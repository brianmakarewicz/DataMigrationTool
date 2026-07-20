"""One-shot generator for the BlanketPOs gold FBDI templates.

Blanket Purchase Agreements (Import Blanket Agreements / ImportBPAJob) share the
PO interface tables with standard orders but use the SEPARATE, Blanket-suffixed
FBDI members and a different column layout (the BPA import template
POBlanketPurchaseAgreementImportTemplate.xlsm). The zip carries four
position-based CSVs (no header row), each with a trailing "END" sentinel column
that Oracle's BPA control files require:

    PoHeadersInterfaceBlanket.csv        122 columns (121 data + END)
    PoLinesInterfaceBlanket.csv          108 columns (107 data + END)
    PoLineLocationsInterfaceBlanket.csv   62 columns  (61 data + END)  price breaks
    PoGAOrgAssignInterfaceBlanket.csv     10 columns  (9 data + END)   BU assignment

Column positions are byte-mirrored from Oracle's own BPA import template (the
canonical objects/BlanketPOs/PoImportBlanketAgreements.zip) and cross-checked
against the proven DMT Blanket generator
(db/packages/dmt_blanket_po_fbdi_gen_pkg.pkb.sql). Every field is double-quoted.

What distinguishes a BLANKET from a STANDARD order in the header:
  - position 7  DOCUMENT_TYPE_CODE = BLANKET
  - position 8  STYLE              = 'Blanket Purchase Agreement'
The GA Org Assign CSV enables the agreement for a requisitioning/bill-to BU so
the created agreement is usable (Enabled = Y).

Two good agreements (G1, G2) + one bad agreement (BAD1). BAD1 carries an invalid
supplier site (ZZINVALIDSITE) so Import Blanket Agreements rejects it into
PO_INTERFACE_ERRORS while the row still lands in PO_HEADERS_INTERFACE and never
reaches PO_HEADERS_ALL.

${PREFIX} and discovered ${TOKEN}s are left in place for the harness to stamp.

Run once to (re)generate the templates:
    python objects/BlanketPOs/build_templates.py
"""
import os

HERE = os.path.dirname(os.path.abspath(__file__))
ART = os.path.join(HERE, 'artifact')

# Column counts of the four Blanket members (DATA columns; END is appended after).
N_HDR = 121
N_LINE = 107
N_LOC = 61
N_GA = 9


def emit(n_data, filled):
    """Build one fully double-quoted CSV row of n_data columns plus a trailing
    quoted "END" sentinel. `filled` maps 1-based position -> value."""
    cells = []
    for pos in range(1, n_data + 1):
        v = filled.get(pos, '')
        cells.append('"' + str(v).replace('"', '""') + '"')
    cells.append('"END"')
    return ','.join(cells)


# ---- HEADER (positions from the BPA template / dmt_blanket_po_fbdi_gen_pkg) --
# 1 Interface Header Key | 2 Action | 3 Batch ID (NUMBER col) | 4 Import Source
# 5 Approval Action | 6 Agreement (Document Num) | 7 Document Type Code=BLANKET
# 8 Style='Blanket Purchase Agreement' | 9 Procurement BU | 10 Buyer
# 11 Currency | 12 Description | 13 Supplier | 14 Supplier Number | 15 Supplier Site
# 22 Payment Terms | 23 Initiating Party (BUYER) | 98 Buyer E-mail
def hdr(sfx, bad=False):
    return emit(N_HDR, {
        1:  '${PREFIX}RT-BPA-' + sfx,
        2:  'ORIGINAL',
        # PO_HEADERS_INTERFACE.BATCH_ID is a NUMBER column -> numeric only.
        3:  '${PREFIX}',
        4:  'RT${PREFIX}',
        5:  'SUBMIT',
        6:  '${PREFIX}RT-BPA-' + sfx,
        7:  'BLANKET',
        8:  'Blanket Purchase Agreement',
        9:  '${PRC_BU_NAME}',
        10: '${AGENT_NAME}',
        11: '${CURRENCY_CODE}',
        12: 'RT Gold Blanket Agreement ' + sfx,
        13: '${VENDOR_NAME}',
        14: '${VENDOR_NUM}',
        # BAD row: invalid supplier site -> Import Blanket Agreements rejects it.
        15: ('ZZINVALIDSITE' if bad else '${VENDOR_SITE_CODE}'),
        22: 'Immediate',
        23: 'BUYER',
        98: '${AGENT_EMAIL}',
    })


# ---- LINE (BPA layout) -------------------------------------------------------
# 1 Line Key | 2 Header Key | 3 Action=ADD | 4 Line | 5 Line Type | 6 Item
# 7 Item Description | 9 Category Name | 11 UOM | 12 Price
def line(sfx):
    return emit(N_LINE, {
        1:  '${PREFIX}RT-BPAL-' + sfx,
        2:  '${PREFIX}RT-BPA-' + sfx,
        3:  'ADD',
        4:  '1',
        5:  '${LINE_TYPE}',
        7:  'RT Gold Blanket line ' + sfx,
        9:  '${CATEGORY_NAME}',
        11: 'Each',
        12: '25',
    })


# ---- LINE LOCATION (price break) --------------------------------------------
# 1 Line Location Key | 2 Line Key | 6 Quantity | 7 Price | 9 Start Date
# One price break per line (matches Oracle's own sample zip).
def loc(sfx):
    return emit(N_LOC, {
        1:  '${PREFIX}RT-BPALL-' + sfx,
        2:  '${PREFIX}RT-BPAL-' + sfx,
        6:  '1',
        7:  '25',
    })


# ---- GA ORG ASSIGN (BU assignment; makes the agreement enabled) -------------
# 1 BU Assignment Key | 2 Header Key | 3 Requisitioning BU | 4 Order Locally=N
# 7 Bill-to BU | 9 Enabled=Y
def ga(sfx):
    return emit(N_GA, {
        1: '${PREFIX}RT-BPABU-' + sfx,
        2: '${PREFIX}RT-BPA-' + sfx,
        3: '${PRC_BU_NAME}',
        4: 'N',
        7: '${PRC_BU_NAME}',
        9: 'Y',
    })


def write(name, lines):
    path = os.path.join(ART, name)
    with open(path, 'w', newline='') as f:
        f.write('\r\n'.join(lines) + '\r\n')
    print('wrote', path, '(%d cols x %d rows)' % (
        lines[0].count(',') + 1, len(lines)))


SFX = ['G1', 'G2', 'BAD1']
write('PoHeadersInterfaceBlanket.csv',
      [hdr('G1'), hdr('G2'), hdr('BAD1', bad=True)])
write('PoLinesInterfaceBlanket.csv', [line(s) for s in SFX])
write('PoLineLocationsInterfaceBlanket.csv', [loc(s) for s in SFX])
write('PoGAOrgAssignInterfaceBlanket.csv', [ga(s) for s in SFX])
print('done.')
