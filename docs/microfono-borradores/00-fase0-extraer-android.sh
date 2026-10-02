#!/usr/bin/env bash
# ===========================================================================
#  FASE 0 — Micrófono interno del AYN Odin 3: descubrimiento desde el Android
# ===========================================================================
#  RIESGO 0: esto SOLO LEE del Android. No escribe nada en ninguna parte.
#
#  CÓMO SE USA
#    1. Arranca el ANDROID del Odin 3 (no Linux).
#    2. Conéctalo por USB al PC y activa "Depuración USB"
#       (Ajustes → Información del teléfono → toca 7 veces "Número de compilación"
#        → Opciones de desarrollador → Depuración USB).
#    3. En el PC:   ./00-fase0-extraer-android.sh
#
#  Requiere `adb` (en Arch: paquete android-tools).
#
#  QUÉ DECIDE ESTO (ver ../MICROFONO-INVESTIGACION.md y 05-analisis-topologias.md):
#    - El MicPMID del micro INTERNO:
#         0x1001        -> el micro está en el VA macro  -> Fases 1+2+3 (y hace falta
#                          una topología nueva, que es el bloqueador B5)
#         0x0C00-0x0C3F -> DMIC del WCD                  -> camino del Odin 2
#                                                          (B5 deja de ser bloqueador)
#    - Y si existe una topología .tplg de AYN con VA_CODEC_DMA_TX_0 **y** SECONDARY_MI2S.
# ===========================================================================
set -uo pipefail

DEST="${1:-./odin3-android-audio}"
mkdir -p "$DEST"

say() { printf '\n\033[1m== %s\033[0m\n' "$*"; }

command -v adb >/dev/null 2>&1 || { echo "Falta 'adb'. En Arch: sudo pacman -S android-tools"; exit 1; }
adb start-server >/dev/null 2>&1

say "Dispositivos conectados"
adb devices -l
if ! adb shell true 2>/dev/null; then
  echo "No hay dispositivo accesible. ¿Está en Android y con la depuración USB activada?"
  exit 1
fi

say "Identificación"
adb shell getprop ro.hardware
adb shell getprop ro.build.fingerprint
adb shell getprop ro.product.model

say "1/4 — Configuración de audio (LO MÁS IMPORTANTE)"
for d in /vendor/etc/audio /vendor/etc; do
  adb shell "ls $d 2>/dev/null" | tr -d '\r' | grep -iE "audio|platform|mixer" | sed "s|^|  $d/|"
done
for f in /vendor/etc/audio_platform_info.xml /vendor/etc/audio_platform_info_extcodec.xml \
         /vendor/etc/audio/audio_platform_info.xml /vendor/etc/audio_platform.xml \
         /vendor/etc/mixer_paths.xml /vendor/etc/audio/mixer_paths.xml; do
  adb pull "$f" "$DEST/" 2>/dev/null && echo "  bajado: $f"
done
# por si hay más de un fichero de perfiles
adb shell 'find /vendor/etc -iname "*audio*" -maxdepth 2 2>/dev/null' | tr -d '\r' | \
  while read -r f; do [ -n "$f" ] && adb pull "$f" "$DEST/" 2>/dev/null; done

say "2/4 — Topología del DSP (bloqueador B5)"
adb shell 'ls -la /vendor/lib/firmware/qcom/sm8750/ 2>/dev/null' | tr -d '\r' | head -20
adb shell 'find /vendor/lib/firmware /vendor/etc/firmware -iname "*tplg*" 2>/dev/null' | tr -d '\r' | \
  while read -r f; do [ -n "$f" ] && adb pull "$f" "$DEST/tplg/" 2>/dev/null; done
mkdir -p "$DEST/tplg"
adb pull /vendor/lib/firmware/qcom/sm8750 "$DEST/sm8750-fw" 2>/dev/null && echo "  bajado el firmware del SoC"

say "3/4 — El micro, visto por el propio Android"
adb shell dumpsys media.audio_flinger 2>/dev/null | tr -d '\r' > "$DEST/audio_flinger.txt"
adb shell dumpsys media.audio_policy   2>/dev/null | tr -d '\r' > "$DEST/audio_policy.txt"
echo "  guardados: audio_flinger.txt ($(wc -l < "$DEST/audio_flinger.txt" 2>/dev/null || echo 0) líneas)," \
     "audio_policy.txt ($(wc -l < "$DEST/audio_policy.txt" 2>/dev/null || echo 0) líneas)"

say "4/4 — ANÁLISIS (esto es lo que importa)"
if compgen -G "$DEST/*.xml" >/dev/null; then
  echo "  --- MicPMID encontrados ---"
  grep -aoE '<MicPMID value="0x[0-9A-Fa-f]+"' "$DEST"/*.xml 2>/dev/null | sort -u | sed 's/^/    /'
  echo "  --- rutas de captura citadas ---"
  grep -aoE 'VA_CODEC_DMA_TX_[0-9]|DMIC[0-9]|ADC[0-9]|SWR_MIC[0-9]+|SECONDARY_MI2S|PRIMARY_MI2S' \
    "$DEST"/*.xml 2>/dev/null | sort | uniq -c | sort -rn | sed 's/^/    /'
else
  echo "  (no se bajó ningún .xml — revisa la ruta en /vendor/etc)"
fi

if compgen -G "$DEST/sm8750-fw/*tplg*" >/dev/null || compgen -G "$DEST/tplg/*tplg*" >/dev/null; then
  echo "  --- la topología trae lo que buscamos? (DEBE salir VA_CODEC_DMA_TX_0 Y SECONDARY_MI2S) ---"
  for t in "$DEST"/tplg/*tplg* "$DEST"/sm8750-fw/*tplg*; do
    [ -f "$t" ] || continue
    printf "    %-40s VA=%s  SEC=%s  PRI=%s\n" "$(basename "$t")" \
      "$(grep -ac VA_CODEC_DMA_TX_0 "$t")" "$(grep -ac SECONDARY_MI2S "$t")" "$(grep -ac PRIMARY_MI2S "$t")"
  done
fi

say "LISTO"
cat <<'TXT'
  Interpretación:

    MicPMID 0x1001 (o rango del VA macro)  -> el micro va por el VA macro:
        hacen falta las Fases 1, 2 y 3 (topología nueva + DTS + UCM/servicio).
        B5 (la topología) es el bloqueador: mira si la del Android trae
        VA_CODEC_DMA_TX_0 Y SECONDARY_MI2S. Si la trae, esa es la que buscábamos.

    MicPMID 0x0Cxx (DMIC del WCD)          -> el micro va por el WCD:
        el camino es el del Odin 2 (03-servicio-mic-route.md, sección WCD) y
        NO hace falta tocar la topología ni recompilar el kernel.

  Pásale el resultado a Alfred (o pega el resumen) y seguimos desde ahí.
TXT
