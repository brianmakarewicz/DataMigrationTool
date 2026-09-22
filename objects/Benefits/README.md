# Benefits

## Status
BLOCKED for live load — employee benefit enrollment is not configured for HDL load on
the demo instance (functional owner's domain, not a code defect). The DMT models below
are correct and doc-validated; each base table exists and is queryable live.

## Object model (CORRECTED 2026-09-22)
Benefits is THREE separate HCM Data Loader objects. Each is its own business object with
its OWN .dat file and discriminator. They are NOT one shared file. The earlier model
loaded all three as `PersonBenefitBalance.dat` under the `PersonBenefitBalance`
discriminator — that was the WRONG business object (benefit BALANCES, not enrollments)
and caused a three-way file-name collision in a single HDL run. Corrected to the proper
per-object business objects:

| DMT object    | Business object / discriminator | .dat file                    | Base table (Fusion)      | Fusion id           | Reconciliation match |
|---------------|---------------------------------|------------------------------|--------------------------|---------------------|----------------------|
| BenParticipant| **ParticipantEnrollment**       | ParticipantEnrollment.dat    | **BEN_PRTT_ENRT_RSLT**   | PRTT_ENRT_RSLT_ID   | prefixed PERSON_NUMBER via PER_ALL_PEOPLE_F (create-only, no SourceSystemId, no key map) |
| BenDependent  | **DependentEnrollment** (+ child **DesignateDependent**) | DependentEnrollment.dat | BEN_PRTT_ENRT_RSLT (via the designation) | designation id | HRC_INTEGRATION_KEY_MAP row OBJECT_NAME='DesignateDependent' |
| BenBeneficiary| **BeneficiaryEnrollment** (+ child **DesignateBeneficiary**) | BeneficiaryEnrollment.dat | benefit designation base | designation id | HRC_INTEGRATION_KEY_MAP (DesignateBeneficiary) |

- Module: HCM
- Loader Type: HDL (REST upload / submit / poll)
- Auth User: hcm_impl

## Oracle documentation authority
- HCM Data Loader benefits enrollment business objects (Participant / Dependent /
  Beneficiary Enrollment): Oracle "HCM Data Loading Business Objects" guide, incl.
  "Example of Loading Dependent Enrollments"
  https://docs.oracle.com/en/cloud/saas/human-resources/24d/fahbo/example-of-loading-dependent-enrollments.html
- Base table BEN_PRTT_ENRT_RSLT (Tables and Views for HCM, oedmh): identifies the plans
  or options a participant is enrolled in; PRTT_ENRT_RSLT_ID is the primary key.
  https://docs.oracle.com/en/cloud/saas/human-resources/oedmh/benprttenrtrslt-4213.html

## Why ParticipantEnrollment reconciles against the base table directly
ParticipantEnrollment is create-only and carries NO SourceSystemId, and Fusion registers
no HRC_INTEGRATION_KEY_MAP row for it. So reconciliation confirms each migrated worker
directly in BEN_PRTT_ENRT_RSLT (joined to PER_ALL_PEOPLE_F by PERSON_ID), matching on the
worker's prefixed PERSON_NUMBER and returning PRTT_ENRT_RSLT_ID as the Fusion id. RECON_KEY
= the prefixed PERSON_NUMBER (no suffix; the earlier `_BENENRL` suffix belonged to the old
PersonBenefitBalance SourceSystemId convention and is gone).

DependentEnrollment / BeneficiaryEnrollment DO register their child designations in
HRC_INTEGRATION_KEY_MAP (OBJECT_NAME='DesignateDependent' / 'DesignateBeneficiary'), so
those two reconcile via the key map.

## Live probes (from the re-model PRs; cred fin_impl)
- BEN_PRTT_ENRT_RSLT: ~38,411 enrollment results; reachable by name; PRTT_ENRT_RSLT_ID
  returns as FUSION_ID (e.g. person 39 -> 337499).
- BEN_PGM_F: 24 programs configured.
- HRC_INTEGRATION_KEY_MAP: DesignateDependent designations present for dependents.

## Code references (current layout)
- STG/TFM DDL: `db/tables/dmt_ben_partic_stg_tbl.sql` / `..._tfm_tbl.sql` (and the
  `dmt_ben_depend_*`, `dmt_ben_benfy_*` equivalents).
- Validators: `db/packages/dmt_ben_partic_validator_pkg.*` (+ depend / benfy).
- Transformers: `db/packages/dmt_ben_partic_transform_pkg.*` (+ depend / benfy).
- HDL generators: `db/packages/dmt_ben_partic_hdl_gen_pkg.*` (+ depend / benfy).
- Reconciliation: `db/packages/dmt_ben_partic_results_pkg.*` (+ depend / benfy).
- BIP recon models: `bip/BenParticipant/`, `bip/BenDependent/`, `bip/BenBeneficiary/`.
- Registry: `db/seed/dmt_bip_report_tbl.sql` (Contract v1 rows for each object).

## Known bad test data
| PERSON_NUMBER | Failure mode | Notes |
|---------------|--------------|-------|
| DMTW1BAD | Rejected enrollment | Correctly rejected by Fusion; the tool captures the real error, which is a success for reconciliation accounting. |

## History
- 2026-03/04: original model loaded all three as PersonBenefitBalance.dat (wrong object,
  file-name collision); load blocked by BenefitBalanceName LOV.
- 2026-09-22: re-modeled to the correct per-object HDL business objects
  (ParticipantEnrollment / DependentEnrollment / BeneficiaryEnrollment), each with its own
  .dat file and base-table reconciliation. Live end-to-end load remains environment-blocked
  (benefits not configured for load on the demo pod).
