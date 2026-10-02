# Micrófono interno del AYN Odin 3 (SM8750) — investigación de bring-up

**Fecha**: 01/10/2026
**Estado**: investigación cerrada, **nada aplicado**. Solo documentación + borradores.
**Ámbito**: Pocknix / ROCKNIX, kernel `linux-7.2.6`, `cq8725s-ayn-common.dtsi`
**Documento previo**: [`MICROFONO-PENDIENTE.md`](MICROFONO-PENDIENTE.md) (estado del 16/09/2026, sigue vigente como resumen de symptoms)

---

> ## ⚠️ CORRECCIÓN (02/10/2026) — LEER ANTES QUE NADA
>
> La conclusión principal de este documento (§2.C: "el micro va por el **VA macro**") **es
> incorrecta**. Se ha medido en el Android stock del AYN (Fase 0) y el micrófono interno va por el
> **códec WCD939x** (`primary_in` → `SWR_MIC` / `TX DMIC MUX`), no por el LPASS VA macro.
>
> Consecuencias:
> - **B5 (la topología DSP) NO bloquea nada**: no hace falta sustituir `SM8750-AYN-tplg.bin`.
> - **La Fase 2 (DTS del va-macro + recompilar kernel) no hace falta.**
> - El camino bueno es el del **Odin 2** (WCD): UCM + routing, y si no aparece captura, el
>   **reloj DMIC del WCD** (§8.4).
>
> Evidencia y resultado completo: [`microfono-borradores/06-fase0-resultado-android.md`](microfono-borradores/06-fase0-resultado-android.md).
> Las secciones B1-B4 siguen siendo ciertas como descripción del estado del VA macro en el DT, pero
> son **irrelevantes para el micrófono interno**.

## 0. TL;DR

En el Odin 3 **el micrófono interno no tiene ninguna ruta de captura en Linux**, y la causa **no es
el UCM ni el `audio-routing`**: es que **falta el hardware path completo del códec VA (LPASS VA
macro)**, que es el bloque que en el SoC SM8750 gestiona los **micrófonos digitales (DMIC) de 1
bit**, que es como el Odin 3 cablea su micro interno.

Hay **4 bloqueadores**, verificados en el código y el firmware:

| # | Bloqueador | Dónde |
|---|---|---|
| **B1** | El nodo `sound` **no declara ningún `va-dai-link`** → no existe PCM de captura VA | `kernel/dts/cq8725s-ayn-common.dtsi` nodo `sound` |
| **B2** | `&lpass_vamacro` **y `&lpass_tlmm` están deshabilitados** (sin `status = "okay"`) → no se instancia el platform device, el módulo `snd-soc-lpass-va-macro.ko` nunca se carga | `sm8750.dtsi:2605-2618` y `:2620+` |
| **B3** | Falta `vdd-micb-supply` en `&lpass_vamacro` → el widget `vdd-micb` del códec queda **dummy**, no hay alimentación de mic-bias | `lpass-va-macro.c:1141` |
| **B4** | Falta el **pinctrl DMIC** (`dmic01_default`, `dmic23_default`) en `&lpass_vamacro` → los pines gpio6/7 y gpio8/9 del `lpass_tlmm` no se configuran como DMIC | `sm8750.dtsi:2669-2700` |

Y hay un **quinto bloqueador, externo a nuestro control y el más importante de todos**:

| # | Bloqueador | Dónde |
|---|---|---|
| **B5** | La **topología DSP** que se carga (`SM8750-AYN-tplg.bin`) **no contiene la HwGraph `VA_CODEC_DMA_TX_0`** ni su `MultiMedia4` → aunque arreglemos B1-B4, el DSP no tiene por dónde enrutar el DMIC | `.../firmware/qcom/sm8750/SM8750-AYN-tplg.bin` |

**Conclusión operativa**: aplicar B1-B4 sin resolver B5 produce un PCM 3 que existe en ALSA pero
**no tiene ruta en el DSP** → silêncio o `I/O error`, y un `SectionDevice."Mic"` que lo use puede
**tumbar el perfil de audio entero** (ver §7). **B5 va primero.**

---

## 1. Cómo se decide qué micrófono existe (mapa de decisión)

Para saber si un micrófono puede funcionar hay que atravesar, en este orden:

```
1. ¿Hay un dai-link en el DT?           (nodo `sound` → platform device → ALSA PCM)
2. ¿El platform device está enabled?    (status = "okay" en el .dtsi)
3. ¿El códec (component) se registra?   (snd_soc_register_component en el probe)
4. ¿La topología DSP (.tplg.bin) tiene la HwGraph correspondiente?
   (Si la HwGraph no está, el link se crea pero no hay BE en el DSP → EIO / silencio)
5. ¿Los pinctrl / clerks / bias están configurados en el DT?
6. ¿El UCM (alsa-ucm-conf) enciende la ruta con csets correctos?
7. ¿PipeWire/ALSA abre el PCM sin que el perfil se descarte?
```

Hoy el Odin 3 **falla en el paso 1** y, si se arreglara, fallaría en el **4**.

---

## 2. Las dos rutas de micrófono posibles en un SM8750

El SM8750 tiene **dos familias de rutas de captura**, y es crucial saber cuál usa el Odin 3:

### 2.A Ruta WCD9395 (`&wcd939x` + `&swr2` + `&lpass_txmacro`) — "micrófonos analógicos y DMIC internos del códec"

- Va por SoundWire (`swr2`) al **códec analógico WCD9395** (`qcom,wcd9395-codec`, `cq8725s-ayn-common.dtsi:29-54`).
- Cubre: **AMIC** analógicos (headset, `ADC1..ADC4`), **SWR_MIC** (micrófonos externos por SWR) y **DMIC0..DMIC7** (los DMIC/SP Filter *internos* del WCD9395, con su reloj interno, sin pines externos).
- **Ya está en el DT**: el dai-link `wcd-capture-dai-link` (`cq8725s-ayn-common.dtsi:171-186`) → CPU `TX_CODEC_DMA_TX_3`.
- Es el PCM **2** (`hw:0,2`).
- El driver mainline `sound/soc/codecs/wcd939x.c` **sí** tiene los widgets `DMIC1..DMIC8 Switch` (SOC_SINGLE_EXT, ~línea 2835) y los widgets `DMIC*` ADC/MIXER/OUTPUT.
- **No necesita `audio-routing`**: los DMIC del WCD son entradas internas del códec, no pines con widget de entrada.
- **Requiere**: clocking/feed-forward interno del WCD, DMIC clock (`qcom,dmic-clk-rate`) y, si fuera AMIC, mic-bias (`qcom,micbias1..4-microvolt` — **ya presentes** en `:36-39`).

### 2.B Ruta VA macro (`&lpass_vamacro`) — "DMIC de 1 bit del LPASS TLMM"

- El **LPASS TLMM** tiene 2 pares de DMIC como GPIO: `gpio6`=dmic1_clk, `gpio7`=dmic1_data, `gpio8`=dmic2_clk, `gpio9`=dmic2_data (`sm8750.dtsi:2669-2700`).
- Los lleva el **VA macro** (`qcom,sm8750-lpass-va-macro`, reg `0x0 0x07660000`, `sm8750.dtsi:2605-2618`), cuyo único códec (`va_macro_dais[]`, `lpass-va-macro.c:957+`) es **solo captura** (`va_macro_tx1/tx2/tx3`, `.capture`, `channels_min=1`).
- El códec tiene además un **mic-bias** (`vdd-micb`, `SND_SOC_DAPM_REGULATOR_SUPPLY("vdd-micb",0,0)`, `lpass-va-macro.c:1141`).
- Va al DSP por `VA_CODEC_DMA_TX_0` (en el tplg del MTP, este es el `MultiMedia4`).
- **En el DTS del AYN no hay absolutamente nada de esto**: no dai-link, no status, no pinctrl, no micb.

### 2.C ¿Cuál usa el Odin 3? — **No está determined al 100 %** (requiere hardware)

Lo que sabemos (razonamiento, no hecho):

- **A favor de 2.A (WCD DMIC):** el barrido de la issue ArmadaOS #362 encontró los 8 `MSM_DIC` y los 12 `SWR_MIC` presentes en la mixer interface, es decir el códec WCD está **en línea y habla**. Si el micro estuviera en el WCD, alguno debería dar señal → **argumento en contra**.
- **A favor de 2.B (VA macro):** el barrido de #362 **no pudo tocar la ruta VA macro en absoluto** (no existe PCM, el módulo ni siquiera se carga) → el resultado "todo ruido idle" **no dice nada** sobre 2.B. Este es el punto que la issue pasada por alto.
- **Indicio fuerte en contra de 2.A:** los DMIC del WCD9395 (filtros SP) tienen **clock interno** y no dependen de `audio-routing`; si estuvieran bien y nadie los energiza... el resultado "ruido idle 270-400 que no responde al sonido" es el síntoma típico de **un DMIC clock no presente**. Es decir, **más probable que falte el DMIC clock del WCD** que "el micro esté en otro sitio".
- **Indicio fuerte a favor de 2.B:** el DTS del AYN **ya trae** `qcom,dmic-sample-rate = <4800000>` en `&lpass_vamacro` (`cq8725s-ayn-common.dtsi:961-963`), línea **copiada del MTP**, que **solo** tiene sentido si hay un DMIC de 1 bit detrás. Sugiere que AYN/AYN-Odin3 copiaron el bloque MTP parcialmente.
- **Indicio fuerte a favor de 2.B:** el MTP (`sm8750-mtp.dts:978-984`) y el QRD (`sm8750-qrd.dts:179-190`) **sí** tienen el bloque completo de DMIC en el VA macro. Es la configuración de referencia de Qualcomm para SM8750 y el Odin 3 comparte plataforma.

**Cómo resolverlo sin tocar el audio**: ver §9 Fase 0 (extraer el DT y los ficheros de la topología del Android stock del AYN por `adb pull`). Ahí está la verdad: si el `board.dts` de AYN declara `&lpass_vamacro { status="okay"; pinctrl-0=<&dmic01_default>... }`, es 2.B.

> ⚠️ **Este es el único punto de toda la investigación que no se puede cerrar con el material disponible.** Todo lo demás está verificado contra código y binarios.

---

## 3. Bloqueador B1 — falta el `va-dai-link`

**Verificado.** `cq8725s-ayn-common.dtsi`, nodo `sound` (línea 120), contiene **exactamente 3 dai-links**:

| dai-link | `link-name` | CPU DAI | PCM |
|---|---|---|---|
| `spk-i2s-dai-link` (139) | Secondary MI2S Playback | `SECONDARY_MI2S_RX` | **0** |
| `wcd-playback-dai-link` (155) | WCD Playback | `RX_CODEC_DMA_RX_0` | **1** |
| `wcd-capture-dai-link` (171) | WCD Capture | `TX_CODEC_DMA_TX_3` | **2** |

**No hay `va-dai-link`.** El MTP sí (`sm8750-mtp.dts:186-198`) y el QRD también
(`sm8750-qrd.dts:179-190`):

```dts
va-dai-link {
        link-name = "VA Capture";
        codec { sound-dai = <&lpass_vamacro 0>; };
        cpu   { sound-dai = <&q6apmbedai VA_CODEC_DMA_TX_0>; };
        platform { sound-dai = <&q6apm>; };
};
```

→ Añadiéndolo **al final** del nodo `sound`, el PCM de captura VA será el **3**
(`hw:${CardId},3`), que es exactamente lo que usa el UCM del MTP (`Qualcomm-sm8750/MTP/HiFi.conf`:
`CapturePCM "hw:${CardId},3"`).

---

## 4. Bloqueador B2 — `lpass_vamacro` y `lpass_tlmm` deshabilitados

**Verificado.**

`sm8750.dtsi:2605-2618`:
```dts
lpass_vamacro: codec@7660000 {
        compatible = "qcom,sm8750-lpass-va-macro", "qcom,sm8550-lpass-va-macro";
        reg = <0x0 0x07660000 0x0 0x2000>;
        clocks = <&q6prmcc LPASS_CLK_ID_TX_CORE_MCLK LPASS_CLK_ATTRIBUTE_COUPLE_NO>,
                 <&q6prmcc LPASS_HW_MACRO_VOTE ...>,
                 <&q6prmcc LPASS_HW_DCODEC_VOTE ...>;
        clock-names = "mclk", "macro", "dcodec";
        #clock-cells = <0>;
        clock-output-names = "fsgen";
        #sound-dai-cells = <1>;
};                                  /* <-- NO HAY `status` */
```

`sm8750.dtsi:2620+`:
```dts
lpass_tlmm: pinctrl@7760000 {
        compatible = "qcom,sm8750-lpass-lpi-pinctrl", "qcom,sm8650-lpass-lpi-pinctrl";
        reg = <0x0 0x07760000 0x0 0x20000>;
        ... gpio-controller; #gpio-cells = <2>; ...
};                                  /* <-- NO HAY `status` */
```

En Device Tree, **sin `status` = `disabled`** (`/proc/device-tree/.../status` ausente). Consecuencias
exactas:

1. No se instancia el platform device → **no hay `va_macro` component** en la tarjeta.
2. El dai-link (si se añadiera) fallaría al resolver `<&lpass_vamacro 0>` → **`snd_soc_of_parse` da
   `-EPROBE_DEFER` y la tarjeta no registra**.
3. El módulo `snd-soc-lpass-va-macro.ko` (existe en el build:
   `sound/soc/codecs/snd-soc-lpass-va-macro.ko`, `CONFIG_SND_SOC_LPASS_VA_MACRO=m`) **nunca se
   autoloada** (nada en DT dice `"qcom,sm8750-lpass-va-macro"` a modprobe).

**Nuestro** `cq8725s-ayn-common.dtsi:961-963` solo añade la sample-rate, sin `status`:

```dts
&lpass_vamacro {
        qcom,dmic-sample-rate = <4800000>;
};
```

**Comparación MTP** (`sm8750-mtp.dts:976-978`): hay un `status = "okay"` inmediatamente antes, en un
bloque previo — confirmando que el MTP sí lo enciende.

**Nota sobre el binding**: `va_macro_dt_match[]` (`lpass-va-macro.c:1762-1770`) **no tiene entrada
para `qcom,sm8750-lpass-va-macro`**, solo `qcom,sm8550-lpass-va-macro` → `sm8550_va_data`. Funciona
porque el nodo declara **los dos compatibles** y `of_match` hace fallback al segundo. No hay que
tocar nada.

---

## 5. Bloqueador B3 — falta `vdd-micb-supply`

**Verificado.** `lpass-va-macro.c:1141`:

```c
SND_SOC_DAPM_REGULATOR_SUPPLY("vdd-micb", 0, 0),
```

`SND_SOC_DAPM_REGULATOR_SUPPLY` se resuelve contra la propiedad `vdd-micb-supply` del nodo DT. **Si no
existe, el widget se registra como "dummy"** y no enciende nada. Es el mic-bias (alimentación de los
micrófonos). Sin él, un DMIC pasivo detrás no tiene alimentación → silencio/ruido.

El binding lo documenta como opcional
(`Documentation/devicetree/bindings/sound/qcom,lpass-va-macro.yaml`: `vdd-micb-supply: description:
phandle to voltage regulator of MIC Bias`), pero para **DMIC es imprescindible**.

**MTP** (`sm8750-mtp.dts:982`): `vdd-micb-supply = <&vreg_l1b_1p8>;`

**Nuestro DTS ya tiene** `vreg_l1b_1p8` declarado (`cq8725s-ayn-common.dtsi:376-377`,
`regulator-name = "vreg_l1b_1p8"`) → el phandle `<&vreg_l1b_1p8>` es **directamente utilizable**
sin tocar nada más. (Nota: `sm8750-pmics.dtsi` de upstream **no** lo define; el AYN lo declara en su
propio `.dtsi` de reguladores.)

⚠️ **Sin hardware no se puede saber** si el mic del Odin 3 necesita bias externo o si es un DMIC de
1 bit auto-alimentado. En el MTP está declarado, y el MTP **sí** tiene DMIC funcionando en
referencia, así que es el valor por defecto seguro.

---

## 6. Bloqueador B4 — falta el pinctrl DMIC

**Verificado.** En `sm8750.dtsi:2669-2700` (dentro de `lpass_tlmm`):

```dts
dmic01_default: dmic01-default-state {
        clk-pins  { pins = "gpio6"; function = "dmic1_clk";  drive-strength = <8>; output-high; };
        data-pins { pins = "gpio7"; function = "dmic1_data"; drive-strength = <8>; input-enable; };
};
dmic23_default: dmic23-default-state {
        clk-pins  { pins = "gpio8"; function = "dmic2_clk";  drive-strength = <8>; output-high; };
        data-pins { pins = "gpio9"; function = "dmic2_data"; drive-strength = <8>; input-enable; };
};
```

MTP (`sm8750-mtp.dts:978-984`):
```dts
&lpass_vamacro {
        pinctrl-0 = <&dmic01_default>, <&dmic23_default>;
        pinctrl-names = "default";
        vdd-micb-supply = <&vreg_l1b_1p8>;
        qcom,dmic-sample-rate = <4800000>;
};
```

**Nuestro** no tiene pinctrl → los 4 pines quedan en su **default de TLMM** (no DMIC) → no hay reloj
de DMIC ni línea de datos → **cero señal**, independientemente de todo lo demás.

---

## 7. Bloqueador B5 — la topología DSP no tiene `VA_CODEC_DMA_TX_0`

**Este es el bloqueador de verdad.** Verificado sobre los binarios.

### 7.1 Cómo se carga la topología (nombre del fichero)

`sound/soc/qcom/qdsp6/topology.c:1312-1321`:
```c
int audioreach_tplg_init(struct snd_soc_component *component)
{
        ...
        char *tplg_fw_name __free(kfree) = kasprintf(GFP_KERNEL, "qcom/%s/%s-tplg.bin",
                                                     card->driver_name,
                                                     card->name);
```

- `card->driver_name` = `of_device_get_match_data(dev)` (`sc8280xp.c:222`), valor `"sm8750"`
  (`sc8280xp.c:240`: `{.compatible = "qcom,sm8750-sndcard", "sm8750"}`).
- `card->name` = `model` del nodo `sound` = **`"SM8750-AYN"`** (`cq8725s-ayn-common.dtsi:132`).
- → Fichero: **`/lib/firmware/qcom/sm8750/SM8750-AYN-tplg.bin`**, cargado por `q6apm.c` →
  `audioreach_tplg_init`.

### 7.2 Contenido real de `SM8750-AYN-tplg.bin` (18236 bytes)

```
MultiMedia1                    (SECONDARY_MI2S_RX  → altavoz)
MultiMedia1 Playback / Volume
MultiMedia2                    (RX_CODEC_DMA_RX_0 → WCD/auriculares)
MultiMedia2 Playback / Volume
MultiMedia3 Mixer
MultiMedia3 Capture            (TX_CODEC_DMA_TX_3  → WCD capture = PCM 2)
SECONDARY_MI2S_RX Audio Mixer
RX_CODEC_DMA_RX_0 Audio Mixer
TX_CODEC_DMA_TX_3 Capture
```

**NO aparece `VA_CODEC_DMA_TX_0`. NO aparece `MultiMedia4`.**

### 7.3 Contenido de `SM8750-MTP-tplg.bin` (→ `../kaanapali/Kaanapali-MTP-tplg.bin`, 38540 B)

```
MultiMedia1 / 2        (playback)
MultiMedia3 Mixer / Capture      (TX_CODEC_DMA_TX_3)
MultiMedia4 Mixer / Capture      (VA_CODEC_DMA_TX_0)   <-- ¡AQUÍ!
MultiMedia5 / 6        (playback)
VA_CODEC_DMA_TX_0
VA_CODEC_DMA_TX_0 Capture
PRIMARY_MI2S_RX Audio Mixer      <-- ¡NO Secondary MI2S!
WSA_CODEC_DMA_RX_0 Audio Mixer
```

### 7.4 Por qué NO basta con sustituir el `.bin` por el del MTP

El tplg del MTP **no tiene `Secondary MI2S`**, y su `MultiMedia1` va por `PRIMARY_MI2S_RX`
(`device105.codec_dma_rx1`). El altavoz del Odin 3 está cableado a **Secondary MI2S** (nuestro
dai-link `spk-i2s-dai-link` + `pinctrl-0 = <&i2s1_default>` + `clocks = <&q6prmcc
LPASS_CLK_ID_SEC_MI2S_IBIT ...>` en `cq8725s-ayn-common.dtsi:123-131`).

**Sustituir el tplg rompe el altavoz.** Confirmado por barrido de todas las topologías presentes en
el rootfs (ninguna de SM8750 combina `VA_CODEC_DMA_TX_0` **y** `SECONDARY_MI2S`):

| tplg | `VA_CODEC_DMA_TX_0` | `SECONDARY_MI2S` |
|---|---|---|
| `sm8750/SM8750-AYN-tplg.bin` | **no** | sí |
| `sm8750/SM8750-KONKR-tplg.bin` | **no** | sí |
| `sm8750/SM8750-MTP-tplg.bin` (=Kaanapali) | sí | **no** |
| `sm8750/SM8750-QRD-tplg.bin` (=Kaanapali) | sí | **no** |
| `glymur/GLYMUR-CRD-tplg.bin` | sí | no |
| `sc8280xp/SC8280XP-LENOVO-X13S-tplg.bin` | sí | no |
| `qcs6490/QCS6490-RB3Gen2-tplg.bin` | sí | sí (otra SoC) |

### 7.5 Consecuencia práctica de aplicar B1-B4 sin B5

El dai-link VA se crearía y ALSA mostraría `device 3: MultiMedia4 Capture`. Pero al abrirlo:
- el FE no encuentra la HwGraph en el tplg cargado → **`read error: Input/output error`**
  (exactamente el síntoma que reporta la issue #362 con `hw:0,2`).
- Peor: si el UCM declara un `SectionDevice."Mic"` sobre ese PCM, el probe de PipeWire
  (`spa/plugins/alsa/acp/alsa-ucm.c`, `ucm_probe_profile_set`) abre **todos** los PCM del perfil y
  marca `p->supported = false` **en el perfil entero** si **uno solo** falla → la tarjeta deja de
  producir sinks y sources → **Dummy Output**. Está documentado en `MICROFONO-PENDIENTE.md`.

**Por eso el orden correcto es B5 primero.**

---

## 8. Other hallazgos relevantes

### 8.1 Numeración de PCM y por qué `hw:0,2` no sirve

Orden de dai-links en el DT → orden de PCM:

| PCM | dai-link | DAI | Tipo |
|---|---|---|---|
| 0 | `spk-i2s-dai-link` | `SECONDARY_MI2S_RX` | playback |
| 1 | `wcd-playback-dai-link` | `RX_CODEC_DMA_RX_0` | playback |
| **2** | `wcd-capture-dai-link` | `TX_CODEC_DMA_TX_3` | **capture (WCD: AMIC/SWR_MIC/DMIC del WCD)** |
| **3** | `va-dai-link` *(añadir)* | `VA_CODEC_DMA_TX_0` | capture (VA macro DMIC) |

`hw:0,2` **es la ruta WCD**, no el DMIC del VA macro. Por eso el barrido de #362 sobre
`SWR_MIC*`/`MSM_DMIC*` solo podría tocar la ruta WCD, y por eso no encontró nada útil.

### 8.2 `sc8280xp_be_hw_params_fixup` — de dónde sale el "solo S16_LE/48000/2ch"

`sc8280xp.c:73-101`:
```c
rate->min = rate->max = 48000;
snd_mask_set_format(fmt, SNDRV_PCM_FORMAT_S16_LE);
channels->min = 2; channels->max = 2;
switch (cpu_dai->id) {
case TX_CODEC_DMA_TX_0: case TX_CODEC_DMA_TX_1:
case TX_CODEC_DMA_TX_2: case TX_CODEC_DMA_TX_3:
        channels->min = 1;             /* <-- 1..2 canales */
        break;
}
```
Explica exactamente el `--dump-hw-params` de la issue #362. **No es un bug, es el fixup del machine
driver.** En el PCM 3 (`VA_CODEC_DMA_TX_0`) el `channels_min=1` también, coherente con
`va_macro_dais[].capture.channels_min = 1` (`lpass-va-macro.c:966`).

### 8.3 El `audio-routing` del Odin 3 **no** es lo que falta

El `audio-routing` de `cq8725s-ayn-common.dtsi:133-138`:
```
"IN1_HPHL","HPHL_OUT", "IN2_HPHR","HPHR_OUT",
"AMIC2","MIC BIAS2", "TX SWR_INPUT1","ADC2_OUTPUT"
```
es **idéntico** al del **Odin 2** (`qcs8550-ayn-common.dtsi:354-358`), y en el Odin 2 el micro
interno **sí funciona** (PR Armada #432, medido −29.8 dB) vía:
```
TX SMIC MUX0 = SWR_MIC7 ; DMIC3 on ; DMIC3_MIXER on ;
TX_AIF1_CAP Mixer DEC0 on ; DEC0 MODE = ADC_DEFAULT ; TX_DEC0 = 100
```
→ **El `audio-routing` NO habilita los DMIC internos del WCD**: esos son entradas internas del
códec, no pines con widget de entrada. **No hay que añadir entradas DMIC al `audio-routing`.**
(Confirmado: `wcd939x.c` no necesita entrada DAPM para DMIC; el path es interno.)

⚠️ Esto hace que la diferencia Odin 2 ↔ Odin 3 sea, casi con seguridad, **la presencia/ausencia del
path VA macro (B1-B5)**, no el `audio-routing`.

### 8.4 El AMIC del headset tampoco funciona en Odin 3

El mismo `audio-routing` declara el path del headset (`AMIC2` → `MIC BIAS2` → `ADC2` →
`TX SWR_INPUT1`) y el nodo `wcd939x` tiene `qcom,micbias2-microvolt = <1800000>`
(`cq8725s-ayn-common.dtsi:37`) y `vdd-mic-bias-supply = <&vreg_bob1>` (`:51`). Todo parece
correcto, y sin embargo **no hay señal** (#362).

**Sospecha** (no verificada, necesita hardware): o bien falta el **clocking del WCD para ADC**
(`qcom,tx-...` / el `&swr2` `pcm-port-mask` que parcheamos), o bien el AYN **no declara en el DT el
`audio-routing` completo** que usa su Android (los ficheros de AYN pueden tener rutas que nunca se
trasladaron al `.dtsi`). Es un bloqueador **independiente** del DMIC y no se resuelve con B1-B5.

### 8.5 Estado upstream

- **ArmadaOS issue #362** — *"Internal microphone not functional on AYN Odin 3 (SM8750)"*:
  https://github.com/armada-os/armada/issues/362 — **abierta, 0 comentarios** (creada 02/09/2026,
  label `device: ayn-odin-3`).
- **ArmadaOS PR #432** — solución para el **Odin 2** (qcs8550), abierta sin mergear, autor
  `Janleyx` (13/09/2026, actualizada 24/09/2026):
  https://github.com/armada-os/armada/pull/432 — UCM mínimo + servicio systemd `amixer` aparte.
  **No aplica tal cual al Odin 3** (es otro SoC, otro códec, otro problema), pero su *forma* es
  la lección correcta: **separar el routing del UCM**.
- **ROCKNIX** tampoco define micrófono para SM8750: su UCM es el de Teguh Sobirin (solo Speaker +
  Headphones),
  `projects/ROCKNIX/packages/audio/alsa-ucm-conf/patches/SM8750/0001_SM8750-AYN-Odin3.patch`.

---

## 9. Plan por fases (ordenado por riesgo)

Cada fase es **independiente y reversible**. Ninguna toca el audio de reproducción salvo donde se
indica.

### Fase 0 — Descubrimiento (riesgo 0, no requiere tocar nada)

**Objetivo**: resolver la pregunta de §2.C y conseguir una topología con `VA_CODEC_DMA_TX_0` (B5).

Requiere el **Android stock del AYN** (el reportero de #362 confirma que en Android 15 el micro
funciona).

```bash
# en el PC, con el Odin 3 en modo fastboot/adb desde Android
adb pull /vendor/etc/audio  ./audio-ayn
adb pull /vendor/lib/firmware/qcom/sm8750 ./sm8750-fw      # <- topología real del AYN
adb shell 'ls -la /vendor/etc/audio/ | grep -i tplg'
adb shell getprop ro.hardware
```

Qué buscar:
1. `*.tplg` / `audio_platform.xml` / `audio_platform_info.xml` → para saber **qué DAIs y MicPMID**
   usa el AYN (`VA_CODEC_DMA_TX_0`?, `TX_CODEC_DMA_TX_3`?) y **qué `MicPMID`** tiene el micro
   interno (`0x1001` VA macro, `0x0C00` DMIC1 del WCD, `0x0C20` DMIC3, `0x401` ADC2, …). Tabla completa en el borrador 04.
   **Un solo número resuelve la pregunta de §2.C.**
2. `sm8750.ko` / `device-tree` de AYN: si hay un `.dtb` decompilable, buscar
   `lpass_vamacro`/`dmic01_default`/`vdd-micb`.

**Rollback**: ninguno (solo lectura, ficheros fuera del dispositivo).

**Alternativa si no hay Android disponible**: pedir en la issue #362 que el reportero comparta su
`audio_platform.xml` y su volcado de `amixer`, o preguntar a AYN directamente.

---

### Fase 1 — Cambiar la topología DSP (riesgo ALTO, afecta a TODO el audio)

**Objetivo**: resolver **B5**.

**Cómo**: renombrar/copiar la topología del AYN (extraída en Fase 0) sobre
`SM8750-AYN-tplg.bin`, **validando antes** que contiene `VA_CODEC_DMA_TX_0` **y**
`SECONDARY_MI2S`:

```bash
sudo cp SM8750-AYN-tplg.bin SM8750-AYN-tplg.bin.bak
sudo cp /tmp/ayn-android-tplg.bin SM8750-AYN-tplg.bin
strings SM8750-AYN-tplg.bin | grep -E 'VA_CODEC_DMA_TX_0|SECONDARY_MI2S|Primary MI2S'
# DEBE imprimir VA_CODEC_DMA_TX_0 *y* SECONDARY_MI2S
sudo reboot
```

⚠️ **Si no se puede obtener una tplg con ambas cosas, esta fase no se puede hacer.** Alternativa
(WIP, más frágil): construir la topología a mano con `acpdb`/`Topology` tools — fuera de alcance
aquí.

**Rollback**:
```bash
sudo cp SM8750-AYN-tplg.bin.bak SM8750-AYN-tplg.bin && sudo reboot
```

**Prueba**:
```bash
arecord -l                              # ¿aparece algún Capture nuevo?
pw-cli list-objects | grep -i node.name
dmesg | grep -iE 'tplg|audioreach'
```

---

### Fase 2 — Habilitar el hardware path (riesgo MEDIO, no afecta al audio actual)

**Objetivo**: resolver **B1, B2, B3, B4** de una vez.

Fichero **único**: `kernel/dts/cq8725s-ayn-common.dtsi`
- añadir `status = "okay";` a `&lpass_vamacro` **y** a `&lpass_tlmm`
- añadir `pinctrl-0`/`pinctrl-names`/`vdd-micb-supply`
- añadir el `va-dai-link` **al final** del nodo `sound`

Borrador listo para aplicar: [`microfono-borradores/01-dts-va-dai-link.patch`](microfono-borradores/01-dts-va-dai-link.patch)

**Rollback**: `git checkout kernel/dts/cq8725s-ayn-common.dtsi` (o el `.patch -R`).

**Prueba** (esto es lo que hay que mirar, en este orden):
```bash
lsmod | grep va-macro                       # ¿snd-soc-lpass-va-macro cargado?
arecord -l                                  # ¿aparece "device 3: MultiMedia4 Capture"?
arecord -D hw:0,3 -f S16_LE -r 48000 -c 2 -d 5 /tmp/mic.raw   # ¿lee?
aplay /tmp/mic.raw -D hw:0,0 -f S16_LE -r 48000 -c 2          # ¿se oye algo?
dmesg | grep -iE 'va-macro|lpass|snd_soc|soundwire'
```

⚠️ Si Fase 1 no está hecha, este paso **no da señal** (silencio o EIO). Es correcto y esperado.

---

### Fase 3 — Configuración del códec (riesgo MEDIO)

**Objetivo**: encender el path en el mixer.

Vía UCM (preferible) o vía script (más seguro para el pipewire, ver §7). Borradores:
- [`microfono-borradores/02-ucm-section-mic.conf`](microfono-borradores/02-ucm-section-mic.conf.md)
- [`microfono-borradores/03-servicio-mic-route.md`](microfono-borradores/03-servicio-mic-route.md)

Primero, inventario real de controles (nunca escribir csets a ciegas):
```bash
amixer -D hw:0 controls | grep -iE 'MUX|DMIC|ADC|vdd-micb|DEC|TX_'
amixer -D hw:0 cget name='TX SMIC MUX0'
```

**Rollback**: restaurar el `.conf` anterior + `systemctl restart alsa-restore` / reiniciar el servicio
de audio.

---

### Fase 4 — Validación end-to-end (riesgo 0)

```bash
pw-cli list-objects | grep -i 'node.name'
pw-top                            # ver la source Mic con un nivel real
arecord -D hw:0,3 -f S16_LE -r 48000 -c 2 -d 10 -v     # debe mostrar nivel > -60 dB
```

---

### Fase 5 (paralelo, bloqueador independiente) — AMIC del headset

Resolver §8.4 por separado. Requiere el `audio_platform.xml` de Android (Fase 0) para saber el
routing real del AMIC2/ADC2 en el Odin 3.

---

## 10. Tabla certeza / sospecha

| # | Afirmación | Estado | Evidencia |
|---|---|---|---|
| 1 | El DTS no declara `va-dai-link` | **CIERTO** | `cq8725s-ayn-common.dtsi:139,155,171` (solo 3 dai-links) |
| 2 | `lpass_vamacro` no tiene `status` → deshabilitado | **CIERTO** | `sm8750.dtsi:2605-2618` |
| 3 | `lpass_tlmm` no tiene `status` → deshabilitado | **CIERTO** | `sm8750.dtsi:2620+` |
| 4 | Nuestro `&lpass_vamacro` solo pone la sample-rate | **CIERTO** | `cq8725s-ayn-common.dtsi:961-963` |
| 5 | Sin supply, `vdd-micb` es un widget dummy | **CIERTO** | `lpass-va-macro.c:1141` + semántica de `SND_SOC_DAPM_REGULATOR_SUPPLY` |
| 6 | `vreg_l1b_1p8` ya existe en nuestro DTS | **CIERTO** | `cq8725s-ayn-common.dtsi:376-377` |
| 7 | Los pinctrl `dmic01_default`/`dmic23_default` existen | **CIERTO** | `sm8750.dtsi:2669-2700` |
| 8 | Nuestro DTS no asigna ese pinctrl | **CIERTO** | `cq8725s-ayn-common.dtsi:961-963` |
| 9 | El tplg del AYN **no** tiene `VA_CODEC_DMA_TX_0` | **CIERTO** | `strings SM8750-AYN-tplg.bin` |
| 10 | El tplg del MTP **sí** lo tiene pero **no** tiene Secondary MI2S | **CIERTO** | `strings SM8750-MTP-tplg.bin` + barrido de 14 tplg |
| 11 | Sustituir el tplg por el del MTP rompe el altavoz | **CIERTO** (consecuencia de 10 + dai-link `spk-i2s` en Secondary MI2S) | |
| 12 | El nombre del tplg es `qcom/sm8750/SM8750-AYN-tplg.bin` | **CIERTO** | `topology.c:1321` + `sc8280xp.c:222,240` + `model` en `.dtsi:132` |
| 13 | El PCM VA sería el **3** | **CIERTO** (orden de dai-links) | `sc8280xp.c:185` itera los links en orden |
| 14 | `hw:0,2` es WCD capture, no DMIC VA | **CIERTO** | tabla §8.1 |
| 15 | El fixup fuerza 48k/S16_LE/2ch (1ch mín. en TX_CODEC) | **CIERTO** | `sc8280xp.c:73-101` |
| 16 | `va_macro_dai` es solo captura, 1..8 canales | **CIERTO** | `lpass-va-macro.c:957-1000` |
| 17 | `sm8750-lpass-va-macro` hace match vía fallback a `sm8550` | **CIERTO** | `lpass-va-macro.c:1766` + compatible dual en `sm8750.dtsi:2606` |
| 18 | `wcd939x` **no** necesita `audio-routing` para sus DMIC | **CIERTO** | `wcd939x.c` DMIC path interno |
| 19 | El `audio-routing` del Odin 3 == el del Odin 2 (donde sí funciona) | **CIERTO** | `cq8725s-ayn-common.dtsi:133-138` vs `qcs8550-ayn-common.dtsi:354-358` |
| 20 | **El micro interno del Odin 3 está en el VA macro DMIC** | **SOSPECHA FUERTE** | Indicios §2.C; **requiere hardware/Android (Fase 0)** |
| 21 | **El micro interno del Odin 3 está en un DMIC del WCD** | **SOSPECHA DÉBIL** | El barrido de #362 no encontró señal, lo que apunta a esta opción… o a falta de DMIC clock |
| 22 | El AMIC del headset falla por clocking/bias del WCD, no por `audio-routing` | **SOSPECHA** | §8.4; **requiere hardware** |
| 23 | La topología del Android del AYN tiene VA + Secondary MI2S | **SOSPECHA RAZONABLE** | Android funciona el micro (#362) y el altavoz → debería tener ambas |

---

## 11. Referencias

- DTS principal: `kernel/dts/cq8725s-ayn-common.dtsi`
  - `sound` 120-186 · `wcd939x` 29-54 · `&lpass_vamacro` 961-963 · `&swr1`/`&swr2` ~1249-1275
- Kernel 7.2.6 (pc-local `~/pocknix-odin3-project/pocknix-os/build/kernel/sm8750/linux-7.2.6`):
  - `arch/arm64/boot/dts/qcom/sm8750.dtsi` — `lpass_vamacro` 2605 · `lpass_tlmm` 2620 · `dmic01_default` 2669 · `dmic23_default` 2685
  - `arch/arm64/boot/dts/qcom/sm8750-mtp.dts` — `va-dai-link` 186-198 · `&lpass_vamacro` 978-984
  - `arch/arm64/boot/dts/qcom/sm8750-qrd.dts` — `va-dai-link` 179-190
  - `sound/soc/qcom/sc8280xp.c` — `driver_name` 222 · match 240 · `be_hw_params_fixup` 73-101
  - `sound/soc/qcom/qdsp6/topology.c` — `audioreach_tplg_init` 1312-1342
  - `sound/soc/codecs/lpass-va-macro.c` — `va_macro_dais[]` 957 · `vdd-micb` 1141 · `dt_match` 1762
  - `sound/soc/codecs/wcd939x.c` — `DMIC*` ~2835
  - `Documentation/devicetree/bindings/sound/qcom,lpass-va-macro.yaml`
- Firmware (pc-local `~/pocknix-odin3-project/pocknix-os/build/rootfs/usr/lib/firmware/qcom/sm8750/`):
  - `SM8750-AYN-tplg.bin` (18236 B, **sin VA**) · `SM8750-MTP-tplg.bin` → `../kaanapali/Kaanapali-MTP-tplg.bin` (38540 B, **sin Secondary MI2S**)
- UCM de referencia (local `reference/armadaos-reference/ucm2/`):
  - `AYN/Odin3/HiFi.conf` — solo Speaker PCM0 + Headphones PCM1
  - `Qualcomm-sm8750/MTP/HiFi.conf` — Mic = `hw:${CardId},3` + `va-macro/DMIC0EnableSeq.conf`
  - `AYN/Thor/HiFi.conf` — Mic = `hw:0,2` (sm8550/wcd938x, **no aplicable**)
- Upstream:
  - https://github.com/armada-os/armada/issues/362 (Odin 3, abierta)
  - https://github.com/armada-os/armada/pull/432 (Odin 2, abierta)
- Borradores: [`microfono-borradores/`](microfono-borradores/README.md)

---

## 12. Lo que **no** se puede cerrar sin hardware

1. **¿Dónde está cableado el micro interno?** (VA macro DMIC vs DMIC del WCD) → Fase 0 (Android) o
   medición con osciloscopio sobre los pines gpio6-9 del TLMM.
2. **¿Necesita mic-bias?** (1.8 V como el MTP, o nada) → medir en el pin o comparar con Android.
3. **¿Por qué el barrido de #362 no encontró señal en los DMIC del WCD?** → medir el DMIC clock del
   WCD (`qcom,dmic-clk-rate` / `DMIC_CLK_RATE` en el registro de control del códec).
4. **¿Por qué el AMIC del headset tampoco funciona?** → Fase 0 (`audio_platform.xml` del AYN) + medir
   `MIC BIAS2` (1.8 V según `qcom,micbias2-microvolt`).
5. **¿De dónde sacar una topología con VA + Secondary MI2S?** → sin Android, no hay atajo.

Todo lo anterior está aislado en §2.C, §8.4 y §9-Fase 0 para que no se mezcle con lo que **sí** está
verificado.

---

## 13. Borradores

En [`microfono-borradores/`](microfono-borradores/README.md) — **nada aplicado**:

| Fichero | Contenido |
|---|---|
| [`01-dts-va-dai-link.patch`](microfono-borradores/01-dts-va-dai-link.patch) | El parche DTS de la Fase 2 (verificado: aplica con `patch -p1` sin fuzz) |
| [`01-dts-va-dai-link.md`](microfono-borradores/01-dts-va-dai-link.md) | Guía del parche: qué cambiar, qué **NO** cambiar, secuencia de verificación y rollback |
| [`02-ucm-section-mic.conf.md`](microfono-borradores/02-ucm-section-mic.conf.md) | El `SectionDevice."Mic"` mínimo sobre `hw:${CardId},3` |
| [`03-servicio-mic-route.md`](microfono-borradores/03-servicio-mic-route.md) | Servicio systemd con `amixer`, al estilo del PR ArmadaOS #432 |
| [`04-obtener-topologia-va.md`](microfono-borradores/04-obtener-topologia-va.md) | Fases 0 y 1: cómo conseguir la topología con `VA_CODEC_DMA_TX_0` |

**Antes de aplicar nada**: Fase 0 (`adb pull` del Android del AYN). Un solo número — el `MicPMID`
del micrófono interno en `audio_platform.xml` — decide si todo este plan es el camino correcto.