# Run 234 — Grants (Award Headers) — Real Fusion Outcome

**Read-only investigation. No code changed, no pipeline re-run, no reconciliation re-run.**
Run 234, prefix 10115. DMT queue row `QUEUE_ID=1427`, `WORK_STATUS=FAILED`,
message: *"3 record(s) unaccounted … not confirmed in base tables or interface error
tables (0 loaded, 0 errored). Object cannot be confirmed."*

## Summary counts

| Outcome | Count | Records |
|---|---|---|
| LOADED (reached a Fusion base table) | 0 | — |
| FAILED with a real Fusion message | 3 | 10115RTGNT-BAD1, 10115RTGNT001, 10115RTGNT002 |
| Genuinely absent (never processed) | 0 | — |

**Bottom line:** This is NOT a job-level failure, and NOT genuine absence. The Award
import ran to completion and Fusion **rejected all 3 records individually** with real,
attributable error messages. The prior memory guess (job errored at JOB level because the
Grants module is unconfigured) is **wrong on the mechanism but half-right on the cause**:
the two GOOD records fail because the Grants/Contracts business-unit setup is incomplete on
this demo pod, and the BAD record fails on its intended data defect. All three failures are
per-record, reported by Fusion's own Award Batch Import Report.

DMT marked them "unaccounted" only because it never read the report that holds these errors
(see Root cause below).

## Per-record outcome

| Key | OUTCOME |
|---|---|
| `10115RTGNT-BAD1` | **FAILED** — "You must provide a value for the Business Unit attribute." (Fusion message code `FND_CMN_REQ_ATTRIB_API_SERV`). Source: Award Batch Import Report, ESS request 9773862. This is the intended bad row (its FBDI header has a blank Business Unit) and Fusion correctly rejected it. |
| `10115RTGNT001` | **FAILED** — "The award contract can't be created because requisite setup steps haven't been completed." (Fusion message code `GMS_CONTRACT_PRE_REQ`). Source: request 9773862. Intended GOOD row; rejected by environment, not by data. |
| `10115RTGNT002` | **FAILED** — same as above: `GMS_CONTRACT_PRE_REQ`, "The award contract can't be created because requisite setup steps haven't been completed." Source: request 9773862. Intended GOOD row; rejected by environment. |

The `GMS_CONTRACT_PRE_REQ` message carries Fusion's own remediation detail (verbatim):
> Verify and ensure that these required setup steps have been completed. The business unit is
> defined. Users who want to create awards are resources in the Resource directory for the
> required business unit. The Multiple Business Units profile option is set to Yes … use the
> Specify Customer Contract Management Business Function Properties task … Assign Business Unit
> Business Function task … verify that the Customer Contract Management checkbox is selected …
> The Manage Data Access for Users task is completed for users with the necessary roles.

So the Grants/Award **contract** setup (Customer Contract Management business function for the
award's business unit) is not complete on this pod. That is a real, quotable Fusion error we
can attribute — the two good rows are blocked by pod configuration, exactly as memory
suspected, but Fusion surfaces it per record, not as a job crash.

## Evidence chain (all read-only)

1. **DMT queue** (`dmt_work_queue_tbl`, run 234, Grants): load ESS job `9773849`, import ESS
   job `9773857`, status FAILED, "3 unaccounted (0 loaded, 0 errored)".

2. **ESS job states** (`dmt_ess_job_tbl`, run 234) — the Grants chain all SUCCEEDED at the
   ESS layer:
   - `9773849` InterfaceLoaderController — SUCCEEDED
   - `9773850` InterfaceLoaderAsyncJob — SUCCEEDED
   - `9773851` / `9773852` InterfaceLoaderSqlldrImport — SUCCEEDED
   - `9773857` **AwardMassImportJob — STATE=12 SUCCEEDED** (not ERROR)
   There is no job-level ERROR anywhere in the Grants chain. Compare Suppliers (`9773481`
   ImportSuppliers = ERROR) — Grants is different; its import job succeeded.

3. **AwardMassImportJob log** (ESS request 9773857, downloaded live via
   `DMT_ESS_UTIL_PKG.GET_ESS_OUTPUT_TEXT`) states plainly:
   ```
   Total count : 3
   Success count : 0
   Error count : 3
   reqSuc = N
   Output report for this process is available in 9773862 request.
   ```
   The import completed with all 3 in error, and it names the report request that holds the
   detail: **9773862**.

4. **Award Batch Import Report** (ESS request 9773862, data model
   `AwardBatchImportReportDm`, downloaded live via `DMT_ESS_UTIL_PKG.GET_ESS_OUTPUT_XML`):
   - Header: `TOTAL_COUNT=3`, `SUCCESS_COUNT=0`, `FAILURE_COUNT=3`,
     `BATCH_STATUS = COMPLETED W/ERRORS`, `LOAD_REQUEST_ID=9773857`.
   - Per-record failure rows (element `G_4` / `G_AWD_HEADER`) give the three messages above,
     each tied to its `PARENT_AWARD_NUMBER` (10115RTGNT-BAD1 / 001 / 002) with
     `PROCESSED_STATUS=FAILURE`.

5. **Base table** `GMS_AWARD_HEADERS_B` / `_VL` — no award created for this prefix (report
   `SUCCESS_COUNT=0`; the `GMS_CONTRACT_PRE_REQ` failure means the award contract could not be
   created, so nothing lands in the base tables). Confirmed no rows.

6. **Interface tables** `GMS_AWARD_HEADERS_INT` — queried live, **0 rows** for `10115RTGNT%`.
   This is the crux: Fusion's Load Interface job runs with the **purge option**. The
   InterfaceLoaderController log (request 9773849) says verbatim: *"the data that will be
   purged from the product interface and error tables will first be extracted and uploaded to
   … UCM …"*. By the time DMT reconciles, the interface/error rows have been purged. The
   errors survive only in the delivered Award Batch Import Report (request 9773862).

## Root cause of "unaccounted" — where the reconciler reads the error

Package `DMT_GRANTS_RESULTS_PKG` (`db/packages/dmt_grants_results_pkg.pkb.sql`):

- `FETCH_BIP_RESULTS` (lines ~113-144) calls a **custom DMT BIP report** whose catalog path
  comes from `DMT_BIP_REPORT_TBL` for `CEMLI_CODE='Grants'`, passing
  `P_BATCH_ID = load_ess_id (9773849)` and `P_IMPORT_ESS_ID = import_ess_id (9773857)`.
  That custom report's SQL reads the Fusion **base tables and interface tables**.
- Because Fusion **already purged the Award interface/error tables**, that custom report
  returns zero rows → no `<reportBytes>`.
- `PARSE_AND_UPDATE` (lines 198-207) hits the "no reportBytes" branch and — correctly, by
  design (rule: never fabricate a FAILED) — leaves the 3 GENERATED rows unaccounted. The
  accounting gate then marks the object FAILED/unaccounted.

So the reconciler is looking in the right conceptual place (interface + base) but at the
**wrong time**: the interface rows are gone, and it never reads Fusion's own
**Award Batch Import Report** (request 9773862, data model `AwardBatchImportReportDm`,
catalog `/Projects/Grants Management/Award/AwardBatchImportReport.xdo`) where the per-record
`PROCESSED_MESSAGE` + `MESSAGE_CODE` still live.

## Fix roadmap (no code changed here — recommendations only)

1. **Read the Award Batch Import Report, not the purged interface tables.** For Grants,
   reconciliation should pull the delivered report tied to the import job — either by
   capturing the `ImportAwardReportJob` child output (here request **9773862**, discoverable
   as the child of AwardMassImportJob `9773857`) via `DMT_ESS_UTIL_PKG.GET_ESS_OUTPUT_XML`, or
   by calling the seeded Fusion report `AwardBatchImportReport.xdo` with `P_BATCH_ID` =
   `LOAD_REQUEST_ID` = the AwardMassImportJob request id (`9773857`), not the loader
   controller id. Map its `G_4`/`G_AWD_HEADER` rows: `PARENT_AWARD_NUMBER`/`AWARD_NUMBER` →
   the TFM row, `PROCESSED_STATUS=FAILURE` → `TFM_STATUS='FAILED'`,
   `PROCESSED_MESSAGE` + `MESSAGE_CODE` → `ERROR_TEXT`.
2. **Capture request 9773862.** DMT's ESS capture stored the parent AwardMassImportJob
   (`9773857`) but not the report child (`9773862`). The reconciler needs that child's output;
   enumerate/capture it (it is a sibling report request, not under the InterfaceLoader tree).
3. **Do not treat "0 interface rows" as absence for Grants.** After a successful
   AwardMassImportJob, the interface tables are purged by design, so an empty interface read
   is expected, not evidence of "never processed." The authoritative source is the import
   report.
4. **Environment note (not a code fix):** the two intended-GOOD awards fail with
   `GMS_CONTRACT_PRE_REQ` because the Customer Contract Management business function / business
   unit setup for awards is incomplete on this demo pod. Until that setup is done, GOOD Grants
   rows cannot reach the base tables here — but that is now provable with a real Fusion error,
   so Grants can be reported honestly as **all-3-FAILED with real messages** rather than
   "unaccounted."

## Reference IDs

- Run 234, prefix 10115, Grants queue id 1427.
- Load (InterfaceLoaderController): ESS request **9773849** (SUCCEEDED).
- Import (AwardMassImportJob): ESS request **9773857** (SUCCEEDED; 3 errors, 0 success).
- Award Batch Import Report (per-record errors): ESS request **9773862**
  (`ImportAwardReportJob` / data model `AwardBatchImportReportDm` /
  `/Projects/Grants Management/Award/AwardBatchImportReport.xdo`).
