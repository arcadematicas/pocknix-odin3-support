# Micrófono del Odin 3 — NO funciona en Linux (limitación conocida, 16/09/2026)

**Resumen**: el micrófono interno de la AYN Odin 3 **no funciona bajo Linux todavía**, y no es un
problema de nuestra configuración. Es bring-up que falta. **Añadir un `SectionDevice."Mic"` al UCM
rompe el audio entero** (PipeWire cae a `Dummy Output`), así que **no se debe añadir**.

## La evidencia

**ArmadaOS tiene la issue abierta exacta**: [armada-os/armada#362 — *"Internal microphone not
functional on AYN Odin 3 (SM8750)"*](https://github.com/armada-os/armada/issues/362) (02/09/2026,
sin resolver). Lo que documentan:

- `arecord -D plughw:0,2 -f S16_LE -r 48000 -c 2` **abre** el PCM pero falla al leer:
  `read error: Input/output error`.
- `--dump-hw-params` en `hw:0,2`: **S16_LE / 48000 / 2ch es la ÚNICA configuración soportada**.
- Añadir un `SectionDevice."Mic"` (adaptado del Thor) **arregla el error de I/O** — el DSP arranca
  y devuelve datos — **pero el audio no tiene señal**.
- Barrido de los 12 puertos `SWR_MIC` y 8 `MSM_DMIC` con `amixer`: **SWR_MIC1 da nivel 0**, todos
  los demás dan ruido idle (270-400) sin responder al sonido.
- Conclusión del reportero: el problema está **por debajo de la capa de mixer** (mic bias, clocking
  o un nodo del DTS que falta), no en el routing del UCM.
- **En Android 15 el micrófono funciona** → es del lado Linux.
- En el **Odin 2** tienen el `SectionDevice."Headset"` **comentado** por el mismo bloqueo.

**ROCKNIX tampoco define micrófono**: su UCM para SM8750 es el mismo de Teguh Sobirin que usamos
(solo Speaker + Headphones). Patch:
`projects/ROCKNIX/packages/audio/alsa-ucm-conf/patches/SM8750/0001_SM8750-AYN-Odin3.patch`

## Por qué añadir el Mic rompe TODO el audio

El **probe de PipeWire** (`spa/plugins/alsa/acp/alsa-ucm.c`, `ucm_probe_profile_set`) abre **todos
los PCM de todos los devices del perfil**, tanto de reproducción como de captura:

```c
m->input_pcm = mapping_open_pcm(ucm, m, SND_PCM_STREAM_CAPTURE, false);
if (!m->input_pcm) {
    pa_log_info("Profile '%s' mapping '%s': input PCM open failed", ...);
    p->supported = false;      /* <-- el PERFIL ENTERO se descarta */
    break;
}
```

Si **un solo** PCM falla → el perfil se marca como no soportado → **la tarjeta no produce ni sinks
ni sources** → `Dummy Output`. No hay aislamiento del device malo.

Y el probe **no ejecuta** los `EnableSequence` de los devices (solo hace `set _verb`); los ejecuta
al **activar** el perfil. Si un `cset` de un include apunta a un control o a un valor de enum que no
existe en el machine driver del Odin 3, la secuencia falla y el perfil no se puede activar.

En nuestro caso el candidato es el include del `wcd939x`: hace `cset "name='ADC2 MUX' CH2_AMIC2"`
mientras el routing verificado del Odin 2 usa `ADC2 MUX = INP2` (¡otro valor de enum!). Un valor
inválido aborta la secuencia. El propio ALSA tiene
[issue #834](https://github.com/alsa-project/alsa-ucm-conf/issues/834) documentando que un include
roto tumba el UCM **entero** y el servidor cae a `auto_null`.

## Lo que SÍ sabemos de la ruta

El DTS (`cq8725s-ayn-common.dtsi`) declara:
```
audio-routing = "AMIC2", "MIC BIAS2", "TX SWR_INPUT1", "ADC2_OUTPUT";
```
Eso describe el camino del **headset** (AMIC2 → ADC2 → TX SWR_INPUT1). El barrido de la issue #362
sugiere que en el Odin 3 **SWR_MIC1 está muerto**, así que ese routing por sí solo no basta.

## Cómo lo resuelven otros (referencia para cuando se haga el bring-up)

**[ArmadaOS PR #432](https://github.com/armada-os/armada/pull/432)** (Odin 2, en validación): UCM
**mínimo** + un **servicio systemd aparte** que hace el routing con `amixer`.

UCM mínimo (sin includes, sin `CaptureMixerElem`, sin `JackControl`):
```
SectionDevice."Mic" {
	Comment "Microphone"
	Value {
		CapturePriority 200
		CapturePCM "hw:${CardId},2"
		CaptureChannels 2
	}
}
```

Y el routing físico va en un servicio (`armada-odin2-mic-route`) que hace `amixer`:
- **Mic interno**: `TX SMIC MUX0` = `SWR_MIC7`, `DMIC3` on, `DMIC3_MIXER` on,
  `TX_AIF1_CAP Mixer DEC0` on, `DEC0 MODE` = `ADC_DEFAULT`, `TX_DEC0` = 100 (y ADC2 apagado)
- **Headset**: `TX SMIC MUX0` = `SWR_MIC1`, `ADC2_MIXER` on, `ADC2 MUX` = `INP2`, `ADC2` on,
  `TX1 MODE` = `ADC_NORMAL`, `TX_DEC0` = 110 (y DMIC3 apagado)

**Por qué separan el routing del UCM**: *"Representing the internal and headset microphones as
conflicting UCM devices makes ALSA ACP create separate card profiles because both share capture PCM
hw:0,2. Switching profiles reconstructs the entire card, including its playback sinks."*

El UCM del **Thor** (sm8550, wcd938x) con captura funcionando:
https://github.com/armada-os/armada/blob/main/system_files/usr/share/alsa/ucm2/AYN/Thor/HiFi.conf

## Qué hacer cuando se ataque esto

1. Leer el log del probe de PipeWire con `PIPEWIRE_DEBUG=4` para ver **qué PCM falla** exactamente.
2. Probar el **UCM mínimo** (sin includes) y comprobar que el audio de salida sigue vivo.
3. Verificar con `amixer` qué controles existen de verdad en el Odin 3 (`amixer controls | grep -iE
   "MUX|DMIC|ADC|TX "`) antes de escribir csets.
4. Seguir la issue **#362** de ArmadaOS: cuando ellos lo resuelvan, replicar.
