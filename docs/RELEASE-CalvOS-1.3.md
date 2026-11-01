# Release **CalvOS 1.3** — AYN Odin 3

**Fecha**: 1/11/2026 · **Artefacto**: `pocknix-sm8750-sd.img` (24,5 GiB; 11,6 GB comprimida)

```
sha256 (img)  13cbc1de85779cb6086132f463e3290619942567604573f8fd5b2544cff43431
sha256 (zst)  31ee0c4f7939fc1a02b21c99e926ee4b54ee5f7a23b1e312592307a4c481d8d1
```

Se graba en una microSD y arranca desde ella: **la memoria interna no se toca**.

## Cambios vs CalvOS 1.2

- **Suspensión que ya no se cuelga** (kernel `7.2.12-28`): parches de GMU de armada
  (`2122`/`2123`, la IRQ HFI limpia solo CM3 y se enmascara antes de arrancar la GMU).
  Desaparecen los `a6xx_gmu_resume`, `GMU OOB` y `44050000 preemption timed out` que dejaban
  la consola muerta tras un toque corto. Confirmado por Jarvis en su Odin y en la nuestra.
- **WiFi y suspensión** (BSP `0.2.0-42`): el `ath12k` abortaba `s2idle`/`deep` con `-110`
  incluso con la wifi como secundaria. El hook `zz-wifi` saca el PCI (`17cb:110e`) en `pre` y
  lo re-escanea en `post`: `wlan0` vuelve sola.
- **`deep` por defecto** (antes `s2idle`): medido en una noche completa, **0,14 %/h**
  (13h31m, 1,85 % de batería) frente a 0,44 %/h con `s2idle`.
- **MangoHUD con batería real** (kernel `2121`): `CHARGE_NOW` sale del coulomb counter, así que
  el porcentaje y el tiempo restante son correctos.
- **Iris completo**: decodificación en stage 1 con `low_latency` (Remote Play / Moonlight) y el
  stack de parches aplica con **0 conflictos** (0 `.rej`).
- **Tema Eclipse** (decky `0.1.0-64`): el oneshot lo instala (0.3.5) **solo si falta** y a partir
  de ahí lo actualiza el **Panel de Control**, sin que la imagen lo revierta.
- **Paquetes**: `pocknix-system-overlay 0.1.0-11` (fuera `baloofilerc`, que ya trae
  `pocknix-desktop-kde`), mesa `2:26.3.0`, gamescope `1:3.16.31.ogc1-3` (stack de color/HDR de
  armada).

## Verificado en la imagen montada

- `KERNEL` `a28d6f…` (kernel 28) en la partición de arranque.
- rootfs: `linux-pocknix-sm8750-7.2.12-28`, `pocknix-decky-0.1.0-63` (contenido = 64 publicada),
  `pocknix-system-overlay-0.1.0-11`, `pocknix-bsp-sm8750-0.2.0-42`, `pocknix-core-0.1.0-6`,
  `pocknix-desktop-kde-0.1.0-3`, `mesa-2:26.3.0-1`, `gamescope-1:3.16.31.ogc1…-3`.
- Repos `[pocknix]`, `[pocknix-shared]`, `[pocknix-base]`; `pacman -Syu` limpio, 0 conflictos,
  0 servicios fallidos.

## Descarga

Tres volúmenes 7-Zip en el grupo de releases de Telegram:

👉 **https://t.me/+Pz1kfKX8UZs0OWE0**

```
pocknix-sm8750-sd.7z.001  3,9 GB  317049c5a7109e2bb0ddddf1e166f23924bb77cb03652d714bead4c669375a4d
pocknix-sm8750-sd.7z.002  3,9 GB  d34caf76e3c132d34120f1ba41d019e7d40e9f6a1d665d800fd61a423d15cbe7
pocknix-sm8750-sd.7z.003  3,8 GB  e501fc94f464a0f3a6892d1db8bc1ceb7576aa63575b283c59678ca3cb5d62f9
```

**Cómo se abre** (7-Zip 23+, PeaZip, o cualquier gestor con volúmenes `.7z.00X`):

1. Doble clic en `.7z.001` → *Extraer*: se unen solos y sale `pocknix-sm8750-sd.img.zst`.
2. Doble clic en el `.zst` → *Extraer*: sale `pocknix-sm8750-sd.img` (24,5 GiB).

Si el 7-Zip es antiguo y no abre `.zst`: `zstd -d pocknix-sm8750-sd.img.zst`.

## Flashear

```sh
lsblk                       # confirmar el dispositivo, sin equivocarse
sudo dd if=pocknix-sm8750-sd.img of=/dev/sdX bs=4M conv=fsync status=progress
```

En Windows: BalenaEtcher o Raspberry Pi Imager.

Usuario `deck`, root `pocknix`, SSH desactivado por defecto.

## Notas

- Base: Pocknix upstream **v0.4** (soporte SM8750 nuestro). El nombre interno del árbol de
  build sigue siendo `0.4`; la **versión publicada es CalvOS 1.3**.
- El torrent sigue existiendo, pero la conexión de casa está **detrás de CGNAT**: los peers de
  fuera no pueden conectar con el seed, así que solo sirve en LAN.
- Pendiente para la próxima: micrófono y giroscopio.

## Gracias

A **Jarvis (DaViDuSkY)** por las pruebas de suspensión en su Odin y el hallazgo del `ath12k`, y a
quienes reportasteis los cuelgues del QAM y del resume.
