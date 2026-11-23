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
