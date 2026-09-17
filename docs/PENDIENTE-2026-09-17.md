# Pendiente — 17/09/2026 (noche): DeckStation lista para pruebas

Estado al cerrar la sesión de noche. **La Odin está lista para testear emuladores.**
Pantalla arreglada (DPMS + powerdevilrc), RetroArch nuevo, 27 emuladores standalone
descargados y activados en ES-DE, ROMs de ejemplo copiadas.

---

## ✅ HECHO ESTA NOCHE

### 1. Pantalla que se apagaba — ARREGLADA (2 fixes)
- **Fix 1 (DPMS atascado)**: kwin tenía `DPMS=off` aunque el panel estuviera iluminado
  (bug KWin Wayland 514471/519218). Fix: `kscreen-doctor --dpms on`
  (con `XDG_RUNTIME_DIR=/run/user/1001 WAYLAND_DISPLAY=wayland-0`).
  Autostart añadido: `~/.config/autostart/deckstation-dpms-fix.desktop` (fuerza DPMS on al login).
- **Fix 2 (seguía apagándose por inactividad)**: el `~/.config/powerdevilrc` usaba el formato
  **plano** `[AC]` pero Plasma 6 usa **anidado** `[AC][Display]` (ver `/etc/xdg/powerdevilrc`).
  powerdevil ignoraba las claves → usaba el default (apagado por inactividad).
  Reescrito con formato anidado: `[AC][Display]` y `[Battery][Display]` con
  `DisplaySleep=0, DimDisplay=0, IdleTime=0, TurnOffDisplay=false` + `[AC][SuspendAndShutdown]`
  `SuspendSession=0`. Verificado con `kreadconfig6` (lee 0/false en todos).

### 2. RetroArch — REEMPLAZADO por nightly oficial (buildbot)
- El AppImage de RetroArch estaba **roto** (AppRun mal generado, `.AppImage.ROTO`).
- **Fix**: descargado el nightly oficial ARM de buildbot
  (`https://buildbot.libretro.com/nightly/linux/aarch64/2026-09-13_RetroArch.7z`),
  binario único `Apps/RetroArch/retroarch` (1.22.2, GCC, 18 MB) + `libxss` instalado.
- **211 cores conservados** en `RetroArch-Linux-aarch64.AppImage.home/.config/retroarch/cores/`
  (incl. Suyu + GooseStation).
- `lanzar.sh` actualizado (busca AppImage → app/AppRun → app/usr/bin → ./retroarch).
- **Verificado**: GUI viva 8s vía `lanzar.sh` (el error de ALSA seq es solo un warning).

### 3. ES-DE — los 27 emuladores standalone activados
- **`es_find_rules.xml`** (commit `296931b` en stshunz): todos los standalone pasan por
  `./Apps/<Nombre>/lanzar.sh` (antes nombres de AppImage fijos que cambian con PkgForge).
  Case corregido (bigpemu/BigPEmu, Scummvm/ScummVM, ymir/Ymir). Vita3K con launcher propio
  (es binario, no AppImage). Reglas nuevas: ClownMDEmu, PCSX-Redux, DOSBox-X, SkyEmu.
- **`es_systems.xml`** (commit `c39d880` en stshunz): rutas hardcodeadas x86_64 → `%EMULATOR_%`
  (BigPEmu ×2, Azahar, Vita3K, ScummVM, Eden, Supermodel) + comandos nuevos
  (PCSX-Redux en psx, ClownMDEmu en segacd, ZSNES en snes).
- **Resultado: 23/23 rutas resuelven + 27/27 emuladores tienen comando en ES-DE.**
- `lanzar.sh` copiado a las 27 carpetas de Apps/ (el setup no lo hacía).

### 4. ROMs de ejemplo copiadas
- Desde `/run/media/fransis/ROMS16TB/DeckStation/ROMs/` → `/opt/deckstation/ROMs/` (rsync).
- ~30 sistemas relevantes (psx, switch, snes, gb/gbc/gba, n3ds, psvita, segacd, dos, scummvm,
  atarijaguar, n64, dreamcast, nds, wiiu, gc, wii, saturn, xbox, msx, flash, model3, amiga,
  arcade, mame, megadrive, nes, genesis, neogeo...), ~8,4 GB.

### 5. Emuladores standalone descargados (mañana/tarde)
- 25 AppImages aarch64 de PkgForge + Eden (gitea) + Vita3K (oficial) → `Apps/` (29 carpetas, 8,6 GB).
- `git.txt` del Updater corregido (commit `3011a92` stshunz / `e1b756b` centro).

---

## 🎮 PARA PROBAR ESTA NOCHE

1. Lanzar `deckstation` → ES-DE debería listar los sistemas con ROMs.
2. Probar emuladores standalone (DuckStation→psx, Eden→switch, Azahar→n3ds, etc.).
3. Probar RetroArch (cores: Suyu Switch, GooseStation PS1, etc.).
4. Si algo no arranca: mirar logs de ES-DE (`~/.local/share/ES-DE/logs/` o el `.home`).

---

## 🔑 Notas de operación (aprendidas hoy)

### Desbloquear `sudo` en la Odin
Si `sudo` rechaza la contraseña (`pocknix`) tras intentos fallidos, es `pam_faillock`.
El fichero `/var/run/faillock/deck` es **propiedad de `deck`** (modo 0660), se limpia sin root:
```bash
: > /var/run/faillock/deck
```
⚠️ **No usar `sudo -S` con heredocs** — el heredoc se come la contraseña. Usar `echo pass | sudo -S cmd`.

### Pantalla de la Odin
```bash
export XDG_RUNTIME_DIR=/run/user/1001 WAYLAND_DISPLAY=wayland-0
kscreen-doctor --dpms show      # si dice "off", forzar:
kscreen-doctor --dpms on
kscreen-doctor output.DSI-1.brightness.100   # brillo (kwin lo controla, no sysfs)
```

### powerdevilrc: formato ANIDADO (Plasma 6)
```ini
[AC][Display]
DisplaySleep=0
DimDisplay=0
IdleTime=0
TurnOffDisplay=false
[AC][SuspendAndShutdown]
SuspendSession=0
```
El formato plano `[AC]` se IGNORA. Referencia: `/etc/xdg/powerdevilrc`.

### RetroArch
- Binario: `Apps/RetroArch/retroarch` (nightly buildbot 2026-09-13). Cores en el `.home`.
- El AppImage de buildbot trae el AppRun roto (busca `/usr/bin/retroarch` absoluto) → usar el binario directo.
- `libxss` requerido (instalado).

---

## 📦 Estado de los repos

| Repo | Últimos commits (17/09 noche) |
|---|---|
| `stshunz/deckstation-arm` | `3011a92` (git.txt aarch64) · `296931b` (es_find_rules) · `c39d880` (es_systems 27 emus) |
| `arcadematicas/pocknix-odin3-support` (centro) | `e1b756b` (git.txt) + este documento |
| `arcadematicas/pocknix-os` (`odin3-sm8750`) | `ee47098` (pacman.conf) |

## ⚠️ GAPS DETECTADOS (pendientes)

1. **El centro NO tiene `configs/es-de/`** (los ES-DE configs solo viven en stshunz). El
   PKGBUILD referencia `deckstation-setup.sh`, `deckstation-launcher.sh`, `deckstation-update.sh`,
   `setup_arm64_apps.py` que **faltan** en `packages/deckstation-arm/scripts/` (solo hay `lanzar.sh`).
   → Sincronizar esas piezas al centro.
2. **`setup_arm64_apps.py` sin conectar** al flujo (nadie lo llama) y `deckstation-setup.sh`
   roto (descargaba el APK de Android de RetroArch). → Arreglar para que el setup sea reproducible.
3. **Licencia GooseStation** (CC-BY-NC-ND + no distribuir): decidir si entra en la imagen.
4. **Ryujinx** (gitea por confirmar) y **PCSX2/PPPSPP/RPCS3/Citron** (sin ARM) siguen sin build.
5. **Powerdevilrc + autostart DPMS**: llevarlos al proyecto (que las imágenes nuevas los traigan).