#!/bin/bash
# ======================================================================
# deckstation-configs.sh — Despliegue de ficheros base de DeckStation
# ======================================================================
# Aplica un manifiesto que mapea ficheros de una carpeta de origen a los
# destinos reales dentro de DeckStation (los .AppImage.home de cada
# emulador). Se usa para dos cosas:
#
#   - configs/  -> la configuracion "de fabrica" (por defecto)
#   - bios/     -> las BIOS del usuario (deckstation-bios.sh)
#
# NO es destructivo: por defecto solo copia lo que FALTA (respeta lo que
# el usuario haya cambiado). Con --force resetea a los valores de origen.
#
# Uso:
#   deckstation-configs.sh [--force] [--dry-run]
#                          [--from DIR] [--manifest FILE]
#
# Lo llama deckstation-setup.sh (tras instalar emuladores) y el launcher
# (auto-reparacion barata: si ya esta todo, no hace nada).
# ======================================================================
set -u

SELF="$(readlink -f "${BASH_SOURCE[0]}")"
DECKSTATION_ROOT="${DECKSTATION_ROOT:-$(cd "$(dirname "$SELF")/.." && pwd)}"
SRC_DIR="${DECKSTATION_ROOT}/configs"
MANIFEST="${SRC_DIR}/deploy-manifest.txt"
APPS_DIR="${DECKSTATION_ROOT}/Apps"

FORCE=0
DRY=0
LABEL="configs"
while [ $# -gt 0 ]; do
    case "$1" in
        --force)    FORCE=1 ;;
        --dry-run)  DRY=1 ;;
        --from)     SRC_DIR="$2"; MANIFEST="$2/deploy-manifest.txt"; shift ;;
        --manifest) MANIFEST="$2"; shift ;;
        --label)    LABEL="$2"; shift ;;
        -h|--help)  sed -n '2,20p' "$SELF"; exit 0 ;;
        *)          echo "Opcion desconocida: $1" >&2; exit 1 ;;
    esac
    shift
done

log()  { echo "  [$LABEL] $*"; }
warn() { echo "  [$LABEL] AVISO: $*" >&2; }
trim() { local s="$1"; s="${s#"${s%%[![:space:]]*}"}"; s="${s%"${s##*[![:space:]]}"}"; printf '%s' "$s"; }

deployed=0
skipped=0
nodest=0

# Resuelve el nombre de app a su directorio *.home (case-insensitive).
# Misma logica que scripts/lanzar.sh, que es quien luego exporta HOME ahi.
#   1) un *.home ya existente
#   2) <AppImage>.home derivado del AppImage
#   3) <subcarpeta>.AppImage.home (arboles extraidos, p.ej. RetroArch)
# Devuelve la ruta por stdout, o falla si no hay forma de determinarla.
resolve_home() {
    local app="$1" dir home img sub
    dir="$(find "$APPS_DIR" -maxdepth 1 -type d -iname "$app" 2>/dev/null | head -1)"
    [ -n "$dir" ] || return 1

    home="$(find "$dir" -maxdepth 3 -type d -name "*.home" 2>/dev/null | head -1)"
    if [ -n "$home" ]; then
        printf '%s' "$home"
        return 0
    fi

    img="$(find "$dir" -maxdepth 3 -type f \( -iname "*.AppImage" -o -iname "*.appimage" \) 2>/dev/null | head -1)"
    if [ -n "$img" ]; then
        printf '%s' "${img}.home"
        return 0
    fi

    # Arboles extraidos (p.ej. RetroArch -> RetroArch-Linux-aarch64): solo
    # aceptamos subcarpetas cuyo nombre empiece por el de la app, para no
    # confundirnos con subcarpetas de datos (Vita3K/data, etc.).
    local base low
    for sub in "$dir"/*/; do
        [ -d "$sub" ] || continue
        base="$(basename "$sub")"
        low="$(printf '%s' "$base" | tr '[:upper:]' '[:lower:]')"
        [ "$low" = "app" ] && continue
        case "$low" in
            "${app,,}"*)
                printf '%s' "${sub%/}.AppImage.home"
                return 0
                ;;
        esac
    done

    return 1
}

# Copia un fichero o el contenido de un directorio.
# $1 origen  $2 destino  $3 politica
copy_one() {
    local src="$1" dst="$2" policy="$3"

    if [ ! -e "$src" ]; then
        warn "origen inexistente, se omite: $src"
        nodest=$((nodest + 1))
        return
    fi

    if [ -d "$src" ]; then
        if [ "$FORCE" = 1 ]; then
            if [ "$DRY" = 1 ]; then
                log "force dir  $src -> $dst"
            else
                mkdir -p "$dst" && cp -a "$src"/. "$dst"/
            fi
            deployed=$((deployed + 1))
            return
        fi
        [ "$DRY" = 1 ] || mkdir -p "$dst"
        local f rel copied=0
        while IFS= read -r -d '' f; do
            rel="${f#"$src"/}"
            if [ ! -e "$dst/$rel" ]; then
                if [ "$DRY" != 1 ]; then
                    mkdir -p "$(dirname "$dst/$rel")"
                    cp -a "$f" "$dst/$rel"
                fi
                copied=1
            fi
        done < <(find "$src" -type f -print0 2>/dev/null)
        if [ "$copied" = 1 ]; then
            log "dir   $src -> $dst"
            deployed=$((deployed + 1))
        else
            skipped=$((skipped + 1))
        fi
        return
    fi

    if [ -e "$dst" ] && [ "$FORCE" != 1 ] && [ "$policy" != "force" ]; then
        skipped=$((skipped + 1))
        return
    fi

    if [ "$DRY" = 1 ]; then
        log "file  $src -> $dst"
        deployed=$((deployed + 1))
        return
    fi
    if mkdir -p "$(dirname "$dst")" && cp -a "$src" "$dst" 2>/dev/null; then
        deployed=$((deployed + 1))
    else
        warn "no se pudo copiar $src -> $dst"
        nodest=$((nodest + 1))
    fi
}

if [ ! -f "$MANIFEST" ]; then
    warn "no encuentro el manifiesto: $MANIFEST"
    exit 1
fi

while IFS='|' read -r src dst policy || [ -n "${src:-}" ]; do
    src="$(trim "${src:-}")"
    case "$src" in ''|\#*) continue ;; esac
    dst="$(trim "${dst:-}")"
    policy="$(trim "${policy:-keep}")"
    [ -n "$policy" ] || policy="keep"

    # Resolver {HOME:NombreApp} -> ruta absoluta del .AppImage.home
    case "$dst" in
        '{HOME:'*)
            rest="${dst#\{HOME:}"
            app="${rest%%\}*}"
            rest="${rest#*\}}"
            home="$(resolve_home "$app")" || {
                warn "$app no instalado; se omite $src"
                nodest=$((nodest + 1))
                continue
            }
            target="${home}${rest}"
            ;;
        /*) target="$dst" ;;
        *)  target="$DECKSTATION_ROOT/$dst" ;;
    esac

    copy_one "$SRC_DIR/$src" "$target" "$policy"
done < "$MANIFEST"

if [ "$DRY" = 1 ]; then
    log "SIMULACION (dry-run): $deployed por desplegar | $skipped ya presentes | $nodest sin destino"
else
    log "desplegados: $deployed | ya presentes: $skipped | sin destino: $nodest"
fi
