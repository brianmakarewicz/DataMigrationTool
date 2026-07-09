#!/usr/bin/env python3
"""
compare_fbdi.py — Stage B4 golden-file byte compare for FBDI generator output.

Compares a locally generated FBDI zip against the frozen-stack golden zip for
one object type, applying ONLY the explicit, per-object token normalization
declared in normalization_map.json:

  1. Run-scoped tokens (old prefix / old run-or-group id vs the local run's
     prefix / run id) are rewritten on BOTH sides to the same placeholder.
  2. Declared generation-date fields (by 0-based CSV position, per the CTL
     column order) are masked on both sides — but only when BOTH sides match
     the FBDI date pattern YYYY/MM/DD; anything else stays a real diff.

Nothing else is normalized. Any remaining difference is reported field-by-field
and the script exits nonzero. HONESTY RULE: never widen the map to make a
compare pass — a diff beyond the declared tokens is a generator finding.

FBDI generator output contract assumed (and verified per line, "self-check"):
every field is double-quoted, quotes escaped by doubling, records end with the
member's declared record terminator (LF by default; "record_terminator":
"CRLF" in the map for generators that emit CRLF, e.g. the supplier family).
If a file does not round-trip through that canonical form, the compare falls
back to reporting it as a finding (quoting/format drift between generators).

HDL (.dat) members: HCM Data Loader files are pipe-delimited, NOT quoted CSV.
A member with "format": "hdl_dat" in the map is parsed line-by-line (split on
'|', LF-terminated, no quoting) into field lists, then the SAME token and
date-mask normalization is applied per field. METADATA/MERGE lines are plain
records; the discriminator (Worker, PersonName, ...) is just field 1. This is
the first HDL golden (the B4 notes anticipated it).

Usage:
  python compare_fbdi.py --object GLBalances --generated out.zip \
      --prefix 9591 --run-id 117 [--map normalization_map.json] [--golden g.zip]

Exit codes: 0 = byte-identical after declared normalization,
            1 = differences found, 2 = usage/environment error.

Stdlib only.
"""

import argparse
import json
import os
import sys
import zipfile

DATE_PAT_LEN = 10  # YYYY/MM/DD


def is_fbdi_date(v):
    if len(v) != DATE_PAT_LEN:
        return False
    for i, ch in enumerate(v):
        if i in (4, 7):
            if ch != "/":
                return False
        elif not ch.isdigit():
            return False
    return True


def parse_dat_records(data, label, problems):
    """Parse a pipe-delimited HDL .dat file into field-lists. HDL .dat is NOT
    quoted CSV: each line is split on '|', lines are LF-terminated, and there is
    no quoting/escaping (HDL forbids '|' inside values). Self-check: the
    canonical re-serialization must reproduce the original bytes, so a
    field-level compare is exactly a byte compare (a CRLF or trailing-content
    drift fails the round-trip and is reported)."""
    try:
        text = data.decode("utf-8")
    except UnicodeDecodeError as e:
        problems.append("%s: not valid UTF-8 (%s); comparing raw bytes only" % (label, e))
        return None
    if "\r" in text:
        problems.append("%s: contains CR bytes; HDL .dat must be LF-terminated "
                        "-- format drift" % label)
        return None
    if not text.endswith("\n"):
        problems.append("%s: last line not LF-terminated -- format drift" % label)
        return None
    records = [line.split("|") for line in text[:-1].split("\n")]
    if serialize_dat(records) != data:
        problems.append("%s: file does not round-trip the canonical HDL .dat "
                        "form (pipe-delimited, LF-terminated) -- format drift" % label)
        return None
    return records


def serialize_dat(records):
    return ("\n".join("|".join(rec) for rec in records) + "\n").encode("utf-8") \
        if records else b''


def parse_records(data, label, problems, terminator="\n"):
    """Parse CSV bytes into a list of field-lists, honoring quoted fields with
    embedded commas/newlines and doubled-quote escapes. Also self-check: the
    canonical re-serialization of each record must reproduce the original
    bytes, so a field-level compare is exactly a byte compare.

    terminator is the member's DECLARED record terminator ("\\n" default, or
    "\\r\\n" when the map says record_terminator=CRLF — the supplier-family
    generators emit CRLF). A terminator the file doesn't actually use is
    still a format-drift finding, because the self-check fails."""
    try:
        text = data.decode("utf-8")
    except UnicodeDecodeError as e:
        problems.append("%s: not valid UTF-8 (%s); comparing raw bytes only" % (label, e))
        return None
    crlf = terminator == "\r\n"
    records, field, fields = [], [], []
    in_quotes = False
    i, n = 0, len(text)
    while i < n:
        ch = text[i]
        if in_quotes:
            if ch == '"':
                if i + 1 < n and text[i + 1] == '"':
                    field.append('"')
                    i += 1
                else:
                    in_quotes = False
            else:
                field.append(ch)
        else:
            if ch == '"':
                in_quotes = True
            elif ch == ",":
                fields.append("".join(field))
                field = []
            elif crlf and ch == "\r" and i + 1 < n and text[i + 1] == "\n":
                fields.append("".join(field))
                records.append(fields)
                field, fields = [], []
                i += 1
            elif not crlf and ch == "\n":
                fields.append("".join(field))
                records.append(fields)
                field, fields = [], []
            elif ch in ("\r", "\n"):
                problems.append(
                    "%s: bare %s byte outside quotes does not match the declared "
                    "%s record terminator — format drift"
                    % (label, "CR" if ch == "\r" else "LF",
                       "CRLF" if crlf else "LF"))
                return None
            else:
                field.append(ch)
        i += 1
    if fields or field or in_quotes:
        problems.append("%s: last record not terminated with the declared "
                        "terminator (or unclosed quote) — format drift" % label)
        return None
    # self-check: canonical serialization must equal the original bytes
    if serialize(records, terminator) != data:
        problems.append(
            "%s: file does not round-trip the canonical FBDI quoting "
            "(all fields double-quoted, declared record terminator) — "
            "quoting/format drift; field-level normalization would not "
            "be byte-honest" % label)
        return None
    return records


def serialize(records, terminator="\n"):
    out = []
    for rec in records:
        out.append(",".join('"' + f.replace('"', '""') + '"' for f in rec))
    return (terminator.join(out) + terminator).encode("utf-8") if records else b""


def apply_tokens(records, tokens):
    """tokens: list of (literal_value, placeholder, match_mode, fields,
    max_len, local_len). Applied per field. match_mode limits how a token may
    hit, so short numeric values (run ids, prefixes) cannot collide with
    unrelated business data:
      whole_field — field must equal the literal exactly
      startswith  — literal replaced only at the start of the field
      substring   — replace every occurrence (use only for long/unique tokens)
    'fields' (optional list of 0-based positions) restricts the token to those
    CSV columns; None = any column.

    max_len (optional, startswith only): the generator's declared truncation
    cap for this column (DMT_UTIL_PKG.PREFIXED(prefix, value, max_len)). The
    prefix comes from a sequence, so its LENGTH can differ between the golden
    run and the local run — a longer local prefix leaves fewer characters of
    the business value inside the cap. With max_len declared, the remainder
    after the prefix is truncated on BOTH sides to (max_len - local_len):
    exactly the bytes the generator must emit for the local prefix. This is a
    reconstruction of declared generator semantics, not a mask — no honest
    diff is hidden (local_len is the length of the LOCAL prefix literal).
    """
    toks = sorted(tokens, key=lambda p: -len(p[0]))
    return [
        [_apply_field(f, c, toks) for c, f in enumerate(rec)]
        for rec in records
    ]


def _apply_field(field, col, toks):
    for lit, ph, mode, fields, max_len, local_len in toks:
        if not lit:
            continue
        if fields is not None and col not in fields:
            continue
        if mode == "whole_field":
            if field == lit:
                field = ph
        elif mode == "startswith":
            if field.startswith(lit):
                rest = field[len(lit):]
                if max_len is not None:
                    rest = rest[:max(max_len - local_len, 0)]
                field = ph + rest
        else:  # substring
            if lit in field:
                field = field.replace(lit, ph)
    return field


def mask_dates(g_records, l_records, positions, member, problems):
    """Mask declared date positions on both sides only where BOTH sides hold a
    YYYY/MM/DD value (or both are empty/equal already). Otherwise leave the
    difference visible."""
    for r, (grec, lrec) in enumerate(zip(g_records, l_records)):
        for pos in positions:
            if pos >= len(grec) or pos >= len(lrec):
                continue
            gv, lv = grec[pos], lrec[pos]
            if gv == lv:
                continue
            if is_fbdi_date(gv) and is_fbdi_date(lv):
                grec[pos] = lrec[pos] = "<DATE>"
            else:
                problems.append(
                    "%s row %d field %d: declared date-mask position but values "
                    "are not both YYYY/MM/DD dates (golden=%r generated=%r) — "
                    "reported as a real diff" % (member, r + 1, pos, gv, lv))


def diff_records(g_records, l_records, member, max_report=20):
    diffs = []
    if len(g_records) != len(l_records):
        diffs.append("%s: row count differs — golden=%d generated=%d"
                     % (member, len(g_records), len(l_records)))
    for r in range(min(len(g_records), len(l_records))):
        grec, lrec = g_records[r], l_records[r]
        if len(grec) != len(lrec):
            diffs.append("%s row %d: field count differs — golden=%d generated=%d"
                         % (member, r + 1, len(grec), len(lrec)))
        for c in range(min(len(grec), len(lrec))):
            if grec[c] != lrec[c]:
                diffs.append("%s row %d field %d: golden=%r generated=%r"
                             % (member, r + 1, c, grec[c], lrec[c]))
                if len(diffs) >= max_report:
                    diffs.append("... (further diffs suppressed)")
                    return diffs
    return diffs


def main():
    ap = argparse.ArgumentParser(description=__doc__.splitlines()[1])
    ap.add_argument("--object", required=True, help="object type key in the map, e.g. GLBalances")
    ap.add_argument("--generated", required=True, help="locally generated FBDI zip")
    ap.add_argument("--golden", help="override golden zip path (default from map)")
    ap.add_argument("--map", dest="map_path",
                    default=os.path.join(os.path.dirname(os.path.abspath(__file__)),
                                         "normalization_map.json"))
    ap.add_argument("--prefix", required=True, help="local run prefix ($PREFIX in the map)")
    ap.add_argument("--run-id", required=True, help="local run id ($RUN_ID in the map)")
    args = ap.parse_args()

    with open(args.map_path, "r", encoding="utf-8") as f:
        full_map = json.load(f)
    if args.object not in full_map:
        print("ERROR: object %r not in %s" % (args.object, args.map_path))
        return 2
    obj_map = full_map[args.object]

    repo_root = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(args.map_path))))
    golden_path = args.golden or os.path.join(repo_root, *obj_map["golden_zip"].split("/"))
    for p in (golden_path, args.generated):
        if not os.path.isfile(p):
            print("ERROR: file not found: %s" % p)
            return 2

    local_values = {"$PREFIX": str(args.prefix), "$RUN_ID": str(args.run_id)}
    gzip_, lzip = zipfile.ZipFile(golden_path), zipfile.ZipFile(args.generated)
    g_names, l_names = set(gzip_.namelist()), set(lzip.namelist())

    problems, diffs = [], []
    mapped = set(obj_map["members"].keys())
    for extra in sorted(g_names - mapped):
        diffs.append("golden zip has member %r not declared in the map" % extra)
    for extra in sorted(l_names - mapped):
        diffs.append("generated zip has undeclared extra member %r" % extra)

    for member, mspec in obj_map["members"].items():
        if member not in g_names:
            diffs.append("member %r missing from golden zip" % member)
            continue
        if member not in l_names:
            diffs.append("member %r missing from generated zip" % member)
            continue
        g_data, l_data = gzip_.read(member), lzip.read(member)
        if g_data == l_data:
            print("  %s: raw bytes identical (no normalization needed)" % member)
            continue

        is_dat = mspec.get("format") == "hdl_dat"
        if is_dat:
            term = "\n"
            g_recs = parse_dat_records(g_data, "golden %s" % member, problems)
            l_recs = parse_dat_records(l_data, "generated %s" % member, problems)
        else:
            term = "\r\n" if mspec.get("record_terminator") == "CRLF" else "\n"
            g_recs = parse_records(g_data, "golden %s" % member, problems, term)
            l_recs = parse_records(l_data, "generated %s" % member, problems, term)
        if g_recs is None or l_recs is None:
            diffs.append("%s: format drift (see problems); raw bytes differ "
                         "(golden %d bytes, generated %d bytes)"
                         % (member, len(g_data), len(l_data)))
            continue

        g_tokens, l_tokens = [], []
        for tok in mspec.get("tokens", []):
            mode = tok.get("match", "whole_field")
            fields = tok.get("fields")
            max_len = tok.get("max_len")
            lv = tok["local"]
            if lv in local_values:
                lv = local_values[lv]              # whole-field placeholder
            else:
                for k, v in local_values.items():  # $PREFIX/$RUN_ID inside a literal
                    lv = lv.replace(k, v)
            lv = str(lv)
            g_tokens.append((str(tok["golden"]), tok["placeholder"], mode, fields,
                             max_len, len(lv)))
            l_tokens.append((lv, tok["placeholder"], mode, fields,
                             max_len, len(lv)))
        g_recs = apply_tokens(g_recs, g_tokens)
        l_recs = apply_tokens(l_recs, l_tokens)
        mask_dates(g_recs, l_recs, mspec.get("date_mask_fields", []), member, problems)

        ser = serialize_dat if is_dat else (lambda recs: serialize(recs, term))
        if ser(g_recs) == ser(l_recs):
            print("  %s: byte-identical after declared normalization "
                  "(tokens: %s; date-mask fields: %s)"
                  % (member,
                     ", ".join(t["placeholder"] for t in mspec.get("tokens", [])) or "none",
                     mspec.get("date_mask_fields", []) or "none"))
        else:
            diffs.extend(diff_records(g_recs, l_recs, member))

    for p in problems:
        print("PROBLEM: %s" % p)
    if diffs:
        print("VERDICT: %s DIFFERS beyond declared normalization (%d finding%s):"
              % (args.object, len(diffs), "" if len(diffs) == 1 else "s"))
        for d in diffs:
            print("  DIFF: %s" % d)
        return 1
    print("VERDICT: %s byte-identical after declared normalization" % args.object)
    return 0


if __name__ == "__main__":
    sys.exit(main())
