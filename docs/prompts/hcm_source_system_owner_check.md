# Prompt for Claude Desktop: HCM source system owner lookup

Copy everything below the line into Claude Desktop.

---

I need you to check, and optionally set up, one lookup in our Oracle Fusion demo pod using the browser. Log in yourself; I'll sign in when the login page appears. Never type, store or repeat a password.

**Fusion URL:** https://fa-esew-dev28-saasfademo1.ds-fa.oraclepdemos.com

**Background:** we load HCM data with HCM Data Loader (HDL). Every HDL record is identified by a pair: SourceSystemOwner plus SourceSystemId. Today every load uses Oracle's default owner, `HRC_SQLLOADER`. We want two of our own owners instead, `DMT_LOCAL` and `DMT_ATP`, so the same SourceSystemId coming from our two databases can never collide. My understanding is that a custom owner must first exist as a value in the lookup type `HRC_SOURCE_SYSTEM_OWNER`.

**Step 1: check (read-only).**
1. Go to Setup and Maintenance, then search for the task **Manage Common Lookups**. If that isn't found, try **Manage Standard Lookups**.
2. Search for lookup type `HRC_SOURCE_SYSTEM_OWNER`.
3. Report:
   - whether the lookup type exists, and its meaning, module and customization level;
   - every lookup code currently in it, with its meaning, enabled flag and dates. Is `HRC_SQLLOADER` there?
   - whether the page lets you add codes, meaning the type is user-extensible.
4. Take a screenshot of the lookup codes table.

**Step 2: add the two codes. Ask me before you click Save.**
If the lookup type exists and allows new codes, prepare these two rows:

| Lookup Code | Meaning | Description | Enabled | Start Date |
|---|---|---|---|---|
| DMT_LOCAL | DMT Local | Data Migration Tool, local Docker instance | Yes | today |
| DMT_ATP | DMT ATP | Data Migration Tool, ATP GOLD instance | Yes | today |

Show me a screenshot of the filled-in rows and wait for my "yes" before saving. After saving, re-query the lookup type and confirm that both codes show as enabled.

**Stop and report instead of improvising if:**
- the lookup type doesn't exist;
- it isn't extensible;
- you get a privilege error;
- the task names differ from those above.

In that case, tell me exactly what you saw, with the page title and the error text, and suggest where else Oracle documents setting up HDL source system owners. Do not change anything else in Fusion.

**Final report (short):**
- whether the lookup exists;
- the codes it had before and after;
- whether DMT_LOCAL and DMT_ATP are now enabled;
- any errors.
