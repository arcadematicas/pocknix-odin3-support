# Release **CalvOS 1.1** — imagen final del AYN Odin 3

**Fecha**: 11/10/2026 · **Artefacto**: `pocknix-sm8750-sd.img` (25.602.031.616 B)
```
sha256  d2ca9892b73347913cf096552089817af2c11bc064c23df73e7508b73999a47f
```

## Cambios vs CalvOS 1.0
- **FIX clave del repo**: la imagen traía la clave pública **de upstream** en `/usr/share/pocknix/pocknix-repo.gpg`, pero el repo R2 va firmado con **la nuestra** (`85C433EE12621EED`) → `[pocknix]`/`[pocknix-shared]` salían inválidas y `pacman -Syu` fallaba ("key is unknown"). **Ahora la imagen trae NUESTRA clave** → actualización limpia desde el primer arranque.
- **FIX DPI de la UI de Steam**: `pocknix-steam` ahora pasa **`--fake-output-mm "${PANEL_MM}"`** al gamescope. La base **OGC** ignora el env `GAMESCOPE_FAKE_OUTPUT_MM` (que era lo que poníamos) → Steam se autoscaleaba a **2,8** (UI enorme). Con el arg vuelve al tamaño correcto por defecto.
- (1.0 → sigue igual): kernel **7.2.9-1**, mesa **26.3.0**, gamescope OGC, Decky 51 (CSS Loader + Eclipse + Panel de Control), branding CalvOS, vk‑valve 20261009‑1, `pacman.conf` sin `[aur]`, repo propio R2.

## Flashear
```sh
sudo dd if=pocknix-sm8750-sd.img of=/dev/sdX bs=4M conv=fsync status=progress
```
⚠️ Comprobar el disco con `lsblk`. root/deck: **pocknix**. SSH viene OFF (activar en Pocknix Tools).
