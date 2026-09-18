#!/bin/bash
# build-suyu-core-x86.sh — compila el core de libretro de Suyu para x86_64 CON el
# parche del idioma (suyu_language), igual que hacemos para aarch64 en la Odin.
#
# Por que: el release oficial solo trae linux-x64 SIN el parche (es de fuente), y
# el buildbot de libretro no compila suyu. Sin el parche el core no tiene opcion
# de idioma y todos los juegos salen en ingles.
#
# Uso: tools/build-suyu-core-x86.sh [--install]
#   --install  copia el .so + el .info a ~/.config/retroarch/cores/
set -euo pipefail

SELF="$(readlink -f "${BASH_SOURCE[0]}")"
ROOT="${POCKNIX_ROOT:-$(cd "$(dirname "$SELF")/.." && pwd)}"
PKG="${ROOT}/packages/suyu-libretro"
WORK="${SUYU_X86_WORK:-/home/fransis/suyu-x86-build}"
SRC="${WORK}/suyu-v0.0.4"
INSTALL=0
[ "${1:-}" = "--install" ] && INSTALL=1

[ -f "${PKG}/suyu-language.patch" ] || { echo "falta ${PKG}/suyu-language.patch" >&2; exit 1; }

echo "== dependencias (Arch/CachyOS) =="
DEPS=(cmake ninja git boost openssl libusb vulkan-icd-loader sdl2 enet fmt zlib zstd lz4 glslang catch2 vulkan-headers)
missing=()
for d in "${DEPS[@]}"; do pacman -Qq "$d" >/dev/null 2>&1 || missing+=("$d"); done
if [ ${#missing[@]} -gt 0 ]; then
    echo "  faltan: ${missing[*]}"
    # OJO: si el script corre en segundo plano (setsid/nohup) NO hay terminal y
    # `sudo` no puede pedir la contrasena -> instalarlas antes a mano:
    #   sudo pacman -S --needed ${missing[*]}
    if sudo -n true 2>/dev/null; then
        sudo -n pacman -S --needed --noconfirm "${missing[@]}"
    else
        echo "  ERROR: sudo necesita contrasena y no hay terminal." >&2
        echo "  Ejecuta primero:  sudo pacman -S --needed ${missing[*]}" >&2
        exit 1
    fi
else
    echo "  todas presentes"
fi

echo "== clonando la fuente =="
mkdir -p "$WORK"
if [ ! -d "$SRC/.git" ]; then
    git clone --depth 1 https://github.com/suyu-emu/suyu-v0.0.4.git "$SRC"
fi
echo "  HEAD: $(git -C "$SRC" log -1 --format='%h %s' | head -c 70)"

echo "== submódulos (28: dynarmic, ffmpeg, SDL, cubeb, ...) — tarda =="
git -C "$SRC" submodule update --init --recursive --depth 1

echo "== aplicando el parche del idioma =="
if git -C "$SRC" apply --check "${PKG}/suyu-language.patch" 2>/dev/null; then
    git -C "$SRC" apply "${PKG}/suyu-language.patch"
    echo "  aplicado"
elif grep -q "suyu_language" "$SRC/src/libretro_core/retro_core.cpp" 2>/dev/null; then
    echo "  ya estaba aplicado"
else
    echo "  ERROR: el parche no aplica" >&2; exit 1
fi
grep -c "suyu_language" "$SRC/src/libretro_core/retro_core.cpp" | sed 's/^/  refs suyu_language: /'

echo "== configurando (cmake/ninja) =="
cmake -B "${SRC}/build" -S "$SRC" \
    -DCMAKE_BUILD_TYPE=Release \
    -DSUYU_BUILD_LIBRETRO_CORE=ON \
    -DENABLE_QT=OFF \
    -DVulkanHeaders_FORCE_BUNDLED=ON \
    -DCMAKE_CXX_FLAGS="-Wno-maybe-uninitialized" \
    -GNinja

echo "== compilando (esto es lo largo) =="
cmake --build "${SRC}/build" --target suyu_libretro

SO="${SRC}/build/src/libretro_core/suyu_libretro.so"
[ -f "$SO" ] || { echo "no se generó ${SO}" >&2; exit 1; }
echo "== listo =="
ls -la "$SO" | awk '{print "  "$5" bytes  "$9}'
echo "  opcion presente: $(strings "$SO" | grep -c suyu_language) referencias a suyu_language"

if [ "$INSTALL" = 1 ]; then
    CORES="${HOME}/.config/retroarch/cores"
    mkdir -p "$CORES"
    cp -v "$SO" "${CORES}/suyu_libretro.so"
    cp -v "${PKG}/suyu_libretro.info" "${CORES}/suyu_libretro.info"
    echo "  instalado en ${CORES}"
fi
