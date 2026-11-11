# AYN Odin 3 Portal — soporte en CalvOS (preparado 11/11/2026)

La Portal es **SM8750** como la Odin 3, pero cambia el **panel** (`vtdr6130,o3p` frente a
`chipone,icna3520`), el **firmware del ADSP** (ruta propia `ayn/odin3portal/`) y el perfil de
audio/mando. La idea es que **la misma imagen** arranque en las dos consolas: el board se elige
por el modelo del device-tree.

Referencia: **ArmadaOS**, commit `b031deef99a095104ef234c5a0705850152dffe1`
(PRs #857 "Device: AYN Odin 3 Portal", #862 "polish", #873 "DT fixes"). ROCKNIX no tiene
soporte de la Portal (solo la Odin 2 Portal en SM8550).

## Qué se añade

| Pieza | Dónde |
|---|---|
| DTS `cq8725s-ayn-odin3portal.dts` | `kernel/dts/` (BSD-3-Clause, autores originales) |
| Panel `vtdr6130,o3p` + calibración de frame length | `kernel/patches/20-sm8750/2160,2161` |
| Board `odin3portal.conf` + dispatch por modelo | `packages/pocknix-bsp-sm8750/boards/`, `device.conf` |
| UCM `AYN/Odin3Portal` (HiFi = el de Odin 3) | BSP → `/usr/share/alsa/ucm2/` |
| InputPlumber `50-ayn_odin3portal.yaml` | BSP → `/usr/share/inputplumber/devices/` |
| Firmware `ayn/odin3portal/{adsp,adsp_dtb,aw883xx_acf,soccp}` | `devices/sm8750/firmware/` + `pocknix-firmware-sm8750/paths` |

## Cómo se cambia de una a otra

No hay rama ni imagen distinta. Al arrancar:

1. **Volume −** con la consola apagada → menú de OpenABL.
2. **Device model** → `AYN Odin 3 Portal` (sale del `.dtb`, no de una lista fija).
3. **Start**.

El kernel arranca con ese DT y `device.conf` enciende el board `odin3portal.conf`
(modelo de DT `"AYN Odin 3 Portal"`). Si el modelo no está en la lista, cae en los valores de
Odin 3 y lo registra en el log — no se queda en negro por eso.

## Qué queda por validar cuando llegue la unidad

Sin hardware no se puede comprobar nada de esto; el bring-up es a ciegas:

- **Panel**: init del `vtdr6130,o3p`, orientación (el DTS pide `rotation = 270`) y que no
  salga en negro.
- **Brillo**: curva y máximo (`ARMADA_BACKLIGHT_MAX` de Armada es específico de su stack;
  el nuestro es `pocknix-panel-calib` + powerdevil).
- **HDR**: nits y colorimetría. Nuestro perfil de gamescope es
  `overlay/usr/share/gamescope/scripts/10-armada/ayn.icna3520.oled.lua` (device_id
  `ayn-odin-3`). La Portal necesitará su propio perfil y su `GAMESCOPE_INTERNAL_DEVICE_ID`.
- **Refresco**: el parche 2161 permite calibrar `frame_len`; hay que medirlo.
- **Audio**: UCM `Odin3Portal` (comparte `HiFi.conf` con Odin 3) y los amps con su
  `aw883xx_acf.bin` propio.
- **Mando**: el YAML nuevo espera `AYN Odin3 Portal Gamepad` y `gpio-keys-paddles`, target
  `xbox-elite`; comprobar sticks, gatillos y paddles.
- **Suspensión y carga**: mismos parches que la Odin 3; verificar resume y batería.

## Notas

- El DTS de Armada trae `armada,dpu-8bpc-dither` (tenemos el parche 2100) y desactiva
  `remoteproc_cdsp`/`remoteproc_mpss` (la Portal no lleva cámara/NPU).
- Licencias: DTS BSD-3-Clause, parches GPL-2.0 (kernel). Los blobs de firmware son vendor
  (misma política que los del ADSP de la Odin 3: se guardan en `devices/sm8750/firmware/`).
