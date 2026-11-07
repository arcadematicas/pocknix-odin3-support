# CALVOS — Decomps Linux en la Odin 3 (x86_64/aarch64)

Estado: **experimental**. Lo nuevo se llama `calvos-*`; `pocknix-*` es herencia.

## Objetivo
Ejecutar los ports/decomps Linux de PC en la Odin 3 sin intervención: el usuario
toca un icono/atajo de Steam y el sistema elige el motor adecuado.

## Rutas
- Juegos: `/home/games/linux/<Juego>/` (bind a `/opt/decomps` en la SD:
  `/opt/decomps  /home/games/linux  none  bind,nofail,x-systemd.requires-mounts-for=/opt  0 0`).
- Logs: `/home/games/linux/logs/<juego>-<AAAAMMDD-HHMMSS>.log` (uno por ejecución).
- Lanzador: `/usr/local/bin/calvos-run` (`decomp-run` es symlink).
- Sync Steam: `/usr/local/bin/calvos-decomps-sync` + `.service`/`.timer`.
- Documentación: este fichero.

## Componentes
### calvos-run
Detecta el tipo de lanzador y ejecuta:
1. Carpeta → busca `*.AppImage`, `*.sh`, ELF (prefiere `Play/`, `bin/`, `Binaries/Linux/`).
2. AppImage → `APPIMAGE_EXTRACT_AND_RUN=1` (FUSE no fiable bajo Box64).
3. `.sh` → lo ejecuta directamente (el script elige el binario).
4. ELF x86_64 → `box64` con `BOX64_DYNAREC_BIGBLOCK=2`, `SAFEFLAGS=1`, `FASTNAN=1`.
5. ELF aarch64 → nativo.
6. `.NET` → `DOTNET_SYSTEM_GLOBALIZATION_INVARIANT=1` (evita el abort de ICU).
7. `cd` a la carpeta del juego y tee del log.

### calvos-decomps-sync
- Escanea `/home/games/linux/*` (excepto `logs/`).
- Detecta lanzador: AppImage (prefiere aarch64) → `.sh` → ELF.
- Escribe `~/.local/share/Steam/userdata/<id>/config/shortcuts.vdf` con:
  - `Exe = /usr/local/bin/calvos-run`
  - `LaunchOptions = "<carpeta del juego>"`
  - `StartDir = <carpeta>`, `AppName = <carpeta>`
  - `DevkitGameID = calvos` (solo reemplaza los suyos; conserva los ajenos).
- **Steam debe estar cerrado**; si está abierto, sale con código 2.
- `calvos-decomps-sync.timer`: arranque + cada 5 min.

### binfmt
- `FEX-x86` para 32 bits/Windows.
- `box64` para ELF x86_64 (`/usr/local/bin/box64`, v0.4.5 con dynarec ARM64).
- `FEX-x86_64` desactivado (competía con Box64).

## Resultados de pruebas (07/11/2026)
| Juego | Tipo | Estado |
|---|---|---|
| Xenogear-lite | UE5 ELF x86_64 | ✅ arranca |
| ConkerRecompiled | recomp x86_64 | ✅ arranca |
| CrashBandicoot | recomp x86_64 | 🔄 compila en el primer arranque |
| DriveClub | AppImage aarch64 | ✅ nativo |
| gen1recomp | AppImage aarch64 | ✅ nativo |
| SuperMetroid | `.sh` | ❌ detector eligió `android/fetch_sdl.sh` |
| Links Awakening | .NET/patcher | ❌ eligió el patcher; dotnet falla |
| Wario | .NET + ELF | ❌ eligió el launcher .NET; el juego es `Play/WarioRecomp` |
| Uncharted | AppImage x86_64 | ❌ runtime AppImage bajo Box64 |
| Captain Toad | `.exe` | — (Windows: Proton/wproton) |

## Limitaciones conocidas
- AppImage x86_64: el runtime puede petar bajo Box64 (probar `.exe` con Proton).
- Ports con libs incompletas (p.ej. `libabsl` de Wario) no arrancan.
- .NET/Avalonia: necesita ICU o el flag invariant.
- Los `.exe` de Windows no se añaden a Steam desde este sync (van por Proton/wproton).
- Los `.exe` dentro de las carpetas son normales (los ports traen ambas builds).
- Steam debe estar cerrado para el sync.

## Siguiente
1. Afinar `detect_launcher`: excluir `android/`, `tools/`, `dependencies/`,
   `*Patcher*`, `*Launcher*`, `*Setup*`, `*Installer*`; preferir `Launch.sh`/`run.sh`
   y el binario del juego.
2. `decomp-run`/`calvos-run`: `--no-steam-overlay` para quitar el ruido de
   `gameoverlayrenderer.so`.
3. Evaluar `calvos-decomps-sync` con icono (`icon.png`/`logo.png`) y carátulas.
4. Para Windows: mantener wproton/Proton; no mezclar con este sync.
5. Añadir un comando `calvos-run --diagnose <juego>` que muestre el lanzador
   elegido, la arquitectura y las libs que faltan.

## Corrección 07/11 21:10 — lanzador explícito
El sync guardaba la **carpeta** en `LaunchOptions`; `calvos-run` re-detectaba dentro
y elegía mal (`tools/build-launcher.sh`, patcher, `android/fetch_sdl.sh`).
Ahora `calvos-decomps-sync` guarda la **ruta del lanzador detectado**:
- Links → `Link's Awakening DX HD`
- Wario → `Play/WarioRecomp`
- SuperMetroid → `Launch.sh`
Verificado en `shortcuts.vdf`: 17 decomps + 10 ajenos.

## Fallos restantes (07/11 noche)
- **Wario/Links (.NET/Avalonia)**: `dotnet not found` / `libhostfxr.so` no carga.
  Necesitan el runtime .NET x86_64 o el flag `DOTNET_SYSTEM_GLOBALIZATION_INVARIANT`
  (ya puesto) no basta si falta el hostfxr.
- **AppImages x86_64** (Uncharted, Paper Mario, SSF2, minish, Earthworm): el runtime
  del AppImage no sobrevive a Box64; usar el `.exe` con Proton o extraer el AppImage
  y lanzar el binario interno.
- **SymphonyRecomp**: `run.sh` con .NET; mismo problema de `libhostfxr.so`.
- **Crash**: compila el recomp la primera vez (esperar).
- **Conker/Xenogear**: OK.

## Paquetes calvos-* (07/11 noche)
Para que esto no dependa de instalar cosas a mano en cada Odin, dos paquetes
`shared` en el centro (van en la imagen via `pocknix-bsp-sm8750`):

- **calvos-dotnet-x86_64** — runtime .NET 10.0.14 **x86_64** (Microsoft, MIT)
  aislado en `/opt/calvos/dotnet-x86_64` + `/usr/bin/calvos-dotnet`.
  Es lo que necesitan Wario/Links/Symphony/Crash: el ELF es un apphost .NET y
  busca `libhostfxr.so`; este runtime corre bajo Box64.
- **calvos-decomps-tools** — `calvos-run` v4 y `calvos-decomps-sync` con sus
  `systemd` (service `User=deck` + timer de 5 min). Incluye
  `decomp-run` como symlink.

`calvos-run` v4:
- recibe el lanzador **explicito** del sync (ya no adivina);
- AppImage: intento directo y, si falla, `unsquashfs` al offset y ejecuta
  `AppRun`/binario interno (funciona con Uncharted);
- exporta `DOTNET_ROOT`/`PATH` si existe el runtime;
- detecta `Error loading needed lib` / `cannot open shared object file` y, en
  binarios aarch64, busca el paquete con `pacman -F` e intenta `pacman -S`
  (sin contraseña solo si hay NOPASSWD; si no, deja el comando en el log).

Instalacion manual (mientras la Odin esta apagada):
```
scp /tmp/opencode/pkg/calvos-*.pkg.tar.xz deck@odin:/tmp/
sudo pacman -U --noconfirm --overwrite '/usr/local/bin/*' /tmp/calvos-*.pkg.tar.xz
sudo rm -f /etc/systemd/system/calvos-decomps-sync.{service,timer}
sudo systemctl daemon-reload && sudo systemctl enable --now calvos-decomps-sync.timer
```
