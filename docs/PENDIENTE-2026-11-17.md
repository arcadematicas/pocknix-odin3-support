# Pendiente de actualización — 2026-11-17

Inventario sacado con `tools/check-published.sh`, `tools/check-upstream-packages.sh` y
`tools/check-armada-deckard.sh --dias 14`. El orden es el de ejecución: cada tanda se cierra
antes de abrir la siguiente.

## 0. Cerrar base + imagen (en marcha)
- [ ] `make build` despinnado
- [ ] `make packages` con `POCKNIX_FORCE_REBUILD=1`
- [ ] `make snapshot` (sube base, escribe lock, rota `base-prev`, mueve pin)
- [ ] `make build` pinneado
- [ ] `make sd-image`
- [ ] validar en SD: arranque, suspensión, audio, wifi, decky, juegos
- [ ] actualizar la Odin
- [ ] anotar el id de snapshot en `CHANGELOG.md`

## 1. Deuda de publicación (publicar lo ya probado)
| Paquete | Nuestra versión | Publicada |
|---|---|---|
| inputplumber | 0.84.0-1 | 0.83.0-1 |
| linux-pocknix-sm8750 | 7.2.15-4 | 7.2.15-2 |
| pocknix-decky | 0.1.0-73 | 0.1.0-72 |
| pocknix-desktop-kde | 0.1.0-4 | 0.1.0-3 |
| pocknix-emulation | 0.1.0-17 | 0.1.0-13 |
| pocknix-power-profiles | 0.1.0-1 | **nunca** |
| pocknix-turnip-x86 | 20261009-2 | 20261009-1 |
| suyu-libretro | 0.0.4-2 | 0.0.4-1 |
| retroarch-autoconfig-pocknix | 0.1.0-4 | 0.1.0-3 |
| retroarch-shaders-pocknix | 0.1.0-4 | 0.1.0-3 |

**Invertidos** (el repo tiene más nuevo que el árbol → re-sincronizar el árbol, NO publicar):
- `gamescope`: árbol `...-1`, repo `...-3`
- `pocknix-bsp-sm8750`: árbol `0.2.0-51`, repo `0.2.0-52`
- `pocknix-base`: árbol `0.2.0-8`, repo `0.2.0-10`

## 2. Bumps de pkgrel de upstream (scripts/config, riesgo bajo)
- [ ] pocknix-snapshots 6 → 10
- [ ] pocknix-lock-migrate 4 → 6
- [ ] pocknix-steam 76 → 80
- [ ] pocknix-steam-full 4 → 5
- [ ] pocknix-session 5 → 7
- [ ] pocknix-steamos-shim 9 → 10
- [ ] pocknix-tools 25 → 26
- [ ] pocknix-gamepad-calibration 2 → 5
- [ ] pocknix-homescreen 1 → 3
- [ ] pocknix-sdcard-automount 7 → 8

## 3. Versiones con código (riesgo medio)
- [ ] inputplumber 0.83 → 0.84 (va con la tanda 1)
- [ ] pocknix-decky 73 (AddGame) y pocknix-desktop-kde 4 (power profiles)
- [ ] pocknix-emulation 17
- [ ] turnip-x86 / suyu-libretro
- [ ] emuladores bin: rpcs3-bin, xemu-bin, vita3k-bin (cada uno engorda la imagen; decidir uno a uno)
- [ ] proton-cachyos / proton-ge (solo pkgrel)

## 4. Armada / Deckard — selectivo (riesgo medio)
Armada, últimos 14 días, áreas tocadas: `kwin`, `powerdevil`, `inputplumber`, `networkmanager`,
`mesa` (26.3.0 el 10/11), `gamescope-session`, `steamos-manager`, `kernel`.

Deckard (hotfixes diarios, 2.126 paquetes; último 17/11 18:48):
`deckard-mesa 27.0.0_devel` (ya alineados: turnip refrescado a mesa main 27.0),
`vulkan-layers 20261107`, `audio-config 20261117`, `hw-support 20261103`,
`linux-72-deckard`, `scx-scheds`, `mangohud`.

- [ ] vulkan-layers: ver si aporta algo en la Odin 3
- [ ] audio-config: solo si aparece problema de audio
- [ ] hw-support: diff antes de tocar
- [ ] scx-scheds / mangohud: evaluar
- [ ] **no** tragar el repo entero

## 5. Paquetes nuevos de upstream que cambian arquitectura — **PENDIENTE DE ESTUDIO**
`pocknix-ui`, `pocknix-store`, `steamos-manager`, `powerdevil`, `pocknix-kernel-guard`,
`pocknix-system-overlay`.

Fransis no los ha visto y no sabe qué cambian → **no se decide nada** hasta tener un estudio corto:
qué sustituyen, qué añaden o quitan en la Odin, y qué se pierde si no se adoptan.
Adelanto: `pocknix-ui` y `pocknix-store` parecen reemplazar piezas de interfaz y de gestión de
paquetes; `steamos-manager` y `powerdevil` van de sesión y energía.

## 6. Kernel — alto riesgo, al final y solo
`linux-pocknix-sm8750 7.2.15-4` está pendiente de publicar; `-5` si procede.
Historial a no repetir: 7.2.5/7.2.6 traían regresión de display (`dsi_calc_clk_rate_6g`, -22) y de
WiFi (`ath12k ... mhi POWER_ON`, -110). Probar en SD antes que en la interna.

## Reglas de la casa
1. Snapshot automático antes de cada transacción (`pocknix-snapshots`); si algo falla, `pocknix-rollback`.
2. `make stage-check` como puerta obligatoria.
3. Un paquete por commit, con `pkgrel` subido.
4. `check-published` limpio antes de dar una tanda por cerrada.
5. Probar en **SD** antes que en la interna.
6. Anotar cada cierre en `CHANGELOG.md`.

## Notas de la tanda 0 (18/11)
- **`libssc` 0.4.4-2 falla al recompilar** en el chroot nuevo: meson aborta con
  `Dependency 'gobject-introspection-1.0' tool variable 'g_ir_scanner' contains erroneous
  value: '/usr/bin/g-ir-scanner'` (gobject-introspection 1.86.0). No es fatal: el script
  conserva la compilación anterior de `shared`. Revisar `makedepends` o esperar corrección
  en ALARM antes de dar por buena una versión nueva de libssc.
- `make build` rc=0 (17/11 21:00) y `make packages` rc=0 (18/11 05:28).
