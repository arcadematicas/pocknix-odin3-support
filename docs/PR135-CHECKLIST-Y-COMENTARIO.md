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
| 8 | **Arranques en frío con `POCKNIX_PANEL_WAIT=0`** | Añadir a la cmdline y ver si el panel sigue saliendo (si ya no hace falta el wait, se quita la clave) | |

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
