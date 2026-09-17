#!/bin/bash
# ======================================================================
# deckstation-cores.sh — Cores del sistema -> carpeta portable
# ======================================================================
# RetroArch de DeckStation es PORTABLE y busca los cores en su propio
# directorio:
#   <retroarch home>/.config/retroarch/cores/
#
# Los paquetes de Pocknix (p. ej. suyu-libretro) instalan los suyos en las
# rutas estandar del sistema:
#   /usr/lib/libretro/*.so
#   /usr/share/libretro/info/*.info
#
# Este script ENLAZA (symlink) lo que haya en esas rutas estandar dentro de
# la carpeta portable, para que ES-DE/RetroArch los vean sin copiarlos a
# mano. Asi, cualquier core que empaquetemos aparece solo.
#
# No destructivo: solo crea los enlaces que falten y nunca pisa un core que
# ya exista como fichero real en la carpeta portable.
#
# Uso: deckstation-cores.sh [--dry-run]
# Lo llaman deckstation-setup.sh y deckstation-launcher.sh.
# ======================================================================
set -u

SELF="$(readlink -f "${BASH_SOURCE[0]}")"
DECKSTATION_ROOT="${DECKSTATION_ROOT:-$(cd "$(dirname "$SELF")/.." && pwd)}"
APPS_DIR="${DECKSTATION_ROOT}/Apps"

SYS_CORES="/usr/lib/libretro"
SYS_INFO="/usr/share/libretro/info"

DRY=0
while [ $# -gt 0 ]; do
    case "$1" in
        --dry-run) DRY=1 ;;
        -h|--help) sed -n '2,22p' "$SELF"; exit 0 ;;
    esac
    shift
done

log()  { echo "  [cores] $*"; }
warn() { echo "  [cores] AVISO: $*" >&2; }

# Localiza el .home portable de RetroArch (misma logica que lanzar.sh).
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

RA_HOME="$(resolve_retroarch_home)" || {
    log "RetroArch no instalado todavia; nada que enlazar"
    exit 0
}
CORES_DIR="${RA_HOME}/.config/retroarch/cores"

if [ ! -d "$SYS_CORES" ] && [ ! -d "$SYS_INFO" ]; then
    log "No hay cores del sistema (${SYS_CORES}); nada que enlazar"
    exit 0
fi

[ "$DRY" = 1 ] || mkdir -p "$CORES_DIR"

linked=0
skipped=0
for f in "$SYS_CORES"/*.so; do
    [ -e "$f" ] || continue
    base="$(basename "$f")"
    dst="${CORES_DIR}/${base}"
    if [ -e "$dst" ]; then
        skipped=$((skipped + 1))
        continue
    fi
    if [ "$DRY" = 1 ]; then
        log "enlazar $f -> $dst"
    else
        ln -s "$f" "$dst" || { warn "no se pudo enlazar ${base}"; continue; }
    fi
    linked=$((linked + 1))
done

# Los .info van junto a los .so (es donde los busca RetroArch).
for f in "$SYS_INFO"/*.info; do
    [ -e "$f" ] || continue
    base="$(basename "$f")"
    dst="${CORES_DIR}/${base}"
    [ -e "$dst" ] && { skipped=$((skipped + 1)); continue; }
    if [ "$DRY" = 1 ]; then
        log "enlazar $f -> $dst"
    else
        ln -s "$f" "$dst" || { warn "no se pudo enlazar ${base}"; continue; }
    fi
    linked=$((linked + 1))
done

if [ "$DRY" = 1 ]; then
    log "SIMULACION: $linked por enlazar | $skipped ya presentes"
else
    log "enlazados: $linked | ya presentes: $skipped"
fi
