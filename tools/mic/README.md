# Kit de prueba del micrófono (Odin 3) — para la sesión del 20/10

Estado: **listo para probar en la consola**. Nada de esto está instalado por defecto ni
empaquetado todavía; se despliega con el script y se revierte igual de rápido.

## Qué hay y por qué

| Fichero | Qué es |
|---|---|
| `probe-mic.sh` | Sonda **de solo lectura** en la Odin: tarjetas, PCMs, controles de captura, 3 s de `arecord` en cada PCM candidato (con medición de nivel) y estado de PipeWire |
| `HiFi-mic.conf` | La UCM actual **+ `SectionDevice."Mic"`** apuntando a `hw:0,2`. Sin `cset` a propósito |
| `pocknix-odin3-mic-route` | Routing del códec (TX0 MODE DMIC/ADC) **fuera** del UCM, tolerante a controles ausentes |
| `pocknix-odin3-mic-route.service` | Unidad oneshot que lo ejecuta al arrancar |
| `deploy-mic-test.sh` | Despliegue/reversión por SSH (probe, enable, revert, route, status) |

## Por qué así (y no csets dentro del UCM)

- Un `cset` a un control que no exista **aborta** la secuencia del UCM y PipeWire marca el
  perfil como no soportado → **Dummy Output**: te quedas sin audio, no solo sin micro.
- Un `SectionDevice` cuyo PCM no tenga ruta en el DSP hace lo mismo durante el *probe*.
- Por eso el orden es: primero **probar el PCM** (`--probe`), luego declararlo (`--enable`),
  y solo después el routing (`--route`). Y todo con `--revert` a un comando.

## Datos que ya tenemos

- dai-links de nuestro DTS (parche `0046`): `0` Secondary MI2S (Speaker), `1` WCD Playback
  (Headphones), **`2` "WCD Capture"** (`wcd939x 1` + `swr2` + `lpass_txmacro` → `TX_CODEC_DMA_TX_3`).
  ⇒ el PCM de captura debería ser **hw:0,2**; el script también prueba el 3.
- El verb HiFi ya enciende `MultiMedia3 Mixer TX_CODEC_DMA_TX_3`.
- El DTS de audio de Lineage define `cdc_dmic01/23/45/67_gpios` y quita los `cdc-dmic*-gpios`
  del `&wcd939x_codec` → los micros del Odin 3 son **DMIC del códec WCD939x**, no del VA macro
  (esto desmonta la hipótesis 2.B de `docs/MICROFONO-INVESTIGACION.md`).
- `alsa-ucm-conf` ya trae los fragmentos del códec: `codecs/wcd939x/{AnalogMic1,3,4,5,HeadphoneMic}*`.

## Secuencia de la sesión

```bash
cd tools/mic
./deploy-mic-test.sh --probe      # 1) ¿existe hw:0,2 y trae señal? (no toca nada)
./deploy-mic-test.sh --enable     # 2) UCM con Mic  -> ¿aparece fuente en PipeWire?
./deploy-mic-test.sh --route      # 3) routing del códec -> ¿deja de ser silencio?
./deploy-mic-test.sh --status     # en cualquier momento
./deploy-mic-test.sh --revert     # si el audio se rompe (Dummy Output)
./deploy-mic-test.sh --route-off  # quitar el servicio
```

Con `--probe` delante, lo normal es: si `hw:0,2` **no** abre o graba silencio absoluto, el
problema está en el kernel/DSP (falta pinctrl DMIC o la ruta TX), no en la UCM — en ese caso
**no** merece la pena `--enable` y hay que ir al DTS (comparar con `cdc_dmic0x_gpios` de Lineage).

## Si funciona

Se formaliza en `pocknix-bsp-sm8750`: `HiFi.conf` con el `Mic`, el servicio de routing y
`MODE=DMIC` por defecto; bump de `pkgrel` y a la imagen. Si no funciona, se borra este
directorio sin dejar rastro en el sistema.
