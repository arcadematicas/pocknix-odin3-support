# PENDIENTES Y PRUEBAS — 13/10/2026 (roadmap)

> Estado: el **PC encendido** compilando la rama de shuuri. Nada de aqui esta hecho salvo lo marcado ✅.

## A. IMPLEMENTAR (en orden)

### A1. Validar el PR #135 (part 2/2) y dejar que shuuri lo mergee  ⭐ bloqueante
- Build fresco de la rama `sm8750-odin3` (ya compilando en el PC: `~/pocknix-upstream-test`).
- Pasar la **checklist B1** en la Odin y **comentar en el PR #135**.
- Cambios suyos a tener en cuenta: kernel **7.2.10**, BSP en layout `root/`+`boards/`, ABL **1.2**,
  `POCKNIX_PANEL_WAIT=30`, `pocknix-steam 0.1.0-70`, firmware con el par ADSP en `ayn/odin3/`.
- OJO: **su cmdline NO lleva `oops=panic panic=5`** (el nuestro si) y usa `quiet loglevel=3` + plymouth.

### A2. Rebasear CalvOS a 7.2.10 (tras el merge)
- Traer su `main` y rebasar nuestro centro/arbol; decidir: `oops=panic` si/no y que cmdline usamos.
- Nuestro extra (guarda **ath12k 0041b**) va como **PR propio a `kernel/common`** (ellos lo dijeron).

### A3. `pocknix-vk-valve` → build del Deckard `-5`  ⭐ PREPARADO (PKGBUILD bumpeado; NO compilado)
- `_valve_pkg` = `deckard-mesa-linux-aarch64-26.3.0_devel+gite07916b4-5-aarch64.pkg.tar.zst`
- sha256 `c30eb810cf537e839f5b7ff66b1088e3c29cf67e17bcbf44856b3ac38064b7cb` (19.334.706 B)
- Bump `pkgver`/`pkgrel` + recompilar + publicar en R2. Medir (el `-1` daba +13,4% FPS).

**Hecho el 13/10/2026 (tarea A3, sin compilar — el PC esta ocupado con A1):**
- **sha256/tamano REALES verificados descargando el fichero** (a `/tmp/opencode`, luego limpiado):
  `c30eb810cf537e839f5b7ff66b1088e3c29cf67e17bcbf44856b3ac38064b7cb`, **19.334.706 B** → **cuadra
  con la nota al byte**. (URL con `%2B` por el `+`: `...26.3.0_devel%2Bgite07916b4-5...`.)
- **PKGBUILD tocado (SOLO el del centro, fuente de verdad)**: `packages/pocknix-vk-valve/PKGBUILD`
  - `pkgver 20261009 → 20261013`, `pkgrel 1` (sin cambio); `_valve_pkg …-1 → …-5`;
    `sha256sums 1bc065a1… → c30eb810…`; comentarios derivados (`# …gite07916b4-5`) actualizados.
  - `_mesa_series`/`_payload` **NO cambian** (`26.3.0-valve`) → la clave del tweak sigue igual.
  - La copia del arbol (`pocknix-os/packages/shared/pocknix-vk-valve/PKGBUILD`) **sigue en `-1`**:
    es un `overlay` del centro, se reescribe al `sync-to-os.sh` (NO se edita a mano).
- **Que cambia `-5` ademas del numero** (comparado con el `-1` descargado, mismo commit `e07916b4`):
  - `.PKGINFO`: deps **identicas** (libdrm, wayland, libxshmfence, libelf, libdisplay-info, libglvnd,
    zstd, vulkan-icd-loader, lua, libconfig) → sin deps nuevas; listado de ficheros identico (124 entradas).
  - El binario **si cambia**: Turnip `.so` 18.850.752 B (`ec8e3510…`) → **18.857.136 B**
    (`6bed18a0…`, el del informe) — rebuild de Valve, no solo el `pkgrel`.
  - `DT_NEEDED` igual salvo **`libdisplay-info.so.1` → `libdisplay-info.so.3`**: con `-5` el payload
    pide directamente el soname que sirve ALARM (el alias `.so.1` del paquete sigue creandose, inocuo).
- **Comando de build corregido** (el flujo real esta en `BUILD.md` §3 y `docs/PRUEBAS-MESA.md` §7;
  `tools/sync-to-os.sh` vive en el CENTRO, NO en `pocknix-os` — la ruta de la tarea era erronea):
  ```
  cd /home/fransis/pocknix-odin3-project/pocknix-odin3-support
  ./tools/sync-to-os.sh && ./tools/check-sync.sh
  cd ../pocknix-os
  sudo DEVICE=sm8750 make packages PKG="pocknix-vk-valve"
  ```
- **Pendiente**: (1) compilar (comando de arriba); (2) publicar en R2; (3) medir **B7** (`-5` vs `-1`,
  el `-1` daba +13,4% en Dead Island).

### A4. FEX → 2610  🟡 PREPARADO (PKGBUILD bumpeado + parches verificados; NO compilado)
- ROCKNIX no lo "tiene": lo compila de **upstream FEX-Emu** → coger **FEX-2610** de upstream.
- Revisar tambien `fex-rootfs` (nuestro va en `20260108-9`).

**Hecho el 13/10/2026 (tarea A4, sin compilar — el PC esta ocupado con el build de A1):**
- **PKGBUILD bumpeado** en el arbol: `pocknix-os/packages/soc/fex-emu/PKGBUILD`
  (`_commit=e869aa64…` → **`14c92681f4d62cf84d901460e0358de09c8847a7`**, `pkgver` `2608.20260804.e869aa64`
  → **`2610.20261007.14c92681`**, `pkgrel` `3` → **`1`**).
- ⚠️ **El centro NO tiene copia del PKGBUILD de fex-emu**: solo `packages/soc-overrides/fex-emu/socs`
  (que ya lista `sm8750`, sin cambios). Como `sync-to-os.sh`/`check-sync.sh` solo transportan ese
  `socs` (bucle `packages/soc-overrides/*` → `packages/soc/*`), **el bump vive SOLO en el arbol** y
  **no hay que tocar los scripts de sync**. (Recomendacion futura: traer el PKGBUILD+parches de
  fex-emu al centro como override completo, para que queden versionados/vigilados aqui.)
- **Los 4 parches propios contra el tag `FEX-2610`** (`git clone --depth 1 --branch FEX-2610`):
  - `0001-fexcore-aarch64-workaround-llvm18-ice`: **REBASADO**. Upstream inserto un bloque
    `if (MINGW) … endif()` entre `target_link_libraries(FEXCore_Base …)` y
    `AddDefaultOptionsToTarget(…)` → el hunk viejo solo aplicaba con **fuzz 2** (y fallaba con
    `--fuzz=0`). Actualizadas SOLO las lineas de contexto (las 4 lineas insertadas son identicas);
    ahora aplica con **0 fuzz / 0 offset**.
  - `0002-split-thunk-build-thunkgen-only`: OK, **offset +39** (0 fuzz).
  - `0005-host-thunks-aarch64-char-signed-char`: OK, limpio.
  - `0006-thunkgen-march-armv8-sve`: OK, **offset −2** (0 fuzz).
  - Un `patch -p1` en orden (el comando exacto del `prepare()`) aplica los 4, rc=0.
- **Cambios upstream 2608→2610 que nos afectan**:
  - Minimo de clang **sin cambios** (`CLANG_MINIMUM_VERSION 13.0`).
  - Submodules pinneados que **cambian**: `External/vixl`, `External/fmt`, `External/rpmalloc`,
    `External/Vulkan-Headers` (el resto igual) — los baja `git submodule update --init --recursive`
    en `prepare()`, sin accion por nuestra parte.
  - Upstream anade un switch `BUILD_STEAM_SUPPORT` (**default OFF** → no cambia nuestro build) y en
    arm64 `TUNE_ARCH` pasa a `-march=<cpu>+crc` (nuestro `TUNE_CPU=cortex-a78` → `cortex-a78+crc`;
    clang lo soporta).
- **Comando de build listo** (NO ejecutado):
  ```
  cd /home/fransis/pocknix-odin3-project/pocknix-os && tools/sync-to-os.sh && sudo DEVICE=sm8750 make packages PKG=fex-emu
  ```
  ⚠️ `tools/sync-to-os.sh` hoy arrastra drift de OTROS trabajos (HDR, deckstation-arm, kernel…);
  el PKGBUILD de fex-emu no depende de eso (no lo toca el sync).
- **`fex-rootfs`**: sigue en `20260108-9` (de `rootfs.fex-emu.gg/ArchLinux/20260108/ArchLinux.sqsh`).
  El indice de ese servidor **NO es listable** desde aqui → para ver si hay rootfs nuevo hay que
  mirar la doc/releases de FEX a mano.
- **Pendiente**: (1) compilar el paquete (comando de arriba); (2) instalar en la Odin (nuevo `FEX` +
  thunks); (3) medir **FEX-2610 vs 2608** con juegos x86 (B7).

### A5. Paquetes del Deckard a EVALUAR (repo `holo-packages.steamos.cloud/archlinux-deckard-hotfixes/`)
- **`deckard-gamescope-layer-x86_64-3.16.30-4`** → capa gamescope WSI mas nueva (vamos con 3.16.29).
- **`deckard-mesa-linux-x86_64-…`** (+ `deckard-mesa-deps-x86_64`) → Mesa del lado **x86 (FEX)**;
  comparar con nuestro `pocknix-turnip-x86 20260904`.
- `deckard-steam-rel-…` → ver si el cliente Steam ARM64 es mas nuevo que el nuestro.
- Son aarch64 genericos pero **para Adreno 750** (el Frame); nosotros **830** → **verificar uno a uno**.
- (Patron bueno: como el `vk-valve`, meterlos como **payload seleccionable**, no reemplazando el sistema.)

### A6. ROCKNIX: `set default wifi country`
- `cb4b9e8e` — relacionado con nuestro problema de **regdom/DFS** (el AP en canal 116).

**Hecho el 13/10/2026 (tarea A6 — regdom permanente; sin compilar ni tocar la Odin):**
- **Kernel (`pocknix-os/kernel/sm8750/config/linux.aarch64.conf`, rama `odin3-sm8750`)**: solo
  `CONFIG_CFG80211=y→m` (l.1708) y `CONFIG_MAC80211=y→m` (l.1717); el resto de `CONFIG_CFG80211_*`
  /`CONFIG_MAC80211_*` **intacto** (grep previo: sin sorpresas; único driver WLAN `ATH12K=m`).
  md5 `c9a429f1…` → `92bfbf80…`. **`MAC80211=m` es imprescindible** (un módulo no puede depender
  de un built-in) y **cfg80211 como módulo** hace que el `85-regulatory.rules` de `wireless-regdb`
  se dispare en el arranque y cargue `regulatory.db` → dominio **ES**.
- **País en la imagen (mecanismo oficial)**: `.install` de **`pocknix-system-overlay`** →
  `_pocknix_set_wireless_regdom()` idempotente que fija `WIRELESS_REGDOM="ES"` en
  `/etc/conf.d/wireless-regdom` (activa/se descomenta/se añade) + llama a `set-wireless-regdom`.
  ⚠️ **NO como fichero del paquete**: ese fichero es propiedad de `wireless-regdb` (backup) y
  pacman daría conflicto duro (reproducido con fakeroot) → rompería build de imagen y `-Syu`.
- **Delta del kernel documentado**: `docs/KERNEL-CONFIG-DELTA-20261013.md` (líneas exactas, motivo,
  cómo re-aplicarlo tras `make sync` — ese fichero lo sobrescribe el sync y NO lo cubre
  `sync-to-os.sh`).
- **Pendiente**: compilar (`sudo DEVICE=sm8750 make kernel`), deploy, y verificar en la Odin
  (`dmesg | grep -i regulatory`, `iw reg get` → `country ES: DFS-ETSI`, `iw phy phy0 info` sin
  `(no IR)`).

### A7. VBoyColor como **core de libretro** (para DeckStation)  ✅ HECHO (13/10/2026)
- Paquete **`vboycolor-libretro`** creado (`packages/`, patron `suyu-libretro`, release fijada
  `v1.0.0-beta.11` + sha256 real) + ES-DE `virtualboy` (VBoy Color primero) y sistema propio
  **`virtualboycolor`** (ROMs en `vbc`) + registrado en `tools/sync-to-os.sh`/`tools/check-sync.sh`.
- Licencia **GPL-3.0** (redistribuible). Detalle en `docs/VBOYCOLOR-LIBRETRO-PENDIENTE.md`.
- **Pendiente**: probar con una ROM `.vb` real en la Odin.

### A8. DEKSTATION/limpieza y varios
- Borrar la carpeta duplicada `Apps/xenia_edge` (0 B) en la Odin.
- WProton: bajar un **runner de Proton** (las carpetas `proton-*` estan vacias).
- (Opcional) tirones por shaders: `docs/RENDIMIENTO-SHADERS-PENDIENTE.md`.

### A9. MAKO (issue #60) — el autor dio luz verde (10/10)
- Clonar el repo COMPLETO y `cmake -S engine -B build-aarch64` → **reportar el primer fallo concreto**
  (el autor dijo que eso ya es util y no hace falta portar todo).
- Los SPIR-V van checked-in; `glslangValidator` solo si se regeneran shaders.

## B. PROBAR (en la Odin)

### B1. Checklist del PR #135 (la prueba que bloquea el merge)
- [ ] **wifi** conecta y aguanta
- [ ] **audio** (altavoces + jack USB-C)
- [ ] **suspension** s2idle y vuelve
- [ ] **mandos** (gamepad UART + paddles)
- [ ] **rotacion en gamescope** (⚠️ parche NUEVO de rotacion inline: vigilar **pantalla negra** o **30 fps fijos**)
- [ ] **salida DP del dock**
- [ ] **bateria** (`/sys/class/power_supply`: valores coherentes)
- [ ] **arranques en frio con `POCKNIX_PANEL_WAIT=0`** (si el panel ya no prueba tarde, ese key se quita)

### B2. WProton 1.72
- [ ] primer arranque + **menu de diagnostico** (cuota API / estado umu)
- [ ] lanzar un juego real (tras bajar runner)

### B3. HDR
- [ ] arranca en **SDR** y el **QAM/MangoHUD quedan ENCIMA** del juego
- [ ] el toggle manual de PocknixControl lo activa

### B4. Red / energia
- [ ] **no vuelve el bucle** (ath12k `0041b`) tras un fallo de autenticacion del AP
- [ ] s2idle real (~0.37 W) y despierta bien

### B5. Tema Eclipse
- [ ] ofrece/actualiza a **0.3.2** y **conserva** `config_USER.json`

### B6. calvos-1.2 (SD de 128 GB)
- [x] ✅ instalacion inicial de DeckStation **31/31** con la API a 0 (12/10)
- [~] emuladores + ES-DE + **VBoyColor** — integracion HECHA (core + `virtualboy`/`virtualboycolor`
      en ES-DE, 13/10); **falta probar** con una ROM `.vb` real

### B7. Los bumps (A3/A4/A5): medir antes/despues
- [ ] **vk-valve `-5`** vs `-1` — FPS/frametimes con MangoHud (`DXVK_HUD=compiler`)
- [ ] **FEX-2610** vs 2608 — juegos x86
- [ ] capa gamescope x86_64 3.16.30 — composicion/rotacion/VRR

## D. ALIGERAR LA IMAGEN (revisar uno a uno)

Objetivo: que **cada build salga lo mas limpia posible** (menos peso, cero basura).

**HECHO YA ✅**: `tools/slim-rootfs.sh` (cache de pacman ~3,9 GB + firmware x86 ~630 MB +
`/usr/share/doc` ~173 MB) enganchado en `build-odin3.sh` **antes** de `make sd-image`.
Medido el 13/10: rootfs 22 GB -> ~17,3 GB. **USA `tools/build-odin3.sh`** para que corra.

| # | Idea | Ahorro | Estado | Riesgo |
|---|---|---|---|---|
| D1 | ⭐ **Steam duplicado**: `usr/share/steam` 4,1 GB vs `home` 3,3 GB -> **hardlinks** si son copias | ~3 GB | ⬜ comprobar | bajo si son copias |
| D2 | `usr/lib/libretro` 2,4 GB (256 cores): duplicados / variantes viejas | ~300-500 MB | ⬜ revisar | bajo |
| D3 | `locale` 464 MB -> dejar `es`/`en` | ~350 MB | ⬜ decidir | medio (idiomas) |
| D4 | firmware `qcom` 536 MB -> recortar a kaanapali/sm8750 | ~200-300 MB | ⬜ evaluar | medio |
| D5 | `man` 105 MB + `icons`/`fonts` 679 MB | ~400 MB | ⬜ evaluar | bajo-medio |
| D6 | modulos del kernel 360 MB -> quitar subsistemas ausentes | ~100-150 MB | ⬜ evaluar | alto |
| D7 | comprimir la imagen mas (btrfs `zstd:15` en vez de `zstd:1`) | 10-15% de **imagen** | ⬜ evaluar | bajo (mas lento) |
| D8 | firmware `ath11k` (la Odin usa **ath12k**) | 65 MB | ⬜ | bajo |
| D9 | no instalar los `linux-firmware-*` que no usamos (base.list) | evita D4/D5/D8 | ⬜ | bajo |
| D10 | `var/lib/pacman/sync` | 11 MB | ⬜ | nulo |

### Housekeeping de build (para que salgan limpias SIEMPRE)
- ✅ Usar **`tools/build-odin3.sh`** (engancha el slim automaticamente).
- ✅ **Clon nuevo**: copiar `build/localrepo/{sm8750,shared}` de un arbol ya construido
  (si no, `make packages` compila TODO bajo qemu -> horas).
- ⚠️ **NUNCA `chown -R`** sobre un directorio que contiene un chroot (rompe el setuid de `sudo`).
- ⚠️ Un `repo-add`/`makepkg` **matado a medias deja `.lck`** -> borrar `build/localrepo/*/*.lck`.
- ⚠️ **No usar `timeout`** en `make build`/`repo-add` (qemu tarda mucho).
- ⬜ Al terminar cada imagen: comparar `du -sh` por directorio vs la anterior (regresiones de peso).

## E. EL `overlay/` DEBE IR EN UN PAQUETE (bug SISTEMICO, 13/10/2026)

**Sintoma**: en la SD de 1 TB (imagen de junio + `-Syu`), el toggle de HDR de PocknixControl dice
*"el panel no reporta HDR"*; `xprop -root` da `GAMESCOPE_DISPLAY_SUPPORTS_HDR = 0`.
**Diagnostico**: faltan **6 de los 11 ficheros de `overlay/`**:
- `usr/share/gamescope/scripts/10-armada/ayn.icna3520.oled.lua` (perfil del panel -> HDR)
- `etc/udev/rules.d/60-ath12k-iommu-fq.rules`
- `etc/udev/rules.d/60-input-id2-odin3-gamepad.rules`
- `etc/udev/rules.d/61-gpio-paddles-no-joystick.rules`
- `usr/share/pipewire/pipewire.conf.d/99-pocknix-buffers.conf` (audio)
- `etc/xdg/baloofilerc`

**Causa raiz**: `overlay/` lo copia `build-sd-image.sh` -> **no es un paquete** -> un dispositivo ya
instalado **nunca lo recibe** con `-Syu`. Afecta a **todas** nuestras imagenes desde el principio.
*(Mitigado a mano en la 1TB el 13/10 copiando los 6 ficheros; falta el arreglo de verdad.)*

**Arreglo (correcto, por defecto)**:
1. **Empaquetar el overlay**: paquete nuevo `pocknix-system-overlay` (o meterlo en
   `pocknix-bsp-<soc>`) que instale `overlay/**` en `/`; `pocknix-bsp-sm8750` en `depends=` y publicar
   en R2 -> los dispositivos lo reciben con `-Syu`.
2. **Quitar del overlay** lo que ya entregue el paquete (que la imagen no lo copie dos veces).
3. **HDR por defecto**: decidir el diseno final:
   - volver a `STEAM_GAMESCOPE_HDR_SUPPORTED=1` (para que el panel reporte HDR y **el toggle funcione**), y
   - **sembrar el cliente Steam con HDR apagado** (`gamescope_hdr_enabled=0` en el `config.vdf` del seed)
     para arrancar en **SDR**.
   Estado actual: gate=0 -> **el toggle no funciona**; y `GAMESCOPE_DISPLAY_HDR_ENABLED=1` de todas formas
   -> HDR encendido. **Es el peor de los dos mundos.**
4. **Verificar** en la 1TB tras reiniciar la sesion: `xprop -root | grep HDR` -> `SUPPORTS_HDR=1` (OK el 13/10).

## C. HECHO (para no repetir)
- ✅ **calvos-1.2** publicada y grabada (SD 128 GB) — sha256 `316278ca…`
- ✅ **HDR off por defecto** + documentado · ✅ ath12k `0041b` + informe + PR #81
- ✅ **DeckStation sin API** (updater 15) publicado + subido a stshunz + **validado 31/31**
- ✅ **WProton 1.72** vendorizado + en la imagen + informe para stshunz
- ✅ **Tema Eclipse** 0.3.2 + servicio que ya actualiza
- ✅ README/presentacion (ES+EN) + LICENSE GPL-2.0 + topics

## F. CORES NUEVOS DE LIBRETRO (danprice142) — 13/10/2026

Fransis preguntó por 3 cores nuevos de libretro para ver si entran en DeckStation. **El trabajo está en la
rama `libretro`** de cada fork (no en la por defecto) y **los releases solo traen DLL de Windows x86-64**.
Análisis completo en la memoria (`~/.opencode_memory.md`, busca "3 CORES NUEVOS de libretro").

### F1. `xenia-edge-libretro` (Xbox 360) — ❌ **DESCARTADO**
Usa `third_party/xbyak` (JIT x86-64) y su `premake5.lua` filtra `architecture:x86_64` (con TODO para otras
arqs). **0 rutas arm64**. Xbox 360 en ARM no es viable. No volver a mirarlo salvo noticia del proyecto.

### F2. `xemu-libretro` (Xbox) — ✅ **HECHO como STANDALONE** (no como core)
- **El core de libretro está BLOQUEADO**: su `ui/libretro.c` es **Windows-only sin `#ifdef`** (eventos Win32
  `CreateEvent`/`SetEvent`/`WaitForSingleObject` + interop Vulkan `VkImportMemoryWin32HandleInfoKHR`).
  El **motor sí es portable** (se compiló hasta el 67% en host aarch64: todo QEMU/Xbox/nv2a). Portarlo sería
  un trabajo real (eventos POSIX + capa Vulkan Linux/DMA-BUF) y el autor solo publica Windows.
- **Solución adoptada: xemu STANDALONE**, que además es lo que ES-DE espera para el sistema `xbox`.
  **Integrado y funcionando**:
  - `stshunz/deckstation-arm` **`805d12f`** + centro **`24f440e`**: `staticpath ./Apps/Xemu/lanzar.sh` en la
    regla `XEMU`, los 4 ficheros de BIOS en `bios/required.txt`/`deploy-bios.txt`, docs.
  - **Odin**: `Apps/Xemu/` con `lanzar.sh` + AppImage aarch64 + `.home`; `lanzar.sh --version` →
    `xemu_version: 0.8.136-49-gf9b14039e5` ✅.
  - **Asset**: se instala por el **Updater** desde **PkgForge** (`pkgforge-dev/xemu-AppImage-Enhanced`), que
    publica `anylinux-aarch64.AppImage` (el scoring descarta `x86_64` y `OS_BAD` → **nunca** el
    `xemu-win-aarch64-release.zip` de upstream). Nota: upstream (`xemu-project/xemu`) **también** publica un
    AppImage aarch64 propio (`xemu-0.8.136-aarch64.AppImage`, probado a mano) — se eligió PkgForge por
    coherencia con el resto de AppImages de DeckStation.
  - **FALTA PROBAR con un juego**: hacen falta las 4 BIOS/ficheros de Xbox (los pone el usuario, copyright:
    `mcpx_1.0.bin`, `Complex_4627v1.03.bin`, `xbox_hdd.qcow2`, `xbox_eeprom.bin`) + un ISO (`.iso`).
    Sistema ES-DE: **`xbox`**, ROMs en `ROMs/xbox/`.

### F3. `RPCS3-Libretro` (PS3) — ❌ **CORE DESCARTADO** (decisión de Fransis, 13/10/2026)
- "Ya tenemos RPCS3 en nuestro sistema. Lo que te pasé era ver si podíamos tener ese **core de libretro**.
  **No se puede**, mantenemos solo nuestro RPCS3 standalone."
- Motivos técnicos (por si se retoma): RPCS3 upstream **no publica binarios** (0 assets) → habría que compilar;
  el `.info` del core pide **`OpenGL Core >= 4.3`**, está marcado **`is_experimental = true`** y
  **`libretro_saves = false`**; el backend `Emu/CPU/Backends/AArch64/` es pequeño (~400 líneas, parcial).
- **El standalone SÍ existe y ya lo tenemos**: en la Odin hay
  **`Apps/RPCS3/rpcs3-v0.0.42-19759-ffc50905_linux_aarch64.AppImage`** (80,4 MB, del 02/10) + su `.home` con
  `config.yml`. ⚠️ **Corrección**: la nota vieja "RPCS3 sin ARM" era **errónea**. Además ROCKNIX, para
  **SM8750**, usa `rpcs3-sa` (standalone) como única opción — igual que nosotros.
- Nuestro `es_systems.xml` ya tiene el sistema `ps3` (`%EMULATOR_RPCS3%`, `./Apps/RPCS3/rpcs3.AppImage`) y en
  el repo está la config de ROCKNIX (`configs/_externos/rocknix/rpcs3/`: `config.yml`, `Default.yml`,
  `CurrentSettings.ini`). **No hay nada que hacer aquí.**

### Nota sobre el punto 3 del bloque E (HDR)
El diseño **implementado el 13/10** es `pocknix-hdr-restore` (forzar el átomo a la preferencia guardada /
defecto **off**, con 2 pasadas), **no** el "sembrar el `config.vdf`". Verificado en la Odin: el átomo pasó de
**1 → 0** al arrancar el servicio. Detalle y corrección del doc del 11/10 en
`docs/HDR-OFF-POR-DEFECTO-2026-10-11.md`.
