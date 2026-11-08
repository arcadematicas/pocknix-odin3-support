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

## AppImages: cómo funciona hoy y el problema pendiente

Hoy: intento directo con `APPIMAGE_EXTRACT_AND_RUN=1`. El runtime x86_64 del AppImage
extrae el squashfs a **`/tmp/appimage_extracted_<hash>`** y ejecuta allí. Si el runtime
peta bajo Box64, se extrae con `unsquashfs` a `/home/games/linux/.appimage/<nombre>/` y se
lanza `AppRun` (esto ya funciona, p. ej. Uncharted).

**Dos problemas reales, ya observados:**

1. **Rutas perdidas / partidas que no persisten.** El juego corre con `cwd` y `APPDIR`
   dentro de `/tmp/appimage_extracted_*`. Lo que escriba junto al ejecutable (saves,
   configs, cachés, shaders) vive en un directorio temporal que se borra. Cada arranque
   es “nuevo”.
2. **Consumo de RAM.** `/tmp` es **tmpfs**: una extracción de 300 MB son 300 MB de RAM.
   Se han visto 5 restos (`appimage_extracted_*`) sumando **811 MB**. Paper Mario 64
   (Paperboat) usa además ~2,6 GB de RSS; con Steam (~1,5 GB) la consola entra en
   presión de memoria y el **QAM se queda colgado**.

**Diseño propuesto (pendiente de implementar): extracción persistente + `cwd` original.**

```
dir = <juego>/.calvos-appimage/<nombre>-<sha256[:8]>/
si no existe o cambió el sha256 del AppImage:
    rm -rf dir ; unsquashfs -o <offset> -d dir <AppImage>
export APPDIR=dir
export ARGV0=<ruta original del AppImage>
export APPIMAGE=<ruta original>
export OWD=<carpeta del juego>
cd <carpeta del juego>
exec box64 dir/AppRun "$@"
```

- Persistente → saves/configs sobreviven y dejan de ocupar RAM.
- `APPDIR` explícito → los `AppRun` que lo recalculan siguen funcionando.
- `cwd` = carpeta del juego → las rutas relativas al directorio del port se mantienen.
- `CALVOS_EXTRACT=force` para re-extraer al actualizar el AppImage (o comparar sha256).
- Limpieza: borrar `<juego>/.calvos-appimage/` al desinstalar/actualizar; nunca en `/tmp`.

Mientras no esté hecho: **no dejar AppImages abiertos**; tras un cierre forzado, limpiar
`/tmp/appimage_extracted_*` (son RAM).

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

## Backlog priorizado

1. **AppImage persistente** (arriba): rutas/saves + RAM. Es el mayor bloqueo actual.
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
