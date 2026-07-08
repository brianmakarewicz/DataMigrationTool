# DMT2 docs

**The requirements/design document lives in ONE place only:**
`C:\Users\Monroe\workspace\data-migration-tool\ConversionTool-dbfull\docs\DMT_DESIGN.html`

Do NOT copy it into this repo — that forked the living document once already (2026-07-07/08).
Blind tranche reviewers and all build work read it from the path above. Proposed coding-standard
rules are added there in red per its change-review convention.

Local to this repo: DMT_OBJECT_CATALOG.html (naming worklist snapshot), coding-standards.md
(mirror, regenerate from the design doc on acceptance), tranche-reviews/ (blind review logs).

## Automated PR review
Every pull request is reviewed the moment it opens or updates, by the GitHub
Actions workflow `.github/workflows/pr-review.yml` running on GitHub's servers.
The review and approval post as brianmakarewicz (a review-only token); the merge
happens after approval. Approvals and change requests carry an AUTOMATED banner.
Reviews are independent of the PR author; merges require the review approval
per branch protection.
