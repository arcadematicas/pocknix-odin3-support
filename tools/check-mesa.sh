#!/bin/bash
# check-mesa.sh — ¿esta nuestro stack grafico al dia?
#
# Compara lo que publica upstream con lo que tenemos pineado en el repo:
#   - Mesa estable       -> packages/soc/mesa/PKGBUILD            (pkgver)
#   - Ramas Turnip       -> packages/soc/pocknix-turnip-arm/      (_versions)
#   - Snapshot de main   -> packages/soc/pocknix-turnip-arm/      (_develcommit)
#
# Solo INFORMA (no toca nada). Uso: tools/check-mesa.sh
# Pensado para lanzarlo a mano o desde un cron/timer.
set -u

SELF="$(readlink -f "${BASH_SOURCE[0]}")"
ROOT="${POCKNIX_ROOT:-$(cd "$(dirname "$SELF")/.." && pwd)}"
# Nuestras versiones viven en packages/soc-overrides/<name>/ (el sync espeja SOLO lo que
# haya ahi sobre el paquete de upstream en packages/soc/<name>/). Buscamos en el centro,
# en su arbol de compilacion hermano (pocknix-os) y en packages/soc local.
find_pkg() {
    local name="$1" cand
    for cand in \
        "${ROOT}/packages/soc-overrides/${name}/PKGBUILD" \
        "${ROOT}/packages/soc/${name}/PKGBUILD" \
        "${ROOT}/../pocknix-os/packages/soc/${name}/PKGBUILD" \
        "${ROOT}/../pocknix-os/packages/soc-overrides/${name}/PKGBUILD" ; do
        [ -f "$cand" ] && { printf '%s' "$cand"; return 0; }
    done
    return 1
}
MESA_PKG="$(find_pkg mesa)" || true
TURNIP_PKG="$(find_pkg pocknix-turnip-arm)" || true

[ -f "$MESA_PKG" ] || { echo "no encuentro ${MESA_PKG}" >&2; exit 1; }
[ -f "$TURNIP_PKG" ] || { echo "no encuentro ${TURNIP_PKG}" >&2; exit 1; }

our_stable=$(grep -m1 '^pkgver=' "$MESA_PKG" | cut -d= -f2)
our_versions=$(grep -m1 '^_versions=' "$TURNIP_PKG" | sed "s/.*(//;s/).*//" | tr -d "'\"")
our_devel=$(grep -m1 '^_develcommit=' "$TURNIP_PKG" | cut -d= -f2)

echo "=== NUESTRO STACK GRAFICO ==="
echo "  Mesa estable (sistema) : ${our_stable}"
echo "  Ramas Turnip pinadas   : ${our_versions}"
echo "  Snapshot mesa main     : ${our_devel:0:12}"
echo ""

echo "=== UPSTREAM: ultimas Mesa estables publicadas ==="
latest_stable=$(curl -sf --max-time 30 https://archive.mesa3d.org/ 2>/dev/null \
  | grep -oE 'mesa-2[0-9]+\.[0-9]+\.[0-9]+\.tar\.xz' | sort -uV | tail -1 | sed 's/mesa-//;s/\.tar\.xz//')
if [ -z "$latest_stable" ]; then
    echo "  (no se pudo consultar archive.mesa3d.org — sin red?)"
else
    echo "  Ultima estable         : ${latest_stable}"
    if [ "$latest_stable" = "$our_stable" ]; then
        echo "  -> Mesa del sistema AL DIA"
    else
        echo "  -> Mesa del sistema DESACTUALIZADO (${our_stable} -> ${latest_stable})"
        echo "     Revisa las notas: https://docs.mesa3d.org/relnotes/${latest_stable}.html"
        echo "     (si no trae nada de freedreno/Turnip, NO merece la pena el rebuild)"
    fi
    # ramas estables que existen upstream y no tenemos pinadas
    branches=$(curl -sf --max-time 30 https://archive.mesa3d.org/ 2>/dev/null \
      | grep -oE 'mesa-2[0-9]+\.[0-9]+\.[0-9]+\.tar\.xz' | sed 's/mesa-//;s/\.tar\.xz//' \
      | sed -E 's/^([0-9]+\.[0-9]+)\..*/\1/' | sort -uV | tail -4)
    echo "  Ramas upstream recientes: $(echo "$branches" | tr '\n' ' ')"
    echo "     -> si aparece una rama que no esta en _versions, anadela al array"
fi
echo ""

echo "=== UPSTREAM: HEAD de mesa main (para refrescar el devel) ==="
head_sha=$(curl -sf --max-time 30 \
  "https://gitlab.freedesktop.org/api/v4/projects/mesa%2Fmesa/repository/commits?ref_name=main&per_page=1" 2>/dev/null \
  | python3 -c "import json,sys; print(json.load(sys.stdin)[0]['id'])" 2>/dev/null)
if [ -z "$head_sha" ]; then
    echo "  (no se pudo consultar gitlab.freedesktop.org — sin red?)"
else
    echo "  HEAD actual            : ${head_sha:0:12}"
    if [ "${head_sha:0:12}" = "${our_devel:0:12}" ]; then
        echo "  -> snapshot devel AL DIA"
    else
        echo "  -> snapshot devel ATRASADO (${our_devel:0:12} -> ${head_sha:0:12})"
        echo "     Refresca _develcommit en pocknix-turnip-arm y reconstruye el paquete."
    fi
fi
echo ""
echo "=== Recordatorio ==="
echo "  El 'Mesa Version' por juego (PocknixControl -> Games -> Use Per-Game Settings)"
echo "  deja probar cualquier rama de Turnip sin tocar el sistema. Refrescar el devel"
echo "  es la via para 'ir siempre a la ultima' sin arriesgar el driver del sistema."
