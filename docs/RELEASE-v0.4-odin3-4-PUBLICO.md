# calvOS / Pocknix 0.4 para AYN Odin 3 — build del 1/11/2026

Imagen nueva del sistema para la **AYN Odin 3** (SM8750), con la suspensión arreglada y consumo
medido en `deep`. Se graba en una SD y arranca desde ella: **la interna no se toca**.

## Qué cambia

- **Suspensión que ya no se cuelga.** Kernel 7.2.12-28 con los parches de GMU de armada: al
  despertar desaparecen los `a6xx_gmu_resume`, `GMU OOB` y `preemption timed out` que dejaban la
  consola muerta tras un toque corto.
- **WiFi y suspensión.** El `ath12k` abortaba el `s2idle`/`deep` con `-110`; ahora un hook saca el
  PCI del módem al dormir y lo re-escanea al despertar (`wlan0` vuelve sola).
- **`deep` por defecto.** Medido en una noche completa: **0,14 %/h** (13 h 31 min, 1,85 % de
  batería) frente a 0,44 %/h con `s2idle`.
- **Batería en MangoHud.** `CHARGE_NOW` sale del coulomb counter: porcentaje y tiempo restante
  correctos.
- **Iris completo.** Decodificación en stage 1 con `low_latency` (Remote Play / Moonlight), y el
  stack de parches aplica **sin conflictos** (0 `.rej`).
- **Tema Eclipse.** Se instala la primera vez y a partir de ahí lo actualiza el **Panel de Control**
  (0.3.5), sin que la imagen lo revierta.
- **Arreglos de paquetes:** `baloofilerc` ya no choca entre paquetes; mesa `2:26.3.0`, gamescope
  OGC con HDR de armada.

## Imagen

- `pocknix-sm8750-sd.img.zst` — 11,6 GB (imagen cruda 24,5 GiB)
- SHA256 (zst): `31ee0c4f7939fc1a02b21c99e926ee4b54ee5f7a23b1e312592307a4c481d8d1`
- SHA256 (img): `13cbc1de85779cb6086132f463e3290619942567604573f8fd5b2544cff43431`

**Torrent / magnet**

```
magnet:?xt=urn:btih:37feb722583f2e86678d76e82cf15a35a0fcac01&dn=pocknix-sm8750-sd.img.zst&tr=udp%3A%2F%2Ftracker.opentrackr.org%3A1337%2Fannounce&tr=udp%3A%2F%2Fopen.stealth.si%3A80%2Fannounce&tr=udp%3A%2F%2Ftracker.torrent.eu.org%3A451%2Fannounce&tr=udp%3A%2F%2Fexodus.desync.com%3A6969%2Fannounce&tr=udp%3A%2F%2Ftracker.openbittorrent.com%3A6969%2Fannounce
```

## Cómo grabarla

1. Descomprime: `zstd -d pocknix-sm8750-sd.img.zst`
2. Comprueba el dispositivo con `lsblk`.
3. `sudo dd if=pocknix-sm8750-sd.img of=/dev/sdX bs=4M conv=fsync status=progress`
   (o BalenaEtcher / Raspberry Pi Imager).
4. Inserta la SD en la Odin y arranca. Usuario `deck`, root `pocknix`. SSH desactivado por defecto.

## Gracias

A **Jarvis (DaViDuSkY)** por las pruebas de suspensión en su Odin y el hallazgo del `ath12k`, y a
todos los que reportasteis los cuelgues del QAM y del resume.
