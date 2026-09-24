#!/bin/bash
# deploy-schedulers.sh — despliega schedulers (scx-mode + perfiles QAM + bfq) y el plugin
# PocknixControl desde el centro a la Odin, sin compilar paquetes. Para iterar rápido.
#
# USO
#   tools/deploy-schedulers.sh            # todo (bsp + plugin)
#   tools/deploy-schedulers.sh --bsp      # solo bsp-common + power-profile
#   tools/deploy-schedulers.sh --plugin   # solo el plugin Decky
#
# Env: DEVICE_HOST (default deck@192.168.4.22) · SUDO_PASS (default pocknix)
#
# ⚠️  El loader de Decky SOLO se reinicia si Steam NO está en modo juego (crash de
#     steamwebhelper si se reinicia en caliente). Si está en modo juego, avisa.
set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
HOST="${DEVICE_HOST:-deck@192.168.4.22}"
SUDO_PASS="${SUDO_PASS:-pocknix}"
SUDO="echo ${SUDO_PASS} | sudo -S"

DO_BSP=0
DO_PLUGIN=0
if [ "$#" -eq 0 ]; then
  DO_BSP=1
  DO_PLUGIN=1
else
  for a in "$@"; do
    case "$a" in
      --bsp) DO_BSP=1 ;;
      --plugin) DO_PLUGIN=1 ;;
      *) echo "argumento desconocido: $a" >&2; exit 2 ;;
    esac
  done
fi

# La Odin debe responder antes de tocar nada.
ssh -o ConnectTimeout=8 -o BatchMode=yes "${HOST}" true 2>/dev/null \
  || { echo "no hay conexion con ${HOST} (encendida y en red?)" >&2; exit 1; }

push() {  # $1=src-rel-centro  $2=destino  $3=modo
  local src="${HERE}/$1" dst="$2" mode="${3:-755}"
  [ -f "${src}" ] || { echo "no existe: ${src}" >&2; exit 1; }
  local tmp="/tmp/$(basename "${dst}")"
  echo "==> $1 -> ${HOST}:${dst}"
  scp -q "${src}" "${HOST}:${tmp}"
  ssh "${HOST}" "${SUDO} install -Dm${mode} '${tmp}' '${dst}' && rm -f '${tmp}'"
}

if [ "${DO_BSP}" = 1 ]; then
  echo "### BSP (schedulers + perfiles)"
  push packages/pocknix-bsp-common/pocknix-scx-mode /usr/bin/pocknix-scx-mode 755
  push packages/pocknix-bsp-common/pocknix-lavd-mode /usr/bin/pocknix-lavd-mode 755
  push packages/pocknix-bsp-common/pocknix-scx-diag /usr/bin/pocknix-scx-diag 755
  push packages/pocknix-bsp-common/pocknix-scx.service /usr/lib/systemd/system/pocknix-scx.service 644
  push packages/pocknix-bsp-common/60-pocknix-io-scheduler.rules /usr/lib/udev/rules.d/60-pocknix-io-scheduler.rules 644
  push packages/pocknix-bsp-sm8750/power/pocknix-power-profile /usr/local/bin/pocknix-power-profile 755
  echo "==> recargando unidades + udev + reiniciando pocknix-scx.service"
  ssh "${HOST}" "${SUDO} sh -c 'ln -sf pocknix-scx.service /usr/lib/systemd/system/pocknix-lavd.service; systemctl daemon-reload; udevadm control --reload-rules; systemctl try-restart pocknix-scx.service'"
fi

if [ "${DO_PLUGIN}" = 1 ]; then
  echo "### Plugin PocknixControl"
  push packages/pocknix-decky/pocknix-control/main.py /usr/share/decky-plugins/PocknixControl/main.py 755
  echo "==> py_modules + dist (arbol)"
  tar -C "${HERE}/packages/pocknix-decky/pocknix-control" -cf - py_modules dist \
    | ssh "${HOST}" "${SUDO} tar -C /usr/share/decky-plugins/PocknixControl -xf -"
  SESSION="$(ssh "${HOST}" "cat /home/deck/.local/state/pocknix-session 2>/dev/null || echo plasma")"
  if [ "${SESSION}" = "gamescope" ]; then
    echo "⚠️  Steam en modo juego — NO reinicio pocknix-decky-loader (crash de steamwebhelper)."
    echo "    Reinicialo desde el escritorio: sudo systemctl restart pocknix-decky-loader.service"
  else
    echo "==> reiniciando pocknix-decky-loader.service"
    ssh "${HOST}" "${SUDO} systemctl restart pocknix-decky-loader.service"
  fi
fi

echo "listo."