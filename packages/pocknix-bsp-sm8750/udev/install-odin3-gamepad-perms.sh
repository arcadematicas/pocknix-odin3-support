#!/bin/bash
# install-odin3-gamepad-perms.sh — clasifica y da acceso de lectura al gamepad
# UART interno del Odin 3 (y a cualquier mando).
#
# DOS PROBLEMAS, y este script resuelve los dos:
#
#   1) CLASIFICACION (el bug de raiz). El builtin `input_id` de udev clasifica el
#      mando UART interno "AYN Odin3 Gamepad" (driver rsinput, SIN idVendor) como
#      RATON y NO le pone ID_INPUT_JOYSTICK. SDL3 filtra la enumeracion por esa
#      variable -> SDL ve 0 joysticks -> ni ES-DE ni los emuladores SDL ven el
#      mando. Se corrige con 60-input-id2-odin3-gamepad.rules, que fija
#      ENV{ID_INPUT_JOYSTICK}="1". VA PRIMERO: la regla de permisos de abajo
#      depende de esa variable y, sin ella, NUNCA se dispara.
#
#   2) PERMISOS. WProton/Proton no lee /dev/input/event6 ("Permission denied")
#      porque el mando no tiene idVendor y ninguna regla de mandos USB le aplica
#      -> cae al fallback con el mando virtual de Steam. Se corrige con
#      70-odin3-gamepad.rules (acceso al grupo input).
#
# ESTO HACE (idempotente):
#   1. Instala /etc/udev/rules.d/60-input-id2-odin3-gamepad.rules (clasificacion).
#   2. Instala /etc/udev/rules.d/70-odin3-gamepad.rules (permisos, grupo input).
#   3. Anade el usuario actual al grupo input (si no esta).
#   4. Recarga udev y re-aplica al mando (event6 / js0).
#   5. Verifica ID_INPUT_JOYSTICK y los permisos de /dev/input/event*.
#
# Uso: sudo bash install-odin3-gamepad-perms.sh   (o sin sudo, pide elevacion)
set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
# El script vive en packages/pocknix-bsp-sm8750/udev/ dentro del centro, y la regla
# de clasificacion vive en overlay/etc/udev/rules.d/ — que es justo la ruta que
# entra en la imagen como /etc/udev/rules.d/. Para no DUPLICAR la regla, la
# referenciamos aqui en vez de tener una copia junto al script.
REPO_DIR=""
if [ -d "${SCRIPT_DIR}/../../.." ]; then
  REPO_DIR="$(cd "${SCRIPT_DIR}/../../.." && pwd)"
fi

CLASSIFY_DST="/etc/udev/rules.d/60-input-id2-odin3-gamepad.rules"
PERMS_DST="/etc/udev/rules.d/70-odin3-gamepad.rules"
TARGET_USER="${SUDO_USER:-$USER}"

# Primer candidato existente que NO sea el propio destino (reinstalar sobre si
# mismo falla y no tiene sentido).
find_src() {
  local dst="$1"; shift
  local c
  for c in "$@"; do
    [ -n "$c" ] || continue
    [ "$c" = "$dst" ] && continue
    if [ -f "$c" ]; then printf '%s\n' "$c"; return 0; fi
  done
  return 1
}

CLASSIFY_SRC="$(find_src "${CLASSIFY_DST}" \
  "${SCRIPT_DIR}/60-input-id2-odin3-gamepad.rules" \
  "${REPO_DIR:+${REPO_DIR}/overlay/etc/udev/rules.d/60-input-id2-odin3-gamepad.rules}" \
  "${CLASSIFY_DST}")" || true

PERMS_SRC="$(find_src "${PERMS_DST}" \
  "${SCRIPT_DIR}/70-odin3-gamepad.rules" \
  "/usr/lib/udev/rules.d/70-odin3-gamepad.rules")" || true

if [ -z "${CLASSIFY_SRC}" ] && [ ! -f "${CLASSIFY_DST}" ]; then
  echo "ERROR: no encuentro 60-input-id2-odin3-gamepad.rules." >&2
  echo "       Ejecuta este script desde packages/pocknix-bsp-sm8750/udev/ del" >&2
  echo "       centro (la regla vive en overlay/etc/udev/rules.d/)." >&2
  exit 1
fi
if [ -z "${PERMS_SRC}" ] && [ ! -f "${PERMS_DST}" ]; then
  echo "ERROR: no encuentro 70-odin3-gamepad.rules (esta junto a este script)." >&2
  exit 1
fi

echo "[1/5] Regla de CLASIFICACION (ID_INPUT_JOYSTICK=1) ..."
if [ -n "${CLASSIFY_SRC}" ]; then
  install -m 0644 "${CLASSIFY_SRC}" "${CLASSIFY_DST}"
  echo "      ${CLASSIFY_SRC} -> ${CLASSIFY_DST}"
else
  echo "      ya instalada en ${CLASSIFY_DST} (no hay fuente que copiar)"
fi

echo "[2/5] Regla de PERMISOS (grupo input) ..."
if [ -n "${PERMS_SRC}" ]; then
  install -m 0644 "${PERMS_SRC}" "${PERMS_DST}"
  echo "      ${PERMS_SRC} -> ${PERMS_DST}"
else
  echo "      ya instalada en ${PERMS_DST} (no hay fuente que copiar)"
fi

echo "[3/5] Anadiendo '$TARGET_USER' al grupo input..."
if id -nG "$TARGET_USER" | tr ' ' '\n' | grep -qx input; then
  echo "      ya esta en el grupo input"
else
  usermod -aG input "$TARGET_USER"
  echo "      anadido. (Cierra sesion y vuelve a entrar, o usa 'newgrp input'.)"
fi

# Reload-rules + trigger explicito sobre el mando UART (event6/js0): asi la nueva
# clasificacion entra en la BD de udev y la regla de permisos puede dispararse.
echo "[4/5] Recargando udev y re-aplicando al mando (event6 / js0)..."
udevadm control --reload-rules
udevadm trigger --action=change /sys/class/input/event6 /sys/class/input/js0

echo "[5/5] Verificando ..."
if [ -e /dev/input/event6 ]; then
  v="$(udevadm info -q property -n /dev/input/event6 2>/dev/null | sed -n 's/^ID_INPUT_JOYSTICK=//p')"
  echo "      /dev/input/event6 ID_INPUT_JOYSTICK = ${v:-<vacio: la regla no ha casado!>}"
fi
for ev in /dev/input/event*; do
  [ -e "$ev" ] || continue
  echo "      $ev: $(stat -c '%A %G' "$ev")"
done

echo
echo "LISTO. Si el usuario '$TARGET_USER' no estaba en el grupo input antes,"
echo "cierra sesion y vuelve a entrar (o 'newgrp input') para que surta efecto."
echo "Prueba luego WProton: el mando real 'AYN Odin3 Gamepad' debe leerse."
