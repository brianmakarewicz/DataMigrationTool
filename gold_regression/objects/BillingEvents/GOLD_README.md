# BillingEvents — gold regression fixture (LIVE-PROVEN)

Project **billing events** import. One FBDI zip, one CSV (`PjbBillingEventsXface.csv`),
one load-and-import ESS job. A billing event attaches to an EXISTING contract line that is
enabled for billing and to an EXISTING project linked to that contract line. This fixture
creates NEW billing events (fresh `${PREFIX}` on the source reference and event number) but
BORROWS every reference (contract, contract line, project, event type, organization, currency)
from data already present on the target pod, discovered live at load time. No dependency on any
earlier DMT load.

## What loads

| Item | Value |
|---|---|
| Type | FBDI |
| Artifact | `BillingEvents_gold.zip` → member `PjbBillingEventsXface.csv` (headerless, 78 positional fields) |
| Auth user | `fin_impl` (HTTP Basic on the SOAP call and the read-only BIP relay) |
| UCM document account | `prj/projectBilling/import` |
| interfaceDetails id | `68` (from `DMT_ERP_INTERFACE_OPTIONS_TBL`, ERP_INTERFACE_OPTIONS_ID 68, CEMLI_CODE BillingEvents) |
| Interface table | `PJB_BILLING_EVENTS_INT` (unconditionally purged after import — see caveat) |
| Base table | `PJB_BILLING_EVENTS` |

## ESS orchestration (in order)

1. **`loadAndImportData`** (ERP Integration SOAP service,
   `<fusion_url>/fscmService/ErpIntegrationService`). One call that (a) base64-uploads the zip to
   UCM under `prj/projectBilling/import`, (b) runs "Load File to Interface Tables" (SQL*Loader)
   to unpack the CSV into `PJB_BILLING_EVENTS_INT`, and (c) chains the import job below.
   - `<JobName>` = `/oracle/apps/ess/projects/billing/transactions,ImportBillingEventJob`
   - `<ParameterList>` = **`#NULL`** (the import job takes no positional arguments)
   - `<interfaceDetails>` = `68`
   - Returns the load ESS request id; poll it with `getESSJobStatus` to a terminal status
     (SUCCEEDED here at ~60 s).
2. **`ImportBillingEventJob`** — the chained import (submitted by loadAndImportData, not a
   separate call). It validates each interface row against the contract / contract line /
   project / event type and either creates a `PJB_BILLING_EVENTS` base row (accepted) or marks
   the interface row `IMPORT_STATUS = ERROR` (rejected). The base rows carry
   `CREATED_REQUEST_ID` = this import child request id.
3. **`ImportBillingEventReportJob`** (downstream report) — a child report job that writes a BIP
   XML with per-row rejection detail (`G_6` interface-row snapshot with `IMPORT_STATUS`, `G_7`
   nested per-row `ERROR_CODE` / `MESSAGE_TEXT`). This XML is the authoritative per-row error
   source because the interface table is purged. The gold harness does not download this XML;
   see the BAD-row caveat below.

Full ParameterList spelled out: the import job **ImportBillingEventJob has no parameters** — the
one and only ParameterList value is the literal `#NULL`.

## Discovery (portability — run at load time, read-only BIP)

One discovery step, `BE_REF`, picks a contract line that already has many accepted USD billing
events (invoice-type event, NULL task) and returns every reference the CSV needs, so the fixture
runs on any pod that ships the standard Projects demo contracts:

```sql
SELECT * FROM (
  SELECT h.contract_number CONTRACT_NUMBER,
         l.line_number      CONTRACT_LINE_NUMBER,
         p.segment1         PROJECT_NUMBER,
         tl.event_type_name EVENT_TYPE_NAME,
         be.bill_trns_currency_code CURRENCY_CODE,
         (SELECT hou.name FROM hr_all_organization_units hou
            WHERE hou.organization_id = be.organization_id AND ROWNUM=1) ORGANIZATION_NAME,
         (SELECT bu.bu_name FROM fun_all_business_units_v bu
            WHERE bu.bu_id = be.business_unit_id) BU_NAME,
         (SELECT ctv.name FROM okc_contract_types_vl ctv
            WHERE ctv.contract_type_id = h.contract_type_id AND ROWNUM=1) CONTRACT_TYPE_NAME,
         COUNT(*) CNT
  FROM pjb_billing_events be
  JOIN okc_k_headers_all_b h  ON h.id = be.contract_id
  JOIN okc_k_lines_b       l  ON l.id = be.contract_line_id
  JOIN pjf_projects_all_b  p  ON p.project_id = be.project_id
  JOIN pjf_event_types_b   etb ON etb.event_type_id = be.event_type_id
  JOIN pjf_event_types_tl  tl  ON tl.event_type_id = be.event_type_id
        AND tl.language = USERENV('LANG')
  WHERE be.bill_trns_currency_code = 'USD'
    AND be.task_id IS NULL
    AND etb.invoice_flag = 'Y'
    AND NVL(etb.end_date_active, SYSDATE+1) > SYSDATE
  GROUP BY h.contract_number, l.line_number, p.segment1, tl.event_type_name,
           be.bill_trns_currency_code, be.organization_id, be.business_unit_id,
           h.contract_type_id
  HAVING COUNT(*) >= 25
  ORDER BY COUNT(*) DESC, h.contract_number, l.line_number
) WHERE ROWNUM = 1
```

Discovered values on the demo pod 2026-07-19 (108 real accepted events back this exact combo):

| Token | Value |
|---|---|
| `${CONTRACT_NUMBER}` | `C10013` |
| `${CONTRACT_LINE_NUMBER}` | `1` |
| `${PROJECT_NUMBER}` | `PCS10013` |
| `${EVENT_TYPE_NAME}` | `Percent Spent Billing` (an invoice-flag event type) |
| `${CURRENCY_CODE}` | `USD` |
| `${ORGANIZATION_NAME}` | `Consulting West US` |
| `${CONTRACT_TYPE_NAME}` | `Sell: Project Lines Soft Limit` |
| (BU, for context) | `US1 Business Unit` |

The event-type NAME the FBDI validates against lives in `PJF_EVENT_TYPES_TL.EVENT_TYPE_NAME`
(keyed by `EVENT_TYPE_ID`, invoice/revenue flags in `PJF_EVENT_TYPES_B`) — NOT in any PJB table.
This was the field that defeated earlier attempts; it is now discovered, not guessed.

## Rows in the fixture

| SOURCEREF (natural key) | Contract | Event type | Amount | Meaning |
|---|---|---|---|---|
| `${PREFIX}RT-BE-G1` | `${CONTRACT_NUMBER}` (C10013) | `${EVENT_TYPE_NAME}` | 1 | GOOD |
| `${PREFIX}RT-BE-G2` | `${CONTRACT_NUMBER}` (C10013) | `${EVENT_TYPE_NAME}` | 2 | GOOD |
| `${PREFIX}RT-BE-BAD1` | `ZZINVALID-${PREFIX}` (no such contract) | `${EVENT_TYPE_NAME}` | 3 | BAD — invalid contract → deterministic rejection |

CSV column order (78 positional fields, headerless) matches the FBDI generator
`dmt_billing_event_fbdi_gen_pkg` and the seed `dmt_upload_fbdi_metadata.sql` (PJB_BILL_EVENTS):
1 SOURCENAME, 2 SOURCEREF, 3 ORGANIZATION_NAME, 4 CONTRACT_TYPE_NAME, 5 CONTRACT_NUMBER,
6 CONTRACT_LINE_NUMBER, 7 EVENT_TYPE_NAME, 8 EVENT_DESC, 9 COMPLETION_DATE (MM/DD/YYYY),
10 BILL_TRNS_CURRENCY_CODE, 11 BILL_TRNS_AMOUNT, 12 PROJECT_NUMBER, 13 TASK_NUMBER (empty —
accepted events have NULL task), 14 BILL_HOLD_FLAG=N, 15 REVENUE_HOLD_FLAG=N, 16-78 empty.

## Verification (read-only BIP, direct single-table reads)

GOOD → base table:
```sql
SELECT be.sourceref, be.event_id, be.event_num, be.bill_trns_amount
FROM pjb_billing_events be
WHERE be.sourceref LIKE '<prefix>RT-BE-%';
-- expect two rows: <prefix>RT-BE-G1 and <prefix>RT-BE-G2, each with a real EVENT_ID
```

BAD → interface error (if read before the purge wins the race):
```sql
SELECT i.sourceref, i.load_request_id, i.import_status
FROM pjb_billing_events_int i
WHERE i.load_request_id = <load_request_id>;
-- <prefix>RT-BE-BAD1 with IMPORT_STATUS = 'ERROR'
```

BAD absent from base:
```sql
SELECT COUNT(*) FROM pjb_billing_events WHERE sourceref = '<prefix>RT-BE-BAD1';  -- 0
```

## Caveat — interface table is purged after import

`PJB_BILLING_EVENTS_INT` is **unconditionally purged** once `ImportBillingEventJob` finishes
(both accepted and rejected rows are deleted — Oracle MOS 2534525.1). The per-row rejection text
survives only in the `ImportBillingEventReportJob` XML. Because of this the direct interface read
can race the purge: on some runs it returns the BAD row with `IMPORT_STATUS = ERROR`, on others
it returns 0 rows. The recipe therefore sets `"bad_proof_is_absence": true`, an opt-in flag
honored by `harness/verify.py`: when the interface read comes back empty (purged), the
authoritative BAD proof is that the bad key is **absent from the base table** while the two good
keys from the SAME load reached base with real ids. Either way the fixture proves the row was
rejected — it never fakes an error. Downloading the report XML for the exact error string
(e.g. `PJB_INVALID_CONTRACT`) is a possible future enhancement via the ESS output-download SOAP
path; it is not needed to prove the two directions.

## Live evidence

- **2026-07-19, prefix 49183, load req 9763533** (SUCCEEDED): 2/2 good → `PJB_BILLING_EVENTS`
  (EVENT_IDs 100002547171788 / 100002547171789, event nums 70/71, amounts 1/2,
  CREATED_REQUEST_ID 9763536); bad row absent from base; interface already purged (0 rows) →
  BAD proven by base-absence.
- **2026-07-19, prefix 52922, load req 9763577** (SUCCEEDED): 2/2 good → `PJB_BILLING_EVENTS`
  (EVENT_IDs 100002547246605 / 100002547246606, event nums 72/73, amounts 1/2); **bad row read
  in `PJB_BILLING_EVENTS_INT` before purge with `IMPORT_STATUS = ERROR`** AND absent from base.
  `run_object.py` returned `pass: true` both directions.

## Reload

`python harness/run_object.py BillingEvents` — picks a fresh numeric prefix, re-discovers the
references on the target pod, rebuilds the zip, loads, polls, verifies. Reloadable without
collision because the prefix is stamped onto SOURCEREF and EVENT_DESC and the event numbers are
assigned by Fusion at import.
