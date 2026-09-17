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

| Repo | Últimos commits |
|---|---|
| `stshunz/deckstation-arm` | `3011a92` · `296931b` · `c39d880` · **`4f43efe`** (Suyu+GooseStation+glcore) · **`006b927`** (XMB/FlatUX) · **`6f95157`** (despliegue de configs) · **`abec664`** (BIOS) |
| `arcadematicas/pocknix-odin3-support` (centro) | `e1b756b` · **`589b256`** (oled-care) · **`0e97795`** (PKGBUILD) · **`3604ab3`** (bios) |
| `arcadematicas/pocknix-os` (`odin3-sm8750`) | `ee47098` (pacman.conf) + árbol sincronizado |
| **PR #81** (`shuuri-labs/pocknix-os`) | **REBASEADO y MERGEABLE** (17/09 noche) |

## ✅ SESIÓN DE MADRUGADA (17→18/09) — lo hecho después

### 1. ES-DE: cores de Suyu y GooseStation (regresión corregida)
- El commit `c39d880` borró por error el `<command>` de **Suyu** → restaurado como primera
  opción de `switch`. Añadido **GooseStation** como primera opción de `psx` (el core estaba
  copiado pero ES-DE no lo conocía).
- **Suyu arranca ya**: la causa del crash era que las claves van en
  `<system>/suyu/keys/`, no en la raíz de `system/`. Sin ellas el cifrador AES queda sin
  inicializar y el core revienta en `aes_util.cpp`. Verificado: "game loaded and running".

### 2. RetroArch
- `video_driver` vulkan → **glcore** (el Vulkan de Turnip en Adreno 8xx relentiza; problema
  de driver, no de RetroArch).
- Menú **XMB** + tema **FlatUX** con los 9 temas de iconos instalados (assets de
  `libretro/retroarch-assets`, 82 MB — **no van en git**).

### 3. OLED care — daemon arreglado
- `oled-care-daemon.py`: guarda de modo juego (no refresca si corre ES-DE/RetroArch/Steam/
  gamescope), `IDLE_SECONDS` 180 → 600, y re-escaneo de `/dev/input/event*` cada 60 s.
- Antes lanzaba el refresher **~221 veces al día** (cada 3 min) y saltaba en mitad de una
  partida. Desplegado en la Odin y en el centro (commit `589b256`).

### 4. Configuración base reproducible
- **`configs/deploy-manifest.txt`** + **`scripts/deckstation-configs.sh`**: despliegan la
  config en cada emulador. Lo llaman el setup y el launcher (no-op si ya está todo).
- Ya no hace falta el payload de MediaFire del Updater (era x86_64).
- PKGBUILD: `chmod -R a+rX` en `configs/` (2 ficheros quedaban en 600 e ilegibles para deck).

### 5. BIOS — solución externa
- **`bios/`** con subcarpetas por sistema + **`bios/README.md`** (qué ficheros necesita cada
  uno) + **`bios/deploy-bios.txt`** + **`scripts/deckstation-bios.sh`**. Se ejecuta también
  en cada arranque. Los ficheros del usuario no se versionan.

## ⚠️ GAPS DETECTADOS (pendientes)

1. **Core de Suyu en la imagen**: el paquete `suyu-libretro` existe en el centro pero **no
   está en `devices/sm8750/packages.list`** ni instalado. Hoy el `.so` es de un build manual.
   → Añadirlo a la imagen y copiarlo a la carpeta portable de cores.
2. **Core de GooseStation**: sin paquete ni entrada en `updater/git.txt`. Licencia
   CC-BY-NC-ND + no redistribuir → **servidor externo + descarga automatizada** (decisión de
   Fransis), pendiente de montar.
3. **Assets XMB de RetroArch** (82 MB): no se descargan. → Añadir a `deckstation-setup.sh`.
4. **`setup_arm64_apps.py` sin conectar** al flujo y `deckstation-setup.sh` todavía con el
   `setup_retroarch` viejo (descargaba el APK de Android). Hoy los emuladores los instala el
   **Updater** desde `git.txt`. → Unificar.
5. **Centro vs stshunz**: el centro (`packages/deckstation-arm/`) ya tiene PKGBUILD +
   `deckstation-configs.sh` + `deckstation-bios.sh` + `bios/`. Faltan en él
   `configs/es-de/` y los scripts `deckstation-setup.sh`/`deckstation-launcher.sh`/
   `deckstation-update.sh`/`setup_arm64_apps.py` (el sync es aditivo, así que no rompe).
6. **Vita3K**: no es AppImage (`.7z` extraído) → no tiene `.home` portable ni recibe configs.
7. **PCSX2 / PPSSPP / RPCS3 / Citron**: sin build ARM (sus entradas se omiten sin error).
8. **Ryujinx** (gitea por confirmar) sin build.
9. **Powerdevilrc + autostart DPMS**: llevarlos al proyecto para que las imágenes nuevas los
   traigan. Estado: powerdevilrc anidado en la Odin (DisplaySleep=0, TurnOffDisplay=false,
   SuspendSession=0) + autostart `deckstation-dpms-fix.desktop`.

## 🔧 Para que una imagen nueva quede completa

1. Recompilar la imagen (`make build` + `make sd-image`) con el árbol ya sincronizado.
2. Flash + primer arranque → Pocknix Tools → "Download DeckStation (emulators)".
3. Lanzar DeckStation: el launcher despliega las configs base solo.
4. Bios: dejar los ficheros en `/opt/deckstation/bios/<sistema>/` (se reparten solos).
5. **Falta**: meter el core de Suyu en la imagen (gap 1) y decidir GooseStation (gap 2).


## ✅ PR #81 — REBASE HECHO, MERGEABLE (17/09/2026, noche)

- El PR estaba **CONFLICTING** (upstream publicó v0.4: 32 commits nuevos en main).
- **Rebase completo** de los 11 commits de `odin3-pr` sobre `origin/main` (rama temporal
  `rebase-pr-20260917`, luego `git branch -f odin3-pr` + force-push a `arcadematicas`).
- **2 conflictos resueltos**:
  1. `pocknix-emulation-full/PKGBUILD`: mantuvimos nuestro cambio (los `-bin` a optdepends,
     que es el propósito del commit eec2d4a) + el pkgdesc de upstream.
  2. `pocknix-steam`: mantuvimos el gate DRM (esperar al panel DSI connected) + el `mark
     "starting gamescope"` de upstream.
- **Estado: `MERGEABLE`** (antes CONFLICTING). Sin checks de CI en la rama.
- El mantenedor comentó el 15/09 ("lo revisaré mañana") pero no ha vuelto. **Pendiente**:
  esperar su respuesta y responderle.

## ⚠️ GAPS DETECTADOS (pendientes)

1. **El centro NO tiene `configs/es-de/`** (los ES-DE configs solo viven en stshunz). El
   PKGBUILD referencia `deckstation-setup.sh`, `deckstation-launcher.sh`, `deckstation-update.sh`,
   `setup_arm64_apps.py` que **faltan** en `packages/deckstation-arm/scripts/` (solo hay `lanzar.sh`).
   → Sincronizar esas piezas al centro.
   - **NOTA (noche)**: el sync de deckstation-arm usa `overlay` (sin `--delete`), así que los
     configs editados a mano en el árbol SOBREVIVEN al sync. Los configs definitivos
     (es_find_rules `1a1331cf`, es_systems `bb23cb59`, git.txt `49b4d79a`, lanzar.sh, updater.py)
     ya están copiados al árbol → la próxima imagen los lleva.
2. **`setup_arm64_apps.py` sin conectar** al flujo (nadie lo llama) y `deckstation-setup.sh`
   roto (descargaba el APK de Android de RetroArch). → Arreglar para que el setup sea reproducible.
3. **Licencia GooseStation** (CC-BY-NC-ND + no distribuir): decisión de Fransis = **servidor
   externo + descarga automatizada** (como lossless.dll). Pendiente de montar.
4. **Ryujinx** (gitea por confirmar) y **PCSX2/PPPSPP/RPCS3/Citron** (sin ARM) siguen sin build.
5. **Powerdevilrc + autostart DPMS**: llevarlos al proyecto (que las imágenes nuevas los traigan).
   Estado: powerdevilrc anidado en la Odin (DisplaySleep=0, TurnOffDisplay=false, SuspendSession=0)
   + autostart `deckstation-dpms-fix.desktop`. **Monitor de pantalla corriendo en la Odin**
   (`/tmp/pantalla_monitor.log`, cada 30s) — pendiente de confirmar que ya no se apaga.