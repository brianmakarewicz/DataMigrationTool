-- PACKAGE BODY DMT_PO_VALIDATOR_PKG

  CREATE OR REPLACE EDITIONABLE PACKAGE BODY "DMT_PO_VALIDATOR_PKG" 
AS
-- ============================================================
-- DMT_PO_VALIDATOR_PKG body
-- PurchaseOrders pre- and post-transform validation.
-- ============================================================

    C_PKG CONSTANT VARCHAR2(50) := 'DMT_PO_VALIDATOR_PKG';

    -- --------------------------------------------------------
    -- VALIDATE_PRE_TRANSFORM
    -- Upstream dependency: VENDOR_NUM must match a LOADED supplier.
    -- For migrated suppliers: NVL(dep_prefix,'') || header.VENDOR_NUM
    --   must exist in DMT_POZ_SUPPLIERS_STG_TBL with STATUS='LOADED'.
    -- Failed headers cascade to child lines, locs, and dists
    --   via INTERFACE_HEADER_KEY match.
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
    BEGIN
        DMT_UTIL_PKG.LOG(
            p_run_id => p_run_id,
            p_message        => 'VALIDATE_PRE_TRANSFORM start. dep_prefix=' ||
                                NVL(p_dependent_prefix, '(from CONVERSION_MASTER)') ||
                                ', doc_type_filter=' || NVL(p_doc_type_filter, '(none)'),
            p_package        => C_PKG,
            p_procedure      => 'VALIDATE_PRE_TRANSFORM');

        -- Resolve dependent prefix: use parameter if supplied, else read from CONVERSION_MASTER
        IF p_dependent_prefix IS NOT NULL THEN
            l_dep_prefix := p_dependent_prefix;
        ELSE
            SELECT PREFIX
            INTO   l_dep_prefix
            FROM   DMT_OWNER.DMT_PIPELINE_RUN_TBL
            WHERE  RUN_ID = p_run_id;
        END IF;

        -- Step 1: Mark PO headers FAILED if their supplier is not LOADED.
        -- Only enforced when suppliers have been migrated (at least one LOADED row exists).
        -- When no suppliers have been migrated, all PO rows pass through unchecked —
        -- this allows PO pipeline testing before the supplier pipeline runs.
        DECLARE
            l_any_loaded NUMBER;
        BEGIN
            SELECT COUNT(*) INTO l_any_loaded
            FROM   DMT_OWNER.DMT_POZ_SUPPLIERS_STG_TBL
            WHERE  STATUS = 'LOADED' AND ROWNUM = 1;

            IF l_any_loaded > 0 THEN
                UPDATE DMT_OWNER.DMT_PO_HEADERS_INT_STG_TBL h
                SET    STATUS            = 'FAILED',
                       ERROR_TEXT        = DMT_UTIL_PKG.APPEND_ERROR(
                                               ERROR_TEXT,
                                               '[PRE_VALIDATION] Supplier ''' ||
                                               h.VENDOR_NAME ||
                                               ''' is not loaded — PO record skipped.'),
                       LAST_UPDATED_DATE = SYSDATE
                WHERE  h.STATUS IN ('NEW', 'RETRY')
                AND    NOT EXISTS (
                           SELECT 1
                           FROM   DMT_OWNER.DMT_POZ_SUPPLIERS_STG_TBL s
                           WHERE  s.VENDOR_NAME = h.VENDOR_NAME
                           AND    s.STATUS   = 'LOADED'
                       )
                AND    (p_doc_type_filter IS NULL OR h.STYLE_DISPLAY_NAME = p_doc_type_filter);
                l_hdr_failed := SQL%ROWCOUNT;

                -- Step 2: Cascade failures to child lines for any failed header.
                UPDATE DMT_OWNER.DMT_PO_LINES_INT_STG_TBL ln
                SET    STATUS            = 'FAILED',
                       ERROR_TEXT        = DMT_UTIL_PKG.APPEND_ERROR(
                                               ERROR_TEXT,
                                               '[PRE_VALIDATION] Parent PO header ''' ||
                                               ln.INTERFACE_HEADER_KEY ||
                                               ''' failed upstream validation — line skipped.'),
                       LAST_UPDATED_DATE = SYSDATE
                WHERE  ln.STATUS IN ('NEW', 'RETRY')
                AND    EXISTS (
                           SELECT 1
                           FROM   DMT_OWNER.DMT_PO_HEADERS_INT_STG_TBL h
                           WHERE  h.INTERFACE_HEADER_KEY = ln.INTERFACE_HEADER_KEY
                           AND    h.STATUS               = 'FAILED'
                           AND    h.ERROR_TEXT LIKE '%[PRE_VALIDATION]%'
                           AND    (p_doc_type_filter IS NULL OR h.STYLE_DISPLAY_NAME = p_doc_type_filter)
                       );
                l_ln_failed := SQL%ROWCOUNT;

                -- Step 3: Cascade to line locations for any failed line.
                UPDATE DMT_OWNER.DMT_PO_LINE_LOCS_INT_STG_TBL loc
                SET    STATUS            = 'FAILED',
                       ERROR_TEXT        = DMT_UTIL_PKG.APPEND_ERROR(
                                               ERROR_TEXT,
                                               '[PRE_VALIDATION] Parent PO line ''' ||
                                               loc.INTERFACE_LINE_KEY ||
                                               ''' failed upstream validation — line location skipped.'),
                       LAST_UPDATED_DATE = SYSDATE
                WHERE  loc.STATUS IN ('NEW', 'RETRY')
                AND    EXISTS (
                           SELECT 1
                           FROM   DMT_OWNER.DMT_PO_LINES_INT_STG_TBL ln
                           JOIN   DMT_OWNER.DMT_PO_HEADERS_INT_STG_TBL h
                                  ON h.INTERFACE_HEADER_KEY = ln.INTERFACE_HEADER_KEY
                           WHERE  ln.INTERFACE_LINE_KEY = loc.INTERFACE_LINE_KEY
                           AND    ln.STATUS             = 'FAILED'
                           AND    ln.ERROR_TEXT LIKE '%[PRE_VALIDATION]%'
                           AND    (p_doc_type_filter IS NULL OR h.STYLE_DISPLAY_NAME = p_doc_type_filter)
                       );
                l_loc_failed := SQL%ROWCOUNT;

                -- Step 4: Cascade to distributions for any failed line location.
                UPDATE DMT_OWNER.DMT_PO_DISTS_INT_STG_TBL d
                SET    STATUS            = 'FAILED',
                       ERROR_TEXT        = DMT_UTIL_PKG.APPEND_ERROR(
                                               ERROR_TEXT,
                                               '[PRE_VALIDATION] Parent PO line location ''' ||
                                               d.INTERFACE_LINE_LOCATION_KEY ||
                                               ''' failed upstream validation — distribution skipped.'),
                       LAST_UPDATED_DATE = SYSDATE
                WHERE  d.STATUS IN ('NEW', 'RETRY')
                AND    EXISTS (
                           SELECT 1
                           FROM   DMT_OWNER.DMT_PO_LINE_LOCS_INT_STG_TBL loc
                           JOIN   DMT_OWNER.DMT_PO_LINES_INT_STG_TBL ln
                                  ON ln.INTERFACE_LINE_KEY = loc.INTERFACE_LINE_KEY
                           JOIN   DMT_OWNER.DMT_PO_HEADERS_INT_STG_TBL h
                                  ON h.INTERFACE_HEADER_KEY = ln.INTERFACE_HEADER_KEY
                           WHERE  loc.INTERFACE_LINE_LOCATION_KEY = d.INTERFACE_LINE_LOCATION_KEY
                           AND    loc.STATUS                      = 'FAILED'
                           AND    loc.ERROR_TEXT LIKE '%[PRE_VALIDATION]%'
                           AND    (p_doc_type_filter IS NULL OR h.STYLE_DISPLAY_NAME = p_doc_type_filter)
                       );
                l_dist_failed := SQL%ROWCOUNT;
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
