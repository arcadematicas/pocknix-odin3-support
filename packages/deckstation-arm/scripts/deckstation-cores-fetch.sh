#!/bin/bash
# ======================================================================
# deckstation-cores-fetch.sh — DESCARGA los cores a la carpeta portable
# ======================================================================
# DeckStation debe ser AUTONOMO del sistema operativo del cliente: sus cores
# viven DENTRO de su propia carpeta portable de RetroArch. Este script los
# DESCARGA ahi cuando faltan, de tres fuentes:
#
#   1) Set de ArkOS (christianhaitian/retroarch-cores, commit pineado)
#   2) Buildbot oficial de libretro (nightly/linux/aarch64)
#   3) Release propio para los cores que NADIE publica ya compilados
#      (azahar, bsnes-hd): se compilaron a mano porque no existen en (1) ni (2).
#
# Lo llama deckstation-setup.sh — es decir, cuando el usuario le da a
# "Instalar DeckStation" desde Pocknix Tools: en ese momento se baja
# DeckStation Y sus cores, quedando todo dentro de la carpeta portable.
#
# No destructivo e idempotente: SOLO descarga lo que falte.
# Si una descarga falla, avisa y SIGUE (no rompe la instalacion).
#
# Uso: deckstation-cores-fetch.sh [--dry-run] [--solo <core>]
# ======================================================================
set -u

SELF="$(readlink -f "${BASH_SOURCE[0]}")"
DECKSTATION_ROOT="${DECKSTATION_ROOT:-$(cd "$(dirname "$SELF")/.." && pwd)}"
APPS_DIR="${DECKSTATION_ROOT}/Apps"

ARKOS_COMMIT="913e84e8371aa252e1c520729fba04bb6a8bc1f1"
ARKOS_BASE="https://raw.githubusercontent.com/christianhaitian/retroarch-cores/${ARKOS_COMMIT}/aarch64"
BUILDBOT_BASE="https://buildbot.libretro.com/nightly/linux/aarch64/latest"
# Release con los cores que no publica nadie (compilados por el proyecto).
EXTRAS_BASE="${DECKSTATION_EXTRAS_BASE:-https://github.com/arcadematicas/deckstation-cores/releases/download/cores-2026-09}"
INFO_BASE="https://raw.githubusercontent.com/libretro/libretro-super/master/dist/info"

# Los .info de estos cores vienen de libretro-super (RetroArch los usa para
# mostrar el nombre y las opciones del core).
INFO_EXTRA="1"

DRY=0
SOLO=""
while [ $# -gt 0 ]; do
    case "$1" in
        --dry-run) DRY=1 ;;
        --solo) shift; SOLO="${1:-}" ;;
        -h|--help) sed -n '2,25p' "$SELF"; exit 0 ;;
    esac
    shift
done

log()  { echo "  [cores] $*"; }
warn() { echo "  [cores] AVISO: $*" >&2; }

# --- Localiza el .home portable de RetroArch (misma logica que lanzar.sh) ---
resolve_retroarch_home() {
    local dir home img sub base low
    dir="$(find "$APPS_DIR" -maxdepth 1 -type d -iname "retroarch" 2>/dev/null | head -1)"
    [ -n "$dir" ] || return 1
    home="$(find "$dir" -maxdepth 3 -type d -name "*.home" 2>/dev/null | head -1)"
    [ -n "$home" ] && { printf '%s' "$home"; return 0; }
    img="$(find "$dir" -maxdepth 3 -type f \( -iname "*.AppImage" -o -iname "*.appimage" \) 2>/dev/null | head -1)"
    [ -n "$img" ] && { printf '%s' "${img}.home"; return 0; }
    for sub in "$dir"/*/; do
        [ -d "$sub" ] || continue
        base="$(basename "$sub")"
        low="$(printf '%s' "$base" | tr '[:upper:]' '[:lower:]')"
        case "$low" in retroarch*) printf '%s' "${sub%/}.AppImage.home"; return 0 ;; esac
    done
    return 1
}

RA_HOME="$(resolve_retroarch_home)" || { warn "RetroArch no instalado todavia; nada que descargar"; exit 0; }
CORES_DIR="${RA_HOME}/.config/retroarch/cores"
[ "$DRY" = 1 ] || mkdir -p "$CORES_DIR"

command -v curl   >/dev/null 2>&1 || { warn "falta curl"; exit 1; }
command -v unzip  >/dev/null 2>&1 || { warn "falta unzip"; exit 1; }

# ---------------------------------------------------------------------------
# Cores del set de ArkOS (mayoria) y del buildbot oficial.
# ---------------------------------------------------------------------------
CORES_ARKOS=(
    2048 81 DoubleCherryGB a5200 applewin ardens arduous atari800 b2 bk
    bluemsx bnes bsnes cannonball cap32 chailove chimerasnes craft crocods
    daphne desmume2015 dinothawr dosbox dosbox_pure dosbox_svn doukutsu_rs
    duckstation easyrpg ecwolf emuscv ep128emu_core fake08 fbalpha2012
    fbalpha2012_cps1 fbalpha2012_cps2 fbalpha2012_cps3 fbalpha2012_neogeo
    fbneo fceumm fceunext fly_flycast flycast flycast_rumble fmsx freechaf
    freeintv freej2me freej2me-plus fuse gambatte gearboy gearcoleco
    gearsystem genesis_plus_gx genesis_plus_gx_EX genesis_plus_gx_wide
    geolith gme gpsp gw handy hatari hatarib imageviewer
    km_fbneo_xtreme_amped libgametank lowresnx lutro mame mame2000 mame2003
    mame2003_plus mame2010 mame2015 mametiger mednafen_lynx mednafen_ngp
    mednafen_pce_fast mednafen_pcfx mednafen_psx_hw mednafen_supafaust
    mednafen_supergrafx mednafen_vb mednafen_wswan melonds mesen mess
    mess2015 meteor mgba mgba_rumble minivmac mpv mrboom mu mupen64plus
    mupen64plus_next nekop2 neocd nestopia np2kai numero nxengine o2em
    onscripter onsyuri opera parallel_n64 pcsx_rearmed pcsx_rearmed_rumble
    picodrive pokemini potator ppsspp prboom prosystem puae puae2021
    puzzlescript px68k quasi88 quicknes race reminiscence retro8 same_cdi
    sameboy sameduck scummvm smsplus snes9x snes9x2002 snes9x2005
    snes9x2005_plus snes9x2010 stella stella2014 superflappybirds
    swanstation tgbdual theodore tic80 tyrquake uae4arm uzem vba_next vbam
    vecx vemulator vice_x128 vice_x64 vice_x64sc vice_xcbm2 vice_xcbm5x0
    vice_xpet vice_xplus4 vice_xscpu64 vice_xvic vircon32 virtualjaguar
    wasm4 x1 xrick yabasanshiro yabause
)

CORES_BUILDBOT=(
    3dengine amiarcadia amiberry anarch armsx2 bbkemu blastem boom3
    bsnes-jg bsnes2014_accuracy bsnes2014_balanced bsnes2014_performance
    bsnes_cplusplus98 bsnes_mercury_accuracy bsnes_mercury_balanced
    bsnes_mercury_performance cdi2015 cemu citra citra2018 clownmdemu
    desmume dice dingooemu dirksimple dolphin dosbox_core fixgb fixnes
    frodo fsuae galaksija gam4980 geargrafx gearlynx gong hatari2014 hbmame
    holani irogb jaxe jollycv jumpnbump kronos mame2003_midway mame2016
    mednafen_gba mednafen_pce mednafen_psx mednafen_saturn mednafen_snes
    melondsds mesen-s mesen2 mojozork native32emu nicaiemu
    nside_sfc_balanced nuance oberon omicron openlara pcee2 pcsx2 pd777
    play pocketcdg pokketstation radio remotejoy rustynes skyemu
    spmp8000emu squirreljme stella2023 superbroswar supermodel tamalibretro
    thepowdertoy tia uw8 vaporspec video_processor virtualxt vitaquake2
    vitaquake2-rogue vitaquake2-xatrix vitaquake2-zaero vitaquake3 wqxemu
)

# Cores propios (no los publica nadie): se bajan del release del proyecto.
CORES_EXTRAS=(
    azahar
    bsnes_hd_beta
)

descargar() {  # descargar <nombre> <base_url> <etiqueta>
    local nombre="$1" base="$2" etiqueta="$3"
    local dst="${CORES_DIR}/${nombre}_libretro.so"
    if [ -e "$dst" ]; then
        echo "skip"
        return 0
    fi
    if [ "$DRY" = 1 ]; then
        log "DESCARGARIA ${nombre} (${etiqueta})"
        echo "dry"
        return 0
    fi
    local tmp; tmp="$(mktemp -d)"
    local ok=0
    # 1) Formato ZIP (buildbot oficial y set de ArkOS: <core>_libretro.so.zip)
    if curl -fsSL --retry 2 --connect-timeout 20 -o "${tmp}/${nombre}.zip" \
         "${base}/${nombre}_libretro.so.zip" 2>/dev/null \
       && unzip -o -q "${tmp}/${nombre}.zip" -d "$CORES_DIR/" 2>/dev/null \
       && [ -e "$dst" ]; then
        ok=1
    fi
    # 2) Formato suelto (.so directo: releases propios, p. ej. deckstation-cores)
    if [ "$ok" = 0 ]; then
        if curl -fsSL --retry 2 --connect-timeout 20 -o "$dst" \
             "${base}/${nombre}_libretro.so" 2>/dev/null && [ -s "$dst" ]; then
            ok=1
        else
            rm -f "$dst"
        fi
    fi
    if [ "$ok" = 1 ]; then
        # El .info (nombre del core y opciones en RetroArch)
        [ "$INFO_EXTRA" = 1 ] && [ ! -e "${CORES_DIR}/${nombre}_libretro.info" ] && \
            curl -fsSL --connect-timeout 20 -o "${CORES_DIR}/${nombre}_libretro.info" "${INFO_BASE}/${nombre}_libretro.info" 2>/dev/null
        rm -rf "$tmp"
        echo "ok"
        return 0
    fi
    rm -rf "$tmp"
    echo "fail"
    return 1
}

bajados=0; saltados=0; fallos=0; fallidos=""
for c in "${CORES_ARKOS[@]}"; do
    [ -n "$SOLO" ] && [ "$c" != "$SOLO" ] && continue
    r="$(descargar "$c" "$ARKOS_BASE" "ArkOS")"
    case "$r" in ok) bajados=$((bajados+1));; skip) saltados=$((saltados+1));; dry) bajados=$((bajados+1));; fail) fallos=$((fallos+1)); fallidos="$fallidos $c";; esac
done
for c in "${CORES_BUILDBOT[@]}"; do
    [ -n "$SOLO" ] && [ "$c" != "$SOLO" ] && continue
    r="$(descargar "$c" "$BUILDBOT_BASE" "buildbot")"
    case "$r" in ok) bajados=$((bajados+1));; skip) saltados=$((saltados+1));; dry) bajados=$((bajados+1));; fail) fallos=$((fallos+1)); fallidos="$fallidos $c";; esac
done
for c in "${CORES_EXTRAS[@]}"; do
    [ -n "$SOLO" ] && [ "$c" != "$SOLO" ] && continue
    r="$(descargar "$c" "$EXTRAS_BASE" "release del proyecto")"
    case "$r" in ok) bajados=$((bajados+1));; skip) saltados=$((saltados+1));; dry) bajados=$((bajados+1));; fail) fallos=$((fallos+1)); fallidos="$fallidos $c";; esac
done

if [ "$DRY" = 1 ]; then
    log "SIMULACION: $bajados por descargar | $saltados ya presentes | $fallos no disponibles"
else
    log "descargados: $bajados | ya presentes: $saltados | no disponibles: $fallos"
fi
[ -n "$fallidos" ] && warn "no se pudieron bajar:$fallidos"
[ -d "$CORES_DIR" ] && [ "$DRY" = 0 ] && chmod 644 "$CORES_DIR"/*.so 2>/dev/null
exit 0
