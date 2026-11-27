# Perfiles de energía desde el escritorio (Plasma ↔ panel)

## Problema

En la Odin, `power-profiles-daemon` (ppd) arranca con **`PlatformDriver: fake`**: el selector
de energía de Plasma (Rendimiento / Equilibrado / Ahorro) solo cambia la etiqueta. La potencia
real la manda el panel de Decky (backend `arm-frequency-levels`, niveles 1-10), que además
reafirma su nivel cada 3 s; cualquier cambio externo (incluido `pocknix-power-profile`) lo
detecta como *drift* y lo revierte.

En modo juego se usa el panel, pero en escritorio no hay acceso cómodo a él: de ahí el puente.

## Solución

Módulo `py_modules/power_bridge.py` dentro del plugin, enganchado en `_startup()` de `main.py`
justo después de `_probe_tdp_backend()`. Un hilo lee cada 2 s el perfil activo de ppd
(`busctl --system get-property net.hadess.PowerProfiles … ActiveProfile`) y, cuando cambia, llama
a la API del propio plugin:

```python
await plugin.set_tdp_watts(nivel, "global")
```

Así el perfil guardado y el guardián del panel quedan en sync (no hay pelea de escritores).

Mapeo por defecto (configurable en `/etc/calvos/power-bridge.json`):

| Perfil de Plasma | Nivel | CPU (pequeños/grandes) | GPU |
|---|---|---|---|
| `power-saver` | 3 | 1,79 / 1,96 GHz | 525 MHz |
| `balanced` | 6 | 2,40 / 2,84 GHz | 734 MHz |
| `performance` | 10 | 3,53 / 4,09 GHz | 1,10 GHz |

Al arrancar no pisa el nivel guardado salvo que ppd esté en `performance` o `power-saver`
(perfiles elegidos explícitamente); con `balanced` (el de por defecto de ppd) no toca nada.

## Instalación / actualización

Lo instala y lo vuelve a enganchar **`/usr/local/bin/pocknix-panel-control-patch`**
(`ensure_power_bridge`), que se ejecuta al instalar/actualizar el plugin. Es idempotente, deja
`main.py.bak-powerbridge` y reescribe `power_bridge.py` si cambia el contenido. El código fuente
vive en `overlay/usr/local/bin/pocknix-panel-control-patch` (constante `POWER_BRIDGE_PY`).

## Verificación

```bash
journalctl -u pocknix-decky-loader -b | grep "power bridge"
# power bridge: activo (ppd=performance, niveles={...})
# power bridge: performance -> nivel 10 ({'ok': True, ...})
for p in /sys/devices/system/cpu/cpufreq/policy*/; do cat $p/scaling_max_freq; done
# 3532800 / 4089600 con performance
```

## Límites

- Solo actúa en cambios de perfil (y en el arranque si el perfil no es `balanced`).
- En modo juego sigue mandando el perfil por juego del panel; el puente solo escribe el global.
- Si ppd desapareciera, el puente no hace nada y el panel sigue funcionando igual.
