# Micrófono Odin 3 (SM8750 + WCD939x) — diagnóstico SoundWire `dout-ports mismatch` y EIO de captura

**Fecha**: 21/10/2026
**Ámbito**: Pocknix / kernel 7.2.11 (+ parches ROCKNIX/armada), SM8750 (Kaanapali), códec WCD939x.
**Estado**: investigación (solo lectura). No se ha aplicado nada.
**Relacionado**: `MICROFONO-INVESTIGACION.md` (01/10/2026), `MICROFONO-PENDIENTE.md`.

---

## 1. Resumen ejecutivo

### 1.1 Causa más probable del `dout-ports (0) mismatch with controller (1)`

El nodo **`swr2: soundwire@7630000`** (label `"TX"`, el controlador SoundWire del **micrófono/headset**) del `arch/arm64/boot/dts/qcom/sm8750.dtsi` de mainline declara:

```dts
qcom,din-ports = <4>;
qcom,dout-ports = <0>;      /* <-- INCORRECTO */
```

pero el **hardware** (registro `SWRM_COMP_PARAMS` del controlador) reporta **1** puerto dout. El driver `drivers/soundwire/qcom.c` → `qcom_swrm_get_port_config()` lee el valor del hardware y lo compara con el DT:

```c
ret = of_property_read_u32(np, "qcom,dout-ports", &val);
if (!ret) {
    if (val != ctrl->num_dout_ports) {
        dev_err(ctrl->dev, "dout-ports (%d) mismatch with controller (%d)",
                val, ctrl->num_dout_ports);     /* <- el mensaje que vemos */
    }
    ctrl->num_dout_ports = val;   /* <- el DT PISA al hardware: queda 0 */
}
```

Ese chequeo lo introdujo el commit upstream **`9e53a66a2f2f`** ("soundwire: qcom: deprecate qcom,din/out-ports", 2025-09-12). Consecuencia: el driver registra **0 DAIs dout + 4 DAIs din** (en vez de 1+4) y configura los puertos SoundWire mal → el camino de captura del WCD (DMIC → WCD → `swr2` → `lpass_txmacro` → `TX_CODEC_DMA_TX_3`) **no puede transportar datos**.

Este es **exactamente el mismo bug** que Neil Armstrong arregló para el **SM8650** (sibling del SM8750) en el commit upstream **`c0bec4b58b8e740236d9ac338821f78dbf784546`** ("arm64: dts: qcom: sm8650: fix soundwire ports properties"), que **sí está mergeado en mainline** (`torvalds/linux` master tiene `swr2` de sm8650 con `qcom,dout-ports = <1>`), pero **nadie lo ha portado al SM8750**: ni upstream, ni ROCKNIX, ni armada-os, ni armbian.

### 1.2 Causa más probable del EIO de `arecord` (`pcm_read: read error: Input/output error`, sin log de kernel)

El BE `TX_CODEC_DMA_TX_3` (dai-link `"WCD Capture"`) no llega a arrancar porque el puerto SoundWire TX del controlador `swr2` está mal configurado (por el punto 1.1). El EIO sale "sin log" porque el fallo real está en el **arranque del grafo en el DSP** (q6apm/audioreach), no en el driver del PCM, y la topología sí existe (`TX_CODEC_DMA_TX_3 Capture` está en `SM8750-AYN-tplg.bin`), así que no hay mensaje de "graph not found".

### 1.3 ¿Es alcanzable el micrófono en mainline?

**Sí, con un fix de una línea (+ 8 arrays) en el DTS.** El camino de hardware ya está todo declarado y es **idéntico al de las placas de referencia** (`sm8750-mtp.dts`, `sm8650-qrd.dts`):

- `cq8725s-ayn-common.dtsi` declara el dai-link `wcd-capture-dai-link` con `sound-dai = <&wcd939x 1>, <&swr2 0>, <&lpass_txmacro 0>` y BE `<&q6apmbedai TX_CODEC_DMA_TX_3>` → **correcto**.
- `&swr2 { wcd_tx: codec@0,3 { qcom,tx-port-mapping = <2 2 3 4>; } }` → **idéntico a la referencia**.
- La topología `SM8750-AYN-tplg.bin` contiene el grafo `TX_CODEC_DMA_TX_3 Capture` / `MultiMedia3 Capture` → **correcta**.
- El micro interno es el **DMIC interno del WCD939x (DMIC2/DMIC3)**, no un DMIC GPIO externo ni el VA macro (ver §4) → el reloj DMIC es interno del códec y **no requiere propiedades DT adicionales**.

**Lo único que falta es corregir `swr2` en `sm8750.dtsi`.**

---

## 2. Qué cambiar exactamente

### 2.1 Nodo, propiedad y valor

Fichero: `arch/arm64/boot/dts/qcom/sm8750.dtsi`, nodo `swr2: soundwire@7630000` (en 7.2.9 ≈ línea 2573; en `torvalds/master` ≈ línea 2563).

Cambio (port **literal** del hunk `swr2` del commit upstream `c0bec4b58b8e`, que en el SM8650 toca `soundwire@6d30000` y en el SM8750 es `soundwire@7630000` con contenido **byte-idéntico**):

```diff
 			qcom,din-ports = <4>;
-			qcom,dout-ports = <0>;
-
-			qcom,ports-sinterval-low =	/bits/ 8 <0x01 0x01 0x03 0x03>;
-			qcom,ports-offset1 =		/bits/ 8 <0x00 0x00 0x01 0x01>;
-			qcom,ports-offset2 =		/bits/ 8 <0x00 0x00 0x00 0x00>;
-			qcom,ports-hstart =		/bits/ 8 <0xff 0xff 0xff 0xff>;
-			qcom,ports-hstop =		/bits/ 8 <0xff 0xff 0xff 0xff>;
-			qcom,ports-word-length =	/bits/ 8 <0xff 0xff 0xff 0xff>;
-			qcom,ports-block-pack-mode =	/bits/ 8 <0xff 0xff 0xff 0xff>;
-			qcom,ports-block-group-count =	/bits/ 8 <0xff 0xff 0xff 0xff>;
-			qcom,ports-lane-control =	/bits/ 8 <0x01 0x02 0x00 0x00>;
+			qcom,dout-ports = <1>;
+
+			qcom,ports-sinterval-low =	/bits/ 8 <0x00 0x01 0x01 0x03 0x03>;
+			qcom,ports-offset1 =		/bits/ 8 <0x00 0x00 0x00 0x01 0x01>;
+			qcom,ports-offset2 =		/bits/ 8 <0x00 0x00 0x00 0x00 0x00>;
+			qcom,ports-hstart =		/bits/ 8 <0xff 0xff 0xff 0xff 0xff>;
+			qcom,ports-hstop =		/bits/ 8 <0xff 0xff 0xff 0xff 0xff>;
+			qcom,ports-word-length =	/bits/ 8 <0xff 0xff 0xff 0xff 0xff>;
+			qcom,ports-block-pack-mode =	/bits/ 8 <0xff 0xff 0xff 0xff 0xff>;
+			qcom,ports-block-group-count =	/bits/ 8 <0xff 0xff 0xff 0xff 0xff>;
+			qcom,ports-lane-control =	/bits/ 8 <0xff 0x01 0x02 0x00 0x00>;
```

**NO tocar `qcom,din-ports = <4>`** (es correcto). **NO tocar `swr1`** (ya tiene `qcom,din-ports = <1>` y 12 entradas en sus arrays; el SM8750 heredó el fix de `swr1` del SM8650 pero **se olvidó de `swr2`**).

> Nota sobre `swr2` del SM8650: el fix también cambió `qcom,din-ports` de `swr1` de `<0>` a `<1>`. En el SM8750 ese lado ya está bien; solo falta `swr2`.

### 2.2 Dónde aplicarlo en NUESTRO árbol (dos opciones)

**Opción A (recomendada para nuestro flujo) — override en el board DTS**, en `kernel/dts/cq8725s-ayn-common.dtsi`, dentro del bloque `&swr2 { }` que ya tenemos:

```dts
&swr2 {
	status = "okay";

	/* Fix mainline sm8750.dtsi: hardware tiene 1 dout port, el DT decía 0
	 * (equivale al fix SM8650 de Neil Armstrong, commit c0bec4b58b8e). */
	qcom,dout-ports = <1>;

	qcom,ports-sinterval-low =	/bits/ 8 <0x00 0x01 0x01 0x03 0x03>;
	qcom,ports-offset1 =		/bits/ 8 <0x00 0x00 0x00 0x01 0x01>;
	qcom,ports-offset2 =		/bits/ 8 <0x00 0x00 0x00 0x00 0x00>;
	qcom,ports-hstart =		/bits/ 8 <0xff 0xff 0xff 0xff 0xff>;
	qcom,ports-hstop =		/bits/ 8 <0xff 0xff 0xff 0xff 0xff>;
	qcom,ports-word-length =	/bits/ 8 <0xff 0xff 0xff 0xff 0xff>;
	qcom,ports-block-pack-mode =	/bits/ 8 <0xff 0xff 0xff 0xff 0xff>;
	qcom,ports-block-group-count =	/bits/ 8 <0xff 0xff 0xff 0xff 0xff>;
	qcom,ports-lane-control =	/bits/ 8 <0xff 0x01 0x02 0x00 0x00>;

	wcd_tx: codec@0,3 {
		compatible = "sdw20217010e00";
		reg = <0 3>;

		qcom,tx-port-mapping = <2 2 3 4>;
	};
};
```

(Las propiedades redefinidas en el override **reemplazan** las del nodo base, así que no hace falta `/delete-property/`.)

**Opción B (forma upstreamable) — parche de kernel contra `sm8750.dtsi`**, un `.patch` nuevo en `kernel/sm8750/patches/20-sm8750/` con el diff de §2.1. Es lo que cabría proponer aguas arriba (equivale a pedir a Qualcomm/Linaro el `sm8750: fix soundwire ports properties`).

### 2.3 Lo que **NO** hace falta cambiar (verificado)

- **`sound-dai = <&lpass_txmacro 0>`**: correcto (idéntico a `sm8750-mtp.dts:158`).
- **No existe `qcom,swr-tx-port`**: el binding de WCD939x (`Documentation/devicetree/bindings/sound/qcom,wcd939x.yaml`) no define ese property. El TX se enlaza con `qcom,tx-device = <&wcd_tx>` (ya en nuestro DTS) + `qcom,tx-port-mapping` (ya en nuestro DTS).
- **No hacen falta `qcom,dout-ports`/`qcom,din-ports` en el nodo del códec** (`codec@0,3`): esos properties son del **controlador** (`soundwire@...`).
- **No hace falta DMIC clock en DT**: el reloj de los DMIC internos del WCD939x es interno; `wcd939x.c` lo habilita al encender el DMIC (DAPM event `wcd939x_tx_swr_ctrl` → `dmic_clk_en`). No hay property `qcom,dmic-clk-rate` en el binding.
- **Topología**: `SM8750-AYN-tplg.bin` ya trae `TX_CODEC_DMA_TX_3 Capture` + `MultiMedia3 Capture`. **No hay que tocar el tplg** para la captura WCD.

---

## 3. Patches upstream / ROCKNIX / armada y si aplican a nuestro árbol

| Qué | Dónde | Estado | ¿Aplica a nuestro árbol? |
|---|---|---|---|
| `soundwire: qcom: deprecate qcom,din/out-ports` (introduce el chequeo) | `torvalds/linux` commit `9e53a66a2f2fd2c379fa1bd782e5cee37b0f75d3` (12/09/2025) | mergeado | Ya lo tenemos (es la causa del mensaje) |
| **`arm64: dts: qcom: sm8650: fix soundwire ports properties`** | `torvalds/linux` commit **`c0bec4b58b8e740236d9ac338821f78dbf784546`** (Neil Armstrong, serie `20260420-topic-sm8650-upstream-cpu-props-v2`, patch 3/3) | **mergeado en mainline** (solo sm8650.dtsi) | **El hunk `swr2` aplica 1:1 a sm8750.dtsi** (contenido idéntico, cambia solo la dirección `6d30000`→`7630000`). El hunk `swr1` NO (el SM8750 ya tiene `din-ports=1`) |
| Mismo parche en ROCKNIX/armada (fuera de árbol) | `projects/ROCKNIX/devices/SM8650/patches/linux/v2_20260420_neil_armstrong_arm64_qcom_sm8650_misc_enhancements.patch` (y `packages/kernel/patches/` en armada) | aplicado **solo a SM8650** | No toca SM8750. Es el punto de partida exacto para portar |
| `0074-soundwire-qcom-PCM-data-port-format-enable.patch` (ROCKNIX/armada/armbian SM8750) | toca `drivers/soundwire/qcom.c` (PCM port format para el puerto HIFI_PCM de **auriculares**) | fuera de árbol | **No es lo nuestro**: es para el modo PCM del headphone, no para el micro. No confundir |
| `0560-ASoC-codecs-lpass-tx-macro-switch-to-pm-clock-framework.patch` (armada) | `lpass-tx-macro.c` | fuera de árbol | Relacionado con relojes del TX macro; revisar **solo si** tras el fix DTS siguen faltando relojes del TX macro (ver §5, hipótesis H2/H5) |

**Conclusión**: el fix correcto existe (SM8650, mergeado), pero **falta portarlo al SM8750**. No hay un parche listo para SM8750 en ningún sitio. Nos toca escribirlo (Opción A o B de §2.2).

---

## 4. Evidencia de que el micro es DMIC interno del WCD939x (no VA macro, no DMIC GPIO)

Fuente: `LineageOS/android_kernel_ayn_cq8725s-devicetrees`, rama `lineage-24.0`, fichero `moorechip/audio/sun-audio-ayn-odin3.dtsi` (la placa se llama `sun`/`sunp` = Snapdragon 8 Elite, mismo silicio que el SM8750).

- El `qcom,audio-routing` de AYN declara, entre otros:
  ```
  "DMIC2", "MIC BIAS3",
  "DMIC2", "Digital Mic3",
  "DMIC3", "MIC BIAS3",
  "DMIC3", "Digital Mic3",
  ```
  → el micro interno son los **DMIC2 y DMIC3 internos del WCD939x** (no AMIC, no DMIC por GPIO).
- El overlay base (`sun-audio-overlay.dtsi`) trae `qcom,cdc-dmic01-gpios` / `cdc-dmic23-gpios` / `cdc-dmic45-gpios`, y AYN hace:
  ```
  /delete-property/ qcom,cdc-dmic01-gpios;
  /delete-property/ qcom,cdc-dmic23-gpios;
  /delete-property/ qcom,cdc-dmic45-gpios;
  ```
  y deshabilita los pinctrl `cdc_dmic01_gpios` … `cdc_dmic67_gpios` → **no hay DMIC externo por GPIO**; los DMIC son los internos del códec (que no necesitan GPIO).
- Los altavoces son `awinic,aw883xx_smartpa` en i2c (familia de nuestro `aw88166`), coherente con nuestro DTS.

Esto **confirma y cierra** la pregunta que dejó abierta `MICROFONO-INVESTIGACION.md` §2.C: el micro interno va por el **WCD** (ruta `wcd-capture-dai-link` → `hw:0,2`), no por el VA macro. El camino de la Fase 2 de aquel documento (VA macro) **no aplica**.

### Ruteo del mixer esperado (para después del fix DTS)

En mainline el camino interno del DMIC se arma así (dos lados):

1. **Códec WCD939x** (widgets en `sound/soc/codecs/wcd939x.c`): encender el DMIC → `DMIC2` (o `DMIC3`) + `DMIC2_MIXER` / `DMIC3_MIXER` (`DMICn Switch`). El reloj DMIC se habilita solo.
2. **TX macro** (`sound/soc/codecs/lpass-tx-macro.c`): el decimador que alimenta `TX_CODEC_DMA_TX_3` se alimenta por SoundWire (`TX DECn MUX = SWR_MIC`), y `TX SMIC MUX0..11` elige el canal SWR_MIC que transporta el DMIC. Controles presentes (verificado): `TX DMIC MUX0..7` (ZERO/DMIC0..7), `TX SMIC MUX0..11` (ZERO/SWR_MIC0..10), `TX0..3 MODE`.

El valor concreto de `TX SMIC MUX` (SWR_MICx) se determina empíricamente tras el fix DTS (el `qcom,tx-port-mapping = <2 2 3 4>` mapea los canales; en el Odin 2 —wcd938x— era `SWR_MIC7`). **Orden de prueba en §5.**

---

## 5. Orden de pruebas sugerido (qué medir y qué descartaría cada hipótesis)

> Todo en la Odin, tras recompilar el kernel con el fix y flashear KERNEL + módulos (regla de oro: kernel y módulos del **mismo build**, mirar md5 del `Image`).

**H1 — El `dout-ports = 0` de `swr2` bloquea la captura.**
1. `dmesg | grep -iE 'soundwire|dout-ports'` → **debe desaparecer** `dout-ports (0) mismatch with controller (1)`.
2. `arecord -D hw:0,2 -f S16_LE -r 48000 -c 2 -d 5 /tmp/mic.raw -v`.
   - Si **lee** (no EIO) y `-v` muestra overruns/datos → H1 confirmada; pasar a H4 para señal real.
   - Si **sigue EIO** → H1 solo parcialmente (el port ya está bien, queda otro bloqueador); revisar H2/H5.
   - Si desaparece el warning **pero** `arecord` sigue EIO **y** `dmesg` al abrir captura muestra `q6apm ... CMD timeout` → mirar H2.

**H2 — El timeout `q6apm gprsvc:service:2:1: CMD timeout for [1001021]` (opcode `0x01001021` = `APM_CMD_GET_SPF_STATE`) deja el ADSP a medias.**
- `1001021` = `APM_CMD_GET_SPF_STATE` (ver `sound/soc/qcom/qdsp6/audioreach.h:40`), emitido por `q6apm_get_apm_state()` → `q6apm_is_adsp_ready()`, llamado en el probe de `q6prm` (`q6prm.c:215`: si no está listo → `-EPROBE_DEFER`).
- Medir: `dmesg | grep -iE 'q6apm|q6prm|EPROBE_DEFER|adsp'` y `lsmod | grep -E 'tx-macro|q6apm|apr'`, `/sys/bus/soundwire` y si `hw:0,2` aparece.
- Interpretación: si es solo un aviso de boot (playback funciona) es **benigno/transitorio**; si reaparece **al abrir captura**, es bloqueador. **Este aviso no es la causa directa del EIO** (es un health-check de probe), pero un ADSP que no responde GET_SPF_STATE sugiere firmware de audio que no está del todo audioreach-compliant.

**H3 — La topología no tiene el grafo de captura.**
- **Ya descartada**: `strings SM8750-AYN-tplg.bin | grep -E 'TX_CODEC_DMA_TX_3|MultiMedia3 Capture'` devuelve ambas. No tocar el tplg.

**H4 — Ruteo del DMIC incorrecto (silencio o ruido tras arreglar el EIO).**
- Con captura ya leyendo, probar en este orden y medir nivel con `arecord -v` / `pw-top`:
  1. `amixer -D hw:0 sset 'TX0 MODE' ADC_HIFI` (o `ADC_NORMAL`)
  2. `amixer -D hw:0 sset 'TX DMIC MUX0' DMIC2` (o `DMIC3`)
  3. `amixer -D hw:0 sset 'DMIC2 Switch' on` (o `DMIC3 Switch`)
  4. `amixer -D hw:0 sset 'MultiMedia3 Mixer TX_CODEC_DMA_TX_3' on`
  5. Alternar `TX SMIC MUX0` entre `SWR_MIC0..10` y ver cuál da nivel (si el DMIC viaja como SWR_MIC).
- Si todo da ruido idle 270–400 sin responder → el canal SWR_MIC elegido no es el del DMIC (probar el resto) o falta bias (menos probable para DMIC interno).

**H5 — Relojes del TX macro (solo si tras el fix DTS sigue EIO).**
- `dmesg | grep -iE 'tx-macro|lpass|mclk|fsgen'` y `lsmod | grep tx-macro`.
- Si el `lpass_txmacro` no tiene reloj (`mclk`/`macro`/`dcodec`/`fsgen`), valorar portar el parche armada `0560-ASoC-codecs-lpass-tx-macro-switch-to-pm-clock-framework.patch`.

**Resultado final esperado**: `pw-cli list-objects | grep -i node.name` muestra un source de captura, y `arecord -D hw:0,2 … -v` con nivel real (> −60 dB) al hablar.

---

## 6. Anexo — repos y commits mirados

### Repos clonados / inspeccionados (PC)
- `/tmp/opencode/research-mic/armada` — `armada-os/armada` (shallow). Parches de kernel en `packages/kernel/patches/`, DTS en `packages/kernel/dts/`.
- `/home/fransis/pocknix-odin3-project/distribution` — `ROCKNIX/distribution` (shallow, rama `next`, HEAD `18aded58`). `projects/ROCKNIX/devices/SM8650/patches/linux/` y `.../SM8750/patches/linux/`.
- `/home/fransis/pocknix-odin3-project/pocknix-os/build/kernel/sm8750/linux-7.2.9` — árbol de kernel local (base de referencia; `sm8750.dtsi`, `sm8650.dtsi`, `drivers/soundwire/qcom.c`, `sound/soc/codecs/wcd939x.c`, `lpass-tx-macro.c`, `sound/soc/qcom/qdsp6/*`).
- `torvalds/linux` (vía raw.githubusercontent.com + GitHub API): `sm8750.dtsi`, `sm8650.dtsi`.
- `LineageOS/android_kernel_ayn_cq8725s-devicetrees` (rama `lineage-24.0`): `moorechip/audio/sun-audio-ayn-odin3.dts`, `sun-audio-ayn-odin3.dtsi`.

### Commits / parches clave
| Ref | Descripción |
|---|---|
| `9e53a66a2f2fd2c379fa1bd782e5cee37b0f75d3` | `soundwire: qcom: deprecate qcom,din/out-ports` — introduce el chequeo que produce el warning (2025-09-12) |
| `c0bec4b58b8e740236d9ac338821f78dbf784546` | `arm64: dts: qcom: sm8650: fix soundwire ports properties` — **el fix de referencia** (Neil Armstrong), mergeado; **falta su equivalente para sm8750** |
| `v2_20260420_neil_armstrong_arm64_qcom_sm8650_misc_enhancements.patch` (ROCKNIX `SM8650`, armada) | misma serie, fuera de árbol; el hunk 3/3 (`swr2`: `dout-ports 0→1` + prepend `0x00/0xff` a arrays) es **el modelo exacto** a portar |
| `0074-soundwire-qcom-PCM-data-port-format-enable.patch` (ROCKNIX/armada/armbian SM8750) | PCM port format para el **headphone** HIFI_PCM; **no** aplica al micro |
| `0560-ASoC-codecs-lpass-tx-macro-switch-to-pm-clock-framework.patch` (armada) | relojes del TX macro (PM clock); candidato si H5 |
| `0564-soundwire-qcom-force-runtime-suspend-across-system-sleep.patch` (armada) | runtime-suspend de SoundWire; no relacionado con captura |

### Issues/PRs
- `armada-os/armada#362` — "Internal microphone not functional on AYN Odin 3 (SM8750)" (abierta; documenta el EIO y el barrido de SWR_MIC/DMIC).
- `shuuri-labs/pocknix-os#135` — nuestro PR (menciona el `dout-ports mismatch` como observación).
- `armbian/build#11044` — "bump SM8750 edge kernel to 7.2.11…" (confirma 7.2.11 como kernel edge SM8750; no lleva fix de puertos).

### Nodos DTS de referencia comparados
- `sm8750.dtsi` `swr2: soundwire@7630000` (label TX) → `qcom,dout-ports = <0>` (BUG, presente en 7.2.9 y en `torvalds/master`).
- `sm8750.dtsi` `swr1: soundwire@6ad0000` (label RX) → `qcom,din-ports = <1>`, `qcom,dout-ports = <11>` (correcto).
- `sm8650.dtsi` `swr2: soundwire@6d30000` en `torvalds/master` → `qcom,dout-ports = <1>` (ya arreglado; prueba de que el fix mergeó para SM8650 y no para SM8750).
- `sm8750-mtp.dts` / `sm8650-qrd.dts` → dai-link `wcd-capture-dai-link` con `sound-dai = <&wcd939x 1>, <&swr2 0>, <&lpass_txmacro 0>` y `qcom,tx-port-mapping = <2 2 3 4>` (igual que nuestro `cq8725s-ayn-common.dtsi`).

---

## 7. RESULTADO EN HARDWARE (21/10, atardecer)

Probado en la consola con kernels de diagnóstico (`7.2.11-10/11`, prints temporales en
`q6apm-dai` y `q6apm-lpass-dais`, ya retirados en `-12`).

### Lo que se descartó
- **`swr2` dout-ports** (fix `1030`, upstream `c0bec4b5`): el aviso
  `dout-ports (0) mismatch with controller (1)` **desaparece**, pero la captura sigue en EIO.
- **Relojes del TX macro** (armada `0560` → PM clocks): aplicado, reproducción intacta,
  captura sigue en EIO.
- **Topología**: probada la de **Kaanapali-MTP** (38 KB, linux-firmware) en lugar de la de AYN
  (18 KB, Android): reproducción OK, captura **igual de rota** → no es la tplg.
- **DTS del dai-link**: idéntico al de `sm8750-mtp.dts` (codec `wcd939x 1` + `swr2 0` +
  `lpass_txmacro 0`; cpu `q6apmbedai TX_CODEC_DMA_TX_3`).
- **Muxes del códec**: `TX0 MODE=ADC_HIFI` + `TX DMIC MUX0` = DMIC0/1/2/3 + `MultiMedia3 Mixer`
  on → EIO siempre.

### Lo que se midió (con prints)
```
q6apm-dai  DIAG: graph_open ERR <basura>      ← el FE falla al abrir su grafo
q6apm-lpass-dais DIAG: prepare dai_id=120 stream=1 graph=...   ← el BE SÍ se prepara
q6apm-dai  DIAG: graph_prepare... / graph_start...
q6apm-lpass-dais DIAG: trigger dai_id=120 cmd=1 → cmd=0 (0,6 s)
```
- **El BE (dai 120 = TX_CODEC_DMA_TX_3) sí se prepara y arranca.**
- **El FE falla en `q6apm_graph_open`** para el stream de captura → el DSP no tiene grafo de
  captura que empujar y `read` devuelve EIO a los 0,6 s.
- `graph_id` que usa el FE = **2** (viene de `cpu_dai->driver->id`, es decir, de la tplg).

### Conclusión y siguiente paso
El bloqueo está en el **mapeo FE→grafo de la topología**: el id 2 que mainline usa para el FE de
captura no corresponde a un grafo de captura válido en estas tplg (ni la de Android ni la MTP).
Siguiente línea de trabajo:
1. Decodificar la tplg (`SM8750-AYN-tplg.bin`) para listar sus `graph_id` de captura reales
   (estructura GKV — se puede volcar con un parser propio o con `q6apm` en modo debug).
2. Comparar con lo que espera `q6apm-dai` (`cpu_dai->driver->id`), y/o generar una tplg propia
   (ROCKNIX tiene tooling de topology para SM8650/SM8750).
3. Alternativa corta: preguntar en ROCKNIX/armada si tienen captura funcionando en algún SM8750
   (Odin 3/Thor) y con qué tplg.
