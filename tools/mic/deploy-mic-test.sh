#!/usr/bin/env bash
# deploy-mic-test.sh — lleva el kit del microfono a la Odin y lo prueba sin recompilar paquetes.
#
#   ./deploy-mic-test.sh --probe        inventario + prueba de captura (NO cambia nada)
#   ./deploy-mic-test.sh --enable       instala la UCM con micro (con backup) y reinicia WirePlumber
#   ./deploy-mic-test.sh --revert       vuelve a la UCM original (ultimo backup)
#   ./deploy-mic-test.sh --route        instala y activa pocknix-odin3-mic-route.service
#   ./deploy-mic-test.sh --route-off    desactiva el servicio de routing
#   ./deploy-mic-test.sh --status       estado (UCM instalada, servicio, fuentes de PipeWire)
#
# Variables: ODIN_HOST (por defecto "odin"), ODIN_SUDO_PASS (por defecto "pocknix"),
#            ODIN_UID (por defecto 1001, el usuario deck).
#
# Orden recomendado: --probe, y solo si el PCM de captura abre y da senal, --enable y luego --route.
set -u

HOST="${ODIN_HOST:-odin}"
PASS="${ODIN_SUDO_PASS:-pocknix}"
UID_DECK="${ODIN_UID:-1001}"
HERE="$(cd "$(dirname "$0")" && pwd -P)"

UCM_DIR=/usr/share/alsa/ucm2/AYN/Odin3
BAK_DIR=/var/backups/pocknix
SVC=/etc/systemd/system/pocknix-odin3-mic-route.service
BIN=/usr/local/bin/pocknix-odin3-mic-route
CONF=/etc/pocknix/mic-route.conf

die() { echo "error: $*" >&2; exit 1; }
say() { printf '\n\033[1;34m==>\033[0m %s\n' "$*"; }

ssh_ok() { ssh -o BatchMode=no -o ConnectTimeout=10 "$HOST" true 2>/dev/null; }

rsudo() { printf '%s\n' "$PASS" | ssh "$HOST" "sudo -S -p '' $*"; }
rdeck() { ssh "$HOST" "XDG_RUNTIME_DIR=/run/user/${UID_DECK} $*"; }

wp_restart() {
  rdeck "systemctl --user restart wireplumber" >/dev/null 2>&1 \
    || echo "aviso: no se pudo reiniciar wireplumber; reinicia sesion si no aparece el micro"
  sleep 2
}

mic_installed() {
  ssh "$HOST" "grep -q 'SectionDevice.\"Mic\"' ${UCM_DIR}/HiFi.conf 2>/dev/null" && echo si || echo no
}

case "${1:-}" in -h|--help) sed -n '2,17p' "$0"; exit 0 ;; esac

ssh_ok || die "no puedo conectar con '$HOST' (Tailscale arriba? ODIN_HOST=usuario@ip?)"

case "${1:---status}" in
  --probe)
    say "sonda del microfono (no cambia nada)"
    scp -q "$HERE/probe-mic.sh" "$HOST:/tmp/probe-mic.sh" || die "scp fallo"
    rsudo "install -m755 /tmp/probe-mic.sh /tmp/probe-mic.sh"
    printf '%s\n' "$PASS" | ssh "$HOST" "sudo -S -p '' /tmp/probe-mic.sh" | sed 's/^/   /'
    out="$(pwd)/mic-probe-$(date +%Y%m%d-%H%M).txt"
    scp -q "$HOST:/tmp/mic-probe.txt" "$out" 2>/dev/null && say "informe guardado en $out"
    ;;

  --enable)
    say "instalando la UCM con micro"
    scp -q "$HERE/HiFi-mic.conf" "$HOST:/tmp/HiFi-mic.conf" || die "scp fallo"
    rsudo "install -d ${BAK_DIR} && install -m644 ${UCM_DIR}/HiFi.conf ${BAK_DIR}/HiFi.conf.\$(date +%Y%m%d-%H%M%S) && install -m644 /tmp/HiFi-mic.conf ${UCM_DIR}/HiFi.conf"
    echo "   backup: ${BAK_DIR}/HiFi.conf.* (en la Odin)"
    wp_restart
    say "fuentes de audio (deberia salir un 'Microphone'/'Mic')"
    rdeck "wpctl status" 2>/dev/null | sed -n '/Audio/,/Video/p' | sed 's/^/   /'
    ;;

  --revert)
    say "volviendo a la UCM original"
    rsudo "b=\$(ls -1t ${BAK_DIR}/HiFi.conf.* 2>/dev/null | head -1); [ -n \"\$b\" ] && install -m644 \"\$b\" ${UCM_DIR}/HiFi.conf && echo restaurado \$b || echo 'no hay backup'"
    wp_restart
    echo "   SectionDevice Mic instalado ahora: $(mic_installed)"
    ;;

  --route)
    say "instalando el servicio de routing"
    scp -q "$HERE/pocknix-odin3-mic-route" "$HOST:/tmp/pocknix-odin3-mic-route" || die "scp fallo"
    scp -q "$HERE/pocknix-odin3-mic-route.service" "$HOST:/tmp/pocknix-odin3-mic-route.service" || die "scp fallo"
    rsudo "install -Dm755 /tmp/pocknix-odin3-mic-route ${BIN}"
    rsudo "install -Dm644 /tmp/pocknix-odin3-mic-route.service ${SVC}"
    rsudo "install -d /etc/pocknix && { [ -f ${CONF} ] || printf 'MODE=DMIC\n' > ${CONF}; }"
    rsudo "systemctl daemon-reload && systemctl enable --now pocknix-odin3-mic-route.service"
    say "log del servicio"
    ssh "$HOST" "journalctl -u pocknix-odin3-mic-route.service -n 15 --no-pager -o cat" | sed 's/^/   /'
    ;;

  --route-off)
    say "desactivando el servicio de routing"
    rsudo "systemctl disable --now pocknix-odin3-mic-route.service 2>/dev/null; rm -f ${SVC} ${BIN}; systemctl daemon-reload"
    ;;

  --status)
    say "estado"
    echo "   host:            $HOST"
    echo "   UCM con Mic:     $(mic_installed)"
    echo "   backups:         $(ssh "$HOST" "ls -1 ${BAK_DIR}/HiFi.conf.* 2>/dev/null | wc -l" 2>/dev/null)"
    echo "   servicio route:  $(ssh "$HOST" "systemctl is-active pocknix-odin3-mic-route.service 2>/dev/null" || echo n/a)"
    say "audio (PipeWire)"
    rdeck "wpctl status" 2>/dev/null | sed -n '/Audio/,/Video/p' | sed 's/^/   /'
    ;;

  -h|--help|*)
    sed -n '2,17p' "$0"
    ;;
esac
