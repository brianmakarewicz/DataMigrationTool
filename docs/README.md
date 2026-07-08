# DMT2 docs

**The requirements document lives HERE and only here:** `docs/DMT_DESIGN.html`
(moved into this repo 2026-07-08 by user decision so every consumer — the automated
PR reviewer, blind tranche reviewers, humans — reads the same file from the checkout).
Changes to it arrive as pull requests like everything else. Its coding-standards
section uses the red-text convention: red = proposed/unverified, promoted to normal
styling only by the owner.

A claude.ai artifact mirrors it for reading:
https://claude.ai/code/artifact/4cb4cb91-8a81-462d-9d6d-42c51e8d28e9
The artifact is a RENDERING, never the master — it is republished automatically
(via a local hook) whenever the master changes.

**The rebuild plan also lives here:** `docs/DMT_REBUILD_PLAN.html` (phases, build
order, roadmap, risks, execution status).

Old locations (ConversionTool-dbfull/docs/ and the data-migration-tool project root)
now hold pointer stubs only. Never create another copy of either document.

Also local: DMT_OBJECT_CATALOG.html (naming worklist snapshot), coding-standards.md
(mirror), tranche-reviews/ (blind review logs).
