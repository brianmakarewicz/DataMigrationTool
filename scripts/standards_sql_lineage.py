#!/usr/bin/env python3
"""standards_sql_lineage.py -- a small, dependency-free SQL lineage reader used by
scripts/check_bip_recon_reports.py.

It is NOT a general SQL parser. It understands exactly as much Oracle SELECT syntax
as the BIP reconciliation data models in bip/<Object>/ use, and answers one
question: "for this output column of this SELECT, which REAL table columns and which
string literals can end up in the value, and along which alternative paths?"

  * comments are stripped (string literals respected);
  * WITH ... AS ( ... ) CTEs, derived tables ( SELECT ... ) alias, UNION [ALL]
    branches, scalar sub-queries, JOINs and correlated aliases are resolved;
  * an expression is reduced to a list of ALTERNATIVES -- one per path a value can
    take (each CASE result / ELSE, each NVL / COALESCE / DECODE result, ...). Each
    alternative carries the set of terminal (table, column) references and the set
    of string literals concatenated along that path, or is the NULL alternative;
  * only OUTPUT-producing parts count: CASE WHEN conditions, the first argument of
    NVL2, DECODE search values, WITHIN GROUP ( ORDER BY ... ), WHERE clauses and
    join predicates are not part of the value and are ignored.

Anything it cannot resolve is reported as the terminal table '?' so a caller that
allow-lists real sources fails CLOSED (an unresolvable reference is never silently
accepted).
"""

import re

KEYWORDS_END_FROM = {"where", "group", "having", "order", "connect", "start",
                     "fetch", "offset", "union", "minus", "intersect", "model",
                     "window", "for"}
JOIN_WORDS = {"join", "left", "right", "full", "inner", "outer", "cross",
              "natural", "on", "using", "lateral", "apply"}
NOT_ALIAS = KEYWORDS_END_FROM | JOIN_WORDS | {"as", "select", "from", "partition"}
SET_OPS = {"union", "minus", "intersect"}

MAX_ALTS = 256


# --------------------------------------------------------------------------
# Lexing
# --------------------------------------------------------------------------
def strip_comments(text):
    """Remove -- and /* */ comments, leaving string literals intact."""
    out = []
    i, n = 0, len(text)
    while i < n:
        c = text[i]
        if c == "'":
            j = i + 1
            while j < n:
                if text[j] == "'":
                    if j + 1 < n and text[j + 1] == "'":
                        j += 2
                        continue
                    break
                j += 1
            out.append(text[i:j + 1])
            i = j + 1
        elif text.startswith("--", i):
            j = text.find("\n", i)
            i = n if j < 0 else j
        elif text.startswith("/*", i):
            j = text.find("*/", i + 2)
            i = n if j < 0 else j + 2
            out.append(" ")
        else:
            out.append(c)
            i += 1
    return "".join(out)


TOKEN_RE = re.compile(r"""
    (?P<str>'(?:[^']|'')*')
  | (?P<bind>:[A-Za-z_][A-Za-z0-9_]*)
  | (?P<num>\d+(?:\.\d+)?)
  | (?P<ident>(?:"[^"]+"|[A-Za-z_][A-Za-z0-9_$#]*)(?:\.(?:"[^"]+"|[A-Za-z_][A-Za-z0-9_$#]*|\*))*)
  | (?P<op>\|\||<>|!=|<=|>=|=>|[=<>+\-*/(),;%])
""", re.X)


class Tok:
    __slots__ = ("kind", "val")

    def __init__(self, kind, val):
        self.kind, self.val = kind, val

    def __repr__(self):
        return "%s:%s" % (self.kind, self.val)

    def kw(self, *words):
        return self.kind == "ident" and self.val in words


class Paren:
    __slots__ = ("items",)
    kind = "paren"

    def __init__(self, items):
        self.items = items

    def kw(self, *words):
        return False

    def __repr__(self):
        return "(%s)" % " ".join(map(repr, self.items))


def tokenize(text):
    toks = []
    for m in TOKEN_RE.finditer(text):
        k = m.lastgroup
        v = m.group(k)
        if k == "str":
            toks.append(Tok("str", v[1:-1].replace("''", "'")))
        elif k == "ident":
            toks.append(Tok("ident", v.replace('"', "").lower()))
        else:
            toks.append(Tok(k, v))
    return toks


def nest(toks):
    """Fold ( ... ) into Paren nodes."""
    stack = [[]]
    for t in toks:
        if t.kind == "op" and t.val == "(":
            stack.append([])
        elif t.kind == "op" and t.val == ")":
            if len(stack) == 1:
                continue
            inner = stack.pop()
            stack[-1].append(Paren(inner))
        else:
            stack[-1].append(t)
    while len(stack) > 1:
        inner = stack.pop()
        stack[-1].append(Paren(inner))
    return stack[0]


def split_top(items, sep=","):
    parts, cur = [], []
    for t in items:
        if t.kind == "op" and t.val == sep:
            parts.append(cur)
            cur = []
        else:
            cur.append(t)
    parts.append(cur)
    return parts


# --------------------------------------------------------------------------
# Query model
# --------------------------------------------------------------------------
class Query:
    def __init__(self, ctes, branches):
        self.ctes = ctes            # name -> Query
        self.branches = branches    # [Select]

    def output_names(self):
        return [it.name for it in self.branches[0].items] if self.branches else []


class Item:
    def __init__(self, toks, name):
        self.toks, self.name = toks, name


class Select:
    def __init__(self):
        self.items = []
        self.sources = {}     # alias -> ("table", name) | ("query", Query)
        self.parent = None    # enclosing Select (correlated refs)
        self.ctes = {}        # visible CTEs

    def lookup_cte(self, name):
        s = self
        while s is not None:
            if name in s.ctes:
                return s.ctes[name]
            s = s.parent
        return None


def parse_query(items, parent=None, ctes=None):
    ctes = dict(ctes or {})
    i = 0
    if items and items[0].kw("with"):
        i = 1
        while i < len(items):
            if items[i].kind == "ident" and i + 2 < len(items) and items[i + 1].kw("as") \
                    and isinstance(items[i + 2], Paren):
                name = items[i].val
                ctes[name] = parse_query(items[i + 2].items, parent, ctes)
                i += 3
                if i < len(items) and items[i].kind == "op" and items[i].val == ",":
                    i += 1
                    continue
                break
            i += 1
    rest = items[i:]
    # split on set operators
    parts, cur = [], []
    j = 0
    while j < len(rest):
        t = rest[j]
        if t.kw(*SET_OPS):
            parts.append(cur)
            cur = []
            if j + 1 < len(rest) and rest[j + 1].kw("all", "distinct"):
                j += 1
        else:
            cur.append(t)
        j += 1
    parts.append(cur)
    branches = []
    for p in parts:
        if not p:
            continue
        if isinstance(p[0], Paren) and len([x for x in p if not x.kw("order", "by")]) >= 1 \
                and p[0].items and (p[0].items[0].kw("select", "with") or isinstance(p[0].items[0], Paren)):
            sub = parse_query(p[0].items, parent, ctes)
            branches.extend(sub.branches)
            continue
        sel = parse_select(p, parent, ctes)
        if sel is not None:
            branches.append(sel)
    return Query(ctes, branches)


def parse_select(toks, parent, ctes):
    if not toks or not toks[0].kw("select"):
        return None
    sel = Select()
    sel.parent = parent
    sel.ctes = ctes
    k = 1
    if k < len(toks) and toks[k].kw("distinct", "unique", "all"):
        k += 1
    j = k
    while j < len(toks) and not toks[j].kw("from"):
        j += 1
    for part in split_top(toks[k:j]):
        sel.items.append(Item(part, item_name(part)))
    # FROM clause
    f = j + 1
    end = f
    while end < len(toks) and not toks[end].kw(*KEYWORDS_END_FROM):
        end += 1
    parse_from(toks[f:end], sel, ctes)
    return sel


def item_name(part):
    if not part:
        return None
    last = part[-1]
    if last.kind == "ident" and len(part) >= 2 and part[-2].kw("as"):
        return last.val
    if last.kind == "ident" and len(part) >= 2 and "." not in last.val:
        prev = part[-2]
        if isinstance(prev, Paren) or prev.kind in ("str", "num", "bind") or \
                (prev.kind == "ident" and not prev.kw("case", "when", "then", "else",
                                                       "and", "or", "not", "is", "in")) \
                or prev.kw("end"):
            if not last.kw("end", "null"):
                return last.val
    if len(part) == 1 and last.kind == "ident":
        return last.val.split(".")[-1]
    return None


def parse_from(toks, sel, ctes):
    i = 0
    n = len(toks)
    expect_source = True
    while i < n:
        t = toks[i]
        if expect_source:
            src = None
            if isinstance(t, Paren):
                src = ("query", parse_query(t.items, sel, ctes))
            elif t.kind == "ident" and not t.kw(*JOIN_WORDS):
                name = t.val
                src = ("table", name)
            if src is not None:
                alias = None
                if i + 1 < n and toks[i + 1].kw("as"):
                    i += 1
                if i + 1 < n and toks[i + 1].kind == "ident" and not toks[i + 1].kw(*NOT_ALIAS):
                    alias = toks[i + 1].val
                    i += 1
                if alias is None:
                    alias = src[1] if src[0] == "table" else "__anon%d" % len(sel.sources)
                if src[0] == "table" and "." not in src[1]:
                    cte = ctes.get(src[1])
                    if cte is not None:
                        src = ("query", cte)
                sel.sources[alias] = src
                expect_source = False
            i += 1
            continue
        if t.kind == "op" and t.val == ",":
            expect_source = True
        elif t.kw("join"):
            expect_source = True
        i += 1


# --------------------------------------------------------------------------
# Expression alternatives
# --------------------------------------------------------------------------
class Alt:
    __slots__ = ("cols", "lits", "null")

    def __init__(self, cols=(), lits=(), null=False):
        self.cols = frozenset(cols)
        self.lits = frozenset(lits)
        self.null = null

    def key(self):
        return (self.cols, self.lits, self.null)


NULL_ALT = Alt(null=True)
EMPTY_ALT = Alt()


def dedupe(alts):
    seen, out = set(), []
    for a in alts:
        if a.key() not in seen:
            seen.add(a.key())
            out.append(a)
    return out


def concat(a_list, b_list):
    out = []
    for a in a_list:
        for b in b_list:
            if a.null and b.null:
                out.append(NULL_ALT)
            else:
                out.append(Alt(a.cols | b.cols, a.lits | b.lits, False))
    out = dedupe(out)
    if len(out) > MAX_ALTS:   # collapse rather than explode; keeps every ref/literal
        cols = frozenset().union(*[x.cols for x in out])
        lits = frozenset().union(*[x.lits for x in out])
        out = [Alt(cols, lits)]
    return out


def non_null(alts):
    return [a for a in alts if not a.null]


class Resolver:
    def __init__(self):
        self._busy = set()

    # ---- column references ------------------------------------------------
    def resolve_ref(self, ref, sel):
        parts = ref.split(".")
        if len(parts) >= 2:
            alias, col = parts[-2], parts[-1]
            s = sel
            while s is not None:
                if alias in s.sources:
                    return self.resolve_in_source(s.sources[alias], col)
                s = s.parent
            return [Alt(cols={("?", ref)})]
        col = parts[0]
        if col in ("null",):
            return [NULL_ALT]
        if col in ("sysdate", "systimestamp", "user", "rownum", "level"):
            return [Alt(cols={("<pseudo>", col)})]
        s = sel
        while s is not None:
            if len(s.sources) == 1:
                return self.resolve_in_source(next(iter(s.sources.values())), col)
            hits = []
            for src in s.sources.values():
                if src[0] == "query" and col in [n for n in src[1].output_names() if n]:
                    hits.append(src)
            if len(hits) == 1:
                return self.resolve_in_source(hits[0], col)
            if s.sources:
                break
            s = s.parent
        return [Alt(cols={("?", col)})]

    def resolve_in_source(self, src, col):
        if src[0] == "table":
            return [Alt(cols={(src[1], col)})]
        return self.resolve_output(src[1], col)

    def resolve_output(self, q, col):
        key = (id(q), col)
        if key in self._busy:
            return [Alt(cols={("?", col)})]
        self._busy.add(key)
        try:
            names = q.output_names()
            alts = []
            for br in q.branches:
                idx = None
                if col in names:
                    idx = names.index(col)
                if idx is not None and idx < len(br.items):
                    alts.extend(self.eval(br.items[idx].toks, br))
                    continue
                # star expansion: x.* / *
                star = [it for it in br.items if it.toks and it.toks[-1].kind == "ident"
                        and (it.toks[-1].val.endswith(".*"))]
                done = False
                for it in star:
                    alias = it.toks[-1].val[:-2]
                    if alias in br.sources:
                        alts.extend(self.resolve_in_source(br.sources[alias], col))
                        done = True
                        break
                if not done:
                    alts.append(Alt(cols={("?", col)}))
            return dedupe(alts)
        finally:
            self._busy.discard(key)

    # ---- expressions -----------------------------------------------------
    def eval(self, toks, sel):
        # strip a trailing alias
        toks = list(toks)
        name = item_name(toks)
        if name and len(toks) >= 2 and toks[-1].kind == "ident" and toks[-1].val == name:
            toks = toks[:-1]
            if toks and toks[-1].kw("as"):
                toks = toks[:-1]
        operands = self.split_concat(toks)
        result = None
        for op in operands:
            alts = self.eval_operand(op, sel)
            result = alts if result is None else concat(result, alts)
        return result or [NULL_ALT]

    @staticmethod
    def split_concat(toks):
        parts, cur, depth = [], [], 0
        for t in toks:
            if t.kw("case"):
                depth += 1
            elif t.kw("end"):
                depth -= 1
            if depth == 0 and t.kind == "op" and t.val in ("||", "+", "-", "*", "/"):
                parts.append(cur)
                cur = []
            else:
                cur.append(t)
        parts.append(cur)
        return [p for p in parts if p]

    def eval_operand(self, toks, sel):
        if not toks:
            return [NULL_ALT]
        t = toks[0]
        if t.kw("case"):
            return self.eval_case(toks, sel)
        if t.kind == "str":
            return [Alt(lits={t.val})] if t.val != "" else [NULL_ALT]
        if t.kind == "num":
            return [EMPTY_ALT]
        if t.kind == "bind":
            return [Alt(cols={("<bind>", t.val.lower())})]
        if isinstance(t, Paren):
            if t.items and t.items[0].kw("select", "with"):
                q = parse_query(t.items, sel, sel.ctes)
                alts = []
                for br in q.branches:
                    if br.items:
                        alts.extend(self.eval(br.items[0].toks, br))
                return dedupe(alts) or [NULL_ALT]
            return self.eval(t.items, sel)
        if t.kind == "ident":
            if len(toks) >= 2 and isinstance(toks[1], Paren):
                return self.eval_func(t.val, toks[1].items, sel)
            if t.kw("null"):
                return [NULL_ALT]
            if t.kw("distinct"):
                return self.eval_operand(toks[1:], sel)
            return self.resolve_ref(t.val, sel)
        return [EMPTY_ALT]

    def eval_case(self, toks, sel):
        # toks: CASE ... END (possibly with trailing junk). Collect THEN / ELSE results.
        # results: [(condition_tokens or None, result_tokens)]
        results, cur, cond, mode, depth = [], [], None, None, 0
        has_else = False
        for t in toks[1:]:
            if t.kw("case"):
                depth += 1
            if depth == 0 and t.kw("when", "then", "else", "end"):
                if mode == "when":
                    cond = cur
                elif mode in ("then", "else") and cur:
                    results.append((cond if mode == "then" else None, cur))
                cur = []
                mode = t.val
                if t.val == "else":
                    has_else = True
                if t.val == "end":
                    break
                continue
            if t.kw("end"):
                depth -= 1
            cur.append(t)
        alts = []
        for c, r in results:
            r_alts = self.eval(r, sel)
            guard = self.not_null_guard(c, sel)
            if guard:
                # WHEN <E> IS NOT NULL THEN ... <E> ...: on this path E is non-NULL,
                # so drop alternatives that carry none of E's columns (they are the
                # paths where E was NULL, which this branch cannot take).
                kept = [a for a in r_alts if a.null or (a.cols & guard)]
                r_alts = kept or r_alts
            alts.extend(r_alts)
        if not has_else:
            alts.append(NULL_ALT)
        return dedupe(alts)

    def not_null_guard(self, cond, sel):
        """For a WHEN condition of the exact form '<expr> IS NOT NULL' return the
        columns of <expr>'s non-NULL alternatives; otherwise an empty set."""
        if not cond or len(cond) < 4:
            return frozenset()
        if not (cond[-3].kw("is") and cond[-2].kw("not") and cond[-1].kw("null")):
            return frozenset()
        expr = cond[:-3]
        if any(t.kw("and", "or") for t in expr):
            return frozenset()
        cols = set()
        for a in non_null(self.eval(expr, sel)):
            cols |= a.cols
        return frozenset(cols)

    def eval_func(self, fname, args_items, sel):
        fname = fname.split(".")[-1]
        args = split_top(args_items)
        # drop LISTAGG "ON OVERFLOW ..." / CAST "AS type" tails
        if fname == "cast":
            body = []
            for x in args_items:
                if x.kw("as"):
                    break
                body.append(x)
            return self.eval(body, sel)
        if fname == "listagg":
            first = args[0] if args else []
            sep = []
            if len(args) > 1:
                sep = []
                for x in args[1]:
                    if x.kw("on"):
                        break
                    sep.append(x)
            alts = self.eval(first, sel)
            if sep:
                # the separator only appears between non-NULL values
                nn = non_null(alts)
                alts = dedupe(concat(nn, self.eval(sep, sel) + [NULL_ALT])
                              + [a for a in alts if a.null])
            return alts
        if fname in ("nvl", "ifnull"):
            a = self.eval(args[0], sel)
            b = self.eval(args[1], sel) if len(args) > 1 else [NULL_ALT]
            return dedupe(non_null(a) + b)
        if fname == "nvl2":
            out = []
            for a in args[1:3]:
                out.extend(self.eval(a, sel))
            return dedupe(out)
        if fname == "coalesce":
            out = []
            for a in args:
                out.extend(non_null(self.eval(a, sel)))
            return dedupe(out + [NULL_ALT])
        if fname == "decode":
            out = []
            rest = args[1:]
            for k in range(1, len(rest), 2):
                out.extend(self.eval(rest[k], sel))
            if len(rest) % 2 == 1:
                out.extend(self.eval(rest[-1], sel))
            else:
                out.append(NULL_ALT)
            return dedupe(out)
        if fname == "nullif":
            return dedupe(self.eval(args[0], sel) + [NULL_ALT])
        if fname in ("substr", "substrb", "trim", "ltrim", "rtrim", "upper", "lower",
                     "initcap", "to_char", "to_clob", "to_nchar", "max", "min", "any_value",
                     "dbms_lob", "lpad", "rpad"):
            return self.eval(args[0], sel) if args else [NULL_ALT]
        if fname in ("replace", "regexp_replace", "translate"):
            a = self.eval(args[0], sel) if args else [NULL_ALT]
            if len(args) >= 3:
                a = concat(a, self.eval(args[2], sel) + [NULL_ALT])
            return a
        if fname in ("count", "sum", "avg", "to_number", "length", "instr", "row_number",
                     "rank", "dense_rank", "to_date", "trunc", "round", "abs", "sign"):
            out = [EMPTY_ALT]
            for a in args:
                for alt in self.eval(a, sel):
                    out = concat(out, [Alt(cols=alt.cols)])
            return out
        # unknown function: every argument contributes (fail closed)
        out = None
        for a in args:
            alts = self.eval(a, sel)
            out = alts if out is None else concat(out, alts)
        return out or [NULL_ALT]


def unwrap_branches(q):
    """Descend through pass-through wrappers: a branch that only re-selects plain
    columns of ONE derived source is replaced by that source's own branches, so
    per-branch checks see the real UNION members (status and message together)."""
    out = []
    for br in q.branches:
        if len(br.sources) == 1:
            src = next(iter(br.sources.values()))
            plain = all(len(it.toks) == 1 and it.toks[0].kind == "ident" for it in br.items)
            if src[0] == "query" and plain:
                inner_names = src[1].output_names()
                if [it.toks[0].val.split(".")[-1] for it in br.items] == \
                        inner_names[:len(br.items)]:
                    out.extend(unwrap_branches(src[1]))
                    continue
        out.append(br)
    return out


def parse_sql(text):
    toks = nest(tokenize(strip_comments(text)))
    # drop trailing ';' and SQL*Plus '/' terminators
    while toks and toks[-1].kind == "op" and toks[-1].val in (";", "/"):
        toks.pop()
    return parse_query(toks)
