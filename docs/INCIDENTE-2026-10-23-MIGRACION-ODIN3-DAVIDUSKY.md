# Incidente 2026-10-23 — actualizacion de la Odin de Davidusky (imagen 02-oct -> repo R2)

## Resumen
Se siguio `ACTUALIZAR-ODIN-DAVIDUSKY-2026-10-23.md`. La preparacion (pacman.conf R2, clave,
`pacman -Syy`) fue correcta, pero la actualizacion NO se pudo completar por **conflictos de
empaquetado** en la migracion desde la imagen del 02-oct. No se instalo nada (kernel sigue
7.2.4); sistema intacto, con snapshot btrfs 0002 y `/flash/KERNEL.bak-20261023`.

## 1. Falta publicada `pocknix-desktop 0.1.0-27`
- El fuente (`pocknix-os`, pkgrel=27 desde `4982ab4` del 15-oct) ya no choca con
  `pocknix-session` (`conflicts=('pocknix-desktop<0.1.0-27')`).
- Pero **el repo publicado sirve 0.1.0-26**: `pacman -Sl` -> `pocknix-shared pocknix-desktop
  0.1.0-26`, y el fichero `pocknix-desktop-0.1.0-27-any.pkg.tar.*` da **404** en R2
  (probadas variantes .xz/.zst y any/aarch64).
- Sin la 27 la transaccion falla: `pocknix-core` (nuevo) exige `pocknix-session`, que entra en
  conflicto con la 26 instalada, y `pocknix-desktop-full 0.1.0-3` sigue dependiendo de
  `pocknix-desktop`.
- **Workaround aplicado (solo en esta Odin)**: compilar `pocknix-desktop 0.1.0-27` desde el
  fuente (`make packages PKG=pocknix-desktop`) e instalarlo con `pacman -U`.

## 2. Conflictos de ficheros al hacer commit
Tras lo anterior, `pacman -Syu` aborta en "checking for file conflicts":

- `pocknix-session: /usr/bin/steamos-session-select exists in filesystem (owned by pocknix-desktop)`
  -> `pocknix-desktop` 0.1.0-27 **sigue instalando** `steamos-session-select`, que ahora tambien
  trae `pocknix-session`. Debe dejar de incluirlo (o `pocknix-session` debe declarar
  `replaces=('pocknix-desktop')`).
- `pocknix-system-overlay 0.1.0-5` quiere instalar ficheros que ya existen como huerfanos:
  `/bootanimation-odin3.zip`, `/etc/systemd/system/pocknix-diag.service`,
  `pocknix-diag.timer`, `pocknix-oobe-marker.service`, `pocknix-powerd.service`,
  `/etc/xdg/powerdevilrc` (owned by pocknix-desktop), `/usr/local/bin/pocknix-oobe-marker`,
  `/usr/local/bin/pocknix-powerd`. -> declararlos en `backup=()`/adoptarlos, o incluirlos en la
  politica de `--overwrite` del doc.
- `msm-firmware-loader 1.8.0-2` incluye la **entrada de directorio `/usr/sbin/`**, y en el
  sistema `/usr/sbin` es un **symlink -> bin** (owned by `filesystem`). -> el paquete debe
  instalar en `/usr/bin` (bug del paquete; afecta a cualquier Arch con el symlink). Nota:
  `msm-firmware-loader` es dependencia de `pocknix-bsp-sm8750 0.2.0-32`, asi que no se puede
  omitir.

## 3. Recomendacion
- Publicar `pocknix-desktop 0.1.0-27` en R2 (y regenerar `pocknix-shared.db`).
- `pocknix-desktop`: dejar de empaquetar `steamos-session-select` (pasa a `pocknix-session`).
- `pocknix-system-overlay`: adoptar/declarar esos ficheros.
- `msm-firmware-loader`: `/usr/sbin` -> `/usr/bin`.
- Mientras tanto, la politica de `--overwrite` del doc de actualizacion deberia cubrir esas
  rutas exactas (nunca `'*'`), pero mejor arreglar los paquetes.

## 4. Estado de la Odin tras el intento
- Kernel 7.2.4, `linux-pocknix-sm8750 7.2.4-2`, `pocknix-desktop 0.1.0-27` (local).
- 0 unidades fallidas. Nada del update instalado.
- `pacman.conf` ya apunta a R2 + clave `85C433EE12621EED` importada.
- Backups: `/flash/KERNEL.bak-20261023`, snapshot btrfs `0002`.
