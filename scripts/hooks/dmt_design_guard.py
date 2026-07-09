#!/usr/bin/env python
"""
Claude Code PreToolUse guard — enforces RED-by-default edits to the canonical
requirements doc (DMT_DESIGN.html).

Policy (requested by the owner 2026-07-09):
  * Any addition to DMT_DESIGN.html must be RED / PROPOSED — inline red styling
    using the doc's proposed-color #b42318 (e.g. <code style="color:#b42318">…</code>
    or a <span style="color:#b42318;font-weight:700">PROPOSED …</span> marker).
    Red = newly added, unverified; the owner promotes it to accepted (normal
    styling) later.
  * An ACCEPTED (non-red) change — promoting a red item to normal styling,
    editing existing accepted text, changing counts, or any full-file Write —
    requires the owner's explicit approval.

How the owner approves a change:
    touch <docs>/.design_change_approved     # sentinel next to the doc
  The sentinel authorizes exactly ONE edit and is consumed (deleted) when used.

Mechanics: reads the tool call JSON on stdin. If the target is DMT_DESIGN.html
and the edit is not red-only (and no approval sentinel is present), it BLOCKS
(exit 2, message on stderr). Red-only additions pass without approval.

HONEST LIMITATION (like dmt_db_guard): this is a guardrail, not a sandbox. An
edit that contains #b42318 anywhere in its new text is treated as a red addition,
so non-red content bundled alongside red is not caught, and the sentinel is a
plain file. It exists to force the red-first habit and make a non-red change a
deliberate, approved act — not to be tamper-proof.
"""
import sys, os, json

RED = "#b42318"          # the doc's PROPOSED / unverified color
SENTINEL = ".design_change_approved"
GUARDED = "DMT_DESIGN.html"


def main():
    try:
        data = json.load(sys.stdin)
    except Exception:
        sys.exit(0)  # can't parse -> don't interfere

    tool = data.get("tool_name", "") or ""
    ti = data.get("tool_input", {}) or {}
    fp = ti.get("file_path", "") or ""

    if os.path.basename(fp) != GUARDED:
        sys.exit(0)  # not the guarded doc

    # Collect the text this call would ADD, and whether it's a whole-file write.
    is_write = False
    if tool == "Write":
        added = ti.get("content", "") or ""
        is_write = True
    elif tool == "MultiEdit":
        added = "\n".join((e or {}).get("new_string", "") for e in ti.get("edits", []) or [])
    elif tool == "Edit":
        added = ti.get("new_string", "") or ""
    else:
        sys.exit(0)  # other tools (Read etc.) are fine

    sentinel = os.path.join(os.path.dirname(fp) or ".", SENTINEL)
    approved = os.path.exists(sentinel)

    # A red-only ADDITION (not a full-file write) is always allowed.
    red_only = (RED in added) and not is_write

    if approved:
        try:
            os.remove(sentinel)  # one-shot: consume the approval
        except OSError:
            pass
        sys.stderr.write("[design-guard] approved change — sentinel consumed; edit allowed.\n")
        sys.exit(0)

    if red_only:
        sys.exit(0)

    sys.stderr.write(
        "BLOCKED (requirements-doc policy): DMT_DESIGN.html changes must be RED / PROPOSED "
        "unless the owner has approved.\n"
        f"  - To PROPOSE: wrap the addition in the proposed-red color {RED} "
        "(e.g. style=\"color:#b42318\") with a PROPOSED marker + date. Red is auto-allowed.\n"
        "  - This edit is either non-red, a promotion of a red item to accepted, or a full-file "
        "rewrite — all of which need approval.\n"
        f"  - To APPROVE one change, the OWNER runs:  touch \"{sentinel}\"  then retry "
        "(the sentinel authorizes exactly one edit and is then consumed).\n"
        "Do not create the sentinel yourself unless the user has explicitly approved this change.\n"
    )
    sys.exit(2)  # block


if __name__ == "__main__":
    main()
