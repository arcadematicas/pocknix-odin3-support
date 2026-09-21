# Updater de DeckStation — port a aarch64 (AYN Odin 3)

Actualizador de los AppImages de emuladores, con interfaz gráfica (pygame).
Vive en la Odin en **`/opt/deckstation/Apps/Updater/`**.

## De dónde viene

El Updater original es de la versión **x86_64** de DeckStation y estaba **solo en la
tarjeta de 1 TB** de la instalación vieja (`~/Downloads/deckstationARM/Apps/Updater/`).
Se rescató a `reference/deckstation-updater-x86/` del centro y se portó aquí.

| | x86_64 (original) | aarch64 (este port) |
|---|---|---|
| Python | portable x86_64, descargado con `curl` | **el del sistema** (`/usr/bin/python3`) |
| `git.txt` | URLs de releases x86_64 | **fuentes aarch64** (ver abajo) |
| Elección de asset | premia `x86_64`/`amd64` | premia **`aarch64`/`arm64`** y descarta el resto |
| pygame | `pip install` en el Python portable | paquete **`python-pygame-ce`** |

## Qué se cambió en `updater.py`

1. **Detección de arquitectura en runtime** (`platform.machine()`), para que el mismo
   código valga en la Odin (aarch64) y en un PC (x86_64). Define `ARCH_OK`, `ARCH_BAD`
   y `OS_BAD`.
2. **La puntuación de assets estaba al revés para ARM**: premiaba `x86_64`/`amd64` con
   `+5` (heredado del original de PC) → en la Odin bajaba el binario equivocado, que no
   arranca. Ahora premia la arquitectura propia (`+6`) y **descarta** (`continue`) los
   assets de la contraria y los de macOS/Windows/Android.
3. **`git.txt` acepta comentarios** (`#`): así se pueden dejar emuladores desactivados
   sin romper el emparejamiento nombre/URL.
4. **`git.txt` acepta URLs directas** (tipo `static`), para fuentes que no son un repo
   con releases — el caso del buildbot de RetroArch.

## `git.txt`: las fuentes aarch64

Se investigaron los releases reales de los emuladores. **30 tienen build Linux aarch64**
(los activos):

- **AppImages `anylinux-aarch64` de PkgForge**: Amiberry, ares, Azahar, BigPEmu, Cemu,
  ClownMDEmu, Dolphin, DosBoxPure, DOSBox-X, Dreamm, Duckstation, Flycast, MAME,
  MelonDS, mGBA, OpenMSX, PCSX-Redux, RMG, Ruffle, ScummVM, SkyEmu, Supermodel, Xemu,
  Ymir, ZSNES
- **Gitea (build propio ARM)**: Eden
- **Releases oficiales**: Vita3K, SnowboardKids2, PPSSPP (`anylinux-aarch64.AppImage`)
- **URL directa**: RetroArch (`buildbot.libretro.com/nightly/linux/aarch64/RetroArch.7z`)

**Los 16 que solo publican x86_64/macOS/Windows** quedan **comentados** en el `git.txt`
(listos para activar el día que publiquen aarch64): PCSX2, SUPER-ZSNES, RPCS3, Citron
(bloqueado por DMCA de Nintendo), Ryujinx, shadPS4, Xenia Edge, PrimeHack, Hypseus Singe,
UZDoom, GZDoom, OpenBor, Redream.

> **Ojo al investigar**: varios repos publican assets con `arm64` en el nombre que son
> **de macOS** (`MacOS-…-ARM64.dmg`). El updater los descarta por `OS_BAD`, pero al
> añadir fuentes nuevas conviene comprobar que el asset sea realmente de Linux.

## `python-pygame-ce`

pygame **no está en los repos de ALARM**, y el pygame clásico 2.6.1 solo publica wheels
hasta **cp313** mientras ALARM va por **Python 3.14**. `pygame-ce` es un fork *drop-in*
(instala el mismo módulo `pygame`) y **sí publica wheel `cp314` aarch64**, así que el
paquete se construye desde el wheel (como `python-pyxel`), sin compilar.

- `provides=('python-pygame')` → satisface la dependencia del paquete `deckstation-arm`.
- **Mantenimiento**: el nombre del wheel lleva la versión de Python (`cp314`). Si ALARM
  sube de 3.14 hay que actualizar `_wheel` y el `sha256` o el paquete no se construye.

## Auto-actualización de DeckStation: DESACTIVADA en ARM

El Updater original trae un botón **"Actualizar DeckStation"** que descarga un `payload/`
de una carpeta de MediaFire y lo aplica encima de la instalación (en `update/`, con
registro en `update/.installed/`).

**Esa carpeta (`1ixylxeqkr0wo`) es la del proyecto x86_64**, y su payload trae AppImages
y `.AppImage.home` de **x86_64**. Aplicarlo en la Odin **pisaría los emuladores ARM con
binarios x86_64**, que no arrancan.

Por eso en este port:
- `SYSTEM_UPDATE_ENABLED = False` → la opción **no se muestra** en el menú del Updater.
- `_check_system_update()` y `start_system_update()` tienen salvaguarda y no hacen nada.
- `MF_FOLDER_KEY` queda documentada por si algún día existe una carpeta con payload ARM:
  basta poner su clave y activar el flag.

De paso, el dibujado del menú se cambió de **índices fijos** (`idx == 1`) a **nombre de
acción**, porque al ocultar una opción los índices se desplazan y el badge/el tema
habrían aparecido en la fila equivocada.

## Dos papeles: INSTALADOR (headless) y CENTRO DE GESTIÓN (GUI)

El mismo motor sirve a dos puertas de entrada. La regla del proyecto es **el motor vive
en el script, la GUI va encima** — así una avería de pygame no te deja sin poder instalar
(y ya pasó: `SDL_VIDEODRIVER=x11` forzado dejaba la ventana invisible).

| | Quién | Qué hace |
|---|---|---|
| **INSTALAR** (una vez) | Pocknix Tools → `deckstation-setup.sh` | entorno + **los 30 emuladores** + configs + `lanzar.sh` + BIOS. Headless. |
| **GESTIONAR** (siempre) | Updater GUI (ES-DE → Updater) | actualizar, añadir/quitar emuladores sueltos, **estado de BIOS** |

### `updater.py --install-all` (modo headless)

Instala **todos** los emuladores que falten sin abrir ventana:

```bash
python3 /opt/deckstation/Apps/Updater/updater.py --install-all
```

- **`SDL_VIDEODRIVER=dummy` antes de importar pygame**: este módulo hace
  `pygame.display.set_mode()` al cargarse, así que sin driver válido falla con
  `pygame.error: No available video device`. Se fuerza solo en modo headless.
- **Reutiliza el mismo motor que la GUI** (`fetch_github_releases`, elección del asset
  aarch64, extracción, `_preparar_portable`): no hay dos lógicas de descarga que puedan
  separarse.
- Imprime progreso por emulador y un **resumen final** con los que fallaron.
- Devuelve **0** si todo fue bien y **1** si algo falló (lo usa el setup).
- Es **reejecutable**: lo que ya está instalado se salta (`scan_apps()`).

### Tolerancia a fallos de la cola

`_download_worker` es un **envoltorio** de `_descargar()`. Dentro de `_descargar()` hay
**13 salidas de error** que hacen `return` sin avisar a nadie; con 30 emuladores, uno que
fallara (repo parado, sin asset aarch64, 404…) **abortaba la cola entera**.

Ahora el envoltorio mira `self._descarga_correcta`: si el intento no la marcó, apunta el
nombre en `_install_fallidos`, suma el contador y **sigue con el siguiente**. El camino de
éxito avanza la cola por su cuenta (dentro de `_descargar`), así que no hay doble avance.
Al vaciarse la cola, el mensaje final dice cuántos entraron y cuáles fallaron.

### Pantalla BIOS (gestión)

En el hub del Updater hay una entrada **"BIOS / Firmware"** que muestra el informe de
`deckstation-bios.sh --check` (una fila por sistema: cuántas tienes, cuáles faltan y a
dónde va cada una) y con **A/Enter** las reparte. DeckStation **no incluye ni descarga
BIOS** (tienen copyright): ver `bios/README.md`.

## Cómo se lanza

```bash
/opt/deckstation/Apps/Updater/launcher.sh
```

Comprueba las dependencias y arranca `updater.py` con el Python del sistema.

## Verificado

En la Odin, con el código realmente desplegado:

- `pygame-ce 2.5.8` (SDL 2.32.10, Python 3.14.7) importa correctamente
- `IS_AARCH64 = True`, `ARCH_OK = ('aarch64','arm64','armv8')`
- `git.txt` carga **17 entradas**
- **15/15** repos de GitHub eligen el asset **aarch64** correcto
  (y descartan bien los de x86_64/macOS/Windows)
