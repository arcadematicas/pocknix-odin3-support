#!/bin/sh
# pocknix-inputplumber-rescan — reinicia InputPlumber cuando el mando interno del
# Odin 3 ("AYN Odin3 Gamepad", driver rsinput sobre UART) ya esta realmente listo.
#
# Lo lanza pocknix-inputplumber-rescan.service, que a su vez lo dispara la regla
# udev 60-input-id2-odin3-gamepad-rescan.rules al aparecer el mando (ACTION=="add").
#
# El mando tarda ~15 s en inicializarse y su uevent "add" puede llegar cuando aun
# NO tiene capacidades (inputplumber lo veria como "empty input" y el reinicio no
# arreglaria nada). Por eso esperamos aqui a que la mascara de keys/abs sea no
# vacia antes de reiniciar; si no lo es dentro del timeout, NO reiniciamos.
set -u

DEVNAME="AYN Odin3 Gamepad"
# ~15 s reales; el margen sobra. Configurable por si hay que aflojarlo en pruebas.
TIMEOUT="${POCKNIX_RESCAN_TIMEOUT:-40}"

# Imprime "eventN" si el mando existe y tiene al menos una capacidad real;
# si no, no imprime nada y devuelve 1.
find_ready_event() {
  local name base caps
  for name in /sys/class/input/event*/device/name; do
    [ -r "${name}" ] || continue
    [ "$(cat "${name}" 2>/dev/null)" = "${DEVNAME}" ] || continue
    base="${name%/device/name}"            # .../input/eventN
    caps="$(cat "${base}/device/capabilities/keys" 2>/dev/null)$(cat "${base}/device/capabilities/abs" 2>/dev/null)"
    # mascara vacia o solo ceros = dispositivo "vacio" todavia -> no vale
    if [ -n "${caps}" ] && printf '%s' "${caps}" | grep -q '[1-9a-fA-F]'; then
      printf '%s' "$(basename "${base}")"
      return 0
    fi
  done
  return 1
}

i=0
ev=""
while [ "${i}" -lt "${TIMEOUT}" ]; do
  if ev="$(find_ready_event)" && [ -n "${ev}" ]; then
    break
  fi
  i=$((i + 1))
  sleep 1
done

if [ -z "${ev}" ]; then
  echo "pocknix-inputplumber-rescan: '${DEVNAME}' sin capacidades tras ${TIMEOUT}s; NO reinicio inputplumber" >&2
  exit 0
fi

echo "pocknix-inputplumber-rescan: '${DEVNAME}' listo (/dev/input/${ev}); reinicio inputplumber"
exec systemctl restart inputplumber.service
