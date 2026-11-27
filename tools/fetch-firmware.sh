#!/usr/bin/env bash
# fetch-firmware.sh — trae los blobs de firmware PROPIOS (los que no están en git).
#
# POR QUÉ EXISTE
#   El par ADSP del Odin 3 (adsp.mbn + adsp_dtb.mbn) lleva la configuracion de autenticacion de
#   bateria que NO tiene el firmware de ROCKNIX: sin el, el cargador del ADSP entra en TEST MODE y
#   la bateria no carga en Linux (ver BATTERY-ISSUE.md). Pesa 42 MB, asi que no vive en git: se
#   descarga de nuestro R2, pinchado por commit/hash, igual que ROCKNIX hace con extra-firmware.
#
# DESTINO
#   <pocknix-os>/vendor/calvos-firmware/   (gitignored; el build lo busca antes que ROCKNIX)
#
# USO
#   tools/fetch-firmware.sh                 # usa ../pocknix-os o POCKNIX_OS_DIR
#   tools/fetch-firmware.sh /ruta/pocknix-os
#   tools/fetch-firmware.sh --check         # solo comprueba, no descarga
set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
OS="${1:-${POCKNIX_OS_DIR:-${HERE}/../pocknix-os}}"
CHECK=0
if [ "${OS}" = "--check" ]; then CHECK=1; OS="${POCKNIX_OS_DIR:-${HERE}/../pocknix-os}"; fi
[ "$#" -ge 2 ] && [ "$2" = "--check" ] && CHECK=1

BASE="https://pub-fd47305874674bf597b27eb7f880e73b.r2.dev/firmware/sm8750/20261127"
DEST="${OS}/vendor/calvos-firmware"

# ruta relativa | sha256 | bytes
FILES=(
  "qcom/sm8750/adsp.mbn|d5fabba5720f0ddb851ae875e185bf6b89b128bc7f17b426c2dd63545f6b054a|21396k"
  "qcom/sm8750/ayn/odin3portal/adsp.mbn|67439236b296614ca64212a7a8d6d5bdffdd62cdb54a77877a7f695c8316b8af|20404k"
)

fail() { echo "ERROR: $*" >&2; exit 1; }

[ -d "${OS}" ] || fail "no existe el arbol pocknix-os en '${OS}' (pasa la ruta o define POCKNIX_OS_DIR)"

missing=0
for entry in "${FILES[@]}"; do
  IFS='|' read -r rel want _size <<<"${entry}"
  f="${DEST}/${rel}"
  if [ -f "${f}" ] && [ "$(sha256sum "${f}" | awk '{print $1}')" = "${want}" ]; then
    echo "ok   ${rel} (ya presente y verificado)"
    continue
  fi
  missing=$((missing+1))
  if [ "${CHECK}" -eq 1 ]; then echo "falta ${rel}"; continue; fi
  echo "==> descargando ${rel}"
  mkdir -p "$(dirname "${f}")"
  tmp="${f}.part"
  curl -fL --retry 3 --max-time 300 -o "${tmp}" "${BASE}/${rel}" || { rm -f "${tmp}"; fail "no se pudo descargar ${rel}"; }
  got="$(sha256sum "${tmp}" | awk '{print $1}')"
  [ "${got}" = "${want}" ] || { rm -f "${tmp}"; fail "sha256 de ${rel} no coincide (${got} != ${want})"; }
  mv -f "${tmp}" "${f}"
  echo "     verificado ${got:0:16}…"
done

[ "${CHECK}" -eq 1 ] && { [ "${missing}" -eq 0 ] && echo "todo presente" || echo "faltan ${missing}"; exit 0; }
echo "firmware propio listo en ${DEST}"
