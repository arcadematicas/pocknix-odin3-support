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
- **Batería en MangoHUD.** `CHARGE_NOW` sale del coulomb counter: porcentaje y tiempo restante
  correctos.
- **Iris completo.** Decodificación en stage 1 con `low_latency` (Remote Play / Moonlight), y el
  stack de parches aplica **sin conflictos** (0 `.rej`).
- **Tema Eclipse.** Se instala la primera vez y a partir de ahí lo actualiza el **Panel de Control**
  (0.3.5), sin que la imagen lo revierta.
- **Arreglos de paquetes:** `baloofilerc` ya no choca entre paquetes; mesa `2:26.3.0`, gamescope
  OGC con HDR de armada.

## Ficheros

Descarga los **tres trozos** en la misma carpeta:

| Fichero | Tamaño |
|---|---|
| `pocknix-sm8750-sd.7z.001` | 3,9 GB |
| `pocknix-sm8750-sd.7z.002` | 3,9 GB |
| `pocknix-sm8750-sd.7z.003` | 3,8 GB |

Hashes SHA256:

```
317049c5a7109e2bb0ddddf1e166f23924bb77cb03652d714bead4c669375a4d  pocknix-sm8750-sd.7z.001
d34caf76e3c132d34120f1ba41d019e7d40e9f6a1d665d800fd61a423d15cbe7  pocknix-sm8750-sd.7z.002
e501fc94f464a0f3a6892d1db8bc1ceb7576aa63575b283c59678ca3cb5d62f9  pocknix-sm8750-sd.7z.003
```

Tras extraerlo, el `.zst` debe dar:

```
31ee0c4f7939fc1a02b21c99e926ee4b54ee5f7a23b1e312592307a4c481d8d1
```

y la imagen sin comprimir:

```
13cbc1de85779cb6086132f463e3290619942567604573f8fd5b2544cff43431
```

## Cómo se abre

Con **7-Zip** (23 o superior), **PeaZip** o cualquier gestor que entienda volúmenes `.7z.00X`:

1. Doble clic en `pocknix-sm8750-sd.7z.001` → *Extraer*. Los tres trozos se unen solos y sale
   `pocknix-sm8750-sd.img.zst`.
2. Doble clic en ese `.zst` → *Extraer*. Sale `pocknix-sm8750-sd.img` (24,5 GiB).

Si tu 7-Zip es antiguo y no abre `.zst`, actualízalo (7-zip.org) o usa:

```bash
zstd -d pocknix-sm8750-sd.img.zst
```

## Cómo grabarla

1. Comprueba el dispositivo con `lsblk` (o el Administrador de discos en Windows).
2. Linux:
   `sudo dd if=pocknix-sm8750-sd.img of=/dev/sdX bs=4M conv=fsync status=progress`
   Windows: **BalenaEtcher** o **Raspberry Pi Imager** (seleccionar el `.img`).
3. Inserta la SD en la Odin y arranca.

Usuario `deck`, root `pocknix`, SSH desactivado por defecto.

## Distribución

La imagen se reparte en trozos por Telegram (unos 11,6 GB). El torrent existe
(`docs/RELEASE-v0.4-odin3-4.md`), pero la conexión de casa está **detrás de CGNAT**: los peers de
fuera no pueden conectar con el seed, así que solo sirve en LAN.

## Gracias

A **Jarvis (DaViDuSkY)** por las pruebas de suspensión en su Odin y el hallazgo del `ath12k`, y a
todos los que reportasteis los cuelgues del QAM y del resume.
