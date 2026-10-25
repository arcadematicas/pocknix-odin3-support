# Audio por HDMI / DisplayPort — estado (25/10/2026)

## Respuesta corta
**No hay audio por HDMI/DP y no es un parche suelto**: falta la **topología** (no existe el PCM de
DisplayPort) y faltan los parches de **audio DP** en el kernel. No lo tenemos, ni ROCKNIX para
sm8750, ni armada para el Odin 3 (sus tplg binarias son de sm8550).

## Evidencia medida en la Odin (25/10, bsp 0.2.0-33)
```
$ aplay -l
card 0: SM8750AYN [SM8750-AYN], device 0: MultiMedia1 Playback
card 0: SM8750AYN [SM8750-AYN], device 1: MultiMedia2 Playback
card 0: SM8750AYN [SM8750-AYN], device 2: MultiMedia3 Capture
$ amixer -c 0 cget name="DP0 Jack"
amixer: Cannot find the given element          # la ruta DP ni se instancia
```

- La **tplg** que usamos (`SM8750-AYN-tplg.bin`, 18 KB) tiene **0 menciones** de `hdmi`/`dp`: no hay
  backend de DisplayPort, así que el card no puede exponer `hw:0,3`.
- El UCM nuestro **no** declara HDMI. Armada sí (`SectionDevice."HDMI"`, `PlaybackPCM "hw:${CardId},3"`,
  `JackControl "DP0 Jack"`), pero eso solo funcionaría **si** existiera el PCM 3: es una plantilla.
- Kernel: `CONFIG_SND_SOC_HDMI_CODEC=y`, `CONFIG_DRM_DISPLAY_HDMI_AUDIO_HELPER=y`, `CONFIG_DRM_MSM=y`
  → la infraestructura genérica está, pero **no hay parches de `hdmi_audio_ops`/`dp_audio`** en nuestro
  árbol (0 parches). Armada tiene uno para **sm8550** (`0006-add-hw_params-callback-function-to-
  drm_connector_hdmi_audio_ops.patch`, tomado de ROCKNIX).

## Qué haría falta (2 piezas, no una)
1. **Kernel**: portar el soporte de audio DP del driver `msm` (`drm_connector_hdmi_audio_ops` +
   callback `hw_params`) desde ROCKNIX/armada (su serie de sm8550). Riesgo medio; hay que probar que
   no rompe el DP/panel actual.
2. **Topología**: una `SM8750-AYN-tplg.bin` con el PCM/widget de DisplayPort. **Nadie la publica
   para sm8750** (ROCKNIX trae la misma sin DP; armada solo tiene binarias de sm8550). Se podría
   generar desde las fuentes de topología de Qualcomm con el compilador `tplg`, pero es trabajo de
   audio-DSP y sin garantía.

## Conclusión
- **HDMI = no soportado hoy**, y no por un flag ni un UCM: falta el PCM en la tplg.
- Si algún día aparece una tplg de sm8750 con DP (o alguien publica las fuentes), se hace: kernel +
  UCM (`SectionDevice."HDMI"`) y probar `speaker-test -D hw:0,3`.
- Mientras tanto, la salida de audio es: altavoz (`hw:0,0`), auriculares (`hw:0,1`) y captura
  (`hw:0,2`, ya funcionando).
