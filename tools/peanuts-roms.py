#!/usr/bin/env python3
"""Sondea los .xci/.nsp de una carpeta y los cruza con los perfiles de Peanuts.

Uso: peanuts-roms.py [carpeta]
"""
import os
import re
import subprocess
import sys

DIR = sys.argv[1] if len(sys.argv) > 1 else "/home/deck/romsdisk/batocera/roms/switch"
APPDIR = "/home/deck/Peanuts/appdir"
IMP = os.path.join(APPDIR, "usr/bin/nximport_cli")
KEYS = "/home/deck/.switch/prod.keys"
PROF = "/home/deck/.local/share/peanutsnative/packer/src-715626111bef/dm/games"

FILE_RE = re.compile(r'^(?P<path>.+)  \((?P<n>\d+) titles?, [0-9.]+s\)$')
TITLE_RE = re.compile(r'^\s+title (?P<title>[0-9A-Fa-f]{16})\s+app (?P<app>[0-9A-Fa-f]{16})\s+kind (?P<kind>\S+)\s+version (?P<version>\d+)\s+name "(?P<name>[^"]*)"')

files = sorted(
    os.path.join(DIR, f) for f in os.listdir(DIR)
    if f.lower().endswith((".xci", ".nsp"))
)

res = {}
for i in range(0, len(files), 10):
    batch = files[i:i + 10]
    try:
        p = subprocess.run([IMP, "--keys", KEYS, "probe"] + batch,
                           capture_output=True, text=True, timeout=900)
        out = p.stdout
    except (OSError, subprocess.SubprocessError) as exc:
        print(f"# fallo sondeando lote {i}: {exc}", file=sys.stderr)
        continue
    cur = None
    for line in out.splitlines():
        m = FILE_RE.match(line)
        if m:
            cur = m.group("path")
            res.setdefault(cur, [])
            continue
        m = TITLE_RE.match(line)
        if m and cur:
            res[cur].append({"id": m.group("app").upper(), "kind": m.group("kind"),
                             "ver": int(m.group("version")), "name": m.group("name")})

rows = []
for path, titles in res.items():
    base = [t for t in titles if t["kind"] == "base"]
    upd = [t for t in titles if t["kind"] == "update"]
    if not base:
        continue
    b = base[0]
    ver = upd[0]["ver"] if upd else b["ver"]
    prof = os.path.join(PROF, b["id"], "game.tsv")
    vers = []
    if os.path.isfile(prof):
        for line in open(prof, errors="replace"):
            mm = re.match(r"build\s+v(\d+)", line)
            if mm:
                vers.append(int(mm.group(1)))
    rows.append({
        "size": os.path.getsize(path), "file": os.path.basename(path),
        "id": b["id"], "ver": ver, "vers": vers, "name": b["name"],
        "ok": bool(vers) and ver in vers,
    })

rows.sort(key=lambda r: -r["size"])
print(f"# {len(rows)} juegos; con perfil y versión compatible: {sum(1 for r in rows if r['ok'])}")
print("GB\tVERS\tPERFIL\tID\tNOMBRE")
for r in rows:
    print("%.1f\t%s\t%s\t%s\t%s" % (
        r["size"] / 1e9,
        "OK" if r["ok"] else "no",
        ",".join(str(v) for v in r["vers"]) or "-",
        r["id"],
        r["name"][:42],
    ))
