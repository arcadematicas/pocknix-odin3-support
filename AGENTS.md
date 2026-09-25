# AGENTS.md — Proyecto Pocknix / AYN Odin 3 (SM8750)

Documento de contexto del proyecto. Cargado automáticamente al trabajar en este
repo. El detalle por temas está abajo; para el historial completo de sesiones ver
`~/.opencode_memory.md` (solo referencias) y los logs de la Odin.

## Qué es esto
Pocknix (Arch Linux ARM) corriendo en una **AYN Odin 3** (Snapdragon SM8750 /
Adreno 830). Trabajo: kernel a medida, batería, Steam en modo juego, plugin
Decky, daemons, etc. **KERNEL BUENO = 7.2** (el 7.1 NO funciona en esta Odin).

## Estructura de repos
- `/home/fransis/pocknix-odin3-project/pocknix-odin3-support/` — **NUESTRO repo** (git, remote = `arcadematicas/pocknix-odin3-support`). Todo el trabajo de la Odin 3 va aquí: `config/`, `kernel/` (parches), `RESEARCH-ARM-DISTROS.md`, `POCKNIX-EXPERIENCE.md`, `BATTERY-ISSUE.md`.
- `/home/fransis/pocknix-odin3-project/pocknix-os/` — clon de trabajo del repo UPSTREAM de shuuri-labs (NO pushear a su remote `origin`). El kernel se compila desde aquí.
  - **Remotes**: `origin` = `shuuri-labs/pocknix-os` (upstream, solo fetch) · `arcadematicas` = **nuestro fork** (aquí sí se pushea).
  - **`odin3-sm8750` es LA RAMA DEL PROYECTO** (ver "MODELO DE RAMAS" abajo): todas nuestras modificaciones + upstream mergeado encima.
  - `odin3-pr` — rama limpia para el PR upstream (#81, **aparcado**). Solo lo que upstream puede aceptar.
- **`stshunz/deckstation-arm`** — repo de **DeckStation ARM** (emulación portable para aarch64/armv7h). ⚠️ **DeckStation es un proyecto INDEPENDIENTE, de autoría de `stshunz`** (nuestro compañero, creador original). **NO está vinculado a Pocknix** (aunque en el futuro Fransis podrá integrarlo por su parte). Todo autocontenido en `/opt/deckstation/`: scripts de setup/launcher/update, configs de emuladores sanitizadas (rutas relativas), PKGBUILD (`deckstation-arm`). Los emuladores (AppImages) NO están en git: se descargan desde GitHub/PkgForge con `deckstation-setup`. Clon local: `/home/fransis/deckstation-arm/`. La versión x86_64 (original, más completa) está en `stshunz/deckstation-x86_64` — NO mezclar.
- **`stshunz/deckstation-x86_64`** — repo de **DeckStation x86_64** (PC/Steam Deck, versión original). Misma autoría (`stshunz`) e independencia. Clon local: `/home/fransis/deckstation-x86_64/`.
- **arcadematicas = nosotros** (confirmado). Todo commit a `pocknix-odin3-support` va a arcadematicas.

## 🔀 MODELO DE RAMAS (15/09/2026) — LEER ANTES DE COMPILAR

- **`odin3-sm8750` = LA RAMA DEL PROYECTO.** Todo nuestro trabajo vive aquí: DeckStation + WProton
  (nuestra capa de emulación), MAKO, kernel 7.2.4 + parches, fixes de arranque/apagado/OOBE,
  firmware ADSP… **y upstream mergeado encima**. Se sincroniza periódicamente con `origin/main`.
- **`odin3-pr`** = rama limpia para el PR upstream (#81, aparcado).
- **⚠️ REGLA DE ORO**: un fix hecho en una rama **NO** existe en la otra. Ya nos ha mordido 3 veces
  (el marker OOBE, el `apply=7` y los sentinels de apagado/reinicio estaban en `odin3-pr` —o solo en
  papel— y la imagen nueva salió sin ellos). **Antes de compilar una imagen: `git diff odin3-sm8750 odin3-pr`
  y comprobar que los fixes están portados.**
- **Sincronizar con upstream**: `git fetch origin` → mergear `origin/main` en una rama aparte
  (`sync/upstream-<tag>`), resolver conflictos, **verificar el build**, y solo entonces mergear a
  `odin3-sm8750`. **Merge, no rebase** (preserva nuestros commits como propios).
  - Upstream v0.4 hizo la **capa de emulación OPCIONAL** (`POCKNIX_EMULATION=1` la mete en la imagen;
    por defecto NO se instala). Nuestra **DeckStation/WProton** es una capa aparte y siempre va.
    Los paquetes de emulación de upstream se conservan (opt-in) pero no se instalan.
- **`DEVICE=sm8750` es OBLIGATORIO** en `make build` / `make kernel` (por defecto compilan sm8550).

## 🏗️ ESTRUCTURA DEL PROYECTO (16/09/2026) — LEER SIEMPRE

### Los cuatro repos y su papel

| Repo / rama | Papel |
|---|---|
| **`arcadematicas/pocknix-os`** rama **`odin3-sm8750`** | **NUESTRO SISTEMA.** Fork de `shuuri-labs/pocknix-os`. Upstream mergeado + soporte del Odin 3 + nuestro desarrollo (DeckStation, MAKO, daemons, parches). **Aquí se compila.** Sigue recibiendo actualizaciones de pocknix. |
| **`arcadematicas/pocknix-odin3-support`** (`master`) | **EL CENTRO.** Fuente de verdad de lo nuestro: parches de kernel/gamescope, paquetes propios, `overlay/`, `tools/`, docs. |
| `shuuri-labs/pocknix-os` (remote `origin`) | **Upstream.** Solo `git fetch`. |
| **`odin3-pr`** | 🔒 **CONGELADA.** Rama limpia del **PR upstream #81** (soporte del Odin 3). **NO se toca** salvo para rebasear/responder al mantenedor. **Nada de DeckStation/MAKO va aquí.** |

**Directorio de trabajo** (donde se ejecuta el build):
`/home/fransis/pocknix-odin3-project/pocknix-os/`

### ⚠️ REGLAS DE ORO

1. **Se edita SIEMPRE en `pocknix-odin3-support`.** `pocknix-os` es un árbol de compilación:
   **NO se edita a mano** — así es como se han perdido fixes (OOBE, sentinels, daemons…).
2. **Antes de compilar**: `tools/sync-to-os.sh` (aplica nuestro contenido). El build llama a
   `tools/check-sync.sh`, que **aborta si el árbol no coincide con el centro**.
3. **Lo upstreamable** (kernel, DTS, BSP, fixes de arranque) se saca del centro a `odin3-pr` en
   commits limpios. **Nuestro desarrollo** (DeckStation, MAKO…) se queda en `odin3-sm8750`.
4. **`DEVICE=sm8750` es OBLIGATORIO** en `make build` / `make kernel` (por defecto compilan sm8550).
5. Los parches de kernel se aplican **siempre** (todo `kernel/sm8750/patches/*/` en orden numérico:
   `05-speedup` → `10-mainline` → `20-sm8750` → `30-version`). `build-kernel.sh` **re-extrae el fuente**
   en cada compilación, así que un parche añadido después de compilar NO está en el kernel hasta que
   se recompile.

### 🛡️ DETECTOR DE REGRESIONES DEL MERGE (obligatorio tras cada merge de upstream)
El merge de upstream v0.4 **pisó 11 cambios nuestros** que vivían solo en `odin3-pr` (entre ellos
`pocknix-oobe-marker.service` sin habilitar → bucle de reinicio del OOBE, y los `socs` de
fex-emu/mangohud/mesa/turnip-arm sin `sm8750`). **Comprobar SIEMPRE después de mergear**:

```bash
cd pocknix-os
BASE=$(git merge-base odin3-pr origin/main)
# OJO: comparar contra el ARBOL DE TRABAJO, no contra HEAD. Nuestros cambios al arbol de
# compilacion NO estan commiteados (los aplica sync-to-os.sh), asi que `git diff HEAD` da
# falsos positivos en todo lo que el sync acaba de aplicar.
git diff --name-only "$BASE" odin3-pr | while read f; do
  git cat-file -e "origin/main:$f" 2>/dev/null || continue
  git diff --quiet origin/main -- "$f" || continue     # el arbol difiere de upstream -> tenemos cambio -> ok
  git diff --quiet odin3-pr origin/main -- "$f" || echo "⚠️ PERDIDO: $f"
done
```
Los "perdidos" que suelen quedar son **cosméticos** (comentarios en `config/pocknix.conf`,
`pocknix-diag`, `pocknix-flathub-dispatcher`, `devices/README.md`) o de **emulación**
(`pocknix-emulation-full`), que no instalamos. Los que importan de verdad son los `socs`, los
servicios de `pocknix-diag`/`pocknix-flathub` y el resto de la capa propia.

### 📖 Guía de compilación para colaboradores
**`pocknix-odin3-support/BUILD.md`** — requisitos, pasos desde un clon nuevo, qué hace cada fase,
problemas conocidos y cómo sincronizar con upstream. **Verificado clonando desde cero (16/09).**

### 📌 PR upstream #81 (soporte del Odin 3)
Abierto, **CONFLICTING** desde v0.4 → habrá que rebasearlo. El mantenedor (`shuuri-labs`) dijo el
15/09 que lo estaba revisando. **Plan**: esperar su respuesta y hacer un solo push (rebase + lo que
pida). No moverle el suelo mientras revisa.

### Estado de la reorganización (PENDIENTE)

- [ ] Reorganizar el repo de soporte: `docs/`, `kernel/patches/`, `gamescope/patches/`, `overlay/`,
      `packages/`, `devices/sm8750/`, `tools/`
- [ ] Escribir `tools/sync-to-os.sh` + `tools/check-sync.sh`
- [ ] **Portar la deuda**: 42 ficheros de `config/` + 3 parches que hoy están SOLO en soporte y por
      tanto NO entran en la imagen (ver sección siguiente)

### 🔴 DEUDA CONOCIDA (15/09/2026) — lo que NO está en el build

**✅ RESUELTO en el repo de soporte (commit `31dc74d`)** — falta sincronizarlo cuando el build pare:

| Qué | Estado |
|---|---|
| Daemons + servicios del Odin 3 (42 ficheros) | ✅ empaquetados en `packages/pocknix-bsp-sm8750/` |
| `pocknix-bsp-sm8750` / `pocknix-device-sm8750` | ✅ creados (¡no existían y estaban referenciados!) |
| `0001-adreno-…gx-collapse-before-cx.patch` | ✅ en `kernel/patches/` → se sincroniza |
| `pocknix-fancontrol` / `pocknix-fan-mode` (más nuevos aquí) | ✅ en `packages/pocknix-bsp-common/` |
| `0079` + DTS | ✅ traídas las versiones del build (eran las buenas) |
| `0002-input-rsinput` | ✅ superado por `0031`+`1002`+`1004` → `reference/superseded-patches/` |
| Duplicados (decky-plugin, pocknix-control-plugin, ayn_mcu, 01-ayn-controller) | ✅ eliminados |
| `tools/sync-to-os.sh` + `tools/check-sync.sh` | ✅ escritos y probados |

**⏳ PENDIENTE**

| Qué | Nota |
|---|---|
| Sincronizar al build | `tools/sync-to-os.sh` — **cuando el build no esté corriendo** |
| `gamescope/patches/0004-fps-limit-atom-persist.patch` | Copiar no basta: el PKGBUILD de gamescope debe referenciarlo en `source=()` |
| 22 parches `05-speedup` | En el árbol, pero **no en el kernel grabado** → recompilar |
| **Lanzador de sesión** | El build usa el modelo **embebido** (`gamescope -e -- steam`); `reference/launcher-variants/pocknix-steam.steamos-model` es el **modelo SteamOS** (gamescope standalone + Steam hermano). **DECISIÓN PENDIENTE** |
| Verificar el PR #81 completo | `git diff odin3-sm8750 odin3-pr` |
| Rebuild + reflasheo | Con todo lo anterior |

## GitHub — usuarios y colaboradores
- **`arcadematicas`** = nosotros (Fransis). Colaborador en los repos de DeckStation (que ya no aloja).
- **`stshunz`** = **compañero y CREADOR ORIGINAL de DeckStation** (https://github.com/stshunz). **Toda la autoría de DeckStation es suya.** Es el **owner** de los repos de DeckStation. Tiene repos propios: `stshunz/WProton` y `stshunz/WProton_ARM`.
- **DeckStation es un proyecto independiente**: no pertenece ni depende de Pocknix ni de ningún otro sistema operativo. Si en el futuro se vincula a Pocknix, será por iniciativa de Fransis y por separado.
- **TRANSFERENCIA COMPLETADA (14/09/2026)**: los repos DeckStation están en la cuenta de su autor, **`stshunz`** (Opción A):
  - `https://github.com/stshunz/deckstation-arm`
  - `https://github.com/stshunz/deckstation-x86_64`
  - Clones locales con remote actualizado. GitHub deja redirects de las URLs antiguas (`arcadematicas/...`).
  - `arcadematicas` (Fransis) figura como colaborador (permiso write) en ambos.
- **Flujo de trabajo git**: GitHub = fuente de verdad. `git pull` antes de trabajar → editar → `git add/commit` → `git push`. La Odin (`/opt/deckstation/`) NO es fuente de verdad: los cambios hechos allí hay que traerlos al clon local y commitear.
- **⚠️ TODO cambio de DeckStation va TAMBIÉN a `stshunz/deckstation-arm`** (no solo a nuestro
  centro). Nuestro `packages/deckstation-arm/` es la copia vendored para el build de la Odin; el
  repo de stshunz es el original. **Antes de tocar nada: `diff` el clon con nuestro centro** (ya
  hubo drift: dos arreglos del PKGBUILD estuvieron semanas sin subir).
- **⚠️ El `.gitignore` de `deckstation-arm` tiene entradas críticas** (`Apps/`, `saves/`, `logs/`,
  `*.AppImage`): al añadir reglas nuevas, **appendear**, nunca sobrescribir.

## Acceso a la Odin
- SSH: alias `odin` (Tailscale IP cambia; config en `~/.ssh/config`). Usuario `deck`, contraseña sudo `pocknix`.
- Unidad compartida: `/home/deck/Recibidos` de la Odin ↔ `/home/fransis/Odin` del PC (SSHFS, montaje `.mount` de usuario como fransis con `idmap=user`).
- Scripts: `~/bin/odin-montar` y `~/bin/odin-desmontar`.
- **UIDs**: fransis=1000, deck=1001.

## Estados CRÍTICOS y lecciones (NO repetir errores)
- **NUNCA reiniciar Decky Loader en caliente** mientras Steam corre en modo juego → crash loop de steamwebhelper (NameError exit en main.py:118). Reiniciar solo desde Plasma o antes de entrar a Game Mode.
- **NUNCA reemplazar el kernel 7.2 por 7.1** (7.1 no arranca en la Odin 3).
- **MangoHUD / `--mangoapp`: NO TOCAR.** `pocknix-steam` lanza gamescope **con `--mangoapp`** y
  **MangoHUD funciona perfectamente desde Steam** (confirmado por Fransis, 21/09/2026). La nota
  vieja *"NO usar `--mangoapp` (modelo SteamOS: mangoapp como hermano)"* está **OBSOLETA** —
  quedó de un modelo anterior y llegó a contradecir al código. **No quitar el flag.**
- **NO desocultar /dev/input/event6** (el mando real está oculto por InputPlumber a propósito; el virtual event10 es el que usan las apps).
- Paneles negros de Steam = bug de FEX (steamwebhelper x86 bajo FEX/CEF). Upstream, sin fix completo.
- `pocknix-decky-sync` re-siembra Decky desde el bundle del OS en cada arranque si `sort -V` lo considera más nuevo. Para instalar Decky persistente: reemplazar `/usr/share/decky-loader/PluginLoader` + borrar el de homebrew.

## Kernel (build y parches)
- Build: `cd pocknix-os && JOBS=14 DEVICE=sm8750 ./scripts/build-kernel.sh` (usa `setsid nohup ... &` para sobrevivir al timeout). Log a `/tmp/kernel_*.log`.
- El script re-extrae source de `build/cache/linux-7.2.tar.xz` y aplica patches en orden numérico de `kernel/sm8750/patches/20-sm8750/`.
- Parches NUESTROS en ese dir (y copia en `pocknix-odin3-support/kernel/`):
  - `0078` battery v4 (estimación % por voltaje OCV con tabla curva Li-ion)
  - `0079` battery poll (polling de capacidad cada 30s → % fresco + avisos batería baja)
  - `0080` charge_enable (port PR ROCKNIX #2840: charge_behaviour/usb_charge_now) — **el firmware de nuestra unidad responde "unknown message 0x33", NO activa carga aún (PENDIENTE)**
  - `0503` ROCKNIX-battery-name, etc.
- **LECCIÓN parches**: generar el diff SIEMPRE contra el source re-extraído (con los patches previos aplicados), formato git (`diff --git a/... b/...`), y probar que aplica SIN fuzz con `patch -p1` (el build no usa fuzz).
- Artefactos: `build/image/sm8750/KERNEL` (Android bootimg), módulos en `build/kernel/sm8750/out/modroot/lib/modules/7.2.0/`.
- Deploy a la Odin: KERNEL → `/flash/KERNEL` (backup previo), módulos → `/lib/modules/7.2.0/`, `depmod -a 7.2.0`, reboot. **Cuidado**: `cp -r /tmp/carpeta /lib/modules/7.2.0/` copia la carpeta como subcarpeta — copiar el CONTENIDO (`/tmp/carpeta/*`).

## Batería (tema principal)
- El fuel gauge corre en el **firmware ADSP** (pmic_glink → qcom_battmgr). No hay gauge real en kernel.
- **%**: parche 0078 estima por voltaje OCV (Debug_Board, sin gauge). El 0079 hace polling 30s (antes el % se congelaba y los apagones por batería no avisaban).
- **Carga NO funciona en Linux**: el firmware ADSP no activa la carga por USB. Android sí (usa driver propietario `qti_battery_charger.ko`). Parche 0080 intenta el SET_USB(0x33,14,1) pero el firmware responde "unknown message 0x33". **PENDIENTE**: desensamblar `/tmp/qti_battery_charger.ko` para hallar el opcode real de esta unidad. Workaround: cargar apagada o en Android.
- **Batería real**: ~7600 mAh (Android charge counter). DTS de Linux dice 5000 (mal).
- El sysfs `charge_behaviour` existe y cambia (auto/inhibit) pero no afecta la carga real.
- Detalle en `BATTERY-ISSUE.md` del repo.

## Steam / gamescope (modelo actual)
- `pocknix-steam` usa el **modelo SteamOS**: gamescope standalone con `--steam -R socket -T stats`, y **Steam como proceso hermano** con `DISPLAY`/`GAMESCOPE_WAYLAND_DISPLAY` del ready socket. NO embebido.
- Flags de Steam: `-gamepadui -steamos3 -steampal -steamdeck -noshaders` (NO `-deckard`; con `-deckard` el QAM no mostraba el selector de perfiles).
- Gates en entorno: `SteamDeck=1`, `STEAM_USE_MANGOAPP=1`, `ENABLE_GAMESCOPE_WSI=1`, etc.
- Steam canal: `steamdeck_publicbeta` (único con gamepadui ARM64). `pocknix-steam` re-pinea `package/beta` en cada lanzamiento.
- **SteamOS Manager (shim D-Bus)**: `/usr/local/bin/pocknix-steamos-manager` (Python+GI) en bus de sesión, expone `com.steampowered.SteamOSManager1` → el QAM controla perfiles de potencia. Interfaz completa obligatoria (si SessionManagement1 incompleta, Steam degrada). Nombres de perfil: `low-power/balanced/performance`. **SwitchToDesktopMode/GameMode ahora ejecutan `steamos-session-select` real** (arreglado 09/09).
- **Frame limiter del QAM roto en ARM**: bug gamescope upstream (átomo GAMESCOPE_FPS_LIMIT se resetea cada frame). Fix = parche Nova-Deck `0004-fps-limit-atom-persist.patch` (en `kernel/`), compilado e instalado. PENDIENTE validar con juego.
- MangoHUD parcheado SM8750 instalado. Toggle por paddle M2 (F13) → daemon v2 resiliente.
- Switch de sesión: `steamos-session-select [gamescope|plasma]` escribe en `/home/deck/.local/state/pocknix-session` + SIGTERM compositor; el supervisor `~/.bash_profile` de deck relanza. NO reiniciar getty.

## Daemons / servicios en la Odin
- `pocknix-fancontrol`, `pocknix-pergame-power`, `pocknix-cpu-governor`, `oled-care-daemon`, `pocknix-decky-loader`, `mangohud-toggle-daemon`, `odin3-splash`, `pocknix-steamos-manager` (user).
- Ojo: algunos tardan en activarse tras boot (After=multi-user.target, sistema en "starting" 1-2 min).

## Plugin Decky (PocknixControl) — ACTUALIZADO 21/09/2026
- **Dónde vive**: `packages/pocknix-decky/pocknix-control/` — frontend TS (`src/tabs/Lighting.tsx`,
  `src/components/`) + backend Python (`py_modules/pocknix_control/`: power.py, **led.py**,
  **oled_care.py**, main.py) + **`dist/index.js` COMPILADO Y COMMITEADO** (no hay node en el
  build del paquete).
  - ⚠️ **La ruta `config/pocknix-control-plugin/` ya NO existe** (el AGENTS.md lo decía mal).
  - ✅ **En el centro desde el 21/09** + registrado en `tools/sync-to-os.sh` y
    `tools/check-sync.sh`. Antes vivía **solo en el árbol** → cualquier cambio se perdía en
    silencio (era el mismo caso que la capa vendored).
  - `node_modules/` (95 MB) está gitignored y **solo existe en el árbol**.
- **Cambiar el frontend**: editar en el centro → `sync-to-os.sh` → compilar EN EL ÁRBOL
  (`cd packages/shared/pocknix-decky/pocknix-control && npx rollup -c`) → **copiar
  `dist/index.js` de vuelta al centro** (sin el `.map`, el PKGBUILD lo borra) → bump `pkgrel`.
- Reiniciar backend: `sudo systemctl restart pocknix-decky-loader.service` (**SOLO sin Steam
  en modo juego**, o crashea steamwebhelper).
- El PluginLoader corre como root sin entorno gráfico; extraer env de sesión vía `pgrep -x` (no -f).
  ⚠️ **Y PipeWire es de `deck`**: para verlo desde root hace falta `XDG_RUNTIME_DIR=/run/user/1001`
  (sin eso `pw-dump` no ve nada — le pasó al daemon del OLED care).

### RGB de los sticks (led.py)
- Odin 3: **un nodo LED-class por CANAL y segmento** (`l:r1`/`l:g1`/`l:b1` … 4 segmentos por
  stick) → `_segments()` solo devuelve los rojos y `_write_segment()` deriva g/b del nombre.
- ⚠️ **Apagar = pintar el trío entero a 0**, no solo bajar `brightness` del rojo (si no, el
  verde y el azul siguen encendidos y parece que "no se apaga").
- **`enabled` POR STICK** (21/09): se puede apagar solo el izquierdo o solo el derecho
  conservando color y brillo (`set_led_side_enabled`). Enlazado copia también el `enabled`.

### OLED care (oled-care-daemon.py + oled_care.py)
- Refresca a los **10 min de inactividad** (el tiempo es correcto por decisión de Fransis).
- **NO debe dispararse mientras el usuario hace algo**: mira input, procesos de juego/frontend
  (es-de/retroarch/steam/gamescope) **y reproducción de medios** (21/09). Para los medios:
  audio sonando vía `pw-dump` (¡con `XDG_RUNTIME_DIR`!) o reproductor abierto. Se ignora el
  ruido (`pocknix`/`oled-refresher`/`python`): su stream queda `running` para siempre.
- Deja estado en **`/run/pocknix/oled-care.json`** (`lastRefresh`, `lastSkip`, `count`,
  `idleSeconds`) → lo expone `oled_care_status()` y lo muestra la pestaña Lighting.
  Antes la UI **no tenía ningún feedback** y por eso parecía que no funcionaba.

## 🧹 SISTEMA FINO + SENSORES (11/09/2026)
- **`odin3-display.service` ARREGLADO**: fallaba (única unidad en `failed`). Causa:
  `echo 3 > /sys/class/drm/card0-DSI-1/rotation` (ese sysfs ya no existe; la
  rotación es propiedad DRM) y dos bucles `modprobe` rotos (`modprobe` sin
  argumento, con `$mod` sin usar) de módulos que no existen. Corregido: solo
  `echo on > status` + `brightness` + `true`. Backup:
  `/etc/systemd/system/odin3-display.service.bak-20260911`. `systemctl --failed` = vacío.
- **Bluetooth ACTIVADO**: `bluetooth.service` enabled+active (adaptador `hci0`,
  no bloqueado). `bluedevil` ya es funcional.
- **SENSORES / BRILLO ADAPTATIVO**: el brillo adaptativo usa el **sensor de luz
  ambiental (ALS)**, NO el acelerómetro (el acelerómetro es para auto-rotación).
  Ambos dependen del stack de sensores Qualcomm (SSC). Estado: `hexagonrpcd` está
  instalado y su servicio `hexagonrpcd-adsp-sensorspd.service` está enabled, pero
  **sale a los ~0.5s y no expone dispositivos IIO** (`/sys/bus/iio/devices/` vacío;
  `pgrep hexagonrpcd` vacío). Log: `Unexpected buffer count: 1f050100` tras
  `INIT_ATTACH_SNS`. Consecuencia: `kscreen-doctor` reporta
  `Automatic brightness: unsupported` y no hay auto-rotación. **Es bring-up que
  falta** (registry/`sns_reg` + ADSP sensor PD), no un simple paquete.
  Ficheros de config reales de Android ya en `/usr/lib/firmware/sensors/`.

## 🚀 MEJORAS DE ARMADAOS IMPLEMENTADAS (11/09/2026)
- Doc: `pocknix-odin3-support/ARMADAOS-IMPL.md`. Todo en las fuentes de `pocknix-os`
  (desplegado en la Odin; suspensión verificada).
- **1) `pocknix-steam`**: feature gates `STEAM_GAMESCOPE_*` (VRR/tearing/HDR/NIS/
  `DYNAMIC_FPSLIMITER`/MULTIPLE_XWAYLANDS/color managed...). No definíamos ninguno.
- **2) `pocknix-desktop-env`** (nuevo autostart fase 1): importa `WAYLAND_DISPLAY`/`DISPLAY`/
  `XAUTHORITY` a `systemd --user` y al bus D-Bus → arregla el crash del daemon de KScreen.
- **3) `pocknix-proton-wrapper`**: inyecta `libwayland-client`/`libxkbcommon` x86 en el prefijo
  (mando muerto en Proton x86) + repara el mando atascado (`VID_28DE` sin promover en
  `system.reg`) + `DXVK_HUD=none`. Incluye los `.so` x86 en `proton-inject/`.
- **NO portado** (ya lo tenemos o no aplica): `controller-type` (→ `pocknix-gamepad-target`),
  perfiles FEX, `scx_loader` (usamos `scx_lavd`), Btrfs nodatacow (ext4), `armada-powerd`
  (tenemos fancontrol/lavd-mode/powerd/plugin Decky). **Suspensión resuelta** (s2idle real +
  hook de pantalla). Pendiente: MTP, HDR (`HDR_NITS`), UCM audio Odin 3.

## DeckStation (Odin 3) — estado 18/09/2026

**Ubicación en la Odin**: `/opt/deckstation/` (paquete `deckstation-arm`; comando
`deckstation`). El detalle exhaustivo está en
`stshunz/deckstation-arm/CAMBIOS-REALIZADOS.md` (secciones 8-11).

### Arquitectura portable
- **ES-DE**: `DeckStation.AppImage` con home en `DeckStation.AppImage.home/ES-DE/`.
- **es_find_rules.xml / es_systems.xml**: `DeckStation.AppImage.home/ES-DE/custom_systems/`
  — rutas relativas `./Apps/...` y `%ROMPATH%/...`.
- **Wrappers `lanzar.sh`**: uno por emulador; limpia `APPIMAGE`/`APPDIR`/`OWD`, exporta
  `HOME` al `*.home` del AppImage (portable) y fija `SDL_VIDEODRIVER`.
- **RetroArch**: config portable en `Apps/RetroArch/RetroArch-Linux-aarch64/*.AppImage.home/.config/retroarch/`.
  `video_driver = glcore` (el Vulkan de Turnip en Adreno 8xx relentiza) y menú **XMB +
  FlatUX** (requiere los assets de `libretro/retroarch-assets`, no van en git).

### Configuración base reproducible (18/09/2026)
- `configs/` **es** la config base: `scripts/deckstation-configs.sh` la despliega según
  `configs/deploy-manifest.txt` (token `{HOME:App}` = el `.home` del emulador). No
  destructivo. Lo llaman el setup y el launcher. **Ya no hace falta el payload de
  MediaFire del Updater** (era x86_64).
- `bios/` + `scripts/deckstation-bios.sh`: solución externa para las BIOS (copyright).
  El usuario deja sus ficheros por sistema y el script los reparte.

### Cores (ojo)
- **Suyu (Switch)**: las claves van en `<retroarch>/system/suyu/keys/` — NO en la raíz de
  `system/`. Sin ellas el core revienta en `aes_util.cpp`.
- **Suyu y GooseStation (PSX)** necesitan su `<command>` en `es_systems.xml`: un core
  copiado sin `<command>` no aparece en ES-DE.
- **Idioma de Suyu**: el core de serie **no tiene opción de idioma y no lee ningún fichero
  de config** → los juegos salían en inglés. Parche propio
  (`packages/suyu-libretro/suyu-language.patch`) que añade la core option
  `suyu_language` → *RetroArch > Opciones del core > Suyu > Console Language > Spanish*.
  El rebuild es incremental (~20 s: solo `retro_core.cpp`).
- **⚠️ Core options ≠ Overrides (RetroArch)**: si al guardar sale *"No hay nada que guardar"*
  es que se está usando **Overrides**, que NO guarda core options. Las core options van a
  `<retroarch>/config/<corename>/<corename>.opt` (se pueden **escribir a mano**); se
  persisten con *Settings → Core → Manage Core Options → Save Core Options*. NO es un
  problema de permisos (todo el árbol es `deck:deck`).

### Setup y cores (18/09/2026)
- `deckstation-setup.sh` **ya no descarga el RetroArch de Android** (bajaba
  `RetroArch_ra32.apk` y lo descomprimía en `Apps/RetroArch/`, rompiendo RetroArch en una
  instalación limpia; y es el script que ejecuta Pocknix Tools). Ahora: baja los assets del
  buildbot (~75 MB, iconos XMB), enlaza los cores del sistema, despliega lanzar.sh +
  configs + bios, y **abre el Updater** para los emuladores.
- `deckstation-cores.sh`: enlaza `/usr/lib/libretro/*.so` y `/usr/share/libretro/info/*.info`
  a la carpeta portable de cores (así cualquier core empaquetado aparece en ES-DE).

### Modo juego de Steam (18/09/2026)
- **DeckStation aparece en Game Mode**: `pocknix-steam-sync` (que `pocknix-steam` llama
  justo antes de arrancar Steam, el único momento seguro para escribir `shortcuts.vdf`)
  estaba reapuntado a la capa de emulación de upstream → buscaba `~/ES-DE` +
  `pocknix-play`, no encontraba nada y el tile nunca aparecía. Ahora emite
  **`DeckStation` → `/usr/bin/deckstation`** (idempotente, marca `DevkitGameID="pocknix"`).
- **Fix necesario**: el launcher de DeckStation no fijaba `SDL_VIDEODRIVER` → ES-DE salía
  en **negro** desde gamescope. Ya lo fija (wayland/x11).
- **Pocknix Tools**: `do_deckstation()` prepara DeckStation y **ofrece** el asistente de
  WProton; hay además una entrada propia "Set up WProton (Windows games)...".
- **Moonlight (juego remoto)**: `moonlight-qt` del repo `extra` de ALARM (aarch64 nativo) +
  tile "Moonlight" en Game Mode vía `tiles()` de `pocknix-steam-sync`. Icono PNG generado con
  `rsvg-convert` (Steam no acepta SVG). Corre nativo en Wayland (el plugin viene en
  `qt6-base`). **El host necesita Sunshine** (o GeForce Experience).

### Pendiente
- **GooseStation**: licencia CC-BY-NC-ND → servidor externo + descarga (decisión de Fransis).
- **`suyu-libretro`**: ya lo instala `build-image.sh` como opcional (warn-on-fail) → **ojo:
  compila desde fuente (submódulos + cmake), build pesado**; si falla, la imagen sale sin el
  core de Switch.
- **Accesos por juego en Game Mode**: el código está listo pero necesita
  `/usr/bin/deckstation-play`.
- **`setup_arm64_apps.py`**: lista de repos hardcodeada y sin conectar (el instalador real de
  emuladores es el Updater, desde `updater/git.txt`).
- PCSX2 / PPSSPP / RPCS3 / Citron / Ryujinx: sin build ARM.
- Vita3K no es AppImage (`.7z`) → sin `.home` portable ni configs.

## ✅ DECKSTATION ARM — SUBIDO A GIT (14/09/2026)

- **Repo**: `stshunz/deckstation-arm` (público) — https://github.com/stshunz/deckstation-arm
- **DeckStation es un proyecto INDEPENDIENTE de autoría de `stshunz`** (no vinculado a Pocknix).
- **Es la versión ARM** (aarch64/armv7h). La versión x86_64 (original) está en `stshunz/deckstation-x86_64`.
- **Filosofía**: TODO autocontenido en `/opt/deckstation/` (Apps, configs, saves, logs). NADA se mezcla con el sistema host.
- **En git** (versionado): scripts (setup/launcher/update), configs de emuladores sanitizadas (rutas relativas), configs ES-DE (es_find_rules/es_systems/es_settings adaptados a ARM), autoconfig de RetroArch (610 mandos), PKGBUILD, overlay con comando `deckstation`, docs.
- **NO en git** (binarios): AppImages de emuladores (~1GB) — se descargan desde GitHub/PkgForge con `deckstation-setup`.
- **PKGBUILD**: `deckstation-arm` — instala estructura en `/opt/deckstation/` + comando `deckstation` en `/usr/bin/`.
- **Clon local**: `/home/fransis/deckstation-arm/`
- **Integración con Pocknix**: NO existe todavía. Si se hace, será por iniciativa de Fransis y por separado (el PKGBUILD se llevaría a `pocknix-os/packages/soc/`).

## ✅ DECKSTATION x86_64 (PC) — SUBIDO A GIT (14/09/2026)

- **Repo**: `stshunz/deckstation-x86_64` (público) — https://github.com/stshunz/deckstation-x86_64
- **DeckStation es un proyecto INDEPENDIENTE de autoría de `stshunz`** (no vinculado a Pocknix).
- **Es la versión PC/x86_64** (la original, más completa). Clon local: `/home/fransis/deckstation-x86_64/`.
- **Fuente original**: `/run/media/fransis/8TB/DeckStation/` (442 GB).
- **En git** (14 MB, solo texto): scripts (DeckStation.sh, launcher.sh multi-python, mapeador.py, selector_manual.py, compresorKSM.sh, PortProton_wsquashfs.sh, run_squashfs_wrapper.sh, Gestor KSM.desktop), configs de 23 emuladores, ES-DE (custom_systems/settings/scrapers), RetroArch (92 sistemas), evmapy (código fuente), PKGBUILD, overlay, docs.
- **NO en git**: ROMs, Media (229 GB), wsquashfs (103 GB), Apps (98 GB), bezels (7.8 GB), saves, logs, libs_py*.
- **PKGBUILD**: `deckstation-x86_64` (arch x86_64).
- **Rutas sanitizadas**: paths de app → relativas, ROMs → `%ROMPATH%`, listas de ROMs personales eliminadas (melonds RecentROM, pcsx2 RecursivePaths, citron/azahar recentFiles+gamedirs, scummvm juegos, rpcs3 games.yml).

## Bug carga batería — RESUELTO (issue #402 ArmadaOS, 10/09/2026)

- Issue: https://github.com/armada-os/armada/issues/402 (creado por nosotros)
- **RESUELTO**: ver sección "CARGA BATERIA - RESUELTO". La clave fue el `adsp_dtb.mbn` de ArmadaOS
  (lleva la config de autenticación de batería). Con los 2 ficheros de firmware de ArmadaOS, carga.
- Corrección previa: `0x1fffffff` = `SERVREG_SERVICE_STATE_UP` (el PDR sí sube).
- Diagnóstico: `pmic_pdcharger_ulog` mostró el firmware atascado en TEST MODE (estado 9).

## ✅ SUSPENSIÓN (s2idle) - RESUELTA (11/09/2026)
- **SÍNTOMA**: el botón de encendido solo "parpadeaba" la pantalla (apagaba y encendía).
- **CAUSA**: `/etc/systemd/system/systemd-suspend.service.d/override.conf` interceptaba
  `systemd-suspend.service` y ejecutaba `/usr/local/bin/pocknix-fake-suspend.sh`, un stub
  que solo apagaba `bl_power` + CPU `powersave` + `sync` y **salía al instante** → systemd
  daba la suspensión por hecha. (La premisa "suspender cuelga el SM8750" era falsa: lo que
  cuelga es `deep`, no `s2idle`.)
- **MODELO ArmadaOS**: en el Odin 3 usa `ARMADA_SUSPEND_MODE=s2idle` (real); su `fake-suspend`
  es solo reserva. `suspend-dispatch` → `systemd-sleep suspend`.
- **FIX (Odin)**:
  1. Quitar el override (`.disabled-20260911` + backups) + `daemon-reload`.
  2. `mem_sleep` = s2idle (`/usr/lib/systemd/sleep.conf.d/10-pocknix-s2idle.conf` +
     `/usr/lib/tmpfiles.d/10-pocknix-mem-sleep.conf`).
  3. Hook `/usr/lib/pocknix/sleep.d/post/004-display`.
- **DOS bloqueos encontrados**:
  - `vhci_hcd` (mando virtual de InputPlumber, target `deck` por USB/IP) → `platform_pm_suspend`
    devuelve `-16` y aborta el suspend. Ya lo resolvía el pre-hook `001-inputplumber`.
  - Al resumir, el panel quedaba negro (`bl_power=4`, `actual_brightness=0`, DPMS On);
    gamescope no lo reactivaba → lo arregla el hook `004-display`.
- **PERMANENTE en `pocknix-os`**: `devices/sm8750/profile.conf` (`mem_sleep_default=s2idle` en
  el cmdline), `overlay/usr/local/bin/pocknix-powerd` (`screen_is_on` lee DPMS del conector
  DSI/eDP/LVDS), `pocknix-bsp-common/display-sleep-post` (pkgrel 14 → `post/004-display`).
- **VERIFICADO**: `systemctl suspend` + alarma RTC duerme los N s y despierta; botón de
  encendido suspende y despierta con pantalla encendida (`bl_power=0`, `actual=3721`).
- **OJO**: probar con `rtcwake -m mem` NO ejecuta los hooks de systemd → InputPlumber no se
  para y el suspend aborta. Usar `systemctl suspend`.
- **VER DETALLE EN**: `SUSPEND-ISSUE.md`.

## 🔗 REPOS, FORK Y PR (11/09/2026)
- **Nuestro repo de soporte** (público): `arcadematicas/pocknix-odin3-support` (`master`).
- **Fork de pocknix-os**: `arcadematicas/pocknix-os`.
  - Rama **`odin3-sm8750`**: nuestro árbol de trabajo completo (9 commits) tal cual.
  - Rama **`odin3-pr`** (rama limpia de PR, partiendo del `main` actual de upstream):
    solo el *enablement* de la familia SM8750 — `kernel/sm8750/` (DTS + serie de
    parches + config), `config/tuning/sm8750.conf`, `devices/sm8750/` (profile +
    `packages.list` + BSP `pocknix-bsp-sm8750` + metapaquete) y
    `packages/soc/{linux-pocknix,pocknix-bootloader}-sm8750`.
  - **`make sync` hecho** contra ROCKNIX `next` clonado en
    `/home/fransis/pocknix-odin3-project/distribution` (shallow, branch `next`):
    `kernel/sm8750` = árbol SM8750 actual de ROCKNIX + nuestro delta. `kernel.conf`
    corregido (`KERNEL_VERSION=7.2`, `ROCKNIX_VERSION_PATCH_DIR=7.2`; antes 7.2.4/
    `default`). Añadido **`0051-adreno-a8xx-force-gx-collapse-before-cx.patch`**
    (regenerado sobre el árbol actual; complementa al 0050 de ROCKNIX). **71 parches
    aplican limpios** con el `apply_patches` estricto (sin fuzz). Quitados los parches
    de batería 0078/0079/0080 (workarounds previos al fix de firmware, van aparte).
  - **`make kernel` OK**: kernel 7.2.0, `Image` + 2 DTBs (odin3 + konkr) + módulos +
    boot image `build/image/sm8750/KERNEL`.
  - **Build de imagen**: `make build` lanzado (log `/tmp/image_odin3pr2.log`). OJO:
    el PC es **x86_64** y el chroot es **aarch64** → se ejecuta bajo **qemu-user**
    (binfmt_misc). El registro `qemu-aarch64` no traía el flag **`C`** (credentials),
    así que el `sudo` dentro del chroot fallaba ("effective uid is not 0") y makepkg
    no instalaba dependencias. **Fix**: override `/etc/binfmt.d/qemu-aarch64-static.conf`
    con flags `FPC` + `systemctl restart systemd-binfmt` (ahora `POCF`, suid OK).
  - **Pendiente**: terminar el build de imagen (lento por qemu), generar la SD y
    probar el arranque en la Odin; luego abrir el PR.
  - **Feedback del creador (issue #54, 12/09) — atendido**: cmdline quiet/plymouth
    (mirror sm8550), README.provenance SM8750 + sha256 correcto, blobs ArmadaOS
    fuera del repo (gitignore; sin binarios), a8xx 0051 confirmado en la rama,
    re-sync 7.2/7.2 con patch dir 20-sm8750. **Pendiente**: probar el
    `adsp_dtb.mbn` actual de ROCKNIX (`qcom/sm8750/ayn/odin3/`, md5 6f4c2eca) en
    la Odin; si la capacidad reporta bien → quitar el nodo `simple-battery` del
    DTS y abrir el PR (deltas sobre su `make sync`).
- **Issue upstream #54** (`shuuri-labs/pocknix-os`): comentario del 11/09/2026 con el
  resumen final (batería + KScreen + suspensión resueltos) y aviso de que estamos listos
  para la fase de merge/PR. https://github.com/shuuri-labs/pocknix-os/issues/54#issuecomment-5633616452
- El mantenedor pidió: (1) pushear la rama del fork que compila, (2) rebasar sobre el árbol
  SM8750 de ROCKNIX actual, (3) PR en la forma espejo de `kernel/sm8550` + entrada de board
  en el `device.conf` de la BSP.

## 🔬 ESTUDIO ARMADAOS (11/09/2026)
- **Informe completo**: `ARMADAOS-STUDY.md`. **Scripts de referencia**: `armadaos-reference/`
  (`libexec-armada/`, `lib-armada/`, `gamescope-session-plus/`, `kernel-config-armada.txt`,
  `packages-armada.txt`, `services-armada.txt`).
- Hecho con la Odin en ArmadaOS (SSH `armada@192.168.4.29`, clave `armada`).
- ArmadaOS = Fedora 44 bootc + ostree + Btrfs + dracut + SDDM + gamescope-session-plus;
  kernel 7.2.3 con configs clave idénticas a las nuestras.
- **Nos falta (prioridad)**: `dbus-update-activation-environment` en la sesión (env KScreen),
  inyección de libs x86 + reparación de mando de `armada-game-launch`, variables
  `STEAM_GAMESCOPE_*`, `armada-powerd` (D-Bus), `controller-type`, MTP, HDR, UCM audio Odin 3.
- **Suspensión**: RESUELTA con s2idle real + hook de pantalla (ver `SUSPEND-ISSUE.md`); el
  `fake-suspend` de ArmadaOS no se usa (solo es su reserva).
  - **Ya portado**: proton-wrapper/FEX, guestos-mount, fex-profiles, scx_lavd, steamos-shim,
    RGB, splash, install-internal.

## 🎮 DECKSTATION EN LA IMAGEN (18/09/2026)

**DeckStation ARM** es un proyecto **independiente de `stshunz`** (no es de Pocknix), pero
nuestra imagen lo instala como capa de emulación. Lo vendored vive en
`packages/deckstation-arm/` (PKGBUILD + updater + scripts) y el árbol de compilación lo
tiene completo en `packages/shared/deckstation-arm/`.

- **Documentación autoritativa**: `stshunz/deckstation-arm` →
  `CAMBIOS-REALIZADOS.md` (secciones 8-11), `configs/README.md`, `bios/README.md`,
  `docs/INSTALACION.md`, `updater/README.md`. Y la sección "DeckStation" de
  `/home/fransis/pocknix-odin3-project/AGENTS.md`.

### 🔑 ARQUITECTURA DE INSTALACIÓN (21/09/2026) — "dos puertas, un motor"

> **El motor vive en los scripts; la GUI va encima.** Así una avería de pygame no deja
> al usuario sin poder instalar (ya pasó: `SDL_VIDEODRIVER=x11` forzado → ventana
> invisible, y el Updater no se podía usar).

| | Quién | Qué hace |
|---|---|---|
| **INSTALAR** (una vez) | Pocknix Tools → `deckstation-setup.sh` | entorno + **los 30 emuladores** (`updater.py --install-all`, headless) + `lanzar.sh` + configs + BIOS |
| **GESTIONAR** (siempre) | Updater GUI (ES-DE → Updater) | actualizar / instalar sueltos / **estado de BIOS** |

- **`updater.py --install-all`** (headless): instala todos los que falten, con progreso y
  **resumen de fallos**. Fuerza `SDL_VIDEODRIVER=dummy` **antes de importar pygame** (el
  módulo hace `display.set_mode()` al cargarse → si no, `No available video device`).
  Devuelve 0/1. Reutiliza el MISMO motor que la GUI (no hay dos lógicas de descarga).
- **Tolerancia a fallos**: `_download_worker` es un **envoltorio** de `_descargar()`.
  Dentro hay **13 `return` de error** que abortaban la cola entera; ahora se detectan con
  `_descarga_correcta`, se apuntan en `_install_fallidos` y **se sigue con el siguiente**.
  El éxito avanza la cola dentro de `_descargar` (no hay doble avance).
- **Config base reproducible**: `scripts/deckstation-configs.sh` +
  `configs/deploy-manifest.txt` despliegan la config en cada emulador (lo llaman el setup
  y el launcher). Ya **no** hace falta el payload de MediaFire del Updater (era x86_64).
- **⚠️ Los emuladores instalados por el Updater quedaban INLANZABLES** (arreglado
  21/09): `es_find_rules.xml` apunta a `Apps/<Emulador>/lanzar.sh` (34 sitios), y el setup
  desplegaba esos wrappers **antes** de que el Updater descargara nada → sin `lanzar.sh`
  ni `.home`/configs. Ahora `scripts/deploy-lanzar-sh.sh` (idempotente) lo despliega desde
  **tres** sitios: el setup (2ª pasada tras cerrar el Updater), el launcher (auto-reparación
  en cada arranque) y el propio Updater (`_preparar_portable`, tras cada instalación).
- **BIOS**: solución externa en `bios/` (copyright: el usuario pone sus ficheros).
  - `bios/required.txt` = qué fichero espera cada sistema (+ **alternativas**: cualquier
    BIOS de PSX vale) y `bios/deploy-bios.txt` = a dónde va cada sistema.
  - `deckstation-bios.sh --check` → **informe**: cuántas tienes, cuáles faltan y el destino
    de cada una. También en la GUI (Updater → **BIOS / Firmware**) y en Pocknix Tools
    (**DeckStation BIOS**).
- **Cores**: Suyu (Switch) necesita las claves en `<retroarch>/system/suyu/keys/`, y tanto
  Suyu como GooseStation (PSX) necesitan su `<command>` en `es_systems.xml`.
- **⚠️ Gap**: el paquete `suyu-libretro` **no está en `devices/sm8750/packages.list`** →
  el core de Switch no entra en la imagen. Pendiente.
- **Ojo con el sync**: `tools/sync-to-os.sh` usa `rsync` **sin `--delete`** → los ficheros
  editados a mano en el árbol sobreviven; los ficheros nuevos del centro se añaden.
- **📋 PORTABILIDAD A OTRAS DISTROS: analizado, documentado y NO implementado** (decidido el
  21/09/2026). Ver **`stshunz/deckstation-arm` → `docs/PORTABILIDAD-DISTROS.md`** (sincronizado
  al centro en `packages/deckstation-arm/docs/`). Resumen: el **motor ya es portable** (ES-DE se
  baja de ES-DE oficial, los emuladores de upstream, **libXss se cosecha del runtime de Steam**,
  `$HOME` con `getent`); lo que ata a Arch son **4 puntos** con fichero y línea (el `pacman` de
  `check_dependencies`, las rutas de cores, el empaquetado y un mensaje). Se haría con un
  `pkg_install()` que abstraiga el gestor + un `install.sh` portable (~1 día). **No se hace hasta
  que alguien lo pida**: no hay demanda y no se puede probar sin una Ubuntu/Fedora ARM reales.
  Lo barato y sin riesgo, si se toca: las rutas de cores y el mensaje.
- **⚠️ Al copiar el `PKGBUILD` de `stshunz` al centro, comprobar `pkgrel`**: divergen (el
  21/09 se revirtió un `pkgrel=4` que solo existía en el centro).

## 💾 ALMACENAMIENTO: ext4 vs F2FS en la UFS interna — PENDIENTE DE REVISAR (18/09/2026)

**Análisis completo en `docs/IDEAS.md` §6.** Resumen:

- **Medido**: raíz btrfs en microSD → **~82 MB/s** de lectura secuencial (`dd iflag=direct`).
  Es el techo real para cargar juegos. No hay ningún dato de la UFS interna todavía.
- **F2FS en la raíz de la microSD → 🔴 DESCARTADA**: perdería snapshots/rollback
  (`pocknix-snapshots` + `pocknix-rollback` + hook alpm), checksums y compresión zstd; y en
  una SD el controlador ya hace wear-leveling/FTL. *(ArmadaOS tiene F2FS en el kernel y
  empaqueta `f2fs-tools`… pero su raíz es Btrfs.)*
- **F2FS en el root de la UFS interna → 🟡 A REVISAR**: `pocknix-install-internal` **ya existe**
  y clona a la UFS interna **en ext4** — o sea que **ya pierde los snapshots** → F2FS ahí **no
  perdería nada en seguridad** y sí ganaría su gestión de flash donde el SO ve el dispositivo.
- **`read_ahead_kb` 128→512 → 🔴 DESCARTADA por medición**: 128 KB → 6303/6329 ms vs
  512 KB → 6340/6378 ms (fichero de 536 MB, caché frío, 3 pasadas alternando). Sin diferencia.
- **Ya implementado (18/09)**: `f2fs-tools` en `config/packages/base.list`; `nodatacow` en
  `steamapps` (`chattr +C`) + `/var/log` + `/var/cache/pacman` (tweak de ArmadaOS que no
  teníamos). Commits `64bc7e0` (árbol) y `c6d99bd` (centro).

**Siguiente paso si se retoma**: leer `pocknix-install-internal` (reparto de la UFS + clonado +
`pocknix-expand-root`), decidir `ext4` vs `f2fs` y **medir con `fio` en la UFS interna**.

## ⏳ FRAME LIMITER DEL QAM — PROBAR ESTA NOCHE (anotado 18/09/2026)

**Contexto**: el selector de FPS del QAM (24/30/60) se diagnosticó el 09/09 como "solo UI" —
se creyó que el cliente Steam ARM64 no comunicaba el límite a gamescope por **ningún** canal
(atom, protocolo Wayland, D-Bus, fichero) y se aplicó un workaround **fijo a 60**
(`gamescopectl debug_set_fps_limit 60` en `pocknix-steam`).

**Estado verificado el 18/09**:
- El workaround **YA NO ESTÁ** en `pocknix-steam` (se quitó el 16/09) ni en ningún otro sitio.
- El atom `GAMESCOPE_FPS_LIMIT` marca **60**.
- El parche `fps-limit-atom-persist` **sí está aplicado** (gamescope `3.16.25-7-g6644cc9a+`).
- **🔑 Hallazgo nuevo**: Steam **SÍ persiste** el límite por app en
  `~/.local/share/Steam/userdata/<id>/config/localconfig.vdf` →
  `"Gamescope" { "AppTargetFrameRate" { "<appid>" "<fps>" } }`.
- El shim `pocknix-steamos-manager` **no** expone nada de fps.

**TEST (30 s, necesita UI)**:
1. Game Mode → QAM → cambiar el límite de FPS a **30**.
2. Comprobar: (a) `localconfig.vdf` → ¿30? · (b) `DISPLAY=:0 xprop -root | grep GAMESCOPE_FPS_LIMIT`
   → ¿30? · (c) ¿el juego va a 30?
3. **Interpretación**: si cambia el atom → **ya funciona**, cerrar el tema. Si **solo** cambia
   el fichero → **implementar el daemon**: vigilar `localconfig.vdf` (inotify) + el atom
   `GAMESCOPE_FOCUSED_APP` y aplicar con `gamescopectl debug_set_fps_limit <fps>` (el parche de
   gamescope ya hace persistir el atom). **Ya sabemos de qué fichero leerlo** — era la pieza que
   faltaba en el diagnóstico del 09/09.

**⚠️** El atom a 60 **no prueba nada** (el 09/09 ya se vio 60 sin que Steam lo escribiera).

## 🎨 STACK GRÁFICO — Mesa / Turnip (18/09/2026)

**Qué tenemos** (paquetes en `pocknix-os/packages/soc/`, versiones en el centro solo como
`soc-overrides/<name>/socs` para añadir `sm8750`):
- **`mesa`** → `pkgname=(mesa vulkan-freedreno)`, build propio desde el tarball de
  `archive.mesa3d.org` (recortado para handhelds, tuned cortex-x3). Ahora **26.2.3**.
- **`pocknix-turnip-arm`** → instala **una build de Turnip por rama upstream** en
  `/usr/share/pocknix/vk-arm/<version>/libvulkan_freedreno.so` + su `icd.json`:
  `25.0.7 25.1.9 25.2.8 25.3.6 26.0.8 26.1.6 26.3.0devel`.
  El `26.3.0devel` es un **snapshot fijo de mesa main** (`_develcommit`) — la vía para "ir
  siempre a la última" **sin arriesgar el driver del sistema**.
- **`pocknix-turnip-x86`** → equivalente x86_64 para apps bajo FEX.

**Cómo se usa la versión por juego**: PocknixControl → pestaña **Games** → elegir juego →
activar **"Use Per-Game Settings"** → aparece **"Mesa Version"** (el plugin apunta
`VK_DRIVER_FILES` a esa versión). ⚠️ **No está en el menú global del QAM** — es por juego y
está oculta hasta activar ese toggle.

**Herramienta**: `tools/check-mesa.sh` — compara upstream con lo nuestro y avisa (Mesa
estable, ramas en `_versions`, `_develcommit` vs el HEAD de main). Solo informa.

**Actualizar**:
1. `tools/check-mesa.sh` → ver qué está desfasado.
2. Mesa del sistema: bumpear `pkgver` + `sha256sums` en `pocknix-os/packages/soc/mesa/PKGBUILD`.
   **Mirar antes las notas del release** (`docs.mesa3d.org/relnotes/<v>.html`): si no trae
   nada de **freedreno/Turnip**, no merece la pena el rebuild.
3. Turnip devel: refrescar `_develcommit` (+ `pkgver`) en `pocknix-turnip-arm/PKGBUILD`.
4. Compilar: `sudo make packages PKG="mesa pocknix-turnip-arm"` (**necesita root**;
   `pocknix-turnip-arm` compila **una Mesa por rama** → build muy largo).

**Notas de hardware (Adreno 830 / Gen8)**:
- El problema histórico era que Turnip **no cargaba** en Gen8; se resolvió con Turnip
  **v26.1.0+**. ⚠️ Las builds **25.x probablemente NO funcionan** en esta GPU — no tiene
  sentido probarlas por juego.
- No hay issues abiertos de *stutter* con Vulkan en Adreno 8xx; en RetroArch seguimos con
  `glcore` (OpenGL) como workaround.
- **ROCKNIX está en Mesa 26.2.0** → vamos por delante. **Mesa 26.3** sale en noviembre 2026.

  **✅ HECHO (20/09/2026) — INSTALADO EN LA ODIN**:
  ```
  mesa              2:26.2.2-1  →  2:26.2.3-1
  vulkan-freedreno  2:26.2.2-1  →  2:26.2.3-1
  pocknix-turnip-arm  20260904  →  20260918
  ```
  Verificado con `vulkaninfo --summary`: `driverName = turnip Mesa driver`,
  `driverInfo = Mesa 26.2.3-pocknix2.1`, `deviceName = Adreno (TM) 830`,
  `apiVersion = 1.4.354`.

  **⚠️ Al compilar: `DEVICE=sm8750` es obligatorio** (`sudo make packages PKG="mesa
  pocknix-turnip-arm"` a secas va al repo `sm8550`). **La Mesa nueva solo entra en
  procesos nuevos** → hay que reiniciar sesión/reiniciar para que la use la sesión.

  **Si makepkg falla con "Integrity checks (sha256) differ in size from the source array"**:
  al añadir un `source=` hay que añadir su entrada en `sha256sums=` (un `SKIP` vale para
  parches).

## 🔴 KERNEL: 7.2.6 DESCARTADO → 7.2.4 + ROTACIÓN (18/09/2026)

**Ver `docs/PENDIENTE-2026-09-18.md` para el detalle completo.**

### Decisión
El **7.2.6 tiene 2 regresiones de mainline** que lo hacen inviable en la Odin 3:

1. **Display (panel negro)**: `dsi_calc_clk_rate_6g()` (7.2.5+) añade `clk_round_rate()`
   del byte clock y **sobrescribe** `byte_clk_rate` → el pixel clock deja de cuadrar →
   `Failed to set rate pixel clk, -22` → panel negro + bucle de
   `dpu_encoder_frame_done_timeout` → la red nunca sube (parece que no arranca).
   Revertir `dsi_host.c` a 7.2.4 lo arreglaba ✅ (**el display arrancó**).
2. **WiFi**: `ath12k_wifi7_pci ... failed to set mhi state: POWER_ON(2)` →
   `failed to start mhi: -110` → `probe with driver ath12k_wifi7_pci failed with error -110`
   (timeout del MHI a los ~90 s → no hay `wlan0`). Revertir el **driver ath12k completo**
   a 7.2.4 **NO bastó** → el fallo está en el **MHI** (`drivers/bus/mhi/host/*`) y/o
   **`pcie-qcom.c`**, que también cambiaron. (Ese revert combinado está generado y
   aplica limpio, pero no llegó a compilarse.)

**Los parches de rotación NO eran los culpables** (un 7.2.6 sin rotación fallaba igual).

### Estado actual (lo compilado y flasheado)
```
Base:    linux-7.2.4  (sha256 01710ee01737dac492f1bae52becd057e08d20d11589089aa06accff415c28dd)
Parches: 98 (05-speedup 22 + 10-mainline 5 + 20-sm8750 66 + 30-version 5), 0 conflictos
KERNEL:  18.964.480 bytes, md5 204c05194598
```
Los **3 parches de rotación** aplican **sin offset** y están verificados en el árbol:
`0013` (infra inline rotation), `0067` (QSEED detail enhancer), `0068` (rotación sm8750).
Commit **`bc08546`** en `pocknix-os` rama `odin3-sm8750`.

> ⚠️ **Cómo verificar parches**: mirar el **árbol de fuentes**
> (`build/kernel/sm8750/linux-7.2.4/`), **no** la imagen `KERNEL` (está comprimida).
> `rot_v2` no sirve de marcador (es upstream). Ojo con mayúsculas (`QSEED` ≠ `qseed`).
> **`rot_maxheight` no lo añade ningún parche nuestro.**

### 🚨 La SD se corrompió (btrfs) — 18/09/2026
Al copiar los módulos 7.2.4 saltó `Error de entrada/salida`; dmesg:
`BTRFS error (device sde2): parent transid verify failed ... wanted 4292 found 4279`.
El `btrfs check` mostró patrón de **rollback** (`Extent back ref already exists` +
transid mismatch) — probablemente **la Odin restauró un snapshot** al arrancar
(hay `@snapshots/0006`…`0010`). El montaje normal ya no funciona.

**Leer los datos**:
```bash
sudo mount -o ro,rescue=all /dev/sde2 /mnt                      # subvol @
sudo mount -o ro,rescue=all,subvol=@home /dev/sde2 /mnt2        # @home
```
**Backup hecho** en
`/run/media/fransis/ROMS16TB/proyectos Alfred/pocknix-odin3/backup-sd-2026-09-18/`
(`home-deck/` 38 GB + `etc/` + `root/` + `var_lib_pacman/`).
El **KERNEL del FAT está intacto** (vfat) → el flasheo funcionó.
**Pendiente**: `btrfs check --repair` vs re-flashear la imagen + restaurar.

### ✅ RESULTADO (20/09/2026) — TODO RESUELTO, objetivo cumplido

Se hizo todo lo pendiente del domingo y más. **Detalle completo de la rotación en
`docs/ROTACION-HARDWARE.md`**; resumen de la sesión en `docs/PENDIENTE-2026-09-20.md`.

| Qué | Resultado |
|---|---|
| **SD** | Estaba **irrecuperable** (`btrfs check --repair` no basta). **Re-flasheada** + FAT reformateado (estaba corrupto) + expandida a 119G + home/`opt` restaurados. Ver `docs/PENDIENTE-2026-09-18.md` y `tools/reflash-sd.sh` |
| **Display/WiFi** | ✅ El 7.2.4 + rotación arranca; WiFi, audio y mando OK |
| **Rotación por hardware** | ✅ **CONSEGUIDA** — `rotation=8` (`ROTATE_270`) en los planos activos → rota el DPU en scanout. Parche `packages/soc/gamescope/0010-…`, commit `51c8def` |
| **gamescope** | Decisión tomada: **rebasado el parche** (no subir a `fa0b4d33`). Aplica con 0 hunks fallidos. Versión resultante `6644cc9-5` |
| **ABL 1.1.8** | ✅ **Ya estaba flasheado** en ambos slots (`state=uptodate`); solo el kit estaba en 1.1.7 |
| **Mesa 26.2.3 + Turnip** | ✅ Instalados y verificados con `vulkaninfo` |
| **BTF (rompía los módulos)** | ✅ Fix con `DEBUG_INFO_DWARF4`, commit `6d9f751` |

### ⏳ Sigue pendiente (no era de esta sesión)
1. **Frame limiter del QAM** — validar con un juego (ver sección propia arriba).
2. **ext4 vs F2FS** en la UFS interna (`docs/IDEAS.md` §6).
3. **Carga de batería** (`charge_enable`, opcode 0x16 vs 0x33) — no es nuevo.
4. (Menor) Reiniciar para que la Mesa nueva entre en la sesión.

## 📦 CÓMO SE AÑADEN PAQUETES (20/09/2026) — LEER ANTES DE TOCAR `config/packages/`

La imagen va sobre un **snapshot CONGELADO de ALARM** (`[pocknix-base]`, generado por
`make snapshot` desde `base.list` + `base-extras.list`) y debajo lleva el **ALARM en vivo**
como fallback (`render_pacman_conf` añade `[core] [extra] [alarm] [aur]`).

### Las dos listas

| Lista | Qué hace |
|---|---|
| **`config/packages/base.list`** | **INSTALADO en la imagen** (y cosechado al snapshot). Para lo que la imagen ship pea. |
| **`config/packages/base-extras.list`** | Solo **HOSPEDADO** en el snapshot: ningún imagen lo instala, pero un dispositivo puede hacer `pacman -S` y lo resuelve de `[pocknix-base]` (versión PINNEADA, no la del ALARM en vivo). Para opt-in (samba, tailscale, la capa de emulación de upstream…). |

**Regla**: *"the harvest only sees what a build installed"* → `base.list` se cosecha
automáticamente; para lo que NO se instala hay que listarlo a mano en `base-extras`.

### ⚠️ Las tres trampas (todas vividas)

1. **NUNCA** poner un paquete de ALARM como **`depends` de un paquete nuestro**.
   El chroot de COMPILACIÓN (`build-packages.sh`) solo ve los repos de pocknix → `makepkg`
   falla con `Missing dependencies` (pasó con `libxss` en `deckstation-arm`). El `depends`
   solo es viable si el paquete está **hospedado en `[pocknix-base]`** (o sea, si está en
   `base.list`/`base-extras` y el snapshot se ha regenerado).
2. **`pacman -S <pkg>` sin `-y`** falla en imagen recién flasheada (`/var/lib/pacman/sync/`
   vacío). Y **`-Syu` es un landmine** sobre base congelada: sube ~260 paquetes (systemd
   incluido). Usar `pacman -Sy --needed <pkg>`.
3. **Familias con epoch**: `samba` declara `smbclient>=4.24.7` sin epoch y el instalado es
   `2:4.24.6` → pacman da la dep por satisfecha y NO lo actualiza → símbolos rotos
   (`SAMBA_4.24.7_PRIVATE_SAMBA not found`). **Instalar la familia entera junta.**

### Dónde va cada cosa (decidido 20/09)

| Necesidad | Solución |
|---|---|
| Lo que la imagen ship pea (RetroArch de DeckStation → `libxss`) | **`base.list`** → `libxss` ✅ |
| Opt-in del usuario (samba, tailscale) | `base-extras.list` ✅ + instalación robusta (`-Sy`, familia junta) ✅ |
| Host sin el paquete y sin repos | provisioning en el propio tool (p. ej. `setup_libxss` en DeckStation) ✅ |

### Y la trampa del veto: la capa vendored y `config/` NO están en el centro

`tools/sync-to-os.sh` sincroniza paquetes/overlay/kernel, y `check-sync.sh` ya comprueba
la capa vendored (deckstation-arm, pocknix-steam, tools, suyu…). **`config/` solo vive en
el árbol** (nuestro fork lo commitea allí) → editarlo en el árbol y **commitearlo ahí**.

## ✅ SCHEDULERS CPU + I/O — IMPLEMENTADO (24/09/2026)

**Estado**: Fase 1 (scheduler sched_ext) + Fase 2 (bfq microSD) **implementadas y verificadas
en la Odin**. Perfiles QAM enlazados al scheduler: **implementado en el centro, pendiente de
deploy + verificación en vivo** (commit `cb0ea84`).

### Cómo funciona
- **`/usr/bin/pocknix-scx-mode`** (paquete `pocknix-bsp-common`, pkgrel 19): get/set/toggle/run
  del scheduler sched_ext. Schedulers ofrecidos: **lavd** (autopilot/performance/balanced/
  powersave) y **bpfland** (default/performance/powersave). Estado persistido en
  `/var/lib/pocknix/scx-mode` como `"<sched> <mode>"`. **rusty DESCARTADO**: scx_rusty 1.1.2 no
  carga en kernel 7.2.4 (`kptr already had cpumask`, main.bpf.c:119).
- **`pocknix-scx.service`** (daemon, alias `pocknix-lavd.service` por symlink): corre
  `pocknix-scx-mode run`, que hace polling cada 3 s de `/var/lib/pocknix/scx-mode` + el
  per-game `/run/pocknix/game-mode` (pid fan lavd — solo aplica si el scheduler efectivo es
  lavd). `StartLimitBurst=20` + fallback `reset-failed` en `do_set` (con 5, 3 cambios rápidos
  bloqueaban el servicio).
- **bfq**: udev rule `60-pocknix-io-scheduler.rules` → `mmcblk[0-9]` = bfq. UFS `sda` intacta
  en `mq-deadline`. NO tocar governor cpufreq (`schedutil`) ni read_ahead.
- **Perfiles QAM → scheduler** (en `/usr/local/bin/pocknix-power-profile`, función
  `apply_scx`): `bajo`→`bpfland powersave`, `medio`→`lavd autopilot`, `alto`→`lavd
  performance`. Se aplica al set y al `restore` (boot). **Override manual**: si existe
  `/var/lib/pocknix/scx-manual`, el perfil NO toca el scheduler.
- **Plugin PocknixControl** (pkgrel 44): selector Scheduler con **"Auto (perfil QAM)"**
  (default) + Scheduler Mode (oculto en auto). Elegir lavd/bpfland a mano crea el flag
  manual; volver a "auto" lo borra y re-aplica el perfil actual (el mapeo vive SOLO en
  power-profile). `scxEffective` en el config muestra el scheduler real en auto.
- **Diagnóstico**: `/usr/bin/pocknix-scx-diag` (scheduler activo, state, flag manual, perfil,
  servicios, block schedulers).
- **Deploy rápido**: `tools/deploy-schedulers.sh [--bsp|--plugin]` (scp + `sudo -S pocknix`;
  reinicia el loader de Decky solo si Steam NO está en modo juego).

### Verificado en la Odin (Fase 1+2)
lavd→bpfland→bpfland performance→lavd OK (`/sys/kernel/sched_ext/root/ops`); backend del
plugin como root OK; 3 cambios rápidos ya no bloquean; estado final lavd autopilot activo;
`mmcblk0=[bfq]`, `sda=[mq-deadline]`.

### Pendiente
- Deploy de perfiles QAM (power-profile + plugin) con `tools/deploy-schedulers.sh` y
  verificación en vivo: cambiar perfil en el QAM → scheduler cambia; fijar manual → el perfil
  no lo pisa; volver a Auto.
- **NO tocar**: governor cpufreq (`schedutil` es el correcto con scx_lavd), read_ahead SD
  (medido sin diferencia), UFS interna (dejar `none`).
## IDEAS FUTURAS (pendientes de implementar)

### 🍋 LEPTON (juegos Android en ARM64) — 🗄️ APARCADO (25/09/2026), reabrir en el futuro
- **Qué es**: capa de Valve para ejecutar juegos Android en Linux ARM64 (creada para el Steam Frame).
  52/130 juegos del Frame lo usan. Tercer pilar: Proton (Windows) + FEX (x86) + Lepton (Android).
- **Repo**: `https://gitlab.steamos.cloud/frame-public/lepton/` — clon local `/home/fransis/lepton/`.
- **Viabilidad en Odin 3**: BUENA — binder+binderfs ya activos en nuestro kernel (build-kernel.sh),
  Waydroid 1.6.3 + lxc instalados, Turnip OK. Falta: **podman** + construir la imagen Android
  (do_build.sh, build AOSP pesado).
- **DECISIÓN (25/09/2026)**: 🗄️ **aparcado** — primero explotar el repo Deckard (binarios listos,
  ver Referencias útiles). Reabrir cuando toque.
- **Detalle**: memoria persistente (sección LEPTON) + `/home/fransis/lepton/`.

### 💾 Almacenamiento: ext4 vs F2FS en la UFS interna — 🟡 REVISAR (18/09/2026)
- **Análisis completo**: `pocknix-odin3-support/docs/IDEAS.md` §6 (+ sección "ALMACENAMIENTO"
  del `AGENTS.md` del centro).
- **Medido**: raíz btrfs en microSD → **~82 MB/s** lectura secuencial. Techo real para cargar
  juegos. No hay datos de la UFS interna todavía.
- **🔴 F2FS en la microSD: descartado** (perdería snapshots/rollback + checksums + compresión;
  y en SD el controlador ya hace wear-leveling). *ArmadaOS tiene F2FS en el kernel y su raíz
  es Btrfs.*
- **🟡 F2FS en el root de la UFS interna: a revisar** — `pocknix-install-internal` **ya existe**
  y clona a la UFS **en ext4**, o sea que **ya pierde los snapshots** → F2FS ahí no perdería
  nada en seguridad. Decidir `ext4` vs `f2fs` y **medir con `fio`**.
- **🔴 `read_ahead_kb` 128→512: descartado por medición** (6303/6329 ms vs 6340/6378 ms —
  sin diferencia; la SD está limitada por ancho de banda, no por latencia).
- **✅ Ya implementado (18/09)**: `f2fs-tools` en `base.list`; `nodatacow` en `steamapps`
  (`chattr +C`) + `/var/log` + `/var/cache/pacman`. Commits `64bc7e0` / `c6d99bd`.

### Mako Decky (Lossless Scaling para Linux) — ❌ NO FUNCIONA en la Odin 3
- **Repo**: https://github.com/eugeniosegala/MAKO
- **Qué es**: plugin Decky que implementa Lossless Scaling (Frame Generation) en Linux.
- **Integración**: ✅ HECHA — `pocknix-decky` (pkgrel 31). Plugin en `/usr/share/decky-plugins/Mako`, sincronizado a `~/homebrew/plugins/Mako`. **Toggle por juego** en Pocknix Control → Games → "MAKO (Lossless Scaling frame gen)" (commit `148d954`).
- **Lossless.dll** (software de PAGO — **nunca al repo**): MAKO la lee en runtime de una instalación legal del usuario, en `~/.local/share/Steam/steamapps/common/Lossless Scaling/Lossless.dll`. Instalador en `pocknix-tools` → "Install Lossless Scaling DLL (MAKO)..." (commit `c31e2bc`).
- **❌ BLOQUEO DEFINITIVO (15/09/2026)**: el Renderer de MAKO es **x86_64**, pero en la Odin los juegos x86_64 corren con Proton ARM64 + **FEX**, y FEX **thunkea** Vulkan al stack **aarch64 del host** (`/run/host/usr/lib/libvulkan.so` + Turnip). Las capas Vulkan deben ser **aarch64** → la capa x86_64 de MAKO **no puede cargarse** (`VK_LOADER_DEBUG`: `cannot open shared object file`; `ctypes.CDLL` desde aarch64 falla). **No hay configuración que lo arregle.**
- **El autor ya lo sabe** ([issue #15](https://github.com/eugeniosegala/MAKO/issues/15)): *"MAKO currently ships an x86-64 Renderer... does not support AArch64 devices yet. I will work on this as a new feature."*
- **DECISIÓN (15/09)**: **esperar el Renderer AArch64** (integración ya lista) + **issue en MAKO** pidiendo estado/roadmap y ofreciendo la Odin 3 para probar → **https://github.com/eugeniosegala/MAKO/issues/60**.
- **📄 Documentación completa**: `pocknix-odin3-support/MAKO-AARCH64.md`.
- **Al llegar el AArch64**: re-vendorizar el plugin, **borrar `mako-aarch64.patch`** + su línea `patch` del PKGBUILD, rebuild de imagen.

### Proton CachyOS ARM64 (instalado 10/09/2026)
- **Archivo**: /run/media/fransis/ROMS16TB/proton-cachyos-11.0-20260703-slr-arm64.tar.xz
- **Ubicación instalada**: ~/Downloads/deckstationARM/Apps/wproton/runtime-aarch64/proton-cachyos-11.0-20260703-slr-arm64/
- **Versión**: Proton 11.0 (CachyOS, ARM64)

### Estado de la carga de batería (✅ RESUELTO)
- **RESUELTO 10/09/2026**: la batería carga en Pocknix. Fix = copiar los 2 ficheros de firmware de
  ArmadaOS (`adsp.mbn` `6cfcbbb8` + `adsp_dtb.mbn` `d88d7ecb`) a `/lib/firmware/qcom/sm8750/`.
  La clave era el `adsp_dtb.mbn` (config de autenticación de batería del ADSP).
- Causa raíz: el firmware entraba en TEST MODE (estado 9) porque no podía autenticar la batería.
- Pendiente: hacerlo permanente en la imagen/build de Pocknix.
- Documentado en BATTERY-ISSUE.md + issues #54 (Pocknix) y #402 (ArmadaOS).

## 🔥 FIRMWARE IMAGEN LIMPIA — RESUELTO (13/09/2026) — commit fbe787e

- **SÍNTOMA**: una **imagen limpia** de Pocknix arrancaba pero **sin WiFi, sin sonido**,
  con boot lentísimo y pantalla negra. (La instalación interna funcionaba porque los
  blobs se habían copiado a mano.)
- **CAUSA**: `linux-firmware` NO trae los blobs del Odin 3:
  - WiFi: el chip es **WCN7860**, el driver busca `ath12k/WCN7860/hw2.0/`; el rootfs
    solo tenía `WCN7850/` y upstream no tiene WCN7860 → probe `-110`, no hay `wlan0`.
  - ADSP/CDSP: el DTS pide `qcom/sm8750/ayn/odin3/` pero el override ponía `qcom/sm8750/`.
  - Audio: faltaban `aw883xx_acf.bin` (altavoz) y `SM8750-AYN-tplg.bin` (topology DSP).
- **FIX (commit `fbe787e`, rama `odin3-pr`)**: el firmware se baja de
  **`ROCKNIX/extra-firmware`** (commit pinnado `30c56e2`) en `make sync` →
  `vendor/rocknix-extra-firmware/` (gitignored, sin binarios en el repo);
  `install_firmware()` para sm8750 lo rsyncea a `/usr/lib/firmware/`. Override ADSP
  movido a `devices/sm8750/firmware/qcom/sm8750/ayn/odin3/`.
- **TAMBIÉN en `fbe787e`**: `pocknix-flathub.service` ya no bloquea el boot (quitados
  `After=/Wants=network-online.target`; antes descargaba >300 MB de Flatpaks dentro de
  la transacción de boot → sesión de Steam no arrancaba).
- **VERIFICADO EN CALIENTE**: WiFi 5 GHz OK, adsp/cdsp `running`, tarjeta `SM8750AYN`,
  PipeWire OK, **login de Steam OK**, carga OK.
- **OJO SD**: la tarjeta de pruebas se desconectó sola (hub/USB) y corrompió el btrfs.
- **Config de la SD de pruebas** (NO va en la imagen): keyfile NM **+ `/var/lib/iwd/<SSID>.psk`**
  (NM usa iwd de backend y NO le pasa la PSK del keyfile), SSH on + `PermitRootLogin yes`,
  password root `pocknix`.
- **DETALLE**: `pocknix-odin3-support/FIRMWARE-ISSUE.md`.
- **ESTADO 13/09 noche**: `make build` terminado + `make sd-image` en marcha (imagen
  nueva lista para flashear/probar). Pendiente: validar la imagen limpia → PR.

## ✅ ARRANQUE + OOBE — RESUELTOS (14/09/2026) — commits `e574b2a`/`b88018d`/`d13f65d`

- **Arranque lentísimo + pantalla negra → RESUELTO** (commit `e574b2a`):
  - `pocknix-diag.service` bloqueaba `multi-user.target` (WantedBy + After + sleep 30)
    → ahora es un **timer** (`pocknix-diag.timer`, `OnBootSec=45s`, `WantedBy=timers.target`).
  - gamescope arrancaba antes del panel DSI (race condition) → `pocknix-steam` ahora
    **espera a que el conector DSI reporte `connected`** (máx 30 s, gate DRM).
  - **Resultado**: `Startup finished in 11.2s (kernel) + 9.5s (userspace) = 20.7s`;
    `is-system-running` = `running` (antes `starting`).

- **OOBE de Steam (asistente inicial) — RESUELTO** (commits `b88018d` + `d13f65d`):
  - Faltaba `/etc/steamos-oobe-image` → el cliente no lanzaba la OOBE. Fix: marker
    instalado por `pocknix-steamos-shim`.
  - **Bug grave**: `steamos-update apply` devolvía **0** → Steam interpretaba "update
    applied" → `system restart required` → **bucle de reinicio infinito** durante la OOBE.
    Fix: `apply` ahora devuelve **7** (no update), igual que el script real de Valve.
  - Shims afectados: `steamos-update` + `steamos-mandatory-update`. pkgrel 8→9.
  - Verificado: OOBE completa, sin reinicio, llega al login.

- **Docs nuevos en `pocknix-odin3-support/`**: `BOOT-OOBE-ISSUE.md` (diagnóstico),
  `PR-DESCRIPTION.md` (texto para el PR upstream en inglés). `README.md` actualizado.

## ✅ PR UPSTREAM — HECHO (14/09/2026)

- **PR #81** abierto en `shuuri-labs/pocknix-os` (rama `odin3-pr`):
  https://github.com/shuuri-labs/pocknix-os/pull/81 — comentado el issue #54.
- Incluye TODO el soporte del Odin 3 (kernel, firmware, boot, OOBE). Texto en
  `pocknix-odin3-support/PR-DESCRIPTION.md`. **Proyecto upstream aparcado.**

## 🎮 INTEGRACIÓN DeckStation + WProton — HECHA (15/09/2026) — rama `odin3-sm8750`

- **Rama de trabajo: `odin3-sm8750`** de `arcadematicas/pocknix-os` (kernel 7.2.4 + mods
  propios). NO usar `odin3-pr` (rama limpia del PR, kernel 7.2.0 — divergidas).
- **Emulación de Pocknix ELIMINADA** (`pocknix-emulation{,-full}` + 15 emuladores: es-de,
  azahar, dolphin-emu, cemu, armsx2/rpcs3/eden/xemu/vita3k-bin, libretro/retroarch, wxwidgets).
  DeckStation es ahora la capa de emulación. Commit `c4444e0`.
- **`deckstation-arm`** (vendored de `stshunz/deckstation-arm`) → `/opt/deckstation/` + comando
  `deckstation` + `.desktop` (SOLO ES-DE; los emuladores se lanzan desde ES-DE).
- **`wproton-arm`** (vendored de `stshunz/WProton_ARM`) → `/opt/wproton/` + comando `wproton`.
- **`pocknix-tools`** → nueva opción **"Download DeckStation (emulators)..."** (descarga ~1 GB
  opcional, NUNCA en el arranque). Commit `75905b6`.
- `build-image.sh` instala los 2 paquetes (en vez de la capa de emulación); `build-sd-image.sh`
  hace **`chown deck`** de `/opt/deckstation` + `/opt/wproton`.
- **Sync de `stshunz/deckstation-arm`** con la Odin: `es_find_rules.xml` → `./Apps/*/lanzar.sh`,
  `retroarch.cfg` sanitizado (+aarch64), `es_settings.xml`, `deploy_lanzar_sh` en el setup.
  Commits `84016bf`/`e7bed9b`/`51c7540`.

## 🐛 ARRANQUE / APAGADO — RESUELTOS (15/09/2026)

- **Boot 2min15s → 14.4s**: `odin3-splash`/`odin-ulog-boot` a `Type=simple` + `dhcpcd@wlan0` fuera.
- **Apagado rápido**: `iwd` enmascarado + `dhcpcd` fuera (se acabó el flapping WiFi).
- **"Reiniciar" desde Steam reinicia la consola**: `pocknix-steam` lee el sentinel + regla polkit
  `50-pocknix-deck.rules` instalada.
- **Pantalla negra tras crash de Steam → auto-recuperable**: `trap cleanup EXIT` mata gamescope.
- Detalle en `pocknix-odin3-support/config/session-fixes.md` (#13/#14/#15).

## Referencias útiles
- `POCKNIX-EXPERIENCE.md`, `RESEARCH-ARM-DISTROS.md`, `BATTERY-ISSUE.md`, `IDEAS.md` en el repo.
- Issues upstream relevantes: shuuri-labs/pocknix-os #54 (Odin 3), #65 (suspend drain Odin 2).
- Proyectos ARM de referencia: ROCKNIX (PR #2840 charge bypass), ArmadaOS, SteamOS-Ubuntu, Nova-Deck.
- **🎮 STEAM FRAME (Deckard) — repo de paquetes aarch64 de Valve** ⭐ (25/09/2026):
  `https://holo-packages.steamos.cloud/archlinux-deckard-hotfixes/` — binarios ARM64 de Valve
  (Mesa 26.3 devel, Vulkan layers RPO/FDM/fossilize, UCM LPASS, sysctls, hw-support). SM8650 ≈
  nuestro SM8750 → casi todo usable. **Centro de vigilancia/adaptación**:
  `/home/fransis/deckard-paquetes/` (LEEME.md, GUIA-ADAPTACION.md, estado.md, `vigilar-deckard.sh`
  + timer systemd diario 08:00 con aviso Telegram). Prioridad: probar layers RPO y Mesa 26.3 en la Odin.

## ESTADO ACTUAL (09/09/2026) — pendientes para retomar
- **CARGA BATERÍA (prioridad #1)**: parche 0080 instalado (kernel md5 9fa025e en /flash, backup KERNEL.bak-012448) pero el firmware ADSP responde "unknown message 0x33" al SET_USB → NO carga en Linux. Siguiente paso: desensamblar `/tmp/qti_battery_charger.ko` (extraído del Android) para hallar el opcode real de esta unidad, o probar reset del power-path tocando el toggle de bypass en Android y volviendo a Linux con cargador. Workaround: cargar apagada/Android.
- **Frame limiter QAM**: gamescope con parche Nova-Deck instalado (v6644cc9+) → validar con un juego que el límite 60 del QAM se respeta (átomo GAMESCOPE_FPS_LIMIT=60 ya confirmado).
- **Switch a escritorio desde Steam**: shim con SwitchToDesktopMode real instalado (md5 a7cba1f) → validar desde el menú de Steam.
- **Batería % congelado**: parche 0079 (poll 30s) instalado → debería refrescar solo; confirmar en uso.
- **MangoHUD + Postal 2**: toggle por paddle crashea con ese juego (mangoapp bucle) → evitar activar HUD en Postal 2; investigar si molesta.
- **Overlay Steam sobre juegos**: sigue sin funcionar (upstream FEX/ARM); se oyen menús pero no se dibuja. No es nuestra config.
- Cargar la Odin y arrancar en Linux para validar todo lo anterior.

## FRAME LIMITER QAM — ⏳ PROBAR ESTA NOCHE (actualizado 18/09/2026)

- **Sintoma**: el selector de fps del QAM (24/30/60, global e individual) se mueve pero los fps no varian.
- **CAUSA RAIZ (diagnostico del 09/09)**: el cliente Steam ARM64 NO comunicaba el limite a gamescope
  por NINGUN canal:
  - Atom X GAMESCOPE_FPS_LIMIT: NO lo escribia (se quedaba en 60, verificado con xprop -root en :0)
  - Protocolo Wayland de gamescope: NO se conectaba al socket (ss -x: solo gamescope-wl consigo mismo)
  - D-Bus (pocknix-steamos-manager): NO llama
  - Archivo de config: NO guardaba nada (grep fps en todos los .vdf = vacio)
- **WORKAROUND (09/09)**: `gamescopectl debug_set_fps_limit 60` en `pocknix-steam`. Limite FIJO 60.
  → **YA NO ESTA** (se quito el 16/09) y no existe en ningun otro sitio. El backup
  `/usr/bin/pocknix-steam.bak-fps60` tampoco existe ya.
- **🔄 ACTUALIZACION 18/09 (manana) — ESTO CAMBIA EL DIAGNOSTICO**:
  - **Steam SI persiste el limite por app** en
    `~/.local/share/Steam/userdata/<id>/config/localconfig.vdf`:
    `"Gamescope" { "AppTargetFrameRate" { "<appid>" "<fps>" } }`
    (el 18/09 a las 08:00 tenia 1 entrada y el fichero se reescribe con actividad).
    **Esa era exactamente la pieza que faltaba** para el "daemon que lea el limite de un archivo".
  - El atom marca **60** y el parche `0004-fps-limit-atom-persist.patch` **si** esta aplicado
    (gamescope `3.16.25-7-g6644cc9a+`). Pero **60 no prueba nada**: el 09/09 ya se observo 60
    sin que Steam lo escribiera → hay que hacer el test para distinguir.
  - Canal de Steam: `steamdeck_publicbeta`. El shim no expone nada de fps.
- **⏳ TEST PENDIENTE (30 s, necesita UI)**: en Game Mode, cambiar el limite del QAM a **30** y mirar
  (a) si `localconfig.vdf` pasa a 30, (b) si el atom pasa a 30, (c) si el juego va a 30.
  - **Si cambia el atom** → **ya funciona** (un cliente mas nuevo lo arreglo) → cerrar el tema.
  - **Si solo cambia el fichero** → **implementar el daemon**: vigilar `localconfig.vdf` (inotify)
    + el atom `GAMESCOPE_FOCUSED_APP` y aplicar con `gamescopectl debug_set_fps_limit <fps>`.
    El parche de gamescope ya hace **persistir** el atom, asi que con eso deberia quedar cerrado.

## FIX % BATERIA - INSTALADO Y VERIFICADO (09/09/2026)
- **CAUSA**: el firmware Debug_Board congela voltage_ocv tras el arranque (solo lo reporta una vez). El parche 0078 usaba ese OCV congelado -> % estatico.
- **FIX**: qcom_battmgr_estimate_percent() ahora usa voltage_now (que SI se actualiza) + compensacion por resistencia interna (~160 mOhm: drop = |I|*R). V_ocv_est = V_now + |I|*R.
- **VERIFICADO**: antes % congelado en 96; tras el fix, % = 48 con V_now 3.89V (bateria real al 48%). El % baja conforme se descarga.
- Kernel instalado: md5 dfe90a1 (backup /flash/KERNEL.bak-fixpct). Modulo battmgr con fix OCV (5 refs a voltage_now/drop).
- NOTA: la tabla OCV tiene escalones de ~50-100mV; el % cambia cuando el voltaje cruza el umbral (no es continuo).

## CARGA BATERIA - O PCODES REALES DESCUBIERTOS (09/09/2026) - ¡SOLUCION ENCONTRADA!
- **METODO**: desensamblar /tmp/qti_battery_charger.ko (Android) con aarch64-linux-gnu-objdump -d -j .text.
- **HALLAZGOS (del desensamblado de usb_charge_now_store y charge_control_en_store)**:
  - El firmware del Odin 3 NO usa el protocolo mainline. El mensaje Android (24 bytes) es:
    - offset 0-7: header 8B = 0x10000800a (owner 0x800a=32778=BATTMGR en low32, type 1=REQ_RESP en high32)
    - offset 8-11: opcode REAL: usb_charge_now=0x16(22), charge_control_en=0x20(32)
    - offset 12-19: property<<32 (usb_charge_now usa prop 14=USB_CHARGE_ENABLE, charge_control_en usa prop 24)
    - offset 20-23: value (0/1)
  - El mainline usa opcode 0x33 (USB_PROPERTY_SET=51) -> el firmware responde "unknown message 0x33" porque espera 0x16.
  - El mainline usa header de 12B (owner+type+opcode separados) y property en 32 bits -> formato distinto.
- **IMPLICACION**: para activar la carga hay que enviar el mensaje en FORMATO ANDROID con opcode 0x16.
- **PENDIENTE**: escribir el parche 0081 que envia el mensaje en formato Android (header 8B + opcode 0x16 + prop<<32 + value). 
  - Opcion A: modificar qcom_battmgr_request_property para el caso USB (header compacto + opcode 0x16).
  - Opcion B: hardcodear el mensaje en el enable_worker.
- El .ko de Android esta en /tmp/qti_battery_charger.ko (si se pierde, re-extraer via adb del Android).

## ESTADO CRITICO - ODIN SIN RESTAURAR (09/09/2026)
- **URGENTE**: /flash/KERNEL contiene el kernel de ROCKNIX adaptado que NO arranca. Hay que restaurar /flash/KERNEL.bak-nuestro -> /flash/KERNEL.
- La Odin no bootea hasta que se restaure (Fransis la restaurara con la SD al llegar a casa).
- Contexto: se probo el kernel ROCKNIX 20260901 (por si arreglaba la carga) pero no arranca con nuestro cmdline/DTB. No volver a intentar sin el DTB correcto.

## KBUILD SPEEDUP (parches para acelerar compilacion)
- 23 parches experimentales guardados en: /run/media/fransis/ROMS16TB/proyectos Alfred/kbuild-speedup/
- Ver LEEME.txt ahi para el detalle. Pendiente de re-extraer de forma robusta e integrar.

## ✅ CARGA BATERIA - RESUELTO Y VERIFICADO (10/09/2026 noche)
- **ESTADO: LA BATERIA YA CARGA EN POCKNIX.** Verificado: `status=Charging`, `current=+424207`,
  `qcom-battmgr-usb online=1` (553mA), `ucsi 3A`, `typec power_role=source [sink]`,
  firmware `ulog "Test mode" = 0`.
- **EL FIX**: copiar a `/lib/firmware/qcom/sm8750/` los **DOS** ficheros de firmware de ArmadaOS:
  - `adsp.mbn` (21907848, md5 `6cfcbbb80b956ddad76950c038ea1a3e`)
  - `adsp_dtb.mbn` (167736, md5 `d88d7ecbba78ecacb13adcc7bcbe131d`) ← **ESTA era la clave**
- **POR QUE**: el `adsp_dtb.mbn` es la config del cargador dentro del ADSP e incluye la
  **autenticación de batería** (`batt_auth_cfg`, `batt-auth-public-key`, `batt-unauth-charging-action`,
  `en-batt-auth`). El de Pocknix (`632e50f2`) NO la tenía → el firmware no autenticaba la batería →
  handler de error → **TEST MODE (estado 9)** → no cargaba.
- **DIAGNOSTICO**: `CONFIG_QCOM_PMIC_PDCHARGER_ULOG=m` + leer `pmic_pdcharger_ulog` (canal
  `PMIC_LOGS_ADSP_APPS`) muestra la decisión interna del firmware. Ya compilado en el kernel 7.2.4.
- **Backups en la Odin**: `adsp.mbn.bak-linux17` (`a1206f38`) y `adsp_dtb.mbn.bak-orig` (`632e50f2`).
- **PERMANENTE EN EL BUILD (11/09/2026)**: los 2 ficheros están en
  `pocknix-os/devices/sm8750/firmware/qcom/sm8750/` y `build-image.sh`
  (`install_firmware()`) los aplica **después** del overlay de ROCKNIX → ganan.
  Ya no hay que copiarlos a mano en la Odin.
- **CORRECCION**: el `0x1fffffff` del dmesg es `SERVREG_SERVICE_STATE_UP` (el PDR **sí** sube).
- **VER DETALLE EN**: BATTERY-ISSUE.md (secciones "premisa CORREGIDA", "HERRAMIENTA...", "SOLUCIÓN ENCONTRADA").

## ✅ KSCREEN / PANTALLA - RESUELTO (11/09/2026)
- **SINTOMA**: en el escritorio Plasma, Ajustes → Pantalla no mostraba el monitor.
- **CAUSA**: faltaba el paquete **`kscreen`** (solo `libkscreen` + `kscreenlocker`).
  Sin él no existe el módulo Ajustes → Pantalla (`kcm_kscreen.so`) ni el KDED
  `kscreen.so`; `libkscreen` sí da `kscreen-doctor` (por eso el script de rotación
  funcionaba pero Ajustes no).
- **FIX**: `sudo pacman -S --noconfirm kscreen` (+ `kimageformats`). Persistente.
- **VERIFICADO**: `kcm_kscreen` carga en systemsettings; `kscreen-doctor -o` enumera
  `DSI-1 1080x1920@120 scale 2.5 rotation Rotate270`; daemon `org.kde.KScreen`
  con backend `kwayland`.
- **NO era** kernel/DRM/DTS: el panel siempre se detectó (conector DSI-1, driver
  `panel-chipone-icna35xx`, propiedad `panel orientation` = 3 Right Side Up).
- La **imagen oficial ya incluye `kscreen`** vía `pocknix-desktop-full`; esta Odin
  no tiene ese meta (escritorio montado a mano).
- **VER DETALLE EN**: KSCREEN-ISSUE.md.

## ⚠️ PENDIENTE PARA MAÑANA

1. **Rebuild imagen** (`make build` + `make sd-image`) en `odin3-sm8750` → flashear + probar en la
   Odin: arranque, DeckStation en `/opt/deckstation/`, opción de descarga en Pocknix Tools, Steam OK.
2. **Revocar el token de RetroAchievements** (`5uidroaH4Gk6P7qg`) — estuvo público en el repo.
3. Avisar a **stshunz** del `.desktop` + `deploy_lanzar_sh` (por si quiere ajustes).
4. `.gitignore`: `devices/sm8750/firmware/qcom/sm8750/ayn/` sale **untracked** (debería ignorarse).
## ✅ RESUELTO — INCIDENTE 25/09: bootloop + kernel panic en imagen nueva

**Síntoma**: la Odin flasheó la imagen nueva y entraba en **bootloop con kernel panic, sin logs**.

**Causa raíz CONFIRMADA (26/09)**: se pasó `nologreplay` como opción de montaje de btrfs en montajes
`rw` — **NO es una opción válida suelta en Linux 7.2** (solo existe `rescue=nologreplay`, y esa exige
montaje solo-lectura). btrfs devuelve `-EINVAL` ("unrecognized mount option") y **la raíz no monta** →
panic **antes de userspace** → sin journal. Mensaje en pantalla:

```
VFS: Cannot open root device "PARTLABEL=POCKNIX_ROOT" or unknown-block(179,2)
```

(`179,2` = `/dev/mmcblk0p2`: la partición SÍ se encontró; lo que falló fue **montar el btrfs**.)

**Dónde estaba** (los dos sitios, ambos commits del 25/09):
- cmdline: `rootflags=nologreplay` → `devices/sm8750/profile.conf` (commit `191fbd4`) ⚠️ **vive SOLO
  en el árbol, NO en el centro** → por eso se coló sin pasar por la revisión del centro (deuda).
- fstab: `,nologreplay` en las 5 líneas → `scripts/build-sd-image.sh` (commit `404257a`, centro `451b8b3`).

**⚠️ El veredicto anterior era ERRÓNEO**: *"NO es culpa del software nuestro / causa probable: la
transferencia o el flasheo"*. **Sí era nuestro software.** El hash de la imagen, las particiones y el
btrfs estaban correctos; se descartaron además IOMMU/DTB (se probó otro DTB, seguía fallando) y la
compresión zstd (el btrfs del árbol hace `select ZSTD_DECOMPRESS`).

**Corrección**: `nologreplay` quitado del cmdline Y del fstab. Verificado: tras corregir ambos en la
SD, la Odin arrancó con **OOBE, sonido, botones y WiFi OK**.

**⚠️ TRAMPA 2 — el kernel y sus módulos deben ser del MISMO build.** Un kernel compilado en otra
máquina (aunque diga `7.2.4`) **no sirve** para una imagen ya construida: el BTF no coincide y el
kernel **rechaza los módulos** (`failed to validate module ... BTF: -22`), lo que deja **sin mando**
(no carga `vhci-hcd`, que inputplumber necesita) y **sin sonido** (módulos `snd_soc_lpass_*`).
- Kernel bueno (el de la imagen): `fransis@cachyos-x8664`, Image md5 `624b596fa8e819d2ad940133a94cba57`.
- Kernel ajeno probado (roto para esta imagen): `davidusky@CachyOS`, Image md5 `3c7a87639dbbc4af77d6ee21056d3bae`.
- **Regla**: "misma versión" NO es "compatible" — mirar el **Image md5**. Kernel y módulos salen juntos
  del mismo entorno. **No recompilar solo el kernel para una imagen ya construida.**

**Documento completo**: `docs/INCIDENTE-2026-09-25-nologreplay.md`.

### Pendientes vivos (25/09 noche → 26/09)
- [x] Jarvis/Compi: verificar SHA256 de las partes de la imagen → **verificado, era correcto** (no era el problema).
- [x] Aplicar los refuerzos de robustez a la SD → **hecho**… y resultó ser **la causa del fallo**, no un refuerzo inocuo.
- [ ] Subir el default `SD_SLACK_MIB=2048` en `config/pocknix.conf` del centro, sync + commit.
- [ ] Probar el layer Vulkan `VK_LAYER_VALVE_rpo` con un juego real.
- [ ] Decidir Mesa 26.3: probar el binario de Valve (opción A) o portar los parches (opción B).
- [ ] **Deuda**: subir la fuente del cmdline (`devices/sm8750/profile.conf`) al centro, para que no se
      pueda colar otra vez un cambio de arranque sin pasar por revisión.
- [ ] **Espacio**: la raíz de ~25 GB se queda corta para Steam en microSD; valorar usar la UFS interna
      para `/home` (ver sección ALMACENAMIENTO y `docs/IDEAS.md` §6).
