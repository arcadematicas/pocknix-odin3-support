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
# Este script COPIA lo que haya en esas rutas estandar DENTRO de
# la carpeta portable, para que ES-DE/RetroArch los tengan EN DeckStation sin
# depender de rutas del sistema. Asi, cualquier core empaquetado queda dentro.
#
# No destructivo: solo copia los que falten y nunca pisa un core que
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
    log "RetroArch no instalado todavia; nada que copiar"
    exit 0
}
CORES_DIR="${RA_HOME}/.config/retroarch/cores"

if [ ! -d "$SYS_CORES" ] && [ ! -d "$SYS_INFO" ]; then
    log "No hay cores del sistema (${SYS_CORES}); nada que copiar"
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
        log "copiar $f -> $dst"
    else
        cp -f "$f" "$dst" || { warn "no se pudo copiar ${base}"; continue; }
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
        log "copiar $f -> $dst"
    else
        cp -f "$f" "$dst" || { warn "no se pudo copiar ${base}"; continue; }
    fi
    linked=$((linked + 1))
done

if [ "$DRY" = 1 ]; then
    log "SIMULACION: $linked por copiar | $skipped ya presentes"
else
    log "copiados: $linked | ya presentes: $skipped"
fi

# Si hemos copiado cores nuevos, invalidamos el cache de core_info.
#
# POR QUE: RetroArch cachea los .info de los cores en
#   <CORES_DIR>/core_info.cache
# y ese cache se escribe UNA vez. Si despues se anade un core (p. ej. al
# instalar un paquete como suyu-libretro, que pone el .so en
# /usr/lib/libretro y el .info en /usr/share/libretro/info), el cache NO
# se invalida solo y el core NUEVO NO APARECE en la lista de cores de
# RetroArch, aunque el .so y el .info esten ahi y ES-DE lo lance sin
# problema. Es exactamente lo que pasaba con Suyu.
#
# Por eso la config de RetroArch va con core_info_cache_enable="false"
# (ver configs/retroarch/retroarch.cfg); este rm es la red de seguridad
# para cuando el cache este disponible.
if [ "$DRY" = 0 ] && [ "$linked" -gt 0 ]; then
    for f in "$CORES_DIR/core_info.cache" "$CORES_DIR/core_info.cache.tmp"; do
        [ -e "$f" ] || continue
        rm -f "$f" 2>/dev/null || warn "no se pudo borrar $(basename "$f")"
    done
    log "cache de core_info invalidado (cores nuevos ya visibles en RetroArch)"
fi
