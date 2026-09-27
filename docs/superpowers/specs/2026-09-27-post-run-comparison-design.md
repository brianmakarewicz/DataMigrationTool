# Post-Run Comparison Report — Design

Date: 2026-09-27
Status: Draft for review
Repo: DataMigrationTool (DMT2)

## What this is

A new post-run report that, for **one pipeline run**, shows each object side by side
with three counts (and money sums where the object has money):

- **STG total** — records this run processed, from the staging table.
- **TFM errors** — records this run failed, from the transform table.
- **Fusion successes** — records that actually landed in Fusion, queried **live from
  Fusion**.

The report exists to prove one equation per object:

```
Fusion successes + TFM errors = STG total
```

When it does not tie out, the report shows the variance. That variance is the whole
point — it is the honest "what did we send, what stuck, what fell through" picture for a
run, backed by Fusion's own numbers rather than our internal status flags.

## Why it is separate from what already exists

DMT2 already has a post-run reporting layer, `DMT_RUN_SUMMARY_PKG` (backlog #66), with
`GET_RUN_ROLLUP`, `GET_RUN_RECORDS`, and `AUDIT_IN_FUSION`, all reading the per-record
view `DMT_RUN_RECORDS_V`. That layer is **row-by-row**: `AUDIT_IN_FUSION` re-runs each
object's per-record reconciliation report and matches Fusion base rows to our transform
rows one record at a time. It counts rows only — there is **no money anywhere** in it —
and it does not group by scenario or reconcile a Fusion count back to a staging count.

This new report is a **different process**:

- It is an **aggregate control-total** query, not a per-record match. It asks Fusion "how
  many, and for how much money, for this batch" — it does **not** fetch one Fusion row per
  record.
- It carries **money sums**, which the existing layer does not.
- It reconciles **Fusion successes + TFM errors against the STG total** for the run.

It reuses two existing assets: the BIP transport plumbing
(`DMT_RECON_CONTRACT_PKG` / `DMT_UTIL_PKG.RUN_BIP_REPORT`) and the registry that maps an
object to its BIP report path. It does **not** touch the existing recon layer.

## Scope

- **One run at a time.** Every number — STG total, TFM errors, Fusion successes — is
  scoped to a single pipeline run. A run belongs to one scenario, so the report is
  effectively "this scenario, this run."
- All three sources are expected to tie out within that one run. Any gap is surfaced as
  the variance.
- **How the STG side is scoped to one run is itself a discovery item.** Staging tables are
  normally scenario-scoped, not run-scoped, so "STG records this run processed" may have to
  be reached through the STG-to-TFM linkage (work-queue id / run id on the transform rows)
  rather than a column on STG. The exact STG query per object is settled in Phase 1.

## Hard rules

1. **Fusion successes MUST come from Fusion.** Never infer a success from our own TFM
   status. The success count and sum are whatever Fusion's base tables report for this
   batch.
2. **Never query Fusion by prefix.** The prefix is a test-harness device and is not a
   valid production approach. Fusion queries key off, in order of preference:
   1. **our stamped work-queue id** on the record in Fusion (preferred — most objects),
   2. else the **load id / import request id**,
   3. else the **Fusion interface tables**.
3. **Never fabricate a number.** If a Fusion query cannot be built for an object yet, that
   object is reported as "not yet provable," not as zero successes.
4. **Standard output shape.** Every per-object Fusion query returns the same columns, and
   the comparison grid has one fixed column set, so one framework drives all objects.

## The two standard column structures

### (a) Fusion aggregate report output — uniform across all objects

Each object has its **own** Fusion query (different base table, key, and amount column),
but every one returns the same shape so a single framework can consume any of them:

| Column | Meaning |
|---|---|
| `OBJECT_TYPE` | the object label |
| `KEY_TYPE` | which key path was used: `WORK_QUEUE_ID`, `LOAD_ID`, or `INTERFACE` |
| `SUCCESS_COUNT` | count of records confirmed in the Fusion base table for this batch |
| `SUCCESS_AMOUNT` | money sum for those records; NULL for objects with no money |
| `AMOUNT_CURRENCY` | currency of `SUCCESS_AMOUNT`; NULL when not applicable |

The report takes **one bind**: the key value (a work-queue id or a load id). It returns
**aggregates only** — at most a handful of rows (for example one per business unit),
**never one row per record**.

### (b) Comparison row — what each object package returns and the page shows

| Column | Meaning |
|---|---|
| `OBJECT_TYPE` | the object label |
| `STG_COUNT` | records this run processed (staging) |
| `STG_AMOUNT` | money sum of those staging records; NULL if no money |
| `TFM_ERROR_COUNT` | records this run failed (transform) |
| `TFM_ERROR_AMOUNT` | money sum of those failed records; NULL if no money |
| `FUSION_SUCCESS_COUNT` | from the Fusion aggregate report |
| `FUSION_SUCCESS_AMOUNT` | from the Fusion aggregate report; NULL if no money |
| `VARIANCE_COUNT` | `STG_COUNT - (FUSION_SUCCESS_COUNT + TFM_ERROR_COUNT)` |
| `VARIANCE_AMOUNT` | same arithmetic on the amounts; NULL if no money |
| `KEY_TYPE` | which Fusion key path was used |
| `IN_BALANCE` | `Y` when both variances are zero, else `N` |

## Per-object contract

Each object's package gets **one procedure with a uniform signature**, for example:

```
GET_RUN_COMPARISON(p_run_id IN NUMBER, x_cursor OUT SYS_REFCURSOR)
```

Inside, it performs exactly three queries and returns one comparison row (or, for
multi-BU objects, one per group):

1. **STG** — count and amount for the run, from that object's staging table.
2. **TFM error** — count and amount for the run, from that object's transform table.
3. **Fusion successes** — a **live** call to that object's Fusion aggregate report, keyed
   by the object's chosen key path.

A shared framework iterates the objects present in a run and calls each object's
procedure, using the **existing catalog-driven dispatch** — the same mechanism
reconciliation already uses. No new hardcoded per-object branches.

## Phase 1 — Manual discovery FIRST (no DB code until this is done)

This is a firm rule: **we prove every query by hand before any of it goes into a package.**

Deliverable: a **proven query matrix** — one row per object — recording:

- the exact **STG query** (count + amount column),
- the exact **TFM-error query** (count + amount column),
- the exact **Fusion success query**, with its **key path decided**
  (work-queue id / load id / interface) and its **amount column** identified,
- evidence that, run by hand against a real completed run, the three **tie out**
  (or a recorded, understood reason they do not).

Only objects with a proven row get built in Phase 2.

**Amount columns are chosen during this discovery**, per object — we do not assume them
up front.

**Proving set (first three):** Purchase Orders (money, multi-BU, work-queue-id path),
AP Invoices (money, likely load-id path), and GL Balances (money, different grain). Once
the pattern is proven on these three, roll it out to the remaining objects.

## Phase 2 — Build (only proven objects)

1. **Per-object Fusion aggregate BIP reports** — one per object, each returning the
   standard shape (a), deployed to `/Custom/DMT2/`. Version alongside existing reports,
   never overwrite.
2. **Per-object `GET_RUN_COMPARISON` procedures** — added to each object's package,
   doing the three proven queries.
3. **A shared framework** to iterate a run's objects and assemble the comparison grid,
   reusing existing catalog dispatch and BIP transport.
4. **One APEX page on app 501** (`LIVEDMT2`) — pick a run, see the comparison grid (one
   row per object), variances highlighted, totals row at the bottom. Built via APEXLang
   on local Docker (26.1), copy-before-modify.

## Timing

**Live on demand.** Opening the page for a run calls each object's procedure right then;
each makes its own live Fusion query. This is the simplest build and is always truthful.
Cost: one SOAP call per object at page-load, so the page is slower and re-queries Fusion
each time. If that proves too slow we revisit (see non-goals).

## Non-goals / future (structure must not preclude)

- **Prior-success comparison** — later, compare a run against the **most recent prior
  successful** load of the same object (the most recent success, not all successes).
- **Persisted snapshots / history** — storing each run's comparison for fast reads and
  trend history, if live-on-demand is too slow.
- **Cross-run / cross-scenario** side-by-side comparison.

None of these are built now. The uniform column shapes and per-object procedure signature
are chosen so they can be added without reshaping the core.

## Reused / touched components

- Reuse: `DMT_UTIL_PKG.RUN_BIP_REPORT` (BIP transport), the BIP report registry, the
  catalog-driven dispatch, app 501 (`LIVEDMT2`).
- New: one Fusion aggregate BIP report per proven object; a `GET_RUN_COMPARISON`
  procedure per proven object package; a shared assembly framework; one APEX page.
- Untouched: `DMT_RUN_SUMMARY_PKG`, `DMT_RUN_RECORDS_V`, and the per-record recon layer.
