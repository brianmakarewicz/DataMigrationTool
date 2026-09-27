# GL Balances — Three-Source Reconciliation Discovery (RUN_ID 132)

Read-only proof for the DMT2 post-run comparison report. All numbers below come
from real queries run 2026-09-27: STG/TFM from the local Docker DMT DB
(`dmt_owner@//localhost:1523/FREEPDB1`), Fusion successes queried **live** from
the Fusion demo instance via `scripts/fusion_bip_query.py --cred fin_impl`.
Nothing was modified; no pipeline was run.

## Object / tables / grain

| Item | Value |
|---|---|
| CEMLI_CODE | `GLBalances` |
| STG table | `DMT_GL_INTERFACE_STG_TBL` (has **no** RUN_ID column) |
| TFM table | `DMT_GL_INTERFACE_TFM_TBL` (RUN_ID, TFM_STATUS, RECON_KEY, WORK_QUEUE_ID, FUSION_JE_HEADER_ID, GROUP_ID) |
| Fusion base tables | `gl_je_batches` -> `gl_je_headers` -> `gl_je_lines` (staged via `gl_interface`) |
| Import ESS job | JournalImportLauncher |
| Work item (run 132) | QUEUE_ID 843, WORK_STATUS DONE, LOAD_ESS 10023701, IMPORT_ESS 10023712 |
| Run header | RUN_ID 132, PREFIX 93212, RUN_STATUS COMPLETED_ERRORS |

**Grain: one record = one GL interface line = one `GL_JE_LINES` line.** GL "balances"
are loaded as journals; the DMT record grain is the journal *line*, not the header
and not the batch. Run 132 has 3 records = 3 journal lines across 2 journal headers:
a balanced 2-line journal (header 2477939, lines keyed 121/122) and an unbalanced
1-line journal (header 2477940, line keyed 123).

**STG rows are reached via the TFM join.** STG has no RUN_ID, so "this run's STG
rows" = the STG rows whose STG_SEQUENCE_ID is referenced by a run-132 TFM row.

## Chosen amount column(s) + rationale

Sum **ENTERED_DR / ENTERED_CR**. Reasoning:
- On this run `ACCOUNTED_DR/ACCOUNTED_CR` are NULL in STG and TFM (single-currency
  test data; accounted amounts were not staged), so accounted sums are meaningless
  on the DMT side. ENTERED amounts are the populated, comparable figures.
- GL reconciles a journal on its entered debit/credit balance; the DMT
  reconciliation itself keys SUCCESS/ERROR off header balance
  (`running_total_dr = running_total_cr`). Entered DR/CR is the natural money grain.
- A journal is two-sided, so for a balanced journal SUM(ENTERED_DR) and
  SUM(ENTERED_CR) are each reported; they are not added together. The headline
  "amount" for the balance check below is **SUM(ENTERED_DR)** (debits), with
  SUM(ENTERED_CR) shown alongside.

## STG query + result

```sql
SELECT COUNT(*) AS cnt,
       SUM(s.ENTERED_DR) AS sum_entered_dr,
       SUM(s.ENTERED_CR) AS sum_entered_cr
FROM   DMT_GL_INTERFACE_STG_TBL s
WHERE  s.STG_SEQUENCE_ID IN (
         SELECT t.STG_SEQUENCE_ID
         FROM   DMT_GL_INTERFACE_TFM_TBL t
         WHERE  t.RUN_ID = 132);
```

Result: **CNT = 3**, SUM_ENTERED_DR = **14999.99**, SUM_ENTERED_CR = **5000**.
(3 lines = 5000 DR + 5000 CR from the good journal, plus 9999.99 DR from the bad one.)

## TFM-error query + result

```sql
SELECT COUNT(*) AS cnt,
       SUM(ENTERED_DR) AS sum_entered_dr,
       SUM(ENTERED_CR) AS sum_entered_cr
FROM   DMT_GL_INTERFACE_TFM_TBL
WHERE  RUN_ID = 132 AND TFM_STATUS = 'FAILED';
```

Result: **CNT = 1**, SUM_ENTERED_DR = **9999.99**, SUM_ENTERED_CR = NULL (0).

Real ERROR_TEXT on that row (TFM_SEQUENCE_ID 123, RECON_KEY 123):
> `[FUSION_ERROR] [LINE] Journal imported (JE_HEADER_ID=2477940) but UNBALANCED: DR=9999.99 CR=0. Will not post.`

This is a genuine Fusion-derived rejection, not a fabricated verdict: the row
physically imported into `gl_je_lines`, but its header does not balance, so it
will not post and is honestly marked FAILED.

## Fusion success query + result (LIVE)

**Key path: `GL_JE_BATCHES.GROUP_ID = RUN_ID` (= 132).** This is the correct
tie-back key for GL — the pipeline stamps the DMT RUN_ID into the journal
GROUP_ID at transform time and it survives Journal Import into the base tables.
It is NOT the WORK_QUEUE_ID (843) and NOT the import ESS request id. (Confirmed
by inspecting the deployed recon data model `bip/GLBalances/DMT_GL_BAL_RECON_DM.xdm`,
whose BASE tier joins on `jb.group_id = :P_RUN_ID`.)

Key path summary: **WORK_QUEUE_ID (no) / LOAD_ID import-request (no) / GROUP_ID = RUN_ID (yes)**.
Round-trip proof: `GL_JE_LINES.REFERENCE_1` came back = TFM RECON_KEY (121/122/123)
and `REFERENCE_2` = `DMT:132:843:xxx` (the DMT:run:queue:tfm reference).

"Success" follows the DMT contract: a line is a Fusion success only if its journal
header is **balanced** (`running_total_dr = running_total_cr`) and therefore postable.

Live aggregate query (run via `fusion_bip_query.py --cred fin_impl`):

```sql
SELECT CASE WHEN jh.running_total_dr = jh.running_total_cr
            THEN 'SUCCESS' ELSE 'ERROR' END        AS fusion_status,
       COUNT(*)                                     AS line_count,
       SUM(NVL(jl.entered_dr,0))                    AS sum_entered_dr,
       SUM(NVL(jl.entered_cr,0))                    AS sum_entered_cr,
       SUM(NVL(jl.accounted_dr,0))                  AS sum_accounted_dr,
       SUM(NVL(jl.accounted_cr,0))                  AS sum_accounted_cr
FROM   gl_je_batches jb
JOIN   gl_je_headers jh ON jh.je_batch_id = jb.je_batch_id
JOIN   gl_je_lines   jl ON jl.je_header_id = jh.je_header_id
WHERE  jb.group_id = 132
GROUP  BY CASE WHEN jh.running_total_dr = jh.running_total_cr
               THEN 'SUCCESS' ELSE 'ERROR' END
ORDER  BY 1;
```

Live result from Fusion:

| FUSION_STATUS | LINE_COUNT | ENTERED_DR | ENTERED_CR | ACCOUNTED_DR | ACCOUNTED_CR |
|---|---|---|---|---|---|
| SUCCESS | 2 | 5000    | 5000 | 5000    | 5000 |
| ERROR   | 1 | 9999.99 | 0    | 9999.99 | 0    |

So **Fusion successes = 2 lines, SUM(ENTERED_DR) = 5000, SUM(ENTERED_CR) = 5000.**

Per-line detail confirmed live (same query without the GROUP BY): header 2477939
lines 1 & 2 are the balanced good journal (keys 122/121); header 2477940 line 1
is the unbalanced bad journal (key 123, DR 9999.99 / CR 0). Note: unlike most
interface tables, all three lines are physically present in the base table
`gl_je_lines`; GL success is decided by header balance, not by mere presence.

## Balance check

Contract: Fusion successes + TFM errors = STG total.

| Measure | Fusion success | TFM error | Sum | STG total | Result |
|---|---|---|---|---|---|
| Count (lines) | 2 | 1 | 3 | 3 | BALANCED |
| SUM(ENTERED_DR) | 5000 | 9999.99 | 14999.99 | 14999.99 | BALANCED |
| SUM(ENTERED_CR) | 5000 | 0 | 5000 | 5000 | BALANCED |

**BALANCED on all three measures — exact, zero variance.** TFM LOADED count (2) and
amount (DR 5000 / CR 5000) also match Fusion SUCCESS exactly, and the one TFM FAILED
line matches the one Fusion ERROR line.

## GL-specific gotchas

- **Grain is the journal line, and a good journal has two lines.** A simple "2 good
  records" is really 1 balanced journal of 2 lines. Do not compare journal-header
  counts to line counts. Debits and credits are separate columns; report both, never
  add DR+CR into one "amount".
- **Presence in `gl_je_lines` does NOT mean success for GL.** Every attempted line
  imported into the base table; success is decided by header balance
  (`running_total_dr = running_total_cr`). An unbalanced journal imports but will not
  post, so it is correctly FAILED even though its row exists. This is the opposite of
  interface tables where presence = failure.
- **Tie-back key is GROUP_ID = RUN_ID, not WORK_QUEUE_ID and not the import request id.**
  The RUN_ID is stamped into journal GROUP_ID and survives import. Keying a Fusion
  query on the prefix would be wrong.
- **ACCOUNTED amounts were NULL on the DMT side for this run** (single-currency test
  data), so reconcile on ENTERED amounts. In Fusion the accounted amounts happen to
  equal entered (same currency), but do not rely on accounted from STG/TFM here.
- Recon key round-trips through `GL_JE_LINES.REFERENCE_1` (= RECON_KEY) and
  `REFERENCE_2` (= `DMT:run:queue:tfm`); this requires the journal source to have
  "Import Journal References" ON.
```
