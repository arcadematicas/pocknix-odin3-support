#!/bin/bash
# steamui-watchdog — reinicia steamwebhelper si la UI de Steam se congela.
#
# steamwebhelper expone un puerto de debug (127.0.0.1:8080). Si la UI se
# bloquea (bug conocido de FEX/CEF), ese puerto deja de responder aunque el
# proceso siga vivo. Este watchdog hace un healthcheck cada 30s y, tras 3
# fallos consecutivos (~90s), reinicia steamwebhelper (Steam lo relanza solo).
# Solo actua en modo juego (cuando steam esta corriendo).
#
# OJO (21/10): solo se cuentan fallos DESPUES de que el puerto haya respondido
# al menos una vez desde que arranco ESE Steam. Antes se contaba desde el
# segundo cero, asi que un Steam que tardaba mas de 90 s en levantar la UI
# (primera carga tras una actualizacion, CEF compilando shaders...) se veia
# como "congelado" y el watchdog lo mataba en bucle: el usuario veia Steam
# reiniciarse solo una y otra vez.

URL="http://127.0.0.1:8080/json/version"
FAILS=0
MAX_FAILS=3
STEAM_PID=""
SEEN_OK=0

log() { logger -t steamui-watchdog "$1"; }

game_running() {
    # Hay juego si corre un .exe de Proton/FEX o un lanzador de juego.
    pgrep -f -d '' '\.exe( |$)' >/dev/null 2>&1 && return 0
    pgrep -f 'pocknix-game-launch' >/dev/null 2>&1 && return 0
    return 1
}

log "Watchdog de UI iniciado (healthcheck cada 30s, reinicio tras $MAX_FAILS fallos, solo si la UI llego a responder)"

while true; do
    pid="$(pgrep -x steam 2>/dev/null | head -1)"
    if [ -n "$pid" ]; then
        if [ "$pid" != "$STEAM_PID" ]; then
            STEAM_PID="$pid"
            FAILS=0
            SEEN_OK=0
            log "Steam nuevo (pid $pid): esperando a que la UI responda antes de contar fallos"
        fi

        if game_running; then
            # Con un juego en marcha la UI puede tardar mas de la cuenta en responder (CPU/GPU
            # ocupadas). Antes se contaban esos fallos y se reiniciaba steamwebhelper EN MITAD
            # de la partida: era justo el "se traba el QAM". Ahora no se cuenta ni se reinicia.
            if [ "$FAILS" -ne 0 ]; then
                log "juego en marcha: healthchecks en pausa (fallos $FAILS reseteados)"
            fi
            FAILS=0
            sleep 30
            continue
        fi
        if curl -s -m 8 "$URL" >/dev/null 2>&1; then
            if [ "$FAILS" -ne 0 ]; then
                log "steamwebhelper responde de nuevo (fallos previos: $FAILS)"
            fi
            FAILS=0
            SEEN_OK=1
        elif [ "$SEEN_OK" -eq 1 ]; then
            FAILS=$((FAILS + 1))
            log "steamwebhelper sin respuesta ($FAILS/$MAX_FAILS)"
            if [ "$FAILS" -ge "$MAX_FAILS" ]; then
                log "UI congelada, reiniciando steamwebhelper"
                pkill -x steamwebhelper
                FAILS=0
                SEEN_OK=0
            fi
        fi
        # SEEN_OK=0 y sin respuesta: la UI aun no ha arrancado; no se toca nada.
    else
        STEAM_PID=""
        SEEN_OK=0
        FAILS=0
    fi
    sleep 30
done
