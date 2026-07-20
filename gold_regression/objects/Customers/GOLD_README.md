# Customers — gold regression fixture

A standalone, reloadable FBDI fixture (2 good + 1 bad customer) that loads
directly into Oracle Fusion Trading Community / Receivables via the ERP
Integration SOAP service (`loadAndImportData`), which loads the seven HZ
interface tables and chains **Import Bulk Customer Data**
(`CDMAutoBulkImportJob`). Verification is read-only via the BIP relay, with
direct single-table reads. No DMT tool code and no DMT database is in the load
path.

Customers is **ONE object**: one FBDI zip carrying **SEVEN** HZ CSVs (parties,
locations, party sites, party site uses, accounts, account sites, account site
uses) — record types of one object, one ESS load. Not seven objects.

**Portable.** The Trading Community **source system** (orig_system) and the
**business unit** are discovered at load time by a read-only BIP query against
the target pod; nothing is hardcoded and the fixture never depends on data we
loaded earlier. The customers are created fresh (prefix-stamped natural keys);
their source-system and BU references are borrowed from what already exists on
the pod.

## The seven CSVs (FBDI, no header row, position-based)

Byte-template taken from the proven `test/fbdi_zips/Customers_116.zip`. Every
CSV's column 1 is `BATCH_ID` and column 2 is the source system (orig_system).

| Member | Record type | Natural key (col 3) |
|---|---|---|
| `HzImpPartiesT.csv`       | Parties         | `${PREFIX}RT-CUST-{G1,G2,BAD1}` |
| `HzImpLocationsT.csv`     | Locations       | `${PREFIX}RT-LOC-{G1,G2,BAD1}` |
| `HzImpPartySitesT.csv`    | Party sites     | `${PREFIX}RT-PSITE-{G1,G2}` |
| `HzImpPartySiteUsesT.csv` | Party site uses | (BILL_TO on each good psite) |
| `HzImpAccountsT.csv`      | Accounts        | account_number `${PREFIX}{G001,G002,BAD01}` |
| `HzImpAcctSitesT.csv`     | Account sites   | `${PREFIX}RT-ASITE-{G1,G2}` (good only) |
| `HzImpAcctSiteUsesT.csv`  | Acct site uses  | BILL_TO on each good acct site |

Three parties / three accounts:

| Row | Party ref | Account number | Party type | Purpose |
|---|---|---|---|---|
| GOOD-1 | `${PREFIX}RT-CUST-G1` | `${PREFIX}G001` | `ORGANIZATION` | valid → base |
| GOOD-2 | `${PREFIX}RT-CUST-G2` | `${PREFIX}G002` | `ORGANIZATION` | valid → base |
| BAD-1  | `${PREFIX}RT-CUST-BAD1` | `${PREFIX}BAD01` | `INVALID_TYPE` | rejected in interface |

**Critical layout facts (learned live):**

- **Column 2 (source system) MUST be a Trading-Community-registered orig_system
  that is enabled for TCA.** The old byte-template used `DMT`, which is NOT
  registered on any pod (`HZ_ORIG_SYSTEMS_B` has no `DMT` row), so every party
  rejected with `HZ_INVALID_ORIG_SYSTEM` and nothing reached the base. The
  fixture now **discovers** a registered SPOKE source system (prefers `LEG1`)
  and stamps it into `${ORIG_SYSTEM}`.
- **The BAD row rejects in the interface, not in pre-validation.** Its party
  type `INVALID_TYPE` is a value the bulk import validates and rejects — the
  party lands in `HZ_IMP_PARTIES_T` with `INTERFACE_STATUS='E'` and real errors
  `HZ_IMP_PARTY_TYPE_ERROR` / `HZ_PRTY_PUA_INVALID_TYPE` in `HZ_IMP_ERRORS`.
  Because its party never creates, the bad account `${PREFIX}BAD01` cannot
  import either (`INTERFACE_STATUS='W'`) and never reaches `HZ_CUST_ACCOUNTS`.
- **The account site / account site use rows carry the discovered `${BU_NAME}`**
  (the business unit name), stamped from discovery — not a hardcoded pod name.

## The exact call

| Thing | Value |
|---|---|
| Endpoint | `{FUSION_URL}/fscmService/ErpIntegrationService` |
| Operation | `loadAndImportData` |
| Auth | HTTP Basic, credential role `fin_impl` (connections.json) |
| UCM DocumentAccount | `fin/receivables/import` |
| ContentType | `ZIP` |
| `<typ:interfaceDetails>` | `4` (the customer `ERP_INTERFACE_OPTIONS_ID` from `db/seed/dmt_erp_interface_options_tbl.sql`) |
| `<erp:JobName>` | `/oracle/apps/ess/cdm/foundation/bulkImport,CDMAutoBulkImportJob` (seed stores it with `;` before the job def; `loadAndImportData` needs the last `;` replaced with `,`) |
| `<erp:ParameterList>` | 4 args: `${PREFIX},Batch ID ${PREFIX} ${ORIG_SYSTEM},CUSTOMER,${ORIG_SYSTEM}` |
| `<typ:notificationCode>` | `10` |

**Why `CDMAutoBulkImportJob`, not `BulkImportJob`.** `CDMAutoBulkImportJob`
("Import Bulk Customer Data") **creates** the HZ import batch from the four
positional args and then processes it. `BulkImportJob` ("Import Trading
Community Data in Bulk") needs a pre-existing `HZ_IMP_BATCH_SUMMARY` batch and
throws a null-batchId error when submitted from `loadAndImportData` — this was
the long-standing "batchId is null" failure. Proven both by manual ESS run
9731634 (DMT2 loader) and live here.

**CDMAutoBulkImportJob ParameterList — 4 positions:**

| # | Value | Meaning |
|---|---|---|
| 1 | `${PREFIX}` | **Batch ID** — must equal column 1 (`BATCH_ID`) of every CSV |
| 2 | `Batch ID ${PREFIX} ${ORIG_SYSTEM}` | Batch Name (non-empty; an empty name loads 0 rows) |
| 3 | `CUSTOMER` | Object **CODE** — literal `CUSTOMER` (NOT `Customer and Consumer`, which silently fails to create the batch) |
| 4 | `${ORIG_SYSTEM}` | Source System — the discovered registered orig_system |

## ESS orchestration (every job in order + the downstream wait)

1. **`loadAndImportData`** (one SOAP call) uploads the zip to UCM under
   `fin/receivables/import`, runs **Load Interface File for Import** to unpack
   the 7 CSVs into the `HZ_IMP_*_T` interface tables (stamped `BATCH_ID=${PREFIX}`),
   and submits **Import Bulk Customer Data** (`CDMAutoBulkImportJob`) with the
   4-arg ParameterList. It returns the **Load ESS request id** in `<result>`.
2. **Poll the Load request id** with `getESSJobStatus` every 60s until terminal.
   It reaches `SUCCEEDED` once the interface load + import submission complete —
   **but the bulk import then runs its child processing asynchronously.**
3. **Downstream wait — poll the HZ import batch.** `loadAndImportData`'s
   SUCCEEDED does NOT mean the customers reached the base tables yet. The bulk
   import creates a row in `HZ_IMP_BATCH_SUMMARY` with `BATCH_NAME =
   'Batch ID ${PREFIX} ${ORIG_SYSTEM}'` and works it from `PROCESSING` to a
   terminal `COMPLETED` / `COMPL_ERRORS`. Poll `BATCH_STATUS` (via BIP) until it
   is no longer `PROCESSING`/`QUEUED` before verifying — the base rows and the
   `HZ_IMP_ERRORS` rejections appear only then. On the proven run the batch took
   ~3 minutes to reach `COMPL_ERRORS` (good rows imported, bad row errored —
   the expected mixed outcome).

## Discovery (run before build, read-only BIP, role fin_impl)

Two steps, both against the target pod:

```sql
-- 1. A Trading-Community-registered source system enabled for TCA (prefer LEG1)
SELECT os FROM (
  SELECT orig_system AS os,
         CASE orig_system WHEN 'LEG1' THEN 0 WHEN 'LEG2' THEN 1
                          WHEN 'CSV' THEN 2 ELSE 3 END AS pref
  FROM   hz_orig_systems_b
  WHERE  status = 'A' AND enable_for_tca_flag = 'Y' AND orig_system_type = 'SPOKE'
  ORDER BY pref, orig_system
) WHERE ROWNUM = 1;                                    -- -> ${ORIG_SYSTEM}

-- 2. A business unit with a primary ledger (US1 Business Unit on the demo pod)
SELECT * FROM (
  SELECT bu.bu_name AS buname, bu.bu_id AS buid
  FROM   fun_all_business_units_v bu
  WHERE  bu.primary_ledger_id IS NOT NULL AND bu.bu_name = 'US1 Business Unit'
  ORDER BY bu.bu_id
) WHERE ROWNUM = 1;                                    -- -> ${BU_NAME}, ${BU_ID}
```

Discovered tokens stamped into the CSVs and the ParameterList: `${ORIG_SYSTEM}`,
`${BU_NAME}` (and `${BU_ID}`, unused by the current CSVs but available).

## Verification (read-only, via the BIP relay — direct single-table reads)

Both directions are proven with **independent single-table reads**, never a
relayed multi-table LEFT JOIN.

- **Good → base.** Direct read of `HZ_CUST_ACCOUNTS` by the prefix on the
  account number:
  ```sql
  SELECT account_number, cust_account_id
  FROM   hz_cust_accounts
  WHERE  account_number LIKE '<prefix>%';
  ```
  Each good account number present with a real `CUST_ACCOUNT_ID` = pass. (The
  corresponding party ids are in `HZ_PARTIES`; the create is also confirmed by
  `HZ_ORIG_SYS_REFERENCES` rows with `STATUS='A'`.)
- **Bad → interface + absent from base.** Direct read of `HZ_IMP_ACCOUNTS_T` by
  batch for the bad account number, with the batch's party/account errors from
  `HZ_IMP_ERRORS`:
  ```sql
  SELECT a.account_number,
         (SELECT LISTAGG(e.message_name, '; ') WITHIN GROUP (ORDER BY e.error_seq_id)
          FROM   hz_imp_errors e
          WHERE  e.batch_id = <prefix>
          AND    e.interface_table_name IN ('HZ_IMP_PARTIES_T','HZ_IMP_ACCOUNTS_T')) AS error_message
  FROM   hz_imp_accounts_t a
  WHERE  a.batch_id = <prefix> AND a.account_number LIKE '<prefix>BAD%';
  ```
  The bad account present in the interface with the rejection text, and absent
  from the `HZ_CUST_ACCOUNTS` base read above = pass.

Interface tables: `HZ_IMP_PARTIES_T` … `HZ_IMP_ACCT_SITE_USES_T`; errors
`HZ_IMP_ERRORS`; batch `HZ_IMP_BATCH_SUMMARY`; base `HZ_PARTIES`,
`HZ_CUST_ACCOUNTS`; cross-reference `HZ_ORIG_SYS_REFERENCES`.

## How to run it

```bash
cd gold_regression/harness
python run_object.py Customers                 # discover -> build -> load -> verify
# NOTE: the bulk import runs asynchronously. loadAndImportData SUCCEEDED does
# not yet mean the base is populated. If verify shows good_in_base_count 0 and
# the bad row "partial", the HZ batch is still PROCESSING -- wait for
# HZ_IMP_BATCH_SUMMARY.BATCH_STATUS to leave PROCESSING, then re-verify:
python verify.py Customers <LOAD_REQUEST_ID> <PREFIX>
```

## Live evidence

**2026-07-19 — LIVE-PROVEN. PASS.**

Standalone load path only (no DMT database / code in the load path);
verification via the read-only BIP relay only.

| Field | Value |
|---|---|
| Date | 2026-07-19 |
| Prefix | `63171` |
| Discovered source system / BU | `LEG1` / `US1 Business Unit` (`300000046987012`) |
| Load ESS request id (`loadAndImportData` result) | `9763020` |
| Load terminal status (`getESSJobStatus`) | `SUCCEEDED` |
| HZ import batch | `HZ_IMP_BATCH_SUMMARY` batch id `63171`, name `Batch ID 63171 LEG1` |
| Batch terminal status | `COMPL_ERRORS` (good imported, bad errored — expected) |

**Good rows → base table `HZ_CUST_ACCOUNTS` (2/2):**

| ACCOUNT_NUMBER | CUST_ACCOUNT_ID | Party id (`HZ_PARTIES`) |
|---|---|---|
| `63171G001` | `100002547170278` | `100002547170201` |
| `63171G002` | `100002547170279` | `100002547170202` |

Both accounts and parties also present in `HZ_ORIG_SYS_REFERENCES` with
`ORIG_SYSTEM='LEG1'`, `STATUS='A'`.

**Bad row → interface rejection, absent from base (1/1):**

| Account | Interface status | Rejection (`HZ_IMP_ERRORS`, `HZ_IMP_PARTIES_T`) |
|---|---|---|
| `63171BAD01` (party `63171RT-CUST-BAD1`, type `INVALID_TYPE`) | party `E`, account `W` | `HZ_IMP_PARTY_TYPE_ERROR`; `HZ_PRTY_PUA_INVALID_TYPE`; `HZ_IMP_PARTY_NAME_ERROR` |

The bad account is absent from `HZ_CUST_ACCOUNTS`. Gold zip `Customers_gold.zip`
(last built at prefix 63171) kept in this directory.

**Note on the earlier stack's blocker.** The DMT2 object README long recorded
"batchId is null — customers never reach the base." Root cause was the wrong job
(`BulkImportJob`) plus the unregistered `DMT` source system. Both are fixed here:
`CDMAutoBulkImportJob` (which self-creates the batch) + a discovered registered
orig_system. This is the first end-to-end Customer load reaching the HZ base
tables via the standalone path.
