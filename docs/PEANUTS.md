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
