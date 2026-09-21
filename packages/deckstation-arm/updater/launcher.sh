#!/bin/bash
# ======================================================================
# LANZADOR DEL UPDATER DE DECKSTATION (aarch64 / AYN Odin 3)
# ----------------------------------------------------------------------
# A diferencia de la version x86_64 (que descargaba un Python portable
# x86_64 con curl), aqui se usa el Python DEL SISTEMA, que ya es aarch64.
# Asi no hay que bajar ~50 MB ni mantener un interprete aparte.
# Dependencias: python, python-pygame, python-requests (las declara el
# PKGBUILD de deckstation-arm).
# ======================================================================
set -uo pipefail

UPDATER_DIR="$(cd -L "$(dirname "${BASH_SOURCE[0]}")" && pwd -L)"

PY="$(command -v python3 || true)"
if [ -z "$PY" ]; then
    echo "🚨 No se encontro python3. Instala: sudo pacman -S python"
    exit 1
fi

# Comprobar dependencias de Python antes de arrancar (mejor un error claro
# que un traceback de import)
if ! "$PY" -c "import pygame, requests" 2>/dev/null; then
    echo "🚨 Faltan dependencias de Python."
    echo "   Instala:  sudo pacman -S python-pygame python-requests"
    echo "   (o desde Pocknix Tools -> descargar DeckStation)"
    exit 1
fi

# Capa grafica: ELEGIR la del compositor que hay, no forzar X11.
# En una sesion Wayland (Plasma/gamescope) pygame con SDL_VIDEODRIVER=x11 falla:
#   pygame.error: x11 not available  /  "Authorization required, but no
#   authorization protocol specified" (XWayland sin permisos)
# y el Updater se queda sin ventana. Misma logica que scripts/lanzar.sh.
if [ -n "${WAYLAND_DISPLAY:-}" ]; then
    export SDL_VIDEODRIVER="${SDL_VIDEODRIVER:-wayland}"
elif [ -n "${DISPLAY:-}" ]; then
    export SDL_VIDEODRIVER="${SDL_VIDEODRIVER:-x11}"
fi
export SDL_AUDIODRIVER="${SDL_AUDIODRIVER:-alsa}"

# El updater deriva sus rutas de la ubicacion del script, pero por si acaso
export DECKSTATION_ROOT="${DECKSTATION_ROOT:-$(dirname "$UPDATER_DIR")/..}"

exec "$PY" "$UPDATER_DIR/updater.py" "$@"
