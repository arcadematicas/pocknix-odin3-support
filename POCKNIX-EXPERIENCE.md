# Experiencia Pocknix en la AYN Odin 3

Estado de la experiencia Pocknix completa en la Odin 3 (SM8750), para el soporte.

Fecha: 06/09/2026
Kernel: 7.2.0 (funciona en Odin 3)

## Resumen

La Odin 3 ya tiene la mayoría de la experiencia Pocknix funcionando. Se instalaron
los paquetes oficiales de Pocknix (base, tools, desktop, snapshots, etc.) y la
tienda de aplicaciones (flatpak + discover + Flathub). Steam y Decky ya funcionan
(adaptados a la Odin 3).

## Paquetes de Pocknix instalados

| Paquete | Versión | Estado |
|---|---|---|
| pocknix-base | 0.2.0-3 | ✅ Instalado (compilado en host) |
| pocknix-base-lock | 20260811-1 | ✅ Instalado (compilado en host) |
| pocknix-core | 0.1.0-1 | ✅ Instalado (metapaquete) |
| pocknix-desktop | 0.1.0-20 | ✅ Instalado |
| pocknix-sdcard-automount | 0.1.0-6 | ✅ Instalado |
| pocknix-snapshots | 0.1.0-2 | ✅ Instalado |
| pocknix-steamos-shim | 0.1.0-6 | ✅ Instalado |
| pocknix-tools | 0.1.0-12 | ✅ Instalado |

## Tienda de aplicaciones

- `flatpak` 1.18.2-1 ✅
- `discover` 6.7.4-1 ✅
- Flathub configurado como remote (system) ✅

**Nota:** El repo `pocknix-base` (https://pocknix.shuuri.net/repo/base) está ROTO
— da 404 para muchos paquetes (snapshot congelado con paquetes obsoletos). Para
instalar paquetes hay que forzar `extra/<paquete>`.

## Aplicaciones KDE instaladas

- konsole, dolphin, kate, kcalc, ark, gwenview, okular ✅

## Emuladores instalados

- dolphin 26.08.0-5 ✅
- retroarch 1.22.2-5 ✅

## Decky Loader

- **YA FUNCIONA** (instalado manualmente en `/home/deck/homebrew/`)
- Servicio `pocknix-decky-loader` activo y habilitado
- Plugin `PocknixControl` instalado
- **No se instaló el paquete `pocknix-decky`** (ya funciona, no necesita paquete)

## Steam

- **YA FUNCIONA** (adaptado a la Odin 3)
- Script `pocknix-steam` modificado (copia de trabajo en
  `config/steamos-manager/pocknix-steam.lanzador-actualizado`):
  **usa `-gamepadui -steamos3 -steampal -steamdeck`** (NO `-deckard`).
  - Histórico: se usaba `-deckard` porque `-gamepadui` daba problemas, pero
    con la config actual (agosto-sept 2026) `-gamepadui -steamos3 -steampal`
    es lo que hace que el QAM muestre el selector de perfil de rendimiento.
    Se cambió el 08/09/2026 y se validó que el selector funciona.
  - Backup del lanzador con `-deckard`: `/usr/bin/pocknix-steam.bak-deckard`
- **SteamOS Manager (nuevo)**: shim D-Bus `com.steampowered.SteamOSManager1`
  en bus de sesión (`/usr/local/bin/pocknix-steamos-manager` + unit de usuario
  + activación D-Bus + sudoers NOPASSWD para `pocknix-power-profile`).
  Expone `Manager2`, `PerformanceProfile1` (low-power/balanced/performance),
  `GpuPerformanceLevel1` y `SessionManagement1` → el QAM de Steam controla el
  perfil de rendimiento real de Pocknix. Código en `config/steamos-manager/`.
- **No se instaló el paquete `pocknix-steam` oficial** (para RP6; la Odin 3
  usa su versión adaptada en `config/steamos-manager/pocknix-steam.*`)

## Lo que funciona

- ✅ Escritorio Plasma Mobile
- ✅ Tienda de aplicaciones (discover + flatpak + Flathub)
- ✅ Steam (modo Deck UI, adaptado)
- ✅ Decky Loader + plugin Pocknix Control
- ✅ MangoHud (con symlink al config de Steam)
- ✅ Gamepad (rsinput driver backport)
- ✅ WiFi, audio, Bluetooth
- ✅ Snapshots btrfs (hook automático antes de cada transacción pacman)
- ✅ Automontaje de microSD
- ✅ Emuladores (dolphin, retroarch)
- ✅ Apps KDE (konsole, dolphin, kate, etc.)

## Lo que NO funciona / pendiente

### Batería (siempre marca 100%)
- **Problema:** El driver `qcom_battmgr.c` no usa `power_supply_get_battery_info()`.
  Depende 100% del firmware GLINK, que reporta capacity=100 siempre
  (model_name=Debug_Board) y charge_full/energy_full = "No data available".
- **Solución:** (1) Añadir nodo `simple-battery` en DTS + (2) modificar
  `qcom_battmgr.c` para fallback con `power_supply_get_battery_info()`.
- **Estado:** PENDIENTE (cambio de kernel, requiere recompilar y probar).

### pocknix-bsp-common (NO instalado)
- **Razón:** Específico del RP6. Instala `pocknix-gpt-abl`/`pocknix-update-abl`
  (actualización de bootloader ABL, PELIGROSO en Odin 3).
- La Odin 3 ya tiene `pocknix-fancontrol`, `pocknix-fan-mode`,
  `pocknix-gamepad-target`, `pocknix-lavd-mode` idénticos a los oficiales.
- **Estado:** Requiere adaptación para la Odin 3 (omitir parte ABL).

### pocknix-lock-migrate (NO instalado)
- **Razón:** Para migrar de rolling a locked. La Odin 3 es un dispositivo rolling.
- **Estado:** No aplica a la Odin 3.

### pocknix-decky (NO instalado como paquete)
- **Razón:** Decky ya funciona manualmente. El paquete instalaría bajo FEX (x86),
  no aporta nada nuevo.
- **Estado:** Decky funciona, no necesita paquete.

### pocknix-steam (NO instalado como paquete)
- **Razón:** El paquete oficial es para RP6. La Odin 3 usa su versión adaptada
  (en `config/steamos-manager/pocknix-steam.lanzador-actualizado`), que desde
  el 08/09/2026 lanza con `-gamepadui -steamos3 -steampal -steamdeck`.
- **Estado:** Steam funciona con el script adaptado + shim SteamOS Manager.

### pocknix-emulation-full (NO instalado)
- **Razón:** Arrastraría muchos emuladores (ES-DE, RPCS3, Cemu, Vita3K, etc.)
  que podrían no funcionar en la Odin 3.
- Se instalaron los emuladores principales (dolphin, retroarch).
- **Estado:** Opcional, requiere evaluación por emulador.

### pocknix-gamepad-calibration (NO instalado)
- **Razón:** No tiene .pkg.tar.zst, requiere compilar. Opcional.
- **Estado:** Pendiente.

## Problemas resueltos

- **Pantalla negra en Plasma Mobile (Fix In-Place):** Se diagnosticó que `kwin_wayland` intentaba iniciar el backend Wayland anidado en lugar de tomar control del panel por hardware (DRM/KMS), debido a `WAYLAND_DISPLAY=wayland-0` presente en el entorno inyectado por `/home/deck/.config/environment.d/wayland.conf`. Se eliminó dicha variable del archivo de configuración y se creó un drop-in de systemd (`/home/deck/.config/systemd/user/plasma-kwin_wayland.service.d/drm.conf`) forzando `--drm`. KWin tomó correctamente el conector DSI-1 (`/dev/dri/card0`) y el escritorio Plasma Mobile volvió a la vida.

## Problemas menores

- Hook mkinitcpio falla: el preset apunta a kernel 7.1.8 pero el instalado es 7.2.0.
  No afecta a la instalación de paquetes.
- Error menor en journal: crash de una librería (no crítico).
- Mensaje de kernel: "Handover signaled, but it already happened" (remoteproc, no crítico).

## Avances recientes (06/09/2026)

- **Batería (Parche v4):** Verificado el parche v4 en el kernel (`qcom_battmgr_estimate_percent`). Lectura real de la batería funcionando correctamente (ej. 16%, ~840mA, 3.68V).
- **OLED Care / Pixel Refresher:** Creado el binario nativo `/usr/local/bin/oled-refresher` (C + SDL2). Ajustado el backend para que detecte el modo juego (Steam/gamescope) y lance el refresco como usuario `deck` mediante X11 (`DISPLAY=:0`, `SDL_VIDEODRIVER=x11`), solucionando los problemas de geometría en Wayland. **AUTOMATIZADO (06/09):** servicio systemd `oled-refresher.service` + timer `oled-refresher.timer` (cada 4h, `OnBootSec=2h`, `Persistent=true`). El script `/usr/local/bin/oled-refresher-auto` solo lanza el refresher si Steam está activo (modo juego) y no hay otro refresher corriendo.
- **Botón de Encendido (Pantalla Off/On):** Implementado un daemon dedicado (`power-button-daemon.py`) que escucha `/dev/input/event0` (`KEY_POWER`) y alterna `bl_power` (`4` apagado, `0` encendido) en el sysfs del panel (`/sys/class/backlight/ae94000.dsi.0/`). Powerdevil configurado a `DoNothing`. Funciona perfectamente en Plasma y modo juego.
- **Volumen en Modo Juego:** Implementado un daemon (`volume-button-daemon.py`) para capturar las teclas de volumen físicas y enrutarlas a PipeWire mediante `wpctl` cuando Steam está activo.
- **Power profiles (pocknix-fan-mode):** Implementado `pocknix-fan-mode` (quiet|moderate|performance) — escribe en `/var/lib/pocknix/fan-mode`, `pocknix-fancontrol` lo relee cada tick (~3s). Curvas = ROCKNIX ("performance" = su "aggressive"). Persiste entre reinicios.
- **FEX fix (FEX_EARLY_LOG_DISABLE=1):** Aplicado para reducir los crashes de `steamwebhelper` (bug conocido de CEF + FEX). Variable en `/etc/environment.d/fex-fix.conf` + inyectada en `pocknix-steam` (env de gamescope). Fix upstream parcial de FEX 2603, recomendado por Bazzite/ArmadaOS.
- **Decky v3.2.8 estable:** Bundle del OS cambiado a v3.2.8 + homebrew re-sembrado + `branch: 0` en `loader.json`. El sync ya no lo revierte.
- **Estado pendiente:** Inestabilidad del `steamwebhelper` tras la actualización de Steam (19:54), pendiente de reiniciar Steam / actualizar Decky Loader.

