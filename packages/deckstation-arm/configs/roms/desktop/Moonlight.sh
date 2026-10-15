#!/bin/bash
# Lanzador de Moonlight (moonlight-qt) desde ES-DE ("Desktop Applications").
#
# Mismo patron que Updater.sh: es un script suelto que ES-DE lanza con el shell
# del sistema (extension .sh del sistema "desktop"). Se ubica a si mismo para no
# depender del cwd con el que ES-DE lo invoca.
#
# Por que no basta con "exec moonlight":
#  * Cuando ES-DE se lanza DESDE STEAM, Steam deja PATH=/tmp/.pathNNNN (una
#    carpeta que solo contiene fusermount). Con ese PATH no se encuentra el
#    binario ni ninguna herramienta; se recompone el PATH normal delante.
#  * ES-DE exporta APPIMAGE/APPDIR/OWD; se limpian por higiene.

# PATH de emergencia (ver lanzar.sh de DeckStation para el diagnostico completo)
PATH="/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin:${PATH:-}"
export PATH

unset APPIMAGE
unset APPDIR
unset OWD

# Localiza el binario (moonlight-qt de ALARM lo instala como /usr/bin/moonlight).
MOONLIGHT="$(command -v moonlight || command -v moonlight-qt || true)"
if [ -z "$MOONLIGHT" ]; then
  echo "[Moonlight.sh] No se encuentra el binario 'moonlight'." >&2
  echo "[Moonlight.sh] Instalalo con: sudo pacman -S --needed moonlight-qt" >&2
  exit 1
fi

# El cliente es Qt6; respeta WAYLAND_DISPLAY/DISPLAY heredados del compositor
# (gamescope o Plasma), asi que no forzamos nada. Solo aseguramos que exista uno.
if [ -z "$WAYLAND_DISPLAY" ] && [ -z "$DISPLAY" ]; then
  echo "[Moonlight.sh] Sin servidor grafico (ni WAYLAND_DISPLAY ni DISPLAY)." >&2
  exit 1
fi

exec "$MOONLIGHT" "$@"
