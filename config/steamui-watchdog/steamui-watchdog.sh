#!/bin/bash
# steamui-watchdog — reinicia steamwebhelper si la UI de Steam se congela.
#
# steamwebhelper expone un puerto de debug (127.0.0.1:8080). Si la UI se
# bloquea (bug conocido de FEX/CEF), ese puerto deja de responder aunque el
# proceso siga vivo. Este watchdog hace un healthcheck cada 30s y, tras 3
# fallos consecutivos (~90s), reinicia steamwebhelper (Steam lo relanza solo).
# Solo actua en modo juego (cuando steam esta corriendo).

URL="http://127.0.0.1:8080/json/version"
FAILS=0
MAX_FAILS=3

log() { logger -t steamui-watchdog "$1"; }

log "Watchdog de UI iniciado (healthcheck cada 30s, reinicio tras $MAX_FAILS fallos)"

while true; do
    if pgrep -x steam >/dev/null 2>&1; then
        if curl -s -m 5 "$URL" >/dev/null 2>&1; then
            if [ "$FAILS" -ne 0 ]; then
                log "steamwebhelper responde de nuevo (fallos previos: $FAILS)"
            fi
            FAILS=0
        else
            FAILS=$((FAILS + 1))
            log "steamwebhelper sin respuesta ($FAILS/$MAX_FAILS)"
            if [ "$FAILS" -ge "$MAX_FAILS" ]; then
                log "UI congelada, reiniciando steamwebhelper"
                pkill -x steamwebhelper
                FAILS=0
            fi
        fi
    fi
    sleep 30
done
