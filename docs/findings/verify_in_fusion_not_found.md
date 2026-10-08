# "Verify in Fusion" returns NOT_FOUND for records that exist: Requisitions, BlanketPOs, Grants

Research date 2026-10-07, against local Docker `dmt2-local` (runs 242, 251 and 253), the demo pod
`fa-esew-dev28-saasfademo1`, and a read-only look at ATP `DMT2_OWNER`. No code was changed. Passwords
are redacted throughout. Every REST call below was made with the same credential source DMT uses:
`DMT_CONFIG_TBL` for `fin_impl`, and `DMT_ERP_INTERFACE_OPTIONS_TBL.FUSION_USERNAME/PASSWORD` for the
per-object load users. Both stores were checked to match `connections.json`.

## How the verify call is built (shared by all three objects)

The console and the regression harness make the same call:

- The page-57 button (`apex/f501src/livedmt2/pages/p00057-record-detail.apx`, process
  `QUERY_FUSION_REST`) calls `DMT_REST_QUERY_PKG.QUERY_FUSION_RECORD(sub_object, display_key,
  tfm_seq_id, lookup_key || display_key)`.
- `scripts/dmt_regression_run.py` `rest_spot_check` makes the same call, using the newest
  LOADED row per sub-object from `DMT_RECORD_DETAIL_V`. It maps any message containing `404` or
  `not found` to NOT_FOUND.
- `DMT_REST_QUERY_PKG.QUERY_FUSION_RECORD` calls `DMT_REST_LOOKUP_PKG.LOOKUP_RECORD` with the
  LOOKUP_KEY. If the result says "not found", it retries with the DISPLAY_KEY, using the same
  filter.
- `DMT_REST_LOOKUP_PKG.LOOKUP_RECORD` resolves the `DMT_REST_LOOKUP_TBL` row: an exact match on the
  sub-object label first, then the object code. It builds
  `{FUSION_URL}{REST_ENDPOINT}?onlyData=true&limit=1&q={QUERY_FILTER with {KEY} replaced}` and
  sends it with Basic auth for:
  1. `DMT_CONFIG_TBL` `<ObjectCode>_USERNAME/_PASSWORD`, if that row exists;
  2. otherwise `HCM_USERNAME` when `AUTH_TYPE='HCM'`;
  3. otherwise `FUSION_USERNAME` (fin_impl).

  **The lookup never reads `DMT_ERP_INTERFACE_OPTIONS_TBL.FUSION_USERNAME`, which is the per-object
  user the load runs as** (see `DMT_UTIL_PKG.GET_CEMLI_CREDENTIALS`).

What the package returns today, reproduced on local Docker with `SELECT
DMT_REST_QUERY_PKG.QUERY_FUSION_RECORD(...) FROM DUAL`:

| Sub-object | Key passed | Result |
|---|---|---|
| Req Headers | 143976 (display key 93307RT-REQ-001) | `REST call failed: ORA-20003: HTTP GET failed. Status: 500 \| URL: .../purchaseRequisitions?onlyData=true&limit=1&q=RequisitionHeaderId=93307RT-REQ-001` |
| Req Lines | 93307RT-REQ-001 | `Record not found in Fusion for Req Lines = 251_RQLN_100000228` |
| Req Distributions | 93307RT-REQ-001 | `Record not found in Fusion for Req Distributions = 251_RQDIST_100165557` |
| Blanket PO Headers | 93309RT-BPA-XG2 | `Record not found in Fusion for Blanket PO Headers = 93309RT-BPA-XG2` |
| Blanket PO Lines | 93309RT-BPA-XG2 | `Record not found in Fusion for Blanket PO Lines = 253_LN_100001017` |
| Award Headers | 93298RTAWD-G1 | `REST call failed: ORA-20003: HTTP GET failed. Status: 404 \| URL: .../gmsGrants?onlyData=true&limit=1&q=AwardNumber=93298RTAWD-G1` |

---

## 1. Requisitions (run 251)

**Symptom.** Verify reports NOT_FOUND (for Req Headers, an HTTP 500) for 93307RT-REQ-001 and
93307RT-REQ-002, which are LOADED.

**What Fusion holds (BIP, read-only):**

```
select requisition_header_id, requisition_number, document_status, preparer_id, req_bu_id
from por_requisition_headers_all where requisition_number in ('93307RT-REQ-001','93307RT-REQ-002')
143976  93307RT-REQ-001  APPROVED  300000047340498  300000046987012
143978  93307RT-REQ-002  APPROVED  300000047340498  300000046987012
```

The TFM side is correct. In `DMT_RECORD_DETAIL_V`, Req Headers for TFM 100000332 has LOOKUP_KEY
`143976`, which is `FUSION_REQUISITION_HEADER_ID`, and the lookup row is `RequisitionHeaderId={KEY}`.
The key, the field, the resource path and the URL encoding are all correct.

**Root cause: wrong REST user.** `purchaseRequisitions` applies data security, so a requisition is
visible only to its preparer, calvin.roth. On local Docker, `DMT_CONFIG_TBL` has no
`Requisitions_USERNAME` row, so the lookup falls back to fin_impl. The load itself runs as
calvin.roth, which comes from `DMT_ERP_INTERFACE_OPTIONS_TBL` row 28.

```
[fin_impl]    GET .../purchaseRequisitions?onlyData=true&limit=5&q=RequisitionHeaderId=143976
  -> HTTP 200  {"count": 0, "items": []}
[calvin.roth] GET .../purchaseRequisitions?onlyData=true&limit=5&q=RequisitionHeaderId=143976
  -> HTTP 200  {"count": 1, "items": [{"RequisitionHeaderId": 143976, "Requisition": "93307RT-REQ-001",
               "RequisitioningBU": "US1 Business Unit", "Preparer": "Calvin Roth", "DocumentStatus": "Approved", ...}]}
[calvin.roth] GET .../purchaseRequisitions?onlyData=true&limit=5&q=Requisition=93307RT-REQ-001
  -> HTTP 200  {"count": 1, ... same record}
```

Two related gaps:

- **The DMT_CONFIG row exists only on ATP.** ATP `DMT2_OWNER.DMT_CONFIG_TBL` has
  `Requisitions_USERNAME = calvin.roth`, but no seed or migration in git creates it. The seed's
  NOTES say it is required. So Requisitions verifies on ATP but fails on every Docker build.
- **The display-key fallback hides the real result.** After fin_impl gets count 0 ("not found"),
  `QUERY_FUSION_RECORD` retries with the display key `93307RT-REQ-001`, still inside
  `RequisitionHeaderId=`. Fusion answers HTTP 500 because the value is not a number:

  ```
  [fin_impl] GET .../purchaseRequisitions?onlyData=true&limit=5&q=RequisitionHeaderId=93307RT-REQ-001
    -> HTTP 500
  ```

  The console then shows a 500 instead of the real "not visible to fin_impl / not found".

A minor point: the `Req Lines` and `Req Distributions` lookup rows list DISPLAY_FIELDS
(`RequisitionNumber`, `PreparerName`, `Status`, `TotalAmount`, `CreationDate`) that the resource
does not return. Once the record is found, those cells would render blank.

**Proposed fix:**

1. `db/packages/dmt_rest_lookup_pkg.pkb.sql` (LOOKUP_RECORD, credential block). Insert the load
   credential from `DMT_ERP_INTERFACE_OPTIONS_TBL` for `l_obj_code`, taken only when
   `FUSION_USERNAME IS NOT NULL`, between the DMT_CONFIG override and the HCM/default fallback.
   The verify then reads Fusion as the user that loaded the record, with no hand-set config row.
   Use a direct `SELECT MAX(FUSION_USERNAME), MAX(FUSION_PASSWORD) ... WHERE CEMLI_CODE =
   l_obj_code AND FUSION_USERNAME IS NOT NULL` instead of `DMT_UTIL_PKG.GET_CEMLI_CREDENTIALS`.
   That helper falls back to fin_impl itself, which would skip the HCM branch, and it can raise
   TOO_MANY_ROWS.

   Before:
   ```sql
   l_username := COALESCE(
       DMT_UTIL_PKG.GET_CONFIG(l_obj_code || '_USERNAME'),
       CASE WHEN l_cfg_auth = 'HCM' THEN DMT_UTIL_PKG.GET_CONFIG('HCM_USERNAME') END,
       DMT_UTIL_PKG.GET_CONFIG('FUSION_USERNAME'));
   ```
   After:
   ```sql
   SELECT MAX(FUSION_USERNAME), MAX(FUSION_PASSWORD) INTO l_opt_user, l_opt_pass
   FROM   DMT_ERP_INTERFACE_OPTIONS_TBL
   WHERE  CEMLI_CODE = l_obj_code AND FUSION_USERNAME IS NOT NULL;
   l_username := COALESCE(
       DMT_UTIL_PKG.GET_CONFIG(l_obj_code || '_USERNAME'),
       l_opt_user,                                              -- the load user
       CASE WHEN l_cfg_auth = 'HCM' THEN DMT_UTIL_PKG.GET_CONFIG('HCM_USERNAME') END,
       DMT_UTIL_PKG.GET_CONFIG('FUSION_USERNAME'));
   -- same order for l_password, using l_opt_pass
   ```

   The username and password must come from the same source. Pick the source first, then read
   both values from it, so that a username from one store is never paired with a password from
   another.
2. `db/packages/dmt_rest_query_pkg.pkb.sql` (QUERY_FUSION_RECORD). When the display-key retry
   returns anything other than a hit, keep and return the **first** lookup's "not found" message
   instead of the retry's HTTP error. This stops a 500 from hiding the real answer for
   id-keyed filters (Requisitions, AR since #608, and Grants if it moves to AwardId).
3. Optional, following #608: in `db/views/dmt_record_detail_v.sql`, make the Req Lines and Req
   Distributions LOOKUP_KEY `TO_CHAR(h.FUSION_REQUISITION_HEADER_ID)` instead of
   `h.REQUISITION_NUMBER`. In `db/seed/dmt_rest_lookup_tbl.sql`, add a new migration
   `db/migrations/2026-10-xx_req_bpa_grants_rest_verify.sql` that sets their lookup rows to
   `RequisitionHeaderId={KEY}` / `FUSION_REQUISITION_HEADER_ID` with the header row's
   DISPLAY_FIELDS. The seed rows are insert-and-skip, so the migration is required.
4. No DMT_CONFIG seed is needed once step 1 is in. The ATP-only `Requisitions_USERNAME` row can
   stay, because it resolves to the same user.

**Risk: low.** This is a read-only GET under a user that already runs the Requisitions load. For
objects whose options row has a FUSION_USERNAME (the procurement objects and Grants), verify
switches from fin_impl to the load user. Purchase orders were checked: run 252 PO
`93308RT-PO-001` is visible to both fin_impl and calvin.roth, so nothing regresses there. Any
object whose load user cannot read its own REST resource would newly fail, but none is known.
Objects with no options credential behave exactly as before.

---

## 2. BlanketPOs (run 253)

**Symptom.** Verify reports NOT_FOUND for agreement 93309RT-BPA-XG2 (`po_header_id` 687872, OPEN),
both for Blanket PO Headers and for Blanket PO Lines.

**What Fusion holds (BIP, read-only):**

```
select po_header_id, segment1, type_lookup_code, document_status, prc_bu_id
from po_headers_all where segment1 in ('93309RT-BPA-XG2','RT-BPA-XG2','93309RT-BPA-001')
687872  93309RT-BPA-XG2  BLANKET  OPEN  300000046987012
(687871 93309RT-BPA-001 also present)
```

The number in Fusion has the run prefix, and the TFM's `DOCUMENT_NUM` (the view's LOOKUP_KEY) is
also `93309RT-BPA-XG2`. **The prefix is not the cause.** The resource path (`purchaseAgreements`),
the field (`AgreementNumber`) and the URL encoding are all correct.

**Root cause: wrong REST user.** `purchaseAgreements` is data-security-scoped to the procurement
agent: the buyer is Roth, Calvin. No `BlanketPOs_USERNAME` row exists on Docker or on ATP, so the
lookup runs as fin_impl. The load runs as calvin.roth (`DMT_ERP_INTERFACE_OPTIONS_TBL` row 181).

```
[fin_impl]    GET .../purchaseAgreements?onlyData=true&limit=5&q=AgreementNumber=93309RT-BPA-XG2
  -> HTTP 200  {"count": 0, "items": []}
[calvin.roth] GET .../purchaseAgreements?onlyData=true&limit=5&q=AgreementNumber=93309RT-BPA-XG2
  -> HTTP 200  {"count": 1, "items": [{"AgreementHeaderId": 687872, "AgreementNumber": "93309RT-BPA-XG2",
               "ProcurementBU": "US1 Business Unit", "Buyer": "Roth, Calvin", "DocumentStyle": "Blanket Purchase Agreement",
               "StatusCode": "OPEN", "Supplier": "93294RT Supplier Good-1", ...}]}
[fin_impl]    GET .../purchaseAgreements?onlyData=true&limit=5&q=AgreementHeaderId=687872
  -> HTTP 200  {"count": 0, "items": []}
[calvin.roth] GET .../purchaseAgreements?onlyData=true&limit=5&q=AgreementHeaderId=687872
  -> HTTP 200  {"count": 1, ... same record}
```

The id-based query also returns count 0 under fin_impl, which confirms that the key is not the
problem and the user is.

**Proposed fix:** the same `DMT_REST_LOOKUP_PKG` credential change as Requisitions step 1. That
fixes BlanketPOs with no data change, and it fixes ATP too, which has no BlanketPOs override.
Optional, following #608: key on the Fusion id instead. Set the Blanket PO Headers and Lines
LOOKUP_KEY in `dmt_record_detail_v.sql` to `TO_CHAR(FUSION_PO_HEADER_ID)` (lines via `h.`). Repoint
the `BlanketPOs` and `Blanket PO Headers` lookup rows, and add a `Blanket PO Lines` row (the lines
currently fall back to the object-code row), to `AgreementHeaderId={KEY}` /
`FUSION_PO_HEADER_ID`, through the seed plus the same migration. Keying on AgreementNumber already
works once the user is right, so this is consistency only, not required.

**Risk: low**, the same as Requisitions. Verify becomes a read as calvin.roth, who is already the
BlanketPOs load user.

---

## 3. Grants (proof run 242)

**Symptom.** Verify returns HTTP 404 for the LOADED awards 93298RTAWD-G1 and 93298RTAWD-G2.

**What Fusion holds (BIP, read-only, the same join the recon report uses):**

```
select b.id, k.contract_number, k.sts_code from gms_award_headers_b b
join okc_k_headers_all_b k on k.id=b.id and k.version_type='C' where k.contract_number like '93298RTAWD%'
300000334921417  93298RTAWD-G1  PENDING_APPROVAL
300000334921449  93298RTAWD-G2  DRAFT
```

The TFM rows match (`FUSION_AWARD_ID` 300000334921417 and 300000334921449, AWARD_NUMBER is
prefixed).

**Root cause: wrong resource path.** `gmsGrants` does not exist on this pod. It returns 404
for every user, with or without a filter, so ppm_impl versus fin_impl is not the cause. The
Fusion REST resource for awards is `awards`:

```
[fin_impl] GET .../gmsGrants?onlyData=true&limit=5&q=AwardNumber=93298RTAWD-G1   -> HTTP 404
[ppm_impl] GET .../gmsGrants?onlyData=true&limit=5&q=AwardNumber=93298RTAWD-G1   -> HTTP 404
[ppm_impl] GET .../gmsGrants?onlyData=true&limit=5                                -> HTTP 404
[ppm_impl] GET .../awards?onlyData=true&limit=5&q=AwardNumber=93298RTAWD-G1      -> HTTP 200 count 1
[fin_impl] GET .../awards?onlyData=true&limit=5&q=AwardNumber=93298RTAWD-G1      -> HTTP 200 count 1
           {"AwardId": 300000334921417, "AwardName": "RT Award Good-1 State", "AwardNumber": "93298RTAWD-G1",
            "BusinessUnitName": "Progress US Business Unit", "SponsorName": "State Government",
            "StartDate": "2026-09-01", "EndDate": "2027-09-01", "ContractStatus": "Pending approval", ...}
[ppm_impl] GET .../awards?onlyData=true&limit=5&q=AwardId=300000334921417        -> HTTP 200 count 1
```

The configured DISPLAY_FIELDS are also wrong for `awards`. `GrantId` and `AwardStatusCode` do
not exist on the resource; the status field is `ContractStatus`.

**Proposed fix:**

1. `db/seed/dmt_rest_lookup_tbl.sql`: in the `Grants` and `Award Headers` rows, set
   `REST_ENDPOINT='/fscmRestApi/resources/11.13.18.05/awards'` and
   `DISPLAY_FIELDS='AwardId,AwardNumber,AwardName,SponsorName,StartDate,ContractStatus'`
   (labels `Award ID,Award #,Name,Sponsor,Start,Status`). Keep
   `QUERY_FILTER='AwardNumber={KEY}'` / `KEY_COLUMN='AWARD_NUMBER'`, which is proven and
   user-independent. Alternatively, following #608 exactly, use `AwardId={KEY}` /
   `FUSION_AWARD_ID`, with the view's Award Headers LOOKUP_KEY changed to
   `TO_CHAR(FUSION_AWARD_ID)`. Both were proven live. If AwardId is chosen, take Requisitions step
   2 as well, so that the display-key retry (`AwardId=93298RTAWD-G1`, an HTTP 400) cannot hide a
   miss.
2. Add the migration `db/migrations/2026-10-xx_req_bpa_grants_rest_verify.sql` (or a
   Grants-only one), modelled on `2026-10-07_ar_rest_verify_by_trx_id.sql`: an idempotent
   `UPDATE DMT_REST_LOOKUP_TBL ... WHERE OBJECT_TYPE IN ('Grants','Award Headers')` plus a
   `DMT_MIGRATION_LOG` MERGE. The seed inserts skip existing rows, so without the migration
   existing databases never converge.
3. No credential change is needed for Grants. `awards` answers fin_impl. Once the Requisitions
   step 1 is in, Grants will read as ppm_impl (options row 57), which was also proven.

**Risk: very low.** Only the configuration of two lookup rows changes. Note that ATP's Grants
options row still has `FUSION_USERNAME` NULL because #601 has not been promoted, so the ATP
verify will run as fin_impl until promotion. That is fine for `awards`.

---

## Files the fix would touch (summary)

| File | Change | Objects |
|---|---|---|
| `db/packages/dmt_rest_lookup_pkg.pkb.sql` | credential: DMT_CONFIG override → **options-table load user** → HCM → fin_impl | Requisitions, BlanketPOs (and every object with an options FUSION_USERNAME) |
| `db/packages/dmt_rest_query_pkg.pkb.sql` | keep the primary "not found" when the display-key retry errors | all id-keyed lookups |
| `db/seed/dmt_rest_lookup_tbl.sql` | Grants/Award Headers → `awards` + real display fields; optionally Req Lines/Dists, BPA rows → Fusion-id keys | Grants (required), Requisitions/BlanketPOs (optional) |
| `db/migrations/2026-10-xx_req_bpa_grants_rest_verify.sql` | new, idempotent UPDATEs mirroring the seed + migration-log MERGE | as above |
| `db/views/dmt_record_detail_v.sql` | optional LOOKUP_KEY → Fusion ids (Req Lines/Dists, BPA headers/lines, Award Headers if AwardId) | optional |
| `scripts/dmt_regression_run.py` | no change needed; it calls the same package | - |
| `objects/{Requisitions,BlanketPOs,Grants}/README.md` | Known Issues entry for the verify fix | docs |

Proof to collect after the fix (local first, per the promotion gate): run `dmt_regression_run.py
--rest-only` (the REST spot-check) for runs 251, 253 and 242. Every Req, BPA and Award
sub-object should read FOUND. Then do the page-57 click-through for one record of each.
