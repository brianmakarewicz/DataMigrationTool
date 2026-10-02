BEGIN EXECUTE IMMEDIATE 'DROP TABLE DMT_RCV_TRANSACTIONS_TFM_TBL CASCADE CONSTRAINTS PURGE'; EXCEPTION WHEN OTHERS THEN IF SQLCODE IN (-942, -4043) THEN NULL; ELSE RAISE; END IF; END;
/
BEGIN EXECUTE IMMEDIATE 'DROP TABLE DMT_RCV_TRANSACTIONS_STG_TBL CASCADE CONSTRAINTS PURGE'; EXCEPTION WHEN OTHERS THEN IF SQLCODE IN (-942, -4043) THEN NULL; ELSE RAISE; END IF; END;
/
BEGIN EXECUTE IMMEDIATE 'DROP TABLE DMT_RCV_HEADERS_TFM_TBL CASCADE CONSTRAINTS PURGE'; EXCEPTION WHEN OTHERS THEN IF SQLCODE IN (-942, -4043) THEN NULL; ELSE RAISE; END IF; END;
/
BEGIN EXECUTE IMMEDIATE 'DROP TABLE DMT_RCV_HEADERS_STG_TBL CASCADE CONSTRAINTS PURGE'; EXCEPTION WHEN OTHERS THEN IF SQLCODE IN (-942, -4043) THEN NULL; ELSE RAISE; END IF; END;
/
BEGIN EXECUTE IMMEDIATE 'DROP SEQUENCE DMT_RCV_TRANSACTIONS_TFM_SEQ'; EXCEPTION WHEN OTHERS THEN IF SQLCODE IN (-2289, -4043) THEN NULL; ELSE RAISE; END IF; END;
/
BEGIN EXECUTE IMMEDIATE 'DROP SEQUENCE DMT_RCV_TRANSACTIONS_STG_SEQ'; EXCEPTION WHEN OTHERS THEN IF SQLCODE IN (-2289, -4043) THEN NULL; ELSE RAISE; END IF; END;
/
BEGIN EXECUTE IMMEDIATE 'DROP SEQUENCE DMT_RCV_HEADERS_TFM_SEQ'; EXCEPTION WHEN OTHERS THEN IF SQLCODE IN (-2289, -4043) THEN NULL; ELSE RAISE; END IF; END;
/
BEGIN EXECUTE IMMEDIATE 'DROP SEQUENCE DMT_RCV_HEADERS_STG_SEQ'; EXCEPTION WHEN OTHERS THEN IF SQLCODE IN (-2289, -4043) THEN NULL; ELSE RAISE; END IF; END;
/
-- ----------------------------------------------------------------------
-- Migration 2026-10-02: drop the orphan Receiving (RCV) tables + sequences
-- (backlog #25, finish). DMT_RCV_HEADERS_* and DMT_RCV_TRANSACTIONS_* belong
-- to a Receiving import path that the MiscReceipts (On Hand Qty) object never
-- took: the live generator (DMT_MISC_RECEIPT_FBDI_GEN_PKG) writes the
-- Inventory-Transactions tables (DMT_INV_TRX_* / _LOTS_ / _SERIALS_) instead.
-- No package writes the RCV tables; they held 0 rows at runtime while
-- DMT_INV_TRX_TFM_TBL held the real 163 rows. They were pure orphans.
--
-- PRE-REQUISITE (same PR, applied first): the eight views that still mapped the
-- MiscReceipts CEMLI onto the empty RCV tables are repointed to DMT_INV_TRX_*:
--   dmt_v_cemli_tfm_tables, dmt_v_cemli_status, dmt_object_detail_v,
--   dmt_record_detail_v, dmt_run_records_v, dmt_run_status_v,
--   dmt_scenario_summary_v, plus the two drill views
--   dmt_rcv_headers_detail_v / dmt_rcv_transactions_detail_v (retained by name
--   so app-500 page 4 keeps working, now sourced from DMT_INV_TRX_*). Because
--   nothing references the RCV base tables after the repoint, dropping them
--   leaves no dangling refs and the 0-invalid gate holds.
--
-- The CREATE files (db/tables/dmt_rcv_*_{stg,tfm}_tbl.sql,
-- db/sequences/dmt_rcv_*_{stg,tfm}_seq.sql) and their @@ lines in
-- db/install.sql are removed in the same change, plus the RCV foreign-key
-- blocks in db/tables/_foreign_keys.sql, so the database converges to git by
-- dropping these objects.
--
-- The historical migration db/migrations/2026-09-25_stg_seq_recover_466.sql
-- names the two RCV STG tables in its (table -> sequence) map, but that loop is
-- guarded (it skips any table/sequence that is missing), so it stays a safe
-- no-op after this drop and is intentionally left untouched.
--
-- Drop order is defensive, not strictly required: every DROP uses CASCADE
-- CONSTRAINTS so inbound foreign keys (TFM -> STG, plus the WORK_QUEUE and
-- FBDI_CSV keys) are cleared regardless of order. TFM tables are still listed
-- before their STG parents, and sequences after the tables that DEFAULT from
-- them, for readability.
--
-- Idempotent (matches the sibling drop-migration pattern): each drop is wrapped
-- in a guarded block that swallows ORA-00942 / ORA-04043 (table/object gone)
-- and ORA-02289 (sequence gone), so a re-run on a database where the objects
-- are already dropped is a no-op.
--
-- The executable blocks lead on purpose: the deploy runner
-- (scripts/dmt_deploy.py) splits a migration on ";\n" / "/\n" and skips any
-- chunk that begins with "--". Each PL/SQL block is one physical line and its
-- "/" terminator is alone on its own line (backlog #81).
-- ----------------------------------------------------------------------
