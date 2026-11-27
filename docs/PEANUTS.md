# Peanuts (Switch nativo en ARM) — estado 27/11/2026

## Qué es

`igawa6/peanuts-native` es un **runner nativo** de juegos de Switch para ARM (no un emulador
clásico): reescribe el NSO, implementa Horizon por HLE y traduce NVN a Metal (Apple) o Vulkan
(Linux/Android). El **PR #130** de `titooo7` añade el **host Linux aarch64 + AppImage** para
handhelds ARM (probado en una Odin 2 Pro: *Super Mario Bros. Wonder* y *Metroid Dread* a 60 fps).

## Lo que tenemos montado (Odin 3)

- AppImage construido por nosotros desde la rama del PR (`titooo7/pr-linux-appimage`, head
  `71562611`) con Docker cross en el sobremesa (~5 min):
  `~/Peanuts/PeanutsNative.AppImage` (20,5 MB).
- **`--selftest` pasa entero en Turnip** (fence, texturas, draw, compute, mip, 60 frames, 0 pipelines
  fallidos).
- `--list`: **167 títulos** con host compilado.
- **Keys**: `prod.keys` copiadas a `~/.switch/prod.keys` y `~/.config/peanutsnative/keys.path`
  apuntando ahí (el launcher también las pide en la ventana si faltan).
- **Acceso en Plasma**: `~/.local/share/applications/peanutsnative.desktop` (`Categories=Game;`).
- **Acceso en Steam (modo juego)**: atajo no-Steam `PeanutsNative` en `shortcuts.vdf`
  (lanzador; los juegos preparados se añaden con `--steam`).

## Cómo se construye (para actualizar)

```bash
git clone --branch pr-linux-appimage https://github.com/titooo7/peanuts-native.git
cd peanuts-native
./peanuts/linux/build-appimage.sh        # Docker cross (linux/Dockerfile), SDL3 y host
# → linux/build/appimage/PeanutsNative-<ver>-aarch64.AppImage
```

Sin Docker, el host se puede compilar en la propia consola siguiendo `linux/build.sh` y
`peanuts/linux/build-appimage.sh` (necesita cmake/ninja/clang, cabeceras Vulkan y SDL3).

## Requisitos en la consola (lo que faltaba y por qué no abría)

El `AppRun` del AppImage es exigente y falla **en silencio** si falta algo:

- **`zenity`** (`extra/zenity`): sin él `GUI=0` y el icono solo imprime el uso. Instalado.
- **PyQt6** para el `python3` del sistema: el launcher Qt solo se abre si `python3 -c "import PyQt6.QtWidgets"`
  funciona. El `python-pyqt6` del repo (6.12.1) no carga contra nuestro Qt 6.12.0
  (`undefined symbol: QMenu::resizeEvent`), así que hay una **venv autocontenida** en
  `~/Peanuts/venv` (`pip install PyQt6`, trae su propio Qt) y se pasa por `PYTHONPATH`.
- **`xcb-util-cursor`** y **`qt6-wayland`**: sin el primero, el plugin `xcb` de Qt no carga; con el segundo
  el launcher va por Wayland.
- **`spirv-val`** (`extra/spirv-tools`): lo necesita la preparación.
- **Python 3.12+**: la Odin tiene 3.14.10.
- Los juegos se leen de **`~/Games`** (también medios extraíbles). El `.xci` puede estar enlazado desde
  `~/Peanuts/games`.

Todo eso queda encapsulado en **`~/Peanuts/peanutsnative.sh`**, que es lo que lanzan el `.desktop` de
Plasma y el atajo de Steam:

```sh
#!/bin/sh
export PATH=/usr/local/bin:/usr/bin:/bin
export PYTHONPATH=/home/deck/Peanuts/venv/lib/python3.14/site-packages
[ -n "$WAYLAND_DISPLAY" ] && export QT_QPA_PLATFORM=wayland
exec /home/deck/Peanuts/PeanutsNative.AppImage "$@"
```

## Cómo se juega

1. Abrir **PeanutsNative** (Plasma o Steam).
2. Elegir `prod.keys` si lo pide (ya está configurado).
3. Seleccionar el `.xci`/`.nsp`; el launcher descarga el árbol fuente del commit, empaqueta el juego
   (`.nup` en `~/Games/PeanutsNative`) y lo deja listo.
4. Lanzar desde el propio launcher. Los juegos preparados se pueden añadir a Steam con
   `PeanutsNative.AppImage --steam` (con Steam cerrado).

**Compatibilidad**: solo títulos presentes en `--list`. En el disco de Fransis hay copias de SMO,
MK8D, TotK, BotW, Pokémon Diamante Brillante/Escarlata y Super Mario RPG; varios están en la lista.

## Notas

- Es un **PR abierto**, no una release: al actualizar, revisar que el rebase siga aplicando y
  reconstruir.
- Nada de esto va al sistema ni a DeckStation: vive en `~/Peanuts` y sus carpetas de usuario.
- Vigilancia: `tools/watch-peanuts.py` (release, PR #130 e issue #3250 de `seedds/nxnative`).

## Mando en la Odin 3 (inputplumber) — 27/11/2026

Síntoma: Peanuts detecta el mando (`AYN Odin3 Gamepad` como jugador 1) pero el juego no
responde a ningún botón.

Causa: en la Odin, **inputplumber** captura el mando físico (`2020:3001`, `event6`) y solo
entrega eventos por su **Xbox 360 virtual** (`045e:028e`). Peanuts veía los dos, asignaba el
físico (sin eventos, capturado) como jugador 1 y el virtual como jugador 2; el juego lee al
jugador 1.

Solución: decirle a SDL que ignore el físico, en el wrapper de Peanuts:

```sh
export SDL_GAMECONTROLLER_IGNORE_DEVICES=0x2020/0x3001
```

y, para toda la sesión (cualquier app SDL), en `~/.config/environment.d/10-calvos-gamepad.conf`:

```
SDL_GAMECONTROLLER_IGNORE_DEVICES=0x2020/0x3001
```

Comprobación sin abrir el juego (SDL del sistema, el mismo que usa Peanuts):

```bash
python3 - <<'PY'
import ctypes
s = ctypes.CDLL("libSDL3.so.0")
s.SDL_InitSubSystem(0x2000)
n = ctypes.c_int(0)
ids = s.SDL_GetGamepads(ctypes.byref(n))
print("mandos:", n.value, [s.SDL_GetGamepadNameForID(ids[i]) for i in range(n.value)])
PY
# sin filtro: 2 (AYN + Xbox virtual); con el filtro: 1 (Xbox virtual)
```

En modo juego, Steam añade su propio pad virtual y su lista de ignorados: si Peanuts no
respondiera ahí, desactivar Steam Input **solo** para el atajo de Peanuts.

## Integración en CalvOS (estado 27/11/2026)

| Pieza | Dónde | Nota |
|---|---|---|
| AppImage (host aarch64 del PR #130) | `~/Peanuts/PeanutsNative.AppImage` | Construido por nosotros (no hay release) |
| Herramientas del packer | `~/.local/share/peanutsnative/packer/` | Se descargan solas en el primer Prepare (~130 MB + .NET) |
| `.nup` + pack del juego | `~/Games/PeanutsNative/` | Por juego; el pack en `packs/<titleID>/` |
| Lanzador con entorno | `~/Peanuts/peanutsnative.sh` | `PYTHONPATH` (PyQt6), Wayland y el filtro SDL del mando |
| Entrada de Plasma | `~/.local/share/applications/peanutsnative.desktop` | La reescribe el `--install` de Peanuts: apunta al AppImage, no al wrapper |
| Atajo de Steam | `shortcuts.vdf` (nombre `PeanutsNative`) | Exe = wrapper; LaunchOptions vacío |
| Entorno de sesión | `~/.config/environment.d/10-calvos-gamepad.conf` y `/etc/environment.d/10-calvos-gamepad.conf` | El de `/etc` lo instala `calvos-peanuts`; `SDL_GAMECONTROLLER_IGNORE_DEVICES=0x2020/0x3001` |

Paquetes que necesita (dependencias de `calvos-peanuts`, y también en `devices/sm8750/packages.list`
para que estén en la imagen): `zenity` (selector de reserva y diálogos del AppRun), `spirv-tools`
(`spirv-val` para la preparación), `xcb-util-cursor` (plugin xcb de Qt) y `qt6-wayland`. Python 3.12+
(la Odin tiene 3.14).

Paquete: `packages/calvos-peanuts` instala `/usr/local/bin/peanutsnative`, la entrada de menú, el
icono y `/etc/environment.d/10-calvos-gamepad.conf`. El **AppImage no va dentro** (se construye con
`tools/peanuts-build.sh`), así que actualizar Peanuts es reconstruir el AppImage, no el paquete.

**PyQt6**: el launcher solo se abre si `python3 -c "import PyQt6.QtWidgets"` funciona. El
`python-pyqt6` del repo puede no casar con el Qt del sistema; la vía que usamos es PyQt6 de pip
autocontenido:

```bash
sudo python3 -m pip install --break-system-packages PyQt6
# o, aislado:  python3 -m venv ~/Peanuts/venv && ~/Peanuts/venv/bin/pip install PyQt6
```

Si el import falla, el AppRun cae al selector zenity (funciona, pero sin ventana de juegos).

## Compatibilidad de juegos

Peanuts solo puede preparar un dump si la **versión del update** del `.xci`/`.nsp` coincide con una
build del perfil `dm/games/<titleID>/game.tsv`. Herramienta:

```bash
tools/peanuts-roms.py /ruta/a/roms/switch     # en la consola (o con el disco por sshfs)
# GB  VERS  PERFIL  ID  NOMBRE   (VERS=OK → preparable tal cual)
```

Necesita el AppImage extraído (`--appimage-extract` en `~/Peanuts/appdir`, usa su `nximport_cli`) y
las `prod.keys`. Con `--any-version` (a mano en `peanuts_build.py`) se puede forzar otra versión,
pero el perfil está afinado para la suya y fallará o se verá mal.

## Actualizar Peanuts (runbook rápido)

1. **Aviso**: `tools/watch-peanuts.py` (timer 09:00) vigila release, PR #130 y comentarios.
2. **Construir** (PC con Docker, ~5 min tras la primera vez):
   ```bash
   tools/peanuts-build.sh --ref pr-linux-appimage --deploy deck@192.168.4.22
   ```
   Guarda el anterior como `PeanutsNative.AppImage.bak`, copia el nuevo y corre `--selftest`.
3. **Validar**: selftest OK; `--list` (nº de hosts); abrir el launcher (Qt, no zenity); un juego ya
   preparado; mando; rendimiento.
4. **Rollback**: restaurar `PeanutsNative.AppImage.bak` (y `.desktop`/wrapper si cambiaron).
5. **Si el PR se fusiona en `igawa6/peanuts-native`**: `--ref main` y revalidar; actualizar
   `docs/UPSTREAM-TRACKER.md` y `CHANGELOG.md`.
6. **No** hace falta re-preparar los juegos al actualizar el AppImage (los packs no cambian salvo que
   Peanuts lo diga); sí conviene probar uno.

## Límites conocidos

- Solo Linux **aarch64** (Odin 3, handhelds ARM). En x86 no hay host Linux.
- Cada juego se prepara con las `prod.keys` del usuario y ocupa 5-20 GB (`.nup` + pack + shaders).
- La preparación tarda 10-40 min (shaders). La primera vez descarga herramientas (~130 MB + .NET).
- Sin HDR; vídeo Vulkan (Turnip). El motor de FG de MAKO no interviene aquí.
- Los packs llevan el juego descifrado: no se distribuyen.
