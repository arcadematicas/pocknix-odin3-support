#!/bin/bash
# check-decky.sh — ¿llevamos la última versión ESTABLE de Decky Loader?
#
# Decky Loader en la Odin corre VIA FEX con el PluginLoader x86_64 OFICIAL de
# SteamDeckHomebrew/decky-loader (ver packages/pocknix-decky). Su QAM de actualización
# está roto en ARM, así que la única forma de subir de versión es empaquetarla aquí y/o
# dejar que el autoactualizador del dispositivo (pocknix-decky-update) la traiga.
#
# Este script SOLO INFORMA: compara la versión que llevamos en el paquete con la última
# release ESTABLE upstream y dice si hay una nueva, con el asset/URL a bajar.
#
# Códigos de salida (para CI / hooks):
#   0  al día
#   1  hay versión nueva (desactualizado)     <-- lo que quieres cazar en CI
#   2  no se pudo determinar (sin red / API / parseo)
#
# Uso:
#   tools/check-decky.sh                                  # paquete del centro
#   tools/check-decky.sh --loader-version-file /tmp/ver   # fuerza "nuestra" versión (pruebas)
#   tools/check-decky.sh --tree ~/…/pocknix-os            # lee el paquete del árbol de compilación
#   tools/check-decky.sh --prereleases                    # compara con la última release, incluidas -pre
#
# Dependencias: curl + python3 (o jq si está). No toca nada.
set -u

REPO="SteamDeckHomebrew/decky-loader"
API="https://api.github.com/repos/${REPO}"
UA="pocknix-check-decky"

SELF="$(readlink -f "${BASH_SOURCE[0]}")"
ROOT="${POCKNIX_ROOT:-$(cd "$(dirname "$SELF")/.." && pwd)}"

TREE=""
VERSION_FILE=""
PRE=0
usage() { awk 'NR==1{next} /^#/{sub(/^# ?/,"");print;next} {exit}' "$SELF"; exit "${1:-0}"; }

while [ $# -gt 0 ]; do
  case "$1" in
    --tree)                 TREE="${2:?falta ruta}"; shift 2 ;;
    --tree=*)               TREE="${1#*=}"; shift ;;
    --loader-version-file)  VERSION_FILE="${2:?falta ruta}"; shift 2 ;;
    --loader-version-file=*) VERSION_FILE="${1#*=}"; shift ;;
    --prereleases|--pre)    PRE=1; shift ;;
    -h|--help)              usage 0 ;;
    *) echo "opción desconocida: $1" >&2; usage 2 ;;
  esac
done

# --- dónde vive el paquete pocknix-decky que define nuestra versión ------------
PKG_DIR="${ROOT}/packages/pocknix-decky"
[ -n "$TREE" ] && PKG_DIR="${TREE}/packages/shared/pocknix-decky"
PKGBUILD="${PKG_DIR}/PKGBUILD"

# --- "nuestra" versión ---------------------------------------------------------
our=""; our_src=""
if [ -n "$VERSION_FILE" ]; then
  [ -f "$VERSION_FILE" ] || { echo "!! no existe el fichero de versión: $VERSION_FILE" >&2; exit 2; }
  our="$(head -n1 "$VERSION_FILE" | tr -d '[:space:]')"
  our_src="$VERSION_FILE"
elif [ -f "${PKG_DIR}/.loader.version" ]; then
  # si algún día el paquete trae el .loader.version como fichero, es la fuente
  our="$(head -n1 "${PKG_DIR}/.loader.version" | tr -d '[:space:]')"
  our_src="$(basename "$PKG_DIR")/.loader.version"
elif [ -f "$PKGBUILD" ]; then
  our="$(grep -m1 '^_loaderver=' "$PKGBUILD" | cut -d= -f2- | tr -d '"'"'"'[:space:]')"
  # si por lo que sea el fichero de versión se genera a mano, cae aquí
  [ -n "$our" ] || our="$(grep -m1 '^pkgver=' "$PKGBUILD" | cut -d= -f2- | tr -d '"'"'"'[:space:]')"
  our_src="${PKGBUILD#$ROOT/} (_loaderver)"
else
  echo "!! no encuentro el paquete pocknix-decky (probé ${PKGBUILD})" >&2
  exit 2
fi

if [ -z "$our" ]; then
  echo "!! no pude sacar nuestra versión de ${our_src:-?}" >&2
  exit 2
fi

# --- última release upstream ---------------------------------------------------
# Devuelve: tag|published|prerelease|asset_name|asset_url|asset_size
fetch_upstream() {
  local url="$1" resp code body
  resp="$(curl -sS --max-time 30 -w $'\n%{http_code}' \
    -H 'Accept: application/vnd.github+json' \
    -H "User-Agent: ${UA}" "$url" 2>/dev/null)" || { echo "__NETERR__"; return; }
  if [ -z "$resp" ]; then echo "__NETERR__"; return; fi
  code="${resp##*$'\n'}"; body="${resp%$'\n'*}"
  case "$code" in
    000|"")  echo "__NETERR__"; return ;;
    403|429) echo "__RATELIMIT__"; return ;;
    200)     : ;;
    *)       echo "__HTTPERR__ ${code}"; return ;;
  esac
  if command -v python3 >/dev/null 2>&1; then
    printf '%s' "$body" | python3 "$PY_PICK"
  elif command -v jq >/dev/null 2>&1; then
    # jq: /releases da lista; /releases/latest da objeto
    printf '%s' "$body" | jq -r '
      (if type=="array" then (map(select(.draft==false))|.[0]) else . end) as $r
      | if ($r|type)!="object" or ($r.tag_name|type)!="string" then "__PARSEERR__"
        else ($r.assets|map(select(.name=="PluginLoader"))|.[0]) as $a
        | "\($r.tag_name)|\($r.published_at // "")|\($r.prerelease)|\($a.name // "")|\($a.browser_download_url // "")|\($a.size // 0)"
        end'
  else
    echo "__NOPARSER__"
  fi
}

# python3 helper (leído por stdin): recibe un objeto de release o una lista; escoge
# el primer no-draft y saca tag|fecha|prerelease|asset|url|tamaño del asset PluginLoader.
PY_PICK="$(mktemp "${TMPDIR:-/tmp}/check-decky.XXXXXX.py")"
trap 'rm -f "$PY_PICK"' EXIT
cat >"$PY_PICK" <<'PY'
import json, sys
try:
    d = json.load(sys.stdin)
except Exception:
    print("__PARSEERR__"); raise SystemExit
r = None
if isinstance(d, list):
    for it in d:
        if isinstance(it, dict) and not it.get("draft"):
            r = it; break
elif isinstance(d, dict):
    if d.get("message") and not d.get("tag_name"):
        print("__MSG__ " + str(d["message"]).replace("\n", " ")); raise SystemExit
    r = d
if not r or not isinstance(r.get("tag_name"), str):
    print("__PARSEERR__"); raise SystemExit
a = None
for it in (r.get("assets") or []):
    if it.get("name") == "PluginLoader":
        a = it; break
print("|".join([
    r["tag_name"],
    r.get("published_at") or "",
    "1" if r.get("prerelease") else "0",
    (a or {}).get("name", ""),
    (a or {}).get("browser_download_url", ""),
    str((a or {}).get("size", 0) or 0),
]))
PY

echo "=== DECKY LOADER (PluginLoader x86_64, via FEX) ==="
echo "  repo upstream : ${REPO}"
echo "  nuestra       : ${our}   (${our_src})"
echo ""

if [ "$PRE" = 1 ]; then
  up_raw="$(fetch_upstream "${API}/releases?per_page=10")"
  up_kind="última release (incluye prereleases)"
else
  up_raw="$(fetch_upstream "${API}/releases/latest")"
  up_kind="última release ESTABLE"
fi

case "$up_raw" in
  __NETERR__)     echo "  upstream      : (no se pudo consultar GitHub — ¿sin red?)"; echo; echo "check-decky: sin red, no se pudo determinar."; exit 2 ;;
  __RATELIMIT__)  echo "  upstream      : (rate limit de la API de GitHub — reintenta o usa un token)"; echo; echo "check-decky: no se pudo determinar (rate limit)."; exit 2 ;;
  __HTTPERR__*)   echo "  upstream      : (error HTTP ${up_raw#__HTTPERR__ })"; echo; exit 2 ;;
  __PARSEERR__)   echo "  upstream      : (respuesta de GitHub no parseable)"; echo; exit 2 ;;
  __NOPARSER__)   echo "  upstream      : (ni python3 ni jq disponibles para parsear el JSON)"; echo; exit 2 ;;
  __MSG__*)       echo "  upstream      : (GitHub dice: ${up_raw#__MSG__ })"; echo; exit 2 ;;
  "")
    echo "  upstream      : (release sin tag)"; echo; exit 2 ;;
esac

IFS='|' read -r up_tag up_date up_pre up_asset up_url up_size <<<"$up_raw"
[ -n "$up_tag" ] || { echo "  upstream      : (no pude leer el tag)"; echo; exit 2; }

# normaliza para comparar: -pre/~pre ordenan por debajo del release (como pocknix-decky-sync)
norm() { printf '%s' "$1" | sed 's/-/~/g'; }
our_n="$(norm "$our")"; up_n="$(norm "$up_tag")"

echo "  upstream      : ${up_tag}   (${up_kind}${up_pre:+$([ "$up_pre" = 1 ] && echo ', PRERELEASE')}; ${up_date})"
if [ -n "$up_asset" ]; then
  echo "  asset         : ${up_asset} (${up_size} B)"
  echo "  url           : ${up_url}"
else
  echo "  asset         : (¡ojo! la release no trae un asset llamado 'PluginLoader')"
fi
echo ""

newest="$(printf '%s\n%s\n' "$our_n" "$up_n" | sort -V | tail -n1)"
if [ "$our_n" = "$up_n" ]; then
  echo "  -> ✅ al día (${our})"
  echo
  echo "check-decky: OK — llevamos la última (${our})."
  exit 0
elif [ "$newest" = "$up_n" ]; then
  echo "  -> ⬆️  hay versión NUEVA (${our} → ${up_tag})"
  echo
  echo "     Opciones:"
  echo "       1) Deja que el dispositivo se actualice solo: el timer pocknix-decky-update"
  echo "          (paquete pocknix-decky) instala la última estable en ~/homebrew sin reiniciar nada."
  echo "       2) Empaquetarla: sube _loaderver + su sha256sums en packages/pocknix-decky/PKGBUILD"
  echo "          y bumpea pkgrel (así una imagen nueva la siembra desde el arranque)."
  echo
  echo "check-decky: DESACTUALIZADO — ${our} -> ${up_tag}."
  exit 1
else
  echo "  -> ✅ al día (vamos por delante: ${our} > ${up_tag})"
  echo
  echo "check-decky: OK — vamos por delante de upstream (${our} > ${up_tag})."
  exit 0
fi
