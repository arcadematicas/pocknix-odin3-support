# OpenABL en una consola nueva, desde fastboot (sin root en Android)

Cuándo se usa este método: la consola viene con **Android de serie** (sin CalvOS, sin
Linux instalado) y **sin root**, así que los scripts del kit (`backup_abl.sh`,
`flash_abl.sh`) no pueden hacer `dd` a `abl_a`/`abl_b`. También vale si el sistema Linux
está roto y no arranca.

Es la vía que se usó el **22/11/2026** en la Odin reparada y la que toca para la
**Odin 3 Portal** cuando llegue.

## Por qué no vale la vía normal

`pocknix-update-abl` (ver [`../guias/ARRANQUE-OPENABL.md`](../guias/ARRANQUE-OPENABL.md)) se
ejecuta **desde Linux ya instalado**: respalda los dos slots con `dd` en `/flash/openabl/`,
copia los `.img` a una SD/USB si hay, escribe los dos slots y verifica cada uno. En una
consola recién salida de fábrica no hay Linux que ejecutar.

La alternativa **no necesita root** y además es **más segura**: el `abl` es A/B, así que se
escribe **solo el slot inactivo** y se cambia el activo. El ABL de serie se queda intacto en
el otro slot y la vuelta atrás es un cambio de slot, sin `dd` de rescate.

## Antes de tocar nada

| Comprobación | Comando / valor |
|---|---|
| Bootloader **desbloqueado** | `fastboot getvar unlocked` → `unlocked: yes`. Si dice `no`, hay que desbloquear (borra datos) antes de seguir. |
| Batería | > 50 % y cable enchufado |
| Cable | **corto, de datos**, a un puerto directo de la placa (no hub, no frontal) |
| ELF correcto | `abl_signed-SM8750.elf`, **532.480 B**, sha256 `0dba7b90d1a36e13977c00fec87f4f5ccc8f49b98864ad495a1ed04d35e33c3a` |
| Herramientas | `android-tools` (`adb`, `fastboot`) |

En un PC de escritorio, si `fastboot` solo funciona como root, se arregla con una regla udev:

```bash
echo 'SUBSYSTEM=="usb", ATTR{idVendor}=="18d1", MODE="0666"' | sudo tee /etc/udev/rules.d/51-android.rules
sudo udevadm control --reload-rules && sudo udevadm trigger
# desenchufar y reenchufar
```

Dónde está el ELF: dentro del paquete `pocknix-bootloader-sm8750`, en
`/usr/share/pocknix/bootloader/openabl/abl_signed-SM8750.elf`. En el centro también se puede
sacar del `.pkg.tar.zst` compilado sin tocar la consola.

## Instalador para usuarios

Todo lo de abajo está automatizado en [`../tools/openabl-flash/`](../tools/openabl-flash/README.md):
`flash-openabl.sh` (Linux) y `flash-openabl.cmd` (Windows, doble clic). Verifica el sha256, se
niega a tocar el slot activo, pide escribir `FLASH` y no reinicia la consola.

## Receta

1. **Entrar en el fastboot de verdad** (el del ABL, no `fastbootd`):
   apagar del todo → mantener **Volumen −** → enchufar el cable → soltar cuando salga la
   pantalla de fastboot. Si no entra: **Power + Volumen −**.
   > `fastbootd` (el de recovery) **no** sirve para `abl`: solo ve particiones lógicas.
   > Sirve como puente: `fastboot reboot bootloader`.
2. **Ver el slot activo** (y no obsesionarse si falla, ver trampas):
   ```bash
   fastboot getvar current-slot      # p. ej. current-slot: a
   ```
3. **Flashear el slot INACTIVO** con el ELF de OpenABL (si el activo es `a`, va a `b`):
   ```bash
   fastboot flash abl_b /ruta/abl_signed-SM8750.elf
   # esperado: Sending 'abl_b' (520 KB) OKAY / Writing 'abl_b' OKAY / Finished
   ```
4. **Activar ese slot**:
   ```bash
   fastboot --set-active=b
   ```
5. **Arrancar con Volumen −** → menú de OpenABL → *Device model* (p. ej. **AYN Odin 3** o
   **AYN Odin 3 Portal**) → *Boot mode: Linux* → *Boot source* (Internal o SD) → *Start*.
   La primera vez hay que elegir modelo: si no, la pantalla se queda negra.

### Vuelta atrás

| Situación | Cómo |
|---|---|
| Algo no convence y el otro slot tiene el ABL de serie | `fastboot --set-active=a` (desde fastboot), o en el menú de OpenABL *Boot other slot* |
| Quieres volver al bootloader original del todo | El slot con el ABL de serie sigue intacto: actívalo y, si quieres, reescribe el otro con `fastboot flash` |

No hace falta backup previo con `dd` **si no se toca el slot activo**: esa es toda la gracia
de escribir en el inactivo.

### Después: `--status` dirá `mixed` (y es lo correcto)

Con OpenABL ya arrancando, `sudo pocknix-update-abl --status` devolverá `state=mixed` porque los
dos slots **no** son iguales: `b` es OpenABL y `a` sigue siendo el ABL de serie. `running_openabl`
sí dirá `1.2`. No es un error y no hay que "arreglarlo".

Ojo si algún día ejecutas `pocknix-update-abl` desde Linux: escribe **los dos** slots (antes
respalda los dos en `/flash/openabl/`), así que perderías el de serie en `a` salvo por ese backup.
Si quieres conservarlo, no lo ejecutes: el slot `b` ya está bien. Aun así, si vas a quedarte con OpenABL, saca una copia del slot
de serie cuando ya haya Linux (para tenerla fuera de la consola).

## Lo que pasó el 22/11/2026 (caso real)

- La Odin reparada estaba en **Android de serie**, con depuración USB, pero **sin `su`** → el
  kit no podía escribir. Se intentó por `adb` y no había root.
- El **USB del sobremesa** iba fatal: `device descriptor read/64, error -110`, `error -71`,
  re-enumeraciones y `adb`/`fastboot` que veían el dispositivo pero no le hablaban. Con **otro
  cable** y en el **portátil** (con regla udev) funcionó a la primera.
- 21:44 — primer intento con el ELF de **ROCKNIX** al slot `b`: se colgó (era el enlace USB).
- 21:48 — `fastboot flash abl_b` con **OpenABL** → **OKAY** (520 KB escritos).
- 21:48 — `fastboot --set-active=b` → **OKAY**.
- ABL de serie **intacto en `a`** hasta hoy: de ahí que esta consola arranque del slot `b`.
- Después: arranque desde SD, instalación interna y el fallo del **cursor parpadeando** porque
  el instalador no escribía las entradas BLS (arreglado a mano y luego en
  `pocknix-install-internal`).

## Trampas (todas vividas)

1. **`fastboot getvar all` se cuelga** en este equipo mientras `flash` sí funciona. No pongas
   el flash detrás de un `getvar`: si `fastboot devices` lo lista, intenta el flash directo.
2. **`adb` no es fastboot.** Si `adb shell` no contesta, mira la interfaz USB: `iInterface …
   ADB Interface` (clase 255/protocolo 1) es Android; fastboot es protocolo 3.
3. **Errores `-110` / `-71`** = cable o puerto, no software. Cable corto de datos y puerto
   directo; si el sobremesa falla, prueba el portátil.
4. **Desbloqueo**: sin `unlocked: yes` el flash falla (y no pasa nada). No es un fallo raro:
   es el estado de fábrica.
5. **Primer arranque sin modelo elegido** = pantalla negra. No está roto.
6. Si después instalas Linux en la flash interna, el instalador **debe escribir el payload
   BLS** (`/Image`, `/dtbs`, `/loader/entries/*.conf`); sin él OpenABL no tiene qué arrancar.
   Ya lo hace `pocknix-install-internal` desde el 22/11.

## Para la Portal (checklist del día)

- [ ] `fastboot getvar unlocked` → `yes` (si no, desbloquear antes de nada).
- [ ] Comprobar el ELF: 532.480 B y sha256 `0dba7b90…e33c3a`.
- [ ] `fastboot flash abl_b` (slot inactivo) y `fastboot --set-active=b`.
- [ ] Volumen − → *Device model = AYN Odin 3 Portal* → *Start* (aquí se ve si el panel
      `vtdr6130,o3p` enciende).
- [ ] Anotar el sha256 del ELF y el slot usado en el vídeo/registro del día.
- [ ] Copiar el ELF y, cuando haya Linux, una copia del slot de serie al PC.
