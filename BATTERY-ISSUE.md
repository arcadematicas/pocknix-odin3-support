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
