#!/bin/bash
# check-decky-plugins.sh — ¿están al día los plugins Decky que vendorizamos?
#
# Compara la versión de NUESTRA copia con la última release upstream de cada plugin:
#   - Panel de Control -> packages/pocknix-decky/panel-de-control   · Hooandee/panel-de-control
#   - MAKO             -> packages/pocknix-decky/mako               · eugeniosegala/MAKO
#
# La versión "nuestra" se lee del `version` de plugin.json; si plugin.json no lo trae
# (es el caso hoy), se usa el `version` de package.json, que es de donde Decky la lee.
#
# Solo INFORMA (no toca nada). Uso: tools/check-decky-plugins.sh
# Pensado para lanzarlo a mano o desde un cron/timer.
#
# No necesita `jq` (usa python3 para el JSON). Tolera: sin red, sin jq y rate-limit de la API.
set -u

SELF="$(readlink -f "${BASH_SOURCE[0]}")"
ROOT="${POCKNIX_ROOT:-$(cd "$(dirname "$SELF")/.." && pwd)}"
DECKY_DIR="${ROOT}/packages/pocknix-decky"
API="https://api.github.com/repos"

# plugin_dir|nombre para mostrar|repo upstream
PLUGINS=(
    "panel-de-control|Panel de Control|Hooandee/panel-de-control"
    "mako|MAKO|eugeniosegala/MAKO"
)

# Nuestra versión: `version` de plugin.json; si no está, la de package.json (lo que lee Decky).
our_version() {
    python3 -c '
import json, sys
d = sys.argv[1]
def read(p):
    try:
        return json.load(open(p))
    except Exception:
        return {}
v = read(d + "/plugin.json").get("version")
if not v:
    v = read(d + "/package.json").get("version")
print(v or "")
' "$1"
}

# Última release upstream. Imprime una marca especial si falla.
#   __NETERR__ / __RATELIMIT__ / __HTTPERR__ <code> / o la versión ya extraída del tag.
upstream_version() {
    local repo="$1" resp code body
    resp="$(curl -sS --max-time 30 -w $'\n%{http_code}' \
        -H 'Accept: application/vnd.github+json' \
        -H 'User-Agent: pocknix-check-decky-plugins' \
        "${API}/${repo}/releases/latest" 2>/dev/null)"
    if [ -z "$resp" ]; then
        echo "__NETERR__"; return
    fi
    code="${resp##*$'\n'}"
    body="${resp%$'\n'*}"
    case "$code" in
        000|"")  echo "__NETERR__"; return ;;
        403|429) echo "__RATELIMIT__"; return ;;
        200)     : ;;
        *)       echo "__HTTPERR__ ${code}"; return ;;
    esac
    printf '%s' "$body" | python3 -c '
import json, re, sys
try:
    d = json.load(sys.stdin)
except Exception:
    print("__PARSEERR__"); raise SystemExit
if isinstance(d, dict) and d.get("message"):
    print("__MSG__ " + str(d["message"]).replace("\n", " ")); raise SystemExit
tag = d.get("tag_name") or d.get("name") or ""
m = re.search(r"[0-9]+(?:\.[0-9]+)*", tag)
print(m.group(0) if m else tag)
'
}

echo "=== NUESTROS PLUGINS DECKY VENDORIZADOS ==="
echo "  directorio: ${DECKY_DIR}"
echo ""

for entry in "${PLUGINS[@]}"; do
    IFS='|' read -r name label repo <<< "$entry"
    dir="${DECKY_DIR}/${name}"

    echo "=== ${label} (${repo}) ==="
    if [ ! -d "$dir" ]; then
        echo "  (no encuentro ${dir})"
        echo ""
        continue
    fi

    our="$(our_version "$dir")"
    [ -n "$our" ] || our="(desconocida)"
    echo "  nuestra : ${our}"

    up="$(upstream_version "$repo")"
    case "$up" in
        __NETERR__)
            echo "  upstream: (no se pudo consultar GitHub — ¿sin red?)"
            ;;
        __RATELIMIT__)
            echo "  upstream: (rate limit de la API de GitHub — reintenta más tarde o usa un token)"
            ;;
        __HTTPERR__*)
            echo "  upstream: (error HTTP ${up#__HTTPERR__ })"
            ;;
        __PARSEERR__)
            echo "  upstream: (respuesta de GitHub no parseable)"
            ;;
        __MSG__*)
            echo "  upstream: (GitHub dice: ${up#__MSG__ })"
            ;;
        "")
            echo "  upstream: (release sin tag)"
            ;;
        *)
            echo "  upstream: ${up}"
            if [ "$our" = "$up" ]; then
                echo "  -> ✅ al día"
            elif [ "$(printf '%s\n%s\n' "$our" "$up" | sort -V | tail -1)" = "$up" ]; then
                echo "  -> ⬆️  hay versión nueva (${our} → ${up})"
                echo "     Re-vendoriza la última release en ${dir#$ROOT/}/ y bumpea pkgrel."
            else
                echo "  -> ✅ al día (vamos por delante: ${our} > ${up})"
            fi
            ;;
    esac
    echo ""
done

echo "=== Recordatorio ==="
echo "  Panel de Control se AUTORREVISA/SELF-UPDATEA en el dispositivo; el sync solo lo"
echo "  siembra cuando falta. Re-vendorizar = bajar el .zip de la release, sustituir el"
echo "  contenido de packages/pocknix-decky/<plugin>/ y bumpear pkgrel de pocknix-decky."
echo "  Ojo: al re-vendorizar Panel de Control hay que re-aplicar el parche local que pone"
echo "  hdr=True en el perfil ayn_odin3 (ver panel-de-control/NOTES.pocknix.md)."
