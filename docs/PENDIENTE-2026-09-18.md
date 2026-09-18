# Pendiente / Estado — 2026-09-18 (para el domingo)

Sesión larga. Resumen de lo conseguido, lo que falló, **el estado exacto de la SD**
y la lista de pruebas para el domingo.

---

## 1. TL;DR

- **El kernel 7.2.6 es inviable en la Odin 3**: tiene **dos regresiones de mainline**
  (display y WiFi). Se confirmó una a una.
- **Decisión final**: volver a **nuestro 7.2.4** (que funciona todo) y añadirle
  **solo los 3 parches de rotación** de ROCKNIX/tiopex. Eso es lo que está compilado
  y flasheado.
- **La SD tiene la rootfs corrupta** (btrfs, transid mismatch + rollback). Se pudo
  montar con `rescue=all` y **se salvó todo a la copia de seguridad**. Falta decidir
  reparar o re-flashear (ver §5).

---

## 2. Las dos regresiones del 7.2.6 (documentadas para no repetirlas)

### 2.1 Display — panel negro (`-22`)

En **7.2.5/7.2.6** mainline cambió `dsi_calc_clk_rate_6g()` en
`drivers/gpu/drm/msm/dsi/dsi_host.c`: añade un `clk_round_rate()` del byte clock y
**sobrescribe** `msm_host->byte_clk_rate`. Con eso el `pixel_clk_rate` calculado deja
de cuadrar y `clk_set_rate(pixel_clk)` devuelve **-22**:

```
dsi_link_clk_set_rate_6g: Failed to set rate pixel clk, -22
```

→ el panel no inicializa y el DPU entra en bucle de `dpu_encoder_frame_done_timeout`
→ nunca sube la red (parece que no arranca, pero sí arranca).

**Fix probado y funcionando**: revertir `dsi_host.c` al comportamiento de 7.2.4
(quitar el `clk_round_rate` + la sobrescritura, y recuperar `dev_pm_opp_set_rate(dev, 0)`
en el disable). Con ese revert **el display arrancó** ✅.
Parche que lo hacía: `20-sm8750/0071-revert-dsi-calc-clk-rate-rounding.patch`
(se ha retirado porque ya no usamos 7.2.6, pero queda documentado aquí).

**Ojo**: los parches de rotación **NO eran los culpables**. Se compiló un kernel
7.2.6 *sin* rotación (el "nodpu") y fallaba exactamente igual.

### 2.2 WiFi — el ath12k no arranca (`-110`)

Con 7.2.6 el WiFi no aparece. Journal:

```
ath12k_wifi7_pci 0000:01:00.0: Wi-Fi 7 Hardware name: wcn7860 hw2.0
ath12k_wifi7_pci 0000:01:00.0: failed to set mhi state: POWER_ON(2)
ath12k_wifi7_pci 0000:01:00.0: failed to start mhi: -110
ath12k_wifi7_pci 0000:01:00.0: failed to power up :-110
ath12k_wifi7_pci 0000:01:00.0: failed to create soc 0 core: -110
ath12k_wifi7_pci 0000:01:00.0: unable to create hw group
ath12k_wifi7_pci 0000:01:00.0: failed to init core: -110
ath12k_wifi7_pci 0000:01:00.0: probe with driver ath12k_wifi7_pci failed with error -110
```

`-110` = ETIMEDOUT (el power-on del MHI tarda ~90 s y expira) → no hay `wlan0`.

**Lo que se probó**: revertir **el driver ath12k COMPLETO** a 7.2.4
(`20-sm8750/0073-revert-ath12k-to-7.2.4.patch`, 16 ficheros, aplica con 0 hunks
fallidos) → **SIGUE fallando igual**. Conclusión: **no es el ath12k**.

**Dónde está entonces**: en el **MHI** (`drivers/bus/mhi/host/{init,main}.c`) y/o el
**PCIe QCOM** (`drivers/pci/controller/dwc/pcie-qcom.c`), que también cambiaron en
7.2.6. Se generó el revert combinado (`revert-mhi-pcie.patch`, 132 líneas, 4 ficheros,
aplica con 0 hunks fallidos) pero **no llegó a compilarse** porque se cambió de
estrategia. Si algún día se retoma el 7.2.6, empezar por ahí.

Cambios concretos del MHI en 7.2.6:
- `init.c`: solo un fix de ruta de error (`goto err_del_dev` + `device_del`).
- `main.c`: añade un **flush del posted write** tras el reset
  (`mhi_read_reg(... MHI_SOC_RESET_REQ_OFFSET ...)`).

Cambios del ath12k en 7.2.6 (por si se retoma): eliminaron
`ath12k_core_get_reserved_mem()` (la lectura del `memory-region` del DTS),
`.rxdma_monitor_dst_ring_size` 8092→8192, y
`complete(&ar->peer_delete_done)` → `ath12k_peer_delete_wait_flush(ar)`.

### 2.3 Nota sobre el parche 0070 (ath12k scan priority)

El `0070-wifi-ath12k-send-the-computed-scan-priority-to-the-firmware.patch`
(arreglo de reconexión de ROCKNIX) **se retiró**: solo tocaba `wmi.c`/scan, no era
el culpable del fallo del probe, y en la nueva base 7.2.4 no aplica igual. Si vuelve
a hacer falta el fix de reconexión, re-aplicarlo sobre 7.2.4.

---

## 3. Estado actual del kernel (lo que hay compilado y flasheado)

```
Base:      linux-7.2.4  (SHA256 01710ee01737dac492f1bae52becd057e08d20d11589089aa06accff415c28dd)
Parches:   98 totales -> 05-speedup(22) + 10-mainline(5) + 20-sm8750(66) + 30-version(5)
           0 conflictos
KERNEL:    18.964.480 bytes   md5 204c05194598
```

Los **3 parches de rotación** aplican **sin un solo offset** sobre 7.2.4 y están
**verificados en el árbol compilado**:

| Parche | Marcador verificado | Valor |
|---|---|---|
| `10-mainline/0013-drm-msm-dpu-fix-inline-rotation` | `DPU_SSPP_INLINE_ROTATION` en `dpu_plane.c` | 4 |
| `20-sm8750/0067-drm-msm-dpu-enable-qseed-detail-enhancer` | `QSEED3_DE_LPF_BLEND` en `dpu_hw_util.c` / campo `blend` en `.h` | 2 / 2 |
| `20-sm8750/0068-drm-msm-dpu-enable-sm8750-inline-rotation` | `VIG_SM8750_MASK_SDMA` en `dpu_hw_catalog.c` | 1 |

> **Truco de verificación**: los símbolos **no** se pueden grepear en la imagen
> `KERNEL` (está comprimida). Hay que mirar el **árbol de fuentes**
> `build/kernel/sm8750/linux-7.2.4/` con los marcadores correctos.
> `rot_v2` **no** sirve como marcador: es upstream (también está en `sc7280`).

**Nota sobre `rot_maxheight`**: **ningún parche nuestro lo añade**. La rotación del
sm8750 se activa vía `.features = VIG_SM8750_MASK_SDMA` (que incluye
`BIT(DPU_SSPP_INLINE_ROTATION)`) + `.sblk = &dpu_vig_sblk_qseed3_3_4_rot_v2` en
`catalog/dpu_12_0_sm8750.h`. Si en el futuro se busca un límite de altura de rotación,
habrá que mirar cómo lo hace ROCKNIX en su gamescope (§6).

### Repos (commits de esta sesión)

- `pocknix-os` (rama `odin3-sm8750`): `38ddd1d` (revert DSI), `ae7d2aa` (revert ath12k),
  **`bc08546` (volver a 7.2.4 + rotación)** ← el estado actual.
- `pocknix-odin3-support` (rama `master`): documentación.

---

## 4. 🚨 La SD está corrupta (importante para el domingo)

Al ir a copiar los módulos 7.2.4 a la SD saltó:

```
cp: no se puede efectuar 'stat' sobre '.../lib/modules/7.2.4/': Error de entrada/salida
```

En dmesg:

```
BTRFS error (device sde2 state EA): parent transid verify failed on logical 30572544
  mirror 1 wanted 4292 found 4279
```

Y el montaje normal ya fallaba ("superbloque incorrecto"). El `btrfs check --readonly`
mostró el patrón clásico de **rollback de btrfs**:

```
parent transid verify failed on 42172416 wanted 4273 found 4280
Error: could not find extent items for root 18446744073709551607
ERROR: failed to repair root items: No such file or directory
Extent back ref already exists for ... (varios)
```

**Causa probable**: la propia Odin **restauró un snapshot** al arrancar (existen
`@snapshots/0006`…`0010`), dejando el árbol en un transid más nuevo que sus padres.
El `@home` monta y los datos están ahí, pero el FS es inconsistente.

**Lo que SÍ funcionó para leer los datos**:

```bash
sudo mount -o ro,rescue=all /dev/sde2 /mnt        # subvol @
sudo mount -o ro,rescue=all,subvol=@home /dev/sde2 /mnt2
```

**Copia de seguridad hecha** (2026-09-18):

```
/run/media/fransis/ROMS16TB/proyectos Alfred/pocknix-odin3/backup-sd-2026-09-18/
  ├── home-deck/          (38 GB: Projects, suyu-build, goosestation-builder,
  │                        Documents, Downloads, Desktop, homebrew, ...)
  ├── etc/
  ├── root/
  └── var_lib_pacman/
```

> **El `KERNEL` del FAT está intacto** (es vfat, no btrfs): por eso el flasheo
> funcionó. md5 `204c05194598`.

### Estado de los módulos en la SD

```
/lib/modules/7.2.4   ← los originales (los buenos para el kernel flasheado)
/lib/modules/7.2.6   ← los que añadimos nosotros (ya NO sirven; borrar si se puede)
```

---

## 5. Pendiente: decidir qué hacer con la SD

Opciones (de menos a más destructiva):

1. **`btrfs check --repair`** sobre `/dev/sde2` (desmontada). Puede arreglar el
   transid + los backrefs. Riesgo: puede empeorar. Con la copia hecha, el riesgo
   es asumible.
2. **`btrfs rescue super-recover -y`** (falló con "device is busy" porque estaba
   montada — reintentar desmontada).
3. **Re-flashear la imagen completa de la SD** (`make sd-image` / el script del
   repo) + restaurar `home-deck/`. Es lo más limpio y garantiza SD sana para el
   domingo, pero hay que reinstalar/restaurar.

**Recomendación**: probar (1); si no queda perfecta, ir a (3) con la copia ya hecha.

---

## 6. Pruebas para el domingo

### 6.1 Lo primero (kernel actual)
- [ ] Arranca con el `KERNEL` `204c05194598` (7.2.4 + rotación).
- [ ] **Display** OK (no debería fallar: es 7.2.4 puro).
- [ ] **WiFi** OK (7.2.4 tiene el ath12k bueno → debería conectar solo).
- [ ] Brillo, táctil, mandos, batería.
- [ ] `uname -r` debe decir `7.2.4`.

### 6.2 Rotación por hardware (lo nuevo)
Los parches de rotación están **en el kernel** pero **no se activan solos**: el
usuario de rotación es gamescope. Hoy seguimos lanzando gamescope con
`--force-orientation "${ORIENT}" --force-composition-rotation -e --`
(parche nuestro `0007`), que hace la rotación **por composición** (software).

Para probar la rotación **por hardware** hay que:
- [ ] Quitar `--force-composition-rotation` de la invocación de gamescope
      (en `/usr/bin/pocknix-steam`).
- [ ] Y antes, resolver la parte de gamescope (§6.3).

### 6.3 gamescope: la pieza que falta
- Nuestro commit: `6644cc9a07d8ba937003deae8bd7c28a490d0c64`
  (`3.16.0.rocknix.20260802.6644cc9-4`).
- El de ROCKNIX: `fa0b4d33` (**43 commits más nuevo**).
- ROCKNIX lleva el parche `0008-DRMBackend-add-rotated-output-max-height.patch`
  (205 líneas) que añade el flag **`--rotated-output-max-height`**.
  Contra nuestro commit **fallan 2 de 4 hunks**.

**Decisión pendiente**: (A) subir gamescope a `fa0b4d33` (la "fórmula tal cual" de
ROCKNIX) o (B) rebasar el parche `0008` a nuestro commit `6644cc9a`.

### 6.4 Otras cosas en cola
- [ ] **ABL 1.1.7 → 1.1.8**: PKGBUILD ya subido (commit `9e2c1f1`), falta
      reconstruir y re-flashear **con backup previo** (`backup_abl.sh`).
- [ ] **Mesa 26.2.3 + Turnip 20260918**: compilados en `build/localrepo`,
      falta instalarlos en la Odin.
      (`pocknix-turnip-arm` `_develcommit=54c629ae6642389f891338e25a3e09a4e71102fd`,
      sha256 del tarball `f0df33dea142ae14d4e06fb3340ebe43cf4449ebb0322a9a387a9ea488d2f217`)
- [ ] **Frame limiter del QAM**: prueba pendiente.
- [ ] **ext4 vs F2FS** en la UFS interna: decisión pendiente (`docs/IDEAS.md` §6).

---

## 7. Herramientas y trucos (reutilizables)

- `tools/check-mesa.sh`, `tools/flash-kernel.sh`, `tools/restore-kernel-from-sd.sh`,
  `tools/build-suyu-core-x86.sh`.
- **Leer el journal de la SD** (funciona siempre, aunque la Odin no tenga red):
  ```bash
  sudo mount -o ro,subvol=@var-log /dev/sde2 /mnt
  sudo journalctl -D /mnt/journal --list-boots
  sudo journalctl -D /mnt/journal -b 0
  ```
  (si el FS está corrupto, añadir `,rescue=all`)
- **`pkill -f <patrón>` mata el propio comando** si el patrón aparece en él
  (¡pasó dos veces!). Usar el truco del corchete `build[-]kernel` y, aun así,
  evitar que el comando contenga el literal que se busca. Mejor: matar por PID.
- **Los subagentes fallan con prompts largos**: usar prompts cortos, pero
  intentarlo siempre.
- **No editar un script mientras corre** (bash lo lee por desplazamiento).
- **Los `sudo make` dejan el árbol de `build/` de root** → antes de un build manual
  hacer `sudo chown -R fransis:fransis build/`, o el `rm -rf` de la fuente falla
  con "Permiso denegado" y el build muere.
- **Verificar parches**: mirar el **árbol de fuentes**, no la imagen comprimida,
  y con los **marcadores exactos** (ojo con mayúsculas: `QSEED` no es `qseed`).
