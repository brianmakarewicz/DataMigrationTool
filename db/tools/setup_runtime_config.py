#!/usr/bin/env python
# ============================================================
# setup_runtime_config.py  --  POST-INSTALL runtime config.
#
# A fresh `build_local_db.sh --fresh` builds the full schema but leaves
# three things unset, because they are secrets / environment-specific and
# must never be committed:
#
#   1. Global Fusion password   DMT_CONFIG_TBL.FUSION_PASSWORD
#                               (comes up as ***MASKED-SET-ME***)
#   2. Per-object credential     DMT_ERP_INTERFACE_OPTIONS_TBL.FUSION_PASSWORD
#      overrides                 (one row per object with a FUSION_USERNAME;
#                               all come up masked the same way)
#   3. Outbound network ACL      DMT_OWNER's ACL to the Fusion host, created
#                               as a side effect of DMT_UTIL_PKG.SET_FUSION_URL
#                               (without it the first live call raises
#                               ORA-24247 network access denied by ACL)
#
# Until all three are set, every live Fusion call (BIP deploy, ESS submit,
# reconcile, credential preflight) fails. This script performs all three
# from the single source of truth for credentials, ~/workspace/connections.json.
#
# Passwords are matched per user: the global password is the FUSION_USERNAME
# config user's password; each override row's password is looked up by its
# FUSION_USERNAME (case-insensitive) in connections.json. That way it stays
# correct even if the demo users ever stop sharing one password.
#
# Usage:  python db/tools/setup_runtime_config.py
# Env:    DMT2_CONN       DMT_OWNER connection (default dmt2-local)
#         CONNECTIONS_JSON path to connections.json (default ~/workspace)
# ============================================================
import json
import os
import re
import sys

import oracledb

DEFAULT_CONN = "dmt_owner/DmtLocal#2026@localhost:1523/FREEPDB1"
DEFAULT_CONNECTIONS = os.path.expanduser(
    os.environ.get("CONNECTIONS_JSON", r"C:\Users\Monroe\workspace\connections.json"))
FUSION_KEY = "demo_fusion_cloud_esewdev28"


def db_connect():
    conn_str = os.environ.get("DMT2_CONN", DEFAULT_CONN)
    m = re.match(r"^([^/]+)/(.+)@(?://)?(.+)$", conn_str)
    if not m:
        sys.exit(f"Cannot parse DMT2_CONN: {conn_str!r}")
    user, password, dsn = m.groups()
    return oracledb.connect(user=user, password=password, dsn=dsn)


def load_passwords():
    """user (lower) -> password, keyed by both the json key and the username field."""
    with open(DEFAULT_CONNECTIONS, encoding="utf-8") as f:
        cfg = json.load(f)
    users = cfg[FUSION_KEY]["users"]
    pw = {}
    for key, v in users.items():
        p = v.get("password")
        if not p:
            continue
        pw[key.lower()] = p
        if v.get("username"):
            pw[v["username"].lower()] = p
    return pw


def main():
    pw_by_user = load_passwords()
    conn = db_connect()
    cur = conn.cursor()

    # (1) Global credential config keys. Each *_PASSWORD is set from its own
    #     *_USERNAME user's password. FUSION_* is the pipeline/ESS credential;
    #     BIP_* is what the shared RUN_BIP_REPORT (Contract-v1 reconcilers) uses
    #     -- it falls back to FUSION_* only when BIP_* is null, so a masked
    #     BIP_PASSWORD makes every Contract-v1 reconcile fail with HTTP 500 even
    #     when FUSION_PASSWORD is correct. Both must be set.
    for pw_key, user_key, default_user in (
        ("FUSION_PASSWORD", "FUSION_USERNAME", "fin_impl"),
        ("BIP_PASSWORD",    "BIP_USERNAME",    "fin_impl"),
    ):
        # Only touch the password key if it exists (BIP_* may be absent on some installs).
        cur.execute("SELECT COUNT(*) FROM DMT_CONFIG_TBL WHERE config_key=:k", k=pw_key)
        if cur.fetchone()[0] == 0:
            print(f"[1] {pw_key} not present -- skipped")
            continue
        cur.execute("SELECT config_value FROM DMT_CONFIG_TBL WHERE config_key=:k", k=user_key)
        row = cur.fetchone()
        guser = (row[0] if row and row[0] else default_user).lower()
        gpw = pw_by_user.get(guser)
        if not gpw:
            sys.exit(f"No password in connections.json for {user_key} user {guser!r}")
        cur.execute("UPDATE DMT_CONFIG_TBL SET config_value=:p WHERE config_key=:k", p=gpw, k=pw_key)
        print(f"[1] {pw_key} set for user {guser} ({cur.rowcount} row)")

    # (2) Per-object credential overrides, matched by each row's FUSION_USERNAME.
    cur.execute("SELECT cemli_code, fusion_username FROM DMT_ERP_INTERFACE_OPTIONS_TBL "
                "WHERE fusion_username IS NOT NULL")
    overrides = cur.fetchall()
    set_cnt = miss = 0
    for cemli, uname in overrides:
        p = pw_by_user.get((uname or "").lower())
        if not p:
            print(f"    WARN no password for override user {uname!r} (CEMLI {cemli}) -- left as is")
            miss += 1
            continue
        cur.execute("UPDATE DMT_ERP_INTERFACE_OPTIONS_TBL SET fusion_password=:p "
                    "WHERE cemli_code=:c", p=p, c=cemli)
        set_cnt += 1
    print(f"[2] per-object credential overrides set: {set_cnt} ({miss} unmatched)")

    # (3) Network ACL to the Fusion host, via SET_FUSION_URL (idempotent).
    cur.execute("SELECT config_value FROM DMT_CONFIG_TBL WHERE config_key='FUSION_URL'")
    row = cur.fetchone()
    fusion_url = row[0] if row else None
    if not fusion_url:
        sys.exit("FUSION_URL is not set in DMT_CONFIG_TBL -- cannot create the ACL.")
    cur.callproc("DMT_UTIL_PKG.SET_FUSION_URL", [fusion_url])
    print(f"[3] network ACL created/refreshed for {fusion_url}")

    conn.commit()
    cur.close()
    conn.close()
    print("=== runtime config complete ===")


if __name__ == "__main__":
    main()
