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
