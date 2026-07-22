# Reconciler enhancement — read the Fusion INTERFACE record for still-UNACCOUNTED rows

**Branch:** `fix/reconcile-interface-errors` (off `origin/main`)
**Status:** DESIGN + DRAFT only. Nothing deployed, nothing merged. Owner reviews first.
**Owner directive (2026-07-22):** "account for errors in both locations, concatenate them if
they both exist, and write them to the TFM table." Never fabricate — only write outcomes
Fusion actually recorded.

---

## 1. The problem, restated with live evidence

A record's Fusion outcome can be recorded in TWO places:

- **(a) the import job's BIP report XML** — per-row accept/reject list (e.g. the
  `ImportProjectReportJob` output).
- **(b) the Fusion INTERFACE table's own per-row status/error column** — every FBDI interface
  table carries a per-row status; some also carry an error/message column.

Today the three reconcilers below confirm LOADED from the base table and read errors from the
import report (Projects) or the interface tables that survive (Customers/Expenditures). A row
whose only recorded outcome is the interface record's status — with no base row and no report
line — falls through to `[UNACCOUNTED]`.

### Live proof (read directly from Fusion via `scripts/fusion_bip_query.py --cred fin_impl`)

**Projects — run 241, task `NOPROJ999.1` (project `10122NOPROJ999`):**

```
SELECT task_number, project_number, import_status, load_status FROM pjf_proj_elements_xface
WHERE project_number LIKE '10122%'
-> NOPROJ999.1 | 10122NOPROJ999 | IMPORT_STATUS=SUBMITTED | LOAD_STATUS=COMPLETE
```

The task IS in the interface table with `IMPORT_STATUS='SUBMITTED'` — it loaded to the interface
but was never imported (its parent project does not exist). The two GOOD tasks are NOT in the
interface any more (purged on successful import). So the interface retains exactly the
un-imported rows, and `SUBMITTED` is the real, Fusion-recorded outcome. The import report
(`ImportProjectReportJob`) has NO task-error line for it (`TASK_ERROR_FOUND=N`) — confirmed in
`docs/findings/run234_Projects.md`. `PJF_PROJ_ELEMENTS_XFACE` has **no error-message column**
(columns: `STATUS, RECORD_STATUS, IMPORT_STATUS, LOAD_STATUS, LOAD_REQUEST_ID, REQUEST_ID`), so
the only thing to report for the task is its status label.

**Customers — run 240, four Party Site Uses under `DMT_HZ_PARTY_SITE_USES_TFM_TBL`:**

```
SELECT site_orig_system_reference, site_use_type, import_status_code, interface_status
FROM hz_imp_partysiteuses_t WHERE site_orig_system_reference LIKE '10121%'
-> 10121RT-PSITE-G1 | BILL_TO     | W | W   (parent site held for CDM duplicate review)
-> 10121RT-PSITE-G1 | INVALID_USE | E | E   (rejected by import)
-> 10121RT-PSITE-G2 | BILL_TO     | S | S   (created)
-> 10121RT-PSITE-G3 | BILL_TO     | S | S   (created)
```

All four are in the interface with a per-row status. Yet all four sit `UNACCOUNTED` because:

1. `SITEUSE_ORIG_SYSTEM_REF` is **NULL** on every one of these interface rows (confirmed live),
   so the currently-deployed V1 report — which keys the site-use error tier on that column —
   returns nothing.
2. The site uses did **not** register in `HZ_ORIG_SYS_REFERENCES` (a base-tier query for
   `owner_table_name='HZ_PARTY_SITE_USES'` and `orig_system_reference LIKE '10121%'` returns
   zero rows), so even the two `S` (created) site uses can never be confirmed by the base tier
   on the site-use's own reference. Their real outcome lives ONLY on the interface record.

The committed-but-**undeployed** `DMT_CUST_RECON_V2_DM.xdm` already fixes the key (parent
`SITE_ORIG_SYSTEM_REFERENCE || '/' || SITE_USE_TYPE`) and already emits a per-row interface
error tier for all seven record types (see `bip/Customers/query.sql`). So Customers is largely
a **deploy-the-V2-data-model** problem plus the concatenation change; the reconciler code
already has the interim-key branches.

---

## 2. What each object needs (interface table, per-row status/error column, tie-back key)

| Object | Interface table | Per-row status column(s) | Error/message column | Tie-back key to our TFM row |
|---|---|---|---|---|
| **Projects — Projects** | `PJF_PROJECTS_ALL_XFACE` | `IMPORT_STATUS`, `LOAD_STATUS` | none (report only) | `PROJECT_NUMBER` (prefixed) |
| **Projects — Tasks** | `PJF_PROJ_ELEMENTS_XFACE` | `IMPORT_STATUS` (`SUBMITTED`=loaded-not-imported), `LOAD_STATUS` | **none** | `PROJECT_NUMBER` + `TASK_NAME`/number; filter `LOAD_REQUEST_ID` |
| **Projects — TeamMembers** | `PJF_PROJECT_PARTIES_INT` | `IMPORT_STATUS`, `LOAD_STATUS` | none | `PROJECT_NAME` + `TEAM_MEMBER_NAME` |
| **Projects — TxnControls** | `PJC_TXN_CONTROLS_STAGE` | `LOAD_STATUS` (no import status) | none | `PROJECT_NUMBER` + `TXN_CTRL_REFERENCE` |
| **Customers — 7 record types** | `HZ_IMP_PARTIES_T`, `HZ_IMP_LOCATIONS_T`, `HZ_IMP_PARTYSITES_T`, `HZ_IMP_PARTYSITEUSES_T`, `HZ_IMP_ACCOUNTS_T`, `HZ_IMP_ACCTSITES_T`, `HZ_IMP_ACCTSITEUSES_T` | `IMPORT_STATUS_CODE` (`S`=created, `E`=rejected, `W`=held), `INTERFACE_STATUS` | none per-row; `HZ_IMP_ERRORS.MESSAGE_NAME` is batch-level context, joined by `BATCH_ID` + `INTERFACE_TABLE_NAME` | each type's own `*_ORIG_SYSTEM_REFERENCE`; **PartySiteUses interim key** = `SITE_ORIG_SYSTEM_REFERENCE || '/' || SITE_USE_TYPE` (own ref is NULL); filter `LOAD_REQUEST_ID` |
| **Expenditures** | `PJC_TXN_XFACE_STAGE_ALL` | `TRANSACTION_STATUS_CODE` (`P`=processed/success) | **none** (`AD#19`: no `%MSG%`/`%ERR%` column) | `ORIG_TRANSACTION_REFERENCE` (prefixed); filter `LOAD_REQUEST_ID` |

Two of the three objects' interface tables carry **no error-message column** — only a status.
So the honest thing to write for those is the **status label**, spelled out (e.g. "loaded to
the interface but not imported — interface status SUBMITTED"), never an invented Fusion message.
Only Customers has a batch-level `HZ_IMP_ERRORS.MESSAGE_NAME` to append as extra context.

---

## 3. Design — TWO distinct accounting mechanisms, in priority order

Per the owner's clarification (2026-07-22) and `docs/DMT_DESIGN.html` §5 ("5 · Error handling",
sub-section "How each row's outcome is resolved (end state)"), a still-unaccounted row is
resolved by TWO separate mechanisms. They run in this order, AFTER the existing base-table
(LOADED) and import-report (`[IMPORT_REPORT]`) passes and BEFORE the shared `SWEEP_UNACCOUNTED`:

### Mechanism 1 — SAME-FBDI parent/child cascade (§5 "Cascade to children" + the `[FUSION_ERROR]` tag rule)

Within ONE FBDI (same object: header→line→loc→dist; or Customers Parties→Party Sites→Party
Site Uses and Accounts→Account Sites→Account Site Uses), when a directly-linked PARENT (or child)
record is `FAILED` **with a real Fusion error string**, propagate THAT EXACT Fusion error onto
the still-unaccounted child, tagged with the source record's key.

The §5 `[FUSION_ERROR]` tag rule (PROPOSED 2026-07-21, quoted from `DMT_DESIGN.html`) permits
exactly one composed form for a related-record failure:

> `'[FUSION_ERROR]The parent/child record has the following Fusion error: ' || l_related_fusion_error`

If the linked record has NO real Fusion error, the child STAYS unaccounted — we never compose a
generic "parent failed" sentence. This is the ONLY case where a record's error originates from
another record.

**This resolves Customers run-240 G1 site uses.** The parent party site `10121RT-PSITE-G1` is
`W`/`E` at the interface (a real interface-recorded outcome). Once the parent party site is
marked FAILED with its real interface finding (Mechanism 2 below applied to the parent), its two
child site uses (`10121RT-PSITE-G1/BILL_TO`, `10121RT-PSITE-G1/INVALID_USE`) inherit that exact
error via the cascade. The Projects reconciler already implements this cascade
(`dmt_project_results_pkg.pkb` lines ~606–708, project→task/team/txncontrol); Customers needs the
same parent→child cascade added for the HZ hierarchy.

### Mechanism 2 — TWO-LOCATION error read (owner directive; §5 resolution steps 2 and 3)

For rows STILL unaccounted after base-table + import-report + Mechanism-1 cascade, read the row's
OWN Fusion INTERFACE record status/error. If BOTH a report error and an interface error exist,
concatenate them; write the real error(s) to the TFM row. Tag each source: `[IMPORT_REPORT]`
(report) and `[INTERFACE_ERROR]` (interface record). Only write outcomes Fusion actually recorded.

**This resolves Projects task `NOPROJ999.1`** (parent project `10122NOPROJ999` is not in the load
at all, so there is no parent record to cascade from). Its own interface row in
`PJF_PROJ_ELEMENTS_XFACE` carries `IMPORT_STATUS='SUBMITTED'` — loaded to the interface but never
imported. That status is the real, Fusion-recorded outcome to report.

**This resolves Customers run-240 G2/G3 site uses** (loaded parent party sites, so no
cascade fires): their OWN interface rows show `IMPORT_STATUS_CODE='S'` (created). Read from the
interface, they are LOADED (see open question 4 on whether `S` alone, with no base id, suffices).

### 3a. Per-object, inside each reconciler's `PARSE_AND_UPDATE`, before the shared sweep

The interface key and columns differ per object, so the read cannot be one generic SQL. But the
**shape** is identical and belongs in one shared helper for the write, keeping each object's SQL
minimal. Concretely:

1. Each reconciler keeps its existing base-tier (LOADED) and report-error passes unchanged.
2. **New pass, added at the END of `PARSE_AND_UPDATE`, over rows still `GENERATED` for this run:**
   for each still-unaccounted TFM row, read that record type's Fusion INTERFACE row (by the
   tie-back key in the table above) via the object's BIP reconciliation data model, and take its
   per-row status/error. This uses the SAME deployed BIP data model as the base/report tiers —
   the working read path on this pod — not ad-hoc queries.
3. **Concatenate report + interface.** If the import report already wrote an error onto this TFM
   row (the row is already `FAILED` with an `[IMPORT_REPORT]` tag) AND the interface record also
   carries a status/error, append the interface finding to the existing `ERROR_TEXT` via the
   shared append helper — never overwrite (design rule: `ERROR_TEXT` is append-only). If only the
   interface carries something, write just that. Tag each source so the origin is auditable:
   `[IMPORT_REPORT] …` (from the report) and `[INTERFACE_ERROR] …` (from the interface record).
   A base-confirmed created row (`S`/`P`) still flips to `LOADED`, not `FAILED`.
4. Set the row `FAILED` when the interface status is a not-created status (`E`, `W`, `SUBMITTED`,
   `N`, `R`, or anything that is not the object's success value) — because a not-created record is
   a real, Fusion-recorded non-load, which is a reportable outcome, not an absence. Set it
   `LOADED` when the interface status is the success value AND (for objects where the base tier
   cannot see the row, like the NULL-ref site uses) there is no contradicting base miss.
5. Anything the interface ALSO cannot explain stays `GENERATED` and the existing shared
   `SWEEP_UNACCOUNTED` marks it `[UNACCOUNTED]`. We never fabricate.

### 3b. The shared write helper (new)

Add one procedure to `DMT_UTIL_PKG` (or a small new `DMT_RECON_UTIL_PKG`) that every reconciler
calls per record type, so the concatenate-and-write logic is written once:

```
PROCEDURE APPLY_INTERFACE_OUTCOME (
    p_run_id        IN NUMBER,
    p_tfm_table     IN VARCHAR2,   -- catalog-checked identifier
    p_key_column    IN VARCHAR2,   -- catalog-checked identifier (or key expression)
    p_key_value     IN VARCHAR2,
    p_status        IN VARCHAR2,   -- the interface per-row status (E/W/S/P/SUBMITTED/...)
    p_success_codes IN VARCHAR2,   -- comma list of success statuses for this object
    p_message       IN VARCHAR2    -- null-safe; interface error/message text if any
);
```

It flips the matching still-`GENERATED` TFM row to `LOADED` (success status) or `FAILED`
(anything else), and on `FAILED` appends `'[INTERFACE_ERROR] interface status ''<status>'''
|| p_message` via `APPEND_ERROR`. It guards on `TFM_STATUS NOT IN ('LOADED','FAILED')` for the
LOADED path but, for the concatenation case, a row already `FAILED` by the import report must
still get the interface text appended — so the FAILED path appends unconditionally when the
existing status is `FAILED` and the source tag is not already present. It stays inside the
sanctioned dynamic-SQL site: table/column names come only from the seeded catalog and are
identifier-checked; every value is bound. NO COMMIT.

**Why a shared helper and not fully generic:** the READ (which interface table, which key, which
status column) is genuinely object-specific and lives in each object's deployed BIP data model
(already true today). The WRITE (concatenate + tag + flip) is identical and is the part worth
centralizing.

### 3c. Preferred implementation: extend the existing BIP data models, not new SQL in PL/SQL

Because ad-hoc PL/SQL cannot reach Fusion tables (the DB has no Fusion link — the BIP report is
the transport), the interface read must be a **column returned by the object's reconciliation
data model**. Two of the three are already most of the way there:

- **Customers:** `DMT_CUST_RECON_V2_DM.xdm` already returns a per-row interface tier for all
  seven record types keyed correctly (parent-ref + use-type for site uses). It just needs to be
  **deployed** (versioned, never overwritten) and the reconciler's error branches — which already
  exist — need the `[INTERFACE_ERROR]` tag and the concatenation-with-report behavior. Smallest
  change of the three.
- **Projects:** the `PROJECT_DM.xdm` already returns `IMPORT_STATUS`/`LOAD_STATUS` per interface
  row for all four record types. The reconciler currently only marks a project FAILED from the
  interface when a real report `error_msg` is present, and leaves tasks/team/txn interface
  statuses unused (they fall to the sweep). The change: when a row is still GENERATED and its
  interface `IMPORT_STATUS` is a not-created status (e.g. `SUBMITTED`), mark it FAILED with an
  `[INTERFACE_ERROR] interface status 'SUBMITTED' — loaded to the interface but not imported`
  message, concatenating with any report error already present.
- **Expenditures:** `EXPENDITURE_DM.xdm` already returns `TRANSACTION_STATUS_CODE` per interface
  row. Same change: a still-GENERATED row whose interface status is not `P` becomes FAILED with
  the `[INTERFACE_ERROR]` status message. NOTE: the Expenditures reconciler is on the OLD pattern
  (private `bip_soap_post`, `echo_to_stg` write-back-to-staging) — modernizing it to the shared
  transport is a larger, separate change; this draft adds the interface-status FAILED branch
  within the existing structure and flags the modernization as a follow-up.

---

## 4. The exact TFM update (concatenation)

For a row already FAILED by the import report AND also carrying an interface status:

```sql
UPDATE <tfm_table>
SET    ERROR_TEXT = DMT_UTIL_PKG.APPEND_ERROR(ERROR_TEXT,
           '[INTERFACE_ERROR] interface status ''' || :status || '''' ||
           CASE WHEN :message IS NOT NULL THEN ' — ' || :message END),
       RESULTS_UPDATED_DATE = SYSDATE, LAST_UPDATED_DATE = SYSDATE
WHERE  RUN_ID = :run_id AND <key_column> = :key_value
AND    TFM_STATUS = 'FAILED';
```

For a still-GENERATED row whose only outcome is the interface status:

```sql
UPDATE <tfm_table>
SET    TFM_STATUS = 'FAILED',
       ERROR_TEXT = DMT_UTIL_PKG.APPEND_ERROR(ERROR_TEXT,
           '[INTERFACE_ERROR] interface status ''' || :status || '''' ||
           CASE WHEN :message IS NOT NULL THEN ' — ' || :message END),
       RESULTS_UPDATED_DATE = SYSDATE, LAST_UPDATED_DATE = SYSDATE
WHERE  RUN_ID = :run_id AND <key_column> = :key_value
AND    TFM_STATUS = 'GENERATED';
```

`APPEND_ERROR` guarantees append-only accumulation, so a report `[IMPORT_REPORT]` error and the
`[INTERFACE_ERROR]` finding end up concatenated in one `ERROR_TEXT`, each tagged with its source.

---

## 5. Tag vocabulary (add one)

Existing tags in use: `[FUSION_ERROR]`, `[IMPORT_REPORT]`, `[RECONCILE_ERROR]` (retiring),
`[UNACCOUNTED]`. **New:** `[INTERFACE_ERROR]` — a real, Fusion-recorded per-row interface status
or error that is not in the import report and not a base-table row. It is proposed for the
coding-standards error-tag table in `docs/DMT_DESIGN.html` (in RED, PROPOSED, per the tranche
rule) — the owner promotes it to accepted.

---

## 6. Open questions for the owner

1. **Local vs live.** The local Docker DB has no Fusion, so this enhancement can only be
   proven on the live demo pod. The three data-model changes must be **deployed** (versioned,
   never overwritten) before a live re-run. Do you want all three deployed together, or Customers
   first (smallest, closest to done)?
2. **`SUBMITTED` interpretation for tasks.** A task with `IMPORT_STATUS='SUBMITTED'` loaded to the
   interface but was never imported (parent project absent). Its interface table has no message
   column. Is "loaded to the interface but not imported — interface status SUBMITTED; parent
   project not loaded" the right FAILED message, or do you want the orphan-task inference from
   `run234_Projects.md` (naming the missing parent) instead of/as well as the raw status?
3. **`W` (held) is not a rejection.** For Customers, `W` = held for CDM potential-duplicate review
   — the record is neither created nor rejected; a human may still approve it. Marking it FAILED
   makes the object accountable, but is FAILED the right terminal state for a held row, or do you
   want a distinct non-terminal marker? (Today the only non-`LOADED` accountable state is FAILED.)
4. **The two `S` (created) site uses with no base reference.** G2/G3 site uses show interface
   status `S` (created) but never registered in `HZ_ORIG_SYS_REFERENCES`, so the base tier cannot
   see them. Is it acceptable to mark them `LOADED` from the interface `S` status alone (no base
   id captured, `FUSION_PARTY_SITE_USE_ID` stays NULL), or must a base id be captured before
   LOADED? The forward-fix (transformer populates `SITEUSE_ORIG_SYSTEM_REF` so TCA registers them)
   is already deferred in `objects/Customers/README.md`.
5. **Expenditures modernization.** The Expenditures reconciler is on the old pattern (private
   `bip_soap_post`, write-back-to-staging). Should modernization ride along with this change or
   stay a separate branch? This draft keeps it separate and only adds the interface-status branch.
