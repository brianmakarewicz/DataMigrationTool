"""Generate the InvTransactionsInterface.csv gold template (3 rows: 2 good + 1 bad).

The FBDI CSV for INV_TRANSACTIONS_INTERFACE has 265 data columns (the CTL's
first 8 fields TRANSACTION_INTERFACE_ID..LOAD_REQUEST_ID are EXPRESSION/CONSTANT,
supplied by the SQL*Loader control file, NOT present in the data CSV). This
mirrors the frozen generator dmt_misc_receipt_fbdi_gen_pkg, which starts the CSV
at ORGANIZATION_NAME (CTL data column 9) and ends at CONT_LICENSE_PLATE_NUMBER
(CTL column 273) -> 265 comma-separated values, no header row.
"""
# Authoritative CSV data column list, extracted directly from
# objects/InvTransactions/InvTransactionsInterface.ctl (the 8 loader-supplied
# system fields and the trailing CONSTANT OBJECT_VERSION_NUMBER are excluded).
import os as _os, sys as _sys
_sys.path.insert(0, _os.path.dirname(_os.path.abspath(__file__)))
from _invtrx_cols import COLS  # noqa: E402
assert len(COLS) == 273, len(COLS)

def row(vals):
    r = {c: "" for c in COLS}
    r.update(vals)
    return ",".join(r[c] for c in COLS)

# Common misc-receipt defaults (mirror the transformer's MCCS defaults).
# SOURCE_HEADER_ID and SOURCE_LINE_ID are NOT NULL on INV_TRANSACTIONS_INTERFACE
# (confirmed via all_tab_columns) -- SOURCE_HEADER_ID groups the batch (= prefix),
# SOURCE_LINE_ID uniquely identifies the row within the batch.
def base(item, qty, ref, line):
    return {
      "ORGANIZATION_NAME": "${ORG_NAME}",
      "PROCESS_FLAG": "1",                       # 1 = pending (loader processes)
      "ITEM_NUMBER": item,
      "SUBINVENTORY_CODE": "${SUBINV}",
      "TRANSACTION_QUANTITY": qty,
      "TRANSACTION_UNIT_OF_MEASURE": "${UOM_NAME}",
      "TRANSACTION_DATE": "${TXN_DATE}",         # YYYY/MM/DD HH24:MI:SS
      "TRANSACTION_SOURCE_TYPE_NAME": "Inventory",
      "TRANSACTION_TYPE_NAME": "Miscellaneous Receipt",
      "TRANSACTION_MODE": "3",                   # 3 = background
      "LOCK_FLAG": "2",                          # 2 = not locked
      "TRANSACTION_REFERENCE": ref,
      "SOURCE_CODE": "DMT",
      "SOURCE_HEADER_ID": "${PREFIX}",           # batch header (NOT NULL)
      "SOURCE_LINE_ID": "${PREFIX}" + line,      # unique per row (NOT NULL)
      # A miscellaneous receipt values the received units from the item's
      # established current (perpetual average) cost. The manager only reads
      # that cost when USE_CURRENT_COST_FLAG='Y' is set explicitly -- leaving it
      # NULL makes the manager reject with INV_MATRX_CURRENT_COST_NULL even for
      # a cost-enabled item. This mirrors the proven pipeline generator, which
      # writes USE_CURRENT_COST='Y' at CSV column 250. Discovery restricts to
      # items that have already posted a misc receipt, proving they carry a
      # readable current cost. No TRANSACTION_COST is supplied.
      "USE_CURRENT_COST_FLAG": "Y",
    }

rows = [
  base("${ITEM_NUMBER}", "7",  "${PREFIX}RT-INVRCPT-G1", "01"),
  base("${ITEM_NUMBER}", "4",  "${PREFIX}RT-INVRCPT-G2", "02"),
  # BAD: nonexistent item -> Fusion rejects into INV_TRANSACTIONS_INTERFACE
  base("FAKE-ITEM-${PREFIX}-BAD", "1", "${PREFIX}RT-INVRCPT-BAD1", "03"),
]

csv = "\r\n".join(row(v) for v in rows) + "\r\n"
import os
out = os.path.join(os.path.dirname(os.path.abspath(__file__)),
                   "..","objects","MiscReceipts","artifact","InvTransactionsInterface.csv")
with open(out,"w",newline="") as f:
    f.write(csv)
print("wrote", os.path.abspath(out))
print("cols per row:", csv.split("\r\n")[0].count(",")+1)
