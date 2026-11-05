#!/bin/sh
# Habilita el verbo UCM "Dock" (HDMI/DisplayPort) y recarga WirePlumber.
# Pensado para dispositivos CON dock. Sin dock, el perfil Dock no se puede
# sondear (el PCM hw:0,3 no abre) y el audio normal puede quedarse sin tarjeta.
# Requiere pocknix-bsp-sm8750 (instala HiFi-Dock.conf) y el kernel con el
# parche de audio HDMI (7.2.12-33+).
set -e
U=/usr/share/alsa/ucm2/AYN/Odin3
[ "$(id -u)" = 0 ] || { echo "Ejecuta con sudo." >&2; exit 1; }
[ -f "${U}/HiFi-Dock.conf" ] || { echo "Falta ${U}/HiFi-Dock.conf (instala pocknix-bsp-sm8750)." >&2; exit 1; }
[ -f "$(dirname "$0")/AYN-Odin3.conf.dock" ] || { echo "Falta AYN-Odin3.conf.dock junto al script." >&2; exit 1; }
[ -f "${U}/AYN-Odin3.conf.bak-dock" ] || cp -a "${U}/AYN-Odin3.conf" "${U}/AYN-Odin3.conf.bak-dock"
cp -f "$(dirname "$0")/AYN-Odin3.conf.dock" "${U}/AYN-Odin3.conf"
su - deck -c 'XDG_RUNTIME_DIR=/run/user/1001 systemctl --user restart wireplumber' 2>/dev/null || systemctl restart wireplumber 2>/dev/null || true
echo "Verbo Dock activado. Conecta el dock y elige el perfil 'Dock' (pactl list cards)."
