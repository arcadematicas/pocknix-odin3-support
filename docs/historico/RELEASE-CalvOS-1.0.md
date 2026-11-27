# Release **CalvOS 1.0** — imagen final del AYN Odin 3

**Fecha**: 11/10/2026 · **Artefacto**: `pocknix-sm8750-sd.img` (25.602.031.616 bytes, ~23 GiB)
(también referida como `v0.4-odin3-3`)

```
sha256  2e4ea33c6f7de65a89443e618e4a877eb92e534aad2738f5c133c6cfccb644c6
```

## Qué es
Imagen SD para el **AYN Odin 3** (SM8750 / Snapdragon 8 Elite), con el **nombre final del proyecto: CalvOS**.
Base = `pocknix-os` + todo nuestro desarrollo.

## Componentes
- **Kernel 7.2.9** (`linux-pocknix-sm8750 7.2.9-1`, módulos coherentes) + **parche térmico del GPU** (trip pasivo ~95 °C).
- **Mesa 26.3.0** + Turnip propia + **Turnip de Valve 0.5.x** (`pocknix-vk-valve 20261009-1`, per-game: por defecto la nuestra, elegible).
- **gamescope OGC** (`1:3.16.29.ogc2.20260918…`, rotación nativa + HDR armada) — sin `--force-composition`.
- **Decky de serie**: CSS Loader + **tema Hooandee Eclipse** + **Panel de Control** (`pocknix-decky 51`).
- **Branding CalvOS** (watermark/wordmark/wallpaper).
- **Repos propios en R2** (`[pocknix]`/`[pocknix-shared]`/`[pocknix-base]`), firmados → `pacman -Syu` actualiza.
- `pacman.conf` **sin `[aur]`** (evita la "chimera" de versiones).

## Cambios vs v0.4-odin3-2
- Kernel 7.2.6 → **7.2.9**.
- **Repo propio en R2** (antes el de upstream daba 404 → mezclaba ALARM/AUR).
- **Decky de serie** completo (CSS Loader + Eclipse + Panel de Control).
- **Fix del QAM** detrás del juego (quitado `--force-composition`).
- **Turnip de Valve 0.5.x** (per-game) + **parche térmico del GPU**.
- `[aur]` eliminado y `pkgver` del kernel corregido a 7.2.9.

## Flashear
```sh
sudo dd if=pocknix-sm8750-sd.img of=/dev/sdX bs=4M conv=fsync status=progress
```
⚠️ Comprobar el dispositivo con `lsblk` antes. Insertar en la Odin y arrancar.
Usuario `deck`/root: **`pocknix`**. SSH viene **OFF** (se activa en Pocknix Tools).
