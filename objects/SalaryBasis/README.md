# SalaryBasis

## Status
Request-id reconciliation with per-row proof (backlog #292, 2026-10-08). See the
History section for the proof run.

## Pipeline
- Module: HCM
- HDL File: SalaryBasis.dat
- Loader Type: HDL (REST upload/submit/poll)
- UCM Account: hcm$/dataloader$/import$
- Fusion user: from the central credential lookup DMT_UTIL_PKG.GET_CEMLI_CREDENTIALS (hcm_impl)
- Standalone config object: no parent chain, no FK dependencies

## Keys (backlog #292)
- SourceSystemOwner: this DMT instance's owner from DMT_CONFIG_TBL (DMT_LOCAL / DMT_ATP), backlog #287.
- SourceSystemId: the TFM row's own TFM_SEQUENCE_ID. Nothing else references it
  (Salaries reference the basis by SalaryBasisName).
- SalaryBasisName: the run-prefixed source name; stays the business key and the
  "Verify in Fusion" key (salaryBases?q=SalaryBasisName=...).

## Reconciliation
- Report: `/Custom/DMT2/SalaryBases/DMT_SALARYBASES_RECON_V2_DM.xdm` (V1 stays deployed,
  never overwritten). Rows are selected by the HDL request id through
  HRC_DL_DATA_SET_BUS_OBJS / HRC_DL_FILE_LINES / HRC_DL_FILE_ROWS, joined to
  HRC_INTEGRATION_KEY_MAP on each row's own owner and id, returned only when the
  line finished LOADED_SUCCESS and the id exists in CMP_SALARY_BASES.
- LOADED only from that report, matched on the exact SourceSystemId (TFM id), stamped
  with FUSION_SALARY_BASIS_ID.
- FAILED from the HDL messages that name the row's exact SourceSystemId; whole-file
  messages last, only on rows still open.
- Single grain: no cross-grain propagation applies.

## V2 Audit: Attribute Name Corrections
| V2 Name (incorrect) | Correct Name |
|---------------------|-------------|
| AnnualizationFactor | SalaryAnnualizationFactor |

See `v2_audit.md` for full attribute audit details.

## Code References
- STG / TFM tables: `db/tables/dmt_sal_basis_stg_tbl.sql`, `db/tables/dmt_sal_basis_tfm_tbl.sql`
- Validator: `db/packages/dmt_sal_basis_validator_pkg.*`
- Transformer: `db/packages/dmt_sal_basis_transform_pkg.*`
- HDL Generator: `db/packages/dmt_sal_basis_hdl_gen_pkg.*`
- Results/Reconciliation: `db/packages/dmt_sal_basis_results_pkg.*`
- BIP: `bip/SalaryBases/`

## Regression Test Data (scripts/insert_regression_test_data.py, section 43a)
Copied from a real salary basis on the pod ("90262 DMT Annual Salary"), read-only.

| SOURCE_ID | SALARY_BASIS_NAME | ELEMENT_NAME | Expected |
|-----------|-------------------|--------------|----------|
| RT-SB-G1 | DMT RT Annual Basis | Regular Salary | LOADED |
| RT-SB-G2 | DMT RT Annual Basis 2 | Regular Salary | LOADED |
| RT-SB-BAD1 | DMT RT BAD Basis | DMT NONEXISTENT ELEMENT | FAILED (real ElementTypeId error) |

All rows: InputValueName Amount, SalaryBasisCode ANNUAL, SalaryAnnualizationFactor 1,
LegislativeDataGroupName "US Legislative Data Group".

## Lessons Learned
- The attribute is `SalaryAnnualizationFactor`, not `AnnualizationFactor`. The V2 template name is wrong.
- Standalone object: no dependency on Workers or any other object. Can be loaded independently.
- ElementName must match an existing payroll element. Invalid element names produce a clear Fusion error.

## History
- 2026-04-04: E2E LOADED confirmed on the frozen stack (2 good, 1 bad rejected).
- 2026-10-08: backlog #292 request-id proof report V2, TFM-id SourceSystemId, exact-key match, regression rows.
  Proof run 309 (prefix 93363, HDL request 10080103, scenario RegressionTest2610081435): RT-SB-G1 and
  RT-SB-G2 LOADED (SALARY_BASIS_ID 300000334948432 / 300000334948430), RT-SB-BAD1 FAILED with
  "You need to enter a valid value for the ElementTypeId attribute...", 0 unaccounted; HCM regression PASS.
