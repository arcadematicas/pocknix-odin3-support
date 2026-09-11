# Mejoras de ArmadaOS implementadas en Pocknix (11/09/2026)

Portado desde el estudio de ArmadaOS (`ARMADAOS-STUDY.md`). Todo va en las
**fuentes de build** (`pocknix-os`); se aplicará en la próxima imagen.

> Estado: **desplegado en la Odin y verificado** (suspensión real resuelta, ver
> `SUSPEND-ISSUE.md`). El resto queda pendiente de validación fina en uso.

---

## 1. Variables de entorno de Steam/gamescope

**Ficheros**: `packages/shared/pocknix-steam/pocknix-steam` (+ copia en `pkg/.../usr/bin/`).

Antes de lanzar gamescope/Steam se exportan los feature-gates que ArmadaOS usa y
nosotros no definíamos (Steam no expone en el QAM VRR/tearing/HDR/NIS/fps-limiter
dinámico sin ellas):

`STEAM_GAMESCOPE_VRR_SUPPORTED`, `STEAM_USE_MANGOAPP`,
`STEAM_MANGOAPP_PRESETS_SUPPORTED`, `STEAM_MANGOAPP_HORIZONTAL_SUPPORTED`,
`STEAM_DISABLE_MANGOAPP_ATOM_WORKAROUND`, `STEAM_USE_DYNAMIC_VRS`,
`STEAM_GAMESCOPE_HAS_TEARING_SUPPORT`, `STEAM_GAMESCOPE_TEARING_SUPPORTED`,
`STEAM_GAMESCOPE_HDR_SUPPORTED`, `STEAM_GAMESCOPE_NIS_SUPPORTED`,
`STEAM_GAMESCOPE_FANCY_SCALING_SUPPORT`, `STEAM_GAMESCOPE_COLOR_MANAGED`,
`STEAM_GAMESCOPE_VIRTUAL_WHITE`, **`STEAM_GAMESCOPE_DYNAMIC_FPSLIMITER`**,
`STEAM_MULTIPLE_XWAYLANDS`, `STEAM_ENABLE_VOLUME_HANDLER`,
`STEAM_DISABLE_AUDIO_DEVICE_SWITCHING`, `STEAM_ALLOW_DRIVE_UNMOUNT/_ADOPT`,
`STEAMOS_STEAM_REBOOT/SHUTDOWN_SENTINEL`, `SRT_URLOPEN_PREFER_STEAM`,
`QT_IM_MODULE=steam`, `GTK_IM_MODULE=Steam`, `GAMESCOPE_FALLBACK_APPID`.

**A probar**: que el QAM muestre VRR/tearing/HDR/NIS y que el **frame limiter
dinámico** empiece a funcionar (puede resolver el bug conocido del frame limiter).

---

## 2. Importar el entorno Wayland a systemd --user (arregla el daemon de KScreen)

**Ficheros**: `packages/shared/pocknix-desktop/pocknix-desktop-env` (nuevo) +
`pocknix-desktop-env.desktop` (nuevo, autostart) + `PKGBUILD` (pkgrel 21).

`dbus-update-activation-environment --systemd` con `WAYLAND_DISPLAY`, `DISPLAY`,
`XAUTHORITY`, `KDE_FULL_SESSION`… Antes, los servicios activados por D-Bus
(`plasma-kscreen`, módulos kded, portales) arrancaban sin `WAYLAND_DISPLAY` y
fallaban ("Failed to create wl_display") — el core dump de `plasma-kscreen.service`
que vimos al cambiar de sesión. Portado de `armada/desktop-bootstrap`.

**A probar**: `systemctl --user show-environment | grep WAYLAND_DISPLAY` en la
sesión Plasma, y que `plasma-kscreen.service` ya no crashee.

---

## 3. Inyección de libs x86 + reparación del mando atascado

**Ficheros**: `packages/shared/pocknix-steam/pocknix-proton-wrapper` (+ copia) +
`proton-inject/x86_64-linux-gnu/` (4 `.so` x86 traídos de ArmadaOS) + `PKGBUILD`.

Portado de `armada/armada-game-launch`:

- **`inject_x86_protocol_libs()`**: copia `libwayland-client.so.0` y
  `libxkbcommon.so.0` (x86_64) al `files/lib/x86_64-linux-gnu` del Proton cuando
  es x86 (pressure-vessel no las trae → **mando muerto**). Se salta el Proton
  arm64ec (`files/bin-arm64`).
- **`repair_wedged_controller()`**: si el prefijo tiene secciones `VID_28DE` sin
  promover a `WINEXINPUT`, las borra de `system.reg` (backup
  `system.reg.pocknix-bak`) para que el pad se re-registre.
- **`DXVK_HUD=none`** por defecto (Proton-CachyOS muestra el HUD del compilador de
  shaders si no está puesto; se respeta un HUD explícito del usuario).

**A probar**: mando dentro de juegos Windows x86 bajo Proton; y que un prefijo con
el mando "muerto" se recupere.

---

## 4. `ENABLE_GAMESCOPE_WSI=1`

**Fichero**: `packages/shared/pocknix-steam/pocknix-steam`. Habilita la capa **WSI de
gamescope** (el juego presenta directamente en el compositor). ArmadaOS lo exporta en su
sesión (`gamescope-session-plus`); nosotros no lo teníamos.

---

## HDR — mecanismo localizado (pendiente de decidir)

`ARMADA_HDR_NITS=650` (perfil del Odin 3) se consume en `gamescope-session-plus` como
**flags de gamescope**:

- `--hdr-itm-target-nits 650` (+ `GAMESCOPE_INTERNAL_DEVICE_ID`,
  `GAMESCOPE_EXPOSE_CLIENT_SAMPLEABLE_FORMATS=1`)
- si `ENABLE_GAMESCOPE_HDR=1` y `ENABLE_GAMESCOPE_WSI=1`: `--hdr-enabled --hdr-itm-enable`
  y `ENABLE_HDR_WSI=1`, `DXVK_HDR=1`, `GAMESCOPE_WAYLAND_DISPLAY=gamescope-0`.

En ArmadaOS está **opt-in** (por defecto `highDynamicRange: false` en KWin). El mecanismo
está documentado y los scripts de referencia guardados; **falta decidir si lo activamos y
probarlo** en la Odin (el gamescope de Pocknix es ROCKNIX `6644cc9`, no el Terra de ArmadaOS,
así que hay que comprobar que soporta los flags — ArmadaOS los guarda con `gamescope --help`).

---

## 5. Botones Steam/Quick Access del Odin 3 (mapeo del mando)

**Problema**: en Pocknix los botones Steam (Guide) y Quick Access (QAM) no quedan
en lados opuestos como en ArmadaOS.

**Causa**: la config AYN de ROCKNIX (`ayn_mcu.yaml`) mapea `BTN_BACK` (botón
Quick Access físico) a la **tecla `KeyF1`** (la UI propia de ROCKNIX), así que
Steam no recibe el botón QuickAccess. Pocknix **ya aplicaba el delta** en SM8250
(`rp5-gamepad.yaml`) y SM8550 (`sm8550-gamepad.yaml`): `BTN_BACK -> QuickAccess`.
Faltaba en el Odin 3 (SM8750).

**Fix** (`pocknix-os`):
- `devices/sm8750/inputplumber/capability_maps/ayn_mcu.yaml` (de ArmadaOS):
  `BTN_MODE -> Guide`, **`BTN_BACK -> QuickAccess`**, `KEY_F24 -> KeyHome`,
  paddles -> `LeftPaddle1`/`RightPaddle1`.
- `devices/sm8750/inputplumber/devices/01-ayn-controller.yaml`: target **`deck`**
  + `keyboard` (pad Steam-native).
- `build-image.sh`: `install_inputplumber_overrides()` aplica el override
  **después** de `install_local_packages` para que gane.
- Copias de referencia en `config/inputplumber/`.

---

## 6. Suspensión real (s2idle) + hook de pantalla

**Problema**: el botón de encendido solo "parpadeaba" la pantalla (un stub
`pocknix-fake-suspend.sh` interceptaba `systemd-suspend.service` y salía al
instante).

**Fix** (portado del modelo de ArmadaOS, que en el Odin 3 usa `s2idle` real):

- **`devices/sm8750/profile.conf`**: `mem_sleep_default=s2idle` en el cmdline
  (específico de sm8750).
- **`overlay/usr/local/bin/pocknix-powerd`**: `screen_is_on()` mira el **DPMS del
  conector DRM interno** (DSI/eDP/LVDS), no solo `bl_power` (que en la Odin 3 se
  queda en 4 aunque el panel esté encendido).
- **`packages/shared/pocknix-bsp-common/display-sleep-post`** (nuevo, instalado
  como `sleep.d/post/004-display`): al resumir, pide a gamescope despertar la
  pantalla (`gamescopectl drm_sleep_internal_screen 0`) y desbloquea el backlight
  (`echo 0 > .../bl_power`).

Detalle completo, diagnóstico y verificación en **`SUSPEND-ISSUE.md`**.

---

## Lo que NO se portó (y por qué)

- **`controller-type`**: ya lo cubre `pocknix-gamepad-target` (deck/xb360/ds5…).
- **Perfiles FEX**: ya tenemos `fex-profiles.json` (default/fast/compatible).
- **`scx_loader`**: usamos `scx_lavd` directamente (`pocknix-lavd-mode`).
- **`fake-suspend` como sustituto**: **no se usa**. Igual que ArmadaOS en el
  Odin 3, Pocknix usa **s2idle real**; el fake-suspend de ArmadaOS es solo su
  reserva. Lo que sí se portó es el espíritu de su `display_on`: el hook
  `004-display` que reactiva la pantalla al resumir. Detalle completo en
  `SUSPEND-ISSUE.md`. (El fake-suspend + `suspend-dispatch` como red de
  seguridad queda como opción futura, hoy innecesaria.)
- **Btrfs nodatacow**: no aplica (Pocknix usa ext4).
- **`armada-powerd` completo**: Pocknix ya tiene `pocknix-fancontrol`,
  `pocknix-lavd-mode`, `pocknix-powerd` y el plugin Decky. El D-Bus unificado de
  ArmadaOS sería un rediseño; pendiente valorar.
- **MTP / HDR / UCM audio**: pendientes (MTP necesita `umtp-responder`; HDR
  necesita ver cómo se consume `HDR_NITS`; el UCM de audio del Odin 3 hay que
  comprobar si ALARM ya lo trae).

---

## Verificación pendiente (cuando la Odin vuelva a Pocknix)

1. `bash -n` / `py_compile` ya OK en los ficheros tocados.
2. Compilar la imagen y arrancar: comprobar los 3 puntos de "A probar".
3. Si algo falla, el código está aislado y se puede revertir por fichero.
