# Micrófono del Odin 3 — UCM (portado de armadaOS, 25/10/2026)

## Síntoma
`arecord -l` no mostraba ningún dispositivo de captura y no había forma de grabar.
El grafo de captura **sí existe** en la topología (`SM8750-AYN-tplg.bin`); lo que faltaba era
declarar los dispositivos de captura en el **UCM**.

## Qué faltaba
Nuestro `HiFi.conf` solo tenía `SectionDevice."Speaker"` y `"Headphones"`. armadaOS declara
además, desde el 21/10 (`c1cda0a`):

- `SectionDevice."Mic"` — micro interno (DMIC2/DMIC3 → `SWR_MIC6`).
- `SectionDevice."Headset"` — micro del jack (wcd939x → `SWR_MIC1`), con `JackControl "Mic Jack"`.

Ambos usan `CapturePCM "hw:${CardId},2"` (el PCM de captura es **estéreo**, así que el micro mono
se alimenta a los dos canales con los dos decimadores DEC0/DEC1).

## Qué hicimos
- `packages/pocknix-bsp-sm8750/HiFi.conf`: añadidos los dos dispositivos con los mismos `cset` que
  armada, con los `Include` de `alsa-ucm-conf` (`/codecs/wcd939x/HeadphoneMic{En,Dis}ableSeq.conf`,
  que sí existen en el paquete; verificado).
- Nuestro `SectionVerb` ya activaba la ruta de captura (`MultiMedia3 Mixer TX_CODEC_DMA_TX_3 1`).

## Qué NO hizo falta
- **Parche de kernel**: armada añadió `0080-ASoC-codecs-lpass-tx-macro-track-every-active-decimator`;
  nuestro `lpass-tx-macro.c` de 7.2.12 **ya tiene** esa lógica (`active_ch_mask` por DAI +
  `for_each_set_bit(decimator, …)`, línea ~1163). No se toca el kernel.
- El `0081` de armada **es** nuestro `2109` (Diogo Trindade, HPH analog volume). Ya lo llevamos.
- El `0073` de armada (HPH PCM HiFi) también está; las versiones difieren de formato, pero la
  funcionalidad está cubierta por el nuestro.

## Verificado en la Odin (25/10/2026, bsp 0.2.0-33)

```
$ arecord -l
card 0: SM8750AYN [SM8750-AYN], device 2: MultiMedia3 Capture (*) []

$ alsaucm -c 0 list _devices/HiFi
  0: Speaker · 1: Headphones · 2: Mic · 3: Headset

$ alsaucm -c 0 set _verb HiFi set _enadev Mic
$ arecord -D hw:0,2 -f S16_LE -r 48000 -c 2 -d 5 /tmp/mic.wav
  frames=240000 peak=22403 rms=1419.9  (SEÑAL)
```

Y por **PipeWire** (lo que usan las apps): tras `systemctl --user restart wireplumber`
aparece `alsa_input.platform-sound.HiFi__Mic__source` ("Built-in Audio Internal microphone"),
queda como **fuente por defecto**, y `pw-record` graba señal (`peak=22403 rms=909`).

Perfiles de tarjeta que expone el UCM:
- `HiFi (Headphones, Mic, Speaker)` → disponible.
- `HiFi (Headphones, Headset, Speaker)` → aparece cuando se enchufa un **auricular con micro**.

`alsaucm ... set _enadev` **no** sirve para probar a mano en dos invocaciones: hay que encadenarlo
(`set _verb HiFi set _enadev Mic`), o sale "No such file or directory".

## Cómo probar
```bash
arecord -l                       # debe aparecer "Mic" y "Headset"
# micro interno:
arecord -D hw:0,2 -f S16_LE -r 48000 -c 2 -d 5 /tmp/mic.wav && aplay /tmp/mic.wav
# micro del jack (con auriculares con micro enchufados):
arecord -D hw:0,2 -f S16_LE -r 48000 -c 2 -d 5 /tmp/headset.wav && aplay /tmp/headset.wav
```
Criterio: se oye la grabación y **no** se rompe la reproducción (auriculares siguen bien).

## Si no aparece
1. `alsamixer -c 0` → comprobar que existe `TX DEC0 MUX` (si no, la tplg no cargó el TX macro).
2. `journalctl -b | grep -i ucm` y `alsaucm -c 0 list _devices/HiFi`.
3. Confirmar que el paquete instalado es el nuevo (`pacman -Q pocknix-bsp-sm8750`).
