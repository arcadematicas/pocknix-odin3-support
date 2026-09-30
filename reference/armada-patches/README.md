# Parches de ArmadaOS que NOS FALTAN (traídos el 30/09/2026)

Fuente: `https://github.com/armada-os/armada` → `packages/kernel/patches/`.
ArmadaOS soporta **el mismo dispositivo** (AYN Odin 3 / SM8750) y mantiene un índice curado de
parches (`packages/kernel/PATCHES.md`, 175 entradas) — **nuestra referencia más cercana**.

⚠️ **OJO con los NÚMEROS**: colisionan con los nuestros (nuestro `0049` es el catálogo Adreno 830,
el suyo es el dither). Comparar **siempre por función**, no por número.

## Los que nos faltan (verificados el 30/09/2026)

| Parche | Qué arregla | Valor |
|---|---|---|
| `1003-input-haptics-fix-rumble-bridge-atomic-sleep.patch` | El "bridge" importado llamaba a los callbacks de haptics (que **duermen**) bajo `spin_lock_irq` → `BUG: scheduling while atomic` en **cada parada de vibración** y **cuelgues duros intermitentes de la Odin 3** (reproducido en hardware). ROCKNIX tiene el mismo bug (04/08/2026). Ahora serializa con mutex, RSInput difiere el callback a un work item y el suspend cancela los workers. | ⭐⭐⭐ **MUY ALTO** (es un cuelgue real) |
| `0049-drm-msm-dpu-panel-opt-in-8bpc-dither.patch` | Dither del DPU opt-in por DT (`armada,dpu-8bpc-dither`) → **quita el banding** del panel 10-bit→8bpc | ⭐⭐ Alto (calidad visible) |
| `1006-tty-serial-qcom-geni-mask-non-console-irq-on-suspend.patch` | Enmascara las IRQ no-consola de GENI al suspender | ⭐ Medio (suspensión) |

## También suyos y aprovechables (NO son parches: son DTS)
De `packages/kernel/dts/cq8725s-ayn-odin3.dts.patch`:
- **Modos de reposo de los raíles del codec** (`vreg_bob1`, `l15b_1p8`, `l2i_1p2`, `s3g_1p8`, `s7i_1p2`
  → `regulator-on-in-suspend` + `RPMH_REGULATOR_MODE_LPM`): *"el codec mantiene esos raíles activos
  durante s2idle; en LPM"* → **ahorro en suspensión, y es solo DTS**.
- `armada,dpu-8bpc-dither` en `&display_panel` (necesita el parche `0049` de arriba).

⚠️ **Ojo**: nuestro `cq8725s-ayn-common.dtsi` **ya es el suyo** (difiere en 3 líneas) y ahí **vamos por
delante**: tenemos el fix de `wake-gpios` ACTIVE_LOW para s2idle (de armada `431bf57`) que su main no
tiene en el DTS.

## Cómo se aplican
```bash
K=pocknix-os/build/kernel/sm8750/linux-7.2.6   # la fuente del build
cd "$K" && patch -p1 --dry-run < <parche>      # comprobar antes
```
Los parches del build se aplican desde `kernel/sm8750/patches/*/` **en orden numérico**
(05-speedup → 10-mainline → 20-sm8750 → 30-version) y `build-kernel.sh` **re-extrae la fuente** en
cada build.
