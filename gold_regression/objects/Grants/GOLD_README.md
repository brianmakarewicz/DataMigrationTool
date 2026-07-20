# Grants (Award Mass Import) — Gold Regression Fixture

## Config-check finding (STEP 0) — the module IS configured

The status table previously marked Grants "⛔ module not configured on demo". **That block is
stale.** A read-only BIP survey of the demo pod on 2026-07-19 proves Grants/Awards is fully set
up today — the same story as Benefits (the old block was an upstream/setup artifact, not a
missing module).

Evidence gathered read-only through the BIP relay (`ApplicationDB_FSCM`, `fin_impl`):

| Check | Result |
|---|---|
| `GMS_AWARD_HEADERS_B` (award base table) | exists, **117 award rows** |
| `GMS_SPONSORS_V` (sponsors) | **35 sponsors** (National Science Foundation, Dept of Health and Human Services, Bond, ...) |
| `GMS_FUNDING_SOURCES_VL` | **52 funding sources** (Internal, Foundation, State, ...) |
| `GMS_AWARD_TEMPLATES_VL` (award templates) | present, e.g. University US = `VU Funded Award`, `VU Funded 3 Year`, `VU Funded 5 Year` |
| `GMS_BUSINESS_UNITS` (Grants BU setup) | **6 fully-configured BUs** — each row has `CONTRACT_TYPE_ID`, `IND_RATE_SCH_ID`, `INVOICE_METHOD_ID`, `REVENUE_METHOD_ID`, `BILLING_CYCLE_ID` populated. Configured BUs: University US (`300000093962136`), Progress US (`300000075888561`), Healthcare US (`300000078974743`), plus 3 more. |
| `GMS_AWARD_HEADERS_INT` (interface table) | exists, queryable, 0 pending rows |
| Existing awards join `OKC_K_HEADERS_ALL_B.ID = GMS_AWARD_HEADERS_B.ID` | award **number = OKC `CONTRACT_NUMBER`** (e.g. EPA0094, DHS1070, HHS-15-034) |

Because real awards, sponsors, templates and configured BUs already exist, the old
"requisite setup steps haven't been completed" error is no longer the state of the pod.
This fixture therefore proceeds to a live load.

## Object shape

Grants is ONE object: a single FBDI zip carrying several award record-type CSVs, loaded by one
ESS job (`AwardMassImportJob`). This fixture ships the two record types whose position layouts
are authoritative in the DMT FBDI metadata seed:

| Record type | FBDI CSV member | Columns |
|---|---|---|
| Award headers | `GmsAwardHeadersInterface.csv` | 124 |
| Award personnel (PI) | `GmsAwardPersonnelInterface.csv` | 61 |

The other 12 award sub-tables (funding, projects, terms, keywords, ...) are not required to
prove good→base / bad→rejection: an award is created from its header + a source template + a
Principal Investigator. Funding/project links can be added later.

## ESS orchestration (what actually runs)

The single SOAP call `loadAndImportData` on the ERP Integration service:

1. Base64-uploads the zip to UCM under document account `prj/grantsManagement/import`.
2. Runs "Load Interface File for Import" (SQL*Loader) to unpack each CSV into its interface
   table — `GMS_AWARD_HEADERS_INT`, `GMS_AWARD_PERSONNEL_INT`.
3. Chains the import job **`AwardMassImportJob`** with the ParameterList below.

The harness polls the returned **load** request id with `getESSJobStatus` every 60s to a
terminal status. No separate downstream `submitESSJobRequest` is needed — `AwardMassImportJob`
runs the award creation itself. Positive proof is the base read (good) and the interface
`PROCESSED_STATUS`/`PROCESSED_MESSAGE` (bad).

### Web-service call

| Field | Value |
|---|---|
| Endpoint | `<fusion_url>/fscmService/ErpIntegrationService` |
| Operation | `loadAndImportData` |
| Auth user | `fin_impl` |
| DocumentAccount | `prj/grantsManagement/import` |
| JobName | `/oracle/apps/ess/projects/grantsManagement/award,AwardMassImportJob` |
| interfaceDetails | `57` (the DMT `ERP_INTERFACE_OPTIONS_ID` for the Award object) |
| **ParameterList** | `#NULL,#NULL,#NULL` |

**ParameterList spelled out — `AwardMassImportJob` takes 3 optional positional arguments**
(award-number LOV bounds + a boolean). All three empty = process everything just loaded.
`#NULL` is used for each empty slot so positions don't collapse (a plain empty token would
shift the positional arguments). Source: the frozen-stack loader; the 2-arg form `NEW,N`
caused an indefinite ESS WAIT, fixed to the 3-arg `#NULL,#NULL,#NULL`.

## Discovery (portability — nothing hardcoded)

Run at load time via the read-only BIP relay against the TARGET pod (`fin_impl`). See
`recipe.json` for the exact SQL.

| Step | Finds | Tokens stamped | Proven value on demo pod |
|---|---|---|---|
| `GMS_TEMPLATE` | An award template in a fully-configured Grants BU (`GMS_BUSINESS_UNITS` row with a contract type). Prefers University US. | `${TEMPLATE_NUM}`, `${BU_ID}`, `${BU_NAME}` | `VU Funded 3 Year` / `300000093962136` / `University US Business Unit` |
| `GMS_SPONSOR` | An existing sponsor party. Prefers National Science Foundation. | `${SPONSOR_NAME}` | `National Science Foundation` |
| `GMS_PI` | An existing worker (lowest person number) with an ASCII display name + work email. | `${PI_NUMBER}`, `${PI_NAME}`, `${PI_EMAIL}` | `10` / `Mandy Steward` / `MANDY.STEWARD_...@oraclepdemos.com` |
| `AWARD_DATES` | Today and today + 12 months (award window). | `${AWD_START}`, `${AWD_END}` | current-run dates |

The award template is the key portability reference: its `TEMPLATE_NUMBER` (from
`GMS_AWARD_TEMPLATES_VL`) inherits the BU's contract type, invoice/revenue method and burden
schedule, so the header CSV needs only template + BU + sponsor + PI + dates.

## Good / bad rows

| Key | Kind | What makes it good/bad |
|---|---|---|
| `${PREFIX}RT-AWD-G1` | GOOD | Discovered template + BU + sponsor + PI, `CONTRACT_TYPE = Sell: Project Award Hard Limit`, award window today→+12mo, one PI personnel row (100% credit). |
| `${PREFIX}RT-AWD-G2` | GOOD | Same, second award. |
| `${PREFIX}RT-AWD-BAD1` | BAD | `SOURCE_TEMPLATE_NUMBER = ZZ-NO-SUCH-TEMPLATE`. Award Mass Import rejects it deterministically ("source template number isn't valid" / template not found) — it reaches `GMS_AWARD_HEADERS_INT` with an error and never creates an award. |

## Verification (read-only, direct single-table reads)

**GOOD → base table.** The award number is the OKC contract number, so a single-table read of
`OKC_K_HEADERS_ALL_B` by the run prefix proves the award was created:

```sql
SELECT h.contract_number AS AWARD_NUMBER, h.id AS AWARD_ID
FROM   okc_k_headers_all_b h
WHERE  h.contract_number LIKE :PREFIX || 'RT-AWD-%';
```

A row present with a real `AWARD_ID` = pass. (Confirmed the join model live: existing award id
`300000085818106` → contract_number `EPA0094`.)

**BAD → interface + absent from base.** The award interface keeps its rows keyed by load
request id with a status/message:

```sql
SELECT award_number AS AWARD_NUMBER,
       NVL(processed_message,
           'PROCESSED_STATUS=' || NVL(processed_status,'(null)') ||
           ' CODE=' || NVL(message_code,'(null)')) AS ERROR_MESSAGE
FROM   gms_award_headers_int
WHERE  load_request_id = :LRID;
```

The bad award appears here with a rejection status/message and is absent from
`OKC_K_HEADERS_ALL_B`.

## The three data-quality gates (each found live, from the interface PROCESSED_MESSAGE)

The award import validates rows AFTER the SQL*Loader load, inside an asynchronous award
service (`processAwardImportAsync`). The interface rows carry the real rejection reason in
`GMS_AWARD_HEADERS_INT.PROCESSED_MESSAGE` / `MESSAGE_CODE` for roughly 30 seconds, then the
interface is purged (accepted and rejected rows both). Each failed attempt below was read
live from that window and fixed:

1. **Date format (ORA-01843 "not a valid month").** The header CTL parses `AWARD_START_DATE`
   / `AWARD_END_DATE` as `MM/DD/YYYY`. First attempt used `YYYY/MM/DD` → SQL*Loader rejected
   all rows into the `.bad` file, so the load job went to ERROR and never reached the import.
   Fix: discovery emits dates as `MM/DD/YYYY`.
2. **PI eligibility (`GMS_PPL_NOT_PI_ELIG` — "One or more persons aren't eligible for the
   principal investigator role").** A generic lowest-person-number worker (Mandy Steward #10)
   is not an eligible PI. Fix: discover a person from `GMS_PERSONS` where `ELIGIBLE_PI='Y'`
   (e.g. Sean Murphy #1171).
3. **Budget periods (`GMS_BP_ONE_EXISTS` / `GMS_BP_CAFT_ISSUE` — "You must enter the budget
   periods manually. You must define at least one budget period").** Award Mass Import does
   NOT auto-generate budget periods from the template; the FBDI must carry a
   `GmsAwardBudgetPeriodsInterface.csv`. Fix: added that CSV (AWARD_NUMBER, BUDGET_PERIOD name,
   START_DATE, END_DATE) with one yearly period per good award spanning the award window, and
   the template discovery prefers `BUDGET_PERIOD_COUNT = 1` (e.g. `VU Funded Award`) so one
   period matches the one-year award window.

After these three fixes the BAD row still fails deterministically as intended, with
`GMS_CAFT_SVC_INVALID_AWD_TEMPL` — "The award template doesn't exist or isn't valid" — for
its `SOURCE_TEMPLATE_NUMBER = ZZ-NO-SUCH-TEMPLATE`.

## Current status (2026-07-20): fixture built + all validations cleared; base confirmation pending ESS queue

- Config: CONFIRMED present (evidence above).
- Two-CSV attempts (prefixes 90505, 90506, 90507): good rows reached `GMS_AWARD_HEADERS_INT`
  and the exact rejection reasons were captured live, driving each of the three fixes.
- BAD row: reproducibly rejected with `GMS_CAFT_SVC_INVALID_AWD_TEMPL`, absent from base.
- Three-CSV attempts (prefixes 90508 / load `9764802`, 90510 / load `9765110`): the load with
  the added budget-periods CSV was submitted correctly but sat in ESS status `WAIT` for
  20+ minutes without the scheduler picking it up — an ESS scheduler backlog on the pod at the
  time of this session, NOT a fixture defect (the earlier two-CSV loads ran WAIT→SUCCEEDED in
  60s). The base-table confirmation of the two good awards in `OKC_K_HEADERS_ALL_B` is
  therefore pending a run where the load leaves `WAIT`.

### To finish (re-run when the pod's ESS queue is moving)

```bash
cd gold_regression/harness
python run_object.py Grants        # fresh prefix; discovery + build + load + verify
```

Watch the interface during the ~30s processing window and the base afterwards:
- good `${PREFIX}RT-AWD-G1/G2` → `OKC_K_HEADERS_ALL_B.contract_number` with a real award id;
- bad `${PREFIX}RT-AWD-BAD1` → `GMS_AWARD_HEADERS_INT` `GMS_CAFT_SVC_INVALID_AWD_TEMPL`, absent
  from base.

Once the load leaves `WAIT` and the two good awards appear in `OKC_K_HEADERS_ALL_B`, record the
prefix, load request id, and award ids here and flip the status-table row to proven.

## How to re-run

```bash
cd gold_regression/harness
python run_object.py Grants                 # fresh random prefix
python run_object.py Grants --prefix 90501
```

Exit code 0 and `"pass": true` when 2 good awards reach `OKC_K_HEADERS_ALL_B` and the bad row
is rejected in `GMS_AWARD_HEADERS_INT` + absent from base.
