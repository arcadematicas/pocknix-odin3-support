# TDP tras el resume: dos gestores y cómo se coordinan (5/11/2026)

## Síntoma
Al despertar de la suspensión, el TDP elegido en el Panel de Control parece desaparecer
(más temperatura y ventilador) hasta que se vuelve a aplicar desde el panel.

## Causa
- El Panel de Control gestiona el TDP por niveles (1-10) y escribe `scaling_max_freq` de cada
  policy de CPU y el `max_freq` del devfreq de la GPU (`py_modules/tdp/arm_levels.py`).
- Al resumir, el hook `zz-power-profile` lanza `pocknix-power-profile verify`, que aplica el
  perfil guardado del sistema (`/var/lib/pocknix/power-profile`, p.ej. `medio`) y **pisa** el
  nivel del panel. El panel re-aplica el suyo al despertar, pero el hook corre unos segundos
  despues y gana.

## Solución
- `zz-power-profile` fase **pre**: si el Panel gestiona el TDP (`tdp_control_enabled` en
  `homebrew/settings/Panel de Control/state.json`), guarda los topes reales en
  `/run/pocknix/tdp-caps`.
- El hook `post` arranca `pocknix-power-profile-late.service` (`verify`) y
  `pocknix-power-profile-reassert.service` en la misma transacción; esta última restaura los
  topes del panel con reintentos y borra el snapshot.
- `After=pocknix-power-profile-late.service` hace que el reassert corra cuando `verify`
  termina, aunque `verify` falle.
- `ConditionPathExists=/run/pocknix/tdp-caps` evita que un snapshot viejo se aplique en un
  trigger de udev; el arranque normal no toca nada.
- Si el panel no está o su control está desactivado no se guarda snapshot y todo funciona
  como antes (el perfil del sistema manda).

## Prueba
1. Con el panel gestionando el TDP, anotar los topes (`cpu0`, `cpu6`, `GPU max_freq`).
2. Suspender y despertar.
3. Comprobar que los topes vuelven a los del panel (no a `medio`) y que el snapshot
   `/run/pocknix/tdp-caps` ha desaparecido.

## Reversión
Quitar el arranque de `pocknix-power-profile-reassert.service` del hook (o vaciar el snapshot)
devuelve el comportamiento anterior.
