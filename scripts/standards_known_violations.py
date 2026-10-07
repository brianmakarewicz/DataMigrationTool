#!/usr/bin/env python3
"""standards_known_violations.py -- the shared "known violations" ratchet used by the
standards checkers (check_bip_recon_reports.py, check_sweep_unaccounted.py).

Every violation a checker finds has a stable KEY of the form

    <RULE-ID>|<subject>|<item>

(no line numbers, so an unrelated edit does not change it). The checked-in list
scripts/standards_known_violations.json records every violation that existed when
the rule was introduced, each tied to the docs/backlog.html item that will fix it.

    * a violation whose key IS in the list  -> reported as KNOWN, does not fail;
    * a violation whose key is NOT in the list -> NEW, fails the checker;
    * a listed key that no longer occurs    -> reported as RESOLVED so the entry
      can be deleted; it does not fail (the fix landed -- the list just lags).

Never add an entry to make a red run green without a backlog item that fixes it.
"""

import json
import os

LIST_PATH = os.path.join(os.path.dirname(os.path.abspath(__file__)),
                         "standards_known_violations.json")


def load(checker):
    """Return {key: entry} for one checker's known violations."""
    if not os.path.exists(LIST_PATH):
        return {}
    with open(LIST_PATH, encoding="utf-8") as fh:
        data = json.load(fh)
    out = {}
    for e in data.get("violations", []):
        if e.get("checker") == checker:
            out[e["key"]] = e
    return out


def partition(checker, found):
    """found: list of (key, message). Returns (new, known, resolved) where new/known
    are lists of (key, message, entry-or-None) and resolved is a list of entries."""
    known_map = load(checker)
    new, known = [], []
    seen = set()
    for key, msg in found:
        seen.add(key)
        if key in known_map:
            known.append((key, msg, known_map[key]))
        else:
            new.append((key, msg, None))
    resolved = [e for k, e in sorted(known_map.items()) if k not in seen]
    return new, known, resolved


def report(checker, found, out=print):
    """Print the three groups and return the exit code (1 if any NEW)."""
    new, known, resolved = partition(checker, found)
    if known:
        out("\nKNOWN violations (listed in scripts/standards_known_violations.json; "
            "each has a backlog item -- they do not fail this run):")
        for key, msg, e in known:
            out("  KNOWN  [backlog #%s] %s" % (e.get("backlog"), key))
            out("           %s" % msg)
    if resolved:
        out("\nRESOLVED (listed as known but no longer found -- delete these entries "
            "from scripts/standards_known_violations.json):")
        for e in resolved:
            out("  RESOLVED  [backlog #%s] %s" % (e.get("backlog"), e["key"]))
    if new:
        out("\nNEW violations (not in the known list -- these FAIL the run):")
        for key, msg, _ in new:
            out("  NEW  %s" % key)
            out("         %s" % msg)
    out("\nSummary: %d new, %d known, %d resolved." % (len(new), len(known), len(resolved)))
    return 1 if new else 0
