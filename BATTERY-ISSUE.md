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

## ACTUALIZACIÓN 10/09/2026 TARDE — issue #402 ArmadaOS (premisa CORREGIDA 10/09/2026 noche)

### Issue #402 de ArmadaOS (creado por nosotros)
https://github.com/armada-os/armada/issues/402

**Título original**: "AYN Odin 3 (SM8750): battery never charges under Linux - charger_pd PDR stays DOWN"

### ⚠️ CORRECCIÓN IMPORTANTE: el PDR NO está DOWN, está UP

Se interpretó mal el valor del dmesg. En el kernel:

```
include/linux/soc/qcom/pdr.h
  SERVREG_SERVICE_STATE_DOWN       = 0x0FFFFFFF
  SERVREG_SERVICE_STATE_UP         = 0x1FFFFFFF   ← ¡esto es 0x1fffffff!
  SERVREG_SERVICE_STATE_EARLY_DOWN = 0x2FFFFFFF
  SERVREG_SERVICE_STATE_UNINIT     = 0x7FFFFFFF
```

Y `qcom_battmgr_pdr_notify()` (qcom_battmgr.c L1781) hace:

```c
if (state == SERVREG_SERVICE_STATE_UP) {
        battmgr->service_up = true;
        schedule_work(&battmgr->enable_work);
        schedule_delayed_work(&battmgr->poll_work, 30 * HZ);
}
```

Por tanto, `state: 0x1fffffff` = **UP** → `service_up=true` y el polling del battmgr SÍ corre.
**El canal kernel↔firmware ADSP (pmic-glink/PDR) funciona correctamente.** La hipótesis
"charger_pd PDR nunca sube" es FALSA y hay que descartarla (y corregir el issue #402).

### Conclusión revisada
El kernel habla bien con el firmware. El problema es que el **firmware ADSP no reporta
USB como `charging_source`** (battmgr-usb online=0 aunque el UCSI ve el cargador). La
diferencia con ROCKNIX (que sí carga) NO está en el kernel, parches, config, cmdline,
DTB, firmware adsp.mbn, battmgr.jsn, compilador, ABL ni scripts userspace (todo probado).

### Probado sin éxito (documentado en el issue)
1. charge_behaviour patch (USB_PROPERTY_SET 0x33 + USB_CHARGE_ENABLE 14, como ROCKNIX PR #2840) — el sysfs existe pero no activa carga
2. Opcode 0x16 (del qti_battery_charger de Android) — el firmware lo acepta pero no carga
3. PMIC_RTR_ADSP_APPS.driver_data = false (saltar espera PDR) — irrelevante: el PDR sí sube
4. UCSI role fix (0509) — ya incluido

### Confirmado
- Kernel pmic_glink.c IDÉNTICO entre 7.2.0 y 7.2.4 → el kernel NO es la diferencia
- Android carga con el MISMO adsp.mbn → el firmware SÍ puede cargar
- ArmadaOS usa kernel stable (armada-os/linux, sin parches odin3) → no sirve directamente
- Lista de parches ROCKNIX SM8750 vs Pocknix: idéntica salvo 0055/0062 (backlight) y nuestros 0078/0079/0080
- Cmdline ROCKNIX SM8750: `rootwait quiet video=efifb:off console=tty0 irqaffinity=0-1 cgroup.memory=nokmem,nosocket nosoftlockup` (= base de Pocknix; sin nada de typec/usb)

## HERRAMIENTA DE DIAGNÓSTICO NUEVA — `pmic_pdcharger_ulog` (10/09/2026 noche)

**Hallazgo**: Pocknix NO compila el módulo que expone el **log interno del firmware del
cargador (ADSP)**. ArmadaOS/ROCKNIX sí lo traen.

- Pocknix `.config`: `# CONFIG_QCOM_PMIC_PDCHARGER_ULOG is not set` (no compilado)
- ArmadaOS: `CONFIG_QCOM_PMIC_PDCHARGER_ULOG=m` (`pmic_pdcharger_ulog.ko` presente)
- Driver: `drivers/soc/qcom/pmic_pdcharger_ulog.c` (solo debug, se carga a mano).
  Se suscribe al canal rpmsg **`PMIC_LOGS_ADSP_APPS`** y descarga el log del firmware
  del cargador (opcode GET_CHG_ULOG_REQ=0x18, owner 32778). Lo publica como tracepoint
  `pmic_pdcharger_ulog_msg` (tracefs).
- Uso (adaptado del script de ArmadaOS `armada-charge-debug`):
  ```sh
  modprobe pmic_pdcharger_ulog
  # (NO descargar el módulo: modprobe -r se cuelga en D en el teardown de GLINK)
  echo 1 > /sys/kernel/tracing/events/pmic_pdcharger_ulog/enable
  sleep 20; cat /sys/kernel/tracing/trace
  ```
  Si el canal no existe, el log dirá `ulog=channel-absent` (el firmware no expone PMIC_LOGS_ADSP_APPS).

**Por qué importa**: es la única vía para ver **la decisión interna del firmware** (por qué
no activa la carga / no reporta USB), sin JTAG ni debug serial. Siguiente paso: compilar el
kernel 7.2.4 con `CONFIG_QCOM_PMIC_PDCHARGER_ULOG=m` y leer ese log en la Odin.

### Nota entorno de arranque
- ArmadaOS = Fedora bootc + initramfs **dracut** (`--no-hostonly`, 645 módulos dentro, incluye pmic_pdcharger_ulog.ko).
- Pocknix = **sin initramfs** (kernel monta root directo).

---

## 🎯 CAUSA RAÍZ ENCONTRADA (10/09/2026 noche) — el firmware está en TEST MODE

Tras habilitar `CONFIG_QCOM_PMIC_PDCHARGER_ULOG=m` y leer el **log interno del firmware
del cargador** (canal `PMIC_LOGS_ADSP_APPS`), el firmware revela:

```
Warn: battmngr_plat_scpqchg_qbg_r1_check_state_change::WARNING::Test mode
Info: battmngr_plat_scpqchg_qbg_r1_check_state_change::Change state to 0 from 9
Info: BattMngrStateMachineLevel_Change_State::Cannot change state since current state is test
```

El **BattMngrStateMachine está atascado en el estado 9 (TEST)** y se niega a cambiar.
Tabla de estados (del `.tmf` de símbolos `qcbattmngr850.pdb`):
`0 ENTRY · 1 NO_CHG · 2 FAST · 3 TOP_OFF · 4 DONE · 5 RECHARGE · 6 TDONE · 7 NOT_CHARGING_THERMAL · 8 ERROR · 9 TEST`

### Por qué entra en TEST MODE
Strings del propio firmware:
```
Warn: ..._batt_err_handle_action_enable_test_mode:: Put the system in test mode
```
Lo dispara un **error de batería** (`batt_err_handle_action`). El handler de errores tiene
3 acciones: `get_batt_st` (re-plugin/plug-out battery), `err_shutdown`, `emergency_shutdown`,
`enable_test_mode`. Los disparadores que aparecen en el firmware:

```
..._check_for_error::Battery ID is invalid
..._init::BattMngrTech_QBG_R1_Get_Battery_ID failed, cell_id=%d batt_id=%d status=0x%X
..._charger_config:: disable charging if battery is un-authenticated and unAuthChargingAction = 0
..._batt_auth_check:: Batt authentication failed
..._batt_auth_check:: Batt authentication times out after %d s
..._get_dev_cfg::BattAuthEn = %d, en_bsi_chip = %d, battAuthCOmms = %d, battAuthUidLen = %d, unAuthChargingAction = %d
Info: override BattAuthData.enable to %d
Info: override BattAuthData.unAuthChargingAction to %d
```

**Hipótesis fuerte**: en Linux la **autenticación de batería falla/timeout** (o el `batt_id`
se lee inválido) y el handler de error mete el sistema en test mode. Android/vendor driver
sobreescribe `BattAuthData` (`enable` / `unAuthChargingAction`) y por eso sí carga.
El modelo reportado por el firmware es `Debug_Board` (perfil de batería de debug), coherente
con "no hay perfil/autenticación válida de la batería real".

### Cómo se capturó (reproducible)
```sh
modprobe pmic_pdcharger_ulog    # (no descargar: cuelga el teardown de GLINK)
echo 1 > /sys/kernel/tracing/instances/<inst>/events/pmic_pdcharger_ulog/enable
cat /sys/kernel/tracing/instances/<inst>/trace
```
También hay un servicio de arranque: `/usr/local/bin/odin-ulog-boot.sh` +
`odin-ulog-boot.service` (vuelca el log a `/var/log/odin-ulog-boot-NN.txt` cada 5s).
El log capturado más temprano (15s) ya muestra test mode → se entra **en el arranque del ADSP**,
antes de que el AP cargue el módulo.

### Corrección de un dato previo
El `adsp.mbn` de ROCKNIX (21.9MB, `f82212a2`) está en
`/lib/firmware/qcom/sm8750/ayn/odin3/`, **pero el kernel carga `qcom/sm8750/adsp.mbn`**
(`firmware-name` del DTS, 17.68MB, `a1206f38`). Por tanto **la prueba previa del firmware de
ROCKNIX fue inválida**: nunca se llegó a cargar. El firmware de ROCKNIX es la MISMA versión
(iguales strings `qcbattmngr`) pero compilada **con símbolos de debug** (de ahí los 21.9MB).

### Próximos pasos
1. Ver cómo el driver Android (`qti_battery_charger`) sobreescribe `BattAuthData` /
   desactiva la autenticación, y replicarlo (posible nuevo parche en `qcom_battmgr`).
2. Probar el `adsp.mbn` de ROCKNIX **en la ruta correcta** (`qcom/sm8750/adsp.mbn`) — barato,
   pero probablemente no cambia nada (misma versión).
3. Buscar el comando/registro que sale de test mode (`set_debug_param`, `set_ship_mode`).

---

# ✅ SOLUCIÓN ENCONTRADA Y VERIFICADA (10/09/2026 noche)

## La batería YA CARGA en Pocknix

**El fix**: usar el **`adsp_dtb.mbn` de ArmadaOS** (`d88d7ecb`) además del `adsp.mbn` correcto.
El `adsp_dtb.mbn` es la **configuración del cargador que va dentro del ADSP** e incluye la
**autenticación de batería** (`batt_auth_cfg`, `batt-auth-public-key`, `batt-unauth-charging-action`,
`en-batt-auth`...). El que traía Pocknix (`632e50f2`) NO tenía esa config → el firmware no podía
autenticar la batería → su handler de error lo metía en TEST MODE → no cargaba.

### Ficheros exactos (los de ArmadaOS, build 2026-07)
| Fichero | Tamaño | md5 |
|---|---|---|
| `adsp.mbn` | 21907848 | `6cfcbbb80b956ddad76950c038ea1a3e` |
| `adsp_dtb.mbn` | 167736 | `d88d7ecbba78ecacb13adcc7bcbe131d` |

Rutas en Pocknix (las que carga el DTS):
- `/lib/firmware/qcom/sm8750/adsp.mbn`
- `/lib/firmware/qcom/sm8750/adsp_dtb.mbn`

### Resultado verificado en la Odin
```
battery: status=Charging   current=+424207   capacity=99%
qcom-battmgr-usb: online=1  current=553000
ucsi-source-psy: status=Charging  current=3000000 (3A)
typec port0: power_role=source [sink]   → negocia y recibe energía
firmware ulog: "Test mode" = 0  → YA NO entra en test mode
```

## Cronología de cómo se llegó al fix
1. **PDR**: se creía que `charger_pd` PDR "nunca subía" (`0x1fffffff`). **FALSO**: `0x1fffffff`
   es `SERVREG_SERVICE_STATE_UP` (ver sección anterior). El canal pmic-glink funciona.
2. **Diagnóstico decisivo**: se habilitó `CONFIG_QCOM_PMIC_PDCHARGER_ULOG=m` y se leyó el log
   interno del firmware (`PMIC_LOGS_ADSP_APPS`). Reveló: **BattMngrStateMachine atascado en
   estado 9 (TEST)**, disparado por el handler de error de batería.
3. **Comparación con ArmadaOS** (que carga): su firmware NO está en test mode. Se descubrió que
   ArmadaOS carga desde `qcom/sm8750/ayn/odin3/adsp.mbn` (21.9MB, `6cfcbbb8`) + su `adsp_dtb.mbn`
   (`d88d7ecb`), mientras Pocknix cargaba `qcom/sm8750/adsp.mbn` (17.68MB, `a1206f38`) +
   `adsp_dtb.mbn` (`632e50f2`).
4. **Prueba**: copiar el `adsp.mbn` de ROCKNIX SOLO no arreglaba (faltaba el dtb). Copiar
   **los dos** ficheros de ArmadaOS → **CARGA**. 

> Nota: el `adsp.mbn` de ROCKNIX (`f82212a2`, 21891464) es la misma build con símbolos de debug;
> el de ArmadaOS (`6cfcbbb8`, 21907848) es el que se validó. La clave real es el **`adsp_dtb.mbn`**.

## Cómo hacerlo permanente (pendiente)
Incluir los dos ficheros en la imagen/build de Pocknix para `qcom/sm8750/` (el build los toma del
overlay de ROCKNIX; hay que añadir un paso que los copie/sobrescriba). Mientras tanto, basta con
tenerlos puestos en la Odin (`/lib/firmware/qcom/sm8750/`). Backups en la Odin:
`adsp.mbn.bak-linux17` y `adsp_dtb.mbn.bak-orig`.

## Lecciones
- `CONFIG_QCOM_PMIC_PDCHARGER_ULOG=m` + leer `pmic_pdcharger_ulog` es LA herramienta para depurar
  carga en Qualcomm: muestra la decisión interna del firmware.
- El `adsp_dtb.mbn` (config del ADSP) es tan importante como el `adsp.mbn` (código).
- Comparar con una distro que funciona (ArmadaOS/ROCKNIX) a nivel de firmware fue lo definitivo.
