#!/bin/bash
# test-dock-dp.sh — estado del DisplayPort AltMode y del audio por DP, sin tocar nada.
#
#   ./test-dock-dp.sh            (en la consola, como deck)
#
# Comprueba, en este orden:
#   1. si el conector USB-C ha negociado AltMode / qué modo tiene
#   2. si el conector DP está "connected" en DRM
#   3. el estado del jack DP0 del codec
#   4. si el PCM de DP (hw:0,3) se puede abrir — esto es lo que decide si el perfil
#      UCM "HDMI" se puede activar sin dejar la consola sin audio
#
# No escribe nada. Para probar sonido: speaker-test -D hw:0,3 -c 2 -t sine
set -u

say() { printf '%s\n' "$*"; }
verdict=0

say "== USB-C / AltMode =="
found=0
for d in /sys/class/typec/port*; do
  [ -e "$d" ] || continue
  found=1
  say "  $d: data_role=$(cat "$d/data_role" 2>/dev/null) power_role=$(cat "$d/power_role" 2>/dev/null)"
  for p in "$d"/partner; do
    [ -e "$p" ] || continue
    say "    partner: $(cat "$p/type" 2>/dev/null) id=$(cat "$p/id" 2>/dev/null)"
    for m in "$p"/modes/*; do
      [ -e "$m" ] || continue
      say "    modo: $(basename "$m") svid=$(cat "$m/svid" 2>/dev/null)"
    done
  done
done
[ "$found" = 1 ] || say "  (sin puertos typec en /sys/class/typec)"

say
say "== AltMode (pmic_glink) =="
am=/sys/devices/platform/pmic-glink/pmic_glink.altmode.0
if [ -d "$am" ]; then
  for f in "$am"/*; do
    [ -f "$f" ] || continue
    case "$(basename "$f")" in
      force_dp) say "  force_dp=$(cat "$f" 2>/dev/null) (1 = forzado por udev al ver un dock)" ;;
    esac
  done
else
  say "  (no existe $am)"
fi

say
say "== DRM: conectores =="
for c in /sys/class/drm/card*-*; do
  [ -e "$c/status" ] || continue
  case "$(basename "$c")" in
    *DSI*|*DP*|*HDMI*)
      say "  $(basename "$c"): $(cat "$c/status")  $(cat "$c/enabled" 2>/dev/null)"
      ;;
  esac
done

say
say "== Jack DP0 =="
if amixer -c 0 cget iface=CARD,name="DP0 Jack" >/dev/null 2>&1; then
  amixer -c 0 cget iface=CARD,name="DP0 Jack" 2>/dev/null | sed -n 's/^ *: values=/  values=/p'
else
  say "  (el control DP0 Jack no responde ahora mismo)"
fi

say
say "== PCM de DP (hw:0,3) =="
if timeout 8 aplay -D hw:0,3 --dump-hw-params /dev/zero >/dev/null 2>&1; then
  say "  ABIERTO: el audio por DP se puede usar (se puede añadir el perfil UCM HDMI)"
else
  verdict=1
  say "  CIERRA con EINVAL: normal sin monitor conectado. NO añadir el perfil UCM HDMI"
  say "  todavía, o PipeWire descarta el perfil y la consola se queda sin altavoz."
fi

say
say "== Mezclador del enlace DP =="
if amixer -c 0 sget "DISPLAY_PORT_RX_0 Audio Mixer MultiMedia4" >/dev/null 2>&1; then
  say "  existe 'DISPLAY_PORT_RX_0 Audio Mixer MultiMedia4'"
else
  say "  no existe el control del mezclador DP (normal sin sink)"
fi

say
if [ "$verdict" = 0 ]; then
  say "RESULTADO: DP utilizable. Siguiente paso: activar el perfil UCM HDMI (docs/DOCK-DP.md)."
else
  say "RESULTADO: DP no utilizable todavía (sin monitor/dock). Nada que cambiar."
fi
exit "$verdict"
