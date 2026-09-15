# FEX — variables de estabilidad

`fex-fix.conf` se instala en `/etc/environment.d/fex-fix.conf`.

```
# FEX stability tweaks for steamwebhelper (x86_64 under FEX)
FEX_EARLY_LOG_DISABLE=1
FEX_JIT_BlockLinking=0
FEX_GDBServer=0
```

- `FEX_EARLY_LOG_DISABLE=1` — reduce la frecuencia del bug de CEF/FEX que rompe
  la UI de Steam (steamwebhelper).
- `FEX_JIT_BlockLinking=0` — estabilidad del JIT.
- `FEX_GDBServer=0` — menos overhead.

Aplican al **reiniciar la sesión de juego** (Steam/gamescope). Complementa al
watchdog de la UI (`config/steamui-watchdog/`).
