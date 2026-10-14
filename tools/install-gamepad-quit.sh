#!/bin/bash
# install-gamepad-quit.sh — instala pocknix-gamepad-quit (script + unidad de USUARIO).
#
# QUE ES
#   `pocknix-gamepad-quit` cierra la app en curso de ES-DE con **START+SELECT**
#   (emuladores standalone y GUIs). ES-DE lanza los emuladores como hijos suyos y
#   no hay gestor de ventanas, asi que Alt+F4 no llega: este servicio manda
#   SIGTERM a lo que cuelgue de ES-DE y, si sigue vivo, SIGKILL.
#
#   **Lee el mando SIN capturarlo** (el emulador sigue recibiendo sus botones; el
#   acceso lo da el grupo `input`, que `deck` ya tiene) y por eso la unidad es de
#   **USUARIO** (`~/.config/systemd/user/`), no de sistema.
#
# POR QUE ESTE INSTALADOR
#   El script se instalaba a mano. Al no existir el binario, la unidad de usuario
#   arrancaba con `203/EXEC` + `Restart=always` -> bucle de reinicios (1504 en la
#   Odin). Esto lo deja instalado y habilitado en un paso, idempotente.
#
# IMPORTANTE: ejecutalo COMO EL USUARIO (deck), NO con sudo entero. Solo el
#   `install` del binario en /usr/local/bin usa sudo por dentro; el
#   `systemctl --user` tiene que hablar por el bus del usuario.
#
# Uso: bash install-gamepad-quit.sh
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BIN_SRC="${SCRIPT_DIR}/pocknix-gamepad-quit"
UNIT_SRC="${SCRIPT_DIR}/pocknix-gamepad-quit.service"
BIN_DST="/usr/local/bin/pocknix-gamepad-quit"
UNIT_DST="${XDG_CONFIG_HOME:-$HOME/.config}/systemd/user/pocknix-gamepad-quit.service"

if [ "$(id -u)" -eq 0 ]; then
  echo "ERROR: ejecutalo como el USUARIO (deck), no como root." >&2
  echo "       Si lo lanzas con sudo entero, 'systemctl --user' iria al bus de" >&2
  echo "       root y la unidad quedaria en el home equivocado. El sudo para el" >&2
  echo "       binario lo hace el propio script." >&2
  exit 1
fi

for f in "${BIN_SRC}" "${UNIT_SRC}"; do
  [ -f "${f}" ] || { echo "ERROR: falta ${f} (ejecuta desde tools/ del centro)" >&2; exit 1; }
done

echo "[1/3] Instalando el binario en ${BIN_DST} (sudo solo aqui) ..."
sudo install -Dm755 "${BIN_SRC}" "${BIN_DST}"

echo "[2/3] Instalando la unidad de usuario en ${UNIT_DST} ..."
install -Dm644 "${UNIT_SRC}" "${UNIT_DST}"

echo "[3/3] Recargando el systemd de usuario y habilitando el servicio ..."
systemctl --user daemon-reload
systemctl --user enable --now pocknix-gamepad-quit.service
systemctl --user --no-pager --full status pocknix-gamepad-quit.service || true

echo
echo "LISTO. START+SELECT cierra la app en curso de ES-DE (SIGTERM y, tras el"
echo "timeout, SIGKILL). Diagnostico:  pocknix-gamepad-quit --status"
