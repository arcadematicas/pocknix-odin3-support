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

## FRAME LIMITER QAM - DIAGNOSTICADO (09/09/2026) - PENDIENTE SOLUCION REAL
- **Sintoma**: el selector de fps del QAM (24/30/60, global e individual) se mueve pero los fps no varian.
- **CAUSA RAIZ**: el cliente Steam ARM64 NO comunica el limite a gamescope por NINGUN canal:
  - Atom X GAMESCOPE_FPS_LIMIT: NO lo escribe (se queda en 60, verificado con xprop -root en :0)
  - Protocolo Wayland de gamescope: NO se conecta al socket (ss -x muestra solo gamescope-wl consigo mismo)
  - D-Bus (pocknix-steamos-manager): NO llama
  - Archivo de config: NO guarda nada (grep fps en todos los .vdf = vacio)
- El selector del QAM es SOLO UI; el valor no llega a ningun sitio.
- **WORKAROUND APLICADO**: gamescopectl debug_set_fps_limit 60 en pocknix-steam (linea ~131) al arrancar la sesion. Limite FIJO 60fps.
- **PARA SOLUCION FUTURA**: probar otra version/canal de Steam que implemente el frame limiter ARM64, o un daemon que lea el limite de un archivo y lo aplique con gamescopectl. El parche 0004-fps-limit-atom-persist.patch SI esta en el binario y funciona (validado con vkcube: 30->29fps) - el problema es que Steam no escribe el atom.
- Backup pocknix-steam: /usr/bin/pocknix-steam.bak-fps60

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

## CARGA BATERIA - INVESTIGACION EXHAUSTIVA COMPLETADA (10/09/2026) - PROBLEMA NO RESUELTO
- **ESTADO**: Pocknix NO carga la bateria en Linux. ROCKNIX (7.1.3 y 7.2.0) SI carga en el MISMO hardware.
- **DESCARTADO** (todo probado): config del kernel (95 diffs, casi todos flags de compilador), parches 0078/0079/0080 (el kernel sin ellos tampoco carga), firmware adsp.mbn (probado el de ROCKNIX 21.9MB), compilador (GCC 15.2 probado), battmgr.ko de ROCKNIX (incompatible), cmdline, DTB, scripts userspace, ABL.
- **⚠️ CORRECCION 10/09 noche - EL PDR SI SUBE**: `SERVREG_SERVICE_STATE_UP = 0x1FFFFFFF` (include/linux/soc/qcom/pdr.h). El dmesg `state: 0x1fffffff` es **UP**, no DOWN. `qcom_battmgr_pdr_notify()` compara contra ese valor -> `service_up=true` y el polling corre. **El canal kernel<->firmware ADSP funciona.** Descartada la hipotesis "PDR nunca sube".
- **MECANISMO DE CARGA (entendido)**: el firmware ADSP envia BATTMGR_BAT_STATUS con charging_source; si source=USB -> battmgr.usb.online=1. En Pocknix el firmware NO reporta USB (aunque el UCSI si ve el cargador).
- **SINTOMA CLAVE**: ucsi-source-psy online=1 y current=1.25A en Pocknix, PERO la bateria no sube (energia no dirigida a la bateria). battmgr-usb online=0 siempre. ROCKNIX negocia PD 9V/3A, Pocknix se queda en 5V.
- **HERRAMIENTA NUEVA - `pmic_pdcharger_ulog`**: Pocknix NO compila `CONFIG_QCOM_PMIC_PDCHARGER_ULOG` (ArmadaOS/ROCKNIX si, `=m`). Expone el **log interno del firmware del cargador** via canal rpmsg `PMIC_LOGS_ADSP_APPS` (tracepoint `pmic_pdcharger_ulog_msg`). Es la unica via de ver POR QUE el firmware no activa la carga. Script listo: `/usr/bin/armada-charge-debug` (ArmadaOS).
- **VER DETALLE EN**: BATTERY-ISSUE.md (seccion "premisa CORREGIDA" + "HERRAMIENTA DE DIAGNOSTICO NUEVA").
- **PARA RETOMAR**: compilar 7.2.4 con `CONFIG_QCOM_PMIC_PDCHARGER_ULOG=m` y leer el log del firmware en la Odin.
