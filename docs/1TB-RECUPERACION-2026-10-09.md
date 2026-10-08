# Recuperación de la tarjeta de 1 TB (Odin 3) — 09-oct-2026

## Diagnóstico (cerrado)
- **El arranque está resuelto**: kernel 7.2.9 + `/flash/KERNEL` regenerado (md5 OK). El KERNEL es
  **byte-idéntico** al de la tarjeta de 128 GB que SÍ arranca (`md5 ca25633cef78bc198ab08e694a163835`).
- Lo que falla es la **sesión de usuario**: el selector estaba en `plasma`; `startplasmamobile`
  / gamescope no levantan → se queda en el bootanimation. Probado también en `gamescope` → tampoco.
- **Es un problema PRE-EXISTENTE de la tarjeta** (ya pasaba ANTES de actualizar: "llega al login pero
  no arranca sesión"), **NO** de la actualización ni del kernel. Viene de la imagen del **21-sep**, muy
  tocada por la depuración del 8-oct.

## Decisión
Reflashear con la **imagen buena del 26-sep** (`build/image/sm8750/pocknix-sm8750-sd.img`) — la MISMA
base de la tarjeta de 128 GB que funciona — **conservando los datos**.

## Datos a preservar (en la tarjeta de 1 TB)
- `/home/deck` (subvol `@home`): **77 G**
- `/opt` (dentro de `@`): **234 G** → DeckStation **176 G** (ROMs, saves, bios, configs), wproton, etc.

## Pasos (lanzar con la 1TB en el lector del PC)
```bash
# 0) identificar la tarjeta (PARTLABEL POCKNIX_ROOT) y elegir DEV
lsblk -o NAME,SIZE,LABEL,PARTLABEL          # p.ej. /dev/sdg
DEV=/dev/sdg

# 1) BACKUP DE DATOS  (¡ANTES de borrar!)
BK=/run/media/fransis/ROMS16TB/proyectos\ Alfred/pocknix-odin3/1tb-backup-<fecha>
sudo mount -o ro,subvol=@home ${DEV}2 /mnt/old-home
sudo mount -o ro,subvol=@     ${DEV}2 /mnt/old-root
sudo mkdir -p "$BK"
sudo rsync -aH /mnt/old-home/deck/ "$BK/home-deck/"
sudo rsync -aH /mnt/old-root/opt/  "$BK/opt/"
sudo umount /mnt/old-home /mnt/old-root

# 2) FLASH de la imagen (dd) + expandir  (o usar tools/reflash-sd.sh, ya hace dd+expand+kernel+home)
IMG=~/pocknix-odin3-project/pocknix-os/build/image/sm8750/pocknix-sm8750-sd.img
sudo dd if="$IMG" of=$DEV bs=4M status=progress conv=fsync
sudo sgdisk -e $DEV; sudo partprobe $DEV; sleep 3
sudo parted -s $DEV resizepart 2 100%; sudo partprobe $DEV; sleep 3
sudo btrfs filesystem resize max ${DEV}2

# 3) FIX DEL REPO + UPDATE  (chroot aarch64 con /flash enganchado; MISMOS comandos que en la Odin)
#    (montar @ en RW, bind proc/sys/dev/run, mount ${DEV}1 en /mnt/new/flash)
#    - pacman.conf: [pocknix] -> .../r2.dev/sm8750 ; [pocknix-shared] -> .../r2.dev/shared ;
#      [pocknix-base] -> .../r2.dev/base ; QUITAR [aur]
#    - pacman-key --add (r2.dev/sm8750/pocknix-repo.gpg) + pacman-key --lsign-key 85C433EE12621EED
#    - chroot <mnt> pacman -Syu  con la política --overwrite acotada (lista cerrada + rutas sin dueño)
#    -> queda en 7.2.9 + todos los paquetes al día; el hook regenera /flash/KERNEL

# 4) RESTAURAR DATOS
sudo rsync -aH "$BK/home-deck/" <nuevo>/home/deck/
sudo rsync -aH "$BK/opt/"        <nuevo>/opt/
sudo chown -R 1001:1001 <nuevo>/home/deck <nuevo>/opt    # en la Odin deck = uid 1001
# depmod del kernel nuevo + verificar /flash/KERNEL.md5
```

## Estado al cierre de la noche
- El PC tiene la **imagen 26-sep** y el **KERNEL 7.2.9** listos.
- La tarjeta de 1 TB **NO estaba en el lector** (`dmesg: "[sdg] Media removed"`, `/dev/sdg`=0B):
  se había sacado para la prueba en la Odin. **Hace falta que esté puesta** para reflashear.
- Duración estimada del proceso completo: **~1 h** (dd ~15 min + update + copia de datos).

## Referencias
- `docs/REPO-R2-CAUSA-RAIZ-2026-10-09.md` — repo propio (R2) + actualización real verificada.
