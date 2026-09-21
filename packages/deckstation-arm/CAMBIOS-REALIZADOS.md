# Cambios realizados en DeckStation ARM

Registro de los cambios de **portabilidad y saneado** hechos sobre la configuración
original, para que el proyecto funcione desde cualquier ruta y en cualquier
dispositivo ARM. Equivale al `.CAMBIOS_REALIZADOS.md` de la versión x86_64.

**Regla de oro**: nada de rutas absolutas. Todo lo que se pueda, relativo a la raíz
de DeckStation (`./Apps/...`) o al propio directorio de configuración (`../...`).

---

## 1. Saneado de rutas en las configuraciones

Muchas configs venían con rutas del equipo donde se configuraron por primera vez
(`/home/deck/...`, `/run/media/...`, `C:/users/...`). Se han convertido a relativas
o se han eliminado. El detalle fichero a fichero está en **`configs/README.md`**.

> **IMPORTANTE — qué es `configs/` y qué no**
> `configs/` es una **copia de referencia** (un snapshot versionado) de las configuraciones
> que se dejaron saneadas. **NO se despliega automáticamente**: el setup
> (`deckstation-setup.sh`) solo despliega los wrappers `lanzar.sh`
> (`deploy_lanzar_sh`); no hay ninguna función que copie `configs/` a los
> `.AppImage.home`. Cada emulador usa la configuración que tiene en su propio
> `.AppImage.home` (semi-portable: vive dentro de DeckStation, no en el `$HOME`).
>
> Sirve por tanto para **consultar y restaurar**: si un emulador queda mal
> configurado, aquí está la versión conocida-buena. Para aplicarla hay que copiarla a
> mano a su `.AppImage.home`.
>
> **Cómo se despliega de verdad**: el **Updater** (`Apps/Updater/`) tiene un
> auto-actualizador de DeckStation que descarga un `payload/` desde una carpeta de
> **MediaFire** (`update/`, con `.installed/` como registro de lo ya aplicado). Ese
> payload trae los emuladores **con sus `.AppImage.home` ya configurados** — es el
> mecanismo real de distribución de configuraciones, no `configs/`.
> `update_dir = <raíz DeckStation>/update`.
>
> ⚠️ **En ARM está DESACTIVADO**: esa carpeta de MediaFire es la del proyecto **x86_64** y
> su payload pisaría los emuladores ARM con binarios x86_64. Ver `updater/README.md`.

| Emulador | Fichero | Qué se cambió |
|---|---|---|
| **PPSSPP** | `ppsspp/ppsspp.ini` | `CurrentDirectory` → `./` (antes absoluta al equipo del autor) |
| **Citron** | `citron/qt-config.ini` | `nand_directory`, `sdmc_directory`, `load_directory`, `dump_directory`, `tas_directory` → relativas (`../../.local/share/citron/...`). Paths de ROMs del usuario eliminados. |
| **Azahar** | `azahar/qt-config.ini` | `nand_directory`, `sdmc_directory`, `screenshots` → relativas (`../../.local/share/azahar-emu/...`) |
| **Dolphin** | `dolphin/dolphin.ini` | Eliminado `ISOPath1` (apuntaba a ROMs del usuario). Eliminados los restos de la versión **Windows**: `BIOS` y `SavesPath` (`C:/users/steamuser/AppData/...`) vaciados y `ISOPath0 = H:/Downloads/Triforce` borrado (`ISOPaths` 2 → 1). |
| **PCSX2** | `pcsx2/pcsx2.ini` | Eliminado `RecursivePaths` (ROMs del usuario). `Textures` → `../textures` (relativa al directorio del config; antes era relativa al directorio de trabajo, que es frágil) |
| **DOSBox Pure** | `dosboxpure/DOSBoxPure.cfg` | `interface_contentpath` → `./ROMs/dos` |
| **AntiMicroX** | `antimicrox/antimicrox_settings.ini` | Paths de perfiles → relativos |
| **DuckStation** | `duckstation/qt.conf` | Plugins relativos (`./QtPlugins`) |
| **RetroArch** | `retroarch/retroarch.cfg` | `savefile_directory`, `savestate_directory`, `screenshot_directory`, `log_dir` → `~/.config/retroarch/...`. `core_updater_buildbot_cores_url` apuntando al buildbot **aarch64**. |
| **ES-DE** | `es-de/settings/es_settings.xml` | Sin paths hardcodeados |
| **ES-DE (systems)** | `es-de/custom_systems/es_find_rules.xml` | Apunta a los wrappers `./Apps/*/lanzar.sh` y a las rutas de cores dentro de los `.AppImage.home` |
| **Flycast** | `flycast/emu.cfg` | Ya era limpia |
| **RMG** | `rmg/mupen64plus.cfg` | Rutas `./Apps/RMG/...` (relativas a la raíz, funcionan con el `lanzar.sh`) |
| **Vita3K, ZSNES, Supermodel** | — | Sin rutas problemáticas |

**Comprobación**: `grep -rnE "[A-Za-z]:[/\\\\]|AppData|steamuser" configs/` no debe
devolver nada (salvo URLs `http://`).

---

## 2. Wrappers `lanzar.sh` por emulador

Cada emulador tiene su `Apps/<Emulador>/lanzar.sh` que:

- Limpia las variables del AppImage (`APPIMAGE`, `APPDIR`, `OWD`).
- Redirige `HOME` al `.AppImage.home` del emulador, de forma que sus configs, saves
  y logs quedan **dentro de DeckStation** y no en el `$HOME` del usuario.
- Fuerza `SDL_VIDEODRIVER` para que funcione bajo gamescope/Game Mode.

Así los emuladores son portables: mover la carpeta de DeckStation a otro dispositivo
no rompe nada. **No hay que tocar los `lanzar.sh` para arreglar rutas**: eso se hace
en las configs del punto 1.

---

## 3. Centralización de saves y logs

`scripts/deckstation-launcher.sh` crea en cada arranque la estructura centralizada y
los symlinks de compatibilidad:

```
saves/                       logs/
├── retroarch/               ├── retroarch/
│   ├── saves/               └── pcsx2/
│   ├── states/
│   └── screenshots/
├── duckstation/
│   ├── savestates/
│   ├── screenshots/
│   └── memcards/
└── pcsx2/
    ├── memcards/
    ├── sstates/
    └── snaps/
```

En la raíz se crean los symlinks `Logs → logs` y `Saves → saves`, porque algunos
emuladores escriben en el directorio de trabajo. Dentro de cada `.AppImage.home` se
redirigen los directorios reales a estos centralizados.

**Motivo**: hacer copia de seguridad de las partidas es copiar una sola carpeta.

---

## 4. Lanzador portable

- **`DeckStation.sh`** (x86_64) / **`scripts/deckstation-launcher.sh`** (ARM): calculan
  la raíz de DeckStation dinámicamente, así que funcionan desde cualquier ubicación.
  No hay que ejecutar el AppImage directamente.
- **`/usr/bin/deckstation`**: comando del sistema que llama al lanzador.

---

## 5. Updater (actualizador de AppImages)

Portado a aarch64 desde la versión x86_64. Vive en `updater/` y se instala en
`/opt/deckstation/Apps/Updater/`. Detalle completo en **`updater/README.md`**.

- `updater.py`: lee `updater/git.txt`, consulta los releases (GitHub/GitLab/Gitea),
  con caché de 30 min, escáner en segundo plano, temas y backup antes de actualizar.
- **Detección de arquitectura en runtime**: el mismo código sirve en aarch64 y x86_64.
  La elección de asset premia la arquitectura propia y **descarta** la contraria y los
  binarios de macOS/Windows.
- `git.txt`: fuentes **aarch64** (17 emuladores con build Linux ARM). Los que solo
  publican x86_64 quedan comentados y listos para activar.
- `launcher.sh`: usa el Python del sistema, no un Python portable descargado.

---

## 6. Notas para el creador

- Los ficheros modificados de cada emulador tienen su backup en
  `.backup-configs-20260624_182554/` (en la instalación de origen).
- **No se han tocado** los emuladores que ya usaban rutas relativas correctamente.
- El saneado se hace **solo en los ficheros de configuración**, nunca en los binarios
  ni en los AppImage.
- Para añadir un emulador nuevo: crear su `lanzar.sh`, su config saneada en `configs/`
  y documentarlo en `configs/README.md`.
- **Pendiente/decidir**: `configs/` es hoy solo referencia. Opciones: (a) dejarlo como
  snapshot documentado, (b) hacer que el setup lo despliegue de verdad (copiar cada
  config a su `.AppImage.home` tras descargar el emulador), o (c) eliminarlo si se
  considera ruido. Además, `deckstation-setup.sh` declara `CONFIGS_DIR` y **no lo usa**
  (variable muerta): limpiar si se opta por (a) o (c).

---

## 7. Core de Suyu para Nintendo Switch (RetroArch)

El sistema `switch` de ES-DE ofrece como **primera opción** el core de libretro de **Suyu**
(fork de Yuzu), antes que los standalone (Yuzu, Eden, Ryujinx, Citron):

```xml
<command label="Suyu (RetroArch)">%EMULATOR_RETROARCH% -L %CORE_RETROARCH%/suyu_libretro.so %ROM%</command>
```

- El core está en el código de Suyu: `src/libretro_core/`
  (`github.com/suyu-emu/suyu-v0.0.4` — el mirror oficial tras el DMCA de Nintendo).
- Se compila con `-DSUYU_BUILD_LIBRETRO_CORE=ON -DENABLE_QT=OFF`.
- **⚠️ No hay build aarch64 publicado** (el release solo trae `linux-x64`): hay que compilarlo.
  En aarch64 el emulador ejecuta el código ARM de la Switch **de forma nativa, sin traducción**,
  así que rinde mejor que en x86_64.
- **⚠️ Con GCC 16** hace falta `-DCMAKE_CXX_FLAGS="-Wno-maybe-uninitialized"`: da un falso
  positivo en `cheat_engine.cpp:221` que, con `-Werror`, aborta el build.
- Metadatos del core: `configs/retroarch/cores/suyu_libretro.info`.
- El core va en el directorio portable de cores de RetroArch
  (el mismo que resuelve `%CORE_RETROARCH%`).

> Verificado en una AYN Odin 3 (aarch64, GCC 16.1): compila y el `.so` resultante carga
> correctamente (165 librerías resueltas, símbolos libretro exportados).

**Regresión corregida (17/09/2026):** el commit `c39d880` ("activar los 27 emuladores
standalone") borró por error el `<command>` de Suyu del `es_systems.xml`. Restaurado.
También se añadió **GooseStation** (core de PSX) como primera opción del sistema `psx`;
el core ya estaba copiado pero ES-DE no lo conocía porque no había `<command>` que lo
referenciase.

**⚠️ Las claves de Switch van en `<system_dir>/suyu/keys/`.** El core las busca ahí
(no en la raíz de `system/`). Sin ellas el cifrador AES queda sin inicializar y el core
revienta con asserts en `core/crypto/aes_util.cpp` ("Failed to set IV on OpenSSL
contexts"). Con `prod.keys` + `title.keys` en su sitio, carga y arranca.

**🌐 Idioma (parche propio).** El core de serie **no expone opción de idioma** y **no lee
ningún fichero de config** (no usa `Config`; el `qt-config.ini` es del frontend Qt, que en
el core no existe) → `language_index` se quedaba en su default
(`Settings::Language::EnglishAmerican`) y **todos los juegos salían en inglés**.

`packages/suyu-libretro/suyu-language.patch` (solo `retro_core.cpp`, ~25 líneas) añade la
core option **`suyu_language`** y la aplica donde el core ya aplica las demás (*"Apply core
options before loading the game"*):

> RetroArch → **Opciones del core → Suyu → Console Language → Spanish**

Valores: `EnglishAmerican` (default), `Spanish`, `SpanishLatin`, `French`, `German`,
`Italian`, `Japanese`, `Korean`, `Dutch`, `Portuguese`, `Russian`, `ChineseSimplified`,
`ChineseTraditional`, `Polish`, `Thai`. En el enum de Suyu, `Spanish` = índice 5.

El rebuild es **incremental** (un fichero + link ≈ 20 s) porque el parche solo toca
`retro_core.cpp` y los idiomas se mapean por string (sin tocar `settings_enums.h`).


---

## 8. Despliegue de la configuración base (`deckstation-configs.sh`)

Antes `configs/` era **solo una copia de referencia**: el despliegue real lo hacía el
Updater con un `payload/` de MediaFire (x86_64), así que en ARM había que copiar todo a
mano y una instalación nueva quedaba sin configurar (ES-DE sin sistemas, RetroArch con la
config de fábrica).

- **`configs/deploy-manifest.txt`** — mapa `config → destino real`, con el token
  `{HOME:NombreApp}` que resuelve al `.home` de cada emulador.
- **`scripts/deckstation-configs.sh`** — aplica el manifiesto. **No destructivo**
  (solo copia lo que falta; `--force` resetea, `--dry-run` simula). Resuelve el `.home`
  con la misma lógica que `lanzar.sh` (existente → derivado del AppImage → árbol
  extraído) y **crea los directorios que falten**, así que funciona en instalaciones
  nuevas, antes de que el emulador se haya ejecutado nunca.
- **Invocado por** `deckstation-setup.sh` (al instalar) y `deckstation-launcher.sh`
  (en cada arranque, como auto-reparación barata: es no-op cuando ya está todo).
- El PKGBUILD hace `chmod -R a+rX` en `configs/`: se construye como root y
  `duckstation.ini`/`settings.ini` quedaban en modo 600, ilegibles para `deck`.

## 9. BIOS y firmware (`deckstation-bios.sh`)

Las BIOS tienen copyright: no se pueden incluir. Solución externa:

- **`bios/`** con una subcarpeta por sistema (`psx`, `ps2`, `dreamcast`, `saturn`,
  `segacd`, `pcecd`, `3do`, `neogeo`, `msx`, `switch`, `3ds`, `misc`).
- **`bios/README.md`** — qué ficheros necesita cada sistema (con los nombres exactos que
  esperan los emuladores) y qué sistemas no necesitan BIOS.
- **`bios/deploy-bios.txt`** — manifiesto: PSX → `system/` de RetroArch **y**
  `bios/` de DuckStation; Dreamcast → `system/dc/`; claves de Switch → `system/suyu/keys/`;
  3DS → sysdata de Azahar; etc.
- **`scripts/deckstation-bios.sh`** — reparte (reutiliza el motor de
  `deckstation-configs.sh` vía `--from/--manifest/--label`). Se ejecuta también en cada
  arranque desde el launcher.
- Los ficheros reales **no se versionan** (`.gitignore`), solo README, manifiesto y
  carpetas.

## 10. RetroArch: driver de vídeo y tema

- **`video_driver` `vulkan` → `glcore`.** El Vulkan libre (Turnip/freedreno) en
  **Adreno 8xx / Gen8** (Odin 3, Adreno 830) relentiza la imagen; es un problema del
  driver, no de RetroArch. `glcore` (OpenGL) es el workaround.
- **`menu_driver` `ozone` → `xmb`** + **`xmb_theme = "flatux"`**, para que el menú use
  iconos y no se vea "de serie".
- **Requiere los assets de RetroArch** en `<retroarch>/assets/xmb/<tema>`. No van en
  git (82 MB): `deckstation-setup.sh` los baja solos del buildbot
  (`buildbot.libretro.com/assets/frontend/assets.zip`, ~75 MB) a la carpeta portable de
  assets.

**⚠️ Core options ≠ Overrides.** Son dos sistemas distintos y es fácil confundirlos: si al
guardar sale *"[Override] No hay nada que guardar. No se han guardado las
personalizaciones"*, se está usando **Overrides** (Quick Menu → Overrides), que **no** guarda
las *core options*. Las core options (idioma, resolución, docked…) se guardan en
**`<retroarch>/config/<corename>/<corename>.opt`** (formato `clave = "valor"`) y se
persisten con *Settings → Core → Manage Core Options → Save Core Options* (o al salir, con
`config_save_on_exit = "true"`). **Se pueden escribir a mano** y RetroArch las lee al cargar
el core — útil para dejar opciones puestas sin pelear con los menús. No es un problema de
permisos: el árbol de RetroArch es `deck:deck` y escribible.

## 11. Setup y cores del sistema

### `deckstation-setup.sh` — ya no baja el RetroArch de Android
Descargaba `RetroArch_ra32.apk` (binario **Android** 1.19.1) y lo descomprimía en
`Apps/RetroArch/`: en una instalación limpia eso **rompe RetroArch**, y es justo el script
que ejecuta Pocknix Tools. Ahora el setup prepara el entorno portable y deja los
emuladores al **Updater** (el que mantiene `updater/git.txt`):

1. `setup_retroarch_assets` — baja `assets.zip` del buildbot (~75 MB: iconos del menú XMB).
2. `deploy_system_cores` — llama a `deckstation-cores.sh`.
3. `deploy_lanzar_sh` — wrappers portables por emulador.
4. `deploy_configs_and_bios` — configs base + BIOS.
5. `install_emulators` — abre el Updater (o indica cómo, si no hay display).

### `deckstation-cores.sh` — cores empaquetados → carpeta portable
Los paquetes de Pocknix instalan sus cores en las rutas estándar
(`/usr/lib/libretro/*.so`, `/usr/share/libretro/info/*.info`), pero RetroArch de
DeckStation es **portable** y busca en `<retroarch home>/.config/retroarch/cores/`. El
script **enlaza** (symlink) lo que haya en las rutas estándar dentro de la carpeta
portable, así cualquier core que empaquetemos aparece en ES-DE solo. No destructivo.
Lo llaman el setup y el launcher.

## 12. DeckStation en el modo juego de Steam

Para poder **entrar a DeckStation desde Game Mode** hay que meter un acceso no-Steam en
`shortcuts.vdf`. El mecanismo ya existía en Pocknix: `pocknix-steam` llama a
**`pocknix-steam-sync` justo antes de arrancar Steam** — el único momento seguro, porque
Steam reescribe `shortcuts.vdf` al salir.

**El script estaba muerto en esta imagen**: era de la capa de emulación de upstream
(buscaba `~/ES-DE/gamelists` y `/usr/bin/pocknix-play`), que **no instalamos** — no
encontraba nada y el tile nunca aparecía. Ahora apunta a DeckStation:

- Emite **`DeckStation` → `/usr/bin/deckstation`**, con `StartDir=/opt/deckstation` y el
  icono `DeckStation.png` si existe.
- **Idempotente**: marca `DevkitGameID="pocknix"` y cada pasada reemplaza **solo ese
  subconjunto**, así que los accesos del usuario sobreviven.
- Los accesos **por juego** (favoritos) están implementados pero **inactivos**: necesitan
  un `/usr/bin/deckstation-play` que aún no existe (haría falta resolver el emulador de
  cada sistema desde `es_systems.xml`).

**⚠️ Y hacía falta un fix previo**: el launcher de DeckStation **no fijaba
`SDL_VIDEODRIVER`**, y ES-DE lanzado desde gamescope se quedaba en **negro** (SDL
"Device or resource busy" si hereda el driver equivocado). Ahora el launcher lo fija al
compositor disponible (wayland o x11), igual que `lanzar.sh` con los emuladores. **Sin
este fix, el tile arrancaría a negro.**

## 13. Gaps conocidos (pendientes)

1. **Core de Suyu en la imagen**: el paquete `suyu-libretro` ya está en el árbol y
   `build-image.sh` lo instala como **opcional** (`for oe in suyu-libretro`, con
   warn-on-fail) + `deckstation-cores.sh` lo enlaza a la carpeta portable. **Ojo**: se
   compila desde fuente (submódulos + cmake) → build pesado; si falla, la imagen sale sin
   el core de Switch.
2. **Core GooseStation**: compilado a mano, sin paquete ni entrada en `updater/git.txt`.
   → Decidir cómo distribuirlo (su licencia es CC-BY-NC-ND y prohíbe redistribuir).
3. **Vita3K**: no es AppImage (es un `.7z` extraído) y no tiene `.home`, así que ni es
   portable ni se le despliegan configs. → Revisar.
4. **PCSX2**: sin build ARM, su entrada del manifiesto se omite (best-effort).
5. **`setup_arm64_apps.py`: RETIRADO (18/09).** Era un instalador headless con la lista de
   repos hardcodeada y **sin conectar al flujo** (nadie lo llamaba); el **Updater**
   (`updater/git.txt`) es el único mecanismo de descarga. Al retirarlo se migró **PPSSPP**
   a `git.txt` — **sí publica `anylinux-aarch64.AppImage`** en su repo oficial (la nota
   "sin build ARM" era falsa). **Mesen** y **Redream** se descartaron: no hay build Linux
   ARM limpio / el repo no existe en GitHub, y sus sistemas ya los cubren cores de
   RetroArch. PSP ya funcionaba con el core `ppsspp_libretro.so`; el standalone queda como
   segunda opción del sistema `psp`.


