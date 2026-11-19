# pocknix-power-profiles — perfiles de energía en el escritorio

Puente entre **power-profiles-daemon** (el API D-Bus `org.freedesktop.UPower.PowerProfiles` que
consume el selector "Power Profile" del applet "Battery and Brightness" de Plasma y
`powerprofilesctl`) y los perfiles propios de Pocknix **`bajo|medio|alto`** que ya usan el Game
Mode/QAM (`pocknix-steamos-manager`), el Panel de Control (Hooandee) y `pocknix-power-profile`.

| PPD (D-Bus) | pocknix (fichero + helper) |
|---|---|
| `power-saver` | `bajo` |
| `balanced` | `medio` |
| `performance` | `alto` |

## Ficheros

| Fichero | Qué es |
|---|---|
| `/usr/local/bin/pocknix-power-profiles` | el puente (python3 + PyGObject) |
| `/usr/lib/systemd/system/pocknix-power-profiles.service` | `Restart=always`, habilitado por symlink estático |
| `/etc/power-profiles-daemon/pocknix-profiles.ini` | lista de los tres perfiles para el backend `fake` de ppd |
| `/usr/lib/systemd/system/power-profiles-daemon.service.d/50-pocknix-profiles.conf` | `POWER_PROFILE_DAEMON_FAKE_DRIVER=` apuntando al ini |

Estado real (sin cambios): `/var/lib/pocknix/power-profile` y `/usr/local/bin/pocknix-power-profile`.
El puente **no** escribe ese fichero: llama al helper, que ya lo persiste (sin duplicar). El
ventilador no se toca en ningún caso (es del Panel de Control).

## Por qué el backend `fake` de ppd

El SM8750 en mainline no expone `/sys/firmware/acpi/platform_profile`, así que ppd cae en su
driver *placeholder*, que sólo anuncia `power-saver` y `balanced`: Plasma dibujaría dos opciones
y `powerprofilesctl set performance` daría `invalid choice`. El backend `fake` de ppd (mecanismo
upstream, activado por variable de entorno) permite declarar la lista de perfiles. Con él ppd
anuncia los tres nombres canónicos y **no toca el hardware**: los topes reales de CPU/GPU los
aplica `/usr/local/bin/pocknix-power-profile`, igual que en el Game Mode.

## Sincronización (bidireccional, con guarda anti-bucle)

* `ActiveProfile` cambia en el daemon → `pocknix-power-profile <bajo|medio|alto>`.
* `/var/lib/pocknix/power-profile` cambia (Game Mode / Panel) → `powerprofilesctl set <perfil>`.
* Al arrancar manda el fichero: se alinea el daemon y se re-aplica el perfil (idempotente).
* La convergencia es idempotente, así que el eco del propio cambio no encuentra nada que hacer
  y el bucle se corta solo.

## Notas del Odin 3

* `powerprofilesctl set ...` desde root (o desde la sesión activa: la acción polkit
  `switch-profile` tiene `allow_active=yes`). Por SSH no hay sesión activa → usar `sudo`.
* Con el **TDP del Panel de Control activado** (`tdp_control_enabled` en su `state.json`), su
  guardia re-aplica cada ~3 s su nivel como techo (p. ej. 2400000 kHz / 734 MHz), así que los
  topes de `medio`/`alto` pueden quedar limitados a ese techo. `bajo` (por debajo del techo) y
  el scheduler `scx` del perfil sí se mantienen. No es cosa de este puente: el perfil, el
  fichero y el daemon quedan siempre sincronizados.
* El applet "Battery and Brightness" (`org.kde.plasma.battery`, con "Power Profile") viene en
  el plugin de plasma/powerdevil; **no existe** un paquete `plasma-battery` en ALARM.
