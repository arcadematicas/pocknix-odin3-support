#!/bin/bash
# ======================================================================
# deckstation-cores-loose.sh — Cores SUELTOS del buildbot (aarch64)
# ======================================================================
# RetroArch de DeckStation usa su PROPIA carpeta de cores:
#   <retroarch home>/.config/retroarch/cores/
# El "pack" del sistema (paquete libretro-cores-pocknix) instala en
#   /usr/lib/libretro/*.so  y se copia ahi con deckstation-cores.sh.
#
# Pero hay cores que el pack NO trae (p. ej. rpcs3, xenia_edge, vita3k...)
# y que el buildbot oficial de libretro SI publica para aarch64. Este script
# los descarga DIRECTAMENTE a la carpeta portable de RetroArch.
#
# REGLA DE ORO: NUNCA pisa un core del pack. Si un core ya existe en
# /usr/lib/libretro, se marca como `pack` y NO se descarga (el del pack va
# PARCHEADO/compilado por el proyecto; sustituirlo por el del buildbot, como
# hace el "Online Updater" de RetroArch, rompe esos parches). El script lo
# avisa y sugiere la opcion del pack.
#
# El buildbot sirve "lo de hoy" (no esta pinnado): son cores sin nuestros
# parches. Sirven para lo que el pack no cubre, no para reemplazarlo.
#
# Uso:
#   deckstation-cores-loose.sh --list           inventario (TAB: nombre<TAB>estado)
#   deckstation-cores-loose.sh --install <core> baja ese core a la carpeta portable
#   deckstation-cores-loose.sh --install-all     baja todos los sueltos que falten
#   deckstation-cores-loose.sh --refresh         (solo --list revalida el indice)
#   --dry-run   no descarga nada, solo dice que haria
#
# Estados (columna 2 del --list):
#   pack       ya viene del pack (/usr/lib/libretro); NO se descarga
#   installed  ya esta en la carpeta portable de RetroArch
#   free       disponible para descargar a la carpeta portable
#
# Variables:
#   DECKSTATION_BUILDBOT_BASE  base del buildbot (por defecto aarch64/latest)
#   DECKSTATION_INFO_BASE      .info de libretro-super
# ======================================================================
set -u

SELF="$(readlink -f "${BASH_SOURCE[0]}")"
DECKSTATION_ROOT="${DECKSTATION_ROOT:-$(cd "$(dirname "$SELF")/.." && pwd)}"
APPS_DIR="${DECKSTATION_ROOT}/Apps"

SYS_CORES="/usr/lib/libretro"
BUILDBOT_BASE="${DECKSTATION_BUILDBOT_BASE:-https://buildbot.libretro.com/nightly/linux/aarch64/latest}"
INFO_BASE="${DECKSTATION_INFO_BASE:-https://raw.githubusercontent.com/libretro/libretro-super/master/dist/info}"

DRY=0
ACCION="list"
CORE=""
while [ $# -gt 0 ]; do
    case "$1" in
        --list)        ACCION="list" ;;
        --install)     shift; ACCION="install"; CORE="${1:-}" ;;
        --install-all) ACCION="install-all" ;;
        --refresh)     : ;;   # compatibilidad: el indice se pide siempre al listar
        --dry-run)     DRY=1 ;;
        -h|--help)     sed -n '2,45p' "$SELF"; exit 0 ;;
    esac
    shift
done

# Las trazas van a STDERR: asi stdout queda limpio para el estado (ok/skip/
# dry/pack/fail) que consume `--install-all` y para el inventario de `--list`.
log()  { echo "  [cores-loose] $*" >&2; }
warn() { echo "  [cores-loose] AVISO: $*" >&2; }

# --- Localiza el .home portable de RetroArch (igual que deckstation-cores.sh) ---
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

RA_HOME="$(resolve_retroarch_home)" || RA_HOME=""
if [ -n "$RA_HOME" ]; then
    CORES_DIR="${RA_HOME}/.config/retroarch/cores"
else
    CORES_DIR=""
fi

command -v curl  >/dev/null 2>&1 || { warn "falta curl"; exit 1; }
command -v unzip >/dev/null 2>&1 || { warn "falta unzip"; exit 1; }

# --- Indice de cores del buildbot (h5ai: tabla de respaldo en el HTML) ----------
_listar_buildbot() {
    curl -fsSL --retry 2 --connect-timeout 20 "${BUILDBOT_BASE}/" 2>/dev/null \
        | grep -oE 'href="[^"]+_libretro\.so\.zip"' \
        | sed -E 's#.*/([^/"]+)_libretro\.so\.zip"#\1#' \
        | sort -u
}

# --- Estado de un core ---------------------------------------------------------
# pack | installed | free
_estado() {  # _estado <name>
    local name="$1"
    if [ -e "${SYS_CORES}/${name}_libretro.so" ]; then
        echo "pack"; return
    fi
    if [ -n "$CORES_DIR" ] && [ -e "${CORES_DIR}/${name}_libretro.so" ]; then
        echo "installed"; return
    fi
    echo "free"
}

# --- Descarga un core suelto a la carpeta portable -----------------------------
_descargar() {  # _descargar <name>   -> ok|skip|fail|pack|dry
    local name="$1"
    local estado; estado="$(_estado "$name")"
    case "$estado" in
        pack)      echo "pack"; return 2 ;;
        installed) echo "skip"; return 0 ;;
    esac
    if [ -z "$CORES_DIR" ]; then
        warn "RetroArch no esta instalado; no hay carpeta de cores"
        echo "fail"; return 1
    fi
    if [ "$DRY" = 1 ]; then
        log "DESCARGARIA ${name} (buildbot aarch64)"
        echo "dry"; return 0
    fi
    mkdir -p "$CORES_DIR"
    local dst="${CORES_DIR}/${name}_libretro.so"
    local tmp; tmp="$(mktemp -d)"
    local ok=0
    log "descargando ${name}..."
    if curl -fsSL --retry 2 --connect-timeout 20 -o "${tmp}/${name}.zip" \
         "${BUILDBOT_BASE}/${name}_libretro.so.zip" 2>/dev/null \
       && unzip -o -q "${tmp}/${name}.zip" -d "$CORES_DIR/" 2>/dev/null \
       && [ -e "$dst" ]; then
        ok=1
    fi
    if [ "$ok" = 1 ]; then
        chmod 644 "$dst" 2>/dev/null
        # .info (nombre del core y opciones en RetroArch), si falta
        [ -e "${CORES_DIR}/${name}_libretro.info" ] || \
            curl -fsSL --connect-timeout 20 -o "${CORES_DIR}/${name}_libretro.info" \
                 "${INFO_BASE}/${name}_libretro.info" 2>/dev/null
        rm -rf "$tmp"
        echo "ok"; return 0
    fi
    rm -rf "$tmp"
    rm -f "$dst" 2>/dev/null
    warn "no se pudo descargar ${name}"
    echo "fail"; return 1
}

# --- Invalidar el cache de core_info (igual que deckstation-cores.sh) -----------
_invalidar_cache() {
    [ -n "$CORES_DIR" ] || return 0
    local f
    for f in "$CORES_DIR/core_info.cache" "$CORES_DIR/core_info.cache.tmp"; do
        [ -e "$f" ] || continue
        rm -f "$f" 2>/dev/null || true
    done
}

# ============================== ACCIONES ======================================

case "$ACCION" in
    list)
        CORES="$(_listar_buildbot)"
        if [ -z "$CORES" ]; then
            warn "no se pudo obtener el indice del buildbot (${BUILDBOT_BASE})"
            exit 1
        fi
        n_pack=0; n_inst=0; n_free=0
        while IFS= read -r name; do
            [ -n "$name" ] || continue
            st="$(_estado "$name")"
            case "$st" in
                pack)      n_pack=$((n_pack+1)) ;;
                installed) n_inst=$((n_inst+1)) ;;
                free)      n_free=$((n_free+1)) ;;
            esac
            printf '%s\t%s\n' "$name" "$st"
        done <<< "$CORES"
        # Resumen en la ultima linea, comentada (la GUI lee las lineas con TAB).
        printf '# buildbot=%s pack=%s installed=%s free=%s\n' \
            "$(printf '%s\n' "$CORES" | grep -c .)" "$n_pack" "$n_inst" "$n_free"
        ;;

    install)
        [ -n "$CORE" ] || { warn "falta el nombre del core"; exit 1; }
        estado="$(_estado "$CORE")"
        if [ "$estado" = "pack" ]; then
            warn "${CORE} YA viene del pack (${SYS_CORES}/${CORE}_libretro.so)."
            warn "No se toca: el del pack va parcheado. Usa la opcion del pack."
            exit 3
        fi
        if [ "$estado" = "installed" ]; then
            log "${CORE} ya esta instalado en la carpeta portable"
            exit 0
        fi
        _descargar "$CORE" >/dev/null    # trazas y estado a consola por separado
        rc=$?
        if [ "$rc" = 0 ]; then
            if [ "$DRY" = 1 ]; then
                log "${CORE}: se descargaria (simulacion)"
            else
                _invalidar_cache
                log "${CORE} instalado"
            fi
        fi
        exit "$rc"
        ;;

    install-all)
        CORES="$(_listar_buildbot)"
        [ -n "$CORES" ] || { warn "no se pudo obtener el indice del buildbot"; exit 1; }
        bajados=0; saltados=0; fallos=0; propios_pack=0; fallidos=""
        while IFS= read -r name; do
            [ -n "$name" ] || continue
            r="$(_descargar "$name")"
            case "$r" in
                ok)    bajados=$((bajados+1)) ;;
                skip)  saltados=$((saltados+1)) ;;
                dry)   bajados=$((bajados+1)) ;;
                pack)  propios_pack=$((propios_pack+1)) ;;
                fail)  fallos=$((fallos+1)); fallidos="$fallidos $name" ;;
            esac
        done <<< "$CORES"
        [ "$bajados" -gt 0 ] && [ "$DRY" = 0 ] && _invalidar_cache
        if [ "$DRY" = 1 ]; then
            log "SIMULACION: $bajados por descargar | $saltados ya presentes | $propios_pack del pack (intocables)"
        else
            log "descargados: $bajados | ya presentes: $saltados | del pack (no tocados): $propios_pack | fallos: $fallos"
        fi
        [ -n "$fallidos" ] && warn "no se pudieron bajar:$fallidos"
        exit 0
        ;;
esac
