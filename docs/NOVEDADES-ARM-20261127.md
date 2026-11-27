# Novedades de Armada / ROCKNIX / Deckard que nos sirven (27/11/2026)

Repaso de la actividad reciente de los proyectos ARM de referencia, con lo aplicable a CalvOS.
Lo ya hecho está marcado; el resto queda como candidato con su valor y su coste.

## ✅ Hecho hoy

### Decodificación de vídeo por hardware — `qcom-va-driver`
- El SM8750 expone `/dev/video0` (`qcom-iris-decoder`) y `/dev/video1` (`qcom-iris-encoder`).
- Paquete nuevo (MIT, `radxa-pkg/qcom-va-driver`, commit `0980a1d`) → `/usr/lib/dri/qcom_drv_video.so`.
- Verificado: `vainfo` da *Iris V4L2 stateful VA-API backend* con H.264 (decode + encode),
  HEVC Main/Main10, VP9 y AV1; `ffmpeg -hwaccel vaapi` decodifica 720p con 0 errores.
- Publicado en R2 y en `packages.list` del sm8750. Doc: `docs/HW-DECODE-VAAPI.md`.
- **Pendiente de probar con pantalla**: Moonlight, mpv 4K HEVC, captura.

## 🟠 Candidatos (valor alto)

| Fuente | Qué | Por qué nos importa | Coste |
|---|---|---|---|
| **armada#893** (cerrado sin merge) | Drop-in de WirePlumber **para el Odin 3**: `api.alsa.headroom = 1024`, `session.suspend-timeout-seconds = 0`, `node.pause-on-idle = false` | Medido **en esta consola**: *crackle* en juegos Proton/FEX y **clic al reanudar tras silencio**. Nos pasa. | Bajo (un `.conf`), pero la parte de suspend-timeout puede vetar la suspensión: probar primero **solo headroom** |
| **ROCKNIX#3655** (abierto) | Parar el DSP de audio en suspensión (PM ops en la tarjeta + q6apm + reloj MI2S) | ES-DE mantiene un stream abierto → **AUDIO veta el colapso CX/DDR en todos los suspends**. Nuestro 0,54 %/h podría bajar. | Medio: depende de los backports de #3645 |
| **ROCKNIX#3649** | Voto de DDR de la GPU y CLX | Rendimiento en juegos | Medio (kernel) |
| **ROCKNIX#3648** | Voto de ancho de banda de CPU y tuning de scheduling | Rendimiento; ojo con nuestro `scx` | Medio (kernel) |

## 🟡 Candidatos (valor medio)

| Fuente | Qué | Nota |
|---|---|---|
| **armada#944** | Mando del Odin 3 a la **máxima tasa de reporte** | Latencia de entrada |
| **armada#945** | Modo directo de mando **sin InputPlumber** (opt-in) | Alternativa si InputPlumber molesta |
| **ROCKNIX#3647** | MLO en el WCN7860 (Wi-Fi 7 multi-link) | Depende del router |
| **ROCKNIX#3646** | Serie `ath12k` logical link id | Estabilidad WiFi |
| **ROCKNIX#3643/#3644/#3645** | Backports de mainline/linux-next para SM8750 | Base de varias de arriba |
| **armada#958/#956/#960** | Arreglos de DP: interrupciones con clocks apagados, PUSH_IDLE, USB-C en suspensión con sink DP | Dock + suspensión |

## 🔵 Emulación (DeckStation)

| Fuente | Qué | Nota |
|---|---|---|
| **ROCKNIX#3696** | Core libretro **armN64** (N64 y 64DD) | Alternativa a Mupen64Plus |
| **ROCKNIX#3701** | **Azahar SA 2127.0.1** | Empaquetamos libretro-azahar 2126.1.2 |

## ⚪ Deckard (Steam Frame)

Nada urgente: su Mesa 27.0.0-devel es para **x86_64 traducido**, gamescope 3.16.30 (nosotros vamos
en 3.16.31 OGC) y wireplumber 0.5.18 (tenemos 0.5.19). Lo único más nuevo es su **Turnip de Valve**;
se puede refrescar `pocknix-vk-valve` (hoy del 13/10) para pruebas por juego, sin prisa.

## Orden propuesto

1. Probar **Moonlight/mpv con VA-API** (esta noche, con pantalla).
2. **Headroom de WirePlumber** (solo `api.alsa.headroom`), medir crackle y confirmar que la
   suspensión sigue igual.
3. **DSP de audio en suspensión** (ROCKNIX #3655 + #3645): el que más puede ahorrar batería.
4. Input (report rate) y WiFi (MLO/ath12k) en la siguiente vuelta de kernel.
