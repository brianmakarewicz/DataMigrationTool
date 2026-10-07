# Value Sets: how Fusion actually loads value set values, and what DMT gets wrong

Research only, 2026-10-07. No product code changed. Backlog item #227 (updated, P3).

## 1. Summary

Value Sets has never loaded because DMT treats it as an FBDI object. It builds a zip and calls
`loadAndImportData` with interface id 302. Fusion therefore starts **Load Interface File for
Import** (`InterfaceLoaderController`) with `submit.argument1 = 302`. That is not a real FBDI
interface, so the request sits in WAIT and then ends in ERROR. The value-set job that DMT names
is never submitted at all.

Oracle's documented process is not FBDI. It has three steps:

1. Build a **pipe-delimited flat file of values** with a header row.
2. Upload that file **on its own** (no zip) to the content repository (UCM).
3. Process it with either the **"Upload Value Set Values"** scheduled process (parameters:
   Flat File Name, Account) or the **`FndManageImportExportFilesService`** SOAP web service.
   The service is present on the pod and exposes `uploadFiletoUCM` and
   `valueSetValuesDataLoader` / `processValueSetValues(Async)` / `downloadProcessLogFile`.

The process **only adds or updates values in a value set that already exists.** It cannot
create the value set definition. DMT's "set" rows (`ValueSetCode.csv`) have no documented file
load, and DMT prefixes every `VALUE_SET_CODE` per run. As a result, every run's values point at
a value set that does not exist in Fusion. This is the largest design gap.

The **ESS job definition path for "Upload Value Set Values" is not documented** and has
**never run on the pod**, so its package path, name and argument order cannot be read from
`ESS_REQUEST_HISTORY` / `ESS_REQUEST_PROPERTY`. The path DMT seeds
(`/oracle/apps/ess/financials/commonModules/shared/applicationCore/valueSet;FndValueSetUploadServiceJob`)
has no source: the only web hit for it is DMT's own PR #544. Under the project rule (discover
ESS parameters from real history, never guess), this is the first open question.

**No standalone proof was attempted.** The process can only write values into an existing value
set. Proving it would mean adding values to a real, existing Fusion value set, which changes
Fusion setup. Creating a test value set first is also a setup change, and the REST create
action is disabled on the pod (PR #544).

## 2. Oracle's documented process (current release, 26D; the 26A to 26D pages are identical)

Sources:

- *Upload Value Set Values Process*:
  https://docs.oracle.com/en/cloud/saas/applications-common/26d/facia/upload-value-set-values-process.html
  (also `financials/26d/fafcf/...`)
- *Import Value Set Values*:
  https://docs.oracle.com/en/cloud/saas/financials/26d/fafcf/import-value-set-values.html
- *Requirements for Flat Files to Upload Value Set Values*:
  https://docs.oracle.com/en/cloud/saas/financials/26d/fafcf/requirements-for-flat-files-to-upload-value-set-values.html
- *Import Value Set Values to Oracle Applications Cloud* (web service):
  https://docs.oracle.com/en/cloud/saas/procurement/26d/oapro/import-value-set-values-to-oracle-applications-cloud.html
- *Overview of Files for Import and Export* / *Guidelines for File Import and Export* (UCM accounts):
  https://docs.oracle.com/en/cloud/saas/applications-common/26d/facia/overview-of-files-for-import-and-export.html

### 2.1 What it does

"This process uploads a flat file containing value set values for flexfields. You can use the
scheduled process to upload a file containing values you want to edit or add to an **existing**
independent or dependent value set." The Import page adds: "you must specify an existing value
set code ... If the value set does not exist, add the value set using the appropriate Manage
Value Sets task."

### 2.2 File format

- The file is pipe (`|`) delimited for both the header and the value rows.
- It must be UTF-8 **without a BOM**.
- The first line is a header line, and the file must "look exactly the same as shown in the
  sample file".
- Columns are matched by the header name. Each later row follows the header order.

| Value set type | Mandatory columns |
|---|---|
| Independent | `ValueSetCode` (60), `Value` (150), `EnabledFlag` (Y/N) |
| Dependent | `ValueSetCode` (60), `IndependentValue` (150), `Value` (150), `EnabledFlag` (Y/N) |

The optional columns are:

- `TranslatedValue` (150) and `Description` (240)
- `StartDateActive` and `EndDateActive`, as DATE in **YYYY-MM-DD** format
- `SortOrder` (NUMBER 18) and `SummaryFlag` (30)
- `FlexValueAttribute1..20` and the user-defined `CustomValueAttribute1..10`
- the typed columns `IndependentValueNumber|Date|Timestamp` and `ValueNumber|Date|Timestamp`
- the FND_VS_VALUES DFF segment API names

The full header from Oracle's sample, in order:

```
ValueSetCode|IndependentValue|IndependentValueNumber|IndependentValueDate|IndependentValueTimestamp|Value|ValueNumber|ValueDate|ValueTimestamp|TranslatedValue|Description|EnabledFlag|StartDateActive|EndDateActive|SortOrder|SummaryFlag|...
```

Minimal independent example: `VALUESETCODE|VALUE|ENABLEDFLAG` then `FLEX_KFF1_IND_CHR_L10_ZEROFILL|5000|Y`.
Dependent example: `ValueSetCode|IndependentValue|Value|EnabledFlag` then `CITIES|AK|Juneau|Y`.

### 2.3 Where the file goes

The file is uploaded on its own through File Import and Export (or `uploadFiletoUCM`) to a
**UCM account of the user's choice**. The process takes **Account** as a parameter ("Select the
user account containing the flat file in the content repository"), so no account is mandated.
The docs do not name `setup/functionalCoreSetup` for this process. Oracle's web-service sample
uses `fin$/tax$/import$`, and the community examples use `fin/generalLedger/import` and
`prc/supplier/import`. `setup/functionalCoreSetup` (the owner's suggestion) is plausible, but the
owner needs to confirm it (see the open questions).

### 2.4 How it is run (three documented routes)

1. **The scheduled process "Upload Value Set Values"** (Scheduled Processes page). It takes two
   parameters: **Flat File Name** and **Account**. Oracle does not publish its ESS package path or
   job name.
2. **The Manage Value Sets UI**: Actions > Import, then Account and File Name, then Upload. This
   route is interactive and not usable by DMT.
3. **The SOAP web service `FndManageImportExportFilesService`** (the "Applications Core Metadata
   Import web service"). It runs in two calls. First, `uploadFiletoUCM(document{fileName,
   contentType, content(base64), documentAccount, documentTitle})` returns the UCM file id. Then
   `valueSetValuesDataLoader(fileIdAtRepository)` processes that file id.

### 2.5 Who can run it

The process is part of value set management. The docs say the web service must be in the "Manage
Application Flexfield Value Set" entitlement, which is carried by the Application Implementation
Consultant job role. On the pod, **FIN_IMPL holds `ORA_ASM_APPLICATION_IMPLEMENTATION_CONSULTANT_JOB`**
(also HCM_IMPL, PPM_IMPL and SCM_IMPL), read from `PER_USER_ROLES` through BIP. FIN_IMPL is
therefore the natural user. This has not been proven by a live call.

## 3. Pod evidence (read-only BIP and a WSDL GET, 2026-10-07)

| Check | Result |
|---|---|
| `ESS_REQUEST_HISTORY.definition` LIKE `%VALUESET%` / `%VALUE_SET%` | **none** (the only applcore flex job is `FndFlexBossRWDSyncJob`, a sync job and not an upload) |
| `ESS_REQUEST_PROPERTY.value` LIKE `%VALUESET%` / `%VALUE_SET%` / `%FNDVS%` | **none**: no value-set upload has ever run on this pod, so there is no real parameter list to copy |
| DMT's own submissions (local `DMT_LOG_TBL`, runs 238 to 247, and PR #544 run 202) | ESS 10048363, 10070535, 10070721, 10070947, 10074741 |
| What those requests actually are | **`InterfaceLoaderController`** (Load Interface File for Import), package `/oracle/apps/ess/financials/commonModules/shared/common/interfaceLoader`, submitter FIN_IMPL, `submit.argument1 = 302`, `argument2 = 7892058` (UCM doc id), `argument3/4 = N` |
| Their state now | `STATE = 10` (ERROR), after the WAIT that DMT's 1800 s poll saw. #227 records the error text as "erpFamily is null" |
| `FndValueSetUploadServiceJob` | **never submitted.** `loadAndImportData` submits the import job only after the loader succeeds, and the loader fails on interface 302 |
| `GET /fndAppCoreServices/FndManageImportExportFilesService?wsdl` as FIN_IMPL | **HTTP 200.** Operations: `uploadFiletoUCM`, `valueSetValuesDataLoader(fileIdAtRepository:long) -> result:string`, `processValueSetValues(fileIdAtRepository, UUID)`, `processValueSetValuesAsync`, `downloadProcessLogFile(UUID) -> string`, `processRelatedSetValueData(Async)`, `processLookupsData`, `processFlexData`, `getImportDocumentId` |
| Base tables | `FND_VS_VALUE_SETS` (VALUE_SET_ID) and `FND_VS_VALUES_B` (VALUE_ID, VALUE_SET_ID, VALUE, INDEPENDENT_VALUE, ENABLED_FLAG, START/END_DATE_ACTIVE, CREATION_DATE, CREATED_BY, LAST_UPDATE_DATE ...). There is **no REQUEST_ID or batch column** (this confirms #257) |

So the "WAIT" was never Fusion refusing a value-set job. It was the generic FBDI loader with an
invented interface id. PR #544's conclusion that the value-set job "is not registered" was not
supported: that job was never reached.

## 4. Differences between DMT today and the documented process

| # | Area | DMT today | Documented process |
|---|---|---|---|
| 1 | Mechanism | FBDI: `DMT_LOADER_PKG.SUBMIT_LOAD` -> `loadAndImportData` | Not FBDI. A plain flat file, then the Upload Value Set Values process or `FndManageImportExportFilesService` |
| 2 | Interface id | `ERP_INTERFACE_OPTIONS_ID = 302` passed as `interfaceDetails` (invented), which starts InterfaceLoaderController | No interface id. The loader must not run at all |
| 3 | Packaging | One zip `FndValueSet_<run>.zip` holding `ValueSetCode.csv` and `ValueSetValue.csv` | One unzipped pipe file of values per upload |
| 4 | Value set definitions | `ValueSetCode.csv` (`ValueSetCode\|Description\|ModuleId\|ValidationType\|...`) | **No file load for definitions.** The value set must already exist (created by Manage Value Sets, setup-data CSV import, or REST, whose create is disabled on the pod) |
| 5 | Run prefix | The transform prefixes `VALUE_SET_CODE` on sets and values (README, 2026-10-06) | Values must reference an **existing** code. A per-run prefixed set never exists, so every value fails |
| 6 | Value header | `ValueSetCode\|Value\|Description\|EnabledFlag\|EffectiveStartDate\|EffectiveEndDate\|IndependentValue\|Tag` | Documented names are `StartDateActive` / `EndDateActive`. `Tag` is not a documented column. `IndependentValue` is fine by name but sits after `Value` in DMT (header-driven, so probably fine, but unproven) |
| 7 | Date format | `YYYY/MM/DD` | `YYYY-MM-DD` |
| 8 | Encoding | `DBMS_LOB.CONVERTTOBLOB` with the DB charset; BOM not checked | UTF-8, no BOM |
| 9 | UCM account | `fin/fusionAccountingHub/import` (seed 302) | The caller chooses one and passes it as the Account parameter; the owner proposes `setup/functionalCoreSetup` |
| 10 | ESS job | `/oracle/apps/ess/financials/commonModules/shared/applicationCore/valueSet;FndValueSetUploadServiceJob`, parameter list `NEW,N` | Real path, name and argument order **unknown** (undocumented, never run on the pod). The documented parameters are Flat File Name and Account, not `NEW,N` |
| 11 | ERP options row | `DMT_ERP_INTERFACE_OPTIONS_TBL` row 302 (ERP_FAMILY FND, LOADER_TYPE SQLLOADER, LOAD_INTERFACE_FLAG Y) | Nothing applies. This object does not belong in the FBDI options table |
| 12 | Errors | The load step logs only the ESS status; there are no per-row errors (correct per the no-fabrication rule, but nothing real is captured either) | Per-row messages are in the process log: the ESS request log/output, or `downloadProcessLogFile(UUID)` for `processValueSetValues` |
| 13 | Reconciliation | BIP `DMT_VS_RECON_RPT` on `FND_VS_VALUE_SETS` / `FND_VS_VALUES_B`, selecting by the code and value lists | Same base tables are right. There is no job id column, so selection stays by key (#257), but it can be narrowed by `CREATION_DATE`/`LAST_UPDATE_DATE >= submit time` and `LAST_UPDATED_BY = submitting user` to avoid a false LOADED on a value that already existed |

## 5. Proposed design (not built)

**Scope split.** Treat **ValueSetValues** as the loadable object. The value set definitions
(the `ValueSets` set rows) are a separate, prerequisite object with no file-load route today. Until
the owner picks a definition route, DMT should not send set rows and should not prefix
`VALUE_SET_CODE`. The values target an existing (functionally created) set, and the run prefix
goes on `Value`, which is unique within the set (the Fusion limit is 150).

1. **Generator** (`DMT_FND_VS_FBL_GEN_PKG`). Emit one UTF-8 file without a BOM,
   `DMT_VS_VALUES_<run_id>.txt`, with the header written once per value-set type group. The
   header uses the documented names:
   `ValueSetCode|IndependentValue|Value|Description|EnabledFlag|StartDateActive|EndDateActive|SortOrder`
   (drop `Tag`). Dates are `YYYY-MM-DD`. Do not zip. Persist the file in `DMT_FBDI_CSV_TBL` as now.
2. **Upload.** Use `FndManageImportExportFilesService.uploadFiletoUCM` (documented, and present
   on the pod) as FIN_IMPL, with `documentAccount` set to the owner-confirmed account (candidate
   `setup$/functionalCoreSetup$`). It returns the UCM file id. The other route is
   `ErpIntegrationService.uploadFileToUcm`, which DMT already uses elsewhere. Both are plain
   uploads with no `loadAndImportData`.
3. **Process.** There are two options:
   - **(a) ESS route (owner's stated process).** Submit "Upload Value Set Values" through
     `ErpIntegrationService.submitESSJobRequest`, one `<paramList>` per argument (Flat File Name,
     Account), then `POLL_ESS_JOB`. **This is blocked on open question 1.**
   - **(b) Web-service route.** Call `processValueSetValues(fileIdAtRepository, UUID)` (or the
     synchronous `valueSetValuesDataLoader`), then `downloadProcessLogFile(UUID)`. This is fully
     documented and pod-verified at WSDL level. It has no ESS request id, so "reconcile by job id"
     becomes "reconcile by the UUID and the log".
4. **Reconciliation.** The job's log is the per-row error source. For the ESS route, download the
   request's log/output (the existing ESS output download path). For the web-service route, use
   `downloadProcessLogFile(UUID)`. Each rejected line is mapped to its TFM row by
   ValueSetCode + IndependentValue + Value and marked FAILED with Fusion's own text. LOADED comes
   only from `FND_VS_VALUES_B` (FUSION_VALUE_ID = VALUE_ID). Base-table selection stays by key
   (no job id exists, #257), but it is narrowed by `CREATION_DATE`/`LAST_UPDATE_DATE` at or
   after the submit time and `LAST_UPDATED_BY` = the submitting user. Anything else stays
   UNACCOUNTED.
5. **Cleanup.** Retire ERP options row 302 and the `LOAD_VIA_FBDI` path for this object. Remove
   `FND_VS` from the FBDI zip table.

## 6. Open questions (owner)

1. **What is the ESS job's real path, name and argument order?** The rule is to discover it from
   history, and the pod has none. The cheapest proof: someone with the owner's sign-off runs
   "Upload Value Set Values" once from Scheduled Processes, against a throwaway value set the
   functional owner creates. We then read `definition` and `submit.argument*` from
   `ESS_REQUEST_HISTORY` / `ESS_REQUEST_PROPERTY`. If not, is the documented web service
   (route 3b) acceptable in place of an ESS job?
2. **Which UCM account?** Is `setup/functionalCoreSetup` the one to use? The process accepts any
   account FIN_IMPL can write to.
3. **How are value set definitions created?** The process only loads values. Should DMT create
   sets (through setup-data CSV import or REST once enabled), or require the functional owner to
   create them, making ValueSets a values-only object?
4. **Where does the run prefix go?** Prefixing `VALUE_SET_CODE` cannot work with an
   existing-set-only process. Move it to `Value`?
5. **What does the log say on failure?** We need to see the real log or result text of
   `valueSetValuesDataLoader` / `downloadProcessLogFile` for one BAD row before writing the
   per-row parser.
6. **Is a test-only value set acceptable?** Is a test-only value set on the demo pod an
   acceptable functional prerequisite for the GOOD/BAD regression rows?
