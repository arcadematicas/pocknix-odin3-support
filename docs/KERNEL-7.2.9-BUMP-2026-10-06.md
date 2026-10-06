# KERNEL 7.2.6 → 7.2.9 — BUMP (06/10/2026)

Subida del kernel del SM8750 (AYN Odin 3) de **7.2.6 a 7.2.9** (último stable de
kernel.org, publicado el 03/10/2026): compilado, empaquetado y commiteado. Sin
pruebas en consola (la Odin sigue sin estar disponible, bucle de arranque).

---

## 1. Qué se cambió (commit `da8b9c9` en `arcadematicas/pocknix-os`, rama `odin3-sm8750`)

| Fichero | Antes | Después |
|---|---|---|
| `kernel/sm8750/kernel.conf` | `KERNEL_VERSION:=7.2.6` | `KERNEL_VERSION:=7.2.9` |
| `kernel/sm8750/kernel.conf` (sha256) | `039aef84f2b0994aeda3f4fcfc3d02ec9d7a9bbb9020ea264c43f446c860f606` | `b4c5dfbe51a364a6c7f03869200f88c8e1f77403539005f14b7fc6bc91b8d8ba` |
| `packages/soc/linux-pocknix-sm8750/PKGBUILD` | `pkgver=7.2.4` / `pkgrel=2` | `pkgver=7.2.9` / `pkgrel=1` |

- El sha256 es el del tarball oficial de kernel.org (`linux-7.2.9.tar.xz`), el mismo
  que usa ROCKNIX para su S922X.
- El PKGBUILD lleva ahora un comentario de mantenimiento: **pkgver NO se calcula
  solo — hay que igualarlo a `KERNEL_VERSION` de `kernel.conf` al subir kernel**
  (historial: estuvo en 7.2.4 mientras el staged era 7.2.6 y el nombre del paquete
  mentía).
- Push: `9ba1db1..da8b9c9 odin3-sm8750 -> odin3-sm8750` (fast-forward, 0 behind).

## 2. Estado de la regresión DSI y del WiFi

- **Regresión DSI (panel negro) del 7.2.5/7.2.6 → ARREGLADA upstream en 7.2.9.** El
  parche `0048a-drm-msm-dsi-round-byte-clock-rate-after-reparenting-to-PLL` ahora da
  `Reversed` (= ya está en mainline; verificado en fuente limpia:
  `dsi_link_clk_set_rate_6g` usa `rounded_byte_clk_rate`).
- **Regresión WiFi (MHI -110 / iommu-map) → NO arreglada upstream.** El changelog
  7.2.9 no trae iommu-map/ath12k/mhi. Siguen siendo imprescindibles nuestros
  `0514-PCI-qcom-honor-iommu-map-cell-count` y
  `0514a-of-property-honor-iommu-cells-in-iommu-map-devlinks` (aplican OK en 7.2.9).

## 3. Catálogo de aplicación de parches (122 en 4 dirs → 115 aplicados)

Log completo: `/tmp/patchlog-7.2.9.txt.keep` (pc-local).

| Dir | Aplicados |
|---|---|
| `05-speedup` | 20 |
| `10-mainline` | 5 |
| `20-sm8750` | 88 |
| `30-version` | 2 |

**Resumen: 81 OK · 10 FUZZ · 24 OFFSET · 7 FAIL (todos esperados).**

### FAIL (7) — literal de `build-kernel.sh`

```
FAIL  01-scripts_mksysmap_drop_the_MODULE_INFO_symbols_from_kallsyms.patch :: Reversed (or previously applied) patch detected!  Assume -R? [n]  Skipping patch.  (rejs:0)
FAIL  02-scripts_mksysmap_fix_escape_of_in_the_pi_pattern.patch :: Reversed (or previously applied) patch detected!  Assume -R? [n]  Skipping patch.  (rejs:0)
FAIL  0048a-drm-msm-dsi-round-byte-clock-rate-after-reparenting-to-PLL.patch :: Reversed (or previously applied) patch detected!  Assume -R? [n]  Skipping patch.  (rejs:0)
FAIL  0050-clk-qcom-gxclkctl-kaanapali-fix-gx-gdsc-collapse.patch :: Reversed (or previously applied) patch detected!  Assume -R? [n]  Skipping patch.  (rejs:0)
FAIL  0055-backlight-aw99706-upstream-fixes.patch :: Reversed (or previously applied) patch detected!  Assume -R? [n]  Skipping patch.  (rejs:0)
FAIL  0517-usb-typec-mux-dont-swallow-EPROBE_DEFER.patch :: Reversed (or previously applied) patch detected!  Assume -R? [n]  Skipping patch.  (rejs:0)
FAIL  9999-fix-rust-build-error.patch :: Hunk #1 FAILED at 1165. 1 out of 1 hunk FAILED -- saving rejects to file tools/perf/Makefile.config.rej  (rejs:0)
```

- `01`/`02`/`0048a`/`0050`/`0055`/`0517` → Reversed: **ya están upstream en 7.2.9**
  (el 0048a es el fix DSI; los demás ya venían resueltos en 7.2.6).
- `9999-fix-rust-build-error` → Hunk #1 FAILED en `tools/perf/Makefile.config:1165`:
  **inaplicable, igual que en 7.2.6** (el 7.2.6 ya compiló sin él). Valorar retirarlo
  del árbol de una vez.

### FUZZ (10) — aplican con fuzz 1–3

```
FUZZ3 04-kallsyms_output_binary_data_to_speed_output_and_kallsyms_ass.patch     FUZZ1 08-kallsyms_reimplement_mksysmap_in_C.patch
FUZZ2 12-kbuild_avoid_re_running_compiler_and_linker_probes_fixed.patch         FUZZ1 14-modpost_cache_section_relocation_mismatch_state.patch
FUZZ2 22-kbuild_build_rust_crates_in_parallel_with_the_rest_of_the_bu.patch     FUZZ1 0002-input-add-input-polldev-driver.patch
FUZZ2 0005-Bluetooth-btrtl-Add-the-support-for-RTL8733BU.patch                  FUZZ2 0028-drm-panel-Add-panel-driver-for-Chipone-ICNA35XX-base.patch
FUZZ1 0048-drm-msm-dsi-reparent-byte-pixel-src-to-xo-on-disable.patch           FUZZ3 0010-msm-resource-cleanup.patch (18 offset-hunks)
```

### OFFSET (24)

`0040, 0045, 0056, 0057, 0068, 0070, 0075, 0077–0081, 0500, 0503, 0504×2, 0509×2,
0521, 0524, 0606, 9998…`

## 4. Resultado del build y artefactos (pc-local)

`JOBS=14 DEVICE=sm8750 ./scripts/build-kernel.sh` → log `/tmp/kernel_7.2.9.log`.

```
==> applied 05-speedup: 20 patches
==> applied 10-mainline: 5 patches
==> applied 20-sm8750: 88 patches
==> applied 30-version: 2 patches
==> staging artifacts -> build/kernel/sm8750/out
==>   staged extra dtb: cq8725s-ayn-odin3.dtb
 ok kernel 7.2.9 staged (2 dtbs)
==> assembling qcom-abl boot image -> build/image/sm8750/KERNEL
 ok boot image ready
 ok linux-pocknix-sm8750 build complete
```

| Artefacto | Valor |
|---|---|
| `build/kernel/sm8750/out/kernelrelease` | **7.2.9** |
| `build/image/sm8750/KERNEL` | **19.001.344 bytes · md5 `50db974f26db148c3785f340625aa419`** |
| Módulos | `out/modroot/lib/modules/7.2.9/` (360 MB) |
| dtbs staged | `cq8725s-ayn-odin3.dtb` + `sm8750-konkr-pf-elite.dtb` |
| Paquete | `build/localrepo/sm8750/linux-pocknix-sm8750-7.2.9-1-aarch64.pkg.tar.xz` (**68.216.992 B**, repo DB actualizado 13:23) |
| Contenido del paquete | `boot/Image`, `boot/dtbs/*.dtb`, 452 ficheros en `usr/lib/modules/7.2.9/` |

## 5. Revisión de ArmadaOS / ROCKNIX (solo informe, no se adoptó nada)

### ROCKNIX (kernel 7.2.0 base para SM8750 — MÁS VIEJO que nosotros)
- Movió **S922X → 7.2.9** y **RK35xx → 7.2.7**, creando `projects/ROCKNIX/packages/linux/patches/7.2.6/`.
- Los 58 parches device SM8750 de ROCKNIX **están todos en nuestro árbol** (comparación por nombre normalizado).
- Parches ROCKNIX 7.2 que **NO llevamos**: `0011-drm-msm-signal-hw_done-before-the-flip-event`,
  `0012-dpu-qos-lut-scaled-compressed-fetch`, `0014-dpu-scaled-fetch-line-width`,
  `0016-drm-msm-dp-audio_prepare` (aplican sobre 7.2.9 → no están upstream; **candidatos DPU**),
  `0015-sm8250-linear-danger-lut` (solo sm8250, N/A para nosotros).
- Su `patch dir 7.2/7.2.6` no aporta nada nuevo a nuestro `30-version`.

### ArmadaOS (kernel unificado 7.2.0) — hallazgos nuevos (05–06/10, no los tenemos)
1. **Odin 3 WiFi PMU rails always-on** — `packages/kernel/dts/cq8725s-ayn-common.dtsi.patch`
   (PR #635): 4 reguladores `vreg_s4d_0p85 / vreg_s5f_0p85 / vreg_l2f_1p2 / vreg_l3f_1p8` +
   comentario *"Re-enabling these four rails at resume can hang the SoC"*. Nosotros sí tenemos
   WAKE# active-low. **Evaluar** (pendiente de prueba de suspensión).
2. **`0078-drm-msm-dpu-fix-vblank-timestamps-on-command-mode-panels.patch`** — lee el TE counter;
   el panel del Odin 3 es command mode. Pareja con su gamescope frame-limiter. **Evaluar.**
3. **ath12k scan priority/timeout perdido**: nuestro `0070-wifi-ath12k-scan-priority` fue **pisado**
   por la renumeración HDR (`1dc3bdf` puso `0070-drm-msm-dpu-lutdma`). ROCKNIX aún lo tiene en
   `devices/SM8550/patches/linux/1020-...`. **Recuperarlo** (recomendado).
4. Menores: 0901/0902 battmgr (unit/charge_now), 1004 haptics stop-zero, 1005 rsinput quiesce,
   0532 pwm-fan en s2idle, 0048b pll bonded (N/A: Odin 3 es single-DSI).

## 6. Qué probar en consola cuando la Odin esté disponible

1. **Arranque** con el nuevo KERNEL (rollback disponible: `sudo cp /flash/KERNEL.bak-<fecha> /flash/KERNEL`).
2. **Panel** (regresión DSI 7.2.5/7.2.6: arranque con panel encendido tras un suspend/resume).
3. **WiFi** (regresión MHI -110: asociación + iperf) — con 0514/0514a aplicados.
4. **Batería** (battmgr) y **s2idle** (los rails LPM, WAKE#, suspensión con audio abierto).
5. **Sesión SteamOS + HDR** (LUTDMA) y **audio** (q6apm/ADSP).
6. `pacman -Syu` / `cat /usr/lib/pocknix/kernelrelease` → debe decir `7.2.9`.

## 7. Pendientes / recomendación

- **Recuperar el parche ath12k scan priority/timeout** (1020/1021 ArmadaOS = nuestro antiguo
  `0070-wifi-ath12k-scan-priority`, hoy pisado por la renumeración HDR).
- **Evaluar**: 0078 vblank command-mode (ArmadaOS), WiFi rails always-on (PR #635), y los 4
  candidatos DPU de ROCKNIX (0011/0012/0014/0016).
- **Retirar `9999-fix-rust-build-error.patch`** del árbol (inaplicable en 7.2.6 y 7.2.9).
- No probado en dispositivo (Odin no disponible; bucle de arranque). El 7.2.9 se compiló igual que
  el 7.2.6 (que ya se verificó en consola), con 115/122 parches y 0 errores de compilación.