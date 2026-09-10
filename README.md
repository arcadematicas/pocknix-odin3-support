# pocknix-os · AYN Odin 3 (SM8750 / Snapdragon 8 Elite)

Aportes para hacer que **pocknix-os** corra en el **AYN Odin 3** (plataforma
SM8750, Adreno 830). El objetivo es que el proyecto pocknix pueda **fusionar
este soporte** y ofrecer el Odin 3 como dispositivo soportado.

## Estado actual
- ✅ **Arranca** (kernel 7.2.0 + DTS de dispositivo).
- ✅ **Sesión de juego** (gamescope + Steam Deck gamepadui) **estable**, sin
  `VkDeviceLost`.
- ✅ **Mando + táctil** funcionando (InputPlumber, incluido el gamepad UART del
  Odin 3 vía driver `rsinput`).
- ✅ **WiFi** (NetworkManager) + **cuenta de Steam** + **juegos**.
- ✅ **Audio** — sound card `SM8750-AYN` funciona (ADSP habilitado).
- ✅ **Batería** — `pmic_glink` reporta capacidad correctamente (aunque el fuel
  gauge del ADSP puede venir descalibrado de fábrica; ver `BATTERY-ISSUE.md`).
- ✅ **Bootanimation Odin 3** — splash de arranque con la animación oficial del
  Odin 3 dibujada en `/dev/fb0` (sin Plymouth, ver `config/splash/`).
- ✅ **ADSP + CDSP** corriendo (`adsp`/`cdsp` remoteproc `running`).
- ✅ **QAM** — botón Select abre el menú Quick Access.
- ✅ **Escritorio (Plasma Mobile)**: **KScreen enumera el panel** (Ajustes →
  Pantalla muestra el monitor `DSI-1` con su resolución y rotación). Causa del
  fallo original: faltaba el paquete **`kscreen`** (KCM de pantalla); ver
  `KSCREEN-ISSUE.md`. La imagen oficial ya lo incluye vía
  `pocknix-desktop-full`.
- ⚠️ **Sensores IIO**: `hexagonrpcd` compilado e instalado (servicio
  `hexagonrpcd-adsp-sensorspd.service`), pero **sale al arrancar y no expone
  dispositivos IIO** → no hay acelerómetro ni sensor de luz ambiental. Por eso no
  funcionan la auto-rotación ni el **brillo adaptativo** (KScreen reporta
  `Automatic brightness: unsupported`). Pendiente: bring-up del sensor PD del
  ADSP (registry/`sns_reg` + logs de `hexagonrpcd`).

## Qué contiene
| Ruta | Qué es |
|---|---|
| `kernel/cq8725s-ayn-odin3.dts` | DTS del dispositivo Odin 3 (SM8750) — ADSP/CDSP habilitados, rutas firmware corregidas a `ayn/odin3` |
| `kernel/cq8725s-ayn-common.dtsi` | DTS común AYN CQ8725S (compartido entre Odin 3 y otros dispositivos AYN) |
| `kernel/0001-adreno-a8xx-force-gx-collapse-before-cx.patch` | **Fix del GPU** (VkDeviceLost / GMU GX-GDSC). Complementario al `0050` de ROCKNIX |
| `kernel/0002-input-rsinput-uart-gamepad.patch` | **Fix del gamepad UART** (driver `rsinput`), necesario para el mando del Odin 3 en modo consola (backport a 7.2) |
| `kernel/sm8750-patches/` | **64 patches SM8750** (0026-1300): SoC ID, panel, touchscreen, LEDs, GPU, WiFi/BT, audio, haptics, rsinput, fan, etc. |
| `config/session-fixes.md` | Documentación completa de todos los fixes (12 fixes documentados) |
| `config/odin3-post-boot-setup.sh` | Script de setup post-boot (suspensión, WiFi, rotación, sensores) |
| `config/ayn_mcu.yaml` | InputPlumber fix: Select → QuickAccess (QAM) |
| `config/hexagonrpcd/` | hexagonrpcd cross-compile + service file para sensores IIO |
| `config/daemons/` | **Daemons**: `power-button-daemon.py` (botón encendido → pantalla on/off) + `volume-button-daemon.py` (volumen → PipeWire en modo juego) + sus servicios systemd |
| `config/oled-care/` | **OLED care**: `oled-care-daemon` (pixel refresher automático tras N min de inactividad) + `oled-refresher-auto` + refresher C |
| `config/decky-plugin/` | Backend del plugin Decky: `oled_care.py` (pixel refresher, detección de modo juego) |
| `config/fake-suspend/` | **Fake Suspend**: script + servicio + override systemd para evitar suspensión real (cuelgue SM8750). Apaga pantalla + CPU powersave. |
| `config/splash/` | **Bootanimation Odin 3**: splash de arranque dibujando en `/dev/fb0` (servicio + reproductor + conversor de frames). Sin Plymouth (no dibuja en el panel DSI). |
| `config/power/` | **Gestión de potencia**: fan mode `off`, selector de governor CPU, power profiles (pseudo-TDP bajo/medio/alto) y aplicación **por juego** con restauración automática. Todo integrado en PocknixControl. |
| `config/steamui-watchdog/` | **Watchdog de la UI de Steam**: reinicia steamwebhelper si la UI se congela (bug FEX/CEF). Healthcheck al puerto de debug cada 30s. |
| `config/fex/` | Variables FEX de estabilidad (`FEX_JIT_BlockLinking=0`, `FEX_GDBServer=0`, `FEX_EARLY_LOG_DISABLE=1`) |
| `config/mangohud/` | **MangoHud parcheado SM8750**: fuente + config compacta (barra horizontal) + toggle por paddle M2 (F13) |
| `config/inputplumber/` | Capability map AYN modificado: paddle M2 → tecla F13 (toggle MangoHud) |
| `config/pocknix-control-plugin/` | Plugin PocknixControl actualizado (backend + frontend): fan off, governor, power profiles (global y per-game) |
| `config/odin3-display.service.clean` | `odin3-display.service` **limpiado**: sin el `rotation` sysfs (ya no existe; es propiedad DRM) ni los `modprobe` muertos → deja de fallar (era la única unidad en `failed`) |
| `BATTERY-ISSUE.md` | Issue de batería: fuel gauge corre en el firmware ADSP (percent viene del firmware), descalibrado `Debug_Board`, solución = ciclo de carga en Android |
| `KSCREEN-ISSUE.md` | **RESUELTO**: KScreen no veía el panel en escritorio — faltaba el paquete `kscreen` (KCM Ajustes → Pantalla) |

## Lo más valioso para upstream
1. **Adreno a8xx GX-collapse fix** — resuelve el `VkDeviceLost` del compositor
   en Adreno 830 (SM8750). Afecta a GPU de esta familia. **Complementario** al
   `0050` de ROCKNIX (el `0050` define el `.power_off` del GX GDSC pero solo
   colapsa con `synced_poweroff`; este parche es quien lo activa en
   `a8xx_recover` — ambos son necesarios).
2. **DTS del Odin 3** — soporte de dispositivo SM8750 (panel, WiFi, mando),
   con firmware ADSP/CDSP apuntando a `ayn/odin3/`.
3. **Driver gamepad `rsinput`** (backport a 7.2) — sin él no se detecta el mando
   del Odin 3 en modo consola.
4. **Ajustes de sesión** — el recetario para que gamescope/Steam funcionen.
5. **Daemons de botones** — power button (pantalla on/off) + volume (PipeWire)
   para modo juego.
6. **OLED care** — pixel refresher nativo (C + SDL2) + automatización systemd
   (solo en modo juego, cada 4h).
7. **FEX fix** — `FEX_EARLY_LOG_DISABLE=1` para reducir crashes de
   `steamwebhelper` (bug CEF + FEX, fix parcial upstream 2603).
8. **Fake Suspend** — evita el cuelgue del SM8750 en suspensión real. Intercepta
   `systemd-suspend.service` y ejecuta un "fake suspend" (pantalla off + CPU
   powersave) seguro y despertable al instante.
9. **Bootanimation en fb0** — el patrón para splash de arranque en handhelds con
   panel DSI sin EDID: **dibujar en `/dev/fb0`** desde un servicio systemd (como
   `rocknix-splash`), no Plymouth. Incluye la extracción del bootanimation
   desde los `super_*.img` fragmentados de la ROM Android.
10. **Batería** — diagnóstico: el fuel gauge del Odin 3 corre en el firmware ADSP
    y el percent llega directo del firmware (sin perfil cargado:
    `MODEL_NAME=Debug_Board`). Útil para no perder tiempo "parcheando en el
    kernel" algo que solo se arregla recalibrando en Android.
11. **MangoHud SM8750 parcheado** — el MangoHud genérico no lee el GPU del SM8750
    mainline (busca rutas kgsl que no existen). Los parches de ROCKNIX apuntan a
    `gpuss0_thermal` y `/sys/class/devfreq/3d00000.gpu`. Compilación cruzada
    aarch64 desde x86 (rootfs + qemu). Ojo: mangoapp es autocontenido → hay que
    reemplazar su binario, no solo las libs.
12. **Watchdog de UI para FEX/CEF** — steamwebhelper expone un puerto de debug
    (`127.0.0.1:8080`); si deja de responder, la UI está congelada → reiniciarlo.
    Healthcheck sencillo que complementa el fix parcial de FEX.
13. **Pseudo-TDP en SM8750** — el SM8750 mainline **no expone nodo de TDP**; la
    vía práctica es limitar frecuencias máx de CPU (`scaling_max_freq`) y GPU
    (`devfreq max_freq`). Perfiles bajo/medio/alto con restauración del snapshot
    original.
14. **Patrón per-game con restauración por PID** — el wrapper de proton escribe
    `/run/pocknix/game-mode` con `pid fan lavd governor profile`; los daemons
    aplican el tweak mientras el PID vive y restauran el global al morir. Campos
    **añadidos al final** para no romper a los lectores existentes
    (`read -r pid fan _`). Reutilizable para cualquier tweak por juego.
15. **Plugin Decky en la imagen** — PocknixControl vive en
    `/usr/share/decky-plugins/` y Decky lo copia a `homebrew/` al arrancar:
    los cambios al plugin hay que hacerlos en la **fuente** o se pierden.

## Notas
- Basado en kernel 7.2.0 (sm8750), rebasado sobre el árbol de ROCKNIX.
- El 7.1.0 funcionaba, pero el 7.2.0 no arrancaba salvo por 2 regresiones que se
  corrigieron: (1) el DTS apuntaba el firmware ADSP/CDSP a los genéricos
  `qcom/sm8750/*.mbn` y dejaba `remoteproc_cdsp` `disabled`; (2) el `.config` se
  había regenerado perdiendo opciones. Con el DTS corregido + `.config` del 7.1,
  el 7.2.0 arranca y **supera al 7.1.0** (CDSP activo, stack LPASS completo,
  Bluetooth, gamepad).
- Sin credenciales/secretos.
- El trabajo se hizo en un fork local; estos artefactos están listos para
  portar/mergear.
