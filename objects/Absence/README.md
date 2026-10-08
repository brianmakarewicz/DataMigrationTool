# Absence

## Status
WORKING (2026-10-08, backlog #293). Proof run 312 (prefix 93366, scenario
RegressionTest2610081509): two GOOD absences LOADED with their own entry ids
(300000334959046, 300000334959089), the BAD absence FAILED with Fusion's own
error, 0 UNACCOUNTED, regression PASS.

## Pipeline
- Module: HCM (pipeline HCM, depends on Workers)
- HDL File: PersonAbsenceEntry.dat (NOT AbsenceEntry.dat, the old filename)
- Loader Type: HDL (REST upload/submit/poll)
- UCM Account: hcm$/dataloader$/import$
- Fusion user: from DMT_UTIL_PKG.GET_CEMLI_CREDENTIALS (hcm_impl); never put a password here
- **V1 format**: this object uses the V1 HDL attribute names, not V2

## Critical Notes
- **DAT filename**: `PersonAbsenceEntry.dat`; discriminator `PersonAbsenceEntry`
- **METADATA**: `SourceSystemOwner|SourceSystemId|PersonId(SourceSystemId)|Employer|AbsenceType|AbsenceStatus|ApprovalStatus|StartDate|EndDate|StartTime|EndTime|AbsenceReason|Comments`
- **SourceSystemOwner**: this DMT instance's owner (DMT_CONFIG_TBL HDL_SOURCE_SYSTEM_OWNER: DMT_LOCAL / DMT_ATP)
- **SourceSystemId**: the absence's own TFM sequence id (also stored in RECON_KEY). A person can carry several absences in one load.
- **PersonId(SourceSystemId)**: the person number of the Worker loaded by the Workers object (cross-object link, keeps the Workers key)
- **Employer** (V1 name, not `EmployerName`) comes from STG column `EMPLOYER_NAME`
- **ApprovalStatus** comes from STG column `APPROVAL_STATUS_CODE`. Every absence on the pod is AbsenceStatus `SUBMITTED` + ApprovalStatus `APPROVED`.
- PersonAbsenceEntry has no `Duration` attribute (only StartDateDuration / EndDateDuration); Fusion derives the duration. The attribute list is in the pod's `HRC_DL_BUS_OBJECT_ATTRS_VL`.

## Former blocker (resolved 2026-10-08): "conflicting processing and approval statuses"
In April every AbsenceStatus value failed with this error and the object was marked
instance-blocked. It was our file, not the pod: the generator sent AbsenceStatus without
ApprovalStatus. Sending `SUBMITTED` with ApprovalStatus `APPROVED` loads.

## Absence types
- `Bereavement` (US) loads for a worker DMT hires in the same run.
- `Vacation` (an accrual-plan type) is rejected for such a worker: "You can't add an absence
  because this person's assignment ... isn't enrolled in or eligible for any absence plan."
  DMT creates no plan enrollments (backlog #510).

## Reconciliation
- Report: `/Custom/DMT2/Absences/DMT_ABSENCES_RECON_V2_DM.xdm` (V1 stays deployed, never overwritten).
  Rows are selected by the HDL request id only, joined to HRC_INTEGRATION_KEY_MAP on each row's own
  owner and id (object PersonAbsenceEntry), and returned only when the line finished LOADED_SUCCESS
  and the entry exists in `ANC_PER_ABS_ENTRIES`. FUSION_ID = PER_ABSENCE_ENTRY_ID.
- Per-record HDL errors are matched on the exact SourceSystemId (the TFM id) and stored as
  `[FUSION_ERROR] <tfm id> (PersonAbsenceEntry.dat line n): <Fusion message>`.
- Verify in Fusion: `absences?q=personAbsenceEntryId=<FUSION_ABSENCE_ENTRY_ID>` (the resource only
  accepts camelCase attribute names).

## Code References
- STG / TFM tables: `db/tables/dmt_absence_stg_tbl.sql`, `db/tables/dmt_absence_tfm_tbl.sql`
- Validator: `db/packages/dmt_absence_validator_pkg.*` (no rules yet, backlog #511)
- Transformer: `db/packages/dmt_absence_transform_pkg.*`
- HDL Generator: `db/packages/dmt_absence_hdl_gen_pkg.*`
- Reconciliation: `db/packages/dmt_absence_results_pkg.*`, `bip/Absences/`

## Regression data
Scenario RegressionTest2610081509 (write-once, `scripts/insert_regression_test_data.py` section 45b),
all for worker RT-WKR-G1 hired in the same run:
- RT-ABS-G1: Bereavement 2026/03/02, expected LOADED
- RT-ABS-G2: Bereavement 2026/04/06 to 2026/04/07, expected LOADED
- RT-ABS-BAD1: absence type `BAD NONEXISTENT ABSENCE TYPE`, expected FAILED ("You need to enter a valid value for the AbsenceTypeId attribute")

## Lessons Learned
- This is a V1 format object. The HDL template version matters — V1 and V2 have different filenames, discriminators, and attribute names.
- The DAT filename `PersonAbsenceEntry.dat` is critical. Using `AbsenceEntry.dat` will cause the load to silently fail (0 rows processed).
- The STG table column is `EMPLOYER_NAME`, but the V1 DAT attribute is `Employer` (no "Name" suffix). The HDL generator must map EMPLOYER_NAME -> Employer in the DAT output.

## History
- 2026-04-04: All AbsenceStatus values tested. Every combination produces "conflicting processing and approval statuses" error. Object marked BLOCKED pending Fusion configuration investigation.
- 2026-10-08 (backlog #293): blocker traced to the missing ApprovalStatus attribute; recon report V2 by HDL request id; SourceSystemId = TFM id; Verify in Fusion fixed. Run 311 showed Vacation needs a plan enrollment; proof run 312 PASS.
