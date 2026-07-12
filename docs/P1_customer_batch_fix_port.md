# P1 — Port the Customer FBDI batch-import fix into DMT2

**Priority:** P1. **Status:** proven in the frozen ConversionTool repo; NOT yet ported to DMT2.
**Source of truth (frozen — read only):** `brianmakarewicz/ConversionTool`, branch `customer-extended-batch-idfix`,
commit **`6c8e38c`**. ConversionTool is frozen — port the logic here; do not edit it.

## Why this exists
The Customer FBDI load never reached the Fusion base tables. Two bugs, both proven live on the demo instance 2026-07-11:

1. **The import job got no batch-creation parameters.** Fusion's "Import Bulk Customer Data" (`BulkImportJob` in
   `/oracle/apps/ess/cdm/foundation/bulkImport`) auto-creates the import batch from a 4-value positional ParameterList:
   **1=Batch ID, 2=Batch Name, 3=Object ('Customer and Consumer'), 4=Source System.** The tool sent none of them, so the
   CSVs loaded into the `HZ_IMP_*_T` interface tables but nothing advanced to the base tables. Proof: with the 4 values,
   **20/20 customers reached `hz_cust_accounts`**; with Batch Name blank, **0** loaded.
2. **The transform threw away the user's data** — it overwrote the uploaded `BATCH_ID` with `run_id` and hard-coded every
   `*_ORIG_SYSTEM` (source system) to `'DMT'`.

## The fix — four parts (all proven in ConversionTool commit 6c8e38c)

### 1. Generator — add a partition filter
Add a trailing `p_batch_id IN NUMBER DEFAULT NULL` to the customer FBDI generator's `GENERATE_FBDI` and to each of the 7
CSV builders. In every CSV query and in the STATUS→GENERATED updates add:
```sql
AND (p_batch_id IS NULL OR BATCH_ID = p_batch_id)
```
So one call emits only one batch's rows, and flips only that batch to GENERATED. (NULL = whole run = backward compatible.)

### 2. Loader — partition Customers by BATCH_ID (this is the whole pattern)
Customers becomes a grouped object (mirrors GL-by-ledger): loop the distinct `BATCH_ID`s, generate + load + import +
reconcile once per batch, and build the 4-value ParameterList from that batch. Skeleton of the ConversionTool block:
```sql
IF p_cemli_code = 'Customers' THEN
    DECLARE
        l_cu_zip BLOB; l_cu_filename VARCHAR2(200); l_cu_csv_id NUMBER;
        l_cu_load_id VARCHAR2(100); l_cu_import_id VARCHAR2(100);
        l_cu_param VARCHAR2(500); l_cu_count NUMBER := 0; l_cu_ok BOOLEAN;
        l_cu_user VARCHAR2(100); l_cu_pass VARCHAR2(100);
        -- on failure, fail all 7 customer sub-object TFM tables for this batch (reportable BAD rows)
        PROCEDURE mark_batch_failed(p_bid NUMBER, p_msg VARCHAR2) IS
        BEGIN
            UPDATE DMT_HZ_PARTIES_TFM_TBL         SET STATUS='FAILED', ERROR_TEXT=APPEND_ERROR(ERROR_TEXT,p_msg) WHERE RUN_ID=p_run_id AND STATUS='GENERATED' AND BATCH_ID=p_bid;
            -- ... repeat for LOCATIONS, PARTY_SITES, PARTY_SITE_USES, ACCOUNTS, ACCT_SITES, ACCT_SITE_USES ...
            COMMIT;
        END;
    BEGIN
        GET_CEMLI_CREDENTIALS('Customers', l_cu_user, l_cu_pass);
        FOR grp_rec IN (
            SELECT BATCH_ID,
                   MIN(PARTY_ORIG_SYSTEM)            AS SOURCE_SYSTEM,
                   COUNT(DISTINCT PARTY_ORIG_SYSTEM) AS SRC_COUNT
            FROM   DMT_HZ_PARTIES_TFM_TBL
            WHERE  RUN_ID = p_run_id AND STATUS = 'STAGED' AND BATCH_ID IS NOT NULL
            GROUP BY BATCH_ID ORDER BY BATCH_ID
        ) LOOP
            l_cu_count := l_cu_count + 1;
            IF grp_rec.SRC_COUNT > 1 THEN          -- one batch must use exactly one source system
                mark_batch_failed(grp_rec.BATCH_ID, '[PRE_VALIDATION] Batch '||grp_rec.BATCH_ID||' mixes multiple source systems.');
                CONTINUE;
            END IF;
            DMT_CUST_FBDI_GEN_PKG.GENERATE_FBDI(p_run_id, l_cu_zip, l_cu_filename, l_cu_csv_id,
                                                p_batch_id => grp_rec.BATCH_ID);
            IF l_cu_zip IS NULL OR DBMS_LOB.GETLENGTH(l_cu_zip)=0 THEN CONTINUE; END IF;
            -- 1=Batch ID, 2=Batch Name, 3=Object, 4=Source System. ALL FOUR REQUIRED.
            l_cu_param := TO_CHAR(grp_rec.BATCH_ID)
                       || ',DMT Batch ' || TO_CHAR(grp_rec.BATCH_ID)
                       || ',Customer and Consumer'
                       || ',' || grp_rec.SOURCE_SYSTEM;
            submit_and_reconcile_one(l_cu_zip, l_cu_filename, l_cu_csv_id, l_cu_param,
                                     'Batch: '||grp_rec.BATCH_ID, l_cu_user, l_cu_pass,
                                     l_cu_load_id, l_cu_import_id, l_cu_ok);
            IF NOT l_cu_ok THEN
                mark_batch_failed(grp_rec.BATCH_ID, '[FUSION_ERROR] Load failed. See ESS '||l_cu_load_id||'.');
                CONTINUE;
            END IF;
        END LOOP;
        IF l_cu_count = 0 THEN RETURN FALSE; END IF;   -- no STAGED rows with a batch id
    END;
    GOTO grouped_finish;   -- or DMT2's equivalent grouped-completion path
END IF;
```
Config: the import job/UCM come from the ERP-options row for `Customers`:
`IMPORT_JOB_NAME = /oracle/apps/ess/cdm/foundation/bulkImport;BulkImportJob`, `UCM_ACCOUNT = fin/receivables/import`.
The existing `submit_and_reconcile_one` already dispatches Customers reconciliation.

### 3. Transform — carry the user's values through (NEVER hard-code STG→TFM)
Across all 7 customer sub-object inserts, replace `run_id` in the BATCH_ID position with `s.BATCH_ID`, and replace every
`'DMT'` in an `*_ORIG_SYSTEM` position with the matching `s.<col>_ORIG_SYSTEM` passthrough. (Deriving is fine — the run
prefix on `*_ORIG_SYSTEM_REFERENCE` values stays.) 22 sites in ConversionTool.

### 4. Validator — Batch ID required
On the parties STG, fail a row with no Batch ID (it can't be split or loaded):
```sql
UPDATE DMT_HZ_PARTIES_STG_TBL p
SET STATUS='FAILED', ERROR_TEXT=APPEND_ERROR(ERROR_TEXT,'[PRE_VALIDATION] BATCH_ID is required (customer batch / partition key).'),
    LAST_UPDATED_DATE=SYSDATE
WHERE p.STATUS IN ('NEW','RETRY') AND p.BATCH_ID IS NULL;
```

## Related — the broader P1 (batch/group-id passthrough, still open)
The same "carry the batch/group id through and match the ESS parameter" applies to **PO, GL, REQ, Items** (each has the id
as an FBDI CSV column AND an ESS ParameterList arg). Porting those needs the same partition-by-id treatment. Agent-confirmed
mismatch points (ConversionTool line refs, for reference only): PO param pos 9, GL pos 4, REQ pos 2, Items pos 1. AP and
ItemCategories don't pass the id to ESS, so passthrough alone is safe there. Full plan lived in ConversionTool
`docs/P1_batch_passthrough_RESUME.md` (frozen — reproduce here as needed).

## Port checklist (into DMT2)
- [ ] Map DMT2's customer generator / loader / transform / validator (structure differs from ConversionTool).
- [ ] Apply parts 1–4 above.
- [ ] Confirm DMT2's ERP-options / job config has the `BulkImportJob` + `fin/receivables/import` values.
- [ ] Deploy + run DMT2 regression; assert customers reach the base tables and a no-batch-id row fails cleanly.
- [ ] Then tackle the PO/GL/REQ/Items partition port.

**Reference:** exact diffs are in ConversionTool commit `6c8e38c` (Customers) and `7054d19` (WIP passthrough) — read-only.
