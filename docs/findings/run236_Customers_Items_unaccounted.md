# Run 236: Customers and Items UNACCOUNTED investigation (READ-ONLY)

Run 236, local Docker DMT2. **Customers** prefix `93292` (work queue 1492, batch 5001,
load ESS **10069417**, import ESS 10069429). **Items** prefix `93292` for the item master,
but the Item Categories rows carry `93285` item numbers (see Item Categories below). The
Items object ran as two partition children: queue **1520** (BATCH_ID 8102, load 10069551,
import 10069555) and queue **1521** (BATCH_ID 8101, load 10069585, import 10069589).

Everything here was read-only. Live Fusion was queried through
`scripts/fusion_bip_query.py --cred fin_impl`, local DMT through `scripts/dmt_regression_run.py`
`connect()` (SELECT only), and the deployed BIP data models were downloaded from the
`/Custom/DMT2/` catalog and compared with the repo copies. Both deployed DMs are identical to
the repo. No code or data was changed, and nothing was re-run, reset or reconciled.

## Per-row table: where each UNACCOUNTED row is, why we miss it, and the fix

None of the six UNACCOUNTED rows is missing from Fusion. Every one has an interface row,
and four of the six also have a real per-row Fusion error message. In each case we fail to
account for the row because of a defect in our reconciliation code.

| # | DMT row (TFM seq) | (a) Where it is in Fusion right now | (b) Why our reconciler does not see it | (c) Fix that accounts for it honestly |
|---|---|---|---|---|
| 1 | Customers / Account Site Uses `93292RT-SITEUSE-G1` BILL_TO (401) | `HZ_IMP_ACCTSITEUSES_T` site_use_id 100002665021962, `IMPORT_STATUS_CODE='W'`, `ERROR_ID` NULL, load_request_id 10069417. It has no `HZ_IMP_ERRORS` row and is not in `HZ_CUST_SITE_USES_ALL`. The whole parent chain is held at W: party `93292RT-CUST-G1`=W, account `93292RT-ACCT-G1`=W, party site `93292RT-PSITE-G1`=W, account site `93292RT-ASITE-G1`=W. | The DM interface tier **does** return the row (`DMT_CUST_RECON_V2_DM.xdm:374-386`), but its `ERROR_MESSAGE` is a batch-wide `LISTAGG` of `HZ_IMP_ERRORS` for `HZ_IMP_ACCTSITEUSES_T` in batch 5001 (`:379-380`). Batch 5001 has **zero** errors for that table, so ERROR_MESSAGE is NULL. `dmt_cust_results_pkg.pkb.sql:448-449` only marks a row FAILED when ERROR_MESSAGE IS NOT NULL, so the row falls through (`:461`) to `SWEEP_UNACCOUNTED` (`dmt_queue_worker_pkg.pkb.sql:321-357`). The `W` status is never mapped. | **Code (DM):** emit a per-row message on every interface tier. Use the row's own `ERROR_ID` (join `HZ_IMP_ERRORS` on `error_id`+`batch_id`, resolve the text through `FND_NEW_MESSAGES` with token substitution), and when `ERROR_ID` is NULL and status is W, emit a parent-cascade message that names the held parent (for example `HELD (W): parent account site 93292RT-ASITE-G1 not created (status W)`). Result: FAILED with a message naming the failed parent. |
| 2 | Customers / Account Site Uses `93292RT-SITEUSE-G2` BILL_TO (402) | `HZ_IMP_ACCTSITEUSES_T` 100002665021963, `W`, no ERROR_ID, not in base. Its parent account site `93292RT-ASITE-G2` is **E** (`HZ_IMP_INVAL_VALUE_COMPARE` on SET_CODE). The grandparents are fine: account G2 and party site G2 are both S and in base. | Same as row 1: NULL batch-level message, then skipped at `:448-449`, then swept. | Same DM fix. The cascade message should read `parent account site 93292RT-ASITE-G2 rejected: HZ_IMP_INVAL_VALUE_COMPARE (SET_CODE)`, which gives FAILED. Once Account Sites issue A is fixed this row should **load**. |
| 3 | Customers / Account Site Uses `93292RT-SITEUSE-G3` BILL_TO (403) | `HZ_IMP_ACCTSITEUSES_T` 100002665021964, `W`, no ERROR_ID, not in base. Parent account site `93292RT-ASITE-G3` is **E** (same SET_CODE reject). | Same as row 1. | Same as row 2. It should **load** once issue A is fixed. |
| 4 | Customers / Account Site Uses `93292RT-SITEUSE-BAD1` INVALID_USE (404) | `HZ_IMP_ACCTSITEUSES_T` 100002665021965, `W`, no ERROR_ID, not in base. It hangs off `93292RT-ASITE-G1`, which is held W, so Fusion **never validated** `INVALID_USE` and no `HZ_API_INVALID_LOOKUP` was raised. | Same as row 1. | Same DM fix, which gives FAILED (parent held). **Seed:** move BAD1 onto a parent that loads (`RT-ASITE-G2`, `insert_regression_test_data.py:869`) so the BAD row produces its own real `HZ_API_INVALID_LOOKUP` and stops being a cascade. |
| 5 | Items / Item Categories `93285DMT-RT-LOT-001` @ eCommerce Catalog / eCom_Bus_Prod (100001559, queue 1520) | `EGP_ITEM_CATEGORIES_INTERFACE` interface_table_unique_id 181525, transaction_id 707674, **PROCESS_STATUS=3 (error)**, load_request_id **10069551**, request_id 10069555. `EGP_IMPORT_ERRORS`: **`EGP_ITEM_NON_LEAF_CATEGORY`**, "Items can only be assigned to leaf level categories when the value of the Catalog Content Code is Leaf Level. (EGP-2775673)". Not in `EGP_ITEM_CATEGORIES`. | Two reconcilers run and both miss it. **(i)** The Contract-v1 Items DM has the right category interface tier with real `EGP_IMPORT_ERRORS` text (`DMT_ITEM_RECON_DM.xdm:168-224`), but `dmt_egp_item_results_pkg.pkb.sql:509` binds `P_LOAD_REQUEST_ID = NVL(p_import_ess_id, p_load_ess_id)`, which is the **import** id 10069555. The interface row carries the **load** id 10069551 (request_id holds the import id). Selector (a) at `DM:223` therefore misses. Selector (b) (`item_number LIKE '93292%'`) also misses, because the category's item number is xref-resolved to the prior run's `93285` item (`dmt_egp_item_cat_transform_pkg.pkb.sql:76` calls `DMT_XREF_PKG.ITEM_NUMBER`, `dmt_xref_pkg.pkb.sql:316-334`). Log evidence: FETCH_ROWS "LoadReqId: 10069555 … rows 2" (items only). **(ii)** The legacy `ItemCategories` report (`bip/ItemCategories/ITEM_CAT_DM.xdm`) does select the row by load id 10069551 with STATUS=REJECTED, but it hard-codes `NULL AS error_message` (`ITEM_CAT_DM.xdm:21`), and `dmt_egp_item_cat_results_pkg.pkb.sql:99` needs a message. The row falls through to the sweep. | **Code:** in `APPLY_CONTRACT_V1_ITEMS` pass the **load** ESS id for `P_LOAD_REQUEST_ID` (and add `OR ic.request_id = :P_IMPORT_ESS_ID` to the category selectors as belt-and-braces), so the category tier returns the row and it goes to FAILED with `[CATEGORY] EGP_ITEM_NON_LEAF_CATEGORY …`. Also fix or retire `ITEM_CAT_DM.xdm` so it stops emitting NULL messages (V2 alongside, harvesting `EGP_IMPORT_ERRORS` on transaction_id). **Seed:** `eCom_Bus_Prod` is a non-leaf node with children `eCom_Gloves` and `eCom_Servers`, so use a leaf (for example `eCom_Gloves`) at `insert_regression_test_data.py:1931` to make this GOOD row actually good. |
| 6 | Items / Item Categories `NONEXISTENT-DMT-ITEM` @ FAKE_SET / ZZZ (100001560, queue 1521) | `EGP_ITEM_CATEGORIES_INTERFACE` 182526, transaction_id 708682, **PROCESS_STATUS=3**, load_request_id **10069585**, request_id 10069589. `EGP_IMPORT_ERRORS` has two rows: **`EGP_INVALID_CAT_PKS`** "The value of the catalog FAKE_SET or category BAD Category attribute is not valid for the item assignment." (EGP_ITEM_CATEGORIES_INTERFACE), and `EGP_ITEM_NOT_EXIST` ITEM_NUMBER "The specified item does not exist." (logged under EGP_SYSTEM_ITEMS_INTERFACE with the same transaction_id). | Same two defects as row 5. Contract-v1 bound import id 10069589 against load id 10069585, and the item has no run prefix, so selector (b) can never catch it. The legacy report returned the row with a NULL message. | Same code fix as row 5, which gives FAILED with `[CATEGORY] EGP_INVALID_CAT_PKS …`. The harvest should also include the `EGP_SYSTEM_ITEMS_INTERFACE` error that shares the transaction_id, so `EGP_ITEM_NOT_EXIST` is reported too. No seed change: this is a correct BAD row. |

**Items queues 1520 and 1521 each report "1 record(s) unaccounted".** These are the same two
rows: queue 1520 = row 5 (`93285DMT-RT-LOT-001`, WORK_QUEUE_ID 1520) and queue 1521 = row 6
(`NONEXISTENT-DMT-ITEM`, WORK_QUEUE_ID 1521). All item-master rows in run 236 are accounted:
three LOADED and `93292DMT-RT-BAD-001` FAILED with the real ORGANIZATION_ID message.

## Summary counts

| Object / record type | LOADED | FAILED | UNACCOUNTED | Genuinely absent from Fusion |
|---|---|---|---|---|
| Customers / Account Sites | 0 | 4 (2 correct, 2 **misattributed**) | 0 | 0 |
| Customers / Account Site Uses | 0 | 0 | 4 | 0 (all 4 are W rows in `HZ_IMP_ACCTSITEUSES_T`) |
| Items / Item Categories | 2 (SERIAL, PLAIN, both without FUSION_CATEGORY_ID) | 0 | 2 | 0 (both are PROCESS_STATUS=3 with real `EGP_IMPORT_ERRORS`) |

## Root causes (code defects, in priority order)

### R1. The Customers DM interface tier reports a batch-wide message list instead of a per-row message (code-fix)
`bip/Customers/DMT_CUST_RECON_V2_DM.xdm` builds ERROR_MESSAGE on every interface tier as
`LISTAGG(DISTINCT message_name)` over **all** `HZ_IMP_ERRORS` rows in the batch for that
interface table (parties `:248-249`, locations `:268-269`, party sites `:288-289`, party
site uses `:312-313`, accounts `:339-340`, account sites `:359-360`, account site uses
`:379-380`). Batch 5001 is reused by every regression run (it holds 31,073 account errors,
2,627 account-site errors and so on), so this list has two failure modes:

- **No error rows for the table, so the message is NULL, so the row is UNACCOUNTED.**
  This is exactly what happens to Account Site Uses: batch 5001 has 0 rows for
  `HZ_IMP_ACCTSITEUSES_T`, so all four W rows come back with ERROR_MESSAGE NULL and
  `dmt_cust_results_pkg.pkb.sql:448-449` discards them.
- **Some other row's error gets stamped on a row that has none (misattribution).** Account
  Sites `93292RT-ASITE-G1` and `93292RT-ASITE-BAD1` are `W` with `ERROR_ID` NULL. Neither has
  its own error, yet both were marked `FAILED [FUSION_ERROR] HZ_IMP_INVAL_VALUE_COMPARE`,
  because G2's and G3's errors are in the same batch. That breaks the error-attribution rule
  (errors go to the specific row, no cascade), and the same defect lets any old batch-5001
  error leak onto a new run's row.

Every `HZ_IMP_*_T` table has a per-row `ERROR_ID` (confirmed on `HZ_IMP_ACCTSITES_T`), and
`HZ_IMP_ERRORS.ERROR_ID` joins to it exactly. G2 and G3 resolve to error_ids 100002665573335
and 100002665573334.

**Fix:** on every interface tier, replace the batch LISTAGG with a per-row join on
`e.error_id = t.error_id AND e.batch_id = t.batch_id`. Resolve the text from
`FND_NEW_MESSAGES` and substitute TOKEN1..5. When `ERROR_ID` is NULL and the status is `W`,
emit a deterministic parent-cascade message built from the parent interface row (account
site, then account or party site, then party), naming the parent's reference and its status
and message, for example `[HZ_IMP_HELD_PARENT] parent CUST_SITE_ORIG_SYS_REF 93292RT-ASITE-G2
status E: HZ_IMP_INVAL_VALUE_COMPARE`. That is a real Fusion outcome (the row is held at W
because its parent was not created), not a fabricated one. Deploy as `DMT_CUST_RECON_V3_DM`
alongside V2 (never overwrite BIP objects) and repoint `dmt_bip_report_tbl` row 100000012.

### R2. Items Contract-v1 binds the import ESS id where the category tier needs the load ESS id (code-fix)
`db/packages/dmt_egp_item_results_pkg.pkb.sql:509` passes
`p_request_id => NVL(p_import_ess_id, p_load_ess_id)`, and `:259` forwards it as
`P_LOAD_REQUEST_ID`. `EGP_ITEM_CATEGORIES_INTERFACE.LOAD_REQUEST_ID` holds the
**InterfaceLoaderController (load)** id, and `REQUEST_ID` holds the ItemImportJobDef id. The
DM's own header (`DMT_ITEM_RECON_DM.xdm:208-213`) documents that the load id is the right
bind, and the Customers reconciler has the same note (`dmt_cust_results_pkg.pkb.sql:150-155`).
The prefix fallback (`DM:224`, `:251`) cannot rescue category rows either, because they carry
the **previous** run's item prefix (xref-resolved) or no prefix at all (BAD row). As a result
the category tier returned **nothing** in both partitions. I reproduced the tier SQL live:
bind 10069555 or 10069589 returns 0 category rows, while bind 10069551 or 10069585 returns
all four.

**Fix:** pass the load ESS id to `P_LOAD_REQUEST_ID` (keep the import id in
`P_IMPORT_ESS_ID`). In the DM, widen both category selectors to
`ic.load_request_id = :P_LOAD_REQUEST_ID OR ic.request_id = :P_IMPORT_ESS_ID OR ic.item_number LIKE :P_PREFIX||'%'`.
The item-master tier is prefix-scoped and is not affected.

### R3. The legacy ItemCategories report never carries an error message (code-fix)
`bip/ItemCategories/ITEM_CAT_DM.xdm:21` selects `NULL AS error_message` (the deployed copy is
identical), and `dmt_egp_item_cat_results_pkg.pkb.sql:99` only marks FAILED when a message is
present. So this second reconciler, called from `dmt_loader_pkg.pkb.sql:4127`, can never
produce FAILED. It can only produce LOADED, and when it does it never stamps
`FUSION_CATEGORY_ID` (`:88-97` match on item+org+set only, with no category code and no id).
That is why SERIAL and PLAIN show LOADED with a blank Fusion id, although their base rows
exist (assignment ids 300000334908013 and 300000334908057).

**Fix:** once R2 is fixed the Contract-v1 category tier covers LOADED (with id) and FAILED
(with real text), so retire the secondary `DMT_EGP_ITEM_CAT_RESULTS_PKG.RECONCILE_BATCH` call
at `dmt_loader_pkg.pkb.sql:4127`. If it has to stay, deploy an `ITEM_CAT_V2_DM` that harvests
`EGP_IMPORT_ERRORS` on transaction_id and returns the assignment id.

## Secondary item A: why Account Sites G2/G3 are rejected (`HZ_IMP_INVAL_VALUE_COMPARE`)

- Fusion evidence: `HZ_IMP_ACCTSITES_T` 100002665021939 (ASITE-G2) and 100002665021936
  (ASITE-G3) are `E`, error_ids 100002665573335 and 100002665573334, MESSAGE_NAME
  `HZ_IMP_INVAL_VALUE_COMPARE`, tokens `ATTRIBUTE1=SET_CODE, ATTRIBUTE2=SET_CODE,
  ATTRIBUTE3=FND_SETID_SETS_VL`. `ERROR_MSG_TEXT` is blank on the error row, but the full text
  **can be resolved**: `FND_NEW_MESSAGES` (US) gives "The value in the {ATTRIBUTE1} column isn't
  valid. You must enter a value of {ATTRIBUTE2} from the {ATTRIBUTE3} table." With the tokens
  substituted that reads **"The value in the SET_CODE column isn't valid. You must enter a value
  of SET_CODE from the FND_SETID_SETS_VL table."** Today DMT stores only the message name.
  The R1 fix should store this resolved text.
- Cause: we send `SET_CODE = 'US1 Business Unit'`, which is a **business unit name**, not a
  reference-data set code. `FND_SETID_ASSIGNMENTS` maps US1 Business Unit, reference group
  `HZ_CUSTOMER_ACCOUNT_SITE`, to set **`CUSTSITE`** (set_id 300000047280442). Every
  account-site interface row ever sent with 'US1 Business Unit' is W or E (88 W, 108 E). The
  only successes used `CUSTSITE` (9 S), and 548 base `HZ_CUST_ACCT_SITES_ALL` rows sit in
  CUSTSITE.
- Trace: seed constant `BU = "US1 Business Unit"` (`scripts/insert_regression_test_data.py:68`)
  is bound into `DMT_HZ_ACCT_SITES_STG_TBL.SET_CODE` at `:814` (GOOD) and `:831` (BAD). The
  transform copies it unchanged (`dmt_cust_transform_pkg.pkb.sql:1077/1106`), and the FBDI
  generator writes it verbatim (`dmt_cust_fbdi_gen_pkg.pkb.sql:486`). Account Site Uses carries
  the same value (`insert_regression_test_data.py:857`, `:873`; generator `:548`) and will very
  likely hit the same reject once the sites load (`HZ_CUSTOMER_ACCOUNT_SITE` is the same
  reference group). No site-use row has ever been validated against SET_CODE, because their
  parents always failed.
- **Fix (seed):** set `SET_CODE='CUSTSITE'` for account sites and account site uses in the
  seed. Do not change the shared `BU` constant, which is correct for suppliers, PO, AP, AR and
  so on. Alternatively, a **code-fix** in `dmt_cust_transform_pkg` could resolve a BU name to
  its `HZ_CUSTOMER_ACCOUNT_SITE` set code. That needs a new xref resolver, which the standing
  rule defers, so the seed fix is the right one now.

**Would the three GOOD site uses load if A is fixed?** G2 and G3: yes, provided their
SET_CODE is fixed too, because their parents (account, party site) are S and in base. G1: no.
Its whole chain (party `93292RT-CUST-G1`, account G1, party site G1, account site G1) is held
at W, the same CDM potential-duplicate hold documented in `run234_Customers.md` for
`RT-CUST-G1`. G1 site use and BAD1 would stay W cascades, which is why R1's parent-cascade
message matters.

## Other observations (logged, not fixed)

- The Account Sites BAD row (`93292RT-ASITE-BAD1`, account `RT-ACCT-NONEXIST`) is `W` with no
  error in Fusion, not `E`. Under R1 it would honestly report as held, not as the SET_CODE
  error it shows today.
- The Item Categories design (xref to the most recent LOADED item, `dmt_xref_pkg.pkb.sql:316-334`)
  means run 236's categories target run 229's `93285` items, not this run's `93292` items. That
  is why "prefix 93285" appears in run 236. It is intended behaviour, but it rules out any
  prefix-only scoping of category rows, which is why R2 matters.
- In batch 5001 during the run window, `HZ_IMP_ACCOUNTS_T` has 82 `GENERIC_MESSAGE` "The OS/OSR
  combination LEG1/93285RT-ACCT-G3 already exists." These belong to another prefix (93285) that
  is reusing batch 5001 concurrently, which is a live example of why R1's batch-wide LISTAGG is
  unsafe.

## Fix roadmap

| # | Type | Change | Rows it accounts for |
|---|---|---|---|
| 1 | code-fix | Customers DM V3: per-row `ERROR_ID` join with resolved FND text, plus a parent-cascade message for `W` rows with no ERROR_ID (all seven interface tiers) | Site Uses 401-404 go to FAILED with a parent named; Account Sites G1/BAD1 stop being misattributed |
| 2 | code-fix | `dmt_egp_item_results_pkg.pkb.sql:509`: bind the load ESS id to `P_LOAD_REQUEST_ID`; DM category selectors also accept `request_id = :P_IMPORT_ESS_ID` | Item Cat 100001559 and 100001560 go to FAILED with real `EGP_IMPORT_ERRORS` text; SERIAL/PLAIN get FUSION_CATEGORY_ID |
| 3 | code-fix | Retire, or V2, the legacy `ITEM_CAT_DM.xdm` + `dmt_egp_item_cat_results_pkg` path (NULL message, LOADED without id) | Removes the second, contradictory reconciler |
| 4 | seed-fix | `SET_CODE='CUSTSITE'` for account sites and site uses (`insert_regression_test_data.py:814/831/857/873`) | Account Sites G2/G3 and Site Uses G2/G3 should load |
| 5 | seed-fix | Account Site Use BAD1 parent becomes `RT-ASITE-G2` (`:869`) | BAD row gets its own `HZ_API_INVALID_LOOKUP` |
| 6 | seed-fix | LOT category `eCom_Bus_Prod` becomes a leaf such as `eCom_Gloves` (`:1931`) | GOOD LOT category actually loads |

## Evidence appendix (all read-only)

- Local TFM `dmt_hz_acct_sites_tfm_tbl` run 236: seq 401-404, all `FAILED [FUSION_ERROR] HZ_IMP_INVAL_VALUE_COMPARE`, SET_CODE `US1 Business Unit`, batch 5001.
- Local TFM `dmt_hz_acct_site_uses_tfm_tbl` run 236: seq 401-404, all `UNACCOUNTED [UNACCOUNTED]`, RECON_KEY `Customers.AccountSiteUses~93292RT-SITEUSE-{G1,G2,G3,BAD1}`.
- Local `dmt_work_queue_tbl`: 1492 Customers load 10069417 / import 10069429 "4 record(s) unaccounted (11 loaded, 13 errored)"; 1520 Items load 10069551 / import 10069555 "1 unaccounted (3 loaded, 0 errored)"; 1521 load 10069585 / import 10069589 "1 unaccounted (2 loaded, 1 errored)".
- Local `dmt_log_tbl` run 236: queue 1520 `FETCH_ROWS … LoadReqId: 10069555 … rows 2`; queue 1521 `LoadReqId: 10069589 … rows 4` (items only, no category rows); `DMT_EGP_ITEM_CAT_RESULTS_PKG.PARSE_AND_UPDATE … LOADED: 1, FAILED: 0` in each partition.
- Fusion `HZ_IMP_ACCTSITES_T` (load_request_id 10069417): ASITE-BAD1 100002665021937 W; ASITE-G1 100002665021938 W; ASITE-G2 100002665021939 E (error_id 100002665573335); ASITE-G3 100002665021936 E (error_id 100002665573334).
- Fusion `HZ_IMP_ACCTSITEUSES_T` (10069417): SITEUSE-G1/G2/G3/BAD1 = 100002665021962/963/964/965, all W, ERROR_ID NULL; none in `HZ_CUST_SITE_USES_ALL`.
- Fusion `HZ_IMP_ERRORS` batch 5001 by table: ACCOUNTS 31073, ACCTSITES 2627, LOCATIONS 1695, PARTIES 3166, PARTYSITES 1599, PARTYSITEUSES 1559, **ACCTSITEUSES 0**.
- Fusion `HZ_ORIG_SYS_REFERENCES` `93292RT%`: Parties G2/G3, Locations G1/G2/G3, PartySites G2/G3, Accounts G2/G3; no account-site or site-use rows.
- Fusion parent statuses: parties G1 W, G2 S, G3 S, BAD1 E; accounts G1 W, G2 S, G3 S, BAD1 E (`HZ_IMP_INVAL_PARTY_REF`); party sites G1 W, G2 S, G3 S, BAD1 E.
- Fusion `FND_SETID_ASSIGNMENTS`: US1 Business Unit, `HZ_CUSTOMER_ACCOUNT_SITE`, set `CUSTSITE`.
- Fusion `EGP_ITEM_CATEGORIES_INTERFACE` run 236: 181526 SERIAL status 7 (base 300000334908013); 181525 LOT status 3; 182525 PLAIN status 7 (base 300000334908057); 182526 NONEXISTENT status 3.
- Fusion `EGP_IMPORT_ERRORS`: txn 707674 `EGP_ITEM_NON_LEAF_CATEGORY` (EGP-2775673); txn 708682 `EGP_INVALID_CAT_PKS` and `EGP_ITEM_NOT_EXIST`.
- Fusion `EGP_CATEGORY_SET_VALID_CATS`: eCom_Bus_Prod has children eCom_Gloves and eCom_Servers (eCommerce Catalog set 300000047481425, content code LEAF_ITEMS).
- Deployed `/Custom/DMT2/Customers/DMT_CUST_RECON_V2_DM.xdm` and `/Custom/DMT2/ItemCategories/ITEM_CAT_DM.xdm` are byte-for-byte the same SQL as the repo copies.
