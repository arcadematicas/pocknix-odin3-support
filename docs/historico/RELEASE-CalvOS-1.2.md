# Release **CalvOS 1.2** — AYN Odin 3

**Fecha**: 11/10/2026 · **Artefacto**: `pocknix-sm8750-sd.img` (25.6 GB)
```
sha256  316278ca6e87d44bfd4b197b21c2769bc0c86dffa79d27cc2d311fbfaab843e8
```

## Cambios vs CalvOS 1.1
- **Kernel `7.2.9-2` con el parche ath12k (`0041b`)**: guardas de NULL en
  `cancel_hw_scan`/`unassign_vif_chanctx`/`remove_interface`. El Oops de
  `ar->scan.arvif` (0x1508) que provocaba **bucle de arranque** ya no paniquea.
- **HDR APAGADO POR DEFECTO** (`pocknix-steam 67` + `gamescope-session-steam 4`): con el HDR
  global, el **QAM y MangoHUD caian DETRAS** del juego. El toggle manual de PocknixControl sigue.
- **Instalacion de DeckStation sin limite de la API de GitHub** (`deckstation-arm 15`): el
  updater resuelve tags/assets por el feed Atom + HTML `expanded_assets` (cero cuota) cuando la
  API da 403 → la **instalacion inicial ya baja todo**.
- **WProton `1.72` (arm-2026-10-11a, de stshunz)**: token opcional, cache/reintentos, via sin API,
  diagnostico de cuota, y el fix de que la "primera vez" se repitiera en cada arranque.
- **Tema Eclipse 0.3.2** con auto-actualizacion (nuestro servicio actualiza conservando el
  `config_USER.json` del usuario).
- Ademas: `pocknix-decky 51`, `pocknix-firmware-sm8750 3` (imagen y R2 cuadrados).

## Flashear
```sh
sudo dd if=pocknix-sm8750-sd.img of=/dev/sdX bs=4M conv=fsync status=progress
```
Comprobar el disco con `lsblk`. root/deck: **pocknix**. SSH viene OFF (activar en Pocknix Tools).
