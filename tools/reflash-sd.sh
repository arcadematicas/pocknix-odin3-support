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
# IMPORTANTE: primero arreglar la GPT (la imagen es mas pequeña que la SD).
# Sin esto, `parted resizepart` falla con "No se pueden satisfacer todas las restricciones".
sudo sgdisk -e "$DEV" 2>/dev/null || true
sudo partprobe "$DEV" 2>/dev/null || true
sleep 3
sudo parted -s "$DEV" resizepart 2 100% || true
sudo partprobe "$DEV" 2>/dev/null || true
sleep 3
sudo btrfs filesystem resize max "$P2" 2>/dev/null || \
  echo "  (aviso: revisa el resize; puede que la particion ya estuviera al maximo)"

echo ""
echo "=== 4/6: flasheando NUESTRO kernel ==="
# El FAT puede venir corrupto de la imagen (o de un arranque fallido): el kernel
# entonces lo monta en SOLO LECTURA ("origen protegido contra escritura") y el cp falla.
# Sintoma en dmesg: "FAT-fs: error, corrupted directory" / "invalid cluster chain".
# Solucion: reformatear el FAT y restaurar su contenido (ABL) desde la imagen.
sudo umount "$P1" 2>/dev/null || true
sudo umount /run/media/*/ROCKNIX 2>/dev/null || true
FAT_OK=1
sudo mount -t vfat -o rw "$P1" /mnt/odin-boot 2>/dev/null
if ! findmnt -no OPTIONS /mnt/odin-boot 2>/dev/null | grep -q "^rw"; then
  FAT_OK=0
fi
if [ "$FAT_OK" = "0" ] || ! sudo test -w /mnt/odin-boot; then
  echo "  ⚠️ el FAT esta corrupto -> reformateando"
  sudo umount /mnt/odin-boot 2>/dev/null || true
  # sacar el contenido original (ABL) de la imagen
  LOOP=$(sudo losetup -P -f --show "$IMG")
  sudo mkdir -p /mnt/img-boot
  sudo mount -o ro "${LOOP}p1" /mnt/img-boot 2>/dev/null
  sudo rm -rf /tmp/fat-restore && sudo mkdir -p /tmp/fat-restore
  sudo cp -a /mnt/img-boot/. /tmp/fat-restore/ 2>/dev/null
  sudo umount /mnt/img-boot 2>/dev/null || true
  sudo losetup -d "$LOOP" 2>/dev/null || true
  # reformatear (la etiqueta DEBE ser ROCKNIX, el bootloader la busca)
  sudo mkfs.vfat -F 32 -n ROCKNIX "$P1"
  sudo mount -t vfat -o rw "$P1" /mnt/odin-boot
  sudo cp -a /tmp/fat-restore/. /mnt/odin-boot/ 2>/dev/null
  echo "  ✅ FAT reformateado + ABL restaurado"
fi
sudo cp "$KERNEL" /mnt/odin-boot/KERNEL
sync
echo "  KERNEL en la SD: md5 $(sudo md5sum /mnt/odin-boot/KERNEL | cut -c1-12)  (esperado $(md5sum "$KERNEL" | cut -c1-12))"
sudo umount /mnt/odin-boot

echo ""
echo "=== 5/6: restaurando el home y /opt ==="
sudo mkdir -p /mnt/odin-root
sudo mount "$P2" /mnt/odin-root
if [ -d "$BACKUP/home-deck" ]; then
  sudo rsync -aH "$BACKUP/home-deck/" /mnt/odin-root/home/deck/
  echo "  home restaurado: $(sudo du -sh /mnt/odin-root/home/deck | cut -f1)"
else
  echo "  ⚠️ no hay backup del home en $BACKUP"
fi
# /opt: DeckStation (23 GB: ROMs, saves, bios, configs) + wproton
if [ -d "$BACKUP/opt" ]; then
  sudo mkdir -p /mnt/odin-root/opt
  sudo rsync -aH "$BACKUP/opt/" /mnt/odin-root/opt/
  echo "  /opt restaurado: $(sudo du -sh /mnt/odin-root/opt | cut -f1)"
else
  echo "  ⚠️ no hay backup de /opt en $BACKUP"
fi
# /usr/local (scripts y libs propias)
if [ -d "$BACKUP/usr_local" ]; then
  sudo mkdir -p /mnt/odin-root/usr/local
  sudo rsync -aH "$BACKUP/usr_local/" /mnt/odin-root/usr/local/
  echo "  /usr/local restaurado"
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
