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

## No confundir con el incidente de GPU hang (2026-10-24)
En este boot **NO** aparece la firma de GPU hang de
`INCIDENTE-2026-10-24-GPU-HANG-Y-MANGOAPP.md` (ni `a8xx_recover: cx gdsc didn't
collapse`, ni `GMU OOB timeout`, ni `gdrv`). Aqui los errores son **exclusivamente**
del DPU/DSI (`enc35 intf1`, `-22/-110`, `panel-chipone-icna35xx`). Son **dos
incidencias distintas**, aunque ambas dejan la pantalla bloqueada; esta es la del
panel tras suspender/modeset.

## ACTUALIZACION 2026-10-25 — el fallo reproducible es GPU/GMU (no I/O ni panel)

Analizado el boot `-1` (`a44f4ab4`, 23:14 -> 00:04, el ultimo antes de reiniciar):

- **NO hay errores de SD/I-O**: ningun `mmcblk*: timeout`, `card never left busy state` ni
  `I/O error` en todo el boot. La hipotesis de I/O (Fransis) **queda descartada** en este caso.
  (El root SI esta en la microSD, `mmcblk0p2`, UHS-I SDR104, pero sin errores.)
- **SI hay fallo de GPU/GMU al volver de s2idle**:

```
Oct 25 00:02:08 platform 3d37000.gmu: [drm:a6xx_gmu_resume] *ERROR* GMU firmware initialization timed out
Oct 25 00:02:10 platform 3d37000.gmu: [drm:a6xx_gmu_set_oob] *ERROR* Timeout waiting for GMU OOB set GPU_SET: 0x0
Oct 25 00:02:20 msm_dpu ae01000.display-controller: 44050000: preemption timed out
Oct 25 00:02:27 adreno 3d00000.gpu: Timeout waiting for GPU to suspend
Oct 25 00:02:27 adreno 3d00000.gpu: PM: dpm_run_callback(): platform_pm_suspend returns -16
Oct 25 00:02:27 adreno 3d00000.gpu: PM: failed to suspend: error -16
```

- Es **la misma firma que el GPU hang** de `INCIDENTE-2026-10-24-GPU-HANG-Y-MANGOAPP.md`
  (`a6xx_gmu_set_oob` + `44050000`). Con la GPU muerta, el DPU/DSI (`enc35`) tambien falla:
  los `-110` del panel son **secundarios** (no la causa).
- Despues, los suspends siguientes fallan (`-16`, "Timeout waiting for GPU to suspend") y el
  sistema se arrastra: **solo se recupera reiniciando**.
- Nota: el boot anterior (`-2`, 15:31 -> 23:13) si mostro el `enc35`/`-110` del panel a las 23:13;
  dos fallos consecutivos del stack display/GPU tras s2idle, pero con firmas distintas.

## Relacionado (lentitud SIN cuelgue)
`docs/PRUEBA-ZELDA-TDP-SUSPEND-20261024.md` (Alfred): mismo juego/perfil va bien recien arrancado
y "se arrastra" tras s2idle, sin errores en el log. Hipotesis: reguladores/rails en LPM que no
vuelven, GPU clavada en `min_freq`, `scx_lavd`, perfil de potencia no reaplicado. Medir con
`tools/diag-post-resume.sh` (before/after/show).

## Conclusion revisada
El bloqueo reproducible es **GPU/GMU al resumir** (`a6xx_gmu_resume`/GMU OOB/preemption timeout),
no I/O ni el panel como causa primaria. `0048a`/`0048b` (nuestro `1032`, identico) ya estan, asi
que no es "faltan parches DSI". La "lentitud sin cuelgue" es la otra incidencia (Zelda/TDP) y se
mide con la herramienta de Alfred.
