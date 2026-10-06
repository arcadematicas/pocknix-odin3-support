# KERNEL 7.2.9 → 7.2.9-2 — PARCHES EXTERNOS ADOPTADOS (06/10/2026)

Segunda pasada sobre el bump 7.2.9 (`da8b9c9`): se recuperó el scan-priority de
ath12k perdido, se adoptaron 2 arreglos de ArmadaOS (rails WiFi + vblank
command-mode) y 1 de ROCKNIX (hw_done), se retiró el 9999-rust, y se recompiló
(`d570cc8` en `arcadematicas/pocknix-os`, rama `odin3-sm8750`).

## 1. Parches (catálogo antes → después)

| # | Parche | Antes | Después | Procedencia |
|---|---|---|---|---|
| 0040 | ath12k QDSS config | ✓ | ✓ | (nuestro) |
| 0041 | ath12k CNSS_QDSS_CFG_MISS | ✓ | ✓ | (nuestro) |
| **0041a** | **wifi: ath12k: send the computed scan priority to the firmware** | ✗ (perdido en `1dc3bdf`) | **✓** | ROCKNIX `devices/SM8550/patches/linux/1020-...` == nuestro viejo 0070 de `79b57e5` (md5 `ab4d0757`) |
| 0048a | dsi byte-clock (reparenting) | Reversed (upstream en 7.2.9) | Reversed (igual) | (nuestro, inerte en 7.2.9) |
| **0083** | **drm/msm/dpu: fix vblank timestamps on command mode panels** | ✗ | **✓** | ArmadaOS `packages/kernel/patches/0078-...` (commit `8fe5af24`, PR #629 frame-limiter) |
| **0084** | **drm/msm: signal hw_done before sending the page-flip event** | ✗ | **✓** | ROCKNIX `packages/linux/patches/7.2/0011-...` (autor sunshineinabox) |
| 9999 | fix-rust-build-error | FAIL (inaplicable) | **retirado** (`git rm`) | — (hardcodea triplets `-rocknix-` en `tools/perf/Makefile.config`) |

- 0041a se ancla tras el 0041 existente (precedente `0048a`, sin colisión de nombres).
- 0083/0084 ocupan los huecos libres 0083/0084 (el 0078 sigue siendo el battery).
- DTS (no es parche): comentario `/* Re-enabling these four rails at resume can
  hang the SoC. */` + `regulator-always-on` en `vreg_s4d_0p85`, `vreg_s5f_0p85`,
  `vreg_l2f_1p2`, `vreg_l3f_1p8` del WCN7860 PMU — ArmadaOS PR #635 (commit
  `d48ee0595`). Va directo a `kernel/sm8750/dts/qcom/cq8725s-ayn-common.dtsi`
  porque `install_dts` clobberea `arch/arm64/boot/dts` después de `apply_patches`.

## 2. Evaluación DPU de ROCKNIX (4 candidatos, 2 adoptados)

- **0011 hw_done** → **ADOPTADO (0084)**: reordenamiento mecánico del atomic
  commit (msm_atomic/dpu_crtc/dpu_kms); frame pacing real en panel DSI
  command-mode; bajo riesgo; misma procedencia que la rotación/LUTDMA que ya
  llevamos.
- **0012 qos-lut-scaled-compressed-fetch** → **NO**: solo carga catálogos
  sm8250/sm6115; para SM8750 (kaanapali) es no-op sin datos de vendor; fabular
  curvas QoS del DPU es arriesgado.
- **0014 scaled-fetch-line-width** → **NO**: idem; carga catálogos de otros SoC.
- **0016 dp-audio_prepare** → **NO**: el Odin 3 tiene `mdss_dp0` pero NO llevamos
  el dai-link de audio DP en el DTS → inerte; además es un backport upstream en
  vuelo que llegará solo con el próximo bump.

## 3. Build 7.2.9-2 (pc-local, `JOBS=14 DEVICE=sm8750 ./scripts/build-kernel.sh`)

- Aplicados: `05-speedup` 20 · `10-mainline` 5 · `20-sm8750` **88 → 91** ·
  `30-version` 2 (9999 fuera). Skips (6, los mismos que 7.2.9-1 salvo 9999):
  01/02 mksysmap (Reversed), 0048a (Reversed, upstream), 0050 gxclkctl,
  0055 aw99706, 0517 typec-mux.
- `kernelrelease` = **7.2.9** · módulos `out/modroot/lib/modules/7.2.9/`
  (ath12k.ko + wifi7/ath12k_wifi7.ko presentes) · dtbs `cq8725s-ayn-odin3.dtb`
  + `sm8750-konkr-pf-elite.dtb` (dtb contiene `regulator-always-on`).
- `build/image/sm8750/KERNEL` = **19.001.344 B · md5
  `285d06a7a07ae13c17e50e2e8229eb9d`** (antes `50db974f…`).
- KSRC verificado: 0041a en wmi.c l.2706 (tras el cálculo 11d, offset 77 OK);
  0083 `dpu_hw_intf_get_te_line_count` + rama CMD en `dpu_crtc_get_scanoutpos`;
  0084 `dpu_crtc_complete_flip` + `complete_flip` antes de hw_done; 9999 ausente.
- Paquete re-empaquetado (mismo nombre 7.2.9-1, contenido nuevo):
  `build/localrepo/sm8750/linux-pocknix-sm8750-7.2.9-1-aarch64.pkg.tar.xz`
  **68.206.328 B · md5 `6fe4a3e508e529e47d6b9934265373df`** (452 ficheros en
  `usr/lib/modules/7.2.9/`), repo DB actualizado (pocknix.db.tar.gz 14:40).

## 4. Commits

- `arcadematicas/pocknix-os` `odin3-sm8750`: `d570cc8` (ff desde `da8b9c9`).
- `arcadematicas/pocknix-odin3-support` `master`: este doc + parches 0041a/0083/
  0084 + dtsi (rails).

## 5. Pendiente de probar en consola (la Odin sigue en bucle de arranque)

1. Arranque del 7.2.9-2 (KERNEL nuevo).
2. Panel: sin regresión DSI (0048a inerte upstream), command-mode/TE con 0083.
3. WiFi (WCN7860): reconnect rápido tras rfkill/resume (0041a), iommu-map 0514/0514a.
4. Batería/carga (battmgr) tras el cambio de rails always-on (PR #635).
5. s2idle/resume: los 4 rieles siguen vivos (ya no se apagan al suspender).
6. Sesión/HDR y pacing de frames (0084/0083).
7. Audio (jack USB-C / altavoces; sin dai-link DP, el 0016 no aplica).
8. Rollback si algo falla: `sudo cp /flash/KERNEL.bak-<fecha> /flash/KERNEL`.
