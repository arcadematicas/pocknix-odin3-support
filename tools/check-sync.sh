#!/bin/bash
# check-sync.sh — fail if the pocknix-os build tree drifted away from this repo (THE CENTER).
#
# The build calls this, so a stale build tree cannot silently produce an image missing our
# fixes. Exit codes: 0 = in sync, 1 = drift (run tools/sync-to-os.sh), 2 = cannot check.
#
# USAGE
#   tools/check-sync.sh
#   POCKNIX_OS_DIR=/path tools/check-sync.sh
set -uo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
OS="${POCKNIX_OS_DIR:-${HERE}/../pocknix-os}"

if [ ! -d "${OS}" ]; then
  echo "check-sync: pocknix-os not found at ${OS}" >&2
  exit 2
fi

drift=0
missing=0

# compare every file we own against its counterpart in the build tree.
# Los SYMLINKS tambien se comprueban (overlay/usr/bin/FEXInterpreter -> FEX):
# con `-type f` un symlink se escapaba del check, y al no estar en el arbol el
# build lo desplegaria... sin él, sin ningun aviso. Un symlink se compara por su
# TARGET (readlink), no byte a byte del fichero al que apunta.
cmp_tree() {
  local src="$1" dst="$2" rel
  [ -d "${src}" ] || return 0
  while IFS= read -r -d '' f; do
    rel="${f#${src}/}"
    if [ ! -e "${dst}/${rel}" ] && [ ! -L "${dst}/${rel}" ]; then
      echo "  MISSING  ${dst#${OS}/}/${rel}"
      missing=$((missing + 1))
    elif [ -L "${f}" ]; then
      if [ ! -L "${dst}/${rel}" ] || [ "$(readlink "${f}")" != "$(readlink "${dst}/${rel}")" ]; then
        echo "  SYMLINK  ${dst#${OS}/}/${rel} (ours -> $(readlink "${f}"), tree -> $(readlink "${dst}/${rel}" 2>/dev/null || echo 'no es symlink'))"
        drift=$((drift + 1))
      fi
    elif ! cmp -s "${f}" "${dst}/${rel}"; then
      echo "  DIFFERS  ${dst#${OS}/}/${rel}"
      drift=$((drift + 1))
    fi
  done < <(find "${src}" \( -type f -o -type l \) -print0)
}

echo "check-sync: comparing ${HERE} -> ${OS}"
cmp_tree "${HERE}/packages/pocknix-bsp-sm8750"    "${OS}/devices/sm8750/packages/pocknix-bsp-sm8750"
cmp_tree "${HERE}/packages/pocknix-device-sm8750" "${OS}/devices/sm8750/packages/pocknix-device-sm8750"
# El firmware del SoC como PAQUETE: PKGBUILD + ./paths. Si este PKGBUILD se queda atras, la
# imagen sale con el firmware viejo (o sin el) SIN QUE NADA LO DIGA — y el par ADSP del cargador
# es justo lo que evita que la bateria vuelva a TEST MODE. Los blobs no se comprueban aqui: los
# stagea build-packages.sh desde devices/<dev>/firmware/ y vendor/ (gitignored, en el host).
cmp_tree "${HERE}/packages/pocknix-firmware-sm8750" "${OS}/devices/sm8750/packages/pocknix-firmware-sm8750"
cmp_tree "${HERE}/packages/linux-pocknix-sm8750"      "${OS}/packages/soc/linux-pocknix-sm8750"
cmp_tree "${HERE}/packages/pocknix-bootloader-sm8750" "${OS}/packages/soc/pocknix-bootloader-sm8750"
cmp_tree "${HERE}/packages/pocknix-bsp-common"    "${OS}/packages/shared/pocknix-bsp-common"
cmp_tree "${HERE}/overlay"                        "${OS}/overlay"
cmp_tree "${HERE}/scripts"                        "${OS}/scripts"
cmp_tree "${HERE}/kernel/patches/05-speedup"       "${OS}/kernel/sm8750/patches/05-speedup"
cmp_tree "${HERE}/kernel/patches/10-mainline"      "${OS}/kernel/sm8750/patches/10-mainline"
cmp_tree "${HERE}/kernel/patches/20-sm8750"        "${OS}/kernel/sm8750/patches/20-sm8750"
cmp_tree "${HERE}/kernel/patches/30-version"       "${OS}/kernel/sm8750/patches/30-version"
cmp_tree "${HERE}/kernel/dts"                     "${OS}/kernel/sm8750/dts/qcom"
# gamescope ya NO tiene linea propia: es un paquete packages/soc/ y lo cubre el bucle
# `packages/soc-overrides/*` de mas abajo (antes vivia en packages/gamescope/).
cmp_tree "${HERE}/packages/pocknix-desktop"       "${OS}/packages/shared/pocknix-desktop"
# La capa vendored: si NO se comprueba, puede quedarse atras EN SILENCIO (paso con
# deckstation-arm: al launcher le faltaba el fix de SDL y al setup el de libXss, y
# check-sync decia OK -> la imagen habria salido con ES-DE en negro desde Game Mode).
cmp_tree "${HERE}/packages/deckstation-arm"   "${OS}/packages/shared/deckstation-arm"
cmp_tree "${HERE}/packages/python-pygame-ce"  "${OS}/packages/shared/python-pygame-ce"
  cmp_tree "${HERE}/packages/suyu-libretro"     "${OS}/packages/shared/suyu-libretro"
  cmp_tree "${HERE}/packages/libretro-cores-pocknix" "${OS}/packages/shared/libretro-cores-pocknix"
# Librerias + shims de los cores precompilados (ARMSX2/uae4arm los piden por
# soname). Sin estas lineas, un cambio aqui podria quedarse SIN sincronizar y el
# fallo apareceria en la Odin ("error while loading shared libraries") en vez de
# en el build — que es justo lo que hacia este paquete.
  cmp_tree "${HERE}/packages/plutovg"               "${OS}/packages/shared/plutovg"
  cmp_tree "${HERE}/packages/plutosvg"              "${OS}/packages/shared/plutosvg"
  cmp_tree "${HERE}/packages/pocknix-soname-compat" "${OS}/packages/shared/pocknix-soname-compat"
cmp_tree "${HERE}/packages/pocknix-steam"     "${OS}/packages/shared/pocknix-steam"
cmp_tree "${HERE}/packages/pocknix-tools"     "${OS}/packages/shared/pocknix-tools"
  cmp_tree "${HERE}/packages/pocknix-decky"   "${OS}/packages/shared/pocknix-decky"
  cmp_tree "${HERE}/packages/pocknix-vk-valve" "${OS}/packages/shared/pocknix-vk-valve"
cmp_tree "${HERE}/packages/pocknix-steam-full" "${OS}/packages/shared/pocknix-steam-full"
cmp_tree "${HERE}/packages/gamescope-session"       "${OS}/packages/shared/gamescope-session"
cmp_tree "${HERE}/packages/gamescope-session-steam" "${OS}/packages/shared/gamescope-session-steam"

# config/ y devices/sm8750/: las listas de paquetes, el pocknix.conf, el tuning y — sobre
# todo — el CMDLINE del kernel (profile.conf). Antes vivian solo en el arbol y no se
# vigilaban: por ahi se colo el `rootflags=nologreplay` que dejo la imagen sin arrancar
# (docs/INCIDENTE-2026-09-25-nologreplay.md).
cmp_tree "${HERE}/config"         "${OS}/config"
cmp_tree "${HERE}/devices/sm8750" "${OS}/devices/sm8750"

if [ -d "${HERE}/packages/soc-overrides" ]; then
  for d in "${HERE}"/packages/soc-overrides/*/; do
    [ -d "${d}" ] || continue
    cmp_tree "${HERE}/packages/soc-overrides/$(basename "${d}")" "${OS}/packages/soc/$(basename "${d}")"
  done
fi

if [ "${missing}" -eq 0 ] && [ "${drift}" -eq 0 ]; then
  echo "check-sync: OK — the build tree matches the centre."
  exit 0
fi

cat >&2 <<EOF

check-sync: FAILED — ${missing} missing, ${drift} differing file(s).
The build tree is NOT what this repo says it should be, so an image built from it would be
missing our fixes. Run:

    tools/sync-to-os.sh

EOF
exit 1
