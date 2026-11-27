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

## Causa raíz (30/10, tarde)

Los `.rej` del iris venían de **parches duplicados en el árbol**: al sustituir la serie de shuuri por
la de armada (29/10) se renumeraron los nuevos a `0017-0025`, pero los viejos de shuuri
(`0017-CABAC`, `0018-delay-controls`, `0019-decode-in-stage-1`) **se quedaron** en el árbol con los
mismos números. El build aplicaba ambos y el segundo chocaba.

- `sync-to-os.sh` usa `rsync -a` **sin `--delete`**: borrar o renumerar un parche en el centro **no**
  lo quita del árbol.
- **No se puede añadir `--delete`** a esos overlays: el árbol tiene ~67 parches del upstream que el
  centro no gestiona y se borrarían (probado: el prune se llevó 67 ficheros y hubo que restaurarlos
  con `git checkout -- kernel/sm8750/patches`).
- Regla: al renumerar/sustituir un parche, **borrar a mano el viejo en
  `pocknix-os/kernel/sm8750/patches/`** y comprobar que no hay dos ficheros con el mismo prefijo
  (`ls | cut -c1-4 | sort | uniq -d`).

Además, el `0021` de armada era redundante: el `0024` ya define `iris_dec_low_latency()`, que
incluye `iris_dec_decode_order()`. Eliminado del centro y del árbol.

## Estado al cierre del 30/10

Kernel **7.2.12-26 compilado e instalado** en la consola (no publicado): 0 fallos, `charge_now`
6,36 M, perfil 832/2.841.600, ventilador 34-42 estable, iris con `display_delay` y la condición
`iris_dec_low_latency` en `iris_set_stage`.

Quedan **10 `.rej`** (`tools/check-kernel-patches.sh` sale 1), ninguno crítico:

| Fichero | Qué se pierde |
|---|---|
| `iris/iris_ctrls.c` | hunk ya aplicado por otra vía (la condición está puesta); solo el `module_param(low_latency)` no aparece en `/sys/module/iris/parameters/` |
| `msm/dsi/dsi_host.c` | ajuste de byte clock div-2 (el panel funciona sin él) |
| `wcd939x-usbss.c` | ruteo USB-C del jack (el jack va por MBHC) |
| `scripts/mksysmap` | micro-optimización del arranque |
| `sound/soc/codecs/*` (6) | pm-clock (runtime suspend del audio) y `pm_runtime_forbid` del jack: por eso el cambio de jack sigue lento |

Siguiente paso: adaptar esos hunks igual que el `2121`, recompilar con el chequeo en verde y
**entonces** publicar el 26 (o el que salga).

## Resuelto (kernel 27, 30/10 noche)

El chequeo sale **en verde** (0 `.rej`) y el build aborta ahora en el primer conflicto
(`build-kernel.sh`: `warn`+`continue` → `die`).

| `.rej` | Causa | Acción |
|---|---|---|
| `Kconfig`, `lpass-tx-macro.c` | `2111` duplicaba el `1031` del árbol (idénticos) | fuera `2111` |
| `lpass-rx-macro.c` | `2115` duplicaba el `0072` | fuera `2115` |
| `wcd939x-usbss.c`, `wcd-mbhc-v2.c/h` | `2118` duplicaba el `0063` (mismo cambio, otro orden) | fuera `2118` |
| `wcd939x.c` | `2119` duplicaba el `0603` | fuera `2119` |
| `wcd939x.c` (HPH PCM) | `2116` chocaba con el `0073`; solo difería en `&& !wcd->is_tx`, que **nunca** llegó a compilarse | fuera `2116` |
| `dsi_host.c` | el `0048a` **ya está en el 7.2.12 vanilla** (`byte_intf_clk_div_2`) | fuera `0048a` |
| `scripts/mksysmap` | el `08` reimplementa mksysmap en C y borra el script | fuera `01` y `02` |
| `iris_ctrls.c` | el `0024` dependía del `0021` (que quitamos) para la condición de `set_stage` | `0024` sin ese hunk + **`0026`** nuevo |

Verificado en el árbol del 27: `iris_low_latency` (param y condición), pm-clock tx/rx, usbss,
jack resumido, byte clock, HPH PCM y `2121`.

Nota: nuestro `2116` tenía un guard `!wcd->is_tx` que el `0073` no trae. No se incluye porque
ningún kernel compilado lo llevó; si interesa (micro), se prueba aparte.
