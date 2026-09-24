-- Honest required-field metadata for the upload data dictionary.
--
-- WHY THIS FILE EXISTS
--   DMT_UPLOAD_DICT_PKG.SEED_DICTIONARY populates DMT_UPLOAD_DICT_TBL from
--   USER_TAB_COLUMNS. It leaves SAMPLE_VALUE and DESCRIPTION null and derives
--   REQUIRED purely from the staging column's NULLABLE flag. Staging tables are
--   deliberately permissive (almost every column is nullable so that BAD rows
--   can be staged and then rejected by Fusion), so that derived REQUIRED flag is
--   misleading. This additive MERGE fills in SAMPLE_VALUE and DESCRIPTION for the
--   handful of columns whose real, Fusion-accepted values we actually know.
--
-- SOURCE OF THESE VALUES (not invented)
--   Every SAMPLE_VALUE below is a value that the proven regression scenario
--   loads and Fusion accepts, taken verbatim from
--   scripts/insert_regression_test_data.py (the GOOD rows) and the object
--   READMEs it cites (e.g. objects/PurchaseOrders/README.md for SHIP_TO_LOCATION
--   = 'Seattle'). No value here is guessed; columns whose correct value we do
--   not know are intentionally left untouched by this MERGE.
--
--   Runs AFTER seed/dmt_upload_object_tbl.sql (which calls SEED_DICTIONARY) so
--   the target rows already exist. Idempotent: MERGE keyed on (OBJECT_CODE,
--   COLUMN_NAME); only updates rows that exist, only overwrites SAMPLE_VALUE and
--   DESCRIPTION, and leaves every other column of the dictionary untouched.

merge into "DMT_UPLOAD_DICT_TBL" t
using (
    -- Suppliers (DMT_POZ_SUPPLIERS_STG_TBL) — values from the GOOD supplier rows.
    select 'POZ_SUPPLIERS' object_code, 'BUSINESS_RELATIONSHIP'          column_name, 'SPEND_AUTHORIZED' sample_value, 'Supplier business relationship lookup. Regression GOOD rows use SPEND_AUTHORIZED.' description from dual
    union all select 'POZ_SUPPLIERS', 'ORGANIZATION_TYPE_LOOKUP_CODE', 'CORPORATION', 'Supplier organization type lookup. GOOD rows use CORPORATION; an unknown code is rejected by Fusion.' from dual
    union all select 'POZ_SUPPLIERS', 'VENDOR_TYPE_LOOKUP_CODE',       'SUPPLIER',    'Supplier vendor type lookup. GOOD rows use SUPPLIER.' from dual
    union all select 'POZ_SUPPLIERS', 'IMPORT_ACTION',                 'CREATE',      'FBDI import action. New suppliers use CREATE.' from dual
    -- Customers / Parties (DMT_HZ_PARTIES_STG_TBL) — values from the GOOD party rows.
    union all select 'HZ_PARTIES', 'PARTY_ORIG_SYSTEM',            'LEG1',        'Original (source) system code that owns the party natural key. Regression uses LEG1.' from dual
    union all select 'HZ_PARTIES', 'PARTY_TYPE',                   'ORGANIZATION','Party type. GOOD customer rows use ORGANIZATION; an unknown type is rejected by Fusion.' from dual
    union all select 'HZ_PARTIES', 'INSERT_UPDATE_FLAG',           'I',           'Insert/update flag for the customer import. New parties use I (insert).' from dual
    -- Customer Locations (DMT_HZ_LOCATIONS_STG_TBL) — values from the GOOD location rows.
    union all select 'HZ_LOCATIONS', 'LOCATION_ORIG_SYSTEM',       'LEG1',        'Original (source) system code that owns the location natural key. Regression uses LEG1.' from dual
    union all select 'HZ_LOCATIONS', 'COUNTRY',                    'US',          'Country code for the customer location. GOOD rows use US.' from dual
    union all select 'HZ_LOCATIONS', 'INSERT_UPDATE_FLAG',         'I',           'Insert/update flag for the location import. New locations use I (insert).' from dual
    -- Purchase Order Line Locations (DMT_PO_LINE_LOCS_INT_STG_TBL) — value from the GOOD PO rows.
    union all select 'PO_LINE_LOCS_INT', 'SHIP_TO_LOCATION',      'Seattle',     'Ship-to location for an expense PO shipment. GOOD rows use Seattle; a null ship-to is rejected and cascades to the whole PO (objects/PurchaseOrders/README.md).' from dual
    union all select 'PO_LINE_LOCS_INT', 'DESTINATION_TYPE_CODE', 'EXPENSE',     'PO shipment destination type. Regression PO shipments use EXPENSE.' from dual
) s
on (t."OBJECT_CODE" = s.object_code AND UPPER(t."COLUMN_NAME") = s.column_name)
when matched then update set
    t."SAMPLE_VALUE" = s.sample_value,
    t."DESCRIPTION"  = s.description;

commit;
