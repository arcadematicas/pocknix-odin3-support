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
# El Updater corre sin PATH cuando se lanza desde la app en Game Mode: sin esto no se
# encuentran pacman ni pkexec (por SSH funcionaba y enmascaraba el fallo).
export PATH="${PATH:-/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin}"

SELF="$(readlink -f "${BASH_SOURCE[0]}")"
DECKSTATION_ROOT="${DECKSTATION_ROOT:-$(cd "$(dirname "$SELF")/.." && pwd)}"
SCRIPTS_DIR="${DECKSTATION_ROOT}/scripts"

CORES_PKG="${DECKSTATION_CORES_PKG:-libretro-cores-pocknix}"
# Paquetes de cores PROPIOS que no van dentro del pack pero si deben actualizarse con el
# (hakuX es un core propio, no esta en el buildbot: sin esto el Updater nunca lo tocaba).
CORES_EXTRA="${DECKSTATION_CORES_EXTRA-libretro-hakux}"

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
    log "SIMULACION: pacman -Sy --needed --noconfirm ${CORES_PKG} ${CORES_EXTRA}"
else
    log "Actualizando el pack de cores (paquete ${CORES_PKG})..."
    # Con el helper del sistema (regla polkit) no hace falta dialogo de contrasena en
    # Game Mode; si no esta, se cae a pacman como antes.
    if [ -x /usr/bin/pocknix-cores-update ]; then
        # Tres caminos, en orden. El Updater corre DENTRO del contenedor del Steam Linux
        # Runtime (reaper): ahi pkexec y sudo NO son setuid y fallan con
        # "pkexec must be setuid root". systemd-run habla con el systemd del host por
        # D-Bus y si funciona desde el contenedor (la regla polkit 60 autoriza solo las
        # unidades llamadas pocknix-cores-update-*).
        paquetes=("${CORES_PKG}")
        for _p in ${CORES_EXTRA}; do paquetes+=("${_p}"); done
        ok=0
        if [ "$(id -u)" = 0 ]; then
            /usr/bin/pocknix-cores-update "${paquetes[@]}" && ok=1
        else
            if [ "$ok" = 0 ] && [ -x /usr/bin/systemd-run ] && [ -S /run/dbus/system_bus_socket ]; then
                log "actualizando por systemd-run (D-Bus)"
                timeout 900 /usr/bin/systemd-run --quiet --pipe --wait --collect \
                    --unit="pocknix-cores-update-$$" \
                    /usr/bin/pocknix-cores-update "${paquetes[@]}" && ok=1
            fi
            if [ "$ok" = 0 ] && [ -u /usr/bin/pkexec ]; then
                log "actualizando por pkexec"
                pkexec /usr/bin/pocknix-cores-update "${paquetes[@]}" && ok=1
            fi
            if [ "$ok" = 0 ]; then
                log "actualizando por sudo"
                sudo -n /usr/bin/pocknix-cores-update "${paquetes[@]}" && ok=1
            fi
        fi
        if [ "$ok" = 1 ]; then
            log "cores del sistema al dia"
            CORES_EXTRA=""
            CORES_PKG_DONE=1
        else
            warn "no se pudieron actualizar los cores (helper/polkit/D-Bus)"
            exit 1
        fi
    elif elevar pacman -Sy --needed --noconfirm "${CORES_PKG}"; then
        log "paquete ${CORES_PKG} al dia"
    else
        warn "no se pudo instalar/actualizar ${CORES_PKG} (¿esta en el repositorio?)"
        exit 1
    fi
    # Cores propios fuera del pack (hakuX). Si un extra no existe en el repo, se avisa
    # pero no se aborta: el pack principal ya esta al dia.
    for _p in ${CORES_EXTRA}; do
        log "Actualizando core propio: ${_p}..."
        if elevar pacman -Sy --needed --noconfirm "${_p}"; then
            log "paquete ${_p} al dia"
        else
            warn "no se pudo actualizar ${_p} (¿esta en el repositorio?)"
        fi
    done
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
