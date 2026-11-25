# Instalar OpenABL 1.2 desde un PC (Odin 3 / Odin 3 Portal, sin root)

## Qué hace

Esta herramienta instala **OpenABL 1.2** en una consola AYN con SM8750 (Odin 3 u Odin 3 Portal)
que todavía tiene Android de serie **sin root**. No necesitas saber fastboot: el script comprueba
el ELF, flashea **solo el slot inactivo**, activa ese slot y deja el **ABL de serie intacto** en el
otro. Nunca desbloquea el bootloader, nunca reinicia la consola y nunca toca el slot activo.
Si algo va mal, la vuelta atrás es cambiar de slot.

Documentación de fondo: [fastboot sin root](../../docs/OPENABL-FASTBOOT-SIN-ROOT.md).

**Aviso:** en una consola que **ya tiene Linux instalado**, la vía normal es
`pocknix-update-abl` (se ejecuta desde la propia consola). Este método es para consolas nuevas,
sin Linux, o con el sistema Linux que no arranca.

## Requisitos

- PC con Linux, macOS o Windows 10/11 con **Windows PowerShell 5.1** (viene incluido).
- `fastboot` instalado: Linux (`android-tools`, por ejemplo `sudo pacman -S android-tools` o
  `sudo apt install android-tools-fastboot`), macOS (`brew install android-platform-tools`) o
  Windows (platform-tools de Google, en `%LOCALAPPDATA%\Android\Sdk\platform-tools`).
- Consola con **batería > 50 %**, cable **corto de datos** y puerto USB directo del PC (sin hub).
- Bootloader **ya desbloqueado**. El script comprueba `unlocked: yes`; si dice `no`, te avisa,
  pero **nunca lo desbloquea por ti** (desbloquear borra los datos).

## Cómo entrar en fastboot

1. Apaga la consola **del todo** (no suspendida).
2. Mantén pulsado **Volumen −** y, sin soltar, enchufa el cable USB al PC.
3. Suelta cuando aparezca la pantalla de fastboot. Si no entra, usa **Power + Volumen −**.
4. Debe ser el fastboot del ABL, no el `fastbootd` del recovery.

## Uso en Linux y macOS

Abre una terminal en esta carpeta:

```bash
./flash-openabl.sh --dry-run     # ver el plan sin descargar ni escribir nada
./flash-openabl.sh               # descarga, verifica y pregunta antes de flashear
./flash-openabl.sh --elf /ruta/abl_signed-SM8750.elf   # usar un ELF local
```

Cuando pida confirmación, escribe exactamente `FLASH` en mayúsculas. Cualquier otra cosa cancela.
El script guarda un registro `openabl-flash-<fecha-hora>.log` junto al propio script.

## Uso en Windows

Haz **doble clic en `flash-openabl.cmd`**. Se abrirá una ventana de PowerShell con el mismo
asistente; al terminar, la ventana espera a que pulses una tecla para que puedas leer el resultado.
Si prefieres la terminal:

```powershell
.\flash-openabl.ps1 -DryRun
.\flash-openabl.ps1
.\flash-openabl.ps1 -Elf C:\ruta\abl_signed-SM8750.elf
```

Opciones en los dos sistemas: `--help`/`-Help`, `--dry-run`/`-DryRun`, `--elf <ruta>`/`-Elf <ruta>`,
`--slot a|b`/`-Slot a|b` (solo si no se puede leer el slot actual) y `--yes`/`-Yes` (omite la
confirmación; **solo para automatizar**).

## Primer arranque

Desconecta el cable, enciende manteniendo **Volumen −** y en el menú de OpenABL elige:

1. **Device model**: `AYN Odin 3` o `AYN Odin 3 Portal` (según tu consola).
2. **Boot mode**: `Linux`.
3. **Boot source**: `SD` o `Internal`.
4. **Start**.

La primera vez hay que elegir el modelo: si no, la pantalla se queda negra y no parece arrancar.

## Volver atrás

Si algo no convence, desde fastboot activa el slot original con
`fastboot --set-active=<slot original>` (por ejemplo `fastboot --set-active=a`), o entra en el
menú de OpenABL y elige **Boot other slot**. El ABL de serie sigue intacto en ese slot.

## Solución de problemas

| Síntoma | Qué hacer |
|---|---|
| Errores USB `-110` / `-71`, fastboot "ve" el dispositivo pero no habla con él | Es cable o puerto, no software. Usa un cable corto de datos, conéctalo directo al PC (sin hub, mejor puerto trasero) y prueba otro cable y otro puerto; si falla el sobremesa, prueba un portátil. |
| `fastboot devices` no muestra nada | Apaga del todo, mantén Volumen − y enchufa; si no, Power + Volumen −. Comprueba también cable y puerto. |
| `getvar all` o `getvar current-slot` se cuelga | Fallo conocido en estas consolas. El script tiene timeout y ofrece `--slot a` o `-Slot b` para indicar el slot activo; el flash sigue funcionando. |
| `unlocked: no` | Hay que desbloquear el bootloader desde Android antes. Borra los datos. El script no lo hace por ti. |
| Windows: `no permissions` o fastboot no responde | Instala el controlador **Android Bootloader Interface** (Administrador de dispositivos → controladores del dispositivo fastboot). |
| Linux: `no permissions` | Crea `/etc/udev/rules.d/51-android.rules` con `SUBSYSTEM=="usb", ATTR{idVendor}=="18d1", MODE="0666"`, ejecuta `sudo udevadm control --reload-rules && sudo udevadm trigger` y vuelve a enchufar. El script muestra la regla, pero no ejecuta `sudo`. |
| "ELF no válido" | Comprueba los dos valores que imprime (532480 bytes y sha256). Vuelve a descargar o usa `--elf` con el fichero correcto extraído del tarball oficial. |
| Falló el flash | No se ha activado ningún slot. Revisa cable, puerto y controladores y vuelve a intentarlo. |
| "Escrito pero no activo" | Puedes terminar después con `fastboot --set-active=<slot>` sin volver a flashear. |

## English summary

OpenABL 1.2 installer for AYN Odin 3 / Odin 3 Portal (SM8750) from a PC, with no root.
It flashes only the inactive slot and activates it, leaving the stock ABL untouched.
Enter fastboot: power off, hold Volume - and plug the cable; or Power + Volume -.
Run flash-openabl.sh on Linux/macOS, or double-click flash-openabl.cmd on Windows.
First boot: choose Device model, Boot mode Linux, source SD or Internal, then Start.
To go back: fastboot --set-active=<original slot> or "Boot other slot" in the menu.
