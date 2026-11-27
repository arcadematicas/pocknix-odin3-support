# Ola del BSP: `pocknix-bsp-common` 30 → 41 (plan de merge)

**Estado:** análisis hecho, sin ejecutar. Es la pieza que bloquea `pocknix-snapshots 10`,
`pocknix-lock-migrate 6` y `pocknix-tools` moderno (QML). Toca arranque, así que requiere sesión
con la consola delante y varios reinicios.

## Tamaño real
`git diff origin/main -- packages/shared/pocknix-bsp-common`: **61 ficheros, +594 / −1859**.
No es un bump: upstream reorganizó y añadió su propia capa de arranque, y nosotros tenemos
parches propios que no existen allí.

## Ficheros SOLO nuestros (hay que conservarlos)
| Fichero | Qué es |
|---|---|
| `pocknix-scx-mode`, `pocknix-scx-diag` | selector de scheduler scx (lavd/bpfland/rusty) + diagnóstico |
| `60-pocknix-io-scheduler.rules` | scheduler de I/O por dispositivo (bfq en microSD) |
| `display-sleep-post` | apagado de pantalla en suspend |
| `inputplumber-sleep-pre/post` | InputPlumber en suspend (mando) |

## Ficheros SOLO de upstream (evaluar uno a uno)
| Fichero | Nota |
|---|---|
| `pocknix-bls-deploy`, `pocknix-boot-deploy`, `91-pocknix-cmdline.hook` | **su** capa de arranque BLS/KERNEL; choca con nuestra versión de `pocknix-bls-deploy` |
| `00-pocknix-abl-gate.hook`, `pocknix-abl-gate` | gate de ABL (con OpenABL ya no bloquea) |
| `pocknix-repo-line` + hook, `96-...` | reescribe `pacman.conf` (riesgo alto) |
| `cores.sh` | `pocknix_prime_core` (lo pide `pocknix-steam` de upstream) |
| `org.pocknix.Perf.{conf,service}`, `pocknix-backlight-grant` | polkit: rendimiento y brillo |
| `lid-powerkey-sleep-{pre,post}` | suspensión por tapa/power |
| `10-journal-size`, `20-wifi-backend`, `60-deck.conf`, `60-latency.conf`, `60-sdl-xb360.conf`, `50-second-screen.rules`, `90-linux-pocknix.hook` | ajustes varios |

## Modificados en ambos (merge manual)
`PKGBUILD`, `pocknix-bsp-common.install`, `pocknix-fan-mode`, `pocknix-fancontrol(.service)`,
`pocknix-game-mode.conf`, `pocknix-gamepad-target(.service)`, `pocknix-gpt-abl`, `pocknix-lavd-mode`,
`pocknix-refresh-abl-kit`, `pocknix-second-screen.service`, `pocknix-update-abl`,
`20-pocknix-powerkey.conf`, `60-pocknix-controllers.rules`, `90-pocknix-backlight.rules`.

## Estrategia propuesta
1. Partir del `PKGBUILD` y los ficheros de upstream 41 en una **rama aparte** de `pocknix-os`.
2. Reaplicar, sin tocar su lógica nueva: `pocknix-scx-mode`, `pocknix-scx-diag`, reglas de I/O,
   hooks de suspend de InputPlumber y pantalla, y el tuning de ventilador.
3. **Decidir qué capa de arranque manda** (nuestra `pocknix-bls-deploy` + `update-abl` con OpenABL
   frente a la de upstream). No pueden convivir dos escritores de BLS/`/flash`.
4. Revisar el gate de ABL y `repo-line` antes de instalarlo (con OpenABL el gate sobra; `repo-line`
   reescribe `pacman.conf` y es el punto más delicado).
5. Probar en hardware, en este orden: arranque → audio (altavoz/auriculares) → suspend/resume →
   ventilador/perfil → mando → ABL/menú. Rollback: snapshot btrfs + `KERNEL.bak` + entrada
   «previous kernel» del menú.

## Por qué no se hace hoy
`pocknix-steam` de upstream depende de `bsp-common>=36` (núcleo prime) y `tools`/`snapshots` de 37+.
Todo cuelga del mismo cambio, y es la única pieza del plan que puede dejar la consola sin arrancar.

---

## Estado al 26/11/2026 (verificado contra `origin/main` @ `49870a95`)

`git diff --stat origin/main -- packages/shared/pocknix-bsp-common`: **64 ficheros,
+627 / −1829**.

### Clasificación real del diff (`git diff --name-status origin/main`)

**Solo upstream (D en el diff) — por riesgo:**

| Grupo | Ficheros |
|---|---|
| 🔴 Capa de arranque | `pocknix-boot-deploy`, `pocknix-build-bootimg`, `pocknix-cmdline-sync`, `90-linux-pocknix.hook`, `91-pocknix-cmdline.hook` |
| 🔴 Reescribe pacman | `pocknix-repo-line`, `pocknix-repo-line.service`, `96-pocknix-repo-line.hook` |
| 🟠 Gate ABL | `pocknix-abl-gate`, `00-pocknix-abl-gate.hook` |
| 🟠 Rendimiento (sustituido por nuestro scx) | `pocknix-perf`, `pocknix-perfd(.service)`, `pocknix_perf.py`, `org.pocknix.Perf.conf/.service`, `power-profiles.conf`, `rtkit-limits.conf` |
| 🟡 Audio DSP de altavoz | `pocknix-speaker-dsp(.service)`, `pocknix-speaker-dsp-render` (nosotros usamos el EQ del plugin) |
| 🟡 Varios | `10-pocknix-journal-size.conf`, `20-pocknix-wifi-backend.conf`, `50-pocknix-second-screen.rules`, `60-pocknix-deck.conf`, `60-pocknix-latency.conf`, `60-pocknix-sdl-xb360.conf` + `pocknix-sdl-xb360.sh`, `lid-powerkey-sleep-{pre,post}`, `pocknix-backlight-grant`, `52-pocknix-fan-mode.rules`, `abl-kit.sh`, `cores.sh`, `zram-generator.conf`, `README.provenance` |

**Solo nuestros (A)**: `pocknix-scx-mode`, `pocknix-scx-diag`, `pocknix-scx.service`
(renombre de `pocknix-lavd.service`), `60-pocknix-io-scheduler.rules`, `91-pocknix-bls.hook`,
`display-sleep-post`, `inputplumber-sleep-{pre,post}`.

**Modificados en ambos (M)**: `PKGBUILD`, `pocknix-bsp-common.install`, `pocknix-bls-deploy`,
`pocknix-fancontrol(.service)`, `pocknix-fan-mode`, `pocknix-game-mode.conf`,
`pocknix-gamepad-target(.service)`, `pocknix-gpt-abl`, `pocknix-lavd-mode`,
`pocknix-refresh-abl-kit`, `pocknix-second-screen.service`, `pocknix-update-abl`,
`20-pocknix-powerkey.conf`, `60-pocknix-controllers.rules`, `90-pocknix-backlight.rules`.

### 🔴 Hallazgo nuevo: `[pocknix-base]` tapa a `[pocknix-shared]`

`pacman -S pocknix-tools` **reinstala la 28** aunque shared tenga la 30: el snapshot
`pocknix-base` fija esa versión y gana en la resolución. Consecuencia: **todo paquete nuestro
que también viva en `base` está clavado** hasta recortar snapshot nuevo (o cambiar la prioridad
de repos en `pacman.conf`). Afecta a `pocknix-bsp-common`, `pocknix-tools`, `pocknix-decky`… no a
los “suelos” (`deckstation-arm`, `libretro-hakux`). Es parte de la ola, no un caso aparte.

### Orden propuesto (actualizado)

- **Lote 1 (hecho)**: paquetes sueltos publicados (hakux 0.38→0.39 directo, deckstation 29,
  tools 30) — sirve para validar la publicación sin tocar el arranque.
- **Lote 2 (inocuo, sin arranque)**: `10-journal-size`, `20-wifi-backend`, `60-latency`,
  `60-sdl-xb360` (+script), `60-deck.conf`, `50-second-screen.rules` (+servicio),
  `rtkit-limits`, `zram-generator`, `backlight-grant`. Revisar uno a uno y **no** tocar
  `cores.sh` (lo pide `pocknix-steam` de upstream: decidir antes).
- **Lote 3 (decisión)**: capa de arranque. Un solo escritor de BLS/`/flash`. Nuestra
  `pocknix-bls-deploy` + `91-pocknix-bls.hook` + `update-abl` (OpenABL ya probado) contra la de
  upstream. `repo-line` **no** se instala.
- **Lote 4**: snapshot `base` nuevo (o prioridad de repos) para que las versiones de shared
  lleguen de verdad a los dispositivos.
- **Lote 5**: probar en hardware (arranque → audio → suspend → dock) y publicar.

---

## Estado al 27/11/2026 (tras el trabajo de la mañana)

- **Lote 1**: cerrado (publicaciones).
- **Lote 2**: **cerrado**. Comprobado en la consola que ya estaban cubiertos: journal 64M
  (`/usr/lib/systemd/journald.conf.d/10-pocknix-flash.conf`), wifi iwd, zram 10,7G, sysctls
  gaming (`60-pocknix-gaming.conf`), límites `nice -20`, `pocknix-second-screen.service`.
  Añadidos de upstream y publicados en **`pocknix-bsp-common 31`**: `rtkit-limits.conf`
  (drop-in de rtkit: RR 81/80) y las reglas polkit `52-pocknix-fan-mode.rules` y
  `50-pocknix-second-screen.rules`.
- **Lote 3 (capa de arranque)**: **decisión tomada: se queda la nuestra**. No se instala
  `pocknix-boot-deploy`, `pocknix-build-bootimg`, `pocknix-cmdline-sync`, los hooks 90/91,
  `repo-line`, `abl-gate`, `pocknix-perf`/`rt-ladder` (sustituidos por scx), `speaker-dsp`
  (usamos el EQ del panel), `cores.sh` (nuestro `pocknix-steam` no lo pide) ni
  `lid-powerkey-sleep-*` (tenemos nuestros hooks). Queda **verificar en hardware** que todo
  sigue bien tras kernel 8 + bsp-common 31 (arranque, audio, suspensión, mando).
- **Lote 4 (snapshot/prioridad)**: **no bloquea**. `pocknix-tools` está en 30 y `pacman -Sl`
  sirve shared 30/31/75; el `28` que aparecía en `pacman -Sp` era un artefacto de caché local.
- **Lote 5**: pruebas de hardware, esta noche.
