# Grabar vídeo del Odin 3 para el canal

Dos caminos, y no son excluyentes.

## 1. Capturadora HDMI (recomendado para el vídeo)

El Odin saca vídeo por USB‑C (`card0-DP-1`). Con un hub USB‑C→HDMI y una capturadora:

- **Vídeo**: la consola lo ve como un monitor. `gamescope` maneja los conectores que encuentra
  (no fijamos `--prefer-output`), y `--force-orientation` **solo rota la pantalla interna**, así que
  la capturadora recibe la imagen **normal**, en horizontal.
- **Audio**: ⚠️ medido en la consola: **no existe sink HDMI/DP** (`pactl list short sinks` solo
  muestra altavoz, auriculares y el ecualizador). El sonido del juego **no sale por el HDMI**.
  Para el vídeo: cable de **jack 3,5 mm** de la Odin a la entrada de línea del PC/capturadora (la
  ruta de auriculares ya está arreglada), o grabar el audio aparte y sincronizar.
- **Diagnóstico rápido**: `dock-check` (en la consola) dice si DP‑1 aparece, con qué modos, si
  gamescope lo está manejando y si hay audio por HDMI.

Si al conectar sale negro o sin señal, casi siempre es el refresco: la sesión pide `-r 120` y la
capturadora es 1080p60. Se prueba a arrancar la sesión con `-r 60`.

## 2. Grabar en la propia consola (`calvos-grabar`)

Encoder **H.264 por hardware** (`qcom-iris-encoder`). Medido: 1080p60 en **tiempo real** (~27 Mbps),
5 s de vídeo codificados en 1,36 s.

```sh
calvos-grabar 60                  # 60 s, TODO (juego + QAM + UI), 1080p60, audio del juego
calvos-grabar 60 --x11            # solo la ventana del juego (sin root, sin QAM)
calvos-grabar 60 --fps 30 --bitrate 12M --out ~/Videos
```

- `kms` captura el **scanout del DPU** → sale lo mismo que por HDMI. Necesita **root** (kmsgrab).
- `x11` no necesita root pero **no** captura el QAM ni los menús de Steam (viven en el compositor).
- El audio se toma del **monitor del sink por defecto**, así que graba lo que suena (sin micro).

## 3. Grabadora de Steam

El cliente ARM64 **sí trae el módulo** (`CGameRecording_*`, `gameoverlayrenderer.so` arm64,
`gamerecording.css`). Falta comprobar en la UI que funciona de verdad (Ajustes → Grabación). Si va,
es lo más cómodo para clips con línea de tiempo.

## 4. Modo escritorio

`wf-recorder` (en los repos) para grabar terminal, `calvos-doctor`, ajustes del sistema, Plasma…
OBS **no** está empaquetado para aarch64 en nuestros repos.

## Consejos de grabación

- 1080p60 a 25–40 Mbps y editas después; tomas de 30–60 s.
- Voz aparte (móvil/PC) y palmada al inicio de cada toma para sincronizar.
- Cuidado con lo que sale en pantalla: usuario, IPs, rutas, y **nada de juegos/ROMs**.
- Espacio: la SD tiene ~584 GB libres (medido 22/10).
