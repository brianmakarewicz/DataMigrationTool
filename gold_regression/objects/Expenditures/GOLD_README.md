# Expenditures — Gold Regression Fixture

Import Project Costs (unprocessed project cost transactions) via FBDI. Standalone load
path: the harness assembles the FBDI zip, discovers all references live on the target pod,
calls the Fusion ERP Integration SOAP service directly, polls to terminal, and verifies with
read-only single-table BIP reads. No DMT database or DMT pipeline code is in the load path.

## What this object loads

A project cost transaction is an *unprocessed transaction* that references data that already
exists on the pod: an existing **project + task** open for costing, a valid **expenditure
type**, an **expenditure organization**, and a **transaction source document / document
entry**. We create NEW transactions (stamped with a fresh numeric prefix on the transaction
reference) but every reference inside them is discovered from the target pod at load time
(portability rules 6–8). We never create a project first and never reference our own earlier
loads.

- **FBDI member:** `PjcTxnXfaceStageAll.csv` (positional, no header row).

### CTL discriminator — the layout is NOT the metadata-seed 103 columns

The SQL*Loader control file `PjcTxnXfaceStageAll.ctl` has FIVE `INTO TABLE` branches, each
selected by the FIRST field (`TRANSACTION`, a FILLER discriminator): `LABOR`, `NONLABOR`, and
three more. Each branch has a DIFFERENT column layout. A row whose first field does not match a
branch value, or whose field count does not match that branch, is discarded — the load job then
errors (`DeleteOnLoadFailure=Y`) and ZERO rows reach the interface table. This fixture uses the
**NONLABOR** branch (107 positional fields), whose layout differs from the DMT
`dmt_upload_fbdi_metadata.sql` 103-column list by inserting four resource fields
(`NON_LABOR_RESOURCE`, `NON_LABOR_RESOURCE_ID`, `NON_LABOR_RESOURCE_ORG`,
`NON_LABOR_RESOURCE_ORG_ID`) right after `ORGANIZATION_ID` (positions 29–32). The authoritative
layout was read from the live load log via `downloadESSJobExecutionDetails` (member
`<loadReqId>.log`). Populated NONLABOR positions: 1=NONLABOR, 2=BUSINESS_UNIT,
4=USER_TRANSACTION_SOURCE, 6=DOCUMENT_NAME, 8=DOC_ENTRY_NAME, 13=EXPENDITURE_ITEM_DATE,
19=PROJECT_NUMBER, 22=TASK_NUMBER, 25=EXPENDITURE_TYPE, 27=ORGANIZATION_NAME, 33=QUANTITY,
35=UNIT_OF_MEASURE, 38=BILLABLE_FLAG, 40=ORIG_TRANSACTION_REFERENCE, 44=GL_DATE,
45=DENOM_CURRENCY_CODE, 47=DENOM_RAW_COST.
- **Interface (staging) table:** `PJC_TXN_XFACE_ALL` (the DMT-side name `PJC_TXN_XFACE_STAGE_ALL`
  resolves to the same rows). Natural key we stamp: `ORIG_TRANSACTION_REFERENCE`.
- **Base table (success):** `PJC_EXP_ITEMS_ALL` — a row here with a real `EXPENDITURE_ITEM_ID`
  and `ORIG_TRANSACTION_REFERENCE = <prefix>RT-EXP-G*` is the pass bar. Cost distributions
  land in `PJC_COST_DIST_LINES_ALL`.

## ESS orchestration (in order)

This is a **two-step** load (like GL Budgets), not one call:

1. `loadAndImportData` base64-uploads the zip to UCM and runs "Load File to Interface Tables"
   (SQL*Loader), which unpacks `PjcTxnXfaceStageAll.csv` into the staging table
   `PJC_TXN_XFACE_STAGE_ALL`. Every loaded row gets `TRANSACTION_STATUS_CODE='P'` (pending). On
   this product the load call does NOT actually run the costing import — the rows sit at `P`.
2. A SEPARATE `submitESSJobRequest` for **Import and Process Cost Transactions**
   (`onestop,ImportAndProcessTxnsJob`) picks up the pending rows, validates and costs them:
   accepted rows move to base `PJC_EXP_ITEMS_ALL`; rejected rows are removed from staging (they
   are NOT retained at status `R` on this pod).

| Step | Program | Notes |
|---|---|---|
| 1. Load File to Interface Tables | `loadAndImportData` | Endpoint `<fusion>/fscmService/ErpIntegrationService`, HTTP Basic `fin_impl`, `interfaceDetails=20`, doc account `prj/projectCosting/import`. Rows → `PJC_TXN_XFACE_STAGE_ALL`, status `P`. |
| 2. Import and Process Cost Transactions | `submitESSJobRequest` on `/oracle/apps/ess/projects/costing/transactions/onestop,ImportAndProcessTxnsJob` | Validates + costs. Accepted → `PJC_EXP_ITEMS_ALL`; rejected → removed from staging. Poll to terminal. |

**USE `ImportAndProcessTxnsJob`, NOT `ImportProcessParallelEssJob` (the ORA-06502 fix).** The
prior fixture called the *parallel* job `onestop,ImportProcessParallelEssJob` (shadow proc
`pjc_import_and_process.onestop_parallel_ess`, a 13-arg form). That job crashes immediately with
`ORA-06502: character to number conversion error` in its own parameter-parsing PL/SQL, every time,
on this pod — confirmed across ~20 historical runs in the ESS request history (all state 10 =
ERROR). The job that actually SUCCEEDS is the non-parallel `onestop,ImportAndProcessTxnsJob`
(shadow proc `pjc_import_and_process.import_and_process_ess`, a 10-arg form). The working positional
order was read from two SUCCEEDED runs (request ids 9719834 and 9719348) via
`FUSION.ESS_REQUEST_PROPERTY` (rows `submit.argument1`..`submit.argument10`), then cross-referenced
to the shadow proc signature in `ALL_ARGUMENTS`. The old recipe crashed because it put a
non-numeric value (the BU name and/or the process date) into a numeric argument slot.

Poll `getESSJobStatus` on each request id every 60 s until terminal (SUCCEEDED / WARNING /
FAILED / ERROR / EXPIRED). WARNING is normal when some rows reject.

- **SOAP endpoint:** `<fusion_url>/fscmService/ErpIntegrationService`
- **Auth user / role:** `fin_impl` (HTTP Basic)
- **Document account (UCM):** `prj/projectCosting/import`
- **interfaceDetails id:** `20`
- **Import job (comma form):** `/oracle/apps/ess/projects/costing/transactions/onestop,ImportAndProcessTxnsJob`

### Full ParameterList (10 positions) — Import and Process Cost Transactions

Delimited by `~` in the `submitESSJobRequest` paramList (one element per position). Each position
maps to a real argument of `PJC_IMPORT_AND_PROCESS.IMPORT_AND_PROCESS_ESS`:

```
IMPORT_AND_PROCESS~${BU_ID}~ALL~#NULL~#NULL~${TXN_SOURCE_ID}~${DOCUMENT_ID}~#NULL~#NULL~#NULL
```

| Pos | Proc arg | Value | Meaning |
|---|---|---|---|
| 1 | `P_MODE` | `IMPORT_AND_PROCESS` | Import then cost the transactions |
| 2 | `P_BU_ID` | `${BU_ID}` (numeric, e.g. `300000046987012`) | Business unit **id** (numeric — never the name) |
| 3 | `P_TXN_STATUS` | `ALL` | Transaction status filter |
| 4 | `P_BATCH_NAME` | `#NULL` | Batch-name **filter**. Leave `#NULL` so all pending rows for the BU are selected. Passing a value here filters to rows whose `BATCH_NAME` column equals it. |
| 5 | `P_INTERFACE_ID` | `#NULL` | Unused |
| 6 | `P_TXN_SOURCE_ID` | `${TXN_SOURCE_ID}` (numeric id of `External Miscellaneous`) | Transaction source **id** (numeric) |
| 7 | `P_DOCUMENT_ID` | `${DOCUMENT_ID}` (numeric id of `Miscellaneous`) | Document **id** (numeric) |
| 8 | `P_START_PROJECT_NO` | `#NULL` | Project range start — unused |
| 9 | `P_END_PROJECT_NO` | `#NULL` | Project range end — unused |
| 10 | `P_PROCESS_THROUGH_DATE` | `#NULL` | Process-through date — unused |

**The unique-batch-name gotcha (the other blocker).** Import Costs validates that each
transaction's batch name is unique (`MESSAGE_NAME=PJC_UNIQUE_BATCH_NAME`). If the interface rows
carry an EMPTY `BATCH_NAME`, the good rows collide with each other (and across prefixes) and are
ALL rejected on `PJC_UNIQUE_BATCH_NAME` — even though their expenditure types are valid. Fix: the
FBDI stamps a per-row unique batch into `BATCH_NAME` (NONLABOR **CSV position 10**), set to the
same value as `ORIG_TRANSACTION_REFERENCE` (`${PREFIX}RT-EXP-G1` etc.). BATCH_NAME position was
read from the live SQL*Loader control-file log (`downloadESSJobExecutionDetails` on the load
request, member `<loadReqId>.log`): in the NONLABOR branch the order is
`TRANSACTION_TYPE(1) BUSINESS_UNIT(2) ORG_ID(3) USER_TRANSACTION_SOURCE(4) TRANSACTION_SOURCE_ID(5)
DOCUMENT_NAME(6) DOCUMENT_ID(7) DOC_ENTRY_NAME(8) DOC_ENTRY_ID(9) BATCH_NAME(10) …`.

## Load-time discovery (read-only BIP, portability rule 7)

All three steps run against the TARGET pod before the artifact is built:

1. **EXP_PROJECT_TASK_REF** — one real, already-posted PJ (non-labor) cost row on the US1
   business unit, giving a project + task that is demonstrably chargeable for costing plus a
   valid expenditure type, expenditure organization, UOM and an open expenditure-item date:
   `pjc_exp_items_all` joined to `pjf_projects_all_vl` / `pjf_proj_elements_vl`, filtered to
   `system_linkage_function='PJ'`, `org_id=300000046987012`, expenditure type in
   (Meals, Airfare, Hotel, Miscellaneous). Binds → `${PROJECT_NUMBER} ${TASK_NUMBER}
   ${EXP_TYPE} ${EXP_ORG} ${BU_NAME} ${BU_ID} ${UOM} ${EI_DATE}`.
2. **EXP_TXN_SOURCE** — the third-party import transaction source and its document / document
   entry, returning BOTH the names (for the CSV) AND the numeric ids (for the ParameterList):
   `pjf_txn_sources_vl` → `pjf_txn_document_b` → `pjf_txn_document_vl` /
   `pjf_txn_doc_entry_vl (system_linkage_function='PJ')` filtered to
   `user_transaction_source='External Miscellaneous'`. Binds → `${TXN_SOURCE}='External
   Miscellaneous' ${TXN_SOURCE_ID}=300000049907116 ${DOC_NAME}='Miscellaneous'
   ${DOCUMENT_ID}=300000049907117 ${DOC_ENTRY}='Miscellaneous'`. The numeric
   `${TXN_SOURCE_ID}` and `${DOCUMENT_ID}` feed positions 6 and 7 of the import ParameterList —
   they were exactly the two "mystery" numeric ids the SUCCEEDED historical runs used. Without a
   valid `USER_TRANSACTION_SOURCE` + document + document entry the import silently leaves rows in
   staging.
3. **EXP_SYSDATE** — `TO_CHAR(SYSDATE,'YYYY/MM/DD')` → `${SYSDATE_SLASH}`. (No longer used by the
   ParameterList — the working `ImportAndProcessTxnsJob` leaves the process-through date `#NULL`.)

## Rows in the fixture

Two good, one bad (all stamped with the run prefix on `ORIG_TRANSACTION_REFERENCE`):

| Key (ORIG_TRANSACTION_REFERENCE) | Expenditure type | Cost | Expected |
|---|---|---|---|
| `${PREFIX}RT-EXP-G1` | `${EXP_TYPE}` (discovered, valid) | 125 | → `PJC_EXP_ITEMS_ALL` |
| `${PREFIX}RT-EXP-G2` | `${EXP_TYPE}` (discovered, valid) | 250 | → `PJC_EXP_ITEMS_ALL` |
| `${PREFIX}RT-EXP-BAD1` | `ZZ-BAD-EXPTYPE-99` (invalid) | 500 | staged then rejected `R` in `PJC_TXN_XFACE_ALL`, absent from base |

All rows are `NONLABOR` (PJ linkage): `TRANSACTION_TYPE=NONLABOR`, `USER_TRANSACTION_SOURCE=
External Miscellaneous`, `DOCUMENT_NAME=Miscellaneous`, `DOC_ENTRY_NAME=Miscellaneous`,
`BATCH_NAME=${PREFIX}RT-EXP-*` (unique per row — see the unique-batch-name gotcha above),
`QUANTITY = DENOM_RAW_COST` (DOLLARS-based UOM), `DENOM_CURRENCY_CODE=USD`, `BILLABLE_FLAG=N`.
The bad row is identical except for an expenditure type that does not exist, so Import Costs
rejects it at validation (`PJC_EXP_TYPE_INVALID`) while the two good rows cost successfully.

## Verification (read-only, direct single-table reads)

**Good → base.** Direct read of the base table by prefix:

```sql
SELECT orig_transaction_reference, expenditure_item_id, denom_raw_cost
FROM   pjc_exp_items_all
WHERE  orig_transaction_reference LIKE '<prefix>RT-EXP-%';
```

Both `<prefix>RT-EXP-G1` and `-G2` present with a real `EXPENDITURE_ITEM_ID` = pass.

**Bad → rejected, absent from base (proof-by-absence + import report).** Import and Process Cost
Transactions PURGES rejected rows from the staging table on this pod — the bad row is NOT retained
at `TRANSACTION_STATUS_CODE='R'`, and `PJC_TXN_XFACE_ALL` / `PJC_BIP_REPORT_DETAILS` are not
BIP-reachable here. So the authoritative bad-row proof is: (a) the bad key is ABSENT from base
`PJC_EXP_ITEMS_ALL` while the two good rows from the SAME import reached base with real ids, and
(b) the per-row rejection message in the Import-Costs report XML
(`ESS_O_<n>_BIP.xml`, retrieved by `downloadESSJobExecutionDetails` on the import request), where
the bad key appears with `MESSAGE_NAME=PJC_EXP_TYPE_INVALID` / `ERROR_GROUP=VALIDATIONS` for
expenditure type `ZZ-BAD-EXPTYPE-99`. The recipe verify block declares `bad_proof_is_absence:true`
(same mechanism as Billing Events / Item Import).

## Replica-lag caveat

Base rows can lag in the read-only BIP replica on this pod (seen on GL Balances). If the import
terminal status confirms rows were processed but a direct base read returns 0 for the good keys,
that is replica lag — re-read later. On the passing run below the good rows appeared in
`PJC_EXP_ITEMS_ALL` immediately. Never fabricate a pass.

## Live evidence (2026-07-19) — PASS to base tables

**Both halves PROVEN E2E on the live demo pod. The two blockers were identified and fixed.**

- **Passing run prefix: `32159`.** Load request **9764984** (SUCCEEDED); import request **9765010**
  (`onestop,ImportAndProcessTxnsJob`, SUCCEEDED).
- **Good → base:** `32159RT-EXP-G1` → `PJC_EXP_ITEMS_ALL.EXPENDITURE_ITEM_ID = 750728` (cost 125);
  `32159RT-EXP-G2` → `EXPENDITURE_ITEM_ID = 750729` (cost 250). Confirmed by direct read of the base
  table. Both good rows also removed from staging.
- **Bad → rejected, absent from base:** `32159RT-EXP-BAD1` does NOT appear in `PJC_EXP_ITEMS_ALL`,
  and the import report (`ESS_O_9765015_BIP.xml`) lists it as the ONLY rejection:
  `MESSAGE_NAME=PJC_EXP_TYPE_INVALID`, `ERROR_GROUP=VALIDATIONS`, expenditure type
  `ZZ-BAD-EXPTYPE-99`. The harness `verify.py` returns `"pass": true`.
- Discovered references: project **PCS10037** / task **5.2**, expenditure type **Airfare**,
  expenditure org **Consulting North US**, BU **US1 Business Unit** (id 300000046987012), source
  **External Miscellaneous** (txn source id **300000049907116**) → document **Miscellaneous**
  (document id **300000049907117**) / entry **Miscellaneous**, UOM DOLLARS.

### The two blockers and their fixes (history-derived)

1. **Wrong ESS job (ORA-06502).** The prior fixture submitted `onestop,ImportProcessParallelEssJob`
   (shadow proc `onestop_parallel_ess`, 13-arg). That job crashes with `ORA-06502: character to
   number conversion error` in its own parameter parsing on this pod — confirmed across ~20
   historical runs in `FUSION.REQUEST_HISTORY`, ALL state 10 (ERROR), including the prior agent's
   four (9763605, 9763692, 9763738, 9763844). The job that SUCCEEDS is the non-parallel
   `onestop,ImportAndProcessTxnsJob` (shadow proc `import_and_process_ess`, 10-arg). The working
   10-position order was read from two SUCCEEDED runs (request ids **9719834**, **9719348**) via
   `FUSION.ESS_REQUEST_PROPERTY` (rows `submit.argument1`..`10`) and cross-referenced to the shadow
   proc signature in `ALL_ARGUMENTS`. The two "mystery" numeric ids those runs used (arg6/arg7)
   turned out to be exactly `TRANSACTION_SOURCE_ID` (External Miscellaneous) and `DOCUMENT_ID`
   (Miscellaneous) — the same references this fixture uses. See the 10-position table above.
2. **Empty batch name (`PJC_UNIQUE_BATCH_NAME`).** With `ImportAndProcessTxnsJob` running, a first
   attempt (batch arg `#NULL`, empty `BATCH_NAME` on the rows) processed the rows but rejected the
   GOOD ones on `PJC_UNIQUE_BATCH_NAME` — the good rows collided on the empty auto-batch (both with
   each other and across the two staged prefixes). Fix: stamp a per-row unique `BATCH_NAME`
   (NONLABOR CSV position 10 = `${PREFIX}RT-EXP-*`) and leave the ParameterList batch filter
   `#NULL`. This is the run that reached base above.

The old "3 LOADED" verdict from the frozen DMT stack was a false positive (its `dmt_loader_pkg`
used the same broken 14-arg parallel form; a live count later found 0 rows in `PJC_EXP_ITEMS_ALL`).
This is the FIRST run that actually proved Expenditures to base — good rows costed into
`PJC_EXP_ITEMS_ALL`, bad row rejected with a reportable error and absent from base.
