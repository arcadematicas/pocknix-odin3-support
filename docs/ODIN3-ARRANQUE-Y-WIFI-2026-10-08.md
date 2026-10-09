# Odin 3 — Diario de arranque y WiFi (2026-10-08)

**Estado**: la consola arranca **Android** (interno) sin SD ✓, pero **NO arranca Pocknix desde la SD**
(se queda en el logo con el cursor parpadeando). Objetivo: arrancar Pocknix **con WiFi**.

## 1. PRUEBAS HECHAS Y DESCARTADO (no repetir)
| Prueba | Resultado |
|---|---|
| DTS del USB nuestro vs ROCKNIX vs ArmadaOS | **Byte a byte idéntico** (hash 33bbc27f…). **Ninguno** tiene `dr_mode`/`usb-role-switch` en SM8750 → no existe "arreglo de referencia" que copiar |
| Parches del kernel (árbol PC) | Nosotros 124 vs sus 66; de USB/WiFi/PCIe/IOMMU **no nos falta ninguno** suyo |
| Config del kernel | Coincide (TYPEC/UCSI/DWC3/QMP/PHY/MUX/SMMU/PCIe/MHI) |
| Firmware ath12k WCN7860 | **Idéntico** al base (md5 iguales) y a ROCKNIX (sin cambios desde sep-2026) |
| Regla udev `60-ath12k-iommu-fq.rules` (Valve, DMA-FQ) | `.desactivado` desde **3-oct 19:23** → **nunca ha estado activa** → **NO es la causa** |
| ABL | ROCKNIX 1.8, igual en todas las distros → descartado (ver BATTERY-ISSUE.md) |
| Hardware de la consola | **Android arranca sin SD** → la consola está **sana** ✓ |
| ArmadaOS | No reportan nuestro fallo de arranque. **SÍ tienen abierto el #658 "Ethernet not working after Odin 3 sleep"** → el problema USB/ethernet es **compartido** |

## 2. CAUSA CANDIDATA DEL WIFI (pendiente de confirmar)
Commit **d570cc8 (6-oct)** "build(kernel): 7.2.9 … **keep Wi-Fi PMU rails on**":
`regulator-always-on` en **4 rieles del PMU del WCN7860** — `vreg_s4d_0p85`, `vreg_s5f_0p85`,
`vreg_l2f_1p2`, `vreg_l3f_1p8` (de ArmadaOS PR #635 / commit d48ee0595).
El nodo del WiFi los usa como supply (`vddaon-supply=<&vreg_s4d_0p85>`, `vddio-supply=<&vreg_l3f_1p8>`).

**Traza medida (6-oct 12:47, kernel 7.2.9)**:
fw carga OK (0x10048fe1) → **MAC generada al azar** → `WMI_SCAN_CHAN_LIST` falla → `-108` (ESHUTDOWN)
→ `arm-smmu 15000000.iommu: Unhandled context fault: iova=0xffc00000 cbfrsynra=0x1401 cb=11` → Oops.

## 3. HALLAZGOS QUE EXPLICAN LA "CEGUERA" (clave)
1. **El diario NO persiste**: `/var/log` del subvol `@` está vacío y `@var-log/journal` solo llega
   al **6-oct** → los arranques del 7 y 8 **no se guardan** → por eso nunca vimos trazas.
2. **El cmdline manda la consola al SERIAL** (`console=ttyMSM0`) → la pantalla no muestra nada
   → de ahí "logo congelado + cursor". **Arreglado añadiendo `console=tty0`**.
3. El cmdline real sale de **`devices/sm8750/profile.conf`** (NO del `kernel-cmdline` del BSP).

## 4. REGLAS DE ORO (aprendidas hoy a base de golpes)
- El cmdline se edita en `devices/sm8750/profile.conf` (el del BSP **no** afecta al kernel).
- Build SIEMPRE: `JOBS=14 DEVICE=sm8750 ./scripts/build-kernel.sh`
  (**sin `DEVICE=sm8750` compila sm8550 por defecto** ✗).
- Tras copiar `KERNEL` a la SD: **actualizar `KERNEL.md5`** (`cd /mnt/rock && md5sum KERNEL > KERNEL.md5`)
  → la Odin **valida** ese checksum.
- Emparejar dispositivos **por etiqueta**: `blkid -L ROCKNIX` / `blkid -L POCKNIX_ROOT` (los `/dev/sdX` cambian).
- La partición **FAT se daña** si el lector se desconecta en seco → `fsck.vfat -a`.
- **UN cambio por prueba** y verificar (hoy se cambiaron dos cosas a la vez y no supimos cuál rompió).

## 5. CAMBIOS APLICADOS HOY
**En el árbol `pocknix-os`:**
- `kernel/sm8750/dts/qcom/cq8725s-ayn-common.dtsi`: quitadas las 4 `regulator-always-on` del PMU del WCN.
  → Se probó 1 vez y **no arrancó** (¿los rieles? ¿el cmdline? sin logs no se supo) → se restauró el
  KERNEL del 1-oct en la SD. **El árbol sigue sin ellas.**
- `devices/sm8750/profile.conf`: **añadido `console=tty0`** (+ pruebas con `oops=panic` fuera).
- `devices/sm8750/packages/pocknix-bsp-sm8750/kernel-cmdline`: editado **por error** (no afecta al
  kernel) → **revertir**.

**En la SD:**
- `KERNEL`: backups en `KERNEL.bak-*` (11) + `KERNEL.md5` regenerado ✓
- `/etc/modprobe.d/99-no-ath12k-recuperacion.conf` (blacklist `ath12k`+`ath12k_wifi7`) → **presente** = arranque seguro
- `/etc/udev/rules.d/60-ath12k-iommu-fq.rules.desactivado`
- FAT reparada con `fsck.vfat -a` (dirty bit + sector de arranque)
- OJO: en la SD `rocknix_abl` es un **fichero** (en ROCKNIX es una **carpeta** con `abl_a/abl_b`) → comparar

## 6. ESTADO ACTUAL Y SIGUIENTES PASOS
1. SD lista con **`console=tty0`** + `KERNEL.md5` correcto + blacklist → **al arrancar, los mensajes salen EN PANTALLA**.
2. Si **arranca**: quitar el blacklist y probar el WiFi.
3. Si **no arranca**: leer los mensajes de la pantalla (foto) → ahí estará la causa.
4. Pendientes: comparar/reponer `rocknix_abl` desde `ROCKNIX-SM8750.img.gz`; arreglar la persistencia
   del diario; comentar en ArmadaOS #658; reportar a ROCKNIX.
