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

Se investigaron los releases reales de ~30 emuladores. **17 tienen build Linux aarch64**:

- **AppImages `anylinux-aarch64` de PkgForge**: Dolphin, Flycast, MAME, Supermodel,
  Cemu, DOSBox-Pure
- **Releases oficiales**: DuckStation (`DuckStation-arm64.AppImage`), PPSSPP, mGBA,
  Mesen (`Linux_ARM64.zip`), Xemu, Vita3K, melonDS, Ruffle, Amiberry, SnowboardKids2
- **URL directa**: RetroArch (`buildbot.libretro.com/nightly/linux/aarch64/`)

**Los 14 que solo publican x86_64/macOS/Windows** quedan **comentados** en el `git.txt`
(listos para activar el día que publiquen aarch64): RPCS3, Citron, shadPS4, Xenia Edge,
PCSX2, OpenMSX, RMG, PrimeHack, Hypseus Singe, UZDoom, GZDoom, OpenBOR, Redream.

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
