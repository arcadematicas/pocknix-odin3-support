# ✅ RESUELTO: KScreen no enumeraba el panel (escritorio Plasma)

**Resuelto:** 11/09/2026 · **Causa:** faltaba el paquete **`kscreen`** (solo estaban
`libkscreen` + `kscreenlocker`). **Fix:** `pacman -S kscreen` (+ `kimageformats`).

---

## Resumen

En el AYN Odin 3 con pocknix-os, la **sesión de juego funcionaba** pero el
**escritorio (Plasma Mobile)** no mostraba el panel en Ajustes:

- System Settings → Pantalla **no mostraba monitor** (ni resolución ni rotación).
- La rotación rápida no estaba disponible.
- Error *"could not find plugin usr"*.

A nivel **DRM/kernel el panel siempre estuvo bien**: conector `DSI-1`
`connected`/`enabled`, 1080x1920 (2 modos: 120 y 60 Hz), driver
`panel-chipone-icna35xx` enlazado y la propiedad del conector
**`panel orientation` = 3 (Right Side Up)** — que viene del `rotation = <90>` del
DTS. KWin también lo veía (`org.kde.KWin.activeOutputName` → `DSI-1`).

El problema era **puramente de userspace**: faltaba el módulo de Ajustes que
enumera el panel.

---

## Causa raíz (confirmada)

El paquete **`kscreen`** **no estaba instalado**. Ese paquete es quien aporta:

| Fichero | Qué es |
|---|---|
| `.../plasma/kcms/systemsettings/kcm_kscreen.so` | **Módulo Ajustes → Pantalla** |
| `.../kf6/kded/kscreen.so` | Módulo KDED de KScreen |
| `/usr/lib/kscreen_osd_service` | OSD de cambios de pantalla |
| `org.kde.kscreen.osdService.service` | D-Bus del OSD |

`libkscreen` (sí instalado) aporta `kscreen-doctor`, los plugins de backend
(`KSC_KWayland.so`, …) y el service file `org.kde.kscreen.service` → pero **sin
`kscreen` no hay KCM**, así que Ajustes → Pantalla no existía / no encontraba el
plugin. Por eso `kscreen-doctor` funcionaba suelto (y el script
`pocknix-desktop-rotate` leía el output) mientras Ajustes no mostraba nada.

Evidencia:

```bash
# Antes: solo estos dos
$ pacman -Q | grep -iE 'kscreen'
kscreenlocker 6.7.4-1
libkscreen 6.7.4-1

# Log de pacman: el 24/08 se instalaron libkscreen + kscreenlocker, NUNCA kscreen
$ grep -iE 'kscreen' /var/log/pacman.log
[2026-08-24T22:51:15] [ALPM] installed libkscreen (6.7.4-1)
[2026-08-24T22:51:15] [ALPM] installed kscreenlocker (6.7.4-1)

# Antes: no existía el KCM
$ find /usr -iname '*kcm_kscreen*'      # (vacío)
```

**Por qué faltaba:** la Odin no tiene instalado el meta-paquete
`pocknix-desktop-full` (que declara `depends=('...' 'kscreen' ...)`, ver
`packages/shared/pocknix-desktop-full/PKGBUILD`). El escritorio se montó a mano y
ese componente se quedó fuera. La **imagen oficial sí lo incluye** (el
`build-image.sh` instala `pocknix-desktop-full`), así que una imagen limpia no
tiene este problema.

---

## Fix aplicado

```bash
sudo pacman -S --noconfirm kscreen      # instala kscreen 6.7.4-1 + kimageformats 6.29.0-1
```

Es persistente (paquete), sobrevive reinicios.

### Verificación (con la sesión Plasma activa)

```bash
$ pacman -Q kscreen kimageformats
kscreen 6.7.4-1
kimageformats 6.29.0-1

$ ls /usr/lib/qt6/plugins/plasma/kcms/systemsettings/kcm_kscreen.so
/usr/lib/qt6/plugins/plasma/kcms/systemsettings/kcm_kscreen.so

# System Settings carga el módulo (journal):
#   systemsettings[...]: qrc:/kcm/kcm_kscreen/RotationButton.qml:...

$ export XDG_RUNTIME_DIR=/run/user/1001 WAYLAND_DISPLAY=wayland-0
$ kscreen-doctor -o | sed 's/\x1b\[[0-9;]*m//g'
Output: 1 DSI-1 9ab0c60a-769f-4cd7-9160-4e6b127c99dc
        enabled
        connected
        Panel
        Modes:  1:1080x1920@120.00!  2:1080x1920@60.00*
        Geometry: 0,0 768x432
        Scale: 2.5
        Rotation: 8            # = Rotate270 (libkscreen: Rotate270 = 8)

# El daemon D-Bus ahora sí arranca y elige el backend KWayland:
$ busctl --user call org.kde.KScreen / org.kde.KScreen backend
s "kwayland"
```

Antes del fix, `org.kde.KScreen` no tenía KCM que lo activara y su `backend`
quedaba vacío.

---

## Notas / lo que NO era

- **No era el kernel/DRM/DTS**: el panel se detectaba perfectamente, incluida la
  propiedad `panel orientation` (Right Side Up, de `rotation = <90>` en el DTS).
  El driver `panel-chipone-icna35xx` expone `get_orientation` y el bridge la
  propaga al conector (`drm_panel_bridge_set_orientation`).
- **No era el PDR** ni nada del stack de carga (eso fue otro tema, ver
  `BATTERY-ISSUE.md`).
- La rotación del escritorio la aplica el script propio
  `/usr/bin/pocknix-desktop-rotate` (`kscreen-doctor output.DSI-1.rotation.right
  scale 2.5`) más el estado persistido en
  `~/.config/kwinoutputconfig.json` (`transform: Rotated270`, `scale 2.5`).
  En esta Odin el autostart `/etc/xdg/autostart/pocknix-desktop-rotate.desktop`
  está renombrado a `.disabled`; no es necesario porque KWin conserva el
  transform.
- El antiguo workaround `chattr +i` sobre `kwinoutputconfig.json` **ya no está
  aplicado** (`lsattr` sin flags).
- El error histórico *"could not find plugin usr"* encaja con el KCM ausente.

## Otros componentes del escritorio (instalados 11/09/2026)

Esta Odin no tenía el meta-paquete `pocknix-desktop-full`, así que además de
`kscreen` faltaban otros `depends`. Ya se instalaron (11/09/2026):

```bash
sudo pacman -S --noconfirm plasma-settings bluedevil waydroid koko kclock kweather unrar
# 28 paquetes nuevos (incl. deps: opencv, lxc, libgbinder, qt6-charts, kweathercore, ...)
```

Con esto el conjunto de dependencias de `pocknix-desktop-full` está completo.

Notas:
- **waydroid**: el paquete está instalado, pero para usarlo falta `waydroid init`
  (descarga la imagen de Android) y montar binderfs. El kernel **sí** trae binder
  compilado dentro (`CONFIG_ANDROID_BINDER_IPC=y`, `CONFIG_ANDROID_BINDERFS=y`,
  `CONFIG_ANDROID_BINDER_DEVICES="binder,hwbinder,vndbinder"`), no como módulo.
- **bluedevil**: requiere `bluetooth.service` activo para funcionar.

## Referencia de diagnóstico rápida

```bash
# ¿Qué ve el kernel?
cat /sys/class/drm/card0-DSI-1/status          # connected
cat /sys/class/drm/card0-DSI-1/modes           # 1080x1920 (x2)
modetest -c | grep -A2 DSI-1                   # props: "panel orientation" value 3

# ¿Qué ve userspace?
export XDG_RUNTIME_DIR=/run/user/1001 WAYLAND_DISPLAY=wayland-0
kscreen-doctor -o
busctl --user call org.kde.KScreen / org.kde.KScreen backend

# ¿Está el KCM?
ls /usr/lib/qt6/plugins/plasma/kcms/systemsettings/kcm_kscreen.so
```
