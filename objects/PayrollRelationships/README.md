# PayrollRelationships

## Status: NOT a standalone HDL load — model correction required (2026-09-17)

A live HCM integration run (run 142) failed this object with:

> `[FUSION_ERROR] The PayrollRelationship file name isn't valid. You need to use
> the name of a top-level supported business object as the file name.; The
> PayrollRelationships_142.zip file doesn't contain valid data files.`

### Root cause

The generator (`db/packages/dmt_pay_rel_hdl_gen_pkg`) builds a standalone
`PayrollRelationship.dat` and asserts (in its header comment) that a payroll
relationship is *"standalone (NOT a Worker component)."* That assumption is
wrong. In Oracle Fusion HCM, **the payroll relationship is created automatically
when a person is hired** (when the work relationship / employment is created for
a person in a legislative data group). There is **no top-level `PayrollRelationship`
HCM Data Loader business object** to create one from scratch, so HDL rejects the
`.dat` file name as not a supported business object.

Per Oracle documentation:

> "When an employee is hired, the application automatically creates the payroll
> relationship details."

HCM Data Loader is used to **load payroll *details onto* the (already existing)
payroll relationship** — payroll relationship details, payroll assignment
records, and assigned-payroll levels — not to create the relationship itself.
That is a different, dependent load (it requires the worker to exist and payroll
to be configured), not the standalone create this generator emits.

Oracle references:
- Overview of Loading Payroll Relationship Details — https://docs.oracle.com/en/cloud/saas/human-resources/24d/fahbo/overview-of-loading-payroll-relationship-details.html
- Loading Payroll Relationships — https://docs.oracle.com/en/cloud/saas/human-resources/20d/fahbo/loading-payroll-relationships.html
- HCM Data Loading Business Objects — https://docs.oracle.com/en/cloud/saas/human-resources/21d/fahbo/loading-payroll-relationships.html

### Recommended resolution (owner decision pending)

1. **Retire the standalone create.** Remove `PayrollRelationships` from the HCM
   pipeline as a standalone load — the payroll relationship comes for free when
   the worker/work-relationship loads. Verify live that a loaded worker gets an
   auto-created row in `PAY_PAY_RELATIONSHIPS_F` (the Contract v1 recon report
   already keys on that table, so it can serve as a read-only *verifier* even
   with no standalone load).
2. **If payroll *details* must be migrated** (assigned payroll, payroll
   relationship attributes), re-model this object to load those onto the existing
   relationship using the correct dependent HDL object/attributes — a separate
   build, dependent on the worker load and payroll configuration on the pod.

### What is confirmed working

- The Contract v1 base-table reconciliation report for this object is built and
  deployed (`bip/PayrollRelationships/`), keyed on `PAY_PAY_RELATIONSHIPS_F`
  via `HRC_INTEGRATION_KEY_MAP`. It correctly returns zero rows today because no
  payroll relationship has been loaded through our (invalid) standalone path.
