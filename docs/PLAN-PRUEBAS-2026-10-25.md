# Plan de pruebas — pendientes al 25/10/2026

Todo lo que hay que medir/probar, **en el orden que menos tiempo cuesta y más desbloquea**.
Cada prueba dice qué decide, qué se necesita y cuándo se da por buena.

Contexto: Davidusky confirmó (25/10) que su fallo tras s2idle es **GPU/GMU**
(`a6xx_gmu_resume: GMU firmware initialization timed out` → `GMU OOB` → `preemption timed out` →
`Timeout waiting for GPU to suspend` / `PM: failed to suspend: -16`), **sin errores de SD/I-O**.
Nuestro caso (Zelda lento tras suspender, sin cuelgue ni errores) puede ser **el mismo fallo en
versión suave**: una GMU que vuelve a medias deja la GPU sin preemption y con el reloj mal.

---

## 1. Zelda al TDP mínimo: before/after de suspensión  ⏱️ 5 min · sin PC

**Decide**: si nuestra lentitud es GMU (mismo bug) o restauración de estado (userspace).

```bash
# en un arranque LIMPIO (el "va casi a 60")
~/diag-post-resume.sh before
# suspender desde el QAM/energía, esperar ~1 min, despertar
~/diag-post-resume.sh after
# (solo si no sale nada raro) jugar 3-5 min:
~/diag-post-resume.sh after-play
```

| Resultado en la foto `after` | Lectura | Siguiente paso |
|---|---|---|
| `a6xx_gmu_resume … timed out` / `preemption timed out` / `Timeout waiting for GPU to suspend` | **Mismo bug que Davidusky**, en versión sin cuelgue | Rails LPM de `0521`–`0526` y orden `gx`→`cx` en **resume** (kernel) |
| Sin esa firma, pero GPU en `min_freq` o `scx`/perfil distintos | No es GMU: es restaurar estado | Arreglo en userspace (reaplicar perfil/scx tras resume) |
| Sin firma y todo igual | Límite térmico/energético | Comparar `trans_stat` con `after-play` |

**Riesgo**: si es la GMU, puede quedarse colgada → reinicio. Hacerlo cuando se pueda permitir.
**Requisito**: `diag-post-resume.sh` en la consola (está en `tools/`; copiar a `/home/deck`).
Detalle de hipótesis: [`PRUEBA-ZELDA-TDP-SUSPEND-20261024.md`](PRUEBA-ZELDA-TDP-SUSPEND-20261024.md).

---

## 2. Confirmar el OSD de MangoHUD  ⏱️ 2 min · al reiniciar sesión

**Decide**: si `gamescope-session 20260928-4` (ya instalado) deja **un solo** `mangoapp`.

```bash
pgrep -c -x mangoapp     # debe devolver 1 (antes 2)
```

Y en juego: HUD estable, F13 lo alterna, QAM por encima.
Si sigue en 2 → revisar que la sesión se reinició **después** de instalar la `-4`.

Detalle: [`INCIDENTE-2026-10-24-GPU-HANG-Y-MANGOAPP.md`](INCIDENTE-2026-10-24-GPU-HANG-Y-MANGOAPP.md).

---

## 3. Port del micrófono (armada lo resolvió el 21/10)  ⏱️ build de kernel · necesita PC

**Decide**: si el Odin 3 deja de tener el micrófono muerto (issue #766, sin respuesta de armada
pero **ya resuelto en su repo**).

Qué portar de `armada-os/armada` (commits `c1cda0a` + `898d40d`):
- `0080-ASoC-codecs-lpass-tx-macro-track-every-active-decimator.patch` (**el grafo de captura**)
- `0081-ASoC-wcd939x-fix-headphone-analog-volume-controls.patch` (versión original de Diogo)
- `0073-ASoC-wcd939x-add-HPH-PCM-HiFi-mode.patch` (actualizado)
- DTS `cq8725s-ayn-odin3` (nodos de micrófono) — comparar con nuestro DTS
- **UCM**: `HiFi.conf` (+96/−12) y `AYN-Odin3.conf` (−13) — **ojo**: nuestro `HiFi.conf` lleva
  nuestro split `Speaker`/`Headphones` y el compander; hay que **fusionar**, no copiar.

**Criterio**: `arecord -l` muestra captura y una grabación de 5 s suena (y no rompe auriculares).

---

## 4. Actualización pendiente de la consola  ⏱️ 15 min · reinicio después

7 paquetes, incluido el refactor de escritorio (`pocknix-desktop -26 → -32`, `pocknix-core`,
`pocknix-system-overlay -6`, `msm-firmware-loader -3`). Es la **misma migración que validó Davidusky**.

```bash
pacman -Syu --print      # mirar antes: entra Plasma Mobile + apps KDE + Waydroid
# luego, con la lista de --overwrite acotada del doc de actualización
```

Detalle y lista exacta: [`ACTUALIZAR-ODIN-DAVIDUSKY-2026-10-23.md`](ACTUALIZAR-ODIN-DAVIDUSKY-2026-10-23.md).

---

## 5. Tailscale  ⏱️ 5 min · requiere abrir una URL

Sin él no hay acceso remoto cuando la consola sale de casa. Receta: [`TAILSCALE.md`](TAILSCALE.md).

---

## 6. GPU hang al cambiar a escritorio (solo con cuidado)  ⏱️ riesgo de reinicio

`a8xx_recover: cx gdsc didn't collapse` + `GMU OOB`. Solo se recupera reiniciando.
Recomendación **actual**: no cambiar a escritorio salvo que se necesite; si se reproduce, guardar
`dmesg` antes de reiniciar (el log del 24/10 está en `docs/incidentes/`).

Detalle: [`INCIDENTE-2026-10-24-GPU-HANG-Y-MANGOAPP.md`](INCIDENTE-2026-10-24-GPU-HANG-Y-MANGOAPP.md).

---

## Orden recomendado

1. **Prueba 2** (2 min, la primera vez que reinicies sesión) → confirma el arreglo del OSD.
2. **Prueba 1** (5 min) → decide si vamos por GMU o por userspace.
3. **Prueba 3** (build) → valor propio, independiente de la 1.
4. **Prueba 4** (actualización) → cuando haya hueco y con reinicio previsto.
5. **Prueba 5** (Tailscale) → cuando se quiera acceso desde fuera.

> Regla: **una cosa por build**. Si el port del micro y un cambio de GMU van en el mismo kernel y
> algo falla, no sabremos cuál fue.
---

## 7. Kernel de prueba GMU para Jarvis (esta semana)

Está en el backlog (`docs/UPSTREAM-BACKLOG.md`): kernel con `0620`+`0622` de armada. **Él reproduce,
nosotros no**; él no puede probar hasta el fin de semana del 31/10, así que se deja compilado y
publicado antes. Una cosa por build: no mezclar con el port del micrófono (ya hecho, sin kernel).
---

## 8. Audio por HDMI/DP — probar con dock  ⏱️ 5 min · **bloqueada: no hay dock**

**Estado**: hoy **no hay** audio por HDMI (medido: la tarjeta solo expone PCM 0/1/2, no existe
`DP0 Jack`). La causa: nuestra tplg no trae el backend de DisplayPort.

**Sospechoso con solución**: la tplg de armada **sí** trae `MultiMedia4 Playback` +
`DISPLAY_PORT_RX_0`, y el kernel ya soporta audio DP (`dp_audio.c`, `CONFIG_DRM_MSM_DP=y`).

**Prueba (cuando haya dock con HDMI)**:
1. Enchufar el dock con HDMI a un monitor/TV.
2. Backup de `/usr/lib/firmware/qcom/sm8750/SM8750-AYN-tplg.bin` y copiar la de armada
   (`system_files/usr/lib/firmware/qcom/sm8750/`, 24.516 B). Reiniciar.
3. `aplay -l` → debe aparecer `device 3: MultiMedia4 Playback`.
4. `speaker-test -D hw:0,3 -c 2 -t sine` → ¿suena por el HDMI?
5. **Verificar que no se rompió nada**: altavoz (`hw:0,0`), auriculares (`hw:0,1`) y micro
   (`hw:0,2`) siguen bien. Si algo falla → restaurar el backup de la tplg y reiniciar.
6. Si funciona: añadir `SectionDevice."HDMI"` al `HiFi.conf` (bloque listo en
   `docs/AUDIO-HDMI-20261025.md`) y decidir cómo distribuir la tplg (binario de armada).

**Vigilancia**: `tools/check-hdmi-audio.sh` (en el chequeo diario) avisa si la tplg de armada
cambia o si ROCKNIX publica parches de audio DP.
