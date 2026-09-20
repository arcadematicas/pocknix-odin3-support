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
- `/home/fransis/pocknix-odin3-project/pocknix-os/` — repo UPSTREAM de shuuri-labs (NO pushear a su remote; es clon de trabajo). El kernel se compila desde aquí.
- **arcadematicas = nosotros** (confirmado). Todo commit a `pocknix-odin3-support` va a arcadematicas.

## Acceso a la Odin
- SSH: alias `odin` (Tailscale IP cambia; config en `~/.ssh/config`). Usuario `deck`, contraseña sudo `pocknix`.
- Unidad compartida: `/home/deck/Recibidos` de la Odin ↔ `/home/fransis/Odin` del PC (SSHFS, montaje `.mount` de usuario como fransis con `idmap=user`).
- Scripts: `~/bin/odin-montar` y `~/bin/odin-desmontar`.
- **UIDs**: fransis=1000, deck=1001.

## Estados CRÍTICOS y lecciones (NO repetir errores)
- **NUNCA reiniciar Decky Loader en caliente** mientras Steam corre en modo juego → crash loop de steamwebhelper (NameError exit en main.py:118). Reiniciar solo desde Plasma o antes de entrar a Game Mode.
- **NUNCA reemplazar el kernel 7.2 por 7.1** (7.1 no arranca en la Odin 3).
- **NO usar `--mangoapp` de gamescope** (modelo SteamOS: mangoapp como hermano).
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

## Plugin Decky (PocknixControl)
- Código en repo `config/pocknix-control-plugin/`. Frontend TS (Lighting.tsx, etc.) + backend Python `pocknix_control/` (power.py, oled_care.py, main.py).
- Reiniciar backend: `sudo systemctl restart pocknix-decky-loader.service` (SOLO sin Steam en modo juego).
- El PluginLoader corre como root sin entorno gráfico; extraer env de sesión vía `pgrep -x` (no -f).

## Referencias útiles
- `POCKNIX-EXPERIENCE.md`, `RESEARCH-ARM-DISTROS.md`, `BATTERY-ISSUE.md`, `IDEAS.md` en el repo.
- Issues upstream relevantes: shuuri-labs/pocknix-os #54 (Odin 3), #65 (suspend drain Odin 2).
- Proyectos ARM de referencia: ROCKNIX (PR #2840 charge bypass), ArmadaOS, SteamOS-Ubuntu, Nova-Deck.

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
  `docs/INSTALACION.md`. Y la sección "DeckStation" de
  `/home/fransis/pocknix-odin3-project/AGENTS.md`.
- **Config base reproducible**: `scripts/deckstation-configs.sh` +
  `configs/deploy-manifest.txt` despliegan la config en cada emulador (lo llaman el setup
  y el launcher). Ya **no** hace falta el payload de MediaFire del Updater (era x86_64).
- **BIOS**: solución externa en `bios/` + `scripts/deckstation-bios.sh` (copyright: el
  usuario pone sus ficheros y el script los reparte).
- **Cores**: Suyu (Switch) necesita las claves en `<retroarch>/system/suyu/keys/`, y tanto
  Suyu como GooseStation (PSX) necesitan su `<command>` en `es_systems.xml`.
- **⚠️ Gap**: el paquete `suyu-libretro` **no está en `devices/sm8750/packages.list`** →
  el core de Switch no entra en la imagen. Pendiente.
- **Ojo con el sync**: `tools/sync-to-os.sh` usa `rsync` **sin `--delete`** → los ficheros
  editados a mano en el árbol sobreviven; los ficheros nuevos del centro se añaden.

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
