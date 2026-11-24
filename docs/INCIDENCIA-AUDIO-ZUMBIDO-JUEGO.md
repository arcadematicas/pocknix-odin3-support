# Zumbido y distorsion en auriculares al arrancar un juego (pendiente)

Estado: **no reproducible ahora mismo**. Queda apuntado como bug a cazar.

## Sintoma
Con auriculares conectados y sonando bien, al **arrancar un juego** el audio pasa a tener
**zumbido constante + distorsion** (hay audio, no es silencio). **Desenchufar y volver a enchufar
los auriculares lo cura** hasta el siguiente arranque de juego.

## Lo que se descarto (medido en el estado malo)
- **Codec (controles ALSA)**: `RX HPH Mode = CLS_H_LOHIFI` (4), `HPHL/HPHR_COMP = on`,
  `HPHL/HPHR/CLSH Switch = on`, volumen 18 (-3 dB), impedancia medida 66/67 ohm. Todo igual que en
  el estado bueno.
- **Grafo PipeWire**: enlaces EQ -> auriculares unicos (sin duplicados), altavoz suspendido,
  streams del juego a **48 kHz** (F32LE), **sin xruns** (`pw-top`), sin errores en el journal.
- **rx_macro**: volcado completo de `/sys/kernel/debug/regmap/6ac0000.codec-rx_macro/registers`
  (996 registros) en estado malo y bueno -> **0 diferencias**.
- `alsaucm ... _disdev/_enadev Headphones` con streams activos: rc=0 pero **sin efecto audible**,
  asi que no sirve como sustituto del replug.

## Hipotesis principal
El replug **reabre el PCM**, y solo entonces se reconfiguran los **parametros de transporte del
SoundWire** (banco/SSP period/frame). Algo en el arranque del juego deja el transporte mal y suena
con zumbido. El codec RX y el controlador `swr1` **no exponen regmap en debugfs**, asi que no se
pudo comparar registro a registro.

## Plan de captura (la proxima vez que aparezca)
Con el zumbido presente, probar en este orden y anotar cual lo cura:
1. `pactl suspend-sink alsa_output.platform-sound.HiFi__Headphones__sink 1` y luego `0`.
2. `pactl set-card-profile <card> off` y volver a `HiFi` (es lo que hace el replug; puede cortar
   1 s de audio y rehacer los enlaces, que el servicio restaura).
3. Si ninguna funciona: instrumentar el controlador (`drivers/soundwire/qcom.c`) con un log del
   banco, SSP period y `SWRM_DPn_SAMPLECTRL2/HCTRL` al abrir stream, comparar los dos estados.

Si (1) o (2) lo cura, se automatiza en `pocknix-audio-jack` **al detectar un stream nuevo**
(el gancho ya esta escrito y probado en banco, pero se quito por no estar validado).
