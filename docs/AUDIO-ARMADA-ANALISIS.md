# Audio de Armada: analisis completo y plan para la Odin 3

Inventario de los 58 parches de audio de Armada (`packages/kernel/patches/`), estado en nuestro
arbol y prioridad. Objetivo: cuando ataquemos el UCM por perfiles, no perder tiempo buscando.

## Parches que YA tenemos (paridad)
| Armada | El nuestro | Que hace |
|---|---|---|
| 0032 aw88166 AYN | `0032-...aw88166-AYN...` | ajustes de los amplis de altavoz AYN |
| 0063 route USBSS | `0063-...route-usbss...` | mux USB en la deteccion de jack |
| 0064 stale jack | `0064-...stale-jack-report...` | limpia el reporte de jack al sacar |
| 0072 HPH PCM rx-macro | `0072-...add-HPH-PCM-mode...` | modo PCM del macro RX |
| 0073 HPH PCM wcd939x | `0073-...HPH-PCM-HiFi-mode...` | kcontrols del PCM de auriculares |
| 0074 PCM data port | `0074-...PCM-data-port-format...` | formato PCM del puerto en swrm |
| 0081 volumen HPH | `2109-...headphone-analog-volume...` | volumen analogico real (0..24 -> +6..-30 dB) |
| 0082 ventana class-H | `2603-...class-H-port-window...` | DP2 no-SIMPLE -> HCtrl 0x36 |
| 0083 arranque class-H | `2604-...class-H-start-up-only-once...` | arranque unico del class-H |
| 0084 IRQ sin regmap | `2600-...skip-the-interrupt-loop...` | wcd-common sin regmap |
| 0085 restart streams | `2601-...restart-SoundWire-streams...` | streams tras suspend |
| 0086 SSP period | `2602-...optional-SSP-period...` | multi-frame SSP (`qcom,ssp-period = <6>`) |
| 0603 codec despierto con jack | `0603-...keep-the-codec-resumed...` | pm_runtime_forbid mientras hay jack |
| 0604 mascara PCM en DTS | `0604-...enable-swr1-PCM-port-mask...` | `qcom,pcm-ports-mask = <0x200>` |
| 0557-0563 PM clock macros (RX/TX) | `2112` `1031` `2113` `2114` | clock framework en los macros |
| 0080 decimadores TX | `2117-...track-every-active-decimator...` | decimadores activos |

## Parches que NO tenemos (candidatos)
| Armada | Que hace | Nos afecta? |
|---|---|---|
| 0557 wsa-macro PM clock | pasa el macro WSA (altavoz) al framework de clocks | **si**: los WSA de la Odin (6aa0000/6b00000) son los altavoces; ayuda en suspend |
| 0558 va-macro PM clock | igual para el macro VA | poco (VA casi no se usa) |
| 0564 soundwire runtime suspend | fuerza runtime suspend del bus en system sleep | **si**: consumo en standby |
| 0570 pmic haptics port | salta el handshake de clock para el puerto de haptics | **si**: vibracion (si usamos el puerto PMIC) |
| 0618 DP audio prepare | no falla el audio del DP si el display esta off | **si**: audio por USB-C/HDMI |
| 0012 q6asm periodos | cambia periodos por defecto del DSP | **si**: latencia/glitches (usamos q6asm?) |
| 0100 revert force-16bit | revierte el forzado a 16 bits | **si**: calidad si el DSP fuerza 16 bits |
| 0007 audioreach channel maps | canales activos en AudioReach | solo si vamos por AudioReach |
| 0200/0304 wcd938x DMIC/zdet | codec wcd938x (otras consolas) | no |
| 0075 wsa884x compander | amplis wsa884x (otras consolas) | no |

## Topologia de audio
Armada trae `audio_topology/sm8750/SM8750-AYN.m4` (topologia **AudioReach** para un AYN con SM8750).
Eso sugiere que en sm8750 ellos usan el camino AudioReach (q6apm/q6prm + grafo), no solo los macros
LPASS + SoundWire como nosotros. **Investigar** si merece la pena (daria mezcla/EQ por DSP y quizas
el transporte mas estable), pero es un cambio grande: primero UCM por perfiles.

## Plan para el UCM por perfiles (lo que atacaremos)
1. Partir `HiFi.conf` en dos devices que PipeWire pueda conmutar como **perfiles distintos**
   (Headphones / Speaker), de forma que el cambio de perfil re-ejecute `EnableSequence` siempre.
2. Mantener en el UCM: impedancia (la mide el driver), compander ON (DSP la necesita con class-H),
   volumen HPH a 18 (-3 dB), modo LOHIFI.
3. Probar matriz completa: jack con juego, jack en silencio, altavoz, dock, HDMI/USB-C, suspend.
4. Si funciona, dejar `pocknix-audio-jack` solo como red de seguridad (enlaces y default sink).
5. Capturar antes/despues `hw_params` (periodo/buffer) para saber si el bug del zumbido viene del
   transporte y fijarlo en PipeWire.

## Nota
El bug del zumbido NO es del class-H (se reprodujo tambien en CLS_AB) y el codec se ve correcto en
los controles; el unico remedio conocido es reabrir el PCM (replug / ciclo de perfil). Ver
`docs/INCIDENCIA-AUDIO-ZUMBIDO-JUEGO.md`.
