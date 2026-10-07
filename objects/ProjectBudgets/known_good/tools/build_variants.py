"""Build prefixed known-good-format and DMT-format variants of PjoBudgetsXface.csv (+ one BAD row)."""
import csv, io, zipfile, os
D = os.path.dirname(os.path.abspath(__file__))
src = list(csv.reader(open(os.path.join(D, '..', 'original', 'PjoBudgetsXface.csv'), newline='')))
assert all(len(r) == 63 for r in src), [len(r) for r in src]


def prefixed(rows, p):
    out = []
    for r in rows:
        r = list(r)
        r[6] = f'{p} {r[6]}'            # col 7 plan version name -> unique new version
        r[15] = f'{p}_{r[15]}'          # col 16 source budget line reference
        out.append(r)
    bad = list(out[-1])                  # mirror the CFIT022 LINE row ...
    bad[2] = f'{p}NOPROJ'                # col 3 project number that does not exist
    bad[5] = f'{p}NOPROJ'                # col 6 task number
    bad[15] = f'{p}_BAD_NOPROJ'
    out.append(bad)
    return out


def kg_csv(rows):        # known-good layout: unquoted, CRLF, 63 cols incl. -1318020000 + END
    b = io.StringIO()
    w = csv.writer(b, lineterminator='\r\n', quoting=csv.QUOTE_MINIMAL)
    for r in rows:
        w.writerow(r)
    return b.getvalue()


def dmt_csv(rows):       # DMT generator layout: every field quoted, LF, 62 cols, col 29 empty, no END
    lines = []
    for r in rows:
        r = list(r[:62])
        r[28] = ''
        lines.append(','.join('"' + v.replace('"', '""') + '"' for v in r))
    return '\n'.join(lines) + '\n'


for name, p, fn, csvname, f in (('A', '97101', 'PjoBudgetsXface.zip', 'PjoBudgetsXface.csv', kg_csv),
                                ('B', '97102', 'ProjectBudgets_97102.zip', 'PjoPlanVersionsXface.csv', dmt_csv)):
    rows = prefixed(src, p)
    body = f(rows)
    d = os.path.join(D, 'run', name)
    os.makedirs(d, exist_ok=True)
    open(os.path.join(d, csvname), 'w', newline='').write(body)
    with zipfile.ZipFile(os.path.join(d, fn), 'w', zipfile.ZIP_DEFLATED) as z:
        z.writestr(csvname, body)
    print(name, fn, csvname, len(rows), 'rows')
    print(body)
