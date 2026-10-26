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

## Plugins de Hooandee (Decky)

- [PENDIENTE] 2026-10-25 · **`panel-de-control` v0.70.1 (14/10) → v0.76.0 (23/10)** · actualizar la
  **copia semilla** del bundle en el próximo build de imagen. **No urgente**: el panel se
  autoactualiza en la consola, así que esto afecta sobre todo a imágenes nuevas/instalaciones
  limpias. **Sin delta nuestro**: el `hdr=True` del perfil `ayn_odin3` entró en upstream
  (PR #947, **mergeado 17/10**), así que es sustituir el árbol y nada más.
  Procedimiento exacto: `packages/pocknix-decky/panel-de-control/NOTES.pocknix.md`.
  Recordar **bump de `pkgrel`** en `pocknix-decky` + `sync-to-os` + `stage`/`publish`.
- [INFO] · `decky-colores` (v0.34.1, 21/10) **no se vende**: lo instala el usuario desde el propio
  panel (o desde archivo). Se vigila su versión porque los fallos de descarga ("no puedo
  instalarlo") acaban en nuestro tejado: su zip está bien (181 KB, HTTP 200) y la URL es la misma
  en nuestra copia y en upstream → el fallo, si aparece, es del dispositivo/red de quien lo baja.
- [HECHO] 2026-10-25 · vigilancia: `tools/check-hooandee.sh` + `VENDORED`, enganchado al chequeo
  diario (marca `<<< ACTUALIZAR`).

## Kernel de prueba para Jarvis — GMU al resumir (preparar esta semana)

- [PENDIENTE] **2026-10-25 · kernel de PRUEBA con `0620` + `0622` de armada para que lo pruebe Davidusky.**
  Él reproduce el fallo en 2 suspends con toque corto; nosotros **no** (2 ciclos limpios el 25/10). Sin
  reproducer en nuestra consola no se puede validar aquí: el banco de pruebas es la suya.
  **Plazo**: preparado antes del fin de semana del 31/10 (él no puede probar antes).

  **Contexto medido**:
  - Nuestro 7.2.12-16 ya tiene `0052` (= armada `0121`, presync floor de rails de la GMU) y
    `2103` (= armada `0621`, bound del wait de la GMU).
  - **Faltan**: `0620` (HFI IRQ limpia solo el bit CM3) y `0622` (enmascarar la interrupción HFI antes
    de arrancar la GMU: 30 líneas, `gmu_write(gmu, REG_A6XX_GMU_GMU2HOST_INTR_MASK, ~0)`).
  - `0622` es **autoría de armada** (no upstream, no llega con un salto de kernel); `0620` es de gennro.
  - Descartado: "faltan parches DSI" (`0048a`/`0048b` ya están, `1032` es idéntico al `0048b` byte a byte).
  - Segunda pista abierta: la serie del **dominio CX en el GCC** (Neil Armstrong) cubre sm8450/8550/8650
    pero **no sm8750** — y nuestra firma es `cx gdsc didn't collapse`. Comprobar en el fuente del kernel
    si el nodo `gcc` de sm8750 declara `power-domains = <&rpmhpd ...CX...>`.

  **Cómo prepararlo** (una cosa por build):
  1. Copiar los dos parches a `kernel/patches/20-sm8750/` como `2110-…-track-hfi…` / `2111-…-mask-hfi…`
     (o los números que toquen) y **verificar que aplican sin fuzz**: el build re-extrae el fuente y
     `apply_patches` es estricto (`patch -p1` sin fuzz).
  2. `DEVICE=sm8750 make kernel` → `KERNEL` + módulos del **mismo** build (la trampa del BTF: kernel y
     módulos de builds distintos rompen mando y audio).
  3. Empaquetar `linux-pocknix-sm8750` con `pkgrel` nuevo + `make packages`, `stage`/`publish`.
  4. Dar a Jarvis: paquete + `/flash/KERNEL.bak` previo + probar **2-3 suspends con toque corto**.
     Si aguanta → adoptarlo en `odin3-sm8750` y publicar; si no → siguiente candidato (dominio CX).

## Plan de adopción (semana del 26/10 → 1/11)

- [PENDIENTE] **1º — kernel de prueba GMU (0620+0622) para Jarvis.** Compromiso: listo antes del finde
  del 31/10 (ver sección de arriba). Es lo único con fecha.
- [PENDIENTE] **2º — `fex-emu` 2610.20261012** (tenemos 20261007). pocknix lo pasó a paquete
  compartido el 23/10. Impacto directo en juegos x86. Comprobar que no llevamos delta del PKGBUILD;
  build + `stage-shared`/`publish`. Probar un juego WProton/FEX después.
- [HECHO 26/10] **`inputplumber` 0.83.0** — compilado y **publicado** (`r2:pocknix/shared`).
  Sin delta en el paquete (el mapa del mando vive en la BSP). Rollback: `~/rollback/inputplumber-0.82.0`.
- [PENDIENTE] **3º — `inputplumber` 0.83.0** (tenemos 0.82.0 y llevamos DELTA del mapa del mando).
  Re-aplicar el delta sobre la versión nueva y probar el pad (incluido el virtual event10).
- [ESPERANDO] **`gamescope` 3.17.0-ogc1** (armada, 25/10). Supone rebasear nuestros 19 parches de
  HDR/rotación (`0101`–`0121` + `0009`/`0010`/`0011`). **Sesión dedicada**, no mezclar con lo anterior.
- [DESCARTADO por ahora] Deckard: `vulkan-layers 20261023.1` (no las empaquetamos),
  `linux-72-deckard 7.2.0` (más viejo), `mesa 26.3.0_devel` (anterior a nuestro 26.3.0).
- [ESPERANDO] MAKO `render-v4.6.0`: sigue **x86_64**, sin binarios aarch64.
- [PENDIENTE · bloqueada hasta tener dock] **Audio HDMI/DP**: la tplg de armada (`SM8750-AYN-tplg.bin`, 24.516 B) **sí** trae
  `MultiMedia4 Playback` + `DISPLAY_PORT_RX_0 Playback`; el kernel ya soporta audio DP. Falta: probar
  la tplg de armada en la consola (con HDMI enchufado) y añadir `SectionDevice."HDMI"` al UCM.
  Detalle y pasos: `docs/AUDIO-HDMI-20261025.md`. Decidir además cómo distribuir la tplg (binario).

## Correcciones pendientes de compilar (mañana)

- [HECHO 26/10] **`msm-firmware-loader 1.8.0-4`** — compilado y **publicado** (`r2:pocknix/shared`,
  unidades ya con `ExecStart=/usr/bin/...`, verificado dentro del paquete). **Falta instalar en la
  Odin** y comprobar `systemctl --failed`. Aviso publicado a Davidusky en el commit `66c2857`.
  (El `package()` reapunta las unidades con `sed`, commit `dac51b5`.) La `1.8.0-3` falla en cada
  arranque con `203/EXEC` (`/usr/sbin/msm-firmware-loader.sh` no existe: en esta imagen `/usr/sbin`
  **no** es symlink a `bin`). Impacto bajo (el firmware va como ficheros; WiFi/audio OK).
  **Avisar a Davidusky**: su Odin tiene la `-3`, así que su cargador también está roto.
- [PENDIENTE] **Kernel con `1034`** (panel ICNA35xx: asentar 120 ms + 3 reintentos). El parche ya
  compila bien tras regenerarlo (`3414049`); falta build + instalar en la Odin + probar el cambio
  a escritorio 2-3 veces (con `/flash/KERNEL.bak`).
