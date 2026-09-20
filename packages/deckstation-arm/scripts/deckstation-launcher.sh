#!/bin/bash
# ======================================================================
# DECKSTATION LAUNCHER PORTABLE v1.0
# ======================================================================
# Este script es el punto de entrada portable de DeckStation.
# Crea automáticamente la estructura centralizada de saves/logs,
# asegura los symlinks de compatibilidad, y lanza ES-DE.
#
# Es 100% portable: calcula las rutas dinámicamente cada vez.
# Si mueves DeckStation a otra ruta, este script se adapta solo.
# ======================================================================

# 1. CALCULAR RAÍZ DE DECKSTATION (funciona esté donde esté)
DECKSTATION_ROOT="${DECKSTATION_ROOT:-$(cd "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")/.." && pwd)}"
cd "$DECKSTATION_ROOT"

echo "=============================================="
echo "  🚀 DECKSTATION PORTABLE LAUNCHER"
echo "  📂 Raíz: $DECKSTATION_ROOT"
echo "=============================================="

# 2. CREAR ESTRUCTURA CENTRALIZADA DE SAVES Y LOGS
mkdir -p "$DECKSTATION_ROOT/saves/retroarch/saves"
mkdir -p "$DECKSTATION_ROOT/saves/retroarch/states"
mkdir -p "$DECKSTATION_ROOT/saves/retroarch/screenshots"
mkdir -p "$DECKSTATION_ROOT/saves/duckstation/savestates"
mkdir -p "$DECKSTATION_ROOT/saves/duckstation/screenshots"
mkdir -p "$DECKSTATION_ROOT/saves/duckstation/memcards"
mkdir -p "$DECKSTATION_ROOT/saves/pcsx2/memcards"
mkdir -p "$DECKSTATION_ROOT/saves/pcsx2/sstates"
mkdir -p "$DECKSTATION_ROOT/saves/pcsx2/snaps"
mkdir -p "$DECKSTATION_ROOT/logs/retroarch"
mkdir -p "$DECKSTATION_ROOT/logs/pcsx2"

# 3. SYMLINKS PARA EMULADORES QUE ESCRIBEN AL CWD
#    (Logs/ y Saves/ en la raíz redirigen a logs/ y saves/)
[ -L "$DECKSTATION_ROOT/Logs" ]  || ln -sf logs  "$DECKSTATION_ROOT/Logs"
[ -L "$DECKSTATION_ROOT/Saves" ] || ln -sf saves "$DECKSTATION_ROOT/Saves"

# 4. SYMLINK PARA RETROARCH: saves → directorio centralizado
#    Así RetroArch guarda en saves/retroarch/ en lugar de dentro de AppImage.home
#    (se detecta el directorio .AppImage.home real, sin hardcodear arquitectura)
RA_HOME="$(find "$DECKSTATION_ROOT/Apps/retroarch" -maxdepth 2 -type d -name "*.AppImage.home" 2>/dev/null | head -1)"
if [ -z "$RA_HOME" ]; then
    RA_HOME="$DECKSTATION_ROOT/Apps/retroarch"
fi
RA_SAVES_DIR="$RA_HOME/.config/retroarch/saves"
RA_STATES_DIR="$RA_HOME/.config/retroarch/states"
RA_SCREENSHOTS_DIR="$RA_HOME/.config/retroarch/screenshots"
RA_LOGS_DIR="$RA_HOME/.config/retroarch/logs"

# Si los directorios existen como directorios reales (no symlinks),
# mover su contenido a la ubicación centralizada y reemplazar con symlink
redirect_to_centralized() {
    local target="$1"      # ruta real dentro de AppImage.home
    local central="$2"     # ruta centralizada en saves/ o logs/

    if [ -d "$target" ] && [ ! -L "$target" ]; then
        echo "  📦 Migrando $target → $central"
        # Mover contenido existente
        if [ "$(ls -A "$target" 2>/dev/null)" ]; then
            cp -rn "$target"/* "$central"/ 2>/dev/null || true
        fi
        rm -rf "$target"
    fi
    ln -snf "$central" "$target"
}

redirect_to_centralized "$RA_SAVES_DIR"       "$DECKSTATION_ROOT/saves/retroarch/saves"
redirect_to_centralized "$RA_STATES_DIR"      "$DECKSTATION_ROOT/saves/retroarch/states"
redirect_to_centralized "$RA_SCREENSHOTS_DIR"  "$DECKSTATION_ROOT/saves/retroarch/screenshots"
redirect_to_centralized "$RA_LOGS_DIR"         "$DECKSTATION_ROOT/logs/retroarch"

# 5. SYMLINK PARA DUCKSTATION
DS_HOME="$DECKSTATION_ROOT/Apps/Duckstation/DuckStation.AppImage.home"
DS_DATA_DIR="$DS_HOME/.local/share/duckstation"

redirect_to_centralized "$DS_DATA_DIR/savestates"  "$DECKSTATION_ROOT/saves/duckstation/savestates"
redirect_to_centralized "$DS_DATA_DIR/screenshots" "$DECKSTATION_ROOT/saves/duckstation/screenshots"
redirect_to_centralized "$DS_DATA_DIR/memcards"     "$DECKSTATION_ROOT/saves/duckstation/memcards"

# 6. SYMLINK PARA PCSX2
PCSX2_HOME="$DECKSTATION_ROOT/Apps/Pcsx2/pcsx2.AppImage.home"
PCSX2_CONFIG_DIR="$PCSX2_HOME/.config/PCSX2"

redirect_to_centralized "$PCSX2_CONFIG_DIR/memcards" "$DECKSTATION_ROOT/saves/pcsx2/memcards"
redirect_to_centralized "$PCSX2_CONFIG_DIR/sstates"  "$DECKSTATION_ROOT/saves/pcsx2/sstates"
redirect_to_centralized "$PCSX2_CONFIG_DIR/snaps"    "$DECKSTATION_ROOT/saves/pcsx2/snaps"
redirect_to_centralized "$PCSX2_CONFIG_DIR/logs"     "$DECKSTATION_ROOT/logs/pcsx2"

# 7. CONFIGS BASE + BIOS + CORES (auto-reparacion barata: solo lo que falte)
if [ -x "$DECKSTATION_ROOT/scripts/deckstation-cores.sh" ]; then
    DECKSTATION_ROOT="$DECKSTATION_ROOT" "$DECKSTATION_ROOT/scripts/deckstation-cores.sh" 2>/dev/null || true
fi
if [ -x "$DECKSTATION_ROOT/scripts/deckstation-configs.sh" ]; then
    DECKSTATION_ROOT="$DECKSTATION_ROOT" "$DECKSTATION_ROOT/scripts/deckstation-configs.sh" 2>/dev/null || true
fi
if [ -x "$DECKSTATION_ROOT/scripts/deckstation-bios.sh" ]; then
    DECKSTATION_ROOT="$DECKSTATION_ROOT" "$DECKSTATION_ROOT/scripts/deckstation-bios.sh" 2>/dev/null || true
fi

# 8. FORZAR SDL AL COMPOSITOR (gamescope / Plasma)
#    Sin esto, ES-DE puede quedarse en NEGRO al lanzarse desde el modo juego de
#    Steam (gamescope "Device or resource busy" si hereda el driver equivocado).
#    Misma logica que scripts/lanzar.sh para los emuladores.
if [ -n "${WAYLAND_DISPLAY:-}" ] && [ -z "${SDL_VIDEODRIVER:-}" ]; then
    export SDL_VIDEODRIVER=wayland
elif [ -n "${DISPLAY:-}" ] && [ -z "${SDL_VIDEODRIVER:-}" ]; then
    export SDL_VIDEODRIVER=x11
fi

echo ""
echo "=============================================="
echo "  ✅ Entorno listo. Lanzando DeckStation..."
echo "=============================================="

# 9. LANZAR ES-DE (el AppImage original)
exec "$DECKSTATION_ROOT/DeckStation.AppImage" "$@"