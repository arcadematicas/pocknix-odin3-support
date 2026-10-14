# PR #135 (shuuri, rama `sm8750-odin3`) — checklist B1 + borrador del comentario

Creado el **14/10/2026**. Objetivo (A1 del roadmap): validar el build de su rama, pasar la **checklist B1**
en la Odin y **comentarlo en el PR**. Aquí va la checklist para ir tachando y el borrador del comentario.

Contexto: build fresco en el PC (`~/pocknix-upstream-test`, wrapper `~/bin/build-shuuri5.sh`);
kernel **7.2.10**, BSP en layout `root/`+`boards/`, ABL **1.2**, `POCKNIX_PANEL_WAIT=30`,
`pocknix-steam 0.1.0-70`, firmware con el par ADSP en `ayn/odin3/`.
⚠️ Su cmdline **NO** lleva `oops=panic panic=5` (el nuestro sí) y usa `quiet loglevel=3` + plymouth.

---

## A) Checklist B1 (en la Odin, con la imagen flasheada)

| # | Prueba | Cómo | Resultado |
|---|---|---|---|
| 1 | **WiFi** conecta y aguanta | `nmcli device status` · `iw dev wlan0 link` · **¿conecta a la primera tras reiniciar o necesita reintentos?** (esta es la medida "antes" del regdb) | |
| 2 | **Audio** altavoces + jack USB-C | `wpctl status` · `pactl list short sinks` · reproducir algo | |
| 3 | **Suspensión s2idle** y vuelve | `cat /sys/power/mem_sleep` (debe decir `s2idle`) · botón de encendido · `rtcwake` NO vale (no corre los hooks) | |
| 4 | **Mandos**: gamepad UART + paddles | `ls /dev/input/` · `evtest` (paddles = M1/M2) | |
| 5 | **Rotación en gamescope** ⚠️ | Parche **NUEVO** de rotación inline: vigilar **pantalla negra** o **30 fps fijos**. Mirar `xprop -root \| grep -i GAMESCOPE` y FPS con MangoHUD | |
| 6 | **Salida DP del dock** | Conectar el dock y `kscreen-doctor -o` / poner un juego | |
| 7 | **Batería** coherente | `upower -d` · `cat /sys/class/power_supply/*/capacity` · estado de carga | |
| 8 | **Arranques en frío con `POCKNIX_PANEL_WAIT=0`** | ⬅️ **PETICIÓN EXPLÍCITA DE SHUURI**: *"could you cold boot **3-5 times** with the panel wait off"* → `echo POCKNIX_PANEL_WAIT=0 \| sudo tee -a /etc/pocknix/device.conf` · y **arrancar en frío 3-5 veces** mirando si el panel sale **negro** alguna vez (si nunca, él quita la clave) | |

### Lo que shuuri pidió vigilar (texto literal de su comentario del 12/10)
> *"Please look out for: **black screen or being locked to 30 fps in gamescope** (ROCKNIX's inline rotation patch),
> **dock DP output**, and **battery values in `/sys/class/power_supply`**."*

> *"Also, could you **cold boot 3-5 times with the panel wait off** (`echo POCKNIX_PANEL_WAIT=0 | sudo tee -a
> /etc/pocknix/device.conf`)? Neither ROCKNIX nor armada needs it, and the panel driver changed in this sync,
> so if it never actually comes up black I'll drop it."*

> Sobre la batería: *"I dropped the simple-battery node for now, since 5000 mAh doesn't match the 8000 mAh AYN
> quotes on their website and it does show up in sysfs. **If you have a source for the numbers I can put it
> back up**."* → **ya respondido por nosotros el 13/10** con 3 fuentes (el `model_name` del propio pack
> `…8000MAH…`, `charge_full ≈ 7,85 Ah` y la ficha de AYN) → pendiente de que él la reponga.

> Docs relacionados en este repo: `ROTACION-HARDWARE.md`, `PRUEBAS-MESA.md`, `SUSPEND-ISSUE.md`,
> `BATTERY-ISSUE.md`, `ODIN3-ARRANQUE-Y-WIFI-2026-10-08.md`, `INCIDENTE-2026-09-25-nologreplay.md`.

---

## B) Fallos del build de su rama — **TODOS de upstream**, no suyos (para el comentario)

Build completo (`make packages`, 23 paquetes): ~18-19 OK, **5 fallos**, todos en paquetes de la capa de
emulación / sched_ext de upstream:

| Paquete | Error literal | Causa |
|---|---|---|
| `armsx2-bin`, `rpcs3-bin`, `xemu-bin` | `cp: cannot stat 'squashfs-root/.DirIcon': No such file or directory` → `ERROR: A failure occurred in prepare().` | Los AppImage nuevos **ya no traen `.DirIcon`**. El PKGBUILD tiene un guard **a propósito** (`[ -s "${srcdir}/icon.svg" ]  # fail the build if the icon vanished upstream`) pero revienta antes, en el `cp`, con mensaje confuso. Mismo patrón en los 3 (probable también `vita3k-bin`) |
| `vita3k-bin` | `ERROR: One or more files did not pass the validity check!` | **Distinto**: el **sha256 de la fuente no cuadra** (upstream movió/cambió el asset). Hay que actualizar `sha256sums` |
| `scx-scheds` | `thread 'main' panicked at scheds/rust/scx_p2dq/build.rs:23:10: failed to generate '.../out/bpf.bpf.o'` → `Caused by: Failed to generate skeleton for bpf.bpf.o` → `Broken pipe (os error 32)` | Falla el **generador de skeletons BPF** del scheduler nuevo `scx_p2dq` (scx-scheds 1.1.3). El build **continúa** con lo anterior del `localrepo` |

En el chroot y **sin importancia**: `mkinitcpio: ERROR: failed to detect root filesystem` (×2, no hay
dispositivo raíz en el chroot) y el hook de `pocknix-base` ("stamping os-release") → `error: command failed
to execute correctly`.

**Construido OK en su rama** (por si quieres citarlo): `linux-pocknix-sm8750 7.2.10`, `gamescope
1:3.16.31.rocknix.20260927.f6916aa`, `mesa 2:26.2.4`, `mangohud`, `fex-emu-2610`, `cemu`, `dolphin-emu`,
`azahar`, `es-de`, `deckstation-arm`, `fex-rootfs`, `pocknix-bootloader-sm8750 1.2`, …

---

## C) Borrador del comentario para el PR #135 (completar con los resultados de B1)

> **Probado en la AYN Odin 3** con un build fresco de `sm8750-odin3` (squashfs/chroot reusado, `DEVICE=sm8750`).
>
> **Resultado del build**: los paquetes construyen; los únicos fallos son de paquetes de la capa de
> emulación y de `scx-scheds` de upstream (no de tu enablement):
> 1. `armsx2-bin`, `rpcs3-bin`, `xemu-bin` (y probablemente `vita3k-bin`): los AppImage ya no traen
>    `.DirIcon` y el `prepare()` muere en el `cp` antes de llegar al guard `[ -s icon.svg ]`. Con
>    `cp ... || true` (o extrayendo el icono de otra ruta) se arregla.
> 2. `vita3k-bin`: `One or more files did not pass the validity check!` → sha256 de la fuente desactualizado.
> 3. `scx-scheds 1.1.3`: panic en `scheds/rust/scx_p2dq/build.rs:23` (`Broken pipe` al generar el skeleton BPF).
>
> **Checklist B1 en la consola** (kernel 7.2.10, ABL 1.2):
> - wifi: …
> - audio: …
> - suspensión s2idle: …
> - mandos + paddles: …
> - rotación en gamescope (⚠️ parche inline nuevo): …
> - DP del dock: …
> - batería: …
> - arranques en frío con `POCKNIX_PANEL_WAIT=0`: …
>
> **Notas**: (a) vuestro cmdline no lleva `oops=panic panic=5` (el nuestro sí) → ¿lo metemos?;
> (b) …

---

## D) Fallos del **`make sd-image`** de su rama (14/10/2026) — **también suyos**

Al pasar de `make build` (rootfs OK) a `make sd-image` aparecen **dos** fallos consecutivos, ambos en su árbol.
Nosotros ya tenemos los dos cubiertos en el fork, así que la imagen de la Odin 3 **no se puede generar desde su
rama sin parchearlos**:

**D1. `SD_SLACK_MIB` demasiado bajo** → aborta el poblado del btrfs:
```
error btrfs root has only 493 MiB free after populate (< 512 MiB) — raise SD_SLACK_MIB or check compression
make: *** [Makefile:35: sd-image] Error 1
```
- Su `config/pocknix.conf:79`: `: "${SD_SLACK_MIB:=1024}"` · `scripts/build-sd-image.sh:283` exige **≥512 MiB libres**.
- **Nosotros lo subimos a `2048` el 26/09** exactamente por esto.
- Como la línea usa `:=`, **la variable de entorno manda** → se arregla sin tocar su fichero:
  `sudo DEVICE=sm8750 SD_SLACK_MIB=2048 make sd-image` ✅ (así lo hemos hecho).

**D2. `copy_abl_kit()` usa `rsync -a` sobre una partición vfat** → al copiar el kit del ABL a la FAT:
```
rsync: [generator] chown ".../rocknix_abl" failed: Operation not permitted (1)
rsync: [receiver]  chown ".../rocknix_abl/.abl_signed-SM8750.elf..." failed: Operation not permitted (1)
rsync error: some files/attrs were not transferred (see previous errors) (code 23)
make: *** [Makefile:35: sd-image] Error 23
```
- **`vfat` no soporta dueños** y `-a` incluye `-o -g` → `chown` da EPERM.
- Afecta a `copy_abl_kit` (**camino ABL/qcom, el de la Odin 3**) y a `populate_arm_efi_boot` (arm-efi).
  La línea 265 (`rsync -aHAX --numeric-ids ROOTFS/ MNT/`) va a **btrfs** → ahí `-o/-g` sí valen y **no se toca**.
- Fix mínimo aplicado en local (con backup del script):
```diff
-  rsync -a "${kit}" "${mnt}/"
+  rsync -rltD --no-owner --no-group "${kit}" "${mnt}/"
-  rsync -a "${bl}/EFI" "${bl}/boot" "${mnt}/"
+  rsync -rltD --no-owner --no-group "${bl}/EFI" "${bl}/boot" "${mnt}/"
```
- ⚠️ **D2 solo aparece después de arreglar D1** (el aborto por espacio ocurría antes) → **probablemente nadie ha
  llegado a generar una imagen de la Odin 3 desde su rama todavía**. Con los dos parcheados, completa.

---

## E) WiFi en la Odin 3 con su rama — hallazgos de la PRUEBA EN VIVO (14/10/2026)

Probado **con la imagen ya flasheada en la SD** (parcheando la SD offline desde el PC, sin rehacer el build).

**E1. `wlan0` SÍ se crea** — pero **falta el blob `WCN7860`**: en la imagen, `usr/lib/firmware/ath12k/`
trae `IPQ5424`, `QCC2072`, `QCN9274`, **`WCN7850`**… y **no `WCN7860`** (en su árbol,
`vendor/rocknix-extra-firmware/` está **vacío**). Aun así el chip arranca (tira del `WCN7850`):
```
[19:52:02] systemd: Found device /sys/subsystem/net/devices/wlan0.
[19:52:12] iwd: udev interface=wlan0 ifindex=3   ·   iwd: Wiphy: 0, Name: phy0
[19:52:13] NetworkManager: (wlan0): new 802.11 Wi-Fi device
```
→ **no es la causa del problema**, pero **convendría traer el `WCN7860`** (nuestro fork sí lo lleva; el
`ath12k` lo pide por el chip real).

**E2. 🔴 BLOQUEANTE de UX en un dispositivo recién flasheado** (esto es lo que deja al usuario tirado):
- NM usa **`iwd` como backend** (`device (wlan0): new IWD device state is disconnected`).
- **No hay ninguna red guardada.**
- **El asistente de Steam (cliente ARM64) NO ofrece configurar WiFi** → el usuario llega al login **sin red**.
- Y su build **apaga SSH**: aviso del propio build → *"SSH is OFF in this image"*.
- ⇒ **Un dispositivo recién flasheado queda atascado** (sin WiFi, sin SSH y sin manera de configurarlo desde la UI).

  **Lo que hicimos para poder seguir probando** (parcheando la SD a mano):
  1. `/etc/NetworkManager/system-connections/<SSID>.nmconnection` (keyfile NM, 600 root:root) **+**
  2. `/var/lib/iwd/<SSID>.psk` (`[Security] Passphrase=…`) — **NM NO le pasa la PSK del keyfile a iwd**,
     hay que darla por separado;
  3. `systemctl enable sshd` (symlink en `multi-user.target.wants`) + clave en `/root/.ssh/authorized_keys`.

  **Sugerencia para el PR**: (a) que la imagen traiga un **mecanismo de primer arranque para la WiFi**
  (o que `sshd` venga encendido en las de prueba), o (b) exponer el selector de red en el asistente.

**E3. `ath12k` se cae y se recupera** (2 veces en un arranque) — `Hardware restart was requested`,
`failed to stopt 11d scan vdev 0 ret: -108`, `failed to submit WMI_VDEV_DELETE_CMDID`. Es el bucle que
**nosotros paramos con nuestro parche `0041b`**, que va como **PR aparte a `kernel/common`** (como acordamos).
En su árbol no está → la WiFi puede quedar inestable.
