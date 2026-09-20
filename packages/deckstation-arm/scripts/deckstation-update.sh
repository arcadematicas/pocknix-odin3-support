#!/bin/bash
# deckstation-update.sh
# Actualiza emuladores de DeckStation a sus últimas versiones
# Siempre hace backup antes de actualizar

set -euo pipefail

# ============================================================================
# Configuración
# ============================================================================

DECKSTATION_ROOT="${DECKSTATION_ROOT:-/opt/deckstation}"
SCRIPTS_DIR="${DECKSTATION_ROOT}/scripts"
LOG_DIR="${DECKSTATION_ROOT}/logs"
APPS_DIR="${DECKSTATION_ROOT}/Apps"
BACKUP_DIR="${DECKSTATION_ROOT}/backups"

# Colores
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# ============================================================================
# Funciones auxiliares
# ============================================================================

log() {
    local msg="[$(date '+%Y-%m-%d %H:%M:%S')] $1"
    echo -e "${BLUE}${msg}${NC}"
    echo "$msg" >> "${LOG_DIR}/update.log" 2>/dev/null || true
}

log_ok() {
    local msg="[$(date '+%Y-%m-%d %H:%M:%S')] [OK] $1"
    echo -e "${GREEN}${msg}${NC}"
    echo "$msg" >> "${LOG_DIR}/update.log" 2>/dev/null || true
}

log_warn() {
    local msg="[$(date '+%Y-%m-%d %H:%M:%S')] [WARN] $1"
    echo -e "${YELLOW}${msg}${NC}"
    echo "$msg" >> "${LOG_DIR}/update.log" 2>/dev/null || true
}

log_error() {
    local msg="[$(date '+%Y-%m-%d %H:%M:%S')] [ERROR] $1"
    echo -e "${RED}${msg}${NC}"
    echo "$msg" >> "${LOG_DIR}/update.log" 2>/dev/null || true
}

# ============================================================================
# Backup
# ============================================================================

create_backup() {
    local component="$1"
    local source="${APPS_DIR}/${component}"
    local timestamp
    timestamp=$(date '+%Y%m%d_%H%M%S')
    local backup_name="${component}_${timestamp}"
    local backup_path="${BACKUP_DIR}/${backup_name}"

    if [[ ! -d "$source" ]]; then
        log_warn "No hay nada que respaldar para ${component}"
        return 0
    fi

    log "Creando backup de ${component}..."

    mkdir -p "$BACKUP_DIR"
    cp -a "$source" "$backup_path"

    log_ok "Backup creado: ${backup_path}"

    # Limpiar backups antiguos (mantener solo los últimos 3)
    cleanup_old_backups "$component"
}

cleanup_old_backups() {
    local component="$1"

    # Listar backups del componente ordenados por fecha
    local backups
    backups=$(ls -dt "${BACKUP_DIR}/${component}_"* 2>/dev/null || true)

    if [[ -z "$backups" ]]; then
        return 0
    fi

    local count=0
    while IFS= read -r backup; do
        ((count++))
        if [[ $count -gt 3 ]]; then
            log "Eliminando backup antiguo: $(basename "$backup")"
            rm -rf "$backup"
        fi
    done <<< "$backups"
}

# ============================================================================
# Actualización de componentes
# ============================================================================

update_retroarch() {
    local component="retroarch"
    local source="${APPS_DIR}/${component}"

    log "=== Actualizando RetroArch ==="

    if [[ ! -d "$source" ]]; then
        log_warn "RetroArch no instalado. Ejecuta deckstation-setup primero"
        return 0
    fi

    # Backup
    create_backup "$component"

    # Ejecutar setup con force
    if [[ -x "${SCRIPTS_DIR}/deckstation-setup.sh" ]]; then
        "${SCRIPTS_DIR}/deckstation-setup.sh" --force 2>&1 | tee -a "${LOG_DIR}/update.log"
    else
        log_error "Script de setup no encontrado"
        return 1
    fi

    log_ok "RetroArch actualizado"
}

update_cores() {
    local cores_dir="${APPS_DIR}/retroarch/cores"

    log "=== Actualizando cores de RetroArch ==="

    if [[ ! -d "$cores_dir" ]]; then
        log_warn "Directorio de cores no encontrado"
        return 0
    fi

    # Los cores se actualizan al ejecutar RetroArch
    log "Los cores se actualizarán al ejecutar RetroArch"
    log "O ejecuta: retroarch --menu -> Online Updater -> Core Updater"
}

update_configs() {
    log "=== Verificando configs ==="

    local configs_dir="${DECKSTATION_ROOT}/configs"

    # No sobrescribir configs del usuario
    # Solo crear defaults si no existen
    if [[ ! -f "${configs_dir}/retroarch.cfg" ]]; then
        log "Creando config por defecto de RetroArch..."
        # El config se creará al ejecutar RetroArch por primera vez
    fi

    log_ok "Configs verificadas"
}

# ============================================================================
# Main
# ============================================================================

main() {
    echo ""
    echo "=========================================="
    echo "  DeckStation - Actualización"
    echo "=========================================="
    echo ""

    # Parsear argumentos
    local force=false

    while [[ $# -gt 0 ]]; do
        case $1 in
            --force)
                force=true
                shift
                ;;
            --help|-h)
                echo "Uso: deckstation-update [--force]"
                echo ""
                echo "Opciones:"
                echo "  --force   Forzar actualización completa"
                echo "  --help    Mostrar esta ayuda"
                exit 0
                ;;
            *)
                log_error "Opción desconocida: $1"
                exit 1
                ;;
        esac
    done

    # Crear directorios necesarios
    mkdir -p "$LOG_DIR" "$BACKUP_DIR"

    log "Iniciando actualización..."
    log "Directorio: ${DECKSTATION_ROOT}"

    # Verificar que hay algo que actualizar
    if [[ ! -d "$APPS_DIR" ]] || [[ -z "$(ls -A "$APPS_DIR" 2>/dev/null)" ]]; then
        log_warn "No hay emuladores instalados"
        log "Ejecuta 'deckstation-setup' primero"
        exit 0
    fi

    # Actualizar cada componente
    echo ""
    update_retroarch
    echo ""
    update_cores
    echo ""
    update_configs

    # Resumen
    echo ""
    echo "=========================================="
    echo "  Actualización completada!"
    echo "=========================================="
    echo ""
    echo "Logs: ${LOG_DIR}/update.log"
    echo "Backups: ${BACKUP_DIR}/"
    echo ""
    echo "Para lanzar:"
    echo "  deckstation"
    echo ""
}

# Capturar errores
trap 'log_error "Error en línea $LINENO"; exit 1' ERR

# Ejecutar
main "$@"
