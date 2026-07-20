# Requisitions (gold regression object)

Import Requisitions (Self-Service Procurement). One FBDI zip, three CSVs
(headers / lines / distributions), one load ESS job that chains
`RequisitionImportJob`. See `GOLD_README.md` in this folder for the full,
proven call recipe, ParameterList, discovery queries, verify SQL and live
evidence. This file records the durable learnings.

## Status

**GOLD — live-proven 2026-07-19 (prefix 90221, load req 9763076).** 1 good → base
`POR_REQUISITION_HEADERS_ALL` (id 128988, status INCOMPLETE); 1 bad (invalid UOM
`ZZZ`) → `POR_REQ_IMPORT_ERRORS`, absent from base.

## Object shape

- Type: FBDI, module Procurement. `interfaceDetails` (ERP_INTERFACE_OPTIONS_ID)
  = **28**. UCM account `prc/requisition/import`.
- Import job: `/oracle/apps/ess/prc/por/createReq/reqImport,RequisitionImportJob`
  (seed stores `;`; replace the last `;` with `,` for `loadAndImportData`).
- 8-arg ParameterList: `#NULL,${PREFIX},#NULL,${BU_ID},NONE,#NULL,NO,ALL`.
  Arg 2 (Import Batch ID) must equal header `BATCH_ID`; arg 4 is the discovered
  Requisitioning BU id.
- Interface tables: `POR_REQ_HEADERS_INTERFACE_ALL`,
  `POR_REQ_LINES_INTERFACE_ALL`, `POR_REQ_DISTS_INTERFACE_ALL`.
- Base tables: `POR_REQUISITION_HEADERS_ALL`, `POR_REQUISITION_LINES_ALL`,
  `POR_REQ_DISTRIBUTIONS_ALL`. Errors: `POR_REQ_IMPORT_ERRORS`
  (`interface_id` + `load_request_id`; header vs line vs dist by which
  interface-id column it joins).

## Learnings (new, from building the gold fixture)

- **`NEED_BY_DATE` (line FBDI col 11) must be a valid `YYYY/MM/DD` date.** A blank
  or malformed value makes SQL*Loader reject the row with `ORA-01841`. Because the
  load runs `DeleteOnLoadFailure = Y`, one bad date fails the WHOLE load — the
  parent ESS goes to ERROR and all three interface tables are purged, so nothing
  reaches import. Diagnose loader-stage failures by pulling the ESS log with the
  SOAP op `downloadESSJobExecutionDetails` (returns a zip of per-child `.log`
  files and a `*_bad.txt` of rejected rows).
- **Auth for the standalone SOAP load is `fin_impl`, not `calvin.roth`.** On this
  pod `calvin.roth` returns HTTP 401 on the ERP Integration service. The
  frozen-stack "must run as calvin.roth for the ledger" issue does NOT apply to
  this direct-SOAP path: the ledger is derived from the Requisitioning BU
  (ParameterList arg 4), and discovery only picks a BU whose `primary_ledger_id`
  is not null, so `get_ledger_id` always resolves.
- **A loaded requisition lands as `INCOMPLETE` (a draft), and that is a legitimate
  LOADED result.** The row exists in `POR_REQUISITION_HEADERS_ALL`. `APPROVED`
  needs a real approver and a clearing approval hierarchy (pod-dependent), so the
  gold fixture does not chase it — it verifies base-table presence, not
  `APPROVED`.
- **Deterministic bad row = invalid `UOM_CODE=ZZZ` on the line.** It passes
  SQL*Loader (valid string) and is then rejected by Import Requisitions with a
  line-level `POR_REQ_IMPORT_ERRORS` row ("The UOM isn't valid…"), while the good
  row still imports. Prefer a line-level bad value over a header-level one: a
  completely invalid header (e.g. nonexistent BU) can be dropped pre-validation
  with `process_flag = NULL` and NO error row, which is not a clean "interface
  error" demonstration.
- **Everything pod-specific is discovered** from an existing requisition on the
  target pod: BU + ledger, preparer email, deliver-to location, UOM, currency,
  category, and the charge-account code combination. Borrowing them from a real
  requisition guarantees each value is already accepted by import on that pod.

## Prior context (frozen DMT stack)

The frozen-stack notes (valid demo values UOM=ECH, Location=Louisville, BU=US1
Business Unit, charge account 101/10/68010/120/000/000, preparer
CALVIN.ROTH_esew-dev28@oraclepdemos.com; the two-tier interface/base
reconciliation; the header-error `process_flag=NULL` caveat) all still hold and
informed this fixture. The gold fixture now discovers those values instead of
hardcoding them, so it is portable to any pod.
