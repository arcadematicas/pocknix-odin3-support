# ath12k en el Odin 3: el arreglo de Valve para el WiFi (IOMMU DMA-FQ)

Traído el arreglo de Valve para **ath12k** (WiFi del Odin 3) y adaptado a nuestro
hardware. Documentado aquí qué hace, cómo se activa y **cómo se revierte**.

> 🔴 **CORRECCIÓN IMPORTANTE — nuestras notas decían `ath11k`, y es FALSO.**
> El WiFi del Odin 3 usa **`ath12k`**, no `ath11k`. Verificado en la Odin el
> 2026-10-03. Esa nota falsa nos hizo dar por hecho que todo el trabajo de Valve
> sobre ath12k no nos aplicaba (ver §6).

---

## 1. Origen

`steamos-customizations-deckard`, release **`20261002.1`**:

- Commit **`a8a2a8faaeed54c18827fdbab8ce3ee2ab61a0fe`** — *Address poor ath12k
  performance during multi-link streaming* (Elliot Saba, Valve, 2026-10-02).
- Ficheros: `misc/rules.d/60-ath12k-iommu-fq.rules` y
  `misc/system-sleep/ath12k-irq-respread.sh`.

Trae **dos** mitigaciones **independientes** para lo que Valve vio haciendo
streaming multi-enlace:

1. Tras un suspend/resume, **todos los IRQ de ath12k se migran a CPU0** (deep
   suspend desconecta las CPUs 1-7, y al volver solo se recolocan los IRQ
   *gestionados*, no los MSI libres como los de ath12k). → hook de systemd.
2. **`NET_RX` tarda demasiado** porque usamos **IOMMU DMA estricto**, que obliga
   a un **sync completo de la TLB de la SMMU tras cada IRQ**. → regla de udev.

---

## 2. La pieza que SÍ trae gains: regla udev `60-ath12k-iommu-fq.rules`

### Qué hace

Con `CONFIG_IOMMU_DEFAULT_DMA_STRICT=y`, **cada unmap del buffer de RX** del WiFi
hace un **sync síncrono de la TLB de la SMMU con las IRQs apagadas**. Valve midió
que eso eran **~32% de las muestras de `NET_RX`**. El coste es tiempo de CPU en el
softirq de recepción de red.

Cambiar el grupo IOMMU a **`DMA-FQ`** hace que esos unmap se **encolen**:
un solo flush por cada **256 unmap y por CPU**, o cada **10 ms**. Valve midió
**~30% más rápido el softirq `NET_RX`** en el Deckard.

### El trade-off (es el del propio comentario de Valve, no inventado aquí)

Hasta que llega ese flush, el dispositivo todavía puede alcanzar páginas
**recientemente desmapeadas**, que para entonces el kernel ya puede haber
reutilizado. Es decir: un bug de *write-after-unmap* corrompería memoria
**en silencio** en vez de levantar un fallo de SMMU. Valve lo considera
aceptable porque ath12k no les está dando fallos de SMMU de todos modos.

`DMA` → `DMA-FQ` **se permite en caliente**, con el driver bindeado o no
(`drivers/iommu/iommu.c:3111`). **Volver a estricto** exige un unbind del driver
o reiniciar sin la regla.

### La adaptación: el ID del dispositivo

El único cambio respecto al original de Valve es el **ID de dispositivo**:

| | vendor | device |
|---|---|---|
| Valve / Steam Frame–Deckard | `0x17cb` | **`0x1107`** |
| **Odin 3 (el nuestro)** | `0x17cb` | **`0x110e`** |

Con el `0x1107` de Valve la regla **no habría hecho match** y el arreglo no
habría llegado a aplicarse. Comprobado (§4).

---

## 3. Verificado en la Odin (2026-10-03)

Todo lo de esta tabla está **medido**, no deducido.

```
$ lspci -nn | grep -i network
01:00.0 Network controller [0280]: Qualcomm Technologies, Inc Device [17cb:110e] (rev 01)

$ cat /sys/bus/pci/devices/0000:01:00.0/vendor   /sys/bus/pci/devices/0000:01:00.0/device
0x17cb
0x110e

$ lsmod | grep ath
ath12k_wifi7           98304  0
ath12k                499712  1 ath12k_wifi7

$ cat /sys/bus/pci/devices/0000:01:00.0/iommu_group/type
DMA                          <-- estricto: el problema del §2 ESTÁ presente

$ zgrep IOMMU_DEFAULT /proc/config.gz
CONFIG_IOMMU_DEFAULT_DMA_STRICT=y
# CONFIG_IOMMU_DEFAULT_DMA_LAZY is not set

$ cat /sys/power/mem_sleep
[s2idle] deep                 <-- lo activo es s2idle (ver §5)

$ cat /proc/cmdline | tr ' ' '\n' | grep -E 'irqaffinity|mem_sleep'
irqaffinity=0-1
mem_sleep_default=s2idle
```

Conclusión: **la precondición de Valve se cumple entera** (IOMMU estricto + ath12k
en el sitio) → **el arreglo nos aplica y merece la pena**.

### Ojo: el grupo IOMMU no es solo del WiFi

```
$ ls /sys/bus/pci/devices/0000:01:00.0/iommu_group/devices/
0000:00:00.0    (class 0x060400 = puente PCI)
0000:01:00.0    (el WiFi)
```

El atributo se escribe a nivel de **grupo**, así que el puente PCIe `00:00.0`
comparte el modo. Es inherente al mecanismo (igual en el Deckard de Valve), no es
algo que introduzcamos nosotros. En la Odin el puente no hace DMA de datos, así que
el riesgo añadido es mínimo, pero **no es un atributo exclusivo del WiFi**.

### Los IRQ del WiFi

**15** MSI, no 16 (el agente anterior contó 16):

```
$ grep -c "ITS-PCI-MSI-0000:01:00.0" /proc/interrupts
15                                    (IRQ 231-245)
$ grep -c "ITS-PCI-MSI" /proc/interrupts
16                                    (+ IRQ 223 = ITS-PCI-MSI-0000:00:00.0, "PCIe PME, aerdrv, PCIe bwctrl" = el puente, NO el WiFi)
```

---

## 4. Aplicado en la Odin, con backup y validado

### Backup

```
/etc/udev/rules.d.bak-ath12k-20261003-192332
```

`cp -a` de `/etc/udev/rules.d` **antes** de instalar nada. El fichero
`60-ath12k-iommu-fq.rules` **no existía antes** (no se sobrescribió nada). La
ruta del backup quedó además anotada en
`/run/pocknix-ath12k-backup-path` en la Odin.

### Instalado

```
/etc/udev/rules.d/60-ath12k-iommu-fq.rules     root:root 0644
```

Mismo nombre y numeración (`60-…`) que la regla de Valve y coherente con las que
ya había ahí (`60-input-id2-odin3-gamepad.rules.desactivado`,
`61-gpio-paddles-no-joystick.rules`).

### Validación — salida real

Sintaxis:

```
$ udevadm verify /etc/udev/rules.d/60-ath12k-iommu-fq.rules

1 udev rules files have been checked.
  Success: 1
  Fail:    0
verify exit=0
```

**Que hace match** (`udevadm test` no escribe nada, solo simula):

```
$ udevadm test --action=add /sys/bus/pci/devices/0000:01:00.0

Reading rules file: /etc/udev/rules.d/60-ath12k-iommu-fq.rules
0000:01:00.0: /etc/udev/rules.d/60-ath12k-iommu-fq.rules:26 ATTR{iommu_group/type}="DMA-FQ":
  Running in test mode, skipping writing "DMA-FQ" to sysfs attribute
  "../../../../../../../kernel/iommu_groups/12/type".
  ../../../../../../../kernel/iommu_groups/12/type : DMA-FQ
```

Traducción: la regla casa con `0000:01:00.0` y el atributo que resolved es
`kernel/iommu_groups/12/type`. `udevadm test` **no** escribe, así que el valor
real **sigue siendo `DMA`** (comprobado) — **nada se ha tocado en caliente**.

**Prueba negativa** (por qué el cambio de ID era obligatorio). Se cargó la regla
**original de Valve** (`0x1107`) con `--extra-rules-dir` y se testeó el mismo
dispositivo:

```
$ udevadm test --action=add --extra-rules-dir=/tmp/udev-valve-original /sys/bus/pci/devices/0000:01:00.0

Reading rules file: /tmp/udev-valve-original/60-valve-original.rules
0000:01:00.0: /etc/udev/rules.d/60-ath12k-iommu-fq.rules:26 ATTR{iommu_group/type}="DMA-FQ": ...
```

La regla de Valve (`0x1107`) **aparece leída pero NO produce ninguna línea de
match**; la única que casa es la nuestra con `0x110e`. **Adaptar el ID no era un
detalle, era la condición de que esto funcionara.**

### Cómo se activa

**Reiniciar.** La regla es `ACTION=="add"`, así que solo corre al añadir el
dispositivo, que en la práctica es en el arranque. Después del reinicio se
comprueba con:

```
cat /sys/bus/pci/devices/0000:01:00.0/iommu_group/type     # debe decir DMA-FQ
```

> ⚠️ **No reiniciar sin avisar.** Fransis está usando la Odin. Y **no hacer
> unbind/rebind de `ath12k` por SSH** (cortaría la conexión).

### Cómo se revierte

Opción A — solo quitar la regla y reiniciar (lo limpio):

```bash
sudo rm /etc/udev/rules.d/60-ath12k-iommu-fq.rules
sudo reboot
# vuelve a CONFIG_IOMMU_DEFAULT_DMA_STRICT → iommu_group/type = DMA
```

Opción B — dejar la regla pero volver a estricto **sin** esperar al próximo
arranque. **OJO: el propio Valve avisa de que DMA-FQ → DMA en caliente NO está
permitido**; en la práctica `echo DMA >` puede ser rechazado por el kernel
(`-EINVAL`), y el único camino soportado sería el unbind del driver, que aquí no
se hace por SSH porque tumba la conexión:

```bash
sudo sh -c 'echo DMA > /sys/bus/pci/devices/0000:01:00.0/iommu_group/type'
```

En el centro, revertir es quitar el fichero de
`overlay/etc/udev/rules.d/` y reconstruir la imagen.

---

## 5. La otra pieza: `ath12k-irq-respread.sh` — evaluada y **NO instalada**

Valve trae un hook de systemd (`pre`/`post` suspend) que guarda la CPU efectiva de
cada IRQ `ITS-PCI-MSI` antes de dormir y la **restaura** después, porque deep
suspend desconecta las CPUs 1-7 y al volver todos los IRQ se quedan en CPU0.

En el Odin **no aporta nada**:

1. **La Odin no usa deep suspend.** `/sys/power/mem_sleep` = `[s2idle] deep` →
   lo activo es **`s2idle`**, y el cmdline lo fija
   (`mem_sleep_default=s2idle`, `devices/sm8750/profile.conf`). En **s2idle las
   CPUs no se desconectan**, así que la premisa del hook (hot-unplug de CPUs →
   migración masiva a CPU0) **no ocurre**. Verificado: `/sys/devices/system/cpu/online` = `0-7`.
2. **`irqaffinity=0-1`.** Solo CPU0 y CPU1 entran en la máscara de afinidad de
   IRQ, así que el margen de mejora es de 2 CPUs a 1.
3. **Hoy ya están repartidos.** Medido: los 15 IRQ del WiFi están alternando
   entre CPU0 y CPU1 (`effective_affinity_list` = 1,1,0,1,0,1,0,0,1,1,0,1,0,1,0).
   No hay "todo en CPU0" que redistribuir.

**Decisión: no se instala.** Añadir un hook de suspend y un fichero de estado en
`/run` para arreglar un problema que aquí no se da no está justificado. Si algún
día se cambia a `deep`, o si tras un `deep` se mide que todo cae en CPU0, se
reinstala (el fichero está en el commit de Valve, línea por línea).

> Nota aparte, por si algún día se usa: el `MATCH='ITS-PCI-MSI'` por defecto de
> Valve matchea **todos** los MSI del GIC ITS, y en la Odin eso incluye el IRQ 223
> del puente PCIe `00:00.0`, que no es ath12k. Si se instalara, habría que
> restringirlo a `ITS-PCI-MSI-0000:01:00.0`.

---

## 6. La corrección: ath12k, NO ath11k

Nuestras notas decían *"nuestro WiFi WCN7860 = ath11k"* y de ahí se concluyo que
**el trabajo de Valve sobre ath12k no nos aplicaba**. Es falso, y era una razón
directa para que este arreglo no se hubiera traído.

| | Valor real |
|---|---|
| Driver | **`ath12k`** (`ath12k_wifi7`, sobre `ath12k`) |
| PCI ID | **`[17cb:110e]`** |
| Chip | WCN7860 (sigue siendo cierto) |

Lo que **sí** era cierto de esa nota, y se conserva: el `ath12k.conf` de Valve
sigue sin ser directamente aplicable (es del Frame/Deckard), y la batería nuestra
va por ADSP/pmic_glink, no por `max1720x_battery`. Lo que estaba **mal** era el
**driver**: por el `ath11k` se descartaron los paquetes de Valve que **sí** nos
aplican, como este arreglo del IOMMU.

Añadida la corrección con fecha en `~/.opencode_memory.md` (en los dos sitios que
la repetían), **sin borrar el texto original**.

---

## 7. Dónde vive en el centro

```
overlay/etc/udev/rules.d/60-ath12k-iommu-fq.rules
```

Se sincroniza sola al árbol de build: `tools/sync-to-os.sh` copia `overlay`
entero (`overlay "overlay" "overlay"`), y los ficheros nuevos se añaden (el
`rsync` va **sin `--delete`**). Con esto, **la imagen lo llevará de serie** al
reiniciar que haga Fransis.

## 8. Lo que NO se ha hecho ni verificado

- **No se ha reiniciado la Odin**, así que la regla **todavía no está activa en
  ejecución**: `iommu_group/type` sigue diciendo `DMA`. Se activa en el próximo
  reinicio.
- **No se ha medido la mejora real en el Odin.** Los "~32% de las muestras de
  NET_RX" y el "~30% más rápido" son **medidas de Valve en el Deckard**; aquí no
  se han reproducido. Habría que comparar `perf`/softirq antes y después.
- **No se ha probado en uso real** (streaming, descarga) con DMA-FQ activo.
- **No se ha instalado** el hook de IRQ (§5), y por tanto no verificado nada de él.
- **No se ha tocado** el grupo IOMMU del puente `00:00.0` más que el inevitable
  efecto de grupo; no se ha medido si eso afecta a otra cosa.
- La sincronización al árbol de build (`pocknix-os`) y la reconstrucción de
  imagen **no se han hecho** en esta sesión.