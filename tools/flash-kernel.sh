#!/bin/bash
# flash-kernel.sh — flashea el kernel recien compilado a la Odin, con backups.
# Uso: tools/flash-kernel.sh <version> [--reboot]
#   p.ej. tools/flash-kernel.sh 7.2.6 --reboot
#
# Seguro por diseño:
#   - Hace backup de /flash/KERNEL antes de tocarlo.
#   - Instala los MODULOS primero (el kernel viejo sigue en /flash hasta el final).
#   - NO borra los modulos antiguos: /lib/modules/<viejo> se queda -> revertir es
#     restaurar el KERNEL.bak y arrancar el kernel viejo.
#   - Copia el CONTENIDO de los modulos (no la carpeta) — leccion aprendida.
set -euo pipefail

VER="${1:?uso: flash-kernel.sh <version> [--reboot]}"
REBOOT="${2:-}"
ODIN="${ODIN_HOST:-odin-local}"
P=/home/fransis/pocknix-odin3-project/pocknix-os
KERNEL="${P}/build/image/sm8750/KERNEL"
MODROOT="${P}/build/kernel/sm8750/out/modroot/lib/modules/${VER}"
STAMP="$(date +%Y%m%d-%H%M)"

[ -f "$KERNEL" ] || { echo "no existe ${KERNEL}" >&2; exit 1; }
[ -d "$MODROOT" ] || { echo "no existe ${MODROOT}" >&2; exit 1; }

echo "== verificando el boot image =="
file "$KERNEL" | grep -q "Android bootimg" || { echo "no es un Android bootimg" >&2; exit 1; }
echo "  ok: $(ls -la "$KERNEL" | awk '{print $5}') bytes"

echo "== subiendo artefactos a la Odin =="
scp -q "$KERNEL" "${ODIN}:/tmp/KERNEL-${VER}"
tar -C "$MODROOT" -czf /tmp/modules-${VER}.tar.gz .
scp -q /tmp/modules-${VER}.tar.gz "${ODIN}:/tmp/"

echo "== instalando en la Odin (modulos primero, luego el KERNEL) =="
ssh "${ODIN}" "bash -s" <<EOS
set -e
echo pocknix | sudo -S mkdir -p /lib/modules/${VER}
echo pocknix | sudo -S tar -xzf /tmp/modules-${VER}.tar.gz -C /lib/modules/${VER}
echo pocknix | sudo -S depmod -a ${VER}
echo "  modulos ${VER}: \$(ls /lib/modules/${VER} | wc -l) entradas"

# backup del kernel actual (solo la primera vez por stamp)
if [ ! -f /flash/KERNEL.bak-${STAMP} ]; then
  echo pocknix | sudo -S cp /flash/KERNEL /flash/KERNEL.bak-${STAMP}
  echo "  backup: /flash/KERNEL.bak-${STAMP}"
fi
echo pocknix | sudo -S cp /tmp/KERNEL-${VER} /flash/KERNEL
echo pocknix | sudo -S chmod 644 /flash/KERNEL
echo "  KERNEL instalado: \$(ls -la /flash/KERNEL | awk '{print \$5}') bytes"

echo "== estado final =="
echo "  /flash/KERNEL      -> \$(md5sum /flash/KERNEL | cut -c1-12)"
echo "  backups en /flash  -> \$(ls /flash/KERNEL.bak* 2>/dev/null | wc -l)"
echo "  modulos disponibles-> \$(ls -d /lib/modules/*/ | xargs -n1 basename | tr '\n' ' ')"
rm -f /tmp/KERNEL-${VER} /tmp/modules-${VER}.tar.gz
EOS

rm -f /tmp/modules-${VER}.tar.gz

if [ "$REBOOT" = "--reboot" ]; then
    echo "== reiniciando la Odin =="
    ssh "${ODIN}" 'echo pocknix | sudo -S reboot' || true
    echo "  reboot enviado — esperando a que vuelva..."
    for i in $(seq 1 40); do
        sleep 15
        if ssh -o ConnectTimeout=8 -o BatchMode=yes "${ODIN}" 'uname -r' 2>/dev/null; then
            echo "  la Odin ha vuelto con el kernel de arriba ^"
            exit 0
        fi
        printf '.'
    done
    echo "  AVISO: no respondio en 10 min — comprobar a mano"
fi
