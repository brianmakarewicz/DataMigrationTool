# db_full — Complete DMT_OWNER Schema Install

This folder is a **complete, self-contained snapshot of the live ATP (queryapp)
`DMT_OWNER` schema**, captured with `DBMS_METADATA` + dictionary queries. It exists
because the piecemeal `db/install.sql` only enrolled a handful of objects and git
no longer fully described the live schema (P1). Once the compare report is clean
and reviewed, **this folder replaces `db/install.sql` as the deploy path**.

## Layout

| Path | Contents |
|---|---|
| `install.sql` | Master install — runs everything in dependency order. Re-runnable. |
| `tables/` | One file per table: guarded `CREATE TABLE` + non-constraint indexes + comments. `_foreign_keys.sql` applies all FKs after all tables exist. |
| `sequences/` | One file per sequence (identity `ISEQ$$` sequences excluded — created with their tables). |
| `views/` | One file per view, `CREATE OR REPLACE FORCE`, emitted in dependency order in `install.sql`. |
| `packages/` | `*.pks.sql` specs (dependency-ordered) and `*.pkb.sql` bodies. |
| `procedures/`, `functions/`, `types/`, `triggers/`, `synonyms/`, `mviews/` | Per-object files (folders may be empty if the schema has none). |
| `jobs/` | DBMS_SCHEDULER jobs (guarded create-if-missing). |
| `grants/` | `grants_made.sql` (grants DMT_OWNER makes; errors tolerated — grantees may not exist locally). `grants_received_reference.sql` is documentation of privileges DMT_OWNER needs *granted to it* (run equivalents as the grantor/admin on a new instance). |
| `seed/` | INSERT scripts for pipeline control tables (`DMT_CEMLI_SPLIT_CFG`, `DMT_BIP_REPORT_TBL`, `DMT_ERP_INTERFACE_OPTIONS_TBL`, `DMT_REST_LOOKUP_TBL`, `DMT_CONFIG_TBL`). Idempotent (duplicate keys skipped). **All credential-like values are masked as `***MASKED-SET-ME***`** — set them post-install. |
| `tools/snapshot_atp.py` | Regenerates this entire folder from the live ATP schema (READ-ONLY against ATP). |
| `tools/local_db_setup.sql` | One-time local-Docker admin step: creates the `DMT_OWNER` user (run as SYSTEM **locally only, never on ATP**). |
| `tools/build_local_db.sh` | Stands up the Docker Oracle Free container and runs the full install. |
| `tools/compare_schemas.py` | Dictionary-level diff ATP vs local Docker → `COMPARE_REPORT.md`. |
| `COMPARE_REPORT.md` | Latest verification result. |

## How it was generated

```
python db_full/tools/snapshot_atp.py
```

Read-only against ATP (`SELECT` + `DBMS_METADATA.GET_DDL`). Transform settings:
`SEGMENT_ATTRIBUTES/STORAGE/TABLESPACE = FALSE` (portable DDL — ATP storage
clauses don't apply to Oracle Free), `REF_CONSTRAINTS = FALSE` (FKs emitted
separately so table order doesn't matter), `EMIT_SCHEMA = FALSE`.

### Known intentional deviations from raw ATP DDL
- Storage / tablespace / segment clauses stripped (portability).
- FK constraints applied in `tables/_foreign_keys.sql` after all tables.
- Views forced to `CREATE OR REPLACE FORCE` so objects referencing packages
  or DB links still create (they recompile at the end).
- Seed credential values masked.
- Sequences carry the `START WITH` current to the snapshot date.

## Rebuild the local test database from scratch

Prereqs: Docker Desktop running, SQLcl at `/c/Users/Monroe/tools/sqlcl/bin`.

```
sh db_full/tools/build_local_db.sh --fresh
```

This: runs `container-registry.oracle.com/database/free` as container `dmt-local`
(port 1521), waits for readiness, creates `DMT_OWNER` (the only admin step),
then runs `install.sql` **as DMT_OWNER**. Local passwords are throwaways
(`ORA_PWD` / `DMT_LOCAL_PWD` env vars to override).

## Verify (compare) against ATP

```
python db_full/tools/compare_schemas.py
```

Compares object inventory, table columns (type/length/nullability), constraints,
indexes, and normalized source/view-text hashes. Writes `COMPARE_REPORT.md`.
ATP is opened read-only via `conn_helper.connect_atp('queryapp','DMT_OWNER')`.

### Expected residual differences
- Objects depending on the `ATP_LINK` DB link (EBS extractors) and on
  Fusion-side/APEX grants are INVALID locally — listed with reasons in the report.
- `grants_made.sql` grantees that don't exist locally are skipped.

## Adoption plan
1. Keep `db/`, `schema/`, `packages/` untouched until the compare is clean.
2. Review `COMPARE_REPORT.md`; every diff must be either fixed or explained.
3. Switch deploys to `@db_full/install.sql`; retire `db/install.sql`.
4. Future object changes: edit the per-object file in `db_full/` and redeploy
   through `install.sql` (same converge-to-git discipline as before).
