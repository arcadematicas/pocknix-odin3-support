#!/usr/bin/env bash
# check-base-health — ¿está sana y al día la base ALARM de la imagen?
#
#   tools/check-base-health.sh                  informe por pantalla
#   tools/check-base-health.sh --telegram       además avisa por Telegram si hay novedades
#   tools/check-base-health.sh --lock <ruta>    otro lockfile
#   tools/check-base-health.sh --force          fuerza el aviso aunque no haya novedades
#
# Qué hace:
#   1) Lee pocknix-base.lock (nombre + versión exacta de los 889 paquetes del snapshot).
#   2) Descarga el tracker de seguridad de Arch y cruza solo las incidencias ABIERTAS.
#   3) Dice qué CVEs nos afectan, si hay parche y qué hacer (parche suelto o re-corte).
#   4) Avisa de la edad del snapshot (cadencia recomendada: 2-3 meses).
#   5) Con --telegram avisa solo si hay CVEs nuevos o si toca re-corte (guarda estado).
#
# Salida: 0 = sano · 10 = toca actuar (CVE grave con parche o snapshot viejo) · 11 = CVEs sin parche
set -uo pipefail

HERE=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd -P)
LOCK="${HERE}/../../pocknix-os/packages/shared/pocknix-base-lock/pocknix-base.lock"
STATE_DIR="${XDG_STATE_HOME:-$HOME/.local/state}/pocknix-base-health"
STATE="$STATE_DIR/last-avgs.txt"
TG=0; FORCE=0; prev=""
for a in "$@"; do
    case "$a" in
        --telegram) TG=1 ;;
        --force) FORCE=1 ;;
        --lock=*) LOCK="${a#--lock=}" ;;
        -h|--help) sed -n '2,16p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
    esac
    [ "$prev" = "--lock" ] && LOCK="$a"
    prev="$a"
done

[ -r "$LOCK" ] || { echo "no encuentro el lockfile: $LOCK" >&2; exit 2; }
command -v vercmp >/dev/null || { echo "falta vercmp (paquete pacman)" >&2; exit 2; }
[ -x "${HERE}/check-base-health.py" ] || { echo "falta ${HERE}/check-base-health.py" >&2; exit 2; }

OUT=$(mktemp)
python3 "${HERE}/check-base-health.py" "$LOCK" > "$OUT" 2>&1
rc=$?
cat "$OUT"

# --- aviso: solo si cambian las incidencias o si toca re-corte ---
mkdir -p "$STATE_DIR"
grep -oE 'AVG-[0-9]+' "$OUT" | sort -u > "$STATE_DIR/.now" || true
NEW=$(comm -13 "$STATE" "$STATE_DIR/.now" 2>/dev/null | tr '\n' ' ')
mv -f "$STATE_DIR/.now" "$STATE"

TG_TOKEN="${POCKNIX_TG_TOKEN:-8946276991:AAENfGidkPImV9eOy17xmc78mmA4Eq9DQD8}"
TG_CHAT="${POCKNIX_TG_CHAT:-12897672}"
need=0
[ "$FORCE" = 1 ] && need=1
[ -n "${NEW// /}" ] && need=1
grep -q "RE-CORTE\|planificar re-corte" "$OUT" && need=1
[ "$rc" -eq 10 ] && need=1

if [ "$TG" = 1 ] && [ "$need" = 1 ]; then
    extra=""
    [ -n "${NEW// /}" ] && extra="Nuevas incidencias: $NEW"
    curl -s --max-time 30 -X POST "https://api.telegram.org/bot${TG_TOKEN}/sendMessage" \
        -d chat_id="$TG_CHAT" --data-urlencode "text=[calvOS base] $extra
$(cat "$OUT")" >/dev/null && echo "aviso enviado por Telegram"
fi
rm -f "$OUT"
exit $rc
