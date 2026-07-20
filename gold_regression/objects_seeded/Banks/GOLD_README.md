# Banks — gold regression fixture (REST) — v2 seeded

This is the **v2 (hard-coded seeded references, no discovery)** version of the Banks
fixture. It is functionally identical to the frozen v1 fixture in `../../objects/Banks/`,
except the two references that v1 discovered at load time are now written as **literals**
in the payload templates, and the recipe's `discovery` block is deleted.

Same as v1: a standalone **REST** fixture for Cash Management that creates a fresh
three-level chain — **Bank -> Branch -> Account** — directly in Oracle Fusion via the Cash
Management REST resources, plus one deliberately-bad bank that the API rejects and never
creates. Read-only BIP verification confirms the good rows reached the base tables and the
bad row is absent. No DMT tool code and no DMT database are in the load path.

## What changed from v1 (the only difference)

v1 discovered two references on the target pod at load time:

- `${LEGAL_ENTITY}` — a US legal entity from `XLE_ENTITY_PROFILES` (required for the account).
- `${CURRENCY}` — confirmed `USD` was enabled in `FND_CURRENCIES`.

v2 replaces both with the literal values v1's discovery resolved to on this pod:

| Token (v1) | Literal (v2) | Confirmed seeded (read-only BIP) |
|---|---|---|
| `${LEGAL_ENTITY}` | `US INS Legal Entity` | Present in `XLE_ENTITY_PROFILES`, carries no prefix — standard seeded demo data. |
| `${CURRENCY}` | `USD` | `enabled_flag='Y'` in `FND_CURRENCIES`. |

Both are standard seeded demo data (not records we loaded), so hard-coding is safe and
portable across any `fa-esew-devN-saasfademo1` demo pod. The recipe's `discovery` block is
removed; `discover.run_discovery()` on a recipe with no block returns `{}`, so the existing
`load_rest.py` runs unchanged.

**Unchanged from v1:**
- `${PREFIX}` still stamps the bank/branch/account **names and numbers** on every run.
- `${ROUTING1}` / `${ROUTING2}` are still **computed** from the prefix (valid ABA routing
  numbers with correct check digit — `load_rest.py` `_aba_routing`), never discovered.
- `United States` (country) is still a literal (Fusion-shipped territory on every pod).
- The bad row still sends `CountryName="Nowhereland"` → HTTP 400, creates nothing.

## The three REST resources (credential role `fin_impl`)

| # | Level | Method + path | Links to parent by | Returns |
|---|---|---|---|---|
| 1 | Bank | `POST /fscmRestApi/resources/11.13.18.05/cashBanks` | (top level) | `BankPartyId` |
| 2 | Branch | `POST /fscmRestApi/resources/11.13.18.05/cashBankBranches` | `BankName` | `BranchPartyId` |
| 3 | Account | `POST /fscmRestApi/resources/11.13.18.05/cashBankAccounts` | `BankName` + `BankBranchName` | `BankAccountId` |

Order matters: a branch is only POSTed after its bank returns 201; an account only after its
branch returns 201. The chain is entirely internal to this fixture (fresh `${PREFIX}` names),
so it is not a dependency on any prior load. The only external references are the seeded legal
entity and currency, now hard-coded.

## The good/bad rows

| Row | Level | Key (name) | Purpose |
|---|---|---|---|
| GOOD-1 | Bank | `DMT Gold Bank ${PREFIX}-1` | → CE_BANKS_V |
| GOOD-2 | Bank | `DMT Gold Bank ${PREFIX}-2` | → CE_BANKS_V |
| GOOD | Branch | `DMT Gold Branch ${PREFIX}-1` (under BANK1) | → CE_BANK_BRANCHES_V |
| GOOD | Branch | `DMT Gold Branch ${PREFIX}-2` (under BANK2) | → CE_BANK_BRANCHES_V |
| GOOD | Account | `DMT Gold Account ${PREFIX}-1` (under BRANCH1) | → CE_BANK_ACCOUNTS |
| BAD | Bank | `DMT Gold Bank ${PREFIX}-BAD` | invalid `CountryName="Nowhereland"` → HTTP 400, creates nothing |

**Bad-row proof (`bad_proof_is_absence`):** the bad bank sends an invalid country name.
Fusion rejects the POST with HTTP 400 `The value of the attribute Country isn't valid.` A
rejected `cashBanks` POST is atomic — no party is created — so the bad key is absent from
CE_BANKS_V. That absence, alongside the good banks from the same run reaching the base with
real ids, is the bad-row proof.

## How to run it (v2 path)

`run_object.py` handles FBDI and HDL only; Banks is REST, so it runs through the same
standalone modules v1 used — `load_rest.py` then `verify_rest.py` — with the one env var that
points the harness at the v2 tree:

```bash
cd gold_regression/harness
export GOLD_OBJECTS_SUBDIR=objects_seeded
python load_rest.py   Banks --prefix <PREFIX> > banks_load.json   # POST bank/branch/account
python verify_rest.py Banks <PREFIX> --load-json banks_load.json  # read-only base verify
```

`GOLD_OBJECTS_SUBDIR=objects_seeded` makes `recipe.py` read/write `objects_seeded/Banks/`.
`verify_rest.py` re-reads the three base tables by prefix and reports `"pass": true` when all
good rows are present with real ids and the bad key is absent.

## Verification (read-only, direct single-table base reads)

- **Banks → base.** `SELECT bank_name, MAX(bank_party_id) FROM ce_banks_v WHERE bank_name LIKE 'DMT Gold Bank <prefix>-%' GROUP BY bank_name`.
- **Branches → base.** `... FROM ce_bank_branches_v WHERE bank_branch_name LIKE 'DMT Gold Branch <prefix>-%' ...` (id `BRANCH_PARTY_ID`).
- **Accounts → base.** `... FROM ce_bank_accounts WHERE bank_account_name LIKE 'DMT Gold Account <prefix>-%' ...` (id `BANK_ACCOUNT_ID`).
- **Bad → absent.** The same `ce_banks_v` read must return no row for `DMT Gold Bank <prefix>-BAD`; the load result carries its HTTP 400 error text.

## Live evidence

**2026-07-20 — v2 seeded — LIVE-PROVEN. PASS.**

Standalone REST load path only; verification via the read-only BIP relay only.
Pod `fa-esew-dev28-saasfademo1`. Credential role/user `fin_impl`. No discovery — legal
entity and currency hard-coded as literals.

| Field | Value |
|---|---|
| Date | 2026-07-20 (UTC) |
| Prefix | `93574` (also loaded live at `92271`) |
| Seeded legal entity (literal) | `US INS Legal Entity` |
| Seeded currency (literal) | `USD` |
| Computed routing numbers | `${ROUTING1}=935740012`, `${ROUTING2}=935740025` |
| Load summary | banks 2 ok / 1 err · branches 2 ok · accounts 1 ok |

**Good rows → base tables:**

| Level | Name | Base table | Fusion id |
|---|---|---|---|
| Bank | `DMT Gold Bank 93574-1` | CE_BANKS_V | `300000331550392` (BankPartyId) |
| Bank | `DMT Gold Bank 93574-2` | CE_BANKS_V | `300000331550397` |
| Branch | `DMT Gold Branch 93574-1` | CE_BANK_BRANCHES_V | `300000331550402` (BranchPartyId) |
| Branch | `DMT Gold Branch 93574-2` | CE_BANK_BRANCHES_V | `300000331550413` |
| Account | `DMT Gold Account 93574-1` | CE_BANK_ACCOUNTS | `300000331550423` (BankAccountId) |

**Bad row → rejected, absent from base:**

| Name | HTTP | Error detail | In CE_BANKS_V? |
|---|---|---|---|
| `DMT Gold Bank 93574-BAD` | 400 | `The value of the attribute Country isn't valid.` | No (absent) |

`verify_rest.py Banks 93574` reported `"pass": true`.
