# Run 234 (prefix 10115) — HCM records, real Fusion outcome

Read-only investigation. No code changed, no pipeline run, no reconciliation re-run.
Live HDL error messages were pulled from Fusion (read-only GET on the dataset
`/child/messages` endpoint, `hcm_impl`); base tables were checked read-only via BIP.

## Summary counts (7 records asked about)

| Outcome | Count | Records |
|---|---|---|
| LOADED to a Fusion base table | **0** | none |
| FAILED at Fusion (real HDL error, dataset-level) | **7** | all 7 |
| Genuinely absent / nowhere | 0 | none |

**The owner's claim holds: none of the 7 is "genuinely nowhere."** Every one reached
Fusion, was processed by the HCM Data Loader, and was rejected there with a real,
readable error. Nothing silently vanished. The reason they are stuck at
`TFM_STATUS='GENERATED'` in our DB is a reconciler attribution gap, explained below —
not a lost record.

Critically: **the Worker "Regina Tester" (10115RT-WKR-G1) did NOT load either.** Our DB
marked the Worker TFM row `LOADED`, but that is wrong — the HDL dataset reported
`Load: 0 ok / 2 err`, the follow-up PersonId lookup found nothing, and BIP confirms no
person `10115RT-WKR-*` exists in `PER_ALL_PEOPLE_F` for this run's prefix. (Reginas from
*other* runs — prefixes 10052, 10053 — do exist; run 234's does not.) So of the whole
run-234 worker chain, **zero HCM rows reached any base table.**

## The three HDL datasets (all terminal ORA_IN_ERROR)

| Object | HDL RequestId | Dataset status | Import ok/err | Load ok/err |
|---|---|---|---|---|
| Workers | 9773545 | ORA_IN_ERROR | 9 / 0 | 0 / 2 |
| PayrollRelationships | 9773661 | ORA_IN_ERROR | 0 / 0 | 0 / 0 |
| TalentProfiles | 9773687 | ORA_IN_ERROR | 0 / 0 | 0 / 0 |

(Assignments 9773645 also ORA_IN_ERROR, load 0/2 — same root cause as Workers; not in scope but confirms the whole worker chain failed to load.)

## Per-record outcome

### Workers dataset 9773545

1. **Workers | Person Name "Regina Tester" (person 10115RT-WKR-G1, PersonName section) | FAILED**
   Real Fusion HDL error on this worker's WorkTerms line:
   `SSID=ET-RT-WKR-G1_TRM — "When multiple changes exist for a single day, only one can be
   identified as the latest change."` This WorkTerms/effective-date error fails the whole
   worker (all sections load as one Worker.dat), so the GLOBAL PersonName never persisted.
   Endpoint: `dataLoadDataSets/9773545/child/messages`.
   Base check: `PER_PERSON_NAMES_F` / `PER_ALL_PEOPLE_F` have **no** `10115RT-WKR-G1` row
   (BIP, fin_impl). GENUINELY-ABSENT from base, but NOT genuinely nowhere — it reached the
   loader and errored there.

2. **Workers | Work Relationship 10115RT-WKR-G1 | FAILED** (same dataset, same cause)
   The work relationship rides in the same Worker.dat as the WorkTerms line that raised
   "only one change can be the latest." Load 0 ok / 2 err. No `PER_ALL_ASSIGNMENTS_M` /
   work-relationship row for `10115RT-WKR-G1` in base (BIP). FAILED at Fusion.

   Note: the BAD worker `10115RT-WKR-B1` (not one of the 7 asked, but in the same dataset)
   errored with `"The WorkerName SDO, LastName attribute value is required."` — that one DID
   get attributed to its TFM row (it has a real SourceSystemId) and is correctly `FAILED`.

### PayrollRelationships dataset 9773661

3. **PayrollRelationships | 10115RT-WKR-BPAY | FAILED**
4. **PayrollRelationships | 10115RT-WKR-G1 | FAILED**
   Both fail for the **same file-level reason** — the entire `.dat` was rejected before any
   row was read. Real Fusion HDL messages (all with `SourceSystemId = null`):
   - `"The PayrollRelationship file name isn't valid. You need to use the name of a
     top-level supported business object as the file name."`
   - `"The PayrollRelationships_234.zip file doesn't contain valid data files."`
   - `"Your file can't be processed as it has critical errors. Review the messages raised,
     make corrections, and resubmit the file."`
   Root cause: the generator names the file/business object `PayrollRelationship`, which is
   not a loadable top-level HDL object. Per `objects/PayrollRelationship/README.md`, the
   loadable object is **`AssignedPayroll`** (the `.dat` must be `AssignedPayroll.dat`). So
   the DMT generator is emitting the wrong object name and the whole file bounces.
   Base check: zero rows in `PAY_PAY_RELATIONSHIPS_DN` for `10115RT-WKR-*` (BIP). FAILED at
   Fusion, at the file level (Import 0/0, Load 0/0 — nothing was even parsed).

### TalentProfiles dataset 9773687

5. **TalentProfiles | Talent Profile 10115RT-WKR-BPROF | FAILED**
6. **TalentProfiles | Talent Profile 10115RT-WKR-G1 | FAILED**
7. **TalentProfiles | Profile Item 10115RT-WKR-G1-COMPETENCY | FAILED**
   The whole Talent Profile file was rejected because the **ProfileItem METADATA line
   (line 4) uses attributes the V2 ProfileItem object does not accept.** Real Fusion HDL
   messages (`SourceSystemId = null`, `DatFileName=TalentProfile.dat`, `FileLine=4`):
   - `"...the TalentProfileId(SourceSystemId) attribute is unknown for V2 version of the
     ProfileItem business object."`
   - `"...the Rating attribute is unknown for V2 version of the ProfileItem business
     object."`
   - `"...the ContentItemName attribute is unknown for V2 version of the ProfileItem
     business object."`
   - `"...the ContentTypeName attribute is unknown for V2 version of the ProfileItem
     business object."`
   - `"The file definition for the Talent Profile business object has critical errors. The
     data for the Talent Profile object should not be loaded until these issues are
     resolved."`
   - `"Your data set couldn't be processed: ... Exception has occurred in one of the child
     jobs."`
   Because the ProfileItem METADATA is invalid, the loader rejects the entire Talent
   Profile file, so the parent profiles (BPROF, G1) never load either — even though the
   parent error is really only in the child section. Contrast the working gold fixture
   (`objects/TalentProfiles/README.md`): it attaches items by `ProfileCode` and uses
   `QualifierId1`/`QualifierId2`; the DMT generator is emitting a different, rejected
   ProfileItem attribute set (`TalentProfileId(SourceSystemId)`, `ContentTypeName`,
   `ContentItemName`, `Rating`).
   Base check: zero rows in `HRT_PROFILES_B` for `10115RT-WKR-*` (BIP). FAILED at Fusion.

## Why they are stuck at GENERATED (the confirmed gap)

Two separate facts combine:

**(a) Where the reconciler reads each HDL error.**
`DMT_HDL_UTIL_PKG.GET_HDL_ERRORS` (`db/packages/dmt_hdl_util_pkg.pkb.sql`, ~line 353) GETs
`dataLoadDataSets/{RequestId}/child/messages`. `RECONCILE_HDL` (same package, ~line 393)
parses that JSON with `JSON_TABLE(... '$.items[*]' COLUMNS (src_ref PATH
'$.SourceSystemId', msg PATH '$.MessageText'))` and marks a TFM row FAILED only when a
message's `SourceSystemId` matches that row's key (`jt.src_ref LIKE t.<key> || '%'`, or an
exact suffix match). The per-object results packages (`DMT_WORKER_RESULTS_PKG`,
`DMT_PAY_REL_RESULTS_PKG`, `DMT_TALENT_PROF_RESULTS_PKG`) each just call this shared
`RECONCILE_HDL`.

**(b) The gap.** For PayrollRelationships and TalentProfiles, **every HDL message has
`SourceSystemId = null`** — they are file-level / METADATA-level errors, not row-level. The
`JSON_TABLE` match finds nothing, so `l_err_count = 0`. `RECONCILE_HDL` then hits its
"`ORA_IN_ERROR` but no row-level error matched → leave rows GENERATED (do not fabricate a
FAILED)" branch (`dmt_hdl_util_pkg.pkb.sql` ~line 519, the `NULL;` case). The rows stay
GENERATED. The logs confirm it: both reconciles logged `LOADED: 0 | FAILED: 0`. For the
Workers PersonName, the sole error that maps to G1 is on SourceSystemId `ET-RT-WKR-G1_TRM`
(the WorkTerms line), which does not match the PersonName TFM key under the current match
predicate, so the PersonName row was left GENERATED too.

This behavior is *intentional and honest* by design (never fabricate an outcome you
didn't observe). It correctly avoided marking things LOADED. But it leaves a real Fusion
failure un-transcribed onto the row.

**The accounting gate already caught it — the objects are NOT silently DONE.**
`DMT_QUEUE_WORKER_PKG.apply_accounting_gate` (`db/packages/dmt_queue_worker_pkg.pkb.sql`
~line 241) ran per object, found the GENERATED (unaccounted) rows, and set each object's
`WORK_STATUS='FAILED'` with the message you saw:
`"N record(s) unaccounted — not confirmed in base tables or interface error tables ...
Object cannot be confirmed."` So the run surfaces the failure at the object level; what is
missing is the **per-row error text** on the TFM rows (their `ERROR_TEXT` is empty and
`TFM_STATUS` is still `GENERATED`). There is no separate "SWEEP_UNACCOUNTED" pass that runs
after reconcile — the accounting gate IS the mechanism, and it did run. The premise that
"the sweep never marked them" is really: the *reconciler* never stamped the row-level
error, and there is no fallback that copies a file-level HDL error onto the affected rows.

## Fix roadmap

1. **Attribute file-level / null-SourceSystemId HDL errors to the run's rows.** When the
   dataset is `ORA_IN_ERROR` and there are messages but none carry a matching
   `SourceSystemId`, `RECONCILE_HDL` should still record the failure: stamp the affected
   GENERATED rows `FAILED` with the file-level `MessageText` (a whole-file rejection means
   every generated row of that object failed). This is the real gap — a dataset that fails
   as a whole must not leave rows GENERATED with empty ERROR_TEXT.

2. **Fix the Worker "LOADED" false positive.** The Worker G1 TFM row is `LOADED` while
   Fusion reported `Load: 0 ok / 2 err` and no PersonId exists. `RECONCILE_HDL`'s
   partial-success branch marks remaining GENERATED rows LOADED whenever `l_err_count > 0`,
   even if the dataset's `ObjectLoadSuccessCount = 0`. It should consult the load success/
   error counts already parsed in `POLL_HDL` and not mark anything LOADED when
   `ObjectSuccessCount = 0`.

3. **Fix the two generators (the actual data-quality defects Fusion is reporting):**
   - PayrollRelationships: emit `AssignedPayroll` as the business object / file name
     (`AssignedPayroll.dat`), per `objects/PayrollRelationship/README.md`. `PayrollRelationship`
     is not a loadable top-level HDL object — the file bounces before any row is read.
   - TalentProfiles ProfileItem: the V2 ProfileItem METADATA is emitting rejected attributes
     (`TalentProfileId(SourceSystemId)`, `ContentTypeName`, `ContentItemName`, `Rating`). Align
     the generator with the proven gold fixture (attach by `ProfileCode`, use
     `QualifierId1`/`QualifierId2`).
   - Workers: the WorkTerms section raises "only one change can be the latest for a single
     day" — a duplicate effective-date change on the terms line to fix in the worker generator.

## Evidence appendix

- HDL messages fetched live (read-only) from
  `.../hcmRestApi/resources/11.13.18.05/dataLoadDataSets/{9773545,9773661,9773687}/child/messages`
  as `hcm_impl`. Full text quoted above.
- Base-table checks (read-only BIP, fin_impl): `PER_ALL_PEOPLE_F`+`PER_PERSON_NAMES_F`,
  `PAY_PAY_RELATIONSHIPS_DN`, `HRT_PROFILES_B` — all zero rows for `10115RT-WKR-*`. Reginas
  for prefixes 10052/10053 confirm the query works and that run 234's records are simply not
  there.
- Local DB: `DMT_WORK_QUEUE_TBL` run 234 — Workers/PayrollRelationships/TalentProfiles all
  `FAILED` with "unaccounted" messages. TFM tables: Worker G1 `LOADED` (false), B1 `FAILED`
  (correct); PersonName G1, PayRel BPAY+G1, TalentProf BPROF+G1, TalentProfItem G1 all
  `GENERATED` with empty ERROR_TEXT.
