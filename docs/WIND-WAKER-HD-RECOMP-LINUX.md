# The Wind Waker HD Recomp para Linux — análisis y veredicto

**Fecha**: 3 de octubre de 2026
**Alcance**: el fork `misael-urquidez/ZeldaWWHDRecomp-Linux`, su rama `linux-port`, y si el
conjunto tiene sentido para la **Odin 3** (aarch64).
**Estado**: 🗄️ **APARCADO**. No se ha hecho nada con él en la Odin. El motivo está en §6.

Todo lo que aquí va marcado como **verificado** se obtuvo el 3/10/2026 de dos fuentes:

- la **API de GitHub** (repo, ramas, commits, releases, contenido de ficheros), consultada desde
  el PC de Fransis;
- el **análisis del PC de Fransis** del `.wua` de Batocera y del clon del repo en la rama
  `linux-port` (§6, §7). Las rutas que aparecen ahí (`/run/media/fransis/...`, `/tmp/opencode/...`)
  son **de la máquina de Fransis**, no del repo ni de la consola.

Lo que no se pudo comprobar se dice explícitamente como **sin verificar**. Ningún fichero del
juego, ni claves, ni texturas se han copiado a este repo.

---

## 1. Qué es, en tres líneas

`ZeldaWWHDRecomp` **traduce a C el código PowerPC de la versión de Wii U (USA) de The Wind Waker
HD** —la versión HD— y reimplementa nativamente las librerías de **Café OS** que el juego usa, de
modo que no hace falta Cemu en runtime. Las órdenes de **GX2** (la GPU de Wii U) se dibujan
directamente contra la GPU, sin emular comandos gráficos.

- **Fork**: `https://github.com/misael-urquidez/ZeldaWWHDRecomp-Linux`
- **Descripción** (verbatim de la API): *"Linux port of the Wind Waker HD static recompilation
  (SDL2 + OpenGL)"*
- **Licencia**: MPL-2.0 (lo dice su `LICENSE`/`README`; el campo `license` de la API devuelve
  `null`, así que el dato sale del README, no de la API).

### Ficha del fork (API, 3/10/2026)

| Métrica | Valor |
|---|---|
| Tamaño | **2 835 KB** (2,8 MB) |
| Estrellas | **0** |
| Issues abiertos | **0** |
| Releases | **0** |
| Creado | 2026-10-03 03:52:59 UTC |
| Último push | 2026-10-03 04:03:17 UTC |
| Rama por defecto | `main` |
| `fork` | `true` |
| `forks_count` | 0 |
| `network_count` | 5 |
| Suscriptores | 0 |

**Es un fork de un repo que tiene un día de vida**: el upstream (`ZeldaWWHDRecomp/ZeldaWWHDRecomp`)
se creó el **2026-10-01 12:28:45 UTC**, o sea **36 horas antes** que el fork. Nadie ha mirado el
fork todavía (0 estrellas, 0 issues, 0 watchers).

### Upstream (API, 3/10/2026)

| Métrica | Fork `misael-urquidez` | Upstream `ZeldaWWHDRecomp` |
|---|---|---|
| Tamaño | 2 835 KB | 1 349 KB |
| Estrellas | 0 | **61** |
| Issues abiertos | 0 | 1 |
| Releases | 0 | **0** |
| Creado | 2026-10-03 | **2026-10-01** |
| Último push | 2026-10-03 04:03 UTC | 2026-10-03 07:20 UTC |
| Ramas | 2 | **4** |
| Licencia API | `null` | `MPL-2.0` |

- `parent` y `source` del fork → **`ZeldaWWHDRecomp/ZeldaWWHDRecomp`**
- Ramas del upstream: **`main`**, **`devel`**, **`linux`**, **`windows`** ← **importante, ver §5**
- Forks del upstream: 5 · suscriptores: 6
- **Ni el fork ni el upstream tienen ninguna release.** No hay nada que instalar: todo se compila.

---

## 2. El fork tiene DOS ramas y esto es lo importante

Clonar sin `-b` se queda con `main`, que **no es el port de Linux**.

### `main` = el port macOS/Metal original, intacto

HEAD = `072eeaa48fbd98e086a88e4d0a53276316ba36f3`
(2026-10-02 08:04:21 UTC, *"Merge pull request #2 from Sean13128/fix-shader-cache-host-memory"*).

Verificado leyendo su `CMakeLists.txt`:

- `enable_language(OBJCXX)`, `-mcpu=apple-m1`,
  `target_link_libraries(... "-framework Metal" "-framework QuartzCore" "-framework AppKit" …)`,
  `runtime/third_party/metal-cpp`, ficheros `.mm`.
- Búsqueda de backends de ventana: `SDL2` / `EGL` / `GLFW` / `X11` / `wayland` → **0 apariciones**
  en el `CMakeLists.txt`.

**Verificado**: el `main` del fork está **1 commit por detrás** del `main` del upstream
(API `compare/main...misael-urquidez:main` → `status: behind`, `behind_by: 1`). Ese commit es
`e186375f16` (*"Update: Vulkan renderer next to Metal, full screen and GamePad screen modes,
aspect ratio (16:10, 21:9, 32:9)"*), que **no es** de macOS → el fork ya se quedó corto en su
rama principal.

### `linux-port` = el port real, **un solo commit**

`git clone -b linux-port https://github.com/misael-urquidez/ZeldaWWHDRecomp-Linux`

- **SHA**: `54755f4` (completo `54755f49432947fb447ed07f175d3b973d772d7f`)
- **Fecha**: 2026-10-03 04:03:04 UTC
- **Mensaje**: *"Linux port: SDL2 + OpenGL backend, ImGui menu, language selector"*
- **Diff**: **57 ficheros, +62 157 / −291** (API)

Qué añade ese commit (verificado en el `CMakeLists.txt` de la rama y en el README de la rama):

- `runtime/src/gfx_sdl/` — ventana GL + input SDL2.
- `ENABLE_OPENGL=1` (línea 51): *"LatteDecompiler.cpp: emit GLSL"* → el decompilador de Cemu
  **traduce los shaders de Latte a GLSL**.
- Dear ImGui (`imgui_impl_sdl2.cpp` + `imgui_impl_opengl3.cpp`) para el menú F1.
- LZ4 (save states), `runtime/src/platform.cpp` (capa Linux), `gfx_null/` y `mtl_shim/`
  (cabeceras Metal vacías para que el decompilador de Cemu compile).
- `WWHD_GFX` = `sdl` (por defecto) | `null`, solo para hosts no-Apple.

**El README bueno es el de `linux-port`**, no el de `main`.

### Qué SÍ trae `linux-port`

Verificado en su README:

- **Selector de idioma**: variable `WWHD_LANGUAGE` (`1` inglés, `2` francés, `5` español) o el
  menú F1. El original de macOS fija inglés a fuego.
- Corre a los **30 fps originales**.
- Menú F1/Start: cámara, remapeo de controles, 5 slots de save states, fullscreen/VSync/FPS.
- Audio: **PipeWire → ALSA → PulseAudio**, con timeout para que un stack de audio colgado no
  congele el arranque.
- Save states con LZ4, datos en `~/.local/share/wwhd/`.

### Qué NO trae

Está en el **Roadmap** de su README, sin cablear al backend OpenGL:

- **60 fps** (interpolación de frames) — el trabajo está hecho en el upstream (`runtime/src/true60.cpp`,
  `interp.cpp`, `tools/true60/`) pero no entra en el backend OpenGL.
- Resolución interna 1x-3x, antialiasing (FXAA), **shader cache / head start**.
- Empaquetado (AppImage/Flatpak) y Windows.

Limitaciones heredadas que el propio README reconoce: *geometry shaders y primitivas de rectángulo
no implementadas*, sombras más duras que en la consola, *"Later parts of the game are untested"*,
y los save states *"still being tested"*.

El README se autodefine **"Status: early and experimental"** y **"How far the game can be
played is untested"**.

---

## 3. Requisitos (según el README de `linux-port`)

**Toolchain**:

| Qué | Detalle |
|---|---|
| **clang** | **obligatorio, rechaza GCC** (`[[clang::musttail]]`) |
| CMake | ≥ 3.20 |
| Ninja | sí |
| SDL2-dev | headers de SDL2 |
| zlib | y LZ4 |
| Python 3 + `pycryptodome` | para la extracción del disco |
| GPU | **OpenGL 4.3 de escritorio** ← el punto crítico para nosotros |

**Del juego** (todo tuyo, nada se distribuye):

- imagen **`.wud` o `.wux`** de The Wind Waker HD (**USA**);
- su **disc key** de 16 bytes en un `.key` con el mismo nombre base, al lado de la imagen;
- la **Wii U common key** en `common.key` (16 bytes crudos o 32 hex) al lado de la imagen o en el
  directorio actual, o en la variable `WIIU_COMMON_KEY`.

Verbatim del README: *"None of these are included or will be provided."*

**Pipeline**:

```sh
python3 tools/wudextract.py game.wux extract game          # -> game/
python3 tools/recomp/recomp.py game/code/cking.rpx build/gen # -> build/gen/ (C generado)
cmake -B build -G Ninja -DCMAKE_BUILD_TYPE=Release \
      -DCMAKE_C_COMPILER=clang -DCMAKE_CXX_COMPILER=clang++
cmake --build build -j$(nproc)
./build/wwhd --game game        # F1 abre el menú
```

---

## 4. Estado del PC donde se probó

Ya estaba instalado: **clang 22.1.8, cmake 4.4.3, ninja 1.13.2, SDL2 2.32.72, zlib,
Python 3.14.7, Mesa 3:26.2.3**. Se instaló para esta prueba: **`python-pycryptodome` 3.23.0** y
**`python-capstone` 5.0.7**.

Es decir: **la cadena de herramientas no es el bloqueo**. Falta el juego.

---

## 5. ⚠️ Lo que nadie miraba: el upstream tiene una rama `linux` con **Vulkan**

Esto es **nuevo** respecto a la evaluación del port del fork, y cambia el panorama. **Verificado** por
API el 3/10/2026 sobre la rama `linux` del upstream:

- HEAD = **`026c71e6a3`** (2026-10-03 06:43:53 UTC),
  *"Build on Linux: Vulkan/SDL3 executable links, tests and renderer smoke pass"*, 8 ficheros, +201.
  Es **posterior** al `linux-port` del fork (04:03 del mismo día).
- `CMakeLists.txt`:
  - `set(WWHD_RENDERER "" CACHE STRING "Graphics backends: BOTH, METAL or VULKAN")`;
    **si no es Apple, el valor por defecto es `VULKAN`**.
  - `find_package(Vulkan 1.3 REQUIRED)`, `runtime/src/gfx/vulkan/*.cpp`
    (**24 ficheros, ~510 KB de código**), `glslang::glslang` + `SPIRV`.
  - `find_package(SDL3 CONFIG REQUIRED)`, `SDL3::SDL3`,
    `runtime/src/platform/input_sdl.cpp` + `mouse_sdl.cpp`.
  - `target_compile_definitions(cemu_latte PUBLIC ENABLE_VULKAN=1)`.
  - **NO hay `-march=x86-64-v3`**. El único `-mcpu` es `-mcpu=apple-m1`, y está protegido por
    `if(APPLE AND CMAKE_SYSTEM_PROCESSOR MATCHES "arm64|aarch64")` (línea 62).
  - Sigue exigiendo **clang** por `musttail`.
- `runtime/src/platform/` es un **directorio** (no un `platform.cpp`): `filesystem.h`, `host.h`,
  `input_sdl.cpp`, `keycodes.h`, `mouse_sdl.cpp`, `native.mm`. `runtime/src/platform.cpp`
  **no existe** en el upstream → ese fichero es aportación del fork.
- **Se puede construir sin juego** (esto es lo importante):
  - `python3 tools/recomp/stubgen.py build/gen-stub` escribe código invitado de relleno y
    `-DGEN_DIR=$PWD/build/gen-stub` compila y enlaza **el runtime entero sin dump**.
  - `./build/linux/wwhd --renderer-smoke` comprueba el renderer Vulkan **sin ficheros del juego**.
- CI: `.github/workflows/linux.yml` → Ubuntu 24.04, `ctest` y `--renderer-smoke` sobre
  **lavapipe** con la capa de validación Khronos.
- Su README avisa de que **SDL3 no está empaquetado en Ubuntu 24.04** (hay que compilarlo del
  release 3.2.x).

**Qué NO se ha hecho**: **no se ha compilado ni ejecutado nada** de esta rama `linux` del
upstream. Lo anterior es lectura de `CMakeLists.txt`, README y mensajes de commit vía API.
**Sin verificar**: si compila en aarch64, si el `--renderer-smoke` pasa sobre Turnip, si SDL3
está disponible en los repos de Arch ARM, y si la capa Vulkan rinde en la Odin.

**Por qué importa**: la rama del fork pide **OpenGL 4.3 de escritorio**, que en la Odin no hay
(Mali/Panfrost → GLES 3.x). La del upstream pide **Vulkan 1.3**, que en la Odin **sí tenemos y
funciona** (Turnip, `vulkaninfo` verificado con Adreno 830). Para nosotros el backend Vulkan es
el camino bueno, no el malo. El vigilante (§8) vigila esa rama por eso.

---

## 6. El bloqueo: por qué no se pudo probar

### El disco que había no era un WUD

Único candidato en la máquina de Fransis:
`/run/media/fransis/ROMS16TB/batocera/roms/wiiu/The Legend of Zelda - The Wind Waker HD (USA).wua`
— **1.489.764.491 bytes**.

**Es el formato propio de Batocera (`.wua`), NO un WUD.** Análisis byte a byte:

- cabecera **zstd** (`28 b5 2f fd`), ~22 700 frames zstd independientes, **sin cabecera `WUX0`**.
- Los sectores salen **ya sin comprimir**: descomprimir no aporta nada.
- Dentro: XML `<app>` con `title_id 0005000010143500`.
- En el offset `0x282`: **ELF PowerPC big-endian = `cking.rpx`**, 6.994.474 bytes, entry `0x028EA120`.
- XML `<menu>` con `<product_code>WUP-P-BCZE</product_code>`.
- Hacia `0x58CB7FF0`: la tabla `0005000010143500_v0` con el **índice de nombres completo**
  (`code`, `app.xml`, `cking.rpx`, `cos.xml`, `content/Cafe/Common/agl_resource_cafe.sarc`, …,
  `meta.xml`, `iconTex.tga`, `bootMovie.h264`) más tablas de entradas y de clústeres.

**No es un WUD válido**, y esto no es una opinión subjetiva:

- **sin firma `CC549EB9`** en `0x10000`,
- **sin tabla de particiones cifrada** en `0x18000`,
- **sin magic `FST0`**,
- el **tamaño no es múltiplo de 64 KiB** (sobran 1545 bytes).

### Las claves tampoco estaban

- Ni `.key` ni `common.key` en el PC.
- Lo único parecido es `~/.bios-deckstation-staging/switch/title.keys`, que es **de Switch**.

### Las herramientas del proyecto no saben leer `.wua`

- `tools/wudextract.py` **exige la firma del WUD** → muere sobre el `.wua`.
- **`tools/` es idéntico al de `main`**: el proyecto **no tiene forma de leer `.wua`**.

### El intento de extraer el RPX a mano: falló

Se extrajeron los bytes `0x282` → `0x6ABA2A` como `cking.rpx`:

- `recomp.py` y `rpxinfo.py` fallan con **`zlib.error: incorrect header check`**.
- Las secciones del ELF están marcadas **`SHF_RPL_ZLIB`**. La sección 3 sí descomprime
  **701.435 bytes** y a partir de ahí se rompe → **la extracción plana no es fiel**.

Resultado final, sin adornos:

- **Nunca se generó `build/gen`.**
- **`cmake --build` no llegó a lanzarse.**
- **Cero frames renderizados. Nunca se vio un frame de este juego en ningún sitio.**

---

## 7. Portabilidad a aarch64 (AYN Odin 3) — el estudio que sí vale

### El código está limpio

Verificado sobre el clon de la rama `linux-port`:

- **Cero assembly x86.**
- **Cero `#ifdef __x86_64__`** en `runtime/` (lo único es `#if defined(__APPLE__)`).
- Toda la capa portable está en **`runtime/src/platform.cpp`**:
  `mmap(..., MAP_PRIVATE|MAP_ANONYMOUS|MAP_NORESERVE|MAP_FIXED_NOREPLACE)` para la ventana de
  4 GiB del invitado, `__executable_start`, pthreads, directorios XDG.
- Dependencias multiplataforma: **OpenGL** (no Metal), **SDL2**, zlib, LZ4, ImGui.

### Qué habría que tocar

1. **`CMakeLists.txt`, target `gamecode`** (línea 33): `-march=x86-64-v3` es de x86 → poner
   `-mcpu=native` o quitarlo en aarch64. El `if(APPLE)` ya hace el equivalente con
   `-mcpu=apple-m1`. **Es el único punto duro del código.**
2. Compilar con **clang** (rechaza GCC).
3. ⚠️ **El riesgo grande**: pide **OpenGL 4.3 de escritorio** y la Odin va con **Mali/Panfrost**,
   que da **GLES 3.x**. El decompilador de Cemu emite **GLSL** (`ENABLE_OPENGL`) → habría que
   **adaptar el backend a GLES**. Esto **no es "solo compilar"**, es trabajo de portabilidad.
   → Salida: §5. **El upstream ya está en Vulkan**, que es lo que sí tenemos.
4. Verificar que `runtime/third_party/cemu` compila limpio en aarch64 (C++ moderno; en principio
   sí, pero **sin verificar**).
5. **Rendimiento**: en el M3 de referencia el código gasta ~**4 ms de CPU/frame**. En la Odin el
   presupuesto para 30 fps (33,3 ms) es una **incógnita** — depende del Vulkan/GLES que toque y
   del TDP. **Sin medir.**

---

## 8. Veredicto

# 🗄️ APARCADO

Dos bloqueos, y son independientes:

1. **Falta el juego.** Para que funcione hace falta **una** de estas dos:
   - (a) un dump **`.wud`/`.wux` válido + disc key + Wii U common key** sacados de **una consola
     y un disco propios**, o
   - (b) una carpeta ya extraída en **formato Cemu** (`code/`, `content/`, `meta/`).
   El **`.wua` de Batocera no sirve**, y el repo no sabe leerlo.
2. **Para la Odin falta además el backend gráfico.** El port del fork pide **OpenGL 4.3 de
   escritorio** y la Odin da **GLES 3.x** → hay que adaptar GL→GLES. **No es "solo compilar".**

**Se retoma cuando:**

- haya dump válido + claves; **y**
- el upstream siga madurando (los 60 fps, la resolución y el shader cache viven **allí**, no en el
  fork).

**Reabrir antes** solo en un caso concreto: cuando se quiera **validar el camino Vulkan**
(rama `linux` del upstream), porque ahí **no hace falta dump** para construir (`stubgen.py`) ni
para arrancar el renderer (`--renderer-smoke`). Eso se podría probar en la Odin **sin tocar nada
del juego** — pero es una prueba de humo del renderer, **no** el juego.

**No se ha distribuido nada del juego**: ni discos, ni texturas, ni claves, ni el RPX
extraído. Este documento solo describe; el repo no contiene nada de eso.

---

## 9. Seguimiento: el vigilante

Hay un guardian: **`tools/watch-wwhd-recomp-linux.sh`**. Se dejó puesto para lo que pidió Fransis
(*"dejalo apuntado y estemos al tanto de ese repositorio y sus novedades"*).

```sh
tools/watch-wwhd-recomp-linux.sh            # una consulta y sale
tools/watch-wwhd-recomp-linux.sh --wait     # cada hora, avisa al vuelo
tools/watch-wwhd-recomp-linux.sh --wait 1800  # cada media hora
tools/watch-wwhd-recomp-linux.sh --help
```

Qué vigila:

1. **Rama `linux-port`**: último commit, fecha y mensaje → si cambia el SHA marca **NOVEDAD**.
2. **Ramas nuevas** aparte de `main` / `linux-port`.
3. **Releases nuevas** (ahora no hay ninguna) y, si traen assets, los nombra y dice si alguno es
   **aarch64**.
4. **El upstream** (`ZeldaWWHDRecomp/ZeldaWWHDRecomp`): últimos commits de `main` **y de
   `linux`** y sus releases — es de ahí de donde sale el avance de verdad (60 fps, resolución,
   shader cache y, ahora, el backend Vulkan).
5. Resumen en una línea: **¿algo nuevo desde la última vez? SÍ/NO**.

Notas de uso:

- Guarda estado en `~/.cache/wwhd-watch.state` (o `$XDG_CACHE_HOME`). **La primera ejecución solo
  guarda estado**; la siguiente compara. Es **idempotente**: repetirla sin cambios no dice nada.
- Usa la API de GitHub. Coge el token de `~/.config/opencode/opencode.jsonc`
  (`GITHUB_PERSONAL_ACCESS_TOKEN`) **si existe**; **sin token funciona igual**, con el rate limit
  de anónimo.
- Si no hay red o GitHub devuelve 403 (rate limit), **lo dice y sale con código 0**, sin
  stacktrace y **sin tocar el estado guardado** (para no perder la línea base).
- Sale siempre con código 0: es un vigilante, no un test.

---

## 10. Lo que NO se ha hecho ni verificado

- **No se ha compilado nada** del port. Ni `cmake -B build` llegó a ejecutarse en el flujo real.
- **No se ha visto un frame.** Ni en el PC ni en la Odin.
- **No se ha obtenido ningún dump válido** ni ninguna clave. Sin ellas el proyecto no puede
  arrancar por diseño (el README lo dice).
- **No se ha analizado el contenido del `.wua` más allá de lo del §6**, ni se ha intentado
  convertirlo a formato Cemu. **No está claro que se pueda**: el `.wua` no tiene firma ni tabla
  de particiones, que es justo lo que `wudextract.py` necesita.
- **La rama `linux` del upstream no se ha compilado ni ejecutado** (§5). Es todo lectura de
  ficheros y mensajes de commit por API.
- **Sin verificar** para aarch64: si `runtime/third_party/cemu` compila limpio, si SDL3 está en
  los repos de Arch ARM, si el `--renderer-smoke` pasa sobre Turnip, y el coste real por frame en
  la Odin (los ~4 ms son del M3 de referencia).
- **No se ha contactado** con el autor del fork ni con el upstream (0 issues, 0 stars: no hay por
  dónde).
- **Las rutas del PC que se citan** (`/run/media/fransis/...`, `/tmp/opencode/wwhd/...`) son de la
  máquina de Fransis. `/tmp` es **tmpfs (RAM)**: si se reinicia el PC, `/tmp/opencode/wwhd/`
  desaparece entero.
