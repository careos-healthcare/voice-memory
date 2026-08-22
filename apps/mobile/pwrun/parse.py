import json, sys, glob, os, collections

def parse(outdir):
    results = {}  # (suite, name) -> status
    errors = {}   # (suite, name) -> error text
    loaderr = []
    for f in sorted(glob.glob(os.path.join(outdir, 'batch*.json'))):
        suites = {}   # suiteID -> path
        tests = {}    # testID -> (suite, name)
        for line in open(f, encoding='utf-8', errors='replace'):
            line = line.strip()
            if not line.startswith('{'):
                continue
            try:
                e = json.loads(line)
            except Exception:
                continue
            t = e.get('type')
            if t == 'suite':
                suites[e['suite']['id']] = e['suite']['path']
            elif t == 'testStart':
                tst = e['test']
                sid = tst.get('suiteID')
                path = suites.get(sid, '?')
                name = tst.get('name', '?')
                tests[tst['id']] = (path, name)
            elif t == 'testDone':
                key = tests.get(e['testID'])
                if key is None:
                    continue
                if e.get('hidden'):
                    # loading/compile errors surface as hidden tests
                    if e.get('result') != 'success':
                        results[key] = 'LOADFAIL'
                    continue
                results[key] = 'PASS' if e.get('result') == 'success' else 'FAIL'
            elif t == 'error':
                key = tests.get(e['testID'])
                if key:
                    errors.setdefault(key, '')
                    errors[key] += (e.get('error') or '') + '\n'
            elif t == 'print':
                key = tests.get(e['testID'])
                if key:
                    errors.setdefault(key, '')
                    errors[key] += (e.get('message') or '') + '\n'
        # capture stderr
        errf = f.replace('.json', '.err')
        if os.path.exists(errf):
            s = open(errf, encoding='utf-8', errors='replace').read().strip()
            if s:
                loaderr.append((os.path.basename(f), s[:2000]))
    return results, errors, loaderr

outdir = sys.argv[1]
results, errors, loaderr = parse(outdir)

fails = {k: v for k, v in results.items() if v != 'PASS'}
bysuite = collections.Counter(k[0] for k in fails)

print(f"TOTAL tests: {len(results)}   PASS: {sum(1 for v in results.values() if v=='PASS')}   FAIL: {len(fails)}")
print()
print("=== FAILURES BY SUITE ===")
for s, c in sorted(bysuite.items()):
    print(f"{c:4d}  {os.path.basename(s)}")
print()
print("=== FAILURES (sorted by suite, name) ===")
for (s, n) in sorted(fails):
    print(f"[{os.path.basename(s)}] {n}")
if len(sys.argv) > 2 and sys.argv[2] == '-v':
    print()
    print("=== ERROR DETAIL ===")
    for (s, n) in sorted(fails):
        print(f"--- [{os.path.basename(s)}] {n}")
        raw = errors.get((s, n), '(no error captured)')
        # strip drift multiple-database warning noise
        lines = raw.split('\n')
        out, skip = [], False
        for ln in lines:
            if ln.startswith('WARNING (drift)'):
                skip = True
            elif skip and (ln.startswith('#') or ln.startswith('Try to follow')
                           or ln.startswith('Here is the stacktrace')
                           or ln.strip() == '' or ln.startswith('<asynchronous')):
                continue
            else:
                skip = False
            if not skip:
                out.append(ln)
        print('\n'.join(out)[:1200])
if loaderr:
    print()
    print("=== STDERR ===")
    for f, s in loaderr:
        print(f"--- {f}\n{s}")
