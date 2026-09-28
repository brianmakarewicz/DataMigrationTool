# GLBudgets — Three-Source Reconciliation Discovery (RUN_ID = 132)

**Verdict: BALANCED.** Fusion successes + TFM errors = STG total, confirmed with a live read
from the Fusion demo instance. Both LOADED cells exist in the Fusion base table
`GL_BUDGET_BALANCES` with the expected amounts; the one FAILED cell carries a real Fusion
rejection message.

| Source | Count | Money (budget amount) |
|---|---|---|
| STG total (staged for this run) | 3 | 2,500 |
| Fusion successes (LOADED, live in `GL_BUDGET_BALANCES`) | 2 | 2,000 |
| TFM errors (FAILED, real Fusion error) | 1 | 500 |
| **Fusion successes + TFM errors** | **3** | **2,500** |
| **Variance vs STG** | **0** | **0** |

Run context: RUN_ID 132, prefix **93212**, scenario `RegressionTest2609231157`, run_mode ALL,
run_status `COMPLETED_ERRORS` (overall run has other objects' errors; GLBudgets queue 844 = DONE).
GLBudgets ran 2026-09-25 17:49–17:57.

---

## Object / tables / grain

- **CEMLI:** `GLBudgets` (object folder is singular `objects/GLBudget/`; BIP folder is `bip/GLBudgets/`).
- **STG:** `DMT_GL_BUDGET_INT_STG_TBL`
- **TFM:** `DMT_GL_BUDGET_INT_TFM_TBL` (status column is `TFM_STATUS`; error column `ERROR_TEXT`)
- **Fusion interface table:** `GL_BUDGET_INTERFACE` (FAILED rows linger here; SUCCESS rows are consumed/deleted)
- **Fusion base table:** `GL_BUDGET_BALANCES` (SQL-queryable via BIP `ApplicationDB_FSCM`).
  `GL_BALANCES` has **zero** budget rows on this instance — do NOT reconcile GL Budgets there.
- **Grain: a budget CELL, not a transaction.** One row per
  `LEDGER_ID + BUDGET_NAME + PERIOD_NAME + CURRENCY_CODE + SEGMENT1..30`. There is no
  per-source-line id, run id, request id, or prefix on a budget cell.
- **ESS process:** Load Interface File for Import (`InterfaceLoaderController`) then, per distinct
  Run Name, the standalone `ValidateAndLoadBudgets` job (child `LoadBudgets`).

### Amount column + rationale

Money = **`BUDGET_AMOUNT`** (the FBDI "Budget Amount", CSV position 37). This is the single amount
a source line carries; positive = debit, negative = credit. It lands in `GL_BUDGET_BALANCES` as
`PERIOD_NET_DR` (positive) / `PERIOD_NET_CR` (negative). "Entered vs period amount" does not apply
to GL budgets — a budget line has exactly one amount, posted to one period cell. The live
`PERIOD_NET_DR` of each loaded cell (1000) equals the staged `BUDGET_AMOUNT` (1000), so amount
round-trips exactly.

---

## STG query + result

STG has no RUN_ID. The run's staged record set = the STG rows feeding this run's TFM rows, joined
on `STG_SEQUENCE_ID`.

```sql
SELECT COUNT(*) AS stg_cnt, SUM(s.budget_amount) AS stg_money
FROM   dmt_gl_budget_int_stg_tbl s
WHERE  s.stg_sequence_id IN (
         SELECT stg_sequence_id FROM dmt_gl_budget_int_tfm_tbl WHERE run_id = 132
       );
```

Result: **STG_CNT = 3, STG_MONEY = 2500.**

---

## TFM-error query + result (real ERROR_TEXT)

```sql
SELECT tfm_status, COUNT(*) AS cnt, SUM(budget_amount) AS money
FROM   dmt_gl_budget_int_tfm_tbl
WHERE  run_id = 132
GROUP  BY tfm_status;
-- FAILED  1  500
-- LOADED  2  2000

SELECT tfm_sequence_id, run_name, budget_name, period_name, budget_amount, error_text
FROM   dmt_gl_budget_int_tfm_tbl
WHERE  run_id = 132 AND tfm_status = 'FAILED';
```

Result — 1 FAILED row, $500, with a **real Fusion error**:

| tfm_seq | run_name | budget_name | period | amount | error_text |
|---|---|---|---|---|---|
| 100000107 | Budget_EO_BAD | NONEXISTENT BUDGET | 06-26 | 500 | `[FUSION_ERROR] [LINE] You must specify a valid budget name.;` |

---

## Fusion success query + result (LIVE, key path)

The two LOADED cells were confirmed present in `GL_BUDGET_BALANCES` on the live demo instance via
`scripts/fusion_bip_query.py --cred fin_impl` (data source `ApplicationDB_FSCM`).

**Run-scoping key path (how a budget cell is tied back to this run):**
1. A budget cell carries no run id / request id / prefix. It is scoped to this run by a
   `LAST_UPDATE_DATE >= PROCESSSTART` window, where PROCESSSTART is the start of this run's
   **successful** `ValidateAndLoadBudgets` ESS job.
2. For RUN 132 the good Run Name `Budget_EO_1` mapped to ESS request **10023741**
   (`ValidateAndLoadBudgets`, STATE 12 SUCCEEDED, start 2026-09-25 17:53:06; child `LoadBudgets`
   10023751 SUCCEEDED). The bad Run Name `Budget_EO_BAD` mapped to ESS request **10023773**
   (STATE 10 ERROR). ESS ids come from `DMT_ESS_JOB_TBL` (RUN_ID=132, CEMLI_CODE='GLBudgets').
3. **FUSION_ID for a loaded cell = `GL_CODE_COMBINATIONS.CODE_COMBINATION_ID`** — the GL account
   the cell sits on, resolved by joining all 30 segments through the ledger's chart of accounts.
   (`GL_BUDGET_VERSIONS` is VPD-blocked, so the account CCID is the honest non-null base-table id.)

```sql
SELECT bb.ledger_id, bb.budget_name, bb.period_name,
       bb.segment1||'-'||bb.segment2||'-'||bb.segment3||'-'||bb.segment4||'-'||bb.segment5||'-'||bb.segment6 AS acct,
       bb.period_net_dr, bb.period_net_cr, gcc.code_combination_id AS ccid,
       TO_CHAR(bb.last_update_date,'YYYY-MM-DD HH24:MI:SS') AS lud
FROM   gl_budget_balances bb
JOIN   gl_ledgers led            ON led.ledger_id = bb.ledger_id
JOIN   gl_code_combinations gcc  ON gcc.chart_of_accounts_id = led.chart_of_accounts_id
                                AND gcc.segment1 = bb.segment1 AND gcc.segment2 = bb.segment2
                                AND gcc.segment3 = bb.segment3 AND gcc.segment4 = bb.segment4
                                AND gcc.segment5 = bb.segment5 AND gcc.segment6 = bb.segment6
WHERE  bb.ledger_id = 300000046975971
AND    bb.budget_name = 'Budget'
AND    bb.period_name = '06-26'
AND    bb.currency_code = 'USD'
AND    bb.segment3 IN ('77600','60540');
```

Live result (2 cells, DR = 1000 each, LUD 17:54:10 — inside the run window that opened 17:53:06):

| acct | period_net_dr | ccid | last_update_date |
|---|---|---|---|
| 101-10-77600-120-000-000 | 1000 | 300000047301444 | 2026-09-25 17:54:10 |
| 101-10-60540-120-000-000 | 1000 | 300000047301445 | 2026-09-25 17:54:10 |

**These live CCIDs (…444 / …445) exactly match the values DMT stored per LOADED TFM row.** See
gotcha #1 about the column name.

**FAILED cell confirmed live too** — `GL_BUDGET_INTERFACE`, scoped to this run's load request
(load_request_id = **10023731**, the run's `InterfaceLoaderController`):

```sql
SELECT run_name, budget_name, status, error_message, load_request_id
FROM   gl_budget_interface
WHERE  run_name = 'Budget_EO_BAD' AND status = 'FAILED'
AND    load_request_id = 10023731;
-- Budget_EO_BAD | NONEXISTENT BUDGET | FAILED | You must specify a valid budget name.; | 10023731
```

(Many other `Budget_EO_BAD` FAILED rows persist in the interface from earlier runs — failed
interface rows are never consumed. The `load_request_id` filter isolates RUN 132's row, exactly as
the Contract-v1 query does via `:P_LOAD_REQUEST_ID`.)

---

## Balance check

```
STG total                     = 3 records / 2,500
Fusion successes (LOADED live) = 2 records / 2,000   (GL_BUDGET_BALANCES cells, run-window scoped)
TFM errors (FAILED)           = 1 record  /   500   (GL_BUDGET_INTERFACE, real Fusion error)
successes + errors            = 3 records / 2,500
variance vs STG               = 0 / 0                → BALANCED
```

Unlike the memory flag warning, the LOADED rows for RUN 132 **do** appear in Fusion with the
correct amounts. No forced balance — every count and dollar is backed by a live Fusion read.

---

## Gotchas

1. **`FUSION_BUDGET_VERSION_ID` is a misnomer.** The TFM column named `FUSION_BUDGET_VERSION_ID`
   (also surfaced as `FUSION_ID` in `DMT_RUN_RECORDS_V`) actually stores the **CODE_COMBINATION_ID**
   of the loaded cell, not a budget version id. The stored values (300000047301444 / …445) match
   `GL_CODE_COMBINATIONS.CODE_COMBINATION_ID` live. This agrees with the Contract-v1 query in
   `bip/GLBudgets/query.sql`, which defines FUSION_ID = CCID. The real `GL_BUDGET_VERSIONS` table is
   VPD-blocked (ORA-00942 on live SELECT), so a true version id is unreachable — the account CCID is
   the deliberate, honest substitute. Do not read the column name literally.

2. **Reconcile against `GL_BUDGET_BALANCES`, never `GL_BALANCES`.** `GL_BALANCES` has zero budget
   rows (actual_flag='B') on this instance. GL budget balances live in the Essbase cube; the
   relational `GL_BUDGET_BALANCES` is the SQL-queryable projection and the only base-table read that
   works.

3. **OTBI cube path returns NULL amounts for all users** (headless SOAP sessions don't initialize GL
   data-access-set security), and the BI-Server logical-SQL data source is not provisioned in this
   SaaS pod. `GL_BUDGET_BALANCES` via `ApplicationDB_FSCM` is the working avenue — do not chase OTBI.

4. **SUCCESS consumes interface rows; FAILURE leaves them.** A successfully loaded cell has no
   surviving `GL_BUDGET_INTERFACE` footprint, so LOADED confirmation must come from
   `GL_BUDGET_BALANCES` (cell present + `LAST_UPDATE_DATE >= job PROCESSSTART`). FAILED confirmation
   comes from the lingering interface row + its `ERROR_MESSAGE`.

5. **Run scoping is a time window, not an id.** Because a cell carries no run/request/prefix, LOADED
   scoping relies on the successful `ValidateAndLoadBudgets` job's PROCESSSTART (from
   `FUSION.ESS_REQUEST_HISTORY` in the Contract-v1 query; from `DMT_ESS_JOB_TBL.START_TIME`
   locally). If the import ESS id does not resolve, the window is NULL and BASE selects nothing —
   never the whole cube. Watch the ATP↔Fusion timezone skew on `LAST_UPDATE_DATE`.

6. **Cell grain collapses colliding source lines.** Two staged lines that share the full cell key
   cannot exist as two cube rows — Fusion overwrites/sums. Dedup to the cell key before load and fan
   the cube outcome back to each source line. RUN 132 had no collisions (3 distinct cells).

7. **Standalone per-Run-Name submission is mandatory.** The old bug submitted only step 1 and let
   the chained validate run with a NULL Run Name (errored in ~1s). The correct flow submits
   `ValidateAndLoadBudgets` once per distinct Run Name. RUN 132 did this: `Budget_EO_1` → 10023741
   SUCCEEDED, `Budget_EO_BAD` → 10023773 ERROR.

---

## Production key resolution

**Verdict: FALLBACK-TO-CAPTURED-IDS — a loaded budget cell carries NO batch key.**
No load/import ESS request id, no batch id, and no source reference round-trips onto a loaded
cell. The production-valid key is the exact **CODE_COMBINATION_ID list DMT already captured on the
LOADED TFM rows** (stored, misleadingly, in `FUSION_BUDGET_VERSION_ID`) plus the **budget name**,
with **no time window**. Proven live below.

### Why no batch key exists (proven live)

1. **The loaded cell has no batch/request column at all.** Live column scan of the base table:
   ```sql
   SELECT column_name FROM all_tab_columns
   WHERE  table_name = 'GL_BUDGET_BALANCES'
   AND    (column_name LIKE '%REQUEST%' OR column_name LIKE '%BATCH%'
        OR column_name LIKE '%LOAD%'    OR column_name LIKE '%SOURCE%'
        OR column_name LIKE '%GROUP%'   OR column_name LIKE '%VERSION%');
   ```
   Live result: the ONLY match is `OBJECT_VERSION_NUMBER` (an optimistic-lock counter, not a load
   batch). There is no `REQUEST_ID`, `BATCH_ID`, `LOAD_REQUEST_ID`, `SOURCE`, or `GROUP_ID` on a
   loaded cell. Nothing ties a base-table cell back to the ESS request that created it.

2. **The interface request id does NOT survive to the cell.** The load's ESS request ids live only
   in `DMT_ESS_JOB_TBL` (RUN_ID=132, CEMLI_CODE='GLBudgets'): `InterfaceLoaderController` 10023731,
   `ValidateAndLoadBudgets` 10023741 (good) / 10023773 (bad), `LoadBudgets` 10023751. The work-queue
   row (queue 844) stores NO ESS ids either (`LOAD_ESS_JOB_ID`/`IMPORT_ESS_JOB_ID` are NULL — they
   are recorded in `DMT_ESS_JOB_TBL`, not on the queue). `GL_BUDGET_INTERFACE` carries
   `LOAD_REQUEST_ID`, but on a **successful** load the import consumes/deletes those interface rows —
   so `LOAD_REQUEST_ID` survives only for FAILED cells, never for a loaded one. It cannot be a
   success key.

3. **No stamped reference round-trips.** Budget name, period, segments, ledger and currency all
   round-trip (they ARE the cell key), but none is a per-run/per-batch stamp — the same
   `budget_name='Budget'` cell key is reused every run. There is no DFF or source-reference carrier
   on a budget cell.

### The production key (captured CODE_COMBINATION_ID list + budget name, no time window)

DMT already stored, on each LOADED TFM row, the exact `CODE_COMBINATION_ID` of the cell it created
(column `FUSION_BUDGET_VERSION_ID` — a misnomer; see gotcha #1). For RUN 132 those are
**300000047301444** and **300000047301445**. Selecting `GL_BUDGET_BALANCES` by that captured CCID
list plus the budget name resolves each cell to a single base-table row without any
`LAST_UPDATE_DATE` window.

```sql
-- Captured on LOADED TFM rows (local DMT DB):
--   SELECT fusion_budget_version_id FROM dmt_gl_budget_int_tfm_tbl
--   WHERE run_id = 132 AND tfm_status = 'LOADED';   -> 300000047301444, 300000047301445
SELECT COUNT(*)                                  AS cnt,
       SUM(bb.period_net_dr - bb.period_net_cr)  AS money
FROM   gl_budget_balances bb
JOIN   gl_ledgers led            ON led.ledger_id = bb.ledger_id
JOIN   gl_code_combinations gcc  ON gcc.chart_of_accounts_id = led.chart_of_accounts_id
                                AND NVL(gcc.segment1,'#') = NVL(bb.segment1,'#')
                                AND NVL(gcc.segment2,'#') = NVL(bb.segment2,'#')
                                AND NVL(gcc.segment3,'#') = NVL(bb.segment3,'#')
                                AND NVL(gcc.segment4,'#') = NVL(bb.segment4,'#')
                                AND NVL(gcc.segment5,'#') = NVL(bb.segment5,'#')
                                AND NVL(gcc.segment6,'#') = NVL(bb.segment6,'#')
WHERE  bb.budget_name = 'Budget'
AND    gcc.code_combination_id IN (300000047301444, 300000047301445);
```

**Live result (no time window): CNT = 2, MONEY = 2000.** Per-cell breakdown confirms both are
period 06-26, DR 1000 each, and no other period collides under budget name `Budget`:

| ccid | period | seg3 | period_net_dr | period_net_cr |
|---|---|---|---|---|
| 300000047301444 | 06-26 | 77600 | 1000 | 0 |
| 300000047301445 | 06-26 | 60540 | 1000 | 0 |

This is the production-valid replacement for the earlier `LAST_UPDATE_DATE >= validate-start`
window. It returns exactly the run's two loaded cells and sums `BUDGET_AMOUNT` to 2000 using only
keys DMT itself captured, with no reliance on wall-clock timing or ATP↔Fusion clock skew.

**Production hardening note.** A CCID uniquely identifies a GL account, so `CCID + budget_name`
already resolved to one period cell here. For a run that loads the same account across multiple
periods, add the captured `period_name` list (also on the TFM row) to the key so each captured cell
maps to exactly one base-table row. The full captured cell key on the TFM row is
`ledger_id + budget_name + period_name + currency_code + segment1..30`; the CCID collapses the 30
segments to one id, so `CCID + budget_name + period_name (+ ledger_id + currency_code)` is the
complete, time-window-free production key.

---

## Evidence / reproduction

- Local DMT DB: `oracledb.connect(user='dmt_owner', password='DmtLocal#2026', dsn='//localhost:1523/FREEPDB1')`
- Live Fusion: `python scripts/fusion_bip_query.py --cred fin_impl` (source `ApplicationDB_FSCM`)
- ESS ids: `SELECT request_id, job_short_name, state, state_text, start_time FROM dmt_ess_job_tbl
  WHERE run_id=132 AND cemli_code='GLBudgets'` → InterfaceLoaderController 10023731 (SUCCEEDED),
  ValidateAndLoadBudgets 10023741 (SUCCEEDED, Budget_EO_1), 10023773 (ERROR, Budget_EO_BAD).
- Contract-v1 model: `bip/GLBudgets/GL_BUDGET_DM.xdm` + `bip/GLBudgets/query.sql`
  (9-column contract, params P_RUN_ID, P_LOAD_REQUEST_ID, P_IMPORT_ESS_ID, P_PREFIX, P_CHUNK_SIZE,
  P_AFTER_KEY).
