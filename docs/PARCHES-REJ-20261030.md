# Parches que no aplican (`.rej`) — 30/10/2026

## Hallazgo

`scripts/build-kernel.sh` aplica el stack con `patch -p1 --fuzz=5` y, si un hunk no encaja, **deja un
`.rej` y sigue**. El build "pasa" y el paquete sale sin ese cambio. Hoy aparecieron **17 `.rej`** en
`build/kernel/sm8750/linux-7.2.12`:

| Zona | `.rej` | Parche(s) sospechosos |
|---|---|---|
| **iris** (`drivers/media/platform/qcom/iris/`) | 8: `iris_ctrls.c/h`, `iris_hfi_gen2.c`, `iris_hfi_gen2_defines.h`, `iris_platform_common.h`, `iris_platform_qcs8300.h`, `iris_platform_sm8550.h`, `iris_vpu_common.c` | `10-mainline/0021` (decode en stage 1) y `0024` (top clock por defecto) chocan con `0016` (cache work mode) en `iris_set_stage` |
| panel/DSI | `drivers/gpu/drm/msm/dsi/dsi_host.c` | `0048a` (round byte clock / div-2) con contexto distinto |
| USB-C/jack | `drivers/usb/typec/mux/wcd939x-usbss.c` | `2118` (route usbss on jack) |
| audio | `Kconfig`, `lpass-rx-macro.c`, `lpass-tx-macro.c`, `wcd939x.c`, `wcd-mbhc-v2.c/h` | `2111/2112` (pm-clock) y `2119` (jack resume) |
| arranque | `scripts/mksysmap` | `05-speedup/01` (mksysmap) |

## Qué está y qué no

- **iris**: la serie está **parcialmente** aplicada. `display_delay` / `display_delay_enable`
  (parche `1033` = `0020`) están en `v4l2-ctl -d /dev/video0 --list-ctrls`, así que esa parte entró.
  Los hunks de `iris_set_stage` (decode-order en stage 1 / top clock) **no**.
- **audio**: `2115` (rx HPH PCM) y `2117` (decimadores) sí entraron; `2111/2112/2119` no.
  Por eso el micro no depende de esto (descartado) y el jack sigue con detección lenta.
- **panel**: el DSI funciona; falta el ajuste de byte clock.

## Herramienta nueva

`tools/check-kernel-patches.sh [soc]` — falla (exit 1) si hay `.rej` recientes y lista el fichero y
el primer hunk. **Ejecutarlo justo después de `make kernel`**, antes de `make packages`/`stage`.

## Plan de reparación

1. **iris** (prioritario: es lo que acelera Remote Play): adaptar `0021` y `0024` al contexto del
   `0016`, o reordenar el stack para que el decode-in-stage vaya antes del cache-work-mode.
2. **audio**: adaptar `2111/2112` (pm-clock) y `2119` (jack) — mismo método que el `2121`.
3. **dsi** y **mksysmap**: adaptar sus hunks o retirarlos si ya no aportan.
4. Recompilar con el chequeo en verde y **solo entonces** publicar.

> Mientras quede un `.rej`, el kernel publicado no lleva todo lo que dice el CHANGELOG. No publicar
> más hasta repararlo.
