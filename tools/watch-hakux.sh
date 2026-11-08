#!/usr/bin/env bash
# watch-hakux.sh — avisa cuando portare-ch/hakuX-lr publique un release linux-vX.Y.Z.
#
# hakuX-lr es el core libretro de Xbox. Su release trae el binario YA COMPILADO
# (hakux-<ver>-aarch64.tar.gz): actualizar = subir pkgver + sha256 del PKGBUILD y
# reconstruir el paquete (que solo empaqueta ficheros). NO se compila el core.
#
# Uso:
#   tools/watch-hakux.sh            # una consulta y sale
#   tools/watch-hakux.sh --wait     # revisa cada 6 h (Ctrl+C para salir)
#
# El aviso va por ~/bin/avisar-telegram.sh si existe; si no, solo por stdout.
# Estado en ~/.local/state/hakux-watch.last (evita repetir el mismo aviso).
set -uo pipefail

REPO="portare-ch/hakuX-lr"
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
PKG="$ROOT/packages/libretro-hakux/PKGBUILD"
STATE="${XDG_STATE_HOME:-$HOME/.local/state}/hakux-watch.last"
AVISA="$HOME/bin/avisar-telegram.sh"
INTERVALO=21600

[ "${1:-}" = "--wait" ] && { ESPERAR=1; [ -n "${2:-}" ] && INTERVALO="$2"; } || ESPERAR=0

consulta() {
  python3 - "$REPO" <<'PY'
import json, sys, urllib.request
repo = sys.argv[1]
try:
    req = urllib.request.Request("https://api.github.com/repos/%s/releases?per_page=15" % repo)
    req.add_header("Accept", "application/vnd.github+json")
    req.add_header("User-Agent", "calvos-hakux-watch")
    with urllib.request.urlopen(req, timeout=30) as x:
        rs = json.load(x)
except Exception as e:
    print("ERROR %s" % e); raise SystemExit(0)
for rel in rs:
    tag = rel.get("tag_name") or ""
    if not tag.startswith("linux-v"):
        continue
    ver = tag[len("linux-v"):]
    asset = next((a for a in rel.get("assets", []) if a["name"].endswith("-aarch64.tar.gz")), None)
    if asset:
        print("%s\t%s\t%s" % (ver, asset["name"], asset["browser_download_url"]))
        break
PY
}

pkgver="$(sed -n 's/^pkgver=//p' "$PKG" | head -1)"
salida="$(consulta)"
latest="$(printf '%s' "$salida" | cut -f1)"
asset="$(printf '%s' "$salida" | cut -f2)"
url="$(printf '%s' "$salida" | cut -f3)"

if [ -z "${latest:-}" ]; then
  echo "$(date '+%F %T') hakuX-lr: no se pudo consultar (${salida:-sin salida})"
  exit 0
fi

if [ "$latest" = "$pkgver" ]; then
  echo "$(date '+%F %T') hakuX-lr al día: $pkgver"
  exit 0
fi

if [ "$(printf '%s\n%s\n' "$pkgver" "$latest" | sort -V | tail -1)" != "$latest" ]; then
  echo "$(date '+%F %T') hakuX-lr: el release linux-v$latest es anterior al paquete ($pkgver); nada que hacer"
  exit 0
fi

prev="$(cat "$STATE" 2>/dev/null || true)"
msg="hakuX-lr $latest disponible (paquete $pkgver). Core PREBUILT: $asset — subir pkgver/sha256 y reconstruir el paquete (no compilar). $url"
echo "$(date '+%F %T') $msg"
if [ "$prev" != "$latest" ]; then
  mkdir -p "$(dirname "$STATE")" 2>/dev/null || true
  printf '%s\n' "$latest" > "$STATE" 2>/dev/null || true
  [ -x "$AVISA" ] && "$AVISA" "$msg" >/dev/null 2>&1 || true
fi
exit 0
