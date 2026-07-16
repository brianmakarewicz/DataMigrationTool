# Full-fidelity scenario upload (via the existing CSV upload machinery)

This note explains how the **existing** Data Management upload now loads a
complete scenario — every object, every child staging table, every business
column — without adding a new mechanism. It extends what already shipped:
`DMT_CSV_UPLOAD_PKG`, `DMT_UPLOAD_DICT_PKG`, and the two metadata tables
`DMT_UPLOAD_OBJECT_TBL` / `DMT_UPLOAD_DICT_TBL`.

## How the working upload functions (end to end)

The APEX Data Management pages call `DMT_CSV_UPLOAD_PKG`. It is fully
metadata-driven — no object names are hardcoded in the package:

1. **Object registry — `DMT_UPLOAD_OBJECT_TBL`.** One row per uploadable
   staging table. It maps an `OBJECT_CODE` to its `STAGING_TABLE`, the expected
   `CSV_FILENAME` inside a bundle, its `PAGE_NUMBER`, a `PARENT_OBJECT_CODE`
   (for child tables), and a `DISPLAY_ORDER` (load order).

2. **Column dictionary — `DMT_UPLOAD_DICT_TBL`.** One row per column per
   registered staging table, with the column's data type, nullability, order,
   and an `IS_ADMIN_COLUMN` flag. This is **not** hand-written: it is generated
   by `DMT_UPLOAD_DICT_PKG.SEED_DICTIONARY`, which reads `USER_TAB_COLUMNS` for
   every registered table. Every real business column is picked up
   automatically, so nothing is dropped.

3. **The loaders.** For a single CSV, `UPLOAD_CSV` / `UPLOAD_CSV_FROM_BLOB`
   read the CSV header row, match each header to a dictionary column, and run
   one `INSERT ... SELECT` from `APEX_DATA_PARSER.PARSE` into the staging table
   (fast path, with `LOG ERRORS INTO` for per-row error capture), or a
   row-by-row `DBMS_SQL` insert (legacy path). For a multi-CSV zip,
   `UPLOAD_ZIP_BUNDLE` unpacks the zip and routes each CSV to its object by
   matching the file name to `DMT_UPLOAD_OBJECT_TBL.CSV_FILENAME`, then delegates
   each to `UPLOAD_CSV_FROM_BLOB`. (A separate entry point, `UPLOAD_FBDI_ZIP`,
   loads position-based headerless FBDI zips — that path is unchanged.)

4. **Admin columns are DB-owned.** Staging tables define `STG_SEQUENCE_ID` as a
   `GENERATED ALWAYS` identity, `STG_STATUS` as `DEFAULT 'NEW' NOT NULL`, and
   `STAGE_DATE` as `DEFAULT SYSDATE`. The loader never inserts these; the
   database fills them. After the load, if a scenario name was supplied, the
   package tags the newly inserted rows with the run's `SCENARIO_ID`.

**The gap that blocked full fidelity:** `DMT_UPLOAD_OBJECT_TBL` had no committed
seed, so on a fresh install it was empty and the loader could not route
anything. The demo file `DMC_Upload_Feature_DDL.sql` is a separate, legacy,
thin loader (one hardcoded header table per object, written to TFM, dropping
child hierarchies and fields like `BUSINESS_RELATIONSHIP`); it is not part of
this stack's machinery.

## What was added to reach full fidelity

### 1. Seed `DMT_UPLOAD_OBJECT_TBL` for every object and child table

`db/seed/dmt_upload_object_tbl.sql` registers **94 staging tables** across the
**43 built objects**. The object/child membership is taken from the two
authoritative registries — `db/seed/dmt_cemli_catalog_tbl.sql` (record types per
object) and `db/seed/dmt_pipeline_def_tbl.sql` (pipeline home) — cross-checked
against the real `db/tables/*_stg_tbl.sql` files. For each staging table:

- `OBJECT_CODE` = the table name without the `DMT_` prefix and `_STG_TBL`
  suffix (e.g. `POZ_SUP_ADDR`), which is the unique routing key.
- `CSV_FILENAME` = `<STAGING_TABLE>.csv` (e.g. `DMT_POZ_SUP_ADDR_STG_TBL.csv`).
- `PARENT_OBJECT_CODE` = the object's header table, for child tables.
- `DISPLAY_ORDER` = a global parent-before-child ordinal.

The seed ends by calling `DMT_UPLOAD_DICT_PKG.SEED_DICTIONARY`, which rebuilds
the column dictionary from `USER_TAB_COLUMNS`. So every business column of every
registered child table becomes uploadable with no further work — including the
fields the thin demo dropped.

Scope decisions baked into the seed:
- `PurchaseOrders`, `BlanketPOs`, and `Contracts` share the same physical PO
  staging tables (they differ only by `STYLE_DISPLAY_NAME`), so those four
  tables are registered **once**, under `PurchaseOrders`.
- `Grants` is expanded from just headers to all **15** `DMT_GMS_AWD_*` child
  staging tables — the full award hierarchy the Grants generator reads.
- Excluded on purpose: `DMT_PLAN_BUDGET_STG_TBL` (PlanningBudgets is out of
  scope), the orphaned `DMT_RCV_*` tables (MiscReceipts uses `DMT_INV_TRX_*`),
  and `ARReceipts` (REST object, not built — no staging table yet).

### 2. Small package changes (clearly commented in the code)

- **`DMT_UPLOAD_DICT_PKG`** — added `SCENARIO_ID` to the admin-column list.
  Every staging table now carries `SCENARIO_ID`; it is set by the upload package
  after the load, so it must be marked admin or it would be offered as an
  uploadable business column.
- **`DMT_CSV_UPLOAD_PKG`** — two changes:
  - **Honour `SOURCE_ID`.** `SOURCE_ID` is admin in the dictionary (defaults to
    NULL, otherwise pipeline-managed) but is a real source natural key. Both the
    fast and legacy single-CSV loaders now accept it when a CSV supplies it
    (`IS_ADMIN_COLUMN = 'N' OR COLUMN_NAME = 'SOURCE_ID'`). This mirrors the
    regression seed, which populates `SOURCE_ID` on every staging row.
  - **Parent-before-child ordering in `UPLOAD_ZIP_BUNDLE`.** The zip loader now
    resolves each matched CSV to its `DISPLAY_ORDER`, sorts the whole bundle by
    it, and loads in that order — so a parent staging table (e.g.
    `DMT_HZ_PARTIES_STG_TBL`, `DMT_PO_HEADERS_INT_STG_TBL`) always loads before
    its children, regardless of file order inside the zip.

No change was needed for `STG_STATUS` / `STAGE_DATE` / `STG_SEQUENCE_ID`
defaults — those are enforced by the staging-table DDL, and the loader already
excludes admin columns from the insert.

### 3. Wired into the installer

`db/install.sql` runs `db/seed/dmt_upload_object_tbl.sql` in the seed section,
after the staging tables and after `DMT_UPLOAD_DICT_PKG` is compiled (the seed
calls `SEED_DICTIONARY`). The seed uses `MERGE` on `OBJECT_CODE`, so re-running
the installer converges an existing database to the committed values.

## The zip / CSV convention (what to upload)

- **One zip = one scenario.** Inside it, one **header-bearing** CSV per staging
  table you want to load. (This is the `UPLOAD_ZIP_BUNDLE` path, not the
  headerless FBDI path.)
- **Each CSV is named for its staging table**, e.g.
  `DMT_POZ_SUP_ADDR_STG_TBL.csv` — this is the `CSV_FILENAME` the registry
  matches on (case-insensitive; any folder path inside the zip is ignored).
- **Row 1 is the header** — staging business column names (case-insensitive,
  standard CSV quoting). Unknown headers are skipped and reported; the good
  columns still load.
- **Admin columns are auto-populated** and need not appear: `STG_STATUS`
  (`'NEW'`), `STAGE_DATE` (`SYSDATE`), `STG_SEQUENCE_ID` (identity), and
  `SCENARIO_ID` (the run's scenario). `SOURCE_ID` is honoured if present.
- **Dates** in real `DATE` columns use the session date format; `NUMBER`
  columns are plain numeric; empty values are left blank.

## Worked examples

**Supplier family (five separate objects).** The zip carries
`DMT_POZ_SUPPLIERS_STG_TBL.csv`, `DMT_POZ_SUP_ADDR_STG_TBL.csv`,
`DMT_POZ_SUP_SITE_STG_TBL.csv`, `DMT_POZ_SUP_SITE_ASSN_STG_TBL.csv`, and
`DMT_POZ_SUP_CONTACTS_STG_TBL.csv`. Each is its own registered object (they are
peer objects, not sub-objects), loaded in registry order. Full-fidelity columns
such as `BUSINESS_RELATIONSHIP`, `ORGANIZATION_TYPE_LOOKUP_CODE`, and
`IMPORT_ACTION` on the supplier header — and `PARTY_SITE_NAME`,
`RFQ_OR_BIDDING_PURPOSE_FLAG` on the address — are all present in the dictionary
and therefore loadable.

**Customer hierarchy (one object, seven child tables).** The `Customers` object
registers `DMT_HZ_PARTIES_STG_TBL` as the header and six children
(`HZ_LOCATIONS`, `HZ_PARTY_SITES`, `HZ_PARTY_SITE_USES`, `HZ_ACCOUNTS`,
`HZ_ACCT_SITES`, `HZ_ACCT_SITE_USES`), each with `PARENT_OBJECT_CODE =
HZ_PARTIES` and an ascending `DISPLAY_ORDER`. The zip loader loads parties
first, then the rest in order, so the whole customer hierarchy arrives in one
upload with every column — including the ones the thin demo dropped
(`PARTY_ORIG_SYSTEM`, `SHIP_TO_LOCATION`, and so on).

## Recommendation on the parallel `DMT_SCENARIO_UPLOAD_PKG`

**Discard it.** The prior agent's `DMT_SCENARIO_UPLOAD_PKG` (branch
`feat/full-fidelity-upload`) is a third parallel loader that duplicates what
`DMT_CSV_UPLOAD_PKG` already does. Everything it set out to achieve — a
header-bearing multi-CSV zip covering full staging hierarchies, per-column type
handling, admin-column auto-population, parent-before-child ordering — is now
delivered by seeding the existing registry and making two small edits to the
existing package. Keeping a second zip loader would be exactly the parallel
mechanism the owner rejected.

Two of its ideas were worth folding in and have been:
- **Parent-before-child load ordering** — implemented in `UPLOAD_ZIP_BUNDLE`
  using the registry's `DISPLAY_ORDER`.
- **Honouring `SOURCE_ID` while treating other infra columns as admin** —
  implemented in both single-CSV loaders.

One idea was deliberately **not** adopted: its "filename *is* the table, so no
routing table is needed" convention. The existing machinery routes through
`DMT_UPLOAD_OBJECT_TBL`, which is what the APEX pages, the single-CSV path, and
the FBDI path already use; routing everything through the one registry keeps a
single source of truth rather than splitting routing between a table and a
filename rule.

## Unresolved / follow-ups

- **Deployed and verified on dmt2-local (Docker).** The two package bodies
  (`DMT_CSV_UPLOAD_PKG`, `DMT_UPLOAD_DICT_PKG`) compile **VALID**, and the seed
  loaded **94 rows** into `DMT_UPLOAD_OBJECT_TBL` and **5,107 rows** into
  `DMT_UPLOAD_DICT_TBL`. Compilation and row counts were confirmed by querying
  `USER_OBJECTS` and the two tables directly. An end-to-end scenario zip upload
  through the APEX UI has **not** yet been exercised — that is the remaining
  verification step before this backlog item is checked off in the design doc.
- **HDL date columns.** Several HCM/HDL objects store "date" values in
  `VARCHAR2` staging columns (the transform carries the string through). Those
  values must already be in the format the generator expects; the dictionary
  types them as text, so the loader passes them through unchanged — but this is
  a data-preparation note for whoever builds the scenario CSVs.
