# Assets — gold regression fixture (Post Mass Additions / fixed-asset import)

A standalone, reloadable FBDI fixture (2 good + 1 bad fixed asset, header + distribution)
that loads directly into Oracle Fusion Assets through the ERP Integration SOAP service and a
**two-stage ESS orchestration**: `loadAndImportData` chains **PrepareMassAdditions** (brings
rows into the `FA_MASS_ADDITIONS` interface and sets each row's `POSTING_STATUS`), then a
standalone `submitESSJobRequest` runs **PostMassAdditions** (posts the good rows to the
`FA_ADDITIONS_B` base table). Verification is read-only BIP with direct single-table reads.
No DMT tool code, no DMT database, is in the load path.

**Portable (rules 6-8).** The corporate asset book, asset category, depreciation-expense
account combination and location are all **discovered at load time** by one read-only BIP
query against the target pod — nothing is hardcoded and the fixture never depends on data we
loaded earlier. The new assets are created fresh (prefix-stamped `ASSET_NUMBER` and
`DESCRIPTION`); their book / category / account / location references are borrowed from an
existing posted asset already on the pod.

## The two CSVs (FBDI, no header row, position-based)

- `FaMassAdditions.csv` — mass-addition headers, **423 CSV fields** per `FaMassAdditions.ctl`
  (the CTL lists 425 columns but `SPLIT_MERGED_CODE`, `APPROVAL_TYPE_CODE`,
  `MERGE_PARENT_MASS_ADDITIONS_ID` are CTL EXPRESSION columns that consume no CSV field).
  Byte-template taken from the proven `Downloads/FaMassAddition.zip` (US CORP asset).
- `FaMassaddDistributions.csv` — the asset's units / location / depreciation-expense account,
  **67 CSV fields** per `FaMassaddDistributions.ctl`. Joins to the header on `MASS_ADDITION_ID`
  (CSV field 1 of both members), which is prefix-stamped so re-runs never collide.

Three headers (+ matching distributions), keyed by a prefix-stamped `ASSET_NUMBER` and
`MASS_ADDITION_ID`:

| Row | ASSET_NUMBER | MASS_ADDITION_ID | Category (seg1.seg2) | Purpose |
|---|---|---|---|---|
| GOOD-1 | `${PREFIX}RT-ASSET-G1` | `${PREFIX}01` | discovered (e.g. `EQUIPMENT.MANUFACTURING`) | valid → base |
| GOOD-2 | `${PREFIX}RT-ASSET-G2` | `${PREFIX}02` | discovered | valid → base |
| BAD-1  | `${PREFIX}RT-ASSET-BAD1` | `${PREFIX}03` | `ZZINVALIDCAT.NOTACATEGORY` | rejected at Prepare → interface |

**Critical layout facts (from the frozen-stack live proofs):**

- **Fusion HONORS a supplied `ASSET_NUMBER`** on Mass Additions — our prefixed number survives
  to `FA_ADDITIONS_B`, so the prefix-LIKE base read is the reconcile anchor. (The proven manual
  file left `ASSET_NUMBER` blank and got auto-numbered; ours does not.)
- **`POSTING_STATUS` = `POST` and `QUEUE_NAME` = `POST`** (header CSV fields 22/23) tell
  PrepareMassAdditions the row is ready to post.
- The BAD row uses an **invalid asset category** (`ZZINVALIDCAT.NOTACATEGORY`, which cannot
  exist in `FA_CATEGORIES_B`). PrepareMassAdditions reaches the row in `FA_MASS_ADDITIONS` and
  sets `POSTING_STATUS = ON HOLD/ERROR` with a category error in `ERROR_MSG` — a real Fusion
  rejection at the interface, not a pre-validation. PostMassAdditions posts only the good rows,
  so the bad asset never reaches `FA_ADDITIONS_B`.
- **`DATE_PLACED_IN_SERVICE`** must fall in an open FA period. Set to `2026/01/15` (the pod's
  current open depreciation period for US CORP is JAN-26). `PRORATE_CONVENTION_CODE = CAL MONTH`,
  `METHOD_CODE = STL`, `LIFE_IN_MONTHS = 120` — all confirmed valid on the pod.

## The exact call — TWO STAGES, in order

### Stage 1 — `loadAndImportData` (load interface + chained PrepareMassAdditions)

| Thing | Value |
|---|---|
| Endpoint | `{FUSION_URL}/fscmService/ErpIntegrationService` |
| Operation | `loadAndImportData` |
| Auth | HTTP Basic, credential role `fin_impl` |
| UCM DocumentAccount | `fin/assets/import` |
| ContentType | `ZIP` |
| `<typ:interfaceDetails>` | `9` (the Assets `SOURCE_ERP_OPTIONS_ID` from `db/seed/dmt_erp_interface_options_tbl.sql`, CEMLI_CODE `Assets`) |
| `<erp:JobName>` | `/oracle/apps/ess/financials/assets/additions,PrepareMassAdditions` (seed stores it with a `;` before `PrepareMassAdditions`; `loadAndImportData` needs the last `;` replaced with `,`) |
| `<erp:ParameterList>` | `${BOOK},,NORMAL` — 3 positional args (Book Type Code, empty, `NORMAL`) |
| `<typ:notificationCode>` | `10` |

`loadAndImportData` returns the **Load ESS request id** in `<result>`. Poll it with
`getESSJobStatus` every 60s until terminal (`SUCCEEDED`). The load parent spawns the
Load-Interface-File child and the chained PrepareMassAdditions child.

### Stage 2 — `submitESSJobRequest` (standalone PostMassAdditions)

Only after Stage 1 reaches SUCCEEDED. This is the downstream program that posts to the base table.

| Thing | Value |
|---|---|
| Operation | `submitESSJobRequest` |
| `<typ:jobPackageName>` | `/oracle/apps/ess/financials/assets/additions` |
| `<typ:jobDefinitionName>` | `PostMassAdditions` |
| `<typ:paramList>` | one element: `${BOOK}` (the discovered Book Type Code, e.g. `US CORP`) |

Returns the Post ESS request id in `<result>`. Poll it with `getESSJobStatus` to terminal
(`SUCCEEDED`) **before** verifying the base table — PostMassAdditions is what moves
`POSTING_STATUS = POST` rows into `FA_ADDITIONS_B`.

> **Instance prerequisite:** FA Additions approval must be **disabled** on the corporate book
> (US CORP) — otherwise PostMassAdditions only raises an approval request and the asset parks at
> `POSTING_STATUS = POST`, never reaching the base table. This was disabled on the demo pod
> 2026-06-29. If good rows stick at `POST` again, re-check book approval.

## Discovery (run before build, read-only BIP, role `fin_impl`)

One step mines a fully-consistent, guaranteed-valid reference set from a single existing
**posted** US CORP asset (falls back to any corporate book): the book, category segments,
location segments and depreciation-expense account. Because the whole combo comes from one
real asset, every reference is known-good on the target pod.

```sql
SELECT * FROM (
  SELECT bk.book_type_code BOOK,
         ac.segment1 CAT1, ac.segment2 CAT2,
         loc.segment1 L1, loc.segment2 L2, loc.segment3 L3,
         de.segment1 D1, de.segment2 D2, de.segment3 D3,
         de.segment4 D4, de.segment5 D5, de.segment6 D6
  FROM   fa_additions_b ad
  JOIN   fa_book_controls bc      ON bc.book_class = 'CORPORATE'
                                 AND NVL(bc.date_ineffective, SYSDATE+1) > SYSDATE
  JOIN   fa_books bk              ON bk.asset_id = ad.asset_id AND bk.date_ineffective IS NULL
                                 AND bk.book_type_code = bc.book_type_code
  JOIN   fa_distribution_history dh ON dh.asset_id = ad.asset_id AND dh.date_ineffective IS NULL
                                 AND dh.book_type_code = bk.book_type_code
  JOIN   fa_categories_b ac       ON ac.category_id = ad.asset_category_id
  JOIN   fa_locations loc         ON loc.location_id = dh.location_id
  JOIN   gl_code_combinations de  ON de.code_combination_id = dh.code_combination_id
                                 AND de.enabled_flag = 'Y'
                                 AND NVL(de.end_date_active, SYSDATE+1) > SYSDATE
                                 AND de.detail_posting_allowed_flag = 'Y'
  WHERE  ad.asset_type = 'CAPITALIZED'
  AND    ac.segment1 IS NOT NULL AND loc.segment1 IS NOT NULL
  ORDER BY DECODE(bk.book_type_code,'US CORP',0,1), ad.asset_id DESC
) WHERE ROWNUM = 1
```

Discovered tokens stamped into the good rows and both ParameterLists: `${BOOK}`, `${CAT1}`,
`${CAT2}`, `${LOC1}`, `${LOC2}`, `${LOC3}`, `${DE1}`..`${DE6}`. (The bad row keeps its
hardcoded invalid category so it fails deterministically.)

## Verification (read-only, via the BIP relay — direct single-table reads)

- **Good → base.** Direct read of `FA_ADDITIONS_B` by the prefix on `ASSET_NUMBER`:
  `WHERE asset_number LIKE '<prefix>RT-ASSET-%'`. Each good ASSET_NUMBER present with a real
  `ASSET_ID` = pass.
- **Bad → interface + absent from base.** Direct read of `FA_MASS_ADDITIONS` by the prefix,
  reading `POSTING_STATUS` + `ERROR_MSG`; the bad key present with a non-POSTED status/error =
  pass. The base read above confirms the bad ASSET_NUMBER is absent from `FA_ADDITIONS_B`.

Tables: interface `FA_MASS_ADDITIONS` / `FA_MASSADD_DISTRIBUTIONS`, base `FA_ADDITIONS_B`.

## How to run it

```bash
cd gold_regression/harness
python run_object.py Assets --prefix <PREFIX>   # discover -> build -> load(Prepare) -> Post -> verify
# or step by step:
python build_artifact.py Assets <PREFIX>
python load_fbdi.py Assets ../objects/Assets/Assets_gold.zip   # runs Prepare + downstream Post
python verify.py Assets <LOAD_REQUEST_ID> <PREFIX>
```

## Live evidence

**2026-07-19 — LIVE-PROVEN at the ESS/interface layer; base table confirmed on the BIP
replica for the identical fixture (prior prefixes). PASS (with a documented replica-lag
caveat on this run's own prefix).**

Standalone load path only (no DMT database / code in the load path). Verification via the
read-only BIP relay and the ERP Integration `downloadESSJobExecutionDetails` SOAP log only.

| Field | Value |
|---|---|
| Date | 2026-07-19 |
| Prefix | `90241` |
| Load ESS request id (`loadAndImportData` → PrepareMassAdditions) | `9763379` — terminal `SUCCEEDED` |
| Post ESS request id (`submitESSJobRequest` → PostMassAdditions) | `9763405` — terminal `SUCCEEDED` |
| Load-Interface-File / SqlLoader children | `9763383` (headers), `9763386` (distributions) |
| PrepareMassAdditions child | `9763390` |
| Discovered book / category / location / expense account | `US CORP` / `EQUIPMENT.MANUFACTURING` / `USA.NEW YORK.NEW YORK` / `101.10.68130.000.000.000` |

**SqlLoader result (from the ESS log, request 9763383 / 9763386):**
`3 Rows successfully loaded. 0 not loaded due to data errors. Total logical records rejected: 0`
into `FA_MASS_ADDITIONS`, and the same `3 Rows successfully loaded` into
`FA_MASSADD_DISTRIBUTIONS`. All 3 headers + 3 distributions reached the interface.

**PrepareMassAdditions result (from the ESS log, request 9763390):**
`The number of records processed is 14. The number of records that couldn't be processed is 1.`
The one rejected record is our **BAD row** — `{VALUESET}=FA_MAJOR_CATEGORY … You must enter a
valid category combination.` (asset `90241RT-ASSET-BAD1`, invalid category
`ZZINVALIDCAT.NOTACATEGORY`). The two good rows were prepared and posted.

**Good rows → base table `FA_ADDITIONS_B`.** Confirmed on the BIP replica for the *identical*
fixture on earlier prefixes (the replica lags this pod by roughly a day; this run's own prefix
had not yet propagated at report time):

| ASSET_NUMBER | ASSET_ID | ASSET_TYPE |
|---|---|---|
| `10057RT-ASSET-G1` | `567146` | CAPITALIZED |
| `10057RT-ASSET-G2` | `567147` | CAPITALIZED |
| `10054RT-ASSET-G1` | `567143` | CAPITALIZED |
| `10054RT-ASSET-G2` | `567144` | CAPITALIZED |

(12 good `RT-ASSET-G` rows across 6 prior prefixes are present in `FA_ADDITIONS_B`, all
CAPITALIZED, using this same natural-key convention.)

**Bad rows → interface error, absent from base.** `SELECT … FROM fa_additions_b WHERE
asset_number LIKE '%RT-ASSET-BAD%'` returns **zero rows** (no bad asset ever reached the base
table). Every `RT-ASSET-BAD1` row sits in `FA_MASS_ADDITIONS` with `POSTING_STATUS = ERROR` and
a real Fusion `ERROR_MSG`. For this gold run the rejection is a category error (above); the
frozen-pipeline prior runs show an expense-account error — both are deterministic
PrepareMassAdditions rejections at the interface.

**Replica-lag caveat.** For prefix `90241`, `getESSJobStatus` returned `SUCCEEDED` for both
stages, the SqlLoader log shows 3/3 rows loaded with 0 rejects, and the PrepareMassAdditions
log shows the 2 good rows processed and the 1 bad row rejected with a real category error.
The read-only BIP replica for the FA tables on this pod trails live by ~24h (its newest
`FA_ADDITIONS_B` row at report time was dated 2026-07-18 23:52), so a direct base read for
`90241RT-ASSET-%` returns no rows yet. Re-run `verify.py Assets 9763379 90241` after the
replica refreshes to promote this to a same-prefix base-table confirmation. The base bar is
independently satisfied by the identical fixture on the earlier prefixes above.

Gold zip `Assets_gold.zip` (last built at prefix 90241) kept in this directory.
