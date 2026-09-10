# FIX: la batería carga en Pocknix (Odin 3 / SM8750)

**Resuelto y verificado el 10/09/2026.** Ver el detalle completo en
`../../BATTERY-ISSUE.md` (sección "SOLUCIÓN ENCONTRADA").

## Resumen
El firmware del cargador (ADSP) se quedaba atascado en **TEST MODE (estado 9)** porque no podía
**autenticar la batería**. La clave es el **`adsp_dtb.mbn`** (config del cargador dentro del ADSP):
el que traía Pocknix no llevaba la config de autenticación (`batt_auth_cfg`,
`batt-auth-public-key`, `batt-unauth-charging-action`, `en-batt-auth`).

## Fix (copiar 2 ficheros a `/lib/firmware/qcom/sm8750/`)
| fichero | tamaño | md5 |
|---|---|---|
| `adsp.mbn` | 21907848 | `6cfcbbb80b956ddad76950c038ea1a3e` |
| `adsp_dtb.mbn` | 167736 | `d88d7ecbba78ecacb13adcc7bcbe131d` |

```sh
# En la Odin (Pocknix):
sudo cp adsp.mbn adsp_dtb.mbn /lib/firmware/qcom/sm8750/
sync && sudo reboot
# Comprobar: cat /sys/class/power_supply/battery/status  -> Charging
```

## Cómo obtener los ficheros
Son los que usa ArmadaOS (build 2026-07). En la SD de ArmadaOS están en
`/usr/lib/firmware/qcom/sm8750/ayn/odin3/{adsp.mbn,adsp_dtb.mbn}`.
También se pueden sacar del initramfs de ArmadaOS.

## Diagnóstico (para futuros problemas de carga)
El kernel de Pocknix 7.2.4 ya compila `CONFIG_QCOM_PMIC_PDCHARGER_ULOG=m`. Con el cargador enchufado:

```sh
sudo modprobe pmic_pdcharger_ulog      # NO descargar después (cuelga el teardown de GLINK)
inst=/sys/kernel/tracing/instances/chk
sudo mkdir -p "$inst"
sudo sh -c "echo 1 > $inst/events/pmic_pdcharger_ulog/enable"
sleep 10
sudo sh -c "echo 0 > $inst/events/pmic_pdcharger_ulog/enable"
sudo cat "$inst/trace" | grep -i "test mode"   # vacío = OK
```

O usar el script: `odin-charge-ulog.sh` (mismo directorio).

Estados del BattMngr (de `qcbattmngr850.pdb`): 0 ENTRY, 1 NO_CHG, 2 FAST, 3 TOP_OFF, 4 DONE,
5 RECHARGE, 6 TDONE, 7 NOT_CHARGING_THERMAL, 8 ERROR, **9 TEST**.

## Pendiente
Hacerlo permanente en la imagen/build de Pocknix: incluir estos 2 ficheros en `qcom/sm8750/`
(por defecto el build sincroniza el firmware del overlay de ROCKNIX; hay que sobrescribirlos).
