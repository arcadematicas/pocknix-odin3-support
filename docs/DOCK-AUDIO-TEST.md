# Audio por dock / HDMI — kit de prueba (para davidusky) — 5/11/2026

## Qué llevamos y qué faltaba

- **Kernel `7.2.12-33`**: añade el parche de armada
  `0006-add-hw_params-callback-function-to-drm_connector_hdmi_audio_ops`
  (1 línea: `.hw_params = drm_connector_hdmi_audio_prepare`). Sin él, `hdmi-codec` no
  llama a `msm_dp_audio_prepare` antes de `q6apm_lpass_dai_prepare` y el DSP devuelve
  **-22** en `DISPLAY_PORT_RX_0` (no hay audio DP).
- **`pocknix-bsp-sm8750 0.2.0-47`**: instala `HiFi-Dock.conf` (verbo **Dock** con HDMI)
  pero **no lo activa** por defecto: sin dock, el probe del PCM `hw:0,3` falla y
  WirePlumber puede dejar la tarjeta sin perfil (sin altavoz ni auriculares).
- **Kit**: `AYN-Odin3.conf.dock`, `dock-audio-enable.sh`, `dock-audio-disable.sh`.

## Instalar

```bash
echo pocknix | sudo -S pacman -U \
  linux-pocknix-sm8750-7.2.12-33-aarch64.pkg.tar.xz \
  pocknix-bsp-sm8750-0.2.0-47-any.pkg.tar.xz
sudo reboot
```

Comprobar que el audio normal sigue bien (altavoz/auriculares) antes de seguir.

## Con el dock conectado

```bash
sudo ./dock-audio-enable.sh
pactl list cards | grep -E "Active Profile|Dock"
# elegir el perfil Dock (el nombre exacto lo muestra el comando anterior):
pactl set-card-profile alsa_card.platform-sound Dock
aplay -l | grep MultiMedia4
speaker-test -D hw:0,3 -c 2 -t sine
pactl list sinks short          # aparece un sink HDMI/DisplayPort
```

## Si no suena

```bash
dmesg | grep -iE "q6apm|displayport|hdmi|asoc"
aplay -l
amixer -c 0 contents | grep -iE "DP0|DISPLAY_PORT"
cat /proc/asound/card0/pcm3p/sub0/hw_params
journalctl -b | grep -iE "ucm|wireplumber|alsa"
```

## Volver al estado seguro (sin dock)

```bash
sudo ./dock-audio-disable.sh
```

## Notas

- El PCM `hw:0,3` **sin dock** da `EINVAL` (no hay sink DP conectado): es normal.
- El control `DP0 Jack` es de `iface=CARD`; sin dock está `off`.
- Con el dock, `DP0 Jack` debería pasar a `on` y el PCM abrir. Si el perfil Dock no
  aparece o el PCM sigue dando error, adjuntar la salida de los comandos de arriba.
