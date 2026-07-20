# Workers — gold regression fixture (HDL)

A standalone, reloadable **HDL** fixture (2 good hires + 1 bad worker) that loads
directly into Oracle Fusion HCM via the HCM Data Loader REST service (upload →
createFileDataSet → poll), with read-only BIP verification against the HCM base
table. No DMT tool code, no DMT database, is in the load path.

**Portable.** The legal employer name and business unit short code are
**discovered at load time** by a read-only BIP query against the target pod. The
new persons are created fresh (prefix-stamped PersonNumber, run-unique SSN);
their LegalEmployer / BU references are borrowed from what already exists.

## The DAT (`Worker.dat`, pipe-delimited HDL)

One `Worker.dat` inside `Workers_gold.zip`. Sections (METADATA + MERGE lines),
byte-template from the proven `test/fbdi_zips/Workers_116.zip`:

`Worker`, `PersonName`, `WorkRelationship`, `WorkTerms`, `Assignment` (the
mandatory five for a hire), plus `PersonEmail`, `PersonPhone`,
`PersonNationalIdentifier`, `PersonLegislativeData`.

**PersonAddress is deliberately omitted.** The demo pod has US address
verification enabled; the byte-template's sample street addresses fail
verification (`HRX_US_AE02`/`AE10`), and because any component failure fails the
whole worker, that blocked the good hires on the first live attempt (prefix
90214). Address is an optional component; dropping it makes the fixture portable
and the good hires clean. (If a pod needs address, supply a verifiable one.)

Three workers, all `ActionCode=HIRE`:

| Row | PersonNumber (SourceSystemId) | LegalEmployer | Purpose |
|---|---|---|---|
| GOOD-1 | `${PREFIX}DMTW001` | `${LEGAL_EMPLOYER}` (discovered) | valid → base |
| GOOD-2 | `${PREFIX}DMTW002` | `${LEGAL_EMPLOYER}` (discovered) | valid → base |
| BAD-1  | `${PREFIX}DMTW-BAD` | `DMT NONEXISTENT LEGAL EMPLOYER` | HDL error, no person |

**Tokens stamped:** `${PREFIX}` on every SourceSystemId / PersonNumber /
component key; `${LEGAL_EMPLOYER}` and `${BU_SHORT}` (discovered) on the good
WorkRelationship / Assignment; `${SSN1}`/`${SSN2}` = a run-unique 9-digit SSN of
the form `1<prefix5>00N` (starts with 1, never 9xx/000/666) so re-runs don't
collide on the national-id uniqueness rule.

**Bad-row design:** the BAD worker's `WorkRelationship.LegalEmployerName` is a
name that cannot resolve, so HCM Data Loader rejects it with a LegalEntityId
error. It reaches the loader and errors there; no person is created for it.

## The exact call (HCM Data Loader REST, credential role `hcm_impl`)

| Step | Method + URL | Body / key |
|---|---|---|
| Upload | `POST {FUSION_URL}/hcmRestApi/resources/11.13.18.05/dataLoadDataSets/action/uploadFile` | `{content: <b64 zip>, fileName}` → `ContentId` |
| Submit | `POST .../dataLoadDataSets/action/createFileDataSet` | `{contentId, fileAction:"IMPORT_AND_LOAD"}` → `RequestId` |
| Poll | `GET .../dataLoadDataSets/{RequestId}` every 30s | `DataSetStatusCode` until terminal |
| Errors | `GET .../dataLoadDataSets/{RequestId}/child/messages?onlyData=true` | per-line `SourceSystemId` + `MessageText` |

**REST resource is `dataLoadDataSets`** (not `hcmDataLoader` — that 404s; the
correct constant is in `db/packages/dmt_hdl_util_pkg.pks.sql` `C_HCM_REST_PATH`).
Terminal statuses: `ORA_COMPLETED` / `ORA_SUCCESS` / `ORA_IN_ERROR` /
`ORA_STOPPED`. `ORA_IN_ERROR` is the **expected** terminal here because the one
bad worker errors on purpose — the two good workers still load (partial success).
Immediately after createFileDataSet the data set is not yet queryable, so the
first GET may 404; the poller treats that as not-ready and retries.

## Discovery (run before build, read-only BIP, role `hcm_impl`)

Confirms a real legal employer + BU exist on the target pod:

```sql
SELECT le.name, bu.name FROM
  (SELECT otl.name FROM hr_org_unit_classifications_f c
     JOIN hr_organization_units_f_tl otl
       ON c.organization_id = otl.organization_id AND otl.language='US'
    WHERE c.classification_code='HCM_LEMP' AND otl.name='US1 Legal Entity'
      AND SYSDATE BETWEEN c.effective_start_date AND c.effective_end_date
      AND ROWNUM=1) le
  CROSS JOIN
  (SELECT otl.name FROM hr_organization_units_f_tl otl
    WHERE otl.language='US' AND otl.name='US1 Business Unit' AND ROWNUM=1) bu
```

→ `${LEGAL_EMPLOYER}` = `US1 Legal Entity`, `${BU_SHORT}` = `US1 Business Unit`.
(The HCM base tables are reached through the same `ApplicationDB_FSCM` BIP relay
using `hcm_impl` credentials — verified live; no separate HCM data source needed.)

## Verification (read-only, direct single-table read)

- **Good → base.** Direct read of `PER_ALL_PEOPLE_F` by the prefix on
  PersonNumber: `WHERE person_number LIKE '<prefix>DMTW%'`. Each good
  PersonNumber present with a real `PERSON_ID` = pass.
- **Bad → HDL error, absent from base.** The bad evidence is the load-time HDL
  message list keyed by `SourceSystemId` (`GET .../child/messages`); the base
  read above confirms the bad PersonNumber is absent.

## How to run it

```bash
cd gold_regression/harness
python run_object.py Workers --prefix <PREFIX>   # discover -> build -> upload/submit/poll -> verify
```

## Live evidence

**2026-07-19 — LIVE-PROVEN. PASS.**

Standalone load path only; verification via the read-only BIP relay only.

| Field | Value |
|---|---|
| Date | 2026-07-19 |
| Prefix | `90217` |
| HDL UCM ContentId | `UCMFA07635513` |
| HDL data set RequestId | `9762975` |
| Terminal DataSetStatusCode | `ORA_IN_ERROR` (expected: 2 good loaded, 1 bad errored) |
| Import / Load counts | import 23 ok / 0 err; load **2 ok / 1 err** |
| Discovered legal employer / BU | `US1 Legal Entity` / `US1 Business Unit` |

**Good rows → base table `PER_ALL_PEOPLE_F` (2/2):**

| PersonNumber | PERSON_ID |
|---|---|
| `90217DMTW001` | `300000331523525` |
| `90217DMTW002` | `300000331523468` |

**Bad row → HDL error, no person created (1/1):**

| PersonNumber | HDL error |
|---|---|
| `90217DMTW-BAD` | `You need to enter a valid value for the LegalEntityId attribute. The current values are DMT NONEXISTENT LEGAL EMPLOYER.` |

The two good workers reached `PER_ALL_PEOPLE_F` with real person ids; the bad
worker errored in the loader (file line 11, WorkRelationship) and created no
person. Gold zip `Workers_gold.zip` (last built at prefix 90217) kept here.

**First-attempt notes (fixed):** prefix 90214 used the wrong REST resource
(`hcmDataLoader`, 404) — fixed to `dataLoadDataSets`; and the good hires failed
on PersonAddress verification — fixed by omitting the optional PersonAddress
section.
