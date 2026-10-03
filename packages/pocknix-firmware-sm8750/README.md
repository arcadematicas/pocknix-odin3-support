# pocknix-firmware-sm8750

The SM8750 family's vendor firmware (AYN Odin 3 + KONKR Pocket FIT Elite) as a **package**,
so it installs from the localrepo like everything else and a device can update it with
**`-Syu`** instead of needing a reflash. Model: `devices/sm8550/packages/pocknix-firmware-sm8550`
(same PKGBUILD shape, same `./paths` + `./staged` mechanism, same `updates/` contract).

Integrated the same way sm8550 is: `pocknix-bsp-sm8750` has it in `depends=`, so the image
gets it through `pocknix-device-sm8750` and `-Syu` on the device reaches it.

## Why it exists (the two bugs it fixes)

1. **"A clean build may not charge."** The charger blobs (`adsp.mbn` + `adsp_dtb.mbn`) used to
   reach the image only through `build-image.sh`'s rsync of `devices/sm8750/firmware/`, and a
   copy of them sat in `.gitignore` on the PR branch — so a clean checkout had **no** charger
   firmware at the path the DTS asks for and the ADSP charger stayed offline. It is a package
   now, and `build-image.sh` verifies it landed (see *Guards*).
2. **A silent `-Syu` regression.** Upstream linux-firmware *does* ship the bare
   `qcom/sm8750/{adsp,cdsp,gen80000_zap}.mbn` paths, and ALARM's `linux-firmware-qcom`
   (installed from `config/packages/base.list`) puts its stock copies there. Our battery-auth
   `adsp_dtb.mbn` used to be rsynced onto that same bare path, so any `linux-firmware-qcom`
   transaction reverted it to the stock blob and the charger dropped back into TEST MODE
   (state 9) — the battery stops charging, with no error anywhere. Installing into
   `/usr/lib/firmware/updates/` (searched **before** `/usr/lib/firmware/`, `fw_path[]` in
   `drivers/base/firmware_loader/main.c`) is what makes that impossible: no package owns
   `updates/`, so nothing can overwrite it.

## Where every blob comes from

`./paths` is the manifest: one path per line, relative to a firmware tree root. No comments
(the `package()` loop reads it verbatim, like sm8550's).

| source | what it provides | in git? |
|---|---|---|
| `devices/sm8750/firmware/` (searched **first**, wins) | `qcom/sm8750/adsp.mbn`, `qcom/sm8750/adsp_dtb.mbn` — **our** battery-auth ADSP pair (ArmadaOS blobs) | **yes, committed** (2 files, 22 MB) |
| `vendor/rocknix-extra-firmware/SM8750/` (pinned `30c56e2`, `make sync`) | everything upstream linux-firmware does not have: ath12k WCN7860 wifi, `ayn/odin3/` + `konkr/pfe/` ADSP/CDSP, `SM8750-{AYN,KONKR}-tplg.bin`, the `.jsn` service configs, BT (`qca/gngbt*`), VPU (`vpu35_p4.mbn`) | no (`vendor/` is gitignored) |

So: **no new binaries are added to the repo.** The two charger blobs were already committed in
`devices/sm8750/firmware/` (they have to be — ROCKNIX's copy of the same paths lacks the
battery-auth config and no download source of ours produces them); everything else keeps coming
from the pinned, downloaded `vendor/` tree, exactly as sm8550's package does. The `.gitignore`
rule for `devices/sm8750/firmware/qcom/sm8750/ayn/` **stays**: those were byte-identical
duplicates left over from an earlier wrong guess about the DTS path, and the blobs that matter
are the two committed ones.

## Regenerating `./paths`

After a `make sync` that moves the ROCKNIX/extra-firmware pin, or after adding an override blob:

```sh
cd vendor/rocknix-extra-firmware/SM8750 && find . -type f -printf '%P\n' | LC_ALL=C sort -u
# + the committed overrides under devices/sm8750/firmware/, merged and sorted:
{ (cd vendor/rocknix-extra-firmware/SM8750 && find . -type f -printf '%P\n')
  (cd devices/sm8750/firmware      && find . -type f -printf '%P\n'); } | LC_ALL=C sort -u > paths
```

Then bump `pkgrel`. `build-packages.sh` dies with the missing path if `./paths` and the vendor
tree disagree, so a stale manifest can never silently ship an image without firmware.

## Guards

* `build-packages.sh`: staging `die`s if a `./paths` entry is in none of the source roots, and
  `make packages` prints the usual "STALE ARTIFACT WILL SHIP" summary if the rebuild failed.
* `build-image.sh` `install_local_packages()`: after the device metapackage install it checks the
  package is installed **and** that `adsp_dtb.mbn` and the WCN7860 `amss.bin` landed under
  `updates/`, and dies naming the fix if not. An image without them has no wifi, no audio and no
  charger firmware.
