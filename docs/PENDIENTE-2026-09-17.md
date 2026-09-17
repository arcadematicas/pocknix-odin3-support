# Pendiente — 17/09/2026: Suyu, repos de la Odin y pruebas de esta noche

Estado al cerrar la sesión. **La Odin quedó con la pantalla apagada** (brightness 0).

---

## 🎮 Para probar esta noche

### 1. DeckStation + ES-DE
- `DeckStation.AppImage` (ES-DE 3.4.1, aarch64) instalado en `/opt/deckstation/`
- Su config en `DeckStation.AppImage.home/ES-DE/` (custom_systems, settings, scrapers)
- **Probar**: lanzar `deckstation` y ver que arranca el frontend y lista sistemas

### 2. RetroArch
- `RetroArch 1.22.2` en `/opt/deckstation/Apps/RetroArch/` (árbol extraído en `app/`)
- **206 cores** + el `retroarch.cfg` saneado del repo (HOME portable)
- **Probar**: lanzarlo desde ES-DE y desde `Apps/RetroArch/lanzar.sh`

### 3. Core de Suyu (Nintendo Switch)
- **Compilado hoy en la Odin**: `suyu_libretro.so` (36,6 MB, ELF aarch64)
- Instalado en `…/RetroArch-Linux-aarch64.AppImage.home/.config/retroarch/cores/` (207 cores)
- **Probar**: cargar un juego de Switch desde ES-DE → sistema `switch` → opción
  **"Suyu (RetroArch)"** (es la primera, la de por defecto)
- **Necesita**: ROM + firmware/keys de Switch
- ⚠️ Si el core no arranca, mirar el log de RetroArch
  (`~/.config/retroarch/logs/` dentro del `.home`)

---

## ✅ Si el core de Suyu funciona

1. **PKGBUILD** para el core (para que entre en la imagen):
   - Fuente: `github.com/suyu-emu/suyu-v0.0.4` (`src/libretro_core/`)
   - `cmake -DSUYU_BUILD_LIBRETRO_CORE=ON -DENABLE_QT=OFF -DVulkanHeaders_FORCE_BUNDLED=ON`
   - **⚠️ Añadir `-DCMAKE_CXX_FLAGS="-Wno-maybe-uninitialized"`** (GCC 16 da un falso positivo
     en `cheat_engine.cpp:221` que, con `-Werror`, aborta el build)
   - `depends`: boost, openssl, libusb, vulkan-icd-loader, sdl2, enet, fmt, zlib, zstd, lz4
   - `makedepends`: cmake, ninja, git, glslang, catch2
   - Copiar el `.so` a los cores de RetroArch + el `suyu_libretro.info`
2. **Integrarlo en el código fuente** (según lo hablado con Fransis)

---

## 🚨 HALLAZGO GRAVE: el `pacman.conf` de la imagen está roto

La Odin **no podía instalar ningún paquete**. Su `/etc/pacman.conf` solo tenía:

```
[pocknix]        → https://pocknix.shuuri.net/repo/sm8750   ❌ 404
[pocknix-shared] → https://pocknix.shuuri.net/repo/shared   ❌ 404
[pocknix-base]   → https://pocknix.shuuri.net/repo/base     ❌ 404
```

y **ningún `[core]` ni `[extra]` de ALARM**. El repo de upstream se cayó y el resultado es que
un dispositivo recién flasheado **no puede instalar nada**.

**Arreglado en la Odin** (backup en `/etc/pacman.conf.bak-*`):
- Repos `pocknix.*` comentados
- Añadidos `[core]` y `[extra]` con `Include = /etc/pacman.d/mirrorlist`
- **NO hacer `pacman -Syu`** (actualizaría todo y rompería Pocknix)

**⚠️ PENDIENTE: arreglarlo en el `pacman.conf` que genera el build** (y decidir qué hacemos con
nuestro propio repo de paquetes, que es lo que debería ocupar el sitio de `pocknix.*`).

---

## 🔑 Notas de operación (aprendidas hoy)

### Desbloquear `sudo` en la Odin
Si `sudo` empieza a rechazar la contraseña (`pocknix`) tras varios intentos fallidos, es
**`pam_faillock`**. El fichero `/var/run/faillock/deck` es **propiedad de `deck`** (modo 0660),
así que se limpia **sin root**:

```bash
: > /var/run/faillock/deck
```

⚠️ **No usar `sudo -S` con heredocs** — el heredoc se come la contraseña y provoca los fallos.
Usar fichero temporal o `echo pass | sudo -S cmd`.

### Pantalla de la Odin
```bash
B=/sys/class/backlight/ae94000.dsi.0
echo 0 | sudo tee $B/brightness    # apagar
```
Hay un `power-button-daemon.service` que la gestiona con el botón físico.

### Bug del AppImage de RetroArch
`RetroArch-Linux-aarch64.AppImage` trae el **`AppRun` mal generado**:
```sh
#!/bin/sh
exec /usr/bin/retroarch "$@"     # ruta ABSOLUTA, pero el binario va DENTRO del AppImage
```
Solución aplicada: extraído con `--appimage-extract` a `app/` (borrando su `AppRun` roto) y el
`lanzar.sh` lo detecta. **Avisar al autor** — el AppImage conserva una copia como `.AppImage.ROTO`.

---

## 📦 Estado de los repos

| Repo | Último commit |
|---|---|
| `stshunz/deckstation-arm` | `2f20206` — soporte del core de Suyu en ES-DE |
| `arcadematicas/pocknix-odin3-support` (centro) | `2264032` + este documento |
| `arcadematicas/pocknix-os` (`odin3-sm8750`) | `f42ee3f` |
