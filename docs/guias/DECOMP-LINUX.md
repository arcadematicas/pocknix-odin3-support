# Decomps Linux — ports de PC en el modo juego

**Qué es**: ejecutar los **ports/decomps Linux** de PC (AppImage, `.sh` o ELF
x86_64/aarch64) desde el **icono de Steam**, sin terminal ni teclado. El sistema
elige motor (nativo o Box64), runtime .NET y librerías, y deja un log por ejecución.

Detalle técnico: [`../CALVOS-DECOMPS.md`](../CALVOS-DECOMPS.md).
Estado por juego: [`../CALVOS-DECOMP-COMPAT.md`](../CALVOS-DECOMP-COMPAT.md).

## Dónde van los juegos

```
/home/games/linux/<Juego>/        # bind a /opt/decomps (SD)
/home/games/linux/logs/           # un .log por ejecución
/home/games/linux/<Juego>/.calimage/   # AppImage extraído (persistente)
```

No mezcles juegos de Windows aquí: esos van por **WProton** o Proton.

## Añadir un juego (3 pasos)

1. Copia la carpeta del juego a `/home/games/linux/` (una carpeta por juego).
2. **Cierra Steam** y ejecuta:
   ```sh
   calvos-decomps-sync
   ```
   (Si Steam está abierto el sync sale sin tocar nada: Steam reescribe sus atajos
   al cerrarse.) También corre solo cada 5 minutos con Steam cerrado.
3. Abre Steam/modo juego: el juego aparece con la etiqueta **CalvOS**. Tócalo y ya.

El sync detecta el lanzador solo: **AppImage** → `.sh` → **ELF** (prefiere
`Play/`, `bin/`, `Binaries/Linux/`). Guarda en el atajo la **ruta exacta** del
lanzador, no la carpeta.

## Qué hace el lanzador por ti

- **AppImage x86_64**: lo extrae una vez en `<Juego>/.calimage/` (persistente) y lo
  ejecuta con `HOME` = `<AppImage>.home` si existe. **Los saves/configs no se
  pierden** y no ocupa RAM en `/tmp`. La primera vez tarda en extraer; luego es
  instantáneo. Si un port solo funciona con el runtime clásico, se puede forzar
  (ver `.calvos.env`).
- **.NET**: usa el runtime **x86_64** de `/opt/calvos/dotnet-x86_64` (Wario, Links,
  Symphony, Crash…). No instala nada en tu `$HOME`.
- **Librerías x86_64**: las que necesitan los ports (p. ej. abseil de Wario) están
  en `/opt/calvos/x86_64/lib`. Si un juego pide una que falta, el log lo dice.
- **Box64**: los ELF x86_64 se ejecutan con Box64; si muere con SIGSEGV, reintenta
  una vez con un dynarec más conservador.

## Configuración por juego (opcional)

Crea `<Juego>/.calvos.env` con variables `CLAVE=valor`:

```sh
CALVOS_APPIMAGE_MODE=runtime     # forzar el runtime (Uncharted)
BOX64_DYNAREC_BIGBLOCK=3         # tuning puntual
SDL_VIDEODRIVER=x11              # ports con SDL sin Wayland
```

## Logs y diagnóstico

```sh
ls -t /home/games/linux/logs/*.log | head        # últimas ejecuciones
grep -v gameoverlayrenderer <log> | tail -40     # sin ruido del overlay
calvos-decomps-sync --dry-run                   # qué lanzador detecta (no escribe)
```

Señales de “está vivo”: contexto GL/Vulkan, `guest frame(s) presented`, ventana
creada, `Game ready`. Si un juego no abre, mira el final del log: casi siempre dice
la librería o el archivo que falta.

## Consejos

- **Un juego pesado a la vez** (10,9 GB de RAM). Cierra el anterior antes de abrir
  otro; si el QAM se queda pillado, mata el juego (y su `AppRun`), **no** Steam.
- Los AppImage se extraen a `.calimage` (disco). Si cierras un juego a lo bruto y
  ves `appimage_extracted_*` en `/tmp`, son del runtime de respaldo y ocupan RAM:
  se pueden borrar si no hay ningún proceso usándolos.
- ¿Un juego no arranca? Anótalo en `CALVOS-DECOMP-COMPAT.md` y revisa el log antes
  de tocar nada.
