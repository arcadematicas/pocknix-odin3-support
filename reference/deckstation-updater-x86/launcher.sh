#!/bin/bash
# ======================================================================
# LANZADOR PORTABLE MULTI-PYTHON DECKSTATION (Edición Roms/desktop)
# Descarga automática de Python Standalone + Aislamiento en Apps/Updater
# ======================================================================

# 1. CALCULAR RUTAS DESDE /Roms/desktop
# Subimos dos niveles (../..) para encontrar la raíz de DeckStation
SCRIPT_DIR="$(cd -L "$(dirname "${BASH_SOURCE[0]}")" && pwd -L)"
DECKSTATION_ROOT="$(cd -L "$SCRIPT_DIR/../.." && pwd -L)"

# La nueva carpeta centralizada para todos los archivos del actualizador
UPDATER_DIR="$DECKSTATION_ROOT/Apps/Updater"

echo "================================================="
echo "   🚀 INICIANDO ENTORNO PORTABLE DECKSTATION"
echo "================================================="

PY_DOT_VER="3.10"
PY_ENV_DIR="$UPDATER_DIR/libs/libs_py${PY_DOT_VER}"

# 2. VERIFICAR ENTORNO PORTABLE EN SU NUEVA UBICACIÓN
if [ ! -d "$PY_ENV_DIR" ]; then
    echo "📦 No se detectó Python portable local. Descargando entorno aislado..."
    mkdir -p "$UPDATER_DIR/libs"

    URL_PYTHON="https://github.com/indygreg/python-build-standalone/releases/download/20240107/cpython-3.10.13+20240107-x86_64-unknown-linux-gnu-install_only.tar.gz"

    curl -L "$URL_PYTHON" -o "$UPDATER_DIR/python_portable.tar.gz"

    if [ -f "$UPDATER_DIR/python_portable.tar.gz" ]; then
        echo "📦 Extrayendo entorno en $PY_ENV_DIR..."
        tar -xzf "$UPDATER_DIR/python_portable.tar.gz" -C "$UPDATER_DIR"
        mv "$UPDATER_DIR/python" "$PY_ENV_DIR"
        rm "$UPDATER_DIR/python_portable.tar.gz"

        echo "📥 Instalando dependencias internas (Pygame y Requests)..."
        "$PY_ENV_DIR/bin/python3" -m pip install --upgrade pip
        "$PY_ENV_DIR/bin/python3" -m pip install pygame requests
    else
        echo "🚨 Error crítico: No se pudo descargar el entorno portátil de Python."
        exit 1
    fi
fi

echo "📌 Versión de Python portátil: $PY_DOT_VER"
echo "📂 Ejecutando desde: $PY_ENV_DIR"

# 3. SEÑALIZAR RUTAS Y EVITAR CONFLICTOS
export PYTHONPATH="$PY_ENV_DIR/lib/python${PY_DOT_VER}/site-packages:$PYTHONPATH"
export LD_LIBRARY_PATH="$PY_ENV_DIR/lib:$LD_LIBRARY_PATH"

# Forzar a SDL (Pygame) a usar la capa gráfica nativa del Game Mode / Escritorio
export SDL_VIDEODRIVER="x11"
export SDL_AUDIODRIVER="alsa"

echo "🎮 Entorno listo. Lanzando actualizador..."
echo "-------------------------------------------------"

# 4. LANZAR EL ACTUALIZADOR EN SU NUEVA CARPETA
"$PY_ENV_DIR/bin/python3" "$UPDATER_DIR/updater.py"
