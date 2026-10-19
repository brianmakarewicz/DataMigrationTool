#!/usr/bin/env python3
"""
test_upload_verify.py - offline proof of the row judging in
test/playwright/dmt_upload_verify.py (backlog #786). No database, no browser.

What it proves, with a fake cursor:
  * a GOOD row passes only when LOADED with a Fusion id; LOADED without one, or
    FAILED, is reported and fails the verdict;
  * a BAD row passes only when FAILED with non-empty error text, and a row
    expected to fail with its document must quote "Rejected with document:";
  * a FAILED row with no error, an UNACCOUNTED row and an uploaded row the run
    never showed all count as unaccounted, inside their GOOD or BAD totals;
  * a run with no BAD rows is not a pass;
  * the FBDI format is not applicable to HCM objects or the four objects with no
    FBDI mapping, and is "partial" when any staging table has no FBDI file;
  * values are written the same way for the file and for the staged read-back.

    python test/unit/test_upload_verify.py

Exit 0 when every case passes, 1 otherwise.
"""
import datetime
import decimal
import sys
from pathlib import Path

REPO = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(REPO / "test" / "playwright"))
import dmt_upload_verify as uv  # noqa: E402

FAILS = []


def check(name, cond):
    print(("ok   " if cond else "FAIL ") + name)
    if not cond:
        FAILS.append(name)


class FakeCursor:
    def __init__(self, rows):
        self.rows = rows

    def execute(self, *_a, **_k):
        pass

    def fetchall(self):
        return self.rows


class FakeReg:
    sub_stg = {("Obj", "Hdr"): "DMT_H_STG_TBL"}
    pipe = {"Obj": {"pipeline": "P2P"}, "Wkr": {"pipeline": "HCM"}, "Assets": {"pipeline": "FINANCIALS"}}
    upload = {"DMT_H_STG_TBL": {"object_code": "POZ_SUPPLIERS", "fbdi": "PoSupplierImport.csv"},
              "DMT_X_STG_TBL": {"object_code": "X", "fbdi": None}}


def judge(records, expected, staged):
    """records: (status, error, fusion_id) per new staged seq; expected per source seq."""
    seq_map = {("DMT_H_STG_TBL", 100 + s): s for s in staged}
    rows = [("Obj", "Hdr", f"K{seq}", st, err, seq, fid) for seq, (st, err, fid) in records.items()]
    manifest = [{"object": "Obj", "stg": "DMT_H_STG_TBL", "source_seqs": sorted(expected)}]
    exp = {("DMT_H_STG_TBL", s): o for s, o in expected.items()}
    return uv.judge(FakeCursor(rows), FakeReg(), 1, ["Obj"], seq_map, exp, manifest)["Obj"]


# all good: 2 GOOD loaded with ids, 1 BAD failed with error, 1 document failure quoted
r = judge({101: ("LOADED", None, "9001"), 102: ("LOADED", None, "9002"),
           103: ("FAILED", "[FUSION_ERROR] bad", None),
           104: ("FAILED", "[FUSION_ERROR] Rejected with document: line 1: x", None)},
          {1: "LOADED", 2: "LOADED", 3: "FAILED", 4: "FAILED_WITH_DOCUMENT"}, [1, 2, 3, 4])
check("clean run passes", uv.verdict_of({"result": r}) == [])
check("clean run totals", (r["good_loaded"], r["good_total"], r["bad_failed_with_error"], r["bad_total"])
      == (2, 2, 2, 2))

# GOOD loaded without a Fusion id
r = judge({101: ("LOADED", None, None), 103: ("FAILED", "e", None)}, {1: "LOADED", 3: "FAILED"}, [1, 3])
check("LOADED without Fusion id fails", r["good_loaded_no_fusion_id"] == 1 and uv.verdict_of({"result": r}))

# BAD row that LOADED
r = judge({101: ("LOADED", None, "1"), 103: ("LOADED", None, "2")}, {1: "LOADED", 3: "FAILED"}, [1, 3])
check("BAD row LOADED fails", r["bad_loaded"] == 1 and uv.verdict_of({"result": r}))

# document failure without the quote
r = judge({101: ("LOADED", None, "1"), 104: ("FAILED", "[FUSION_ERROR] own", None)},
          {1: "LOADED", 4: "FAILED_WITH_DOCUMENT"}, [1, 4])
check("document failure needs the quote", r["bad_failed_with_error"] == 0 and uv.verdict_of({"result": r}))

# FAILED with no error, UNACCOUNTED, and a staged row not in the run
r = judge({101: ("FAILED", "", None), 103: ("UNACCOUNTED", "[UNACCOUNTED]", None)},
          {1: "LOADED", 3: "FAILED", 5: "FAILED"}, [1, 3, 5])
check("unaccounted counted in totals", (r["unaccounted"], r["not_in_run"], r["good_total"], r["bad_total"])
      == (3, 1, 1, 2))

# no BAD rows at all
r = judge({101: ("LOADED", None, "1")}, {1: "LOADED"}, [1])
check("no BAD rows is not a pass", any("no BAD rows" in x for x in uv.verdict_of({"result": r})))

# FBDI applicability
reg = FakeReg()
check("HCM not applicable", "HCM" in (uv.fbdi_applicability(reg, "Wkr", ["Wkr"], {"Wkr": {}}) or ""))
check("no FBDI mapping", uv.fbdi_applicability(reg, "Assets", ["Assets"], {"Assets": {}}) == "no FBDI mapping")
check("partial mapping", (uv.fbdi_applicability(reg, "Obj", ["Obj"], {"Obj": {"DMT_X_STG_TBL": [1]}}) or "")
      .startswith("partial"))
check("full mapping applies", uv.fbdi_applicability(reg, "Obj", ["Obj"], {"Obj": {"DMT_H_STG_TBL": [1]}}) is None)

# value formatting
check("date", uv.fmt(datetime.datetime(2026, 1, 2)) == "2026/01/02")
check("date-time", uv.fmt(datetime.datetime(2026, 1, 2, 3, 4, 5)) == "2026/01/02 03:04:05")
check("decimal", uv.fmt(decimal.Decimal("12.500")) == "12.5" and uv.fmt(decimal.Decimal("1E+2")) == "100")
check("null", uv.fmt(None) == "")

print(f"\n{'All' if not FAILS else len(FAILS)} {'cases passed' if not FAILS else 'case(s) FAILED'}")
sys.exit(1 if FAILS else 0)
