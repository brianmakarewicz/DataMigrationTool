-- PACKAGE BODY DMT_WORKER_RESULTS_PKG

  CREATE OR REPLACE EDITIONABLE PACKAGE BODY "DMT_WORKER_RESULTS_PKG" 
AS
-- ============================================================
-- DMT_WORKER_RESULTS_PKG body
-- Worker HDL reconciliation via DMT_HDL_UTIL_PKG.
-- ============================================================

    C_PKG   CONSTANT VARCHAR2(50) := 'DMT_WORKER_RESULTS_PKG';
    C_CEMLI CONSTANT VARCHAR2(30) := 'Workers';

    -- --------------------------------------------------------
    -- CONFIRM_REFERENCE_ROUNDTRIP (private)
    -- Backlog #12 round-trip proof for one just-LOADED Worker base row (HDL family
    -- template; mirrors DMT_GL_RESULTS_PKG.CONFIRM_REFERENCE_ROUNDTRIP). For HDL persons the
    -- carrier is Slot A: SourceSystemId (= the prefixed PERSON_NUMBER we wrote into
    -- Worker.dat) lands in HRC_INTEGRATION_KEY_MAP.SOURCE_SYSTEM_ID and comes back as
    -- the recon report's RECORD_KEY (= PER_ALL_PEOPLE_F.PERSON_NUMBER). So the proof
    -- is: the base RECORD_KEY equals the Slot A value the TFM row carries as
    -- RECON_KEY -- the value we stamped survived to the Fusion base table and
    -- returned unchanged. There is NO Slot C for HDL persons, so the full reference
    -- (BUILD_REF = DMT:run:wq:tfm) is logged for audit alongside the confirmed Slot A
    -- carrier. Diagnostic only: a mismatch or lookup miss logs WARN and NEVER alters
    -- the LOADED outcome (design section 7).
    -- --------------------------------------------------------
    PROCEDURE CONFIRM_REFERENCE_ROUNDTRIP (
        p_run_id     IN NUMBER,
        p_record_key IN VARCHAR2,
        p_fusion_id  IN NUMBER
    ) IS
        C_PROC        CONSTANT VARCHAR2(30) := 'CONFIRM_REFERENCE_ROUNDTRIP';
        l_slot_a      VARCHAR2(1000);
        l_full_ref    VARCHAR2(150);
    BEGIN
        -- Read the Slot A carrier (RECON_KEY) and the full reference for the matched
        -- TFM row. RECON_KEY is exactly what the generator wrote as SourceSystemId.
        SELECT RECON_KEY,
               DMT_REF_ID_PKG.BUILD_REF(RUN_ID, WORK_QUEUE_ID, TFM_SEQUENCE_ID)
          INTO l_slot_a, l_full_ref
          FROM DMT_WORKER_TFM_TBL
         WHERE RUN_ID = p_run_id AND RECON_KEY = p_record_key
           AND ROWNUM = 1;

        IF p_record_key IS NOT NULL AND p_record_key = l_slot_a THEN
            DMT_UTIL_PKG.LOG(p_run_id,
                'REF #12 round-trip OK for RECON_KEY ' || p_record_key ||
                ': Slot A SourceSystemId returned from the base table '
                || '(HRC_INTEGRATION_KEY_MAP.SOURCE_SYSTEM_ID -> PER_ALL_PEOPLE_F, '
                || 'PERSON_ID=' || p_fusion_id || ') = ' || l_slot_a ||
                '. Full ref (audit, no Slot C for HDL): ' || l_full_ref || '.',
                'INFO', C_PKG, C_PROC);
        ELSE
            DMT_UTIL_PKG.LOG(p_run_id,
                'REF #12 round-trip MISMATCH for RECON_KEY ' || p_record_key ||
                ': base RECORD_KEY=' || NVL(p_record_key, '(null)') ||
                ' expected Slot A=' || l_slot_a || '.',
                DMT_UTIL_PKG.C_LOG_WARN, C_PKG, C_PROC);
        END IF;
    EXCEPTION
        WHEN NO_DATA_FOUND THEN
            DMT_UTIL_PKG.LOG(p_run_id,
                'REF #12 round-trip: no TFM row found for RECON_KEY ' ||
                p_record_key || ' (proof skipped).',
                DMT_UTIL_PKG.C_LOG_WARN, C_PKG, C_PROC);
    END CONFIRM_REFERENCE_ROUNDTRIP;

    -- --------------------------------------------------------
    -- MARK_COMPONENT_LOADED (private)  -- backlog #289
    -- A person component (name, email, phone, address, national identifier,
    -- legislative data) is LOADED only from its OWN proof row in the Workers recon
    -- report (V2): OBJECT_TYPE = the key-map object, RECORD_KEY = the exact
    -- SourceSystemId the generator wrote for that component
    -- (<PERSON_NUMBER>_NME/_EML/_PHN/_ADR/_NID/_LEG), FUSION_ID = the component's
    -- own base-table id (key-map surrogate confirmed in its base table). The row is
    -- matched on that exact SourceSystemId, never on its parent worker's verdict
    -- (the former "parent LOADED, so component LOADED" cascade is gone). Static
    -- UPDATEs, one per component table. Returns the number of rows marked.
    -- --------------------------------------------------------
    FUNCTION MARK_COMPONENT_LOADED (
        p_run_id      IN NUMBER,
        p_object_type IN VARCHAR2,
        p_record_key  IN VARCHAR2,
        p_fusion_id   IN NUMBER
    ) RETURN NUMBER IS
        l_rc NUMBER := 0;
    BEGIN
        CASE
            WHEN p_object_type = 'PersonName' THEN
                UPDATE DMT_PERSON_NAME_TFM_TBL
                SET    TFM_STATUS            = 'LOADED',
                       FUSION_PERSON_NAME_ID = p_fusion_id,
                       RESULTS_UPDATED_DATE  = SYSDATE,
                       LAST_UPDATED_DATE     = SYSDATE
                WHERE  RUN_ID = p_run_id
                AND    PERSON_NUMBER || '_NME' = p_record_key
                AND    TFM_STATUS NOT IN ('LOADED', 'FAILED');
                l_rc := SQL%ROWCOUNT;
            WHEN p_object_type = 'EmailAddress' THEN
                UPDATE DMT_PERSON_EMAIL_TFM_TBL
                SET    TFM_STATUS              = 'LOADED',
                       FUSION_EMAIL_ADDRESS_ID = p_fusion_id,
                       RESULTS_UPDATED_DATE    = SYSDATE,
                       LAST_UPDATED_DATE       = SYSDATE
                WHERE  RUN_ID = p_run_id
                AND    PERSON_NUMBER || '_EML' = p_record_key
                AND    TFM_STATUS NOT IN ('LOADED', 'FAILED');
                l_rc := SQL%ROWCOUNT;
            WHEN p_object_type = 'Phone' THEN
                UPDATE DMT_PERSON_PHONE_TFM_TBL
                SET    TFM_STATUS           = 'LOADED',
                       FUSION_PHONE_ID      = p_fusion_id,
                       RESULTS_UPDATED_DATE = SYSDATE,
                       LAST_UPDATED_DATE    = SYSDATE
                WHERE  RUN_ID = p_run_id
                AND    PERSON_NUMBER || '_PHN' = p_record_key
                AND    TFM_STATUS NOT IN ('LOADED', 'FAILED');
                l_rc := SQL%ROWCOUNT;
            WHEN p_object_type IN ('Address', 'PersonAddress') THEN
                UPDATE DMT_PERSON_ADDR_TFM_TBL
                SET    TFM_STATUS           = 'LOADED',
                       FUSION_ADDRESS_ID    = p_fusion_id,
                       RESULTS_UPDATED_DATE = SYSDATE,
                       LAST_UPDATED_DATE    = SYSDATE
                WHERE  RUN_ID = p_run_id
                AND    PERSON_NUMBER || '_ADR' = p_record_key
                AND    TFM_STATUS NOT IN ('LOADED', 'FAILED');
                l_rc := SQL%ROWCOUNT;
            WHEN p_object_type = 'NationalIdentifier' THEN
                UPDATE DMT_PERSON_NID_TFM_TBL
                SET    TFM_STATUS                    = 'LOADED',
                       FUSION_NATIONAL_IDENTIFIER_ID = p_fusion_id,
                       RESULTS_UPDATED_DATE          = SYSDATE,
                       LAST_UPDATED_DATE             = SYSDATE
                WHERE  RUN_ID = p_run_id
                AND    PERSON_NUMBER || '_NID' = p_record_key
                AND    TFM_STATUS NOT IN ('LOADED', 'FAILED');
                l_rc := SQL%ROWCOUNT;
            WHEN p_object_type = 'PersonLegislativeInfo' THEN
                UPDATE DMT_PERSON_LEGISL_TFM_TBL
                SET    TFM_STATUS           = 'LOADED',
                       FUSION_PERSON_ID     = p_fusion_id,
                       RESULTS_UPDATED_DATE = SYSDATE,
                       LAST_UPDATED_DATE    = SYSDATE
                WHERE  RUN_ID = p_run_id
                AND    PERSON_NUMBER || '_LEG' = p_record_key
                AND    TFM_STATUS NOT IN ('LOADED', 'FAILED');
                l_rc := SQL%ROWCOUNT;
            ELSE
                l_rc := 0;  -- not a person-component object type
        END CASE;
        RETURN l_rc;
    END MARK_COMPONENT_LOADED;

    -- --------------------------------------------------------
    -- APPLY_CONTRACT_V1_WORKERS (private)
    -- The Contract v1 base-tier positive proof for the Worker record (design
    -- section 5), Option A shape (owner decision on PR #248). The shared package
    -- DMT_RECON_CONTRACT_PKG.FETCH_ROWS runs the Workers recon report over BIP and
    -- returns the parsed rows (no dynamic SQL, no TFM reference there); the APPLY
    -- here is STATIC SQL against the compile-time-known Worker TFM table. It confirms
    -- each migrated worker in the Fusion base table (PER_ALL_PEOPLE_F) by person
    -- number and marks that Worker TFM row LOADED with the real Fusion person id
    -- stamped into FUSION_PERSON_ID; any ERROR row is marked FAILED with the real
    -- Fusion error. This REPLACES the bulk LOOKUP_FUSION_IDS positive path for
    -- Workers. The single-record REST "Verify in Fusion" button path is unchanged.
    -- The HDL data set request id is the Contract v1 P_LOAD_REQUEST_ID. This is the
    -- template the other 13 HDL objects copy.
    -- --------------------------------------------------------
    PROCEDURE APPLY_CONTRACT_V1_WORKERS (
        p_run_id     IN NUMBER,
        p_request_id IN VARCHAR2
    ) IS
        C_PROC      CONSTANT VARCHAR2(30) := 'APPLY_CONTRACT_V1_WORKERS';
        l_gen_count NUMBER := 0;
        l_rows      DMT_RECON_CONTRACT_PKG.T_RECON_TBL;
        l_err_code  NUMBER;
        l_loaded    NUMBER := 0;
        l_failed    NUMBER := 0;
        l_rc        NUMBER := 0;    -- backlog #65: rows matched by the current tier
        l_dff_seq   NUMBER;          -- backlog #65 tier 2: TFM_SEQUENCE_ID from DFF_KEY
        l_tier      VARCHAR2(10);    -- backlog #65: which tier matched (audit log)
    BEGIN
        -- Generated-row count is done statically here (not in the shared pkg),
        -- and drives the shared fetch's keyset page-count cap. The V2 report
        -- returns one row per person component too, so count every person tier.
        SELECT (SELECT COUNT(*) FROM DMT_WORKER_TFM_TBL        WHERE RUN_ID = p_run_id)
             + (SELECT COUNT(*) FROM DMT_PERSON_NAME_TFM_TBL   WHERE RUN_ID = p_run_id)
             + (SELECT COUNT(*) FROM DMT_PERSON_EMAIL_TFM_TBL  WHERE RUN_ID = p_run_id)
             + (SELECT COUNT(*) FROM DMT_PERSON_PHONE_TFM_TBL  WHERE RUN_ID = p_run_id)
             + (SELECT COUNT(*) FROM DMT_PERSON_ADDR_TFM_TBL   WHERE RUN_ID = p_run_id)
             + (SELECT COUNT(*) FROM DMT_PERSON_NID_TFM_TBL    WHERE RUN_ID = p_run_id)
             + (SELECT COUNT(*) FROM DMT_PERSON_LEGISL_TFM_TBL WHERE RUN_ID = p_run_id)
        INTO   l_gen_count
        FROM   DUAL;

        DMT_RECON_CONTRACT_PKG.FETCH_ROWS(
            p_cemli_code  => C_CEMLI,
            p_run_id      => p_run_id,
            p_load_ess_id => TO_NUMBER(p_request_id),
            p_row_cap     => l_gen_count,
            x_rows        => l_rows,
            x_error_code  => l_err_code);

        -- A transport / SOAP failure raises loudly (design section 5: never a
        -- silent retry, never a zero-row "success"); the fetch already logged detail.
        IF l_err_code <> DMT_UTIL_PKG.C_SUCCESS THEN
            RAISE_APPLICATION_ERROR(-20094,
                'APPLY_CONTRACT_V1_WORKERS: Contract v1 fetch failed for Workers '
                || '(detail in DMT_LOG_TBL).');
        END IF;

        IF l_rows.COUNT = 0 THEN
            -- Zero report rows is never success (design section 5): leave the
            -- remaining GENERATED rows for the existing unaccounted sweep.
            DMT_UTIL_PKG.LOG(
                p_run_id    => p_run_id,
                p_message   => C_PROC || ': Workers recon report returned zero rows; '
                               || 'GENERATED rows left for the unaccounted sweep '
                               || '(never a silent success).',
                p_log_type  => DMT_UTIL_PKG.C_LOG_WARN,
                p_package   => C_PKG,
                p_procedure => C_PROC);
        ELSE
            FOR i IN 1 .. l_rows.COUNT LOOP
                l_rc   := 0;     -- backlog #65: reset per row so a prior row's tier
                l_tier := NULL;  -- cannot mislabel this row's audit log line.
                IF l_rows(i).SOURCE_TYPE = 'BASE'
                   AND l_rows(i).FUSION_STATUS = 'SUCCESS'
                   AND l_rows(i).FUSION_ID IS NOT NULL
                   AND l_rows(i).OBJECT_TYPE = 'Person' THEN
                    -- Positive proof: person found in PER_ALL_PEOPLE_F with a
                    -- real id. The ONLY path to LOADED.
                    --
                    -- Backlog #65 three-tier match (owner order on PR #481). Tier 1 is
                    -- the stamped Slot A reference (RECON_KEY = RECORD_KEY, exactly as
                    -- before). Only if tier 1 matches NO TFM row do we fall through:
                    -- tier 2 (the Slot C DFF stamp: TFM_SEQUENCE_ID = the trailing
                    -- segment of DFF_KEY) -- for HDL persons there is NO DFF carrier so
                    -- DFF_KEY is null and tier 2 is skipped -- and then tier 3 (the
                    -- business key: PERSON_NUMBER = BUSINESS_KEY, the SourceSystemId the
                    -- report returns as SOURCE_REF). Every tier-1 hit short-circuits, so
                    -- loaded outcomes are identical to before. Static UPDATEs.
                    UPDATE DMT_WORKER_TFM_TBL
                    SET    TFM_STATUS           = 'LOADED',
                           FUSION_PERSON_ID     = l_rows(i).FUSION_ID,
                           RESULTS_UPDATED_DATE = SYSDATE,
                           LAST_UPDATED_DATE    = SYSDATE
                    WHERE  RUN_ID    = p_run_id
                    AND    RECON_KEY = l_rows(i).RECORD_KEY
                    AND    TFM_STATUS NOT IN ('LOADED', 'FAILED');
                    l_rc := SQL%ROWCOUNT;
                    l_tier := CASE WHEN l_rc > 0 THEN 'TIER1' END;

                    -- Tier 2 (DFF): only when tier 1 matched nothing and a DFF stamp is
                    -- present. HDL persons have no DFF carrier, so this is normally a
                    -- no-op; kept uniform with the shared three-tier template.
                    IF l_rc = 0 AND l_rows(i).DFF_KEY IS NOT NULL THEN
                        l_dff_seq := TO_NUMBER(
                            REGEXP_SUBSTR(l_rows(i).DFF_KEY, '[0-9]+$') DEFAULT NULL ON CONVERSION ERROR);
                        IF l_dff_seq IS NOT NULL THEN
                            UPDATE DMT_WORKER_TFM_TBL
                            SET    TFM_STATUS           = 'LOADED',
                                   FUSION_PERSON_ID     = l_rows(i).FUSION_ID,
                                   RESULTS_UPDATED_DATE = SYSDATE,
                                   LAST_UPDATED_DATE    = SYSDATE
                            WHERE  RUN_ID    = p_run_id
                            AND    TFM_SEQUENCE_ID = l_dff_seq
                            AND    TFM_STATUS NOT IN ('LOADED', 'FAILED');
                            l_rc := SQL%ROWCOUNT;
                            IF l_rc > 0 THEN l_tier := 'TIER2'; END IF;
                        END IF;
                    END IF;

                    -- Tier 3 (business key): last resort, only when tiers 1 and 2 both
                    -- matched nothing. The worker's business key is PERSON_NUMBER, equal
                    -- to the SourceSystemId the report returns as BUSINESS_KEY.
                    IF l_rc = 0 AND l_rows(i).BUSINESS_KEY IS NOT NULL THEN
                        UPDATE DMT_WORKER_TFM_TBL
                        SET    TFM_STATUS           = 'LOADED',
                               FUSION_PERSON_ID     = l_rows(i).FUSION_ID,
                               RESULTS_UPDATED_DATE = SYSDATE,
                               LAST_UPDATED_DATE    = SYSDATE
                        WHERE  RUN_ID    = p_run_id
                        AND    PERSON_NUMBER = l_rows(i).BUSINESS_KEY
                        AND    TFM_STATUS NOT IN ('LOADED', 'FAILED');
                        l_rc := SQL%ROWCOUNT;
                        IF l_rc > 0 THEN l_tier := 'TIER3'; END IF;
                    END IF;

                    l_loaded := l_loaded + l_rc;
                    IF l_tier IN ('TIER2','TIER3') THEN
                        DMT_UTIL_PKG.LOG(p_run_id,
                            C_PROC || ': matched a LOADED Worker via ' || l_tier ||
                            ' fallback (tier 1 stamped ref did not resolve). PERSON_ID '
                            || l_rows(i).FUSION_ID || '.', 'INFO', C_PKG, C_PROC);
                    END IF;

                    -- Backlog #12 round-trip proof (Slot A): confirm the base
                    -- RECORD_KEY that came back equals the SourceSystemId (RECON_KEY)
                    -- we wrote for this TFM row. Private proc so this loop keeps one
                    -- BEGIN/END (design section 7 coding standard).
                    -- Backlog #65: the Slot A proof is meaningful ONLY when tier 1
                    -- matched (RECON_KEY = RECORD_KEY). On a tier-3 fallback the match
                    -- was made on the business key, so RECON_KEY deliberately did not
                    -- equal RECORD_KEY -- running the Slot A proof there would log a
                    -- guaranteed, misleading MISMATCH. Gate it to tier 1.
                    IF l_tier = 'TIER1' THEN
                        CONFIRM_REFERENCE_ROUNDTRIP(
                            p_run_id     => p_run_id,
                            p_record_key => l_rows(i).RECORD_KEY,
                            p_fusion_id  => l_rows(i).FUSION_ID);
                    END IF;

                ELSIF l_rows(i).SOURCE_TYPE = 'BASE'
                      AND l_rows(i).FUSION_STATUS = 'SUCCESS'
                      AND l_rows(i).FUSION_ID IS NOT NULL
                      AND l_rows(i).OBJECT_TYPE IN
                          ('PersonName','EmailAddress','Phone','Address','PersonAddress',
                           'NationalIdentifier','PersonLegislativeInfo') THEN
                    -- Backlog #289: a person component is LOADED only from its OWN
                    -- proof row (key-map surrogate confirmed in the component's base
                    -- table, report V2), matched on the exact SourceSystemId the
                    -- generator wrote, and stamped with its own Fusion id. Never from
                    -- the parent worker's verdict.
                    l_loaded := l_loaded + MARK_COMPONENT_LOADED(
                        p_run_id      => p_run_id,
                        p_object_type => l_rows(i).OBJECT_TYPE,
                        p_record_key  => l_rows(i).RECORD_KEY,
                        p_fusion_id   => l_rows(i).FUSION_ID);

                ELSIF l_rows(i).FUSION_STATUS = 'ERROR'
                      AND l_rows(i).ERROR_MESSAGE IS NOT NULL
                      AND l_rows(i).OBJECT_TYPE = 'Person' THEN
                    -- A real, specific Fusion error -> FAILED on the exact
                    -- message (never composed). Static UPDATE.
                    UPDATE DMT_WORKER_TFM_TBL
                    SET    TFM_STATUS           = 'FAILED',
                           ERROR_TEXT           = DMT_UTIL_PKG.APPEND_ERROR(
                                                    ERROR_TEXT,
                                                    '[FUSION_ERROR] ' || l_rows(i).ERROR_MESSAGE),
                           RESULTS_UPDATED_DATE = SYSDATE,
                           LAST_UPDATED_DATE    = SYSDATE
                    WHERE  RUN_ID    = p_run_id
                    AND    RECON_KEY = l_rows(i).RECORD_KEY
                    AND    TFM_STATUS NOT IN ('LOADED', 'FAILED');
                    l_failed := l_failed + SQL%ROWCOUNT;

                ELSE
                    -- INTERFACE/SUCCESS (corroborating, never sufficient) or a
                    -- non-terminal status with no real error: leave the row for
                    -- the existing unaccounted sweep. Never fabricate an outcome.
                    NULL;
                END IF;
            END LOOP;
        END IF;

        -- Backlog #289: no parent-verdict cascade. Each person component is
        -- LOADED only from its own proof row above; a component Fusion rejected
        -- with its document is FAILED by PROPAGATE_DOCUMENT_ERRORS, quoting the
        -- real error of the record that failed.

        DMT_UTIL_PKG.LOG(
            p_run_id    => p_run_id,
            p_message   => C_PROC || ' complete. Report rows: ' || l_rows.COUNT
                           || ' | LOADED: ' || l_loaded
                           || ' | FAILED: ' || l_failed
                           || '.',
            p_package   => C_PKG,
            p_procedure => C_PROC);

    EXCEPTION
        WHEN OTHERS THEN
            DMT_UTIL_PKG.LOG_ERROR(
                p_run_id    => p_run_id,
                p_message   => C_PROC || ' failed.',
                p_sqlerrm   => SQLERRM,
                p_package   => C_PKG,
                p_procedure => C_PROC);
            RAISE;
    END APPLY_CONTRACT_V1_WORKERS;

    -- --------------------------------------------------------
    -- APPLY_HDL_ERRORS (private, backlog #288)
    -- Per-record HDL errors, static SQL. DMT_HDL_UTIL_PKG.STAGE_HDL_MESSAGES has
    -- already staged every page of this data set's error messages in
    -- DMT_HDL_MESSAGE_GTT. A GENERATED row is marked FAILED only when a message
    -- names EXACTLY the SourceSystemId its generator wrote for it (never LIKE,
    -- never a prefix), and it gets that message, named:
    --   [FUSION_ERROR] <SourceSystemId> (<file> line <n>): <Fusion message>
    -- Replaces the dynamic-SQL DMT_HDL_UTIL_PKG.RECONCILE_HDL.
    -- --------------------------------------------------------
    PROCEDURE APPLY_HDL_ERRORS (
        p_run_id     IN NUMBER,
        p_request_id IN VARCHAR2
    ) IS
        C_PROC    CONSTANT VARCHAR2(30) := 'APPLY_HDL_ERRORS';
        l_request NUMBER := TO_NUMBER(p_request_id);
        l_failed  NUMBER := 0;
    BEGIN
        -- DMT_WORKER_TFM_TBL: SourceSystemId = PERSON_NUMBER
        UPDATE DMT_WORKER_TFM_TBL t
        SET    t.TFM_STATUS           = 'FAILED',
               t.ERROR_TEXT           = DMT_UTIL_PKG.APPEND_ERROR(t.ERROR_TEXT,
                                            DMT_HDL_UTIL_PKG.ROW_ERRORS(p_request_id, t.PERSON_NUMBER)),
               t.RESULTS_UPDATED_DATE = SYSDATE,
               t.LAST_UPDATED_DATE    = SYSDATE
        WHERE  t.RUN_ID     = p_run_id
        AND    t.TFM_STATUS = 'GENERATED'
        AND    EXISTS (SELECT 1
                       FROM   DMT_HDL_MESSAGE_GTT m
                       WHERE  m.REQUEST_ID       = l_request
                       AND    m.SOURCE_SYSTEM_ID IN (t.PERSON_NUMBER));
        l_failed := l_failed + SQL%ROWCOUNT;

        -- DMT_PERSON_NAME_TFM_TBL: SourceSystemId = PERSON_NUMBER || '_NME'
        UPDATE DMT_PERSON_NAME_TFM_TBL t
        SET    t.TFM_STATUS           = 'FAILED',
               t.ERROR_TEXT           = DMT_UTIL_PKG.APPEND_ERROR(t.ERROR_TEXT,
                                            DMT_HDL_UTIL_PKG.ROW_ERRORS(p_request_id, t.PERSON_NUMBER || '_NME')),
               t.RESULTS_UPDATED_DATE = SYSDATE,
               t.LAST_UPDATED_DATE    = SYSDATE
        WHERE  t.RUN_ID     = p_run_id
        AND    t.TFM_STATUS = 'GENERATED'
        AND    EXISTS (SELECT 1
                       FROM   DMT_HDL_MESSAGE_GTT m
                       WHERE  m.REQUEST_ID       = l_request
                       AND    m.SOURCE_SYSTEM_ID IN (t.PERSON_NUMBER || '_NME'));
        l_failed := l_failed + SQL%ROWCOUNT;

        -- DMT_PERSON_EMAIL_TFM_TBL: SourceSystemId = PERSON_NUMBER || '_EML'
        UPDATE DMT_PERSON_EMAIL_TFM_TBL t
        SET    t.TFM_STATUS           = 'FAILED',
               t.ERROR_TEXT           = DMT_UTIL_PKG.APPEND_ERROR(t.ERROR_TEXT,
                                            DMT_HDL_UTIL_PKG.ROW_ERRORS(p_request_id, t.PERSON_NUMBER || '_EML')),
               t.RESULTS_UPDATED_DATE = SYSDATE,
               t.LAST_UPDATED_DATE    = SYSDATE
        WHERE  t.RUN_ID     = p_run_id
        AND    t.TFM_STATUS = 'GENERATED'
        AND    EXISTS (SELECT 1
                       FROM   DMT_HDL_MESSAGE_GTT m
                       WHERE  m.REQUEST_ID       = l_request
                       AND    m.SOURCE_SYSTEM_ID IN (t.PERSON_NUMBER || '_EML'));
        l_failed := l_failed + SQL%ROWCOUNT;

        -- DMT_PERSON_PHONE_TFM_TBL: SourceSystemId = PERSON_NUMBER || '_PHN'
        UPDATE DMT_PERSON_PHONE_TFM_TBL t
        SET    t.TFM_STATUS           = 'FAILED',
               t.ERROR_TEXT           = DMT_UTIL_PKG.APPEND_ERROR(t.ERROR_TEXT,
                                            DMT_HDL_UTIL_PKG.ROW_ERRORS(p_request_id, t.PERSON_NUMBER || '_PHN')),
               t.RESULTS_UPDATED_DATE = SYSDATE,
               t.LAST_UPDATED_DATE    = SYSDATE
        WHERE  t.RUN_ID     = p_run_id
        AND    t.TFM_STATUS = 'GENERATED'
        AND    EXISTS (SELECT 1
                       FROM   DMT_HDL_MESSAGE_GTT m
                       WHERE  m.REQUEST_ID       = l_request
                       AND    m.SOURCE_SYSTEM_ID IN (t.PERSON_NUMBER || '_PHN'));
        l_failed := l_failed + SQL%ROWCOUNT;

        -- DMT_PERSON_ADDR_TFM_TBL: SourceSystemId = PERSON_NUMBER || '_ADR'
        UPDATE DMT_PERSON_ADDR_TFM_TBL t
        SET    t.TFM_STATUS           = 'FAILED',
               t.ERROR_TEXT           = DMT_UTIL_PKG.APPEND_ERROR(t.ERROR_TEXT,
                                            DMT_HDL_UTIL_PKG.ROW_ERRORS(p_request_id, t.PERSON_NUMBER || '_ADR')),
               t.RESULTS_UPDATED_DATE = SYSDATE,
               t.LAST_UPDATED_DATE    = SYSDATE
        WHERE  t.RUN_ID     = p_run_id
        AND    t.TFM_STATUS = 'GENERATED'
        AND    EXISTS (SELECT 1
                       FROM   DMT_HDL_MESSAGE_GTT m
                       WHERE  m.REQUEST_ID       = l_request
                       AND    m.SOURCE_SYSTEM_ID IN (t.PERSON_NUMBER || '_ADR'));
        l_failed := l_failed + SQL%ROWCOUNT;

        -- DMT_PERSON_NID_TFM_TBL: SourceSystemId = PERSON_NUMBER || '_NID'
        UPDATE DMT_PERSON_NID_TFM_TBL t
        SET    t.TFM_STATUS           = 'FAILED',
               t.ERROR_TEXT           = DMT_UTIL_PKG.APPEND_ERROR(t.ERROR_TEXT,
                                            DMT_HDL_UTIL_PKG.ROW_ERRORS(p_request_id, t.PERSON_NUMBER || '_NID')),
               t.RESULTS_UPDATED_DATE = SYSDATE,
               t.LAST_UPDATED_DATE    = SYSDATE
        WHERE  t.RUN_ID     = p_run_id
        AND    t.TFM_STATUS = 'GENERATED'
        AND    EXISTS (SELECT 1
                       FROM   DMT_HDL_MESSAGE_GTT m
                       WHERE  m.REQUEST_ID       = l_request
                       AND    m.SOURCE_SYSTEM_ID IN (t.PERSON_NUMBER || '_NID'));
        l_failed := l_failed + SQL%ROWCOUNT;

        -- DMT_PERSON_LEGISL_TFM_TBL: SourceSystemId = PERSON_NUMBER || '_LEG'
        UPDATE DMT_PERSON_LEGISL_TFM_TBL t
        SET    t.TFM_STATUS           = 'FAILED',
               t.ERROR_TEXT           = DMT_UTIL_PKG.APPEND_ERROR(t.ERROR_TEXT,
                                            DMT_HDL_UTIL_PKG.ROW_ERRORS(p_request_id, t.PERSON_NUMBER || '_LEG')),
               t.RESULTS_UPDATED_DATE = SYSDATE,
               t.LAST_UPDATED_DATE    = SYSDATE
        WHERE  t.RUN_ID     = p_run_id
        AND    t.TFM_STATUS = 'GENERATED'
        AND    EXISTS (SELECT 1
                       FROM   DMT_HDL_MESSAGE_GTT m
                       WHERE  m.REQUEST_ID       = l_request
                       AND    m.SOURCE_SYSTEM_ID IN (t.PERSON_NUMBER || '_LEG'));
        l_failed := l_failed + SQL%ROWCOUNT;

        DMT_UTIL_PKG.LOG(
            p_run_id    => p_run_id,
            p_message   => C_PROC || ' complete. Rows FAILED on their own named HDL error: ' || l_failed || '.',
            p_package   => C_PKG,
            p_procedure => C_PROC);

    EXCEPTION
        WHEN OTHERS THEN
            DMT_UTIL_PKG.LOG_ERROR(
                p_run_id    => p_run_id,
                p_message   => C_PROC || ' failed.',
                p_sqlerrm   => SQLERRM,
                p_package   => C_PKG,
                p_procedure => C_PROC);
            RAISE;
    END APPLY_HDL_ERRORS;

    -- --------------------------------------------------------
    -- APPLY_FILE_ERRORS (private, backlog #288)
    -- Whole-file rejections, static SQL. Messages that name no record (no
    -- SourceSystemId: an invalid METADATA line, an unknown file, a data-set
    -- message) reject every record of their .dat file. They are applied LAST,
    -- after the per-record errors and the base-table proof, and only to rows
    -- still GENERATED, so a row proven LOADED or already FAILED on its own error
    -- is never touched. The text is Fusion's own, named with the file and line.
    -- --------------------------------------------------------
    PROCEDURE APPLY_FILE_ERRORS (
        p_run_id     IN NUMBER,
        p_request_id IN VARCHAR2
    ) IS
        C_PROC   CONSTANT VARCHAR2(30) := 'APPLY_FILE_ERRORS';
        l_text   VARCHAR2(4000);
        l_failed NUMBER := 0;
    BEGIN
        -- DMT_WORKER_TFM_TBL: whole-file messages of Worker.dat
        l_text := DMT_HDL_UTIL_PKG.FILE_LEVEL_ERRORS(p_request_id, 'Worker.dat');
        IF l_text IS NOT NULL THEN
            UPDATE DMT_WORKER_TFM_TBL t
            SET    t.TFM_STATUS           = 'FAILED',
                   t.ERROR_TEXT           = DMT_UTIL_PKG.APPEND_ERROR(t.ERROR_TEXT, l_text),
                   t.RESULTS_UPDATED_DATE = SYSDATE,
                   t.LAST_UPDATED_DATE    = SYSDATE
            WHERE  t.RUN_ID     = p_run_id
            AND    t.TFM_STATUS = 'GENERATED';
            l_failed := l_failed + SQL%ROWCOUNT;
        END IF;

        -- DMT_PERSON_NAME_TFM_TBL: whole-file messages of Worker.dat
        l_text := DMT_HDL_UTIL_PKG.FILE_LEVEL_ERRORS(p_request_id, 'Worker.dat');
        IF l_text IS NOT NULL THEN
            UPDATE DMT_PERSON_NAME_TFM_TBL t
            SET    t.TFM_STATUS           = 'FAILED',
                   t.ERROR_TEXT           = DMT_UTIL_PKG.APPEND_ERROR(t.ERROR_TEXT, l_text),
                   t.RESULTS_UPDATED_DATE = SYSDATE,
                   t.LAST_UPDATED_DATE    = SYSDATE
            WHERE  t.RUN_ID     = p_run_id
            AND    t.TFM_STATUS = 'GENERATED';
            l_failed := l_failed + SQL%ROWCOUNT;
        END IF;

        -- DMT_PERSON_EMAIL_TFM_TBL: whole-file messages of Worker.dat
        l_text := DMT_HDL_UTIL_PKG.FILE_LEVEL_ERRORS(p_request_id, 'Worker.dat');
        IF l_text IS NOT NULL THEN
            UPDATE DMT_PERSON_EMAIL_TFM_TBL t
            SET    t.TFM_STATUS           = 'FAILED',
                   t.ERROR_TEXT           = DMT_UTIL_PKG.APPEND_ERROR(t.ERROR_TEXT, l_text),
                   t.RESULTS_UPDATED_DATE = SYSDATE,
                   t.LAST_UPDATED_DATE    = SYSDATE
            WHERE  t.RUN_ID     = p_run_id
            AND    t.TFM_STATUS = 'GENERATED';
            l_failed := l_failed + SQL%ROWCOUNT;
        END IF;

        -- DMT_PERSON_PHONE_TFM_TBL: whole-file messages of Worker.dat
        l_text := DMT_HDL_UTIL_PKG.FILE_LEVEL_ERRORS(p_request_id, 'Worker.dat');
        IF l_text IS NOT NULL THEN
            UPDATE DMT_PERSON_PHONE_TFM_TBL t
            SET    t.TFM_STATUS           = 'FAILED',
                   t.ERROR_TEXT           = DMT_UTIL_PKG.APPEND_ERROR(t.ERROR_TEXT, l_text),
                   t.RESULTS_UPDATED_DATE = SYSDATE,
                   t.LAST_UPDATED_DATE    = SYSDATE
            WHERE  t.RUN_ID     = p_run_id
            AND    t.TFM_STATUS = 'GENERATED';
            l_failed := l_failed + SQL%ROWCOUNT;
        END IF;

        -- DMT_PERSON_ADDR_TFM_TBL: whole-file messages of Worker.dat
        l_text := DMT_HDL_UTIL_PKG.FILE_LEVEL_ERRORS(p_request_id, 'Worker.dat');
        IF l_text IS NOT NULL THEN
            UPDATE DMT_PERSON_ADDR_TFM_TBL t
            SET    t.TFM_STATUS           = 'FAILED',
                   t.ERROR_TEXT           = DMT_UTIL_PKG.APPEND_ERROR(t.ERROR_TEXT, l_text),
                   t.RESULTS_UPDATED_DATE = SYSDATE,
                   t.LAST_UPDATED_DATE    = SYSDATE
            WHERE  t.RUN_ID     = p_run_id
            AND    t.TFM_STATUS = 'GENERATED';
            l_failed := l_failed + SQL%ROWCOUNT;
        END IF;

        -- DMT_PERSON_NID_TFM_TBL: whole-file messages of Worker.dat
        l_text := DMT_HDL_UTIL_PKG.FILE_LEVEL_ERRORS(p_request_id, 'Worker.dat');
        IF l_text IS NOT NULL THEN
            UPDATE DMT_PERSON_NID_TFM_TBL t
            SET    t.TFM_STATUS           = 'FAILED',
                   t.ERROR_TEXT           = DMT_UTIL_PKG.APPEND_ERROR(t.ERROR_TEXT, l_text),
                   t.RESULTS_UPDATED_DATE = SYSDATE,
                   t.LAST_UPDATED_DATE    = SYSDATE
            WHERE  t.RUN_ID     = p_run_id
            AND    t.TFM_STATUS = 'GENERATED';
            l_failed := l_failed + SQL%ROWCOUNT;
        END IF;

        -- DMT_PERSON_LEGISL_TFM_TBL: whole-file messages of Worker.dat
        l_text := DMT_HDL_UTIL_PKG.FILE_LEVEL_ERRORS(p_request_id, 'Worker.dat');
        IF l_text IS NOT NULL THEN
            UPDATE DMT_PERSON_LEGISL_TFM_TBL t
            SET    t.TFM_STATUS           = 'FAILED',
                   t.ERROR_TEXT           = DMT_UTIL_PKG.APPEND_ERROR(t.ERROR_TEXT, l_text),
                   t.RESULTS_UPDATED_DATE = SYSDATE,
                   t.LAST_UPDATED_DATE    = SYSDATE
            WHERE  t.RUN_ID     = p_run_id
            AND    t.TFM_STATUS = 'GENERATED';
            l_failed := l_failed + SQL%ROWCOUNT;
        END IF;

        DMT_UTIL_PKG.LOG(
            p_run_id    => p_run_id,
            p_message   => C_PROC || ' complete. Rows FAILED by a whole-file HDL error: ' || l_failed || '.',
            p_package   => C_PKG,
            p_procedure => C_PROC);

    EXCEPTION
        WHEN OTHERS THEN
            DMT_UTIL_PKG.LOG_ERROR(
                p_run_id    => p_run_id,
                p_message   => C_PROC || ' failed.',
                p_sqlerrm   => SQLERRM,
                p_package   => C_PKG,
                p_procedure => C_PROC);
            RAISE;
    END APPLY_FILE_ERRORS;

    -- --------------------------------------------------------
    -- RECONCILE_BATCH
    -- Stages the data set's HDL error messages (all pages), applies each one
    -- to the row whose SourceSystemId it names exactly, applies the base-table
    -- proof (the only path to LOADED), then the whole-file rejections.
    -- --------------------------------------------------------
    PROCEDURE RECONCILE_BATCH (
        p_run_id IN NUMBER,
        p_request_id     IN VARCHAR2,
        p_dataset_status IN VARCHAR2 DEFAULT NULL
    ) IS
        C_PROC CONSTANT VARCHAR2(30) := 'RECONCILE_BATCH';
        l_msg_count NUMBER;  -- HDL error messages staged for this data set
    BEGIN
        DMT_UTIL_PKG.LOG(
            p_run_id => p_run_id,
            p_message        => C_PROC || ' start. RequestId: ' || p_request_id,
            p_package        => C_PKG,
            p_procedure      => C_PROC);

        -- Per-record HDL errors (backlog #288): stage every page of this data
        -- set's error messages, then mark FAILED only the rows a message names
        -- exactly. LOADED comes only from base-table proof; there is no
        -- data-set-status promotion and no write-back to the STG table.
        DMT_HDL_UTIL_PKG.STAGE_HDL_MESSAGES(
            p_run_id        => p_run_id,
            p_request_id    => p_request_id,
            p_log_context   => C_CEMLI,
            x_message_count => l_msg_count,
            p_cemli_code     => C_CEMLI);
        APPLY_HDL_ERRORS(p_run_id, p_request_id);

        -- Contract v1 base-tier positive proof (design section 5), Option A shape
        -- (owner decision on PR #248): the shared package fetches the parsed report
        -- rows (no dynamic SQL, no TFM reference there) and the APPLY is done here
        -- as STATIC SQL against the compile-time-known Worker TFM table. Extracted
        -- into its own private procedure (one BEGIN/END per procedure).
        APPLY_CONTRACT_V1_WORKERS(p_run_id, p_request_id);

        -- Whole-file HDL rejections last, only on rows still open (backlog #288).
        APPLY_FILE_ERRORS(p_run_id, p_request_id);

        DMT_UTIL_PKG.LOG(
            p_run_id => p_run_id,
            p_message        => C_PROC || ' complete. All 7 object types reconciled.',
            p_package        => C_PKG,
            p_procedure      => C_PROC);

    EXCEPTION
        WHEN OTHERS THEN
            DMT_UTIL_PKG.LOG_ERROR(
                p_run_id => p_run_id,
                p_message        => C_PROC || ' failed.',
                p_sqlerrm        => SQLERRM,
                p_package        => C_PKG,
                p_procedure      => C_PROC);
            RAISE;
    END RECONCILE_BATCH;

    -- --------------------------------------------------------
    -- PROPAGATE_DOCUMENT_ERRORS (public) -- backlog #289
    -- Design section 5, "Whole-document rejection carries the real error to every
    -- grain". HCM Data Loader rejects the whole Worker logical object (the person
    -- with every component and assignment in Worker.dat) when one of its records
    -- fails, but reports the error only on that record. Run AFTER both the Worker
    -- and the Assignment RECONCILE_BATCH (per-record errors and base-table proof
    -- applied), every row of such a person that is still GENERATED -- not proven in
    -- Fusion and with no error of its own -- is marked FAILED quoting the real
    -- error of the person's first failing record, named
    --   [FUSION_ERROR] Rejected with document: <business object> <SourceSystemId>: <message>
    -- (DMT_WORKER_DOC_ERROR_V, DMT_UTIL_PKG.FORMAT_DOCUMENT_ERROR). A LOADED row is
    -- never touched, and a row keeps its own error as its own. Static SQL.
    -- --------------------------------------------------------
    PROCEDURE PROPAGATE_DOCUMENT_ERRORS (
        p_run_id     IN NUMBER,
        p_request_id IN VARCHAR2
    ) IS
        C_PROC    CONSTANT VARCHAR2(30) := 'PROPAGATE_DOCUMENT_ERRORS';
        l_request NUMBER := TO_NUMBER(p_request_id);
        l_failed  NUMBER := 0;
    BEGIN
        UPDATE DMT_WORKER_TFM_TBL t
        SET    t.TFM_STATUS           = 'FAILED',
               t.ERROR_TEXT           = DMT_UTIL_PKG.APPEND_ERROR(t.ERROR_TEXT,
                                            (SELECT d.QUOTED_ERROR
                                             FROM   DMT_WORKER_DOC_ERROR_V d
                                             WHERE  d.RUN_ID        = t.RUN_ID
                                             AND    d.REQUEST_ID    = l_request
                                             AND    d.PERSON_NUMBER = t.PERSON_NUMBER)),
               t.RESULTS_UPDATED_DATE = SYSDATE,
               t.LAST_UPDATED_DATE    = SYSDATE
        WHERE  t.RUN_ID     = p_run_id
        AND    t.TFM_STATUS = 'GENERATED'
        AND    EXISTS (SELECT 1
                       FROM   DMT_WORKER_DOC_ERROR_V d
                       WHERE  d.RUN_ID        = t.RUN_ID
                       AND    d.REQUEST_ID    = l_request
                       AND    d.PERSON_NUMBER = t.PERSON_NUMBER);
        l_failed := l_failed + SQL%ROWCOUNT;

        UPDATE DMT_PERSON_NAME_TFM_TBL t
        SET    t.TFM_STATUS           = 'FAILED',
               t.ERROR_TEXT           = DMT_UTIL_PKG.APPEND_ERROR(t.ERROR_TEXT,
                                            (SELECT d.QUOTED_ERROR
                                             FROM   DMT_WORKER_DOC_ERROR_V d
                                             WHERE  d.RUN_ID        = t.RUN_ID
                                             AND    d.REQUEST_ID    = l_request
                                             AND    d.PERSON_NUMBER = t.PERSON_NUMBER)),
               t.RESULTS_UPDATED_DATE = SYSDATE,
               t.LAST_UPDATED_DATE    = SYSDATE
        WHERE  t.RUN_ID     = p_run_id
        AND    t.TFM_STATUS = 'GENERATED'
        AND    EXISTS (SELECT 1
                       FROM   DMT_WORKER_DOC_ERROR_V d
                       WHERE  d.RUN_ID        = t.RUN_ID
                       AND    d.REQUEST_ID    = l_request
                       AND    d.PERSON_NUMBER = t.PERSON_NUMBER);
        l_failed := l_failed + SQL%ROWCOUNT;

        UPDATE DMT_PERSON_EMAIL_TFM_TBL t
        SET    t.TFM_STATUS           = 'FAILED',
               t.ERROR_TEXT           = DMT_UTIL_PKG.APPEND_ERROR(t.ERROR_TEXT,
                                            (SELECT d.QUOTED_ERROR
                                             FROM   DMT_WORKER_DOC_ERROR_V d
                                             WHERE  d.RUN_ID        = t.RUN_ID
                                             AND    d.REQUEST_ID    = l_request
                                             AND    d.PERSON_NUMBER = t.PERSON_NUMBER)),
               t.RESULTS_UPDATED_DATE = SYSDATE,
               t.LAST_UPDATED_DATE    = SYSDATE
        WHERE  t.RUN_ID     = p_run_id
        AND    t.TFM_STATUS = 'GENERATED'
        AND    EXISTS (SELECT 1
                       FROM   DMT_WORKER_DOC_ERROR_V d
                       WHERE  d.RUN_ID        = t.RUN_ID
                       AND    d.REQUEST_ID    = l_request
                       AND    d.PERSON_NUMBER = t.PERSON_NUMBER);
        l_failed := l_failed + SQL%ROWCOUNT;

        UPDATE DMT_PERSON_PHONE_TFM_TBL t
        SET    t.TFM_STATUS           = 'FAILED',
               t.ERROR_TEXT           = DMT_UTIL_PKG.APPEND_ERROR(t.ERROR_TEXT,
                                            (SELECT d.QUOTED_ERROR
                                             FROM   DMT_WORKER_DOC_ERROR_V d
                                             WHERE  d.RUN_ID        = t.RUN_ID
                                             AND    d.REQUEST_ID    = l_request
                                             AND    d.PERSON_NUMBER = t.PERSON_NUMBER)),
               t.RESULTS_UPDATED_DATE = SYSDATE,
               t.LAST_UPDATED_DATE    = SYSDATE
        WHERE  t.RUN_ID     = p_run_id
        AND    t.TFM_STATUS = 'GENERATED'
        AND    EXISTS (SELECT 1
                       FROM   DMT_WORKER_DOC_ERROR_V d
                       WHERE  d.RUN_ID        = t.RUN_ID
                       AND    d.REQUEST_ID    = l_request
                       AND    d.PERSON_NUMBER = t.PERSON_NUMBER);
        l_failed := l_failed + SQL%ROWCOUNT;

        UPDATE DMT_PERSON_ADDR_TFM_TBL t
        SET    t.TFM_STATUS           = 'FAILED',
               t.ERROR_TEXT           = DMT_UTIL_PKG.APPEND_ERROR(t.ERROR_TEXT,
                                            (SELECT d.QUOTED_ERROR
                                             FROM   DMT_WORKER_DOC_ERROR_V d
                                             WHERE  d.RUN_ID        = t.RUN_ID
                                             AND    d.REQUEST_ID    = l_request
                                             AND    d.PERSON_NUMBER = t.PERSON_NUMBER)),
               t.RESULTS_UPDATED_DATE = SYSDATE,
               t.LAST_UPDATED_DATE    = SYSDATE
        WHERE  t.RUN_ID     = p_run_id
        AND    t.TFM_STATUS = 'GENERATED'
        AND    EXISTS (SELECT 1
                       FROM   DMT_WORKER_DOC_ERROR_V d
                       WHERE  d.RUN_ID        = t.RUN_ID
                       AND    d.REQUEST_ID    = l_request
                       AND    d.PERSON_NUMBER = t.PERSON_NUMBER);
        l_failed := l_failed + SQL%ROWCOUNT;

        UPDATE DMT_PERSON_NID_TFM_TBL t
        SET    t.TFM_STATUS           = 'FAILED',
               t.ERROR_TEXT           = DMT_UTIL_PKG.APPEND_ERROR(t.ERROR_TEXT,
                                            (SELECT d.QUOTED_ERROR
                                             FROM   DMT_WORKER_DOC_ERROR_V d
                                             WHERE  d.RUN_ID        = t.RUN_ID
                                             AND    d.REQUEST_ID    = l_request
                                             AND    d.PERSON_NUMBER = t.PERSON_NUMBER)),
               t.RESULTS_UPDATED_DATE = SYSDATE,
               t.LAST_UPDATED_DATE    = SYSDATE
        WHERE  t.RUN_ID     = p_run_id
        AND    t.TFM_STATUS = 'GENERATED'
        AND    EXISTS (SELECT 1
                       FROM   DMT_WORKER_DOC_ERROR_V d
                       WHERE  d.RUN_ID        = t.RUN_ID
                       AND    d.REQUEST_ID    = l_request
                       AND    d.PERSON_NUMBER = t.PERSON_NUMBER);
        l_failed := l_failed + SQL%ROWCOUNT;

        UPDATE DMT_PERSON_LEGISL_TFM_TBL t
        SET    t.TFM_STATUS           = 'FAILED',
               t.ERROR_TEXT           = DMT_UTIL_PKG.APPEND_ERROR(t.ERROR_TEXT,
                                            (SELECT d.QUOTED_ERROR
                                             FROM   DMT_WORKER_DOC_ERROR_V d
                                             WHERE  d.RUN_ID        = t.RUN_ID
                                             AND    d.REQUEST_ID    = l_request
                                             AND    d.PERSON_NUMBER = t.PERSON_NUMBER)),
               t.RESULTS_UPDATED_DATE = SYSDATE,
               t.LAST_UPDATED_DATE    = SYSDATE
        WHERE  t.RUN_ID     = p_run_id
        AND    t.TFM_STATUS = 'GENERATED'
        AND    EXISTS (SELECT 1
                       FROM   DMT_WORKER_DOC_ERROR_V d
                       WHERE  d.RUN_ID        = t.RUN_ID
                       AND    d.REQUEST_ID    = l_request
                       AND    d.PERSON_NUMBER = t.PERSON_NUMBER);
        l_failed := l_failed + SQL%ROWCOUNT;

        UPDATE DMT_WORK_REL_TFM_TBL t
        SET    t.TFM_STATUS           = 'FAILED',
               t.ERROR_TEXT           = DMT_UTIL_PKG.APPEND_ERROR(t.ERROR_TEXT,
                                            (SELECT d.QUOTED_ERROR
                                             FROM   DMT_WORKER_DOC_ERROR_V d
                                             WHERE  d.RUN_ID        = t.RUN_ID
                                             AND    d.REQUEST_ID    = l_request
                                             AND    d.PERSON_NUMBER = t.PERSON_NUMBER)),
               t.RESULTS_UPDATED_DATE = SYSDATE,
               t.LAST_UPDATED_DATE    = SYSDATE
        WHERE  t.RUN_ID     = p_run_id
        AND    t.TFM_STATUS = 'GENERATED'
        AND    EXISTS (SELECT 1
                       FROM   DMT_WORKER_DOC_ERROR_V d
                       WHERE  d.RUN_ID        = t.RUN_ID
                       AND    d.REQUEST_ID    = l_request
                       AND    d.PERSON_NUMBER = t.PERSON_NUMBER);
        l_failed := l_failed + SQL%ROWCOUNT;

        UPDATE DMT_ASSIGNMENT_TFM_TBL t
        SET    t.TFM_STATUS           = 'FAILED',
               t.ERROR_TEXT           = DMT_UTIL_PKG.APPEND_ERROR(t.ERROR_TEXT,
                                            (SELECT d.QUOTED_ERROR
                                             FROM   DMT_WORKER_DOC_ERROR_V d
                                             WHERE  d.RUN_ID        = t.RUN_ID
                                             AND    d.REQUEST_ID    = l_request
                                             AND    d.PERSON_NUMBER = t.PERSON_NUMBER)),
               t.RESULTS_UPDATED_DATE = SYSDATE,
               t.LAST_UPDATED_DATE    = SYSDATE
        WHERE  t.RUN_ID     = p_run_id
        AND    t.TFM_STATUS = 'GENERATED'
        AND    EXISTS (SELECT 1
                       FROM   DMT_WORKER_DOC_ERROR_V d
                       WHERE  d.RUN_ID        = t.RUN_ID
                       AND    d.REQUEST_ID    = l_request
                       AND    d.PERSON_NUMBER = t.PERSON_NUMBER);
        l_failed := l_failed + SQL%ROWCOUNT;

        DMT_UTIL_PKG.LOG(
            p_run_id    => p_run_id,
            p_message   => C_PROC || ' complete. Rows FAILED with their rejected Worker document: '
                           || l_failed || '.',
            p_package   => C_PKG,
            p_procedure => C_PROC);

    EXCEPTION
        WHEN OTHERS THEN
            DMT_UTIL_PKG.LOG_ERROR(
                p_run_id    => p_run_id,
                p_message   => C_PROC || ' failed.',
                p_sqlerrm   => SQLERRM,
                p_package   => C_PKG,
                p_procedure => C_PROC);
            RAISE;
    END PROPAGATE_DOCUMENT_ERRORS;

END DMT_WORKER_RESULTS_PKG;
/
