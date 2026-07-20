# ItemCategories — Gold Regression Fixture (Item Category Assignments)

**Status: STILL TABLED — 2026-07-19 (after Catalog Import retarget attempt).** Fixture is
built and portable. Two standalone load paths have now been tried and **neither reaches the
base table**:
1. **ItemImportJobDef** (interfaceDetails 29) — loads to `EGP_ITEM_CATEGORIES_INTERFACE`
   but the rows are never processed (category assignment is a *peripheral entity* of an
   Item Import batch; a category-only ZIP creates no item batch). See "Blocker (path 1)".
2. **CatalogImportJobDef** (interfaceDetails 137, account `scm/item/import`, params
   `${PREFIX},N,N`) — the documented NEXT STEP. Retried live 2026-07-19 (prefix **93120**,
   load request **9764809**, scm_impl). **`loadAndImportData` loaded the file but never
   dispatched a `CatalogImportJobDef` child.** The load request stayed an
   `InterfaceLoaderController` stuck in **WAIT** for 18+ minutes with only two
   `InterfaceLoaderAsyncJob` children (both SUCCEEDED) and **no** `CatalogImport` child job
   anywhere on the pod. Zero base assignments were created. See "Blocker (path 2)".

Object family: **SCM / Product Information Management.** All Fusion calls (SOAP load + BIP
verify) use the **scm_impl** credential, not fin_impl.

---

## What this fixture does

A category assignment links an EXISTING item to an EXISTING catalog (category set) + an
EXISTING category the item is not yet assigned to. Nothing upstream is created: no items,
no catalogs. The fixture discovers, at load time, on the target pod:

1. an existing inventory item in the item-master org `000` that has spare (unassigned)
   clean category codes in the seeded **eCommerce Catalog** category set, and
2. two clean (single-segment) category codes in that set the item is not yet assigned to.

It then builds three category-assignment rows for that item: two good (valid discovered
category codes) and one bad (a nonexistent category code `ZZBADCAT${PREFIX}`).

### Good rows (2)
Assign the discovered item (e.g. `AS00100` / org `000`) to the discovered eCommerce
Catalog categories (e.g. `Canned_Fruit`, `Industrial`). These are real, seeded categories
present on every demo pod, so the fixture is portable with no dependency on our own loads.

### Bad row (1)
Same item / org / set, but `CATEGORY_CODE = ZZBADCAT${PREFIX}` — a category that does not
exist in the eCommerce Catalog. Expected Fusion rejection: category not found / not valid
for the catalog, so the row is rejected in the interface and never reaches the base table.

---

## Portability (rules 6-8)

- **No upstream dependency.** The item and the category set/codes are discovered live on
  the TARGET pod via read-only BIP (scm_impl). We do not reference any item, catalog, or
  category we loaded earlier under a prefix. `AS00100` and the eCommerce Catalog seed
  categories ship with every Oracle SCM demo pod.
- **Reloadable.** Discovery step `IC_ITEM` picks an `AS%` item in org `000` that still has
  at least three unassigned clean eCommerce categories, and step `IC_CATEGORIES` picks the
  first two category codes that item is not yet assigned to. A re-run therefore picks fresh
  unassigned categories and never collides with a prior run's assignment.
- **Traceability.** Each row carries the run prefix in `SOURCE_SYSTEM_REFERENCE`
  (`${PREFIX}RT-ICAT-G1/-G2/-BAD1`) and in the interface `BATCH_ID` (the numeric prefix).

---

## FBDI artifact

- ZIP member (one CSV, no header row, position-based per the control file
  `objects/ItemCategories/EgpItemCategoriesInterface.ctl`):
  `EgpItemCategoriesInterface.csv` — target interface table `EGP_ITEM_CATEGORIES_INTERFACE`.
- 14 columns, in control-file order:
  `TRANSACTION_TYPE, BATCH_ID, BATCH_NUMBER, ITEM_NUMBER, ORGANIZATION_CODE,
   CATEGORY_SET_NAME, CATEGORY_NAME, CATEGORY_CODE, OLD_CATEGORY_NAME, OLD_CATEGORY_CODE,
   SOURCE_SYSTEM_CODE, SOURCE_SYSTEM_REFERENCE, START_DATE, END_DATE`
- Template: `objects/ItemCategories/artifact/EgpItemCategoriesInterface.csv`
  (`${PREFIX}` + discovered `${ITEMNUM}`, `${ORGCODE}`, `${G1CODE}`, `${G2CODE}` tokens).
- Assembled artifact: `objects/ItemCategories/ItemCategories_gold.zip`.

---

## ESS orchestration (current — Catalog Import retarget, recipe.json as of 2026-07-19)

The categories CSV is now submitted through the dedicated **Catalog Import** job
(interfaceDetails 137). This is the documented NEXT STEP from the prior ItemImport attempt.

- Web service: ERP Integration SOAP service
  `{fusion_url}/fscmService/ErpIntegrationService`.
- Operation: `loadAndImportData` (base64-embeds the ZIP, uploads to UCM under
  `DocumentAccount = scm/item/import`, runs "Load File to Interface Tables", then is meant
  to chain the import job named below).
- Auth user: **scm_impl** (SCM). fin_impl is NOT used for this object.
- Load/import job (jobList JobName):
  `/oracle/apps/ess/scm/productModel/items,CatalogImportJobDef`.
- interfaceDetails: `137` (the `ERP_INTERFACE_OPTIONS_ID` for the SCM / Catalogs row in
  `DMT_ERP_INTERFACE_OPTIONS_TBL`; seed `db/seed/dmt_erp_interface_options_tbl.sql`).
- ParameterList (Catalog Import positional args, per Oracle "Import Catalogs with FBDI"):
  `${PREFIX},N,N` = (Batch ID / batch number = the prefix, Reprocess-Errors = N,
  Purge-after = N). Catalog Import keys row selection off the interface `BATCH_ID`.

### RESULT (live, prefix 93120, load request 9764809, scm_impl) — DID NOT CHAIN

`loadAndImportData` accepted the call and returned load request **9764809**, which the pod
records as an **`InterfaceLoaderController`**. Its only children are two
**`InterfaceLoaderAsyncJob`** requests (both state 12 = SUCCEEDED). **No
`CatalogImportJobDef` child was ever dispatched** — a pod-wide search of
`fusion.ess_request_history` for `%CATALOGIMPORT%` returns zero rows, and the controller
sat in **WAIT** (never RUNNING) for 18+ minutes. This is the memory-rule signature
(`feedback_ess_wait_timeout`): a controller stuck in WAIT that never becomes RUNNING means
the named import job was not accepted at dispatch. `loadAndImportData` will load the file
to the interface but will **not** launch `CatalogImportJobDef` standalone through the ERP
Integration chaining path.

### Prior ESS orchestration (path 1 — ItemImportJobDef, for reference)

`/oracle/apps/ess/scm/productModel/items,ItemImportJobDef`, interfaceDetails `29`,
ParameterList `${PREFIX},null,CREATE,null,null,N,Y` (7 positional args, MCCS RICE_009 /
Items pattern: Batch ID, Organization null, Process-Only CREATE, Process-All-Orgs null,
Delete-Processed null, Reprocess-Error N, Process-Sequentially Y). Loaded to the interface
but never processed the categories into base (peripheral-entity blocker, path 1 below).

---

## Discovery queries (read-only BIP, scm_impl)

**Step IC_ITEM** — an `AS%` master-org (`000`) item with ≥3 spare clean eCommerce categories:

```sql
SELECT ITEMNUM, ORGCODE FROM (
  SELECT b.item_number AS ITEMNUM, p.organization_code AS ORGCODE,
    (SELECT COUNT(*) FROM egp_categories_b c
       WHERE c.category_id IN (SELECT category_id FROM egp_category_set_valid_cats
              WHERE category_set_id=(SELECT category_set_id FROM egp_category_sets_vl
                                     WHERE category_set_name='eCommerce Catalog'))
         AND c.category_code NOT LIKE '%.%'
         AND NOT EXISTS (SELECT 1 FROM egp_item_categories a
             WHERE a.inventory_item_id=b.inventory_item_id AND a.category_id=c.category_id
               AND a.category_set_id=(SELECT category_set_id FROM egp_category_sets_vl
                                      WHERE category_set_name='eCommerce Catalog'))) AS FREECATS
  FROM egp_system_items_b b
  JOIN inv_org_parameters p ON p.organization_id=b.organization_id
  WHERE p.organization_code='000' AND b.item_number LIKE 'AS%'
  ORDER BY b.item_number) WHERE FREECATS >= 3 AND ROWNUM=1
```

**Step IC_CATEGORIES** — two clean unassigned eCommerce codes for the discovered item
(`${ITEMNUM}` is substituted from step 1):

```sql
SELECT G1CODE, G2CODE FROM (
  SELECT c.category_code AS G1CODE,
         LEAD(c.category_code) OVER (ORDER BY c.category_code) AS G2CODE,
         ROW_NUMBER() OVER (ORDER BY c.category_code) rn
  FROM egp_categories_b c
  WHERE c.category_id IN (SELECT category_id FROM egp_category_set_valid_cats
          WHERE category_set_id=(SELECT category_set_id FROM egp_category_sets_vl
                                 WHERE category_set_name='eCommerce Catalog'))
    AND c.category_code NOT LIKE '%.%'
    AND NOT EXISTS (SELECT 1 FROM egp_item_categories a
        JOIN egp_system_items_b b ON b.inventory_item_id=a.inventory_item_id
        WHERE b.item_number='${ITEMNUM}' AND a.category_id=c.category_id
          AND a.category_set_id=(SELECT category_set_id FROM egp_category_sets_vl
                                 WHERE category_set_name='eCommerce Catalog'))
) WHERE rn=1
```

Note: `egp_categories_b.CATEGORY_CODE` is the canonical concatenated code the interface
matches on (e.g. `eCom_Bus_Prod`, `Canned_Fruit`). `SEGMENT1` is NOT the match key in a
multi-level catalog (it repeats across category ids). Filtering `CATEGORY_CODE NOT LIKE
'%.%'` keeps to single-segment leaf-ish codes and avoids the ambiguous hierarchy nodes.

---

## Verify queries (read-only BIP, scm_impl) — direct single-table reads

**Good → base.** Direct read of the base assignment table `EGP_ITEM_CATEGORIES`, joined to
the item and category by the discovered item + eCommerce set + discovered codes:

```sql
SELECT c.category_code AS CATEGORY_CODE,
       TO_CHAR(a.item_category_assignment_id) AS ASSIGN_ID
FROM egp_item_categories a
JOIN egp_system_items_b b ON b.inventory_item_id=a.inventory_item_id
                         AND b.organization_id=a.organization_id
JOIN inv_org_parameters p ON p.organization_id=a.organization_id
JOIN egp_categories_b c ON c.category_id=a.category_id
WHERE b.item_number='${ITEMNUM}' AND p.organization_code='${ORGCODE}'
  AND a.category_set_id=(SELECT category_set_id FROM egp_category_sets_vl
                         WHERE category_set_name='eCommerce Catalog')
  AND c.category_code IN ('${G1CODE}','${G2CODE}','ZZBADCAT${PREFIX}')
```

A row present for each good code with a real `ITEM_CATEGORY_ASSIGNMENT_ID` = pass.

**Bad → interface + absent from base.** Direct read of the interface table by load request
id; `PROCESS_STATUS`/`HAS_ERRORS` carry the rejection, and the bad code must be absent from
the base read above:

```sql
SELECT i.category_code AS CATEGORY_CODE, i.process_status AS PROCESS_STATUS,
       (CASE WHEN i.has_errors='Y' OR i.process_status=1
             THEN 'PROCESS_STATUS='||i.process_status||' HAS_ERRORS='||NVL(i.has_errors,'?')
                  ||' (rejected: category not found / not valid for catalog)' END) AS ERROR_MESSAGE
FROM egp_item_categories_interface i
WHERE i.load_request_id = :LRID
```

---

## Blocker (path 2) — Catalog Import does not chain standalone (2026-07-19)

**Live run 2026-07-19, prefix 93120, load request id 9764809 (scm_impl),
job `CatalogImportJobDef`, interfaceDetails 137, ParameterList `93120,N,N`.** The load
request is an `InterfaceLoaderController` that stayed in **WAIT** for 18+ minutes with only
two `InterfaceLoaderAsyncJob` children (both SUCCEEDED). **No `CatalogImportJobDef` child
was dispatched** (pod-wide `%CATALOGIMPORT%` search of `ess_request_history` = 0 rows).
The prefix-93120 interface rows were not yet visible in the SCM BIP replica, and **zero**
base assignments exist for the discovered item+codes
(`AS00100`/`000`/eCommerce Catalog/`eCom_Automotive`,`eCom_Bus_Prod`). Root cause: the ERP
Integration `loadAndImportData` chaining path loads the FBDI file to the interface but does
**not** launch `CatalogImportJobDef` — the named import job is not accepted at dispatch, so
the controller waits forever for a child that never schedules. On this pod `CatalogImport`
has no history at all, i.e. it has never been driven this way. Reaching base via Catalog
Import would require submitting `CatalogImportJobDef` as its **own** scheduled process
(`submitESSJobRequest`, not the `loadAndImportData` jobList chain) *after* a separate
"Load Interface File for Import" completes — and Catalog Import is primarily a
catalog/category-structure importer that expects catalog + category interface rows, not a
bare category-assignment row. That is a materially different, unproven load path; it is out
of scope for a standalone gold retry and stays TABLED.

## Blocker (path 1) — peripheral entity of Item Import (prior finding)

**Live run 2026-07-19, prefix 90251, load request id 9763938 (scm_impl), terminal status
SUCCEEDED.** All three rows loaded into `EGP_ITEM_CATEGORIES_INTERFACE` with the correct
discovered item (`AS00100`/org `000`), set (`eCommerce Catalog`), and codes (`Canned_Fruit`,
`Industrial`, `ZZBADCAT90251`). But **all three rows stayed at `PROCESS_STATUS = 0` with
`HAS_ERRORS = NULL`** — i.e. loaded to the interface but never processed by the import.

Root cause (confirmed live + web-verified):

1. **Item category assignment is a *peripheral entity* of an Item Import *batch*.** Oracle's
   Item Import processes the *core entity* (the item) first, then peripheral entities such
   as category assignments. A category-only ZIP has no item core rows, so the Item Import
   child process has no batch to process the categories under, and they remain
   `PROCESS_STATUS = 0` (unprocessed) rather than erroring. This matches the canonical
   `objects/ItemCategories/README.md`, which already states ItemCategories is *bundled with
   Items, not a standalone ESS job*.
2. **The interface `BATCH_ID` (90251) references no real batch.** Real
   `EGI_IMPORT_BATCHES_B.batch_id` values are large surrogate ids (e.g.
   300000326645556 with `BATCH_NUMBER` 265815). A batch row is *created* by Item Import
   Preprocessing from the item interface rows; with no item rows, no batch is created, so
   the categories tagged with the synthetic id 90251 belong to no batch and are never
   picked up. Passing `BATCH_NUMBER` instead of `BATCH_ID` does not help: the control file
   resolves an existing batch by number and yields `-1` when none exists.

**Why it is not fixed here:** making the good rows reach the base requires either (a) a
companion `EgpSystemItemsInterface.csv` for the same existing item in the same ZIP so Item
Import creates the batch and the categories ride along as peripheral entities, or (b) the
dedicated **Catalog Import** job (`CatalogImportJobDef`, `EgpCatalogImportTemplate`) which
creates a catalog/category batch standalone. Path (a) means hand-building a ~130-column
item row and risks mutating an existing item — outside "do not create items first / do not
touch upstream". Path (b) is the correct standalone route and is the recommended NEXT step;
it still targets the same `EGP_ITEM_CATEGORIES_INTERFACE` table this fixture already builds.

### Web finding

Oracle documentation and community notes confirm the peripheral-entity model: "Core
entities are always processed first. Peripheral entities [category assignments] are
processed after the core entities. If the core import fails, the system stops processing
the peripheral entities." A standalone assignment therefore needs either an item batch
(Item Import) or the Catalog Import job to create the batch context.
Sources: Oracle SCM "Item Import for FBDI"
(https://docs.oracle.com/en/cloud/saas/supply-chain-and-manufacturing/25c/faips/plm-item-import-for-file-based-data-import-and-smart-spreadsheet.html);
"Import Catalogs with FBDI"
(https://docs.oracle.com/en/cloud/saas/supply-chain-and-manufacturing/24d/faipr/import-catalogs-with-fbdi.html);
"Schedule Catalog Import Job"
(https://docs.oracle.com/en/cloud/saas/supply-chain-and-manufacturing/24b/faspc/schedule-catalog-import-job.html).

---

## NEXT (to promote to gold) — both simple paths are now exhausted

Path 1 (ItemImportJobDef) and Path 2 (CatalogImportJobDef via `loadAndImportData` chaining)
have both been tried live and neither reaches base. To promote this to gold, one of the
following heavier routes is required — each is a materially different, unproven load and is
out of scope for a standalone gold retry:

1. **Two-step Catalog Import** (not the `loadAndImportData` jobList chain). Submit "Load
   Interface File for Import" to land the ZIP in `EGP_ITEM_CATEGORIES_INTERFACE`, then
   submit `CatalogImportJobDef` as its **own** `submitESSJobRequest` (params `${PREFIX},N,N`)
   so it processes the interface rows for that BATCH_ID. Catalog Import has never run on this
   pod, so its real ParameterList and whether it accepts bare category-assignment rows
   (vs. full catalog+category structure rows) are unverified.
2. **Bundle with an item batch** (Path 1 done right): add a companion
   `EgpSystemItemsInterface.csv` for the same existing item in the same ZIP so Item Import
   creates a real batch and the categories ride along as peripheral entities. This means
   hand-building a ~130-column item row and risks mutating an existing item — outside the
   "do not create items / do not touch upstream" rule.
3. If Catalog Import needs catalog/category-structure rows, add the minimal catalog+category
   interface rows for the *already-existing* eCommerce Catalog (update, not create).

When one of these is proven to land good codes in `EGP_ITEM_CATEGORIES` with real
`ITEM_CATEGORY_ASSIGNMENT_ID`s and the bad code rejected+absent, flip the status to ✅.

---

## Live evidence log

- 2026-07-19 — prefix **90251**, load request id **9763938**, scm_impl, `loadAndImportData`
  + `ItemImportJobDef`, terminal **SUCCEEDED**. Interface: 3/3 rows present in
  `EGP_ITEM_CATEGORIES_INTERFACE` (item `AS00100`, org `000`, set `eCommerce Catalog`, codes
  `Canned_Fruit`, `Industrial`, `ZZBADCAT90251`). Base `EGP_ITEM_CATEGORIES`: 0 new rows for
  the discovered item+codes. Bad code absent from base (as required). **TABLED** — peripheral
  entity, no item batch. (A later replica read showed those rows moved to `PROCESS_STATUS = 7`
  on the good rows / `3` on the bad, i.e. Item Import eventually errored them; still no base
  row.)
- 2026-07-19 — **Catalog Import retarget.** prefix **93120**, load request id **9764809**,
  scm_impl, `loadAndImportData` + `CatalogImportJobDef`, interfaceDetails **137**,
  ParameterList `93120,N,N`, item `AS00100`/org `000`/set `eCommerce Catalog`, codes
  `eCom_Automotive`, `eCom_Bus_Prod`, bad `ZZBADCAT93120`. Load request recorded as
  `InterfaceLoaderController` stuck in **WAIT for 18+ minutes**; children = two
  `InterfaceLoaderAsyncJob` (both SUCCEEDED); **no `CatalogImportJobDef` child dispatched**
  (pod-wide `%CATALOGIMPORT%` = 0 rows). Interface replica showed 0 rows for BATCH_ID 93120;
  base `EGP_ITEM_CATEGORIES` had 0 assignments for the discovered item+codes. ESS execution
  log for the controller was empty (still WAITing, no terminal log). **STILL TABLED** —
  `loadAndImportData` does not dispatch `CatalogImportJobDef` standalone; see Blocker (path 2).
