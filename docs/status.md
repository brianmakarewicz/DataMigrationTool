# DMT2 -- Session Status Log

## Session -- 2026-10-05 -- Stop fabricating FAILED verdicts (proven, run 229); faster runs; Item Categories load proven

**Bottom line.** The tool was quietly covering up rows it could not account for. About fourteen
objects were turning rows whose outcome it had not actually found in Fusion into made-up FAILED
verdicts. We stopped that. Reconciliation now returns either the real Fusion error for a row or
nothing at all, so a row the tool cannot account for is left honestly UNACCOUNTED instead of being
dressed up as a failure. We proved it in a full run against the live Fusion demo.

**What changed and why it matters.** We changed every reconcile query to return the real error or
nothing, and we changed the shared error-text helper so a missing error now returns null instead of
inventing the string "Import error (no details)." We deployed that change and redeployed the fourteen
affected Fusion reconcile data models in place (PR #574). This is the whole mission of the tool:
report the truth about every record, never fabricate an outcome.

**Proof -- run 229, against the live Fusion demo.** Made-up FAILED verdicts went from eleven to
zero. Twenty rows that the tool could not account for are now honestly marked UNACCOUNTED instead of
fake failures. Rows that genuinely loaded rose from seventy-eight to eighty-five. Nothing legitimate
regressed -- no row that had really loaded, and no row that had really failed with a Fusion error,
changed for the worse. The objects that flipped from fake failure to honest UNACCOUNTED were Purchase
Orders, Requisitions, AR Invoice lines, Customers account site uses, and Item Categories.

**A bonus the same fix delivered.** Two Items rows (a lot and a serial row) had been failing falsely
because the tool read the outcome before Fusion had finished. The fix now waits for Fusion, and those
two items actually load. Item Master now reads three loaded and one genuinely failed (a bad
organization row with its real Fusion error). Misc Receipts picked up more loaded rows from the same
timing fix.

**Faster runs.** Runs were slow because the tool downloaded each Fusion job's output and log files
while the run was still going. It now only asks whether the job finished and reads the outcome, and
pulls no files during the run. Runs are materially faster (PR #572).

**Un-expired the two console logins.** The two service accounts the console uses had expired; we
refreshed them so runs could reach Fusion again.

**Item Categories can load -- and one Fusion rule is a real block.** We proved item categories load by
using a catalog that allows an item to hold more than one category assignment (the eCommerce Catalog)
-- two categories physically landed in the Fusion base table (PR #575). The Purchasing catalog, by
contrast, allows only a single assignment, so a second assignment is genuinely rejected by Fusion with
error EGP-2775085. That rejection is a real Fusion functional rule, not a defect in our tool.

**The one follow-up left.** When Fusion rejects a single-assignment Purchasing category with
EGP-2775085, we do not yet capture that message onto the rejected rows, so they read UNACCOUNTED with
blank text instead of carrying the real reason. Harvesting that EGP-2775085 text onto the rejected
category rows is the remaining work (logged as a low-priority backlog item).

## Session -- 2026-10-03 -- #148 BIP transport-fault retry + #149 activity-log drill speed-up; one gating regression; Fusion pod credentials expired

**Bottom line.** Shipped two reliability fixes and proved both work exactly as intended. The one
combined regression that gates them could not be certified a full pass -- not because of these
changes, but because the Fusion demo pod is now rejecting our saved credentials pod-wide, which
stops any good row from loading. That is an environmental password expiry, independent of our code,
and it is the one thing left to clear before a clean end-to-end run.

**#148 -- a network blip no longer fails a whole batch.** When the tool asks Fusion to run a
reconciliation report and the request fails on the network (a dropped connection or an HTTP 500
with no real error inside it), it now waits a few seconds and tries again, a small fixed number of
times, before giving up. Before, a single blip failed the whole group of records. Two settings
control it: how many retries (default 2) and how long to wait between them (default 3 seconds). A
genuine Fusion error -- the kind that means we called the wrong report, not a blip -- still fails
immediately and is never retried, which is the behavior we want. Proven in the regression: the tool
retried the blips exactly as designed and left the real errors to fail loudly. (PR #568, merged.)

**#149 -- the activity-log drill no longer times out.** Opening a single log entry on the activity
page used to get slow and sometimes time out once the log table grew large. Added a database index
so that lookup is now instant: the drill opened in about 1.5 seconds over the web, where it used to
exceed the 90-second limit. Also added a safe log-cleanup routine that deletes old log rows on a
retention setting (default 90 days) but never touches recent data or active runs. Proven: the drill
is fast, and the cleanup removed 53,000 old rows while leaving recent runs intact. (PR #569, merged.)

**One honest follow-up logged (#150).** Fixing the single-entry drill revealed that the *whole-run*
activity-log list on the same page still reads the entire table because of how its filter is
written. It is about 6 seconds today and will slow as the log grows. Logged as a separate small
item; it is a console-speed issue, not a data-accounting problem.

**The blocker to flag -- Fusion demo pod credentials expired.** The regression's good rows could not
reach Fusion's base tables because the pod returned "not authorized" (HTTP 401) to both of our shared
service accounts. The pod itself is up (its public pages load fine); it is the saved passwords that
no longer match. A direct test from this machine confirmed it is the pod rejecting the credentials,
not anything in our code or local database. Loaded counts dropped from 78 in the last good run to 42
here purely for this reason. Refreshing the demo password (or waiting for the owner to) is the next
step before re-running to confirm the loaded count recovers.

**Where the backlog stands.** 150 items: 139 resolved, 4 still open (#72 TaxCards env-parked, #85 AR
line AR-blocked, #130 config objects functional-owner-blocked, #150 the activity-log list speed-up),
5 superseded, 2 stale. #148 and #149 moved to resolved this session.

## Session -- 2026-10-03 -- #147 shared reconcile settle/re-read (late-commit safety net), one regression

**Bottom line.** Added a safety net so a good record that Fusion loaded is never falsely marked
unaccounted just because our reconcile read the base table a beat before the row became visible.
Built it once in the shared reconcile path so every object benefits, proved it's safe, and logged
two honest findings the regression surfaced.

**What it does.** When an object's Fusion import finished successfully but some rows aren't yet
found in the base table, the reconcile now waits a configurable time (default 30 seconds) and
re-reads, up to a configurable number of tries (default 2), before concluding "unaccounted." A row
that appears on a retry is marked loaded with its real Fusion id; one that never appears stays
honestly unaccounted -- it never invents a result. It only kicks in when the import actually
succeeded and only for rows with no real rejection, so a genuinely-bad row or a job that crashed
outright gets no pointless wait. Two settings control it: `RECONCILE_SETTLE_SECONDS` (30) and
`RECONCILE_MAX_RETRIES` (2). Documented in the shared reconcile code and the Items notes.

**Proven.** Unit checks showed it waits and re-reads and resolves a late row (or honestly gives up).
The full regression (run 225) showed it introduced **zero new regressions** -- every object matched
the prior baseline -- and it correctly stayed dormant this run (nothing needed it), so it added no
time and no object incurred a wasted wait.

**Honest findings from the run (not caused by this change), logged as new items:**
- **#148** -- a single transient network error on a reconcile report call (not a real report fault)
  failed a whole Items partition and stranded two category rows. The fix is a small bounded retry on
  transient transport errors only -- leaving the "a real report fault must fail loudly" rule intact.
- **#149** -- the Activity-Log per-row drill can time out when the log table is very large on the
  slow local database; wants an index and periodic log pruning (separate from the earlier #145 fix).
- Environment note (no code item): one AP invoice line failed with "accounting date not in an open
  period" for today's date -- a Fusion demo period-close condition; confirm the AP period for the run
  date is open before reading it as a defect.

**Backlog now: 137 resolved, 0 partial, 5 still-open, 5 superseded, 2 stale (149).** Still-open are
the externally-blocked #72/#85/#130 plus the two new findings #148/#149.

## Session -- 2026-10-02 -- DONE: workable-items goal complete (#65 all objects, #25, #69, #145, #146), one regression

**Bottom line.** All five items are finished completely -- not one object, every object -- and proven
by a single combined regression (run 205): zero new problems except one page break this work caused,
which was then fixed and re-proven. No "mostly done."

**#65 -- rolled to every object.** The "match on the stamped reference first, then the attribute,
then the business key" reconcile logic now covers all 30 reconcile packages (the 3 done earlier plus
all 27 remaining), across five area PRs. The primary match is unchanged, so every object loads and
fails exactly as before -- the regression confirmed that for all of them. Honest limit: for two
objects (Grants, Projects) a third-tier match genuinely doesn't apply (no separate business key), and
for accounts-receivable it can't be exercised while AR invoicing is blocked by the functional owner;
those correctly use the first two tiers.

**#25 -- finished.** The naming leftovers were mostly already done or were misreads of the catalog;
the one real gap -- receipt drill screens reading empty orphan tables -- was fixed by repointing them
to the live inventory tables and dropping the orphans. The regression then caught a column the
repoint had dropped (it broke the Order-to-Cash page); that was fixed too (column restored plus a
stale saved-report cleaned), and the page now renders clean.

**#69 -- finished honestly.** The export-hygiene defects were cleaned and the reversed-log issue was
already gone. The one remaining piece -- a zero-amount AR line -- is correctly left "unaccounted": an
attempt to mark it "failed" was removed because it would have invented a Fusion error, which the
mission rules forbid; there is no real error to record until AR is unblocked.

**#145 -- fixed.** The Activity-Log drill that returned a 500 was tracing to the database streaming a
large message field twice per click and exhausting the web tier's connection pool; the fix reads the
message once and stops the whole-run report from re-rendering on a single-row drill. The pages that
failed now load in about a second.

**#146 -- fixed.** The regression tool no longer miscounts a deliberately-bad orphan row as a failed
good row, so it stops raising a phantom "regression" every run while still catching real ones.

**The combined regression (run 205).** Ran all 41 objects to completion with no manual nudging --
the local-scheduler fix (#144) holding at full scale, up to ten workers at once. Tier-1 behaviour
matched the baseline for every object. The only blocking finding was the page break above, now
fixed. One pre-existing, non-deterministic issue was found and logged as its own item (#147): the
Items reconcile sometimes reads Fusion's base table a moment before Item Import commits a row, so a
good item can be marked failed even though it did load -- not caused by this work, and it needs a
short settle/re-read before the Items reconcile.

**Backlog now: 136 resolved, 0 partial, 4 still-open, 5 superseded, 2 stale (147).** The 4 still-open
are all out of our hands or newly-logged: #72 (tax cards, parked/env), #85 (AR line id, AR blocked),
#130 (config objects, functional owner), #147 (the Items timing race, new). Nothing from the
greenlit list remains.

## Session -- 2026-10-02 -- CHECKPOINT: full #65 rollout + #25/#69/#145/#146 (in progress)

**Bottom line (snapshot, mid-flight).** Working the five "workable now" items to full completion --
no "one object, rest staged." The big one, #65, is being rolled to ALL 27 remaining objects, not a
sample. Most of the work is merged; two small pieces are still finishing and the single combined
regression that gates the verdict flips has not run yet. This entry records exactly where things
stand so the record is current.

**#65 -- three-tier reconcile match, full rollout to all 27 objects.** Done as five parallel agents
by area, each mirroring the proven Workers/GL/Customers template on its own results packages (leaf
packages, no cross-dependency), each proving tier-1 behaviour byte-equivalent + 0 invalid + a
tier-2/3 fallback. No schema changes were needed -- the transform tables already carry the key
columns. PRs: P2P 6 objects (#553, merged), GLBudgets/Assets/MiscReceipts/BillingEvents (#554,
merged), HCM group 2, 7 objects (#556, merged), HCM group 1, 5 objects (#558, merged), O2C/Projects
5 objects (#560, open). Honest limit recorded on the item: for Grants and Projects a third-tier
match is genuinely not applicable (no business key distinct from the stamped reference), and for AR
it can't be exercised because AR invoicing is blocked by the functional owner -- those three keep
the first two tiers, which is correct. PENDING: merge #560, then ONE combined regression across the
whole pipeline proving zero new problems and that every object still loads/fails as before; only
then does #65 flip to resolved.

**#25 -- naming-registry leftovers.** Reviewed (merged, #557): most were already done or were
misreads of the catalog (same as the earlier null-row note). One genuine gap remains and is being
finished now -- the orphan receipt tables that eight MiscReceipts drill screens still read from
(so those screens show empty counts); the fix repoints the screens to the live inventory tables and
drops the orphans (PR in flight).

**#69 -- reconcile cleanup.** APEX-export defects cleaned (merged, #559): removed references to four
pages that don't exist and deleted a leftover old button template; clean import proven. The AR
zero-amount line now reads "failed" with a real reason instead of "unaccounted" (in #560, open).

**#145 -- the Activity-Log drill that returns a 500.** Being diagnosed and fixed now; the agent is
finishing the fix and the proof that the drill renders.

**#146 -- regression-tool false alarm. DONE (merged, #555).** The tool now counts a deliberately-bad
orphan row as bad (not as a failed-good row), so it stops raising a phantom "regression" every run,
while still catching real ones. A reporting-tool fix -- no pipeline run needed, so it's closed.

**Backlog now: 132 resolved, 2 partial (#65, #25 -- both finishing), 5 still-open, 5 superseded,
2 stale (146).** Remaining after this wave lands: the externally-blocked items (#72 TaxCards, #85 AR
line id, #130 config objects) that wait on the functional owner / environment. Next concrete steps:
finish #145 and the #25 receipt-table repoint, merge #560, run the one combined regression, then
flip #65/#25/#69 to their final verdicts.

## Session -- 2026-10-02 -- Backlog #138 + #144 (last two owner decisions), one regression

**Bottom line.** The two items that were waiting on an owner decision are done and proven by one
regression (run 204): zero new problems versus the last known-good run. That finishes the whole
greenlit list.

**#138 — supplier "mark it failed" fix.** Each of the five supplier loaders now validates and then
flags only its own object's rejected staging rows as failed, so a bad supplier/address/site/contact
row no longer sits in limbo and get re-rejected every run. Proven: the good rows still load exactly
as before, and the deliberately-bad orphan rows now correctly read "failed."

**#144 — scheduler reliability, fixed on restart (your call).** Added a database startup hook: every
time the database comes up (which is what a container restart does), it clears out any leftover
worker jobs that were killed mid-run by the previous shutdown -- those orphans are what used to pile
up and choke the run poller. It also leaves the always-on poller alone, and can never block the
database from opening. The job-slot limit was raised from four to thirty-two (sized to the
pipeline's real peak of ~15-20 workers running at once, plus the poller, plus headroom -- not
padding). Proven two ways: a real container restart auto-cleared planted orphan jobs and kept the
poller; and this regression ran all forty-one objects straight through with no manual nudging at all
-- peaking at ten workers at once, which the old four slots could never have carried. The thing that
stalled every prior run is fixed.

**Where the backlog stands:** 131 resolved, 2 partial (#65 reconcile-match rollout and #25 naming
registry items -- both have their hard part done), 6 still-open, 5 superseded, 2 stale, of 146. The
remaining still-open items are the externally-blocked ones (functional-owner / environment /
infrastructure) plus the two small follow-ups this work logged (#145 the pre-existing p54 drill 500,
#146 the regression-tool labeling gap). Two environment-gated Fusion deploys are still pending when
someone has access: the #94 comparison data models and the #60 W-2 report.

## Session -- 2026-10-01 -- Backlog #25 naming sweep (views + APEX), on its own

**Bottom line.** Renamed all 78 run-detail drill views to the house naming convention and repointed
the nine console pages that read them, so the screens still show their data. This was a name-only
change -- no logic touched -- so it was verified by a clean install and an all-pages screen check
rather than a full data-load run.

**Done and proven.** 78 views renamed to the `*_V` suffix, the install list and a safe re-runnable
migration updated, and the nine object pages in the console repointed. Checks: zero broken database
objects, all 78 views return data, and the console re-imported and rendered all 41 pages with no
blank screens (including the run-detail, object-detail and record-detail drill pages).

**Left for a follow-up (named in the backlog item).** The smaller naming cleanups -- a few stray
registry rows, some upload filenames, an unregistered Grants file, orphaned receipt tables -- were
deliberately left so this stayed one coherent, verified change. Two of the original cleanup notes
turned out not to apply: the Payroll-relationships rename is already done in live code, and the
"delete the null row #120" note was based on a misread of the data (a null value there is normal for
~156 inactive rows), so that row was correctly left alone.

**Batch status.** This finishes the owner-greenlit list. Everything is resolved or honestly
dispositioned except two items that need the owner's decision: how to fix the supplier validation
call, and the go-ahead to raise the local database's job limit and add a pre-run job cleanup.

## Session -- 2026-10-01 -- Backlog "do-it" wave close-out (nine items, parallel), one regression

**Bottom line.** Nine backlog items the owner greenlit were worked in parallel, merged to main, and
proven by one regression (run 203): zero new problems versus the last known-good run. Seven are
fully resolved, one is partial (the hard part is done and proven on three objects, the rest is a
mechanical repeat), and one -- value sets -- is built but can't finish on this demo pod.

**What was resolved.**
- **#19** -- removed leftover dead code in four transforms; every cross-object reference already
  goes through the shared resolver. No behaviour change.
- **#23** -- deleted the old interface-only AR reconcile report (it even pointed at the frozen old
  stack); the real base-table check is now the only AR path.
- **#60** -- the HCM W-2 reconcile was asking Fusion for a report under the wrong name; fixed the
  name in both the registry and the deploy script. (Still needs the report deployed to Fusion to
  verify, which is environment-blocked here.)
- **#62** -- added the auto-run CI workflow (self-hosted runner + a browser UI check); a person
  still has to install the runner once.
- **#89** -- documented the dynamic-SQL exception for the file-upload package, matching the one the
  queue engine already carries (owner chose "document it" over a rewrite).
- **#90** -- finished the table-name-versus-import-tab audit across all nineteen remaining objects;
  no real defects, just cosmetic name drift, plus a few spec-comment fixes.
- **#94** -- extended the value fingerprint to the other money-less objects (customers, projects,
  contracts, workers), each checked live against Fusion. (The reports need deploying to Fusion for
  the match flag to light up in production.)

**Partial.**
- **#65** -- the new "match on the stamped reference first, then the attribute, then the business
  key" reconcile logic is built and proven on GL Balances, Workers, and Customers (run 203 matched
  the baseline exactly). The same small change still needs repeating on the other ~27 objects.

**Built but blocked.**
- **Value sets (part of #130)** -- replaced the dead web-service load with a real file-upload +
  import-job pipeline. It submits correctly, but the import process isn't turned on for this demo
  pod, so the load never runs. Ready for a functional owner to enable it.

**Two new items recorded.** A pre-existing Activity-Log page drill that returns a 500 (not caused by
this work -- no page files changed), and a cosmetic mislabel in the regression tool that counted a
bad test row as a good one and caused a false alarm this run.

**Still waiting on the owner:** #138 (how to fix the supplier validation call) and #144 (go-ahead
to raise the local job limit and add a pre-run job cleanup). **Next:** #25, the naming sweep,
including the APEX page updates.

## Session -- 2026-10-01 -- Backlog batch 7 (#71) + final sweep disposition of the remaining items

**Bottom line.** Fixed one more real code item and then gave every remaining backlog item an
explicit, written disposition, which completes the batch-by-batch sweep of the backlog. The
backlog now stands at 122 resolved, 4 partial, 11 still-open (each with a stated reason), 5
superseded, 2 stale, out of 144.

**What was resolved (#71).** For Projects, Fusion's import job is only a thin "request accepted"
wrapper -- it reports success before the records are actually created by a background service, so
the reconcile could run too early and see nothing. The shared report-capture step now waits for
that background job to finish (bounded to 10 minutes; if it times out, the rows stay in a
not-done state rather than being given a false verdict) before the reconcile reads the result.
Proven on a Projects run: the wait kicked in, good projects loaded with real ids, the bad row
failed with a real error. The same step is used by a few other objects; the change only makes the
reconcile wait for data it was going to read anyway, so it cannot turn a loaded row into a
failure. The full all-objects confirmation run is pending behind the local scheduler issue (#144).

**Why the remaining 15 items are not closed (each is annotated in the backlog).**
- **Blocked by Fusion setup or environment (can't be proven):** #60 (HCM recon web-service 500 on
  the pod), #85 (AR invoice-line id -- AR invoicing loads nothing until the functional owner acts),
  #130 (config objects on file/workbook/setup-manager paths the owner controls), #72 (tax-card
  recon, parked and env-blocked).
- **Standing decisions / owner instruction:** #19 (cross-reference rollout is break-fix-only),
  #138 (owner said leave it), #89 (removing dynamic SQL from the upload path waits on a design
  decision).
- **Infrastructure, not product code:** #62 (needs a self-hosted CI runner installed), #144 (the
  local scheduler reliability fix -- recommended next, since it is what slows every regression).
- **Too large/entangled to batch safely -- need a dedicated solo run:** #25 (rename sweep across
  all views and shared seeds), #65 (reconcile-on-reference rewrite across every results package).
- **Core done, mechanical rollout remains (partial):** #23 (two-tier recon -- only AR left, and AR
  is blocked), #90 (table-name audit -- method set, other objects remain), #94 (money-less checksum
  -- mechanism proven on suppliers, other objects remain).

**Recommended next step.** Fix #144 (raise the local database's job-process limit and add a
pre-run cleanup of leftover jobs). It is the single thing most slowing the regressions, and
clearing it would make the remaining solo items (#25, #65) and any future work much faster to
verify. Also note: several test runs (195 scenario full, 200, 201 tails) were left mid-flight by
that scheduler starvation -- a Docker restart will clear them.

## Session -- 2026-10-01 -- Backlog batch 6 close-out (regression test data), proving the Batch-3 deferrals

**Bottom line.** Three test-data backlog items were resolved, and doing so finally proved three
earlier fixes that had shipped but never been exercised. The root cause behind all of them was the
same: good and bad test rows for four objects existed in the seed but had never been captured into
a scenario the regression actually runs.

**What was resolved.**
- **#143** -- added good and bad rows for Units of Measure, Lookups, Cash Banks, and item receipts
  (including lot and serial rows) into a new write-once test scenario, and pointed the regression at
  it. Each object was then proven on its own: good rows loaded into Fusion and the reconcile
  confirmed them; bad rows failed with real errors. Also fixed two real latent bugs found along the
  way -- nine tables were missing from the scenario cleanup list (so repeat runs would pile up
  duplicates), and the item-receipt serial numbers now vary per scenario so they stop colliding.
- **#134** -- a good item-receipt row now loads to its Fusion base table (previously item receipts
  had only bad rows and loaded nothing). Proven: a plain receipt plus a lot row plus a serial row
  all loaded, with no unaccounted rows.
- **#61** -- the worry was that the local worker seed had triplicate copies causing Fusion to reject
  "multiple data lines". On inspection the seed already had one copy; the duplicates were only in an
  old scenario the regression never uses. Proven by the generated file having exactly one line per
  worker, and the worker loading.

**Earlier fixes now proven (were "shipped but not exercised" after batch 3).**
- **#135** (Units of Measure + Lookups reconcile), **#136** (Cash Banks reconcile), and **#137**
  (item-receipt unique numbers) were merged in batch 3 but the test scenario had no rows for them.
  With the batch-6 data they are now proven end-to-end in per-object runs.

**Regression note (honest).** Each of the four objects was proven in its own targeted run (good
loads, bad fails, reconcile confirms). The combined full-scenario confirmation run was left in
progress because the local database's job scheduler starves the run poller (the known local issue
#144); pushing it to finish needs a container restart. Batch 6 changed only test data -- no
pipeline code -- so no other object's behavior can change from it, and every changed object is
proven in its own run. So the batch is closed on that per-object evidence rather than blocking on
the slow full run.

## Session -- 2026-10-01 -- Backlog batch 5 close-out (Banks REST + Assets + PO buyer + page-84), one regression

**Bottom line.** Four more backlog items were worked in parallel and closed out as one batch,
proven by a single full regression (run 195). All four are fully resolved. The regression found
zero new problems compared to the last known-good run.

**What was resolved.**
- **#39** -- bank accounts used to load through the old flat-file method. They now load through
  Fusion's web service (banks, then branches, then accounts, in order), and the old flat-file
  generator was removed. Proven live: a good bank/branch/account chain landed in Fusion with real
  ids, and a bad bank came back with Fusion's real "country is not valid" error.
- **#78** -- a purchase order's buyer given by name was falling back to a raw number because the
  name-to-id lookup had never been filled in. Added the lookup (built from Fusion's buyer list)
  so the buyer now resolves by name. Proven: 159 buyers loaded, and the sample buyer resolves by
  name instead of the number.
- **#139** -- the Assets book table stored the asset's id, which repeats across an asset's
  corporate and tax books, so the uniqueness check was wrong. It now stores an asset-plus-book
  key that is unique per book. Proven: the id auditor's Assets-book check passes.
- **#142** -- the two Run Pipeline page controls that were removed earlier as having nothing
  behind them now have real settings behind them: one makes a run check that an object's parent
  loaded first, the other pins which earlier run a run depends on. Both are saved on the run and
  actually obeyed. The regression harness was updated to match the new settings so it keeps
  testing the real submission path.

**One thing checked and cleared.** During this batch several helper agents reported ten
comparison packages showing as broken on the shared local database. That turned out to be
leftover state from deploying files one at a time, not a real problem: a full clean install
recreates the shared data type and recompiles all ten, and the regression confirmed zero broken
objects after a full install. No code fix was needed.

**Known ongoing local issue (item #144).** The local database's job scheduler again ran slowly
mid-run (it starves the run poller while long file-generation jobs hold the scheduler slots). The
run still completed; it was nudged along with status-only actions and no staged rows were reset.
This is the local-environment reliability item already on the backlog.

## Session -- 2026-10-01 -- Backlog batch 4 close-out (engine + suppliers + CSV + comparison), one regression

**Bottom line.** Six more backlog items were worked and closed out as one batch, proven by a
single full regression (run 174). Three are fully resolved, two are partial (the core is done,
a mechanical rollout to more objects remains), and one was already done under an earlier change.
The regression found zero new problems compared to the last known-good run.

**What was resolved.**
- **#38** -- the run-cancel feature. Already gone. A check found it was removed back when the
  engine was first built; the only "cancel" words left in the code are Fusion's own job-state
  names and ordinary close-this-dialog buttons. Nothing to change.
- **#43** -- the two big supplier packages (one shared transform, one shared reconciler, each
  covering all five supplier objects) were split into one transform and one reconciler per
  object, which is the house standard. The split only moved code, it did not rewrite it. Run 174
  proved all five supplier objects load and fail exactly as before.
- **#76** -- the CSV loaders used to flip the database's date format at run time. They now state
  the exact date format on each conversion instead, so loading no longer depends on a mutable
  session setting. Proven by deliberately setting a wrong session date format and showing the
  loaders still parse correctly. Run 174 had no date errors.

**What is partial (core done, more to do).**
- **#90** -- checked whether the Assets staging/transform table names match the Fusion import
  file tabs. They do not match by name, but the data is modeled correctly, so this is cosmetic
  naming drift, not a real defect. Fixed a wrong file list in one spec comment and wrote the
  audit into the Assets notes. The same name-vs-file check still needs doing for the other objects.
- **#94** -- objects with no money amount (suppliers, customers, projects, and so on) had nothing
  to compare on the post-run comparison page. Added a business-key checksum so they get a real
  match signal, and wired it for suppliers first. Checked live against Fusion that the supplier
  name actually comes from the party table (not where the first attempt assumed), and that the
  existing success count cannot be broken by the new checksum. The other money-less objects still
  need the same wiring, each against its own verified Fusion source.

**Superseded.**
- **#77** -- the On-Failure control on the Run Pipeline page already shipped and was proven. The
  two remaining controls on that page need new scheduler settings and are tracked as item #142.
  So #77 is closed as superseded by #142.

**New backlog item.** **#144** -- on the local Docker database the job scheduler sometimes jams
mid-run (a numeric-overflow error inside Oracle's scheduler, made worse by the database allowing
only four job processes), which stalls a regression and forces manual cleanup and a container
restart. This is a local-environment reliability problem, not a product defect, but it makes
regressions slow. The fix is to raise the job-process limit and add a pre-run cleanup of leftover
jobs.

## Session -- 2026-10-01 -- Backlog batch 3 close-out (GL + Projects + recon reports), one regression

**Bottom line.** Seven backlog items were fixed, merged to main, and closed out as one batch.
A single full regression run (run 169, on main at commit 365a739) found zero new problems
compared to the last known-good run. Four of the seven fixes were proven end-to-end by that
run. The other three were merged and checked on their own, but the regression scenario has no
test data for the objects they touch, so they were not exercised end-to-end. That gap is now
its own backlog item so the next run proves them.

**What was resolved and proven in run 169.**
- **#92** -- GL Balances reconciliation now uses the same shared result-reader every other
  object uses, instead of its own one-off reader. The GL line proof (journal header and line
  number together) still gets saved. Run 169: 2 GL journal lines loaded, reconciled through
  the shared reader.
- **#87** -- GL Budgets was trying to save a budget-version id that Fusion blocks from being
  read back. It now saves the budget cell key instead (ledger, budget, period, and account
  combined). The column was widened from a number to text to hold it. Run 169: 2 budget cells
  loaded with the cell-key proof saved.
- **#64** -- Projects can now optionally accept a task whose parent project was already loaded
  in an earlier run. This is off by default, so nothing changes unless someone turns it on.
  Run 169: projects and project tasks loaded as before.
- **#93** -- New read-only end-of-run summary that counts what landed in Fusion for each object.
  Run 169: it ran cleanly and reported no errors.

**What was fixed and merged but NOT exercised by run 169 (test-data gap, see new item #143).**
- **#135** -- The Units-of-Measure and Lookups reconcile reports were matching Fusion rows by a
  custom marker that these objects do not carry, so they could never confirm a load. They now
  match on the natural business key. The implementer verified the reports against real loaded
  ids. The regression scenario stages no UoM or Lookups rows, so this was not re-proven in run 169.
- **#136** -- The CashBanks reconcile report existed and was correct, but it had been left out of
  the deploy list, so the pipeline kept using an old one that returned zero. Adding it to the
  deploy list fixes the zero-confirmed result. Same situation: no CashBanks rows in the scenario.
- **#137** -- In item receipts (MiscReceipts), lot and serial rows in a single Fusion load could
  share the same interface number and collide. The fix makes each parent's number unique per load
  and rewrites the child lot rows to match, so the result-reader still ties them together. A lot
  with no resolvable parent is now failed with a real reason and kept out of the file sent to
  Fusion. Proven on its own with a before/after collision test (2 lot rows went from unaccounted
  to fully accounted). The scenario has no fresh lot/serial rows, so it was not re-proven in run 169.

**New backlog item.** **#143** -- the regression scenario needs a few good and bad rows added for
MiscReceipts (lot/serial), Units-of-Measure, Lookups, and CashBanks, so the next run proves the
three fixes above end-to-end. The rows must be added as new write-once test data, never by changing
existing scenario rows.

**Housekeeping.** Also fixed a stale typo in the backlog data (one item's status read "STILLOPEN"
with no space, so it was dropping out of the summary counts). The backlog summary now totals 143
items correctly.

## Session -- 2026-09-30 -- Backlog batch close-out (UI + view-fix items), reviewer-grouped

**Bottom line.** Closed out a batch of backlog items that just merged to main and recorded two
new ones. The team is now working the backlog in batches grouped by which reviewer area they
belong to, and the automated goal-loop is driving those batches.

**What was resolved.**
- **#45** -- RESOLVED. PR #510 added the "Prefixed key(s)" column to all four object tables in
  section 1 of the design doc. The new column is marked red/proposed per the design-doc red-guard
  and waits for the owner to promote it to accepted.
- **#56** -- RESOLVED. PR #510. The separate requirements files it asked about never existed on
  their own; that content was always inside DMT_DESIGN.html, and GENERIC_OBJECT_FLOW.html already
  carries the current model. The one stale leftover, design_text.txt, was moved to the docs
  archive folder.
- **#54** -- RESOLVED. PR #511. On the ESS Job Detail page, each request id now links straight to
  that job's output files, the duplicate attachments column was removed, and there is a clean "no
  files" message when a job produced none. Verified on local.
- **#73** -- RESOLVED. Already done back in PR #460; the backlog label was just stale. Filtering
  the record list by object and by work item both work (checked on local: PurchaseOrders returned
  661 rows).

**What is partial.**
- **#77** -- PARTIAL. PR #512. The On-Failure control on the Run Pipeline page is wired all the way
  through and proven (a live run recorded its setting). The other two controls on that page --
  Dependent Run and Validate Upstream -- were removed because nothing in the backend stood behind
  them; they were dead UI. That remaining work is captured as a new follow-up item.

**View fix.**
- The record-detail view's ERROR_CATEGORY column was coming back empty for every error row. The
  cause was a regular expression that Oracle 26ai mis-reads. It was fixed across all 83 places it
  appears (PR #509), and the category now correctly shows TRANSFORM_ERROR, PRE_VALIDATION,
  FUSION_ERROR, and so on. Added to the backlog as RESOLVED.

**New backlog items.** Two were added: the ERROR_CATEGORY view fix above (RESOLVED), and a
follow-up to #77 to wire the Dependent-Run and Validate-Upstream controls once the scheduler
supports the backend parameters they need (still open).

## Session -- 2026-09-30 -- Config objects: verified they are wired-but-never-loaded (NOT "DDL-only/blocked")

**Bottom line.** Live checks this session corrected the status of the six configuration objects.
They were being described as "DDL-only" or "blocked/deferred". That is wrong. Each one is wired
and has a runner, but NONE of them has ever loaded a row into Fusion. Each has staged rows (STG)
but zero transformed rows (TFM). "Has a runner" is not the same as "loads".

**Verified status of the six config objects (per the owner's delivery rule -- file-loader first,
then web service, then Functional Setup Manager):**
- **ValueSets** -- must load via the FBDI / ADFdi file loader. Its REST endpoint `/valueSets`
  does NOT exist.
- **TaxConfig** -- must load via the Tax Configuration Workbook plus the "Import Tax Configuration
  Content" scheduled process (ESS). Its REST endpoints `/taxRegimes` and `/taxRates` do NOT exist.
- **PaymentTerms** -- must load via a Functional Setup Manager setup-data import. Its REST endpoint
  `standardTerms` does NOT exist.
- **GLCalendar** -- Functional Setup Manager or manual; there is no create service.
- **Lookups, UnitsOfMeasure, CashBanks** -- their REST endpoints are real and can create records,
  but loading through them is UNPROVEN. Each needs a live proving run (one GOOD row reaching the
  base table, one BAD row failing with a real Fusion error).

So: three objects are on delivery paths that are not REST at all (file loader / workbook+ESS / FSM),
and three have real REST endpoints but have never been proven. Nothing here is "done".

**Docs updated this session (docs-only PR):**
- `docs/DMT_REBUILD_PLAN.html` section 0 object-status matrix (`#objstatus`) -- the CONFIGURATION
  block now states the wired-but-never-loaded reality per object instead of "deferred".
- `docs/backlog.html` -- the config-objects item (was #130) rewritten to the verified reality;
  four new backlog items added: DFF-token-for-all rollout, carrier config table slim, finish
  Customers on Contract v1, and MiscReceipts good test data.

## Session -- 2026-09-29 -- Reconcile-hardening goal COMPLETE; full regression (run 142) PASSES with zero new regressions

**Bottom line.** The reconcile-hardening work is done and proven. A full regression run against the
live Fusion demo (run 142, prefix 93222, on local Docker, main at 977ce90) PASSED with **zero new
regressions** versus the run-351 baseline. All 34 objects / 41 work items reached a terminal state.
Totals: **74 LOADED, 79 FAILED, 0 UNACCOUNTED, 0 stuck.** Every FAILED row carries a real
Fusion/import error (Rule #1 holds). No object lost LOADED coverage; no new UNACCOUNTED or
null-error rows appeared.

**What was done (all landed on main via squash-merged PRs):**
- **Uniform LOADED promotion (#493).** Every results package now uses the same shape to promote a
  record to LOADED, gated on a real Fusion id.
- **Config-driven carrier stamp (#492).** Expenditures and BillingEvents now stamp their traceability
  carrier (Slot C) from config rather than in code. Deferred objects were added to the backlog.
- **Re-run reconcile for a run (#489).** New capability to re-reconcile a whole run
  (`DMT_QUEUE_PKG.RERUN_RUN` + a "Re-run reconcile" button on the Run Detail page, page 82). The
  automated reviewer flagged the first attempt for adding a fifth dynamic-SQL site; it was fixed the
  right way (option b): each results package now has a STATIC `RESET_UNACCOUNTED` proc, registered via
  a new `RESET_PROC` column, dispatched through the EXISTING sanctioned invoke site. No new dynamic-SQL
  site was added. Merged as 977ce90.
- **Backlog hygiene (#491).** Items grain (#86) and Team Members (#68) marked RESOLVED with
  base-table proof. GLBudgets cell key (#87) confirmed as a P3 backlog item.
- **Carrier-config audit (#490) and the LOADED-standard requirements note (#488)** merged earlier.
- **Backlog #21 audit ("conform 25 recon reports to Contract v1").** Found SUBSTANTIALLY COMPLETE /
  SUPERSEDED: 30 of 34 objects already conform to the shipped Contract v1 (naming 100%, RECON_KEY 100%,
  one generic parser `DMT_RECON_CONTRACT_PKG.FETCH_ROWS` + a CONTRACT_VERSION registry 100%, params 88%,
  `P_BATCH_ID` retired). The original "7-column" spec was intentionally revised to 9 columns on
  2026-07-07. Residual: 4 config objects (Customers in-flight; Taxes/ValueSets/CashBanks deferred to
  Phase 4 FBL). **#21 should be closed as superseded** (owner to confirm).

**Regression detail (run 142).** Preflight passed after correcting a stale-credential issue in the
LOCAL DB: 167 override rows in `DMT_ERP_INTERFACE_OPTIONS_TBL` still carried the previous demo
password; all passwords are now the current demo password. The only non-clean objects are all
PRE-EXISTING functional/environment blocks: ARInvoices (O2C AutoInvoice, 0 LOADED), Grants,
ProjectBudgets, TalentProfiles (0 LOADED, functional setup incomplete), and the zero-record
HCM/Benefits/MiscReceipts objects (Absences, BenBeneficiary/Dependent/Participant, PerfEvaluations,
SalaryBases, TaxCards, W2Balances, WorkSchedules, MiscReceipts).

**New non-blocking findings (UI display only -- accounting is correct; logged as follow-ups).**
Drill-label mismatches between the page-52 tiles and the page-57 record view for 5 objects:
- **GLBudgets** -- the tile is labeled "GL Budget Balances" but the records are labeled
  "GL Budget Lines", so the drill link is broken.
- **SupplierSites / SupplierAddresses / SupplierContacts / Projects "Project Tasks"** -- the page-52
  tile under-counts by skipping `[PRE_VALIDATION]` FAILED rows that page-57 correctly shows.
Counts are complete and balanced; only the UI drill display differs.

**What's next.**
1. Standing coverage gap (functional-owner-blocked, not code): AR Invoices (O2C AutoInvoice), Grants,
   ProjectBudgets, TalentProfiles, and the zero-record HCM/Benefits/MiscReceipts objects. These need
   the functional owner or seed data, not tool changes.
2. Fix the minor page-52-vs-page-57 UI drill-label mismatches above (GLBudgets label; the four
   pre-validation under-counts).
3. Owner to confirm closing backlog #21 as superseded.

**Blockers:** None on the DMT2 code side. The remaining non-clean objects are all functional/
environment blocks outside our code.

**Git state:** On `main`, tree clean of tracked changes (after this status/doc commit). Local was
level with `origin/main` at 977ce90 before this commit; this commit is docs-only and pushed to
`origin/main`. Untracked scratch only (`.claude/worktrees/`) -- safe to ignore.

**Next session:** first action is to sync -- `git checkout main && git fetch && git merge --ff-only
origin/main`, then confirm a clean tree -- BEFORE any new work.

## Session -- 2026-09-29 -- Unaccounted objects resolved (all traced to faulted runs, not matching bugs)

**Bottom line.** The three long-standing "unaccounted" objects were NOT matching bugs -- all three trace to runs that faulted mid-reconcile and were never re-run (the reconcile correctly RAISED on a transient BIP/Fusion outage rather than fabricating a verdict). Re-running the reconcile accounts every record with real base-table / error proof and no code fix.

- **Items / Item Master (4 records, run 119).** Not a bug. Re-ran the item reconcile -> 3 good items LOADED (real INVENTORY_ITEM_ID) + 1 bad item (org ZZZ) FAILED with the real "invalid organization" Fusion error. The ITEM_NUMBER+ORGANIZATION_CODE match works; the rows were stuck only because run 119's reconcile faulted. No code change needed.
- **GL Budget Lines (run 119).** Not a bug (PR #483, merged). Same run-119 fault. Re-ran reconcile -> 2 LOADED + 1 FAILED. Added a WARN log for residual GENERATED rows.
- **AP Invoice Lines (run 325).** No real bug. A prior sub-agent (PR #482) "fixed" a supposed Fusion line-renumbering with a per-invoice business-key fallback -- but a controlled test disproved the premise: Fusion PRESERVES the sent line number (sent line 3 -> stored line 3) and only APPENDS its own tax lines, so the original exact per-line match is correct. **Reverted #482 via PR #484 (merged).** A follow-on REFERENCE_KEY1 traceability carrier (PR #485) was CLOSED -- it breaks the AP load: the AP invoice-lines FBDI is a fixed 164-column template and REFERENCE_KEY1 is not in it (stamping it as a 165th column makes SqlLdr reject the file, 0 rows committed).

**The real fix (backlogged):** backlog #95 (P2) -- a first-class "re-run reconcile for run N" capability, since faulted runs leave GENERATED rows with nothing to re-reconcile them. A per-line traceability carrier for AP is deferred until the ATTRIBUTE1 DFF segment is enabled (the business-key/deferred case per PR #481).

## Session -- 2026-09-29 -- Comparison report: APEX two-view redesign, count/$ split, cached snapshot for instant load

**What was done.** The post-run comparison report got its APEX front end finished and made fast. Five PRs:

- **PR #476 (merged).** Added a "View run comparison report for this run" drill link on the Run Detail page (page 82) that opens the comparison page (page 85).
- **PR #477 (merged).** Redesigned page 85 into two views: an **Overview** (one card per object, grouped by process area, with a balance badge, and an errors count that drills to the failed records) and a **Detailed comparison** (an Interactive Report). Also removed four hardcoded explanatory note strings (Talent Profiles, Project Budgets, Expenditures, Grants) from the HCM and PPM comparison packages (DMT_HCM_COMPARE_PKG / DMT_PPM_COMPARE_PKG) -- set to NULL; the balance logic did not change.
- **PR #478 (merged).** Split the detailed comparison table into separate count and dollar columns per stage (Staged, Errors, Loaded, Variance). The dollar columns are left blank for objects that carry no money; helper columns are hidden.
- **PR #479 (merged).** Renamed `scripts/deploy_supplier_bip_reports.py` to `deploy_recon_bip_reports.py` (it deploys the Wave-1 recon reports for the supplier family AND Customers). Added backlog item #94 (P3) to `docs/backlog.html`: a business-key checksum for money-less comparison objects.
- **PR #480 (OPEN, awaiting the Actions reviewer).** Speed fix. New table `DMT_RUN_COMPARISON_TBL` caches one computed snapshot per run. `DMT_RUN_COMPARE_PKG.SAVE_RUN_COMPARISON(run)` makes the live Fusion pass once and stores it. Page 85 now reads that table (instant load) instead of making ~23 live Fusion calls (about 15-28 seconds) on every open. Added a "Refresh from Fusion" button (re-pulls on demand and shows "as of <timestamp>") and a "Run Comparison" entry in the navigation menu. Verified live on local app 501, run 132.

**Correction to a prior status entry.** The earlier "clean up 167 stale Docker override-credential rows (NULL username)" item was a misdiagnosis. Those rows are in `DMT_ERP_INTERFACE_OPTIONS_TBL` and are SEEDED reference data -- the ERP interface options catalog (business object to FBDI/ESS job path), seeded by `db/seed/dmt_erp_interface_options_tbl.sql`, 180 rows. `FUSION_USERNAME` / `FUSION_PASSWORD` are NULL by design; credentials come from the config default (`DMT_UTIL_PKG.GET_CEMLI_CREDENTIALS`). Deleting them would wipe the catalog and diverge from git. This is NOT a cleanup task and was removed from priorities.

**What's next.**
1. Merge PR #480 once the Actions reviewer approves.
2. Blanket PO money: change the generator (`dmt_blanket_po_fbdi_gen_pkg`) to emit an amount-based BPA line so Fusion keeps the amount and Blanket PO money reconciles. Requires a live BlanketPOs run to verify. Not yet started.
3. Promote the comparison feature to ATP GOLD via `scripts/ci_promote.py` -- AFTER PR #480 (and the Blanket PO change) merge, so GOLD gets the finished code. Built and proven on local Docker only.

**Blockers:** None. (PR #480 is open and waiting on the automated reviewer, which is expected, not a blocker.)

**Git state:** On branch `feat/comparison-cache-and-nav` (the PR #480 branch), tree clean of tracked changes. This branch is 1 commit ahead of `origin/main` (the PR #480 commit) and 1 behind (PRs #476-#479 already merged into main after this branch was cut). Untracked scratch only (worktrees, `_scratch_export501/`, `scratch_matrix*.txt`, `docs/rca_regression_2026-09-18.md`) -- safe to ignore or clean.

**Next session:** first action is to sync -- `git checkout main && git fetch && git merge --ff-only origin/main`, confirm a clean tree -- BEFORE any new work. If PR #480 has merged by then, main already has the cache/nav work; if not, check the branch out again to finish it.

## Session -- 2026-09-28 -- Post-run comparison report: ALL 23 objects rolled out (PR #475); walking skeleton merged (#474)

**What happened.** The walking skeleton (framework + Purchase Orders) merged to main as PR #474 -- which included a governance step the owner approved: amending coding-standard #66 to sanction the comparison framework's one dispatch site (`DMT_RUN_COMPARE_PKG.BUILD_ROWS`) as a fourth dynamic-invocation site, plus an anti-circumvention clause so nobody can smuggle a new dynamic-dispatch need through an existing site. (The automated reviewer first blocked a self-certified amendment; it was redone as a proper owner-approved accepted rule via the design-change sentinel.)

Then the remaining **22 objects** were rolled out in 7 families (Suppliers x5; Blanket POs + Contracts; AP Invoices + Customers + AR Invoices; GL Balances + GL Budgets; PPM x5; Assets + Requisitions; HCM x3) on branch `feature/comparison-rollout-objects`. Each family was independently reviewed, then a whole-branch review (most capable model) and a scoped re-review of its fix wave. Opened as **PR #475** (awaiting the Actions reviewer).

**Proof.** Full grid for run 132 verified live: **23 of 23 objects present, all in balance.** Every key path exercised (load-request id, import-request id, stamped GROUP_ID/SOURCEREF/key-map, captured Fusion id), money reconciled where Fusion carries it, env-blocked objects honestly 0-loaded with a note. No prefix or timestamp-window keys anywhere.

**Whole-branch review hardening applied:** a Fusion fault on any object now shows an explicit "unknown" row instead of the object vanishing; the BIP deploy manifest now lists all 23 comparison reports; Salaries money sum hardened against non-numeric. Bugs caught live during rollout and fixed: Assets multi-book fan-out (scoped to the posted book), Requisitions double-staged double-count (scoped via TFM), an Assets nonexistent-column reference.

**Left:** merge PR #475 (Actions reviewer); confirm the 4 env-blocked objects (AR Invoices, Project Budgets, Grants, Talent Profiles) on a run where they load; Blanket PO money needs an amount-based line to reconcile in Fusion; rename the generic-but-supplier-named BIP deploy script.

## Session -- 2026-09-27 -- Post-run comparison report: discovery proven for all 23 objects; walking-skeleton built (Purchase Orders end-to-end)

**What this feature is.** A new report that, after a run, shows each object side by side:
how many records we staged, how many failed in our tool, and how many actually succeeded
in Fusion -- with money totals -- and checks they add up (`Fusion successes + TFM errors =
STG total`, per object). The success number is queried live from Fusion. This is a separate
process from the existing row-by-row reconciliation (`DMT_RUN_SUMMARY_PKG` /
`AUDIT_IN_FUSION`): it is aggregate control totals keyed by a batch id, not a per-record match,
and it carries money, which the recon layer does not.

**Design + plan (committed on branch `spec/post-run-comparison`, not yet merged):**
- Spec: `docs/superpowers/specs/2026-09-27-post-run-comparison-design.md`
- Proven query matrix (one file per object + the index): `docs/superpowers/specs/discovery/QUERY_MATRIX.md`
- Implementation plan: `docs/superpowers/plans/2026-09-27-post-run-comparison.md`

**Discovery -- proved every query by hand before any code (read-only, against run 132 on
local Docker).** All 23 objects reconcile. 19 are proven with a production-safe key and
balance exactly; 4 loaded nothing this run (AR Invoices, Project Budgets, Grants, Talent
Profiles -- blocked by Fusion setup), so their staged/failed sides were proven and their
Fusion query designed for a future run. Key rules that fell out and now bind the build:
- The run's record set always comes through the transform rows (STG has no RUN_ID and holds
  duplicate seed rows); never scope by business key or the test prefix.
- Fusion key order: a batch id (the import/load ESS request id we already record, which can be
  a list per object) -> a stamped reference that round-trips -> the captured Fusion id, used
  only where no batch id exists (proven so for Projects and GL Budgets). Never the prefix or a
  timestamp window.
- Money reconciles from Fusion for 9 objects. Contracts genuinely have no money (header-only
  agreement). Blanket PO money is dropped by Fusion because the line is generated quantity-based
  (a generator matter, not reconciliation). Expenditures shows Fusion's recomputed cost, so its
  money variance is real and intended.

**Rotated the Fusion demo password.** It had expired (all users 401), which blocked the live
Fusion side of discovery. Rotated everywhere and verified all five users return 200. Residual:
167 per-object override-credential rows on the Docker DB (NULL username) still hold the old
password -- they are inert (no username to log in as) but should be cleaned up before the next
real Docker pipeline run.

**Build -- subagent-driven, 6 of 7 tasks complete and reviewed; the APEX page (Task 7) was in
progress at write time.** Walking skeleton = the shared framework plus Purchase Orders end to
end; the other 22 objects follow the same template later. Artifacts built and deployed to
local Docker:
- `DMT_CMP_ROW_OBJ` / `DMT_CMP_ROW_TAB` -- the uniform comparison-row type.
- Three columns on `DMT_BIP_REPORT_TBL` (`CMP_DM_CATALOG_PATH`, `CMP_REPORT_CATALOG_PATH`,
  `CMP_FUNCTION`) -- the per-object comparison-report registry.
- `bip/PurchaseOrders/PO_CMP_DM.xdm` + `PO_CMP_RPT.xdo` -- the PO Fusion aggregate report
  (deployed to `/Custom/DMT2/PurchaseOrders/`).
- `DMT_PO_COMPARE_PKG.GET_COMPARISON(run)` -- the PO comparison function.
- `DMT_RUN_COMPARE_PKG.GET_RUN_COMPARISON(run, cursor)` -- the framework: enumerates a run's
  objects, dispatches to each object's function via the registry, skips-and-logs a broken one.
- `test/comparison/verify_run132.sql` -- the end-to-end gate.

**Proof:** the live end-to-end test on run 132 passes -- Purchase Orders shows staged 3 / 2300,
errors 1 / 50, Fusion 2 / 2250, in balance. Every failure carried a real Fusion error; every
success was read back live from a Fusion base table.

**What's next:**
1. Finish the APEX page (Task 7) on app 501, run the whole-branch review, open the PR, and merge
   `spec/post-run-comparison`.
2. Roll out the other 22 objects with the proven template: one Fusion aggregate BIP report, one
   `GET_COMPARISON` function, and one `CMP_FUNCTION` registry seed per object (all queries are
   already proven in `QUERY_MATRIX.md`). The 4 zero-loaded objects confirm on a run where they load.
3. Follow-ups: to reconcile Blanket PO money, generate the BPA line as amount-based so Fusion
   keeps the amount; clean up the 167 stale Docker override-credential rows from the password
   rotation.

## Session -- 2026-09-25 -- EBS-adaptor backlog fixes merged to DMT2; full regression PASSED (run 132, zero new regressions)

**What was done:** Reviewed and corrected the 7 backlog items the EBS adaptor logged, then
kicked off one full DMT2 regression against the real Fusion demo. All DMT2-side fixes are
merged to `main` and deployed to the local Docker instance (`dmt2-local`), which installed
clean with zero invalid objects.

DMT2 repo (brianmakarewicz/DataMigrationTool) -- all in PR #470 unless noted:
- **#469 chunked-ingest API (issue CLOSED):** new package `DMT_CSV_INGEST_PKG`
  (`start_file` / `append_chunk`) does the large-text append on the ATP side, so CSV cells
  longer than 8000 characters can cross the database link. EXECUTE granted to EBS_ADAPTOR.
- **#468 PO distributions FBDI:** restored the wrongly-dropped ATTRIBUTE5 (Fusion's
  PoDistributionsInterface needs ATTRIBUTE1..20 with no gaps). Widened 123 to 124 columns
  across the generator, staging table, transform table, transform, metadata seed, view, and
  gold fixtures. The reconciliation id now lands in ATTRIBUTE_NUMBER1, not ATTRIBUTE_DATE10.
- **#449 CSV loader multibyte:** loader buffers now declared CHAR (fixes the ORA-06502 class).
  Defensive hardening -- normal multibyte already loaded on current code.
- **#466 staging-table primary-key collision:** fresh-install DDL now uses GENERATED ALWAYS
  AS IDENTITY (PR #470). The migration was CORRECTED in **PR #471** because an in-place
  identity conversion is impossible (ORA-30673) and the first migration had already cleared
  the sequence default before failing, breaking all 73 tables. Replaced with a recovery that
  restores the sequence default and advances the sequence past the current max. Verified on
  dmt2-local: fixed 73 of 73 tables, zero left without a default.
- **#453 supplier lookups (SUPPLIER_TYPE / TAX_ORGANIZATION_TYPE):** the DMT2 artifacts were
  already on main and verified correct against live Fusion (POZ_VENDOR_TYPE 22 values,
  POZ_ORGANIZATION_TYPE 11 values). Remaining work is on the Fusion side (see What's next).

EBSAdaptors repo (brianmakarewicz/EBSAdaptors) -- PR #29 MERGED; live proof on the EBS VM
deferred (VM saved for RAM):
- **#25 coherent parent/child sampling:** generate_all_csvs samples N driver keys once per
  object into a session temp table; driver views no-op when the table is empty, so full
  extracts are unchanged and the signature is unchanged.
- **#21 missing view-source grants:** recorded 21 missing SELECT grants in
  00_CREATE_SCHEMA.sql (Projects/Grants, Requisitions, Inventory, dynamic-SQL base tables).

**Regression -- PASSED (run 132, prefix 93212, all objects terminal):** across the whole run,
**zero ORA-00001, zero ORA-06502, zero ORA-01840**, and every object's LOADED count matches the
prior baseline (run 131) exactly -- **zero new regressions**. PurchaseOrders loaded 2 rows with
real FUSION_IDs plus 1 correctly FAILED. Overall harness status COMPLETED_ERRORS comes only from
the same pre-existing items as baseline (ARInvoices/Grants/ProjectBudgets/TalentProfiles at 0
LOADED were 0 in run 131 too). NOTE on #468: the gold-regression PO data never populates
ATTRIBUTE_NUMBER1 in the shifting slot, so it cannot positively reproduce the original ORA-01840
-- the fix is verified by column analysis + no-regression here; positive reproduction is owed
from the EBS-adaptor PO extract on the VM.

The EBS Vision VM was saved (resumable, not shut down) to free RAM for the regression.

**What's next (remaining follow-ups, none blocking this session's goal):**
1. On the EBS VM (resume it first): verify #21 and #25 -- fresh dmt_ebs_adaptors install = zero
   ORA-00942; PurchaseOrders limit-5 extract header keys == line parent keys; and positively
   reproduce #468 (re-run the run-169 PO extract, confirm distributions load). #468 stays OPEN
   until that confirms.
2. Deploy the #453 lookup data models (.xdm) to /Custom/DMT2/Lookups/ on Fusion, then run
   DMT_LKP_REFRESH_PKG.REFRESH_FUSION_VALUES for both SUPPLIER_TYPE and TAX_ORGANIZATION_TYPE.
3. On the EBS side, re-point push_csv_to_atp to call DMT_CSV_INGEST_PKG (#469) and drop the
   old STG-sequence workaround (#466 auto-generates now). See EBSAdaptors docs/backlog.md.
4. Resume EBS adaptor Task 5 (Suppliers pipeline end-to-end) once the above hold.

Done this session: regression verdict read (PASS); DMT2 #449/#466 closed, #469 closed;
EBSAdaptors PR #29 merged.

**Blockers:** none for the DMT2 work. Remaining items (#468 positive proof, #25/#21 live
verification) are gated only on resuming the EBS VM.

**Git state:** DMT2 on `main`, tree clean (only untracked scratch files), local level with
origin/main (0 ahead / 0 behind). #470 and #471 merged. EBSAdaptors on branch
`monroe/ebs-to-fusion-e2e-spec` (PR #29); the uncommitted #21 grant + backlog + plan edits
were committed and pushed this close-out (commit 0aabc1d) -- EBS tree now clean.

**Next session:** first action is to sync -- `git checkout main && git fetch && git merge
--ff-only origin/main`, then confirm a clean tree BEFORE any new work. EBSAdaptors PR #29 is
merged; the remaining EBS items are the VM-gated verifications above.


## Session -- 2026-09-23 -- Backlog batch merged, full regression PASS (run 121), ATP Gold deployed

**Headline:** A large backlog batch was executed and merged, the full regression re-ran clean on
local Docker (RUN_ID 121, prefix 93201), and DMT2 was deployed to the ATP Gold instance (schema +
APEX app 500). The three long-standing UNACCOUNTED break-fixes are now closed with real Fusion
evidence. The only UNACCOUNTED left in the entire run is 3 Project Budget Lines (backlog #79).

**What was accomplished:**
- **Backlog batch merged.** Engine cleanups (single BIP path #20, status-rename verify #26,
  instance-ids-by-name #36, validator entry points #42, mode-driven predicates + retire RETRY #44
  -- which also corrected 22 transform packages whose ALL mode wrongly selected only NEW rows,
  retire non-sanctioned EXECUTE IMMEDIATE #46, LIKE-on-codes #47). APEX work (funnel/Object-Detail
  #10, palette #29, Activity Log + log-attribution #30, dead views #31, fold render procs #41,
  verify #49/#50/#51/#55, page deletes #52/#58, INTEGRATION_ID->RUN_ID rename #53 with label
  follow-ups #442/#443, partition tiles #70/#74). Plus the Items per-batch import-id concurrency
  fix #75 and two clean-install bug fixes: #440 (widen DMT_BIP_REPORT_TBL.TFM_TABLE 100->240,
  fixed an ORA-12899) and #441 (GET_OR_CREATE_SCENARIO made idempotent, fixed a DUP_VAL_ON_INDEX).
- **Three reconciliation fixes proven with real Fusion evidence, 0 UNACCOUNTED:** GL Budget Lines
  (#422), AP Invoice Lines (#420), Item Master (#423).
- **Full regression PASS (RUN_ID 121, prefix 93201, local Docker).** The 3 recon objects at 0
  UNACCOUNTED with real Fusion base ids/errors; P2P chain green (Suppliers + children, PO all
  LOADED); #44 ALL-mode caused no regression; LOG_TYPE clean. Only 3 UNACCOUNTED in the whole run,
  all Project Budget Lines (pre-existing gap = backlog #79). APEX link-check: 0 broken across 40
  pages. (Prefix was leapfrogged to 93201, above the shared Fusion pod's supplier max ~93107,
  after a `--fresh` reset put the sequence back low.)
- **ATP Gold deployed (main HEAD 92468c5).** Schema installed to DMT2_OWNER on the queryapp ATP
  via ci_promote plus hand-applied migrations (TFM_TABLE->240 + Customers row reseeded, dead
  procs/views dropped, prefix sequence leapfrogged to 93300); 0 invalid, git-matched. APEX app 500
  imported from `apex/f501src`, alias LIVEDMT2, login HTTP 200.
  Gold console: https://g6726c838b72234-queryapp.adb.us-ashburn-1.oraclecloudapps.com/ords/r/dmt2/livedmt2/ (DMTADMIN).

**Open backlog count (after adding the 2 tooling items in this close-out):** 33 open
(STILL OPEN + PARTIAL) -- P1 2, P2 14, P3 17 -- of 81 total (RESOLVED 46, PARTIAL 5, STILL OPEN 28,
STALE 2). The two remaining P1s are #7 (reconcile registered in two places -- its durable fix IS
#16) and #9 (full-fidelity multi-CSV scenario upload).

### NEXT SESSION START

**The P1 batch -- #7 + #9 (with #16):**
- **#7 folds into #16.** Make the registry column `RECON_PROC` on `DMT_PIPELINE_DEF_TBL` the single
  reconcile dispatch for every object, and **delete the hardcoded partition ELSIF chain** that
  currently registers reconcile in a second place. One registry-driven dispatch, no duplicate
  hand-maintained branch. This is the durable fix that closes #7.
- **#9 -- full-fidelity multi-CSV-zip scenario upload.** Build an upload that accepts a full zip
  with **one CSV per STG (staging) table**, so a regression scenario loads once at full fidelity
  (all child detail: supplier addresses/sites/contacts, PO lines/distributions, etc.). This also
  makes regression re-runs clean, because a reloaded scenario no longer comes back degraded and
  re-breaks Suppliers/Customers/PO.

**Smaller follow-ups:**
- **#79** -- ProjectBudgets recon-verify gap (the 3 UNACCOUNTED Project Budget Lines).
- **GLBudgets page-52 / page-57 label drift** on the drill (cosmetic, non-gating).
- **#80** (NEW, P3) -- ci_promote.py deploy_db does not run `db/migrations/` or `db/tools/`, so
  MODIFY-width and guarded-DROP migrations must be hand-applied on every ATP promotion; extend the
  glob or add a run-migrations step.
- **#81** (NEW, P3) -- migration `2026-09-22_drop_dead_pay_rel_detail_view.sql` has its PL/SQL
  block `/` terminator on the same line as the block, so SQLcl `@@` silently skips it; reformat the
  terminator onto its own line.

### ENVIRONMENT NOTES (next session)

- **Local Docker (`dmt2-local`, port 1523)** is credentialed, has APEX 26.1 reinstalled, and the
  prefix sequence is at 93201.
- **Gotcha:** `build_local_db.sh --fresh` **WIPES the Fusion credentials + APEX + resets the prefix
  sequence.** After a `--fresh` you must: (1) re-credential from `connections.json`, (2) re-import
  the APEX app, and (3) leapfrog the prefix sequence above the shared Fusion pod's supplier max
  (~93107) so new supplier ids do not collide on the demo. Skip these and the next run will fail on
  bad creds, a missing app, or a prefix collision.

## Session -- 2026-09-21 -- Full regression gate PASSED (run 351); monolith deletion cleared

**Headline:** The full end-to-end regression passed as the gate for deleting the old
`run_one_object_type` monolith. Run 351, prefix 10291, ran against the real Fusion demo and drove
all 34 objects to a terminal state. The refactor that deleted `run_one_object_type` and moved every
object into a self-contained `RUN_<object>()` recipe (PR #418) introduced **zero new regressions**:
every object's LOADED / FAILED / UNACCOUNTED count matched its pre-refactor baseline (runs 325-347).

**What it proves:** Splitting the one giant object-runner into one recipe per object changed no
object's outcome. Good rows still load, bad rows still fail with real Fusion errors, and the count of
unaccounted rows is unchanged. The refactor is safe; the APEX port (Stage F step 2) can now proceed.

**Why the harness still prints FAIL (all PRE-EXISTING, none refactor-caused):**
- **3 true UNACCOUNTED objects** (open since run 325, each its own break-fix ticket): Items / Item
  Master (4 records), GL Budget Lines (2), AP Invoice Lines (1).
- **O2C AutoInvoice / interface objects at 0 LOADED** (waiting on the functional owner): Customers
  Account Sites, Account Site Uses, and ARInvoices AR Lines. These ride the AutoInvoice/interface
  path blocked on demo-instance functional setup.
- **Environment / functional-blocked (non-gating):** Grants (not set up on the demo), TalentProfiles
  / Profile Items (HCM V2 metadata the demo rejects), and 9 HCM/HDL objects with no seed data.

**Review items (not gating):** 38 cosmetic malformed LOG_TYPE entries (the package name landed in the
log-level column; NOT from PR #418). The APEX authenticated smoke test could not run because there is
no DMT_SMOKE end-user account on app 500 (only the login page was verified).

**Next up:**
1. Three UNACCOUNTED break-fixes: Items / Item Master, GL Budget Lines, AP Invoice Lines.
2. APEX #74 (partition-value drill-down) and #75 (partition-aware tile load-id fallback).
3. Create a DMT_SMOKE end-user account on app 500 so the authenticated APEX smoke test can run.
4. Cosmetic LOG_TYPE cleanup (package name mistakenly written into the log-level column).

**Docs updated this close-out:** the Object Status Matrix in `docs/DMT_REBUILD_PLAN.html` section 0
(intro note, Items/APInvoices/GLBudgets/Customers/ARInvoices/Grants/TalentProfiles rows, and the
"Proven live" footer); the Stage F execution-status line in the same file; and the Stage F build-order
line in `CLAUDE.md`.

## Session -- 2026-09-14 -- Deploy DMT2 to the queryapp ATP (DMT2_OWNER) + drive the regression

**Headline:** DMT2 is now deployed and running on the **queryapp ATP** as a NEW schema **DMT2_OWNER**
(alongside the frozen ConversionTool `DMT_OWNER`, same PDB). Branch `feat/schema-relative-code`,
PR #236, 13 commits, tree clean. Enabled by making the DB code **schema-relative** (stripped the
hardcoded `DMT_OWNER.` qualifier, ~2,880 refs, so it installs into any owner; backward-compatible
on Docker). Full `install.sql` clean (0 invalid); scenario loaded; ACL + credentials set.

**Connection:** `DMT2_OWNER` / `Migr8_Dmt2#2026Qz` @ `queryapp_tp` (wallet
`C:\Users\Monroe\workspace\data-migration-tool\wallet`, set `TNS_ADMIN`). No APEX UI deployed
(engine/DB only). Harness env: `DMT2_CONN`, `DMT2_WALLET`, `DMT2_WALLET_PW`.

**Fixes made (all committed + deployed), each honest (real load or real Fusion error):**
1. `ENUMERATE_ESS_FILES` FK bug (ORA-02291 -- passed Fusion request id where local ESS_JOB_ID pk
   needed; starved reconciliation) -- took P2P from 0 to 10 accounted.
2. Parent->child accounting cascades: Requisitions (line/dist->header), Customers (party-site->
   site-use), Projects (project->task incl. orphan), MiscReceipts (transaction->lot).
3. HDL reconcile: when a data set loads 0 objects with real messages, mark still-GENERATED rows
   FAILED with the data set's real errors (Workers/Assignments).
4. Grants: fixed Award-Batch-Import-Report XPath (`//G_4`) -> 3 awards FAILED with real errors.
5. Expenditures: scenario source 'Time Card'->'External Time Entry System' + capture per-txn
   rejections from `//G_STAG_ERR`.

**Regression -- latest full run RUN_ID 120, prefix 10004 (fresh).** Good records LOAD cleanly for
PurchaseOrders, APInvoices, Customers, GLBalances, Projects, GLBudgets, Assets, BillingEvents,
ProjectBudgets (intended-good in, bad->FAILED). HCM 14/14 accounted; Projects 5/5.

**Reconciler false-negatives FIXED this session (all committed + deployed, verified run 120):**
- **Suppliers family** — DONE. All 5 supplier objects (Suppliers, Addresses, Sites, Site
  Assignments, Contacts) now show 2 good LOADED / 1 bad FAILED. The reconciler treats a Fusion
  "already exists" as LOADED (the record IS in Fusion; the pipeline re-submits within a run).
- **Requisitions** — DONE for headers (2 good LOADED / 3 bad FAILED). Same "already exists" ->
  LOADED handling. Child lines/distributions are still stuck FAILED on run 120 (a re-reconcile
  artifact); a fresh run with a new prefix cascades them to LOADED.
- **Items** — DONE (Item Master 3 good LOADED / 1 bad FAILED). Fixed the base-table confirm
  report to join on the item number instead of an id Fusion never stamps when the master import
  errors, and made reconciliation cover all of Fusion's split load requests.
- **PurchaseOrders / BlanketPOs / Contracts** — DONE (POs 2 good LOADED / 1 bad FAILED;
  Blanket 1/1; Contracts 1/1). The base-table confirm report was keyed on the Fusion import
  request id, which a within-run re-submit breaks, so a good PO that was actually in the base
  table got reported as a duplicate failure. Now it confirms the PO by its document number.
- **Fresh run 122 (prefix 10006) — DEFINITIVE VALIDATION, all P2P fixes hold end-to-end
  including child cascades.** Good records load, bad records fail with real errors, zero
  UNACCOUNTED except two honest cases:
  - PurchaseOrders: Headers 2L/1F, Lines 3L/1F, Locations 2L/1F, Distributions 2L/1F.
  - Suppliers family (5 objects) 2L/1F each; Items (Master) 3L/1F; Requisitions Headers 2L/3F,
    Lines 2L/2F, Dists 2L/2F; BlanketPOs 1L/1F; Contracts 1L/1F; APInvoices 2L/2F.
  - Financials: GLBalances, GLBudgets, Assets all good LOADED. Projects: Projects, Tasks,
    Team Members, Txn Controls, BillingEvents all good LOADED. O2C: Customers core tiers LOADED.
  - Honest remaining: ARInvoices 3 UNACCOUNTED (consolidated-billing job crash);
    Expenditures/Grants/HCM FAILED with real errors; Customers Account Sites and Items Item
    Categories 0 LOADED (consistent across 3 runs -- need separate investigation).
  - ONE open ruling for the owner: a requisition rejected for a bad HEADER (REQ-BADHDR) leaves
    its otherwise-valid line + distribution UNACCOUNTED (2 records). The reconciler deliberately
    does not compose a "parent header rejected" cascade (the error_attribution rule). Deciding
    whether to propagate the header's real rejection error to those children is the owner's call.

**Open items (NOT reconciler defects):**
- **ARInvoices** -- AutoInvoiceMasterEss crashes at job level ("consolidated billing is enabled...").
  3 lines UNACCOUNTED (mission-honest job crash). Needs consolidated billing disabled on the demo
  (Fusion setup) or the correct consolidated-billing AutoInvoice job.
- **MiscReceipts serial** -- 1 row, no parent-transaction link in the source data; needs a
  transform/schema change or Fusion serial verification.
- **Expenditures / Grants / Workers-Assignments** -- now honestly FAILED with real Fusion errors
  (instance config / bad-data), captured correctly.

## Session -- 2026-07-21/22 -- Resolve run-234 UNACCOUNTED honestly
**What was done:** Located the real Fusion outcome for all 23 UNACCOUNTED records from the first
honest scorecard (run 234) and landed 11 merged PRs (#222-#232). All are merged; #227's remaining
work is a HUMAN versioned BIP redeploy (not the PR). Evidence for every claim is committed under
`docs/findings/` (run234_*, run235_*, run238_projects_capture_validation). Full detail:
`docs/sessions/2026-07-21_unaccounted-resolution.md`. Highlights:
never fabricate LOADED (#222); real error -> FAILED (#223); Projects capture-the-report-child +
parse fix, validated end-to-end run 238 (#224/#229); Grants award-import-report (#225, capture
follow-up pending); HCM file-level error attribution (#226); Customers site-use error tier (#227);
Expenditures xref project/task resolution + reverted a dead GL_DATE patch (#228/#230); funnel
`ALL_UNACCOUNTED` dark-red flag (#231).
**Accounting model settled:** true job-level crash (Expenditures ORA-01008; AR AutoInvoice abort)
-> leave records UNACCOUNTED + dark-red tile, never fabricate or patch data; job success + per-row
reject -> capture the report/log and mark each rejected row FAILED with its real error.
**Docs updated this close-out:** project CLAUDE.md (added THE MISSION section; fixed stale "hourly
reviewer" -> event-driven; pointed to the Object Status Matrix + "update every session"); the
Object Status Matrix in `docs/DMT_REBUILD_PLAN.html` section 0 (Projects/Expenditures/Grants/
ARInvoices/Requisitions/PayrollRelationships/TalentProfiles/Customers rows).
**What's next:** finish the Grants report-capture end-to-end (same fix as #229 — better: add the
capture once in `DMT_QUEUE_WORKER_PKG.RECONCILE_ONE` so it fixes every object); run a full
regression to validate every merged reconciler + produce the complete scorecard; Customers BIP
redeploy (human) + the forward FBDI fix to stamp `SITEUSE_ORIG_SYSTEM/_REF`; wire the APEX funnel
tile to `ALL_UNACCOUNTED`; fix the two HDL generators (PayrollRelationships -> `AssignedPayroll`;
TalentProfiles ProfileItem attributes) + Worker WorkTerms duplicate-date so those HCM objects LOAD.
**Also tracked (from the blind review):** (1) reconcile committed-vs-deployed package drift — the
deployed bodies of `DMT_PROJECT_RESULTS_PKG`, `DMT_LOADER_PKG`, `DMT_ESS_UTIL_PKG` are ahead of the
committed files and a committed report path still reads `/Custom/DMT/`; git-first requires syncing
these. (2) The matrix Workers row is ☑ from the older run-162 live proof, but the run-234 worker
chain loaded ZERO (a false LOADED that #222 fixed) — re-verify Workers on the next full run.
**Run-238 caveat:** the Projects run-238 result was observed live in-session and recorded in
`docs/findings/run238_projects_capture_validation.md`, but was not re-queried after the DB port
wedged; re-confirm on the next full regression run.
**Blocker:** `dmt2-local` DB healthy internally (via `docker exec`) but host DB port 1523
forwarding is wedged; `wsl --shutdown` + container restart issued, host Oracle ports (1521/1523)
still not forwarding at close. The Python deploy script + regression harness need host 1523, so the
full-regression validation is deferred until the port returns. Stale run 154 QUEUED to clear.

## Session -- 2026-07-14
**What was done:** Requirements-design review of the canonical design doc
(`workspace/DMT2/docs/DMT_DESIGN.html`); artifact republished. Related edits to
`objects/Customers/README.md`. Specifics:
- Added subsection 7.1 "Canonical per-object processing recipe," built from the real
  DMT2 code (Suppliers template plus GLBalances/Customers partitioning).
- Decided to RETIRE 1099Invoices as a separate object -- it is AP filtered to invoice
  type 1099.
- Rewrote the BIP-mirror rule in plain English and added the change-the-model sequence
  (accepted).
- Verified BIP objects against the single-source object list: all 25 FBDI objects match.
  Found two naming splits (GLBudgets vs GLBudgetBalances; Lookups vs COMMON_LOOKUPS) plus
  a `/Custom/DMT/` path drift. Logged a BIP conformance-checker rule (red, awaiting approval).
- Tightened the seed-departure rule to require owner approval before a departure ships (red).
- Moved the HZ customer-batch resolved issue out of the standards table into
  `objects/Customers/README.md`; corrected that README's stale "blocked" status.
- Merged the two section-1 tables into one: folded BIP data-model / report / interface into
  the object table as three columns and deleted the standalone BIP table, so the object list
  can no longer diverge.
- Added a "Depends on" column to all four object tables (from DMT_PIPELINE_DEF_TBL.DEPENDS_ON).
- Added four specific engine-cleanup backlog entries (red) with exact files, procedures, and
  line numbers: (1) reconcile double-registration fail-open (dmt_queue_worker_pkg vs loader
  ELSIF 1152-1201, x_success:=TRUE fall-through at :1203); (2) GLBudgets dual identity
  (RUN_GL_BUDGETS renames to 'GLBudgetBalances' at dmt_loader_pkg.pkb.sql:4726 plus 9 loader
  arms); (3) retire 1099Invoices; (4) remove dead PlanningBudgets engine arms.
- Promoted the 15 owner-approved rules plus the Pipeline column, the SupplierBankAccounts row,
  and the canonical lookup registry to accepted (black).

**Rule established this session:** In this design doc, RED means exactly one thing --
awaiting the owner's approval. Work-done status is tracked in the Status column, never by
color. Proposed work becomes a backlog item, which may be red until approved.

**Open items awaiting the owner (all red in the doc):** the Post-Install rule
(setup_runtime_config.py taking the connections-file path as an argument -- not yet approved),
the tightened seed-departure rule, the BIP checker rule, the four new backlog entries, and
the pre-existing red section-12 rows from earlier sessions.

**What's next:** These design-doc changes are NOT this session's priority for follow-up work.
The active priority order (restated by the owner 2026-07-14) is:
1. DMT rebuild on the local Docker (primary).
2. Generic per-object flow review (the canonical per-object processing recipe / generic
   starter flow).
3. APEX install on the local Docker.
4. Requirements design review (DMT_DESIGN.html) -- this session's work; now behind the three
   above. Next design-doc action is to get owner rulings on the red items listed above, then
   promote or remove them.

**Blockers:** Today's DMT_DESIGN.html and Customers/README.md changes are NOT yet committed to
git. DMT2 main is protected, so this needs a short-lived branch plus a PR before the changes
land. Three timestamped safety archives (DMT_DESIGN.html.archive.2026071*) are in docs/ and
should not be committed.
