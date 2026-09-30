#!/bin/bash
# build-odin3.sh — build COMPLETO de la imagen del Odin 3, con el ORDEN correcto.
#
# ⚠️ POR QUE EXISTE ESTE SCRIPT
#   `make sync` (scripts/sync.sh, de upstream) usa `rsync -a --delete` sobre
#   kernel/sm8750/{patches,dts,bootloader}, asi que **BORRA todos NUESTROS parches**
#   (rotacion 0013/0067/0068, adreno 0051, bateria 0078-0081...) y nuestros DTS.
#   El 26/09/2026 se hizo `sync-to-os.sh` ANTES de `make sync` (el orden que decia BUILD.md)
#   y el kernel salio con 62 parches en vez de 70: la imagen se habria compilado SIN rotacion
#   por hardware, SIN fixes de bateria, etc. Nadie avisaba, porque check-sync no formaba parte
#   del build y build-kernel.sh solo deja un `warn`.
#
#   Este script fija el orden en CODIGO:
#     git pull (el trabajo se hace en el PORTATIL)  ->  make sync  ->  sync-to-os.sh
#       ->  check-sync.sh (aborta si algo falta)  ->  build
#
# USO
#   tools/build-odin3.sh              # build completo (pide sudo para kernel/imagen)
#   tools/build-odin3.sh --check      # solo verificar que el arbol tiene lo nuestro
#   POCKNIX_OS_DIR=/ruta tools/build-odin3.sh
set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
OS="${POCKNIX_OS_DIR:-${HERE}/../pocknix-os}"
export DEVICE="${DEVICE:-sm8750}"
export JOBS="${JOBS:-$(nproc)}"

[ -d "${OS}" ] || { echo "ERROR: no encuentro pocknix-os en ${OS} (usa POCKNIX_OS_DIR)" >&2; exit 1; }

if [ "${1:-}" = "--check" ]; then
  "${HERE}/tools/check-sync.sh"
  exit $?
fi

echo "==> 0/5  actualizar los repos (git pull)"
# El trabajo (editar + commit + push) se hace en el PORTATIL. El PC solo COMPILA:
# antes de construir se trae lo ultimo de GitHub. Si no hay red o hay cambios
# locales que lo impiden, se AVISA y se sigue con lo que haya (no se aborta).
for _repo in "${HERE}" "${OS}"; do
  [ -d "${_repo}/.git" ] || continue
  if git -C "${_repo}" pull --ff-only --quiet 2>/dev/null; then
    echo "    ${_repo##*/}: al dia — $(git -C "${_repo}" log -1 --format='%h %s' | cut -c1-56)"
  else
    echo "    AVISO: no se pudo actualizar ${_repo##*/} (¿sin red / cambios locales?) — sigo con lo que hay" >&2
    git -C "${_repo}" status --porcelain 2>/dev/null | head -3 | sed 's/^/      /' >&2
  fi
done

echo "==> 1/5  make sync   (vendoriza ROCKNIX; BORRA nuestros parches — es esperado)"
( cd "${OS}" && make sync )

echo "==> 2/5  sync-to-os.sh   (reaplica NUESTRO contenido ENCIMA)"
"${HERE}/tools/sync-to-os.sh"

echo "==> 3/5  check-sync.sh   (si falta algo nuestro, aborta AQUI)"
"${HERE}/tools/check-sync.sh"

echo "==> 4/5  kernel + imagen + SD"
if [ "$(id -u)" -eq 0 ]; then
  ( cd "${OS}" && make kernel && make build && make sd-image )
else
  ( cd "${OS}" && sudo make kernel && sudo make build && sudo make sd-image )
fi

echo
echo "==> LISTO: ${OS}/build/image/sm8750/pocknix-sm8750-sd.img"
