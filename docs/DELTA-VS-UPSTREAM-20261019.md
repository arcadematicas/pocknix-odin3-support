# Nuestra rama vs `shuuri-labs:sm8750-odin3` (19/10/2026)

> **DECISIÓN (19/10, Fransis): NO se rebasa. Seguimos con nuestro fork como fuente de
> verdad.** Nosotros somos los testers del hardware; shuuri no lo tiene. Mantenemos el
> control de versiones (Steam, MangoHUD, FEX, Mesa...) y afinamos a nuestro gusto.
> Este documento queda como **referencia** (qué compartimos y qué es solo nuestro), no
> como un plan a ejecutar. Upstream se usa como **fuente de parches** que evaluamos y
> llevamos cuando nos interesan.

Inventario para planificar el día que integremos nuestro trabajo en la rama de
shuuri (o al revés). **No es un plan de hoy**: sirve de mapa.

## Tamaño de la divergencia
- `odin3-sm8750` (nuestra): **190 commits** que no están en la suya.
- `sm8750-odin3` (suya): **212 commits** que no tenemos (main nuevo + su
  reescritura del soporte SM8750).
- **4.371 ficheros** distintos entre ambas.

## De dónde sale el volumen (nuestro lado)
| Ficheros | Área |
|---|---|
| 3.020 | `packages/shared/deckstation-arm` (frontend ES-DE + configs + scripts) |
| 306 | `devices/sm8750/packages` (BSP: sensores, splash, panel, udev, suspend) |
| 289 | `packages/shared/pocknix-decky` (Decky + PocknixControl + updater) |
| 284 | `packages/shared/pocknix-sensors-config` |
| 149 | `kernel/sm8750` (7.2.11, 25-armada-sleep, dts propios) |
| 51 | `packages/soc/gamescope` (parches Odin 3) |
| 31 | `packages/shared/pocknix-system-overlay` |
| 28 | `overlay/` (HDR restore, panel-control, powerkey-rebind) |

## Paquetes que **solo** tenemos nosotros (31)
- **Emulación**: `deckstation-arm`, `libretro-azahar`, `libretro-bsnes-hd`,
  `suyu-libretro`, `vboycolor-libretro`, `python-pygame-ce`, `python-pyxel`.
- **UI/Decky**: `pocknix-decky`, `pocknix-system-overlay`, `pocknix-wsquashfs`,
  `pocknix-branding` (deltas), `gamescope-session`, `gamescope-session-steam`
  (¡ellos no usan esos paquetes: lanzan gamescope desde `pocknix-steam`!).
- **Sensores**: `pocknix-sensors-config`, `hexagonrpc`, `pd-mapper`, `libqrtr`,
  `libssc`, `msm-firmware-loader`.
- **Juegos/Windows**: `wproton-arm`, `pocknix-soname-compat`, `attic/steam-rom-manager`.
- **Kernel**: `packages/soc/linux-pocknix-sm8250` (nuestra receta antigua; upstream
  ya usa la receta única `linux-pocknix`).

## Plan de integración propuesto (por fases, cuando toque)
1. **Base**: partir de `sm8750-odin3` (main nuevo + su familia SM8750) y **dejar de
   mantener** lo que ya cubre: canal de Steam, GMU hang fixes, `kernel/common`,
   firmware empaquetado, `devices/` y cmdline renderizado.
2. **Paquetes nuestros que no existen allí**: `deckstation-arm` (lo más grande),
   `pocknix-decky`, `pocknix-system-overlay`, `pocknix-sensors-config` +
   `hexagonrpc/pd-mapper/libqrtr/libssc`, `wproton-arm`, cores libretro propios.
3. **Kernel**: llevar como serie aparte nuestro `25-armada-sleep` (sleep/s2idle),
   `0512`, `0518`, `0531`, `0044`/`0521` desactivados y los DTS propios; su base es
   7.2.10, la nuestra 7.2.11.
4. **HDR/rotación**: shuuri pidió esperar en HDR ("we'll likely port Armada's"); la
   rotación ya la resolvió él (`--force-orientation`). Nuestro overlay de HDR queda
   como delta hasta que ellos decidan.

## Nota
El rebase no es urgente: hoy publicamos desde nuestro fork sin problema (R2) y la
consola funciona. Esto es para que, cuando lo hagamos, no se pierda nada.
