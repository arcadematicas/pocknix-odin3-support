# LINEAGE AYN — Análisis para Pocknix (Odin 3 / SM8750)

**Fecha:** 2026-10-20
**Autor:** subagente de análisis (solo lectura; no se ha tocado el proyecto)
**Objetivo:** inventariar los repos de LineageOS de la AYN Odin 3 y extraer QUÉ nos sirve para Pocknix Linux, hueco por hueco.

---

## 0. Corrección de nomenclatura (importante)

El "SM8750" tiene **tres nombres** según el sitio, y conviene no mezclarlos:

| Nombre | Dónde aparece | Qué es |
|---|---|---|
| **sun** / **sunp** | DTS (`sunp-ayn-odin3`, `sun-qrd-sku1-v8.dtsi`), `TARGET_BOARD_PLATFORM := sun` | SoC SM8750 (Snapdragon 8 Elite) en el árbol de devices/DTS |
| **pakala** | configs de sensores (`pakala_*.json`) | codename interno Qualcomm del SM8750 para el Sensor Core |
| **kera** | kernel: `CONFIG_ARCH_KERA`, `CONFIG_SM_GCC_KERA`, `CONFIG_SM_GPUCC_KERA`, `CONFIG_PINCTRL_KERA`, `CONFIG_INTERCONNECT_QCOM_KERA` | nombre del SoC en el kernel CAF/GKI |

La Odin 3 es **sunp** (DTS) con `qcom,msm-id = <639, 618, 705, 706, 0x100026a, 0x100027f, 0x10002c1, 0x10002c2>` y `qcom,board-id = <0x1001f 0>`, compatible `"qcom,sunp-hdk","qcom,sunp","qcom,hdk"` (⇒ **hw_platform "HDK"**).

Ojo: en el mismo repo de DTS existe un `qcom/kera.dtsi` con `msm-id = <659>` que **NO es** la Odin 3 (es otro SKU del SM8750). No confundir.

---

## 1. Resumen ejecutivo

- **El "oro" real son 3 sitios**: `android_kernel_ayn_cq8725s-devicetrees/moorechip/` (DTS específicos de la Odin 3: audio, display/panel, thermal/fan, joystick, fingerprint), `android_kernel_ayn_common-modules/` (drivers AYN: `moorechip-joystick.c`, `leds-htr3212.c`, `leds-sn3112.c`, `focaltech_fp/`) y `proprietary_vendor_ayn_cq8725s-common/vendor/etc/sensors/` (configs del Sensor Core).
- **Ventilador: resuelto con datos exactos.** Es un `pwm-fan` estándar sobre PM8550 LPG PWM4 con `cooling-levels = <0 40 65 75 90 100 120 150 175>` y trips de CPU/GPU/batería en `sunp-moorechip-thermal.dtsi`. No hay daemon en Android: todo es thermal framework in-kernel.
- **Audio: resuelto a nivel de hardware.** Codec WCD939x + 2× amp Awinic **AW883xx** (driver `aw88395`) + jack 3.5mm (MBHC) + mic AMIC1/2/5 + DMIC2/3. El routing completo está en `sun-audio-ayn-odin3.dtsi`. Android **no** tiene UCM: usa `mixer_paths_sun_qrd.xml` genérico.
- **ALS/brillo-auto: aquí hay una discrepancia que hay que cerrar.** El repo de vendor de Lineage **sí** trae `pakala_tmd3765_0.json` (ALS+prox ams-OSRAM TMD3765, con hw_platform "HDK" que es la Odin 3). Nuestro doc `SENSORES-ODIN3-2026-10-15.md` concluía "no hay ALS" basándose en `persist/sensors/sensors_list.txt`. Los dos datos se contradicen → hay que verificar el hardware real.
- **Batería: Lineage no tiene el dato.** No hay capacidad (mAh), ni JEITA, ni `adsp_dtb.mbn` en ningún repo público. Confirma que el perfil de carga vive en el firmware de stock (ArmadaOS), no en Lineage.
- **Panel: tenemos el 80% ya.** El panel es **ICNA3520** AMOLED 1080×1920 DSC (120/60 Hz), y nuestro parche 0028 ya trae el driver ICNA35XX. Lineage aporta la secuencia de init completa y el modo 60 Hz (v-fp=2004).
- **RGB y joystick: chips identificados.** RGB = 2× **HTR3212** I2C (4 LEDs RGB por stick); joystick = MCU **Moorechip** por UART (emula Xbox 360 045e:028e). Ya tenemos driver HTR3212 (parche 0030) y mapeo `ayn_mcu.yaml` alineado (BTN_C/BTN_Z).
- **OJO rama vendor:** `proprietary_vendor_ayn_cq8725s-common` tiene la rama `lineage-23.2` **vacía** ("Initial empty repository"); el contenido real (844 ficheros) está en `lineage-24.0`.

---

## 2. Hueco por hueco

### 2.1. Sensor de luz (ALS) / auto-brillo / auto-rotación — PRIORIDAD 1

**Qué hay en Lineage** (`proprietary_vendor_ayn_cq8725s-common`, rama `lineage-24.0`):

- `proprietary/vendor/etc/sensors/`:
  - `sns_reg_config` (→ input `json.lst`, output `/mnt/vendor/persist/sensors/registry/registry`)
  - `sns_odp_config`, `hals.conf` (`sensors.qsh.so`, `sensors.dynamic_sensor_hal.so`)
  - `config/` con **83 JSON + `json.lst`**
- `json.lst` lista 3 plataformas: **pakala** (SM8750), **bonito**, **eliza** + los `sns_*` de algoritmos.
- **ALS/prox = ams-OSRAM TMD3765** (`config/pakala_tmd3765_0.json` y `pakala_qrd_tmd3765_0.json`):
  - I2C `bus_instance=2`, esclavo **0x39 (57)**, 400 kHz, `dri_irq_num=64`
  - rails `/pmic/client/sensor_vdd` + `/pmic/client/sensor_vddio`
  - calibración ALS (coefs ch0/ch1, dgf 29.43, lux target 300) y prox (near/far threshold)
  - `hw_platform = ["MTP","Surf","RCM","HDK"]` ← **la Odin 3 es "HDK"**, `soc_id = ["618","639","705","706"]` ← coincide
- Sensores del pack pakala: IMU **ST LSM6DSO** (+ QMI8658/ICM4x6xx), mag **QMC6308** + **MMC56x3x**, presión **LPS22DF**, humedad **SHT4x**, hall **BU52053NVX**, SAR **SX932x**.
- `pakala_default_sensors.json` declara entre los default: `ambient_light`, `proximity`, `sar`, `sensor_temperature` (usa `lsm6dso`), más accel/gyro/mag/derivados.
- **NO existe `sns_settling_config` en ningún repo** (buscado en los 7). El "settling" va embebido por sensor (`num_rail`, `rail_on_state`, `vdd_rail`, `vddio_rail`) + `pakala_power_0.json` (`enable_island=1`).

**Discrepancia a cerrar (importante):**

Nuestro `SENSORES-ODIN3-2026-10-15.md` dice "la Odin 3 no tiene ALS ni prox", con 3 argumentos: (1) `persist/sensors/sensors_list.txt` no lista `light`/`proximity`, (2) `ssccli --sensor light` falla, (3) "las configs de luz (`bonito_tmd3765_0.json`, `eliza_tmd2755_0.json`) son de otras variantes, no de pakala".

El punto (3) queda **desmentido por este análisis**: el vendor de Lineage (actualizado el 17-oct-2026) **sí trae `pakala_tmd3765_0.json`** con hw_platform "HDK" (la Odin 3). Nuestro `pocknix-sensors-config` venía de un dump viejo (`Odin3_20251206`); el `json.lst` de Lineage es más nuevo e incluye `pakala_tmd3765_0.json`, `pakala_qmi8658_0.json`, `sns_amd_sw_enabled.json`, `sns_tilt_sw_enabled.json`, etc.

**Qué haríamos:**
1. **Diff** `pocknix-sensors-config` (nuestro dump) contra `vendor/etc/sensors/` de Lineage 24.0 — sobre todo `json.lst` y la presencia de `pakala_tmd3765_0.json`/`pakala_qrd_tmd3765_0.json`. Coste: bajo (es diff de texto). Destino: `packages/pocknix-sensors-config/`.
2. **Verificar el hardware real**: ¿está el TMD3765 poblado en la Odin? Chequear en el I2C del sensor core (bus 2, addr 0x39) o pedir el `registry` generado. Esto decide si el auto-brillo es factible. Coste: bajo; riesgo: ninguno.
3. Si el TMD3765 existe, añadir su JSON al `json.lst` de `pocknix-sensors-config` y re-registrar el SSC. El error histórico `Unexpected buffer count` ya está diagnosticado (faltaban entradas del `json.lst`) — el `json.lst` de Lineage es una referencia más fiel.

**Sobre auto-rotación:** el doc ya concluyó (6-ter) que no es nuestra guerra (falta mount-matrix por DMI vacío). Lineage **no** aporta nada nuevo aquí: la mount-matrix no está en sus configs (solo `gyro_rot_matrix`). No cambia la decisión.

**Riesgo:** bajo. No hay `sns_settling_config` que falte; el "settling" está embebido. La incógnita real es física (¿TMD3765 poblado?).

---

### 2.2. Audio UCM (altavoces, jack, micrófonos)

**Qué hay en Lineage** (`moorechip/audio/sun-audio-ayn-odin3.dtsi` + `configs/audio/` del device tree):

- **Codec:** Qualcomm **WCD939x** (`wcd939x_dlkm.ko` + `wcd939x_slave_dlkm.ko`), colgado del `wcd_usbss` (I2C). `qcom,msm-mbhc-usbc-audio-supported = <1>`.
- **Altavoces:** 2× amp **Awinic AW883xx** (`awinic,aw883xx_smartpa`) en `qupv3_se5_i2c`:
  - `@0x34`: reset tlmm 128, irq tlmm 127, `sound-channel=1`
  - `@0x35`: reset tlmm 126, irq tlmm 125, `sound-channel=0`
  - `re-min=1000`, `re-max=40000` (calibración de impedancia)
  - driver en CAF: `sound/soc/codecs/aw88395/` ⇒ **es el aw88395** (que ya tocamos en el parche 0059)
- **Jack 3.5 mm:** HPH L/R + MBHC (`mbhc_dlkm.ko`) + AUX (ear). `msm-mbhc-hphl-swh=0`, `gnd-swh=0`.
- **Micros:** AMIC1, AMIC2, AMIC5 (analógicos) + DMIC2, DMIC3 (digitales por MIC BIAS3).
- **Hápticos:** `swr_haptics` (HAP_IN → WSA2_HAPT OUT).
- **WSA884x/883x deshabilitados** (no hay el amp clásico de Qualcomm).
- Routing completo en el bloque `qcom,audio-routing` de `sun-audio-ayn-odin3.dtsi`. Modelo de tarjeta: `sun-qrd-snd-card`.
- Android NO usa UCM: `configs/audio/` tiene `audio_policy_configuration.xml`, `mixer_paths_sun_qrd.xml`, `resourcemanager_sun_qrd.xml` (todos **genéricos sun_qrd**, sin personalizar para AYN; `mixer_paths` referencia caminos WSA/HPH genéricos).

**Qué haríamos:**
1. Escribir una **ALSA UCM** (`SM8750-AYN.conf`) a partir del `qcom,audio-routing` del DTS: `Speaker` (AW883xx vía sec-mi2s/fm_i2s1), `Headphone` (WCD939x HPH), `Mic` (AMIC1/2/5 + DMIC2/3), `Haptics`.
   - Destino: `pocknix-bsp-sm8750/` (o un paquete `pocknix-ucm-sm8750`), + `alsa-ucm-conf` en la imagen.
   - Coste: medio (escribir y afinar controles). Riesgo: bajo.
2. Confirmar que nuestro kernel tiene el codec **AW883xx (aw88395)** completo (tenemos 0059, y WCD939x con 0063/0064). El amp **no es** aw88166 (eso es de AyaNeo, parche 0032).
3. Los nombres de control de mezclador para la UCM salen de `mixer_paths_sun_qrd.xml` (referencia) + el driver aw88395/wcd939x.

**Riesgo:** medio. El AW883xx y WCD939x ya están medio portados; falta el "cableado" UCM y validar el jack.

---

### 2.3. Ventilador / MCU (RGB, botones)

**Ventilador** (`moorechip/sunp-moorechip-thermal.dtsi`):

- `fan0`: `pwm-fan` (driver estándar de Linux) sobre **PM8550 LPG PWM4** (`pm8550_pwm_2` @0xeb00, GPIO8 func1, 1.8 V), `fan-supply = fan_reg` (regulador fijo 5 V en **tlmm 84**).
- `cooling-levels = <0 40 65 75 90 100 120 150 175>` → **9 niveles**.
- Curvas (cooling-maps):
  - CPU grande (`cpu-0-0-0`): 55→85 °C en pasos de 5 °C → fan 1..8 (hysteresis 5 °C).
  - CPU media (`cpu-0-5-0`): idéntica a la anterior.
  - GPU (`gpuss-0`, `gpuss-1`): 50→85 °C en pasos de 5 °C → fan 0..8.
  - Batería (`sys-therm-11`): 43 °C → fan 6-7; 45 °C → fan 7-8 (hysteresis 2-3 °C).
- **No hay daemon de ventilador en Android**: todo es thermal framework in-kernel.

**MCU / joystick** (`moorechip/sunp-moorechip-joystick.dtsi` + `android_kernel_ayn_common-modules/moorechip-joystick.c`):

- Joystick = MCU **Moorechip** por UART `qupv3_se15_2uart` (QUP2 SE7, GPIO30/31), driver `moorechip,joystick` (serdev). `moorechip,layout-nintendo`.
- Emula **Xbox 360** (`USB 045e:028e`). Protocolo: magic `0x3D5AD3A5`, comandos `SET_PARAMETER=5`, `SET_LEFT_STICK_AXIS_SWAP=0xB0`, upgrade `0xE9+`.
- sysfs en `/sys/class/moorechip-joystick/joystick/`: `layout`, `triggers`, `digital_trigger_threshold`, `m0_function`, `m1_function`, `ignore_mask`, `calibration`, `left_stick_axis_swap`, `firmware_version`, `raw`.
- Botones M0/M1 = GPIO3/GPIO7 (activo bajo). Alimentación `joystick_vdd_reg` 3.3 V (tlmm 83) + level-shifter **AW3911** 1.8 V (tlmm 85).
- Defaults: `m0_function="c"` (BTN_C), `m1_function="z"` (BTN_Z) ← coincide con nuestro `ayn_mcu.yaml` (BTN_C→F13 MangoHud, BTN_Z→LeftPaddle).
- Persistencia de calibración en `/mnt/vendor/persist/odin/joys`.

**RGB** (`sunp-moorechip-joystick.dtsi` + `leds-htr3212.c`):

- 2× **HTR3212** (`yongfukang,htr3212`) I2C, 12 canales cada uno = **4 LEDs RGB por stick**:
  - izquierda: `qupv3_hub_i2c4` @0x3c, vdd tlmm 87 → `left:stick:0..3`
  - derecha: `qupv3_hub_i2c3` @0x3c, vdd tlmm 88 → `right:stick:0..3`
- Clase LED multicolor (`multi_intensity` + `brightness`). El control en Android (`AynParts` + `charger_rgb`) escribe directamente a `/sys/class/leds/*/multi_intensity`.
- `leds-sn3112.c` (strip) existe en common-modules pero **no se carga en la Odin 3** (no hay tira de LEDs; solo los 8 LEDs de los sticks).

**Qué haríamos:**
1. **Ventilador:** portar `cooling-levels` + trips exactos a nuestro árbol (kernel 7.2.11-6). Opción A (recomendada): usar `pwm-fan` + cooling-maps in-kernel (como Android) y jubilar/alinear `pocknix-fancontrol`. Opción B: alimentar `pocknix-fancontrol` con estos niveles/trips. Destino: `kernel/sm8750/patches/20-sm8750/` + `pocknix-bsp-common/pocknix-fancontrol`. Coste: bajo. Riesgo: bajo.
2. **RGB:** ya tenemos driver HTR3212 (parche 0030, compatible `heroic,htr3212`). Solo alinear el DTS a la Odin 3 (0x3c, gpios 87/88, labels `left/right:stick:0..3`). Coste: bajo.
3. **MCU:** nuestro gamepad ya funciona (RSInput/AyaNeo MCU + InputPlumber). Si queremos paridad con Android (`layout`/`triggers`/`m0/m1`/`calibration`/`axis_swap` en sysfs), portar `moorechip-joystick.c` (serdev limpio, portable) o extender nuestro driver. Coste: medio. **Ojo:** depende de `panel_event_notifier` (API QCOM que en mainline hay que adaptar o stubear).

**Riesgo:** bajo en fan/RGB; medio en MCU (UART + notifier).

---

### 2.4. Batería (capacidad, JEITA, `adsp_dtb.mbn`)

**Qué hay en Lineage (o más bien qué NO hay):**

- **No hay capacidad (mAh), ni JEITA, ni step-charging** en ningún repo público (buscado `7600`, `mAh`, `battery-capacity`, `jeita`, `step-charg`, perfiles QBG/QG en sun).
- `battery_charger` genérico (`qcom/sun-qrd-sku1.dtsi` → `sun.dtsi`): `thermal-mitigation-step=500000` (500 mA), `wireless-fw-name="idt9418.bin"`, `ship-mode-immediate`.
- Carga: 2× **SMB1396** (bombas de carga @0x34/0x35) + cargador inalámbrico **IDT9418** (@0x3b), vía `pmic_glink` (I2C instancia 6 del ADSP).
- `vendor/etc/charger_fw_fstab.qti` = fstab para el modo "cargador apagado".
- **No hay `adsp_dtb.mbn`** en el vendor (la carpeta `vendor/firmware/` solo trae `evass*` (EVA), `gen70900_*`/`gen80000_*` (Adreno) y `vpu33/vpu35` (video)). La partición `dsp` se monta en `/vendor/dsp` (fstab), pero el contenido (adsp.mbn/adsp_dtb.mbn) no está en el repo.

**Confirmación de la hipótesis:** el perfil de batería del SM8750 corre en el ADSP y el `adsp_dtb.mbn` que lo autentica **no viene de Lineage** — viene del firmware de stock (ArmadaOS). Nuestro doc ya lo dice ("No tocar `adsp_dtb.mbn`"). Lineage no añade nada.

**Qué haríamos:**
1. Nada portable desde Lineage para el mAh/JEITA. La capacidad (7600 vs nuestro 5000 en DTS) es un dato del fabricante que Lineage tampoco tiene. Si se quiere corregir, hay que fijar el perfil en nuestro DTS/fuel-gauge (no en Lineage).
2. Referencia útil: `thermal-mitigation-step=500000` y el esquema SMB1396+IDT9418 para nuestro manejo de carga térmica.

**Riesgo:** nulo (no hay nada que portar). No perder tiempo aquí con Lineage.

---

### 2.5. Térmicas (tripping/zonas vs las nuestras)

**Qué hay en Lineage** (`moorechip/sunp-moorechip-thermal.dtsi`, 519 líneas):

- Trips de ventilador (ver 2.3) + `thermal-engine-config`/`thermal-hal-config` a 125 °C (es el tope que usa el HAL de perf).
- PMICs deshabilitados: `pm8010_m`, `pm8010_n`, `pmd802x`, `pmr735d`.
- `&ibat_lvl1 { temperature = <15000> }` (15 A de corriente de batería).
- No hay `thermal-engine*.conf` en vendor: Android usa el thermal framework del kernel + perf HAL.

**Qué haríamos:**
- Comparar nuestros trips (kernel 7.2.11-6, `cooling-maps` recién arreglados) con los trips de fan de Lineage y portar exactamente la tabla CPU/GPU/batería. Destino: `kernel/sm8750/patches/20-sm8750/` (DTS) o el config del BSP.
- Coste: bajo. Riesgo: bajo. Los valores son directos.

---

### 2.6. Panel (timings/init 60/120 Hz, brillo)

**Qué hay en Lineage** (`moorechip/display/display/dsi-panel-icna3520-1080p-dsc-cmd.dtsi` + `sun-sde-display-ayn-odin3.dtsi`):

- Panel: **ICNA3520** AMOLED, **1080×1920**, DSC (slice 540×12, 8 bpc/8 bpp), modo **cmd**, 4 lanes, `rgb_swap_rgb`, 24 bpp.
- **120 Hz** (timing@0): h-fp=24, h-bp=24, h-pw=1, v-bp=28, **v-fp=28**, v-pw=1.
- **60 Hz** (timing@1): ídem pero **v-fp=2004** (estira el frame). Cambio de modo por registro **0x48**: `0x00`=HFR normal (120 Hz), `0x10`=HF1 (60 Hz).
- **Brillo:** `bl_ctrl_dcs`, min 10, max **3413**, `mdss-dsi-bl-inverted-dbv`. Init con `0x53 E0` (HBM1 + BCTL on).
- Secuencia de init completa (unlock 9C/FD, sleep out, REG SEL grupos 0/1/13, registros de timing/gamma C1/C2/C3, lock, display on).
- Panel: reset tlmm 98, backlight-en tlmm 56, AVDD2 1.0 V (tlmm 97).
- **Táctil: FocalTech FTS** (`focaltech_fts.ko`) en `qupv3_se4_i2c` @0x38, reset tlmm 161, irq tlmm 162, 1080×1920, 10 toques, `focaltech,ic-type = <0x35190489>`.
- `vendor.prop`: `ro.surface_flinger.game_default_frame_rate_override=120`, `vendor.display.enable_dpps_dynamic_fps=1` (60/120 dinámico).

**Qué haríamos:**
1. Ya tenemos el driver **ICNA35XX** (parche 0028) y el "pocket fit panel" (0055). **Diff** de timings/init de Lineage contra los nuestros para confirmar el modo 60/120 Hz (v-fp 2004) y la escala de brillo 3413. Destino: parche de panel en `20-sm8750/`.
2. **Táctil:** Lineage usa FocalTech FTS; nosotros tenemos Chipone TDDI (parche 0061). Verificar cuál lleva realmente la Odin 3 (el DTS de Lineage dice FocalTech). Si es FocalTech, revisar si nuestro touch driver lo cubre.
3. El `qcom-amoled-regulator.ko` (regulador AMOLED) y el patrón `panel_event_notifier` pueden ser útiles para nuestro manejo del panel/OLED-care.

**Riesgo:** bajo (panel ya mayormente portado). El punto a validar es touch (FocalTech vs Chipone).

---

### 2.7. GPU/GDSC, PCIe, suspend (deltas accionables)

**Qué hay en Lineage** (`moorechip/sunp-ayn-odin3.dtsi` + `sunp-moorechip-rpmh.dtsi`):

- `pcie0`: `qcom,no-client-based-bw-voting` (evita votar BW por cliente).
- RPMh: borra varios `periph-*` supplies del `regulator_ocp_notifier` (limpieza de notificadores OCP).
- `pmih010x_haptics`: `lra-period-us = 7692`.
- USB: `qcom,wcd_usbss`, borra `ssusb_redriver`; `redriver` deshabilitado.
- `qupv3_se4_spi` y `qupv3_se5_i2c` deshabilitados en el DTS base (se5 se re-habilita en el overlay de audio).
- Patrón `panel_event_notifier` (lo usan LED/joystick/panel para sincronizar con encendido del panel).
- Wifi/BT: WCN7860 ("peach"), `sun-peach-cnss`/`sun-peach-bt` (Android usa cnss2/qca_cld3; nosotros mainline ath12k). MAC: `read_mac_addr_from_mac_file=1` (WLAN) y `ro.vendor.bt.bdaddr_path=/mnt/vendor/persist/quec_bt_mac` (BT).

**Qué haríamos:** la mayoría ya está portada (armada #723). Deltas menores accionables: el `pcie0 no-client-based-bw-voting`, la limpieza de `regulator_ocp_notifier` y `lra-period-us` del háptico. Para suspend/wifi no aporta sobre lo que ya tenemos (ath12k ≠ cnss2). El `WCNSS_qcom_cfg.ini` **no aplica** a ath12k.

**Riesgo:** bajo.

---

## 3. Lo que NO sirve (para no perder tiempo)

- **Binarios/HAL de Android** (`vendor/lib64/*.so`, `*.apex`, `WfdService.apk`, `TimeService.apk`, `sensors.qsh.so`, perf HAL, `vendor.qti.*` services): inaplicables a Linux.
- **`audio_policy_configuration.xml`, `mixer_paths_sun_qrd.xml`, `resourcemanager_sun_qrd.xml`**: formato del Audio HAL de Android; sirven solo de referencia para los nombres de control de mezclador (no como UCM). Además son **genéricos sun_qrd** (no AYN).
- **`WCNSS_qcom_cfg.ini`** (`vendor/etc/wifi/peach_v2/`): es para el driver Qualcomm cnss2/qca_cld3; nosotros usamos mainline **ath12k**. No es reutilizable directamente.
- **`android_kernel_ayn_cq8725s-modules/`** (qca-wifi-host-cmn): stack WLAN de Android. No sirve para mainline.
- **`packages/AynParts`** (Kotlin/Java): lógica de referencia (nodos sysfs y protocolo RGB), no compilable en Pocknix. La lógica útil ya está en los drivers C.
- **`thermal-engine*.conf` / perf HAL**: no existen en estos repos (Android usa thermal in-kernel). Nada que portar.
- **`sns_settling_config`**: no existe. No hay nada que echar de menos.
- **Configs `bonito_*` / `eliza_*` de sensores**: otras variantes del SM8750, no la nuestra (pakala).
- **`qcom/kera.dtsi` (msm-id 659)**: otro SKU, no la Odin 3.
- **`adsp_dtb.mbn` / firmware ADSP**: no está en Lineage; viene del stock (ya lo sabemos).

---

## 4. Anexo — comandos y rutas

### Rutas de los clones (PC `192.168.4.60`, usuario `fransis`)

```
/home/fransis/ayn-lineage/
├── android_hardware_ayn                    (LineageOS, lineage-24.0)
├── proprietary_vendor_ayn_cq8725s-common   (TheMuppets, lineage-24.0  ← 23.2 está VACÍA)
├── android_kernel_ayn_cq8725s-devicetrees  (LineageOS, lineage-24.0)
├── android_device_ayn_cq8725s-common       (LineageOS, lineage-24.0)
├── android_kernel_ayn_cq8725s              (LineageOS, lineage-24.0)
├── android_kernel_ayn_cq8725s-modules      (LineageOS, lineage-24.0)
└── android_kernel_ayn_common-modules       (LineageOS, lineage-24.0)
```

### Comandos de clonado

```sh
git clone --depth 1 --single-branch --branch lineage-24.0 https://github.com/LineageOS/android_hardware_ayn.git
git clone --depth 1 --single-branch --branch lineage-24.0 https://github.com/LineageOS/android_kernel_ayn_cq8725s-devicetrees.git
git clone --depth 1 --single-branch --branch lineage-24.0 https://github.com/LineageOS/android_device_ayn_cq8725s-common.git
git clone --depth 1 --single-branch --branch lineage-24.0 https://github.com/LineageOS/android_kernel_ayn_cq8725s.git
git clone --depth 1 --single-branch --branch lineage-24.0 https://github.com/LineageOS/android_kernel_ayn_cq8725s-modules.git
git clone --depth 1 --single-branch --branch lineage-24.0 https://github.com/LineageOS/android_kernel_ayn_common-modules.git

# vendor: OJO, la rama 23.2 (default) está vacía. El contenido está en 24.0:
git clone --depth 1 --single-branch --branch lineage-24.0 https://github.com/TheMuppets/proprietary_vendor_ayn_cq8725s-common.git
```

### Ficheros clave analizados

| Fichero (relativo al repo) | Repo | Relevancia |
|---|---|---|
| `moorechip/sunp-ayn-odin3.dtsi` / `-overlay.dts` | devicetrees | DTS principal Odin 3 (base `sun-qrd-sku1-v8.dtsi`) |
| `moorechip/sunp-moorechip-thermal.dtsi` | devicetrees | fan + trips |
| `moorechip/sunp-moorechip-joystick.dtsi` | devicetrees | joystick Moorechip + HTR3212 |
| `moorechip/audio/sun-audio-ayn-odin3.dtsi` | devicetrees | routing audio (WCD939x + AW883xx) |
| `moorechip/display/display/dsi-panel-icna3520-1080p-dsc-cmd.dtsi` | devicetrees | panel ICNA3520 (init/timings) |
| `moorechip/display/display/sun-sde-display-ayn-odin3.dtsi` | devicetrees | display + touch FocalTech |
| `moorechip/fingerprint/sun-fingerprint-ayn-odin3.dtsi` | devicetrees | fingerprint FocalTech (SPI) |
| `moorechip-joystick.c` | common-modules | driver joystick (serdev) |
| `leds-htr3212.c` / `leds-sn3112.c` | common-modules | drivers RGB LED |
| `focaltech_fp/` | common-modules | driver fingerprint |
| `config/gki_moorechip.conf` | common-modules | CONFIG de módulos AYN |
| `vendor/etc/sensors/{sns_reg_config,sns_odp_config,hals.conf,config/*}` | vendor-common | configs Sensor Core |
| `configs/audio/{audio_policy_configuration.xml,mixer_paths_sun_qrd.xml}` | device-common | audio Android (referencia) |
| `properties/vendor.prop` | device-common | props (120 Hz, BT MAC, audio…) |
| `init/fstab.default`, `config.fs` | device-common | particiones (dsp, persist, spunvm) |
| `packages/AynParts/...`, `services/{charger_rgb,left_stick_axis_swap,recovery_rgb}` | hardware-ayn | protocolo RGB + persistencia |

### Verificación de la discrepancia ALS (recomendado al retomar el tema)

```sh
# en la Odin 3 (por ssh):
# ¿está el TMD3765 en el sensor I2C? (bus 2 del SSC, addr 0x39)
ssccli --sensor light --timeout 6
# y comparar json.lst nuestro vs el de Lineage:
diff /usr/lib/firmware/sensors/json.lst <(cat .../proprietary_vendor_ayn_cq8725s-common/proprietary/vendor/etc/sensors/config/json.lst)
```

---

*Nota:* este informe es solo lectura. No se ha ejecutado ningún build ni se ha modificado `pocknix-os` ni el repo de soporte (salvo la creación de este fichero).

---

## CORRECCIÓN (verificada a mano, 20/10 — Alfred)

La sección 2.1 concluía que `pocknix-sensors-config` venía de un dump viejo sin `pakala_tmd3765_0.json`.
**Es falso**: comprobado en `packages/pocknix-sensors-config/`:

- El paquete tiene **144 ficheros**, con **30 `pakala_*`**, incluidos `pakala_tmd3765_0.json` y
  `pakala_qrd_tmd3765_0.json`.
- Su `json.lst` (138 líneas) **ya lista** `pakala_tmd3765_0.json` (línea 28) y **no le falta ni un
  fichero** de los que referencia (`comm` vacío).
- Frente al `json.lst` de Lineage 24.0 solo hay **4 entradas nuevas**, todas de variantes:
  `qsh_camera_imx688_4.json`, `sns_amd_sw_disabled.json`, `sns_presence_detect.json`,
  `sns_tilt_sw_disabled.json`.
- Los `pakala_*` de Lineage que no tenemos: **ninguno**.

⇒ **La config del sensor core no es el problema.** El bloqueo del ALS sigue siendo la PD del ADSP
(`Unexpected buffer count: 1f050100`), no los JSON. No hay nada que ganar copiando ficheros de Lineage.

Datos verificados de paso (útiles):
- Ventilador AYN (`moorechip/sunp-moorechip-thermal.dtsi:42`):
  `cooling-levels = <0 40 65 75 90 100 120 150 175>`; trips 55/60/65/70/75… °C.
  Nosotros (`0601-ROCKNIX-odin3-pwm-fan-sysfs.patch`): `<0 30 45 60 70 90 120 150>`; trips 90/95/120.
  → la curva de AYN es **bastante más agresiva** (y llega a 175). Candidata a perfil alternativo.
- Panel (`moorechip/display/display/dsi-panel-icna3520-1080p-dsc-cmd.dtsi`): 1080×1920, modo 120 Hz y
  modo 60 Hz con **v-front-porch = 2004** (no es "mitad de reloj": cambia el porch).
