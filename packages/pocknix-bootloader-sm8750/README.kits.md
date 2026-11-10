# pocknix-bootloader-sm8750 — two ABL kits, one package

This package installs two bootloader kits under `/usr/share/pocknix/bootloader/` and
**never flashes anything by itself**. Only `pocknix-update-abl` (or a user running the kit
scripts from Android) writes `abl_a`/`abl_b`.

| Kit | Version | Boots | Role |
|---|---|---|---|
| `rocknix_abl/` | ROCKNIX ABL 1.1.8 | `/KERNEL` (Android boot image) | what the Odin 3 runs today; the fallback / way back |
| `openabl/` | OpenABL 1.2 | BLS: `/loader/entries/*.conf` + `/Image` + `/dtbs/*.dtb` | migration target |

* Both kits ship the same `abl_signed-SM8750.elf` layout, `version`, `README`,
  `flash_abl.sh`, `backup_abl.sh` and `restore_backup_abl.sh` and live side by side.
* `pocknix-update-abl` uses **`openabl/`** when it exists and falls back to `rocknix_abl/`
  only when it does not, so installing this package never changes what the next flash
  writes until the openabl kit is actually present.
* The BLS files OpenABL reads are written by `pocknix-bls-deploy` (pocknix-bsp-common) on
  every kernel/`boot/Image` transaction. They are inert while the ROCKNIX ABL boots, which
  is what makes the migration a two-step, reversible operation: write the files first,
  verify, and flash OpenABL afterwards.
* The SD image copies **both** kits to its boot FAT (`scripts/build-sd-image.sh`), so either
  one can be used to provision a factory device from the card alone.

Byte provenance and the exact release/sha pins are in `README.provenance`.
