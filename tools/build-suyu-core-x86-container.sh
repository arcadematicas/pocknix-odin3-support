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

# El build corre DENTRO del contenedor. Se monta el parche (lectura), el
# directorio de salida y un /build PERSISTENTE: la fuente trae 28 submodulos
# anidados y clonarlos tarda mucho, asi que no puede perderse en cada reintento
# (el contenedor va con --rm).
mkdir -p "${WORK}/container-build"
"$ENGINE" run --rm \
    -v "${PKG}/suyu-language.patch:/in/suyu-language.patch:ro" \
    -v "${OUT}:/out" \
    -v "${WORK}/container-build:/build" \
    -w / \
    "$IMAGE" \
    bash -euo pipefail -c '
        mkdir -p /build
        cd /build
        echo "== glibc del contenedor =="
        # OJO: NADA de `ldd --version | head -1` — con `set -o pipefail`, head
        # cierra el pipe, ldd muere con SIGPIPE (141) y `set -e` mata el script
        # en silencio justo aqui. `sed -n 1p` lee todo y no rompe.
        ldd --version 2>&1 | sed -n 1p

        echo "== dependencias =="
        apt-get update -qq
        DEBIAN_FRONTEND=noninteractive apt-get install -y -qq --no-install-recommends \
            build-essential cmake ninja-build git ca-certificates curl \
            libssl-dev libusb-1.0-0-dev \
            libvulkan-dev libsdl2-dev libenet-dev \
            zlib1g-dev libzstd-dev liblz4-dev glslang-dev catch2 \
            pkg-config python3 >/dev/null
        # SDL3 (submodulo) se configura SIEMPRE y exige las cabeceras X11/Wayland;
        # sin ellas falla con "dependency package for XTEST".
        # OJO: NADA de apostrofos en los comentarios de este bloque — todo esto va
        # dentro de un bash -c entre comillas simples y un apostrofo suelto lo
        # cerraria antes de tiempo (las comillas de sed -n 1p si son seguras:
        # se concatenan y el contenido queda igual).
        DEBIAN_FRONTEND=noninteractive apt-get install -y -qq --no-install-recommends \
            libx11-dev libxext-dev libxrandr-dev libxcursor-dev libxfixes-dev \
            libxi-dev libxss-dev libxtst-dev libxkbcommon-dev \
            libdrm-dev libgbm-dev libgl1-mesa-dev libegl1-mesa-dev \
            libgles2-mesa-dev libasound2-dev libpulse-dev libdbus-1-dev \
            libudev-dev libwayland-dev libdecor-0-dev >/dev/null
        DEBIAN_FRONTEND=noninteractive apt-get install -y -qq --no-install-recommends \
            libavcodec-dev libavformat-dev libavutil-dev libswscale-dev \
            libavfilter-dev libswresample-dev libinih-dev \
            nlohmann-json3-dev libzip-dev >/dev/null
        DEBIAN_FRONTEND=noninteractive apt-get install -y -qq --no-install-recommends \
            glslang-tools spirv-tools >/dev/null
        echo "  listo"

        # Boost: bookworm trae 1.74 y suyu incluye boost/regex/v5/... (existe
        # desde 1.78). Se compilan SOLO las libs que usa, a /usr/local.
        # Junto con CMake y fmt, esto es lo que permite tener GLIBC VIEJA con
        # HERRAMIENTAS NUEVAS: es exactamente el compromiso que exige SteamOS
        # (glibc 2.36..2.41, pero Boost 1.8x, GCC 12+ y CMake 3.31+).
        echo "== Boost >=1.78 (bookworm trae 1.74; suyu usa boost/regex/v5) =="
        BOOST_VER="${BOOST_VER:-1.86.0}"
        BOOST_U="${BOOST_VER//./_}"
        if [ ! -d /usr/local/include/boost ]; then
            curl -fsSL -o /tmp/boost.tar.gz \
                "https://archives.boost.io/release/${BOOST_VER}/source/boost_${BOOST_U}.tar.gz"
            tar -xzf /tmp/boost.tar.gz -C /tmp
            cd "/tmp/boost_${BOOST_U}"
            ./bootstrap.sh --prefix=/usr/local \
                --with-libraries=regex,filesystem,system,context,thread,program_options
            ./b2 -j"$(nproc)" variant=release link=shared \
                --with-regex --with-filesystem --with-system --with-context \
                --with-thread --with-program_options install >/dev/null
            cd /build
            rm -rf /tmp/boost.tar.gz "/tmp/boost_${BOOST_U}"
        fi
        ls /usr/local/lib/libboost_regex.so* 2>/dev/null | sed -n 1p

        # fmt: bookworm trae fmt 9 y suyu necesita >=10 (usa format_string::get,
        # que no existe en 9). Por eso el build ARM si funciona: Arch trae fmt 11.
        # Se compila fmt 10 a /usr/local y NO se instala libfmt-dev, para que no
        # haya dos fmt y CMake coja el bueno sin ambiguedad.
        echo "== fmt 10 (bookworm trae 9; suyu necesita >=10) =="
        FMT_VER="${FMT_VER:-10.2.1}"
        if [ ! -f /usr/local/lib/cmake/fmt/fmt-config.cmake ]; then
            curl -fsSL -o /tmp/fmt.tar.gz \
                "https://github.com/fmtlib/fmt/archive/refs/tags/${FMT_VER}.tar.gz"
            tar -xzf /tmp/fmt.tar.gz -C /tmp
            cmake -S "/tmp/fmt-${FMT_VER}" -B /tmp/fmt-build \
                -DCMAKE_BUILD_TYPE=Release -DFMT_TEST=OFF -DFMT_DOC=OFF \
                -DCMAKE_INSTALL_PREFIX=/usr/local -DBUILD_SHARED_LIBS=ON -GNinja
            cmake --build /tmp/fmt-build
            cmake --install /tmp/fmt-build
            rm -rf /tmp/fmt.tar.gz "/tmp/fmt-${FMT_VER}" /tmp/fmt-build
        fi
        sed -n 1p /usr/local/include/fmt/base.h 2>/dev/null || true

        # suyu exige CMake >= 3.31 y bookworm trae 3.25 -> se trae uno moderno
        # APARTE. CMake es una herramienta de BUILD: no cambia la glibc contra la
        # que se enlaza el resultado, que es lo que nos importa (seguimos en 2.36).
        echo "== CMake moderno (bookworm trae 3.25, suyu pide >=3.31) =="
        CMAKE_VER="${CMAKE_VER:-3.31.6}"
        if [ ! -x /opt/cmake/bin/cmake ]; then
            curl -fsSL -o /tmp/cmake.tar.gz \
                "https://github.com/Kitware/CMake/releases/download/v${CMAKE_VER}/cmake-${CMAKE_VER}-linux-x86_64.tar.gz"
            mkdir -p /opt/cmake
            tar -xzf /tmp/cmake.tar.gz -C /opt/cmake --strip-components=1
            rm -f /tmp/cmake.tar.gz
        fi
        export PATH="/opt/cmake/bin:$PATH"
        cmake --version | sed -n 1p

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

        # x86_64: boost::crc_optimal<32>::value_type es `unsigned long` (64 bits),
        # porque en x86_64 Linux uint_fast32_t ES de 64 bits. suyu compila con
        # -Werror=conversion -> "conversion ... may change value" y no compila.
        # En ARM no pasa (alli uint_fast32_t es de 32). Se hace el cast explicito.
        # Ojo: hay que tocarlo EN LA FUENTE, porque el -Werror lo anade el propio
        # proyecto DESPUES de nuestros CMAKE_CXX_FLAGS (asi que anadirlo a mano no
        # ganaria la pelea).
        echo "== parche x86_64: cast del crc de Boost =="
        sed -i \
            "s|message.header.crc = crc.checksum();|message.header.crc = static_cast<u32>(crc.checksum());|" \
            /build/suyu/src/input_common/helpers/udp_protocol.h
        grep -n "static_cast<u32>(crc.checksum())" \
            /build/suyu/src/input_common/helpers/udp_protocol.h | sed -n 1p

        echo "== configurando =="
        cmake -B /build/suyu/build -S /build/suyu \
            -DCMAKE_BUILD_TYPE=Release \
            -DSUYU_BUILD_LIBRETRO_CORE=ON \
            -DENABLE_QT=OFF \
            -DVulkanHeaders_FORCE_BUNDLED=ON \
            -DCMAKE_CXX_FLAGS="-Wno-maybe-uninitialized" \
            -DCMAKE_PREFIX_PATH=/usr/local \
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
