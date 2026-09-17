#!/bin/bash
# ======================================================================
# deckstation-setup.sh — Prepara DeckStation ARM
# ======================================================================
# Prepara el entorno portable de DeckStation:
#   1. Estructura de directorios
#   2. Assets de RetroArch (iconos del menu XMB, ~75 MB)
#   3. Cores del sistema -> carpeta portable (p. ej. suyu-libretro)
#   4. Wrappers lanzar.sh en cada emulador
#   5. Configs base + BIOS
#   6. Abre el Updater, que es quien instala/actualiza los emuladores
#      (AppImages) desde updater/git.txt.
#
# Uso: deckstation-setup [--force]
#   --force  Re-descarga tambien lo que ya existe (assets, etc.)
#
# NOTA: este script NO descarga emuladores por su cuenta. Antes lo intentaba
# y bajaba el APK de ANDROID de RetroArch (roto en Linux); ahora esa tarea es
# exclusiva del Updater, que es el que mantiene git.txt.
# ======================================================================

set -euo pipefail

# ============================================================================
# Configuración
# ============================================================================

DECKSTATION_ROOT="${DECKSTATION_ROOT:-/opt/deckstation}"
SCRIPTS_DIR="${DECKSTATION_ROOT}/scripts"
LOG_DIR="${DECKSTATION_ROOT}/logs"
APPS_DIR="${DECKSTATION_ROOT}/Apps"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

FORCE_DOWNLOAD=false

# ============================================================================
# Funciones auxiliares
# ============================================================================

log() {
    local msg="[$(date '+%Y-%m-%d %H:%M:%S')] $1"
    echo -e "${BLUE}${msg}${NC}"
    echo "$msg" >> "${LOG_DIR}/setup.log" 2>/dev/null || true
}

log_ok() {
    local msg="[$(date '+%Y-%m-%d %H:%M:%S')] [OK] $1"
    echo -e "${GREEN}${msg}${NC}"
    echo "$msg" >> "${LOG_DIR}/setup.log" 2>/dev/null || true
}

log_warn() {
    local msg="[$(date '+%Y-%m-%d %H:%M:%S')] [WARN] $1"
    echo -e "${YELLOW}${msg}${NC}"
    echo "$msg" >> "${LOG_DIR}/setup.log" 2>/dev/null || true
}

log_error() {
    local msg="[$(date '+%Y-%m-%d %H:%M:%S')] [ERROR] $1"
    echo -e "${RED}${msg}${NC}"
    echo "$msg" >> "${LOG_DIR}/setup.log" 2>/dev/null || true
}

check_dependencies() {
    log "Verificando dependencias..."
    local missing=()
    for cmd in curl unzip; do
        command -v "$cmd" &>/dev/null || missing+=("$cmd")
    done
    if [[ ${#missing[@]} -gt 0 ]]; then
        log_warn "Faltan dependencias: ${missing[*]}"
        if command -v pacman &>/dev/null; then
            sudo pacman -S --needed --noconfirm "${missing[@]}" || {
                log_error "No se pudieron instalar las dependencias"
                return 1
            }
        else
            log_error "Instala manualmente: ${missing[*]}"
            return 1
        fi
    fi
    log_ok "Dependencias verificadas"
}

ensure_directories() {
    log "Creando estructura de directorios..."
    local dirs=(
        "${APPS_DIR}"
        "${LOG_DIR}"
        "${DECKSTATION_ROOT}/saves"
        "${DECKSTATION_ROOT}/settings"
        "${DECKSTATION_ROOT}/Media"
    )
    for dir in "${dirs[@]}"; do
        mkdir -p "$dir"
    done
    log_ok "Directorios creados"
}

# Localiza el .home portable de una app (misma logica que scripts/lanzar.sh):
#   1) un *.home ya existente
#   2) <AppImage>.home
#   3) <subcarpeta>.AppImage.home (arboles extraidos, p.ej. RetroArch)
find_app_home() {
    local app="$1" dir home img sub base low
    dir="$(find "${APPS_DIR}" -maxdepth 1 -type d -iname "$app" 2>/dev/null | head -1)"
    [ -n "$dir" ] || return 1

    home="$(find "$dir" -maxdepth 3 -type d -name "*.home" 2>/dev/null | head -1)"
    [ -n "$home" ] && { printf '%s' "$home"; return 0; }

    img="$(find "$dir" -maxdepth 3 -type f \( -iname "*.AppImage" -o -iname "*.appimage" \) 2>/dev/null | head -1)"
    [ -n "$img" ] && { printf '%s' "${img}.home"; return 0; }

    for sub in "$dir"/*/; do
        [ -d "$sub" ] || continue
        base="$(basename "$sub")"
        low="$(printf '%s' "$base" | tr '[:upper:]' '[:lower:]')"
        case "$low" in
            app) continue ;;
            "$(printf '%s' "$app" | tr '[:upper:]' '[:lower:]')"*)
                printf '%s' "${sub%/}.AppImage.home"
                return 0
                ;;
        esac
    done
    return 1
}

# ============================================================================
# Entorno portable
# ============================================================================

# Assets de RetroArch: iconos del menu XMB (ozone/xmb/glui...). ~75 MB.
# Sin ellos, `menu_driver = "xmb"` se ve sin iconos.
setup_retroarch_assets() {
    local ra_home assets_dir url tmp
    ra_home="$(find_app_home retroarch)" || {
        log_warn "RetroArch no instalado todavia; se omiten los assets"
        return 0
    }
    assets_dir="${ra_home}/.config/retroarch/assets"

    if [ -d "${assets_dir}/xmb" ] && [ "$FORCE_DOWNLOAD" != true ]; then
        log_ok "Assets de RetroArch ya instalados"
        return 0
    fi

    url="https://buildbot.libretro.com/assets/frontend/assets.zip"
    tmp="${LOG_DIR}/assets.zip"
    log "Descargando assets de RetroArch (~75 MB, iconos del menu)..."
    if ! curl -L --progress-bar -o "$tmp" "$url"; then
        rm -f "$tmp"
        log_warn "No se pudieron descargar los assets: el menu XMB se vera sin iconos"
        return 0
    fi

    mkdir -p "$assets_dir"
    if unzip -q -o "$tmp" -d "$assets_dir"; then
        log_ok "Assets de RetroArch instalados"
    else
        log_warn "No se pudieron descomprimir los assets"
    fi
    rm -f "$tmp"
}

# Cores instalados como paquetes del sistema (p. ej. suyu-libretro) ->
# carpeta portable de cores, para que ES-DE/RetroArch los vean.
deploy_system_cores() {
    if [ -x "${SCRIPTS_DIR}/deckstation-cores.sh" ]; then
        log "Enlazando cores del sistema a la carpeta portable..."
        "${SCRIPTS_DIR}/deckstation-cores.sh" || log_warn "Fallo al enlazar los cores del sistema"
    fi
}

# Despliega el wrapper portable lanzar.sh a cada carpeta de emulador que contenga
# un AppImage. ES-DE (es_find_rules.xml) apunta a ./Apps/*/lanzar.sh en vez del
# AppImage directo, así que el wrapper debe existir para que el lanzamiento sea
# portable (HOME redirigido al .home, SDL fijado al compositor).
deploy_lanzar_sh() {
    local lanzar_src="${SCRIPTS_DIR}/lanzar.sh"
    local app_dir found

    [ -f "${lanzar_src}" ] || {
        log_warn "Plantilla lanzar.sh no encontrada (${lanzar_src}); se omite"
        return 0
    }

    log "Desplegando lanzar.sh a los emuladores..."
    for app_dir in "${APPS_DIR}"/*/; do
        [ -d "${app_dir}" ] || continue
        found="$(find "${app_dir}" -maxdepth 1 \( -iname "*.AppImage" -o -iname "*.appimage" \) 2>/dev/null | head -1)"
        [ -n "${found}" ] || continue
        install -m755 "${lanzar_src}" "${app_dir}lanzar.sh" 2>/dev/null \
            && log_ok "lanzar.sh -> $(basename "${app_dir}")" || true
    done
}

# Configs base + BIOS (no destructivos: solo rellenan lo que falte).
deploy_configs_and_bios() {
    if [ -x "${SCRIPTS_DIR}/deckstation-configs.sh" ]; then
        log "Desplegando configs base de DeckStation..."
        "${SCRIPTS_DIR}/deckstation-configs.sh" || log_warn "Fallo al desplegar los configs base"
    else
        log_warn "No encuentro ${SCRIPTS_DIR}/deckstation-configs.sh; se omiten los configs base"
    fi
    if [ -x "${SCRIPTS_DIR}/deckstation-bios.sh" ]; then
        log "Repartiendo BIOS del usuario (si hay)..."
        "${SCRIPTS_DIR}/deckstation-bios.sh" || log_warn "Fallo al repartir las BIOS"
    fi
}

# ============================================================================
# Emuladores (los instala el Updater)
# ============================================================================

install_emulators() {
    local launcher="${APPS_DIR}/Updater/launcher.sh"

    if [ ! -x "$launcher" ]; then
        log_warn "No encuentro el Updater (${launcher})"
        log "Instala los emuladores desde ES-DE -> Updater."
        return 0
    fi

    if [ -z "${DISPLAY:-}${WAYLAND_DISPLAY:-}" ]; then
        log "Los emuladores los instala el Updater."
        log "Abrelo desde ES-DE (o ejecuta ${launcher} en una sesion grafica)."
        return 0
    fi

    log "Abriendo el Updater para instalar/actualizar los emuladores..."
    "$launcher" || log_warn "El Updater termino con un error"
}

# ============================================================================
# Main
# ============================================================================

main() {
    echo ""
    echo "=========================================="
    echo "  DeckStation - Setup"
    echo "=========================================="
    echo ""

    while [[ $# -gt 0 ]]; do
        case $1 in
            --force)
                FORCE_DOWNLOAD=true
                shift
                ;;
            --help|-h)
                echo "Uso: deckstation-setup [--force]"
                echo ""
                echo "Prepara el entorno portable de DeckStation (assets, cores,"
                echo "lanzar.sh, configs y BIOS) y abre el Updater para instalar"
                echo "los emuladores."
                echo ""
                echo "Opciones:"
                echo "  --force   Re-descargar tambien lo que ya existe"
                echo "  --help    Mostrar esta ayuda"
                exit 0
                ;;
            *)
                log_error "Opción desconocida: $1"
                exit 1
                ;;
        esac
    done

    ensure_directories
    check_dependencies || exit 1

    echo ""
    log "Preparando el entorno portable..."
    echo ""

    setup_retroarch_assets
    deploy_system_cores
    deploy_lanzar_sh
    deploy_configs_and_bios

    echo ""
    log "Emuladores..."
    install_emulators

    echo ""
    echo "=========================================="
    echo "  Setup completado!"
    echo "=========================================="
    echo ""
    echo "Emuladores en: ${APPS_DIR}"
    echo "Logs en: ${LOG_DIR}/setup.log"
    echo ""
    echo "Para lanzar:"
    echo "  deckstation"
    echo ""
}

main "$@"
