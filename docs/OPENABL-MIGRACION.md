# Migración a OpenABL en la Odin 3 (SM8750) — plan y estado

> Objetivo: pasar del **ROCKNIX ABL 1.1.8** (el que llevamos) a **OpenABL v1.2**, para tener
> **menú de arranque real** y entradas BLS (arranque + kernel anterior + futuro rollback), sin
> depender de una SD de rescate para cada susto.
>
> Regla de esta migración: **primero se escribe el payload nuevo (inocuo), se verifica, y solo
> después se toca el bootloader**. Nunca al revés.

---

## 1. Por qué no es un simple "dd"

| | ROCKNIX ABL 1.1.8 (actual) | OpenABL v1.2 (destino) |
|---|---|---|
| Qué arranca | Imagen Android boot en `/KERNEL` de la FAT | **BLS** (`/loader/entries/*.conf`), UKI (`/EFI/Linux/*.efi`), `extlinux.conf` o `\EFI\BOOT\BOOTAA64.EFI` |
| Menú | No | Sí (Volume − al encender) |
| Modelo de dispositivo | No aplica | Se elige en el menú, **a partir de los `.dtb` de `/dtbs`** |
| Versión visible desde Linux | No | ESRT (`fw_version = major<<16 \| minor`) |
| Fastboot | Sí (qcom ABL) | Sí, también con el menú abierto |
| EDL | Combo externo / PC | **"Emergency download mode" en el menú** |
| A/B | Sí | Sí, con "Boot other slot" |

**Consecuencia clave:** al flashear OpenABL, `/KERNEL` deja de usarse. Si no hay entradas BLS
válidas, el dispositivo **no arranca Linux**. Por eso el orden es:

1. escribir `/Image`, `/dtbs/*.dtb` y `/loader/entries/*.conf` (el ROCKNIX ABL los ignora: sigue
   arrancando `/KERNEL` como siempre),
2. verificar que están bien,
3. flashear OpenABL,
4. primer arranque con **Volume −** → *Device model* + *Start*.

---

## 2. Estado de partida (verificado en la Odin, 10/11/2026)

```
sda  = LUN0 UFS (datos)      sda18  FAT  "POCKNIX"       512 MiB → /flash   (361 MiB libres)
                             sda19  btrfs "POCKNIX_ROOT"  196 GiB → /
sde  = LUN4 UFS (bootloader) sde69  abl_a    1 MiB
                             sde70  abl_b    1 MiB
                             sde71/sde72 boot_a/boot_b (Android, sin usar)
```

- ABL actual: **ROCKNIX 1.1.8** (`/usr/share/pocknix/bootloader/rocknix_abl`, único kit instalado).
- `NO hay ESRT` (`/sys/firmware/efi/esrt` no existe) → la detección de "OpenABL en marcha" dará
  vacío hasta después de flashear y reiniciar. Es lo esperado.
- `/boot/Image` = **45.771.264 B**; `/boot/dtbs` = **3 dtb, 404 KiB**.
- `kernel-cmdline` usa `root=PARTLABEL=POCKNIX_ROOT` → el escritor BLS lo repina a
  `root=PARTUUID=956c3c5f-d725-4a72-944f-c5313eb0185f` (el PARTUUID real de `sda19`).
- Espacio en `/flash`: 361 MiB libres. Necesario: `Image` (45,7) + `Image.bak` (45,7 en la
  primera actualización) + dtbs (0,4) + margen 8 MiB ≈ **100 MiB**. Cabe de sobra.
- `/flash` contiene además `KERNEL`, `KERNEL.bak`, `KERNEL.bak-20261105-33` y
  `modules-7.2.15.tar.zst` (157 MiB usados). **No se borra nada** en esta migración (el fallback
  a ROCKNIX ABL depende de `KERNEL`).

---

## 3. Qué se prepara (código)

En el **centro** (`pocknix-odin3-support`), nunca en `pocknix-os`:

| Fichero | Qué hace |
|---|---|
| `packages/pocknix-bsp-common/pocknix-bls-deploy` | Escribe `/flash/Image`, `/flash/dtbs/*.dtb`, `/flash/loader/entries/pocknix{,-previous}.conf` y `loader.conf`, con `root=PARTUUID` repinado. tmp+rename, `Image.bak`, poda de dtbs, chequeo de espacio. Idempotente. |
| `packages/pocknix-bsp-common/91-pocknix-bls.hook` | PostTransaction en `boot/Image` / `boot/dtbs/*` → ejecuta el escritor. Inocuo en chroot (sin `/flash` montado). |
| `packages/pocknix-bootloader-sm8750/PKGBUILD` | **Añade** el kit `openabl/` v1.2 (ELF SM8750 + `version=1.2`). **Conserva** `rocknix_abl/` 1.1.8 como reversión. |
| `packages/pocknix-bsp-common/pocknix-update-abl` | Versión nueva: backups a `/flash/openabl` + copia a SD, verificación por slot, gate de batería 30 %, `--status`, aviso de *Device model*. Sin `repo-line` ni gate `requires-openabl`. |
| `packages/pocknix-bsp-common/pocknix-refresh-abl-kit` | Refresca a `/flash` el kit que exista (`openabl` y/o `rocknix_abl`). |
| `scripts/build-sd-image.sh` | Copia ambos kits a la FAT y escribe el payload BLS también en la imagen de SD (con el PARTUUID de la SD, no el del dispositivo). |

Datos del artefacto (verificados):

- `openabl-v1.2.tar.gz` sha512 `41f8b0460bc5c2cbbec312911377e52c41eda7c4dcd365bc76486d81cf4da0e9072df00edaf3afacb87565d856487d0aac3c8b5506d46b9ea6c901c319635492`
- `SM8750/abl_signed-SM8750.elf` = **532.480 B** (cabe en los slots de 1 MiB, con verificación de tamaño del propio script), sha256 validado contra el sidecar del release.

---

## 4. Procedimiento por fases

Cada fase termina en un **checkpoint**: si no se cumple, se para y se revierte.

### Fase 0 — Preparación (sin tocar el dispositivo)
- [x] Documento (este fichero).
- [x] Kit OpenABL descargado y verificado (sha512 + sha256 del ELF).
- [x] Código del centro revisado y testeado en seco (`/tmp`, sin dispositivo): 28/28 PASS.
- [x] `git commit` + push del centro (commits `f148cd4`, `4f198bc`, `08f71a4`, `32408bf`,
      `76e40b6`).

### Fase 1 — Instalar paquetes con BLS (sigue arrancando por `/KERNEL`)
1. Snapshot btrfs + copia de `/usr/share/pocknix/bootloader` y de `pocknix-update-abl`
   (hecho: snapshot `0073` automático de la transacción; bundle en
   `/home/deck/abl-rollback-20261110` y en `~/odin-backups` del portátil).
2. Instalar `pocknix-bsp-common` + `pocknix-bootloader-sm8750` nuevos (`pacman -U`, desde paquetes
   compilados en el **PC de sobremesa**).
3. **Checkpoint 1:** ✅ `pocknix-bls-deploy` instalado; kit `openabl/` presente;
   `sudo pocknix-update-abl --status` → `state=differs kit=openabl shipped_version=1.2
   running_openabl= needs_openabl=1 menu_reboot=1`.
4. Ejecutar a mano `SRCROOT=/ /usr/lib/pocknix/pocknix-bls-deploy` (o dejar que el hook lo haga al
   instalar el kernel).
5. **Checkpoint 2:** ✅ `/flash/Image` 45.771.264 B (cabecera `MZ`, EFI stub), `/flash/dtbs`
   con 2 dtb (el `.dtb.bak-pre-mic` se ignora por extensión), `loader/loader.conf` con
   `default pocknix.conf`, y `loader/entries/pocknix.conf` con
   `root=PARTUUID=956c3c5f-d725-4a72-944f-c5313eb0185f`. Sin `Image.bak` (primer Image).
   Espacio tras escribir: 316 MiB libres.
6. Reiniciar. **Checkpoint 3:** ✅ vuelve en ~55 s, kernel 7.2.15, `/KERNEL` intacto,
   0 unidades fallidas, root en `sda19[/@]`. El ROCKNIX ABL ignora el payload como estaba previsto.

### Fase 2 — Flashear OpenABL (ventana de 15 min, enchufado)
Precondiciones: batería >50 %, cargador enchufado, sin procesos de build, backups hechos.

1. Backup explícito: `pocknix-update-abl` (hace `dd` de `sde69`/`sde70` a `/flash/openabl/abl_{a,b}.img`)
   **y** copia externa (`scp` al portátil). Verificar que los `.img` miden 1 MiB.
2. `sudo pocknix-update-abl` → escribir `FLASH` cuando lo pida. Escribe y verifica slot A,
   luego slot B. **No cortar la corriente.**
3. Reiniciar con **Volume −** pulsado → menú OpenABL.
4. **Device model** → elegir el nuestro (sale de los `.dtb`). **Boot mode: Linux**. **Boot source:
   Internal** (o Auto).
5. **Start**.
6. **Checkpoint 4:** Linux arranca; `cat /sys/firmware/efi/esrt/entries/entry0/fw_version` da
   `65538` (1.2); `pocknix-update-abl --status` dice `running_openabl=1.2`, `needs_openabl=0`.

### Fase 3 — Limpieza opcional (solo tras varios arranques buenos)
- Valorar borrar `KERNEL.bak-20261105-33` y `KERNEL.bak` para liberar ~36 MiB (no urgente).
- **No** borrar `rocknix_abl/` ni el ELF de ROCKNIX: es la reversión.

---

## 5. Reversión

| Situación | Cómo se vuelve |
|---|---|
| Fase 1 (paquetes) | `pocknix-rollback` al snapshot previo, o reinstalar los `.pkg.tar.zst` viejos |
| OpenABL flasheado y arranca, pero no nos convence | `dd` del ELF de ROCKNIX (kit `rocknix_abl/abl_signed-SM8750.elf`) a `sde69` y `sde70`, desde Linux o `fastboot flash abl_a/abl_b` con el menú abierto |
| OpenABL no arranca Linux pero abre menú | Volume − → *Boot other slot* / *Debug*; o arrancar desde SD; o flashear ROCKNIX por fastboot |
| El flash se corta (sin slots válidos) | **EDL**: `iqoo_13.melf` + `edl-ng`/`bkerler-edl`. Documentado abajo |

### EDL — estado de la red de seguridad
- En Odin 3 (mismo SoC) **está probado** por terceros: entra en 9008, Sahara negocia, el loader
  `iqoo_13.melf` (sha256 `8CB97D13…13E08`) sube, configura UFS y **lee GPT/particiones**.
- El loader anuncia `program`, `erase`, `patch`: la **escritura** es posible en teoría, pero **no
  está verificada** en este dispositivo por nosotros. Se considera último recurso.
- Consecuencia práctica: **no hay que llegar ahí**. El riesgo real se controla no cortando la
  corriente y verificando slot a slot.

---

## 6. Lo que NO se hace en esta migración
- No se toca `KERNEL` ni su hook (`pocknix-build-bootimg` sigue generando la imagen Android de
  fallback).
- No se borran los backups ni el kit de ROCKNIX.
- No se activa `pocknix-repo-line` ni el gate `requires-openabl` de upstream (son su modelo de
  repos, no el nuestro).
- No se cambia el kernel en la misma sesión que el bootloader (si hace falta kernel nuevo, se
  compila en el PC y se instala **antes**, en la Fase 1).

---

## 7. Pendiente de decidir
- Si el primer arranque con OpenABL se hace con **Boot source = Internal** o **Auto**.
- Si mantenemos el `video=efifb:off` del cmdline (OpenABL gestiona el splash de forma distinta).
- Si a medio plazo adoptamos `Image.bak` como entrada de rollback automática (ya se escribe, pero
  nadie la selecciona sola).

---

## 8. Estado a 10/11/2026 (lo que falta es solo la Fase 2)

Hecho y verificado en la consola:

| Comprobación | Resultado |
|---|---|
| `pocknix-bsp-common` / `pocknix-bootloader-sm8750` | `0.1.0-26` / `1.2-2` instalados |
| Escritor BLS + hook | instalados; hook probado en seco (28/28) y a mano en la consola |
| `/flash/Image` | 45.771.264 B, `MZ` (EFI stub), kernel 7.2.15 |
| `/flash/dtbs` | `cq8725s-ayn-odin3.dtb`, `sm8750-konkr-pf-elite.dtb` |
| Entrada por defecto | `loader.conf` → `pocknix.conf`, `root=PARTUUID=956c3c5f…` |
| Kit en la consola | `openabl` 1.2 (`0dba7b90…`) y `rocknix_abl` 1.2 (`48441f73…`) |
| Reversión | `abl_a.img`/`abl_b.img` con el 1.1.8 exacto (`8d7fd55d…`), dentro y fuera |
| Tras reiniciar | arranca por `/KERNEL` como siempre, 0 fallos |

Pendiente inmediato (necesita a Fransis delante):

1. `sudo pocknix-update-abl` → escribir `FLASH` (deja backups de los slots en `/flash/openabl`).
2. Reiniciar con **Volume −** → **Device model = AYN Odin 3**, **Boot mode = Linux**,
   **Boot source = Internal** (o Auto) → **Start**.
3. `cat /sys/firmware/efi/esrt/entries/entry0/fw_version` → debe dar `65538` (1.2).

Notas sueltas:

- `pocknix-update-abl --status` **necesita root** (sin él `state=nopart`: `blkid` no ve los
  slots). Pocknix Tools lo llama por `pkexec`, así que allí no se nota.
- `pocknix-tools` sigue etiquetando el bootloader como "ROCKNIX <ver>" en `do_abl()` /
  `abl_item_label()`: con OpenABL 1.2 mostraría un nombre equivocado. Cosmético, pendiente.
- El payload BLS también entra en la imagen de SD nueva (mismo escritor, con el PARTUUID de
  la tarjeta). No se ha construido una SD de rescate en esta sesión.
