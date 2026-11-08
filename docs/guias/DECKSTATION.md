# DeckStation — emulación en la Odin 3

**Qué es**: sistema de emulación portable (ES-DE + ~30 emuladores ARM64) que vive
entero en `/opt/deckstation`. Proyecto independiente de **stshunz**
(https://github.com/stshunz/deckstation-arm); CalvOS lo empaqueta y lo integra.

## Instalación

1. Abre **Pocknix Tools**.
2. Elige **“Install DeckStation (emulators)...”**.
3. Espera: descarga unos **1,5 GB** (30 AppImages + launchers + configs + assets de
   RetroArch) y necesita red. Es **seguro repetirlo**: lo que ya está se salta.
4. Al terminar, DeckStation aparece como **icono en el modo juego** de Steam
   (tile “DeckStation”). También puedes lanzarlo con el comando `deckstation`.

El instalador real es `/opt/deckstation/scripts/deckstation-setup.sh`; el menú de
Pocknix Tools solo lo llama. Después, para actualizar o añadir emuladores sueltos,
usa el **Updater dentro de ES-DE**.

## Dónde está todo

```
/opt/deckstation/
├── DeckStation.AppImage / DeckStation.sh   # ES-DE (el frontend)
├── Apps/<Emulador>/                        # emuladores + su .home portable
├── saves/                                  # partidas guardadas
├── logs/                                   # logs de ejecución
├── bios/                                   # BIOS/firmware (tú las pones)
├── configs/                                # configuración base reproducible
├── Media/                                  # carátulas/vídeos
├── settings/                               # ajustes de ES-DE
└── scripts/                                # setup, cores, bios, update, launcher
```

Cada emulador usa su **`.home` portable** como `$HOME`: así sus saves/configs
quedan dentro de `/opt/deckstation` y mover la carpeta se lo lleva todo.

## Uso diario

- **Modo juego**: icono **DeckStation** → ES-DE. Navega con el mando; **A** entra,
  **B** vuelve, **Start** abre el menú.
- **Escritorio/terminal**: `deckstation`.
- **Añadir ROMs**: copia tus juegos a la carpeta de ROMs. Por defecto ES-DE usa
  `./ROMs` dentro de su home portable; cámbialo en **ES-DE → Ajustes → Rutas de
  ROMs** (puede ser una carpeta de la SD).
- **Actualizar emuladores**: dentro de ES-DE → **Updater**. Instala, actualiza o
  repara uno a uno y muestra el estado de BIOS.

## BIOS

- Deja tus ficheros en `/opt/deckstation/bios/` (el manifiesto `required.txt` dice
  qué espera cada sistema y `deploy-bios.txt` a dónde va cada uno).
- Comprueba el estado con:
  ```sh
  /opt/deckstation/scripts/deckstation-bios.sh --check
  ```
- El **Updater** también tiene una pestaña **BIOS / Firmware**.
- Sin la BIOS del sistema, el emulador puede arrancar y quedarse en negro: es lo
  primero que hay que mirar.

## Cores (RetroArch)

- El setup deja los cores en la carpeta portable y **prunea** de `es_systems.xml`
  los `<command>` cuyo core no exista.
- Hay tres scripts en `scripts/`: `deckstation-cores.sh` (copia los del sistema),
  `deckstation-cores-fetch.sh` (descarga los que falten) y
  `deckstation-cores-sync.sh` (poda ES-DE).
- **Orden importante**: primero poblar (`-cores.sh`/`-fetch.sh`) y **después**
  sincronizar (`-sync.sh`). Al revés, el sync no ve el core y lo quita.
- Lo que pongas tú en la carpeta portable **no se borra nunca**.

## Mandos y atajos

El mapeo verificado y los atajos de RetroArch están en
[`../MANDO-ODIN3-RETROARCH.md`](../MANDO-ODIN3-RETROARCH.md). Si un mando no
responde en un emulador, revisa primero el perfil de ese emulador y el
`SDL_VIDEODRIVER` que fija su `lanzar.sh`.

## Guardados y copias

- Partidas: `/opt/deckstation/saves/` y los `.home` de cada emulador.
- Para una copia completa y portable: copia `/opt/deckstation/` entera (o al menos
  `saves/`, `configs/`, `settings/` y los `.home`).
- Antes de tocar configuraciones, haz copia de la carpeta del emulador.

## Problemas comunes

| Síntoma | Qué mirar |
|---|---|
| ES-DE no lanza un juego | `../DECKSTATION-ESDE-NO-LANZA-JUEGOS.md` (wrapper/`<command>`/core). |
| Un emulador no aparece | Updater → instalarlo; luego `deckstation-cores-sync.sh`. |
| Pantalla negra al entrar | BIOS ausente o `SDL_VIDEODRIVER`; revisa el log en `logs/`. |
| Suyu (Switch) no arranca | Claves en `<RetroArch>.home/.config/retroarch/system/suyu/keys/`. |
| Juego en inglés en Suyu | Opciones del core → `suyu_language` → Spanish. |
| No aparecen los assets XMB | Re-ejecuta el setup (descarga los assets de RetroArch). |
