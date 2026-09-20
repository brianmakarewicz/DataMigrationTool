# DFF ATTRIBUTE Round-Trip for FBDI Objects — Findings & How-To

**Question:** Can we stamp a run-scoped reference string (`DMT:run:workitem:record`) into a
Descriptive Flexfield `ATTRIBUTE1` on each FBDI-loaded object and read it back from the Fusion
**base table** via BIP after import?

**Short answer:** Not without setup. The base tables physically have `ATTRIBUTE1..n` columns
regardless of DFF configuration, but the **import processes validate DFF segment values and drop
(reject) anything that isn't a defined + deployed segment**. Live evidence on the demo pod proves
this: GL journal DFFs have **zero enabled segments**, and across **11,030,529** `GL_JE_LINES` rows
and **97,291** `GL_JE_HEADERS` rows, **every `ATTRIBUTE1` (and every other `ATTRIBUTE`) is NULL** —
exactly the symptom seen when `GL_INTERFACE.ATTRIBUTE20` came back NULL. Where a DFF segment *is*
deployed (PO, AP, Projects on this pod), base rows *do* carry `ATTRIBUTE1` values.

Verified live 2026-09-20 against demo pod (`fin_impl` via BIP ephemeral data model).

---

## 1. The empirical verdict on the owner's hypothesis

The owner's hypothesis was: *the base tables physically have `ATTRIBUTE1..30` regardless of DFF
setup, so the import may write the raw value anyway; enabling/deploying the DFF might only affect
UI visibility + validation, not raw storage.*

**This is refuted for the FBDI import path.** The column exists physically, but the import does not
write a raw, un-validated value into it. Evidence:

| Object | DFF title | Enabled ATTRIBUTE segments on pod | Base rows | Base rows with `ATTRIBUTE1` populated |
|---|---|---|---|---|
| GL Journal header | Journals (`GL_JE_HEADERS`) | **0** | 97,291 | **0** |
| GL Journal line | Journal Lines (`GL_JE_LINES`) | **0** | 11,030,529 | **0** |
| AR Transaction | Transactions (`RA_CUSTOMER_TRX`) | **0** | — | — |
| AP Invoice header | Invoices (`AP_INVOICES`) | 8 | 52,088 | 0 (segments exist but nobody stamped ATTRIBUTE1 on these rows) |
| Projects | Project DFF (`PJF_PROJECTS_DESC_FLEX`) | 5 | 860 | (ATTRIBUTE2 populated on 1 row) |
| PO header | Purchasing Document Headers (`PO_HEADERS`) | 5 | 17,859 | **1** row, `ATTRIBUTE1 = 'LOCAL'` |

The GL result is the clincher: with **zero** deployed segments and **11 million** journal lines,
not one `ATTRIBUTE` column is populated. If the import wrote raw values regardless of DFF state, we
would expect *some* non-null attributes across 11M rows. There are none. Conversely, PO — where the
DFF is deployed — has a real `ATTRIBUTE1='LOCAL'` in a base row.

**Mechanism (why the value is dropped, from Oracle docs):** import processes validate the DFF.
Journal Import states: *"If your descriptive flexfield segments are null, then Journal Import does
not validate the descriptive flexfield. Otherwise, Journal Import will successfully import your
descriptive flexfield data if … the global segments have valid values; the context is a valid
value; the context-dependent segments have valid values."*
(https://docs.oracle.com/cd/A60725_05/html/comnls/us/gl/gloiji10.htm). A value pushed into a column
that has **no defined+deployed segment** cannot satisfy this validation, so it is not persisted.
Deployment is what makes the segment "exist" to the runtime — an un-deployed segment sits in status
**Edited**/**Patched** and *"isn't reflected in the production environment"* until it reaches
**Deployed**
(https://docs.oracle.com/en/cloud/saas/human-resources/faucf/overview-of-flexfield-deployment.html).

> Note on the earlier `ATTRIBUTE20` failure: on this pod the GL DFFs have *no* segments deployed at
> **any** index, so ATTRIBUTE20 failing is fully explained by "DFF not deployed," not by "the import
> maps 1–15 but not 20." `GL_INTERFACE` and `GL_JE_LINES` both physically carry `ATTRIBUTE1..20`, so
> once a segment is deployed on ATTRIBUTE20 it would carry. There is no evidence of an index cap
> below 20 for GL. (Ranges *do* differ by object — see §3.)

**Bottom line for the design question:** we **cannot** write `ATTRIBUTE1` and read it back from the
base table with zero config. The DFF segment must be defined and deployed first.

---

## 2. Exact setup to make `ATTRIBUTE1` round-trip for an FBDI object

Do this once per object (config, not code). UI path: **Setup and Maintenance → Manage Descriptive
Flexfields** (search the DFF by name/code, e.g. `GL_JE_LINES`).

1. **Edit the DFF.** Open the flexfield. It is already registered against the table (the
   `ATTRIBUTE1..n` columns pre-exist).
2. **Create/enable a segment on `ATTRIBUTE1`.** Add a **global segment** (simplest — always applies,
   no context needed), set its **column assignment = ATTRIBUTE1**, data type Character, a value set
   that accepts a free-form string long enough for `DMT:run:workitem:record` (e.g. a format-only text
   value set of length 150). A **global** segment avoids needing `ATTRIBUTE_CATEGORY` to be set on the
   interface row. (Global vs context-sensitive:
   https://docs.oracle.com/en/cloud/saas/applications-common/26a/oaext/considerations-for-managing-descriptive-flexfields.html)
3. **(Optional) Validate.** Manage Descriptive Flexfields → Actions → **Validate Flexfield**
   (https://docs.oracle.com/en/cloud/saas/applications-common/25c/oaext/validate-descriptive-flexfields.html).
4. **Deploy.** Manage Descriptive Flexfields → **Deploy Flexfield**. Wait for status **Deployed**.
   *"After you configure a flexfield, you must deploy it to make the changes available."*
   (https://docs.oracle.com/en/cloud/saas/human-resources/faucf/overview-of-flexfield-deployment.html)
5. **Load via FBDI as usual**, populating the interface `ATTRIBUTE1` (and `ATTRIBUTE_CATEGORY` only
   if you used a context-sensitive segment). Then read back
   `SELECT attribute1 FROM <base_table>` via BIP.

If you use a **context-sensitive** segment instead of global, you must also stamp the interface
`ATTRIBUTE_CATEGORY` (and `ATTRIBUTE_CATEGORY2` for GL lines 11–20) to the matching context code, or
validation won't select the segment. **Recommendation: use a global segment on ATTRIBUTE1** to keep
the stamp uniform and avoid the context dance. Also confirm the FBDI import option that governs DFF
transfer is not overwriting the value (e.g. AP's "Transfer PO distribution additional information"
can backfill null attribute columns from the PO).

---

## 3. Per-object table

DFF display name / code and base column confirmed live (`FND_DESCRIPTIVE_FLEXS_VL`,
`FND_DESCR_FLEX_COLUMN_USAGES`, `ALL_TAB_COLUMNS`) on the demo pod 2026-09-20.

| Object | DFF (title / code) | Base table | `ATTRIBUTE1` exists? | Attr range on base | Enabled segments on demo? | Would `ATTRIBUTE1` round-trip today? |
|---|---|---|---|---|---|---|
| GL Journal header | Journals / `GL_JE_HEADERS` | `GL_JE_HEADERS` | **Y** | 1..10 | **No (0)** | No — needs deploy |
| GL Journal line | Journal Lines / `GL_JE_LINES` | `GL_JE_LINES` | **Y** | 1..20 | **No (0)** | No — needs deploy |
| AP Invoice header | Invoices / `AP_INVOICES` | `AP_INVOICES_ALL` | **Y** | 1..15 | **Yes (8)** — but on ATTRIBUTE1? see note | Likely, if a segment sits on ATTRIBUTE1 |
| AP Invoice line | Invoice Lines | `AP_INVOICE_LINES_ALL` | **Y** | 1..15 | unknown (not enumerated) | Verify per segment |
| AR Transaction (DFF) | Transactions / `RA_CUSTOMER_TRX` | `RA_CUSTOMER_TRX_ALL` | **Y** | 1..15 | **No (0)** | No — needs deploy |
| AR Transaction line (DFF) | (line DFF `RA_CUSTOMER_TRX_LINES`) | `RA_CUSTOMER_TRX_LINES_ALL` | **Y** | 1..15 | unknown | No/verify |
| PO header | Purchasing Document Headers / `PO_HEADERS` | `PO_HEADERS_ALL` | **Y** | 1..20 | **Yes (5, incl. ATTRIBUTE1=Y)** | **Yes** (base row already shows `ATTRIBUTE1='LOCAL'`) |
| PO line | (PO line DFF) | `PO_LINES_ALL` | **Y** | 1..20 | unknown | Verify |
| Requisition header | Requisition Headers / `POR_REQUISITION_HEADERS` | `POR_REQUISITION_HEADERS_ALL` | **Y** | 1..20 | unknown | Verify |
| Requisition line | (line DFF) | `POR_REQUISITION_LINES_ALL` | **Y** | 1..20 | unknown | Verify |
| Projects | Project Descriptive Flexfield / `PJF_PROJECTS_DESC_FLEX` | `PJF_PROJECTS_ALL_B` | **Y** | 1..50 | **Yes (5, incl. ATTRIBUTE1=Y)** | **Yes** for ATTRIBUTE1 (segment enabled) |
| Fixed Assets | Asset Category / `FA_ADDITIONS` | `FA_ADDITIONS_B` | **Y** | 1..30 | Partial (ATTRIBUTE2 seen; ATTRIBUTE1 not) — structure col is `ATTRIBUTE_CATEGORY_CODE` | Verify; note category-driven context |
| Items | Item DFF / `EGP_SYSTEM_ITEMS_DFF` | `EGP_SYSTEM_ITEMS_B` | **Y** | 1..30 (VARCHAR2 240) | unknown (SCM data source) | Verify |
| Suppliers | Supplier Profile / `POZ_SUPPLIERS` | `POZ_SUPPLIERS` | **Y** (per docs, 1..20) | 1..20 | unknown | Verify; **prefer EXTERNAL_SYSTEM ref** |
| Customers (TCA party) | Party DFF | `HZ_PARTIES` | **Y** (per docs, 1..30) | 1..30 | unknown | Verify; **prefer ORIG_SYSTEM_REFERENCE** |

**All 13 base tables I could query confirmed `ATTRIBUTE1` physically exists** (live
`ALL_TAB_COLUMNS`): GL_JE_HEADERS(1..10), GL_JE_LINES(1..20), AP_INVOICES_ALL(1..15),
AP_INVOICE_LINES_ALL(1..15), RA_CUSTOMER_TRX_ALL(1..15), RA_CUSTOMER_TRX_LINES_ALL(1..15),
PO_HEADERS_ALL(1..20), PO_LINES_ALL(1..20), POR_REQUISITION_HEADERS_ALL(1..20),
POR_REQUISITION_LINES_ALL(1..20), PJF_PROJECTS_ALL_B(1..50), FA_ADDITIONS_B(1..30),
EGP_SYSTEM_ITEMS_B(1..30). Supplier/TCA ranges are from Oracle docs (not queried; SCM/CRM data
source). **The physical column existing does NOT mean the value round-trips — deployment gates it.**

> AP note: `AP_INVOICES` has 8 enabled segments on this pod but they are demo contexts ("My Group 1",
> "My Group 2") on ATTRIBUTE2/4/date columns — not necessarily a global ATTRIBUTE1. Confirm a segment
> sits specifically on ATTRIBUTE1 before relying on it.

### The AR trap (do not conflate three column families)
`RA_INTERFACE_LINES_ALL` carries **four** flexfield families:
- `INTERFACE_HEADER_ATTRIBUTE1..15` + `INTERFACE_HEADER_CONTEXT` → **Transaction (header) Flexfield**,
  an AutoInvoice **identity/reference key** → lands in `RA_CUSTOMER_TRX_ALL.INTERFACE_HEADER_ATTRIBUTE*`.
- `INTERFACE_LINE_ATTRIBUTE1..15` + `INTERFACE_LINE_CONTEXT` → **Line Transaction Flexfield**
  (identity/link key) → `RA_CUSTOMER_TRX_LINES_ALL.INTERFACE_LINE_ATTRIBUTE*`.
- `HEADER_ATTRIBUTE1..15` + `HEADER_ATTRIBUTE_CATEGORY` → **header DFF** passthrough →
  `RA_CUSTOMER_TRX_ALL.ATTRIBUTE*`.
- `ATTRIBUTE1..15` + `ATTRIBUTE_CATEGORY` → **line DFF** passthrough →
  `RA_CUSTOMER_TRX_LINES_ALL.ATTRIBUTE*`.

For AR, the `INTERFACE_*_ATTRIBUTE*` columns are the **native source-reference carrier** and do NOT
require a DFF to round-trip — that is what AutoInvoice uses to tie a Fusion transaction back to your
source system. This is the AR equivalent of the "native reference field" option in §5.

---

## 4. Can the setup be automated (config, not code)?

Yes — DFF setup is FSM setup data, so it is exportable/importable and scriptable, but there is **no
single clean REST call literally named "Deploy Flexfield."** Options, strongest first:

- **CSV setup import via scheduled process** — *"Upload Comma-Separated Value Files for Import"*
  uploads a flat file of setup artifacts *"such as flexfields, messages, lookups"* to add/update
  setup data. Prepare the CSV, upload via File Import and Export, run the process.
  (https://docs.oracle.com/en/cloud/saas/applications-common/23b/oaext/upload-comma-separated-value-files-for-import-process-.html)
- **FSM CSV file packages + REST** — export a task's setup (including flexfields) as a CSV package
  and import into another pod. REST resources: **Setup Task CSV Exports / Imports / Template
  Exports** and the Offering equivalents (REST API for Common Features). Role
  `ORA_ASM_FUNCTIONAL_SETUPS_USER_ABSTRACT` + task privileges. Gives a fully programmatic
  export→import pipeline.
  (https://docs.oracle.com/en/cloud/saas/applications-common/25c/oafsm/automate-export-and-import-of-csv-file-packages.html)
- **Deploy step** — deployment is initiated by the **Deploy Flexfield** UI action or carried as part
  of setup import / the "Deploy Flexfields" scheduled-process family. Treat programmatic deploy as
  "setup-import-driven or scheduled process," **not** a documented standalone REST endpoint. Verify
  on the target release before relying on it.

Practical recommendation: build a one-time, repeatable **CSV setup package** that defines a single
global `ATTRIBUTE1` segment on each object's DFF, import it per environment, and deploy. This makes
the enablement reproducible across TEST/GOLD/customer pods as config.

---

## 5. Recommended approach for the #12 reference stamp

**Use a hybrid, per-object, preferring the native source-reference field where one exists; use a
deployed global `ATTRIBUTE1` DFF only where there is no native carrier.**

Rationale: several objects already have a purpose-built, no-setup-required source-reference field
that survives import to the base table without any DFF deployment. Using those is more robust (they
are indexed / meant for cross-reference) and zero-config:

| Object | Preferred native reference carrier (no DFF setup) | Fallback |
|---|---|---|
| Suppliers | `EXTERNAL_SYSTEM` / `EXTERNAL_SYSTEM_ID` (POZ_SUPPLIERS) | Supplier DFF ATTRIBUTE1 |
| Customers / TCA parties | `ORIG_SYSTEM` + `ORIG_SYSTEM_REFERENCE` (HZ_ORIG_SYS_REFERENCES / HZ_PARTIES) | Party DFF ATTRIBUTE1 |
| AR transactions | `INTERFACE_HEADER_ATTRIBUTE*` / `INTERFACE_LINE_ATTRIBUTE*` (Transaction Flexfield) | Transaction DFF ATTRIBUTE1 |
| GL journals | *(none native)* → **deployed global ATTRIBUTE1 DFF** on GL_JE_LINES/HEADERS | — |
| AP invoices | *(none native for arbitrary ref)* → **deployed ATTRIBUTE1 DFF** | — |
| PO / Requisitions | *(none native)* → deployed ATTRIBUTE1 DFF (PO already has one enabled here) | — |
| Projects | *(none native)* → deployed ATTRIBUTE1 DFF (already enabled here) | — |
| Fixed Assets | *(none native)* → deployed ATTRIBUTE1 DFF (mind `ATTRIBUTE_CATEGORY_CODE`) | — |
| Items | *(none native for arbitrary ref)* → deployed ATTRIBUTE1 DFF | — |

If uniformity across all objects matters more than robustness, the alternative is: **deploy a global
`ATTRIBUTE1` DFF segment on every object** via the CSV setup package (§4) and stamp `ATTRIBUTE1`
everywhere. This is clean and uniform but requires the one-time config on each pod and does not
leverage the better native fields for suppliers/customers/AR.

**Do NOT** rely on writing `ATTRIBUTE1` (or any ATTRIBUTE index) and reading it back with no setup —
the live GL evidence proves the value is dropped.

---

## What I could and couldn't verify live

**Verified live (demo pod, 2026-09-20):**
- Every listed base table physically has `ATTRIBUTE1` (ranges above), via `ALL_TAB_COLUMNS`.
- GL "Journals" and "Journal Lines" DFFs exist in the registry but have **0 enabled ATTRIBUTE
  segments**; AR "Transactions" DFF also 0.
- 11,030,529 `GL_JE_LINES` and 97,291 `GL_JE_HEADERS` rows: **all `ATTRIBUTE*` NULL**.
- PO, AP, Projects DFFs have enabled segments (PO & Projects include an enabled ATTRIBUTE1); a real
  `PO_HEADERS_ALL` row carries `ATTRIBUTE1='LOCAL'`.

**Could not verify live:**
- Supplier/TCA/Item DFF segment deployment state (SCM/CRM data source not queried here; column ranges
  are from Oracle docs).
- A standalone "Deploy Flexfield" REST endpoint — not found in docs; deployment is UI action /
  scheduled process / setup-import driven.
- Exact enabled column for AP's ATTRIBUTE1 (its 8 segments are demo contexts on other columns).
- MOS Note 2669059.1 body (login-gated) — its title corroborates FBDI DFF updates for Assets require
  DFF configuration.

## Key citations
- Journal Import DFF validation (null skipped, else must be valid): https://docs.oracle.com/cd/A60725_05/html/comnls/us/gl/gloiji10.htm
- Flexfield deployment & status meanings: https://docs.oracle.com/en/cloud/saas/human-resources/faucf/overview-of-flexfield-deployment.html
- Managing DFFs (global vs context-sensitive, column assignment): https://docs.oracle.com/en/cloud/saas/applications-common/26a/oaext/considerations-for-managing-descriptive-flexfields.html
- Validate flexfield: https://docs.oracle.com/en/cloud/saas/applications-common/25c/oaext/validate-descriptive-flexfields.html
- Upload CSV for setup import (scheduled process): https://docs.oracle.com/en/cloud/saas/applications-common/23b/oaext/upload-comma-separated-value-files-for-import-process-.html
- FSM CSV export/import + REST resources: https://docs.oracle.com/en/cloud/saas/applications-common/25c/oafsm/automate-export-and-import-of-csv-file-packages.html
- GL_INTERFACE (ATTRIBUTE1..20 + ATTRIBUTE_CATEGORY/_CATEGORY2): https://docs.oracle.com/en/cloud/saas/financials/25d/oedmf/glinterface-8553.html
- AR AutoInvoice interface (INTERFACE_*_ATTRIBUTE vs DFF passthrough): https://docs.oracle.com/en/cloud/saas/financials/25d/faofc/autoinvoice-interface-table-ra-interface-lines-all.html
- Suppliers source ref (EXTERNAL_SYSTEM): https://docs.oracle.com/en/cloud/saas/procurement/25d/oedmp/pozsuppliers-23042.html
- TCA source ref (HZ_ORIG_SYS_REFERENCES): https://docs.oracle.com/en/cloud/saas/sales/oedms/hzorigsysreferences-25121.html
