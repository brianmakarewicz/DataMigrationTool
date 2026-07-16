-- PACKAGE BODY DMT_PO_VALIDATOR_PKG

  CREATE OR REPLACE EDITIONABLE PACKAGE BODY "DMT_PO_VALIDATOR_PKG"
AS
-- ============================================================
-- DMT_PO_VALIDATOR_PKG body
-- PurchaseOrders pre- and post-transform validation.
--
-- Pre-validation rejections are recorded in the run-stamped error table
-- DMT_OWNER.DMT_STG_TFM_ERROR_TBL (design §7); the STG rows keep their
-- status only (no message) and are flagged FAILED afterwards by the
-- standard FLAG_STG_FAILED helper. No validator writes ERROR_TEXT on a
-- *_STG_TBL row.
-- ============================================================

    C_PKG CONSTANT VARCHAR2(50) := 'DMT_PO_VALIDATOR_PKG';

    -- ============================================================
    -- FLAG_STG_FAILED — STANDARD helper (design §7). Marks every STG row FAILED
    -- (status only, no message) that has a DMT_STG_TFM_ERROR_TBL row for this run.
    -- The pre-validation checks record WHY in the error table; this sets the STG
    -- status so FAILED-mode reruns select on it. Byte-identical across validator
    -- packages except the STG table name(s) and the SUB_OBJECT filter (tagged EDIT
    -- regions), like SWEEP_UNACCOUNTED. Does NOT commit — the caller owns the txn.
    -- ============================================================
    PROCEDURE FLAG_STG_FAILED (p_run_id IN NUMBER) IS
    BEGIN
        -- <<EDIT-TABLE — the object's STG table. Repeat this whole UPDATE block
        --   (EDIT-TABLE through the ';') once per STG table the object owns.>>
        UPDATE DMT_OWNER.DMT_PO_HEADERS_INT_STG_TBL
        -- <<END EDIT-TABLE — everything below is FIXED until EDIT-SCOPE>>
        SET    STG_STATUS = 'FAILED', LAST_UPDATED_DATE = SYSDATE
        WHERE  STG_STATUS IN ('NEW','RETRY')
        AND    STG_SEQUENCE_ID IN (SELECT STG_SEQUENCE_ID FROM DMT_OWNER.DMT_STG_TFM_ERROR_TBL
                                   WHERE RUN_ID = p_run_id
        -- <<EDIT-SCOPE — this table's SUB_OBJECT(s). The PO header STG table is
        --   shared by all three PO styles, so match every header label the catalog
        --   registers (PurchaseOrders / BlanketPOs / Contracts).>>
                                   AND SUB_OBJECT IN ('PO Headers','Blanket PO Headers','Contract Headers')
        -- <<END EDIT-SCOPE — nothing below this changes>>
                                  );

        -- <<EDIT-TABLE>>
        UPDATE DMT_OWNER.DMT_PO_LINES_INT_STG_TBL
        -- <<END EDIT-TABLE>>
        SET    STG_STATUS = 'FAILED', LAST_UPDATED_DATE = SYSDATE
        WHERE  STG_STATUS IN ('NEW','RETRY')
        AND    STG_SEQUENCE_ID IN (SELECT STG_SEQUENCE_ID FROM DMT_OWNER.DMT_STG_TFM_ERROR_TBL
                                   WHERE RUN_ID = p_run_id
        -- <<EDIT-SCOPE — shared PO lines STG table: match both line labels
        --   the catalog registers (PurchaseOrders / BlanketPOs).>>
                                   AND SUB_OBJECT IN ('PO Lines','Blanket PO Lines')
        -- <<END EDIT-SCOPE>>
                                  );

        -- <<EDIT-TABLE>>
        UPDATE DMT_OWNER.DMT_PO_LINE_LOCS_INT_STG_TBL
        -- <<END EDIT-TABLE>>
        SET    STG_STATUS = 'FAILED', LAST_UPDATED_DATE = SYSDATE
        WHERE  STG_STATUS IN ('NEW','RETRY')
        AND    STG_SEQUENCE_ID IN (SELECT STG_SEQUENCE_ID FROM DMT_OWNER.DMT_STG_TFM_ERROR_TBL
                                   WHERE RUN_ID = p_run_id
        -- <<EDIT-SCOPE>>
                                   AND SUB_OBJECT = 'PO Line Locations'
        -- <<END EDIT-SCOPE>>
                                  );

        -- <<EDIT-TABLE>>
        UPDATE DMT_OWNER.DMT_PO_DISTS_INT_STG_TBL
        -- <<END EDIT-TABLE>>
        SET    STG_STATUS = 'FAILED', LAST_UPDATED_DATE = SYSDATE
        WHERE  STG_STATUS IN ('NEW','RETRY')
        AND    STG_SEQUENCE_ID IN (SELECT STG_SEQUENCE_ID FROM DMT_OWNER.DMT_STG_TFM_ERROR_TBL
                                   WHERE RUN_ID = p_run_id
        -- <<EDIT-SCOPE>>
                                   AND SUB_OBJECT = 'PO Distributions'
        -- <<END EDIT-SCOPE>>
                                  );
    END FLAG_STG_FAILED;

    -- --------------------------------------------------------
    -- VALIDATE_PRE_TRANSFORM
    -- Upstream dependency: the PO's supplier must have LOADED. Per design
    --   section 5, LOADED is a TFM-only status (STG never carries it), so the
    --   check reads the supplier's TFM row: a supplier STG row whose VENDOR_NAME
    --   matches the PO header, joined to its DMT_POZ_SUPPLIERS_TFM_TBL row with
    --   TFM_STATUS='LOADED' (linked 1:1 by STG_SEQUENCE_ID).
    -- Failed headers cascade to child lines, locs, and dists
    --   via INTERFACE_HEADER_KEY match.
    -- Rejections are recorded in DMT_STG_TFM_ERROR_TBL (design §7); FLAG_STG_FAILED
    --   flags the STG rows FAILED afterwards (status only, no message). The cascade
    --   identifies a failed parent by the presence of its error row this run, not by
    --   a STG message.
    -- --------------------------------------------------------
    PROCEDURE VALIDATE_PRE_TRANSFORM (
        p_run_id    IN NUMBER,
        p_dependent_prefix  IN VARCHAR2 DEFAULT NULL,
        p_doc_type_filter   IN VARCHAR2 DEFAULT NULL
    )
    IS
        l_dep_prefix   VARCHAR2(30);
        l_hdr_failed   NUMBER := 0;
        l_ln_failed    NUMBER := 0;
        l_loc_failed   NUMBER := 0;
        l_dist_failed  NUMBER := 0;
        l_cemli_code   VARCHAR2(60);
        l_so_hdr       VARCHAR2(60);   -- header sub-object display label (per style)
        l_so_ln        VARCHAR2(60);   -- line sub-object display label (NULL if none)
    BEGIN
        DMT_UTIL_PKG.LOG(
            p_run_id => p_run_id,
            p_message        => 'VALIDATE_PRE_TRANSFORM start. dep_prefix=' ||
                                NVL(p_dependent_prefix, '(from CONVERSION_MASTER)') ||
                                ', doc_type_filter=' || NVL(p_doc_type_filter, '(none)'),
            p_package        => C_PKG,
            p_procedure      => 'VALIDATE_PRE_TRANSFORM');

        -- CEMLI code and per-sub-object display labels follow the document style.
        -- Labels MUST match the catalog (db/seed/dmt_cemli_catalog_tbl.sql): Blanket
        -- agreements register only headers + lines; contracts register only headers.
        -- Error rows are not written for sub-objects a style does not register.
        CASE p_doc_type_filter
            WHEN 'Blanket Purchase Agreement' THEN
                l_cemli_code := 'BlanketPOs';
                l_so_hdr     := 'Blanket PO Headers';
                l_so_ln      := 'Blanket PO Lines';
            WHEN 'Contract Purchase Agreement' THEN
                l_cemli_code := 'Contracts';
                l_so_hdr     := 'Contract Headers';
                l_so_ln      := NULL;   -- contracts are header-only
            ELSE
                l_cemli_code := 'PurchaseOrders';
                l_so_hdr     := 'PO Headers';
                l_so_ln      := 'PO Lines';
        END CASE;

        -- Resolve dependent prefix: use parameter if supplied, else read from CONVERSION_MASTER
        IF p_dependent_prefix IS NOT NULL THEN
            l_dep_prefix := p_dependent_prefix;
        ELSE
            SELECT PREFIX
            INTO   l_dep_prefix
            FROM   DMT_OWNER.DMT_PIPELINE_RUN_TBL
            WHERE  RUN_ID = p_run_id;
        END IF;

        -- Step 1: Record a rejection for PO headers whose supplier is not LOADED.
        -- Only enforced when suppliers have been migrated (at least one LOADED row exists).
        -- When no suppliers have been migrated, all PO rows pass through unchecked —
        -- this allows PO pipeline testing before the supplier pipeline runs.
        DECLARE
            l_any_loaded NUMBER;
        BEGIN
            SELECT COUNT(*) INTO l_any_loaded
            FROM   DMT_OWNER.DMT_POZ_SUPPLIERS_TFM_TBL
            WHERE  TFM_STATUS = 'LOADED' AND ROWNUM = 1;

            IF l_any_loaded > 0 THEN
                INSERT INTO DMT_OWNER.DMT_STG_TFM_ERROR_TBL
                       (RUN_ID, CEMLI_CODE, SUB_OBJECT, STG_SEQUENCE_ID, ERROR_TEXT)
                SELECT p_run_id, l_cemli_code, l_so_hdr, h.STG_SEQUENCE_ID,
                       '[PRE_VALIDATION] Supplier ''' || h.VENDOR_NAME ||
                       ''' is not loaded — PO record skipped.'
                FROM   DMT_OWNER.DMT_PO_HEADERS_INT_STG_TBL h
                WHERE  h.STG_STATUS IN ('NEW', 'RETRY')
                AND    NOT EXISTS (
                           SELECT 1
                           FROM   DMT_OWNER.DMT_POZ_SUPPLIERS_STG_TBL s
                           JOIN   DMT_OWNER.DMT_POZ_SUPPLIERS_TFM_TBL t
                                  ON t.STG_SEQUENCE_ID = s.STG_SEQUENCE_ID
                           WHERE  s.VENDOR_NAME = h.VENDOR_NAME
                           AND    t.TFM_STATUS   = 'LOADED'
                       )
                AND    (p_doc_type_filter IS NULL OR h.STYLE_DISPLAY_NAME = p_doc_type_filter);
                l_hdr_failed := SQL%ROWCOUNT;

                -- Step 2: Cascade to child lines for any header rejected this run.
                -- Only styles that register a lines sub-object (PurchaseOrders,
                -- BlanketPOs) have lines; contracts are header-only and are skipped.
                IF l_so_ln IS NOT NULL THEN
                    INSERT INTO DMT_OWNER.DMT_STG_TFM_ERROR_TBL
                           (RUN_ID, CEMLI_CODE, SUB_OBJECT, STG_SEQUENCE_ID, ERROR_TEXT)
                    SELECT p_run_id, l_cemli_code, l_so_ln, ln.STG_SEQUENCE_ID,
                           '[PRE_VALIDATION] Parent PO header ''' || ln.INTERFACE_HEADER_KEY ||
                           ''' failed upstream validation — line skipped.'
                    FROM   DMT_OWNER.DMT_PO_LINES_INT_STG_TBL ln
                    WHERE  ln.STG_STATUS IN ('NEW', 'RETRY')
                    AND    EXISTS (
                               SELECT 1
                               FROM   DMT_OWNER.DMT_PO_HEADERS_INT_STG_TBL h
                               JOIN   DMT_OWNER.DMT_STG_TFM_ERROR_TBL e
                                      ON e.STG_SEQUENCE_ID = h.STG_SEQUENCE_ID
                                     AND e.RUN_ID          = p_run_id
                                     AND e.SUB_OBJECT      = l_so_hdr
                               WHERE  h.INTERFACE_HEADER_KEY = ln.INTERFACE_HEADER_KEY
                               AND    (p_doc_type_filter IS NULL OR h.STYLE_DISPLAY_NAME = p_doc_type_filter)
                           );
                    l_ln_failed := SQL%ROWCOUNT;
                END IF;

                -- Steps 3 & 4: Cascade to line locations and distributions. Only
                -- standard PurchaseOrders register these sub-objects in the catalog;
                -- blanket agreements and contracts have neither, so they are skipped.
                IF l_cemli_code = 'PurchaseOrders' THEN
                    -- Step 3: line locations for any line rejected this run.
                    INSERT INTO DMT_OWNER.DMT_STG_TFM_ERROR_TBL
                           (RUN_ID, CEMLI_CODE, SUB_OBJECT, STG_SEQUENCE_ID, ERROR_TEXT)
                    SELECT p_run_id, l_cemli_code, 'PO Line Locations', loc.STG_SEQUENCE_ID,
                           '[PRE_VALIDATION] Parent PO line ''' || loc.INTERFACE_LINE_KEY ||
                           ''' failed upstream validation — line location skipped.'
                    FROM   DMT_OWNER.DMT_PO_LINE_LOCS_INT_STG_TBL loc
                    WHERE  loc.STG_STATUS IN ('NEW', 'RETRY')
                    AND    EXISTS (
                               SELECT 1
                               FROM   DMT_OWNER.DMT_PO_LINES_INT_STG_TBL ln
                               JOIN   DMT_OWNER.DMT_STG_TFM_ERROR_TBL e
                                      ON e.STG_SEQUENCE_ID = ln.STG_SEQUENCE_ID
                                     AND e.RUN_ID          = p_run_id
                                     AND e.SUB_OBJECT      = l_so_ln
                               WHERE  ln.INTERFACE_LINE_KEY = loc.INTERFACE_LINE_KEY
                           );
                    l_loc_failed := SQL%ROWCOUNT;

                    -- Step 4: distributions for any line location rejected this run.
                    INSERT INTO DMT_OWNER.DMT_STG_TFM_ERROR_TBL
                           (RUN_ID, CEMLI_CODE, SUB_OBJECT, STG_SEQUENCE_ID, ERROR_TEXT)
                    SELECT p_run_id, l_cemli_code, 'PO Distributions', d.STG_SEQUENCE_ID,
                           '[PRE_VALIDATION] Parent PO line location ''' || d.INTERFACE_LINE_LOCATION_KEY ||
                           ''' failed upstream validation — distribution skipped.'
                    FROM   DMT_OWNER.DMT_PO_DISTS_INT_STG_TBL d
                    WHERE  d.STG_STATUS IN ('NEW', 'RETRY')
                    AND    EXISTS (
                               SELECT 1
                               FROM   DMT_OWNER.DMT_PO_LINE_LOCS_INT_STG_TBL loc
                               JOIN   DMT_OWNER.DMT_STG_TFM_ERROR_TBL e
                                      ON e.STG_SEQUENCE_ID = loc.STG_SEQUENCE_ID
                                     AND e.RUN_ID          = p_run_id
                                     AND e.SUB_OBJECT      = 'PO Line Locations'
                               WHERE  loc.INTERFACE_LINE_LOCATION_KEY = d.INTERFACE_LINE_LOCATION_KEY
                           );
                    l_dist_failed := SQL%ROWCOUNT;
                END IF;

                -- Standard final step: flag the STG rows FAILED from the recorded
                -- error rows (status only, no message) so FAILED-mode reruns select
                -- on them (§7).
                FLAG_STG_FAILED(p_run_id);
            END IF;
        END;

        DMT_UTIL_PKG.LOG(
            p_run_id => p_run_id,
            p_message        => 'VALIDATE_PRE_TRANSFORM complete. Pre-validation failures — ' ||
                                'Headers: ' || l_hdr_failed ||
                                ' | Lines: '  || l_ln_failed ||
                                ' | Locations: ' || l_loc_failed ||
                                ' | Distributions: ' || l_dist_failed,
            p_package        => C_PKG,
            p_procedure      => 'VALIDATE_PRE_TRANSFORM');

    EXCEPTION
        WHEN OTHERS THEN
            DMT_UTIL_PKG.LOG_ERROR(
                p_run_id => p_run_id,
                p_message        => 'VALIDATE_PRE_TRANSFORM failed.',
                p_sqlerrm        => SQLERRM,
                p_package        => C_PKG,
                p_procedure      => 'VALIDATE_PRE_TRANSFORM');
            RAISE;
    END VALIDATE_PRE_TRANSFORM;


    -- --------------------------------------------------------
    -- VALIDATE_POST_TRANSFORM
    -- Data quality checks on TFM rows after transformation.
    -- Stub — no rules implemented yet.
    -- --------------------------------------------------------
    PROCEDURE VALIDATE_POST_TRANSFORM (
        p_run_id IN NUMBER
    )
    IS
    BEGIN
        -- No post-transform validations implemented yet.
        -- Future: check DOCUMENT_TYPE_CODE, CURRENCY_CODE, QUANTITY > 0, etc.
        NULL;
    EXCEPTION
        WHEN OTHERS THEN
            DMT_UTIL_PKG.LOG_ERROR(
                p_run_id => p_run_id,
                p_message        => 'VALIDATE_POST_TRANSFORM failed.',
                p_sqlerrm        => SQLERRM,
                p_package        => C_PKG,
                p_procedure      => 'VALIDATE_POST_TRANSFORM');
            RAISE;
    END VALIDATE_POST_TRANSFORM;

END DMT_PO_VALIDATOR_PKG;
/
