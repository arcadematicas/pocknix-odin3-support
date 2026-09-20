# Rotación por HARDWARE en la AYN Odin 3 — cómo funciona y cómo verificarla

**Estado: ✅ FUNCIONANDO (20/09/2026).** El DPU rota el plano en scanout; NO se rota
por composición. Objetivo del proyecto cumplido.

---

## 1. El problema que resuelve

El panel de la Odin 3 es **1080x1920 (portrait native)**, pero el escritorio se usa en
landscape (1920x1080). Alguien tiene que rotar 90°.

| Método | Coste |
|---|---|
| **Rotación por composición** (gamescope rota la textura cada frame) | Una pasada completa de GPU **por cada present**, para siempre |
| **Rotación por scanout** (el DPU rota el plano) | **Gratis** — el hardware lo hace al escanear |

La Odin 3 tiene rotador inline en el DPU, así que se puede hacer en hardware. Pero el
camino tiene dos trampas (abajo).

---

## 2. Las dos trampas (y por qué fallaban)

### Trampa A: el DPU solo rota hasta **1088 líneas** pre-rotación
El rotador inline de Qualcomm acepta un plano rotado solo si su **altura de origen
pre-rotación** ≤ 1088 líneas. El plano anuncia `ROTATE_90` como capacidad **estática**
(no se puede cualificar por modo), así que gamescope cree que puede rotar en scanout.

Con el panel en 1080x1920: para rotar 90° el origen mide 1920 de **alto** por 1080 de
ancho → **1920 > 1088** → el commit atómico es **rechazado** → no se escanea nada →
**panel negro**.

> Nota: la "altura pre-rotación" es la del **origen**. Para 90/270 la anchura del panel
> (1080) pasa a ser la altura del origen. En nuestro panel 1080 ≤ 1088, así que **no
> clampa** — el flag es la red de seguridad para paneles más anchos.

### Trampa B: el parche de mainline del DSI (7.2.5+)
En el kernel **7.2.5/7.2.6** mainline cambió `dsi_calc_clk_rate_6g()` y metía un
`clk_round_rate()` del byte clock que **sobrescribía** `byte_clk_rate` → el pixel clock
dejaba de cuadrar → `Failed to set rate pixel clk, -22` → panel negro + bucle de
`dpu_encoder_frame_done_timeout`. **Por eso el 7.2.6 se descartó** (ver más abajo).

---

## 3. Las dos mitades de la solución

### Mitad kernel: los parches de rotación inline (en `pocknix-os`)

| Parche | Qué aporta |
|---|---|
| `10-mainline/0013-drm-msm-dpu-fix-inline-rotation.patch` | Infraestructura de rotación inline en el DPU |
| `20-sm8750/0067-drm-msm-dpu-enable-qseed-detail-enhancer.patch` | QSEED detail enhancer (mejora el escalado del upscale) |
| `20-sm8750/0068-drm-msm-dpu-enable-sm8750-inline-rotation.patch` | Activa la rotación inline del **SM8750**: `.features = VIG_SM8750_MASK_SDMA` (incluye `BIT(DPU_SSPP_INLINE_ROTATION)`) + `.sblk = &dpu_vig_sblk_qseed3_3_4_rot_v2` en `catalog/dpu_12_0_sm8750.h` |

**Aplican sin un solo offset sobre 7.2.4.**

> ⚠️ **`rot_maxheight` NO lo añade ningún parche nuestro.** `rot_v2` **no** sirve como
> marcador (es upstream, está también en sc7280). Marcadores reales para verificar:
> `DPU_SSPP_INLINE_ROTATION` en `dpu_plane.c`, `QSEED3_DE_LPF_BLEND` en
> `dpu_hw_util.c`, `VIG_SM8750_MASK_SDMA` en `dpu_hw_catalog.c`.

### Mitad userspace: gamescope (en `pocknix-os`)

Parche **`packages/soc/gamescope/0010-DRMBackend-add-rotated-output-max-height.patch`**,
**rebasado** del de ROCKNIX (`gamescope-max-height.patch`, Philippe Simons) a nuestro
commit `6644cc9` + nuestro parche `0007`.

Qué hace el parche:
- Añade el flag **`--rotated-output-max-height N`**.
- Clampa la altura **lógica** de salida (aspect-preserving, ambos ejes pares) cuando el
  panel se escanea rotado, y **escala los CRTC rects** de vuelta al modo real para que
  el mismo plano haga el upscale gratis (`SRC_W/H` se quedan en el tamaño de textura;
  la escala es `src -> crtc`).
- `drm_set_refresh()` busca el modo por el tamaño **real** del panel cuando el clamp
  está activo (el tamaño clampado no casa con ningún modo del conector).

> **Por qué hay que rebasarlo**: el parche espera como base la rotación **por
> composición** (`g_uOutputRotation`, nuestro `0007`). Sin `0007` fallan 2 de 4 hunks.
> Con `0007` aplicado **entra limpio (0 hunks fallidos)**.

### El cambio en `pocknix-steam`

Se **quita** `--force-composition-rotation` y se **añade** el flag nuevo:

```bash
# ANTES (rotación por composición, coste de GPU)
--force-orientation "${ORIENT}" --force-composition-rotation -e --

# AHORA (rotación por hardware en el DPU)
--force-orientation "${ORIENT}" --rotated-output-max-height 1088 -e --
```

> Al quitar `--force-composition-rotation`, gamescope deja `g_uOutputRotation = 0`
> cuando el plano **sí** puede rotar → y el DPU hace la rotación en scanout.

---

## 4. ✅ Cómo verificar que la rotación por hardware está ACTIVA

```bash
sudo cat /sys/kernel/debug/dri/0/state | grep -A3 "plane\["
```

Los planos **activos** (los que tienen `crtc=crtc-0`) deben mostrar:

```
plane[53]: plane-1
	crtc=crtc-0
	crtc-pos=1080x1920+0+0
	rotation=8          <-- DRM_MODE_ROTATE_270  = HARDWARE
```

| `rotation=` | Significa |
|---|---|
| **`8`** (`ROTATE_270`) | ✅ **El DPU rota el plano** (hardware) |
| `1` (`ROTATE_0`) | ⚠️ Gamescope rota en el **compositor** (la textura ya viene rotada) |

Los planos **inactivos** (`crtc-pos=0x0+0+0`) tienen `rotation=1`: es normal.

**Bitácora de referencia (20/09/2026):**
```
plane[53]: crtc=crtc-0  crtc-pos=1080x1920+0+0  rotation=8   <- ACTIVO
plane[59]: crtc=crtc-0  crtc-pos=1080x1920+0+0  rotation=8   <- ACTIVO
plane[47]:               crtc-pos=1080x1920+0+0  rotation=8
plane[65/71/77]:         crtc-pos=0x0+0+0        rotation=1   (inactivos)
```

Otras comprobaciones:
```bash
# el gamescope debe llevar el flag nuevo y NO el viejo
pgrep -a gamescope | grep -oE "rotated-output-max-height [0-9]+|force-composition-rotation"

# el panel y su modo
cat /sys/class/drm/card0-DSI-1/status   # connected
cat /sys/class/drm/card0-DSI-1/modes    # 1080x1920

# mensajes del clamp (solo aparecen si el clamp se dispara)
grep -iE "rotated-output-max-height|logical output" ~/pocknix-steam.log
```

> El mensaje `"--rotated-output-max-height: logical output AxB -> CxD"` **solo sale si
> el clamp se dispara**. En nuestra Odin **no se dispara** (1080 ≤ 1088) → es normal no
> verlo.

---

## 5. Historia: por qué NO usamos 7.2.6

El 7.2.6 traía **dos regresiones de mainline** que lo hacían inviable:

1. **Display** (la Trampa B de arriba): `dsi_calc_clk_rate_6g()` → `-22` → panel negro.
   Se probó el revert y **el display arrancaba**, así que era eso.
2. **WiFi**: `ath12k_wifi7_pci: failed to set mhi state: POWER_ON(2)` →
   `failed to start mhi: -110` → `probe ... failed with error -110` (timeout del MHI a
   los ~90 s → sin `wlan0`). **Revertir el driver ath12k completo NO bastó** → el fallo
   está en el **MHI** (`drivers/bus/mhi/host/*`) y/o **`pcie-qcom.c`**.

**Decisión**: volver a **nuestro 7.2.4** (que funciona todo) y añadirle **solo** los 3
parches de rotación. Commit `bc08546`.

> Los parches de rotación **NO eran los culpables** del panel negro: un 7.2.6 sin
> rotación (el "nodpu") fallaba igual.

---

## 6. El obstáculo extra: la BTF (que rompía TODOS los módulos)

Al montar el 7.2.4 con rotación, la Odin arrancaba pero: **sin audio, sin botones, LEDs
encendidos y con el asistente de primer arranque de Steam**. El journal:

```
failed to validate module [soundwire_bus] BTF: -22
failed to validate module [snd_soc_lpass_tx_macro] BTF: -22
inputplumber: modprobe: ERROR: could not insert 'vhci_hcd': Invalid argument
inputplumber: Failed to create target device: failed to load vhci-hcd module
systemd: dev-zram0.device: Job ... timed out
```

→ **El kernel rechazaba TODOS los módulos por BTF inválida** (`-22`). Sin módulos: sin
audio (soundwire/lpass), sin `vhci-hcd` (el mando virtual de InputPlumber), sin zram.

**Causa**: `scripts/build-kernel.sh` **activa la BTF a propósito** (`DEBUG_INFO_BTF=y` +
`DEBUG_INFO_BTF_MODULES=y` + `SCHED_CLASS_EXT=y`, para el scheduler `scx_lavd`) y
desactiva `DEBUG_INFO_REDUCED`. Con **GCC 16.1.0** el DWARF por defecto es **DWARF 5**,
y **pahole 1.32 genera BTF de módulos MALFORMADA** con él
(`libbpf: Malformed BTF string section, did you forget to provide base BTF?`).
La config original de Pocknix no lo sufre porque tiene `DEBUG_INFO_REDUCED=y` +
`PAHOLE_VERSION=0` (**sin BTF**) — de ahí que su `scx_lavd` tampoco funcionase.

**Fix (commit `6d9f751`)**: en `scripts/build-kernel.sh`, cambiar
`--enable DEBUG_INFO_DWARF_TOOLCHAIN_DEFAULT` → **`--enable DEBUG_INFO_DWARF4`**.
Mantiene BTF + sched_ext y pahole genera BTF **válida**.

**Verificación**:
```bash
pahole -F btf --btf_base <vmlinux> <modulo>.ko   # antes: "Malformed BTF string section"
```

> ⚠️ **Fallback** si algún día vuelve a fallar la BTF: desactivar `DEBUG_INFO_BTF` +
> `DEBUG_INFO_BTF_MODULES` y volver a `DEBUG_INFO_REDUCED=y` (como Pocknix original) —
> se pierde `scx_lavd` pero **todo lo demás funciona**.

---

## 7. Resumen de commits

| Repo | Commit | Qué |
|---|---|---|
| `pocknix-os` | `bc08546` | Volver a 7.2.4 + los 3 parches de rotación |
| `pocknix-os` | `6d9f751` | DWARF 4 para que pahole genere BTF válida |
| `pocknix-os` | `51c8def` | gamescope: `--rotated-output-max-height` (rotación HW) |

Estado verificado en la Odin (20/09/2026):
```
kernel 7.2.4 · rotación HW (rotation=8) · 0 errores BTF · audio · mando · WiFi · zram
gamescope 6644cc9-5 con --rotated-output-max-height 1088
```
