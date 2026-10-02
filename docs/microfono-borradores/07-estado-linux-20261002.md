# Estado del micrófono en nuestro Linux (02/10/2026)

**Sesión**: consola con Android → se reinicia a Linux → reconocimiento hecho por SSH.
**Conclusión corta**: la Fase 0 cambió el diagnóstico, y en Linux **hay más de lo que creíamos**
(PCM de captura incluido), pero ese PCM **falla con `Input/output error`** por algo que aún no está
resuelto. Nada tocado en la consola (solo 3 controles de mixer a mano, que se pierden al reiniciar).

---

## 1. Lo que sabemos ahora (y antes creíamos mal)

| | Creíamos | Es |
|---|---|---|
| El micro | **VA macro** (§2.C del documento principal) | **WCD939x**, entrada **AMIC2** |
| Captura en Linux | "ninguna ruta de captura" | **Sí hay PCM**: `00-02 MultiMedia3 Capture` |
| Bloqueador | B5 (topología DSP) + recompilar kernel | Ninguno de los dos |

**Prueba del DT** (`cq8725s-ayn-common.dtsi`, nodo `sound`):

```
audio-routing = "AMIC2", "MIC BIAS2", "TX SWR_INPUT1", "ADC2_OUTPUT";
```

o sea: **AMIC2 → MIC BIAS2 → ADC2 → TX SWR_INPUT1**. El micro interno es **analógico (AMIC2)** y
entra por el códec WCD939x.

**Y el DT ya declara el enlace de captura** (añadido en nuestro trabajo del 01/10):

```
wcd-capture-dai-link {
    link-name = "WCD Capture";
    codec  { sound-dai = <&wcd939x 1>, <&swr2 0>, <&lpass_txmacro 0>; };
    cpu    { sound-dai = <&q6apmbedai TX_CODEC_DMA_TX_3>; };
    platform { sound-dai = <&q6apm>; };
};
```

`TX_CODEC_DMA_TX_3` **sí está** en la topología de AYN (`SM8750-AYN-tplg.bin`, presente en
`/lib/firmware/qcom/sm8750/`), así que en principio todo cuadra.

## 2. El bloqueador actual: `EIO` en la captura

```bash
arecord -D hw:0,2 -f S16_LE -c 2 -r 48000 -d 3 /tmp/x.wav
# arecord: pcm_read:2285: read error: Input/output error
```

Y **no deja rastro en `dmesg`**. Otros datos:

- El códec **está vivo** en SoundWire: `sdw:2:0:…` y `sdw:3:0:…` → `Attached`, y los módulos
  `snd_soc_wcd939x`, `snd_soc_wcd939x_sdw`, `soundwire_qcom` están cargados.
- El mixer del códec tiene `ADC1..4 MUX/Switch/Volume`, `DEC0..7 MODE`, `DMIC0..7 Switch` y
  `ADC2 MUX` ofrece **solo** `CH2_AMIC_DISABLE / CH2_AMIC1..AMIC5` (no hay DMIC en ese mux).
- Activando a mano `ADC2_MIXER Switch`, `ADC2 Switch`, `ADC2 MUX=CH2_AMIC2` y `ADC2 Volume=12`
  el resultado **sigue siendo EIO** → el problema no está en el códec, está en el camino del DSP.
- **PipeWire no expone ninguna Source** (la UCM de AYN no tiene sección de Mic), así que a día de hoy
  el sistema no ve un micrófono ni aunque el PCM funcionara.

## 3. Sorpresas encontradas por el camino

1. **La UCM de AYN/Odin3 existe** (`/usr/share/alsa/ucm2/AYN/Odin3/`, de Teguh Sobirin) y tiene
   `SectionDevice."Speaker"` y `."Headphones"`, **pero ninguna de Mic**.
2. **Las secuencias de micrófono que ya vienen no sirven para nuestro kernel**: usan controles del
   stack QTI/DSP que en nuestro mixer **no existen**
   (`TX0 MODE`, `TX DEC0 MUX`, `TX DMIC MUX0`, `TX_AIF1_CAP Mixer DEC0`, `TX_DEC0 Volume`).
   Los ficheros de `/usr/share/alsa/ucm2/codecs/qcom-lpass/tx-macro/` son de otro stack.
   → Cuando escribamos la sección de Mic hay que usar los nombres **reales** de nuestro mixer.
3. **Ruido en el log**: el ADSP escupe `qcom_q6v5_pas 6800000.remoteproc: Handover signaled, but it
   already happened` **una vez por segundo** (142 líneas desde el arranque). Es cosmético, pero
   inunda `dmesg` y tapa los mensajes útiles. Candidato a parche.
4. `/lib/firmware/qcom/sm8750/ayn/odin3/` contiene un `adsp.mbn` + `adsp_dtb.mbn` propios de AYN…
   **del mismo tamaño** que el genérico (¿copia?), y el kernel carga el genérico:
   `Booting fw image qcom/sm8750/adsp.mbn`. El DT solo usa esa carpeta para
   `aw883xx_acf.bin` (los amplificadores del altavoz, `spk_amp_l/r` en i2c). No parece el problema,
   pero queda anotado.

## 4. Siguientes pasos (en orden)

1. **Entender el EIO**: es del `q6apm`. Mirar con `debugfs` (montado: no expone `asoc/` en este
   kernel) y probar a abrir el PCM con el **UCM cargado** (`alsaucm`) en vez de `hw:0,2` a pelo.
2. **Escribir la sección de Mic de la UCM** con los nombres reales del mixer
   (`ADC2_MIXER Switch`, `ADC2 MUX = CH2_AMIC2`, `ADC2 Switch`, `ADC2 Volume`, `DEC0 MODE`) y
   `CapturePCM "hw:${CardId},2"`. Con backup y rollback: si el PCM falla, PipeWire puede marcar la
   tarjeta como no soportada y dejar sin audio hasta revertir.
3. **Comparar con el Odin 2** (mismo fabricante, mismo enfoque WCD): pedir su sección de Mic /
   su `amixer` a quien lo tenga funcionando.
4. Solo si nada de lo anterior da captura: mirar el lado **DSP** (grafo del `TX_CODEC_DMA_TX_3`).

## 5. Cómo volver a probarlo en 30 segundos

```bash
arecord -D hw:0,2 -f S16_LE -c 2 -r 48000 -d 3 /tmp/mic.wav && echo "GRABA"
wpctl status | sed -n '/Sources:/,/Filters:/p'      # ¿aparece alguna fuente?
amixer -c 0 sget 'ADC2 MUX'                          # ¿sigue en CH2_AMIC2?
```
