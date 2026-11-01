# Release — Pocknix/calvOS 0.4 (Odin 3) — build del 1/11/2026

## Imagen

- **Fichero**: `pocknix-sm8750-sd.img` (26.283.606.016 bytes; ~24,5 GiB)
- **Comprimido**: `pocknix-sm8750-sd.img.zst` (11,6 GB, zstd -15 --long=27)
- **SHA256 (img)**:
  `13cbc1de85779cb6086132f463e3290619942567604573f8fd5b2544cff43431`
- **SHA256 (zst)**:
  `31ee0c4f7939fc1a02b21c99e926ee4b54ee5f7a23b1e312592307a4c481d8d1`

## Distribución (1/11/2026) — volúmenes 7-Zip

La imagen se reparte en **3 volúmenes 7-Zip** (modo *store*, sin recomprimir) dentro de una carpeta:

```
pocknix-sm8750-sd.7z.001  3.900.000.000 B  317049c5a7109e2bb0ddddf1e166f23924bb77cb03652d714bead4c669375a4d
pocknix-sm8750-sd.7z.002  3.900.000.000 B  d34caf76e3c132d34120f1ba41d019e7d40e9f6a1d665d800fd61a423d15cbe7
pocknix-sm8750-sd.7z.003  3.802.833.981 B  e501fc94f464a0f3a6892d1db8bc1ceb7576aa63575b283c59678ca3cb5d62f9
```

- Comprobado: `7z t` sobre los tres (CRC OK) y extracción real del `.001` → `.zst` con SHA256
  `31ee0c4f…81d8d1`.
- Destino: `/run/media/fransis/ROMS16TB/odin 3/CalvOS release/` (PC) con `LEEME.txt`.
- Copia en el portátil: `~/releases/` (el `.zst` original sigue ahí para el seed).

### Torrent: solo LAN

```
magnet:?xt=urn:btih:37feb722583f2e86678d76e82cf15a35a0fcac01&dn=pocknix-sm8750-sd.img.zst&tr=udp%3A%2F%2Ftracker.opentrackr.org%3A1337%2Fannounce&tr=udp%3A%2F%2Fopen.stealth.si%3A80%2Fannounce&tr=udp%3A%2F%2Ftracker.torrent.eu.org%3A451%2Fannounce&tr=udp%3A%2F%2Fexodus.desync.com%3A6969%2Fannounce&tr=udp%3A%2F%2Ftracker.openbittorrent.com%3A6969%2Fannounce
```

- Seed activo (transmission-daemon, portátil, `~/releases`, 51413 TCP/UDP, DHT/PEX/LPD).
- ⚠️ **CGNAT**: el WAN del router es `100.68.121.83` (100.64/10) y la IP pública real
  `147.136.252.230` → los peers de fuera **no pueden conectar** con el seed. UPnP funciona (mapeo
  creado vía URL directa del IGD, porque la wifi bloquea el SSDP), pero el operador filtra el
  entrante: `Port is open: No`.
- Sirve así para alguien en la misma LAN, o para un peer con puerto público al que el seed pueda
  conectar hacia fuera.

## Qué lleva

- **Kernel 7.2.12-28**: GMU al resumir (2122/2123), `CHARGE_NOW` por coulomb counter (2121),
  iris completo (`low_latency`), 0 `.rej`.
- **BSP 0.2.0-42**: `mem_sleep_default=deep` y hook `zz-wifi` (saca el PCI del ath12k al
  suspender y lo re-escanea al despertar).
- **Overlay 0.1.0-11**: sin `baloofilerc` (lo trae `pocknix-desktop-kde`).
- **Decky 0.1.0-64** (repos): Eclipse se instala solo si falta (0.3.5); lo actualiza el Panel de Control.
  La imagen lleva la **0.1.0-63**, con el **mismo contenido** (solo cambiaba el pkgrel): el primer
  `pacman -Syu` la sustituye por la 64 sin cambios funcionales.
- Mesa `2:26.3.0`, gamescope `1:3.16.31.ogc1…-3`, todos los paquetes del localrepo.

## Verificado en la imagen montada

- `KERNEL` = `a28d6f…` (kernel 28) en la partición de arranque.
- rootfs: `linux-pocknix-sm8750-7.2.12-28`, `pocknix-decky-0.1.0-63` (contenido = 64 publicada),
  `pocknix-system-overlay-0.1.0-11`, `pocknix-bsp-sm8750-0.2.0-42`, `pocknix-core-0.1.0-6`,
  `pocknix-desktop-kde-0.1.0-3`, `mesa-2:26.3.0-1`, `gamescope-1:3.16.31.ogc1…-3`.
- Repos: `[pocknix]`, `[pocknix-shared]`, `[pocknix-base]`.

## Flashear

```bash
sudo dd if=pocknix-sm8750-sd.img of=/dev/sdX bs=4M conv=fsync status=progress
```

Comprobar el dispositivo con `lsblk` antes. La interna no se toca.

## Notas

- Root por defecto: `pocknix` (SSH desactivado en la imagen).
- `make build` → rootfs; `make sd-image` → imagen. Ver `docs/PLAN-DISTRIBUCION-BUILD-20261028.md`.
