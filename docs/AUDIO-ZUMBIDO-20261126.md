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

## Nota

El daemon `pocknix-audio-jack` ya hace `hard_reset()` (perfil off→on) y un segundo reset con el
stream asentado; ninguno de los dos elimina este zumbido. El UCM partido en verbos
(`HiFi` / `Headphones`) sigue siendo necesario para la conmutación correcta.
