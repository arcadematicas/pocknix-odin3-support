# VBoyColor como **core de libretro** para DeckStation — PENDIENTE (anotado 12/10/2026)

## El cambio
El **11/10** descartamos VBoyColor (`yuk27/VBoyColor`, emulador de **Virtual Boy en color**) porque
**no era core de libretro ni AppImage** (era app CMake + Android) → "si no es portable no lo podemos
incluir en la coleccion de DeckStation".

**Eso ha cambiado**: la release **`v1.0.0-beta.9`** publica un **core de libretro para `linux-arm64`**:

```
https://github.com/yuk27/VBoyColor/releases/download/v1.0.0-beta.9/vboycolor_libretro-v1.0.0-beta.9-linux-arm64.zip
```

→ **Encaja perfecto en DeckStation**: es un core de RetroArch, como `suyu-libretro` / `goosestation`.

## Plan (cuando se retome)
1. **Bajar** el zip y ver que trae: `vboycolor_libretro.so` (+ ¿`.info`?).
2. **Paquete** (patron `suyu-libretro`): `packages/vboycolor-libretro/` → instala el `.so` en
   `/usr/lib/libretro/` y el `.info` en `/usr/share/libretro/info/`. Version beta → **fijar sha256**
   y subir `pkgrel` cuando el autor publique.
3. **RetroArch portable de DeckStation**: copiar el `.so` (y el `.info`) al dir de cores del AppImage
   portable (`/opt/deckstation/Apps/RetroArch/retroarch.AppImage.home/.config/retroarch/cores/`),
   como hace el hook del core de suyu.
4. **ES-DE**: sistema **Virtual Boy** con
   `%EMULATOR_RETROARCH% -L %CORE_RETROARCH%/vboycolor_libretro.so %ROM%`.
   Ojo: Fransis quiere las ROMs en **`vbc`** → `ROMs/vbc/` (`%ROMPATH%/vbc`).
5. **Licencia**: comprobar la del repo antes de meterlo en una imagen que se distribuye.
6. **Probar** con una ROM `.vb` real (y comprobar los "color packs").
7. Si va bien, llevar tambien `es_systems.xml`/`es_find_rules.xml` a **`stshunz/deckstation-arm`**
   (regla: DeckStation se actualiza tambien en SU git).

## Estado — ✅ HECHO (13/10/2026)

Se ha dejado **permanente en los repos** lo que se habia aplicado a mano en la Odin. La release
usada es la **`v1.0.0-beta.11`** (la del doc era la beta.9; el autor ya publico la .11).

- **a) Paquete `vboycolor-libretro`** (patron `suyu-libretro`) en `packages/vboycolor-libretro/`:
  core **PRECOMPILADO** (no se compila nada; el zip linux-arm64 ya trae `.so` + `.info`). El
  `package()` instala `vboycolor_libretro.so` -> `/usr/lib/libretro/` y `vboycolor_libretro.info`
  -> `/usr/share/libretro/info/`. `pkgver=1.0.0.beta.11`, `pkgrel=1`, `arch=('aarch64')`,
  `depends=('gcc-libs')`. **sha256 REAL (no `SKIP`)**:
  `7d12179d5bc7ed80777be71451fc507a5be45fdfd160855565df427003aebd15`.
- **b) ES-DE `es_systems.xml`** (`configs/es-de/custom_systems/`, en las **3 copias**): el sistema
  `virtualboy` vuelve a `%ROMPATH%/virtualboy` con **VBoy Color como primera opcion** (delante de
  Beetle VB y Mednafen), y se anade el sistema PROPIO **`virtualboycolor`** — `%ROMPATH%/vbc`,
  `<platform>virtualboy</platform>` + `<theme>virtualboy</theme>`, un solo `<command>` (VBoy Color).
- **c) RetroArch portable de DeckStation**: **no hay que tocar nada** — `scripts/deckstation-cores.sh`
  copia `/usr/lib/libretro/*.so` y `/usr/share/libretro/info/*.info` a la carpeta portable, y
  `scripts/deckstation-cores-sync.sh` regenera el `es_systems.xml` ACTIVO: al existir
  `vboycolor_libretro.so`, el `<command>` "VBoy Color" aparece solo en ambos sistemas.
- **d) Registro + build**: `tools/sync-to-os.sh` y `tools/check-sync.sh` llevan su linea
  (`overlay`/`cmp_tree`), y el paquete ya esta copiado al arbol de compilacion
  (`pocknix-os/packages/shared/vboycolor-libretro/`). `deckstation-arm` sube a **`pkgrel=16`**
  (centro) y **`pkgrel=11`** (`stshunz/deckstation-arm`) para que el cambio llegue por actualizacion.
- **e) Licencia**: `yuk27/VBoyColor` es **GPL-3.0** (confirmado por la API de GitHub — `spdx_id:
  GPL-3.0` — y por el `LICENSE` dentro del zip) -> **permite redistribuir**, asi que se puede
  empaquetar. El `package()` instala ese `LICENSE` en `/usr/share/licenses/vboycolor-libretro/`.

**Pendiente**: probar con una **ROM `.vb` real** en la Odin (y mirar los "color packs"). El core
tambien sirve ejecutandolo suelto (`.vb`/`.vboy`).
