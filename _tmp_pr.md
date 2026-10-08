## What
Owner decision 2026-10-08: "if something never passed before, I don't want to hold everything up." Implemented narrowly in the ATP promotion gate.

- `scripts/regression_known_review.json` (new): the 11 pre-existing, never-passed review items that full regression run 300 still reports on main after the REST lookup fix (#669): 9 HCM objects DONE with zero records (HCM backlog #292/#293), REST_VERIFY BillingEvents/Billing Events (#462, fin_impl 403) and REST_VERIFY Customers/Locations (#468). Matched on category + object (+ sub) only, never prefixes, keys or HTTP detail. Each entry carries backlog + reason.
- `scripts/dmt_regression_run.py`: review items classified KNOWN or NEW (one helper block + the verdict block only, to keep rebases easy). Both groups printed; `known_review`, `new_review`, `known_review_cleared` added to `--json`. New verdict `PASS (known review items only)` with exit 0 when there are no failures and no NEW items. A listed item that no longer appears prints "KNOWN item cleared: ... remove it from regression_known_review.json" (non-blocking). Unreadable file means every item is NEW (fails closed).
- `scripts/ci_promote.py` / `scripts/promotion_gate.py`: accept the new verdict (still requires exit 0); record known/new counts in evidence and in the promotion-log gate events. No bypass flag added; `--owner-override` untouched; nothing else loosened.
- Docs: new ATP Promotion Gate section in `docs/DMT_DESIGN.html` (red, added), `.claude/skills/deploy-dmt2-atp/SKILL.md`, `docs/status.md`.

## Tests
- `python scripts/dmt_regression_run.py --status-only 300 --json <tmp>` on local Docker: `VERDICT: PASS (known review items only)`, exit 0, 11 known / 0 new / 0 cleared.
- `test/unit/test_regression_known_review.py` (new, offline): 11 known / 0 new; volatile detail still matches; unlisted items (incl. Assets/Asset Books, Customers/Parties) are NEW. 5/5.
- `test/unit/test_promotion_gate.py`: two new scenarios (known-only verdict with exit 2 refused; with exit 0 accepted). 23/23.
- No deploy, no pipeline run submitted.

🤖 Generated with [Claude Code](https://claude.com/claude-code)

https://claude.ai/code/session_01U8b9oVmN9YXxfmmB65XjHx
