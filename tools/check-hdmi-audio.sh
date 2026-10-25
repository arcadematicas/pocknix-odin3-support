#!/usr/bin/env bash
# check-hdmi-audio.sh — ¿hay ya forma de sacar audio por HDMI/DisplayPort en el Odin 3?
#
# Imprime 2 líneas, para el informe diario de `check-upstream-daily.sh`.
#
# Por qué existe (docs/AUDIO-HDMI-20261025.md): hoy NO hay audio por HDMI porque la topología
# del SM8750 (`SM8750-AYN-tplg.bin`) no trae backend de DisplayPort (no existe `hw:0,3`) y el
# kernel no tiene los parches de audio DP. Se arregla con **dos** piezas: parches de kernel
# (`drm_connector_hdmi_audio_ops` / `hw_params`) + una **tplg con DP**. Este chequeo avisa si
# aparece cualquiera de las dos.
#
# Solo informa: no descarga ni modifica nada.
set -u
HERE="$(cd "$(dirname "$0")" && pwd)"
CENTRO="${HERE}/.."
OS_TREE="${POCKNIX_OS:-${CENTRO}/../pocknix-os}"
GH="https://api.github.com"

# 1) Nuestra tplg: ¿tiene DP?
tplg=""
for cand in \
  "${OS_TREE}/devices/sm8750/firmware/qcom/sm8750/SM8750-AYN-tplg.bin" \
  "${OS_TREE}/vendor/rocknix-extra-firmware/SM8750/qcom/sm8750/SM8750-AYN-tplg.bin" ; do
  [ -r "${cand}" ] && { tplg="${cand}"; break; }
done
if [ -n "${tplg}" ]; then
  # las topologías son binarias: los nombres de widget/PCM van en ASCII
  n=$(strings -n 3 "${tplg}" 2>/dev/null | grep -ciE 'hdmi|display_?port|multimedia4|dp0')
  printf 'HDMI/DP: tplg SM8750 %s (%s menciones de DP/HDMI)\n' \
    "$([ "${n}" -gt 0 ] && echo 'CON DP' || echo 'sin DP')" "${n}"
else
  printf 'HDMI/DP: tplg SM8750 no encontrada en el arbol\n'
fi

# 2) ¿Aparece una tplg de sm8750 con DP publicada, o parches de audio DP para sm8750?
# Arbol de git (funciona sin token; la API de code-search sin token da 401)
tree_count() {  # $1=repo  $2=patron
  curl -fsSL -H 'User-Agent: pocknix-upstream-check' \
    "https://api.github.com/repos/$1/git/trees/HEAD?recursive=1" 2>/dev/null \
  | python3 -c "
import sys, json, re
pat = re.compile(sys.argv[1], re.I)
try:
    d = json.load(sys.stdin)
    print(sum(1 for e in d.get('tree', []) if pat.search(e.get('path',''))))
except Exception:
    print('?')" "$2" 2>/dev/null || echo '?'
}

tplg_armada=$(tree_count armada-os/armada 'sm8750.*tplg|tplg.*8750')
tplg_rocknix=$(tree_count ROCKNIX/extra-firmware 'sm8750.*tplg|tplg.*8750')
patches=$(curl -fsSL -H 'User-Agent: pocknix-upstream-check' \
  "https://raw.githubusercontent.com/armada-os/armada/main/packages/kernel/patches/series" 2>/dev/null \
  | grep -ciE 'hdmi[_-]audio|dp[_-]audio|audio.*displayport' 2>/dev/null || echo 0)
rnx_patches=$(tree_count ROCKNIX/distribution 'hdmi_audio_ops|dp_audio')

# ¿la tplg de armada trae audio DP? (24 KB; es la señal que importa)
armada_dp="?"
tmp=$(mktemp)
if curl -fsSL -H 'User-Agent: pocknix-upstream-check' \
     "https://raw.githubusercontent.com/armada-os/armada/main/system_files/usr/lib/firmware/qcom/sm8750/SM8750-AYN-tplg.bin" \
     -o "${tmp}" 2>/dev/null; then
  if strings -n 3 "${tmp}" 2>/dev/null | grep -qiE 'display_?port|multimedia4'; then armada_dp="CON DP"; else armada_dp="sin DP"; fi
fi
rm -f "${tmp}"

printf 'HDMI/DP: tplg de armada %s | publicadas -> armada=%s, ROCKNIX=%s | parches audio DP -> armada=%s, ROCKNIX=%s\n' \
  "${armada_dp}" "${tplg_armada}" "${tplg_rocknix}" "${patches}" "${rnx_patches}"
printf '  (si aparece una tplg sm8750 CON DP o parches de audio DP para sm8750: leer docs/AUDIO-HDMI-20261025.md y probar)\n'
