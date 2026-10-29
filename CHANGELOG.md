# Changelog — Pocknix Odin 3

*La historia de qué se ha añadido y quitado en el proyecto, en orden. Para el detalle
técnico fino ver `AGENTS.md` y `docs/`.*

Este fichero resume el historial real del repositorio `pocknix-odin3-support` (209
registros, del 25/08/2026 al 25/09/2026), agrupado por semanas y explicado en lenguaje
normal: qué se hace, qué se quita y por qué. Los identificadores técnicos aparecen
solo entre comillas invertidas cuando hacen falta para buscar el detalle.

- `✅` = problema resuelto
- `🚀` = cosa nueva
- `⚠️` = problema abierto o solución provisional
- `🧹` = limpieza / algo retirado

---

## 📅 29 de octubre 2026 — publicado el lote de sensores y adoptado iris low-latency

### ✅ Publicado el lote del 28/10 (repo `sm8750`)
- **`linux-pocknix-sm8750 7.2.12-18`**, **`hexagonrpc 0.5.0-3`** y **`libssc 0.4.4-2`** ya están
  en `r2:pocknix/sm8750`, firmados (3 paquetes, delta +3 −1 frente a la `7.2.12-17`).
- **Validación de suspensión**: la consola estuvo **suspendida 9 h** (28/10 22:14 → 29/10 07:09) y
  despertó limpia; además dos ciclos de 64 s y 49 s. Sin firmas de panel ni GPU, sin módulos
  rechazados por la guardia. `stage-check` pasado con `POCKNIX_STAGE_CHECK_SOCS=sm8750`.
- Trampa aprendida: **`rtcwake` se salta los hooks de `systemd-sleep`** y por eso el mando virtual
  de inputplumber (`vhci_hcd`) aborta la suspensión con `-16`. Con `systemctl suspend` el hook
  `zz-inputplumber` suelta el `vhci` y duerme bien. Para probar con alarma RTC: armar
  `rtcwake -m no -s N` y **luego** `systemctl suspend`.

### ⚠️ `msm-firmware-loader 1.8.0-6`: instalado, sin publicar
- Compilado y **instalado en la Odin** (el helper queda en `/usr/lib/pocknix/hexagonfs-island-off.py`,
  con el drop-in `50-island-off.conf`). No se ejecuta hasta el próximo arranque, así que **no se
  publica todavía**: primero un reinicio y comprobar que la isla SSC sigue apagada.

### 🚀 Adoptado: iris low-latency + smp2p + pm-clock (kernel `pkgrel 20`, compilado)
- Los **10 parches de iris** de `armada-os/armada` (`0016-0025` en `10-mainline`), que son superset del
  PR #157 de shuuri: POC type, AV1 tier, CABAC, delays, stage 1, **sesiones al reloj máximo** y
  **stage 1 al reloj máximo por defecto** (`1037`), más el fix del buffer de cambio de resolución.
  Ojo: el `1034` de armada **no es** el de shuuri — mezclarlos rompe (`1037` no aplica).
- `2110` soc/qcom: smp2p resetea el estado inbound solo en restart.
- `2111-2114` ASoC lpass: macros a pm-clock y runtime suspend forzado en system sleep (que el audio
  no impida el suspend profundo).
- Verificado aplicando la secuencia entera sobre un `linux-7.2.12` limpio y compilado: **290 módulos**,
  2 dtbs, cero errores.
- Pendiente de probar (con Fransis): streaming en Moonlight y que el audio siga bien.

### 🎙️ DTS: micrófono interno + dither 8bpc (pkgrel 21)
- El parche de DTS de armada **no aplica** (es un diff contra su árbol). Portado a mano lo que encaja:
  - **Micrófono interno**: `widgets = "Microphone", "Internal Mic"` y las rutas `DMIC3`/`MIC BIAS3`/
    `TX SWR_INPUT6` en `cq8725s-ayn-common.dtsi`. Comprobado en el `.dtb` compilado.
  - **Dither 8bpc** del panel (`armada,dpu-8bpc-dither`); el driver ya lo teníamos (`2100`).
  - Reguladores del códec en LPM: **ya estaban** de una adopción anterior.
- **LED de carga: pendiente**. El nodo `pm8550_pwm` existe, pero el **canal 3 lo usa el ventilador**
  (`pwms = <&pm8550_pwm 3 40000>`) y el trigger `battery-charging-orange-full-green` **no existe en
  nuestro kernel** (es de SteamOS). Se hará con un servicio que lea `power_supply` y escriba rojo/verde.
- **SoCCP (deep sleep)**: pendiente; necesita driver (`0556`) + nodo (`0556a`).
- **Audio (2115-2119)**: HPH PCM/HiFi (0072/0073), decimadores del tx-macro (0080), usbss en el jack
  (0063) y codec resumido con jack (0603). Compila; sin probar sonido todavía.
- El **giroscopio** sigue pendiente: se arregla en paquetes (`inputplumber 0005-0008`, `libssc 0005`).

---

## 📅 28 de octubre 2026 — sensores, `uhid` y la salud de la batería

### ✅ Batería: `charge_full_design` (salud real)
- **`linux-pocknix-sm8750 7.2.12-18`** aplica el parche `1082` de upstream (battmgr, firmware
  SM8350-class). En la Odin, `charge_full_design` devolvía **ENODATA**, así que la "salud" que
  enseñaba upower (100 %) era inventada.
- Verificado tras el arranque: `charge_full_design` = **7.838.000 µAh**, upower da
  **salud 98,6 %**, `energy-full-design` 35,11 Wh y **"time to full"**. El tiempo restante que ya
  funcionaba (nuestro `2108`, `power_now = V×I`) sigue bien: 4,87 W frente a los ~51 W falsos del
  firmware. El `1083` (charge_now) **no hacía falta**.

### 🐛 `uhid`: carrera en la cola de salida (parche `0014`)
- En 7.2.12, `uhid_char_read()` leía `outq[tail]` **sin `qlock`**: en CPU débilmente ordenada puede
  pasar un NULL a `copy_to_user()` y **matar el dispositivo uhid con `devlock` tomado**. Steam se
  queda esperando *feature reports* y **el mando se congela hasta reiniciar**.
- Es exactamente el escenario de armada (InputPlumber sirviendo un mando virtual en un AYN), así que
  entra en el mismo kernel. Sin forma directa de "verlo": se valida por ausencia de oops.

### 🌡️ Sensores: isla SSC apagada en el Odin 3
- **`msm-firmware-loader 1.8.0-5/-6`**: helper *fail-open* que copia `sensors/config` y `registry`
  (eran enlaces a particiones de solo lectura), pone `enable_island=0` y deja las copias en su sitio.
  Con la isla activa, **un s2idle justo después de cerrar un sensor cuelga el SoC** (armada `623e96d3`).
  - Dos tropiezos por el camino, ya corregidos: la comprobación de modelo usaba DMI, que en la Odin
    viene **vacío** (hay que leer `/proc/device-tree/model`), y el JSON real anida la isla en
    `power..island`, no en `.island` de primer nivel.
- **`hexagonrpc 0.5.0-3`**: parche `0008` contesta la petición `apps_std` que el ADSP hace al
  arrancar; sin respuesta **el ADSP de sensores no duerme** (y el SoC no colapsa CX/DDR).
- **`libssc 0.4.4-2`**: parche `0002`, registra el error antes de entregarlo (leía memoria liberada
  al cerrar un sensor).
- Estado: instalado y aplicado en la consola (log `/run/pocknix-island-off.log`). **Pendiente de
  publicar** hasta validar suspensión.

### ⚙️ CMA a 256 MB
- **`pocknix-bsp-sm8750 0.2.0-38`**: `cma=256M` en el cmdline (antes 44 MiB por defecto, con solo
  ~2,5 MiB libres en juego). El paquete **reensambla `/flash/KERNEL`** al instalarse, porque el hook
  90 no dispara con `kernel-cmdline`.
- **No arregló** el SEGV de Turnip al suspender con el ambilight de Colores: ese es del cliente de
  captura (ver issue de Hooandee). Sí se dejó de reproducir el cuelgue al abrir juegos.

### 🎮 Moonlight + Sunshine (streaming desde el PC)
- `moonlight-qt 6.2.0` en la Odin, emparejado con Sunshine del PC (VAAPI). Ajustes en el host:
  `encoder = vaapi` y **`av1_mode = 0`** — la RX 6750 XT no codifica AV1 y Sunshine entraba en bucle
  creando `av1_vulkan` ("no se ha recibido vídeo").
- **HDR no es posible hoy**: el decodificador Iris **sí** ofrece `P010` (10 bits), pero Moonlight
  negocia `NV12` y avisa de GPU no compatible. Reportado en **moonlight-stream/moonlight-qt#2081**.
  Doc: `docs/MOONLIGHT-20261028.md`.
- Atajo no-Steam añadido a `shortcuts.vdf` **con Steam cerrado** (round-trip verificado) y limpieza de
  los **dos atajos huérfanos** que quedaron de una edición anterior.

### 📝 Documentación
- `docs/PRUEBAS-2026-10-28.md` (plan y resultados), `docs/MOONLIGHT-20261028.md`, plan de distribución
  de la próxima build (`docs/PLAN-DISTRIBUCION-BUILD-20261028.md`).

## 📅 26–27 de octubre 2026 — firmware, red de seguridad del kernel, branding e informes

### 🧹 Dos arreglos de upstream adoptados (27/10)
- **`pocknix-bsp-common 0.1.0-23`**: coredumps limitados a **1 GB** (`coredump.conf.d`). systemd
  guardaba hasta el 10 % del sistema de ficheros: en una consola con raíz única son decenas de GB
  de volcados que nadie lee.
- **`pocknix-desktop-kde 0.1.0-3`**: **baloo** (indexador de KDE) apagado por defecto vía
  `/etc/xdg/baloofilerc`; `~/.config` sigue mandando, así que activarlo en Ajustes funciona.
  *Solo afecta al sabor KDE, que no publicamos* — se mantiene por paridad con upstream.
- Ambos portados de `shuuri-labs/pocknix-os` (`fa778ceb`, `bd074e65`) sobre nuestras versiones.

### ⏸️ Pendiente: formateo de SD desde Steam (upstream 56ba06b8)
Upstream movió el formateo de la microSD a *Ajustes → Almacenamiento* de Steam y **quitó** la
sección del plugin. **No es un cherry-pick para nosotros**: su `pocknix-steam` es Python con
CDP/WebSocket y el nuestro es bash; haría falta habilitar CEF-debugging en el launcher, portar
`pocknix-steam-storage` + `pocknix_cdp.py` y probarlo con tarjeta. Mientras tanto **mantenemos
nuestra sección** (`SdCard.tsx` + `sdcard.py`): quitarla sin sustituto sería perder función.

### 🧩 `linux-pocknix-sm8750 7.2.12-17` — el parche del panel, ahora en paquete
- El paquete **-16 no incluía módulos** (0 entradas bajo `usr/lib/modules`): por eso un `KERNEL`
  copiado a mano podía convivir con módulos viejos sin que nada avisara. El **-17 sí los trae**
  (290 `.ko`) y dispara los hooks 90 (regenera `/flash/KERNEL`) y 91 (par de reparación).
- Validado en la consola: **varios cambios Game Mode ↔ escritorio + 4 suspends** sin
  `failed to initialize panel`, `dsi_cmds2buf_tx`, `a8xx_recover`/`gdsc` ni hangcheck.
- Publicado en `r2:pocknix/sm8750`. Aviso a Jarvis/Davidusky: issue #2 del repo.

### 🛡️ Red de seguridad kernel/módulos (tras el susto del 26/10)
- **`pocknix-kernel-guard`** (nuevo paquete *shared*, dependencia de `pocknix-core`): a los 75 s del
  arranque comprueba que los módulos son del mismo build que `/flash/KERNEL` (md5 + `failed to
  validate module` en el log). Si no, reinstala desde `/flash/modules-<ver>.tar.zst` y reinicia una vez.
- **`pocknix-kernel-pair`** (hook alpm 91): mantiene en `/flash` el md5 y el tar de módulos del build
  en curso, para que el guardia siempre pueda reparar.
- **`pocknix-core 0.1.0-6`**: añade la dependencia, así llega a todas las consolas.
- Regla nueva: el kernel entra **siempre por paquete** (hook 90 regenera `/flash/KERNEL`); nunca
  copiar `KERNEL`/módulos a mano.
- Documento: `docs/RED-SEGURIDAD-KERNEL-20261026.md`.

### 🚀 Informes de incidencia desde PocknixControl (nuestro propio mecanismo)
- Botón **"Enviar informe"** en la pestaña *Sistema* del plugin: descripción opcional + envío.
- **No duplica nada**: el backend lanza `calvos-doctor --send --yes [--text ...]` (el script del BSP que
  ya recoge el diagnóstico y **redacta** PII) y parsea la URL del issue. El token de GitHub sigue
  viviendo **solo** en el Worker; el plugin solo hace POST.
- Los issues van a **`arcadematicas/calvOS-reports`** (nuestro repo de incidencias, como el de Hooandee
  pero nuestro).
- `pocknix-decky 0.1.0-58` (dist recompilado). `report.py` + `send_report` + `sendReport` + sección
  `INFORME` en `System.tsx`.

### 🔴 Regresión corregida: `msm-firmware-loader`
El cambio del 24/10 (`-3`) movió los scripts a `/usr/bin` dando por hecho que `/usr/sbin` es un
symlink a `bin`. **En estas imágenes no lo es** (es un directorio real), así que las unidades de
upstream seguían apuntando a `/usr/sbin/*.sh` y **fallaban en cada arranque**:
`Unable to locate executable '/usr/sbin/msm-firmware-loader.sh'` → `status=203/EXEC`.
- **`msm-firmware-loader 1.8.0-4`**, publicado: el `package()` reapunta las unidades con
  `sed 's|/usr/sbin/msm-firmware-loader|/usr/bin/msm-firmware-loader|g'`.
- Lección: las unidades vienen del **tarball de upstream**; parchear solo la ruta de instalación no
  basta (misma trampa que `gamescope-session`).
- Aviso publicado a Davidusky en su commit.

### 🚀 Panel de Control de Hooandee al día
- `pocknix-decky 0.1.0-57`: re-vendorizado de **v0.70.1 → v0.76.0** (23/10). **Sin delta propio**: el
  `hdr=True` del perfil `ayn_odin3` entró en upstream (PR #947, mergeado el 17/10).
- `tools/check-hooandee.sh` (en el chequeo diario) avisa cuando se queda atrás.

### 🧪 Compilado y pendiente de probar (no publicado a propósito)
- ~~**`fex-emu 2610.20261012.896a8691`**~~ → **probado** con juegos x86 y **publicado** el 26/10.
- ~~**Kernel 7.2.12 con el parche `1034`**~~ → validado y **publicado como `7.2.12-17`**; el `-18`
  añade `uhid` y `battmgr` (ver entrada del 28/10).

## 📅 25 de octubre 2026 — el micrófono del Odin 3 vuelve a la vida

ArmadaOS lo resolvió el 21/10 y **no era kernel**: nuestro `lpass-tx-macro` de 7.2.12 ya trae su
parche `0080` (tracking de decimadores por DAI) y su `0081` es nuestro `2109` (Diogo Trindade).
Lo que faltaba era declarar la **captura en el UCM**: nuestro `HiFi.conf` solo tenía `Speaker` y
`Headphones`.

### 🚀 Añadido
- `Mic` (micro interno, DMIC2/DMIC3 → `SWR_MIC6`) y `Headset` (micro del jack, wcd939x →
  `SWR_MIC1`, con `Mic Jack`), ambos por `CapturePCM "hw:${CardId},2"` con los dos decimadores.
- `pocknix-bsp-sm8750 0.2.0-33`, publicado en R2.

### ✅ Verificado en la Odin
- `arecord -l` muestra el PCM de captura; grabación de 5 s con **señal real** (`peak=22403`).
- PipeWire expone `alsa_input…__Mic__source` y queda como **fuente por defecto**;
  `pw-record` graba señal. El perfil de auricular con micro aparece al enchufarlo.
- No se tocó el kernel (cero reinicios, cero rebuild).

### 📝 Docs
- `docs/MICROFONO-20261025.md` (causa, port, verificación y diagnóstico si falla).

## 📅 24 de octubre 2026 — el refactor de escritorio que nunca se publicó

Davidusky (Jarvis) no pudo actualizar su Odin desde la imagen del 02-oct. Su informe era correcto y
**los cuatro bloqueos eran nuestros**: el refactor de escritorio llevaba días en el árbol de
compilación, pero **jamás se había publicado**. Nadie lo había notado porque nuestras consolas se
actualizan desde el árbol, no desde el repo.

### ✅ Publicado en R2 (firmado, `stage-check` en verde)
- **`pocknix-desktop 0.1.0-32`** — deja de instalar `/usr/bin/steamos-session-select` (desde `-27`
  ese fichero es de `pocknix-session`). Se acaba el conflicto de ficheros en la actualización.
- **`pocknix-desktop-plasma-mobile -2`**, **`pocknix-desktop-kde -2`**, **`pocknix-homescreen -1`** —
  los **sabores** y sus dependencias. Sin ellos, `pocknix-desktop -27..-32` era **ininstalable**: pide
  el virtual `pocknix-desktop-flavour` y no había ningún proveedor publicado. Esa era la causa de
  fondo de que R2 siguiera sirviendo la `-26`.
- **`pocknix-system-overlay -6`** — ya no empaqueta `etc/xdg/powerdevilrc`: lo trae
  `pocknix-desktop`. Eran dos dueños del mismo fichero.
- **`msm-firmware-loader 1.8.0-3`** — instala en `/usr/bin`. El fallo no era el contenido: el paquete
  metía la **entrada de directorio `/usr/sbin/`**, y en Arch `/usr/sbin` es un symlink a `bin` →
  `exists in filesystem (owned by filesystem)` y la transacción entera abortaba.

### ✅ Bug nuestro que salió a la luz
- `scripts/build-packages.sh` **abortaba cualquier build con el chroot al día**: `pacman -Syu` sale
  con código 1 y `there is nothing to do`, y el script lo interpretaba como "base obsoleta". Ahora se
  trata como el caso sano (`75e894c`).

### 🧹 Lo que NO se tocó (y por qué)
- **`pocknix-base` / `pocknix-update`**: ya llevaba política `--overwrite` acotada + autorreparación.
  Lo que le faltaba a su Odin era la **primera pasada manual** (política del doc de actualización).
- **`pocknix-desktop-plasma`** (sabor Plasma de escritorio): sigue **sin publicar** por decisión. No lo
  usa ninguna consola nuestra (la Odin es táctil → Plasma Mobile) y añadiría un segundo proveedor del
  virtual sin nadie que lo pruebe.

### 📝 Documentación
- `docs/INCIDENTE-2026-10-23-MIGRACION-ODIN3-DAVIDUSKY.md` §5: qué se publicó y cómo reintentar.
- `docs/ACTUALIZAR-ODIN-DAVIDUSKY-2026-10-23.md`: lista de `--overwrite` ampliada con los ficheros
  que las imágenes viejas dejaron sin dueño (solo hacen falta en la primera pasada).
- Reglas nuevas en `AGENTS.md` para que no vuelva a pasar.

## 📅 23 de octubre 2026 — el sistema, a la flash interna (y los juegos, quietos en la SD)

Día de mudanza: **calvOS pasa a arrancar de la UFS 4.0 interna** sin mover ni un juego, y se cierran
los flecos de audio y mandos que quedaban de la víspera.

### 🚀 Instalación en la flash interna
- El instalador de `pocknix-tools` clona **todo** el root de la SD, así que se negaba: la SD tenía
  **419 GiB** usados (325 en `/opt`) y la interna solo puede dar **196 GiB**.
- **Parche propio**: `pocknix-install-internal --exclude DIR` — no clona `DIR` y **descuenta su
  tamaño** del cálculo. Con `--exclude /opt` el clon baja a **94 GiB** ✅.
- Instalado con `--userdata-gib 1` (Android reseteado, no se usa): `ROCKNIX`/`POCKNIX` (FAT 512 MiB) +
  `POCKNIX_ROOT` (btrfs 196 GiB con snapshots). **~24 min** de clonado, 0 errores.
- **Juegos sin mover**: `/opt` entero se monta desde la SD (`bind` en fstab) → DeckStation (184 GiB)
  y WProton (140 GiB) siguen en su ruta. Nada más se redirige.
- **Choque de nombres**: la SD se renombró a `POCKNIX_SD` (GPT + FS) para que el fstab interno no
  montara `/home` desde la SD; su `KERNEL` se parcheó en el sitio (`root=PARTLABEL=POCKNIX_SD`) para
  que siguiera siendo arrancable de rescate.
- **Lección del ABL**: no elige por etiqueta del FAT; con la SD sin `KERNEL` el equipo no arrancaba
  hasta **cambiar el origen en el menú del ABL**. Documentado en `docs/INSTALACION-INTERNA-20261023.md`.

### ✅ Audio de auriculares: la compander
- Apagarla en la UCM **no basta**: DAPM la reactiva al alimentar la ruta. El vigilante
  `pocknix-audio-jack` la apaga y la vigila en cada pasada. Confirmado por Fransis: sin chisporroteo.

### ✅ Altavoz: era la ruta, no el volumen
- El control `SPK_L/R PCM Playback Volume` de los **AW88166** es **atenuación** (0 = máximo): leerlo a
  0 **no** es silencio. Se retiró el `950` que habíamos puesto (atenuaba casi al mute) y el vigilante
  ya no toca los amps. El fallo real era soltar `HPHL/HPHR`, `RDAC` y `CLSH` al volver al altavoz.

### ✅ QAM jugando y botón de encendido
- `steamui-watchdog` **no cuenta fallos ni reinicia la UI mientras hay un juego** (el reinicio a mitad
  de partida era el "se traba el QAM").
- `power-button-daemon.py` **faltaba en disco** (el paquete lo lista): servicio en bucle y botón
  físico muerto. Reinstalado `pocknix-system-overlay`.

### ✅ Batuta del Wind Waker
- Arriba y derecha no registraban con el stick derecho. El port traía `stick_deadzone 0.15` y
  `right_stick_range 1.0`; con **0.08 / 1.35** van las cuatro direcciones.

### 🛡️ Memoria
- `systemd-oomd` activo con umbrales altos (95 % swap, 70 % de presión 45 s): en el caso patológico
  mata el proceso más pesado en vez de dejar el sistema arrastrándose (probado con un UE5 que llegó
  a 9,1 GiB de zram y 379 MB libres).

---

## 📅 10–22 de octubre 2026 — suspensión a 0,26 W, kernel 7.2.12, audio de auriculares y Wind Waker

Dos semanas de trabajo fino: bajar el consumo, entender por qué el panel no conmuta de refresco, arreglar el
audio de auriculares y dejar un port nativo de Wind Waker funcionando desde Steam. Todo verificado en la Odin.

### ✅ Suspensión: de ~0,37 W a **0,24–0,26 W**
- Fuera los parches que peleaban entre sí: **`0044` y `0521` desactivados**, **`0512` añadido**.
- Hooks `zz-inputplumber` y `zz-wifi` + udev `99-wifi-pm.rules` para que el mando y el WiFi suelten el bus al dormir.
- **Medido en batería** (7.2.11‑7, dormida 359 s): **63–70 mA ≈ 0,26 W**. Antes ~0,37 W.
- Limpieza de la pila de parches: `0035` duplicaba `0076`, `0038a` ya estaba cubierto y `1022`+`1023` exigen
  rebase conjunto → waiveados. Solo quedó `1021`.

### 🚀 Kernel: 7.2.11‑8 → 7.2.12‑16
- **`1030`** (swr2), **`1031`** (relojes PM del tx‑macro), **`1032`** (bias del PLL del DSI, `0048b` de armada)
  y **`1033‑TEST`** (modo 60 Hz primero en `icna3520`, para probar sin tocar el panel a mano).
- **`7.2.12`** (estable nueva) + **`2109`** de armada: los controles **HPHL/HPHR Volume** del **WCD939x**
  venían heredados del wcd938x y **no hacían nada** — la etapa de auriculares se quedaba fija en **+6 dB**
  (el doble) y el `20` que escribe la UCM no servía. Ahora apuntan a `HPH_NEW_INT_PA_GAIN_CTL` y **0 dB es 0 dB**.
- Publicado como **`linux-pocknix-sm8750 7.2.12‑16`** en el repo propio. Volver a 120 Hz “normal”:
  `pacman -S linux-pocknix-sm8750=7.2.11-13` (sigue en R2).

### ✅ Panel: qué pasa de verdad con 60 Hz
- **El modo 60 Hz funciona** si es el **primero/preferido**: medido **59,95 Hz reales** con `panel-vhz.py` y **0 errores**.
  `gamescope -r` **no** elige modo (es refresco anidado, no del panel).
- **El bloqueo** es que el panel **no se reinicializa tras un `disable`** (`0x53`/`0x9C` → `-110`), así que no se puede
  conmutar en caliente todavía. Todo el detalle en [`docs/REFRESH-60HZ-20261021.md`](docs/REFRESH-60HZ-20261021.md).

### ⚠️ Micrófono: es soporte de plataforma, no configuración
- El front‑end de captura pide **`graph_id=2`** y `q6apm_get_audioreach_graph()` / `audioreach_alloc_graph_pkt()`
  fallan **sin log**. Ni la tplg de AYN ni la Kaanapali‑MTP publican ese grafo, así que no hay forma de arreglarlo
  desde la UCM. Derivado a **`armada-os/armada#766`**.
- Descartado por el camino: swr2, `0560`, dos tplg distintas. El BE `dai 120` **sí** arranca; el que falla es el FE.

### ✅ Audio de auriculares: dos averías distintas
- **Volumen**: el citado `2109` (la etapa estaba clavada a +6 dB).
- **Conmutación**: el ecualizador del panel (`AYN Odin 3 EQ`) enlazaba su salida **a mano** al nodo de auriculares;
  al desenchufar, el sonido se quedaba en un nodo no disponible → **silencio hasta reiniciar el filtro**.
  Ahora el filtro **sigue al sink por defecto**, y un vigilante (`pocknix-audio-jack`) reengancha los enlaces y el
  sink por defecto cada 2 s (también tras reiniciar PipeWire).
- Añadido **suelo de latencia** (`default.clock.min-quantum = 512`) para evitar los xrun
  `snd_pcm_avail after recover: Broken pipe` cuando una app pedía buffers demasiado pequeños.

### ✅ Steam: por qué desaparecían nuestros atajos
- `pocknix-steam-sync` escribía las entradas del `shortcuts.vdf` con las claves en **minúscula** (`appname`/`exe`);
  Steam las descarta al arrancar. Corregido a **`AppName`/`Exe`** (formato canónico). Efecto visible: el tile
  “The Legend of Zelda: The Wind Waker HD” ya sobrevive a los reinicios de Steam.

### 🚀 Wind Waker HD v0.4.0 (port nativo ARM64) desde Steam
- Instalado desde el volcado propio (`.wux` + claves), **sin WProton**: es un **AppImage de Linux ARM64**.
- Cuatro causas encadenadas, todas resueltas en el lanzador: Steam lo ejecutaba bajo **Proton** (excepción por appid),
  las **capas Vulkan** del overlay lo mataban (`VK_INSTANCE_LAYERS`), **FUSE** no está disponible bajo Steam
  (`APPIMAGE_EXTRACT_AND_RUN=1`) y el launcher busca el juego en `$XDG_DATA_HOME/wwhd` (enlace + variable).
- Ajustes por defecto: **castellano**, **una sola pantalla** (sin ventana del GamePad), **1080p** interno (`1.5x`)
  y pantalla completa. Menú del juego sin teclado: **mantener SELECT ~1 s**.
- **Save states** del PC (slots 1‑3 + `last_session`) copiados y funcionando entre x86_64 y ARM.

### 🚀 Mandos en RetroArch (DeckStation)
- El mando físico lo agarra InputPlumber (`EVIOCGRAB`), así que solo emite el **virtual** “X-Box 360 pad”. El lanzador
  ahora lo busca **por nombre** (hasta 10 s) y lo pasa con `--appendconfig`; antes podía arrancar sin mando.

### ✅ Audio del altavoz: era la ruta, no el volumen de los amplificadores
- El altavoz lo mueven dos **AW88166**, pero su control `SPK_L/R PCM Playback Volume` es
  **atenuación** (0 = máximo, el valor de mute es `AW88166_MUTE_VOL`): leerlo a 0 **no** significa
  silencio. (Lo dimos por bueno al revés durante un rato; corregido.)
- El fallo real al volver de auriculares es de **ruta**: el códec deja encendidos `HPHL/HPHR`,
  `RDAC` y `CLSH`. La UCM los suelta al activar el altavoz y el vigilante reengancha el sink.
- **Conmutador instantáneo**: `pocknix-audio-jack` pasa de *polling* cada 2 s a **`pactl subscribe`**
  (con red de seguridad cada 10 s) y deja en el journal una línea con los **ms** que tarda, para
  poder medir ("tarda bastante" deja de ser una impresión).
- **Entrecortado de auriculares**: era la **compander** (`HPHL/HPHR_COMP`). Apagarla en la UCM no basta:
  **DAPM la vuelve a encender** al alimentar la ruta, así que el vigilante la apaga y la vigila en cada
  pasada. Verificado en la consola: audio limpio y conmutación de ~17 ms.

### 🚀 calvos-doctor — ya instalado
- `calvos-doctor` recoge kernel/paquetes/audio/panel/batería/logs, **redacta** (rutas, usuario,
  hostname, MAC, IP, SSID, seriales) y **solo envía con `--send`**.
- Colector **desplegado** en Cloudflare Workers: `calvos-reports.<cuenta>.workers.dev` → issues en
  `arcadematicas/calvOS-reports`. Probado de punta a punta (redacción verificada en servidor).
- El botón de informe del panel apunta a nuestro colector **sin tocar su código** (`PDC_REPORT_URL`
  exportada por `pocknix-steam`), así sobrevive a las actualizaciones del plugin.

### 🚀 Captura de vídeo
- `calvos-grabar`: graba la pantalla con el **encoder H.264 por hardware** (`qcom-iris-encoder`).
  Medido: 1080p60 **en tiempo real** (~27 Mbps); 5 s codificados en 1,36 s. Modo `kms` (todo,
  incluido QAM) y `x11` (solo el juego, sin root).
- `dock-check`: diagnóstico de la salida externa (DP‑1, modos, gamescope, sinks de audio).
  **Hallazgo**: no hay sink de audio HDMI/DP → para grabar sonido hay que usar el jack de 3,5 mm.
- `tools/gpu-135.sh`: el test de 15 min del PR #135, listo para correr **en el sistema de shuuri**.

### 🚀 calvOS-reports y calvOS-doctor (en marcha)
- Repo público **`arcadematicas/calvOS-reports`** para los informes del sistema.
- Diseño copiado de lo que hace bien el panel de Hooandee: **colector que redacta** (rutas, usuario, hostname,
  seriales) → **POST a un colector propio** → el servicio abre el issue. El cliente **nunca** lleva token.
- Pendiente: desplegar el colector (Worker de Cloudflare con el token como *secret*) y decidir si el primer envío
  se hace con el modal del panel vendorizado o con el futuro `calvOS-doctor` propio.

### 📄 Documentación y estado
- Nuevos: [`docs/REFRESH-60HZ-20261021.md`](docs/REFRESH-60HZ-20261021.md),
  [`docs/MIC-SOUNDWIRE-20261021.md`](docs/MIC-SOUNDWIRE-20261021.md), [`docs/UPSTREAM-BACKLOG.md`](docs/UPSTREAM-BACKLOG.md).
- Abierto en armada: **#766** (micrófono). PRs **#146/#147/#148** en shuuri sin respuesta todavía; **#135** espera
  test de GPU de 15 min + `journalctl -k | grep -iE 'gdsc|gmu|oob|hangcheck|recover'`.

---

## 📅 05–09 de octubre 2026 — repo propio (R2), kernel 7.2.9, Decky completo y el QAM

Semana de cierre del sistema: estrenamos **repo de actualizaciones propio**, subimos el kernel, dejamos **Decky
“de serie”** (CSS Loader + tema Eclipse + Panel de Control) y **arreglamos el QAM detrás del juego**. Todo verificado
en la Odin.

### 🚀 Repo propio en Cloudflare R2 (las Odin se actualizan solas)
- **`[pocknix]`** (`…r2.dev/sm8750`) + **`[pocknix-shared]`** (`…r2.dev/shared`) + **`[pocknix-base]`**
  (`…r2.dev/base`), **firmados** con nuestra clave `85C433EE12621EED`. Se **quita `[aur]`** (era el veneno: ofrecía
  paquetes que bajaban versiones). `devices/sm8750/profile.conf` pasa a `POCKNIX_SHIP_SOC_REPO=1`.
- La **base ALARM** (snapshot `20260826.2`) queda espejada en `r2:pocknix/base` (893 paquetes + tarball) → un `-Syu`
  resuelve la base del snapshot, **no de la ALARM viva**.
- **Actualización real verificada**: una Odin pasó de 7.2.4 → 7.2.6 (y luego 7.2.9) **sin “signature invalid”**, sin
  mezclar con ALARM y **sin errores BTF**. **Aclarado**: el fallo histórico **no era el kernel, era la mezcla de
  paquetes**. Ver [`docs/REPO-R2-CAUSA-RAIZ-2026-10-09.md`](docs/REPO-R2-CAUSA-RAIZ-2026-10-09.md).

### 🚀 Kernel 7.2.9 (+ parches externos)
- Bump 7.2.6 → **7.2.9** con **scan-priority de ath12k**, vblank TE en command-mode, `hw_done` antes del flip y
  **rails de WiFi always-on** (ArmadaOS/ROCKNIX). Ver `docs/KERNEL-7.2.9-BUMP-2026-10-06.md` y
  `docs/KERNEL-7.2.9-2-EXTERNAL-PATCHES-2026-10-06.md`.

### 🚀 Decky “de serie”: CSS Loader + tema Eclipse + Panel de Control
- **CSS Loader** (`SDH-CssLoader`, GPL) empaquetado y sembrado en `~/homebrew/plugins`; se instala como
  **`SDH-CssLoader`** (el nombre que usa Decky). Ver `docs/DECKY-CSS-LOADER-ECLIPSE.md`.
- **Tema Hooandee Eclipse**: un servicio de primer arranque lo **descarga del catálogo oficial, verifica el sha256 y
  lo deja ACTIVADO** (no se redistribuye). `pocknix-decky-theme-eclipse.service`.
- **Panel de Control** (Hooandee, GPL, v0.66.0) de serie, con **siembra-solo-si-falta** para que se autoactualice.
  En la Odin **funciona de verdad**: **TDP** (backend `arm-frequency-levels`, CPU+GPU), ecualizador, pantalla (color),
  límite de carga y mandos; los **ventiladores no** los detecta (van por `pocknix-fancontrol`).

### ✅ QAM detrás del juego — ARREGLADO
- **Se quita `--force-composition`** de `pocknix-steam` y de `sessions.d/steam`: con la base gamescope **OGC** (la que
  metimos por el HDR) ese flag **peleaba** con la composición y el QAM se quedaba **detrás**. ArmadaOS **no** lo usa; la
  base ya clasifica el overlay interactivo por `root_width`. Ver [`docs/QAM-DETRAS-DEL-JUEGO-2026-10-09.md`](docs/QAM-DETRAS-DEL-JUEGO-2026-10-09.md).

### ✅ Turnip de Valve a la 0.5.x
- `pocknix-vk-valve` sube de la 0.4.x (`gitabc426bb`) a la **0.5.x** (`gite07916b4`), como **payload per-game**.
- **Medida** (Dead Island): **FPS empate** (+0,5 %), **1 % low +31 %**, **tirones 22 → 3** → más suave. Ver
  [`docs/MESA-VALVE-0.5.x-PRUEBAS-2026-10-09.md`](docs/MESA-VALVE-0.5.x-PRUEBAS-2026-10-09.md).

### 🚀 Extras
- **Guía de actualización para terceros** (Davidusky y su IA): [`docs/ACTUALIZAR-ODIN-DAVIDUSKY-2026-10-09.md`](docs/ACTUALIZAR-ODIN-DAVIDUSKY-2026-10-09.md).
- **Recuperación de la tarjeta de 1 TB** (reflasheo + datos): [`docs/1TB-RECUPERACION-2026-10-09.md`](docs/1TB-RECUPERACION-2026-10-09.md).

### 🔎 Issue externo #1 (proyecto Holodor) — ACD del Adreno 830: NO nos afecta
- Otro proyecto (**Holodor**) que usa nuestro kernel reportó que los OPP altos del Adreno 830
  corren a media velocidad por `qcom,opp-acd-level` (`0038`/`0049`). **Reproducido: NO.** En
  7.2.9 el **FP32 escala lineal con el OPP** (338 GFLOPS @1100 vs 203 @660 → ratio 1,666 ≈ ratio
  de reloj) y en OpenGL igual (glmark2 1100 > 660) → **no tenemos el "half clock"**; su kernel es
  `7.1.3-33`. Respondido en el issue.
- **Sí** confirmamos su punto **térmico**: `gpuss0..7` sin cooling map → ver parche del trip
  pasivo ~95 °C.
- Detalle en [`docs/ADRENO830-ACD-INVESTIGACION-2026-10-09.md`](docs/ADRENO830-ACD-INVESTIGACION-2026-10-09.md).

---

## 📅 27–28 de septiembre 2026 — HDR, kernel 7.2.6, s2idle, sesión SteamOS y limpiezas

Dos días muy intensos: se recupera el kernel 7.2.6, se porta todo el trabajo de energía de armadaOS,
se **consigue el HDR** y se cambia la sesión de Steam al modelo de SteamOS. Todo verificado en la Odin.

### 🚀 HDR (conseguido)

- 🚀 **Kernel con color pipelines por plano**: LUTDMA (`dpu_hw_reg_dma`) + IGC/3D-LUT por plano en VIG
  y soporte de planos 10-bit (`ABGR/XBGR2101010`) — parches `0070`/`0071`/`0076`/`0077`/`0082`
  (portados de armadaOS, adaptado el hunk del catálogo VIG a nuestra entrada).
- 🚀 **gamescope re-baseado a OpenGamingCollective `3.16.29-ogc2`** (antes ROCKNIX/Valve 3.16.25) con
  **19 parches de armada** (`0101`–`0121`): perfil edidless + HDR del Odin 3 (650 nits, gamma 2.2),
  tonemap, output-LUTs, P3 y **color por plano**. Se descartaron los parches de rotación de ROCKNIX
  (la base OGC ya trae rotación); se mantienen `0009`/`0010`/`0011`.
- 🚀 **Perfil de panel del Odin 3** (`ayn.icna3520.oled.lua`, en `overlay/`) + `GAMESCOPE_INTERNAL_DEVICE_ID=ayn-odin-3`
  en `pocknix-steam` + `GAMESCOPE_EXPOSE_CLIENT_SAMPLEABLE_FORMATS=1` y `--hdr-itm-target-nits 650`
  (de armada). El log confirma `Got known display: armada_ayn_icna3520_oled` y `xwm: HDR output enabled`.
- ✅ **HDR funcionando** en `Ori and the Will of the Wisps` (WProton). *El toggle del QAM del cliente
  Steam ARM64 no se dibuja (gate interno del cliente, igual que en armadaOS), pero el juego pide HDR
  directo y funciona.*

### 🚀 Kernel 7.2.6 (recuperado)

- ✅ **El 7.2.6 deja de estar descartado**: las dos regresiones las arregla mainline con los parches de
  armadaOS — panel negro (`0048a`, DSI byte clock tras reparentar) y WiFi (`0514`/`0514a`, `iommu-map`
  con `#iommu-cells=2`). En 7.2.6, `0050`/`0055`/`0517` se saltan solos (ya en mainline).
- ✅ Compilado, instalado y verificado (panel `connected`, WiFi `connected:full`, sesión OK).

### 🚀 Energía (s2idle + ADSP)

- 🚀 **s2idle de armadaOS**: `0521` (PCIe suspend OPP), `0522` (D3cold), `0523`–`0526` (regulator
  suspend-state) + DTS (rails del códec en LPM + PCIe WAKE# active-low). Sleep 0.71 → 0.37 W (medido
  por armada). Verificado suspend/resume en la Odin.
- 🚀 **ADSP duerme al suspender con audio abierto** (`0528`/`0529`/`0613`, este último renumerado desde
  el `0530` de armada para ir *después* del `0612` de ROCKNIX). Verificado (audio OK tras resume).
- 🚀 **Extras** `0903` (battmgr charge-current) y `1007` (rsinput MCU supply en sleep).

### 🚀 Sesión de Steam (modelo SteamOS)

- 🚀 **gamescope-session-plus portado a Pocknix**: paquetes `gamescope-session` (motor OGC) +
  `gamescope-session-steam` (nuestra `sessions.d/steam` con geometría/rotación del panel,
  `GAMESCOPECMD` propio con `--force-composition` + `--rotated-output-max-height`, y
  `pocknix-steam-client`). **Reversible**: se activa con `~deck/.use-gsplus` y el supervisor
  `~/.bash_profile` elige; borrar el fichero vuelve a `pocknix-steam`.
- 🚀 Aparece la **VRS** (sombreado de velocidad variable) en el QAM con la sesión nueva.

### 🚀 Plugin PocknixControl

- 🚀 **Interruptor de HDR** en la pestaña System: lee/escribe los átomos de gamescope
  (`GAMESCOPE_DISPLAY_{SUPPORTS,HDR_ENABLED}`). El plugin corre como **root** y el X de gamescope exige
  cookie, así que el `xprop` se lanza **como `deck`** (`runuser`) — si no, salía "HDR no disponible".
- ✅ **Estado del OLED care**: el timer de 4 h no actualizaba `/run/pocknix/oled-care.json` → el plugin
  decía "sin refrescos" aunque sí refrescaba en modo juego. Ya lo escribe.

### 🎮 DeckStation / emulación

- ✅ **Naomi / Naomi 2**: faltaba la BIOS de NAOMI (DeckStation no la contemplaba) → añadida al
  manifiesto (`bios/naomi/` → `system/dc` de RetroArch). Subido a `stshunz/deckstation-arm` + centro.
- ✅ **Saturn**: `yabause`/`kronos` buscan `saturn_bios.bin` (la Odin solo tenía `sega_101.bin`) →
  añadido el alias. `yabasanshiro` no puede (pide OpenGLES3 y el RetroArch es OpenGL).
- ✅ **Launcher**: resetea el límite de FPS de gamescope al arrancar (evita heredar el 30/60 del último
  juego de Steam y que los emuladores vayan a media velocidad).

### 🧹 Limpiezas

- 🧹 **Watcher `xprop` retirado** de `pocknix-steam` y de la sesión: era redundante con el parche
  gamescope `0011` (`--force-composition` no cancelable por la propiedad X11).
- 🧹 **`set -x` retirado** del motor de gamescope-session-plus (llenaba el log de la sesión).
- 🧹 Corregido un **chown equivocado del chroot** de compilación (se dejó entero en uid 1000 y rompió
  el setuid de `sudo`); y limpiados los restos muertos de `packages/gamescope` en `tools/`.

### ⚠️ Gotchas de build documentados

- ⚠️ **Locks huérfanos de `repo-add`**: `make packages` muere en silencio tras el `-Syu`.
  `sudo find build/localrepo -name '*.lck' -delete` (y si sigue, lanzar `bash scripts/build-packages.sh <pkg>`
  directo, que ha funcionado).
- ⚠️ **`srccache` con ownership equivocado** (uid 1000 vs `builder` 1001) → makepkg "dubious ownership"
  → "is not a clone of". `chown -R 1001:1001` del `srccache` (NO del chroot entero).
- ⚠️ **Push bloqueado por el llavero**: usar `GH_TOKEN` del MCP de GitHub (`grep` en la config de opencode).

### ⚠️ Abierto al cerrar el día (28/09)

- ⚠️ **MangoHUD: FPS con caídas/desincronía** en todos los juegos (Steam, AppImages, WProton). El
  mangoapp calcula los FPS con los *nudges* de frame de gamescope (`mangoapp_nudge_app_frame`), así
  que si el compositor entrega frames irregularmente, el HUD lo refleja.
- ⚠️ **El QAM vuelve a quedarse detrás del juego** en algún caso (intermitente): se vio con
  `--force-composition` puesto y el parche `0011` instalado, y el DRM en 1 plano (composite) otras
  veces — no es permanente.
- **Hipótesis**: el **HDR estaba encendido GLOBALMENTE** (`GAMESCOPE_DISPLAY_HDR_ENABLED=1` por
  defecto del cliente), lo que obliga a gamescope a la ruta HDR + tonemap por frame en TODO (también
  SDR) y, con los planos de color por plano de armada, podría mandar el juego a su plano y dejar los
  overlays detrás. **Se dejó el HDR APAGADO** (átomo a 0) para probar; Fransis lo seguía notando "raro"
  pero sin confirmar. **Pendiente** de probar a fondo (con el toggle de PocknixControl) y, si se
  confirma, dejar el HDR apagado por defecto y encenderlo solo para juegos HDR.
- **A investigar**: mangoapp de OGC 3.16.29 vs el anterior; interacción del `--force-composition`/
  `0011` con el pacing; el límite de FPS.

---

## 📅 26 de septiembre 2026 — incidente de arranque: resuelto y documentado

Cierra el incidente del día 25. La imagen nueva no arrancaba y el primer diagnóstico
(transferencia/flasheo) era equivocado: **sí era nuestro software**. Se arregla la causa real y se
documenta para que no se repita.

### Corregido / solucionado

- ✅ **La imagen vuelve a arrancar**: iba con `nologreplay` como opción de montaje de btrfs — en el
  cmdline del kernel y en 5 líneas del `fstab`. En Linux 7.2 `nologreplay` **no es una opción
  válida** (solo `rescue=nologreplay`, y esa exige solo-lectura), así que btrfs rechazaba montar la
  raíz y el kernel paniqueaba **antes de userspace — sin ningún log**. Quitado de los dos sitios.
  Verificado en la Odin: arranca con asistente inicial, sonido, botones y WiFi.
- ✅ **Incidente documentado** (para que no se repita):
  `docs/INCIDENTE-2026-09-25-nologreplay.md`. `AGENTS.md` corregido: el veredicto anterior
  ("no es culpa del software / probable transferencia") queda marcado como erróneo.

### ⚠️ Notas (trampas descubiertas)

- ⚠️ **El kernel y sus módulos deben ser del MISMO build.** Un kernel compilado en otra máquina
  (aunque declare la misma versión y el mismo *vermagic*) **no sirve** para una imagen ya
  construida: el **BTF** no coincide, el kernel **rechaza los módulos** y te deja **sin mando y sin
  sonido**. Regla: "misma versión" ≠ "compatible" — mirar el **Image md5**. Kernel y módulos salen
  juntos del mismo entorno; **no recompilar solo el kernel** para una imagen ya hecha.
- ⚠️ **Deuda**: el cmdline del kernel vive **solo en el árbol** (`devices/sm8750/profile.conf`), no
  en el centro. Por eso un cambio de arranque se pudo colar sin revisión. Hay que subir esa fuente
  al centro.

---

## 📅 Semana del 22–25 de septiembre 2026

La semana más intensa en emuladores: se reparan los últimos fallos del gestor de
emuladores, se añaden sistemas nuevos y se integra todo con Steam. También es la
semana del incidente de arranque del día 25.

### Añadido

- 🚀 **Emuladores nuevos para el brazo del Odin**: se incorporan **RPCS3** (PlayStation 3)
  y **Xenia Edge** (Xbox 360) al instalador de emuladores, y se amplía el catálogo de
  ficheros de BIOS con Xbox, Nintendo DS, PS3, Amiga, GameCube, Cemu, PS Vita, Sega CD,
  MSX, PC Engine CD y 3DO. Para PS3 y Xbox 360 se crean además sus lanzadores propios:
  sin ellos no aparecerían en el menú de emuladores.
- 🚀 **Convertidor de ROMs integrado**: OpenROM 3.0.0 entra dentro de DeckStation para pasar
  tus juegos al formato que necesita cada emulador.
- 🚀 **Biseles (marcos decorativos) por fin visibles**: se instalan dentro de RetroArch
  (antes se quedaban a medio camino y no se veían) sin duplicarlos, y se limpia el
  temporal que dejaba el instalador. Además el instalador ya no se cuelga y **detecta solo
  dónde está la instalación**, en vez de tener la ruta del PC escrita a mano.
- 🚀 **Control de cómo se reparten el procesador y el disco**: se generaliza el sistema de
  "perfiles de rendimiento" y se **enlaza con los perfiles de energía del menú rápido de
  Steam** (bajo / medio / alto). La microSD pasa a usar la política de lectura `bfq`, pensada
  para que la carga de juegos vaya más fluida. En el plugin del menú de juego se muestra
  qué política está realmente activa, y se añaden dos herramientas: un diagnóstico y un
  script que manda los cambios a la consola sin recompilar nada.
- ✅ **El menú rápido de Steam y el indicador de FPS ya no quedan tapados por el juego**:
  se fuerza la composición de las capas para que se pinten por encima.
- El menú de emuladores **muestra solo los núcleos que están de verdad instalados** (antes
  aparecían en la lista cosas que no estaban).
- El gestor de emuladores ahora **abre a pantalla completa**, **no salta el teclado en
  pantalla**, se puede cerrar con una opción "Salir" o con Esc/B, y se corrigió un fallo
  que lo cerraba de golpe.
- Se añaden **configuraciones básicas para los emuladores que se usan sueltos** (aceleración
  por hardware y dónde buscar ROMs y BIOS), y los lanzadores de interfaz del sistema
  "Emuladores" del menú.
- El gestor de emuladores **valida los ficheros de BIOS por su huella digital (MD5)** y
  acepta rutas con subcarpetas. Se corrige la carpeta de PS2: el núcleo de PCSX2 de RetroArch la busca en otro
  sitio y por eso no encontraba nada.
- **Xenia se hace portátil** (tiene su propia carpeta de datos) y **MelonDS ya trae el mapeo
  del mando de Xbox**. Se activa la mejora de imagen (FSR) en RPCS3.
- Se añaden imágenes nuevas al programa de emuladores (logo, cabecera, portada e icono).
- Se traen al centro (este repositorio) las comprobaciones automáticas de que la copia del
  gestor de emuladores no se desvía de la del compañero, ampliadas con la lista de núcleos.
- Se ignoran las copias de seguridad de imágenes al guardar en el repositorio, para que no
  se suban por error.
- Se escribe la **guía completa de repositorio, versiones, paquetes y actualizaciones**.

### Corregido / solucionado

- ✅ **Arranque más robusto tras un corte de luz**: la tarjeta se monta con opciones que
  evitan que se rompa si apagas la consola de golpe.
- ✅ **Se documenta el incidente del 25/09**: la Odin entró en bucle de reinicio con el
  núcleo en pánico al flashear la imagen nueva. El análisis concluye que **el contenido de
  la imagen es correcto**, así que la causa más probable es la transferencia o el flasheo,
  no nuestro software. Aun así se refuerza el arranque (protecciones de montaje + arranque
  visible y diagnosticable) por si vuelve a pasar.
- ✅ **Herramientas para mandar cambios a la consola por red**: el uso de `sudo` se comía los
  datos que se enviaban por el canal de copia; ahora se empaqueta en un fichero temporal y se
  manda aparte.
- ⚠️ Se deja anotado que falta **instalar y probar en la consola** el enlace entre los perfiles
  de energía de Steam y las políticas de procesador/disco (ya está implementado aquí, pero
  sin verificar en vivo).

### Cambiado / notas

- La **integración de DeckStation en Steam pasa a ser automática** (ya no hay que activarla a
  mano) y añade las imágenes al estilo de la biblioteca de juegos. Además se detecta mejor si
  estamos en modo juego, y deja de ser "opcional".
- Se retira la opción "DeckStation BIOS" del menú de herramientas de Pocknix: era redundante
  porque ya está dentro del gestor de emuladores.
- 🧹 **Se retira el programa de instalación antiguo de aplicaciones** (lista de repositorios escrita a
  mano que no estaba conectada a nada); su trabajo pasa al gestor de emuladores. PPSSPP
  también pasa a instalarse desde ahí.
- Se unifica en un solo sitio el **documento de contexto del proyecto** (el que se carga solo
  al trabajar aquí), que estaba repartido entre el PC y el repositorio.

---

## 📅 Semana del 15–21 de septiembre 2026 — segunda mitad (17–21)

Semana grande de emulación. Se rescata la tarjeta corrupta, se vuelve al núcleo bueno, se
consigue **que la pantalla gire sin usar la GPU**, el gestor de emuladores se convierte en el
instalador de verdad y el plugin del menú de juego se amplía mucho.

### Añadido

- 🚀 **El gestor de emuladores pasa a ser también el instalador inicial**: desde las
  herramientas de Pocknix se prepara todo el entorno y se instalan los ~30 emuladores de una
  tacada. Se documenta la idea de fondo: *"dos puertas, un único motor"* — una para instalar
  (una sola vez) y otra para gestionar siempre, pero el motor es el mismo, para que un fallo
  de la ventana no deje al usuario sin poder instalar.
- 🚀 **254 núcleos de emulación** (se pasa de 165 a esa cifra) y **RetroArch completo ya en la
  primera instalación**, con los **perfiles que más usa Fransis** y los efectos de imagen
  (Mega Bezel, CRT y el de consolas) guardados en el repositorio.
- 🚀 **El núcleo de Suyu (Nintendo Switch) ya está compilado para el brazo del Odin** y entra
  en la imagen, con un parche nuestro que **añade la opción de idioma de la consola** → los
  juegos de Switch salen en español (antes salían siempre en inglés). También se prepara ese
  mismo núcleo para PC (x86), compilándolo dentro de un contenedor con una biblioteca
  antigua, para poder usarlo en un Deck o un PC.
- 🚀 **Herramientas nuevas**:
  - "¿Están al día los controladores de la GPU?" (`check-mesa.sh`).
  - "Sostén la tarjeta" (`check-deckstation-libs.sh`): revisa qué librerías les faltan a los
    emuladores.
  - Poner y recuperar el núcleo de la consola (`flash-kernel.sh` y
    `restore-kernel-from-sd.sh`).
  - `reflash-sd.sh`: re-flashear la tarjeta de forma robusta.
  - Herramientas para trabajar sin re-flashear la tarjeta: *(añadidas el día 16, ver la
    sección siguiente)*.
- 🚀 **Juego remoto (Moonlight) y DeckStation aparecen en el modo juego de Steam**, y la
  preparación de DeckStation ofrece además WProton con su propia entrada.
- 🚀 **"Distribuidor de BIOS del usuario"**: el usuario deja sus ficheros donde quiera y el
  script los reparte a la carpeta correcta de cada sistema. Se documenta la instalación
  inicial completa.
- 🚀 **Plugin del menú de juego ampliado**:
  - **Luz de color en los joysticks**: el mando se ilumina del color que elijas, y **ahora
    se puede apagar solo el izquierdo o solo el derecho** conservando su color y brillo.
  - **Estado del cuidado del panel (OLED)**: la pestaña de luces muestra cuándo se ha
    refrescado la pantalla y por qué se ha saltado (antes no había ningún aviso y parecía
    que no funcionaba).
  - Nueva pestaña **"Limpieza"**: cachés y registros, más un analizador de espacio en disco.
  - Nueva pestaña **"Sistema"**: incluye WProton y los emuladores.
- ✅ **El cuidado del panel ya no refresca la pantalla mientras estás jugando** y vuelve a
  detectar los mandos/lectores al reanudar.
- Se despliega el script de configuración a los emuladores y **se hacen legibles sus
  configuraciones**; ya no hace falta descargar un paquete de configuración de un servidor
  externo (era solo para PC).
- Se **sincroniza nuestra copia del gestor de emuladores con el repositorio del compañero**
  (stshunz) trae muchas mejoras: el menú de emuladores (ES-DE) se baja ya de la fuente
  oficial, dependencias reales (7zip), requisitos documentados, corrección de la ruta de los
  núcleos de RetroArch, un núcleo por defecto en cada sistema, carpeta propia para cada
  emulador instalado, y un plan de portabilidad a otras distribuciones.
- Se añaden notas de sesión de los días 17 y 18 (núcleos, configuraciones, BIOS, cuidado del
  panel) y se actualizan los huecos conocidos.

### Corregido / solucionado

- ✅ **La tarjeta SD se había corrompido y era irrecuperable** (el sistema de ficheros no
  montaba). Se recupera lo posible, se **re-flashea desde cero**, se reformatea la partición
  de Windows (que también estaba corrupta) y se restauran los datos del usuario y la carpeta
  de programas. El re-flasheo también se arregla para que no lleve escrito el número de
  usuario del PC (en la Odin es otro).
- ✅ **Se vuelve al núcleo bueno (7.2.4)**: el 7.2.6 traía **dos regresiones graves** (pantalla
  negra y WiFi que no arranca) y queda descartado. Se documenta por qué, con medidas.
- 🚀 **Rotación de pantalla sin usar la GPU conseguida**: la pantalla gira sin coste de GPU (lo
  hace el chip de vídeo por su cuenta). Se documenta con guía de verificación, incluidas las
  dos trampas que hubo que superar.
- Se traen los parches de rotación del proyecto de referencia (ROCKNIX) y se **limpian los
  parches que ya vienen incluidos** en esa versión.
- ✅ **Los emuladores instalados quedaban sin poder arrancarse**: faltaba el lanzador y su
  carpeta de datos. Ahora se despliega automáticamente desde tres sitios (la instalación, el
  propio lanzador al arrancar y el gestor tras cada instalación), así que se auto-repara.
- ✅ **Cinco fallos impedían instalar los 30 emuladores**: si uno fallaba, se paraba la cola
  entera. Ahora se anota el fallo y se sigue con el siguiente, con un resumen al final.
- ✅ **El gestor de emuladores se abría en negro** cuando arrancaba Steam: elegía el modo de
  pantalla equivocado. Se corrige para que funcione tanto en sesión gráfica como en la de
  Steam.
- ✅ **El instalador inicial ya no descarga RetroArch de Android**: eso rompía RetroArch en una
  instalación limpia. Ahora baja solo los recursos de la interfaz y enlaza los núcleos que ya
  trae el sistema.
- ✅ **Librería `libxss`**: se declara como dependencia y se revierte (el entorno de compilación
  no la puede resolver). Se pasa a "cosecharla" del propio Steam en el momento de instalar.
- ✅ **El gestor de emuladores en versión de brazo**: se corrigen las rutas de los
  emuladores, que apuntaban donde no era.
- ✅ **El camino de instalación del gestor** (carpetas con subcarpetas) y el apartado de BIOS
  (faltaba la rama en el menú) quedan activados.
- ✅ **La ruta del fichero compilado del núcleo de Switch** estaba mal, así que no se
  encontraba.
- ✅ **Gestión de ficheros compartidos (Samba)**: la instalación fallaba por el formato de
  versión de los paquetes (había que instalar la familia entera junta, no un paquete suelto).
- Se corrigió el **uso de las librerías de emulación antiguas** (fuera del camino obligatorio
  de compilación) y se trajeron al centro los paquetes de núcleos que solo vivían en el
  árbol de compilación (se perdían en silencio).
- Se anotan y se dejan escritas dos decisiones pendientes: la prueba del limitador de FPS del
  menú de Steam y si conviene un tipo de fichero distinto en el disco interno.
- Se aplica un ajuste de rendimiento (evitar copias al escribir) en los registros, la caché y
  la biblioteca de Steam.

### Cambiado / notas

- 🧹 **Este repositorio se convierte en EL CENTRO del proyecto**: se reescribe el README (que
  estaba desfasado desde antes de la reorganización) y se documenta la deriva entre la consola
  y el repositorio, incluidos dos fallos de sincronización encontrados (el cargador de arranque
  y la capa de gráficos).
- Se documenta **cómo se añaden paquetes** a la imagen, incluidas las tres trampas que han
  mordido y dónde va cada cosa.
- Se deja escrito que el interruptor de MangoHud está bien como está y **no se toca**: el
  indicador de FPS funciona perfectamente desde Steam (se había dudado de ello).
- Se documenta la **segunda pasada del estudio de ArmadaOS/ROCKNIX**: qué queda por
  aprovechar.
- Notas de la primera imagen oficial (`v0.4-odin3-1`).
- Se retiran de la documentación las cosas que se decide no hacer (el script puntual del
  núcleo de Switch para PC).

---

## 📅 Semana del 15–21 de septiembre 2026 — primera mitad (15–16)

Semana de orden interno y de arreglo de los fallos de arranque. Se reorganiza el proyecto
para que nada se pierda, y se corrigen tres problemas que impedían que la consola arrancara
bien.

### Añadido

- 🧹 **Reorganización: este repositorio pasa a ser EL CENTRO del proyecto**. Se crean las
  carpetas de paquetes, herramientas y ficheros que van al sistema, y se escriben dos
  herramientas nuevas: una que **copia el centro al sistema que se compila** y otra que
  **comprueba que no se ha quedado nada atrás** (la propia compilación la llama y para si no
  cuadran). Regla de oro documentada: se edita siempre aquí.
- Nuevo **paquete de "sistema base" para el chip SM8750** + metapaquete, que agrupa los
  servicios y ficheros propios del Odin.
- 🚀 **Pantalla de arranque del Odin 3** (la animación de encendido) dibujada directamente en
  pantalla, y **reducida** (960x540, 24 MB) porque la versión completa ralentizaba el arranque.
- 🎤 **Los 3 huecos de la auditoría**: micrófono, pantalla de arranque y refresco del panel.
- **Herramientas para trabajar sin re-flashear la tarjeta** cada vez: mandar un cambio a la
  consola por red o copiar un fichero suelto. Esto cambió la forma de trabajar del día a día.
- **Guía `BUILD.md`**: cómo compilar el Odin 3 desde cero, para colaboradores. Verificada
  clonando el repositorio en limpio.
- **MAKO** (escalado sin pérdida y generación de frames) queda integrado en el plugin, y se
  documenta por qué **no puede funcionar en la Odin**: su motor es solo para PC, y aquí los
  juegos de PC se traducen al vuelo. La integración queda lista y se abre una petición en su
  proyecto pidiendo una versión para ARM.

### Corregido / solucionado

- ✅ **El audio volvía a romperse entero** al añadir la configuración del micrófono → se
  revierte (el micrófono, de momento, no queda soportado).
- ✅ **Bucle de reinicios (434 seguidos)**: un servicio de sensores se quedaba reiniciándose
  solo. Se desactiva ese servicio concreto y se activan los que sí sirven.
- ✅ **Bucle de reinicio del asistente inicial de Steam**: al mezclar la actualización del
  proyecto original **se perdieron 6 cambios nuestros**; se recuperan y, sobre todo, se activa
  de verdad el servicio que marca el asistente (que se había quedado sin arrancar).
- ✅ **El parche de rotación de la GPU no llegaba a la imagen**: faltaba añadir el chip
  SM8750 a la lista del paquete que se instala.
- Se regenera el parche de la GPU Adreno que no aplicaba, y se rehace el paquete de sistema
  base sobre la versión ya verificada (el nuestro estaba duplicado).
- Se recupera lo que faltaba del núcleo y del cargador de arranque en la rama del proyecto.
- Se integra el parche del **limitador de FPS del menú rápido de Steam**.
- La **compilación usa todos los núcleos del PC** de forma permanente, y la capa de emulación
  antigua del proyecto original pasa a ser opcional (ya no estorba para compilar).
- Se corrigen rutas en el script de comprobación.

### Cambiado / notas

- Se documenta el modelo de ramas del proyecto y el "detector de regresiones" que hay que
  pasar tras cada actualización del proyecto original (porque ya nos ha pisado cosas tres
  veces).

---

## 📅 Semana del 8–14 de septiembre 2026

Semana de **batería cargando**, **escritorio que ya ve la pantalla**, **suspensión real**, y
el **arranque a 20 segundos**. Es el salto de "arranca pero a medias" a "arranca bien".

### Añadido

- 🚀 **Estudio completo de ArmadaOS** (el sistema que trae la Odin de fábrica, con el que se
  puede hacer comparativa directa) con informe, **scripts de referencia guardados** en el
  repositorio e índice.
- 🚀 **Se implementan varias mejoras venidas de ese estudio**:
  - Los interruptores que SteamOS activa (frecuencia variable, HDR, varias capas, etc.): antes
    no activábamos ninguno.
  - Un módulo que pasa las variables de pantalla a los servicios de la sesión: **arregla un
    fallo del servicio de pantalla** que se caía al cambiar de sesión.
  - El envoltorio de los juegos de Windows: **inyecta las librerías de mando que faltaban**
    (el mando estaba muerto), **repara un mando que se quedaba atascado** y desactiva la
    superposición del indicador de FPS.
- 📘 **Guía de los botones del mando del Odin 3**: el botón "atrás" pasa a "Acceso Rápido"
  para que funcione el menú de Steam, y **se conserva** el atajo del indicador de FPS.
- **Notas para el proyecto original**: el texto del PR de soporte del Odin 3 y la nota del
  asistente inicial de Steam. También se atendieron las peticiones del creador (petición #54) y
  se dejó constancia en el comentario.
- **Se re-sincroniza la rama limpia del PR con ROCKNIX** y se compila el núcleo 7.2.0. Por el
  camino se arregla un detalle que impedía compilar en un PC: los programas de arquitectura
  ARM no podían instalar dependencias por un problema de permisos.
- Se crea el **fork propio del repositorio del sistema** y la rama de trabajo del proyecto.
- Documentación: cómo activar el modo de pantalla completa de la capa de gráficos y dónde
  está el mecanismo de HDR; los ficheros de configuración de la sesión, el mapeo de mandos y
  la traducción de programas de PC de ArmadaOS.

### Corregido / solucionado

- ✅ **La batería ya carga en Pocknix** (¡hito!). La causa era que el firmware del cargador
  echaba a la batería a "modo de prueba" por no reconocerla. Se resolvió con el fichero de
  configuración adecuado, se dejó **permanente en la compilación** y se escribió una guía para
  poder reproducirlo. Se corrige también una lectura de diagnóstico que se interpretaba al revés.
- ✅ **El botón de encendido ya suspende de verdad** y la pantalla se enciende al despertar.
  Antes solo parpadeaba. Se documenta el problema y los dos bloqueos que hubo que quitar.
- ✅ **Ajustes → Pantalla ya ve el monitor** en el escritorio: faltaba instalar un paquete.
  El paquete de escritorio completo ya lo incluye de serie. Además se aclara que el aviso rojo
  del servicio de pantalla al cambiar de sesión es un falso positivo, no un fallo.
- ✅ **El servicio de la pantalla ya no falla** (usaba una ruta que ya no existe) y
  **Bluetooth queda activado** (se había quedado bloqueado sin dar error).
- ✅ **El arranque baja a ~20 segundos** (medido: 11 s de núcleo + 9 s de usuario): el
  diagnóstico ya no bloquea el arranque y Steam **espera a que la pantalla esté conectada**
  antes de arrancar (si no, se lanzaba antes y la salida se quedaba a oscuras).
- ✅ **El asistente inicial de Steam ya no entra en bucle de reinicios**: faltaba el fichero
  que lo marca, y además el programa de actualización **decía "hecho" cuando no había nada que
  hacer**, así que Steam pedía reiniciar en bucle. Verificado: el asistente termina y llega
  al inicio de sesión.
- ⚠️ **La imagen limpia arrancaba sin WiFi ni sonido**. Se documenta la causa: los ficheros de
  firmware del Odin 3 **no vienen en el paquete estándar de Linux** (ni el del WiFi, ni el
  del audio, ni el del procesador de sonido). Referencia: `docs/FIRMWARE-ISSUE.md`.
- Se corrige el apagado lento (el WiFi se reconectaba solo y lo bloqueaba) y se deja escrito
  el recetario de la sesión de juego (reinicio/apagado desde Steam, pantalla negra recuperable).

### Cambiado / notas

- Se deja constancia de la pista nueva para el problema de carga (abierta en el proyecto de
  ArmadaOS) y de las notas de DeckStation.
- Se escribe una **petición de ayuda en inglés** para el Discord de AYN/Armada sobre el
  problema de carga.
- Se crea el documento de contexto del proyecto con el estado de carga ya documentado.

---

## 📅 Semana del 1–7 de septiembre 2026

Primeros resultados en serio: el mando por cable, los juegos de Windows, el menú rápido de
Steam y el porcentaje de batería.

### Añadido

- 🚀 **Se adopta el modelo de SteamOS** para la sesión de juego: la capa que dibuja los juegos
  como proceso independiente y Steam como proceso hermano, más un servicio que gestiona el
  interruptor del indicador de FPS de forma resistente.
- 🚀 **Gestor de SteamOS**: un programa pequeño que se hace pasar por el gestor oficial para
  poder cambiar el **perfil de rendimiento (bajo / medio / alto) desde el menú rápido de Steam**
  — y para volver al escritorio o al modo juego de verdad.
- Se integra el **parche que arregla el limitador de FPS del menú rápido en arquitectura ARM**
  (venía de otro proyecto, Nova-Deck).
- Se amplía el plugin del menú de juego: **gestión de potencia** (ventilador, velocidad del
  procesador, perfiles), **indicador de FPS adaptado al chip del Odin**, y una **pantalla de
  vigilancia** que reinicia lo que se cuelga.
- Se mejora el plugin para que detecte los juegos que no pasan por el lanzador de Pocknix y
  para que los ajustes por juego se apliquen **en vivo** al guardar.
- Se escribe la **guía de reproducción del arreglo de carga de la batería** y el documento de
  contexto del proyecto.
- Se ignoran las copias binarias del núcleo al guardar en el repositorio.

### Corregido / solucionado

- ✅ **El porcentaje de batería ya no se queda congelado** y avisa antes de apagarse: antes
  solo se leía al arrancar, así que se quedaba clavado y los apagones por batería no daban
  aviso.
- ✅ **El porcentaje de batería ya no marca siempre lo mismo**: se calculaba con un valor de
  voltaje que el firmware solo informa una vez; ahora se estima con el voltaje real, corrigiendo
  la caída por la resistencia interna de la batería.
- ✅ **El mando por cable ya funciona en los juegos de Windows**: le faltaban permisos de
  lectura, así que no lo veían ni Proton ni WProton.
- Se investiga la carga a fondo: **desensamblando el módulo de Android se descubren los
  códigos que el firmware de esta unidad espera** y se escribe el parche correspondiente. Al
  día siguiente **se revierte** (el código original era el correcto, verificado contra el
  proyecto de referencia) y **se deja documentado el hallazgo** para cuando haga falta.
- Se añade el parche de activación de carga de referencia y el programa que cambia de sesión
  de verdad.

### Cambiado / notas

- Se cambia la estimación de batería a "v5": voltaje de la curva de una batería de iones de
  litio en vez del contador de coulomb (que en esta placa no existe).

---

## 🚀 Del 25 de agosto al 2 de septiembre 2026 — el punto de partida

Cuatro días que montan casi todo lo que luego se ha ido puliendo. Es el registro grande que
presenta el soporte del Odin 3.

### Añadido

- 🚀 **Soporte de la AYN Odin 3 (chip SM8750 / GPU Adreno 830)** en el repositorio del sistema.
  Trae el fichero de descripción del dispositivo (panel, WiFi, mando) y **un arreglo para el
  fallo de la GPU** que reiniciaba el controlador y dejaba la pantalla en negro.
- **Audio, batería, menú rápido de Steam, rotación de pantalla, suspensión y sensores** como
  parte del paquete propio (no como parches sueltos).
- **Suspensión falsa** (apagar pantalla y poner el procesador en ahorro) como medida
  temporal: se evita un cuelgue que se atribuía al hardware y **más tarde se confirmó que la
  premisa era falsa** (lo que cuelga es la suspensión profunda, no la normal) — se resolvió
  con la suspensión real el 11/09.
- **Cuidado automático del panel OLED** y **arreglo de la traducción de programas de PC**
  (FEX).
- **Cuaderno de ideas** (`IDEAS.md`) con lo que queda por plantear.
- Se integran los ficheros de configuración **reales de Android** para los sensores (los que
  trae la consola de fábrica) en el servicio de sensores.
- Se corrige la **ruta del firmware de audio y procesador** en la descripción del dispositivo,
  y se empieza con el **núcleo 7.1.0** (que luego resultó no servir: el bueno es el 7.2).
- **Controlador del mando por cable del Odin 3** (portado a la versión 7.2): sin él, el
  mando no se detectaba.

### Corregido / solucionado

- ✅ **Pantalla negra al cambiar de sesión**: documentado y resuelto (era la ruta que usaba
  la capa de pantallas).

### Cambiado / notas

- ⚠️ **Problema abierto desde el día 1**: Ajustes → Pantalla no ve el monitor en el escritorio
  (se resolvió el 11/09 installando el paquete que faltaba).
- Ajustes de sesión para el sonido, el control de ficheros abiertos, el mapeo de mandos y
  la red (WiFi).
