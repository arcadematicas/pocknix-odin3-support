#!/bin/bash
# deploy-to-device.sh — compila un paquete NUESTRO y lo instala en la Odin por SSH.
#
# POR QUÉ EXISTE
#   Flashear la imagen entera (~30-45 min) solo hace falta para distribuir o para una
#   instalación desde cero. Para ITERAR sobre el sistema no hace falta nada de eso: se
#   compila el paquete afectado y se instala en caliente por SSH, que son minutos.
#
# USO
#   tools/deploy-to-device.sh pocknix-bsp-sm8750
#   tools/deploy-to-device.sh pocknix-decky pocknix-tools        # varios de golpe
#   DEVICE_HOST=deck@192.168.4.29 tools/deploy-to-device.sh ...
#   NO_RESTART=1 tools/deploy-to-device.sh pocknix-bsp-sm8750    # no reiniciar servicios
#
# QUÉ HACE
#   1. sync-to-os.sh   (aplica el centro al árbol de compilación)
#   2. make packages PKG="..."  (compila solo esos)
#   3. scp de los .pkg.tar.* a la Odin
#   4. pacman -U --noconfirm en la Odin
#   5. reinicia los servicios afectados (o te dice cuáles hay que reiniciar)
#
# OJO: esto instala lo compilado, NO cambia el repo. Si tocas algo a mano en la Odin para
# probar, tráelo al centro después (regla de oro: el centro es la fuente de verdad).
set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
OS="${POCKNIX_OS_DIR:-${HERE}/../pocknix-os}"
HOST="${DEVICE_HOST:-deck@192.168.4.29}"
DEVICE="${DEVICE:-sm8750}"

[ "$#" -ge 1 ] || { echo "uso: $0 <paquete> [paquete...]" >&2; exit 1; }
PKGS="$*"

echo "==> 1/5 sincronizando el centro al árbol de compilación"
"${HERE}/tools/sync-to-os.sh" >/dev/null
"${HERE}/tools/check-sync.sh" >/dev/null || { echo "check-sync falló" >&2; exit 1; }
echo "    OK"

echo "==> 2/5 compilando: ${PKGS}"
( cd "${OS}" && DEVICE="${DEVICE}" PKG="${PKGS}" make packages )

echo "==> 3/5 buscando los paquetes compilados"
FILES=()
for p in ${PKGS}; do
  # el paquete recién construido (el más nuevo que case con el nombre)
  f=$(ls -t "${OS}"/build/localrepo/*/"${p}"-*.pkg.tar.* 2>/dev/null | head -1 || true)
  [ -n "${f}" ] || { echo "    no encuentro el paquete ${p} en build/localrepo" >&2; exit 1; }
  echo "    ${f##*/}"
  FILES+=("${f}")
done

echo "==> 4/5 instalando en ${HOST}"
scp -q "${FILES[@]}" "${HOST}:/tmp/"
for f in "${FILES[@]}"; do
  echo "    pacman -U ${f##*/}"
  ssh "${HOST}" "sudo pacman -U --noconfirm /tmp/${f##*/} >/dev/null && rm -f /tmp/${f##*/}"
done

echo "==> 5/5 servicios"
if [ "${NO_RESTART:-0}" = "1" ]; then
  echo "    NO_RESTART=1 — reinicia tú lo que toque (systemctl --failed para ver qué se queja)"
else
  # Si el paquete trae unidades nuevas o cambiadas, systemd ya avisa. Reiniciamos los daemons
  # nuestros que suelen verse afectados, ignorando los que no existan en este dispositivo.
  for s in oled-care-daemon mangohud-toggle-daemon power-button-daemon volume-button-daemon \
           pocknix-power-profile pocknix-cpu-governor pocknix-pergame-power steamui-watchdog \
           pocknix-decky-loader; do
    ssh "${HOST}" "sudo systemctl try-restart ${s}.service 2>/dev/null" || true
  done
  echo "    daemons reiniciados (los que existían)"
  echo
  echo "    Estado en la Odin:"
  ssh "${HOST}" 'systemctl --failed --no-legend 2>/dev/null | sed "s/^/      /" || true'
  ssh "${HOST}" 'systemctl --failed --no-legend 2>/dev/null | grep -q . || echo "      (sin servicios fallidos)"'
fi

echo
echo "listo. Si el cambio era de sesión (gamescope/Steam), reinicia la sesión desde la consola."
