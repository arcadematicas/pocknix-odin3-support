# El actualizador del QAM se quedaba atascado para siempre (2026-10-05)

**Estado:** fase 1 PUBLICADA y verificada. Fase 2 pendiente de que Fransis pulse el botón
una vez y reinicie. Nada de esto se ha publicado en `shuuri-labs/pocknix-os`.

---

## 1. El síntoma

El botón de actualizar de PocknixControl (QAM) terminaba siempre en error, y el log
(`/run/pocknix-update.log`) repetía lo mismo:

```
error: could not perform operation (conflicting files)
plutovg: /usr/include/plutovg/plutovg.h exists in filesystem
plutosvg: /usr/include/plutosvg/plutosvg.h exists in filesystem
pocknix-soname-compat: /usr/lib/libFLAC.so.8 exists in filesystem
pocknix-soname-compat: /usr/lib/libpcap.so.0.8 exists in filesystem
pocknix-vk-valve: /usr/lib/libdisplay-info.so.1 exists in filesystem
pocknix-vk-valve: /usr/share/pocknix/vk-arm/26.3.0-valve/... exists in filesystem
==> ERROR: failed to prepare transaction (conflicting files)
```

Un `-Syu` abortado por conflictos **no deja nada a medias** (pacman descarta la
transacción entera), así que el equipo no se rompe. Pero la actualización no puede
aterrizar nunca, y quien no tenga terminal se queda atascado para siempre. La entrada de
Plasma "Pocknix Updater" (`exec pacman -Syu`) tenía exactamente el mismo problema.

## 2. Causa raíz: no es el build de la imagen

Lo primero que se sospechó fue `build-image.sh`. **Es inocente.** Todo lo que instala
`install_local_packages()` (scripts/build-image.sh:82) pasa por pacman; lo único que ese
script escribe por su cuenta son el firmware, `/usr/share/inputplumber/`, la pubkey del
repo y la semilla de Steam — nada de esto.

Los ficheros sin dueño los escribió pocknix **a mano en la rootfs de un equipo ya
vendido**, y a las rutas de las que procedían se les dio un paquete días después:

| Fecha | Qué se escribió a mano | Paquete que acabó siendo su dueño |
|---|---|---|
| 2026-09-26 21:53 | `tools/install-deckard-mesa.sh`: payload de Valve Turnip en `/usr/share/pocknix/vk-arm/26.3.0-valve/` + symlink `libdisplay-info.so.1`, con `install -D` (fuera de pacman) | `pocknix-vk-valve` (2026-09-27, commit `b88eb6e`) |
| 2026-09-30 22:27 | `plutovg`/`plutosvg`: headers + `.so` (755) + cmake + pkgconfig, y `libpcap.so.0.8` (firma de extracción de tarball) | `plutovg`, `plutosvg` |
| 2026-10-01 00:08 | `libFLAC.so.8` (FLAC 1.3.4 compilado; el del sistema es 1.5.0 con otra ABI) | `pocknix-soname-compat` (2026-10-01) |

Los motivos están en el propio `sync-to-os.sh`: hacen falta para
que los cores libretro **precompilados** de ArkOS (ARMSX2, uae4arm) carguen, y esos cores
se compilaron en Debian.

**Pruebas:**

- `/var/log/pacman.log` no tiene **ninguna** entrada para esos paquetes ni para esos
  nombres: nunca pasaron por pacman.
- `pacman -Qo` responde "No package owns" para las nueve rutas.
- Las mtimes de los ficheros (2026-09-26 21:53, 2026-09-30 22:27, 2026-10-01 00:08) son las
  de cuando se escribieron, no de un paquete.

Es decir: pocknix fabricó sus propios huérfanos. **Por eso el arreglo es seguro** (ver §4).

## 3. Qué se ha tocado

| Fichero | Dónde | Cambio | pkgrel |
|---|---|---|---|
| `packages/shared/pocknix-base/pocknix-update` | árbol `pocknix-os` | el motor: `--overwrite` acotado + autorreparación | — |
| `packages/shared/pocknix-base/PKGBUILD` | árbol `pocknix-os` | comentario del bump | **5 → 6** |
| `packages/pocknix-decky/pocknix-control/py_modules/pocknix_control/updates.py` | centro | el QAM llama a `pocknix-update`; stderr al log | — |
| `packages/pocknix-decky/PKGBUILD` | centro | comentario del bump | **47 → 48** |
| `tools/install-deckard-mesa.sh` | centro | deja de fabricar huérfanos | — |
| `scripts/stage-check.sh` | árbol `pocknix-os` | `POCKNIX_STAGE_CHECK_TEMP_DROP`, `POCKNIX_STAGE_CHECK_SOCS` | — |

Commits: `pocknix-os` `b7a5516` (rama `odin3-sm8750` de nuestro fork), centro `f28ecdb`
(`master`). Pushados **solo a `arcadematicas/*`**. `shuuri-labs/pocknix-os` intacto.

`pocknix-decky` es del centro y se copia al árbol con `tools/sync-to-os.sh`; `pocknix-base`
solo vive en el árbol. El diff completo está en los dos commits.

## 4. La política de `--overwrite`, y por qué es robusta

**No es `--overwrite '*'`.** Son dos capas, la más estrecha primero:

**Capa 1 — lista cerrada (12 líneas).** `--overwrite` acotado a las rutas que poseen
exactamente `plutovg`, `plutosvg`, `pocknix-soname-compat` y `pocknix-vk-valve`:

```
/usr/include/plutovg/*        /usr/lib/libplutovg.so*
/usr/include/plutosvg/*       /usr/lib/libplutosvg.so*
/usr/lib/cmake/plutovg/*      /usr/lib/libFLAC.so.8*
/usr/lib/cmake/plutosvg/*     /usr/lib/libpcap.so.0.8*
/usr/lib/pkgconfig/plutovg.pc /usr/lib/libdisplay-info.so.1*
/usr/lib/pkgconfig/plutosvg.pc /usr/share/pocknix/vk-arm/*
```

Al ser una lista **cerrada**, nunca puede autorizar que un paquete le robe un fichero a
otro paquete ya instalado: eso sería un fallo de empaquetado real, no algo que haya que
tapar. En la práctica esta capa basta sola, así que el caso normal no le enseña ni una
actualización fallida al usuario.

**Capa 2 — autorreparación.** Si pacman aun así informa de conflictos, se reintenta **una
vez** con `--overwrite` reducido a *exactamente* las rutas que nombra pacman, y solo a las
que `pacman -Qo` responde "no package owns". Esto es lo que mantiene el arreglo funcionando
con el próximo huérfano que nadie haya visto todavía, y **no necesita que se edite nada
aquí**: lee la salida del propio pacman (expresión `^[A-Za-z0-9@._+-]+: /[^ ]*`, que no
depende del idioma: el nombre de un paquete no puede llevar `:` ni empezar por `/`, y la
prosa traducida se descarta).

**El límite importante:** una ruta que **sí** pertenece a un paquete instalado nunca se
pisa. El reintento se aborta con un mensaje explícito que dice que es un conflicto de
empaquetado real y que hay que reportarlo. Probado: con una ruta que sí es de otro paquete,
no hay reintento y se devuelve el código original.

## 5. Lo que se ha publicado (fase 1) y cómo se ha verificado

Publicado a `r2:pocknix/shared` (= `https://pub-fd47305874674bf597b27eb7f880e73b.r2.dev/shared`),
**sin sudo**, desde el espejo de staging, nunca con `POCKNIX_PUBLISH_FROM=localrepo`:

- **Añadidos:** `pocknix-base 0.2.0-6`, `pocknix-decky 0.1.0-48` (y fuera `-5` y `-47`).
- **Retirados temporalmente:** `plutovg`, `plutosvg`, `pocknix-soname-compat`,
  `pocknix-vk-valve`, `pocknix-steam-full`, `libretro-cores-pocknix`.
  Los dos últimos también, porque arrastran a los otros cuatro como `depends`: si se
  quedan, suscandidate versiones dependerían de paquetes que ya no están y pacman abortaría
  la transacción por dependencia insatisfecha — el mismo fallo con otro mensaje.
- `r2:pocknix/sm8750` **intacto** (11 paquetes).

**Verificación real (no "publish OK"):**

1. HTTP público: `pocknix-shared.db` 200, `pocknix-base-0.2.0-6` 200 (14052 B),
   `pocknix-decky-0.1.0-48` 200 (27277932 B), `pocknix-repo.gpg` 200;
   `plutovg-1.3.3-1` y `libretro-cores-pocknix-0.1.0-7` → **404**.
2. El `.db` que sirve el CDN contiene `pocknix-base-0.2.0-6` y `pocknix-decky-0.1.0-48`, y
   ningún nombre retirado.
3. Resolviendo contra lo que la Odin tiene instalado (db desechable en `/tmp`,
   `--logfile /dev/null`, **nada instalado**):

   ```
   $ pacman -Sup --dbpath /tmp/... --print-format '%n %v'
   f2fs-tools 1.17.0-1
   pocknix-base 0.2.0-6
   pocknix-decky 0.1.0-48
   ```

   Idéntico con y sin el `--overwrite` acotado (ya no hay nada que entre en conflicto).
   `f2fs-tools` viene de ALARM y no estorba en el conflicto.
4. La Odin **no se ha tocado**: db de sincronización real, `/var/log/pacman.log` y el
   conjunto de paquetes instalados, con md5 antes y después, **sin cambios**. El askpass
   temporal se borró al salir.

## 6. Qué tiene que hacer Fransis (en orden)

Esto es lo suyo: el `--overwrite` transitorio lo tiene que ejecutar **él desde la interfaz**,
no a mano.

1. **Comprobar que aparecen 3 actualizaciones** en el panel del QAM (pestaña de
   actualizaciones). Deberían ser `f2fs-tools`, `pocknix-base` y `pocknix-decky`.
   Si aparece alguna más, **para** y avisa: significaría que la fase 1 no se publicó bien.
2. **Pulsar el botón de actualizar** una sola vez y esperar. Lo que tiene que verse:
   ```
   POCKNIX_UPDATE_EXIT:0
   ```
   con una lista de actualización *terminada*, sin "archivos en conflicto".
   Fíjate en que el log ya no acaba en una línea de error.
3. **Reiniciar la Odin.** Esto no es opcional: el módulo Python del plugin lo carga una
   sola vez el `pocknix-decky-loader.service` (activo desde el 03/10), así que sin
   reiniciar la sesión seguiría usando el `updates.py` viejo. No hay scriptlet que
   reinicie el loader a propósito: tiraría el `steamwebhelper` al usar el QAM en Game Mode.
4. Comprobar que `/usr/bin/pocknix-update` es el nuevo:
   `grep -c OVERWRITE_BASE /usr/bin/pocknix-update` → `2`.
5. **Decirme que ha ido bien** → ejecuto la fase 2 (§7) y entonces sí, el **segundo**
   pulsar del botón es la prueba de verdad: instala `plutovg`, `plutosvg`,
   `pocknix-soname-compat`, `pocknix-vk-valve`, `libretro-cores-pocknix` y
   `pocknix-steam-full` por encima de los ficheros huérfanos, y ahí es donde se ve la
   capa 1 (o la autorreparación, si hiciera falta).

Si el paso 2 falla, **no sigas**: pásame el log tal cual
(`sudo cat /run/pocknix-update.log`) y no pulses nada más.

## 7. Fase 2 — SOLO después del reinicio del paso 6.3

Los seis paquetes ya están construidos en `build/localrepo/shared`; no hay que compilar
nada. En el PC (`pc-local`), **sin sudo**:

```bash
cd ~/pocknix-odin3-project/pocknix-os
export POCKNIX_REPO_RCLONE_REMOTE="r2:pocknix"
export POCKNIX_REPO_URL="https://pub-fd47305874674bf597b27eb7f880e73b.r2.dev"
export POCKNIX_STAGE_CHECK_OFFLINE=1
export POCKNIX_STAGE_CHECK_SOCS="sm8750"
# OJO: en la fase 2 NO se declara nada en TEMP_DROP: nada se retira.

make stage-shared PKG="plutovg plutosvg pocknix-soname-compat pocknix-vk-valve pocknix-steam-full libretro-cores-pocknix"
make publish-shared
```

Por qué `POCKNIX_STAGE_CHECK_*` (tres cosas que hubo que arreglar para poder publicar, y
que hay que saber para no volver a tropezar):

- `POCKNIX_REPO_RCLONE_REMOTE="r2:pocknix"` **obligatorio**: el default de
  `config/pocknix.conf` es `r2:pocknix/repo`, que **no existe**. Con el default, el
  staging se espeja de una ruta vacía y publicaría en un prefijo que ningún dispositivo
  lee. Es un fallo silencioso: `rclone sync` de un origen inexistente no da error.
- `POCKNIX_STAGE_CHECK_OFFLINE=1` con `build/stage/.dbcache/base.db` ya descargado: el gate
  pide la db del base congelado, y `[pocknix-base]` de los equipos apunta a
  `https://pocknix.shuuri.net/repo/base`, no a nuestro bucket (y el gate lo pide por
  rclone, que no entiende una URL https suelta).
- `POCKNIX_STAGE_CHECK_SOCS="sm8750"`: el gate recorre todos los `kernel/*/` y este bucket
  solo tiene `sm8750`. Para `sm8250`/`sm8550` no hay db, así que todo juicio se hace contra
  un universo vacío y falla con paquetes que ya estaban publicados (`mangohud`, `fex-emu`).
  Son fallos que bloqueaban **cualquier** publicación desde este estado, no algo que
  causara este cambio.

## 8. Texto para `shuuri-labs/pocknix-os` — **NO PUBLICADO**

Preparado, sin enviar. Enviar solo cuando Fransis haya confirmado el paso 6.

> **Título:** `pocknix-update: --overwrite acotado para los ficheros sin dueño que creó la propia distribución
>
> **Resumen**
>
> El botón de actualizar del plugin de Decky ejecutaba `pacman -Syu` a pelo. En dispositivos
> ya instalados eso aborta la transacción entera con "conflicting files", sin dejar nada a
> medias pero sin dejar actualizar nunca: un usuario sin terminal no puede recuperarse.
>
> **Causa raíz**
>
> Las rutas en conflicto no las dejó el build de la imagen — todo lo que instala
> `install_local_packages()` pasa por pacman. Son ficheros que la propia distribución
> escribió en la rootfs fuera de pacman y a los que después dio un paquete:
> `install-deckard-mesa.sh` (`install -D` del payload de Turnip en `/usr/share/pocknix/vk-arm/`
> más el alias `libdisplay-info.so.1`), y la instalación manual de `plutovg`, `plutosvg`,
> `libFLAC.so.8` y `libpcap.so.0.8` para que cargaran los cores libretro precompilados.
> Semanas después esos mismos ficheros pasaron a ser propiedad de `pocknix-vk-valve`,
> `plutovg`, `plutosvg` y `pocknix-soname-compat`. En el dispositivo fielded queda una copia
> sin dueño y cada `-Syu` posterior aborta.
>
> **Propuesta**
>
> 1. Un motor de actualización único (`pocknix-update`) con una política de `--overwrite` en
>    dos capas: primero una lista **cerrada** con las rutas que poseen esos paquetes (nunca
>    puede dejar que un paquete le robe un fichero a otro ya instalado), y si aun así hay
>    conflictos, un reintento con `--overwrite` reducido a las rutas que el propio pacman
>    nombra y solo a las que `pacman -Qo` dice que no pertenecen a nadie — así el siguiente
>    huérfano se arregla solo, sin editar nada.
> 2. El plugin llama a ese motor en vez de construir su propio `pacman -Syu` (dos copias de
>    la misma política divergen, y la que no llevaba `--overwrite`).
> 3. `install-deckard-mesa.sh` consulta `pacman -Qo` antes de escribir y se niega si la ruta
>    ya tiene dueño, para no volver a fabricar huérfanos.
>
> **Cómo probarlo**
>
> `pacman -Sup` contra un db desechable sobre un dispositivo con esos ficheros presentes
> devuelve el conjunto pendiente; `pacman -Syu --overwrite <lista>` completa la
> transacción. Con una ruta que sí pertenece a un paquete, el motor no reintenta y lo
> explica.
>
> **Notas**
>
> - Publicamos esto en dos pasos a propósito: primero el motor, y los seis paquetes afectados
>   vuelven al repo en una segunda publicación, para que la primera actualización de un
>   dispositivo no encuentre nada que entre en conflicto. Por eso hace falta reiniciar entre
>   una y otra: el loader de Decky carga el módulo Python una sola vez.
> - `stage-check.sh` necesitó dos knobs (`POCKNIX_STAGE_CHECK_TEMP_DROP` para un retiro
>   declarado a dos pasos, y `POCKNIX_STAGE_CHECK_SOCS` para no juzgar SoCs sin árbol
>   publicado).

## 9. Lo que NO se ha podido verificar

- **El botón en sí.** No se ha ejecutado ni una vez el actualizador nuevo: por diseño lo
  pulsa Fransis. Todo lo demás (los 5 escenarios del motor, las dos ramas del módulo, la
  resolución real contra la Odin) está probado, pero el recorrido completo
  botón → unidad systemd → log → `POCKNIX_UPDATE_EXIT` no.
- **La capa 2 en un caso real.** El escenario "huérfano desconocido" está probado contra
  un pacman simulado, no contra una transacción real. La capa 1 (que es la que debería
  entrar) está probada de verdad, porque es la lista de rutas que pacman nombró en el fallo
  real.
- **El camino de reinicio del paso 6.3** no se ha probado: depende de que el loader
  recargue el módulo al reiniciar.
- **La fase 2 no se ha ejecutado ni publicado**, a propósito.
- Nada se ha probado en la imagen (`build`/`sd-image`): esto toca paquetes, no la imagen.

## 10. Colateral que conviene mirar

1. **`config/pocknix.conf:130`**: `POCKNIX_REPO_RCLONE_REMOTE:=r2:pocknix/repo` no
   corresponde al bucket real (`r2:pocknix/{shared,sm8750}`). Publicar sin la variable
   explícita sube a un prefijo que nadie lee y no da error.
2. **Rama local del OS tree**: `odin3-sm8750` está 1 commit por delante y **3 por detrás**
   de `arcadematicas/odin3-sm8750`, con 35 ficheros sin marcar de otra sesión. No se ha
   tocado nada de eso: el commit se rebasó y empujó desde un worktree desechable. Quien
   tenga esa sesión abierta necesitará un `git rebase` antes de seguir.
3. **Deriva centro ↔ árbol**: `check-sync.sh` falla con 3 ficheros distintos
   (`devices/sm8750/firmware/README.md`, `devices/sm8750/packages/pocknix-bsp-sm8750/PKGBUILD`,
   `scripts/build-packages.sh`). En el árbol son **más nuevos** que en el centro, así que un
   `sync-to-os.sh` completo los rebasaría. Por eso aquí se aplicó solo el overlay de
   `pocknix-decky` (el mismo `rsync -a --itemize-changes` que usa el script). Con eso
   `check-sync` pasó de 5 a 3 diferencias, y ninguna es nuestra.