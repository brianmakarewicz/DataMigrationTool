"""Assemble a loadable FBDI zip or HDL zip from templated members.

Given an object recipe and a numeric prefix, this reads the object's templated
member file(s), replaces every ${PREFIX} token with the prefix and every
discovered ${TOKEN} with the value found on the TARGET pod at load time, then
writes the artifact:

  - FBDI (recipe "type":"FBDI"): a .zip whose internal CSV names match the FBDI
    control files Fusion expects (e.g. ApInvoicesInterface.csv). FBDI CSVs have
    NO header row; the templated CSV already carries the position-based layout.
  - HDL  (recipe "type":"HDL"):  a .zip whose internal member is the .dat file
    (e.g. Worker.dat). HDL uploads a zip containing the DAT; the harness zips
    the single DAT member.

${PREFIX} is stamped onto natural keys so the same fixture reloads without
colliding. Discovered ${TOKEN}s (supplier, business unit, legal employer, ...)
make the fixture portable to any pod (rules 6-8).

Usage:
    python build_artifact.py APInvoices 96271
    python build_artifact.py Workers    96271 --no-discovery   # offline stamp only
"""
import os
import sys
import argparse
import zipfile

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
ROOT = os.path.dirname(HERE)  # gold_regression/
from recipe import load_recipe, load_objects, object_dir  # noqa: E402,F401
import discover  # noqa: E402


def _members(recipe):
    """Return the list of member specs (template -> archive name), from the FBDI
    "csvs" list or the HDL "dat"/"members" list."""
    if recipe.get('csvs'):
        return [(m['template'], m['fbdi_name']) for m in recipe['csvs']]
    if recipe.get('members'):
        return [(m['template'], m['archive_name']) for m in recipe['members']]
    if recipe.get('dat'):
        d = recipe['dat']
        return [(d['template'], d['archive_name'])]
    raise KeyError('recipe has no csvs/members/dat member list')


def derived_tokens(prefix):
    """Return the tokens computed FROM the prefix alone (not discovered).

    Broken out of build() so the SAME values are available to verify.py (whose
    base read may need to scope on a prefix-derived date/id it also stamped into
    the artifact). Pure function of the prefix; no I/O.
    """
    prefix = str(prefix)
    # SSNs must be 1xx-8xx, never 9xx/000/666. A 5-digit prefix gives a 9-digit
    # SSN of the form 1<prefix5>0NN starting with 1.
    p5 = prefix.zfill(5)[-5:]
    import datetime as _dt
    _today = _dt.date.today()
    return {
        'SSN1': '1' + p5 + '001',
        'SSN2': '1' + p5 + '002',
        # Today's date for artifacts that must carry an open-period date on the
        # rows themselves (e.g. AR AutoInvoice trx/GL dates -- a stale hardcoded
        # date lands in a closed period and AutoInvoice selects/derives nothing).
        'GL_DATE': _today.strftime('%Y-%m-%d'),
        'GL_DATE_SLASH': _today.strftime('%Y/%m/%d'),
        # One year after today, YYYY/MM/DD. Used by the Projects v2 seeded fixture
        # as the project (and task) finish date so the project window is always
        # open around today -- a hard-coded 2025 window would fall in the past and
        # is not required to be any specific date, only to bracket the task dates.
        'PRJ_FINISH_SLASH': (_today + _dt.timedelta(days=365)).strftime('%Y/%m/%d'),
        # GL accounting-period NAME for today, in the demo pod's calendar naming
        # convention MM-YY (e.g. today 2026-07-20 -> '07-26'; confirmed live via
        # gl_period_statuses on US Primary Ledger). Used by the GLBalances v2
        # seeded fixture so the journal always names the period that is OPEN today
        # -- a hard-coded period name would break the moment that period closes.
        'GL_PERIOD': _today.strftime('%m-%y'),
        # MM/DD/YYYY form for FBDI members whose CTL parses dates as MM/DD/YYYY
        # (e.g. Billing Events COMPLETION_DATE -- see the FBDI generator's fmt_date).
        'GL_DATE_MDY': _today.strftime('%m/%d/%Y'),
        # YYYY/MM/DD HH24:MI:SS form for the inventory transaction interface
        # TRANSACTION_DATE (InvTransactionsInterface.ctl parses it with
        # to_date(:TRANSACTION_DATE,'YYYY/MM/DD HH24:MI:SS')). Use today's date
        # so the misc receipt lands in an open inventory accounting period.
        'TXN_DATE': _dt.datetime.now().strftime('%Y/%m/%d %H:%M:%S'),
        # A small run-distinguishable positive integer derived from the prefix,
        # used by fixtures that must write a numeric attribute whose value proves
        # "this run wrote it" in the base table (e.g. the TaxCards fixture stamps
        # it as the Federal Extra Withholding dollar amount). Range 100-999 so it
        # is always a valid positive amount and visibly non-default.
        'EXTRA_WH': str(100 + (int(p5) % 900)),
        # A date-effective key derived UNIQUELY from the prefix, for fixtures that
        # add a new date-effective segment to a FIXED (hard-coded) seeded parent
        # on every run -- e.g. a Salary change on one seeded assignment. Because
        # each run gets a fresh prefix, each run gets a distinct DateFrom, so a
        # second consecutive run against the same assignment inserts a NEW
        # date-effective segment instead of colliding on an existing one. Base
        # 2020-01-01 + prefix days keeps every value a valid, future-enough,
        # run-unique date (max prefix 99999 days ~= year 2293, well inside range).
        'SAL_DATE': (_dt.date(2020, 1, 1) +
                     _dt.timedelta(days=int(p5))).strftime('%Y/%m/%d'),
        'SAL_DATE_DASH': (_dt.date(2020, 1, 1) +
                          _dt.timedelta(days=int(p5))).strftime('%Y-%m-%d'),
        # A prefix-derived date-effective key for the PayrollRelationships v2
        # seeded fixture (HDL AssignedPayroll). Assigning a payroll to a seeded
        # employee is stateful: an AssignedPayroll MERGE is keyed on the
        # AssignmentNumber plus its StartDate, so a fixed date would collide on a
        # second run against the same hard-coded assignment. Deriving the date
        # from the prefix (base 2020-01-01 + prefix days) gives every run a
        # distinct StartDate, so each run adds a NEW date-effective assigned-
        # payroll segment on the same seeded assignment instead of colliding --
        # the same mechanism as SAL_DATE for Salaries. PAY_DATE is YYYY/MM/DD
        # (HDL .dat EffectiveStartDate/StartDate); PAY_DATE_DASH is YYYY-MM-DD for
        # the verify base read (scopes on ap.start_date = this run's date).
        'PAY_DATE': (_dt.date(2020, 1, 1) +
                     _dt.timedelta(days=int(p5))).strftime('%Y/%m/%d'),
        'PAY_DATE_DASH': (_dt.date(2020, 1, 1) +
                          _dt.timedelta(days=int(p5))).strftime('%Y-%m-%d'),
        # A prefix-derived absence window for the Absences v2 seeded fixture. An
        # absence entry is keyed by person + start/end dates, so a fixed date
        # would collide on a second run against the same seeded person. Deriving
        # the window from the prefix (base 2020-01-01 + prefix days) gives every
        # run a distinct start/end, so consecutive runs book NEW distinct absence
        # windows on the same seeded persons instead of colliding. Fusion rejects
        # an absence whose date is not a scheduled workday ("You need to enter an
        # absence date that's on a scheduled workday") -- the person's assignment
        # work schedule only covers dates NEAR the present, not centuries out, so
        # the window must stay close to today. The start is today + (30..330) days
        # (offset derived from the prefix, so each run differs), then snapped
        # FORWARD to the next Monday; the two-day window is Monday->Tuesday, both
        # weekdays on the standard demo work schedule and inside the scheduled
        # horizon. Distinct offset per prefix => consecutive runs book distinct,
        # non-colliding windows. ABS_START/ABS_END are YYYY/MM/DD (HDL .dat
        # StartDate/EndDate); ABS_START_DASH is YYYY-MM-DD for the verify read.
        **(lambda _s: {
            'ABS_START': _s.strftime('%Y/%m/%d'),
            'ABS_END': (_s + _dt.timedelta(days=1)).strftime('%Y/%m/%d'),
            'ABS_START_DASH': _s.strftime('%Y-%m-%d'),
        })((lambda _d: _d + _dt.timedelta(days=(7 - _d.weekday()) % 7))(
            _today + _dt.timedelta(days=30 + (int(p5) % 300)))),
        # A WALL-CLOCK-monotonic date-effective key for the BenParticipant v2
        # seeded fixture. PersonBenefitBalance (unlike Salary) rejects a new
        # date-effective segment whose start date falls BEFORE the person's
        # existing balance record ("you've provided a date-effective row that
        # starts on <earlier> for an existing record that doesn't start until
        # <later>"). A prefix-derived date is NOT safe here: a smaller random
        # prefix on a later run gives an EARLIER date, which is rejected. This
        # token advances with the real clock instead -- days since 2020-01-01 off
        # a high base year (2300) -- so each successive calendar day's run starts
        # strictly later than any prior run's segment and MERGE inserts a fresh
        # dated balance. BEN_DATE is YYYY/MM/DD (HDL .dat EffectiveStartDate);
        # BEN_DATE_DASH is YYYY-MM-DD for the verify base read.
        'BEN_DATE': (_dt.date(2300, 1, 1) +
                     _dt.timedelta(days=(_today - _dt.date(2020, 1, 1)).days)
                     ).strftime('%Y/%m/%d'),
        'BEN_DATE_DASH': (_dt.date(2300, 1, 1) +
                          _dt.timedelta(days=(_today - _dt.date(2020, 1, 1)).days)
                          ).strftime('%Y-%m-%d'),
    }


def build(object_name, prefix, tokens=None, recipe=None, log=print):
    """Stamp prefix + discovered tokens into the templated member(s) and zip.

    tokens: dict of extra ${TOKEN} -> value to substitute (from discovery). If
    None, discovery is run automatically when the recipe declares it.
    Returns the absolute path of the written zip.
    """
    prefix = str(prefix)
    recipe = recipe or load_recipe(object_name)
    if tokens is None:
        tokens = discover.run_discovery(recipe, log=log)
    tokens = dict(tokens or {})
    for k, val in derived_tokens(prefix).items():
        tokens.setdefault(k, val)

    obj_dir = object_dir(object_name)
    artifact_dir = os.path.join(obj_dir, 'artifact')
    zip_path = os.path.join(obj_dir, f'{object_name}_gold.zip')

    with zipfile.ZipFile(zip_path, 'w', zipfile.ZIP_DEFLATED) as zf:
        for tmpl, archive_name in _members(recipe):
            with open(os.path.join(artifact_dir, tmpl), 'r', newline='') as f:
                body = f.read()
            body = body.replace('${PREFIX}', prefix)
            for token, val in (tokens or {}).items():
                body = body.replace('${' + token + '}', str(val))
            # Guard: no un-substituted tokens leak into a loaded artifact.
            import re
            leftover = re.findall(r'\$\{[A-Z0-9_]+\}', body)
            if leftover:
                raise RuntimeError(
                    f'{object_name}/{tmpl}: un-substituted tokens {set(leftover)}. '
                    'Every ${TOKEN} must be PREFIX or a discovered value.')
            zf.writestr(archive_name, body)
    log(f'built {zip_path} (prefix {prefix}, tokens {sorted((tokens or {}).keys())})')
    return zip_path


if __name__ == '__main__':
    ap = argparse.ArgumentParser()
    ap.add_argument('object_name')
    ap.add_argument('prefix')
    ap.add_argument('--no-discovery', action='store_true',
                    help='skip live discovery (offline stamp of ${PREFIX} only; '
                         'artifact will still fail the leftover-token guard if '
                         'the template has discovered tokens)')
    a = ap.parse_args()
    toks = {} if a.no_discovery else None
    out = build(a.object_name, a.prefix, tokens=toks)
    print(f'built {out} with prefix {a.prefix}')
