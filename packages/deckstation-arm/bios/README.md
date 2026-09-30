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
├── amiga/               kickstarts de Amiga (A500/A600/A1200/A4000/CDTV/CD32)
├── atarist/             TOS de Atari ST (o EmuTOS)
├── atari800/ atari5200/ atari7800/
├── intellivision/ colecovision/ odyssey2/ atarilynx/
├── x68000/ pc98/ pc88/ fmtowns/ pcfx/ neogeocd/
├── macintosh/ apple2gs/
├── adam/ coco/ vsmile/  BIOS de dispositivo de MAME (van a la carpeta de ROMs)
├── mame/                BIOS de dispositivo de MAME (awbios, naomi, konamigv...)
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
| `amiga/` | Kickstarts: `kick34005.A500` (1.3), `kick37175.A500` (2.05), `kick33180.A500` (1.2), `kick40063.A600`, `kick40068.A1200` (3.1), `kick39106.A1200` (3.0), `kick40068.A4000`, `kick34005.CDTV`, `kick40060.CD32` (+ `.ext`). Van **también al `system/` de RetroArch** (si solo están en `bios/amiga`, PUAE y FS-UAE no arrancan). |
| `atarist/` | `tos.img` (TOS 1.02), `tos206.img` (TOS 2.06). **Alternativa libre:** `etos192uk.img` (EmuTOS). |
| `atari800/` | `ATARIXL.ROM` (OS XL/XE), `ATARIBAS.ROM`, `ATARIOSA.ROM`, `ATARIOSB.ROM` |
| `atari5200/` | `5200.rom` |
| `atari7800/` | `7800 BIOS (U).rom`, `7800 BIOS (E).rom` |
| `intellivision/` | `exec.bin`, `grom.bin` |
| `colecovision/` | `colecovision.rom` (o `coleco.rom`) |
| `odyssey2/` | `o2rom.bin`, `c52.bin` (Philips C52), `g7400.bin` (G7400) |
| `atarilynx/` | `lynxboot.img` |
| `x68000/` | `iplrom.dat`, `cgrom.dat` (se dejan en `system/` y en `system/keropi/`) |
| `pc98/` | `bios.rom`, `itf.rom`, `font.rom`, `sound.rom` (van a `system/np2kai/`) |
| `pc88/` | `n88.rom` |
| `fmtowns/` | `FMT_SYS.ROM`, `FMT_DIC.ROM`, `FMT_F20.ROM`, `FMT_DOS.ROM` |
| `pcfx/` | `pcfx.rom` |
| `neogeocd/` | `neocd.bin`, `neocd_f.rom`, `neocd_z.rom` |
| `macintosh/` | `MacII.ROM` (minivmac) |
| `apple2gs/` | `apple2gs.rom` |
| `adam/` `coco/` `vsmile/` | `adam.zip` (+ `adam_ddp/fdc/kb/prn.zip`), `coco.zip`/`coco3.zip`, `vsmile.zip` → **van a la carpeta de ROMs** |
| `mame/` | BIOS de dispositivo: `awbios.zip`, `pgm.zip`, `skns.zip`, `naomi.zip`, `naomi2.zip`, `naomigd.zip`, `konamigv.zip`, `konamigx.zip`, `megaplay.zip`, `megatech.zip`, `sys246.zip`, `sys256.zip`, `sys573.zip`, `galgbios.zip`, `hng64.zip` → **van a la carpeta de ROMs** (arcade, naomi, atomiswave, model2, model3) |
| `misc/` | Cualquier otra (Jaguar, ...) |

> No todas las BIOS son obligatorias: muchos cores de RetroArch funcionan sin
> ellas (o con HLE). Si un sistema no arranca, mira el log del emulador: casi
> siempre dirá exactamente qué fichero y qué nombre espera.

## Sistemas que NO necesitan BIOS

Game Boy / GBA / NES / SNES / Mega Drive / Master System / N64 / PSP / PS Vita
(juegos), Neo Geo Pocket, WonderSwan, Atari 2600, PC Engine (HuCard), Spectrum,
Amstrad CPC, C64, etc.

> **Ojo**: Atari 5200, 7800 y Lynx **sí** tienen BIOS (no son imprescindibles,
> pero mejoran la compatibilidad), y están en el manifiesto.

## Firmware que no es "BIOS"

Algunos emuladores necesitan además **claves o firmware del sistema**:

- **Suyu / Eden / Citron (Switch)**: `prod.keys` + `title.keys` en `switch/`
  (el script los deja en `system/suyu/keys/` para el core de RetroArch).
  Algunos juegos piden además el firmware instalado.
- **Azahar (3DS)**: sysdata en `3ds/`.
- **Vita3K**: necesita su propio firmware (se instala desde el menú del emulador).

## Origen de las BIOS de esta instalación

Las 122 BIOS de esta Odin se recuperaron de la **colección personal del SHARE**
(que resulta ser un share de Batocera: `SHARE/bios` + `SHARE/system/bios`, 17.650
ficheros). De ahí salieron los 21 sistemas que faltaban en el manifiesto
(Atari ST, kickstarts de Amiga, IntelliVision, ColecoVision, Odyssey2, Lynx,
X68000, PC-98/88, FM Towns, PC-FX, Neo Geo CD, Mac II, Apple IIGS y los BIOS de
dispositivo de MAME), además de los ya cubiertos.

`deckstation-bios.sh --check` da **40/40 sistemas cubiertos**.

## Nota legal

Este directorio **no contiene ni descarga BIOS**. Es solo el sitio donde tú
pones las tuyas para que el script las reparta. Respeta la legislación de tu
país: lo correcto es extraerlas de tus propias consolas.
