#!/bin/bash
# slim-rootfs.sh — quita grasa del rootfs ANTES de empaquetar la imagen.
#
# Medido el 13/10/2026 (rootfs de 22 GB): la cache de pacman son 3,9 GB, /usr/share/doc
# 173 MB y el firmware de hardware x86 (intel/nvidia/amdgpu/radeon/i915) ~630 MB. Nada de
# eso hace falta en la Odin (aarch64/Adreno/qcom).
#
# Uso:  tools/slim-rootfs.sh [rootfs]      (por defecto $POCKNIX_OS_DIR/build/rootfs)
set -u
HERE="$(cd "$(dirname "$0")" && pwd)"
OS="${POCKNIX_OS_DIR:-${HERE}/../pocknix-os}"
ROOT="${1:-${OS}/build/rootfs}"

[ -d "${ROOT}/usr" ] && [ -d "${ROOT}/var" ] || { echo "ERROR: ${ROOT} no parece un rootfs" >&2; exit 1; }
before=$(du -sm "${ROOT}" 2>/dev/null | cut -f1)

echo "==> cache de paquetes de pacman (la imagen no la necesita)"
rm -rf "${ROOT}/var/cache/pacman/pkg"/* 2>/dev/null || true

echo "==> /usr/share/doc (las licencias de /usr/share/licenses SE CONSERVAN)"
rm -rf "${ROOT}/usr/share/doc"/* 2>/dev/null || true

echo "==> firmware de hardware que no existe en ARM (x86)"
for fw in intel nvidia amdgpu radeon i915; do
  if [ -d "${ROOT}/usr/lib/firmware/${fw}" ]; then
    rm -rf "${ROOT}/usr/lib/firmware/${fw}"
    echo "    - usr/lib/firmware/${fw}"
  fi
done

after=$(du -sm "${ROOT}" 2>/dev/null | cut -f1)
echo "==> rootfs: ${before} MB -> ${after} MB   (ahorro $((before-after)) MB)"
echo "    NOTA: los paquetes linux-firmware-* siguen en la DB de pacman; si un -Syu los"
echo "          actualiza, volveran a traer sus ficheros (ver PENDIENTES-20261013.md)."
