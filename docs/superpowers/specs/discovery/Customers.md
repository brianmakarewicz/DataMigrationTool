# Customers — three-source reconciliation, RUN 132 (local Docker DMT)

READ-ONLY discovery. No DB object, pipeline, or DMT table was modified. Fusion reads
were live and read-only via `scripts/fusion_bip_query.py --cred fin_impl`.

## Object / tables / grain
- **CEMLI:** `Customers` (ONE object, ONE FBDI zip, ONE bulk-import ESS load — seven HZ record types).
- **TFM table used for the reconciliation grain:** `DMT_HZ_ACCOUNTS_TFM_TBL` (the Accounts
  record type). RUN 132 has 4 Account records — the count the brief specifies for Customers.
- **Grain:** one row per customer account (account-grain). RECON_KEY = `Customers.Accounts~<prefixed CUST_ORIG_SYSTEM_REFERENCE>`.
- **Fusion base table:** `HZ_CUST_ACCOUNTS`, keyed for read-back through
  `HZ_ORIG_SYS_REFERENCES` (OWNER_TABLE_NAME='HZ_CUST_ACCOUNTS', OWNER_TABLE_ID=CUST_ACCOUNT_ID).
  The DMT column that stores the confirmed base id is `FUSION_CUST_ACCOUNT_ID`.
- **Run keys (from `DMT_WORK_QUEUE_TBL`, run 132, queue_id 841):**
  LOAD_ESS_JOB_ID = 10023695, IMPORT_ESS_JOB_ID = 10023709.
- **Prefix (derived from the data, never used as a key):** `93212`.

## Amount column + rationale
**AMOUNT = NONE.** Customer accounts carry no monetary value. `DMT_HZ_ACCOUNTS_TFM_TBL`
has no amount column. This is a COUNT-ONLY reconciliation.

## STG total (the run's record set)
STG has no RUN_ID, so the run's record set is the set of TFM rows for RUN 132.

```sql
-- STG total for the run = TFM rows for this run (account grain)
SELECT COUNT(*) AS stg_total
FROM   dmt_hz_accounts_tfm_tbl
WHERE  run_id = 132;
```
**Result: STG total = 4 accounts.**

Detail (one row per account):

```sql
SELECT tfm_sequence_id, tfm_status, recon_key, fusion_cust_account_id,
       account_number, cust_orig_system_reference,
       SUBSTR(error_text,1,300) AS err
FROM   dmt_hz_accounts_tfm_tbl
WHERE  run_id = 132
ORDER  BY tfm_sequence_id;
```
| seq | status | recon_key | fusion_cust_account_id | acct_number | cust ref |
|----|--------|-----------|------------------------|-------------|----------|
| 121 | FAILED | Customers.Accounts~93212RT-ACCT-G1   |        | 93212RTG001 | 93212RT-ACCT-G1 |
| 122 | LOADED | Customers.Accounts~93212RT-ACCT-G2   | 100002649023586 | 93212RTG002 | 93212RT-ACCT-G2 |
| 123 | LOADED | Customers.Accounts~93212RT-ACCT-G3   | 100002649023587 | 93212RTG003 | 93212RT-ACCT-G3 |
| 124 | FAILED | Customers.Accounts~93212RT-ACCT-BAD1 |        | 93212RTBAD01 | 93212RT-ACCT-BAD1 |

## TFM errors (count + real ERROR_TEXT)
```sql
SELECT tfm_sequence_id, recon_key, SUBSTR(error_text,1,400) AS error_text
FROM   dmt_hz_accounts_tfm_tbl
WHERE  run_id = 132
AND    tfm_status = 'FAILED'
ORDER  BY tfm_sequence_id;
```
**Result: 2 FAILED, both carrying real Fusion HZ import errors.**
- seq 121 (G1): `[FUSION_ERROR] Not created in base -- interface status 'W' (held/warning)
  -- batch messages: GENERIC_MESSAGE; HZ_IMP_ACTION_MISMATCH; HZ_IMP_INVAL_PARTY_REF`
- seq 124 (BAD1): `[FUSION_ERROR] Not created in base -- interface status 'E' (rejected by
  import) -- batch messages: GENERIC_MESSAGE; HZ_IMP_ACTION_MISMATCH; HZ_IMP_INVAL_PARTY_REF`

Both are real per-record import statuses (W held / E rejected) plus the batch's real
`HZ_IMP_ERRORS.MESSAGE_NAME` list — not fabricated. `HZ_IMP_INVAL_PARTY_REF` is the
invalid-party-reference reject documented in `objects/Customers/README.md` (G1's party was
held; BAD1 points at a non-existent party `93212RT-CUST-NONEXIST`).

Amount of errors: N/A (count-only).

## Fusion successes (LIVE FROM FUSION)
Key path used: **captured FUSION_ID list confirmed against the live base table.** The two
LOADED TFM rows already carry `FUSION_CUST_ACCOUNT_ID`; those ids were re-confirmed live in
`HZ_CUST_ACCOUNTS` via `HZ_ORIG_SYS_REFERENCES`, filtered by the run prefix on the reference.

```sql
-- LIVE Fusion (read-only, fin_impl). Confirms each account reached HZ_CUST_ACCOUNTS.
SELECT orig_system_reference AS oref,
       owner_table_name      AS owner_table,
       TO_CHAR(owner_table_id) AS fusion_id
FROM   hz_orig_sys_references
WHERE  owner_table_name = 'HZ_CUST_ACCOUNTS'
AND    orig_system_reference LIKE '93212%'
ORDER  BY orig_system_reference;
```
**Live result: 2 rows, matching the DMT-stamped ids exactly.**
- `93212RT-ACCT-G2` → HZ_CUST_ACCOUNTS → **100002649023586** (== TFM seq 122 FUSION_CUST_ACCOUNT_ID)
- `93212RT-ACCT-G3` → HZ_CUST_ACCOUNTS → **100002649023587** (== TFM seq 123 FUSION_CUST_ACCOUNT_ID)

Fusion successes = **2 accounts**. Amount: N/A.

## Balance check
```
Fusion successes + TFM errors = STG total
        2         +     2      =     4      ✔ BALANCED
```
Every one of the 4 records is accounted for: 2 confirmed in the Fusion base table, 2
failed with a real Fusion rejection. Zero unaccounted. Count-only (no money).

## Gotchas
- The prefix `93212` is derived only to build the LIKE filter on the ORIG_SYSTEM_REFERENCE;
  it is not itself a key. The real read-back keys are the captured CUST_ACCOUNT_IDs plus the
  prefixed orig-system reference that TCA round-trips into `HZ_ORIG_SYS_REFERENCES`.
- The FAILED rows never reached `HZ_CUST_ACCOUNTS`, so the live base query correctly returns
  only the 2 loaded accounts — the base-tier count IS the success count.
- Source-system correctness matters (see README): these rows use `PARTY_ORIG_SYSTEM='LEG1'`
  (a TCA-registered source), which is why the GOOD ones created cleanly. The two failures are
  intentional bad data (held party / non-existent party ref), not a source-system defect.
- Other Customers record types (Parties, Locations, etc.) also have TFM rows in run 132, but
  the brief's "4 records" is the Accounts grain; Accounts is the account-level object the
  reconciliation balances on.
```
