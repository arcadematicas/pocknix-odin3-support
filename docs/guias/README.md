# Manuales de usuario de CalvOS

Guías cortas de las funciones **especiales** del sistema: qué son, dónde están y
cómo se usan. No sustituyen a los documentos técnicos de `docs/`; cada guía
enlaza al suyo para el detalle interno.

| Función | Se usa desde | Guía |
|---|---|---|
| **DeckStation** (emulación) | CalvOS Tools / Steam | [DECKSTATION.md](DECKSTATION.md) |
| **WProton** (juegos Windows) | CalvOS Tools / mando | [WPROTON.md](WPROTON.md) |
| **Decomps Linux** (ports de PC) | Carpeta + Steam | [DECOMP-LINUX.md](DECOMP-LINUX.md) |
| **Sistema** (energía, HDR, snapshots, captura, diagnóstico) | QAM / terminal | [SISTEMA.md](SISTEMA.md) |
| **Mando y atajos** | RetroArch / ES-DE | [../MANDO-ODIN3-RETROARCH.md](../MANDO-ODIN3-RETROARCH.md) |

## Convenciones

- Las rutas del sistema son las de la consola: usuario `deck`, casa `/home/deck`.
- Los comandos que necesitan root se indican con `sudo`.
- La tarjeta SD grande se monta en `/opt`; los juegos Linux viven en
  `/home/games/linux` (bind a `/opt/decomps`) y las ROMs donde las tengas.
- **CalvOS Tools** (comando `pocknix-tools`) es el menú de instalación/preparación
  (accesible desde el escritorio o el propio sistema). En la versión actual del
  paquete el título del menú aún dice «Pocknix Tools»; se rebrandea en la próxima
  actualización de paquetes. Las opciones que se citan aquí son las que
  aparecen en ese menú.

## Documentos técnicos relacionados

- `../CALVOS-DECOMPS.md` y `../CALVOS-DECOMP-COMPAT.md` — decomps (arquitectura y matriz por juego).
- `../WPROTON-1.72-2026-10-11.md` — cambios de WProton 1.72.
- `packages/deckstation-arm/README.md` — DeckStation ARM (proyecto de `stshunz`).
- `../GRABAR-VIDEO.md`, `../CALVOS-DOCTOR.md`, `../SUSPEND-ISSUE.md`, `../BATTERY-ISSUE.md`.
