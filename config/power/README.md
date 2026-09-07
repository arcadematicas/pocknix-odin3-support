# Gestión de potencia del Odin 3: fan off, governor CPU y power profiles

Ampliación del sistema de control de Pocknix (patrón archivo→daemon→plugin
PocknixControl) para el Odin 3. Todo esto se controla desde el plugin Decky
PocknixControl → sección Performance, tanto en el perfil global como por juego.

## Componentes (instalados en la Odin)

| Archivo | Qué es |
|---|---|
| `/usr/bin/pocknix-fancontrol` | Daemon de curva de ventilador (modificado: soporta modo `off`) |
| `/usr/local/bin/pocknix-fan-mode` | get/set modo fan (quiet\|moderate\|performance\|off) → `/var/lib/pocknix/fan-mode` |
| `/usr/local/bin/pocknix-cpu-governor` | get/set governor CPU → `/var/lib/pocknix/cpu-governor`, aplica a las 8 CPUs |
| `/etc/systemd/system/pocknix-cpu-governor.service` | oneshot que re-aplica el governor al arrancar |
| `/usr/local/bin/pocknix-power-profile` | get/set perfil de potencia (bajo\|medio\|alto) → `/var/lib/pocknix/power-profile` |
| `/etc/systemd/system/pocknix-power-profile.service` | oneshot que re-aplica el perfil al arrancar |
| `/usr/local/bin/pocknix-pergame-power.py` | daemon que aplica governor/perfil del **juego en curso** y restaura el global al salir |
| `/etc/systemd/system/pocknix-pergame-power.service` | servicio del daemon per-game |

## Modos

### Fan: quiet | moderate | performance | **off**
- `off` fija PWM=0 (sin refrigeración activa) — thresholds inalcanzables en el daemon.
  ⚠️ Solo para juegos ligeros o con refrigeración externa.
- El modo se cambia en caliente (el daemon relee el archivo cada ~3s), sin reiniciar nada:
  `pocknix-fan-mode off`

### Governor CPU: powersave | schedutil | performance | ondemand
- `schedutil` es el recomendado (lo usa `scx_lavd`). "Más suave" = `powersave`/`ondemand`.
- Se aplica en caliente a las 8 CPUs y persiste (servicio oneshot al boot):
  `pocknix-cpu-governor powersave`

### Power profile (pseudo-TDP): bajo | medio | alto
El SM8750 **no expone nodo de TDP** en mainline, así que el "TDP" se gestiona
limitando las frecuencias máximas de CPU y GPU (menos MHz = menos consumo):
- `bajo`:  CPU ~1.7 GHz, GPU 525 MHz
- `medio`: CPU grandes ~2.8 GHz, GPU 832 MHz
- `alto`:  sin límite (restaura cpuinfo_max_freq + GPU 1.1 GHz)
- El snapshot de los máximos originales se guarda en `/var/lib/pocknix/power-profile-orig`
  la primera vez que se limita.
- ⚠️ Son límites *software*: el **LMh térmico del SoC** puede bajarlos aún más bajo
  carga (protección hardware, siempre gana).

## Per-game (governor + power profile por juego)

El `pocknix-proton-wrapper` escribe `/run/pocknix/game-mode` al lanzar un juego con
el formato `pid fan lavd governor profile` (campos "-" = sin override). El daemon
`pocknix-pergame-power` lee ese archivo cada ~3s:
- si el PID del juego vive → aplica el governor/perfil de ese juego;
- al morir el PID → restaura el governor/perfil **global** guardado.

Los lectores antiguos (`pocknix-fancontrol`, `pocknix-lavd-mode`) siguen
funcionando porque los campos nuevos se **añaden al final** y ellos hacen
`read -r pid fan _` / `read -r pid _ lavd`.

## Notas
- Todos los archivos del sistema (`/usr/bin`, `/usr/lib/pocknix`, `/etc/systemd`)
  viven en la imagen; una actualización de Pocknix podría sobrescribirlos
  (los backups `*.bak.*` en la Odin sirven para restaurar).
- El plugin PocknixControl se distribuye en la imagen en
  `/usr/share/decky-plugins/PocknixControl` y Decky lo copia a
  `/home/deck/homebrew/plugins/` al arrancar → **modificar siempre la fuente**
  (`/usr/share/decky-plugins`), no la copia instalada, o los cambios se pierden.
