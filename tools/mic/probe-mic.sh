#!/usr/bin/env bash
# probe-mic.sh — inventario del microfono del Odin 3. NO cambia nada: solo lee y graba
# 3 s en cada PCM de captura candidato para ver cual existe y si trae senal.
#
# Se ejecuta EN LA ODIN (lo lanza tools/mic/deploy-mic-test.sh --probe).
# Escribe el informe en /tmp/mic-probe.txt y lo imprime al final.
#
# Contexto: el dai-link de captura de nuestro DTS (parche 0046) es "WCD Capture"
# (wcd939x 1 + swr2 + lpass_txmacro -> q6apmbedai TX_CODEC_DMA_TX_3) y es el 3er link,
# asi que el PCM deberia ser hw:0,2. Los PCMs 0/1 son playback (Speaker / Headphones).
set -u
OUT=/tmp/mic-probe.txt
: > "$OUT"
say() { echo "$@" | tee -a "$OUT"; }

say "== probe-mic $(date -Is) =="
say

say "-- tarjetas --"
cat /proc/asound/cards 2>/dev/null | tee -a "$OUT"
say
say "-- PCMs --"
cat /proc/asound/pcm 2>/dev/null | tee -a "$OUT"
say

say "-- controles de captura (ADC/TX/DMIC/AMIC/MultiMedia) --"
amixer -c 0 scontrols 2>/dev/null | grep -iE "adc|tx[0-9]|dmic|amic|mic|multimedia|va[ _-]?macro" | tee -a "$OUT"
say

say "-- valores de los que importan --"
for c in "TX0 MODE" "TX1 MODE" "ADC1 MUX" "ADC1 Volume" "ADC1 Switch" "ADC1_MIXER Switch" \
         "MultiMedia3 Mixer TX_CODEC_DMA_TX_3" "RX_CODEC_DMA_RX_0 Audio Mixer MultiMedia2"; do
  v="$(amixer -c 0 sget "$c" 2>/dev/null | tr -s ' ' | sed -n 's/.*: values=//p' | head -1)"
  [ -n "$v" ] && say "   $c = $v"
done
say

say "-- prueba de captura (3 s por PCM, 48 kHz estereo S16) --"
for pcm in 2 3 0 1; do
  w=/tmp/mic-test-${pcm}.wav
  rm -f "$w"
  if timeout 12 arecord -D "hw:0,${pcm}" -d 3 -f S16_LE -r 48000 -c 2 "$w" >/tmp/arec-${pcm}.log 2>&1; then
    rms="$(python3 - "$w" <<'PY' 2>/dev/null
import sys, wave, audioop
try:
    w = wave.open(sys.argv[1], "rb")
    d = w.readframes(w.getnframes())
    print("%.1f dBFS pico, %.1f dBFS rms" % (
        (20 * __import__("math").log10(max(audioop.max(d, 2), 1) / 32768.0)),
        (20 * __import__("math").log10(max(audioop.rms(d, 2), 1) / 32768.0))))
except Exception as e:
    print("(no se pudo medir: %s)" % e)
PY
)"
    say "   hw:0,${pcm}: GRABO -- $rms"
  else
    say "   hw:0,${pcm}: fallo -- $(tail -1 /tmp/arec-${pcm}.log 2>/dev/null | cut -c1-110)"
  fi
  rm -f "$w"
done
say

say "-- kernel: codec / macros --"
dmesg 2>/dev/null | grep -iE "wcd939|txmacro|rxmacro|va.?macro|swr[0-9]|q6apm|asoc.*(error|fail)" | tail -15 | tee -a "$OUT"
say

say "-- PipeWire / WirePlumber --"
if command -v wpctl >/dev/null; then
  sudo -u deck XDG_RUNTIME_DIR=/run/user/1001 wpctl status 2>/dev/null | sed -n '/Audio/,/Video/p' | tee -a "$OUT"
fi
say

say "-- estado del servicio de routing (si existe) --"
systemctl is-enabled pocknix-odin3-mic-route.service 2>/dev/null | sed 's/^/   enabled: /' | tee -a "$OUT"
systemctl is-active  pocknix-odin3-mic-route.service 2>/dev/null | sed 's/^/   active:  /' | tee -a "$OUT"
say
say "== fin =="
echo
echo "informe: $OUT"
