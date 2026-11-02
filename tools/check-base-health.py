import json, re, subprocess, sys, datetime, urllib.request

lock = sys.argv[1]
pkgs = {}
head = ""
for line in open(lock, encoding="utf-8", errors="replace"):
    line = line.rstrip("\n")
    if line.startswith("#"):
        if not head and "snapshot" in line:
            head = line.lstrip("# ").strip()
        continue
    parts = line.split()
    if len(parts) == 2:
        pkgs[parts[0]] = parts[1]

print(f"base: {head or '(cabecera desconocida)'}")
print(f"paquetes en el snapshot: {len(pkgs)}")
m = re.search(r"snapshot (\d{4})(\d{2})(\d{2})", head or "")
cadencia = 0
if m:
    d = datetime.date(int(m.group(1)), int(m.group(2)), int(m.group(3)))
    age = (datetime.date.today() - d).days
    print(f"edad del snapshot: {age} dias ({d.isoformat()})")
    if age > 90:
        print("cadencia: RE-CORTE recomendado (mas de 3 meses)"); cadencia = 2
    elif age > 60:
        print("cadencia: toca planificar re-corte (mas de 2 meses)"); cadencia = 1
    else:
        print("cadencia: dentro de lo razonable (< 2 meses)")

url = "https://security.archlinux.org/issues/all.json"
try:
    with urllib.request.urlopen(url, timeout=60) as r:
        issues = json.load(r)
except Exception as e:
    print(f"ERROR consultando el tracker: {e}")
    sys.exit(3)

def vercmp(a, b):
    return int(subprocess.run(["vercmp", a, b], capture_output=True, text=True).stdout.strip() or 0)

rank = {"Critical": 0, "High": 1, "Medium": 2, "Low": 3, "Unknown": 4}
hits = []
for it in issues:
    if (it.get("status") or "") not in ("Vulnerable", "Unknown"):
        continue                       # resueltas o no aplicables: fuera
    sev = it.get("severity") or "Unknown"
    fixed = (it.get("fixed") or "").strip()
    for name in (it.get("packages") or []):
        our = pkgs.get(name)
        if not our:
            continue
        if fixed:
            try:
                if vercmp(our, fixed) >= 0:
                    continue           # ya parcheado en el snapshot
            except Exception:
                pass
        hits.append((rank.get(sev, 9), sev, name, our, fixed or "-", it.get("name"), len(it.get("issues") or [])))

hits.sort()
con = [h for h in hits if h[4] != "-"]
graves = [h for h in hits if h[1] in ("Critical", "High")]

print(f"CVEs abiertos que nos afectan: {len(hits)} ({len(con)} con parche publicado)")
for r, sev, name, our, fixed, adv, n in hits[:25]:
    extra = f" < {fixed}" if fixed != "-" else " (sin parche)"
    print(f"  - {sev:8} {name} {our}{extra}  [{adv}, {n} CVE(s)]")
if len(hits) > 25:
    print(f"  ... y {len(hits)-25} mas")

criticos = sorted({h[2] for h in graves if h[4] != "-"})
rc = 0
if not hits:
    print("recomendacion: NADA - la base no tiene CVEs abiertos para nuestros paquetes")
elif not con:
    print("recomendacion: seguimiento - hay CVEs abiertos sin parche publicado")
    rc = 11
else:
    print(f'recomendacion: PARCHE SUELTO con make extend-base PKG="{" ".join(criticos)}"')
    if set(criticos) & {"glibc", "systemd", "openssl", "openssl-1.1"} or len(criticos) > 5:
        print("             (glibc/systemd/openssl o mas de 5 paquetes: mejor RE-CORTE)")
        rc = 10
    else:
        rc = 10
if cadencia == 2:
    rc = max(rc, 10)
sys.exit(rc)
