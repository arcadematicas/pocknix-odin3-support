#!/bin/bash
# push-file.sh — copia UN fichero del centro a la Odin (para probar cambios rápidos).
#
# Para iterar sobre scripts, configs o unidades NO hace falta compilar un paquete ni
# reflashear: se copia el fichero y se recarga lo que corresponda. Son segundos.
#
# USO
#   tools/push-file.sh packages/pocknix-bsp-sm8750/oled-care/oled-care-daemon.py /usr/local/bin/oled-care-daemon.py
#   tools/push-file.sh overlay/etc/systemd/system/pocknix-diag.timer /etc/systemd/system/pocknix-diag.timer
#
# Opciones por entorno:
#   DEVICE_HOST=deck@192.168.4.29   (por defecto)
#   MODE=755|644                    permisos en destino (por defecto: los del origen)
#   RELOAD="systemctl daemon-reload; systemctl try-restart foo.service"
#                                   comando a ejecutar después (por defecto: nada)
#
# ⚠️  Esto es para PROBAR. Cuando el cambio funcione, llévalo al centro (el fichero ya está
#     ahí, porque esto copia DESDE el centro) y commitea. La regla de oro sigue siendo que
#     pocknix-os se regenera con sync-to-os.sh — nunca se edita a mano.
set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
HOST="${DEVICE_HOST:-deck@192.168.4.29}"

[ "$#" -eq 2 ] || { echo "uso: $0 <fichero-del-centro> <ruta-destino>" >&2; exit 1; }
SRC="${HERE}/$1"
DST="$2"

[ -f "${SRC}" ] || { echo "no existe: ${SRC}" >&2; exit 1; }

MODE="${MODE:-$(stat -c %a "${SRC}")}"
TMP="/tmp/$(basename "${DST}")"

echo "==> ${1} -> ${HOST}:${DST} (modo ${MODE})"
scp -q "${SRC}" "${HOST}:${TMP}"
ssh "${HOST}" "sudo install -Dm${MODE} '${TMP}' '${DST}' && rm -f '${TMP}'"

if [ -n "${RELOAD:-}" ]; then
  echo "==> recargando: ${RELOAD}"
  ssh "${HOST}" "sudo sh -c '${RELOAD}'"
else
  echo "    (sin RELOAD=; si es una unidad: sudo systemctl daemon-reload && sudo systemctl try-restart <unidad>)"
fi

echo "listo."
