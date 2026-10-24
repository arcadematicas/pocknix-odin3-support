# Incidente 2026-10-24 — sistema lentisimo tras suspender (panel DSI no re-inicializa)

## Resumen
Tras volver de **s2idle**, el sistema se queda **muy lento** y la GPU no sube de frecuencia.
No es la GPU: es el **panel DSI (ICNA3520, driver `panel-chipone-icna35xx`)** que no
re-inicializa en un modeset/disable-enable y deja el host DSI msm atascado; con el
pipeline de pantalla colgado, todo el sistema se arrastra. Solo se recupera reiniciando.

## Evidencia (kernel 7.2.12-16, Odin de Davidusky, boot anterior)
Suspend/resume de ese boot:
```
Oct 24 16:34:22 PM: suspend entry (s2idle)
Oct 24 22:10:24 PM: suspend exit
Oct 24 22:11:16 PM: suspend entry (s2idle)
Oct 24 22:11:36 PM: suspend exit
Oct 24 22:41:21 PM: suspend entry (s2idle)
Oct 24 22:55:47 PM: suspend exit
```
Fallo ~18 min despues (23:13), al hacer un modeset:
```
dsi_cmds2buf_tx: cmd dma tx failed, type=0x29, data0=0xfd, len=8, ret=-110
panel-chipone-icna35xx ae94000.dsi.0: sending generic data fd 5a 5a failed: -110
panel-chipone-icna35xx ae94000.dsi.0: failed to initialize panel: -110
[drm:dpu error] enc35 ctl 1 start interrupt wait failed
[drm:dpu error] wait for commit done returned -22 / -110
dpu_encoder_frame_done_timeout: enc35 frame done timeout
[drm:dpu error] enc35 ctl 1 reset failure
```
**Importante**: ese boot estuvo en **Game Mode (gamescope)** de principio a fin
(`pocknix-session` = gamescope; sin kwin/plasmashell). Asi que **no es solo el camino de
kwin**: el host DSI msm no se recupera tambien con gamescope como DRM master.

## No es la GPU
`/sys/class/devfreq/3d00000.gpu/trans_stat` del boot actual muestra que la GPU **si rampa**
(hasta 832 MHz y 1100 MHz). El `max_freq` en 734 MHz es el tope del power-profile
(pseudo-TDP), normal. El "no sube la frecuencia" es consecuencia de que no hay trabajo
real (el commit de pantalla nunca completa).

## Causa probable y fix
Documentado en `docs/REFRESH-60HZ-20261021.md` (§1 y R2): la diferencia de kernel
relevante con armada (que rota modos sin fallar) son **dos parches DSI que NO tenemos**:

- `0048a-drm-msm-dsi-round-byte-clock-rate-after-reparenting-to-PLL.patch`
  (Qualcomm upstream, corrige el byte clock del PLL en hosts 6G v2.9 = SM8750).
- `0048b-drm-msm-dsi-fix-pll-init-in-bonded-mode.patch`
  (init de `PLL_SYSTEM_MUXES` + settle en PHY 7nm).

El unico fix de panel de ROCKNIX que **ya tenemos** es el de PR #2884 (`0028`). El cambio
de modo fuerza un power-cycle del host DSI que pasa por `0048a`/`0048b`.

## Recomendacion
1. **Portar `0048a` y `0048b`** al kernel sm8750 (riesgo bajo; uno es upstream Qualcomm).
2. Mientras tanto, mitigacion: no cambiar modo/refresco despues de resumir; el arranque
   a 60 Hz (parche 1033-TEST) ya esta activo. Si falla, solo se recupera reiniciando.
3. Validacion propuesta (experimento discriminador del doc REFRESH): con gamescope/Sway
   como duenio del conector, hacer un ciclo DPMS off->on y un 120->60 sin cambiar de modo;
   si con `0048a`/`0048b` ya no falla, queda confirmado.

## Entorno
kernel 7.2.12-16, `pocknix-desktop 0.1.0-32`, `pocknix-bsp-sm8750 0.2.0-32`,
gamescope OGC (`1:3.16.31.ogc1.20260928.afd6eac6-3`), mesa 26.3.0.
