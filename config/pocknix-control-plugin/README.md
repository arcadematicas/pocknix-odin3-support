# PocknixControl (plugin Decky) — ampliado con governor + power profiles

Plugin Decky de control del Odin 3. **IMPORTANTE**: se distribuye en la imagen en
`/usr/share/decky-plugins/PocknixControl` y Decky lo copia a
`/home/deck/homebrew/plugins/PocknixControl/` al arrancar. **Los cambios se hacen
siempre en la fuente** (`/usr/share/decky-plugins`), o se pierden al reiniciar.

## Estructura (lo relevante de esta sesión)
```
main.py                          # backend Decky (expone set_fan_mode, set_lavd_mode,
                                 #   set_cpu_governor, set_power_profile, ...)
py_modules/pocknix_control/
  modes.py                       # FAN_MODES incluye "off"
  power.py                       # NUEVO: cpu_governor(), power_profile() + setters
  config.py                      # build_config() devuelve cpuGovernor y powerProfile
dist/index.js                    # frontend (bundle parcheado a mano)
```

## Cambios
1. **Fan mode "off"** añadido a FAN_MODES (backend) y al desplegable Fan Curve.
2. **CPU Governor** (powersave|schedutil|performance|ondemand) — nuevo select en
   Performance (Default y per-game), llama a `set_cpu_governor`.
3. **Power Profile** (bajo|medio|alto) — nuevo select, llama a `set_power_profile`.
4. Los selects per-game guardan en los tweaks del juego (`cpuGovernor`,
   `powerProfile`), que el `pocknix-proton-wrapper` aplica al lanzar.

## Notas de edición del frontend
- El bundle `dist/index.js` se parcheó a mano (no hay toolchain TS en la Odin).
- Se añadieron: `governorOptions`, `powerProfileOptions` (tras `lavdOptions`),
  los setters `setCpuGovernor`/`setPowerProfile`, y los `SelectEdit` en el bloque
  Default (junto a CPU Scheduler/Fan Curve) y en `PerfFields` (per-game).
- `node --check` pasa. El `.map` queda obsoleto respecto al bundle (inofensivo).
- Si se quiere tocar por fuente, hay que reconstruir desde los fuentes del sourcemap.
