# Audio de auriculares en el Odin 3 — dos averías distintas (22/10/2026)

Dos síntomas que parecían uno:

1. **El volumen de los auriculares no respondía**: subir o bajar no cambiaba nada y sonaba
   demasiado alto.
2. **Al desenchufar los auriculares, el audio no volvía al altavoz** (silencio hasta reiniciar
   el filtro de ecualización). Y por los cascos, un **entrecortado** intermitente.

## 1. Volumen: los controles HPHL/HPHR no hacían nada

En el **WCD939x**, los controles `HPHL Volume` / `HPHR Volume` venían **heredados del wcd938x**,
donde la ganancia de la etapa de auriculares vive en los bits bajos de `HPH_L_EN` / `HPH_R_EN`.
En el WCD939x esos bits son **de reserva** (`WCD939X_L_EN_SPARE_BITS`) y la ganancia real está en
el campo VALUE de `HPH_NEW_INT_PA_GAIN_CTL_L/R`.

Consecuencia: escribir los controles **no tenía efecto** y la etapa se quedaba en su valor de
reset (**código 0 = +6 dB**). La UCM escribe `HPHL Volume 20` esperando 0 dB, y no hacía nada.

- **Fix**: parche **`2109-ASoC-wcd939x-fix-headphone-analog-volume-controls-armada.patch`**
  (de armada), incluido en `linux-pocknix-sm8750 7.2.12-16`. Ahora el control apunta al campo
  real y `20` es 0 dB de verdad (códigos 0..24 = +6 dB … −30 dB en pasos de 1,5 dB).
- **Cómo comprobarlo**: `amixer -c 0 cget numid=31` (HPHL Volume) y mover el volumen: debe
  cambiar la ganancia; antes no.

## 2. Conmutación altavoz ↔ auriculares: el ecualizador clavaba el destino

El sink virtual del panel (`AYN Odin 3 EQ`, un `libpipewire-module-filter-chain`) escribía en su
configuración:

```
playback.props = { … node.passive = true target.object = "alsa_output…HiFi__Headphones__sink" }
```

Es decir: **todo** el audio iba al nodo de **auriculares**. Al desenchufar, ese nodo queda
*not available*, y WirePlumber **no vuelve a enganchar** el stream pasivo del filtro → el sonido
se pierde hasta reiniciar el filtro (o el panel).

- **Fix 1 (panel)**: `target=None` en `py_modules/audio/filter_chain.py` / `pipewire.py` → el
  filtro sigue al **sink por defecto**, que es lo que WirePlumber gestiona al conmutar el jack.
- **Fix 2 (sistema, independiente del panel)**: `pocknix-audio-jack.service`
  (`/usr/local/bin/pocknix-audio-jack`), que cada 2 s comprueba el estado del jack
  (`amixer -c 0 cget numid=111`) y:
  - reengancha la salida del filtro al nodo disponible (`pw-link`), y
  - deja el sink por defecto en el ecualizador (o en el altavoz si no hay EQ).
  Cubre también el caso de reiniciar PipeWire/WirePlumber con el filtro huérfano.

## 3. Entrecortado: xrun en el PCM de auriculares

En el journal aparecían ráfagas de:

```
spa.alsa: hw:SM8750AYN,1p: (93 suppressed) snd_pcm_avail after recover: Broken pipe
```

El PCM de auriculares (`hw:0,1`) admite `period_time` mínimo de **10 ms** y de 2 a 8 periodos.
Si una aplicación pedía buffers por debajo de eso (o justo en el límite), el PCM entraba en
**xrun** y la recuperación fallaba.

- **Fix**: `/etc/pipewire/pipewire.conf.d/10-pocknix-latency.conf` con
  `default.clock.quantum = 1024`, `min-quantum = 512`, `max-quantum = 2048` (≈10 ms extra en el
  peor caso, inapreciable).
- **Descartado como causa**: el ecualizador (el fallo persistía con el filtro parado). ALSA
  directo con `aplay` y buffers grandes va perfecto.

## CONFIRMADO (22/10): era la compander

Con la compander apagada (`HPHL_COMP`/`HPHR_COMP` = 0) y los cascos de estudio, Fransis confirma
que **el audio va perfecto**: sin entrecortados. Activarla lo reproduce, asi que la causa esta ahi
(el driver la configura sin impedancia declarada, `HPHL/HPHR Impedance = 0`).

- **Arreglo definitivo**: la UCM (`HiFi.conf`, dispositivo *Headphones*) apaga la compander
  **despues** del include que la enciende, asi que ya no hace falta el vigilante.
- Efecto secundario: algo menos de "pegada" a bajo volumen (la compander comprimia). A cambio,
  sin bombeo ni cortes.

## Si algun dia se quiere recuperar la compander

- El entrecortado **no está 100 % cerrado**: si reaparece, los siguientes candidatos son la
  **compander** (`HPHL_COMP`/`HPHR_COMP`, activada por la UCM) y el modo **class‑H**
  (`CLSH Switch`, `RX HPH Mode = CLS_H_LOHIFI`). Prueba A/B: apagar `HPHL_COMP`/`HPHR_COMP` y
  comparar; si mejora, el problema está en la compander y hay que ajustar impedancia
  (`HPHL/HPHR Impedance`, hoy en 0) o desactivarla en la UCM.
- No se ha podido medir con oído del usuario en cada cambio; el diagnóstico es del log
  (`snd_pcm_avail after recover`) y de pruebas ALSA/PipeWire.

## Ficheros

- `packages/pocknix-bsp-sm8750/audio/pocknix-audio-jack.py`
- `packages/pocknix-bsp-sm8750/audio/pocknix-audio-jack.service`
- `packages/pocknix-bsp-sm8750/audio/10-pocknix-latency.conf`
- `packages/pocknix-decky/panel-de-control/py_modules/audio/{pipewire,filter_chain}.py`
