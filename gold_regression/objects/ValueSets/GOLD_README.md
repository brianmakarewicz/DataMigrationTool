# ValueSets — gold regression fixture (REST value set values) — LIVE-PROVEN, PASS

A standalone, reloadable fixture for **flexfield value set VALUES**. It adds new
values to an **existing, editable, independent value set** on the target pod
through the Fusion REST API, plus one deliberately-bad value the API rejects and
never creates. Read-only BIP verification confirms the good values reached the
base table `FND_FLEX_VALUES` and the bad value is absent. No DMT tool code and no
DMT database are in the load path; verification is the read-only BIP relay only.

## Mechanism finding — this is NOT UI-only (unlike Lookups)

The status table originally marked ValueSets "FBL delivery undecided". The
investigation found a genuine **non-UI standalone load path**, so it is built and
proven rather than tabled.

There are three candidate delivery mechanisms for value set values; two are
unusable by this harness, one is:

1. **UI-only import** — *Setup and Maintenance → Manage Value Sets → Actions →
   Import* reading a pipe-delimited CSV from UCM. This is the same UI-click path
   that blocks the Lookups object; it satisfies neither the web-service nor the
   no-browser posture. Not used.
2. **"Upload Value Set Values" scheduled process (ESS job)** — a real schedulable
   ESS job that reads a flat file from a content-repository account. It exists and
   is a valid non-UI path, but it needs the flat file placed via the *File Import
   and Export* page (UCM) first and returns no per-row interface table that is
   BIP-reachable for bad-row proof. Documented here as a fallback but not the
   chosen path.
3. **Fusion REST API `valueSets` child `values`** *(chosen — proven live)* — a
   direct, standalone, one-value-per-POST create:
   `POST /fscmRestApi/resources/11.13.18.05/valueSets/{ValueSetCode}/child/values`.
   This is exactly what the reference PL/SQL tool uses
   (`db/packages/dmt_fnd_vs_results_pkg.pkb.sql`, phase 2). It writes straight to
   the base tables, returns the created `ValueId` inline, and returns an HTTP 4xx
   with a Fusion error for a bad value. Same class of load path as the Banks REST
   object. This is the gold load path.

Because value set VALUES are created individually via REST (no zip, no ESS job in
the load path), this object — like Banks — has its own load module,
`harness/load_rest_vsv.py` (additive; it does not touch the FBDI/HDL/Banks
modules). There is no `_gold.zip`; the payload template is captured in
`artifact/ValueSetValues.rest.json` for reference and for the ESS/FBL fallback.

## The load call (credential role `fin_impl`)

`valueSets` is a Financials/Common REST resource; the `fin_impl` user loads it.
Base URL comes from `connections.json` (`get_fusion_url()`), version `11.13.18.05`.

| Method + path | Body | Returns |
|---|---|---|
| `POST /fscmRestApi/resources/11.13.18.05/valueSets/{ValueSetCode}/child/values` | `{"Value","EnabledFlag","Description"}` | `ValueId` (201) |

`{ValueSetCode}` is the discovered value set's name, **URL-encoded** into the path
(names can contain spaces). There is no ParameterList — REST has none; the
"parameters" are the JSON body fields.

### Payload (exact fields)

```json
{"Value":"G${PREFIX}1","EnabledFlag":"Y","Description":"DMT gold value ${PREFIX} one"}
```

`IndependentValue` is omitted deliberately: the fixture targets an **independent**
value set, so a value has no parent value to reference. Effective dates are left
null (the value is active immediately).

## Portability — discover an existing value set, never hardcode (rules 6-8)

Value set values must attach to an existing value set, so the fixture does **not**
create a value set (that would require a module id and extra config). Instead one
discovery step finds an existing **editable independent** value set on the TARGET
pod at load time and stamps its name/id into the load path and the verify reads:

- `${VS_CODE}` / `${VS_ID}` — from `FND_FLEX_VALUE_SETS` joined to
  `FND_FLEX_VALUES`, choosing a value set that is:
  - `validation_type = 'I'` (independent — values stand alone),
  - `protected_flag = 'N'` **and** `security_enabled_flag = 'N'` (editable),
  - `format_type = 'C'`, `maximum_size` between 20 and 40 (so the bad value's
    fixed 48-character string reliably exceeds the size),
  - **`created_by <> 'SEED_DATA_FROM_APPLICATION'`** — the load-hardening filter:
    Oracle-seeded value sets reject writes with HTTP 400 *"You cannot modify a
    protected value set"* even when `protected_flag='N'`. Excluding
    `SEED_DATA_FROM_APPLICATION` restricts discovery to implementation-created
    (writable) value sets. This was found live: prefix 91864 first picked a
    seeded set and was rejected; the filter fixed it and re-runs pass on every
    fresh prefix.
  - has 2–200 existing values (a real, in-use independent set), ordered to a
    stable pick.

The new values are stamped with a fresh numeric `${PREFIX}` code (`G<prefix>1`,
`G<prefix>2`), so re-runs never collide and nothing depends on a value set we
loaded earlier. Different pods (and different runs on the same pod) resolve
`${VS_CODE}` to whatever editable independent value set they happen to have — the
fixture has been observed to pick `retail_grocery_package _type_vs` (id 50880),
`str_absorbancy_vs` (id 51206) and `str_mat_char_vs` (id 51207) on this pod.

## The good / bad rows

| Row | Value code | Purpose |
|---|---|---|
| GOOD-1 | `G${PREFIX}1` | enabled value → `FND_FLEX_VALUES` |
| GOOD-2 | `G${PREFIX}2` | enabled value → `FND_FLEX_VALUES` |
| BAD | `B${PREFIX}TOOLONGXXXX…` (48 chars) | Value longer than the set's `MaximumSize` → HTTP 400 `The value ... is too long. (FND-2825)` → creates nothing |

**Bad-row design (deterministic, pod-independent).** The bad value's code is a
fixed 48-character string. Every candidate value set has `maximum_size ≤ 40`, so
the value always exceeds the limit and Fusion always rejects the POST with
`FND-2825`. A rejected value POST is atomic — no `FND_FLEX_VALUES` row is created
— so the bad key is absent from base. That absence, alongside the two good values
from the same run reaching base with real `FLEX_VALUE_ID`s, is the bad-row proof
(`bad_proof_is_absence` in the recipe). The bad value targets the **same**
discovered value set as the good values, so good-succeeds / bad-rejects is proven
in one value set in one run.

## Orchestration

No ESS job, no chained/downstream job — each REST POST writes the value directly
to `FND_FLEX_VALUES`/`_TL` and returns its `ValueId` synchronously. There is no
interface table for the REST path. (If the ESS "Upload Value Set Values" fallback
were ever used instead, its interface table is `FND_VS_VALUES_INTERFACE` and its
base table `FND_VS_VALUES_B`/`_TL`; the REST resource surfaces the same data and
is what this fixture uses.)

## How to run it

```bash
cd gold_regression/harness
python load_rest_vsv.py ValueSets --prefix <PREFIX>
```

`load_rest_vsv.py` runs discover → POST each value → read-only BIP verify in one
process (one discovery pass). It prints progress to stderr and the combined
load+verify JSON to stdout, and exits 0 when `"pass": true`. Omit `--prefix` for a
fresh random one.

## Verification (read-only, direct single-table base reads)

- **Good → base.** `SELECT fv.flex_value, MAX(fv.flex_value_id) FROM
  fnd_flex_values fv JOIN fnd_flex_value_sets vs ON vs.flex_value_set_id =
  fv.flex_value_set_id WHERE vs.flex_value_set_id = <VS_ID> AND fv.flex_value LIKE
  'G<prefix>%' GROUP BY fv.flex_value`. Both good codes present with a real
  `FLEX_VALUE_ID` = pass.
- **Bad → absent.** The same read scoped to `fv.flex_value LIKE 'B<prefix>%'` must
  return no row; the load result carries the bad value's HTTP 400 `FND-2825` text.

## Live evidence

**2026-07-19 — LIVE-PROVEN. PASS.**

Standalone REST load path only; verification via the read-only BIP relay only.
Pod `fa-esew-dev28-saasfademo1`. Credential role/user `fin_impl`.

| Prefix | Discovered value set (id) | Good → FND_FLEX_VALUES (FLEX_VALUE_ID) | Bad → reject / absent | Verdict |
|---|---|---|---|---|
| `91861` | `retail_grocery_package _type_vs` (50880) | `G918611`→619812, `G918612`→619813 | HTTP 400 FND-2825, absent | pass |
| `91870` | `str_absorbancy_vs` (51206) | `G918701`→619818, `G918702`→619819 | HTTP 400 FND-2825, absent | pass |
| `91873` | `str_mat_char_vs` (51207) | `G918731`→619821, `G918732`→619822 | HTTP 400 FND-2825, absent | pass |

Bad-row error text (identical each run):
`The value B<prefix>TOOLONGXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX is too long. (FND-2825)`

**First-attempt note (fixed):** the discovery filter originally allowed any
value set with `protected_flag='N'`; prefix 91864 picked the Oracle-seeded set
`HWM_DD_BLDG_BLK_TYPE` (created_by `SEED_DATA_FROM_APPLICATION`) and every POST
returned HTTP 400 *"You cannot modify a protected value set."* Adding
`created_by <> 'SEED_DATA_FROM_APPLICATION'` to discovery restricts the pick to
implementation-created, writable value sets; all subsequent fresh-prefix runs
pass.

## Sources

- Oracle: [Upload Value Set Values Process](https://docs.oracle.com/en/cloud/saas/applications-common/26a/facia/upload-value-set-values-process.html) (the ESS-job fallback)
- Oracle: [Import Value Set Values](https://docs.oracle.com/en/cloud/saas/human-resources/faucf/import-value-set-values.html) (file format for the ESS/UI path)
- Oracle REST: [Values REST Endpoints](https://docs.oracle.com/en/cloud/saas/applications-common/25a/farca/api-value-sets-values.html) — `valueSets/{id}/child/values` (the chosen load path)
- RishOraDev: [Bulk Upload Value Sets in Oracle Fusion](https://blog.rishoradev.com/2025/04/12/bulk-upload-value-sets-in-oracle-fusion/)
- Reference tool loader: `db/packages/dmt_fnd_vs_results_pkg.pkb.sql`
