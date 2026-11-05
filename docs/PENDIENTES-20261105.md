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

## 4) HDR tras el resume (noche del 5/11)
- Síntoma: al despertar, `GAMESCOPE_DISPLAY_HDR_ENABLED = 1` (HDR real ON) mientras el panel
  muestra HDR desactivado (`state.json` → `hdr_enabled: false`; `color.json` →
  `games.ns:windwaker.hdr: false`).
- Causa: el panel, **por diseño**, en el resume solo re-afirma HDR **ON**
  (`main.py::_reapply_hdr_sync`: "never force a supported panel OUT of an HDR mode set
  elsewhere, e.g. Steam's own toggle"). Si el átomo quedó en 1 (p. ej. el toggle de Steam),
  el panel no lo apaga. El toggle explícito (`set_hdr`) sí aplica ambos estados.
- Workaround inmediato: en el panel, encender y apagar HDR una vez (o usar el toggle de
  Steam) para sincronizar; después se mantiene.
- Pendiente (mañana): elegir fuente única de verdad:
  a) `get_hdr_state` lee el átomo real (`xprop -root GAMESCOPE_DISPLAY_HDR_ENABLED`) y
     sincroniza el estado del panel al iniciar/resumir (parche al plugin vía
     `pocknix-panel-control-patch`, que ya se re-aplica solo);
  b) hook de resume del sistema que re-aplique el estado del panel en ambos sentidos
     (necesita el appid actual);
  c) dejar solo el toggle de Steam y ocultar el del panel (contradice la decisión del 16/10).
