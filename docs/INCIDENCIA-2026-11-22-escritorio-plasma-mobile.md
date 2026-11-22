# Incidencia 22/11/2026 — el modo escritorio solo mostraba el fondo

## Síntoma
En la Odin reparada (imagen `20261118` arrancada desde SD), al cambiar a **modo escritorio**
aparecía un error y solo se veía el fondo: ni paneles ni escritorio funcional.

## Causa
- `pocknix-desktop` elige sesión con `pocknix-desktop-select`, y su **`DEFAULT` era
  `plasma-mobile`**.
- En la imagen está instalado **`plasma-mobile 6.7.4-4`**, que se compiló contra **Qt 6.11**
  mientras el sistema lleva **Qt 6.12**. `plasmashell` arranca el *mobileshell* y falla a medias:
  `Failed to retrieve Wayland window handle`, errores QML de `mobileshell/VolumeOSD.qml`, etc.
- El 16/11 se sacó `plasma-mobile` del **build**, pero la base congelada `20261118` **ya lo traía
  publicado**, y además:
  - `pocknix-desktop-full` incluye `pocknix-desktop-plasma-mobile`,
  - **`pocknix-homescreen` depende de `plasma-mobile`**,
  así que la imagen lo instala igualmente.

## Arreglo aplicado
1. **`pocknix-desktop 0.1.0-36`**: `DEFAULT=plasma` en `pocknix-desktop-select`. El modo escritorio
   arranca `startplasma-wayland` (Plasma de escritorio). El *picker* sigue permitiendo elegir
   Plasma Mobile a mano, pero ya no es lo que sale por defecto.
2. **En la SD concreta**: se escribió `~deck/.config/pocknix/desktop-session` con `plasma`
   (propietario 1001:1001), que es lo que lee el selector.

## Pendiente para próximas imágenes
- Mientras `plasma-mobile` no se recompile contra Qt 6.12, **no debe ser el sabor por defecto**
  (ya corregido) ni ofrecerse como si funcionara.
- Para poder **quitarlo** del todo hay que romper antes dos dependencias:
  `pocknix-homescreen → plasma-mobile` y `pocknix-desktop-full → pocknix-desktop-plasma-mobile`.
  Es trabajo de la tanda de escritorio, no urgente mientras el default sea `plasma`.
- Al cortar la próxima base: comprobar que `plasma-mobile` o no entra, o entra reconstruido
  contra el Qt del snapshot.
