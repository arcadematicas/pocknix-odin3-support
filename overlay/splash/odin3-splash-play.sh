#!/bin/sh
# Splash de arranque Odin 3 - reproduce la bootanimation en /dev/fb0
# Parte 1: reproduce los 240 frames (part0, ~8s a 30fps)
# Parte 2: mantiene el ultimo frame (logo estatico) hasta que kwin toma el display
FB=/dev/fb0
FRAMES=/usr/share/odin3-splash/frames
START=$(date +%s)
TOTAL_FRAMES=240

# Pasa 1: animacion completa
i=0
while [ "$i" -lt "$TOTAL_FRAMES" ]; do
    f=$(printf "%s/frame_%04d.raw" "$FRAMES" "$i")
    [ -f "$f" ] || break
    # timeout 1: si el write se bloquea (kwin tomo el DRM master), salimos
    timeout 1 cat "$f" > "$FB" 2>/dev/null || exit 0
    sleep 0.028
    i=$((i + 1))
    # safety: no mas de 30s en la animacion
    [ "$(( $(date +%s) - START ))" -gt 30 ] && exit 0
done

# Pasa 2: mantener el logo estatico final
LAST=$(printf "%s/frame_0239.raw" "$FRAMES")
while true; do
    timeout 1 cat "$LAST" > "$FB" 2>/dev/null || exit 0
    sleep 1
    # safety: maximo 120s total
    [ "$(( $(date +%s) - START ))" -gt 120 ] && exit 0
done
exit 0
