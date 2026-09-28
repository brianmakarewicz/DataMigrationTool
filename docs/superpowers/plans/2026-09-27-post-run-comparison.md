# Post-Run Comparison Report Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build a post-run report that, for one pipeline run, shows each object's staged count/amount, transform-error count/amount, and **live Fusion success** count/amount side by side, and flags where they don't reconcile.

**Architecture:** One uniform output contract (a SQL object type) produced by a per-object comparison function that runs three queries — staged (from the run's transform rows), transform errors, and a **live Fusion aggregate BIP report** keyed by a production-valid batch id (or captured Fusion ids where no batch id exists). A shared framework enumerates the objects in a run, dispatches to each object's function via a registry column, and returns the assembled grid. An APEX page on app 501 drives it. This plan builds the framework plus **Purchase Orders** end-to-end (the walking skeleton); the other 22 objects follow the same template in later plans.

**Tech Stack:** Oracle PL/SQL (23ai on Docker `dmt2-local` port 1523), Oracle BI Publisher (SOAP v2 ReportService against Fusion), Oracle APEX 26.1 (APEXLang), Python only as the deploy/test shim (`scripts/dmt_deploy.py`).

**Spec:** `docs/superpowers/specs/2026-09-27-post-run-comparison-design.md` (read it and `docs/superpowers/specs/discovery/QUERY_MATRIX.md` + `discovery/PurchaseOrders.md` before starting — the proven per-object SQL lives there).

## Global Constraints

- **Pure PL/SQL pipeline.** Python is dev/test/deploy shim only — no pipeline logic in Python.
- **Git-first DDL.** Every DB change is a committed file, deployed with `python scripts/dmt_deploy.py code <files>` (packages) or `dmt_deploy.py table --create <f> --migration <f>` (schema). Never connect as ADMIN/SYSTEM; schema owner `dmt_owner` only.
- **New SQL files must be registered in `db/install.sql`** in dependency order (types → tables → views → packages → seed).
- **Install/migration scripts must be idempotent** and re-runnable (guarded DDL, `MERGE` seeds); prove by running twice.
- **BIP target folder is `/Custom/DMT2/` only.** Never overwrite an existing BIP object — deploy the comparison report as a NEW object (`*_CMP_DM.xdm` / `*_CMP_RPT.xdo`) alongside the recon report.
- **Never query Fusion by prefix or by a timestamp window.** Key on the batch id (import/load ESS request id from `DMT_WORK_QUEUE_TBL`, which can be a **list** for one object), a stamped round-tripping reference, or the captured `FUSION_*_ID` — in that order.
- **A BIP SOAP fault must raise, never be swallowed as zero** (`DMT_UTIL_PKG.RUN_BIP_REPORT` returns `x_error_code`; treat non-success as an error, not as 0 successes).
- **Staging is scoped through the transform row's `STG_SEQUENCE_ID`,** never by business key or prefix (STG has no RUN_ID and holds duplicate seed rows).
- **APEX work is APEXLang on local Docker (26.1), copy-before-modify,** on app 501 (alias `LIVEDMT2`, files under `apex/f501src/livedmt2/`).
- **The BIP transport is owned by `DMT_UTIL_PKG.RUN_BIP_REPORT`;** comparison code never builds its own SOAP.

## Review Focus

- **Object still in flight (no request id yet):** `GET_COMPARISON` for a run whose object has NULL `IMPORT_ESS_JOB_ID`/`LOAD_ESS_JOB_ID` must return the staged/error sides with `FUSION_SUCCESS_COUNT = NULL` and `KEY_TYPE = 'NONE'`, not error and not report 0 — pinned in Task 4.
- **BIP SOAP fault / non-success:** a fault from the Fusion call must surface as an error on that object's row (or a raised exception), never a silent `SUCCESS_COUNT = 0` — pinned in Task 4.
- **Multiple request ids in one run:** an object with two ESS ids (e.g. Requisitions) must pass **all** of them to the Fusion report (IN-list bind), or the success count undercounts — the batch-id resolver in Task 4 returns a list; pinned in Task 5's dispatch test with a stub.
- **Money absent in Fusion (Blanket POs) / recomputed (Expenditures):** `FUSION_MONEY_AVAILABLE = 'N'` suppresses the money variance so no false out-of-balance shows — pinned in Task 1 (the type's balance rule) and Task 4.
- **Run object with no comparison function registered:** the framework skips it with a logged note, never raising — pinned in Task 5.

---

## File Structure

- Create `db/types/dmt_cmp_row_typ.sql` — the SQL object type `DMT_CMP_ROW_OBJ` and table type `DMT_CMP_ROW_TAB` (the uniform comparison row).
- Create `db/migrations/2026-09-27_bip_report_comparison_cols.sql` — adds comparison columns to `DMT_BIP_REPORT_TBL`.
- Modify `db/tables/dmt_bip_report_tbl.sql` — add the three comparison columns to the create script (git-first).
- Modify `db/seed/dmt_bip_report_tbl.sql` — set the comparison columns for the `PurchaseOrders` row.
- Create `bip/PurchaseOrders/PO_CMP_DM.xdm` and `bip/PurchaseOrders/PO_CMP_RPT.xdo` — the PO Fusion aggregate report.
- Create `db/packages/dmt_po_compare_pkg.pks.sql` / `.pkb.sql` — `GET_COMPARISON(p_run_id) RETURN DMT_CMP_ROW_OBJ` for Purchase Orders.
- Create `db/packages/dmt_run_compare_pkg.pks.sql` / `.pkb.sql` — the framework: `GET_RUN_COMPARISON(p_run_id, x_cursor)` and helpers.
- Create `test/comparison/test_po_compare.sql` and `test/comparison/test_run_compare.sql` — runnable assertion harnesses against run 132.
- Modify `db/install.sql` — register the new type and packages in order.
- Modify `apex/f501src/livedmt2/` — new page `p000NN-run-comparison.apx` (copy-before-modify) + supporting page process.

The comparison row type is the linchpin interface every later object reuses; it is Task 1.

---

### Task 1: The uniform comparison-row type

**Files:**
- Create: `db/types/dmt_cmp_row_typ.sql`
- Modify: `db/install.sql` (register the type before packages)
- Test: `test/comparison/test_type_compiles.sql`

**Interfaces:**
- Produces: SQL types `DMT_CMP_ROW_OBJ` (attributes below) and `DMT_CMP_ROW_TAB AS TABLE OF DMT_CMP_ROW_OBJ`, used by every object's `GET_COMPARISON` function and by the framework.

Attribute contract (order matters — the APEX region and the framework cursor read positionally):
`OBJECT_TYPE VARCHAR2(100), CEMLI_CODE VARCHAR2(60), KEY_TYPE VARCHAR2(20), STG_COUNT NUMBER, STG_AMOUNT NUMBER, TFM_ERROR_COUNT NUMBER, TFM_ERROR_AMOUNT NUMBER, FUSION_SUCCESS_COUNT NUMBER, FUSION_SUCCESS_AMOUNT NUMBER, AMOUNT_CURRENCY VARCHAR2(15), FUSION_MONEY_AVAILABLE VARCHAR2(1), VARIANCE_COUNT NUMBER, VARIANCE_AMOUNT NUMBER, IN_BALANCE VARCHAR2(1), NOTE VARCHAR2(400)`.

- [ ] **Step 1: Write the failing test**

`test/comparison/test_type_compiles.sql`:
```sql
SET SERVEROUTPUT ON
DECLARE
    r DMT_CMP_ROW_OBJ;
    t DMT_CMP_ROW_TAB;
BEGIN
    r := DMT_CMP_ROW_OBJ('PurchaseOrders','PurchaseOrders','LOAD_ID',
                         3, 2300, 1, 50, 2, 2250, 'USD', 'Y', NULL, NULL, NULL, NULL);
    t := DMT_CMP_ROW_TAB(r);
    IF t.COUNT = 1 AND t(1).STG_COUNT = 3 THEN
        DBMS_OUTPUT.PUT_LINE('PASS');
    ELSE
        RAISE_APPLICATION_ERROR(-20900, 'type shape wrong');
    END IF;
END;
/
```

- [ ] **Step 2: Run it and confirm it fails**

Run: `python scripts/dmt_deploy.py run test/comparison/test_type_compiles.sql` (or pipe via SQLcl per `reference_sqlcl_deploy_stdin_gotcha`: `echo exit | sql dmt_owner/…@… @test/comparison/test_type_compiles.sql`).
Expected: FAIL — `PLS-00201: identifier 'DMT_CMP_ROW_OBJ' must be declared`.

- [ ] **Step 3: Create the type**

`db/types/dmt_cmp_row_typ.sql`:
```sql
CREATE OR REPLACE TYPE DMT_CMP_ROW_OBJ AS OBJECT (
    OBJECT_TYPE            VARCHAR2(100),
    CEMLI_CODE             VARCHAR2(60),
    KEY_TYPE               VARCHAR2(20),   -- LOAD_ID | IMPORT_ID | STAMPED_REF | CAPTURED_ID | NONE
    STG_COUNT              NUMBER,
    STG_AMOUNT             NUMBER,
    TFM_ERROR_COUNT        NUMBER,
    TFM_ERROR_AMOUNT       NUMBER,
    FUSION_SUCCESS_COUNT   NUMBER,
    FUSION_SUCCESS_AMOUNT  NUMBER,
    AMOUNT_CURRENCY        VARCHAR2(15),
    FUSION_MONEY_AVAILABLE VARCHAR2(1),    -- Y | N
    VARIANCE_COUNT         NUMBER,
    VARIANCE_AMOUNT        NUMBER,
    IN_BALANCE             VARCHAR2(1),     -- Y | N | ? (unknown: Fusion side not available)
    NOTE                   VARCHAR2(400)
);
/
CREATE OR REPLACE TYPE DMT_CMP_ROW_TAB AS TABLE OF DMT_CMP_ROW_OBJ;
/
```

- [ ] **Step 4: Register in install.sql**

In `db/install.sql`, add a line to run `db/types/dmt_cmp_row_typ.sql` after sequences/tables and **before** the packages section (types must exist before packages that reference them). Match the existing `@@` include style used for other DDL in that file.

- [ ] **Step 5: Deploy and re-run the test**

Run: `python scripts/dmt_deploy.py code db/types/dmt_cmp_row_typ.sql` then re-run the test.
Expected: PASS (prints `PASS`).

- [ ] **Step 6: Commit**

```bash
git add db/types/dmt_cmp_row_typ.sql db/install.sql test/comparison/test_type_compiles.sql
git commit -m "feat(comparison): uniform comparison-row SQL type"
```

---

### Task 2: Registry columns for the comparison report

**Files:**
- Create: `db/migrations/2026-09-27_bip_report_comparison_cols.sql`
- Modify: `db/tables/dmt_bip_report_tbl.sql` (add columns to the create script)
- Modify: `db/seed/dmt_bip_report_tbl.sql` (set them for PurchaseOrders)
- Test: `test/comparison/test_registry_cols.sql`

**Interfaces:**
- Produces: three columns on `DMT_BIP_REPORT_TBL` — `CMP_DM_CATALOG_PATH VARCHAR2(500)`, `CMP_REPORT_CATALOG_PATH VARCHAR2(500)`, `CMP_FUNCTION VARCHAR2(200)` (the `PKG.FUNC` returning `DMT_CMP_ROW_OBJ` for that object). Consumed by the framework (Task 5) and the per-object function's report-path lookup (Task 4).

- [ ] **Step 1: Write the failing test**

`test/comparison/test_registry_cols.sql`:
```sql
SET SERVEROUTPUT ON
DECLARE
    l_fn   DMT_BIP_REPORT_TBL.CMP_FUNCTION%TYPE;
    l_path DMT_BIP_REPORT_TBL.CMP_REPORT_CATALOG_PATH%TYPE;
BEGIN
    SELECT CMP_FUNCTION, CMP_REPORT_CATALOG_PATH
      INTO l_fn, l_path
      FROM DMT_BIP_REPORT_TBL
     WHERE CEMLI_CODE = 'PurchaseOrders';
    IF l_fn = 'DMT_PO_COMPARE_PKG.GET_COMPARISON'
       AND l_path = '/Custom/DMT2/PurchaseOrders/PO_CMP_RPT.xdo' THEN
        DBMS_OUTPUT.PUT_LINE('PASS');
    ELSE
        RAISE_APPLICATION_ERROR(-20901, 'registry not seeded: '||l_fn||' / '||l_path);
    END IF;
END;
/
```

- [ ] **Step 2: Run it and confirm it fails**

Run the test. Expected: FAIL — `ORA-00904: "CMP_FUNCTION": invalid identifier`.

- [ ] **Step 3: Write the migration (idempotent)**

`db/migrations/2026-09-27_bip_report_comparison_cols.sql`:
```sql
DECLARE
    PROCEDURE add_col(p_col VARCHAR2, p_def VARCHAR2) IS
        n NUMBER;
    BEGIN
        SELECT COUNT(*) INTO n FROM user_tab_columns
         WHERE table_name = 'DMT_BIP_REPORT_TBL' AND column_name = p_col;
        IF n = 0 THEN
            EXECUTE IMMEDIATE 'ALTER TABLE DMT_BIP_REPORT_TBL ADD ('||p_col||' '||p_def||')';
        END IF;
    END;
BEGIN
    add_col('CMP_DM_CATALOG_PATH',     'VARCHAR2(500)');
    add_col('CMP_REPORT_CATALOG_PATH', 'VARCHAR2(500)');
    add_col('CMP_FUNCTION',            'VARCHAR2(200)');
END;
/
```

- [ ] **Step 4: Mirror the columns in the create script (git-first)**

In `db/tables/dmt_bip_report_tbl.sql`, add the same three columns to the `CREATE TABLE` column list (so a fresh install already has them), placed after `APPLY_PROC`.

- [ ] **Step 5: Seed PurchaseOrders**

In `db/seed/dmt_bip_report_tbl.sql`, in the `PurchaseOrders` MERGE source row add:
`'/Custom/DMT2/PurchaseOrders/PO_CMP_DM.xdm' cmp_dm_catalog_path, '/Custom/DMT2/PurchaseOrders/PO_CMP_RPT.xdo' cmp_report_catalog_path, 'DMT_PO_COMPARE_PKG.GET_COMPARISON' cmp_function` and add these to the MERGE's `UPDATE SET` and `INSERT` column lists. Keep every other object's new columns NULL for now.

- [ ] **Step 6: Deploy and re-run the test**

Run: `python scripts/dmt_deploy.py table --create db/tables/dmt_bip_report_tbl.sql --migration db/migrations/2026-09-27_bip_report_comparison_cols.sql`, then deploy the seed: `python scripts/dmt_deploy.py code db/seed/dmt_bip_report_tbl.sql`. Re-run the test twice (prove idempotent). Expected: PASS both times.

- [ ] **Step 7: Commit**

```bash
git add db/migrations/2026-09-27_bip_report_comparison_cols.sql db/tables/dmt_bip_report_tbl.sql db/seed/dmt_bip_report_tbl.sql test/comparison/test_registry_cols.sql
git commit -m "feat(comparison): registry columns for per-object comparison report"
```

---

### Task 3: Purchase Orders Fusion aggregate BIP report

**Files:**
- Create: `bip/PurchaseOrders/PO_CMP_DM.xdm`
- Create: `bip/PurchaseOrders/PO_CMP_RPT.xdo`
- Test: manual deploy + live run (Task 6 verifies end-to-end; this task authors and unit-checks the SQL against Fusion).

**Interfaces:**
- Produces: a BIP data model at `/Custom/DMT2/PurchaseOrders/PO_CMP_DM.xdm` returning ONE row `G_1` with elements `SUCCESS_COUNT`, `SUCCESS_AMOUNT`, `AMOUNT_CURRENCY`, keyed by bind `:P_BATCH_ID` (a comma-joined list of import request ids). Consumed by Task 4.

The exact success query is the one proven in `discovery/PurchaseOrders.md` (Fusion side): standard POs in `po_headers_all` for the run's import request id(s), amount = `SUM(quantity*unit_price)` over `po_lines_all` because the line `AMOUNT` is null for standard lines.

- [ ] **Step 1: Author the data model**

`bip/PurchaseOrders/PO_CMP_DM.xdm` — copy the shape of the existing `bip/PurchaseOrders/PO_DM.xdm` (same `dataModel` header, `ApplicationDB_FSCM` source, `include_parameters`), replacing the dataset SQL with the aggregate and declaring a single `:P_BATCH_ID` string parameter. Dataset SQL (CDATA):
```sql
SELECT COUNT(DISTINCT h.po_header_id)                       AS success_count,
       NVL(SUM(ln.quantity * ln.unit_price), 0)             AS success_amount,
       MAX(h.currency_code)                                 AS amount_currency
FROM   po_headers_all h
JOIN   po_lines_all   ln ON ln.po_header_id = h.po_header_id
WHERE  h.type_lookup_code = 'STANDARD'
AND    h.request_id IN (
         SELECT TO_NUMBER(REGEXP_SUBSTR(:P_BATCH_ID, '[^,]+', 1, LEVEL))
         FROM dual CONNECT BY REGEXP_SUBSTR(:P_BATCH_ID, '[^,]+', 1, LEVEL) IS NOT NULL
       )
```
Output group `G_1` with three `<element>` tags mapping `SUCCESS_COUNT`, `SUCCESS_AMOUNT`, `AMOUNT_CURRENCY` (all `xsd:string`), root `DATA_DS`.

- [ ] **Step 2: Author the report object**

`bip/PurchaseOrders/PO_CMP_RPT.xdo` — copy `bip/PurchaseOrders/PO_RPT.xdo`, repoint its data model reference to `PO_CMP_DM`. (The report is a data carrier only; no layout needed for a SOAP `runReport` that returns XML data.)

- [ ] **Step 3: Verify the SQL against Fusion (read-only, before deploy)**

Run the dataset SQL live with `:P_BATCH_ID = '10024267'` via `python scripts/fusion_bip_query.py` (the proven run-132 import id).
Expected: one row, `SUCCESS_COUNT = 2`, `SUCCESS_AMOUNT = 2250`, `AMOUNT_CURRENCY = USD`. If not, fix the SQL before deploying.

- [ ] **Step 4: Commit**

```bash
git add bip/PurchaseOrders/PO_CMP_DM.xdm bip/PurchaseOrders/PO_CMP_RPT.xdo
git commit -m "feat(comparison): PO Fusion aggregate BIP report"
```

---

### Task 4: Purchase Orders comparison function

**Files:**
- Create: `db/packages/dmt_po_compare_pkg.pks.sql`, `db/packages/dmt_po_compare_pkg.pkb.sql`
- Modify: `db/install.sql` (register the package)
- Test: `test/comparison/test_po_compare.sql`

**Interfaces:**
- Consumes: `DMT_CMP_ROW_OBJ` (Task 1); `DMT_BIP_REPORT_TBL.CMP_REPORT_CATALOG_PATH` (Task 2); `DMT_UTIL_PKG.RUN_BIP_REPORT(p_run_id, p_cemli_code, p_params, x_report_xml, x_error_code, p_report_path)` and `DMT_BIP_REPORT_TBL` for the request-id list.
- Produces: `DMT_PO_COMPARE_PKG.GET_COMPARISON(p_run_id IN NUMBER) RETURN DMT_CMP_ROW_OBJ`.

Logic: (a) STG/TFM counts+amount from the run's transform rows for standard POs, using the proven queries in `discovery/PurchaseOrders.md`; (b) request-id list from `DMT_WORK_QUEUE_TBL` for `(p_run_id,'PurchaseOrders')`; (c) if list is empty → `KEY_TYPE='NONE'`, Fusion columns NULL, `IN_BALANCE='?'`; (d) else call the comparison report, parse the single row; (e) on `x_error_code <> C_SUCCESS` raise (never treat as 0); (f) compute variance and balance (money variance only when `FUSION_MONEY_AVAILABLE='Y'`).

- [ ] **Step 1: Write the failing test (against run 132)**

`test/comparison/test_po_compare.sql`:
```sql
SET SERVEROUTPUT ON
DECLARE
    r DMT_CMP_ROW_OBJ;
BEGIN
    r := DMT_PO_COMPARE_PKG.GET_COMPARISON(132);
    DBMS_OUTPUT.PUT_LINE('stg='||r.STG_COUNT||'/'||r.STG_AMOUNT
        ||' tfmerr='||r.TFM_ERROR_COUNT||'/'||r.TFM_ERROR_AMOUNT
        ||' fus='||r.FUSION_SUCCESS_COUNT||'/'||r.FUSION_SUCCESS_AMOUNT
        ||' key='||r.KEY_TYPE||' bal='||r.IN_BALANCE);
    IF r.STG_COUNT = 3 AND r.TFM_ERROR_COUNT = 1
       AND r.FUSION_SUCCESS_COUNT = 2 AND r.FUSION_SUCCESS_AMOUNT = 2250
       AND r.VARIANCE_COUNT = 0 AND r.IN_BALANCE = 'Y' THEN
        DBMS_OUTPUT.PUT_LINE('PASS');
    ELSE
        RAISE_APPLICATION_ERROR(-20902, 'PO comparison did not balance');
    END IF;
END;
/
```

- [ ] **Step 2: Run it and confirm it fails**

Run the test. Expected: FAIL — `PLS-00201: identifier 'DMT_PO_COMPARE_PKG' must be declared`.

- [ ] **Step 3: Write the package spec**

`db/packages/dmt_po_compare_pkg.pks.sql`:
```sql
CREATE OR REPLACE PACKAGE DMT_PO_COMPARE_PKG AS
    -- Post-run comparison for Purchase Orders (standard). Returns one
    -- DMT_CMP_ROW_OBJ for the run: staged vs transform-errors vs live Fusion
    -- successes. Read-only; never queries Fusion by prefix.
    FUNCTION GET_COMPARISON(p_run_id IN NUMBER) RETURN DMT_CMP_ROW_OBJ;
END DMT_PO_COMPARE_PKG;
/
```

- [ ] **Step 4: Write the package body**

`db/packages/dmt_po_compare_pkg.pkb.sql`:
```sql
CREATE OR REPLACE PACKAGE BODY DMT_PO_COMPARE_PKG AS
    C_CEMLI CONSTANT VARCHAR2(30) := 'PurchaseOrders';

    FUNCTION GET_COMPARISON(p_run_id IN NUMBER) RETURN DMT_CMP_ROW_OBJ IS
        l_stg_cnt   NUMBER; l_stg_amt   NUMBER;
        l_err_cnt   NUMBER; l_err_amt   NUMBER;
        l_fus_cnt   NUMBER; l_fus_amt   NUMBER; l_ccy VARCHAR2(15);
        l_batch     VARCHAR2(4000);
        l_xml       XMLTYPE;
        l_err       NUMBER;
        l_key_type  VARCHAR2(20);
        l_money_ok  VARCHAR2(1) := 'Y';
        l_path      DMT_BIP_REPORT_TBL.CMP_REPORT_CATALOG_PATH%TYPE;
        l_bal       VARCHAR2(1);
        l_var_cnt   NUMBER; l_var_amt NUMBER;
    BEGIN
        -- (a) staged total for the run's standard-PO transform rows.
        --     amount rolls up from the line transform table (qty*unit_price).
        SELECT COUNT(*) INTO l_stg_cnt
          FROM DMT_PO_HEADERS_INT_TFM_TBL
         WHERE RUN_ID = p_run_id
           AND NVL(DOCUMENT_TYPE_CODE,'PO') = 'PO';   -- confirm value vs discovery/PurchaseOrders.md
        SELECT NVL(SUM(ln.QUANTITY * ln.UNIT_PRICE),0) INTO l_stg_amt
          FROM DMT_PO_LINES_INT_TFM_TBL ln
         WHERE ln.RUN_ID = p_run_id;

        -- (b) transform errors (real Fusion error captured).
        SELECT COUNT(*) INTO l_err_cnt
          FROM DMT_PO_HEADERS_INT_TFM_TBL
         WHERE RUN_ID = p_run_id
           AND NVL(DOCUMENT_TYPE_CODE,'PO') = 'PO'
           AND TFM_STATUS = 'FAILED';
        SELECT NVL(SUM(ln.QUANTITY * ln.UNIT_PRICE),0) INTO l_err_amt
          FROM DMT_PO_LINES_INT_TFM_TBL ln
          JOIN DMT_PO_HEADERS_INT_TFM_TBL h
            ON h.INTERFACE_HEADER_KEY = ln.INTERFACE_HEADER_KEY
         WHERE h.RUN_ID = p_run_id AND h.TFM_STATUS = 'FAILED';

        -- (c) batch id list = import ESS ids for this run's PO work-queue rows.
        SELECT LISTAGG(IMPORT_ESS_JOB_ID, ',') WITHIN GROUP (ORDER BY IMPORT_ESS_JOB_ID)
          INTO l_batch
          FROM DMT_WORK_QUEUE_TBL
         WHERE RUN_ID = p_run_id AND CEMLI_CODE = C_CEMLI
           AND IMPORT_ESS_JOB_ID IS NOT NULL;

        IF l_batch IS NULL THEN
            -- still in flight: no Fusion side yet.
            RETURN DMT_CMP_ROW_OBJ(C_CEMLI, C_CEMLI, 'NONE',
                l_stg_cnt, l_stg_amt, l_err_cnt, l_err_amt,
                NULL, NULL, NULL, l_money_ok, NULL, NULL, '?',
                'No import request id yet (in flight)');
        END IF;
        l_key_type := 'IMPORT_ID';

        -- (d) live Fusion aggregate.
        SELECT CMP_REPORT_CATALOG_PATH INTO l_path
          FROM DMT_BIP_REPORT_TBL WHERE CEMLI_CODE = C_CEMLI;
        DMT_UTIL_PKG.RUN_BIP_REPORT(
            p_run_id      => p_run_id,
            p_cemli_code  => C_CEMLI,
            p_params      => 'P_BATCH_ID|'||l_batch,
            x_report_xml  => l_xml,
            x_error_code  => l_err,
            p_report_path => l_path);
        -- (e) a fault must not read as zero successes.
        IF l_err <> 0 THEN
            RAISE_APPLICATION_ERROR(-20903,
                'PO comparison: BIP report error code '||l_err);
        END IF;
        IF l_xml IS NULL THEN
            l_fus_cnt := 0; l_fus_amt := 0;
        ELSE
            SELECT TO_NUMBER(x.success_count),
                   TO_NUMBER(x.success_amount),
                   x.amount_currency
              INTO l_fus_cnt, l_fus_amt, l_ccy
              FROM XMLTABLE('/DATA_DS/G_1' PASSING l_xml COLUMNS
                     success_count  VARCHAR2(40) PATH 'SUCCESS_COUNT',
                     success_amount VARCHAR2(40) PATH 'SUCCESS_AMOUNT',
                     amount_currency VARCHAR2(15) PATH 'AMOUNT_CURRENCY') x;
        END IF;

        -- (f) variance + balance; money variance only when money is available.
        l_var_cnt := l_stg_cnt - (NVL(l_fus_cnt,0) + l_err_cnt);
        l_var_amt := CASE WHEN l_money_ok = 'Y'
                          THEN l_stg_amt - (NVL(l_fus_amt,0) + l_err_amt) END;
        l_bal := CASE WHEN l_var_cnt = 0
                        AND (l_money_ok = 'N' OR l_var_amt = 0)
                      THEN 'Y' ELSE 'N' END;

        RETURN DMT_CMP_ROW_OBJ(C_CEMLI, C_CEMLI, l_key_type,
            l_stg_cnt, l_stg_amt, l_err_cnt, l_err_amt,
            l_fus_cnt, l_fus_amt, NVL(l_ccy,'USD'), l_money_ok,
            l_var_cnt, l_var_amt, l_bal, NULL);
    END GET_COMPARISON;
END DMT_PO_COMPARE_PKG;
/
```
Note for the implementer: confirm the standard-PO discriminator value (`'PO'` vs `'STANDARD'`) and the exact amount columns against `discovery/PurchaseOrders.md` and the run-132 data before finalizing; the proven queries there are authoritative.

- [ ] **Step 5: Register in install.sql and deploy**

Add `dmt_po_compare_pkg.pks.sql` then `.pkb.sql` to the packages section of `db/install.sql` (after `dmt_util_pkg` and the type). Deploy: `python scripts/dmt_deploy.py code db/packages/dmt_po_compare_pkg.pks.sql db/packages/dmt_po_compare_pkg.pkb.sql`.

- [ ] **Step 6: Deploy the BIP report to Fusion**

Deploy the Task-3 files with the project's BIP deploy path (`DMT_BIP_DEPLOY_PKG.DEPLOY_RECON_REPORT` with folder `/Custom/DMT2/PurchaseOrders`, dm `PO_CMP_DM`, rpt `PO_CMP_RPT`, or the existing `scripts/deploy_*_bip_reports.py` shim pointed at the two new files). Confirm they land under `/Custom/DMT2/PurchaseOrders/`.

- [ ] **Step 7: Run the test and confirm it passes**

Run `test/comparison/test_po_compare.sql`. Expected: PASS, printing `stg=3/2300 tfmerr=1/50 fus=2/2250 key=IMPORT_ID bal=Y`.

- [ ] **Step 8: Commit**

```bash
git add db/packages/dmt_po_compare_pkg.pks.sql db/packages/dmt_po_compare_pkg.pkb.sql db/install.sql test/comparison/test_po_compare.sql
git commit -m "feat(comparison): PurchaseOrders comparison function"
```

---

### Task 5: The framework — assemble a run's comparison grid

**Files:**
- Create: `db/packages/dmt_run_compare_pkg.pks.sql`, `.pkb.sql`
- Modify: `db/install.sql`
- Test: `test/comparison/test_run_compare.sql`

**Interfaces:**
- Consumes: `DMT_CMP_ROW_TAB`/`DMT_CMP_ROW_OBJ` (Task 1); `DMT_BIP_REPORT_TBL.CMP_FUNCTION` (Task 2); each object's `GET_COMPARISON` (Task 4 for PO).
- Produces: `DMT_RUN_COMPARE_PKG.GET_RUN_COMPARISON(p_run_id IN NUMBER, x_cursor OUT SYS_REFCURSOR)` — one row per object in the run that has a registered `CMP_FUNCTION`, ordered by object; plus `BUILD_ROWS(p_run_id) RETURN DMT_CMP_ROW_TAB` (the collection the cursor selects from).

Dispatch: for each distinct `CEMLI_CODE` in `DMT_WORK_QUEUE_TBL` for the run that has a non-null `CMP_FUNCTION`, dynamic-call the function into a `DMT_CMP_ROW_OBJ`. An object with no `CMP_FUNCTION` is skipped with a `DMT_LOG_TBL` note (never raised).

- [ ] **Step 1: Write the failing test**

`test/comparison/test_run_compare.sql`:
```sql
SET SERVEROUTPUT ON
DECLARE
    c   SYS_REFCURSOR;
    v   DMT_CMP_ROW_OBJ;
    n   NUMBER := 0;
    po_seen BOOLEAN := FALSE;
BEGIN
    DMT_RUN_COMPARE_PKG.GET_RUN_COMPARISON(132, c);
    LOOP
        FETCH c INTO v;  -- object-type cursor: one DMT_CMP_ROW_OBJ per row
        EXIT WHEN c%NOTFOUND;
        n := n + 1;
        IF v.CEMLI_CODE = 'PurchaseOrders' THEN
            po_seen := TRUE;
            IF v.IN_BALANCE <> 'Y' THEN
                RAISE_APPLICATION_ERROR(-20904,'PO not balanced in framework');
            END IF;
        END IF;
    END LOOP;
    CLOSE c;
    IF po_seen AND n >= 1 THEN DBMS_OUTPUT.PUT_LINE('PASS rows='||n);
    ELSE RAISE_APPLICATION_ERROR(-20905,'PO row missing from framework grid'); END IF;
END;
/
```

- [ ] **Step 2: Run it and confirm it fails**

Run the test. Expected: FAIL — `PLS-00201: identifier 'DMT_RUN_COMPARE_PKG' must be declared`.

- [ ] **Step 3: Write the spec**

`db/packages/dmt_run_compare_pkg.pks.sql`:
```sql
CREATE OR REPLACE PACKAGE DMT_RUN_COMPARE_PKG AS
    -- Live post-run comparison grid for one run. Enumerates the objects in the
    -- run, dispatches to each object's registered comparison function, and
    -- returns one DMT_CMP_ROW_OBJ per object. Read-only; no writes.
    FUNCTION BUILD_ROWS(p_run_id IN NUMBER) RETURN DMT_CMP_ROW_TAB;
    PROCEDURE GET_RUN_COMPARISON(p_run_id IN NUMBER, x_cursor OUT SYS_REFCURSOR);
END DMT_RUN_COMPARE_PKG;
/
```

- [ ] **Step 4: Write the body**

`db/packages/dmt_run_compare_pkg.pkb.sql`:
```sql
CREATE OR REPLACE PACKAGE BODY DMT_RUN_COMPARE_PKG AS
    C_PKG CONSTANT VARCHAR2(30) := 'DMT_RUN_COMPARE_PKG';

    FUNCTION BUILD_ROWS(p_run_id IN NUMBER) RETURN DMT_CMP_ROW_TAB IS
        l_out DMT_CMP_ROW_TAB := DMT_CMP_ROW_TAB();
        l_row DMT_CMP_ROW_OBJ;
    BEGIN
        FOR obj IN (
            SELECT DISTINCT r.CEMLI_CODE, r.CMP_FUNCTION
              FROM DMT_WORK_QUEUE_TBL wq
              JOIN DMT_BIP_REPORT_TBL r ON r.CEMLI_CODE = wq.CEMLI_CODE
             WHERE wq.RUN_ID = p_run_id
               AND r.CMP_FUNCTION IS NOT NULL
             ORDER BY r.CEMLI_CODE
        ) LOOP
            BEGIN
                EXECUTE IMMEDIATE
                    'BEGIN :r := '||obj.CMP_FUNCTION||'(:p); END;'
                    USING OUT l_row, IN p_run_id;
                l_out.EXTEND; l_out(l_out.LAST) := l_row;
            EXCEPTION WHEN OTHERS THEN
                DMT_LOG_TBL_PKG_OR_INLINE_LOG(p_run_id, obj.CEMLI_CODE, SQLERRM);
                -- skip a broken object; never fail the whole grid
                NULL;
            END;
        END LOOP;
        RETURN l_out;
    END BUILD_ROWS;

    PROCEDURE GET_RUN_COMPARISON(p_run_id IN NUMBER, x_cursor OUT SYS_REFCURSOR) IS
        l_rows DMT_CMP_ROW_TAB := BUILD_ROWS(p_run_id);
    BEGIN
        OPEN x_cursor FOR
            SELECT VALUE(t) FROM TABLE(l_rows) t;
    END GET_RUN_COMPARISON;
END DMT_RUN_COMPARE_PKG;
/
```
Implementer note: replace `DMT_LOG_TBL_PKG_OR_INLINE_LOG(...)` with the project's standard logging call (match how `DMT_UTIL_PKG` writes to `DMT_LOG_TBL` — same `p_run_id`, `p_procedure => C_PKG`, `p_message`). The catch-and-skip is what satisfies the "unregistered/broken object never crashes the grid" review-focus item.

- [ ] **Step 5: Register in install.sql and deploy**

Add both files to `db/install.sql` after `dmt_po_compare_pkg`. Deploy with `python scripts/dmt_deploy.py code db/packages/dmt_run_compare_pkg.pks.sql db/packages/dmt_run_compare_pkg.pkb.sql`.

- [ ] **Step 6: Run the test and confirm it passes**

Run `test/comparison/test_run_compare.sql`. Expected: PASS (at least the PurchaseOrders row present and balanced; other objects appear once their `CMP_FUNCTION` is registered in later plans).

- [ ] **Step 7: Commit**

```bash
git add db/packages/dmt_run_compare_pkg.pks.sql db/packages/dmt_run_compare_pkg.pkb.sql db/install.sql test/comparison/test_run_compare.sql
git commit -m "feat(comparison): run-level comparison framework + dispatch"
```

---

### Task 6: End-to-end verification against run 132

**Files:**
- Create: `test/comparison/verify_run132.sql` (assertion harness that mirrors the discovery numbers)

**Interfaces:**
- Consumes: `DMT_RUN_COMPARE_PKG.GET_RUN_COMPARISON`.

- [ ] **Step 1: Write the end-to-end assertion**

`test/comparison/verify_run132.sql` fetches the grid for run 132 and asserts the PurchaseOrders row equals the discovery-proven numbers (stg 3/2300, tfm-err 1/50, fusion 2/2250, in_balance Y, key IMPORT_ID). Reuse the fetch loop from Task 5's test; assert on the PO row's every field.

- [ ] **Step 2: Run it live (Docker + Fusion)**

Run: `python scripts/dmt_deploy.py run test/comparison/verify_run132.sql`.
Expected: PASS. This is the real gate — it proves the PO row reaches Fusion base tables and reconciles (satisfies the project rule that nothing counts until it reaches base tables).

- [ ] **Step 3: Commit**

```bash
git add test/comparison/verify_run132.sql
git commit -m "test(comparison): end-to-end verification of PO comparison on run 132"
```

---

### Task 7: APEX page — the comparison grid

**Files:**
- Modify: `apex/f501src/livedmt2/` — add page `p000NN-run-comparison.apx` and any shared item; export via the APEX CLI per `reference_apex_cli_workflow`.
- Test: HTTP assertion via the existing APEX drill pattern (below).

**Interfaces:**
- Consumes: `DMT_RUN_COMPARE_PKG.GET_RUN_COMPARISON`.

Approach: live data can't be a plain SQL region (it calls Fusion), so a page process populates an APEX collection, and the report region reads the collection. Copy-before-modify: copy app 501 to a new working app id, add the page there, verify, then fold back per the project's APEX workflow.

- [ ] **Step 1: Create the page item + process**

Add page item `P<NN>_RUN_ID` (a select list of recent runs from `DMT_PIPELINE_RUN_TBL`). Add a Before-Header PL/SQL process "Load comparison" that runs:
```sql
DECLARE
    c SYS_REFCURSOR; v DMT_CMP_ROW_OBJ; i NUMBER := 0;
BEGIN
    APEX_COLLECTION.CREATE_OR_TRUNCATE_COLLECTION('RUN_COMPARISON');
    IF :P<NN>_RUN_ID IS NOT NULL THEN
        DMT_RUN_COMPARE_PKG.GET_RUN_COMPARISON(:P<NN>_RUN_ID, c);
        LOOP
            FETCH c INTO v; EXIT WHEN c%NOTFOUND;
            APEX_COLLECTION.ADD_MEMBER('RUN_COMPARISON',
                p_c001 => v.OBJECT_TYPE, p_c002 => v.KEY_TYPE,
                p_n001 => v.STG_COUNT,  p_n002 => v.STG_AMOUNT,
                p_n003 => v.TFM_ERROR_COUNT, p_n004 => v.TFM_ERROR_AMOUNT,
                p_n005 => v.FUSION_SUCCESS_COUNT, p_n006 => v.FUSION_SUCCESS_AMOUNT,
                p_n007 => v.VARIANCE_COUNT, p_n008 => v.VARIANCE_AMOUNT,
                p_c003 => v.IN_BALANCE, p_c004 => v.FUSION_MONEY_AVAILABLE,
                p_c005 => v.AMOUNT_CURRENCY, p_c006 => v.NOTE);
        END LOOP;
        CLOSE c;
    END IF;
END;
```

- [ ] **Step 2: Create the report region**

Interactive report region source:
```sql
SELECT c001 AS object_type,
       n001 AS staged_count,   n002 AS staged_amount,
       n004 AS error_count,    n004 AS error_amount,
       n005 AS fusion_count,   n006 AS fusion_amount,
       n007 AS variance_count, n008 AS variance_amount,
       c003 AS in_balance,     c002 AS key_type, c006 AS note
  FROM APEX_COLLECTIONS
 WHERE COLLECTION_NAME = 'RUN_COMPARISON'
 ORDER BY object_type
```
Add a highlight condition: rows where `IN_BALANCE = 'N'` render in the warning colour. Add a totals row (report footer sum of the count/amount columns).

- [ ] **Step 3: Deploy the page to the working app copy and verify over HTTP**

Copy app 501 → working id (per `reference_apex_cli_workflow` / `feedback_apex_copy_before_modify`), import the page, and load it with `P<NN>_RUN_ID = 132`. Confirm the PurchaseOrders row shows staged 3, error 1, fusion 2, in-balance = Y. Use the same HTTP-assert approach the `dmt-regression-tester` uses for drill pages.

- [ ] **Step 4: Fold back and commit**

Once verified on the copy, apply to app 501 per the copy-before-modify rule, export, and commit:
```bash
git add apex/f501src/livedmt2/
git commit -m "feat(comparison): APEX run-comparison page on app 501"
```

---

## Self-Review

**Spec coverage:** Scope (single run) → Tasks 4–6. Two standard column shapes → Task 1 (comparison row) + Task 3 (Fusion aggregate output). Per-object contract/procedure → Task 4. Shared framework + dispatch → Task 5. Live-on-demand timing → Tasks 4/7 (no persistence). APEX page on 501 → Task 7. Discovery patterns (STG-via-TFM, batch-id list, money-availability flag, object-specific success) → Tasks 1/4. Rollout of the other 22 objects → explicitly deferred to follow-on plans (each adds a BIP aggregate report + a `GET_COMPARISON` + a registry seed row, mirroring Tasks 3–4). Not built here: the 4 zero-loaded objects' confirmation and persistence/prior-success (spec non-goals).

**Placeholder scan:** The one intentional implementer-fill is the standard log call in Task 5 Step 4 (named, with the exact pattern to copy) and the discriminator-value confirmation in Task 4 Step 4 (pointed at the authoritative discovery file) — both are verification instructions, not missing code.

**Type consistency:** `DMT_CMP_ROW_OBJ` constructor arg order in Tasks 1, 4, 5, and 7 matches the attribute list. `GET_COMPARISON(p_run_id) RETURN DMT_CMP_ROW_OBJ` and `GET_RUN_COMPARISON(p_run_id, x_cursor)` are used identically across tasks. `CMP_FUNCTION`/`CMP_REPORT_CATALOG_PATH` column names match Task 2.

**Review Focus:** in-flight (no request id) → Task 4 Step 4 + test; SOAP fault ≠ zero → Task 4 Step 4 (raise on `x_error_code`); multiple request ids → Task 4 `LISTAGG` + Task 3 IN-list bind; money absent/recomputed → Task 1 flag + Task 4 balance rule; unregistered/broken object → Task 5 catch-and-skip. All five are pinned to owning tasks.
