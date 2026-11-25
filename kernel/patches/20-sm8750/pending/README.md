# Pendientes: (vacío desde el 25/11/2026)

Los dos parches de la **AYN Odin 3 Portal** ya están **activos**, un nivel más arriba:

- `2160-drm-panel-vtdr6130-add-odin3portal.patch` — añade el panel `vtdr6130,o3p`
  al driver `panel-visionox-vtdr6130-cog.c`.
- `2161-drm-panel-vtdr6130-allow-calibrating-the-odin3portal-frame-length.patch` —
  expone `frame_len_120` / `frame_len_60` para calibrar el refresco por unidad.

Antes no aplicaban porque el kernel no tenía el driver **COG**: solo el
`panel-visionox-vtdr6130.c` upstream. Lo trajeron los parches de ROCKNIX
`2157`/`2158`/`2159` (que viven en el árbol de compilación, no en el centro), y
desde entonces los dos aplican limpios (dry-run verificado el 25/11/2026).

Este directorio NO se aplica solo: `build-kernel.sh` recorre
`kernel/patches/*/` y dentro de cada uno solo los `*.patch` de primer nivel, así
que lo que se deje aquí queda inerte a propósito.
