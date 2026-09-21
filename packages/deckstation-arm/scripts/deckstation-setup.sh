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
    # Lo que el setup Y el Updater necesitan de verdad. El Updater es pygame y
    # extrae con 7z: sin ellos la instalacion de emuladores falla (antes solo se
    # comprobaban curl y unzip, asi que en un sistema limpio todo parecia bien
    # hasta que el Updater no arrancaba o no extraia nada).
    local missing=()
    for cmd in curl unzip 7z python3; do
        command -v "$cmd" &>/dev/null || missing+=("$cmd")
    done
    # python-requests / pygame no son comandos: se comprueban como modulos.
    python3 -c "import requests" 2>/dev/null || missing+=("python-requests")
    python3 -c "import pygame"   2>/dev/null || missing+=("python-pygame")
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
    local ra_home assets_dir tmp

    ra_home="$(find_app_home retroarch)" || {
        log_warn "RetroArch no instalado todavia; se omiten los assets"
        return 0
    }
    assets_dir="${ra_home}/.config/retroarch"

    # Todo lo que se baja del buildbot para que RetroArch quede COMPLETO de una
    # vez, sin que el usuario tenga que ir al menu de descargas. Cada pack se
    # comprueba por separado y, si uno falla, los demas siguen.
    #
    #   assets    iconos del menu (sin esto el XMB sale SIN ICONOS)
    #   info      ficha de cada core (el menu la muestra)
    #   database  base de datos para el escaneo de ROMs
    #   cheats    trucos
    #   overlays  marcos/teclados en pantalla del pack oficial
    #
    # NO se baja nada de la categoria "cores": los del buildbot son x86_64 y en la
    # Odin no sirven. Los cores aarch64 los pone el sistema.
    local packs="assets info database-rdb database-cursors cheats overlays"
    local base="https://buildbot.libretro.com/assets/frontend"
    local bajados=0 fallos=0 pack url destino

    log "Preparando RetroArch (assets e datos oficiales, ~180 MB)..."

    for pack in $packs; do
        # El nombre del zip no siempre coincide con la carpeta de destino.
        case "$pack" in
            database-rdb)     destino="${assets_dir}/database/rdb" ;;
            database-cursors) destino="${assets_dir}/database/cursors" ;;
            *)                destino="${assets_dir}/${pack}" ;;
        esac

        if [ -d "$destino" ] && [ "$FORCE_DOWNLOAD" != true ]; then
            continue
        fi

        url="${base}/${pack}.zip"
        tmp="${LOG_DIR}/${pack}.zip"
        rm -f "$tmp" 2>/dev/null
        if ! curl -fL --retry 2 --connect-timeout 20 -s -o "$tmp" "$url"; then
            log_warn "No se pudo descargar ${pack}; RetroArch funcionara sin el"
            fallos=$((fallos + 1))
            rm -f "$tmp" 2>/dev/null
            continue
        fi
        mkdir -p "$destino"
        # OJO con el codigo de salida de unzip: 0 = bien, 1 = AVISOS, 2+ = error.
        # Los avisos son normales aqui (los .cht llevan nombres con acentos y
        # japones y el zip mezcla codificaciones: "mismatching local filename"),
        # pero descomprime todo perfectamente. Si solo se aceptara el 0, se
        # reportaria un fallo inexistente.
        unzip -qo "$tmp" -d "$destino" 2>/dev/null
        rc=$?
        if [ "$rc" -le 1 ]; then
            bajados=$((bajados + 1))
        else
            log_warn "No se pudo descomprimir ${pack} (codigo ${rc})"
            fallos=$((fallos + 1))
        fi
        rm -f "$tmp" 2>/dev/null
    done

    if [ "$bajados" -gt 0 ]; then
        log_ok "RetroArch preparado (${bajados} paquete(s) descargado(s))"
    fi
    [ "$fallos" -gt 0 ] && log_warn "${fallos} paquete(s) fallaron; se puede reintentar reejecutando el setup"
    return 0
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
    local helper="${SCRIPTS_DIR}/deploy-lanzar-sh.sh"

    # La logica vive en deploy-lanzar-sh.sh porque la necesitan tambien el
    # launcher (auto-reparacion) y el Updater (tras instalar un emulador).
    if [ ! -x "$helper" ]; then
        log_warn "No encuentro ${helper}; se omite el despliegue de lanzar.sh"
        return 0
    fi

    log "Desplegando lanzar.sh a los emuladores..."
    DECKSTATION_ROOT="$DECKSTATION_ROOT" "$helper" | while read -r linea; do
        log_ok "${linea#  }"
    done
}

# Configs base + BIOS (no destructivos: solo rellenan lo que falte).
# ----------------------------------------------------------------------
# libXss: RetroArch en DeckStation NO es un AppImage, es el binario nativo del
# buildbot, y enlaza contra libXss.so.1. Hay hosts (imagenes minimalistas) que
# no traen el paquete libxss -> "error while loading shared libraries:
# libXss.so.1" y ES-DE no lanza NINGUN emulador de RetroArch.
#
# Se provisiona en <root>/lib (que lanzar.sh ya mete en el LD_LIBRARY_PATH)
# desde el paquete oficial de ALARM, sin exigir que el host lo tenga ni
# ensuciar /usr/lib. Si el host ya lo tiene, no se hace nada.
# ----------------------------------------------------------------------
# ES-DE (el front-end) — se baja de la fuente OFICIAL, no de un build sin publicar.
#
# DeckStation ES el AppImage oficial de ES-DE renombrado: el
# `DeckStation.AppImage` que traia el proyecto es **byte a byte identico** al
# `ES-DE_aarch64.AppImage` de la release 3.4.1 de ES-DE (mismo md5
# 9e459692ebd86dc5f0524f4c2bbad3b3). ES-DE empezo a publicar ARM64 justo en la
# 3.4.1, y por eso antes no habia de donde bajarlo.
#
# Bajarlo de la fuente oficial evita depender de un binario que no esta publicado
# en ningun sitio (el repo de DeckStation no tiene releases): sin este paso, una
# instalacion limpia se queda SIN front-end y `deckstation` no arranca.
ESDE_VERSION="${ESDE_VERSION:-3.4.1}"
ESDE_URL="${ESDE_URL:-https://gitlab.com/es-de/emulationstation-de/-/package_files/326321114/download}"
ESDE_MD5="${ESDE_MD5:-9e459692ebd86dc5f0524f4c2bbad3b3}"

setup_esde() {
    local destino="${DECKSTATION_ROOT}/DeckStation.AppImage"
    local tmp="${DECKSTATION_ROOT}/.DeckStation.AppImage.part"

    if [ -x "$destino" ]; then
        log_ok "ES-DE ya esta instalado"
        return 0
    fi

    log "Descargando ES-DE ${ESDE_VERSION} (AppImage oficial ARM64, ~127 MB)..."
    rm -f "$tmp" 2>/dev/null
    if ! curl -fL --retry 3 --connect-timeout 20 -o "$tmp" "$ESDE_URL"; then
        log_error "No se pudo descargar ES-DE. Sin el, 'deckstation' no arranca."
        rm -f "$tmp" 2>/dev/null
        return 1
    fi

    # Comprobar que es el fichero correcto antes de dejarlo en su sitio
    local md5_real
    md5_real="$(md5sum "$tmp" 2>/dev/null | cut -d" " -f1)"
    if [ -n "$ESDE_MD5" ] && [ "$md5_real" != "$ESDE_MD5" ]; then
        log_error "El AppImage descargado no coincide (md5 ${md5_real:-?}). Se descarta."
        rm -f "$tmp" 2>/dev/null
        return 1
    fi

    chmod 755 "$tmp" 2>/dev/null
    mv -f "$tmp" "$destino" 2>/dev/null || {
        log_error "No se pudo colocar ES-DE en ${destino}"
        return 1
    }
    log_ok "ES-DE ${ESDE_VERSION} instalado (md5 verificado)"
}

setup_libxss() {
    local lib_dir="${DECKSTATION_ROOT}/lib"
    local arch pkg base url tmp

    if [ -e /usr/lib/libXss.so.1 ] || [ -e "${lib_dir}/libXss.so.1" ]; then
        log_ok "libXss disponible"
        return 0
    fi

    case "$(uname -m)" in
        aarch64) arch="aarch64" ;;
        armv7l)  arch="armv7h" ;;
        *) log_warn "libXss: sin paquete para $(uname -m); se omite"; return 0 ;;
    esac

    # Version pinneada (la que usa ALARM extra). Si upstream la sube, el
    # fallback de lanzar.sh (runtime de Steam) sigue cubriendo el caso.
    pkg="libxss-1.2.5-1-${arch}.pkg.tar.xz"
    base="http://mirror.archlinuxarm.org/${arch}/extra"
    url="${base}/${pkg}"
    tmp="${LOG_DIR}/${pkg}"

    log "libXss no esta en el sistema; provisionando en ${lib_dir}..."
    if ! curl -L --progress-bar -o "$tmp" "$url"; then
        rm -f "$tmp"
        log_warn "No se pudo descargar libXss; RetroArch podria no arrancar"
        return 0
    fi

    mkdir -p "$lib_dir"
    if tar -xJf "$tmp" -C "$lib_dir" --strip-components=2 usr/lib/libXss.so.1.0.0 2>/dev/null; then
        ln -sf libXss.so.1.0.0 "${lib_dir}/libXss.so.1" 2>/dev/null || true
        log_ok "libXss provisionada en ${lib_dir}"
    else
        log_warn "No se pudo extraer libXss del paquete"
    fi
    rm -f "$tmp"
}

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
    local updater="${APPS_DIR}/Updater/updater.py"

    if [ ! -f "$updater" ]; then
        log_warn "No encuentro el Updater (${updater})"
        log "Instala los emuladores desde ES-DE -> Updater."
        return 0
    fi

    # INSTALACION INICIAL COMPLETA: los 30 emuladores de git.txt, en modo
    # headless (no necesita escritorio, asi que funciona tambien por SSH).
    # El Updater GRAFICO queda para GESTIONAR despues: actualizar o anadir
    # emuladores sueltos desde ES-DE. Mismo motor en ambos casos, para que no
    # haya dos logicas de descarga que puedan separarse.
    log "Instalando los emuladores (son ~1,5 GB; puede tardar)..."
    echo ""
    if python3 "$updater" --install-all; then
        log_ok "Emuladores instalados"
    else
        log_warn "Algun emulador fallo; se puede reintentar desde el Updater"
    fi
    echo ""
    log "Para gestionar/actualizar despues: ES-DE -> Updater"
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
    setup_libxss
    deploy_system_cores
    deploy_lanzar_sh
    deploy_configs_and_bios

    echo ""
    setup_esde || log_warn "Sigue sin ES-DE: 'deckstation' no arrancara hasta tenerlo"

    echo ""
    log "Emuladores..."
    install_emulators

    # install_emulators ESPERA a que el Updater cierre, y es el Updater quien
    # descarga los emuladores: los que acaban de instalarse no existian cuando
    # se desplego lanzar.sh mas arriba. Sin esta segunda pasada se quedaban sin
    # wrapper y sin configs, y ES-DE (que apunta a Apps/<Emu>/lanzar.sh) no
    # podia lanzarlos.
    echo ""
    log "Aplicando lanzar.sh y configs a los emuladores recien instalados..."
    deploy_lanzar_sh
    deploy_configs_and_bios

    # Los ASSETS de RetroArch se descargaban al principio, cuando RetroArch aun
    # no estaba instalado -> "[WARN] RetroArch no instalado todavia; se omiten los
    # assets" y el menu XMB salia SIN ICONOS. Es el mismo problema de orden que
    # lanzar.sh y las configs: el setup prepara el entorno ANTES de que el Updater
    # descargue nada. Se repite aqui, ya con RetroArch en su sitio.
    setup_retroarch_assets

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
