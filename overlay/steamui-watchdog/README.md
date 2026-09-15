# Watchdog de la UI de Steam (steamui-watchdog)

**Problema**: la interfaz de Steam (steamwebhelper, que es x86_64 corriendo bajo
FEX) se congela/desaparece de forma intermitente, pero Steam sigue vivo. Bug de
upstream FEX/CEF, sin fix completo.

**Solución**: `steamwebhelper` expone un puerto de depuración
(`127.0.0.1:8080`). Cuando la UI se bloquea, ese puerto deja de responder aunque
el proceso siga vivo. El watchdog hace un healthcheck cada 30s y, tras 3 fallos
consecutivos (~90s), reinicia `steamwebhelper` (Steam lo relanza solo).

## Archivos
- `/usr/local/bin/steamui-watchdog.sh` — el watchdog
- `/etc/systemd/system/steamui-watchdog.service` — servicio (Restart=always)

## Mitigaciones complementarias (variables FEX)
`/etc/environment.d/fex-fix.conf` (ver `config/fex/`):
```
FEX_EARLY_LOG_DISABLE=1
FEX_JIT_BlockLinking=0
FEX_GDBServer=0
```
Reducen la frecuencia del cuelgue de steamwebhelper (aplican al reiniciar la
sesión de juego).

## Workaround manual
Si la UI se congela y no quieres esperar los 90s del watchdog:
`pkill -x steamwebhelper` (Steam lo relanza en unos segundos).
