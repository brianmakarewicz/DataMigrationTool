# Workers

## Status
E2E LOADED — ALL 10 COMPONENTS (3L/0F, prefix 9210, 2026-04-04 DB-20)

## Pipeline
- Module: HCM
- HDL File: Worker.dat
- Loader Type: HDL (REST upload/submit/poll)
- UCM Account: hcm$/dataloader$/import$
- Auth User: hcm_impl (password: m?CDa6^6)

## Components

### Mandatory (all 5 required for a successful hire)
1. **Worker** — top-level person record
2. **PersonName** — GLOBAL name type required
3. **WorkRelationship** — employment relationship (HIRE action)
4. **WorkTerms** — employment terms (DateStart attribute required in addition to EffectiveStartDate)
5. **Assignment** — job assignment details

### Optional (ALL E2E LOADED 2026-04-04 DB-20)
6. **PersonEmail** — requires `DateFrom` (use Worker StartDate)
7. **PersonPhone** — requires `LegislationCode` + `DateFrom`; AreaCode separate from 7-digit PhoneNumber
8. **PersonAddress** — requires `EffectiveStartDate`
9. **PersonNID** — SSN must be 9 digits WITHOUT hyphens (111223333 not 111-22-3333)
10. **PersonLegislativeData** — requires `EffectiveStartDate`

## SourceSystemId Convention
| Component | Suffix | Example |
|-----------|--------|---------|
| Worker | (none) | PERSON_NUMBER |
| PersonName | _NME | DMTW001_NME |
| WorkRelationship | _POS | DMTW001_POS |
| WorkTerms | _TRM | `<AssignmentNumber>_TRM` (e.g. ET-RT-WKR-G1_TRM) |
| Assignment | _ASG | `<AssignmentNumber>_ASG` (e.g. ET-RT-WKR-G1_ASG) |
| PersonEmail | _EML | DMTW001_EML |
| PersonPhone | _PHN | DMTW001_PHN |
| PersonAddress | _ADR | DMTW001_ADR |
| PersonNID | _NID | DMTW001_NID |
| PersonLegislativeData | _LEG | DMTW001_LEG |

**WorkTerms and Assignment are keyed by the SOURCE assignment number, not the
person.** The Worker load has no assignment number of its own, so it sources one
from the Assignment object's rows (joined by PERSON_NUMBER) and emits one
WorkTerms + one Assignment per assignment. The Assignment object builds the same
`<AssignmentNumber>_TRM` / `<AssignmentNumber>_ASG` keys from the same field, so
the two loads never collide on the shared assignment id, and one person can carry
multiple assignments with distinct keys. A worker with no matching assignment row
fails the worker validator (rule R3) — the number is never fabricated.

## V2 Audit — Invalid Attributes
These attributes exist in the V2 template but are rejected by the Fusion REST API. The HDL generator must exclude them.

| Component | Invalid Attribute | Notes |
|-----------|-------------------|-------|
| Worker | LegalEntityName | Use LegalEmployerName on WorkRelationship instead |
| PersonName | DisplayName | Auto-derived by Fusion |
| WorkRelationship | EffectiveStartDate | Use DateStart only |
| WorkRelationship | EffectiveEndDate | |
| PersonEmail | EffectiveStartDate | |
| PersonEmail | EffectiveEndDate | |
| PersonPhone | EffectiveStartDate | |
| PersonPhone | EffectiveEndDate | |
| PersonNID | EffectiveStartDate | |
| PersonNID | EffectiveEndDate | |

See `v2_audit.md` for full attribute audit details.

## Code References
- STG Table DDL (Worker): `schema/tables/96_dmt_worker_stg_tbl.sql`
- TFM Table DDL (Worker): `schema/tables/97_dmt_worker_tfm_tbl.sql`
- STG Table DDL (PersonName): `schema/tables/98_dmt_person_name_stg_tbl.sql`
- TFM Table DDL (PersonName): `schema/tables/99_dmt_person_name_tfm_tbl.sql`
- STG Table DDL (PersonEmail): `schema/tables/100_dmt_person_email_stg_tbl.sql`
- TFM Table DDL (PersonEmail): `schema/tables/101_dmt_person_email_tfm_tbl.sql`
- STG Table DDL (PersonPhone): `schema/tables/102_dmt_person_phone_stg_tbl.sql`
- TFM Table DDL (PersonPhone): `schema/tables/103_dmt_person_phone_tfm_tbl.sql`
- STG Table DDL (PersonAddress): `schema/tables/104_dmt_person_addr_stg_tbl.sql`
- TFM Table DDL (PersonAddress): `schema/tables/105_dmt_person_addr_tfm_tbl.sql`
- STG Table DDL (PersonNID): `schema/tables/106_dmt_person_nid_stg_tbl.sql`
- TFM Table DDL (PersonNID): `schema/tables/107_dmt_person_nid_tfm_tbl.sql`
- STG Table DDL (PersonLegislative): `schema/tables/108_dmt_person_legisl_stg_tbl.sql`
- TFM Table DDL (PersonLegislative): `schema/tables/109_dmt_person_legisl_tfm_tbl.sql`
- STG Table DDL (WorkRelationship): `schema/tables/110_dmt_work_rel_stg_tbl.sql`
- STG Table DDL (Assignment): `schema/tables/112_dmt_assignment_stg_tbl.sql`
- Validator: `packages/validators/dmt_worker_validator_pkg.*`
- Transformer: `packages/transformers/dmt_worker_transform_pkg.*`
- HDL Generator: `packages/generators/hdl/dmt_worker_hdl_gen_pkg.*`
- Results/Reconciliation: `packages/reconciliation/dmt_worker_results_pkg.*`

## Known Good Test Data (E2E LOADED prefix 9210)
| Component | Field | Value |
|-----------|-------|-------|
| Worker | PERSON_NUMBER | DMTW101, DMTW102 |
| Worker | DATE_OF_BIRTH | 1985/03/15, 1990/07/22 |
| Worker | ACTION_CODE | HIRE |
| Worker | START_DATE | 2026/01/01 |
| Worker | LEGAL_ENTITY_NAME | US1 Legal Entity |
| PersonName | LEGISLATION_CODE | US |
| PersonName | NAME_TYPE | GLOBAL |
| WorkRelationship | WORKER_TYPE | E |
| PersonEmail | EMAIL_TYPE | W1 |
| PersonPhone | PHONE_TYPE | W1 |
| PersonPhone | COUNTRY_CODE_NUMBER | 1 |
| PersonPhone | AREA_CODE | 555 |
| PersonPhone | PHONE_NUMBER | 1234567 (7 digits — NOT 10) |
| PersonAddress | ADDRESS_TYPE | HOME |
| PersonAddress | COUNTRY | US |
| PersonNID | NATIONAL_IDENTIFIER_TYPE | SSN |
| PersonNID | NATIONAL_IDENTIFIER_NUMBER | 111223333 (NO hyphens) |
| PersonLegislativeData | SEX | F, M |
| PersonLegislativeData | MARITAL_STATUS | S, M |

## Known Bad Test Data
| PERSON_NUMBER | Failure Mode | Notes |
|---------------|-------------|-------|
| DMTW1BAD | No DOB, no optional components | Loads anyway — DOB is optional. Useful for pipeline validation. |

## Lessons Learned
- WorkTerms is generated internally (no separate STG table) but needs **DateStart** as a distinct attribute — EffectiveStartDate alone is not sufficient.
- All 5 mandatory components must be present in a single Worker.dat for a successful hire. Missing any one causes the entire worker to fail.
- Optional components can be omitted entirely — they are not required for a hire to succeed.
- **PersonPhone** requires `LegislationCode` in METADATA to disambiguate `CountryCodeNumber=1` (maps to both US and CA). Generator derives LegislationCode from the PersonNID table. Also requires `DateFrom`.
- **PersonPhone** format: PhoneNumber must be exactly 7 digits. Area code goes in the separate `AreaCode` field. Sending 10 digits in PhoneNumber causes "enter the person's 7-digit number" error.
- **PersonEmail** requires `DateFrom` in METADATA — Fusion rejects without it. Generator derives from Worker START_DATE.
- **PersonNID** SSN must be 9 digits without hyphens (111223333). Hyphens cause Fusion load errors.
- DOB is technically optional — DMTW-BAD loads successfully even without it.
- Any optional component failure causes the ENTIRE worker to fail (all components in one Worker.dat upload).
- The V2 template contains several attributes that the Fusion REST API rejects. These must be stripped from the DAT output.
- **Phone AREA_CODE must be populated separately from PHONE_NUMBER.** The regression data had AREA_CODE=NULL and PHONE_NUMBER='5551234567' (10 digits). Fusion requires exactly 7 digits in PhoneNumber with AreaCode separate. Fixed by splitting: AREA_CODE=SUBSTR(1,3), PHONE_NUMBER=SUBSTR(4). Result: Workers 0L/42F → 19L/19F.
- **SalaryBasis has duplicate detection.** "You can't supply multiple data lines for the same record" — SalaryBasis names (DMT Test Hourly, etc.) persist across runs. Each regression run creates new TFM rows but uses the same SalaryBasis names, causing duplicates.

## History
- 2026-04-04 (DB-19): E2E LOADED — 3/3 workers with mandatory 5 components. Optional components blocked by phone data quality.
- 2026-04-04 (DB-20): **E2E LOADED — ALL 10 COMPONENTS.** Fixed Phone (LegislationCode, DateFrom, 7-digit), Email (DateFrom), NID (no hyphens). 3L/0F with prefix 9210.
- 2026-04-07 (DB-27): **Phone fix + duplicate cleanup.** Workers 0L/42F → 19L/19F. Phone AREA_CODE split from PHONE_NUMBER. STG duplicates deleted. 3 Workers + 3 PersonNames + 2 each of Email/Phone/Address/NID/Legislation + 2 Salaries + 1 TalentProfile = 19 LOADED.

## Offline build (obj/workers-offline, 2026-07-09)

Six-step offline recipe built and proven on dmt2-local (no Fusion). Results:

- **Identity conversion (accepted rule 2026-07-08):** the 7 Workers-owned STG/TFM
  table pairs (worker + person_name/email/phone/addr/nid/legisl = 14 tables)
  converted from sequence-default PKs to `GENERATED ALWAYS AS IDENTITY`, using the
  empty-table drop-and-recreate template from the Suppliers tables. All 14 now pass
  `db/tools/check_column_dictionary.sql` (no longer sanctioned deferrals). The
  transformer's explicit `..._TFM_SEQ.NEXTVAL` inserts were removed (an identity
  column rejects an explicit value, ORA-32795). WorkRelationship and Assignment
  tables were left unconverted — they belong to the separate Assignments object
  (catalog #26), not Workers, and the Worker generator does not read them.
- **Golden inputs:** `test/golden/inputs/Workers*_input.csv` (7 files) reproduce the
  run-116 HCM regression rows (2 GOOD DMTW001/DMTW002 with all components + 1 BAD
  DMTW-BAD, mandatory-5 only). Source of record: the frozen repo's
  `scripts/insert_hcm_regression_data.py` (NOT `insert_regression_test_data.py`,
  which has no Worker rows).
- **Golden compare — HDL mode added:** `test/golden/compare_fbdi.py` gained a
  `format: "hdl_dat"` member mode (pipe-delimited METADATA/MERGE lines, LF-terminated,
  not quoted CSV) plus `$PREFIX`/`$RUN_ID` substitution inside literal tokens.
  `normalization_map.json` has a Workers entry (member Worker.dat) with two declared
  tokens: `{PREFIX}` (startswith on the run prefix) and `{ET_PREFIX}` (substring
  `ET-<prefix>` for the WorkTerms AssignmentName/Number). **VERDICT: Worker.dat is
  byte-identical to the golden after those two declared tokens — no other diff.**
- **Determinism fix:** the transformer's `INSERT..SELECT` had no `ORDER BY`, so
  identity assignment order (and thus the generator's `ORDER BY TFM_SEQUENCE_ID` line
  order) was not guaranteed run-to-run — one golden run in ~6 produced a reordered
  Worker section. Added `ORDER BY s.STG_SEQUENCE_ID` to all 7 transform inserts;
  5/5 consecutive golden runs then byte-identical.
- **Validator:** `VALIDATE_PRE_TRANSFORM` was a stub. Added two offline structural
  rules (PERSON_NUMBER required; ACTION_CODE in HIRE/ADD_CWK), tagging a failing STG
  row FAILED with an appended `[PRE_VALIDATION]` message (accumulate, never
  overwrite). The unit test's BAD row uses ACTION_CODE=TERMINATE (a validator
  failure), distinct from the golden's DMTW-BAD (missing DOB is optional and loads).
- **Unit suite:** `test/unit/test_workers.sql`, 26 assertions, all green — land,
  validate-alone (GOOD pass / BAD tagged), transform-alone (prefix on TFM, STG
  untouched, idempotent), HDL generate (Worker.dat METADATA/MERGE + auto-generated
  WorkTerms).

### Reconciler audit (accepted-rule violations) — TRACKED, shared-layer

The Workers results package `DMT_WORKER_RESULTS_PKG` is itself clean: no
write-back-to-staging, no STG-status='LOADED' read, no INSTR/SUBSTR parsing, no
P_BATCH_ID. It only calls the shared `DMT_HDL_UTIL_PKG`. The violations below live
in that SHARED HDL loader (used by all 14 HDL objects), so they are NOT fixed in this
Workers-object PR — they need a dedicated shared-layer change (other object agents
run concurrently against the same package):

- **Write-back-to-staging + STG-status='LOADED' (violation).**
  `DMT_HDL_UTIL_PKG.RECONCILE_HDL` "Step 3: Echo to STG tables"
  (`db/packages/dmt_hdl_util_pkg.pkb.sql:504-526`) issues
  `UPDATE <p_stg_table> SET STG_STATUS='LOADED'` / `'FAILED'`. This both writes back
  to staging and sets a staging status of LOADED — two accepted-rule violations. Fix
  belongs in the shared package (remove the STG echo; TFM is the sole run-outcome
  record).
- **REST-inside-a-FUNCTION (violation).** `REST_HTTP`, `UPLOAD_HDL`, `SUBMIT_HDL`,
  `GET_HDL_ERRORS` are FUNCTIONs performing UTL_HTTP network calls
  (`db/packages/dmt_hdl_util_pkg.pkb.sql`). The accepted rule is procedures-only for
  network work. Shared-layer fix.
- **Positive-proof-of-load reconciler is a to-build gap (not invented here).** Per
  DMT_DESIGN.html, HDL objects have no Contract v1 reconciliation report yet (the
  BIP-registry "—" cells are backlog). Today HDL LOADED is inferred from the dataset
  status + the absence of a per-record HDL failure message; the design's required
  base-tier proof (key + Fusion id from HCM base tables, one bulk BIP call) is not yet
  built for Workers. `LOOKUP_FUSION_IDS` does a per-record REST lookup that the design
  explicitly rejected at conversion volume ("retires"). These are tracked gaps for the
  live (Rule #1) phase, not offline scope.

## Minimal Worker test-data plan (2026-07-15)

Goal: seed the smallest STG row set that loads ONE real Worker to the Fusion HCM base
tables (PER_ALL_PEOPLE_F / PER_ALL_ASSIGNMENTS_M) via HDL, plus ONE clearly-bad row.
The HCM regression currently has NO Worker rows in `scripts/insert_regression_test_data.py`,
so HCM cannot be proven. This section scopes exactly what to add. It is a proposal —
no code or seed file was changed.

### What the generator actually reads (minimal footprint)

`db/packages/dmt_worker_hdl_gen_pkg.pkb.sql` reads the TFM tables, which the transformer
(`dmt_worker_transform_pkg`) fills 1:1 from the matching STG tables. Only **two STG tables
are required** for a loadable hire:

- **DMT_WORKER_STG_TBL** — drives the Worker, WorkRelationship, WorkTerms and Assignment
  sections. WorkRelationship/WorkTerms/Assignment are auto-generated from each Worker row;
  there is no separate STG table to populate for them. (DMT_WORK_REL_STG_TBL and
  DMT_ASSIGNMENT_STG_TBL belong to the separate Assignments object, catalog #26, and are
  NOT read by the Worker generator.)
- **DMT_PERSON_NAME_STG_TBL** — drives the PersonName section (GLOBAL name is mandatory
  for a hire).

The other five person tables (email, phone, address, NID, legislative) are **optional** —
each section is emitted only if rows exist. The minimal loadable worker omits all five.

Required columns actually consumed by the generator:

| STG table | Column | Used for | Note |
|---|---|---|---|
| DMT_WORKER_STG_TBL | PERSON_NUMBER | Worker SourceSystemId + PersonNumber; parent key for every other section | required by validator |
| DMT_WORKER_STG_TBL | START_DATE | hire date; WorkRelationship DateStart, WorkTerms/Assignment EffectiveStartDate | YYYY/MM/DD |
| DMT_WORKER_STG_TBL | EFFECTIVE_START_DATE | Worker EffectiveStartDate (falls back to START_DATE if null) | YYYY/MM/DD |
| DMT_WORKER_STG_TBL | ACTION_CODE | Worker/WorkTerms/Assignment ActionCode | must be HIRE or ADD_CWK (validator R2) |
| DMT_WORKER_STG_TBL | DATE_OF_BIRTH | Worker DateOfBirth | optional (BAD row can omit) |
| DMT_WORKER_STG_TBL | LEGAL_ENTITY_NAME | WorkRelationship LegalEmployerName | MUST match a real legal employer name |
| DMT_PERSON_NAME_STG_TBL | PERSON_NUMBER | joins the name to the worker | must equal the Worker PERSON_NUMBER |
| DMT_PERSON_NAME_STG_TBL | NAME_TYPE | PersonName NameType | use GLOBAL (defaults to GLOBAL if null) |
| DMT_PERSON_NAME_STG_TBL | LEGISLATION_CODE | PersonName LegislationCode | US |
| DMT_PERSON_NAME_STG_TBL | LAST_NAME | PersonName LastName | required |
| DMT_PERSON_NAME_STG_TBL | FIRST_NAME | PersonName FirstName | required |

Values NOT taken from STG (hardcoded in the generator, so no STG column needed): WorkerType
`E`, AssignmentStatusTypeCode `ACTIVE_PROCESS`, PersonTypeCode `Employee`, and
BusinessUnitShortCode from named config `WORKER_DEFAULT_BU_NAME` (seeded value
`US1 Business Unit`).

### Real reference values to mimic (verified live on the demo instance, hcm_impl)

Confirmed against a real active employee, PersonNumber `10` (Mandy Steward):

| Reference value | Live value | How verified |
|---|---|---|
| Legal employer name | **US1 Legal Entity** | assignment legal_entity_id 300000046974965 → HR_ORGANIZATION_UNITS_F_TL |
| Business unit | **US1 Business Unit** | assignment business_unit_id 300000046987012 → HR_ORGANIZATION_UNITS_F_TL |
| Assignment status | ACTIVE | PER_ALL_ASSIGNMENTS_M.assignment_status_type |
| System person type | EMP (Employee) | PER_ALL_ASSIGNMENTS_M.system_person_type |
| Legislation | US | PersonName/NID convention; instance is a US legislative install |
| Example job on this LE | Data Steward Manager | job_id 300000047624120 → PER_JOBS_F_TL (not needed for the minimal load) |

The two values that matter for the minimal load are **US1 Legal Entity** (WorkRelationship
LegalEmployerName) and **US1 Business Unit** (Assignment BU, already the config default).
Both are live-verified and both already match the frozen-stack known-good data — so no
config change is needed.

Queries used (read-only, tiny result sets):

```
-- real workers (person number + name)
SELECT p.person_number, n.first_name, n.last_name
FROM per_all_people_f p, per_person_names_f n
WHERE n.person_id=p.person_id AND n.name_type='GLOBAL'
AND SYSDATE BETWEEN p.effective_start_date AND p.effective_end_date
AND SYSDATE BETWEEN n.effective_start_date AND n.effective_end_date AND ROWNUM<=5;
-- → 10 Mandy Steward, 13 Marion MarketingMgr, 39 Aakash Sharma, 44 Bala Gupta, 48 Matthew Schnieder

-- assignment reference ids for person 10
SELECT p.person_number, TO_CHAR(a.effective_start_date,'YYYY/MM/DD'),
       a.assignment_status_type, a.system_person_type,
       a.business_unit_id, a.legal_entity_id, a.job_id
FROM per_all_assignments_m a, per_all_people_f p
WHERE a.person_id=p.person_id AND p.person_number='10'
AND a.assignment_type='E' AND a.primary_flag='Y'
AND SYSDATE BETWEEN a.effective_start_date AND a.effective_end_date
AND SYSDATE BETWEEN p.effective_start_date AND p.effective_end_date AND ROWNUM<=3;
-- → ESD 2007/11/05, ACTIVE, EMP, BU 300000046987012, LE 300000046974965, JOB 300000047624120

-- resolve legal employer name
SELECT otl.name FROM hr_org_unit_classifications_f c, hr_organization_units_f_tl otl
WHERE c.organization_id=otl.organization_id AND otl.language='US'
AND c.classification_code='HCM_LEMP' AND c.organization_id=300000046974965;  -- → US1 Legal Entity

-- resolve business unit name
SELECT otl.name FROM hr_organization_units_f_tl otl
WHERE otl.language='US' AND otl.organization_id=300000046987012;             -- → US1 Business Unit
```

### Proposed seed rows

Person numbers use a distinctive source id (`RT-WKR-G1`, etc.). The regression run applies
a numeric prefix at transform time, so the loaded PersonNumber will be `<prefix>RT-WKR-G1` —
no collision with the real `10`/`13`/etc. and no collision with the frozen-stack `DMTW*`
data. Dates are YYYY/MM/DD. All amounts/codes below are live-verified or generator-hardcoded.

**GOOD worker** — reaches PER_ALL_PEOPLE_F + PER_ALL_ASSIGNMENTS_M:

DMT_WORKER_STG_TBL (1 row):
- PERSON_NUMBER = `RT-WKR-G1`
- ACTION_CODE = `HIRE`
- START_DATE = `2026/01/01`
- EFFECTIVE_START_DATE = `2026/01/01`
- DATE_OF_BIRTH = `1985/03/15`
- LEGAL_ENTITY_NAME = `US1 Legal Entity`
- SOURCE_ID = `RT-WKR-G1`, SCENARIO_ID = RegressionTest scenario id, STG_STATUS = `NEW`

DMT_PERSON_NAME_STG_TBL (1 row):
- PERSON_NUMBER = `RT-WKR-G1`
- NAME_TYPE = `GLOBAL`
- LEGISLATION_CODE = `US`
- LAST_NAME = `Tester`
- FIRST_NAME = `Regina`
- SOURCE_ID = `RT-WKR-G1`, SCENARIO_ID = scenario id, STG_STATUS = `NEW`

**BAD worker** — fails our validator with a reportable error (does NOT reach Fusion):

DMT_WORKER_STG_TBL (1 row):
- PERSON_NUMBER = `RT-WKR-B1`
- ACTION_CODE = `TERMINATE`  ← not in (HIRE, ADD_CWK); validator R2 tags STG_STATUS=FAILED
  with `ACTION_CODE TERMINATE is not a supported worker action (HIRE, ADD_CWK).`
- START_DATE = `2026/01/01`, EFFECTIVE_START_DATE = `2026/01/01`
- LEGAL_ENTITY_NAME = `US1 Legal Entity`
- SOURCE_ID = `RT-WKR-B1`, SCENARIO_ID = scenario id, STG_STATUS = `NEW`
- (no PersonName row needed — the row never leaves validation)

This BAD row is caught by OUR validator before any HDL call (a clean, deterministic
FAILED-with-error). An alternative BAD row that reaches Fusion and fails there would be a
missing GLOBAL PersonName, but that is less deterministic to report; ACTION_CODE=TERMINATE
is the recommended bad case. (Note: the frozen stack's `DMTW-BAD` — missing DOB only —
LOADS successfully because DOB is optional, so it is NOT a valid bad row for Rule #1.)

### Risks / prerequisites

- **Reference data already exists — no prerequisite setup needed.** `US1 Legal Entity` and
  `US1 Business Unit` are live on the instance and already the seeded config default. A US
  legislative install is present (real US workers exist). This worker does NOT need any
  setup we cannot provide from data.
- **The generator hardcodes the assignment shape** (status ACTIVE_PROCESS, person type
  Employee, worker type E). These are valid on this instance (person 10 is ACTIVE/EMP), so
  the GOOD row should hire cleanly. If Fusion later rejects `ACTIVE_PROCESS`, that is a
  generator concern, not a test-data concern.
- **Rule #1 proof is a separate gap.** Even after the GOOD worker loads, the Workers object
  has no base-table BIP reconciliation report yet (tracked above under "Reconciler audit").
  Confirming the GOOD worker reached PER_ALL_PEOPLE_F / PER_ALL_ASSIGNMENTS_M will, until
  that report exists, be a manual BIP query on person_number `<prefix>RT-WKR-G1`.
- **PersonNumber uniqueness across re-runs** is handled by the run prefix; never reuse a
  prefix (existing rule). The source ids `RT-WKR-G1` / `RT-WKR-B1` are stable; the prefix
  makes each run's PersonNumber unique.
