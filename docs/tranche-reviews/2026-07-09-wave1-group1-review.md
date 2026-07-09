# Blind Tranche Review — Wave-1 Group 1 (Customers, GLBalances, Projects, Workers) 2026-07-09

**Verdict: FAIL — on Customers alone.**

| Object | Verdict | Summary |
|--------|---------|---------|
| GLBalances | PASS | Reference-quality port: shared RUN_BIP_REPORT transport, Contract v1 params, XMLTABLE parsing, two-tier BASE/INTERFACE, no STG write-back, procedures-only. Minor: bip/ artifact still carries P_BATCH_ID + a duplicate .xdm + non-_RECON_ naming (package moved to v1, artifact lagged). |
| Projects | PASS-WITH-FINDINGS | Package conformant. Recorded gap: child record types (Tasks/TeamMembers/TxnControls) reconciled at INTERFACE tier only — LOADED with parent FUSION_PROJECT_ID, no child base id (platform limitation, xface tables purge). README documents it. Minor BIP naming lag. |
| Workers | PASS-WITH-FINDINGS | Object wrapper clean. All violations live in the SHARED DMT_HDL_UTIL_PKG (STG write-back; REGEXP JSON parsing; private UTL_HTTP + EXECUTE IMMEDIATE; missing positive-proof HDL reconciler) — honestly recorded in the Workers README as gaps the object cannot fix under shared-DB discipline. |
| Customers | FAIL | Reconciler NOT modernized: EXECUTE IMMEDIATE in package (dmt_cust_results_pkg.pkb:469), retired P_BATCH_ID (:147), private UTL_HTTP FUNCTION doing network (:19-73), non-Contract-v1 BIP model (CUST_DM.xdm) — AND README says "Known Issues: None" (concealment). Only the STG write-back was removed. |

## Dispositions
- **Customers: FIX NOW** — port its reconciler to the shared DMT_UTIL_PKG.RUN_BIP_REPORT (delete the private bip_soap_post function), replace the EXECUTE IMMEDIATE sweep with 7 static UPDATEs, move to Contract v1 params, rebuild the BIP data model to Contract v1 with the DMT_CUST_RECON_DM/_RPT naming + byte-matched mirror, and REWRITE the README Known Issues to the truth. Then re-run the Customers live gate + a Customers re-review. (This is the same modernization GLBalances/Projects already did.)
- **GLBalances BIP artifact lag: FIX** — regenerate bip/GLBalances data model to Contract v1 params + _RECON_ naming, drop the orphan duplicate .xdm, byte-match the mirror. Minor, bundle with the Customers fix or its own PR.
- **Projects / Workers findings: recorded gaps, no code change** — the interface-tier child reconciliation (Projects) and the shared-HDL-layer violations + missing HDL reconciler (Workers) are tracked. The shared DMT_HDL_UTIL_PKG modernization (write-back removal, JSON_TABLE parsing, shared transport, no EXECUTE IMMEDIATE) is its own dedicated work item — it serves 14 HDL objects.
- **Cross-cutting infra: DMT_BIP_REPORT_TBL lacks CONTRACT_VERSION/TFM_TABLE/FUSION_ID_COLUMN columns** — so no object can be registered CONTRACT_VERSION=1 yet. Tracked shared-infra item, part of the Contract v1 report-rework.

## Proposed rules: 2 (added red) — tightenings of existing rules.
