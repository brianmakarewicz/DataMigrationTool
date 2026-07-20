# Items (gold regression)

Import Items / EGP item import — FBDI, **SCM object → `scm_impl` credential for BOTH the
SOAP load and the read-only BIP verify**.

**Gold status:** ✅ LIVE-PROVEN 2026-07-19. Prefix `69160`, load request `9763999`:
2/2 good items → base `EGP_SYSTEM_ITEMS_B` (org 000, INVENTORY_ITEM_IDs
`100002547248242` / `100002547248243`); bad row (invalid ORGANIZATION_CODE) rejected by
Item Import — "You must provide a valid value for the attribute organization" — and absent
from base.

Full call, ParameterList, discovery, verify SQL, and live evidence are in
[`GOLD_README.md`](GOLD_README.md). Recipe is `recipe.json`. Frozen artifact is
`Items_gold.zip` (single member `EgpSystemItemsInterface.csv`, 399 positional columns, no
header, 2 good + 1 bad).

## Key facts

- **Job:** `ItemImportJobDef` at `/oracle/apps/ess/scm/productModel/items`, via
  `loadAndImportData`. UCM DocumentAccount `scm/item/import`, interfaceDetails `29`.
- **ParameterList (7 args):** `${PREFIX},null,CREATE,Y,ORA_COMP,N,Y`
  (arg1 Batch ID = the numeric prefix, must equal CSV BATCH_ID; arg5 `ORA_COMP` keeps
  error rows longer than `ORA_ER`).
- **Discovery (one BIP query, scm_impl):** item master org `000`, item class
  `Root Item Class`, status `Active`, primary UOM name `Each` — all discovered on the
  target pod, nothing hardcoded, no dependency on our earlier loads.
- **Data-quality gotcha:** interface column 13 `PRIMARY_UOM_NAME` needs the UOM **name**
  (`Each`), not the code (`ECH`) — the code fails "Primary Unit of Measure isn't valid".
- **Base replica lag:** good items appear in `EGP_SYSTEM_ITEMS_B` ~2 min after the load
  request goes SUCCEEDED. Verify a couple of minutes later.
- **Bad-row proof:** Item Import purges the errored interface row after the batch
  completes, so the durable proof is ABSENCE from base while the good rows from the same
  load reached base. Recipe sets `bad_proof_is_absence` + `bad_absence_note`; the invalid
  org error is captured live in the `ItemImportJobDef` ESS report.
