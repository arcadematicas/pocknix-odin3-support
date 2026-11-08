# WProton — juegos de Windows en la Odin 3

**Qué es**: lanzador portable de juegos **Windows** (Proton/Wine) para ARM64, con
soporte de `.wsquashfs`. Proyecto independiente de **stshunz**
(https://github.com/stshunz/WProton_ARM); CalvOS lo integra en `/opt/wproton`.

## Instalación / primer arranque

1. **CalvOS Tools** → **“Set up WProton (Windows games)...”** (o ejecuta `wproton`
   en una terminal).
2. El **asistente de primera vez** elige runner (Proton/Wine) y ajustes básicos, y
   añade WProton al **modo juego** de Steam.
3. A partir de ahí, todo se gestiona desde el **menú de WProton** (zenity, navegable
   con mando).

## Dónde está todo

```
/opt/wproton/
├── games/        # tus juegos (.wsquashfs o carpetas con .exe)
├── runtime/      # umu-launcher + runners (GE-Proton, Proton-CachyOS, Wine-GE…)
├── prefixes/     # prefijos de Wine (por juego o compartido)
├── profiles/     # un .conf por juego (runner y ajustes)
├── logs/         # wproton_AAAAMMDD_HHMMSS.log
└── bin/          # squashfuse / fuse-overlayfs propios (si están)
```

## Uso

```sh
wproton                              # menú principal
wproton /ruta/juego.wsquashfs        # lanzar un juego
wproton --exe /ruta/juego.wsquashfs  # elegir el .exe a mano
wproton --config [juego]             # configuración del juego
wproton --setup                      # descargar/actualizar umu + Proton
wproton --kill                       # desmontar y cerrar Wine
```

- **Añadir un juego**: copia el `.wsquashfs` (o la carpeta con el `.exe`) a
  `/opt/wproton/games/` y lánzalo desde el menú. La primera vez pregunta por el
  ejecutable y crea su perfil.
- **Icono en Steam**: crea un atajo **no-Steam** cuyo comando sea
  `wproton /opt/wproton/games/<juego>.wsquashfs` (el asistente ya añade el acceso
  general de WProton).
- **Runners**: se descargan desde el propio menú (GE-Proton, Proton-CachyOS,
  Wine-GE, Kron4ek…). Cada juego recuerda el suyo en `profiles/<id>.conf`.
- **Carátulas**: opcional, con una API key de SteamGridDB en el menú.

## Guardados y copias

- Prefijo Wine de cada juego: `prefixes/<id>` (o `prefixes/default` si es
  compartido). Los saves suelen estar dentro del prefijo.
- Copia de seguridad: **menú → “Copia de tu configuración”** (perfiles, ajustes y
  carátulas) y, para partidas, la carpeta `prefixes/`.

## Problemas comunes

| Síntoma | Qué mirar |
|---|---|
| “No se pudo obtener umu-launcher” / fallo al descargar | Límite de la API de GitHub. WProton 1.72 ya trae caché, reintentos y diagnóstico en el menú. Si persiste, pon un `GITHUB_TOKEN` en el script o en `github.key`. |
| Repite la instalación inicial en cada arranque | Síntoma del bug de umu corregido en 1.72; confirma la versión en el menú. |
| El mando no va dentro del juego | Ajustes del juego → **Superposición de Steam** (ver nota del script) y el runner elegido. |
| Se queda un proceso Wine colgado | `wproton --kill`. |
| Un juego no arranca con un runner | Prueba otro runner en `--config`; los casos conocidos están en `COMPATIBILIDAD.md` del proyecto. |

Logs: `/opt/wproton/logs/`. Detalle de la versión y cambios:
[`../WPROTON-1.72-2026-10-11.md`](../WPROTON-1.72-2026-10-11.md) y
[`../REPORTE-WPROTON-UMU-403-2026-10-11.md`](../REPORTE-WPROTON-UMU-403-2026-10-11.md).

> Los juegos de Windows **no** los añade `calvos-decomps-sync`: ese sync es solo
> para ports **Linux**. Los `.exe`/`.wsquashfs` van por WProton o Proton desde Steam.
