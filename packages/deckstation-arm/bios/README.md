# BIOS y firmware — DeckStation

Aquí van las **BIOS y el firmware** que necesitan algunos emuladores. DeckStation
**no las incluye ni las descarga**: tienen copyright y hay que obtenerlas
legalmente de tus propias consolas (o de alternativas libres cuando existen).

Deja tus ficheros en la subcarpeta del sistema correspondiente y ejecuta:

```bash
deckstation-bios.sh --check     # INFORME: que falta y donde va cada una
deckstation-bios.sh             # distribuye a cada emulador
deckstation-bios.sh --dry-run   # ver que haria, sin tocar nada
deckstation-bios.sh --force     # sobrescribir lo que ya exista
```

### El informe (`--check`)

```
SISTEMA    TIENES  FALTAN                           DESTINO
psx        1/3     scph5501.bin, scph5502.bin       RetroArch system + Duckstation bios
dreamcast  2/2     —                               RetroArch system/dc
saturn     0/2     sega_101.bin, mpr-17933.bin      RetroArch system
3ds        0/2     aes_keys.txt, seeddb.bin         Azahar sysdata
```

- **De dónde salen los datos**: `required.txt` (qué fichero espera cada sistema) y
  `deploy-bios.txt` (a dónde va cada sistema). Los ficheros reales no van en git.
- **Alternativas**: en `required.txt` una fila puede listar variantes y vale cualquiera
  de ellas. Por ejemplo, para PSX sirve `scph1001.bin`, `ps1_rom.bin`, `psxonpsp660.bin`,
  `scph5500.bin`… así que con **una** BIOS de PSX la fila queda cubierta.
- La comparación es **sin distinguir mayúsculas** (los emuladores no se ponen de acuerdo:
  `MSX.ROM` vs `msx.rom`).
- El mismo informe se ve **desde el salón**: ES-DE → Updater → **BIOS / Firmware**
  (con A/Enter para repartirlas). Y desde **Pocknix Tools → DeckStation BIOS**.

### `required.txt`

Una línea por fichero esperado:

```
<sistema>|<fichero>|<nota>|<alternativas separadas por comas>
```

Al añadir un sistema nuevo hay que tocar **los dos** ficheros: `required.txt` (qué
ficheros) y `deploy-bios.txt` (a dónde van).

El script **no es destructivo**: por defecto solo copia lo que falta, así que
puedes volver a ejecutarlo cuando añadas ficheros nuevos. Es reejecutable.

## Estructura

```
bios/
├── README.md            (esto)
├── deploy-bios.txt      (mapa: sistema -> destino de cada emulador)
├── psx/                 BIOS de PlayStation 1
├── ps2/                 BIOS de PlayStation 2
├── dreamcast/           BIOS de Dreamcast
├── saturn/              BIOS de Sega Saturn
├── segacd/              BIOS de Sega CD / Mega CD
├── pcecd/               BIOS de PC Engine CD / TurboGrafx-CD
├── 3do/                 BIOS de 3DO
├── neogeo/              neogeo.zip
├── msx/                 ROMs de MSX / MSX2
├── switch/              claves de Switch (prod.keys / title.keys)
├── 3ds/                 sysdata de 3DS (aes_keys.txt, seeddb.bin, ...)
└── misc/                cualquier otra BIOS -> system/ de RetroArch
```

## Qué ficheros necesita cada sistema

| Carpeta | Ficheros (nombres que esperan los emuladores) |
|---|---|
| `psx/` | `scph5500.bin` (JP), `scph5501.bin` (US), `scph5502.bin` (EU). También valen `scph1001.bin`, `ps1_rom.bin`, `psxonpsp660.bin`. **Alternativa libre:** OpenBIOS (ya viene con PCSX-Redux). |
| `ps2/` | `scph10000.bin`, `scph39001.bin`, etc. |
| `dreamcast/` | `dc_boot.bin`, `dc_flash.bin` |
| `saturn/` | `sega_101.bin` (JP), `mpr-17933.bin` (US/EU) |
| `segacd/` | `bios_CD_U.bin`, `bios_CD_E.bin`, `bios_CD_J.bin` |
| `pcecd/` | `syscard3.pce` (Super CD-ROM²), `syscard2.pce`, `syscard1.pce` |
| `3do/` | `panafz1.bin` (FZ-1), `panafz10.bin` (FZ-10), `panafz10e-anvil.bin` |
| `neogeo/` | `neogeo.zip` (BIOS + ROMs del sistema, tal cual) |
| `msx/` | `MSX.ROM`, `MSX2.ROM`, `MSX2EXT.ROM`, `MSX2P.ROM`, `MSX2PEXT.ROM` |
| `switch/` | `prod.keys`, `title.keys` (y opcionalmente el firmware) |
| `3ds/` | `aes_keys.txt`, `seeddb.bin` (sysdata de Azahar) |
| `misc/` | Cualquier otra (Jaguar, Intellivision, ColecoVision, ...) |

> No todas las BIOS son obligatorias: muchos cores de RetroArch funcionan sin
> ellas (o con HLE). Si un sistema no arranca, mira el log del emulador: casi
> siempre dirá exactamente qué fichero y qué nombre espera.

## Sistemas que NO necesitan BIOS

Game Boy / GBA / NES / SNES / Mega Drive / Master System / N64 / PSP / PS Vita
(juegos), Neo Geo Pocket, WonderSwan, Atari 2600/5200/7800, Lynx, PC Engine
(HuCard), etc.

## Firmware que no es "BIOS"

Algunos emuladores necesitan además **claves o firmware del sistema**:

- **Suyu / Eden / Citron (Switch)**: `prod.keys` + `title.keys` en `switch/`
  (el script los deja en `system/suyu/keys/` para el core de RetroArch).
  Algunos juegos piden además el firmware instalado.
- **Azahar (3DS)**: sysdata en `3ds/`.
- **Vita3K**: necesita su propio firmware (se instala desde el menú del emulador).

## Nota legal

Este directorio **no contiene ni descarga BIOS**. Es solo el sitio donde tú
pones las tuyas para que el script las reparta. Respeta la legislación de tu
país: lo correcto es extraerlas de tus propias consolas.
