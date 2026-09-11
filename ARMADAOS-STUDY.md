# Estudio ArmadaOS vs Pocknix — AYN Odin 3 (SM8750)

> Estudio realizado el **11/09/2026** con la Odin arrancada en **ArmadaOS**
> (SSH `armada@192.168.4.29`, usuario/clave `armada`). Kernel 7.2.3.
> Objetivo: catalogar todo lo que ArmadaOS hace y Pocknix no, para decidir qué
> portar (sistema operativo, Steam, Plasma, energía, entrada...).
>
> Los scripts/fics de ArmadaOS están copiados en `armadaos-reference/`
> (`libexec-armada/`, `lib-armada/`, `gamescope-session-plus/`, `kernel-config-armada.txt`,
> `packages-armada.txt`, `services-armada.txt`).

---

## 0. Resumen ejecutivo

ArmadaOS es **Fedora 44 bootc + ostree + Btrfs** (subvol `root`, `compress=zstd:1`) con
**initramfs dracut**, **SDDM** y **gamescope-session-plus**. Pocknix es **Arch Linux ARM +
ext4 + sin initramfs** con supervisor propio. El **kernel es prácticamente el mismo**
(configs clave idénticas: `SCHED_CLASS_EXT=y`, `ANDROID_BINDER*=y`, `QCOM_PMIC_PDCHARGER_ULOG=m`).

Lo importante **no es el SO, son sus scripts de integración** (`/usr/libexec/armada/`,
`/usr/lib/armada/`, `/usr/share/armada/`). Pocknix **ya ha portado varios** (proton-wrapper,
guestos-mount, fex-profiles, lavd, steamos-shim). Lo que sigue faltando, por prioridad:

1. **`fake-suspend` / gestión de suspensión** — Pocknix **desactiva** la suspensión; ArmadaOS
   suspende de verdad (s2idle) con fallback "fake suspend". *(Alto)*
2. **`dbus-update-activation-environment` en la sesión de escritorio** — justo el problema
   que tuvimos con el daemon de KScreen (env Wayland no llegaba a systemd --user). *(Alto, trivial)*
3. **`armada-game-launch`** — wrapper de lanzamiento que arregla el **mando muerto en Proton**
   (inyecta `libwayland-client`/`libxkbcommon` x86), aplica perfiles FEX y **repara el mando
   atascado** en el prefijo. Pocknix tiene `pocknix-proton-wrapper` pero sin estas partes. *(Alto)*
4. **Perfiles de energía completos (`armada-powerd`, D-Bus `org.armada.Power1`)** — CPU caps por
   perfil, GPU devfreq auto/manual, curvas de ventilador, suspensión. Pocknix tiene fancontrol
   y lavd-mode pero no un daemon unificado. *(Medio-alto)*
5. **`controller-type`** (cambiar el mando a Steam Deck / Xbox 360 / DualSense por D-Bus
   InputPlumber). *(Medio)*
6. **Calibración de sticks/triggers** vía parámetros del módulo `rsinput`. Pocknix tiene
   `pocknix-gamepad-calibration` pero es otro enfoque. *(Medio)*
7. **MTP** (`umtp-responder`) para pasar archivos por USB. *(Medio)*
8. **HDR** (`ARMADA_HDR_NITS=650` + `STEAM_GAMESCOPE_HDR_SUPPORTED=1`). *(Medio)*
9. **`backlight-acl` + "brightness steering"** (Steam escribe el brillo correcto). *(Bajo-medio)*
10. **`scx_loader`** (cambio de scheduler sched_ext en caliente; Pocknix lanza `scx_lavd` directo). *(Bajo)*
11. **UCM de audio del Odin 3** (`AYN/Odin3`) — Pocknix solo trae el de KONKR del overlay ROCKNIX. *(Verificar)*

---

## 1. Base del sistema operativo

| Aspecto | ArmadaOS | Pocknix |
|---|---|---|
| Distro | Fedora Linux 44 (bootc / ostree) | Arch Linux ARM |
| Root | Btrfs, `subvol=/root`, `noatime,compress=zstd:1` | ext4 |
| Initramfs | dracut (`--no-hostonly`, ~645 módulos) | **ninguno** (root montado directo) |
| Kernel | 7.2.3 (stable, sin parches odin3) | 7.2.4 + parches (batería, GPU, UCSI...) |
| Config kernel (clave) | `SCHED_CLASS_EXT=y`, `ANDROID_BINDER*=y`, `QCOM_PMIC_PDCHARGER_ULOG=m` | **idénticas** |
| Gestor de sesión | **SDDM** (autologin) | supervisor propio (`~/.bash_profile` + `pocknix-session`) |
| Actualizaciones | `bootc` (imagen OCI `ghcr.io/armada-os/armada:beta`) | `pacman` |
| Firmware ADSP | `qcom/sm8750/ayn/odin3/adsp.mbn` (6cfcbbb8) + `adsp_dtb.mbn` (d88d7ecb) | **fix aplicado** (los mismos 2 ficheros) |

**cmdline de ArmadaOS** (7.2.3):
```
ostree=/ostree/boot.1/default/<hash>/0 root=UUID=... rw boot=UUID=... rootwait
console=tty0 quiet loglevel=3 allow_mismatched_32bit_el0 fw_devlink.strict=1
pcie_ports=compat psi=1 cgroup_disable=pressure cgroup.memory=nokmem,nosocket
cpufreq.default_governor=schedutil swiotlb=8192 rootflags=subvol=/root,noatime,compress=zstd:1
```
Notas: usa **`fw_devlink.strict=1`** en SM8750 (nuestra nota decía que era solo de SM8550),
**`psi=1`** (pressure stall info), **`cgroup_disable=pressure`**, **`swiotlb=8192`**,
**`cpufreq.default_governor=schedutil`**. Nuestro cmdline SM8750 no los lleva.

**Firmware de carga** (para el fix permanente): en ArmadaOS están en
`/usr/lib/firmware/qcom/sm8750/ayn/odin3/` (los genéricos `qcom/sm8750/adsp*.mbn` van **`.xz`**).
El DTS de ArmadaOS apunta a la ruta `ayn/odin3/`; el nuestro apunta a `qcom/sm8750/`, por eso
copiamos los ficheros a esa ruta. **Copia en `armadaos-reference/` NO incluida** (21 MB); están
en `/tmp/opencode/armada-fw/` y se integrarán en el build.

---

## 2. Arranque y gestión de sesión

- **SDDM** con autologin; el `session-control` escribe
  `/etc/sddm.conf.d/zz-steamos-autologin.conf` y reinicia SDDM.
- **`session-control`** (`switch-desktop|switch-gamemode|default-gamemode`):
  separa la config de Plasma **desktop** y **mobile** con symlinks
  (`plasmashellrc.desktop` / `plasmashellrc.mobile`) — permite cambiar de modo sin perder ajustes.
- Sesiones: `gamescope-session-steam.desktop` (Exec=`gamescope-session-plus steam`),
  `armada-plasma.desktop` (Exec=`/usr/libexec/armada/start-plasma`).
- **Splash**: `armada-splash-early.service` (antes de `basic.target`) + `armada-splash` (binario C
  + libdrm, 135 KB) + `splash.asp`. Mismo concepto que nuestro `odin3-splash` (fb0/drm), pero
  con **binario nativo** y `armada-splash-progress` para el arranque.

**Portable a Pocknix:** el truco de **dos configs de Plasma (desktop/mobile) por symlink** es
interesante si queremos conservar ajustes separados. Nuestro splash ya es equivalente.

---

## 3. Steam (cliente, entorno y flags)

**Cliente**: nativo ARM en `~/.local/share/Steam/steamrtarm64/steam` (igual que Pocknix).
`launch-steam` monta `LD_LIBRARY_PATH` con `steamrtarm64` + `lib/aarch64-linux-gnu`,
`FUSERMOUNT_PROG=/run/host/usr/bin/fusermount3`, y limpia el registro viejo de Proton 11.

**Flags**: `/usr/libexec/armada/launch-steam -gamepadui -steamos3 -steampal -steamdeck`
(Pocknix añade además `-noverifyfiles -noshaders`; ArmadaOS no usa `-noshaders`).

**Variables de sesión** (`gamescope-session-plus/sessions.d/steam`) — comparar con las nuestras:

| Variable | Valor | Pocknix |
|---|---|---|
| `STEAM_GAMESCOPE_VRR_SUPPORTED` | `1` | ❔ |
| `STEAM_USE_MANGOAPP` / `STEAM_MANGOAPP_PRESETS_SUPPORTED` | `1` | ❔ |
| `STEAM_MANGOAPP_HORIZONTAL_SUPPORTED` | `1` | ❔ |
| `STEAM_DISABLE_MANGOAPP_ATOM_WORKAROUND` | `1` | ❔ |
| `STEAM_USE_DYNAMIC_VRS` | `1` | ❔ |
| `STEAM_GAMESCOPE_DYNAMIC_FPSLIMITER` | `1` | ❔ (¡el frame limiter dinámico por fifo!) |
| `STEAM_GAMESCOPE_HAS_TEARING_SUPPORT` / `_TEARING_SUPPORTED` | `1` | ❔ |
| `STEAM_GAMESCOPE_HDR_SUPPORTED` | `1` | ❔ |
| `STEAM_GAMESCOPE_NIS_SUPPORTED` | `1` | ❔ |
| `STEAM_GAMESCOPE_FANCY_SCALING_SUPPORT` | `1` | ❔ |
| `STEAM_GAMESCOPE_COLOR_MANAGED` / `_VIRTUAL_WHITE` | `1` | ❔ |
| `STEAM_MULTIPLE_XWAYLANDS` | `1` | ❔ |
| `STEAM_ENABLE_VOLUME_HANDLER` | `1` | ❔ |
| `STEAM_DISABLE_AUDIO_DEVICE_SWITCHING` | `1` (lo hace wireplumber) | ❔ |
| `STEAM_ALLOW_DRIVE_UNMOUNT` / `_ADOPT` | `1` | ❔ |
| `STEAMOS_STEAM_REBOOT_SENTINEL` / `_SHUTDOWN_SENTINEL` | rutas en `/tmp` | ❔ |
| `SRT_URLOPEN_PREFER_STEAM` | `1` | ❔ |
| `QT_IM_MODULE=steam` / `GTK_IM_MODULE=Steam` | teclado Steam | ❔ |
| `XCURSOR_THEME=steam` / `XCURSOR_SCALE=256` | cursor | ❔ |
| `GAMESCOPE_FALLBACK_APPID` | `0x41524d41` | ❔ |
| `STEAM_UPDATEUI_PNG_BACKGROUND` | fondo SteamOS | ❔ |
| `GAMESCOPE_FORCE_VULKAN_REALTIME` | `1` (si tweak activo) | ❔ |

> **Verificado**: Pocknix **no define ninguna** de estas variables (búsqueda en `pocknix-os`:
> 0 coincidencias). Su `pocknix-steam` solo pasa flags a gamescope. Es un **portado directo y de
> alto valor** (muchas son solo `export`).

**Muy relevante**: `STEAM_GAMESCOPE_DYNAMIC_FPSLIMITER=1` — el **frame limiter dinámico de
Mesa (fifo)**. Nuestro problema conocido del QAM (el límite no llega a gamescope) podría
resolverse probando este flag.

**`armada-fixups`** (servicio `armada-fixups`): normaliza el id del tool Proton CachyOS
(fecha→estable `proton-cachyos-11.0-arm64`) y borra el wildcard `"0"` de `CompatToolMapping`
(que rompe la instalación de compat tools de Valve). **Buen candidato** (evita fallos tras
actualizaciones de Proton).

**Proton por defecto** (`device-env`): SM8750 = `proton-experimental-arm64:proton_11-arm64:proton-cachyos-11.0-arm64`
(probados en ese orden).

---

## 4. Proton / FEX / lanzamiento de juegos

**`armada-game-launch`** (Python, se pone como *launch option* `armada-game-launch %command%`):

1. **`FEX_APP_CONFIG` por juego** desde `/usr/share/armada/fex-profiles.json` (perfiles
   `default`/`fast`/`compatible` con `TSOEnabled`, `X87ReducedPrecision`, `Multiblock`,
   `VectorTSOEnabled`, `MemcpySetTSOEnabled`, `HalfBarrierTSOEnabled`) + `ThunksDB`
   (Vulkan/GL/drm/WaylandClient/asound). Evita forzar RootFS/thunks para no vaciar el rootfs SLR4.
2. **Inyecta libs x86 de protocolo** (`libwayland-client.so.0`, `libxkbcommon.so.0`) en
   `files/lib/x86_64-linux-gnu` del prefijo → **arregla el mando muerto** (pressure-vessel no
   las trae). `armadaos-reference/share-armada` no las copiamos (binarios x86), pero están en
   `/usr/share/armada/proton-inject/x86_64-linux-gnu/`.
3. **Perf**: afinidad de CPU (`cores`), `WINE_CPU_TOPOLOGY`, `nice`, scheduler; avisa al daemon
   de sesión por socket (`/run/armada/session.sock`).
4. **Repara el mando atascado**: si el prefijo tiene secciones `VID_28DE` sin promover a
   `WINEXINPUT`, las borra de `system.reg` (backup `.armada-bak`).
5. `DXVK_HUD=none` por defecto (Proton-CachyOS muestra el HUD del compilador de shaders).

**Pocknix** ya tiene `pocknix-proton-wrapper` (FEX_APP_CONFIG + fex-profiles) y
`pocknix-guestos-mount` (monta `ArchLinux.sqsh` + `ArmadaMesa.sqsh` en `/usr/share/guestos/fex-mesa`),
pero **le faltan los puntos 2 (inyección de libs → mando) y 4 (reparación del mando)**.
Son los de más valor para el usuario.

**`armada-guestos-mount`**: monta por squashfs+overlay el rootfs x86 de FEX
(`/usr/share/fex-emu/RootFS/ArchLinux.sqsh` + `ArmadaMesa.sqsh`) en `/usr/share/guestos/fex-mesa`.
Pocknix tiene `pocknix-guestos-mount` equivalente.

---

## 5. Energía y térmica

**`armada-powerd`** (daemon D-Bus del sistema, `org.armada.Power` / `/org/armada/Power`, iface
`org.armada.Power1`):
- Métodos: `Reload`, `Suspend`, `Resume`, `GetStatus`.
- Propiedades: `AvailableProfiles`, `Profile`, `SuggestedDefaultProfile`,
  `AvailableGpuPerformanceLevels`, `GpuPerformanceLevel`, `ManualGpuClock`(+Min/Max),
  `FanMode`, `FanPwm`, `FanRpm`, `Temperature`.
- **CLI**: `armada-power status|reload|profile [name]|gpu-auto|gpu-manual <mhz>|suspend|resume`.
- Ejemplo real en el Odin 3: `profile=Balanced`, `cpu_underclock=medium`,
  `cpu_caps={policy0:2227200, policy6:2246400}`, `gpu auto 160–1100 MHz`, `fan managed pwm=51`,
  `temp=42`.

**Perfiles** (`/usr/share/armada/power-profiles.conf`):
- `eco` (cpu_max 0.65, underclock large, gpu_max 0.80, fan relaxed)
- `balanced` (cpu_max 0.65, underclock medium, gpu_max 1.0, fan moderate)
- `performance` (governor performance, underclock none, gpu_min=gpu_max=1.0, fan aggressive)
- **Curvas de ventilador** en `temp:pwm` (relaxed/moderate/aggressive) + parámetros
  `min_pwm=51`, `max_pwm=255`, `ramp_up=36`, `ramp_down=6`, `smoothing=0.50`, `pwm_quantum=8`.
- **Underclock por SoC** (SM8750 small/medium/large → `cpu_max_policy0`/`policy6`).
- **Suspend fan**: `fan_safe_above=55`, `fan_low_pwm=51`, `fan_safe_pwm=128`.

**`fake-suspend`** (por si el suspend real cuelga el SoC; el Odin 3 usa **s2idle real**):
- Se instala como `systemd-suspend.service` y **bloquea hasta el wake**.
- Silencia audio, bloquea input (`evtest --grab`), apaga pantalla
  (`gamescopectl drm_sleep_internal_screen 1`, fallback `bl_power`), **congela `app.slice`**
  (cgroup freeze) y llama a `armada-power suspend` (escrituras devfreq GPU) + runtime PM de USB.
- Espera wake por **tecla power** (o abrir la tapa) y restaura todo.
- `suspend-dispatch` elige fake vs s2idle; `device-quirks` fija `mem_sleep` y crea/borra
  `/etc/NetworkManager/ignore-sleep`.

**Pocknix**: tiene `pocknix-fancontrol` + `pocknix-fan-mode` + `pocknix-lavd-mode`, pero
**desactiva la suspensión** (mask de `sleep.target`). **No tiene `fake-suspend` ni un daemon de
energía unificado con D-Bus.** Portar el modelo de suspensión y el `powerd` es el mayor salto
de calidad.

---

## 6. CPU / rendimiento

- **Schedulers sched_ext**: paquetes `scx-scheds` + `scx-tools` (`scx_loader.service`, ahora
  *disabled*). Modos `eevdf`/`cosmos`/`lavd` (usuario final: `lavd` = latencia baja).
- **`armada_perf.py`**: afinidad de CPU por juego, `WINE_CPU_TOPOLOGY`, **prioridad realtime de
  gamescope** (`SCHED_RR`, prio 40) + `nice`, y selección de scheduler. Estado en
  `/run/armada/perf-state.json`.
- **`game-tweaks.json`**: por appid (y global) — `cores`, `fexProfile`, `gamescopeCores`,
  `gamescopeNice=-20`, `gamescopeRr`, `gamescopeVulkanRealtime`, `scheduler`, `thunks`, `wineTopology`.
- **Topology SM8750**: LITTLE=∅, BIG=0-7, PRIME=6-7, IRQ=∅.

**Pocknix** ya tiene `pocknix-lavd-mode`/`pocknix-lavd.service` (autopilot/performance/balanced/
powersave) y conoce `scx_lavd` en `pocknix-steam`. Falta el `scx_loader` (cambio en caliente) y
la capa de **prioridad realtime de gamescope + tweaks por juego**.

---

## 7. Entrada / mandos

- **InputPlumber** con perfiles por dispositivo (`/usr/share/inputplumber/devices/01-ayn-controller.yaml`, ...).
- **`controller-type`**: cambia el tipo de mando por D-Bus InputPlumber
  (`SetTargetDevices` con `deck-uhid`|`xb360`|`ds5`; por defecto `deck-uhid`). Config en
  `/etc/armada/controller.conf`. También `inputplumber-intercept` (overlay/gamepad/reset).
- **`apply-input-calibration`**: escribe parámetros de calibración de sticks/triggers en
  `/sys/module/rsinput/parameters/` (AYN) desde `/etc/armada/input-calibration.json`.
- **`touchscreen-inhibit`**: inhibe un device por nombre (táctil secundario en modo juego).

**Pocknix**: usa InputPlumber y tiene `pocknix-gamepad-calibration`, pero **no tiene
`controller-type` ni `touchscreen-inhibit`**. El cambio de tipo de mando es útil (algunos juegos
prefieren Xbox/DualSense).

---

## 8. Pantalla / brillo / HDR

- Perfil del panel: `ARMADA_PANEL_ORIENTATION=right`, `ARMADA_HDR_NITS=650`,
  `ARMADA_PRIMARY_CONNECTOR=DSI-1`.
- **`backlight-acl`** (udev): da a `wheel` escritura directa al backlight **salvo** si hay panel
  secundario (entonces Steam usa el helper polkit que "dirige" el brillo al panel primario).
- **`desktop-bootstrap`** (arranque de la sesión de escritorio):
  1. **`dbus-update-activation-environment --systemd`** con `WAYLAND_DISPLAY`, `DISPLAY`,
     `XAUTHORITY`, `KDE_FULL_SESSION`, ... → **soluciona el problema del daemon de KScreen que
     vimos** (env Wayland no llegaba al `systemd --user`).
  2. Aplica **rotación y escala** con `kscreen-doctor` (con marcadores de estado).
  3. `setup-dual-screen` si hay panel secundario.
- **KWin**: `kwinoutputconfig.json` con `highDynamicRange`, `edrPolicy: always`,
  `colorProfileSource: sRGB`, `colorPowerTradeoff: PreferEfficiency`, `brightness` (nativo KWin).

**Portable:** el `dbus-update-activation-environment` es un fix trivial y directo para nuestro
problema de KScreen/Plasma.

---

## 9. Audio

- UCM de ALSA específico: `/usr/share/alsa/ucm2/AYN/Odin3/AYN-Odin3.conf`,
  `Qualcomm/sm8750/...`, `conf.d/sm8750/SM8750-AYN.conf`.
- **Pocknix** solo trae `SM8750-KONKR.conf` del overlay de ROCKNIX (visto en `vendor/`).
  **Verificar** si ALARM/linux-firmware ya aporta el de AYN; si no, portar el UCM de ArmadaOS.

---

## 10. Almacenamiento / transferencia

- **`setup-steamapps`**: crea la biblioteca de Steam como **subvolumen Btrfs con `chattr +C`**
  (nodatacow) → menos fragmentación/desgaste. Solo aplica en Btrfs (Pocknix usa ext4, **no aplica**).
- **MTP**: paquete `umtp-responder` + `armada-mtp.service` + `mtp-gadget` → pasar archivos por USB.
  **Pocknix no lo tiene.**

---

## 11. RGB

- `armada-rgb` + `armada-rgb.service`, backend `channels` con 24 LEDs
  (`red/green/blue` × `l/r` × 4). Pocknix ya tiene RGB en el plugin Decky
  (`pocknix-control/led.py`, `rgb.ts`, `Lighting.tsx`).

---

## 12. Actualizaciones (bootc)

- `armada-update` (hook de Steam `steamos-update`): cambia canal o actualiza vía **`bootc`**,
  reportando % a Steam; difiere hasta que el usuario ha iniciado sesión.
- `armada-select-branch` (hook `steamos-select-branch`), `armada-update-reserve`.
- Pocknix tiene `steamos-select-branch` (shim) pero usa `pacman`, no bootc.

---

## 13. Instalación / gestión de arranque

- `armada-installer`, `armada-abl-update` + `armada-abl-finalize` (ABLs firmados por SoC en
  `/usr/lib/armada/abl/`), `armada-bootimg-update`/`-finalize`, `armada-esp-rename`
  (renombra el ESP de `ROCKNIX` a `ARMADA`).
- Pocknix tiene `pocknix-install-internal` y usa el ABL de ROCKNIX.

---

## 14. Waydroid

- Config en `/usr/share/armada/waydroid/` (`keylayout`, `vendor`) + `armada-waydroid-input.service`/
  `.path` + `waydroid-mesa-overlay`. Pocknix tiene el paquete pero sin configurar.

---

## 15. Tabla resumen (qué tenemos / qué falta / prioridad)

| Feature de ArmadaOS | Pocknix | Prioridad |
|---|---|---|
| Firmware ADSP Odin 3 (carga) | ✅ aplicado en la Odin · ⚠️ falta en el build | **Alta** |
| `dbus-update-activation-environment` (env sesión) | ❌ | **Alta (trivial)** |
| `fake-suspend` + `suspend-dispatch` | ❌ (suspend desactivado) | **Alta** |
| `armada-game-launch`: inyección libs x86 (mando) + reparación mando | ⚠️ parcial (sin esas 2 partes) | **Alta** |
| `armada-powerd` (D-Bus) + perfiles + curvas + underclock | ⚠️ parcial (fancontrol/lavd) | **Media-alta** |
| `STEAM_GAMESCOPE_DYNAMIC_FPSLIMITER` y demás env Steam | ❌ (0 en `pocknix-os`) | **Media-alta** |
| `armada-fixups` (normaliza Proton CachyOS / CompatToolMapping) | ❌ | **Media** |
| `controller-type` (deck/xb360/ds5) | ❌ | **Media** |
| Calibración sticks/triggers (rsinput) | ⚠️ otro enfoque | **Media** |
| MTP (`umtp-responder`) | ❌ | **Media** |
| HDR (`HDR_NITS=650` + env Steam) | ❌ | **Media** |
| UCM audio Odin 3 | ❔ verificar | **Media** |
| `backlight-acl` (steering brillo) | ❌ | **Baja-media** |
| `scx_loader` (cambio scheduler en caliente) | ⚠️ lavd directo | **Baja** |
| `touchscreen-inhibit` | ❌ | **Baja** |
| `armada-fixups` / `armada-control` (daemon control unificado) | ⚠️ plugin Decky | **Baja** |
| RGB (24 LEDs) | ✅ plugin Decky | — |
| Splash | ✅ equivalente | — |
| Proton wrapper / guestos / fex-profiles | ✅ portado | — |
| `scx_lavd` | ✅ portado | — |
| Btrfs nodatacow Steam library | N/A (ext4) | — |

> ❔ = pendiente de verificar en la Odin (Pocknix) en el próximo arranque.

---

## 16. Cómo reproducir este estudio

```bash
ssh armada@192.168.4.29                 # clave: armada
# Scripts de integración:
rsync -a armada@192.168.4.29:/usr/libexec/armada/ ./libexec-armada/
rsync -a armada@192.168.4.29:/usr/lib/armada/    ./lib-armada/
rsync -a armada@192.168.4.29:/usr/share/gamescope-session-plus/ ./gamescope-session-plus/
# Datos:
ssh armada@192.168.4.29 'cat /boot/config-$(uname -r)' > kernel-config-armada.txt
ssh armada@192.168.4.29 'rpm -qa | sort'               > packages-armada.txt
ssh armada@192.168.4.29 'systemctl list-unit-files'    > services-armada.txt
# Perfil de energía en vivo:
ssh armada@192.168.4.29 'armada-power status'
# Perfil de dispositivo (panel, HDR, RGB, cores):
ssh armada@192.168.4.29 '/usr/libexec/armada/device-env'
```