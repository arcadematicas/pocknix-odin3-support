# calvOS en la flash interna del Odin 3 (23/10/2026)

Instalación del **sistema** en la UFS 4.0 interna dejando **los juegos en la SD**. Sin copiar
juegos de un lado a otro: la SD se queda montada en `/opt/deckstation` y `/opt/wproton`.

## Hardware de partida
- Interna: **226 GB** (modelo 256 GB) → ~196 GiB útiles para el sistema.
- SD: 1 TB, root con **419 GiB** usados (325 de ellos en `/opt`: DeckStation 184 GiB + WProton 141 GiB).

## El problema
`pocknix-install-internal` clona **todo** el root de la SD y exige que quepa en la interna:
`mode=nofit`, faltaban 244 GiB. No había forma de instalar "solo el sistema".

## La solución: `--exclude`
Parche en `pocknix-tools` (ver `packages/pocknix-tools/README-instalador-interna.md`):
- `--exclude DIR` (repetible): no clona `DIR` y **descuenta su tamaño** del cálculo.
- Con `--exclude /opt` → `sd_used_gib=94` ✅.

```sh
pocknix-install-internal --yes --exclude /opt --userdata-gib 1
```

Resultado (dry-run y real):
```
#17 userdata      1 GiB   (Android — RESET)
#18 ROCKNIX/POCKNIX 512 MiB FAT (KERNEL del ABL, renombrada a POCKNIX en el primer arranque)
#19 POCKNIX_ROOT  ~196 GiB btrfs (snapshots) — 94 GiB clonados
```
Duración del clonado: **~24 min** (lee de la SD). Nada anterior a `userdata` se toca.

## Choque de nombres (importante)
El fstab interno usa `PARTLABEL=POCKNIX_ROOT` para `/`, `/home`, `/.snapshots`, `/var/*`. Con la SD
también etiquetada `POCKNIX_ROOT`, el montaje es **ambiguo** (podía montar `/home` desde la SD).
Solución: renombrar la **SD** a `POCKNIX_SD`:
- `parted -s /dev/mmcblk0 name 2 POCKNIX_SD` y `btrfs filesystem label /dev/mmcblk0p2 POCKNIX_SD`.
- Para que la SD **siga arrancando**, su `KERNEL` lleva el cmdline dentro: se parchea el byte-string
  `root=PARTLABEL=POCKNIX_ROOT` → `root=PARTLABEL=POCKNIX_SD  ` (**misma longitud**) y se actualiza
  `KERNEL.md5`. Copia: `KERNEL.bak-POCKNIX_ROOT`.
- Su `fstab` usa PARTUUID, así que renombrar no le afecta.

## Juegos de la SD, montados en su ruta
`/etc/fstab` del sistema interno:
```
PARTUUID=706f636b-…0002  /mnt/sd-legacy  btrfs  rw,noatime,compress=zstd:1,commit=5,subvol=@,nofail  0 0
/mnt/sd-legacy/opt/deckstation  /opt/deckstation  none  bind,nofail,x-systemd.requires-mounts-for=/mnt/sd-legacy  0 0
/mnt/sd-legacy/opt/wproton      /opt/wproton      none  bind,nofail,x-systemd.requires-mounts-for=/mnt/sd-legacy  0 0
```
Con la SD puesta, todo sigue en su ruta: ROMs, juegos de WProton (incluido Wind Waker con saves y
save states). Sin la SD, el sistema arranca igual y esos directorios salen vacíos (`nofail`).

## Estado final
- `/` en `/dev/sda19` (btrfs, 197 G, **110 G libres**), `/flash` en `/dev/sda18` (POCKNIX).
- 0 unidades fallidas; audio, watchdog, botón de encendido y `oomd` activos.
- Revertir: `pocknix-uninstall-internal` desde la SD.
- Pendiente de probar: arranque con la SD puesta (debe elegir interna) y arranque de rescate desde la SD.
