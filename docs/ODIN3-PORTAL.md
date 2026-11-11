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
| Panel `vtdr6130,o3p` + calibración de frame length | `kernel/patches/20-sm8750/pending/2160,2161` (**no activos**, ver abajo) |
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

## Estado del kernel (build del 11/11/2026)

- **Los parches del panel NO están activos.** `2160` y `2161` son contra
  `drivers/gpu/drm/panel/panel-visionox-vtdr6130-cog.c` (el driver COG de Armada, el
  de sus parches sm8250). Nuestro 7.2.15 solo trae el driver upstream simple
  `panel-visionox-vtdr6130.c`, así que el dry-run falla con
  `can't find file to patch` (4/4 y 14/14 hunks ignorados). Viven en
  `kernel/patches/20-sm8750/pending/` (fuera del glob que aplica el build, que
  ahora **aborta** en conflicto en vez de avisar) con un README que detalla el
  conflicto y qué falta: portar el driver COG (o los parches) y habilitar
  `CONFIG_DRM_PANEL_VISIONOX_VTDR6130_COG` (hoy ni el `VTDR6130` simple está en
  `kernel/sm8750/config/linux.aarch64.conf`).
- **DTS adaptado a nuestro árbol** (el resto es el de Armada tal cual): el nodo del
  panel y el del touchscreen de `&i2c4` viven en nuestro `cq8725s-ayn-odin3.dts`, no
  en el dtsi común, así que se traen completos (reset/vddio/pinctrl y touchscreen
  FT5452); los pinctrl `disp0_reset_n_*`, `mdp_vsync_*` y `ts_p_*` se copian también.
  Se dejan fuera `vci`/`vdd`/`disp`/`blvdd` del panel: el driver de Armada pide
  `vddio` + `tvdd`. `cpusys_vm_mem` **existe** en nuestro `sm8750.dtsi` → el
  `/delete-node/` se mantiene.
- Compilado y empaquetado: `linux-pocknix-sm8750` con **los dos DTBs**
  (`cq8725s-ayn-odin3.dtb` intacto y `cq8725s-ayn-odin3portal.dtb` con
  `model = "AYN Odin 3 Portal"` y `compatible = "vtdr6130,o3p"`);
  `pocknix-bsp-sm8750-0.2.0-52` y `pocknix-firmware-sm8750-0.1.0-4` en el localrepo.
  Sin hardware, el panel no hará probe hasta portar el driver.

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

## El driver del panel: opciones (decidir con la unidad delante)

Ojo: **la Odin 3 y la Portal no comparten panel**. La Odin 3 es ChipOne ICNA3520
(`panel-chipone-icna35xx.c`, driver de familia, `CONFIG_DRM_PANEL_CHIPONE_ICNA35XX=y`
y solo nuestro parche `1034-...-harden-init-after-reset`). La Portal es Visionox
VTDR6130, y su driver en Armada/ROCKNIX es `panel-visionox-vtdr6130-cog.c`, que
**no está en mainline** ni en nuestro 7.2.15 (comprobado: 404 en torvalds/linux).

Nuestro `panel-visionox-vtdr6130.c` es el upstream simple: un modo, tres reguladores
fijos y sin DSC/PPS ni selección de refresco. Para la Portal falta:

- compatible `vtdr6130,o3p` y su tabla de modos 60/120 Hz (mismo pixel clock y DSC;
  el refresco se elige con el comando `0x6c`),
- secuencia de init y PPS de 12 líneas del vendor,
- supplies de la Portal (`tvdd`),
- calibración de frame length (parche 1305).

### Opción A (recomendada): traer el driver `-cog`
- Origen: kernel de ROCKNIX/Armada (GPL-2.0), versión base 7.2.6; el nuestro es 7.2.15.
- Aplicar encima los parches `1304` (o3p) y `1305` (frame length), que ya están en
  `kernel/patches/20-sm8750/pending/`.
- Activar `CONFIG_DRM_PANEL_VISIONOX_VTDR6130` (hoy ni está).
- Ventaja: es la ruta que ya usan otros equipos con este panel (Pocket 6, RP5,
  Flip 2, Pocket Duo); no inventamos DSC ni secuencias.
- Coste: un driver más que mantener y sincronizar con el kernel.

### Opción B: portar solo los datos al driver simple
- Diff pequeño y controlado, pero reimplementamos DSC/PPS/refresco a ciegas.
- Solo si A da problemas de integración con 7.2.15.

### Aparte: mejoras para la Odin 3 (no dependen de la Portal)
Armada tiene dos parches contra el driver que **sí** usamos (`panel-chipone-icna35xx.c`):
- `0060-drm-panel-icna35xx-luminance-linear-backlight-scale.patch` (brillo más lineal),
- `0518a-...-serialise-live-frame-length-writes.patch` y
  `0518b-...-calibrate-the-ICNA3512-frame-length.patch`.

Evaluar solo si mejoran algo medible y sin pisar el Panel de Control (que manda en brillo).

## Notas

- El DTS de Armada trae `armada,dpu-8bpc-dither` (tenemos el parche 2100) y desactiva
  `remoteproc_cdsp`/`remoteproc_mpss` (la Portal no lleva cámara/NPU).
- Licencias: DTS BSD-3-Clause, parches GPL-2.0 (kernel). Los blobs de firmware son vendor
  (misma política que los del ADSP de la Odin 3: se guardan en `devices/sm8750/firmware/`).
