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

## ACTUALIZACIÓN (25/10, mismo día) — la tplg de armada SÍ trae DP

Comparando `SM8750-AYN-tplg.bin` de armada (`system_files/usr/lib/firmware/qcom/sm8750/`, 24.516 B)
con la nuestra (18.236 B del `vendor/rocknix-extra-firmware`):

| Widget | Nuestra | Armada |
|---|---|---|
| `MultiMedia1/2 Playback`, `MultiMedia3 Capture` | sí | sí |
| **`MultiMedia4 Playback`** (= `hw:0,3`) | **no** | **sí** |
| **`DISPLAY_PORT_RX_0 Playback`** | **no** | **sí** |

Y el kernel **ya soporta** el audio DP: `drivers/gpu/drm/msm/dp/dp_audio.c` con
`hdmi_audio_ops`, y `CONFIG_DRM_MSM_DP=y` / `CONFIG_DRM_MSM_HDMI=y`.

**Conclusión revisada**: no hace falta kernel; basta **(1)** usar la tplg de armada y
**(2)** añadir `SectionDevice."HDMI"` al UCM. Riesgo: la tplg es el corazón del audio, hay que
reprobar altavoz, auriculares y micro después de cambiarla.

### Pasos para probarlo (cuando haya un HDMI a mano)
1. Copiar la tplg de armada a `/usr/lib/firmware/qcom/sm8750/SM8750-AYN-tplg.bin` (backup previo) y
   reiniciar. Comprobar que sigue habiendo altavoz/auriculares/micro.
2. `aplay -l` debe mostrar ahora `device 3: MultiMedia4 Playback`.
3. `speaker-test -D hw:0,3 -c 2 -t sine` con un monitor/HDMI enchufado.
4. Si suena, añadir al `HiFi.conf`:
   ```
   SectionDevice."HDMI" {
       Comment "HDMI / DisplayPort playback"
       Value {
           PlaybackChannels 2
           PlaybackPriority 100
           PlaybackPCM "hw:${CardId},3"
           PlaybackMixer "default:${CardId}"
           JackControl "DP0 Jack"
           JackHWMute "Speaker"
       }
   }
   ```
5. **Pendiente de decidir**: cómo distribuir la tplg (es un binario de armada). Opciones: override en
   `devices/sm8750/firmware/...` (va a git, 24 KB) o descarga pineada en el build (como el firmware de
   ROCKNIX). Sin decidir: por eso no se ha tocado el paquete.

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
