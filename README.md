# DMT2 — Data Migration Tool (rebuild)

Oracle Fusion Cloud data migration tool: pure PL/SQL pipeline on Oracle DB (Docker-local now, ATP later),
FBDI/HDL/REST load to Fusion, BIP reconciliation, APEX UI.

Re-platform of the frozen ConversionTool repo, seeded from its proven full-schema install.
See CLAUDE.md for working rules and DMT_REBUILD_PLAN.html (project root of the old workspace) for the master plan.

Quick start (local DB): `sh db/tools/build_local_db.sh` → dmt2-local on port 1523.
