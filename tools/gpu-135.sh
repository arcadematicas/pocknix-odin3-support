#!/bin/sh
# gpu-135 — test de GPU de 15 min para shuuri-labs/pocknix-os#135.
#
# POR QUE EXISTE: el PR #135 pide 15 minutos de carga de GPU en la consola y el filtro del journal
# (gdsc/gmu/oob/hangcheck/recover) para descartar hangs del GMU. El test tiene que correr en el
# SISTEMA DE SHUURI (rama sm8750-odin3), no en el nuestro: los parches no son los mismos.
#
# Uso (en la consola, con la sesion grafica arriba):
#   ./gpu-135.sh            # 15 minutos (por defecto)
#   ./gpu-135.sh 5          # 5 minutos (prueba rapida)
#
# Deja el resultado en ~/gpu-135-<fecha>.txt y lo imprime. Ese texto es lo que se pega en el PR.
set -u

MIN="${1:-15}"
NINST="${GPU135_INSTANCES:-1}"   # vkcube no es muy exigente: varias instancias cargan mas la GPU
OUT="$HOME/gpu-135-$(date +%Y%m%d-%H%M%S).txt"
JOURNAL_RX='gdsc|gmu|oob|hangcheck|recover'

log() { printf '%s\n' "$*" | tee -a "$OUT"; }

: > "$OUT"
log "=== gpu-135 — $(date -Is) ==="
log "duracion: ${MIN} min"
log ""
log "-- sistema --"
log "kernel   : $(uname -r)"
log "modelo   : $(tr -d '\0' < /proc/device-tree/model 2>/dev/null || echo n/d)"
log "os       : $(grep -m1 PRETTY_NAME /etc/os-release 2>/dev/null | cut -d= -f2 | tr -d '\"')"
for p in mesa pocknix-turnip-arm linux-pocknix-sm8750 gamescope; do
  v=$(pacman -Q "$p" 2>/dev/null | awk '{print $2}')
  [ -n "$v" ] && log "$(printf '%-18s' "$p"): $v"
done
log ""

# Carga: vkcube es lo mas simple y viene en vulkan-tools; si no, glmark2.
# glxgears sin vsync satura relleno de verdad (medido: 3100 FPS, GPU a 734 MHz);
# vkcube (un cubo) es demasiado ligero y deja la GPU en 160 MHz: no sirve como carga.
if command -v glxgears >/dev/null 2>&1; then
  LOAD="env vblank_mode=0 glxgears -fullscreen"
elif command -v vkcube >/dev/null 2>&1; then
  LOAD="vkcube"
elif command -v glmark2 >/dev/null 2>&1; then
  LOAD="glmark2 --run-forever"
else
  log "ERROR: falta vkcube (vulkan-tools) y glmark2. Instala uno de los dos."
  exit 1
fi

if [ -z "${DISPLAY:-}" ] && [ -z "${WAYLAND_DISPLAY:-}" ]; then
  log "AVISO: sin DISPLAY/WAYLAND_DISPLAY. En la consola suele ser DISPLAY=:0 (Xwayland de gamescope)."
  log "       Exporta DISPLAY=:0 o XDG_RUNTIME_DIR=/run/user/\$(id -u) WAYLAND_DISPLAY=wayland-0"
fi

log "-- carga (${LOAD} x ${NINST}) durante ${MIN} min --"
# La primera linea de vkcube dice la GPU y la version de Vulkan: se guarda.
(sleep 2; kill "$(pgrep -n -f '^vkcube|^glmark2')" 2>/dev/null) &
KILLER=$!
i=1
while [ "$i" -le "$NINST" ]; do
  timeout $((MIN * 60 + 5)) $LOAD >> /tmp/gpu-135-load.log 2>&1 &
  i=$((i + 1))
done
wait
LOAD_RC=$?
kill "$KILLER" 2>/dev/null
log "salida de la carga (rc=$LOAD_RC):"
sed -n '1,6p' /tmp/gpu-135-load.log | sed 's/^/  /' | tee -a "$OUT"
log ""

log "-- journal del kernel (filtro del PR) --"
COUNT=$(journalctl -k -b --no-pager 2>/dev/null | grep -icE "$JOURNAL_RX")
log "coincidencias de '${JOURNAL_RX}': ${COUNT}"
journalctl -k -b --no-pager 2>/dev/null | grep -iE "$JOURNAL_RX" | tail -40 | sed 's/^/  /' | tee -a "$OUT"
log ""

log "-- errores de GPU en la sesion (dmesg) --"
dmesg 2>/dev/null | grep -iE 'gpu|adreno|msm|fault|timeout' | tail -20 | sed 's/^/  /' | tee -a "$OUT"
log ""

log "-- temperatura / frecuencia al terminar --"
for z in /sys/class/thermal/thermal_zone*/temp; do
  t=$(cat "$z" 2>/dev/null) || continue
  # solo las zonas que importan (cpu/gpu/skin): hay 50+ y el resto es ruido
  case "$t" in
    ''|0) continue ;;
  esac
  [ "$t" -gt 40000 ] 2>/dev/null && printf '  %s: %s\n' "$(basename "$(dirname "$z")")" "$t"
done | head -8 | tee -a "$OUT"
for f in /sys/class/devfreq/*gpu*/cur_freq /sys/class/devfreq/*gpu*/max_freq; do
  [ -f "$f" ] && log "  $f: $(cat "$f")"
done

log ""
log "=== fin. Informe: $OUT ==="
log ""
log "Para el PR (#135): pega el bloque '-- journal del kernel --' completo."
