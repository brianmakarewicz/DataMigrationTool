# HCM reconciliation root cause: `DMT_HDL_UTIL_PKG.RECONCILE_HDL` (backlog #228, 2026-10-07)

Every HDL object reconciles through one shared procedure, `DMT_HDL_UTIL_PKG.RECONCILE_HDL`
(`db/packages/dmt_hdl_util_pkg.pkb.sql:406-738`). It has three defects. This document records
what each defect is, what Fusion actually gives us to fix it, how many rows were wrongly
marked LOADED because of it, and the proposed design.

**Outcome: research only, no code changed.** The fix is not straightforward. The reasons are
in "Why this was not fixed now" below. Everything here was read-only: the local DMT2 database,
read-only HDL REST GETs (`hcm_impl`, credentials from `connections.json`), and read-only BIP
queries through `scripts/fusion_bip_query.py`.

## Headline numbers

- **Rows wrongly marked LOADED by the dataset-status promotion (Step 2): 0.** In every run
  whose log survives (17 runs from 120 to 238), each child table's `RECONCILE_HDL complete`
  line reports `LOADED: 0`.
- **Rows LOADED in a table that has no base-table proof of its own: 22**, all PersonName rows
  (one per run, runs 120 to 238). They were set LOADED by the Worker parent-verdict cascade in
  `DMT_WORKER_RESULTS_PKG.APPLY_CONTRACT_V1_WORKERS` (`dmt_worker_results_pkg.pkb.sql:365-395`),
  not by Step 2. **All 22 are real:** each carries its own `FUSION_PERSON_NAME_ID`, and a
  read-only BIP query found all 22 ids in `PER_PERSON_NAMES_F` under the right person number.
- The other eleven child tables that rely on Step 2 have either no rows in any run (PersonEmail,
  PersonPhone, PersonAddress, PersonNationalIdentifier, PersonLegislativeData, TaxCards card and
  component, W2Balances detail, WorkSchedules detail, PerfEvaluations rating) or only FAILED
  rows (TalentProfiles item: 20 FAILED). So the false-LOADED defect is **latent**: today's seed
  never lets it fire, but a run where the data set finishes `ORA_COMPLETED`, or finishes in
  error with one matched error in a child table, would promote every other row of that table to
  LOADED with no proof.

## Defect 1: messages are not named

`RECONCILE_HDL` Step 1 (`:486-511`) writes
`'[FUSION_ERROR] ' || LISTAGG(jt.msg, '; ')`. Only `MessageText` is read. When several messages
match a row (with the prefix `LIKE`, every component error of a person matches every table keyed
on that person), they are joined with no indication of which record each came from.

**What HDL gives us per message.** `GET .../dataLoadDataSets/{RequestId}/child/messages`
returns one item per message. Run 238, Workers (request 10070511):

| Field | Value |
|---|---|
| `SourceSystemId` | `93294ET-RT-WKR-BASG_TRM` |
| `DatFileName` | `Worker.dat` |
| `FileLine` | `10` |
| `BusinessObjectDiscriminator` | `WorkTerms` |
| `ReportedAgainstCode` | `ORA_FILE_LINE` |
| `ConcatenatedUserKey` | `ET-93294ET-RT-WKR-BASG` |
| `MessageLineId` / `DataSetId` / `DataSetBusObjId` | `100002665801435` / `300000334917984` / `300000334918008` |
| `MessageText` | You must provide a valid reference to the parent record. ... |

Three things matter for the message format:

- Some messages have no `FileLine`. Run 236's Worker error on `93292RT-WKR-B1` ("The WorkerName
  SDO, LastName attribute value is required") is reported against the logical object, with an
  empty line. The format must drop the line part when it is missing.
- Some messages have no `SourceSystemId` at all. Run 236 TalentProfiles (request 10069777) has
  six messages, all file-level: four METADATA errors on `TalentProfile.dat line 4`, a "critical
  errors" message and a data-set message. These are the null-key messages that Step 1b
  (`:527-553`) already copies to every row of the table.
- `GET_HDL_ERRORS` (`:379-380`) asks for `limit=500` and never follows `hasMore`. A data set
  with more than 500 messages silently loses the rest. That is a second, smaller defect in the
  same code.

So the target format `[FUSION_ERROR] <SourceSystemId> (<file> line <n>): <real msg>` is fully
supported by the data. Example from run 238:
`[FUSION_ERROR] 93294ET-RT-WKR-BASG_TRM (Worker.dat line 10): You must provide a valid reference to the parent record. ...`

## Defect 2: rows are matched with `LIKE` on the prefixed key

Messages are already fetched per data set: `GET_HDL_ERRORS` reads
`dataLoadDataSets/{p_request_id}/child/messages`, so the message side is scoped by the HDL
request id. The defect is on the row side. Unless the caller passes `p_key_suffixes`, a message
is tied to a row with `jt.src_ref LIKE t.<key> || '%'` (`:439-440`). Only Assignments passes
suffixes (`'_TRM,_ASG'`, exact equality). The other 25 calls use the prefix `LIKE`, so:

- a table keyed on `PERSON_NUMBER` takes every message whose SourceSystemId starts with that
  person number, whatever component it belongs to (`_NME`, `_EML`, `_POS`, ...);
- a key that is a prefix of another key absorbs the other key's messages (the `G1` / `G1B` case
  that made Assignments switch to exact matching).

**Exact keys are known for most tables, not all.** The generators write these SourceSystemIds
(`db/packages/dmt_*_hdl_gen_pkg.pkb.sql`):

| Object / table | SourceSystemId written | Exact match possible today? |
|---|---|---|
| Workers: Worker | `PERSON_NUMBER` | Yes |
| Workers: PersonName / Email / Phone / Address / NID / Legislative | `PERSON_NUMBER` + `_NME` / `_EML` / `_PHN` / `_ADR` / `_NID` / `_LEG` | Yes (per-table suffix) |
| Workers: WorkRelationship | `PERSON_NUMBER_POS` | Yes |
| Workers: Assignment | `ASSIGNMENT_NUMBER` + `_TRM` and `_ASG` | Yes (already exact) |
| Salaries | `PERSON_NUMBER_SAL` | Yes, but see note below |
| TalentProfiles | `_TPROF` (profile), `_TPITM` (item) | Yes |
| TaxCards | `_TAXCARD` (card), `_TAXCOMP` (component) | Yes |
| Absences | `_ABS` | Yes |
| BenBeneficiary | `_BENENRL`, `_BENDSGN` | Yes |
| BenDependent | `..._<line number>_BENDEP` | **No.** The line number is generated and not stored on the TFM row. |
| WorkSchedules | `WORK_SCHEDULE_NAME_WPAT`; `PERSON_NUMBER_WSASG` on a table keyed by schedule name | **No** for the schedule assignment (#188). |
| W2Balances, PerfEvaluations | none | **No.** No SourceSystemId is written (#183, #187). |

Note on Salaries: the BAD salary row's `PERSON_NUMBER` is the raw `RT-WKR-BSAL` (no run
prefix), and the SourceSystemId Fusion reported is `RT-WKR-BSAL_SAL`, but the row's `RECON_KEY`
is `93294RT-WKR-BSAL_SAL`. So `RECON_KEY` is **not** always the SourceSystemId that was sent; an
exact match must use the generator's own expression (`PERSON_NUMBER || '_SAL'`), not
`RECON_KEY`. The same unprefixed SourceSystemId is sent in every run, which is safe only because
messages are read per data set. Key formats are out of scope here (backlog #218).

**How to scope by the data set without the prefix.** Fusion keeps the per-line state of each
data set, keyed by the HDL request id we already store as the work item's `LOAD_ESS_JOB_ID`:

```
HRC_DL_DATA_SET_BUS_OBJS b   -- REQUEST_ID = the HDL request id, DATA_FILE_NAME
JOIN HRC_DL_FILE_LINES   l ON l.DATA_SET_BUS_OBJ_ID = b.DATA_SET_BUS_OBJ_ID
JOIN HRC_DL_FILE_ROWS    r ON r.LINE_ID = l.LINE_ID        -- KEY_SOURCE_OWNER, KEY_SOURCE_ID
LEFT JOIN HRC_DL_PHYSICAL_LINES p ON p.ROW_ID = r.ROW_ID  -- VALIDATED_LOADED_STATUS
WHERE b.REQUEST_ID = :P_LOAD_REQUEST_ID
```

Run 238, Workers (request 10070511), read on 2026-10-07 about a day after the load:

| KEY_SOURCE_ID | Line status |
|---|---|
| `93294RT-WKR-G1` | LOADED_SUCCESS |
| `93294RT-WKR-G1_NME` | LOADED_SUCCESS |
| `93294RT-WKR-G1_POS` | LOADED_SUCCESS |
| `93294ET-RT-WKR-G1_TRM`, `..._G1B_TRM`, `..._G1_ASG`, `..._G1B_ASG` | LOADED_SUCCESS |
| `93294ET-RT-WKR-BASG_TRM` | UNPROCESSED (import ERROR, the line with the message) |
| `93294ET-RT-WKR-BASG_ASG` | UNPROCESSED (no message of its own: rejected with its document) |

This answers two questions left open by `docs/findings/bip_row_selection_review.md` (row for
the 14 HDL objects): the data-set lines **do** survive until reconciliation, and
`HRC_DL_FILE_ROWS.KEY_SURROGATE_ID` is **empty** on loaded lines, so the Fusion id has to come
from `HRC_INTEGRATION_KEY_MAP`, not from the data-set row.

## Defect 3: Step 2 promotes child rows to LOADED from the data-set status

Twelve calls do not pass `p_defer_base_proof => TRUE`, so Step 2 (`:602-698`) runs for them:
PersonName, PersonEmail, PersonPhone, PersonAddress, PersonNationalIdentifier,
PersonLegislativeData (Workers); TalentProfiles item; PerfEvaluations rating; TaxCards card and
component; W2Balances detail; WorkSchedules detail. For those tables:

- `ORA_COMPLETED` / `SUCCESS` marks every remaining GENERATED row LOADED (`:666-673`);
- `ORA_IN_ERROR` with at least one matched error in the same table marks every other row LOADED
  (`:674-682`).

Neither branch looks at Fusion for the row. The counts are in "Headline numbers": 0 rows were
promoted this way in the 17 runs with logs, because every regression run has a BAD record (so
the data set ends `ORA_IN_ERROR`) and the child tables almost never have a matched error of
their own. The Worker parent-verdict cascade has the same shape (child LOADED because the
parent is LOADED); its 22 PersonName rows turned out to be real only because the Workers recon
report also stamps each name's own id.

**How each child row can be proven on its own key.** Every loaded HDL record lands in
`HRC_INTEGRATION_KEY_MAP` with its SourceSystemId and Fusion surrogate id. Joining the data-set
rows above to the key map and then to the base table proves each row by its exact
SourceSystemId, scoped only by the request id. Run 238, Workers (10070511) and Salaries
(10070631), all from one read-only query:

| Request | KEY_SOURCE_ID | Line status | Key map object | Surrogate id | In base table |
|---|---|---|---|---|---|
| 10070511 | `93294RT-WKR-G1` | LOADED_SUCCESS | Person | 300000334843428 | Y (`PER_ALL_PEOPLE_F`) |
| 10070511 | `93294RT-WKR-G1_NME` | LOADED_SUCCESS | PersonName | 300000334843431 | Y (`PER_PERSON_NAMES_F`) |
| 10070511 | `93294RT-WKR-G1_POS` | LOADED_SUCCESS | PeriodOfService | 300000334843430 | Y (`PER_PERIODS_OF_SERVICE`) |
| 10070511 | `93294ET-RT-WKR-G1_ASG` | LOADED_SUCCESS | Assignment | 300000334843460 | Y (`PER_ALL_ASSIGNMENTS_M`) |
| 10070511 | `93294ET-RT-WKR-BASG_TRM` | UNPROCESSED | (none) | | N |
| 10070631 | `93294RT-WKR-G1_SAL` | LOADED_SUCCESS | Salary | 300000334843504 | Y (`CMP_SALARY`) |
| 10070631 | `RT-WKR-BSAL_SAL` | LOADED_ERROR | (none) | | N |

The DMT side agrees: run 238's PersonName row has `FUSION_PERSON_NAME_ID` 300000334843431, and
the Salary G1 row is LOADED. (`WorkTerms` lines map to key-map object `Assignment`.)

## Why this was not fixed now

The three changes are clear, but doing them correctly for all 14 objects is not a small edit:

1. **`RECONCILE_HDL` is dynamic SQL.** Every statement in it is `EXECUTE IMMEDIATE` on a table
   name passed in, which the coding standard bans ("No EXECUTE IMMEDIATE", design section 7).
   Changing the message format or the match predicate means rewriting those statements. Doing
   it properly means the Option A shape already used for recon reports: the shared package
   returns parsed rows, and each object's results package applies them with static SQL. That
   touches 14 results packages and 26 call sites.
2. **Proof needs new BIP data models.** Removing Step 2 without a per-row proof source turns
   the twelve tables into UNACCOUNTED rows. The current recon reports scope by
   `SOURCE_SYSTEM_ID LIKE :P_PREFIX || '%'` (backlog #233, #246, #252 and the other HDL items
   from #616), and the Workers report proves only Person, PersonName, PeriodOfService and
   Assignment, not Email, Phone, Address, NID or Legislative data. Each HDL object needs a new
   data model version, deployed alongside the current one and never over it, that selects by
   `P_LOAD_REQUEST_ID` and proves each component. That is Fusion catalog work across up to 14
   objects.
3. **Open design questions remain.** Three objects cannot be matched exactly today:
   W2Balances and PerfEvaluations write no SourceSystemId, and BenDependent's SourceSystemId
   includes a generated line number that the TFM row does not store. Fixing them means
   changing key formats, which belongs to #218. Exact matching also stops the prefix `LIKE`
   from copying a person-level error onto the person's components. The owner rule on
   whole-document rejection (design section 5) says those rows must then get the real error,
   named. That is the cross-grain work in #181-#188, and it should land together with this fix
   so no row moves from FAILED to UNACCOUNTED.

## Proposed design

One shared change, built in the Option A shape, delivered object by object behind the
regression scenario.

1. **Shared fetch, no dynamic SQL.** Replace `RECONCILE_HDL` with
   `DMT_HDL_UTIL_PKG.FETCH_HDL_MESSAGES(p_run_id, p_request_id, x_msgs)`. It returns a
   collection of (SourceSystemId, DatFileName, FileLine, BusinessObjectDiscriminator,
   MessageText), follows `hasMore` until every message is read, and touches no TFM table.
   Add `DMT_HDL_UTIL_PKG.FORMAT_HDL_ERROR(msg)`, returning
   `<SourceSystemId> (<file> line <n>): <text>`, or `<SourceSystemId> (<file>): <text>` when
   there is no line, or `<file>: <text>` for file-level messages. The caller prefixes
   `[FUSION_ERROR] `.
2. **Static apply per object.** Each `DMT_<obj>_RESULTS_PKG` matches messages to its own TFM
   tables with static SQL on the exact generator key
   (for example `jt.src_ref = c.PERSON_NUMBER || '_NME'`). Never `LIKE`, never the prefix. Rows
   are limited to the work item being reconciled (`WORK_QUEUE_ID`), and messages come only from
   that work item's request id. Null-key (file-level) messages keep today's behaviour of
   applying to every GENERATED row of that file, now named with the file.
3. **Proof per row, scoped by the request id.** A new recon data model version per HDL object
   (for example `DMT_WORKERS_RECON_V2_DM`, deployed next to the current one, registry row
   repointed) selects
   `HRC_DL_DATA_SET_BUS_OBJS.REQUEST_ID = :P_LOAD_REQUEST_ID`, joins the data-set rows to
   `HRC_INTEGRATION_KEY_MAP` on owner and SourceSystemId, confirms the surrogate in the base
   table, and returns one BASE/SUCCESS row per component with `OBJECT_TYPE` = the key-map object
   and `RECORD_KEY` = the exact SourceSystemId. The query shape is proven above. Each child
   table is marked LOADED only from its own row in that report, stamped with its own Fusion id.
   Step 2 and the "parent LOADED, so child LOADED" cascade are deleted.
4. **Whole-document rejection.** The same report can also return the data-set line status
   (`UNPROCESSED`, `LOADED_ERROR`) and the logical-object id. A row whose own line is
   UNPROCESSED with no message of its own is FAILED quoting the real message of the line that
   rejected the document, named, in the permitted related-record form. This is #181-#188 and
   lands with this change.
5. **Prove it.** New HCM runs with a new prefix, at least Workers (with Assignments) and
   Salaries. GOOD rows LOADED with their own Fusion ids, BAD rows FAILED with their own named
   messages, nothing LOADED without a row in the proof report, `dmt_regression_run.py` PASS,
   the Playwright click-through, and all `scripts/check_*.py`.

Suggested order: Workers (largest, proof query already shown), Salaries, then the
functionally blocked objects as they become loadable. W2Balances, PerfEvaluations and
BenDependent wait for #218 to give them an exact key.

## Evidence index

- Local DB (dmt2-local), `DMT_LOG_TBL` lines `RECONCILE_HDL complete. LOADED: n` for
  `Workers > PersonName > RECONCILE_HDL` and the other contexts, runs 120 to 238.
- Status counts across the 16 HDL TFM tables, all runs: PersonName 22 LOADED / 1 GENERATED;
  TalentProfiles item 20 FAILED / 1 GENERATED; the other ten child tables have no rows.
- BIP: `PER_PERSON_NAMES_F` joined to `PER_ALL_PEOPLE_F` for the 22 `FUSION_PERSON_NAME_ID`
  values. 22 of 22 found, each under its run's `<prefix>RT-WKR-G1`.
- HDL REST messages: requests 10070511 and 10070631 (run 238), 10069492 and 10069777 (run 236).
- BIP: `HRC_DL_DATA_SET_BUS_OBJS` / `HRC_DL_FILE_LINES` / `HRC_DL_FILE_ROWS` /
  `HRC_DL_PHYSICAL_LINES` / `HRC_INTEGRATION_KEY_MAP` plus base tables, for requests 10070511
  and 10070631.
