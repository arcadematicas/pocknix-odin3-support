# CALVOS — Matriz de compatibilidad de decomps

Última actualización: **08/11/2026**. Arquitectura y funcionamiento:
**`CALVOS-DECOMPS.md`**. Este fichero es el **registro por juego**: qué lanzador usa,
qué necesita y en qué estado está. Al validar o romper un port, se actualiza aquí.

Leyenda: ✅ validado en pantalla · 🟡 arranca pero falta algo · ⏳ sin validar ·
❌ no arranca · ➖ no aplica (Windows/otro motor)

## Tabla

| Juego | Lanzador (sync) | Tipo / arch | Estado | Notas |
|---|---|---|---|---|
| ConkerRecompiled | `Conker.sh` | .sh → x86_64 | ✅ | Arranca bajo Box64. |
| Crash Bandicoot | `crash.sh` | .sh → .NET x86_64 | ✅ | **1ª ejecución compila** con Roslyn (~2 min). Si Box64 muere con SIGSEGV, `calvos-run` reintenta con `BIGBLOCK=0`. Después usa caché. Lento: recompilador + .NET bajo Box64. |
| DriveClub | `DriveClub-recomp-aarch64.AppImage` | AppImage aarch64 | ✅ | Nativo. |
| Earthworm Jim HD | `EarthwormJimHD-linux-x86_64.AppImage` | AppImage x86_64 | ✅ | Arranca (swapchain creada). Rendimiento por medir. |
| New Super Paper Bros | `New Super Paper Bros` | ELF x86_64 | ✅ | Arranca (Aurora, VSync, 2.2x). Rendimiento por medir. |
| SymphonyRecomp | `run.sh` | .sh → .NET x86_64 | ✅ | Arranca (GL 4.6, assets/packs cargados). **Lento**: doble traducción .NET→x86_64→Box64. Autoupdater avisa de v1.1.2p (hay 0.5.1b): no actualizar sin probar. |
| Zelda: Link's Awakening DX HD | `Link's Awakening DX HD` | ELF .NET x86_64 | ✅ | Carga .NET/Vulkan. |
| Uncharted Remastered | `Uncharted-x86_64.AppImage` | AppImage x86_64 | 🟡 | Su launcher es **PyInstaller** y se cae fuera del runtime (rc=1 silencioso); el fallback al runtime **sí arranca**. Los saves van a `Uncharted-x86_64.AppImage.home` (HOME portable). Con `CALVOS_APPIMAGE_MODE=runtime` se evita el intento persistente. |
| Wario Land: Shake It! | `Play/WarioRecomp` | ELF x86_64 | ✅ | Necesita `calvos-x86_64-libs` (abseil) y `dvd_root=/opt/decomps/...` en `Play/UserData/Config.toml`. **Medido: 44,9 fps** con TDP 4 W; **52,7 fps** con relojes máximos (slow 13,5 %→3 %). Los flags de Box64 no cambian nada. |
| gen1recomp | `gen1recomp-0.2.56-linux-arm64.AppImage` | AppImage aarch64 | ✅ | Nativo. |
| Minish Cap (Project Picori) | `Project_Picori_Minish_Cap-x86_64.AppImage` | AppImage x86_64 | ❌ | Binario **estáticamente enlazado** (sharun); Box64 avisa "not really compatible with statically linked binaries" y su SDL solo trae x11 (sin wayland) → "x11 not available". FEX da SIGILL. Sin build Windows en la carpeta. Bloqueado: pedir build dinámico al autor o probar el .exe por Proton. |
| Paper Mario 64 (Paperboat) | `Paperboat.AppImage` | AppImage x86_64 | ✅ | Arranca y corre. **Extracción persistente** en `.calimage/` desde 08/11 (ya no usa `/tmp`). Sigue siendo **~2,6 GB RSS**: no dejarlo abierto junto a otro juego. |
| Paper Mario: La puerta milenaria | `papercut-linux-x64.AppImage` | AppImage x86_64 | ❌ | Aborta: `the C heap at 0x... is below 2 GiB` (asume heap >2 GiB). **Probado `BOX64_MMAP32=0`: sin efecto** (el heap es brk, no mmap). Bloqueo duro: requiere parche del port o un Box64 que coloque el brk alto. |
| Super Street Fighter II HD Remix | `SSF2THDRemix-x86_64.AppImage` | AppImage x86_64 | ✅ | Arranca (swapchain Vulkan 1920). Rendimiento por medir. |
| Super Metroid | `Launch.sh` | .sh → x86_64 | 🟡 | Arranca; falta configurarlo (mandos/ROM). |
| Vandal Hearts | `VandalHearts.appimage` | AppImage x86_64 | ✅ | Arranca (ventana 1600x1200, HD pack 75 fondos, textos en español). |
| Xenogear-lite | `Weltall.sh` | .sh → UE5 x86_64 | ✅ | Arranca bajo Box64. |
| Captain Toad | — | `.exe` (Windows) | ➖ | No lo gestiona este sync: va por **wproton/Proton** desde Steam. |

## Cómo validar un juego (protocolo)

1. Cerrar Steam (el sync solo escribe con Steam cerrado) → `calvos-decomps-sync`.
2. Abrir Steam/modo juego y lanzar desde el icono.
3. Anotar la hora y mirar el log:
   ```bash
   ls -t /home/games/linux/logs/*.log | head -3
   grep -v gameoverlayrenderer <log> | tail -40
   ```
4. Señales de “está vivo”: contexto GL/Vulkan, `guest frame(s) presented`, ventana
   creada, `Game ready`.
5. **No dejar abierto** un juego pesado mientras se prueba otro: la RAM es el recurso
   crítico (10,9 GB). Comprobar `free -m`.

## Problemas transversales (afectan a varios)

- **AppImages x86_64**: extracción en `/tmp` (RAM) y rutas/saves efímeras. Solución
  diseñada, pendiente (ver `CALVOS-DECOMPS.md` → “AppImages”).
- **.NET**: resuelto con `calvos-dotnet-x86_64`; nunca usar el `/home/deck/.dotnet`
  que instalan algunos `run.sh` (es aarch64).
- **Libs x86_64**: si un port pide una `.so` que no trae, se añade a `calvos-x86_64-libs`.
- **Memoria/QAM**: si el QAM se bloquea, cerrar el juego (no Steam) y limpiar
  `/tmp/appimage_extracted_*`.
- **Rutas absolutas del port**: los ports que guardan `dvd_root`/rutas de datos en su
  config deben apuntar a una ruta válida en la consola. Convención: `/opt/decomps/...`
  (existe en la Odin como montaje y en el sobremesa como symlink).
