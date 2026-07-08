-- PACKAGE BODY DMT_MISC_RECEIPT_FBDI_GEN_PKG

  CREATE OR REPLACE EDITIONABLE PACKAGE BODY "DMT_MISC_RECEIPT_FBDI_GEN_PKG" 
AS
    C_PKG CONSTANT VARCHAR2(50) := 'DMT_MISC_RECEIPT_FBDI_GEN_PKG';

-- ============================================================
-- MiscReceipts FBDI: InvTransactionsInterface.csv (273 columns)
-- Per InvTransactionsInterface.ctl from FBDI template 25D.
-- ============================================================

    FUNCTION clob_to_blob(p_clob IN CLOB) RETURN BLOB IS
        l_blob         BLOB;
        l_dest_offset  INTEGER := 1;
        l_src_offset   INTEGER := 1;
        l_lang_context INTEGER := DBMS_LOB.DEFAULT_LANG_CTX;
        l_warning      INTEGER;
    BEGIN
        DBMS_LOB.CREATETEMPORARY(l_blob, TRUE);
        DBMS_LOB.CONVERTTOBLOB(
            dest_lob     => l_blob,
            src_clob     => p_clob,
            amount       => DBMS_LOB.LOBMAXSIZE,
            dest_offset  => l_dest_offset,
            src_offset   => l_src_offset,
            blob_csid    => DBMS_LOB.DEFAULT_CSID,
            lang_context => l_lang_context,
            warning      => l_warning);
        RETURN l_blob;
    END clob_to_blob;

    PROCEDURE af (
        p_clob  IN OUT NOCOPY CLOB,
        p_value IN VARCHAR2,
        p_last  IN BOOLEAN DEFAULT FALSE
    ) IS
        l_val VARCHAR2(32767);
    BEGIN
        l_val := '"' || REPLACE(p_value, '"', '""') || '"';
        DBMS_LOB.WRITEAPPEND(p_clob, LENGTH(l_val), l_val);
        IF NOT p_last THEN
            DBMS_LOB.WRITEAPPEND(p_clob, 1, ',');
        ELSE
            DBMS_LOB.WRITEAPPEND(p_clob, 1, CHR(10));
        END IF;
    END af;

    FUNCTION fmt_date(p_date IN DATE) RETURN VARCHAR2 IS
    BEGIN
        IF p_date IS NULL THEN RETURN NULL; END IF;
        RETURN TO_CHAR(p_date, 'YYYY/MM/DD HH24:MI:SS');
    END fmt_date;

    FUNCTION fmt_date_short(p_date IN DATE) RETURN VARCHAR2 IS
    BEGIN
        IF p_date IS NULL THEN RETURN NULL; END IF;
        RETURN TO_CHAR(p_date, 'YYYY/MM/DD');
    END fmt_date_short;

    FUNCTION fmt_num(p_num IN NUMBER) RETURN VARCHAR2 IS
    BEGIN
        IF p_num IS NULL THEN RETURN NULL; END IF;
        RETURN TO_CHAR(p_num);
    END fmt_num;

    -- --------------------------------------------------------
    -- Generate main transactions CSV (273 columns per CTL)
    -- --------------------------------------------------------
    FUNCTION gen_transactions_csv (p_run_id IN NUMBER) RETURN CLOB IS
        l_csv CLOB;
    BEGIN
        DBMS_LOB.CREATETEMPORARY(l_csv, TRUE);

        FOR r IN (
            SELECT * FROM DMT_OWNER.DMT_INV_TRX_TFM_TBL
            WHERE  RUN_ID = p_run_id
            AND    TFM_STATUS     = 'STAGED'
            ORDER BY TFM_SEQUENCE_ID
        ) LOOP
            -- Columns 1-273 per InvTransactionsInterface.ctl
            -- Skipping system-managed: TRANSACTION_INTERFACE_ID, TRANSACTION_HEADER_ID,
            -- LAST_UPDATE_DATE, LAST_UPDATED_BY, CREATION_DATE, CREATED_BY,
            -- LAST_UPDATE_LOGIN, LOAD_REQUEST_ID (all EXPRESSION/CONSTANT in CTL)

            af(l_csv, r.ORGANIZATION_NAME);                           -- 1
            af(l_csv, fmt_num(r.TRANSACTION_GROUP_ID));               -- 2
            af(l_csv, fmt_num(r.TRANSACTION_GROUP_SEQ));              -- 3
            af(l_csv, fmt_num(r.TRANSACTION_BATCH_ID));               -- 4
            af(l_csv, fmt_num(r.TRANSACTION_BATCH_SEQ));              -- 5
            af(l_csv, r.PROCESS_FLAG);                                -- 6
            af(l_csv, r.INVENTORY_ITEM);                              -- 7
            af(l_csv, r.ITEM_NUMBER);                                 -- 8
            af(l_csv, r.REVISION);                                    -- 9
            af(l_csv, r.INV_LOTSERIAL_INTERFACE_NUM);                 -- 10
            af(l_csv, r.SUBINVENTORY_CODE);                           -- 11
            af(l_csv, r.LOCATOR_NAME);                                -- 12
            af(l_csv, r.LOC_SEGMENT1);                                -- 13
            af(l_csv, r.LOC_SEGMENT2);                                -- 14
            af(l_csv, r.LOC_SEGMENT3);                                -- 15
            af(l_csv, r.LOC_SEGMENT4);                                -- 16
            af(l_csv, r.LOC_SEGMENT5);                                -- 17
            af(l_csv, r.LOC_SEGMENT6);                                -- 18
            af(l_csv, r.LOC_SEGMENT7);                                -- 19
            af(l_csv, r.LOC_SEGMENT8);                                -- 20
            af(l_csv, r.LOC_SEGMENT9);                                -- 21
            af(l_csv, r.LOC_SEGMENT10);                               -- 22
            af(l_csv, r.LOC_SEGMENT11);                               -- 23
            af(l_csv, r.LOC_SEGMENT12);                               -- 24
            af(l_csv, r.LOC_SEGMENT13);                               -- 25
            af(l_csv, r.LOC_SEGMENT14);                               -- 26
            af(l_csv, r.LOC_SEGMENT15);                               -- 27
            af(l_csv, r.LOC_SEGMENT16);                               -- 28
            af(l_csv, r.LOC_SEGMENT17);                               -- 29
            af(l_csv, r.LOC_SEGMENT18);                               -- 30
            af(l_csv, r.LOC_SEGMENT19);                               -- 31
            af(l_csv, r.LOC_SEGMENT20);                               -- 32
            af(l_csv, fmt_num(r.TRANSACTION_QUANTITY));                -- 33
            af(l_csv, r.TRANSACTION_UOM);                             -- 34
            af(l_csv, r.TRANSACTION_UNIT_OF_MEASURE);                 -- 35
            af(l_csv, fmt_num(r.RESERVATION_QUANTITY));               -- 36
            af(l_csv, fmt_date(r.TRANSACTION_DATE));                  -- 37
            af(l_csv, r.TRANSACTION_SOURCE_TYPE_NAME);                -- 38
            af(l_csv, r.TRANSACTION_TYPE_NAME);                       -- 39
            af(l_csv, r.TRANSFER_ORGANIZATION_TYPE);                  -- 40
            af(l_csv, r.TRANSFER_ORGANIZATION_NAME);                  -- 41
            af(l_csv, r.TRANSFER_SUBINVENTORY);                       -- 42
            af(l_csv, r.XFER_LOC_SEGMENT1);                          -- 43
            af(l_csv, r.XFER_LOC_SEGMENT2);                          -- 44
            af(l_csv, r.XFER_LOC_SEGMENT3);                          -- 45
            af(l_csv, r.XFER_LOC_SEGMENT4);                          -- 46
            af(l_csv, r.XFER_LOC_SEGMENT5);                          -- 47
            af(l_csv, r.XFER_LOC_SEGMENT6);                          -- 48
            af(l_csv, r.XFER_LOC_SEGMENT7);                          -- 49
            af(l_csv, r.XFER_LOC_SEGMENT8);                          -- 50
            af(l_csv, r.XFER_LOC_SEGMENT9);                          -- 51
            af(l_csv, r.XFER_LOC_SEGMENT10);                         -- 52
            af(l_csv, r.XFER_LOC_SEGMENT11);                         -- 53
            af(l_csv, r.XFER_LOC_SEGMENT12);                         -- 54
            af(l_csv, r.XFER_LOC_SEGMENT13);                         -- 55
            af(l_csv, r.XFER_LOC_SEGMENT14);                         -- 56
            af(l_csv, r.XFER_LOC_SEGMENT15);                         -- 57
            af(l_csv, r.XFER_LOC_SEGMENT16);                         -- 58
            af(l_csv, r.XFER_LOC_SEGMENT17);                         -- 59
            af(l_csv, r.XFER_LOC_SEGMENT18);                         -- 60
            af(l_csv, r.XFER_LOC_SEGMENT19);                         -- 61
            af(l_csv, r.XFER_LOC_SEGMENT20);                         -- 62
            af(l_csv, fmt_num(r.PRIMARY_QUANTITY));                   -- 63
            af(l_csv, fmt_num(r.SECONDARY_TRANSACTION_QUANTITY));     -- 64
            af(l_csv, r.SECONDARY_UOM_CODE);                         -- 65
            af(l_csv, r.SECONDARY_UNIT_OF_MEASURE);                  -- 66
            af(l_csv, r.SOURCE_CODE);                                 -- 67
            af(l_csv, fmt_num(r.SOURCE_HEADER_ID));                  -- 68
            af(l_csv, fmt_num(r.SOURCE_LINE_ID));                    -- 69
            af(l_csv, r.TRANSACTION_SOURCE_NAME);                     -- 70
            -- DSP segments 1-30
            af(l_csv, r.DSP_SEGMENT1);                                -- 71
            af(l_csv, r.DSP_SEGMENT2);                                -- 72
            af(l_csv, r.DSP_SEGMENT3);                                -- 73
            af(l_csv, r.DSP_SEGMENT4);                                -- 74
            af(l_csv, r.DSP_SEGMENT5);                                -- 75
            af(l_csv, r.DSP_SEGMENT6);                                -- 76
            af(l_csv, r.DSP_SEGMENT7);                                -- 77
            af(l_csv, r.DSP_SEGMENT8);                                -- 78
            af(l_csv, r.DSP_SEGMENT9);                                -- 79
            af(l_csv, r.DSP_SEGMENT10);                               -- 80
            af(l_csv, r.DSP_SEGMENT11);                               -- 81
            af(l_csv, r.DSP_SEGMENT12);                               -- 82
            af(l_csv, r.DSP_SEGMENT13);                               -- 83
            af(l_csv, r.DSP_SEGMENT14);                               -- 84
            af(l_csv, r.DSP_SEGMENT15);                               -- 85
            af(l_csv, r.DSP_SEGMENT16);                               -- 86
            af(l_csv, r.DSP_SEGMENT17);                               -- 87
            af(l_csv, r.DSP_SEGMENT18);                               -- 88
            af(l_csv, r.DSP_SEGMENT19);                               -- 89
            af(l_csv, r.DSP_SEGMENT20);                               -- 90
            af(l_csv, r.DSP_SEGMENT21);                               -- 91
            af(l_csv, r.DSP_SEGMENT22);                               -- 92
            af(l_csv, r.DSP_SEGMENT23);                               -- 93
            af(l_csv, r.DSP_SEGMENT24);                               -- 94
            af(l_csv, r.DSP_SEGMENT25);                               -- 95
            af(l_csv, r.DSP_SEGMENT26);                               -- 96
            af(l_csv, r.DSP_SEGMENT27);                               -- 97
            af(l_csv, r.DSP_SEGMENT28);                               -- 98
            af(l_csv, r.DSP_SEGMENT29);                               -- 99
            af(l_csv, r.DSP_SEGMENT30);                               -- 100
            af(l_csv, r.TRANSACTION_ACTION_NAME);                     -- 101
            af(l_csv, r.TRANSACTION_MODE);                            -- 102
            af(l_csv, r.LOCK_FLAG);                                   -- 103
            af(l_csv, r.TRANSACTION_REFERENCE);                       -- 104
            af(l_csv, r.REASON_NAME);                                 -- 105
            af(l_csv, r.CURRENCY_NAME);                               -- 106
            af(l_csv, r.CURRENCY_CODE);                               -- 107
            af(l_csv, r.CURRENCY_CONVERSION_TYPE);                    -- 108
            af(l_csv, fmt_num(r.CURRENCY_CONVERSION_RATE));          -- 109
            af(l_csv, fmt_date_short(r.CURRENCY_CONVERSION_DATE));   -- 110
            af(l_csv, fmt_num(r.TRANSACTION_COST));                  -- 111
            af(l_csv, fmt_num(r.TRANSFER_COST));                     -- 112
            af(l_csv, fmt_num(r.NEW_AVERAGE_COST));                  -- 113
            af(l_csv, fmt_num(r.VALUE_CHANGE));                      -- 114
            af(l_csv, fmt_num(r.PERCENTAGE_CHANGE));                 -- 115
            -- DST segments 1-30
            af(l_csv, r.DST_SEGMENT1);                                -- 116
            af(l_csv, r.DST_SEGMENT2);                                -- 117
            af(l_csv, r.DST_SEGMENT3);                                -- 118
            af(l_csv, r.DST_SEGMENT4);                                -- 119
            af(l_csv, r.DST_SEGMENT5);                                -- 120
            af(l_csv, r.DST_SEGMENT6);                                -- 121
            af(l_csv, r.DST_SEGMENT7);                                -- 122
            af(l_csv, r.DST_SEGMENT8);                                -- 123
            af(l_csv, r.DST_SEGMENT9);                                -- 124
            af(l_csv, r.DST_SEGMENT10);                               -- 125
            af(l_csv, r.DST_SEGMENT11);                               -- 126
            af(l_csv, r.DST_SEGMENT12);                               -- 127
            af(l_csv, r.DST_SEGMENT13);                               -- 128
            af(l_csv, r.DST_SEGMENT14);                               -- 129
            af(l_csv, r.DST_SEGMENT15);                               -- 130
            af(l_csv, r.DST_SEGMENT16);                               -- 131
            af(l_csv, r.DST_SEGMENT17);                               -- 132
            af(l_csv, r.DST_SEGMENT18);                               -- 133
            af(l_csv, r.DST_SEGMENT19);                               -- 134
            af(l_csv, r.DST_SEGMENT20);                               -- 135
            af(l_csv, r.DST_SEGMENT21);                               -- 136
            af(l_csv, r.DST_SEGMENT22);                               -- 137
            af(l_csv, r.DST_SEGMENT23);                               -- 138
            af(l_csv, r.DST_SEGMENT24);                               -- 139
            af(l_csv, r.DST_SEGMENT25);                               -- 140
            af(l_csv, r.DST_SEGMENT26);                               -- 141
            af(l_csv, r.DST_SEGMENT27);                               -- 142
            af(l_csv, r.DST_SEGMENT28);                               -- 143
            af(l_csv, r.DST_SEGMENT29);                               -- 144
            af(l_csv, r.DST_SEGMENT30);                               -- 145
            -- Miscellaneous fields
            af(l_csv, r.LOCATION_TYPE);                               -- 146
            af(l_csv, r.EMPLOYEE_CODE);                               -- 147
            af(l_csv, r.RECEIVING_DOCUMENT);                          -- 148
            af(l_csv, fmt_num(r.LINE_ITEM_NUM));                     -- 149
            af(l_csv, r.SHIPMENT_NUMBER);                             -- 150
            af(l_csv, fmt_num(r.TRANSPORTATION_COST));               -- 151
            af(l_csv, fmt_num(r.CONTAINERS));                        -- 152
            af(l_csv, r.WAYBILL_AIRBILL);                            -- 153
            af(l_csv, fmt_date(r.EXPECTED_ARRIVAL_DATE));            -- 154
            af(l_csv, r.REQUIRED_FLAG);                               -- 155
            af(l_csv, r.SHIPPABLE_FLAG);                              -- 156
            af(l_csv, fmt_num(r.SHIPPED_QUANTITY));                  -- 157
            af(l_csv, fmt_num(r.VALIDATION_REQUIRED));               -- 158
            af(l_csv, fmt_num(r.NEGATIVE_REQ_FLAG));                 -- 159
            af(l_csv, r.OWNING_TP_TYPE);                              -- 160
            af(l_csv, r.TRANSFER_OWNING_TP_TYPE);                    -- 161
            af(l_csv, r.OWNING_ORGANIZATION_NAME);                   -- 162
            af(l_csv, r.XFR_OWNING_ORGANIZATION_NAME);               -- 163
            af(l_csv, fmt_num(r.TRANSFER_PERCENTAGE));               -- 164
            af(l_csv, r.PLANNING_TP_TYPE);                            -- 165
            af(l_csv, r.TRANSFER_PLANNING_TP_TYPE);                  -- 166
            af(l_csv, r.ROUTING_REVISION);                            -- 167
            af(l_csv, fmt_date_short(r.ROUTING_REVISION_DATE));      -- 168
            af(l_csv, r.ALTERNATE_BOM_DESIGNATOR);                   -- 169
            af(l_csv, r.ALTERNATE_ROUTING_DESIGNATOR);               -- 170
            af(l_csv, r.ORGANIZATION_TYPE);                           -- 171
            af(l_csv, r.USSGL_TRANSACTION_CODE);                     -- 172
            af(l_csv, fmt_num(r.WIP_ENTITY_TYPE));                   -- 173
            af(l_csv, fmt_num(r.SCHEDULE_UPDATE_CODE));              -- 174
            af(l_csv, fmt_num(r.SETUP_TEARDOWN_CODE));               -- 175
            af(l_csv, fmt_num(r.PRIMARY_SWITCH));                    -- 176
            af(l_csv, fmt_num(r.MRP_CODE));                          -- 177
            af(l_csv, fmt_num(r.OPERATION_SEQ_NUM));                 -- 178
            af(l_csv, fmt_num(r.WIP_SUPPLY_TYPE));                   -- 179
            af(l_csv, r.RELIEVE_RESERVATIONS_FLAG);                  -- 180
            af(l_csv, r.RELIEVE_HIGH_LEVEL_RSV_FLAG);                -- 181
            af(l_csv, fmt_num(r.TRANSFER_PRICE));                    -- 182
            af(l_csv, r.BUILD_BREAK_TO_UOM);                         -- 183
            af(l_csv, r.BUILD_BREAK_TO_UNIT_OF_MEASURE);             -- 184
            -- Flexfields
            af(l_csv, r.ATTRIBUTE_CATEGORY);                          -- 185
            af(l_csv, r.ATTRIBUTE1);                                  -- 186
            af(l_csv, r.ATTRIBUTE2);                                  -- 187
            af(l_csv, r.ATTRIBUTE3);                                  -- 188
            af(l_csv, r.ATTRIBUTE4);                                  -- 189
            af(l_csv, r.ATTRIBUTE5);                                  -- 190
            af(l_csv, r.ATTRIBUTE6);                                  -- 191
            af(l_csv, r.ATTRIBUTE7);                                  -- 192
            af(l_csv, r.ATTRIBUTE8);                                  -- 193
            af(l_csv, r.ATTRIBUTE9);                                  -- 194
            af(l_csv, r.ATTRIBUTE10);                                 -- 195
            af(l_csv, r.ATTRIBUTE11);                                 -- 196
            af(l_csv, r.ATTRIBUTE12);                                 -- 197
            af(l_csv, r.ATTRIBUTE13);                                 -- 198
            af(l_csv, r.ATTRIBUTE14);                                 -- 199
            af(l_csv, r.ATTRIBUTE15);                                 -- 200
            af(l_csv, r.ATTRIBUTE16);                                 -- 201
            af(l_csv, r.ATTRIBUTE17);                                 -- 202
            af(l_csv, r.ATTRIBUTE18);                                 -- 203
            af(l_csv, r.ATTRIBUTE19);                                 -- 204
            af(l_csv, r.ATTRIBUTE20);                                 -- 205
            af(l_csv, fmt_num(r.ATTRIBUTE_NUMBER1));                 -- 206
            af(l_csv, fmt_num(r.ATTRIBUTE_NUMBER2));                 -- 207
            af(l_csv, fmt_num(r.ATTRIBUTE_NUMBER3));                 -- 208
            af(l_csv, fmt_num(r.ATTRIBUTE_NUMBER4));                 -- 209
            af(l_csv, fmt_num(r.ATTRIBUTE_NUMBER5));                 -- 210
            af(l_csv, fmt_num(r.ATTRIBUTE_NUMBER6));                 -- 211
            af(l_csv, fmt_num(r.ATTRIBUTE_NUMBER7));                 -- 212
            af(l_csv, fmt_num(r.ATTRIBUTE_NUMBER8));                 -- 213
            af(l_csv, fmt_num(r.ATTRIBUTE_NUMBER9));                 -- 214
            af(l_csv, fmt_num(r.ATTRIBUTE_NUMBER10));                -- 215
            af(l_csv, fmt_date_short(r.ATTRIBUTE_DATE1));            -- 216
            af(l_csv, fmt_date_short(r.ATTRIBUTE_DATE2));            -- 217
            af(l_csv, fmt_date_short(r.ATTRIBUTE_DATE3));            -- 218
            af(l_csv, fmt_date_short(r.ATTRIBUTE_DATE4));            -- 219
            af(l_csv, fmt_date_short(r.ATTRIBUTE_DATE5));            -- 220
            af(l_csv, fmt_date(r.ATTRIBUTE_TIMESTAMP1));             -- 221
            af(l_csv, fmt_date(r.ATTRIBUTE_TIMESTAMP2));             -- 222
            af(l_csv, fmt_date(r.ATTRIBUTE_TIMESTAMP3));             -- 223
            af(l_csv, fmt_date(r.ATTRIBUTE_TIMESTAMP4));             -- 224
            af(l_csv, fmt_date(r.ATTRIBUTE_TIMESTAMP5));             -- 225
            -- Tax fields
            af(l_csv, r.TRANSACTION_COST_IDENTIFIER);                -- 226
            af(l_csv, r.DEFAULT_TAXATION_COUNTRY);                   -- 227
            af(l_csv, r.DOCUMENT_SUB_TYPE);                          -- 228
            af(l_csv, r.TRX_BUSINESS_CATEGORY);                     -- 229
            af(l_csv, r.USER_DEFINED_FISC_CLASS);                   -- 230
            af(l_csv, r.TAX_INVOICE_NUMBER);                        -- 231
            af(l_csv, r.TAX_INVOICE_DATE);                           -- 232
            af(l_csv, r.PRODUCT_CATEGORY);                           -- 233
            af(l_csv, r.PRODUCT_TYPE);                               -- 234
            af(l_csv, r.ASSESSABLE_VALUE);                           -- 235
            af(l_csv, r.TAX_CLASSIFICATION_CODE);                   -- 236
            af(l_csv, r.EXEMPT_CERTIFICATE_NUMBER);                 -- 237
            af(l_csv, r.EXEMPT_REASON_CODE);                        -- 238
            af(l_csv, r.INTENDED_USE);                               -- 239
            af(l_csv, r.FIRST_PTY_NUMBER);                          -- 240
            af(l_csv, r.THIRD_PTY_NUMBER);                          -- 241
            af(l_csv, r.FINAL_DISCHARGE_LOC_CODE);                  -- 242
            -- Additional
            af(l_csv, r.CATEGORY_NAME);                              -- 243
            af(l_csv, fmt_num(r.OWNING_ORGANIZATION_ID));           -- 244
            af(l_csv, fmt_num(r.XFR_OWNING_ORGANIZATION_ID));       -- 245
            af(l_csv, r.PRC_BU_NAME);                                -- 246
            af(l_csv, r.VENDOR_NAME);                                -- 247
            af(l_csv, r.VENDOR_NUMBER);                              -- 248
            af(l_csv, r.CONSIGNMENT_AGREEMENT_NUM);                  -- 249
            af(l_csv, r.USE_CURRENT_COST);                           -- 250
            af(l_csv, r.EXTERNAL_SYSTEM_PACKING_UNIT);              -- 251
            af(l_csv, r.TRANSFER_LOCATOR_NAME);                     -- 252
            af(l_csv, r.INV_PROJECT);                                -- 253
            af(l_csv, r.INV_TASK);                                   -- 254
            af(l_csv, r.COUNTRY_OF_ORIGIN_NAME);                    -- 255
            af(l_csv, r.TRANSFER_INV_PROJECT);                      -- 256
            af(l_csv, r.TRANSFER_INV_TASK);                          -- 257
            -- Extended columns (25D additions — not in MCCS STG, output as NULL)
            af(l_csv, NULL);  -- 258: PJC_PROJECT_NUMBER
            af(l_csv, NULL);  -- 259: PJC_TASK_NUMBER
            af(l_csv, NULL);  -- 260: PJC_EXPENDITURE_TYPE_NAME
            af(l_csv, NULL);  -- 261: PJC_EXPENDITURE_ITEM_DATE
            af(l_csv, NULL);  -- 262: PJC_EXPENDITURE_ORG_NAME
            af(l_csv, NULL);  -- 263: PJC_CONTRACT_NUMBER
            af(l_csv, NULL);  -- 264: PJC_FUNDING_SOURCE_NAME
            af(l_csv, NULL);  -- 265: REQUESTER_NAME
            af(l_csv, NULL);  -- 266: REQUESTER_NUMBER
            af(l_csv, NULL);  -- 267: EXTERNAL_SYS_TXN_REFERENCE
            af(l_csv, NULL);  -- 268: SOURCE_LOT_FLAG
            af(l_csv, NULL);  -- 269: LOT_TXN_GROUP_NAME
            af(l_csv, NULL);  -- 270: REPRESENTATIVE_LOT_NUMBER
            af(l_csv, NULL);  -- 271: LICENSE_PLATE_NUMBER
            af(l_csv, NULL);  -- 272: XFR_LICENSE_PLATE_NUMBER
            af(l_csv, NULL, p_last => TRUE);  -- 273: CONT_LICENSE_PLATE_NUMBER

        END LOOP;

        RETURN l_csv;
    END gen_transactions_csv;

    -- --------------------------------------------------------
    -- Public: Generate FBDI ZIP
    -- --------------------------------------------------------
    PROCEDURE GENERATE_FBDI (
        p_run_id  IN  NUMBER,
        x_fbdi_zip        OUT BLOB,
        x_filename        OUT VARCHAR2,
        x_fbdi_csv_id     OUT NUMBER
    ) IS
        C_PROC      CONSTANT VARCHAR2(30) := 'GENERATE_FBDI';
        l_trx_csv   CLOB;
        l_trx_blob  BLOB;
        l_row_count NUMBER;
    BEGIN
        DMT_UTIL_PKG.LOG(p_run_id,
            C_PROC || ' start.', C_PKG, C_PROC);

        SELECT COUNT(*) INTO l_row_count
        FROM   DMT_OWNER.DMT_INV_TRX_TFM_TBL
        WHERE  RUN_ID = p_run_id
        AND    TFM_STATUS     = 'STAGED';

        IF l_row_count = 0 THEN
            DMT_UTIL_PKG.LOG(p_run_id,
                C_PROC || ': No STAGED rows to generate.', C_PKG, C_PROC);
            x_fbdi_zip    := NULL;
            x_filename    := NULL;
            x_fbdi_csv_id := NULL;
            RETURN;
        END IF;

        -- Generate transactions CSV
        l_trx_csv  := gen_transactions_csv(p_run_id);
        l_trx_blob := clob_to_blob(l_trx_csv);
        DBMS_LOB.FREETEMPORARY(l_trx_csv);

        -- Build ZIP with transactions CSV + optional lots/serials CSVs
        DBMS_LOB.CREATETEMPORARY(x_fbdi_zip, TRUE);
        APEX_ZIP.ADD_FILE(
            p_zipped_blob => x_fbdi_zip,
            p_file_name   => 'InvTransactionsInterface.csv',
            p_content     => l_trx_blob);
        DBMS_LOB.FREETEMPORARY(l_trx_blob);

        -- Lots CSV (InvTransactionLotsInterface) if any lot TFM rows exist
        DECLARE
            l_lots_csv  CLOB;
            l_lots_blob BLOB;
            l_lots_cnt  NUMBER := 0;
        BEGIN
            DBMS_LOB.CREATETEMPORARY(l_lots_csv, TRUE);
            FOR lr IN (
                SELECT * FROM DMT_OWNER.DMT_INV_TRX_LOTS_TFM_TBL
                WHERE  RUN_ID = p_run_id
                ORDER BY TFM_SEQUENCE_ID
            ) LOOP
                l_lots_cnt := l_lots_cnt + 1;
                -- CTL cols (after 6 system): INV_LOT_INTERFACE_NUM, INV_SERIAL_INTERFACE_NUM,
                -- SOURCE_CODE, SOURCE_LINE_ID, LOT_NUMBER, DESCRIPTION, LOT_EXPIRATION_DATE,
                -- TRANSACTION_QUANTITY, PRIMARY_QUANTITY
                af(l_lots_csv, lr.INVENTORY_LOT_INTERFACE_NUMBER);   -- 1
                af(l_lots_csv, lr.INVENTORY_SERIAL_INTERFACE_NUM);   -- 2
                af(l_lots_csv, lr.SOURCE_CODE);                      -- 3
                af(l_lots_csv, fmt_num(lr.SOURCE_LINE_ID));          -- 4
                af(l_lots_csv, lr.LOT_NUMBER);                       -- 5
                af(l_lots_csv, lr.DESCRIPTION);                      -- 6
                af(l_lots_csv, fmt_date_short(lr.LOT_EXPIRATION_DATE)); -- 7
                af(l_lots_csv, fmt_num(lr.TRANSACTION_QUANTITY));    -- 8
                af(l_lots_csv, fmt_num(lr.PRIMARY_QUANTITY), TRUE);  -- 9 (last)
            END LOOP;

            IF l_lots_cnt > 0 THEN
                l_lots_blob := clob_to_blob(l_lots_csv);
                APEX_ZIP.ADD_FILE(
                    p_zipped_blob => x_fbdi_zip,
                    p_file_name   => 'InvTransactionLotsInterface.csv',
                    p_content     => l_lots_blob);
                DBMS_LOB.FREETEMPORARY(l_lots_blob);
            END IF;
            DBMS_LOB.FREETEMPORARY(l_lots_csv);
        END;

        -- Serials CSV (InvSerialNumbersInterface) if any serial TFM rows exist
        -- Join to parent TFM to get INV_LOTSERIAL_INTERFACE_NUM for linkage.
        DECLARE
            l_ser_csv  CLOB;
            l_ser_blob BLOB;
            l_ser_cnt  NUMBER := 0;
        BEGIN
            DBMS_LOB.CREATETEMPORARY(l_ser_csv, TRUE);
            -- Join serial TFM → serial STG (for SOURCE_ID = parent STG_SEQUENCE_ID)
            -- → parent TFM (for INV_LOTSERIAL_INTERFACE_NUM, SOURCE_CODE, SOURCE_LINE_ID)
            FOR sr IN (
                SELECT s.FM_SERIAL_NUMBER, s.TO_SERIAL_NUMBER,
                       p.INV_LOTSERIAL_INTERFACE_NUM, p.SOURCE_CODE, p.SOURCE_LINE_ID
                FROM   DMT_OWNER.DMT_INV_TRX_SERIALS_TFM_TBL s
                JOIN   DMT_OWNER.DMT_INV_TRX_SERIALS_STG_TBL ss
                    ON ss.STG_SEQUENCE_ID = s.STG_SEQUENCE_ID
                JOIN   DMT_OWNER.DMT_INV_TRX_TFM_TBL p
                    ON p.RUN_ID  = s.RUN_ID
                   AND p.STG_SEQUENCE_ID = TO_NUMBER(ss.SOURCE_ID)
                WHERE  s.RUN_ID = p_run_id
                ORDER BY s.TFM_SEQUENCE_ID
            ) LOOP
                l_ser_cnt := l_ser_cnt + 1;
                -- CTL cols (after 6 system): INV_SERIAL_INTERFACE_NUM, SOURCE_CODE,
                -- SOURCE_LINE_ID, FM_SERIAL_NUMBER, TO_SERIAL_NUMBER
                af(l_ser_csv, sr.INV_LOTSERIAL_INTERFACE_NUM); -- 1 INV_SERIAL_INTERFACE_NUM
                af(l_ser_csv, sr.SOURCE_CODE);                 -- 2 SOURCE_CODE
                af(l_ser_csv, fmt_num(sr.SOURCE_LINE_ID));     -- 3 SOURCE_LINE_ID
                af(l_ser_csv, sr.FM_SERIAL_NUMBER);            -- 4 FM_SERIAL_NUMBER
                af(l_ser_csv, sr.TO_SERIAL_NUMBER, TRUE);      -- 5 TO_SERIAL_NUMBER (last)
            END LOOP;

            IF l_ser_cnt > 0 THEN
                l_ser_blob := clob_to_blob(l_ser_csv);
                APEX_ZIP.ADD_FILE(
                    p_zipped_blob => x_fbdi_zip,
                    p_file_name   => 'InvSerialNumbersInterface.csv',
                    p_content     => l_ser_blob);
                DBMS_LOB.FREETEMPORARY(l_ser_blob);
            END IF;
            DBMS_LOB.FREETEMPORARY(l_ser_csv);
        END;

        APEX_ZIP.FINISH(p_zipped_blob => x_fbdi_zip);

        x_filename    := 'MiscReceipts_' || TO_CHAR(p_run_id) || '.zip';
        x_fbdi_csv_id := NULL;

        -- Mark TFM rows as GENERATED
        UPDATE DMT_OWNER.DMT_INV_TRX_TFM_TBL
        SET    TFM_STATUS        = 'GENERATED',
               LAST_UPDATED_DATE = SYSDATE
        WHERE  RUN_ID = p_run_id
        AND    TFM_STATUS     = 'STAGED';

        DMT_UTIL_PKG.LOG(p_run_id,
            C_PROC || ' complete. Rows: ' || l_row_count
            || ', ZIP size: ' || DBMS_LOB.GETLENGTH(x_fbdi_zip) || ' bytes.',
            C_PKG, C_PROC);

    EXCEPTION
        WHEN OTHERS THEN
            DMT_UTIL_PKG.LOG_ERROR(p_run_id,
                C_PROC || ' failed.', SQLERRM, C_PKG, C_PROC);
            RAISE;
    END GENERATE_FBDI;

END DMT_MISC_RECEIPT_FBDI_GEN_PKG;
/
