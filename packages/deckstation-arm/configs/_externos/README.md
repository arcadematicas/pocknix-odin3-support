# configs/_externos/ — perfiles de mando y configs de emulador AJENOS

Todo lo que hay en esta carpeta viene **copiado tal cual** de repos de terceros
(ROCKNIX, Batocera, Armada, stshunz/deckstation-*). Nada de esto se despliega
automáticamente: `deploy-manifest.txt` **no** menciona ninguna ruta `_externos/`,
así que el instalador de DeckStation no toca este contenido.

Motivo de que estén aparte y no mezclados con `configs/<emulador>/`:
`configs/azahar/`, `configs/dolphin/`, `configs/duckstation/`, `configs/retroarch/`…
son **nuestros**, están ajustados y ya se despliegan. Si se copiaran encima,
`deploy-manifest.txt` (política `keep`) los pisaría en cualquier instalación
nueva. Aquí no hay nada que pisar.

## Layout

```
_externos/
  rocknix/                 ROCKNIX/distribution  (rama `next`)
    <emulador>/            un directorio por emulador standalone
    gptk/                  perfiles de traducción de mando (Gamepad Translation Kit)
    retroarch/             retroarch.cfg de SM8750 + gamepads/*.cfg
    inputplumber-SM8750/   perfiles InputPlumber del Odin 3
    inputplumber-SM8550/   lo mismo para Odin 2 / Thor (SM8550)
    quirks/                scripts de quirk por dispositivo AYN
  armada/                  armada-os/armada
    <emulador>/            + azahar-store/ (plantilla del Decky)
    input/                 capa de entrada: udev, busctl, keylayout, tests
    sistema/               conf de sistema (no es mando, está por contexto)
  batocera/                batocera-linux/batocera.linux
    hotkeygen/             mapeos botón → acción global
    perfiles/              .keys: traducción de botones de mando a teclas
    udev/                  regla del gamepad de la Odin 3
    sistema/               batocera.conf de la Odin 3 (no es mando)
  deckstation-x86_64/      stshunz/deckstation-x86_64
```

`stshunz/deckstation-arm` **no** aparece: sus configs ya son copia de lo que
tenemos en `configs/` (mismos nombres, mismos contenidos), no aportan nada.

## Licencias

Ficheros de texto de configuración: sin problema. Los scripts de quirk llevan su
cabecera `SPDX-License-Identifier: GPL-2.0` de ROCKNIX si la tienen; se deja tal
cual. No se ha copiado **ningún** binario, ROM, BIOS, firmware ni shader cache.
Ver `docs/MANDOS-DE-OTROS-SISTEMAS.md` para el inventario completo, los descartes
y lo que falta.