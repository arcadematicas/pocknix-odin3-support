# Plan: micrófono interno y giroscopio (próxima sesión)

Decisión de Fransis (29/10/2026): **se arreglan próximamente**. Los dos son funciones que faltan,
no regresiones, y ninguno bloquea la build. Este documento deja el diagnóstico ya hecho y los pasos
ordenados para no repetir trabajo.

---

## 1. Micrófono interno

### Estado (medido el 29/10)

- El `.dtb` lleva `widgets = "Microphone", "Internal Mic"` y las rutas `DMIC3`, `DMIC3→MIC BIAS3`,
  `TX SWR_INPUT6←DMIC3_OUTPUT`.
- El códec expone el control `DMIC3` y el PCM de captura abre (`hw:0,2`), pero **captura ceros**:
  4 s de grabación → bloque 0 con transitorio y el resto exactamente 0.0.
- El backend que se activa se llama `WCD Capture`, pero **es el correcto**: su CPU DAI es
  `TX_CODEC_DMA_TX_3` (nombre del link, no del códec).
- Probado a mano sin éxito: `DMIC2`, `DMIC3`, `DMIC3_MIXER` en on; `TX DEC0 MUX=SWR_MIC`;
  `TX_AIF1_CAP Mixer DEC0=on`; `TX_DEC0=100`; mezclador FE a ambos canales; **barrido de
  `TX SMIC MUX0` por `SWR_MIC0..7`** → todos mudos.

Conclusión: el fallo está **aguas arriba del SWR**.

### Hipótesis, por orden de probabilidad

1. **El DMIC no recibe bias/reloj**: `MIC BIAS3` no llega a encenderse (widget DAPM Off).
2. **El UCM pide controles que no existen con ese nombre** en nuestro kernel: `DMIC2 Switch`,
   `DMIC3_MIXER Switch`, `TX_DEC0 Volume`. Los `cset` fallan en silencio. Nuestros nombres reales son
   `DMIC2`, `DMIC3_MIXER`, `TX_DEC0`.
3. **El micro va por AMIC (analógico), no por DMIC** en este board.
4. Falta el parche de armada `0200-ASoC-wcd938x-add-DMIC-DAPM-inputs` (ellos lo tienen para
   wcd938x; habría que ver si aplica a wcd939x).

### Pasos

1. **DAPM con la captura activa** (lo que faltó la última vez):
   ```sh
   ( arecord -D hw:0,2 -f S16_LE -r 48000 -c 2 -d 8 /tmp/m.wav & )
   sleep 2
   sudo grep -rhE "MIC BIAS3|DMIC3|TX DMIC3|TX SWR_INPUT6|TX SMIC MUX0" \
       /sys/kernel/debug/asoc/SM8750-AYN/*/dapm/* | sed 's/^/  /'
   ```
   Si `MIC BIAS3` está `Off`, ese es el problema: buscar su control (`amixer -c 0 scontrols | grep -i bias`)
   o el widget que lo alimenta.

2. **Descartar el camino analógico**: micro en el jack + `arecord`. Si capta, el ADC y el PCM están
   bien y el problema es solo el DMIC.

3. **UCM propio** (sin tocar `/usr`): copiar `AYN/Odin3/HiFi.conf` a `/etc/alsa/ucm2/` y corregir los
   `cset` a los nombres reales. Probar con `alsaucm -c 0 set _verb HiFi` + `set _enadev Mic`.

4. Si nada: probar el parche `0200` adaptado a `wcd939x` y comparar con el DTS de armada.

**Criterio de éxito**: `arecord` de 4 s hablando → `rms_ac > 500` y que suba al hablar.
**Rollback**: el UCM propio se borra y listo; no toca paquetes.

---

## 2. Giroscopio (IMU)

### Estado

- La **isla SSC está apagada** a propósito (`hexagonfs-island-off.py` de `msm-firmware-loader`),
  porque con ella activa teníamos inestabilidad. Consecuencia: no hay sensores.
- `inputplumber 0.83.0` está instalado, pero **sin fuente IMU configurada**: no hay dispositivos
  `/dev/iio:device*` ni `iio-sensor-proxy` con datos.
- Armada lo tiene funcionando con su pila.

### Qué hace falta (de armada)

- `inputplumber`: `0005` SSC sensors, `0006` calibración del giro, `0007` fastrpc en los devices,
  `0008` suspender las fuentes SSC durante system sleep.
- `libssc`: `0005` (log del disable fallido).
- Decisión sobre la isla: o se deja encendida (y se acepta el coste/riesgo) o se adopta el trabajo de
  armada para que el SoC llegue a deep sleep **con el giro encendido** (`dac08dfe0a`).

### Pasos

1. Portar los parches de `inputplumber` a **0.83.0** (ellos van por 0.82) y `libssc 0005`.
2. Probar **sin** tocar la isla primero: ver si `inputplumber` detecta algo con la isla apagada.
3. Activar la isla (revertir el helper de forma temporal), comprobar que aparece el IMU y que
   `iio-sensor-proxy` da datos.
4. **Medir suspensión** con el hook `pocknix-sleep-report`: si el giro impide el deep sleep, adoptar
   el parche de armada antes de dejarlo activo.
5. Decidir el modelo final: isla encendida + deep sleep, o giro solo bajo demanda.

**Criterio de éxito**: aparece dispositivo IMU, el giro responde a movimiento, y la suspensión sigue
durmiendo sin cuelgues ni consumo anómalo.

**Riesgo principal**: volver a la inestabilidad que nos hizo apagar la isla. Por eso el paso 4 no es
opcional.

---

## Orden recomendado

1. **Micrófono** (1-2 h, sin kernel nuevo, reversible).
2. **Giroscopio** (sesión larga: paquetes + pruebas de suspensión).

Ninguno de los dos debe retrasar la build; si la build se compila antes, se publica sin ellos.

## Avance del 30/10 (mañana) — cadena confirmada, sigue mudo

Con la consola despierta y sin interferencias, se activó la ruta completa y se volcó el DAPM:

- Códec: `MIC BIAS3 On`, `DMIC3_MIXER On`, `DMIC3_OUTPUT On`.
- LPASS (6ae0000.codec): `TX SWR_INPUT6 On`, `TX SMIC MUX0 = SWR_MIC6`, `TX DEC0 MUX = SWR_MIC`,
  `TX_AIF1_CAP Mixer DEC0 On`.
- Ajustes: `DMIC2 off`, `DMIC3 on`, `DMIC3_MIXER on`, mezclador FE→TX_CODEC en ambos canales.

Resultado: **captura a cero** (medido en el último segundo, descartando el transitorio de ~1 s).

Dos hallazgos nuevos:

1. **`DMIC2` se auto-enciende** en cuanto se activa `DMIC3_MIXER`, aunque el DTS solo enruta
   `DMIC3 → Internal Mic`. Todo apunta al DAPM del códec (bias/clock compartido), no al UCM.
2. **Ojo con los falsos positivos**: el transitorio de apertura del PCM dura ~1 s (pico 22.403).
   Cualquier prueba que mida desde 0,3 s lo confunde con señal. Medir siempre el **último** segundo.

Siguiente hipótesis (la que queda): **el DMIC no recibe reloj**. El `wcd939x` debe generar el clock
del DMIC (bit de `DMIC3_MIXER` + pinctrl/GPIO); si ese reloj no sale, el códec entrega ceros aunque
el DAPM esté arriba. Revisar en el DTS/binding del wcd939x el clock del DMIC y compararlo con el
DTS de armada. Alternativa: probar el camino analógico `AMIC2` (micro en el jack) para validar el ADC.

### 30/10 (tarde) — también probado DMIC2 + DMIC3_MIXER

La combinación que usa el UCM de armada (`DMIC2` + `DMIC3_MIXER`) **también da ceros**. Probadas ya:
DMIC0..7 con sus mixers, DMIC3+DMIC3_MIXER, DMIC2+DMIC3_MIXER, y la cadena DAPM completa en `On`.
Conclusión: no es la selección de DMIC ni el UCM; falta algo físico o de reloj. Siguiente sesión:
comparar el reloj del DMIC (el `wcd939x` debe generarlo) y, si hay dudas, probar el camino analógico
`AMIC2` con un micro en el jack.
