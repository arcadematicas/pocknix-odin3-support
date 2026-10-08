# Firmware — AYN Odin 3 / KONKR PF Elite (SM8750 family)

**This directory is a SOURCE TREE, not an install step.** Nothing here is copied into the image
any more: the blobs it holds are staged by `scripts/build-packages.sh` into the package
**`pocknix-firmware-sm8750`** (`devices/sm8750/packages/pocknix-firmware-sm8750/`), which
`build-image.sh` installs from the localrepo like any other package. Read that package's
`PKGBUILD`/`README.md` for the mechanism; this file is about *which* blobs and *why*.

Two source roots feed it, searched in this order by `build-packages.sh`:

| # | root | what it is |
|---|---|---|
| 1 | `devices/sm8750/firmware/` (this dir) | **committed** — our two charger blobs, the battery-authentication ADSP pair. Searched first, so it wins over any vendor copy of the same path. |
| 2 | `vendor/rocknix-extra-firmware/SM8750/` | **gitignored**, `make sync` only — ROCKNIX/extra-firmware pinned to `30c56e2f34af37fe372166b739d6ab277f5155b5`. Everything upstream linux-firmware does not have. |

`./paths` in the package is the manifest (37 entries) and the union of the two roots.

## `qcom/sm8750/adsp.mbn` + `qcom/sm8750/adsp_dtb.mbn` — the charger pair (committed here)

The ADSP **charger** firmware. The Odin 3 DTS
(`kernel/sm8750/dts/qcom/cq8725s-ayn-odin3.dts`) sets
`firmware-name = "qcom/sm8750/adsp.mbn"` — the **bare** path, *not* `ayn/odin3/`. (The CDSP node
right below it names `qcom/sm8750/cdsp.mbn` but has `status = "disabled"`, and the speaker amp
nodes name `qcom/sm8750/ayn/odin3/aw883xx_acf.bin`; `cq8725s-ayn-common.dtsi` adds
`qcom/sm8750/gen80000_zap.mbn` for the ZAP. Earlier revisions of this file claimed the DTS read
`ayn/odin3/adsp.mbn` — it does not.)

`adsp_dtb.mbn` carries the **battery-authentication config**
(`batt_auth_cfg`, `batt-auth-public-key`, `batt-unauth-charging-action`, `en-batt-auth`). The
blob linux-firmware/ROCKNIX ships lacks it, so the ADSP charger firmware cannot authenticate the
battery, falls into **TEST MODE (state 9)** and the battery never charges under Linux. Diagnostics
in `pocknix-odin3-support/BATTERY-ISSUE.md`; the fix itself is upstream's issue
`armada-os/armada#402` (we reported it) and `docs/FIRMWARE-ISSUE.md`.

| file | size | md5 |
|---|---|---|
| `adsp.mbn` | 21907848 | `6cfcbbb80b956ddad76950c038ea1a3e` |
| `adsp_dtb.mbn` | 167736 | `d88d7ecbba78ecacb13adcc7bcbe131d` |

These are the blobs ArmadaOS installs at the same bare paths (its own DTS also reads the bare
`qcom/sm8750/adsp.mbn`); that is where they came from and why they are byte-for-byte what they
are. Verified on-device: `battery status=Charging`, `qcom-battmgr-usb online=1`, `ucsi 3A`, and
the charger-firmware ulog stopped reporting "Test mode".

### Why these two stay in git while nothing else does

No download source of ours produces them (ROCKNIX/extra-firmware's copies are a *different*
binary: `qcom/sm8750/ayn/odin3/adsp.mbn` is 21891464 B / md5 `f82212a2…`, and its
`adsp_dtb.mbn` is md5 `6f4c2eca…`), so a clean build has to carry them or the device ships with a
charger firmware that cannot charge. 22 MB is the price. Everything else keeps coming from the
pinned `vendor/` tree — the same criterion `pocknix-firmware-sm8550` uses.

### Why `qcom/sm8750/ayn/` is gitignored

`.gitignore` has `/devices/sm8750/firmware/qcom/sm8750/ayn/`. What is physically in that
subdirectory are leftovers from the wrong DTS-path guess above: copies byte-identical (same md5)
to the committed pair. **The DTS does not read them for the ADSP** — it reads
`ayn/odin3/` only for `aw883xx_acf.bin`, which the package stages from `vendor/`. So the rule
stays: keeping them would duplicate 22 MB in git for nothing.

## Why the package installs to `updates/`

Every blob goes to `/usr/lib/firmware/updates/<path>`, not `/usr/lib/firmware/<path>`.
`fw_path[]` in `drivers/base/firmware_loader/main.c` searches

```
fw_path_para, "/lib/firmware/updates/" UTS_RELEASE, "/lib/firmware/updates",
"/lib/firmware/" UTS_RELEASE, "/lib/firmware"
```

so `updates/` **wins** — and, more importantly, no other package owns it. Upstream
linux-firmware *does* ship bare `qcom/sm8750/{adsp,adsp_dtb,cdsp,cdsp_dtb,gen80000_zap}.mbn`
and their `.jsn` (verified 03/10/2026 at
`git.kernel.org/pub/scm/linux/kernel/git/firmware/linux-firmware.git/tree/qcom/sm8750`), and
ALARM's `linux-firmware-qcom` (in `config/packages/base.list`) lays them down at exactly those
bare paths. An override written onto the bare path is therefore silently reverted to stock by
any `linux-firmware-qcom` transaction — and stock `adsp_dtb.mbn` carries no battery-auth config,
so the charger drops back into TEST MODE with no error anywhere. Same trap
`pocknix-firmware-sm8550` exists for.

## What comes from `vendor/rocknix-extra-firmware/SM8750/`

`make sync` clones it pinned; `vendor/` is gitignored so no blob enters the repo.

| path (relative to `/usr/lib/firmware/`) | purpose |
|---|---|
| `ath12k/WCN7860/hw2.0/` (amss.bin, aux_ucode.bin, bdwlan.elf, board-2.bin, m3.bin, qdss.cfg, regdb.bin) | WiFi — ath12k WCN7860 hw2.0, the Odin 3's chip. linux-firmware only ships WCN7850, so without this the probe times out (`-110`) and there is no `wlan0` |
| `qcom/sm8750/ayn/odin3/{adspr,adsps,adspua,adspuo,cdspr,battmgr}.jsn` | ADSP/CDSP service configs (the DTS is read per service) |
| `qcom/sm8750/ayn/odin3/aw883xx_acf.bin` | AW88261 speaker-amp calibration |
| `qcom/sm8750/ayn/odin3/{cdsp,cdsp_dtb}.mbn` | CDSP (node currently `disabled` in the DTS) |
| `qcom/sm8750/konkr/pfe/**` | the same set for the KONKR Pocket FIT Elite |
| `qcom/sm8750/SM8750-{AYN,KONKR}-tplg.bin` | ASoC DSP topologies — without them no sound card is created |
| `qca/gngbtfw20.mbn`, `qca/gngbtnv20.bin` | Bluetooth |
| `qcom/vpu/vpu35_p4.mbn` | VPU |

## Caveat: `-Syu` on the device (do not flip it silently)

`devices/sm8750/profile.conf` sets `POCKNIX_SHIP_SOC_REPO=1`: our `sm8750` repo is published
 on R2, so the image ships the `[pocknix]` stanza and a device fetches new package versions
 with plain `pacman -Syu`. (Historically `0` while sm8750 was unpublished; flipped
 09-oct-2026 once the repo + key were live.)

## Guard rails

* `build-packages.sh` `die`s if a `./paths` entry exists in none of the source roots, naming
  `make sync`; `make packages` then prints the "STALE ARTIFACT WILL SHIP" summary rather than
  quietly reusing an old `.pkg.tar`.
* `build-image.sh` `install_local_packages()` checks the package is installed **and** that
  `qcom/sm8750/adsp_dtb.mbn` and `ath12k/WCN7860/hw2.0/amss.bin` exist under
  `/usr/lib/firmware/updates/`, and dies naming the fix otherwise.
