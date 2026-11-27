# gamescope SIGSEGV (Turnip) con el ambilight de Colores — 27/10/2026

## Síntoma

"Se reinicia la interfaz de Steam" al arrancar un juego. Pasó con **The Wind Waker HD** (26/10 23:53)
y con **wproton** (27/10 18:27, 18:36).

## Causa

No es la UI: **`gamescope-wl` muere con SIGSEGV** y el supervisor reinicia la sesión.

Coredumps (`coredumpctl`), misma traza en los dos:

```
#0 libvulkan_freedreno.so + 0xc9f68     <- Turnip
#1 libvulkan_freedreno.so + 0x1a29b0
#2 gamescope + 0x119944
#3 gamescope + 0x126694
#4 gamescope + 0x126d64
```

Segundos antes en el log: `ambilight start: node=… fps=10`. El ambilight de **Colores** (Hooandee)
se conecta por **PipeWire** al nodo `gamescope` (Video/Source) para capturar la pantalla; con un
juego Vulkan en marcha (DXVK en wproton, wgpu en el port del Zelda), la ruta de captura de gamescope
revienta dentro de Turnip.

## Evidencia a favor / descartes

- **Con ambilight desactivado**: varias aperturas/cierres de wproton y Zelda + QAM → **0 cuelgues**.
- **UI sola**: `pw_capture.py gamescope 160 90 5` (capturador del propio plugin) durante 6 s con Steam
  abierto y sin juego → gamescope **sobrevive**. Hace falta carga Vulkan del juego.
- **No es el kernel 1034**: el cuelgue de 23:53 es anterior a instalarlo.
- Un **SIGABRT** de gamescope (26/10 20:02 y 27/10 18:36) acompaña a los reinicios de sesión.

## Entorno

mesa/vulkan-freedreno **26.3.0** · gamescope **3.16.31.ogc1.20260928.afd6eac6** ·
decky-colores **0.34.1** (ambilight vividness 27, smoothing 75, fps 10, sampling columns) ·
kernel 7.2.12 · AYN Odin 3 (SM8750) · `pacman -Qu` = 0 actualizaciones pendientes.

## Reportado

- Upstream: **Hooandee/decky-colores#212**.
- Interno: **arcadematicas/pocknix-odin3-support#3**.

## Mitigación

- **Ambilight desactivado** (ajuste del usuario en Colores). Colores no lo empaquetamos nosotros, así
  que no se puede cambiar el valor por defecto desde la imagen.
- Pendiente de acotar: repro mínima con un juego en marcha (`pw_capture.py gamescope 1920 1080 10`)
  para ver si depende de resolución/formato o del simple hecho de capturar.
