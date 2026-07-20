# ValueSets — gold regression fixture (REST value set values) — v2 seeded

This is the **v2 (hard-coded seeded reference, no discovery)** version of the ValueSets
fixture. It is functionally identical to the frozen v1 fixture in `../../objects/ValueSets/`,
except the value set that v1 **discovered** at load time is now written as a **literal**
(`FA_MAJOR_CATEGORY`) in the recipe, and the recipe's `discovery` block is deleted.

Same as v1: a standalone **REST** fixture for flexfield value set VALUES. It adds new values
to an existing, editable, independent value set on the target pod through the Fusion REST API
(`POST /fscmRestApi/resources/11.13.18.05/valueSets/{ValueSetCode}/child/values`), plus one
deliberately-bad value the API rejects and never creates. Read-only BIP verification confirms
the good values reached base table `FND_FLEX_VALUES` and the bad value is absent. No DMT tool
code and no DMT database are in the load path; verification is the read-only BIP relay only.

## The one nuance for this object — why a literal is safe here

Every other v2 object hard-codes a *reference* (a business unit, a legal entity). This object
hard-codes the **target** of the write — the value set the new values attach to — and that
target must be **writable**. A **seeded** value set (Oracle-shipped, `created_by =
SEED_DATA_FROM_APPLICATION`) is read-protected and rejects every write with HTTP 400
*"You cannot modify a protected value set."* — so, unlike other objects, we cannot hard-code
a plain seeded value set.

The literal chosen is **`FA_MAJOR_CATEGORY`** — the standard Oracle Fusion **Fixed Assets
Major Category** value set. It satisfies every requirement:

- **Editable / writable.** `created_by = FIN_IMPL` (an implementation user, **not**
  `SEED_DATA_FROM_APPLICATION`), `protected_flag = 'N'`, `security_enabled_flag = 'N'`. A live
  probe POST returned HTTP 201 with a real `ValueId` — it accepts value writes.
- **Not one we loaded.** It carries no DMT prefix; it is part of the base Fixed Assets
  configuration, created during demo-image provisioning, long before any gold run.
- **Stable across pods.** It is a fixed-name, Oracle-delivered Fixed Assets *setup* value set
  that exists in the base demo image, so it is present on every `fa-esew-devN-saasfademo1`
  demo pod under the same name. (This is why it is a better v2 literal than the SCM demo
  product value sets v1 happened to resolve to — `retail_grocery_package _type_vs`,
  `str_absorbancy_vs`, `str_mat_char_vs` — which vary run to run.)
- **`maximum_size = 20`.** The bad value's fixed 48-character code always exceeds it, so the
  bad POST is deterministically rejected with `FND-2825` on any pod.

**No minimal lookup was needed.** Because `FA_MAJOR_CATEGORY` is a stable, named, editable
Fixed Assets configuration value set present on every demo pod, it is hard-coded as a plain
literal with **zero discovery** — the fixture takes the "hard-code a specific existing editable
non-seeded value set" branch, not the "keep a minimal single lookup" exception.

## What changed from v1 (the only difference)

| Aspect | v1 (`../../objects/ValueSets/`) | v2 (this folder) |
|---|---|---|
| Value set target | **discovered** at load time (a `discovery` block queried `FND_FLEX_VALUE_SETS` for the first editable independent set) | **hard-coded** literal `FA_MAJOR_CATEGORY` in a `seeded` block |
| `${VS_CODE}` source | discovery bind | `recipe.seeded.VS_CODE` |
| `${VS_ID}` in verify SQL | discovery bind (`vs.flex_value_set_id = ${VS_ID}`) | **removed** — verify keys on the value set **name** (`vs.flex_value_set_name = 'FA_MAJOR_CATEGORY'`), which is pod-portable and needs no id |
| `${PREFIX}` on new value codes | yes (`G<prefix>1/2`, `B<prefix>...`) | **unchanged** — yes |

The shared loader `harness/load_rest_vsv.py` gained one additive, backward-compatible line: it
merges `recipe.get('seeded')` into the token map after discovery. A v1 recipe has no `seeded`
key and a v2 recipe has no `discovery` block, so exactly one source populates the tokens and v1
runs unchanged.

## The load call (credential role `fin_impl`)

`valueSets` is a Financials/Common REST resource; the `fin_impl` user loads it. Base URL comes
from `connections.json` (`get_fusion_url()`), version `11.13.18.05`.

| Method + path | Body | Returns |
|---|---|---|
| `POST /fscmRestApi/resources/11.13.18.05/valueSets/FA_MAJOR_CATEGORY/child/values` | `{"Value","EnabledFlag","Description"}` | `ValueId` (201) |

There is no ParameterList — REST has none; the "parameters" are the JSON body fields.
`IndependentValue` is omitted deliberately (an independent value set's values have no parent).

## The good / bad rows

| Row | Value code | Purpose |
|---|---|---|
| GOOD-1 | `G${PREFIX}1` | enabled value → `FND_FLEX_VALUES` |
| GOOD-2 | `G${PREFIX}2` | enabled value → `FND_FLEX_VALUES` |
| BAD | `B${PREFIX}TOOLONGXXXX…` (48 chars) | Value longer than the set's `MaximumSize` (20) → HTTP 400 `The value ... is too long. (FND-2825)` → creates nothing |

**Bad-row proof (`bad_proof_is_absence`).** The bad value's code is a fixed 48-character
string; `FA_MAJOR_CATEGORY` has `maximum_size = 20`, so the POST is always rejected with
`FND-2825`. A rejected value POST is atomic — no `FND_FLEX_VALUES` row is created — so the bad
key is absent from base. That absence, alongside the two good values from the same run reaching
base with real `FLEX_VALUE_ID`s, is the bad-row proof.

## How to run it (v2 path)

`load_rest_vsv.py` is the dedicated runner for this REST type (`run_object.py` handles only
FBDI and HDL). Point it at the v2 tree with the one env var:

```bash
cd gold_regression/harness
export GOLD_OBJECTS_SUBDIR=objects_seeded
python load_rest_vsv.py ValueSets --prefix <PREFIX>
```

It runs POST each value → read-only BIP verify in one process, prints the combined load+verify
JSON to stdout, and exits 0 when `"pass": true`. Omit `--prefix` for a fresh random one.

## Verification (read-only, direct single-table base reads)

- **Good → base.** `SELECT fv.flex_value, MAX(fv.flex_value_id) FROM fnd_flex_values fv JOIN
  fnd_flex_value_sets vs ON vs.flex_value_set_id = fv.flex_value_set_id WHERE
  vs.flex_value_set_name = 'FA_MAJOR_CATEGORY' AND fv.flex_value LIKE 'G<prefix>%' GROUP BY
  fv.flex_value`. Both good codes present with a real `FLEX_VALUE_ID` = pass.
- **Bad → absent.** The same read scoped to `fv.flex_value LIKE 'B<prefix>%'` returns no row;
  the load result carries the bad value's HTTP 400 `FND-2825` text.

## Live evidence

**2026-07-20 — v2 seeded — LIVE-PROVEN. PASS (two consecutive runs).**

Standalone REST load path only (`load_rest_vsv.py`, `GOLD_OBJECTS_SUBDIR=objects_seeded`);
verification via the read-only BIP relay only. Pod `fa-esew-dev28-saasfademo1`. Credential
role/user `fin_impl`. No discovery — value set hard-coded to `FA_MAJOR_CATEGORY`.

| Prefix | Value set (literal) | Good → FND_FLEX_VALUES (FLEX_VALUE_ID) | Bad → reject / absent | Verdict |
|---|---|---|---|---|
| `94120` | `FA_MAJOR_CATEGORY` | `G941201`→619824, `G941202`→619825 | HTTP 400 FND-2825, absent | pass |
| `94137` | `FA_MAJOR_CATEGORY` | `G941371`→619827, `G941372`→620816 | HTTP 400 FND-2825, absent | pass |

Bad-row error text (identical each run):
`The value B<prefix>TOOLONGXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX is too long. (FND-2825)`

The second consecutive run (fresh prefix, no reset) landed cleanly alongside the first with no
collision, proving reloadability.

**Writability probe (2026-07-20):** before wiring the literal, a one-off probe POST to
`FA_MAJOR_CATEGORY`, `FA_ASSET_KEY` and `FA_BUILDING` each returned HTTP 201 with a real
`ValueId`, confirming these Fixed Assets value sets are editable. `FA_MAJOR_CATEGORY` was
chosen (stable Fixed Assets *Major Category* setup value set, `maximum_size = 20`). The child
`values` resource does not support DELETE (returned 400), so the three inert probe values —
plain codes carrying no prefix, no collision with the `G<prefix>N` gold values — remain in
those sets; they are harmless.

## Sources

- Oracle REST: `valueSets/{id}/child/values` — the chosen load path.
- v1 fixture: `../../objects/ValueSets/GOLD_README.md` (discovery version, live-proven 2026-07-19).
- Reference tool loader: `db/packages/dmt_fnd_vs_results_pkg.pkb.sql` (phase 2 POST).
