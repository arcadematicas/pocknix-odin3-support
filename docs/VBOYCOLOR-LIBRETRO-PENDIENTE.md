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

## Estado
**Nada hecho todavia.** Anotado el 12/10/2026 con el PC apagado; se retoma cuando se encienda.
