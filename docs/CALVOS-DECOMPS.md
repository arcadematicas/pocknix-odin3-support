# CALVOS — Decomps Linux en la Odin 3 (x86_64/aarch64)

Estado: **funcional, en ampliación**. Lo nuevo se llama `calvos-*`; `pocknix-*` es herencia.
Matriz de juegos y estado por título: **`CALVOS-DECOMP-COMPAT.md`** (mismo directorio).

## Objetivo

Ejecutar los ports/decomps Linux de PC en la Odin 3 sin intervención: el usuario toca
un icono de Steam y el sistema elige motor, runtime y librerías. Sin teclado ni ratón.
Todo lo necesario va **en la imagen**; nada de instalar a mano por dispositivo.

## Rutas

| Qué | Dónde |
|---|---|
| Juegos | `/home/games/linux/<Juego>/` (bind a `/opt/decomps` en la SD) |
| Logs | `/home/games/linux/logs/<juego>-<AAAAMMDD-HHMMSS>.log` (uno por ejecución) |
| Lanzador | `/usr/local/bin/calvos-run` (`decomp-run` es symlink) |
| Sync Steam | `/usr/local/bin/calvos-decomps-sync` + `.service`/`.timer` |
| Runtime .NET x86_64 | `/opt/calvos/dotnet-x86_64` (`calvos-dotnet`) |
| Libs x86_64 compartidas | `/opt/calvos/x86_64/lib` |
| Extracción AppImage (fallback) | `/home/games/linux/.appimage/<nombre>/` |

El bind está en `/etc/fstab`:
`/opt/decomps  /home/games/linux  none  bind,nofail,x-systemd.requires-mounts-for=/opt  0 0`

`/opt` vive en la SD (`/dev/mmcblk0p2`); `/home` en la UFS interna.

## Paquetes (van en la imagen vía `pocknix-bsp-sm8750`)

| Paquete | Qué aporta |
|---|---|
| `calvos-dotnet-x86_64` | Runtime .NET **10.0.14 x86_64** (Microsoft, MIT) en `/opt/calvos/dotnet-x86_64` + `/usr/bin/calvos-dotnet`. Lo piden los ports .NET (Wario, Links, Symphony, Crash). |
| `calvos-x86_64-libs` | Librerías x86_64 que los ports enlazan y no incluyen. Hoy: **abseil** (`libabsl_*.so.2608.0.0`, Arch x86_64 `20260817.0`). |
| `calvos-decomps-tools` | `calvos-run` + `calvos-decomps-sync` + `systemd` (service `User=deck`, timer 5 min) + `decomp-run`. |

`pocknix-bsp-sm8750` depende de los tres, así que una imagen nueva los trae de serie.

## Arquitectura

### 1. `calvos-decomps-sync` (Steam → atajos)

- Escanea `/home/games/linux/*` (excepto `logs/`).
- Elige **lanzador** con esta prioridad:
  1. `*.AppImage` / `*.appimage` (prefiere aarch64 si hay varios).
  2. `*.sh` de primer nivel (prefiere `Launch/run/start/play`).
  3. ELF dentro de `Play/`, `bin/`, `Binaries/Linux/`, `Game/`.
  4. ELF de primer nivel; último recurso, un subdirectorio.
  - Excluye `android/`, `tools/`, `toolchain/`, `dependencies/`, `docs/`, `Redist/`
    y nombres `patcher`, `launcher`, `setup`, `installer`, `unins`, `updater`,
    `crashpad`, `probe`, `gpu-capabilities`, `fetch_`.
- Escribe `~/.local/share/Steam/userdata/<id>/config/shortcuts.vdf`:
  - `Exe = /usr/local/bin/calvos-run`
  - `LaunchOptions = "<ruta del lanzador>"` ← **ruta explícita**, no la carpeta
  - `StartDir = <carpeta>`, `AppName = <carpeta>`
  - `DevkitGameID = calvos` (solo reemplaza sus entradas; conserva las ajenas)
- **Steam debe estar cerrado**: si está abierto, sale con código 2 (Steam reescribe
  `shortcuts.vdf` desde memoria). El servicio lo acepta (`SuccessExitStatus=2`).
- Timer: `OnBootSec=3min`, luego cada 5 min, como `deck`.

### 2. `calvos-run` (lanzador)

Recibe la ruta del lanzador y decide:

```
target = AppImage ─┬─ intento directo con APPIMAGE_EXTRACT_AND_RUN=1
                   │    └─ si falla ─→ unsquashfs al offset → AppRun / binario interno
                   ├─ .sh ─→ bash (reintento con BIGBLOCK=0 si SIGSEGV)
                   ├─ ELF aarch64 ─→ nativo
                   └─ ELF x86_64  ─→ box64
                        · BOX64_DYNAREC_BIGBLOCK=2, SAFEFLAGS=1, FASTNAN=1
                        · BOX64_LD_LIBRARY_PATH = /opt/calvos/x86_64/lib
                          + <juego>/libs.x86_64 + libs/ + lib/
                        · si SIGSEGV (139): reintento con BIGBLOCK=0
```

Siempre:
- `cd` a la carpeta del juego y `tee` del log por ejecución.
- `DOTNET_ROOT=/opt/calvos/dotnet-x86_64`, `PATH`, `DOTNET_SYSTEM_GLOBALIZATION_INVARIANT=1`.
- **Detección de libs**: parsea `Error loading needed lib` / `cannot open shared object file`.
  En binarios aarch64 busca paquete (`pacman -F`) e intenta `pacman -S --noconfirm`
  **solo si hay NOPASSWD**; si no, deja el comando exacto en el log. En x86_64 avisa de
  que hay que añadir la `.so` a `calvos-x86_64-libs`.

### 3. binfmt

- `FEX-x86` → 32 bits / Windows.
- `box64` → ELF x86_64 (v0.4.5, dynarec ARM64, `/usr/local/bin/box64`).
- `FEX-x86_64` desactivado (competía con Box64).

## .NET: por qué lo piden ports “nativos”

“Nativo Linux” solo significa que el ejecutable es un **ELF de Linux**. Muchos ports
están hechos en **C#/.NET**: el ELF es un **apphost** que carga el runtime
(`libhostfxr.so`, `libcoreclr.so`) y la lógica va en IL.

El fallo típico (`Failed to load .../.dotnet/host/fxr/10.0.14/libhostfxr.so`) era porque
el `run.sh` del port instalaba .NET **aarch64** y el apphost es **x86_64**. Con el runtime
x86_64 de `/opt/calvos/dotnet-x86_64` bajo Box64, los cuatro ports .NET arrancan.

## Librerías x86_64 compartidas

Los ports compilados contra Arch x86_64 enlazan contra sonames concretos que no incluyen
(ej. Wario → `libabsl_*.so.2608.0.0`). Esas librerías **no** pueden salir de los paquetes
aarch64 del sistema: Box64 necesita binarios x86_64. Se empaquetan en
`calvos-x86_64-libs` (`/opt/calvos/x86_64/lib`) y `calvos-run` las pone en
`BOX64_LD_LIBRARY_PATH`.

Regla: **cada vez que un port pida una `.so` x86_64, se añade al paquete** (no a la SD).

## AppImages: extracción persistente (implementado 08/11)

`calvos-run` v4.2 extrae los AppImage **x86_64** en
`<juego>/.calimage/<nombre>-<sha256[:12]>/` y ejecuta su `AppRun` con:

- `cwd` = carpeta del juego (las rutas relativas del port se mantienen),
- `APPDIR` / `APPIMAGE` / `ARGV0` / `OWD` explícitos,
- `HOME` = `<AppImage>.home` si existe (el HOME portable del runtime).

Ventajas:
- Los saves/configs/cachés del port **persisten** (antes iban a `/tmp` y se borraban).
- **No usa `/tmp`** (tmpfs = RAM): se acabaron las extracciones de 200–800 MB en memoria.
- La extracción se reutiliza; solo se repite si cambia el sha256 del AppImage.

Modos (`CALVOS_APPIMAGE_MODE`, también en `<juego>/.calvos.env`):
- `auto` (defecto): persistente para x86_64; runtime para aarch64.
- `runtime`: fuerza el runtime (extrae a `/tmp`), para ports que solo funcionan así.
- Si la extracción persistente falla, **fallback automático** al runtime.

Validado (08/11): Paper Mario 64, SSF2, Earthworm Jim y Vandal Hearts corren desde
`.calimage` sin `/tmp`. **Uncharted** no: su launcher (PyInstaller) se cae fuera del
runtime, así que usa el fallback (el runtime sí funciona); su `HOME` portable ya se
aplica. `papercut` (TTYD) aborta antes por el chequeo de heap.

### Config por juego

`<juego>/.calvos.env` se carga con `set -a` antes de lanzar. Ejemplos:

```
CALVOS_APPIMAGE_MODE=runtime      # forzar runtime en un port concreto
BOX64_DYNAREC_BIGBLOCK=3          # tuning puntual
SDL_VIDEODRIVER=x11               # ports con SDL sin Wayland
```

## Memoria y QAM

Síntoma: al probar un juego pesado, el **QAM deja de responder**. No es un cuelgue del
sistema: es **presión de memoria** (10,9 GB RAM + swap). El juego, Steam/steamwebhelper y
los restos de AppImage en tmpfs compiten; el cliente de Steam se queda sin margen.

Medidas inmediatas (manuales):
```
free -m
ps -eo pid,rss,comm --sort=-rss | head
pgrep -af 'AppRun|box64|calvos-run'
kill <pid del juego>          # NO matar steam ni gamescope
rm -rf /tmp/appimage_extracted_*   # solo si ningún proceso los usa
```

Propuesta (backlog): lanzar el juego en un **scope systemd con `MemoryHigh`/`MemoryMax`**
para que el OOM mate al juego y no a Steam, y un aviso en el log cuando
`MemAvailable < 1 GB`.

## Diagnóstico rápido

```bash
# qué lanzador detecta el sync (no escribe nada)
calvos-decomps-sync --dry-run

# log de la última ejecución de un juego
ls -t /home/games/linux/logs/*.log | head
grep -v gameoverlayrenderer <log> | tail -40

# arquitectura de un binario
readelf -h <bin> | grep Machine

# libs que faltan (Box64)
BOX64_LOG=1 box64 <bin> 2>&1 | grep -i 'needed lib'

# runtime .NET
box64 /opt/calvos/dotnet-x86_64/dotnet --list-runtimes
```

Notas:
- El ruido de `gameoverlayrenderer.so` (`LD_PRELOAD`) es inofensivo.
- Los `.exe` que aparecen en las carpetas son builds Windows/tools de los ports; no se
  añaden a Steam desde este sync (van por wproton/Proton).

## Rendimiento — medición 08/11/2026

Síntoma: los juegos arrancan pero van lentos, y el frametime es inestable (Wario
marca 60 fps en el overlay pero oscila). **No es la GPU.**

### Wario (WarioRecomp, x86_64 bajo Box64)

Medido sobre el log `logs/Play-20261108-014918.log` (30 s de partida):

| Métrica | Valor |
|---|---|
| FPS medio (watchdog) | **44,9 fps** (808 frames en 18 s) |
| Frames “slow” | 180 de 1335 (**13,5 %**) |
| p50 de los slow | **33,3 ms** (≈30 fps) |
| Rango | 24,6 ms … **463 ms** |

Desglose de un frame lento:
`game 33.32 (gx 0.00, disc 0.00), present 0.00, end_frame 0.01, pace 0.00`

→ **todo el tiempo es código invitado** (`game`); presentación GPU ≈0. La GPU
(Mesa 26.3.0 / Adreno 830) está prácticamente idle. El juego pide 60 (VI), pero
cuando el código no cabe en 16,7 ms cae al siguiente múltiplo (33,3 ms): de ahí
la sensación de “60 con tirones”.

El pico de 463 ms coincide con un **cambio de escena/init** (configuración de
mandos, `scene 0xFFDC`, `disc 8.58 ms`, `PPCMtdec` stubbed), no con I/O de disco.

### Crash / Symphony (.NET)

Peor caso de traducción: **IL de .NET → JIT x86_64 → Box64 → ARM64**. Crash además
recompila el juego (`JitWarmup 4117 métodos en 1,8 s`) y ejecuta código PSX
recompilado. La lentitud es esperable; falta medir fps por escena.

### Causa y margen

Box64 traduce bloques x86_64 a ARM64 en tiempo de ejecución, un hilo por hilo
invitado. En este SoC el límite es **CPU de un núcleo**, no GPU ni disco. Hay
margen de mejora por flags, motor alternativo (FEX) y perfil de energía; no hay
garantía de 60 estables.

`zram0` (swap comprimido, 10,7 GB) tenía **1 GB usado** al probar: bajo presión de
memoria el intercambio comprimido también añade tirones. Otra razón para reducir
el consumo de los AppImage (extracción en `/tmp` = RAM).

### TDP y flags: qué mueve de verdad (08/11)

El **Panel de Control** (plugin) tenía `pl1 = 4 W` en modo estable: CPU a
**1,99/2,44 GHz** (hardware: 3,53/4,09 GHz) y GPU a **660 MHz** (hardware: 1,1 GHz).
Forzando relojes máximos solo durante la prueba:

| Config | Wario |
|---|---|
| 4 W (real) | 44,9 fps, 180 slow (13,5 %) |
| relojes máximos | **52,7 fps**, 30 slow (~3 %) |
| + `SAFEFLAGS=0` | 52,1 fps |
| + `STRONGMEM=0 CALLRET=1 FASTROUND=1 BIGBLOCK=3` | 52,7 fps |

Los **flags de Box64 no cambian nada** (dentro del ruido). Fransis confirma que con
el TDP al máximo tampoco hay una diferencia grande en juego. Conclusión: el techo
real es la **traducción x86_64→ARM64** (Box64), no el dynarec configurable ni el TDP.
Queda como línea futura probar **FEX** por juego (Minish ya falla en FEX por binario
estático; Wario habría que probarlo con rootfs x86_64).

### FEX vs Box64 — medido 08/11

FEX 2611 estaba instalado, pero su rootfs (`fex-rootfs`) era de enero (glibc 2.42)
y Wario pide 2.44. Se construyó un rootfs ligero con Arch x86_64 actual
(`pacstrap`, 308 MB con Mesa/Turnip x86_64, `libdisplay-info` y `xcb-utils`) para
poder medir en igualdad de condiciones.

| Motor | Wario (relojes máximos) |
|---|---|
| Box64 0.4.5 | **52,7 fps** |
| FEX 2611 | **52,5 fps** |

Mismo perfil de frames lentos (30; p50 33,4 ms). **FEX no aporta rendimiento** en
estos ports nativos: sería coste de mantenimiento (rootfs de 300 MB + Mesa + deps)
sin ganancia. Se mantiene Box64. El rootfs nuevo queda en
`/opt/calvos/fex-rootfs-glibc244.sqsh` por si hace falta FEX como **fallback de
compatibilidad** (juego que no arranque en Box64); el rootfs original se restauró
para no perder FEX 32-bit.

### Cómo medir (repetible)

Wario escribe en su log, cada ~6 s:
`[vi] [watchdog] N s: X guest frame(s) presented`
→ fps medio = ΔX / Δs. Y cada frame > umbral deja `[vi] slow frame <ms>`.
Benchmark: misma escena, 60 s, un solo cambio por pasada.

### Líneas de trabajo (mañana)

1. **Matriz de flags Box64** (A/B con Wario, 60 s): `BIGBLOCK=2/3`,
   `SAFEFLAGS=0`, `STRONGMEM=0`, `CALLRET=1`, `FASTROUND=1`,
   `BLEEDING_EDGE=1`. Medir fps medio y % de slow frames.
2. ~~FEX vs Box64~~ — **medido 08/11**: empate técnico (52,5 vs 52,7). Se mantiene Box64.
3. **Perfil de energía**: probar con perfil “alto” del QAM (`performance`) y
   mirar `cpufreq`/TDP durante la partida; comparar con “medio”.
4. **`DOTNET_TieredCompilation`** y afines en los .NET para ver si reduce el
   coste del JIT bajo Box64.
5. **Config por juego** (diseño): `<juego>/.calvos.env` leído por `calvos-run`
   con `CALVOS_ENGINE=box64|fex`, `BOX64_*` y `SDL_VIDEODRIVER`. Evita tocar el
   lanzador global por un título.
6. **AppImage persistente** (backlog #1): también quita presión de RAM, que
   agrava los tirones.

## Backlog priorizado

1. ~~AppImage persistente~~ — **HECHO 08/11** (`v4.2`): rutas/saves + RAM.
0. **Rendimiento**: flags Box64 descartados (sin efecto); pendiente FEX por juego (ver sección).
2. **Scope de memoria por juego** (`systemd-run --user --scope -p MemoryHigh=...`) y aviso
   de memoria baja; evitar que el QAM se bloquee.
3. **`calvos-run --diagnose <juego>`**: lanzador, arch, libs que faltan, runtime .NET.
4. **`--no-steam-overlay`**: quitar el ruido de `gameoverlayrenderer.so`.
5. **Iconos/carátulas** en el sync (`icon.png`/`logo.png`/`cover.png`).
6. **Auto-instalación de libs**: decidir si se habilita una regla sudoers acotada.
7. **Windows**: mantener wproton/Proton aparte; no mezclar con este sync.
8. **Documentar cada port nuevo** en `CALVOS-DECOMP-COMPAT.md` al validarlo.

## Historial

- **07/11**: sync pasa la **ruta del lanzador** (antes la carpeta; `calvos-run`
  re-detectaba mal). Box64 nativo; bind de decomps; logs por ejecución.
- **07/11**: paquete `calvos-dotnet-x86_64`; FEX 2611 validado con Dead Island.
- **08/11**: validados Symphony, Links, Wario y Crash (.NET resuelto). Nuevo
  `calvos-x86_64-libs` (abseil). Reintento automático `BIGBLOCK=0` ante SIGSEGV.
  Wario: `dvd_root` corregido a `/opt/decomps/...` (existe en Odin y sobremesa).
  Detectado el problema de RAM/rutas de los AppImages (Paper Mario 64 + QAM).
