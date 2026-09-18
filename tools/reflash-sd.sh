#!/usr/bin/env bash
# reflash-sd.sh — Re-flashea la SD de la Odin 3 con la imagen + restaura el home.
#
# USO:  sudo tools/reflash-sd.sh /dev/sdX
#
# ⚠️  DESTRUCTIVO: borra TODA la SD. El backup ya está hecho en:
#     /run/media/fransis/ROMS16TB/proyectos Alfred/pocknix-odin3/backup-sd-2026-09-18/
#
# POR QUÉ: el 18/09/2026 el btrfs de la SD se corrompió (la Odin restauró un
# snapshot al arrancar). El `btrfs rescue zero-log` + `check --repair` la dejaron
# montable en RW, pero quedaron 16450 inodos huérfanos y el árbol raíz del FS (-9)
# sigue roto → no es fiable. Un re-flasheo deja una SD sana garantizada.
#
# QUÉ HACE:
#   1. Comprueba la imagen y el dispositivo
#   2. Escribe la imagen (dd)
#   3. Expande POCKNIX_ROOT para llenar la SD
#   4. Flashea NUESTRO kernel (7.2.4 + rotación) en el FAT
#   5. Restaura el home desde el backup
#   6. depmod para el kernel flasheado
#
# ALTERNATIVA sin borrar: en la Odin, desde el menú de arranque, restaurar un
# snapshot de @snapshots (0006..0010) — eso reconstruye el árbol consistente.

set -euo pipefail

IMG="/home/fransis/pocknix-odin3-project/pocknix-os/build/image/sm8750/pocknix-sm8750-sd.img"
KERNEL="/home/fransis/pocknix-odin3-project/pocknix-os/build/image/sm8750/KERNEL"
MODROOT="/home/fransis/pocknix-odin3-project/pocknix-os/build/kernel/sm8750/out/modroot"
BACKUP="/run/media/fransis/ROMS16TB/proyectos Alfred/pocknix-odin3/backup-sd-2026-09-18"

DEV="${1:-}"
if [ -z "$DEV" ]; then echo "USO: sudo $0 /dev/sdX"; exit 1; fi
[ -b "$DEV" ] || { echo "ERROR: $DEV no es un dispositivo de bloque"; exit 1; }
[ -f "$IMG" ] || { echo "ERROR: no existe la imagen $IMG"; exit 1; }
[ -f "$KERNEL" ] || { echo "ERROR: no existe el KERNEL $KERNEL"; exit 1; }

echo "=== RESUMEN ==="
echo "  Dispositivo : $DEV  ($(lsblk -dno SIZE "$DEV"))"
echo "  Imagen      : $IMG ($(du -h "$IMG" | cut -f1))"
echo "  Kernel      : $KERNEL (md5 $(md5sum "$KERNEL" | cut -c1-12))"
echo "  Backup      : $BACKUP"
echo ""
echo "⚠️  SE VA A BORRAR TODO EN $DEV"
read -rp "Escribe SI para continuar: " OK
[ "$OK" = "SI" ] || { echo "Cancelado"; exit 1; }

echo ""
echo "=== 1/6: escribiendo la imagen (tarda ~10 min) ==="
sudo dd if="$IMG" of="$DEV" bs=4M status=progress conv=fsync
sync

echo ""
echo "=== 2/6: recargando tabla de particiones ==="
sudo partprobe "$DEV" 2>/dev/null || true
sleep 3
lsblk -o NAME,SIZE,LABEL "$DEV"

# Detectar las particiones (p1 = ROCKNIX vfat, p2 = POCKNIX_ROOT btrfs)
P1="${DEV}1"; P2="${DEV}2"
[ -b "$P1" ] || { P1="${DEV}p1"; P2="${DEV}p2"; }
[ -b "$P2" ] || { echo "ERROR: no encuentro las particiones"; exit 1; }

echo ""
echo "=== 3/6: expandiendo POCKNIX_ROOT para llenar la SD ==="
sudo parted -s "$DEV" resizepart 2 100% || true
sudo partprobe "$DEV" 2>/dev/null || true
sleep 3
sudo btrfs filesystem resize max "$P2" 2>/dev/null || \
  echo "  (aviso: revisa el resize; puede que la particion ya estuviera al maximo)"

echo ""
echo "=== 4/6: flasheando NUESTRO kernel ==="
sudo mkdir -p /mnt/odin-boot
sudo mount "$P1" /mnt/odin-boot
sudo cp "$KERNEL" /mnt/odin-boot/KERNEL
sync
echo "  KERNEL en la SD: md5 $(sudo md5sum /mnt/odin-boot/KERNEL | cut -c1-12)"
sudo umount /mnt/odin-boot

echo ""
echo "=== 5/6: restaurando el home ==="
sudo mkdir -p /mnt/odin-root
sudo mount "$P2" /mnt/odin-root
if [ -d "$BACKUP/home-deck" ]; then
  sudo rsync -aH "$BACKUP/home-deck/" /mnt/odin-root/home/deck/
  echo "  home restaurado: $(sudo du -sh /mnt/odin-root/home/deck | cut -f1)"
else
  echo "  ⚠️ no hay backup del home en $BACKUP"
fi

echo ""
echo "=== 6/6: depmod + ajustes ==="
sudo depmod -b /mnt/odin-root -a 7.2.4 2>/dev/null && echo "  depmod ok"
# El home debe ser del usuario deck (1000)
sudo chown -R 1000:1000 /mnt/odin-root/home/deck 2>/dev/null || true
sync

echo ""
echo "=== HECHO ==="
echo "  home:   $(sudo du -sh /mnt/odin-root/home/deck 2>/dev/null | cut -f1)"
sudo umount /mnt/odin-root 2>/dev/null || true
sudo umount /mnt/odin-boot 2>/dev/null || true
sync
echo "  ✅ SD lista. Ya puedes ponerla en la Odin."
