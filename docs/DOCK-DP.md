# Dock USB-C: DisplayPort y audio (estado 10/11/2026)

> Portado del PR **ROCKNIX/distribution #3509** ("sm8750: enable DisplayPort Alt Mode, audio
> routing, and dock charging on AYN Odin 3"), autor Chazmus. Aquí está lo que se ha aplicado,
> lo que **no**, y cómo terminar de validarlo cuando haya un dock o un monitor USB-C.

## Lo que ya está en la consola

| Pieza | Dónde | Estado |
|---|---|---|
| 5 parches de kernel (0620-0624) | `kernel/patches/20-sm8750/` | aplicados, kernel compilado e instalado |
| `try-power-role = "sink"` | `kernel/dts/cq8725s-ayn-odin3.dts` | en el dtb (verificado en `/proc/device-tree`) |
| Fuerza DP con el Billboard del dock | `udev/80-sm8750-typec-dp.rules` | instalado |
| Audio USB con más prioridad | `wireplumber/60-sm8750-usb-audio.conf` | instalado |
| Topología con el puerto DP | `pocknix-firmware-sm8750` (`updates/…/SM8750-AYN-tplg.bin`, 24.516 B) | ya estaba |

Los parches son, en corto:

- **0620** guarda `clientdata` en el probe del redriver `nb7vpq904m` (evita un NULL al quitarlo).
- **0621** deja de esperar el ACK del `pmic_glink altmode` (con firmware nuevo se quedaba en
  `pan_ack_tmout`).
- **0622** habilita el audio para **cualquier** display DP externo.
- **0623** conserva host-mode y usa el combo PHY solo para DP.
- **0624** no apaga el USB del mux `wcd939x` al entrar en DP AltMode.

El **0525** del PR no se ha metido: 7.2.15 ya trae `.hw_params` en
`drm_connector_hdmi_audio_ops`.

## Lo que falta: el perfil UCM "HDMI"

El PCM **existe** (`hw:0,3`, "MultiMedia4 Playback"), pero **abre con EINVAL cuando no hay
display conectado**. Y con un `SectionDevice."HDMI"` en el UCM que apunte a él, UCM2 falla al
activar el dispositivo y **PipeWire descarta el perfil entero**: la consola se queda sin
altavoz ni auriculares. Eso fue el incidente del 5/11.

Por eso la sección está retirada a propósito (`HiFi.conf`, nota al final).

### Cómo terminarlo (con dock o monitor USB-C)

1. Conecta el dock/monitor y comprueba el estado:
   ```bash
   ~/tools/test-dock-dp.sh        # o tools/test-dock-dp.sh del centro
   ```
   Tiene que decir *ABIERTO* en el PCM de DP.
2. Prueba sonido por ahí:
   ```bash
   speaker-test -D hw:0,3 -c 2 -t sine
   ```
3. Añade al final de `packages/pocknix-bsp-sm8750/HiFi.conf`:
   ```
   SectionDevice."HDMI" {
       Comment "DisplayPort playback"

       Value {
           PlaybackChannels 2
           PlaybackPriority 200
           PlaybackPCM "hw:${CardId},3"
           PlaybackMixer "default:${CardId}"
           JackControl "DP0 Jack"
           JackHWMute "Speaker"
       }
   }
   ```
   y al `EnableSequence` del `SectionVerb`:
   ```
   cset "name='DISPLAY_PORT_RX_0 Audio Mixer MultiMedia4' 1"
   ```
4. **Valida antes de instalar** (no toca el UCM vivo):
   ```bash
   cp -a /usr/share/alsa/ucm2 /tmp/ucm-dock
   # edita /tmp/ucm-dock/AYN/Odin3/HiFi.conf con los dos bloques de arriba
   ALSA_CONFIG_UCM2=/tmp/ucm-dock bash -c \
     'printf "set _verb HiFi\nset _devices HDMI\n" | alsaucm -c hw:0 -b -'
   ```
   Si `set _devices` no da error, se puede instalar. Si da `Invalid argument`, **no**.
5. Con la sección validada, `pkgrel` +1 en `pocknix-bsp-sm8750`, compilar, instalar y probar
   que altavoz y auriculares siguen saliendo en `wpctl status`.

## Notas

- El control `DP0 Jack` es de **iface=CARD**, no de mezclador: por eso UCM2 se atraganta si se
  combina mal. La variante sin `JackControl` también parsea (probado con `alsaucm`), pero
  entonces el altavoz no se silencia solo al conectar el monitor.
- El dock **no da corriente en todos los casos**: `try-power-role = "sink"` es lo que pide el
  puerto; si un dock concreto sigue sin cargar, hay que mirar su negociación PD
  (`/sys/class/typec/port0/partner`), no el kernel.
