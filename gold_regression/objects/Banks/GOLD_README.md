# Banks — gold regression fixture (REST)

A standalone, reloadable **REST** fixture for Cash Management banks. It creates a
fresh three-level chain — **Bank → Branch → Account** — directly in Oracle Fusion
via the Cash Management REST resources, plus one deliberately-bad bank that the
API rejects and never creates. Read-only BIP verification confirms the good rows
reached the base tables and the bad row is absent. No DMT tool code and no DMT
database are in the load path.

This is the only REST object in the gold library, so it has its own load module
(`harness/load_rest.py`) and verifier (`harness/verify_rest.py`), both additive —
they do not touch the FBDI/HDL modules.

## Why REST (not FBDI/HDL)

Cash Management banks/branches/accounts have no FBDI import job; they are created
one record at a time through the Fusion REST API. The reference tool loader is
`db/packages/dmt_ce_bank_results_pkg.pkb.sql` (three sequential POST phases). This
fixture mirrors that flow in pure Python.

## The three REST resources (credential role `fin_impl`)

All three are Financials resources; Cash Management requires the `fin_impl` user.
Base URL comes from `connections.json` (`get_fusion_url()`), version `11.13.18.05`.

| # | Level | Method + path | Links to parent by | Returns |
|---|---|---|---|---|
| 1 | Bank | `POST /fscmRestApi/resources/11.13.18.05/cashBanks` | (top level) | `BankPartyId` |
| 2 | Branch | `POST /fscmRestApi/resources/11.13.18.05/cashBankBranches` | `BankName` | `BranchPartyId` |
| 3 | Account | `POST /fscmRestApi/resources/11.13.18.05/cashBankAccounts` | `BankName` + `BankBranchName` | `BankAccountId` |

Order matters: a branch is only POSTed after its bank returns 201; an account only
after its branch returns 201. The chain is entirely **internal to this fixture**
(fresh `${PREFIX}` names), so it is not a dependency on any prior load.

### Payloads (exact fields — verified against each resource's `/describe`)

**Bank** (`cashBanks`). Valid create attributes on this pod: `BankName` (mandatory),
`CountryName`, `BankNumber`, `Description`, `TaxpayerIdNumber`, `TaxRegistrationNumber`.
```json
{"CountryName":"United States","BankName":"DMT Gold Bank ${PREFIX}-1",
 "BankNumber":"${PREFIX}101","Description":"Gold regression bank ${PREFIX} one"}
```
> **Gotcha (fixed):** the reference tool payload sends `ShortBankName`, which this
> REST version rejects with HTTP 400 `Invalid attribute "ShortBankName" in the
> payload.` It is not a valid `cashBanks` attribute — omit it. (Logged for the
> tool: the PL/SQL loader should drop `ShortBankName` too.)

**Branch** (`cashBankBranches`). `BankBranchName` mandatory; links to the bank by
`BankName`; `BranchNumber` is the routing number for US branches.
```json
{"BankName":"DMT Gold Bank ${PREFIX}-1","BankBranchName":"DMT Gold Branch ${PREFIX}-1",
 "BranchNumber":"${ROUTING1}","CountryName":"United States",
 "EFTSWIFTCode":"DMTGUS${PREFIX}","Description":"Gold regression branch ${PREFIX} one"}
```
> **Gotcha (fixed):** a US branch `BranchNumber` is validated as an **ABA routing
> transit number** with a check-digit rule. An arbitrary number fails with HTTP
> 400 `You must enter a valid value for the Routing Number field. (CE-660076)`.
> The harness builds a valid 9-digit routing number from the prefix
> (`load_rest.py` `_aba_routing`): the check digit satisfies
> `3(d1+d4+d7)+7(d2+d5+d8)+(d3+d6+d9) ≡ 0 (mod 10)`. Tokens `${ROUTING1}` /
> `${ROUTING2}` are the two valid routing numbers, distinct per prefix so re-runs
> don't collide. (See MOS 1905241.1 / 1287647.1 for the CE-660076 validation.)

**Account** (`cashBankAccounts`). Mandatory: `BankAccountName`, `BankAccountNumber`,
`CurrencyCode`, **`LegalEntityName`**. Links to bank+branch by `BankName` +
`BankBranchName`.
```json
{"BankAccountName":"DMT Gold Account ${PREFIX}-1","BankAccountNumber":"${PREFIX}301",
 "CurrencyCode":"${CURRENCY}","BankName":"DMT Gold Bank ${PREFIX}-1",
 "BankBranchName":"DMT Gold Branch ${PREFIX}-1","LegalEntityName":"${LEGAL_ENTITY}",
 "Description":"Gold regression account ${PREFIX} one"}
```
> **Gotcha (fixed):** `LegalEntityName` is **mandatory** for `cashBankAccounts`.
> The reference tool account payload omits it and the branch/bank link fields, so
> its account POST would fail. This fixture supplies a discovered legal entity and
> the bank+branch names. (Logged for the tool.)

## The good/bad rows

| Row | Level | Key (name) | Purpose |
|---|---|---|---|
| GOOD-1 | Bank | `DMT Gold Bank ${PREFIX}-1` | → CE_BANKS_V |
| GOOD-2 | Bank | `DMT Gold Bank ${PREFIX}-2` | → CE_BANKS_V |
| GOOD | Branch | `DMT Gold Branch ${PREFIX}-1` (under BANK1) | → CE_BANK_BRANCHES_V |
| GOOD | Branch | `DMT Gold Branch ${PREFIX}-2` (under BANK2) | → CE_BANK_BRANCHES_V |
| GOOD | Account | `DMT Gold Account ${PREFIX}-1` (under BRANCH1) | → CE_BANK_ACCOUNTS |
| BAD | Bank | `DMT Gold Bank ${PREFIX}-BAD` | invalid `CountryName="Nowhereland"` → HTTP 400, creates nothing |

**Bad-row design:** the bad bank sends an invalid country name. Fusion rejects the
POST with HTTP 400 `The value of the attribute Country isn't valid.` A rejected
`cashBanks` POST is atomic — no party is created — so the bad key is absent from
CE_BANKS_V. That absence, alongside the good banks from the same run reaching the
base with real ids, is the bad-row proof (`bad_proof_is_absence` in the recipe).

## Discovery (load-time, read-only BIP, role `fin_impl`) — portability

No pod-specific id is hardcoded. Two references are discovered on the TARGET pod:

- `${LEGAL_ENTITY}` — a US legal entity (prefers `US1 Legal Entity`, else any
  `US%Legal Entity`) from `XLE_ENTITY_PROFILES`. Required for the account.
- `${CURRENCY}` — confirms `USD` is enabled in `FND_CURRENCIES`.

`United States` (country) is a Fusion-shipped territory on every pod, so it is a
literal in the payload rather than discovered. The routing numbers `${ROUTING1}` /
`${ROUTING2}` are **computed** from the prefix (not discovered) — see the branch
gotcha above.

## How to run it

```bash
cd gold_regression/harness
python load_rest.py   Banks --prefix <PREFIX> > /tmp/banks_load.json   # discover -> POST bank/branch/account
python verify_rest.py Banks <PREFIX> --load-json /tmp/banks_load.json  # read-only base verify
```
`load_rest.py` writes progress to stderr and the structured load result (ids,
errors, tokens) as JSON to stdout. `verify_rest.py` re-reads the three base tables
by prefix and reports `"pass": true` when all good rows are present with real ids
and the bad key is absent.

## Verification (read-only, direct single-table base reads)

Each level is read independently — no relayed multi-table join.

- **Banks → base.** `SELECT bank_name, MAX(bank_party_id) FROM ce_banks_v WHERE
  bank_name LIKE 'DMT Gold Bank <prefix>-%' GROUP BY bank_name`.
- **Branches → base.** `... FROM ce_bank_branches_v WHERE bank_branch_name LIKE
  'DMT Gold Branch <prefix>-%' ...` (id `BRANCH_PARTY_ID`).
- **Accounts → base.** `... FROM ce_bank_accounts WHERE bank_account_name LIKE
  'DMT Gold Account <prefix>-%' ...` (id `BANK_ACCOUNT_ID`).
- **Bad → absent.** The same `ce_banks_v` read must return no row for
  `DMT Gold Bank <prefix>-BAD`; the load result carries its HTTP 400 error text.

## Live evidence

**2026-07-19/20 — LIVE-PROVEN. PASS.**

Standalone REST load path only; verification via the read-only BIP relay only.
Pod `fa-esew-dev28-saasfademo1`. Credential role/user `fin_impl`.

| Field | Value |
|---|---|
| Date | 2026-07-20 (UTC) |
| Prefix | `91805` (also proven at `91803`) |
| Discovered legal entity | `US INS Legal Entity` |
| Discovered currency | `USD` |
| Computed routing numbers | `${ROUTING1}=918050015`, `${ROUTING2}=918050028` |
| Load summary | banks 2 ok / 1 err · branches 2 ok · accounts 1 ok |

**Good rows → base tables:**

| Level | Name | Base table | Fusion id |
|---|---|---|---|
| Bank | `DMT Gold Bank 91805-1` | CE_BANKS_V | `300000331549646` (BankPartyId) |
| Bank | `DMT Gold Bank 91805-2` | CE_BANKS_V | `300000331549651` |
| Branch | `DMT Gold Branch 91805-1` | CE_BANK_BRANCHES_V | `300000331549657` (BranchPartyId) |
| Branch | `DMT Gold Branch 91805-2` | CE_BANK_BRANCHES_V | `300000331549668` |
| Account | `DMT Gold Account 91805-1` | CE_BANK_ACCOUNTS | `300000331549678` (BankAccountId) |

**Bad row → rejected, absent from base:**

| Name | HTTP | Error detail | In CE_BANKS_V? |
|---|---|---|---|
| `DMT Gold Bank 91805-BAD` | 400 | `The value of the attribute Country isn't valid.` | No (absent) |

`verify_rest.py Banks 91805` reported `"pass": true`.

**First-attempt notes (all fixed, retried on fresh prefixes):**
- prefix 91801 — bank POST 400 `Invalid attribute "ShortBankName"`; removed the field.
- prefix 91802 — branch POST 400 `...Routing Number...(CE-660076)`; added the ABA
  routing-number generator; also confirmed the account needs `LegalEntityName`.
- prefix 91803/91805 — full chain 201 across bank→branch→account; bad bank 400.
