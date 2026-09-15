#!/bin/bash
# =============================================================================
# ODIN 3 (SM8750) - POST-BOOT SETUP SCRIPT
# =============================================================================
# Ejecutar UNA VEZ después de flashear la imagen o en cada boot si es necesario.
# Requiere: usuario deck en grupo wheel, password 'pocknix' para su.
#
# Este script aplica:
#   1. Deshabilitacion TOTAL de suspensión
#   2. Deshabilitacion de WiFi power save
#   3. Pantalla apagada (proteger AMOLED)
#   4. Fix de rotacion Plasma Mobile
#   5. Sensor config para hexagonrpcd
#   6. Verificacion de servicios criticos
# =============================================================================

set -e
PW="pocknix"
run() { echo "$PW" | su -c "$1" root 2>&1; }

echo "=========================================="
echo "  ODIN 3 POST-BOOT SETUP"
echo "  $(date)"
echo "=========================================="

# --- 1. SUSPENSION TOTAL ---
echo ""
echo "[1/6] Deshabilitando suspensión..."
run "systemctl mask sleep.target suspend.target hibernate.target hybrid-sleep.target suspend-then-hibernate.target 2>/dev/null"
# logind.conf: ignorar suspensión desde.userspace
run "grep -q '^HandleSuspendKey=ignore' /etc/systemd/logind.conf 2>/dev/null || echo 'HandleSuspendKey=ignore' >> /etc/systemd/logind.conf"
run "grep -q '^HandleLidSwitch=ignore' /etc/systemd/logind.conf 2>/dev/null || echo 'HandleLidSwitch=ignore' >> /etc/systemd/logind.conf"
run "grep -q '^IdleAction=ignore' /etc/systemd/logind.conf 2>/dev/null || echo 'IdleAction=ignore' >> /etc/systemd/logind.conf"
run "grep -q '^IdleActionSec=infinity' /etc/systemd/logind.conf 2>/dev/null || echo 'IdleActionSec=infinity' >> /etc/systemd/logind.conf"
echo "  ✅ Suspensión deshabilitada (systemd + logind)"

# --- 2. WiFi POWER SAVE OFF ---
echo ""
echo "[2/6] Deshabilitando WiFi power save..."
run "mkdir -p /etc/NetworkManager/conf.d"
run 'cat > /etc/NetworkManager/conf.d/no-wifi-powersave.conf << "NM"
[connection]
wifi.powersave = 2
NM'
run "chmod 644 /etc/NetworkManager/conf.d/no-wifi-powersave.conf"
run "iw dev wlan0 set power_save off 2>/dev/null || true"
echo "  ✅ WiFi power save off"

# --- 3. PANTALLA OFF (proteger AMOLED) ---
echo ""
echo "[3/6] Apagando pantalla..."
run "echo 0 > /sys/class/backlight/ae94000.dsi.0/brightness"
echo "  ✅ Brightness=0"

# --- 4. SSH SIEMPRE ACTIVO ---
echo ""
echo "[4/6] Verificando SSH..."
run "systemctl enable sshd 2>/dev/null"
run "systemctl start sshd 2>/dev/null"
echo "  ✅ sshd activo"

# --- 5. ROTACION PLASMA MOBILE ---
echo ""
echo "[5/6] Fix rotación Plasma Mobile..."
# Create fix script
cat > /tmp/fix_rotation.py << 'PY'
import json, subprocess, os
p = os.path.expanduser("~/.config/kwinoutputconfig.json")
if not os.path.exists(p):
    print("kwinoutputconfig.json not found")
    exit(1)
with open(p) as f: data = json.load(f)
changed = False
for item in data:
    if item.get("name") == "outputs":
        for out in item.get("data", []):
            if out.get("connectorName") == "DSI-1":
                if out.get("autoRotation") != "Disabled" or out.get("transform") != "Normal":
                    out["autoRotation"] = "Disabled"
                    out["transform"] = "Normal"
                    changed = True
with open(p, "w") as f: json.dump(data, f, indent=4)
if changed:
    print("rotation fix applied: auto=Disabled, transform=Normal")
else:
    print("rotation already correct")
PY
run "cp /tmp/fix_rotation.py /home/deck/fix_rotation.py"
run "chown deck:deck /home/deck/fix_rotation.py"
echo "  ✅ Script de rotación instalado en ~/fix_rotation.py"
echo "  ⚠️  Ejecutar: python3 ~/fix_rotation.py"
echo "  ⚠️  Después: echo pocknix | su -c 'chattr +i /home/deck/.config/kwinoutputconfig.json' root"

# --- 6. SENSOR CONFIG ---
echo ""
echo "[6/6] Sensor config para hexagonrpcd..."
# Los archivos REALES de sensores vienen integrados en la imagen
# (extraídos del firmware Android Odin3_20251206, partición vendor):
#   /usr/lib/firmware/sensors/config/*.json  (140 archivos, incl. pakala_* SM8750)
#   /usr/lib/firmware/sensors/sns_reg.conf
#   /usr/lib/firmware/sensors/registry/      (output del daemon)
#   /vendor/etc/sensors/                     (paths Android, espejo)
run "mkdir -p /vendor/etc/sensors /usr/lib/firmware/sensors/config /usr/lib/firmware/sensors/registry"
run "chmod -R 644 /vendor/etc/sensors/ /usr/lib/firmware/sensors/"
run "chmod 755 /usr/lib/firmware/sensors/registry"
run "systemctl daemon-reload 2>/dev/null"
run "systemctl restart hexagonrpcd-adsp-sensorspd 2>/dev/null || true"
echo "  ✅ Sensor config instalado (configs reales de Android integrados)"

# --- STATUS ---
echo ""
echo "=========================================="
echo "  ESTADO FINAL"
echo "=========================================="
run "echo kernel=\$(uname -r)"
run "echo adsp=\$(cat /sys/class/remoteproc/remoteproc0/state 2>/dev/null)"
run "echo sound=\$(cat /proc/asound/cards 2>/dev/null)"
run "echo battery=\$(cat /sys/class/power_supply/battery/capacity 2>/dev/null)"
run "echo brightness=\$(cat /sys/class/backlight/ae94000.dsi.0/brightness 2>/dev/null)"
run "echo wifi=\$(ip addr show wlan0 2>/dev/null | grep 'inet ' | awk '{print \$2}')"
run "echo hexagonrpcd=\$(systemctl is-active hexagonrpcd-adsp-sensorspd 2>/dev/null)"
run "echo ssh=\$(systemctl is-active sshd 2>/dev/null)"
echo ""
echo "  Setup completado."
echo "=========================================="
