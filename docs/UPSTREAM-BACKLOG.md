# Backlog de upstream — lo que revisamos y lo que decidimos

`tools/check-upstream.sh` mira kernel.org, pocknix, ROCKNIX-next, armada y Deckard.
`tools/check-upstream-daily.sh` (timer de usuario, cada día a las 08:15) guarda el informe
en `~/.local/share/pocknix/upstream/AAAA-MM-DD.txt` (90 días) y marca las **novedades**
respecto a la ejecución anterior.

**Este fichero es la memoria de decisiones**: cuando una novedad se revisa, se anota aquí
con fecha y veredicto. Lo que no se atienda un día no se pierde: queda en el informe del
día y en este backlog cuando se revise.

Formato: `- [estado] YYYY-MM-DD · qué · veredicto/enlace`. Estados: PENDIENTE, HECHO,
DESCARTADO, ESPERANDO.

## Kernel
- [HECHO] 2026-10-19 · kernel 7.2.11 (stable) · adoptado; parches limpiados (5 obsoletos fuera,
  0517 rebasado). Cero saltos.
- [HECHO] 2026-10-19 · `0512` skip L23 poll + `0044`/`0521` desactivados · suspend real (~0,5 W en SD).
- [HECHO] 2026-10-19 · `0531` audio I2S suspend (rebasado) · incluido.
- [HECHO] 2026-10-19 · `1021` ath12k frequency ranges · incluido en 7.2.11-7.
- [PENDIENTE] `1022`+`1023` ath12k (scans WCN7860 / TX protect) · **rebasar juntos**: 1022 no
  aplica sobre nuestro ath12k y 1023 solo rompe `mac.c`.
- [ESPERANDO] 7.3 mainline · armada backporta de 7.3; revisar cuando 7.3 sea estable y ellos migren.
- [ESPERANDO] `net: qrtr: resend HELLO on MHI resume` (solo 7.3, `6a5719cc3ef2`) · necesario si
  apagamos el endpoint WiFi del todo (#723).

## Suspend / energía
- [PENDIENTE] armada #723/#746: SoCCP park + PCIe full off · riesgo de no despertar; hacer con
  tiempo y en la SD primero.
- [DESCARTADO] unbind/bind del PCIe ath12k antes/después de dormir · dejó la WiFi muerta y reinició
  la consola (probado 19/10).
- [DESCARTADO] `endpoint_d3cold=0` · sube el consumo; solo como rescate si no despierta.

## Paquetes
- [HECHO] 2026-10-19 · turnip 20261009 · adoptado.
- [DESCARTADO] mangohud `0008` (fdinfo ilegible) · el parche upstream no aplica a nuestro snapshot
  0.8.4.r184 (ese código ya no está en `src/gpu_fdinfo.cpp`) y mangoapp va bien.
- [DESCARTADO] Deckard `vulkan-layers 20261014.1` · no empaquetamos esas layers; solo aparecen como
  dependencia de build en mesa/turnip.
- [HECHO] 2026-10-19 · mesa 26.3.0, mangohud 0.8.4.r184, fex 2610.20261007 · vamos por delante.

## PRs upstream
- [ESPERANDO] #146 (rsync a FAT), #147 (SD_SLACK_MIB), #148 (guard ath12k) · abiertos 19/10, sin
  comentarios de shuuri todavía.
- [ESPERANDO] #135 part 2/2 · faltan 15 min de juego GPU-intensivo + `journalctl -k | grep -iE
  'gdsc|gmu|oob|hangcheck|recover'` (la consola se quedó en el trabajo el 19/10).

## 21-22/10 — puesta al día
- [HECHO] 22/10 · **Panel 60 Hz**: el modo funciona si es el **primero/preferido** (59,95 Hz, 0
  errores). El bloqueo real es que el panel **no se re-inicializa tras un disable** (`0x53`/`0x9C`
  con `-110`). Detalle en `REFRESH-60HZ-20261021.md` §9. Pendiente: parámetro `preferred_refresh`
  y arreglar disable/enable.
- [ESPERANDO] 21/10 · **armada #766** (issue abierto por nosotros): ¿captura en SM8750? Evidencia:
  el FE de captura pide `graph_id=2`, `q6apm_get_audioreach_graph` falla y `audioreach_alloc_graph_pkt`
  devuelve `ERR_CAST` **sin log**; ninguna de las dos tplg (AYN Android y Kaanapali-MTP) publica ese
  grafo. Detalle en `MIC-SOUNDWIRE-20261021.md` §7-8.
- [HECHO] 21/10 · kernel: `swr2` dout-ports (`1030`), tx-macro PM clocks (`1031`), 0048b PLL bias
  (`1032`). Ninguno arregló el micro; 0048b se queda (lo lleva armada).
- [PENDIENTE] **#135 de shuuri**: 15 min de juego GPU + `journalctl -k | grep -iE
  'gdsc|gmu|oob|hangcheck|recover'` para cerrar el checklist.
- [PENDIENTE] `0108` de armada (DPU flip event tras vblank irq) para frame pacing — evaluar.
- [HECHO] 21/10 · QAM: el limitador de FPS funciona (30→30); el **refresco del panel no** (es
  cosmético en nuestro cliente ARM; y el panel no acepta cambios en caliente, ver arriba).
- [HECHO] 21/10 · watchdog de Steam corregido (no mata steamwebhelper mientras la UI aún no ha
  respondido nunca) y lanzador de RetroArch con el mando virtual por nombre.
