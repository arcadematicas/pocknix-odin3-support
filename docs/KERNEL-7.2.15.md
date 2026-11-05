# Kernel 7.2.15 — análisis de actualización (5/11/2026)

**Veredicto: no es un drop-in.** Dry-run sobre el tarball de kernel.org `linux-7.2.15`
(sha256 `d0f6b1d7324c…`): **155 de 168 parches aplican limpios**; **13 hay que rebasar**.

No se toca el kernel que corre (7.2.12) hasta rebasar y validar en la Odin.

## Los 13 que fallan

| Prioridad | Parche | Qué es |
|---|---|---|
| 🔴 **Crítico (pantalla)** | `20-sm8750/0028-drm-panel-Add-panel-driver-for-Chipone-ICNA35XX-base.patch` | driver del panel de la Odin 3 |
| 🔴 **Crítico (pantalla)** | `20-sm8750/0048-drm-msm-dsi-reparent-byte-pixel-src-to-xo-on-disable.patch` | reparent del byte/pixel clock al apagar DSI |
| 🟠 Suspend/fan | `25-armada-sleep/0504-mailbox-qcom-ipcc-mask-summary-irq-for-suspend-to-ram.patch` | IPCC en suspend |
| 🟠 Suspend/fan | `25-armada-sleep/0532-hwmon-pwm-fan-optionally-run-the-fan-while-charging-in-s2idle.patch` | ventilador en s2idle/carga |
| 🟠 Suspend/fan | `25-armada-sleep/0541-input-joystick-mcu-joystick-power-the-mcu-off-in-suspend.patch` | MCU del mando en suspend |
| 🟠 Suspend/fan | `25-armada-sleep/1006-tty-serial-qcom-geni-mask-non-console-irq-on-suspend.patch` | geni serial en suspend |
| 🟡 Periféricos | `10-mainline/0002-input-add-input-polldev-driver.patch` | input-polldev |
| 🟡 Periféricos | `10-mainline/0005-Bluetooth-btrtl-Add-the-support-for-RTL8733BU.patch` | BT RTL8733BU |
| 🟡 Versión | `30-version/0010-msm-resource-cleanup.patch` | limpieza de recursos MSM |
| ⚪ Rendimiento (prescindibles) | `05-speedup/04-kallsyms…` | kallsyms binario |
| ⚪ Rendimiento (prescindibles) | `05-speedup/12-kbuild_avoid_re_running…` | probes de kbuild |
| ⚪ Rendimiento (prescindibles) | `05-speedup/14-modpost_cache…` | cache de modpost |
| ⚪ Rendimiento (prescindibles) | `05-speedup/22-kbuild_build_rust_crates_in_parallel…` | crates Rust en paralelo |

Los conflictos son de **contexto** (hunks pequeños: 1 de 5–12 en la mayoría), no de fondo.
Ninguno está ya incorporado en 7.2.15 (el apply inverso también falla).

## Plan cuando toque

1. Rebasar los 13 sobre un árbol 7.2.15 (empezando por los 🔴 de pantalla).
2. `KERNEL_VERSION=7.2.15` + `KERNEL_SOURCE_SHA256=d0f6b1d7324c…` en `kernel/sm8750/kernel.conf`.
3. Los 4 `05-speedup` se pueden **omitir** si el rebase se atasca (son ganancia de tiempo de
   compilación, no funcionalidad).
4. Build completo + instalar en la Odin + probar pantalla/suspend/audio antes de publicar.
5. Si sale bien, mover los parches que upstream ya no necesite a `reference/superseded-patches/`
   con nota (como se hizo con `0002-input-rsinput`).

Nota: `25-armada-sleep` vivía **solo en el árbol**; ya está portado al centro y mapeado en
`sync-to-os.sh`/`check-sync.sh`.
