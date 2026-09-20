# pocknix-odin3-support — AYN Odin 3 (SM8750 / Snapdragon 8 Elite)

**El centro de nuestro trabajo** para hacer que [pocknix-os](https://github.com/shuuri-labs/pocknix-os)
(Arch Linux ARM) corra en la **AYN Odin 3** (Qualcomm **SM8750** / **Adreno 830**).

Este repo es la **fuente de verdad**: parches de kernel y gamescope, paquetes propios
(Mesa/Turnip, bootloader, BSP, DeckStation…), overlay de sistema, herramientas y toda la
documentación. El árbol de compilación (`pocknix-os`) **se regenera desde aquí**, nunca al revés.

> ⚠️ **No es un fork del sistema.** El sistema vive en
> **`arcadematicas/pocknix-os`** (rama **`odin3-sm8750`**), que mezcla upstream + lo de aquí.
> Este repo solo contiene *lo nuestro*.

---

## 📊 Estado actual (20/09/2026)

| Área | Estado |
|---|---|
| **Arranque** | ✅ Kernel **7.2.4** + DTS del Odin 3. Arranque en ~20 s (`pocknix-diag` a timer, no bloquea) |
| **Rotación de pantalla** | ✅ **POR HARDWARE** — el DPU rota en scanout (`rotation=8`/`ROTATE_270`), sin coste de GPU. Ver [`docs/ROTACION-HARDWARE.md`](docs/ROTACION-HARDWARE.md) |
| **Sesión de juego** | ✅ gamescope + Steam gamepadui estable (sin `VkDeviceLost`) |
| **Gráficos** | ✅ **Mesa 26.2.3** + **Turnip 20260918** (`driverInfo = Mesa 26.2.3-pocknix2.1`, Adreno 830, Vulkan 1.4.354) |
| **Mando + táctil** | ✅ InputPlumber, incluido el gamepad UART (driver `rsinput`) |
| **WiFi / Bluetooth** | ✅ NetworkManager + `hci0` (ath12k **WCN7860**) |
| **Audio** | ✅ Sound card `SM8750AYN` (ADSP + stack LPASS completo) |
| **Batería** | ✅ Carga + % estimado por OCV (ver [`docs/BATTERY-ISSUE.md`](docs/BATTERY-ISSUE.md)) |
| **Suspensión** | ✅ `s2idle` real + hook que reactiva la pantalla al resumir ([`docs/SUSPEND-ISSUE.md`](docs/SUSPEND-ISSUE.md)) |
| **Escritorio (Plasma)** | ✅ KScreen enumera el panel ([`docs/KSCREEN-ISSUE.md`](docs/KSCREEN-ISSUE.md)) |
| **Bootanimation** | ✅ Splash del Odin 3 dibujado en `/dev/fb0` (sin Plymouth) |
| **Bootloader** | ✅ **ABL 1.1.8** en ambos slots (`pocknix-update-abl --status` → `uptodate`) |
| **Emulación** | ✅ DeckStation ARM en `/opt/deckstation/` (capa de emulación propia) + WProton |
| **Panel Decky** | ✅ PocknixControl en la imagen (potencia, luces, OLED care) |
| **Sensores IIO** | ⚠️ `hexagonrpcd` sale al arrancar y no expone IIO → **sin auto-rotación ni brillo adaptativo** |

> El detalle de la sesión más reciente y lo que queda: [`docs/PENDIENTE-2026-09-20.md`](docs/PENDIENTE-2026-09-20.md)

---

## 🎯 El hito: rotación por hardware

El panel es **1080x1920 portrait** y el escritorio se usa en landscape. Rotar en el
**compositor** cuesta una pasada de GPU **por frame**; rotar en el **scanout del DPU** es gratis.

Conseguirlo requirió dos mitades que tienen que encajar:

1. **Kernel** — los parches de rotación inline del DPU (`0013`, `0067`, `0068`).
2. **gamescope** — el parche `0010` (rebasado del de ROCKNIX) que añade
   `--rotated-output-max-height`, para que gamescope sepa **cuándo** puede rotar en scanout.

Y el detalle que costó más: **la BTF**. Con GCC 16 el DWARF por defecto es DWARF 5, y pahole
generaba BTF de módulos **malformada** → el kernel rechazaba **todos** los módulos (sin audio,
sin mando, sin zram). Fix: `DEBUG_INFO_DWARF4`.

👉 **Guía completa (incluye cómo verificarlo):** [`docs/ROTACION-HARDWARE.md`](docs/ROTACION-HARDWARE.md)

---

## 🗂️ Estructura

| Ruta | Qué es |
|---|---|
| **`kernel/patches/`** | Nuestro set de parches del kernel, aplicados en orden numérico por el build: `05-speedup` (22, aceleración de kbuild), `10-mainline` (5, input/pwm/BT/DPU), `20-sm8750` (6, **nuestros**), `30-version` (2) |
| **`kernel/dts/`** | `cq8725s-ayn-odin3.dts` + `cq8725s-ayn-common.dtsi` (panel, WiFi, mando, rutas de firmware `ayn/odin3`) |
| **`packages/`** | Paquetes propios: `gamescope` (parche 0010), `pocknix-steam`, `pocknix-bootloader-sm8750`, `pocknix-bsp-sm8750` (daemons/servicios/device.conf), `pocknix-bsp-common`, `linux-pocknix-sm8750`, `soc-overrides` (mesa, turnip, mangohud…), `deckstation-arm`, `suyu-libretro`, `python-pygame-ce`, `pocknix-tools`, `pocknix-desktop` |
| **`overlay/`** | Ficheros que van al rootfs: `pocknix-diag.timer`, `pocknix-oobe-marker.service`, bootanimation, `pocknix-oobe-marker` |
| **`tools/`** | `sync-to-os.sh` + `check-sync.sh` (centro ↔ árbol), `flash-kernel.sh`, `reflash-sd.sh`, `restore-kernel-from-sd.sh`, `deploy-to-device.sh`, `check-mesa.sh`, `push-file.sh` |
| **`scripts/`** | `build-packages.sh` y `build-sd-image.sh` (nuestras versiones; el sync las lleva al árbol) |
| **`docs/`** | Toda la documentación (índice abajo) |
| **`reference/`** | Material de consulta: estudio de ArmadaOS, backups de ABL/kernel, parches superados, variantes de lanzador |
| **`BUILD.md`** | Guía de compilación desde cero para colaboradores |

---

## 🔧 Cómo se trabaja aquí

### Reglas de oro

1. **Se edita SIEMPRE en este repo.** `pocknix-os` es el árbol de compilación: se regenera con
   `tools/sync-to-os.sh`.
2. Tras editar: **`tools/sync-to-os.sh`** y **`tools/check-sync.sh`** (el build llama a este
   último y **aborta si el árbol no coincide con el centro**).
3. **`DEVICE=sm8750` es obligatorio** en `make build` / `make kernel` / `make packages`
   (por defecto compilan `sm8550`).
4. **Lo upstreamable** (kernel, DTS, BSP, fixes de arranque) se saca a la rama `odin3-pr` en
   commits limpios. **Nuestro desarrollo** (DeckStation, MAKO…) se queda en `odin3-sm8750`.

### ⚠️ La trampa del sync (nos ha mordido)

El sync **copia del centro al árbol**, así que **si el centro está más viejo, REVIERTE**
mejoras ya commiteadas. Ya pasó con el PKGBUILD del bootloader (volvía a 1.1.7) y con el parche
`0010` de gamescope (se habría perdido la rotación por HW).

> **Regla**: tras arreglar algo en el árbol, **copiarlo al centro y commitearlo en la misma
> sesión**. Comprobar con `git diff HEAD -- <fichero>` después de cada sync.

### Compilar

```bash
# En el árbol (pocknix-os), tras sincronizar:
JOBS=14 DEVICE=sm8750 ./scripts/build-kernel.sh     # kernel
sudo env DEVICE=sm8750 make packages PKG=gamescope  # paquetes (necesita root)
```

Guía completa: [`BUILD.md`](BUILD.md)

---

## 💡 Lo más valioso (candidato a upstream)

1. **Rotación por hardware en paneles portrait del DPU** — parches de kernel `0013/0067/0068` +
   el parche de gamescope `0010`. Aplica a cualquier SoC con rotador inline (no solo SM8750).
2. **Fix de la BTF con GCC 16** — `DEBUG_INFO_DWARF4`; sin él el kernel rechaza todos los
   módulos y el sistema arranca sin audio/mando/zram. Afecta a cualquier build con GCC ≥ 16.
3. **Adreno a8xx GX-collapse fix** (`0051`) — resuelve el `VkDeviceLost` del compositor en
   Adreno 830. **Complementario** al `0050` de ROCKNIX (los dos son necesarios).
4. **DTS del Odin 3** — soporte SM8750 (panel, WiFi, mando) con firmware ADSP/CDSP en `ayn/odin3/`.
5. **Driver gamepad `rsinput`** (backport) — sin él no se detecta el mando UART del Odin 3.
6. **Suspensión s2idle real + hook de pantalla** — `mem_sleep_default=s2idle`, `pocknix-powerd`
   mirando el **DPMS del conector** (no `bl_power`) y el hook `sleep.d/post/004-display`.
   El bloqueo de `vhci_hcd` (InputPlumber) abortaba el suspend.
7. **Firmware del Odin 3** — `linux-firmware` no trae los blobs (ath12k **WCN7860**,
   `qcom/sm8750/ayn/odin3/`, `aw883xx_acf.bin`, `SM8750-AYN-tplg.bin`). Se bajan de
   `ROCKNIX/extra-firmware` en `make sync`. Ver [`docs/FIRMWARE-ISSUE.md`](docs/FIRMWARE-ISSUE.md).
8. **Carga de batería** — la clave era el `adsp_dtb.mbn` con la config de **autenticación de
   batería** del ADSP. Sin él el firmware entraba en TEST MODE y no cargaba.
9. **Arranque + OOBE** — `pocknix-diag` como timer, gate de gamescope vs panel DSI, marker de la
   OOBE y el `steamos-update apply` que devuelve 0 (→ bucle de reinicio). Ver
   [`docs/BOOT-OOBE-ISSUE.md`](docs/BOOT-OOBE-ISSUE.md).
10. **Pseudo-TDP en SM8750** — el SoC no expone nodo de TDP; la vía práctica es limitar
    `scaling_max_freq` (CPU) y `devfreq max_freq` (GPU), con perfiles bajo/medio/alto.
11. **Patrón per-game con restauración por PID** — el wrapper de Proton escribe
    `/run/pocknix/game-mode`; los daemons aplican el tweak mientras el PID vive y restauran al
    morir. Campos **añadidos al final** para no romper lectores existentes.
12. **MangoHud parcheado SM8750** — el genérico no lee el GPU del SM8750 mainline (busca rutas
    kgsl que no existen); los parches de ROCKNIX apuntan a `gpuss0_thermal` y
    `/sys/class/devfreq/3d00000.gpu`.
13. **Watchdog de la UI de Steam** — `steamwebhelper` bajo FEX/CEF se congela; healthcheck al
    puerto de debug (`127.0.0.1:8080`) para reiniciarlo.
14. **Bootanimation en fb0** — el patrón para splash en handhelds con panel DSI sin EDID:
    dibujar en `/dev/fb0` desde systemd, no Plymouth.
15. **Plugin Decky en la imagen** — PocknixControl en `/usr/share/decky-plugins/`; Decky lo copia
    a `homebrew/` al arrancar, así que los cambios van en la **fuente** o se pierden.

---

## 📚 Documentación

| Doc | Qué cuenta |
|---|---|
| [`docs/ROTACION-HARDWARE.md`](docs/ROTACION-HARDWARE.md) | **Rotación por hardware**: las 2 trampas, la solución, cómo verificarla, y el fix de la BTF |
| [`docs/PENDIENTE-2026-09-20.md`](docs/PENDIENTE-2026-09-20.md) | Última sesión: resultados, pendientes y notas de trabajo |
| [`docs/BATTERY-ISSUE.md`](docs/BATTERY-ISSUE.md) | Batería: gauge en el firmware ADSP, autenticación, carga |
| [`docs/SUSPEND-ISSUE.md`](docs/SUSPEND-ISSUE.md) | Suspensión s2idle: causa, bloqueos y hooks |
| [`docs/KSCREEN-ISSUE.md`](docs/KSCREEN-ISSUE.md) | Escritorio: por qué Ajustes → Pantalla no veía el panel |
| [`docs/FIRMWARE-ISSUE.md`](docs/FIRMWARE-ISSUE.md) | Imagen limpia sin WiFi/audio: blobs que faltaban |
| [`docs/BOOT-OOBE-ISSUE.md`](docs/BOOT-OOBE-ISSUE.md) | Arranque lento + OOBE de Steam |
| [`docs/IDEAS.md`](docs/IDEAS.md) | Ideas y análisis (ext4 vs F2FS en la UFS interna, etc.) |
| [`docs/ARMADAOS-STUDY.md`](docs/ARMADAOS-STUDY.md) | Estudio de ArmadaOS (qué portamos y qué no) |
| [`docs/MAKO-AARCH64.md`](docs/MAKO-AARCH64.md) | MAKO (frame gen): por qué no funciona en ARM todavía |
| [`docs/session-fixes.md`](docs/session-fixes.md) | Recetario de la sesión de juego (gamescope/Steam) |
| [`docs/PR-DESCRIPTION.md`](docs/PR-DESCRIPTION.md) | Texto del PR upstream #81 (aparcado) |
| [`AGENTS.md`](AGENTS.md) | Contexto profundo del proyecto (para agentes/colaboradores) |

---

## 🤝 Upstream

El **PR #81** ([shuuri-labs/pocknix-os](https://github.com/shuuri-labs/pocknix-os/pull/81)) lleva
el soporte del Odin 3 en su forma "limpia" (rama `odin3-pr`). Está **aparcado** a la espera del
mantenedor. Toda nuestra evolución del día a día vive en `odin3-sm8750`.

## 📄 Notas

- Sin credenciales ni binarios de terceros en el repo (los blobs de firmware se descargan).
- Trabajo hecho en un fork; los artefactos están listos para portar/mergear.
