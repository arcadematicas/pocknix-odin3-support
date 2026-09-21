#!/bin/bash
# ======================================================================
# build-suyu-core-x86-container.sh — compila el core de Suyu para x86_64
# DENTRO DE UN CONTENEDOR con glibc antigua, para que funcione en SteamOS
# (Steam Deck) y en cualquier distro moderna.
# ======================================================================
# POR QUE HACE FALTA UN CONTENEDOR
#
# El script original (build-suyu-core-x86.sh) compila EN EL HOST. Si el host
# tiene glibc nueva (CachyOS: 2.44), el .so sale pidiendo simbolos GLIBC_2.43/
# 2.44 y falla en SteamOS:
#
#   [ERROR] Error(s): /usr/lib/libm.so.6: version `GLIBC_2.44' not found
#            (required by .../cores/suyu_libretro.so)
#
# Y no hay arreglo por detras: el AppImage de RetroArch NO trae libc/libm
# propias (usa las del sistema), y un core libretro es un .so que RetroArch
# carga con dlopen -> no se puede lanzar con un loader propio (la tecnica que
# si vale para un ejecutable, como WiiCompiled).
#
# La unica solucion real es ENLAZAR CONTRA UNA GLIBC VIEJA. Compilar "estatico"
# no basta: los simbolos versionados GLIBC_x.y vienen de la glibc contra la que
# se enlaza.
#
# OBJETIVO: Debian bookworm (glibc 2.36, GCC 12).
#   - Cubre SteamOS 3.3+ (que es Arch-based, glibc 2.36..2.41 segun version).
#   - Y de paso Ubuntu 22.04+ / Debian 12+.
#   - GCC 12 es lo mas bajo realista: suyu necesita C++20 y GCC 9/10 no bastan
#     (por eso no se baja a Debian bullseye / Ubuntu 20.04).
#
# Uso:
#   tools/build-suyu-core-x86-container.sh              # compila
#   tools/build-suyu-core-x86-container.sh --install    # y copia a ~/.config/retroarch/cores
# ======================================================================
set -euo pipefail

SELF="$(readlink -f "${BASH_SOURCE[0]}")"
ROOT="${POCKNIX_ROOT:-$(cd "$(dirname "$SELF")/.." && pwd)}"
PKG="${ROOT}/packages/suyu-libretro"
WORK="${SUYU_X86_WORK:-/home/fransis/suyu-x86-build}"
OUT="${WORK}/container-out"
INSTALL=0
[ "${1:-}" = "--install" ] && INSTALL=1

ENGINE="${CONTAINER_ENGINE:-podman}"
IMAGE="${SUYU_BUILD_IMAGE:-docker.io/library/debian:bookworm-slim}"

[ -f "${PKG}/suyu-language.patch" ] || { echo "falta ${PKG}/suyu-language.patch" >&2; exit 1; }
command -v "$ENGINE" >/dev/null 2>&1 || { echo "falta ${ENGINE}" >&2; exit 1; }

mkdir -p "$WORK" "$OUT"

echo "== contenedor: ${IMAGE} ($(${ENGINE} --version | head -1)) =="
echo "   objetivo: glibc 2.36 (Debian bookworm) -> SteamOS 3.3+ / Ubuntu 22.04+"
echo ""

# El build corre DENTRO del contenedor. Se monta solo el parche (lectura) y el
# directorio de salida: la fuente se clona dentro, para no arrastrar objetos
# compilados en el host (que envenenarian el enlazado con la glibc nueva).
"$ENGINE" run --rm \
    -v "${PKG}/suyu-language.patch:/in/suyu-language.patch:ro" \
    -v "${OUT}:/out" \
    -w / \
    "$IMAGE" \
    bash -euo pipefail -c '
        mkdir -p /build
        cd /build
        echo "== glibc del contenedor =="
        # OJO: NADA de `ldd --version | head -1` — con `set -o pipefail`, head
        # cierra el pipe, ldd muere con SIGPIPE (141) y `set -e` mata el script
        # en silencio justo aqui. `sed -n 1p` lee todo y no rompe.
        ldd --version 2>&1 | sed -n '1p'

        echo "== dependencias =="
        apt-get update -qq
        DEBIAN_FRONTEND=noninteractive apt-get install -y -qq --no-install-recommends \
            build-essential cmake ninja-build git ca-certificates \
            libboost-all-dev libssl-dev libusb-1.0-0-dev \
            libvulkan-dev libsdl2-dev libenet-dev libfmt-dev \
            zlib1g-dev libzstd-dev liblz4-dev glslang-dev catch2 \
            pkg-config python3 >/dev/null
        echo "  listo"

        echo "== clonando suyu v0.0.4 =="
        if [ ! -d /build/suyu/.git ]; then
            git clone --depth 1 https://github.com/suyu-emu/suyu-v0.0.4.git /build/suyu
        fi
        git -C /build/suyu log -1 --format="  HEAD: %h %s"

        echo "== submodulos (28: dynarmic, ffmpeg, SDL, cubeb...) — tarda =="
        git -C /build/suyu submodule update --init --recursive --depth 1

        echo "== parche del idioma =="
        if git -C /build/suyu apply --check /in/suyu-language.patch 2>/dev/null; then
            git -C /build/suyu apply /in/suyu-language.patch
            echo "  aplicado"
        elif grep -q suyu_language /build/suyu/src/libretro_core/retro_core.cpp 2>/dev/null; then
            echo "  ya estaba aplicado"
        else
            echo "  ERROR: el parche no aplica" >&2; exit 1
        fi

        echo "== configurando =="
        cmake -B /build/suyu/build -S /build/suyu \
            -DCMAKE_BUILD_TYPE=Release \
            -DSUYU_BUILD_LIBRETRO_CORE=ON \
            -DENABLE_QT=OFF \
            -DVulkanHeaders_FORCE_BUNDLED=ON \
            -DCMAKE_CXX_FLAGS="-Wno-maybe-uninitialized" \
            -GNinja

        echo "== compilando (esto es lo largo) =="
        cmake --build /build/suyu/build --target suyu_libretro

        SO=/build/suyu/build/src/libretro_core/suyu_libretro.so
        [ -f "$SO" ] || { echo "no se genero $SO" >&2; exit 1; }

        cp -v "$SO" /out/suyu_libretro.so
        echo "== glibc que pide el core =="
        objdump -T /out/suyu_libretro.so | grep -oE "GLIBC_2\.[0-9]+" | sort -uV | tail -1
        echo "  referencias a suyu_language: $(strings /out/suyu_libretro.so | grep -c suyu_language)"
    '

SO="${OUT}/suyu_libretro.so"
[ -f "$SO" ] || { echo "no se genero ${SO}" >&2; exit 1; }

echo ""
echo "== listo =="
ls -la "$SO" | awk '{print "  "$5" bytes  "$9}'
echo "  GLIBC max: $(objdump -T "$SO" 2>/dev/null | grep -oE 'GLIBC_2\.[0-9]+' | sort -uV | tail -1)"

if [ "$INSTALL" = 1 ]; then
    CORES="${HOME}/.config/retroarch/cores"
    mkdir -p "$CORES"
    cp -v "$SO" "${CORES}/suyu_libretro.so"
    cp -v "${PKG}/suyu_libretro.info" "${CORES}/suyu_libretro.info"
    echo "  instalado en ${CORES}"
fi
