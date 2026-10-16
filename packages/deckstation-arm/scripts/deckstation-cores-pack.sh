#!/bin/bash
# ======================================================================
# deckstation-cores-pack.sh — PACK de cores: paquete del sistema -> portable
# ======================================================================
# El "pack" de cores de Pocknix es el PAQUETE `libretro-cores-pocknix`
# (cores aarch64 vendored/compilados por el proyecto: ArkOS set + buildbot
# + extras propios como azahar, bsnes-hd, vboycolor...). Instala en la ruta
# estandar:
#   /usr/lib/libretro/*.so
#
# El RetroArch de DeckStation es PORTABLE y NO mira esa ruta: busca en su
# propia carpeta. Asi que despues de instalar/actualizar el paquete hay que
# COPIARLOS con deckstation-cores.sh (el "puente" no destructivo).
#
# Este script es el MOTOR de la opcion "Cores de RetroArch (ARM)" del
# Updater. Hace las dos cosas y se puede llamar tambien SIN escritorio
# (desde Pocknix Tools o una terminal):
#
#   1) pacman -Sy --needed --noconfirm <paquete>   (solo pide root aqui)
#   2) deckstation-cores.sh                        (copia no destructiva)
#
# NO usa infraestructura nueva: el pack sale del repositorio pacman de
# Pocknix. Si el paquete no esta en el repositorio, lo dice y sale; no
# inventa fuentes.
#
# Uso: deckstation-cores-pack.sh [--dry-run] [--no-bridge]
#   --dry-run    no toca nada: solo dice que haria
#   --no-bridge  actualiza el paquete pero NO llama al puente (cores.sh)
#
# Variables:
#   DECKSTATION_CORES_PKG   paquete del pack (por defecto libretro-cores-pocknix)
#   DECKSTATION_SUDO        comando para root (por defecto: pkexec si hay
#                           entorno grafico, si no sudo). Ej: "sudo -n".
# ======================================================================
set -u

SELF="$(readlink -f "${BASH_SOURCE[0]}")"
DECKSTATION_ROOT="${DECKSTATION_ROOT:-$(cd "$(dirname "$SELF")/.." && pwd)}"
SCRIPTS_DIR="${DECKSTATION_ROOT}/scripts"

CORES_PKG="${DECKSTATION_CORES_PKG:-libretro-cores-pocknix}"

DRY=0
BRIDGE=1
while [ $# -gt 0 ]; do
    case "$1" in
        --dry-run)   DRY=1 ;;
        --no-bridge) BRIDGE=0 ;;
        -h|--help)   sed -n '2,35p' "$SELF"; exit 0 ;;
    esac
    shift
done

log()  { echo "  [cores-pack] $*"; }
warn() { echo "  [cores-pack] AVISO: $*" >&2; }

# --- Quien eleva a root --------------------------------------------------------
# pacman necesita root. En la Odin el usuario es `deck` (sudo con password).
# Desde la GUI (ES-DE/gamescope) preferimos pkexec: abre el dialogo de polkit
# sin necesidad de terminal. En consola/headless, sudo.
# Se puede forzar con DECKSTATION_SUDO (p. ej. "sudo -n" para no preguntar).
elevar() {
    local cmd
    if [ "$(id -u)" = 0 ]; then
        "$@"
        return $?
    fi
    if [ -n "${DECKSTATION_SUDO:-}" ]; then
        # shellcheck disable=SC2086
        $DECKSTATION_SUDO "$@"
        return $?
    fi
    if [ -n "${DISPLAY:-}${WAYLAND_DISPLAY:-}" ] && command -v pkexec >/dev/null 2>&1; then
        cmd="pkexec"
    elif command -v sudo >/dev/null 2>&1; then
        cmd="sudo"
    elif command -v pkexec >/dev/null 2>&1; then
        cmd="pkexec"
    else
        warn "no hay pkexec ni sudo: no puedo elevar a root para usar pacman"
        return 1
    fi
    "$cmd" "$@"
}

if ! command -v pacman >/dev/null 2>&1; then
    warn "no hay pacman en este sistema; el pack solo aplica a Pocknix/Arch"
    exit 1
fi

# --- 1) Instalar / actualizar el paquete del pack ------------------------------
# pacman -Sy --needed: refresca la base de datos e instala SOLO si falta o si
# hay version nueva (si ya esta al dia, no hace nada). NO se usa -Syu: subir
# todo el sistema sobre la base congelada de Pocknix es un landmine (ver
# AGENTS.md). El repo que sirve el paquete es el de Pocknix.
if [ "$DRY" = 1 ]; then
    log "SIMULACION: pacman -Sy --needed --noconfirm ${CORES_PKG}"
else
    log "Actualizando el pack de cores (paquete ${CORES_PKG})..."
    if elevar pacman -Sy --needed --noconfirm "${CORES_PKG}"; then
        log "paquete ${CORES_PKG} al dia"
    else
        warn "no se pudo instalar/actualizar ${CORES_PKG} (¿esta en el repositorio?)"
        exit 1
    fi
fi

# --- 2) Puente: copiar los cores del sistema a la carpeta de RetroArch ---------
if [ "$BRIDGE" = 1 ]; then
    if [ -x "${SCRIPTS_DIR}/deckstation-cores.sh" ]; then
        if [ "$DRY" = 1 ]; then
            DECKSTATION_ROOT="$DECKSTATION_ROOT" "${SCRIPTS_DIR}/deckstation-cores.sh" --dry-run || true
        else
            DECKSTATION_ROOT="$DECKSTATION_ROOT" "${SCRIPTS_DIR}/deckstation-cores.sh" || \
                warn "el puente de cores fallo; revisa si RetroArch esta instalado"
        fi
    else
        warn "no encuentro ${SCRIPTS_DIR}/deckstation-cores.sh (puente de cores)"
    fi
fi

log "listo"
