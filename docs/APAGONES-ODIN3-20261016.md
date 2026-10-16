# Apagón en seco del Odin 3 con rumble (Cemu) — 16/10/2026

## 1. Resumen

La **Odin 3 se apagó en seco** (corte de corriente a nivel de hardware) mientras el
usuario jugaba con el core **Cemu**, que hace uso del **rumble** del mando interno
(RSInput sobre UART, hápticos Qualcomm vía `qcom-hv-haptics`).

**NO fue un panic.** Lo que sí sabemos y lo que se descartó:

- **Sin panic/oops/BUG**: el `pstore`/`ramoops` estaba **vacío** y el journal no
  contiene `oops`, `BUG` ni `panic`. Lo último que el kernel escribió **no** fue un
  volcado de fallo.
- Al **arrancar de nuevo** el sistema dice `system.journal corrupted or uncleanly
  shut down` — la firma de un corte de alimentación, no de un reinicio ordenado.
- **Lo último que registró el kernel** antes de morir fueron **5 errores del driver
  de hápticos en los últimos 24 s**, y la **ÚLTIMA línea** del arranque es una de
  ellas (14:40:15):

  ```
  qcom-hv-haptics c400000.spmi:pmic@7:qcom,hv-haptics@f000: poll HPWR_DISABLED failed after stopped play
  ```

  Es decir: el **stop del rumble** (`... after stopped play`) es exactamente el
  último camino por el que pasó el kernel.

> Nota de alcance: este documento es la parte *de kernel*. El corte en sí
> (alimentación a nivel HW) **no** produce una traza; el único rastro es el
> journal de la propia SD. Por eso el arreglo es **quitar de raíz el trabajo
> peligroso del driver de hápticos** (no "cortar el rumble": la decisión del
> usuario es arreglarlo con parche, no capar la función).

## 2. Evidencia del journal

| Hecho | Valor |
|---|---|
| **Última línea del arranque** | `qcom-hv-haptics c400000.spmi:pmic@7:qcom,hv-haptics@f000: poll HPWR_DISABLED failed after stopped play` (14:40:15) |
| Errores de hápticos antes de morir | **5 en los últimos 24 s** |
| `pstore` / `ramoops` | **vacío** (no hubo volcado) |
| `oops` / `BUG` / `panic` en el journal | **ninguno** |
| Marca en el arranque siguiente | `system.journal corrupted or uncleanly shut down` |
| Contexto | juego con **Cemu** (rumble activo) |

**Boot IDs**: el arranque que murió es el que el arranque *siguiente* marca como
`corrupted or uncleanly shut down` (el journal de ese boot es el que quedó a medias).
Los IDs numéricos de `journalctl --list-boots` de la máquina **no** se han
archivado todavía en el centro; cuando se recojan de la SD hay que añadirlos aquí
(`journalctl --list-boots` y `journalctl -b -1 -p err`). **No se inventan**: se
dejan como pendiente explícito (§7).

## 3. Sospechosos y descartes

Del análisis del journal (investigación previa, **no** repetida aquí):

- **Temperaturas — descartado**: no hay *thermal trip* ni episodios de throttling
  violento alrededor del corte.
- **Ventilador — descartado**: no hay error del controlador del ventilador ni
  parada anómala del mismo.
- **Batería / `caps` (fuel gauge, `qcom_battmgr`) — descartado**: no hay evento de
  tensión baja ni desconexión de batería en el journal. (Recuérdese que llevamos
  parches propios de `battmgr` —`0078/0079/0080/0081`— y aun así no hay traza.)
- **Sospechoso nº 1 (el que se ataca aquí)**: el **driver de hápticos**. Tanto la
  familia de bugs de *scheduling while atomic* del bridge de rumble como el
  *stop* diferido del rumble son exactamente la actividad que el kernel estaba
  ejecutando y la última que registró. ArmadaOS documenta que esa clase de fallo
  **cuelga en duro la Odin 3** (reproducido en hardware, ver §4).
- **Sospechoso nº 2 (abierto)**: el **bucle de handover del ADSP** (arranque/
  recuperación del DSP sin converger). No está confirmado y **no** lo toca este
  cambio; queda anotado para seguimiento.

## 4. Qué había ya y qué faltaba

### 4.1 El bug de contexto atómico (armada `1003`) — **ya portado** (`2101`)

ArmadaOS, en `packages/kernel/PATCHES.md`:

- `1003-input-haptics-fix-rumble-bridge-atomic-sleep`: el bridge de rumble
  importado llamaba a los callbacks de hápticos (que **duermen**: I/O de regmap
  SPMI, el mutex de play, `cancel_work_sync`/`cancel_delayed_work_sync`) bajo
  `spin_lock_irq`, y el callback de playback de RSInput corre además con el
  `event_lock` de su propio input device con las interrupciones deshabilitadas →
  `BUG: scheduling while atomic` en **cada** parada de rumble y **cuelgues duros
  intermitentes** de la Odin 3 (reproducido en hardware).

Esto **ya lo tenemos**: nuestro port es
`kernel/patches/20-sm8750/2101-input-haptics-fix-rumble-bridge-atomic-sleep-armada.patch`
(desde 01/10/2026), y por debajo, la base sincronizada de ROCKNIX ya trae
`1004-input-qcom-hv-haptics-defer-rsinput-playback.patch` (difiere el playback a un
work item desde el lado de los hápticos).

**Comparación `1003` de armada ↔ nuestro `2101` (hecha el 16/10/2026):**

- El `1003` de armada **no ha cambiado** desde el 30/09/2026 (`diff` vacío contra
  `reference/armada-patches/1003-…`).
- Nuestro `2101` **porta fielmente** el `1003`: sitúa `haptics_global_lock` (mutex)
  alrededor de la publicación/teardown de `phapchip` en `probe`/`remove` y en las
  rutas de *upload* y *set-gain*, y **añade el `cancel_work_sync(&chip->set_gain_work)`
  a la ruta de suspend** junto a los drenados que ya hacía nuestro `1004`
  (`global_playback_work` + `stop_work`). Comprobado en el árbol ya parcheado:

  ```
  6628  cancel_work_sync(&chip->global_playback_work);   <- 1004
  6630  cancel_work_sync(&chip->set_gain_work);          <- 2101 (lo que pedía el ejemplo)
  6631  cancel_delayed_work_sync(&chip->stop_work);      <- 1004
  ```

- **Deliberadamente NO portado** (y documentado en la cabecera de `2101`): (a) tomar
  el mutex en `qcom_spmi_haptics_global_playback()` — reintroduciría
  *scheduling while atomic*, porque en nuestro árbol ese callback aún viene de
  RSInput en contexto atómico; armada puede hacerlo solo porque su mitad RSInput
  ya difiere la llamada; (b) toda la mitad RSInput del `1003` (`rumble_work`,
  `rsinput_suspend`, cambio de PM ops) — redundante con nuestro `1004`/`1007`.

**Conclusión de §4.1: nuestro port es completo.** La pieza que el ejemplo de la
tarea citaba (que la ruta de suspend cancele los workers de *stop* y *set-gain*)
**ya estaba**: `set_gain_work` por `2101`, `stop_work` por `1004`. No hubo que
completar nada.

### 4.2 El *stop* diferido del rumble (armada `1004`) — **LO TENÍAMOS PENDIENTE** → `2107`

ArmadaOS:

- `1004-input-haptics-stop-zero-amplitude-immediately`: el parche de compatibilidad
  *periodic-sine* cambió las actualizaciones a **amplitud cero** para poner la
  ganancia a 1 y **parar el motor 5 s después**. Con el patrón de freno
  configurado, esa parada se convierte en un **golpecito distinto y retrasado**
  exactamente 5 s después del rumble normal. Ahora las actualizaciones a amplitud
  cero **borran de inmediato**, una petición de playback posterior **no** puede
  reanudar estado de motor obsoleto cuando no hay efecto cargado, y las
  actualizaciones de ganancia *in-place* equilibran su referencia transitoria de
  runtime-PM.

Esto encaja con el error de la **parada** (`...failed after stopped play`) y es lo
que faltaba. **Portado como `2107`** (§5).

## 5. Parches añadidos / cambiados en el centro

Numeración `2xxx` para los ports de armada (igual que `2100`–`2106`).

| Nuestro parche | Origen (armada) | URL (pineada a commit) | sha256 del crudo |
|---|---|---|---|
| `kernel/patches/20-sm8750/2107-input-haptics-stop-zero-amplitude-immediately-armada.patch` **(nuevo)** | `1004-input-haptics-stop-zero-amplitude-immediately.patch` | `https://raw.githubusercontent.com/armada-os/armada/ce363b8e67cfd2b5fcf44fd384686f85d777ae9d/packages/kernel/patches/1004-input-haptics-stop-zero-amplitude-immediately.patch` | `f78668f793643306450b93f2672268271c2d1e816399fd50588fb366784c161b` |

- Rama por defecto de armada: **`main`**, commit **`ce363b8e67cfd2b5fcf44fd384686f85d777ae9d`**
  (consultado el 16/10/2026).
- El crudo se guarda además en
  `reference/armada-patches/1004-input-haptics-stop-zero-amplitude-immediately.patch`.
- Colisión de fichero: `2107` toca `drivers/input/misc/qcom-hv-haptics.c`, el mismo
  que nuestro `1004` y `2101`. **Orden garantizado**: dentro de `20-sm8750` los
  parches se aplican por orden **numérico**, así que `2107` va **después** de
  `2101`, y `2107` se regeneró contra ese estado (§6). No hay *fuzz* ni rechazo.

**Adaptación de `2107`**: el `1004` de armada aplica a nuestro árbol **byte a byte**
(los añadidos/quitados son los suyos, sin cambios de lógica). Como en el port
`2102`, **solo** se movieron las cabeceras `@@` a los números de línea de nuestro
árbol para que entre a **offset 0** (las cabeceras de armada iban 12 líneas antes);
los nombres de función de las cabeceras se dejaron igual.

**Descartados (revisados por asociación, no portados, con motivo):**

| Parche de armada | Decisión | Motivo |
|---|---|---|
| `1005-input-rsinput-quiesce-the-mcu-across-system-sleep.patch` | **NO portar aparte** | Su paso de quiesce del MCU (bajar `enable-gpios`/`reset-gpios` antes del suspender) ya está **inline** en nuestro `1007-input-rsinput-drop-the-mcu-supply-across-system-sleep.patch`. Portarlo añadiría un `rsinput_suspend()` duplicado. |
| `1006-tty-serial-qcom-geni-mask-non-console-irq-on-suspend.patch` | **Ya portado** | Es nuestro `2102-…-armada.patch` (desde 01/10/2026). Nada que añadir. |
| `1003-input-haptics-fix-rumble-bridge-atomic-sleep.patch` | **Ya portado** | Es nuestro `2101-…-armada.patch` (§4.1). |
| `1007-input-rsinput-drop-the-mcu-supply-across-system-sleep.patch` | **Ya portado** | Es nuestro `1007-…-system-sleep.patch` (con el `1005` inline). |

## 6. Verificación de aplicación (reproducible)

**Qué exige el build.** `scripts/build-kernel.sh` → `apply_patches()` re-extrae el
tarball y aplica, en orden de directorio (`05-speedup` → `10-mainline` →
`20-sm8750` → `30-version`) y por orden **numérico** dentro de cada uno, con:

```bash
patch -p1 --fuzz=5 -d "$KSRC" < "$p"    # y si falla: warn "patch conflict (skipping)"
```

> Ojo: el build usa **`--fuzz=5`** y ante un conflicto **salta el parche en
> silencio** (no aborta). Por eso la prueba por separado con **`-F0`** es la red de
> seguridad: si un parche nuevo (como `2107`) fallara, el build lo omitiría sin
> enterarse.

**Banco de pruebas (en el centro, sin tocar el árbol de compilación):**

```bash
# 1) fuente base
tar -C /home/fransis/ktest -xf /tmp/opencode/kernel/linux-7.2.9.tar.xz

# 2) árbol de parches EXACTAMENTE el del build (copia de solo lectura del árbol OS)
cp -a pocknix-os/kernel/sm8750/patches/{05-speedup,10-mainline,20-sm8750,30-version} /home/fransis/ktest/patches/
cp    kernel/patches/20-sm8750/2107-…-armada.patch                          /home/fransis/ktest/patches/20-sm8750/

# 3a) tal como lo hará el build (fuzz=5, salta conflictos)
for d in patches/*/; do for p in "$d"*.patch; do \
  patch -p1 --fuzz=5 -d linux-7.2.9 < "$p" >/dev/null 2>&1 || echo "SKIP $(basename "$p")"; done; done

# 3b) estricto (sin fuzz) como pide esta tarea
for d in patches/*/; do for p in "$d"*.patch; do \
  patch -p1 -F0 -d linux-7.2.9 < "$p"; done; done
```

**Resultado 3a — como lo hará el build (`--fuzz=5`):**

```
APPLIED 05-speedup : ok=20 skip=2   (01/02 mksysmap)
APPLIED 10-mainline: ok=5  skip=0
APPLIED 20-sm8750  : ok=98 skip=4   (0048a, 0050, 0055, 0517)
APPLIED 30-version : ok=2  skip=0
```

Los **6 skips** son exactamente los ya documentados en
`docs/KERNEL-7.2.9-2-EXTERNAL-PATCHES-2026-10-06.md` §3 — **pre-existentes, ninguno
toca hápticos ni RSInput**. El banco reproduce el comportamiento real del build.

**Resultado 3b — estricto `-F0` (0 rechazos, 0 fuzz en lo nuestro):**

- **Los 14 parches que nos importan entran limpios (0 rechazos, 0 fuzz)**:
  `1000`, `1001`, `1002`, `1003`, `1004`, `1007`, `2100`, `2101`, `2102`, `2103`,
  `2104`, `2105`, `2106` y el **nuevo `2107`**.
- `2107` concreto: `patch -p1 -F0 --dry-run` → `checking file
  drivers/input/misc/qcom-hv-haptics.c` sin ninguna línea `Hunk #N succeeded …
  (offset …)` ⇒ **offset 0 y fuzz 0**.
- A `-F0` fallan **16 parches de base** (mksysmap/kallsyms/kbuild de `05-speedup`,
  `0002 polldev`/`0005 btrtl` de `10-mainline`, `0028/0048/0048a/0050/0055/0517` de
  `20-sm8750`, `0010-msm-resource-cleanup` de `30-version`). Son **deriva de base**
  (context drift); 10 de ellos los "rescata" el `--fuzz=5` del build y los otros 6
  se saltan igual (los documentados). **Ninguno** toca
  `drivers/input/misc/qcom-hv-haptics.c` ni `drivers/input/joystick/rsinput.c`, así
  que no afectan a este arreglo, pero conviene tenerlos en el radar (§7).

**Sobre la versión de fuente.** La prueba se hizo con **linux-7.2.9**, no 7.2.10:

- Solo había tarball local de **7.2.9** (`/tmp/opencode/kernel/linux-7.2.9.tar.xz`,
  el mismo que usa `build/cache/`), y descargar 7.2.10 de kernel.org (160 MB) fue
  **inviable** desde aquí (red limitada a ~10 KB/s; todos los espejos probados
  igual o peor). La pin en `kernel/sm8750/kernel.conf` es **7.2.10**
  (sha256 `2feaa704…`).
- Esto **no invalida** la prueba para este cambio: los ficheros que tocan nuestros
  parches de hápticos son **creados enteros por parches anteriores de la misma
  pila** — `1000-input-misc-qcom-hv-haptics-sm8750.patch` crea
  `drivers/input/misc/qcom-hv-haptics.c` (`new file mode`, `--- /dev/null`) y
  `0031_input--Add-driver-for-RSInput-Gamepad.patch` crea
  `drivers/input/joystick/rsinput.c` (idem). Su contenido **en el punto en que
  aplica `2107`** lo fija la pila, no la versión de base. Y el banco reprodujo
  además el resultado **real** del último build (los 6 skips), lo que confirma que
  es fiel.
- Aun así, **hay que re-verificar contra 7.2.10** en el PC antes de fiarse (los
  parches de base `0028/0048/0048a/0050/0055/0517` podrían cambiar de estado).

## 7. Qué queda por hacer

1. **Recompilar** el kernel **7.2.10** con el set nuevo (que incluye `2107`) en el
   PC y confirmar en el log del build que `2107` **no** aparece como
   `patch conflict (skipping)`.
2. **Re-verificar** el `-F0` de `2107` y de los `2xxx` contra **7.2.10** (aquí no
   se pudo bajar el tarball).
3. **Publicar** el paquete resultante (repo R2) y **desplegarlo** en la Odin.
4. **Probar el rumble** a conciencia (Cemu y cores con parada de rumble): sin
   `BUG: scheduling while atomic`, sin el golpecito a 5 s, sin apagón.
5. **Archivar los boot IDs** del arranque que murió (`journalctl --list-boots`,
   `journalctl -b -1 -p err`) en §2, y de paso revisar el `dmesg` del arranque
   bueno anterior por los 5 errores de hápticos.
6. **Seguir el sospechoso nº 2** (bucle de handover del ADSP) por separado.
7. (Aparte) El build **salta en silencio** los parches que no aplican; revisar si
   los `6`/`16` de deriva de base deben arreglarse para 7.2.10 (no es de este
   cambio).

## 8. Referencias

- Diagnóstico del apagón: sesión del 16/10/2026 (journal de la SD; `pstore`
  vacío; sin oops/BUG/panic).
- `packages/kernel/PATCHES.md` de ArmadaOS (copia local en
  `/tmp/opencode/armada-kernel-patches.md`): entradas `1003`, `1004`, `1005`, `1006`,
  `1007`.
- Nuestros parches: `kernel/patches/20-sm8750/` (ports `2xxx`), base sincronizada
  `1000`–`1004`, `1007`.
- `docs/KERNEL-7.2.9-2-EXTERNAL-PATCHES-2026-10-06.md` (los 6 skips conocidos del
  build).
- `reference/armada-patches/` (crudos de armada + README actualizado).
