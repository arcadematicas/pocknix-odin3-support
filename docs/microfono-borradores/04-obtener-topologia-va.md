# BORRADOR — Fase 0 y Fase 1: obtener una topología con `VA_CODEC_DMA_TX_0`

> 🔴 **ESTA ES LA FASE CRÍTICA.** Sin ella, la Fase 2 (DTS) produce un PCM 3 sin ruta en el DSP.
> Ver `../MICROFONO-INVESTIGACION.md` §7 y §9.

## Por qué hace falta

El nombre del fichero de topología lo compone el kernel en
`sound/soc/qcom/qdsp6/topology.c:1321`:

```c
kasprintf(GFP_KERNEL, "qcom/%s/%s-tplg.bin", card->driver_name, card->name)
```

- `card->driver_name` = `"sm8750"` (`sc8280xp.c:240`)
- `card->name` = `model` del nodo `sound` = **`"SM8750-AYN"`** (`cq8725s-ayn-common.dtsi:132`)

→ **`/usr/lib/firmware/qcom/sm8750/SM8750-AYN-tplg.bin`**

Y su contenido es el problema:

```
SM8750-AYN-tplg.bin (18236 B):
  MultiMedia1 (SECONDARY_MI2S_RX)  MultiMedia2 (RX_CODEC_DMA_RX_0)
  MultiMedia3 (TX_CODEC_DMA_TX_3)
  → NO hay VA_CODEC_DMA_TX_0, NO hay MultiMedia4

SM8750-MTP-tplg.bin → ../kaanapali/Kaanapali-MTP-tplg.bin (38540 B):
  ... VA_CODEC_DMA_TX_0, MultiMedia4  ✅
  ... pero SOLO Primary MI2S, NO Secondary MI2S  ❌  (el altavoz del Odin 3 usa Secondary MI2S)
```

**Sustituir el AYN por el MTP rompe el altavoz.** Ninguna de las 14 topologías presentes en el
rootfs combina ambas cosas.

---

## Fase 0 — Descubrimiento (riesgo 0)

Requiere el **Android stock del AYN** (el reportero de la issue #362 confirma que en Android 15 el
micrófono **sí funciona**).

### 0.1 Extraer la configuración de audio

```bash
adb pull /vendor/etc/audio           ./audio-ayn
adb pull /vendor/etc/media.audio*.xml ./audio-ayn/ 2>/dev/null || true
adb shell 'ls -la /vendor/etc/audio/'
adb shell getprop ro.hardware
adb shell getprop ro.build.fingerprint
```

### 0.2 Qué buscar (esto resuelve la pregunta abierta principal)

**En `audio_platform.xml` / `audio_platform_info.xml`:**

| Qué buscar | Por qué |
|---|---|
| `<MicPMID value="0x..."/>` del micro **interno** | **Un solo número decide si el micro está en el VA macro o en el WCD** |
| `VA_CODEC_DMA_TX_0` o `PRIMARY_MI2S_RX`+`SECONDARY_MI2S_RX` | qué DAIs usa AYN de verdad |
| `DMIC1`..`DMIC8`, `ADC1`..`ADC4`, `SWR_MIC0..11` | inventario de rutas de captura |

MicPMID relevantes (convención Qualcomm):

| MicPMID | Ruta |
|---|---|
| `0x0C00`-`0x0C07` | DMIC1..DMIC8 del **WCD** (micrófonos digitales internos del códec) |
| `0x0C20` | DMIC3 del WCD (la del Odin 2) |
| `0x401`-`0x408` | ADC1..ADC4 del WCD (**analógicas**) |
| `0x0F01`-`0x0F08` | SWR_MIC0..7 del WCD |
| `0x1001` | **DMIC del VA macro** (ruta `VA_CODEC_DMA_TX_0`) |

→ Si el MicPMID del micro interno del Odin 3 es `0x1001` (o un valor del rango VA macro), el micro
está en el VA macro → **las Fases 1-3 son el camino correcto**, y las conclusiones de
`../MICROFONO-INVESTIGACION.md` §2.C se confirman.
→ Si es `0x0C20` (DMIC3) u `0x0Cxx`, el micro está en el **WCD** → el camino es el del Odin 2
(fichero `03-servicio-mic-route.md`, sección "Si resulta que el micro está en el WCD") y el problema
es probablemente el **DMIC clock** del WCD (§8.4).

### 0.3 Extraer la topología del DSP

```bash
adb shell 'ls -la /vendor/lib/firmware/qcom/sm8750/ 2>/dev/null'
adb shell 'ls -la /vendor/lib/firmware/qcom/sm8750/ayn/odin3/ 2>/dev/null'
adb pull /vendor/lib/firmware/qcom/sm8750 ./sm8750-fw
```

Buscar ficheros `.tplg`, `adsp.mbn`, `audio_platform.xml`, y cualquier `*.xml` que mencione
`VA_CODEC_DMA_TX_0`.

**Validación local antes de tocar la Odin:**

```bash
strings sm8750-fw/SM8750-AYN-tplg.bin | grep -E 'VA_CODEC_DMA_TX_0|SECONDARY_MI2S|PRIMARY_MI2S'
# DEBE imprimir VA_CODEC_DMA_TX_0 **y** SECONDARY_MI2S
```

### 0.4 El DT de AYN (si existe `.dtb`)

```bash
adb pull /vendor/lib/firmware/qcom/sm8750/ayn/odin3/*.dtb . 2>/dev/null || true
# o: adb shell 'ls /sys/firmware/devicetree/base/sound/'
dtc -I dtb -O dts < AYN.dtb 2>/dev/null | grep -A20 lpass_vamacro
```

Si aparece `status = "okay"` + `pinctrl-0 = <&dmic01_default>` en `lpass_vamacro`, es la confirmación
definitiva de §2.C.

### 0.5 Si NO hay Android disponible

- Preguntar en la **issue ArmadaOS #362** al reportero por su `audio_platform.xml` y su volcado de
  `amixer` (es el dato que falta).
- O preguntar a **AYN** directamente.
- En `sm8750-pmics.dtsi` upstream **no** existe `vreg_l1b_1p8`; si el DTS del Android declara el mic-bias
  con otro regulador, adaptarlo (el nuestro sí tiene `vreg_l1b_1p8` en `cq8725s-ayn-common.dtsi:376`).

---

## Fase 1 — Sustituir la topología (🔴 riesgo ALTO)

⚠️ **Afecta a TODO el audio.** Si se equivoca el fichero, **no hay sonido** (ni altavoz ni auriculares).

### Precondiciones

- [ ] Backup hecho: `cp SM8750-AYN-tplg.bin SM8750-AYN-tplg.bin.bak`
- [ ] `strings` del nuevo **confirma `VA_CODEC_DMA_TX_0` Y `SECONDARY_MI2S`**
- [ ] Idealmente, el fichero viene del **Android del AYN** (Fase 0.3), no del MTP

### Procedimiento

```bash
cd /usr/lib/firmware/qcom/sm8750/

# 1. backup (OBLIGATORIO)
sudo cp SM8750-AYN-tplg.bin SM8750-AYN-tplg.bin.bak

# 2. validar el candidato ANTES de instalar
strings /tmp/ayn-android-tplg.bin | grep -E 'VA_CODEC_DMA_TX_0|SECONDARY_MI2S|Primary MI2S'
#   -> debe aparecer VA_CODEC_DMA_TX_0  (si no, abortar)
#   -> debe aparecer SECONDARY_MI2S    (si no, el altavoz se queda mudo)

# 3. instalar
sudo cp /tmp/ayn-android-tplg.bin SM8750-AYN-tplg.bin

# 4. reiniciar
sudo reboot
```

⚠️ La topología se carga **una vez**, al arrancar el `q6apm`. **Cambiar el fichero NO requiere
recargar nada: hay que reiniciar.**

### Verificación

```bash
dmesg | grep -iE 'tplg|audioreach|soundwire' | head -20
aplay -l                       # ¿siguen los playback?
speaker-test -D hw:0,0 -c 2 -t sine -l 1     # ¿altavoz OK?
pw-cli list-objects | grep -i node.name      # ¿sinks Y sources?
```

| Síntoma | Diagnóstico | Acción |
|---|---|---|
| Altavoz mudo | el nuevo tplg no tiene Secondary MI2S | rollback inmediato |
| **No aparece ningún PCM de captura nuevo** | el nuevo tplg no tiene `VA_CODEC_DMA_TX_0` | rollback, volver a Fase 0 |
| `dmesg`: `tplg firmware loading ... failed` | path/nombre incorrecto | rollback |
| Todo OK + aparece PCM 3 | **B5 resuelto** ✅ | → Fase 2 (DTS) |

### Rollback

```bash
sudo cp /usr/lib/firmware/qcom/sm8750/SM8750-AYN-tplg.bin.bak \
        /usr/lib/firmware/qcom/sm8750/SM8750-AYN-tplg.bin
sudo reboot
```

---

## Alternativa: construir la topología a mano

Si no hay forma de obtener una topología con `VA_CODEC_DMA_TX_0` + `SECONDARY_MI2S`, se puede
generar con las herramientas de Qualcomm (`acpdb` + `Topology` de `mdss`/`cptool`, o el
`asoc-topology` de `alsa-utils`). Está **fuera del alcance** de esta investigación (horas de
trabajo, herramientas propietarias de Qualcomm) pero es la salida si el `adb pull` falla.

Otra alternativa: buscar un `.tplg` de otro dispositivo SM8750 que tenga ambos (p. ej. el QRD
`sm8750-qrd.dts` tiene `va-dai-link`). En el rootfs actual `SM8750-QRD-tplg.bin` es un symlink al
MTP (sin Secondary MI2S), pero el **QRD real** de Qualcomm puede tenerlos. Check: el DTS
`sm8750-qrd.dts` (líneas 179-190) **sí** declara `va-dai-link` con `VA_CODEC_DMA_TX_0`; y a
diferencia del MTP, el QRD de referencia de Qualcomm sí usa Secondary MI2S para altavoz en algunas
variantes. Merece la pena mirar el repo de firmware de Qualcomm o el de
`arch/arm64/boot/dts/qcom/sm8750-qrd.dts` en busca de una topología "qrd" que no sea symlink.