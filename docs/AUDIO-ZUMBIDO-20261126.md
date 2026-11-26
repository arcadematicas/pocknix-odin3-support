# Zumbido en auriculares (Odin 3) — estado 26/11/2026

## Síntoma

Zumbido en los auriculares, **intermitente**: aparece al habilitar la etapa de auriculares
(replug, cambio de perfil, arranque) y otras veces no. Con música fuerte se percibe como
distorsión. Con el códec apagado (sink `SUSPENDED`) **no hay zumbido**.

## Lo que se ha descartado (medido en la consola)

| Prueba | Resultado |
|---|---|
| Perfil activo / sinks | `Headphones` correcto, sink correcto. No es enrutado. |
| Ganancia HP: −3 dB (18) vs −21 dB (6) | El zumbido **no cambia** con la ganancia. |
| Compander (`HPHL_COMP`/`HPHR_COMP`) on/off | Indiferente. |
| Modo: `CLS_H_LOHIFI` vs `CLS_AB` | Indiferente. |
| Entrada de micrófono: `ADC1`/`ADC2` y sus mixers off | Indiferente. |
| `MBHC` (bias/detección) off | Indiferente (el jack sigue detectado). |
| EQ del panel (`AYN Odin 3 EQ`) | **Plano**: las 10 bandas a 0.0 dB. No recorta ni colorea. |
| `RDAC` off (salida del DAC desconectada) | El zumbido **desaparece** → nace en la salida del DAC; pero togglear RDAC **no lo cura** de forma fiable. |
| Estado del mezclador, bueno vs malo | **Idéntico**. Capturado con un vigilante cada 2 s (`jackwatch`). El fallo no está en el mixer. |

## Lo que sí lo deja bien

- **Replug físico**: 3 de cada 4 veces deja el estado bueno (4ª vez volvió el zumbido).
- **Reiniciar la consola**: estado bueno.
- `pactl set-card-profile off/on`: **no** lo arregla (a veces lo provoca).

## Lo que NO hay que hacer

- **Unbind/bind en caliente del códec SoundWire** (`wcd9390-codec`): cambia los nombres de
  los controles ALSA (desaparece el sufijo ` Switch`), el UCM deja de casar y la consola se
  queda **sin audio** hasta reiniciar. Descartado como vía de "reset".

## Hipótesis viva

1. **Estado interno del códec** (clase-H / charge pump / transporte SoundWire) no expuesto en
   el mezclador. El driver registra en cada arranque
   `clsh: port2 hstart=3 hstop=6 sinterval=64 HCtrl_w=0x36 HCtrl_rb=54`, que es el estado
   medido como bueno.
2. **Componente de apantallamiento del cable**: con auriculares de botón con micro (4 polos),
   tocar el cable cambia el ruido. Hay una parte de EMI/masa del propio auricular, además del
   estado del códec.

## Siguiente paso (otra sesión)

- Comparar **registros del códec** (regmap/debugfs) en estado bueno y malo, no solo el mixer.
- Probar un init determinista desde el daemon: deshabilitar el device de la UCM, esperar
  ~100 ms y volver a habilitarlo (hoy `hard_reset()` reabre el PCM y no basta).
- Valorar dejar `CLS_AB` si reduce la sensibilidad al estado (no cura, pero puede bajar el nivel).
- Mientras tanto, remedio para el usuario: **desenchufar y volver a enchufar**; si no se va,
  reiniciar.

## 🎯 Causa probable encontrada (26/11/2026, noche)

**Falta `qcom,ssp-period` en el controlador SoundWire `&swr1`.**

La nota de `PATCHES.md` del PR armada#955 lo dice con estas palabras:

> “*Optional qcom,ssp-period for the master FRAME_CTRL. The WCD939x class-H port
> (interval 64) does not divide the 50x16 RX frame; **without an SSP its stream starts at a
> random phase and about half of the Odin 3's headphone streams are fuzzy**.*”

Eso explica todo lo observado: aparece y desaparece, el replug (stream nuevo) cambia la fase, no
depende de ningún control del mezclador, y el estado bueno/malo es idéntico al leerlo.

Comprobado en nuestro árbol:

- El driver **sí** soporta la propiedad (`drivers/soundwire/qcom.c`, patch `2602` del centro).
- Nuestro `&swr1` **no la declara**, y además `qcom,pcm-ports-mask = <0x200>` solo cubre el
  puerto 9. Armada usa `0x204` (puertos 2 y 9: el 2 es el class-H, con formato PCM como en
  Android) y `qcom,ssp-period = <6>`.

**Cambio aplicado** en `kernel/dts/cq8725s-ayn-common.dtsi` (`&swr1`):

```dts
qcom,pcm-ports-mask = <0x204>;
qcom,ssp-period = <6>;
```

Kernel recompilado y pendiente de instalar/probar. Los parches armada 0082 (ventana class-H) y
0083 (start-up una vez) **ya estaban** en el 7.2.15 instalado (verificado en la fuente extraída),
así que no eran la causa.

## Referencias externas (encontradas el 26/11/2026)

- **armada-os/armada#876** (mergeado 15/11/2026) — dos parches de kernel para el WCD939x:
  - `0082`: el puerto class-H del códec sigue declarado `SDW_DPN_SIMPLE`, así que **conserva su
    ventana de reset (hstart 0, hstop 15)** mientras el master manda class-H en 3..6. Se arregla
    declarándolo `SDW_DPN_FULL`.
  - `0083`: la secuencia de arranque IQ del class-H se ejecuta **en los dos canales**; el segundo
    no restaura los valores de reproducción y deja la alimentación en estado de arranque. Síntoma
    descrito: *"loud passages clip at about three quarters of full volume, or drop out briefly with
    the compander on"*.
  - **Nuestro árbol 7.2.12 NO los tiene** (comprobado: `wcd939x-sdw.c` sigue con `SDW_DPN_SIMPLE`
    y `wcd-clsh-v2.c` llama a `wcd_clsh_v3_force_iq_ctl()` sin condición).
- **armada-os/armada#955** (abierto) — 0087–0091: versión del códec leída en el probe, rampa de
  impedancia (estéreo detectado como mono), **trims** ("la mayoría de arranques dejaban el códec
  sin trim y su compander silenciaba por encima de −30 dBFS"), reloj del controlador SoundWire en
  resume y re-enumeración en `AUTO_ENUM_FAILED`. Candidato para la variabilidad entre arranques.
- **ROCKNIX/distribution#3654** (abierto) — detección de headset con los enlaces SoundWire
  dormidos; el códec cachea los registros de ack y cada resume borra eventos del MBHC.
- **Nova-Deck/os-build#142** — "metallic ringing on low sounds" en Pocket S2: descartó class-H y
  nivel RX; menciona `0825` (RX digital limitado a 59) para la saturación.

## Plan revisado

1. ~~Portar 0082 + 0083~~ **Ya están en el 7.2.15 instalado** (verificado en la fuente extraída);
   no eran la causa.
2. **`qcom,ssp-period = <6>` + `pcm-ports-mask = <0x204>` en `&swr1`** (hecho, kernel compilado
   pendiente de instalar). Es la causa que encaja con el síntoma.
3. Si tras probarlo queda variabilidad, evaluar **0089** (trims) de #955.
4. Mantener el apaño de replug/reinicio mientras tanto.

## Nota

El daemon `pocknix-audio-jack` ya hace `hard_reset()` (perfil off→on) y un segundo reset con el
stream asentado; ninguno de los dos elimina este zumbido. El UCM partido en verbos
(`HiFi` / `Headphones`) sigue siendo necesario para la conmutación correcta.
