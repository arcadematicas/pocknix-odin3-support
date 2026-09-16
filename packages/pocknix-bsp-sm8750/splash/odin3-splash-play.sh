#!/bin/sh
# odin3-splash-play.sh — splash de arranque del Odin 3 (sin Plymouth).
#
# POR QUÉ ASÍ
#   El bootanimation original se probó con Plymouth y falla en el panel DSI-1 (sin EDID):
#   el renderer DRM no dibuja en ese conector. ROCKNIX y ArmadaOS hacen lo mismo que
#   hacemos aquí: volcar frames directamente a /dev/fb0 desde un servicio systemd que corre
#   antes de que el compositor tome el display.
#
# POR QUÉ UN STREAM COMPRIMIDO
#   Los 240 frames en crudo (BGRX 1080x1920, stride 4352) son 8.355.840 B cada uno, o sea
#   1,9 GB. La SD va a 20-90 MB/s, así que leerlos en crudo NO da para 30 fps (harían falta
#   250 MB/s) y la animación salía a tirones. Los mismos frames comprimidos con zstd son
#   ~45 MB (ratio 42x, la animación es muy coherente entre frames) y descomprimir va a
#   ~1 GB/s: la animación sí corre fluida y ocupa 42 veces menos.
#
# Parte 1: reproduce los frames del stream.
# Parte 2: mantiene el último frame (el logo) hasta que kwin/gamescope toma el display.

FB=/dev/fb0
STREAM=/usr/share/odin3-splash/frames.raw.zst
TMP=/tmp/odin3-splash-last.raw

# Cada frame es 1080x1920 BGRX con stride 4352 (1080*4 + 32 de padding), tal y como los
# genera convert_frames.py. Si cambia el panel, cambian estos dos números.
FRAME_BYTES=8355840
TOTAL_FRAMES=240
FRAME_DELAY=0.028          # ~30 fps
ANIM_MAX=30                # corta la animación si el display se bloquea
HOLD_MAX=120               # y no se queda pegado más de 2 min en total

START=$(date +%s)

# Sin zstd o sin stream no hay nada que hacer (mejor no dejar el arranque colgado).
command -v zstdcat >/dev/null 2>&1 || exit 0
[ -r "${STREAM}" ] || exit 0

# El servicio arranca en multi-user.target pero puede que /dev/fb0 aún no exista.
i=0
while [ ! -e "${FB}" ] && [ "${i}" -lt 30 ]; do
    sleep 0.2
    i=$((i + 1))
done
[ -e "${FB}" ] || exit 0

# --- Parte 1: la animación ---------------------------------------------------
zstdcat "${STREAM}" 2>/dev/null | {
    n=0
    while [ "${n}" -lt "${TOTAL_FRAMES}" ]; do
        # dd lee EXACTAMENTE un frame del pipe y lo vuelca al framebuffer. timeout 1: si el
        # write se bloquea (el compositor ya tiene el DRM master) salimos en vez de colgarnos.
        timeout 1 dd bs="${FRAME_BYTES}" count=1 iflag=fullblock status=none \
            of="${FB}" 2>/dev/null || exit 0
        n=$((n + 1))
        sleep "${FRAME_DELAY}"
        [ "$(( $(date +%s) - START ))" -gt "${ANIM_MAX}" ] && exit 0
    done
}

# --- Parte 2: mantener el logo ----------------------------------------------
# El último frame se saca del final del stream (no del framebuffer: leerlo de vuelta de
# /dev/fb0 no es fiable). Descomprimir 45 MB otra vez cuesta ~2 s y pasa una sola vez.
zstdcat "${STREAM}" 2>/dev/null | tail -c "${FRAME_BYTES}" > "${TMP}" 2>/dev/null
[ -s "${TMP}" ] || exit 0
while true; do
    timeout 1 dd bs="${FRAME_BYTES}" count=1 iflag=fullblock status=none \
        if="${TMP}" of="${FB}" 2>/dev/null || exit 0
    sleep 1
    [ "$(( $(date +%s) - START ))" -gt "${HOLD_MAX}" ] && exit 0
done
