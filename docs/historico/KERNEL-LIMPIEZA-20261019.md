# Kernel SM8750: limpieza del stack + calibración de panel (19/10/2026)

## 1. Parches que se saltaban en silencio

El build usa `patch -p1 --fuzz=5` y **salta conflictos con un warn**. Sobre un
`linux-7.2.11` prístino + nuestra pila se comprobó que 5 de los 7 eran
backports que **ya están en 7.2.11**:

| Parche | Veredicto | Evidencia |
|---|---|---|
| `05-speedup/01` mksysmap `__UNIQUE_ID_modinfo` | **obsoleto** | `scripts/mksysmap:86` ya lo filtra; el parche 08 reescribe mksysmap en C |
| `05-speedup/02` mksysmap `__pi_` | **obsoleto** | `scripts/mksysmap:38` ya escapa `__pi_\$`; idem 08 |
| `20-sm8750/0048a` DSI round byte clock | **obsoleto** | `dsi_host.c` usa `byte_intf_clk_div_2` y redondea en `dsi_link_clk_set_rate_6g()` |
| `20-sm8750/0050` gxclkctl GX GDSC | **obsoleto** | `gdsc_gx_disable` ya existe y se usa como `.power_off` |
| `20-sm8750/0055` aw99706 fixes | **obsoleto** | nombres DT con sufijo, `RESV = U32_MAX`, `backlight_get_brightness()` |
| `20-sm8750/0517` typec mux `EPROBE_DEFER` | **parcial** | los 2 hunks de `-EPROBE_DEFER` ya están; faltaba el **zero-init de `sw_devs[]`** |
| `30-version/9999` rust build fix | **obsoleto** | hardcodeaba triplets `-rocknix-`; ya no existe en la rama (quedaba como fichero suelto en el árbol del PC) |

Acción: borrados del stack los 5, sustituido `0517` por
`0517-usb-typec-mux-zero-init-sw_devs.patch` (rebasado, 1 hunk real) y eliminado
el `9999` del árbol de build. Resultado: **cero `patch conflict`** (el último
build solo saltó el `9999` residual del árbol del PC, ya borrado).

## 2. Calibración del panel (frame pacing)

El parche `0518` (ROCKNIX) expone `/sys/bus/mipi-dsi/devices/*/frame_len_60|120`.
El valor correcto cambia por unidad, así que:

- **`pocknix-panel-calib <60|120> [--save]`** — mide el vblank real
  (`DRM_IOCTL_WAIT_VBLANK`) y ajusta `frame_len_<rate>` hasta clavar el refresco
  nominal; con `--save` guarda en `/etc/pocknix/panel-calibration.conf`.
  Adaptado de `rocknix-panel-calibration` (GPL-2.0).
- **`pocknix-panel-apply`** + `pocknix-panel-apply.service` — reaplica los valores
  guardados en cada arranque (espera al atributo hasta 30 s; sin conf no hace nada).

Ambos van en el **BSP ‑20** (publicado). Flujo previsto: arrancar en modo juego,
ejecutar `sudo pocknix-panel-calib 60 --save` y `... 120 --save` con la sesión en
cada refresco, y a partir de ahí lo aplica el servicio en cada boot.

## 3. Descartado

- **mangohud `0008`** (mangoapp aborta con fdinfo ilegible): el parche de upstream
  no aplica a nuestro snapshot (`0.8.4.r184`), porque ese código ya no está en
  `src/gpu_fdinfo.cpp` (upstream lo movió). Nuestro mangoapp funciona; no merece
  adaptarlo a ciegas.

## Pendiente
- Instalar `7.2.11‑5` + BSP ‑20 en la consola (offline en Tailscale al escribir esto).
- Ejecutar la calibración en la consola y comparar frame pacing (60/120 Hz).
