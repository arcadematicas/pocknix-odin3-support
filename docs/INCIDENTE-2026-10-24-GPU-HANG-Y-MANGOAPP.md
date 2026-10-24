# Incidente 24/10/2026 — GPU hang al cambiar a escritorio + el OSD duplicado

## 1. El cuelgue: GPU hang, no la sesión

Al pulsar **"cambiar a escritorio"** desde el QAM, la consola se quedó *pillada* (imagen congelada)
pero el sistema seguía vivo (SSH respondía, load 11-13). Plasma **sí** llegó a arrancar
(`kwin_wayland` + `plasmashell --no-respawn`, estado `pocknix-session` = `plasma`).

El kernel dijo:

```
msm_dpu ae01000.display-controller: [drm:recover_worker] *ERROR* 44050000: offending task: plasma-k:gdrv0
adreno 3d00000.gpu: [drm:a8xx_recover] *ERROR* cx gdsc didn't collapse
platform 3d37000.gmu: [drm:a6xx_gmu_set_oob] *ERROR* Timeout waiting for GMU OOB set GPU_SET: 0x0
```

Es decir: **fallo de GPU durante la transición gamescope → Plasma**, y la **recuperación de la GPU
también falló** (el GDSC de CX no colapsa y la GMU deja de responder). Sin GPU no hay composición:
pantalla congelada con el CPU girando. Solo se arregla **reiniciando** (el reset del driver no basta).

- Evidencia completa: `docs/incidentes/gpu-hang-cambio-escritorio-20261024.log`.
- Tras reiniciar: **0 errores de GPU** en el arranque.
- Relacionado con nuestros parches de adreno (`0001`/`0051`, *gx collapse before cx*) y con
  `a8xx_recover`. **Pendiente**: reproducir con `plasma` desde un arranque limpio (sin gamescope
  antes) para saber si es la transición o Plasma en sí, y mirar si armada/ROCKNIX tienen
  parches nuevos de `a8xx_recover`/`gmu`.

### Trampa de diagnóstico
`pgrep -x gamescope` devuelve **0** aunque gamescope esté corriendo: el proceso se llama
**`gamescope-wl`**. Casi saco conclusiones falsas de ahí.

## 2. El OSD de MangoHUD que "mide a ratos y se para"

Síntoma con Wind Waker HD (port nativo aarch64): el HUD mide bien, luego se desincroniza y se queda
congelado. **Causa: dos `mangoapp` dibujando el mismo overlay.**

- `sessions.d/steam` pasa **`--mangoapp`** a gamescope → `gamescopereaper --respawn -- mangoapp`
  arranca uno.
- Y `gamescope-session-plus` (upstream) arranca **otro** con `(while true; do mangoapp; done) &`.

Dos clientes del overlay = dos muestreos independientes del mismo juego → cifras que bailan y OSD
que se queda clavado. El daemon del paddle no tenía culpa: ya manda `SIGHUP` a **todos** los
mangoapp (verificado).

### Arreglo (publicado e instalado)
`gamescope-session` **20260928-4**: `package()` borra el bucle de upstream
(`sed '/^# If we have mangoapp binary start it$/,/^fi$/d'`). Una sola vía: la de gamescope.
Surte efecto **al reiniciar la sesión**.

### 🔴 La trampa gorda (nos costó tres intentos)
El `PKGBUILD` **compila del tarball de GitHub** (`cp -a "${src}/usr"`). El fichero vendorizado en
`packages/gamescope-session/usr/...` **NO entra en el paquete**: tenerlo arreglado en el repo no
cambia nada. Hay que **parchear en `package()`** (como ya se hacía con el `set -x`).
Publicamos `-3` sin efecto por esto; `-4` es el bueno (verificado en el paquete: 0 bucles, 394
líneas, `+x`).

## 3. Cambios revertidos
`pocknix-steam` **no** es la sesión de hoy (esa es `gamescope-session-plus` +
`pocknix-steam-client`). El primer intento quitó `--mangoapp` de ahí: se revirtió
(centro `9cd58cc`, árbol `pocknix-steam 0.1.0-72`).
