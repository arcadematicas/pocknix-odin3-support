#!/usr/bin/env bash
# ===========================================================================
#  watch-superzsnes-arm.sh — avisa cuando SUPER ZSNES exista para aarch64
# ===========================================================================
#  Estado a 02/10/2026: NO hay build ARM64.
#    - El binario oficial de Linux es x86_64 (verificado: e_machine 0x3e en el
#      ejecutable y en su UnityPlayer.so).
#    - El AppImage de pkgforge tambien es solo x86_64.
#    - SuperZSNES esta escrito en C# sobre Unity (IL2CPP), NO en C/C++: el
#      tarball "Linux" no trae fuentes (cero .c/.cpp), asi que no se puede
#      compilar por nuestra cuenta.
#    - Unity SI soporta Linux ARM64 desde 6.3/6.5 (paquete
#      com.unity.sdk.linux-arm64), asi que es cuestion de que ellos publiquen
#      el target. El escollo probable es su plugin de Steamworks.
#
#  USO
#    tools/watch-superzsnes-arm.sh            # una consulta y sale
#    tools/watch-superzsnes-arm.sh --wait     # revisa cada hora, avisa al vuelo
#    tools/watch-superzsnes-arm.sh --wait 1800   # cada media hora
#
#  Sale con codigo 0 siempre (es un vigilante, no un test).
# ===========================================================================
set -uo pipefail

REPO="pkgforge-dev/SUPER-ZSNES-AppImage"
INTERVALO=3600
[ "${1:-}" = "--wait" ] && { ESPERAR=1; [ -n "${2:-}" ] && INTERVALO="$2"; } || ESPERAR=0

consulta() {
    python3 - "$REPO" <<'PY'
import json, sys, urllib.request
repo = sys.argv[1]
try:
    req = urllib.request.Request("https://api.github.com/repos/%s/releases?per_page=6" % repo)
    req.add_header("Accept", "application/vnd.github+json")
    req.add_header("User-Agent", "alfred")
    with urllib.request.urlopen(req, timeout=30) as x:
        rs = json.load(x)
except Exception as e:
    print("ERROR  no se pudo consultar GitHub: %s" % e); raise SystemExit(0)

arm64 = []
for rel in rs:
    for a in rel.get("assets", []):
        n = a["name"].lower()
        if "zsnes" in n and any(k in n for k in ("aarch64", "arm64", "armv7")):
            arm64.append((rel["tag_name"], a["name"], a["size"], a["browser_download_url"]))

if arm64:
    print("SI")
    for tag, nombre, tam, url in arm64:
        print("   %s | %s | %.1f MB" % (tag, nombre, tam/1048576))
        print("   %s" % url)
else:
    ult = rs[0] if rs else {}
    print("NO")
    print("   ultima release: %s (%s)" % (ult.get("tag_name", "?"), (ult.get("published_at") or "?")[:10]))
    for a in (ult.get("assets") or [])[:4]:
        print("     %s" % a["name"])
PY
}

revisar() {
    local salida; salida="$(consulta)"
    if printf '%s' "$salida" | head -1 | grep -q '^SI$'; then
        printf '\n\033[1m🎉 ¡YA HAY BUILD ARM64 DE SUPER ZSNES!\033[0m\n'
        printf '%s\n' "$salida" | tail -n +2
        return 0
    fi
    printf '%s  [%s] %s\n' "$(date '+%F %T')" "$REPO" "$(printf '%s' "$salida" | tail -n +2 | tr '\n' ' ')"
    return 1
}

if [ "$ESPERAR" = 0 ]; then
    revisar
    exit 0
fi

echo "Vigilando $REPO cada ${INTERVALO}s (Ctrl+C para salir)..."
while true; do
    revisar && exit 0
    sleep "$INTERVALO"
done
