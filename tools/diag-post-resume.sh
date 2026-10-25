#!/bin/bash
# diag-post-resume.sh — foto del estado de rendimiento para comparar ANTES y DESPUÉS de s2idle.
#
# Uso:
#   ./diag-post-resume.sh before    # con la consola recién arrancada o antes de suspender
#   ./diag-post-resume.sh after     # al volver de la suspensión
#   ./diag-post-resume.sh show      # ver las dos fotos y sus diferencias
#
# Escribe en ~/suspend-diag.log (una foto por invocación). No cambia NADA del sistema:
# solo lee sysfs/journal.
#
# Por qué existe: con el Zelda (Wind Waker HD) al TDP mínimo, recién arrancada va casi a 60 fps,
# y al volver de la suspensión "le cuesta moverse". Hay que saber QUÉ no se restaura
# (frecuencia de GPU, governor, scheduler sched_ext, perfil de potencia, térmicas, modo del panel).

set -u
LOG="${HOME}/suspend-diag.log"
GPU=/sys/class/devfreq/3d00000.gpu

read_or() { [ -r "$1" ] && cat "$1" 2>/dev/null || echo "n/a"; }

snapshot() {
  local label="$1"
  {
    echo "=================================================================="
    echo "== $label  $(date '+%Y-%m-%d %H:%M:%S')  uptime: $(cut -d. -f1 /proc/uptime)s"
    echo "=================================================================="

    echo "-- GPU (adreno 3d00000) --"
    echo "   cur=$(read_or $GPU/cur_freq) min=$(read_or $GPU/min_freq) max=$(read_or $GPU/max_freq) gov=$(read_or $GPU/governor)"
    echo "   trans_stat (últimas 6 líneas):"
    [ -r "$GPU/trans_stat" ] && tail -6 "$GPU/trans_stat" | sed 's/^/     /'

    echo "-- CPU --"
    for p in /sys/devices/system/cpu/cpufreq/policy*; do
      [ -d "$p" ] || continue
      echo "   $(basename "$p"): cur=$(read_or $p/scaling_cur_freq) max=$(read_or $p/scaling_max_freq) gov=$(read_or $p/scaling_governor) epp=$(read_or $p/energy_performance_preference)"
    done

    echo "-- scheduler sched_ext --"
    echo "   activo=$(read_or /sys/kernel/sched_ext/root/ops) | estado=$(read_or /var/lib/pocknix/scx-mode) | manual=$([ -e /var/lib/pocknix/scx-manual ] && echo si || echo no)"
    echo "   game-mode=$(read_or /run/pocknix/game-mode)"

    echo "-- perfil de potencia / térmicas --"
    echo "   perfil=$(read_or /var/lib/pocknix/power-profile) | fan-mode=$(read_or /var/lib/pocknix/fan-mode)"
    for z in /sys/class/thermal/thermal_zone*; do
      [ -r "$z/temp" ] || continue
      echo "   $(basename "$z") $(read_or $z/type): $(( $(cat "$z/temp") / 1000 ))C"
    done | sort -t: -k2 -rn | head -4
    for f in /sys/class/hwmon/hwmon*/fan1_input; do [ -r "$f" ] && echo "   fan: $(cat "$f") rpm"; done

    echo "-- panel / DRM --"
    echo "   conector: $(read_or /sys/class/drm/card0-DSI-1/status) | modos: $(tr '\n' ' ' < /sys/class/drm/card0-DSI-1/modes 2>/dev/null | cut -c1-60)"

    echo "-- memoria --"
    free -m | awk 'NR==2{print "   ram usada "$3"MB de "$2"MB"}'
    [ -r /sys/block/zram0/mm_stat ] && awk '{printf "   zram: orig %dMB comp %dMB\n", $1/1048576, $2/1048576}' /sys/block/zram0/mm_stat

    echo "-- suspensiones en este boot: $(journalctl -b --no-pager 2>/dev/null | grep -c 'PM: suspend exit') --"

    echo "-- errores de pantalla/GPU en este boot (últimas 5) --"
    journalctl -k -b --no-pager 2>/dev/null | grep -iE "dsi_cmds|panel-chipone|wait for commit|frame_done|a8xx_recover|GMU OOB|a6xx_gmu|preemption timed out|Timeout waiting for GPU to suspend|failed to suspend" | tail -5 | sed 's/^/   /'

    echo "-- carga y top CPU --"
    echo "   load: $(cut -d' ' -f1-3 /proc/loadavg)"
    ps -eo pcpu,comm --sort=-pcpu 2>/dev/null | head -6 | sed 's/^/   /'
    echo
  } >> "$LOG"
  echo "foto '$label' añadida a $LOG"
}

label="${1:-}"
if [ "${label}" = "show" ]; then
  [ -s "${LOG}" ] || { echo "no hay fotos todavia (${LOG})"; exit 1; }
  echo "--- log completo: ${LOG} ---"
  grep -E "^== |^   (cur=|activo=|perfil=|load:)" "${LOG}"
  exit 0
fi
if ! printf '%s' "${label}" | grep -qE '^[a-z][a-z0-9-]{0,20}$'; then
  echo "uso: $0 <etiqueta> | show      (etiqueta: before, after, after-play, ...)" >&2
  exit 2
fi
snapshot "${label}"
