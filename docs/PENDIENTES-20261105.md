# Pendientes — 5/11/2026

## 1) Xbox en DeckStation (para mañana)
Con un juego en formato **XISO**:
- **hakuX-lr (core nuevo, Vulkan)**: no abre el juego.
- **xemu (el otro)**: error de **squashfs**.
- **Standalone (xemu)**: sí abre.

A revisar:
- Cómo lanza DeckStation/ES-DE el sistema Xbox: argumentos del core vs standalone, extensión
  aceptada (`.xiso`, `.iso`) y si el core espera el XISO tal cual o extraído.
- El error de squashfs sugiere que se está pasando al emulador una imagen comprimida/squashfs
  (¿el propio juego o el contenedor donde vive?) en vez del XISO real.
- Comprobar requisitos de hakuX (BIOS/`mcpx_1.0.bin`, `Complex_4627v1.03.bin`, HDD) y que el
  core esté bien enlazado en RetroArch portable.
- Probar el mismo XISO con `xemu` standalone desde consola para aislar DeckStation.
- Anotar el título exacto del juego y la ruta del fichero.

## 2) TDP tras el resume (arreglo listo, falta prueba real)
- Causa: el hook `zz-power-profile` aplicaba el perfil del sistema (`medio`) ~8 s después del
  resume y pisaba el nivel del Panel de Control.
- Arreglo: snapshot de los topes antes de suspender (`pre`) + unidad
  `pocknix-power-profile-reassert.service` ordenada tras `late` que los restaura; solo actúa
  si el panel gestiona el TDP.
- Estado: `pocknix-bsp-sm8750 48` y `pocknix-system-overlay 12` compilados; falta probar con
  una suspensión real y publicar.

## 3) Upstream
- PR #148 (ath12k NULL guard): **cerrado** por shuuri-labs el 5/11. Pide el oops NULL real sin
  la guarda o aceptación upstream, número nuevo (1081 ocupado) y entrada en `PATCHES.md`.
  Decisión: dejarlo en nuestro fork, sin reabrir.
