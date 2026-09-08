#!/bin/bash
# install-odin3-gamepad-perms.sh — da a WProton/Proton acceso de lectura al
# gamepad UART interno del Odin 3 (y a cualquier mando).
#
# PROBLEMA: WProton no lee /dev/input/event6 ("AYN Odin3 Gamepad", gamepad UART
# interno sin idVendor) -> "Permission denied" -> cae al fallback con el mando
# virtual de Steam. La regla de WProton solo cubre mandos USB con idVendor.
#
# ESTO HACE:
#   1. Instala /etc/udev/rules.d/70-odin3-gamepad.rules (acceso grupo input a
#      todos los joysticks, sin depender de idVendor).
#   2. Anade el usuario actual al grupo input (si no esta).
#   3. Recarga udev y re-aplica permisos a los nodos existentes.
#
# Uso: sudo bash install-odin3-gamepad-perms.sh   (o sin sudo, pide elevacion)
set -e

RULES_SRC="$(dirname "$0")/70-odin3-gamepad.rules"
RULES_DST="/etc/udev/rules.d/70-odin3-gamepad.rules"
TARGET_USER="${SUDO_USER:-$USER}"

if [ ! -f "$RULES_SRC" ]; then
  echo "ERROR: no encuentro $RULES_SRC (ejecuta desde config/udev/)" >&2
  exit 1
fi

echo "[1/4] Instalando regla udev..."
install -m 0644 "$RULES_SRC" "$RULES_DST"
echo "      -> $RULES_DST"

echo "[2/4] Anadiendo '$TARGET_USER' al grupo input..."
if id -nG "$TARGET_USER" | tr ' ' '\n' | grep -qx input; then
  echo "      ya esta en el grupo input"
else
  usermod -aG input "$TARGET_USER"
  echo "      anadido. (Cierra sesion y vuelve a entrar, o usa 'newgrp input'.)"
fi

echo "[3/4] Recargando udev..."
udevadm control --reload-rules
udevadm trigger --subsystem-match=input --subsystem-match=hidraw

echo "[4/4] Verificando permisos de /dev/input/event* ..."
for ev in /dev/input/event*; do
  [ -e "$ev" ] || continue
  perms="$(stat -c '%A %G' "$ev")"
  echo "      $ev: $perms"
done

echo
echo "LISTO. Si el usuario '$TARGET_USER' no estaba en el grupo input antes,"
echo "cierra sesion y vuelve a entrar (o 'newgrp input') para que surta efecto."
echo "Prueba luego WProton: el mando real 'AYN Odin3 Gamepad' debe leerse."