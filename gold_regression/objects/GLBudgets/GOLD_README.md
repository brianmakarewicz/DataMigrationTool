# GLBudgets — gold regression fixture

A standalone, reloadable FBDI fixture (4 good + 1 bad GL budget balance rows)
that loads directly into Oracle Fusion General Ledger via the ERP Integration
SOAP service, with read-only BIP verification against the budget base table and
the budget interface table. No DMT tool code, no DMT database, is in the load
path.

**Portable.** The ledger, budget name (Accounting Scenario), accounting period,
currency, and the account code combinations are all **discovered at load time**
by a read-only BIP query against the target pod — nothing is hardcoded and the
fixture never depends on data we loaded earlier. The good/bad rows are created
fresh (prefix-stamped Run Names); their ledger / budget / period / account
references are borrowed from what already exists on the pod.

## Why GL Budgets is different from every other FBDI object

1. **Two ESS steps, not one chained import.** `loadAndImportData` only loads the
   CSV into `GL_BUDGET_INTERFACE`. The validation/load into the budget cube is a
   **separate standalone ESS job, `ValidateAndLoadBudgets`, submitted once per
   distinct Run Name**, whose single parameter is that Run Name. The
   `ValidateAndLoadBudgets` chained by `loadAndImportData` gets no Run Name
   (`#NULL`) and errors harmlessly in ~1s — the real work is the standalone
   submissions.
2. **The base table is `GL_BUDGET_BALANCES`, not `GL_BALANCES`.** In Fusion
   Cloud, GL budget balances live in the Essbase balances cube; the relational
   `GL_BALANCES` table has zero budget rows. `GL_BUDGET_BALANCES` is the
   SQL-queryable projection of the cube and is the correct base-table proof.
3. **Budgets are cells, not transactions.** One row per
   `LEDGER + BUDGET_NAME + PERIOD + CONCAT_ACCOUNT + CURRENCY`. There is no
   per-source-line id and no prefix-bearing natural key in the base table. A
   successful load **overwrites** the cell and stamps a fresh `LAST_UPDATE_DATE`.
   So the good rows are verified by: the discovered accounts present for the
   discovered ledger/budget/period with `PERIOD_NET_DR = 1000` **and**
   `LAST_UPDATE_DATE` within the last 4 hours (this run).

## The one CSV (FBDI, no header row, position-based)

`GlBudgetInterface.csv` — 38 columns per the `glbudgetimport.ctl` order:
`RUN_NAME, STATUS, LEDGER_ID, BUDGET_NAME, PERIOD_NAME, CURRENCY_CODE,
SEGMENT1..SEGMENT30, BUDGET_AMOUNT, LEDGER_NAME`.

| Row | RUN_NAME | BUDGET_NAME | Account (SEG1-6) | Amount | Purpose |
|---|---|---|---|---|---|
| GOOD-1 | `${PREFIX}RT-GLBUD-G` | discovered (`Budget`) | discovered acct A | 1000 | valid → base cube |
| GOOD-2 | `${PREFIX}RT-GLBUD-G` | discovered | discovered acct B | 1000 | valid → base cube |
| GOOD-3 | `${PREFIX}RT-GLBUD-G` | discovered | discovered acct C | 1000 | valid → base cube |
| GOOD-4 | `${PREFIX}RT-GLBUD-G` | discovered | discovered acct D | 1000 | valid → base cube |
| BAD-1  | `${PREFIX}RT-GLBUD-B` | `RT NONEXISTENT BUDGET ${PREFIX}` | discovered acct A | 500 | rejected → interface |

The 4 good rows share **one** Run Name so a single `ValidateAndLoadBudgets`
submission loads them all. The bad row uses a **separate** Run Name so its
`ValidateAndLoadBudgets` submission errors independently and its row lingers in
`GL_BUDGET_INTERFACE` with a reportable error.

The bad row's budget name is a run-unique string that cannot be a valid
Accounting Scenario, so `ValidateAndLoadBudgets` rejects it deterministically
with **`You must specify a valid budget name.`** — a rejection reached at
validation, not a pre-load filter.

## Full ESS orchestration (jobs in order)

| # | Step | Endpoint / Operation | Job | ParameterList | Wait |
|---|---|---|---|---|---|
| 1 | Load CSV → interface | `{FUSION_URL}/fscmService/ErpIntegrationService` · `loadAndImportData` | `/oracle/apps/ess/financials/generalLedger/ledgers/ledgerDefinitions,ValidateAndLoadBudgets` | `#NULL` | poll `getESSJobStatus` to SUCCEEDED |
| 2 | Validate + load GOOD run name into cube | same endpoint · `submitESSJobRequest` | same job | **`${PREFIX}RT-GLBUD-G`** (single arg = Run Name) | poll to terminal (expect SUCCEEDED) |
| 3 | Validate BAD run name (expected to fail) | same endpoint · `submitESSJobRequest` | same job | **`${PREFIX}RT-GLBUD-B`** (single arg = Run Name) | poll to terminal (expect ERROR) |

- **Auth:** HTTP Basic, credential role `fin_impl` (connections.json).
- **UCM DocumentAccount:** `fin/budgetBalance/import`.
- **`interfaceDetails`:** `17` (the `generalLedgerBudgetBalance` row in
  `db/seed/dmt_erp_interface_options_tbl.sql`).
- **`notificationCode`:** `10`.
- Step 1's `job_name` stores the raw form with a `;` before the definition name;
  `loadAndImportData` needs the last `;` replaced by `,` (done in the recipe).
- Steps 2/3 are `submitESSJobRequest`: the harness splits the job path on the
  last `,` into `jobPackageName` + `jobDefinitionName`, and the single Run Name
  argument becomes one `paramList` element.

## Discovery (run before build, read-only BIP, credential role `fin_impl`)

One step, `GL_BUDGET_REF`. It picks the ledger/budget/currency combo that is
**most populated in `GL_BUDGET_BALANCES`** (the strongest signal that the combo
is loadable on this pod), its most-recent **Open** accounting period (via the
ledger's own period set), and four **real, distinct natural-account** values for
the anchor `SEGMENT1/SEGMENT2` prefix. All returned in one row:

Tokens stamped into the rows, the base read, and (implicitly) the Run Names:
`${LEDGER_ID}`, `${LEDGER_NAME}`, `${BUDGET_NAME}`, `${CURRENCY_CODE}`,
`${PERIOD_NAME}`, `${S1}`, `${S2}`, `${S4}`, `${S5}`, `${S6}`,
`${ACCT_A..ACCT_D}`.

```sql
SELECT * FROM (
  SELECT led.name LEDGER_NAME, ref.ledger_id LEDGER_ID, ref.budget_name BUDGET_NAME,
         ref.currency_code CURRENCY_CODE, per.period_name PERIOD_NAME,
         ref.segment1 S1, ref.segment2 S2, ref.segment4 S4, ref.segment5 S5, ref.segment6 S6,
         MAX(CASE WHEN acc.rn=1 THEN acc.acct3 END) ACCT_A,
         MAX(CASE WHEN acc.rn=2 THEN acc.acct3 END) ACCT_B,
         MAX(CASE WHEN acc.rn=3 THEN acc.acct3 END) ACCT_C,
         MAX(CASE WHEN acc.rn=4 THEN acc.acct3 END) ACCT_D
  FROM ( SELECT ledger_id, budget_name, currency_code, segment1, segment2, segment4, segment5, segment6
         FROM gl_budget_balances
         WHERE currency_code='USD' AND segment4='000' AND segment5='000' AND segment6='000'
         GROUP BY ledger_id, budget_name, currency_code, segment1, segment2, segment4, segment5, segment6
         ORDER BY COUNT(*) DESC FETCH FIRST 1 ROWS ONLY ) ref
  JOIN gl_ledgers led ON led.ledger_id = ref.ledger_id
  CROSS APPLY ( SELECT ps.period_name FROM gl_period_statuses ps
                JOIN gl_periods p ON p.period_set_name = led.period_set_name AND p.period_name = ps.period_name
                WHERE ps.ledger_id = ref.ledger_id AND ps.application_id = 101 AND ps.closing_status='O'
                ORDER BY p.end_date DESC FETCH FIRST 1 ROWS ONLY ) per
  CROSS APPLY ( SELECT acct3, ROW_NUMBER() OVER (ORDER BY acct3) rn FROM (
                  SELECT DISTINCT segment3 acct3 FROM gl_budget_balances
                  WHERE ledger_id=ref.ledger_id AND budget_name=ref.budget_name
                    AND segment1=ref.segment1 AND segment2=ref.segment2 )
                WHERE ROWNUM<=4 ) acc
  GROUP BY led.name, ref.ledger_id, ref.budget_name, ref.currency_code, per.period_name,
           ref.segment1, ref.segment2, ref.segment4, ref.segment5, ref.segment6
) WHERE ROWNUM=1
```

## Verification (read-only, via the BIP relay — direct single-table reads)

- **Good → base cube (`GL_BUDGET_BALANCES`).** Direct read scoped to the
  discovered ledger/budget/period/currency and the four discovered concat
  accounts, requiring `PERIOD_NET_DR = 1000` and `LAST_UPDATE_DATE` within the
  last 4 hours. Each of the four accounts present = pass. (The 4-hour window is
  the proven ATP↔Fusion `LAST_UPDATE_DATE` skew headroom; it scopes the read to
  this run and excludes months-old pre-existing budget cells for the same
  accounts.)

  ```sql
  SELECT bb.concat_account, bb.period_net_dr, bb.last_update_date
  FROM   gl_budget_balances bb
  WHERE  bb.ledger_id = <LEDGER_ID> AND bb.budget_name = '<BUDGET_NAME>'
  AND    bb.period_name = '<PERIOD_NAME>' AND bb.currency_code = '<CURRENCY_CODE>'
  AND    bb.concat_account IN (<4 discovered accounts>)
  AND    bb.period_net_dr = 1000
  AND    bb.last_update_date >= SYSDATE - INTERVAL '4' HOUR
  ```

- **Bad → interface + absent from base.** Direct read of `GL_BUDGET_INTERFACE`
  by the bad Run Name; the row is present with `STATUS = NEW/FAILED` and
  `ERROR_MESSAGE = 'You must specify a valid budget name.'`. Its account never
  reaches the base cube under this run (the base read finds only the four good
  accounts), so it is absent from base.

  ```sql
  SELECT i.run_name, i.status, i.error_message
  FROM   gl_budget_interface i
  WHERE  i.run_name = '<PREFIX>RT-GLBUD-B'
  ```

## How to run it

```bash
cd gold_regression/harness
python run_object.py GLBudgets --prefix <PREFIX>   # discover -> build -> load -> verify
# or step by step:
python discover.py GLBudgets
python build_artifact.py GLBudgets <PREFIX>
python load_fbdi.py GLBudgets ../objects/GLBudgets/GLBudgets_gold.zip
python verify.py GLBudgets <LOAD_REQUEST_ID> <PREFIX>
```

## Live evidence

**2026-07-19 — LIVE-PROVEN. PASS.**

Standalone load path only (no DMT database / code in the load path);
verification via the read-only BIP relay only.

| Field | Value |
|---|---|
| Date | 2026-07-19 |
| Prefix (kept in the gold zip) | `90231` |
| Load ESS request id (`loadAndImportData`) | `9763087` |
| Load terminal status | `SUCCEEDED` |
| `ValidateAndLoadBudgets` GOOD Run Name req | `9763103` → `SUCCEEDED` |
| `ValidateAndLoadBudgets` BAD Run Name req | `9763165` → `ERROR` |
| Discovered ledger / budget / period / currency | `US Primary Ledger` (`300000046975971`) / `Budget` / `07-26` / `USD` |
| Discovered accounts (good rows) | `101-10-{11102,11200,12101,12310}-000-000-000` |

A first proving run at prefix `90230` also passed identically (load `9763047`,
good `9763059` SUCCEEDED, bad `9763068` ERROR) — the fixture is reloadable on a
fresh prefix.

**Good rows → base cube `GL_BUDGET_BALANCES` (4/4)** — each account present with
`PERIOD_NET_DR = 1000`, `LAST_UPDATE_DATE` = this run:

| CONCAT_ACCOUNT | PERIOD_NET_DR |
|---|---|
| `101-10-11102-000-000-000` | 1000 |
| `101-10-11200-000-000-000` | 1000 |
| `101-10-12101-000-000-000` | 1000 |
| `101-10-12310-000-000-000` | 1000 |

**Bad row → interface, absent from base (1/1):**

| RUN_NAME | Error |
|---|---|
| `90231RT-GLBUD-B` | `You must specify a valid budget name.` (`GL_BUDGET_INTERFACE`) |

## Harness changes made for this object (contained, reusable)

- `load_fbdi.py` — downstream job ParameterLists are now stamped with
  `${PREFIX}`/`${GL_DATE}`/discovered tokens (previously only the main import
  ParameterList was). Needed so the per-Run-Name `ValidateAndLoadBudgets`
  submissions carry the prefixed Run Name.
- `verify.py` — the base/interface SQL and the good/bad keys now substitute
  discovered `${TOKEN}`s (previously only `${PREFIX}`). Needed for a
  cell-grained object whose base rows have no prefix-bearing key; the read is
  scoped to the exact discovered ledger/budget/period/accounts.
- `run_object.py` — passes the discovered `tokens` into `verify()`.

These are additive and backward-compatible; Suppliers / APInvoices / Workers are
unaffected.
