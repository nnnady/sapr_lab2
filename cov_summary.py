# итог покрытия по файлам: строки (line), ветвления (branch), переключения битов (toggle)
import re, sys, collections

stat = collections.defaultdict(lambda: [0, 0])   # (файл, тип) -> [всего точек, покрыто]
missed = []                                      # непокрытые строки и ветвления
for line in open(sys.argv[1], encoding='utf-8', errors='replace'):
    m = re.match(r"C '(.*)' (\d+)", line.rstrip('\n'))
    if not m:
        continue
    kv = dict(x.split('\x02', 1) for x in m.group(1).split('\x01') if '\x02' in x)
    count = int(m.group(2))
    fname = kv.get('f', '')
    kind = kv.get('page', '').split('/')[0].replace('v_', '')
    stat[(fname, kind)][0] += 1
    stat[(fname, kind)][1] += count > 0
    if count == 0 and kind != 'toggle':
        missed.append(f"{fname}:{kv.get('l')} {kind} {kv.get('o', '')}")

print(f"{'file':<18}{'type':<8}{'covered':>10}{'percent':>10}")
for (fname, kind), (total, hit) in sorted(stat.items()):
    print(f"{fname:<18}{kind:<8}{hit:>5}/{total:<4}{100 * hit / total:>9.1f}%")
print("\nnot covered (lines/branches):")
for x in missed:
    print("  " + x)
