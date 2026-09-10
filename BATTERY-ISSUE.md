# Batería · reporte erróneo de capacidad en Pocknix (Odin 3)

**Síntoma**: Pocknix reportaba ~48 % de batería mientras Android mostraba ~96 %,
con el cargador enchufado (Pocknix: "discharging", Android: cargando).

## Diagnóstico (conclusión)

El fuel gauge del Odin 3 **no corre en el kernel**: corre en el firmware ADSP
(`pmic_glink` → `qcom_battmgr`). El porcentaje llega **directo del firmware**,
no se calcula en Linux:

- `drivers/power/supply/qcom_battmgr.c` — para la familia SM8350/SM8550 (que el
  Odin usa vía el compatible de fallback `qcom,sm8550-pmic-glink`), el percent
  es `resp->intval.value / 100`, valor que manda el firmware ADSP (~línea 1420).
  El contador de culombios (`charge_counter`) que se ve en sysfs es un dato del
  firmware, no un cálculo del kernel.

Evidencias en la Odin (`/sys/class/power_supply/battery/`):
- `MODEL_NAME=Debug_Board` → el fuel gauge **no tiene perfil de batería** cargado
  (por eso no integra corriente de forma fiable).
- `CAPACITY=41`, `charge_counter=2096201` (≈2096 mAh) vs `charge_full=4296457`
  (≈4296 mAh) → el contador está ~2× por debajo de lo real.
- `VOLTAGE_NOW=4302101` (4.30 V) → la batería está **casi llena** (contradice el
  41 %).
- `STATUS=Discharging` y el PMIC no aplica carga: `qcom-battmgr-usb ONLINE=0`
  mientras `ucsi` ve el cargador (PD, 3 A). El cargador no carga.
- Límite de carga activo (heredado de Android): `CHARGE_CONTROL_START_THRESHOLD=70`,
  `CHARGE_CONTROL_END_THRESHOLD=80` (carga limitada 70–80 %).
- `adsp.mbn` verificado **idéntico** al de la partición de firmware
  (md5 `a1206f38ff5940336c7ba511db80890f`) — el bug no es del firmware instalado.
- Sin perfil de batería en `persist` (montada sda5) ni en
  `/lib/firmware/qcom/sm8750/ayn/odin3/` (`battmgr.jsn` solo trae config PDR).

**Causa raíz**: el contador de culombios del firmware ADSP está **descalibrado**
(probablemente por el perfil `Debug_Board` sin parámetros de batería). El kernel
solo reenvía lo que el firmware reporta, así que ningún fix en Linux puede
corregir el porcentaje mientras el firmware mande un valor malo.

## Limpieza aplicada

El servicio `odin3-display.service` (el que fuerza el display en cada boot)
tenía dos líneas **peligrosas e inexistentes** heredadas de un experimento:

```sh
echo 1 > /sys/class/power_supply/battery/calibrate
echo 1 > /sys/class/power_supply/battery/reset
```

Esos nodos **no existen** en sysfs; de existir, un `1` en `calibrate`/`reset`
podría disparar una recalibración o reset del fuel gauge en caliente. Se
eliminaron. Copia limpia en `config/odin3-display.service.clean`.

> Nota: el servicio sigue fallando con `status=1` porque los bucles finales
> `for mod in ...; do modprobe 2>/dev/null; done` no usan `$mod` (llaman a
> `modprobe` sin argumento). No afecta a lo importante (el `echo on` /
> `brightness` ya corrieron antes), pero está pendiente de limpiar.

## Solución (pendiente de validar)

Un ciclo completo de carga en Android para que el fuel gauge del ADSP se
recalibre:

1. En Android, descargar la batería hasta el apagado.
2. Cargar apagada hasta el 100 % (sin encenderla).
3. Arrancar Android y confirmar que reporta 100 %.
4. Volver a Pocknix y comprobar que el porcentaje cuadra.

Si tras el ciclo Android sigue bien pero Pocknix no, el problema estaría en cómo
el firmware expone el percent vía `pmic_glink` y habría que mirar el
`battmgr.jsn` / la config PDR del ADSP.

## Referencia

- Código: `qcom_battmgr.c` (percent firmware ~L1420, charge_count ~L1444).
- Ficheros en la Odin: `/lib/firmware/qcom/sm8750/ayn/odin3/{adsp.mbn,battmgr.jsn}`,
  `persist` (sda5), `/sys/class/power_supply/{battery,qcom-battmgr-usb,...}`.

---

## ACTUALIZACIÓN 10/09/2026 — INVESTIGACIÓN EXHAUSTIVA COMPLETADA (problema NO resuelto)

### Resumen ejecutivo
**Pocknix NO carga la batería en Linux. ROCKNIX (7.1.3 y 7.2.0) SÍ carga en el MISMO hardware (verificado en vivo).** Tras semanas de investigación comparativa, el problema sigue sin resolver. Todo lo que se podía comparar desde fuera es idéntico o fue probado sin éxito.

### Lo que se probó y se DESCARTÓ (todo verificado empíricamente)

| Hipótesis | Prueba | Resultado |
|---|---|---|
| Config del kernel | Diff completo ROCKNIX vs Pocknix (95 diffs, casi todos flags de compilador) | ❌ No es la causa |
| Parches 0078/0079/0080 (nuestros) | Kernel compilado SIN ellos (63 parches, idéntico a ROCKNIX) | ❌ Sigue sin cargar |
| Firmware ADSP | adsp.mbn de ROCKNIX 7.2.0 (md5 f82212a2, 21.9MB) probado en Pocknix | ❌ No arregla |
| battmgr.jsn | Comparado byte a byte con ROCKNIX 7.2.0 | ✅ IDÉNTICO |
| Compilador | Kernel recompilado con GCC 15.2.0 (el de ROCKNIX) | ❌ Sigue sin cargar |
| Módulo battmgr | El .ko de ROCKNIX no carga (struct module size mismatch); el stock recompilado tampoco carga | ❌ No es el módulo |
| Versión del kernel | 7.2.0 y 7.2.4 (el más reciente) probados | ❌ Ambos sin carga |
| Cmdline | Comparado — solo difieren root/console, nada de typec/usb | ❌ No es la causa |
| DTS/DTB | Mismos parches (0046/0047 Odin3), misma estructura | ❌ No es la causa |
| Scripts userspace | ROCKNIX no tiene scripts de carga (todo es kernel/firmware) | ❌ No existe tal cosa |
| ABL (bootloader) | El mismo en todas las distros (1.8 de ROCKNIX) | ❌ No es la causa |

### Síntomas clave medidos en vivo

**ROCKNIX (carga ✅):**
- `battmgr-usb online=1`, `status=Charging`, corriente positiva (+198mA)
- Negocia PD **9V/3A** (`voltage_max=9000000`, `current_max=3000000`)
- Al conectar el cargador: ucsi online=1 a los ~16s, battmgr online=1 a los ~18s (el battmgr aprende del UCSI con delay)

**Pocknix (no carga ❌):**
- `battmgr-usb online=0` SIEMPRE, `status=Discharging`, corriente negativa (-500mA)
- Se queda en **5V** (`voltage_max=5000000`, `current_max=4500000` — el default del hardware)
- `ucsi-source-psy online=1` y `current=1.25A` (ve el cargador) PERO la batería NO sube (la energía no llega a la batería)
- `ucsi voltage_max=0` (la negociación PD NO se completa)

### Mecanismo de carga (entendido)
El firmware ADSP envía `BATTMGR_BAT_STATUS` con `charging_source`. Si `source=USB` → `battmgr.usb.online=1` (línea 1326 de qcom_battmgr.c). En Pocknix el firmware **nunca reporta USB como fuente** — aunque el UCSI ve el cargador. La energía entra al sistema (1.25A) pero el firmware no la dirige a la batería.

### Conclusión / hipótesis restante
La diferencia está en **cómo el entorno de arranque inicializa el pmic-glink** (el canal de comunicación kernel↔firmware ADSP). ROCKNIX y Pocknix arrancan el mismo kernel de forma distinta (initramfs/orden de módulos). Sin acceso a debug hardware (JTAG/serial), no podemos ver qué ocurre en ese momento.

### Para retomar
1. Comparar el initramfs de ROCKNIX vs Pocknix (cómo cargan los módulos del pmic-glink)
2. Probar el orden de carga de módulos (battmgr antes/después del ucsi)
3. Debug serial/JTAG del arranque para ver la negociación PD

---

## ACTUALIZACIÓN 10/09/2026 TARDE — PISTA NUEVA (issue #402 ArmadaOS)

### Issue #402 de ArmadaOS (creado por nosotros)
https://github.com/armada-os/armada/issues/402

**Título**: "AYN Odin 3 (SM8750): battery never charges under Linux - charger_pd PDR stays DOWN"

### Dato clave NUEVO
dmesg muestra: `PDR: Indication received from msm/adsp/charger_pd, state: 0x1fffffff`
→ El **charger_pd PDR service NUNCA sube** en Linux.

### Hipótesis refinada
En Android, `qti_battery_charger` (driver del vendor) registra como cliente pmic_glink y **algo en ese flujo sube charger_pd**. Mainline `qcom_battmgr` se registra pero **no sube charger_pd**.

### Probado sin éxito (documentado en el issue)
1. charge_behaviour patch (USB_PROPERTY_SET 0x33 + USB_CHARGE_ENABLE 14, como ROCKNIX PR #2840) — el sysfs existe pero no activa carga
2. Opcode 0x16 (del qti_battery_charger de Android) — el firmware lo acepta pero no carga
3. PMIC_RTR_ADSP_APPS.driver_data = false (saltar espera PDR) — charger_pd sigue DOWN
4. UCSI role fix (0509) — ya incluido

### Confirmado
- Kernel pmic_glink.c IDÉNTICO entre 7.2.0 y 7.2.4 → el kernel NO es la diferencia
- Android carga con el MISMO adsp.mbn → el firmware SÍ puede cargar
- ArmadaOS usa kernel stable (armada-os/linux, sin parches odin3) → no sirve directamente
- MasOS: no encontrado en GitHub (buscar en Discord AYN/Armada)

### Siguiente paso
Comparar cómo ROCKNIX inicializa el pmic-glink en el arranque vs Pocknix (entorno de arranque, no kernel).
