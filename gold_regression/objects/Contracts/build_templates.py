"""One-shot generator for the Contracts (Contract Purchase Agreement) gold FBDI template.

A Contract Purchase Agreement (CPA) is a HEADERS-ONLY procurement agreement. Its FBDI
zip carries a single position-based CSV, PoHeadersInterfaceContract.csv, whose 105-column
layout is byte-mirrored from the proven DMT contract generator
(db/packages/dmt_contract_fbdi_gen_pkg.pkb.sql, gen_headers_csv) which in turn follows
Oracle's POContractPurchaseAgreementImportTemplate.xlsm. The CTL requires a trailing
literal END field after column 105 on every data row (confirmed by the proven
BlanketPOs fixture -- CPA and BPA share PO_HEADERS_INTERFACE and the same trailing END).

Differences from a Standard PO / Blanket PO:
  * headers only -- no lines/locations/distributions CSV,
  * DOCUMENT_TYPE_CODE = 'CONTRACT' (a Blanket PO is 'BLANKET'),
  * STYLE = 'Contract Purchase Agreement',
  * imported by ImportCPAJob (7-arg ParameterList), UCM account
    prc/contractPurchaseAgreement/import.

Every field is double-quoted except the trailing END marker (matches the generator's
append style and the proven Blanket zip). ${PREFIX} and discovered ${TOKEN}s are left in
place for the harness to stamp at load time.

Two good agreements (G1, G2) + one bad agreement (BAD1). BAD1 carries an invalid supplier
site code so ImportCPAJob rejects it into PO_INTERFACE_ERRORS while the row still lands in
PO_HEADERS_INTERFACE and never reaches PO_HEADERS_ALL (TYPE_LOOKUP_CODE=CONTRACT).

Run once to (re)generate the template:
    python objects/Contracts/build_templates.py
"""
import os

HERE = os.path.dirname(os.path.abspath(__file__))
ART = os.path.join(HERE, 'artifact')

# ---- exact ordered column list (105 cols) from the proven CPA generator ------
# Position -> logical column. Only the positions a CPA import needs are filled;
# the rest are empty ("").  Position numbering matches the generator comments.
COLS = [
    'INTERFACE_HEADER_KEY',       # 1  Interface Header Key
    'ACTION',                     # 2  Action
    'BATCH_ID',                   # 3  Batch ID (NUMBER column -> numeric)
    'INTERFACE_SOURCE_CODE',      # 4  Import Source
    'APPROVAL_ACTION',            # 5  Approval Action
    'DOCUMENT_NUM',               # 6  Agreement (Document Num)
    'DOCUMENT_TYPE_CODE',         # 7  Document Type Code  (CONTRACT)
    'STYLE_DISPLAY_NAME',         # 8  Style
    'PRC_BU_NAME',                # 9  Procurement BU
    'AGENT_NAME',                 # 10 Buyer
    'CURRENCY_CODE',              # 11 Currency Code
    'COMMENTS',                   # 12 Description
    'VENDOR_NAME',                # 13 Supplier
    'VENDOR_NUM',                 # 14 Supplier Number
    'VENDOR_SITE_CODE',           # 15 Supplier Site
    'VENDOR_CONTACT',             # 16 Supplier Contact
    'VENDOR_DOC_NUM',             # 17 Supplier Order
    'FOB',                        # 18 Fob
    'FREIGHT_CARRIER',            # 19 Carrier
    'FREIGHT_TERMS',              # 20 Freight Terms
    'PAY_ON_CODE',                # 21 Pay On Code
    'PAYMENT_TERMS',              # 22 Payment Terms
    'ORIGINATOR_ROLE',            # 23 Initiating Party
    'CHANGE_ORDER_DESC',          # 24 Change Order Description
    'ACCEPTANCE_REQUIRED_FLAG',   # 25 Required Acknowledgment
    'ACCEPTANCE_WITHIN_DAYS',     # 26 Acknowledge Within (Days)
    'SUPPLIER_NOTIF_METHOD',      # 27 Communication Method
    'FAX',                        # 28 Fax
    'EMAIL_ADDRESS',              # 29 E-mail
    'CONFIRMING_ORDER_FLAG',      # 30 Confirming order
    'AGREEMENT_AMOUNT',           # 31 Agreement Amount (empty)
    'AMOUNT_LIMIT',               # 32 Amount Limit (empty)
    'MIN_RELEASE_AMOUNT',         # 33 Minimum Release Amount (empty)
    'START_DATE',                 # 34 Start Date (empty)
    'END_DATE',                   # 35 End Date (empty)
    'NOTE_TO_VENDOR',             # 36 Note to Supplier
    'NOTE_TO_RECEIVER',           # 37 Note to Receiver
    'AUTO_GEN_ORDERS',            # 38 Automatically generate orders (empty)
    'AUTO_SUBMIT_APPROVAL',       # 39 Automatically submit for approval (empty)
    'GROUP_REQUISITIONS',         # 40 Group requisitions (empty)
    'GROUP_REQ_LINES',            # 41 Group requisition lines (empty)
    'USE_SHIP_TO_ORG_LOC',        # 42 Use ship-to organization and location (empty)
    'USE_NEED_BY_DATE',           # 43 Use need-by date (empty)
    'ATTRIBUTE_CATEGORY',         # 44
]
COLS += ['ATTRIBUTE%d' % i for i in range(1, 21)]            # 45-64 ATTRIBUTE1-20
COLS += ['ATTRIBUTE_DATE%d' % i for i in range(1, 11)]       # 65-74 ATTRIBUTE_DATE1-10
COLS += ['ATTRIBUTE_NUMBER%d' % i for i in range(1, 11)]     # 75-84 ATTRIBUTE_NUMBER1-10
COLS += ['ATTRIBUTE_TIMESTAMP%d' % i for i in range(1, 11)]  # 85-94 ATTRIBUTE_TIMESTAMP1-10
COLS += [
    'AGENT_EMAIL_ADDRESS',        # 95 Buyer E-mail
    'MODE_OF_TRANSPORT',          # 96 Mode of Transport
    'SERVICE_LEVEL',              # 97 Service level
    'USE_CUSTOMER_SALES_ORDER',   # 98 Use Customer Sales Order (empty)
    'BUYER_MANAGED_TRANSPORT_FLAG',  # 99 Buyer Managed Transportation
    'CONFIG_ORDERING_ENABLED',    # 100 (empty)
    'ALLOW_UNASSIGNED_SITES',     # 101 (empty)
    'OUTSIDE_PROCESSING_ENABLED', # 102 (empty)
    'ENABLE_AUTO_SOURCING',       # 103 (empty)
    'MASTER_CONTRACT_NUMBER',     # 104 (empty)
    'MASTER_CONTRACT_TYPE',       # 105 (empty)
]
assert len(COLS) == 105, len(COLS)


def row(values):
    """Fully double-quoted CSV line for the 105-col order, then a trailing
    literal END field (unquoted -- matches generator + proven Blanket zip)."""
    cells = ['"' + str(values.get(c, '')).replace('"', '""') + '"' for c in COLS]
    return ','.join(cells) + ',END'


def hdr(sfx, bad=False):
    v = {
        'INTERFACE_HEADER_KEY': '${PREFIX}RT-CPA-' + sfx,
        'ACTION': 'ORIGINAL',
        # PO_HEADERS_INTERFACE.BATCH_ID is a NUMBER column -> must be numeric.
        # (The ImportCPAJob arg-4 batch label is separate pass-through text.)
        'BATCH_ID': '${PREFIX}',
        'INTERFACE_SOURCE_CODE': 'RT${PREFIX}',
        'APPROVAL_ACTION': 'SUBMIT',
        'DOCUMENT_NUM': '${PREFIX}RT-CPA-' + sfx,
        # A Contract Purchase Agreement is DOCUMENT_TYPE_CODE=CONTRACT + this style.
        'DOCUMENT_TYPE_CODE': 'CONTRACT',
        'STYLE_DISPLAY_NAME': 'Contract Purchase Agreement',
        'PRC_BU_NAME': '${PRC_BU_NAME}',
        'AGENT_NAME': '${AGENT_NAME}',
        'CURRENCY_CODE': '${CURRENCY_CODE}',
        'COMMENTS': 'RT Gold Contract Agreement ' + sfx,
        'VENDOR_NAME': '${VENDOR_NAME}',
        'VENDOR_NUM': '${VENDOR_NUM}',
        # BAD row: invalid supplier site -> ImportCPAJob rejects it into
        # PO_INTERFACE_ERRORS (same deterministic rejection as the PO fixture).
        'VENDOR_SITE_CODE': ('ZZINVALIDSITE' if bad else '${VENDOR_SITE_CODE}'),
        'AGENT_EMAIL_ADDRESS': '${AGENT_EMAIL}',
    }
    return row(v)


def write(name, lines):
    path = os.path.join(ART, name)
    # FBDI CSVs use CRLF line endings; keep newline='' so we control them.
    with open(path, 'w', newline='') as f:
        f.write('\r\n'.join(lines) + '\r\n')
    print('wrote', path, '(%d cols + END x %d rows)' % (len(COLS), len(lines)))


write('PoHeadersInterfaceContract.csv',
      [hdr('G1'), hdr('G2'), hdr('BAD1', bad=True)])
print('done. header cols=%d (+END marker)' % len(COLS))
