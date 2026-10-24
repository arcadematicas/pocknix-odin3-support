# Prueba pendiente — Zelda WWHD al TDP mínimo se arrastra tras volver de la suspensión

**Anotado el 24/10/2026 (Fransis). Estado: pendiente de medir.**

## Lo observado

- Juego: **The Legend of Zelda: The Wind Waker HD** (port nativo aarch64, `/opt/wproton/games/...`).
- Perfil de potencia: **TDP al mínimo**.
- **Consola recién reiniciada** → va **casi a 60 fps** (sensación clara, sostenida).
- **Al volver de la suspensión (s2idle)** → "le cuesta moverse": mismo juego, mismo perfil, notablemente peor.

No es un cuelgue ni errores de pantalla: es **rendimiento**. El panel vuelve bien.

## Esto NO es ninguno de los dos incidentes del 24/10

| Incidente | Firma | ¿Aplica? |
|---|---|---|
| **GPU hang al cambiar a escritorio** (`docs/INCIDENTE-2026-10-24-GPU-HANG-Y-MANGOAPP.md`) | `a8xx_recover: cx gdsc didn't collapse` + `GMU OOB timeout`; pantalla congelada | **No** — aquí no se cuelga nada |
| **Panel DSI tras s2idle** (Davidusky, `docs/INCIDENTE-2026-10-24-SUSPEND-PANEL-DSI-ODIN3.md`) | `panel-chipone-icna35xx: failed to initialize panel: -110`, `wait for commit done -22/-110` | **No** — a Fransis le vuelve el panel |
| **Este** | Sin errores en el log; solo **menos rendimiento** | ✅ |

Y por lo que sabemos hoy: `0048a` y el `0048b` (nuestro `1032`, byte a byte igual) **ya están** en el kernel
desde `ff61120` — o sea, la hipótesis "faltan parches DSI" está descartada también para la lentitud.

## Hipótesis, en orden de probabilidad

> **ACTUALIZACIÓN 25/10** — Davidusky encontró la firma en su Odin tras s2idle: `a6xx_gmu_resume:
> GMU firmware initialization timed out` → `GMU OOB` → `44050000: preemption timed out` →
> `Timeout waiting for GPU to suspend` / `PM: failed to suspend: error -16`. Es la **misma
> familia** que su cuelgue, y **explica la lentitud sin cuelgue**: una GMU que resucita a medias
> deja la GPU sin preemption y con el reloj mal, que es exactamente "va, pero arrastrándose".
> Su caso NO tenía errores de SD/I-O (la hipótesis del I/O queda descartada) y los `-110` del
> panel eran **secundarios**. Por eso la hipótesis 1 pasa a ser esta, y el test del hook DSI deja
> de ser prioritario.


1. **(PRINCIPAL) Fallo de resume de la GPU/GMU.** `a6xx_gmu_resume` con timeout deja la GPU
   sin preemption/reloj. Los rails en LPM de nuestros parches s2idle son el primer sitio donde mirar. Nuestros parches de s2idle (`0521`–`0526`)
   ponen rails del códec y PCIe en modo **LPM** al suspender. Si alguno **no vuelve** a high-performance
   al despertar, el SoC va con menos ancho de banda: encaja con "funciona pero arrastrándose".
   → Mirar `dmesg` del resume y el estado de los reguladores; comparar `trans_stat` de la GPU.
2. **GPU stuck en la frecuencia mínima** (o el governor no vuelve). `cur_freq` clavado en `min_freq`
   mientras se juega = confirmado.
3. **sched_ext (`scx_lavd`) caído o en modo conservador.** `pocknix-scx.service` hace polling, pero si
   tras el resume el estado es `bpfland powersave` o el scheduler no está cargado, el juego pierde
   fluidez con el mismo TDP.
4. **Perfil de potencia no reaplicado** (el "bajo"/TDP mínimo se restaura a medias; el per-game
   `/run/pocknix/game-mode` perdido).
5. **Térmicas/ventilador**: tras el resume el ventilador no arranca y el SoC se queda estrangulado.
6. **Memoria**: zram lleno tras horas de sesión (no debería con el port nativo, pero se mira).

## Cómo medirlo (5 minutos, sin pruebas artificiales)

El script `tools/diag-post-resume.sh` saca una foto del estado **sin tocar nada**:

```bash
# con la consola recién arrancada (o antes de suspender)
~/diag-post-resume.sh before

# jugar un rato, suspender, despertar, volver al juego 2-3 minutos
~/diag-post-resume.sh after

# comparar
~/diag-post-resume.sh show
```

Qué mira la foto: frecuencia/governor de GPU y CPU, `trans_stat`, scheduler sched_ext y su modo,
perfil de potencia, `game-mode`, térmicas y ventilador, estado del conector/modos del panel, memoria y
zram, y **los errores de DSI/GPU del boot** (para descartar que sea un `-110` silencioso).

## Criterio para dar esto por arreglado

1. Mismo tramo del juego: **misma sensación de fluidez** antes y después de suspender.
2. `cur_freq` de la GPU y `trans_stat` **comparables** (no clavado en `min_freq`).
3. `sched_ext` y perfil de potencia **idénticos** en las dos fotos.

Si falla el punto 1 con 2 y 3 iguales, el siguiente sospechoso es el **panel/modo tras el resume**
(60 Hz vs 120, o un modo distinto) — se mira en la sección `panel / DRM` de la foto.

## Relacionado

- Nuestro hook de resume `sleep.d/post/004-display` (fuerza `status=on` + brillo). Es un **modo-set**:
  sirve para el panel negro de antes, pero es candidato del `-110` de Davidusky. No tocarlo aquí sin
  medir: en esta prueba el panel vuelve bien.
