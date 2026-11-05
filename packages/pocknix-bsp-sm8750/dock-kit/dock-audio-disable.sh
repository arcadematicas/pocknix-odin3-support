#!/bin/sh
# Restaura el UCM sin verbo Dock (estado seguro sin dock).
set -e
U=/usr/share/alsa/ucm2/AYN/Odin3
[ "$(id -u)" = 0 ] || { echo "Ejecuta con sudo." >&2; exit 1; }
[ -f "${U}/AYN-Odin3.conf.bak-dock" ] || { echo "No hay backup .bak-dock." >&2; exit 1; }
cp -f "${U}/AYN-Odin3.conf.bak-dock" "${U}/AYN-Odin3.conf"
su - deck -c 'XDG_RUNTIME_DIR=/run/user/1001 systemctl --user restart wireplumber' 2>/dev/null || systemctl restart wireplumber 2>/dev/null || true
echo "Verbo Dock desactivado (UCM seguro sin dock)."
