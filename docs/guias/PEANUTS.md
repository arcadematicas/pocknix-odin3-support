# Peanuts Native — juegos de Switch en la Odin 3

**Qué es**: un host nativo aarch64 para juegos de Switch (Peanuts Native, proyecto
`igawa6/peanuts-native`). CalvOS instala el AppImage y su lanzador; **no incluye juegos**.
Detalle técnico: [`../PEANUTS.md`](../PEANUTS.md).

## Abrir y preparar un juego

1. Abre **PeanutsNative** desde el menú (o `peanutsnative` en una terminal).
2. La primera vez pide tus **`prod.keys`** (ya configuradas en la Odin).
3. Elige el **`.xci` o `.nsp`**; el launcher lo prepara (10-40 min la primera vez:
   importa, empaqueta y compila shaders). El pack queda en `~/Games/PeanutsNative`.
4. **Play**. En Steam puedes añadir los juegos con `peanutsnative --steam` (con Steam cerrado).

## Fuentes de consola (firmware) — necesario para algunos juegos

**Síntoma**: el juego se prepara sin errores pero **no abre**; en el log aparece
`CRASH sig=11 addr=0x38 pc=main+0x8b37c` y `... (the standard font: nothing of its own
was found)`. Pasa porque el host está usando las fuentes de relleno y el juego pide un
carácter que no existe. Le ocurre a **Echoes of Wisdom** y puede pasarle a más juegos.

**Solución** (una vez por consola): importar las fuentes del **firmware de Switch**.

### Qué necesitas

- Un **firmware de Switch** (carpeta o `.zip` con los NCA) y sus **`prod.keys`**.
  No lo distribuimos: usa el de tu propia consola o el que ya uses con otros emuladores.
  Las claves deben ser de esa misma versión de firmware.

### Comando

```sh
# claves configuradas (keys.path o ~/.switch/prod.keys)
calvos-peanuts-firmware /ruta/Firmware.22.1.0.zip

# si las claves no son las configuradas
calvos-peanuts-firmware --keys /ruta/prod.keys /ruta/Firmware.22.1.0.zip
```

El comando extrae las fuentes (unos 17 MB) en
`~/.local/share/peanutsnative/firmware/fonts` y escribe `DM_FONT_DIR` en
`~/.config/peanutsnative/settings.env`, así que vale para **todos** los juegos. No
necesita root ni descomprimir el AppImage a mano.

### Comprobar

```sh
calvos-peanuts-firmware --check
```

Debe salir `rc=0`, con `standard.ttf` de **más de 1 MB** (el de relleno pesa 337 KB) y la
línea `DM_FONT_DIR` en `settings.env`. Después abre el juego otra vez.

### Notas

- Si un juego concreto necesita otra carpeta (raro), pon `DM_FONT_DIR=...` en
  `~/.config/peanutsnative/<titleID>.env`; ese fichero manda sobre el global.
- Al actualizar el paquete o el AppImage **no** hay que repetirlo: las fuentes y el
  `settings.env` se quedan.
- El aviso también sale al instalar/actualizar `calvos-peanuts` (mensaje de pacman).

## Idioma

Castellano por defecto en la Odin (`DM_LANG=es`). Para todos los juegos:
`~/.config/peanutsnative/settings.env`; para uno solo: `<titleID>.env`.

## Si algo falla

- **No abre**: mira el log más reciente en
  `~/.local/share/peanutsnative/<titleID>/logs/`. Si es el crash de fuentes, ejecuta
  `calvos-peanuts-firmware --check` y, si falta, importa el firmware.
- **Mando**: en la Odin, inputplumber entrega un mando Xbox virtual; el lanzador ya lo
  configura (`SDL_GAMECONTROLLER_IGNORE_DEVICES`). En modo juego funciona igual.
- **Espacio**: cada juego ocupa 5-20 GB (pack + `.nup` + shaders) en `~/Games/PeanutsNative`.
- **Preparar tarda**: es normal (shaders). La primera vez descarga herramientas.
