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
  * the FBDI format is not applicable to HCM objects, or when any staging table
    has no FBDI file in the registry (fbdi_column_maps.FILES);
  * values are written the same way for the file and for the staged read-back;
  * one zip for many objects writes one file per staging table (a table shared
    by several objects carries all their rows) and keeps each object's rows for
    judging; the negative test's bad rows break one value each; the
    ready-for-functional-testing rule.

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
check("a staging table with no FBDI file", (uv.fbdi_applicability(reg, "Obj", ["Obj"], {"Obj": {"DMT_X_STG_TBL": [1]}})
                                           or "").startswith("no FBDI file for"))
check("full mapping applies", uv.fbdi_applicability(reg, "Obj", ["Obj"], {"Obj": {"DMT_H_STG_TBL": [1]}}) is None)

# one zip for many objects: a staging table shared by several objects is ONE file
class PlanReg:
    upload = {"DMT_PO_H_STG_TBL": {"object_code": "PO_H", "csv": "DMT_PO_H_STG_TBL.csv", "fbdi": None, "order": 2},
              "DMT_SUP_STG_TBL": {"object_code": "SUP", "csv": "DMT_SUP_STG_TBL.csv", "fbdi": None, "order": 1}}
    dict_cols = {"PO_H": ["STYLE", "AMT"], "SUP": ["NAME"]}
    dict_fbdi = {}


src = {"Suppliers": {"DMT_SUP_STG_TBL": [{"STG_SEQUENCE_ID": 1, "NAME": "A"}]},
       "PurchaseOrders": {"DMT_PO_H_STG_TBL": [{"STG_SEQUENCE_ID": 10, "STYLE": "STD", "AMT": 5}]},
       "BlanketPOs": {"DMT_PO_H_STG_TBL": [{"STG_SEQUENCE_ID": 11, "STYLE": "BPA", "AMT": None}]}}
members, files, manifest = uv.plan_files(PlanReg(), "header", ["Suppliers", "PurchaseOrders", "BlanketPOs"], src)
check("header format: members are the checks", members is files)
po = [f for f in files if f["stg"] == "DMT_PO_H_STG_TBL"]
check("shared staging table is one file", len(files) == 2 and len(po) == 1)
check("shared file holds every object's rows", po[0]["source_seqs"] == [10, 11]
      and po[0]["objects"] == ["PurchaseOrders", "BlanketPOs"])
check("files follow the registry load order", [f["stg"] for f in files] == ["DMT_SUP_STG_TBL", "DMT_PO_H_STG_TBL"])
check("manifest keeps each object's own rows for judging",
      {(m["object"], tuple(m["source_seqs"])) for m in manifest}
      == {("Suppliers", (1,)), ("PurchaseOrders", (10,)), ("BlanketPOs", (11,))})
check("header file renders all rows", uv.render("header", po[0]["layout"], po[0]["rows"]).decode().splitlines()
      == ["STYLE,AMT", "STD,5", "BPA,"])


# negative test 1: three bad copies of the first row, one bad value each
class TypeCursor(FakeCursor):
    pass


types = [("STYLE", "VARCHAR2", 30), ("AMT", "NUMBER", None), ("NOTE", "VARCHAR2", 5), ("D", "DATE", None)]
PlanReg.dict_cols["PO_H"] = ["STYLE", "AMT", "NOTE", "D"]
f = dict(po[0], raw_rows=[])
uv.add_bad_rows(TypeCursor(types), PlanReg(), "header", f)
kinds = {b["kind"]: b["column"] for b in f["bad"]}
check("bad columns: number, text (columns already in the file first), date",
      kinds == {"number": "AMT", "length": "STYLE", "date": "D"})
check("a needed column is added to the header file", f["layout"] == ["STYLE", "AMT", "D"])
check("bad rows carry one bad value each", [r["AMT"] for r in f["raw_rows"]][0] == "NOT_A_NUMBER"
      and len(f["raw_rows"][1]["STYLE"]) == 40 and f["raw_rows"][2]["D"] == "NOT-A-DATE"
      and f["raw_rows"][1]["AMT"] == "5")
check("good row count excludes the bad rows", f["rows_in_file"] == 2)

# FBDI plan from the file registry: filtered files share a table, a joined file feeds two tables
from fbdi_column_maps import FbdiFile  # noqa: E402


class FReg:
    upload = {"DMT_PH_STG_TBL": {"object_code": "PH", "order": 1}, "DMT_AH_STG_TBL": {"object_code": "AH", "order": 2},
              "DMT_AB_STG_TBL": {"object_code": "AB", "order": 3}}
    dict_cols = {"PH": ["STYLE", "NUM"], "AH": ["ASSET", "DESCR"], "AB": ["ASSET", "BOOK"]}
    dict_fbdi = {}


saved = uv.FBDI_FILES
uv.FBDI_FILES = [FbdiFile("Std.csv", "PH", ["NUM", "STYLE"], 1, False, uv.MDY, "f", None),
                 FbdiFile("Bpa.csv", "PH", ["STYLE", None, "NUM"], 1, False, None, "f", None),
                 FbdiFile("Fa.csv", "AH", ["ASSET", "DESCR", "BOOK"], 1, True, None, None, ("AB", "ASSET")),
                 FbdiFile("Fa.csv", "AB", ["ASSET", "DESCR", "BOOK"], 2, False, None, None, ("AB", "ASSET"))]
fsrc = {"POs": {"DMT_PH_STG_TBL": [{"STG_SEQUENCE_ID": 1, "STYLE": "STD", "NUM": 7},
                                   {"STG_SEQUENCE_ID": 2, "STYLE": "BPA", "NUM": 8}]},
        "Assets": {"DMT_AH_STG_TBL": [{"STG_SEQUENCE_ID": 5, "ASSET": "A1", "DESCR": "x"}],
                   "DMT_AB_STG_TBL": [{"STG_SEQUENCE_ID": 6, "ASSET": "A1", "BOOK": "B1"},
                                      {"STG_SEQUENCE_ID": 7, "ASSET": "A1", "BOOK": "B2"}]}}
mem, chk, _m = uv.plan_files(FReg(), "fbdi", ["POs", "Assets"], fsrc,
                             {("Std.csv", "PH"): {1}, ("Bpa.csv", "PH"): {2}})
by = {m["file"]: m for m in mem}
check("FBDI: one member per registry file", sorted(by) == ["Bpa.csv", "Fa.csv", "Std.csv"])
check("FBDI: row filter splits a shared table", [r["NUM"] for r in by["Std.csv"]["rows"]] == [7]
      and [r["NUM"] for r in by["Bpa.csv"]["rows"]] == [8])
check("FBDI: joined file has one row per driver row", [(r["BOOK"], r["DESCR"]) for r in by["Fa.csv"]["rows"]]
      == [("B1", "x"), ("B2", "x")])
check("FBDI: file's date mask used", uv.render("fbdi", ["D"], [{"D": datetime.datetime(2026, 1, 2)}],
                                               mask=uv.MDY).decode().strip() == '"01/02/2026"')
cby = {c["stg"]: c for c in chk}
check("FBDI: one staging check per table, all its rows", cby["DMT_PH_STG_TBL"]["source_seqs"] == [1, 2]
      and cby["DMT_PH_STG_TBL"]["files"] == ["Std.csv", "Bpa.csv"] and cby["DMT_AB_STG_TBL"]["rows_in_file"] == 2)
uv.FBDI_FILES = saved

# readiness: header PASS and (FBDI PASS or not applicable)
rd = uv.readiness([{"object": "A", "format": "header", "verdict": "PASS"},
                   {"object": "A", "format": "fbdi", "verdict": "NOT APPLICABLE"},
                   {"object": "B", "format": "header", "verdict": "PASS"},
                   {"object": "B", "format": "fbdi", "verdict": "FAIL"},
                   {"object": "C", "format": "header", "verdict": "PASS"}])
check("ready rule", rd["A"] == "yes" and rd["B"].startswith("no") and rd["C"].startswith("not yet"))

# value formatting
check("date", uv.fmt(datetime.datetime(2026, 1, 2)) == "2026/01/02")
check("date-time", uv.fmt(datetime.datetime(2026, 1, 2, 3, 4, 5)) == "2026/01/02 03:04:05")
check("decimal", uv.fmt(decimal.Decimal("12.500")) == "12.5" and uv.fmt(decimal.Decimal("1E+2")) == "100")
check("null", uv.fmt(None) == "")

print(f"\n{'All' if not FAILS else len(FAILS)} {'cases passed' if not FAILS else 'case(s) FAILED'}")
sys.exit(1 if FAILS else 0)
