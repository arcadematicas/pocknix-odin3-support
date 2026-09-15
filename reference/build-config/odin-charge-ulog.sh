#!/bin/bash
# odin-charge-ulog.sh — diagnostico de carga del Odin 3 (SM8750) en Pocknix
#
# Adaptado del script armada-charge-debug de ArmadaOS (GPL-2.0), reducido a lo
# que necesitamos: leer el LOG INTERNO DEL FIRMWARE DEL CARGADOR (ADSP) via el
# driver pmic_pdcharger_ulog (canal rpmsg PMIC_LOGS_ADSP_APPS, tracepoint
# pmic_pdcharger_ulog_msg). Es la unica via de ver por que el firmware no
# activa la carga sin JTAG/serial.
#
# Uso:  sudo ./odin-charge-ulog.sh [segundos]   (con el cargador enchufado)
#
# NO descargar el modulo despues (modprobe -r se cuelga en D en el teardown de
# GLINK hasta reiniciar). Se deja cargado: hace polling 1/s despierto, nada
# dormido.

set -uo pipefail

secs=${1:-20}
tracefs=/sys/kernel/tracing
instance="$tracefs/instances/odin-charge-ulog"

[[ $EUID -eq 0 ]] || { echo "Ejecutar con sudo." >&2; exit 1; }

echo "## Sistema"
echo "kernel=$(uname -r)"
echo "cmdline=$(cat /proc/cmdline)"
echo

echo "## Power supplies"
for s in /sys/class/power_supply/*; do
  [[ -r $s/uevent ]] || continue
  sed "s/^/$(basename "$s") /" "$s/uevent"
done
echo

echo "## Type-C / USB role"
for p in /sys/class/typec/*; do
  [[ -d $p ]] || continue
  printf 'typec=%s' "$(basename "$p")"
  for e in data_role power_role port_type orientation usb_power_delivery_revision; do
    [[ -r $p/$e ]] && printf ' %s=%s' "$e" "$(cat "$p/$e")"
  done
  echo
done
for e in /sys/class/usb_role/*/role; do
  [[ -r $e ]] || continue
  echo "usb_role $(basename "$(dirname "$e")")=$(cat "$e")"
done
echo

echo "## Log del firmware del cargador (ulog)"
if [[ ! -d /sys/module/pmic_pdcharger_ulog ]]; then
  if ! modprobe pmic_pdcharger_ulog 2>/dev/null; then
    echo "ulog=module-unavailable (pmic_pdcharger_ulog no carga; kernel sin CONFIG_QCOM_PMIC_PDCHARGER_ULOG?)"
    exit 0
  fi
fi

bound=0
for d in /sys/bus/rpmsg/devices/*PMIC_LOGS_ADSP_APPS*; do
  [[ -e $d ]] && bound=1
done
if ((!bound)); then
  echo "ulog=channel-absent (el firmware no expone PMIC_LOGS_ADSP_APPS)"
  exit 0
fi

if ! mkdir -p "$instance" 2>/dev/null ||
   ! echo 1 >"$instance/events/pmic_pdcharger_ulog/enable" 2>/dev/null; then
  echo "ulog=tracefs-unavailable"
  exit 0
fi

echo "ulog=capturando ${secs}s del log del firmware..."
sleep "$secs"
echo 0 >"$instance/events/pmic_pdcharger_ulog/enable" 2>/dev/null
grep -v '^#' "$instance/trace" 2>/dev/null || echo "ulog_trace=empty"
rmdir "$instance" 2>/dev/null
echo "ulog_module=dejado-cargado (no descargar: cuelga el teardown de GLINK)"
echo

echo "## dmesg carga (battmgr/pmic_glink/charger/ucsi/pdr)"
dmesg 2>/dev/null | grep -Ei 'battmgr|pmic_glink|pmic-glink|pdcharger|charger|ucsi|typec|pdr|adsp|remoteproc' | tail -n 100
