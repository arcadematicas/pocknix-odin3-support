# Revisión de upstream antes de compilar kernel — 18/10/2026

Fuentes revisadas: **pocknix** (`shuuri-labs/pocknix-os`, origin/main), **armada**
(`armada-os/armada`, main, últimos 30 commits), **Deckard** (holo-packages
`archlinux-deckard-hotfixes`, índice completo).

## 1. pocknix — 15 commits nuevos desde el 13/10

| Commit | Qué | ¿Nos sirve? |
|---|---|---|
| `450e18c` + `610e1f4` | **mangohud 0.8.4**, build **único compartido** (fuera parches por SoC), GPU/devfreq y zona térmica **en runtime**; parches nuevos `0007-msm-hottest-gpu-zone` y `0008-gpu_fdinfo-skip-unreadable` | ✅ **Sí** (bajo riesgo, sin kernel). Toca justo nuestro terreno MangoHUD/HDR/consumo |
| `628d784` | **pocknix-session**: espera a que el último compositor suelte el display (#134) | ✅ Sí (cambio gamescope ↔ plasma) |
| `0e3e6e9` | microSD UHS con **sdhci-msm stock**, fuera el driver downstream | ❌ Solo `sm8550` (Odin 2/RP6). Nuestro `sm8750` **no** lleva parches sdhci/mmc |
| `383c375` | **cemu** sigue `main` upstream en vez del pin de ROCKNIX | ⚠️ Decisión aparte (main puede romper; Fransis juega Wii U) |
| `80fd60f`, `c6b3ffb`, `15f81c8`, `b074010`, `9293118`, `078fbed` | Reestructuración: `packages/gpu`, **una** receta `linux-pocknix` para todos los SoC, `devices/<soc>/tuning`, cmdline desde el perfil, `/flash` desde `bsp-common`, calibración de mando en `pocknix-core` | ⏸️ **Estructural**: colisiona con nuestro fork. Pase dedicado, no antes de compilar |
| `bc29ffa`/`1ad1e95`/`0c166b3` | Thor: touch sin doble rotación | ❌ N/A (Thor) |

## 2. armada — lo importante, y es **para el Odin 3**

Serie **deep sleep / AOSS en SM8750** (PR #746 `deep-sleep`, PR #723 `sm8750-soccp`
y commits sueltos). Su kernel también es **7.2** y dicen "backported from the 7.3 work":

| Pieza | Qué hace |
|---|---|
| `eb6e392` | **firmware `soccp.mbn` del Odin 3** (565 KB, sacado de la partición módem; lo carga el driver PAS en lugar de la imagen temprana del bootloader) → permite **CX shutdown y DDR low power** en `s2idle` |
| `0556` + `0556a` | `remoteproc qcom pas`: gestionar el **SoCCP de sm8750** + nodo en el DTS |
| `008e910` (nuevo `…pcie-state-manager-power-control.patch`, 67 líneas) | `PCI0_CESTA`: pcie-qcom no tomaba los state managers → se fija el override en boot (como `pci-msm`) |
| `008e910` (nuevo `…mdss-to-the-display-sequencer-at-suspend.patch`, 457 líneas) + nodo DTS `armada,sm8750-disp-cesta` | el secuenciador de display seguía "activo" (CRM) → **handoff display-off** en suspend y rearme al resumir |
| `0531` | liberar el reloj **I2S** de la tarjeta de sonido en suspend |
| `2764b29`, `cacf1e3` | dejar de mantener las **PCIe GDSC** encendidas en suspend / gestionar SoCCP en vez del "piso" de PCIe |
| `2f280a5` | limpieza de parches de sleep que ya no hacen falta |

**Resultado declarado**: "the Odin 3 counts AOSS deep sleep for the whole suspend".
Esto es lo que explica (y arregla) nuestro "la WiFi flapea" = **suspend**, y la batería
que se va durmiendo. Es **la razón para recompilar kernel**.

Otros de armada: `5b2a681` **rndis** (tethering USB, trivial) · resto = KONKR/ Ayaneo/
SM8250/SM8550/SM8650 → N/A.

## 3. Deckard (holo-packages)

- Lo último que nos sirve ya lo tenemos: **vulkan layers `20261001.1-4`**.
- Nuevos: `deckard-audio-config 20261016.1.3`, `deckard-hw-support 20261015.1.1`,
  `deckard-fan-control 20261015.1.4`, `deckard-uboot/uboot-tools 20261015.1.1`
  → específicos del **Steam Frame**; nada aplicable a la Odin 3.
- Su `mangohud` es `20260922.1.1` (**más viejo** que el 0.8.4 de pocknix) → ignorar.

## Recomendación

1. **Portar la serie de deep sleep de armada al kernel `sm8750`**: los 3 parches nuevos
   (PCIe state managers, MDSS handoff, I2S), `0556`+`0556a` (SoCCP), el nodo DTS del Odin 3
   y el **`soccp.mbn`** al BSP. Compilar kernel **una vez** con todo.
2. Sin kernel, y en paralelo: **mangohud 0.8.4** (shared + 0007/0008) y **pocknix-session #134**.
3. Después: reestructuración de pocknix (pase propio), `cemu` main (decisión), `rndis` (se puede colar ya).

⚠️ Riesgos del port: los parches vienen de una cola distinta (`packages/kernel/patches`
de armada vs nuestros `kernel/sm8750/patches/{05-speedup,10-mainline,20-sm8750,30-version}`),
hará falta adaptarlos; y `soccp.mbn` es un blob de firmware del propio dispositivo
(se distribuye ya con el BSP, comprobar que encaja en la licencia del paquete).
