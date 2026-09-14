# PR Description — SM8750 / AYN Odin 3 support

> Copy-paste ready for `shuuri-labs/pocknix-os`.

---

## Title (suggested)

```
feat(sm8750): AYN Odin 3 family — kernel 7.2, DTS, 71 patches, device profile, boot/OOBE fixes
```

---

## Body

### Summary

Adds full support for the **AYN Odin 3** family (Qualcomm SM8750 / Snapdragon 8
Elite, Adreno 830). This brings Pocknix to a second generation of AYN handhelds,
building on the existing SM8550 (Odin 2) work.

**What's included:** Linux 7.2 kernel with device-tree for the Odin 3, 71 kernel
patches (including the Adreno a8xx GX-collapse fix), SoC-tuned packages, a
bootloader, device profile, and firmware sourced from ROCKNIX extra-firmware
(no binaries committed to the repo).

### What changed

**Kernel / DTS**
- `kernel/sm8750/` — full patch series (0026–0509+), SM8750 defconfig, device-tree
  for the Odin 3 (`cq8725s-ayn-odin3.dts`) and Konkr PF Elite.
- `0051-adreno-a8xx-force-gx-collapse-before-cx.patch` — complements ROCKNIX's
  `0050` to fix `VkDeviceLost` on Adreno 830.
- Boot image generation for `make build`.

**Firmware handling**
- Firmware is sourced from `ROCKNIX/extra-firmware` (pinned commit `30c56e2`),
  downloaded at `make sync` time into `vendor/rocknix-extra-firmware/`
  (gitignored — no binaries in the repo).
- `install_firmware()` rsyncs the SM8750 tree (WiFi `WCN7860`, ADSP/CDSP, audio
  topology, speaker amp config) to the rootfs.
- Charge-fix firmware (`adsp.mbn` + `adsp_dtb.mbn` with battery authentication
  config) lives in `devices/sm8750/firmware/` and is applied after the ROCKNIX
  overlay.

**Boot fix**
- `pocknix-diag.service` → timer (`pocknix-diag.timer`, `OnBootSec=45s`) so it
  no longer blocks `multi-user.target` during boot.
- `pocknix-steam` waits for the DSI panel to report `connected` (up to 30 s)
  before launching gamescope, preventing a black-screen race on cold boot.

**Steam OOBE (first-run experience)**
- `pocknix-steamos-shim` installs `/etc/steamos-oobe-image` so the Steam client
  shows the initial setup wizard (language, timezone, WiFi) on a clean image.
- `steamos-update` and `steamos-mandatory-update` now return exit code 7 ("no
  update available") for `apply` and any call without `check`, matching Valve's
  contract in `jupiter-legacy-support`. Previously `apply` returned 0, which the
  client interpreted as "update applied → system restart required", causing an
  infinite reboot loop during OOBE.

**Other**
- `pocknix-flathub.service` no longer blocks boot (removed
  `After=/Wants=network-online.target` — it was downloading 300+ MB of Flatpaks
  inside the boot transaction).
- SoC packages (`socs` lists in mesa, gamescope, mangohud, fex-emu, turnip,
  etc.) now include `sm8750`.

### Verified on device (clean image, AYN Odin 3)

| Feature | Status | Notes |
|---|---|---|
| Boot time | **20.7 s** total (11.2 s kernel + 9.5 s userspace) | `graphical.target` at 9.5 s |
| `systemctl is-system-running` | `running` | Was stuck at `starting` before fix |
| WiFi | WCN7860, 5 GHz | `ath12k` firmware from extra-firmware |
| Audio | ADSP + CDSP running, `SM8750-AYN` card | `aw883xx` speaker amp + topology |
| Battery / charging | Charging, `battmgr-usb online=1` | Requires `adsp_dtb.mbn` with auth config |
| Suspend (s2idle) | Real suspend + resume with screen | `mem_sleep_default=s2idle` in cmdline |
| OOBE | Full first-run wizard works | No reboot loop, wizard completes |
| Steam login | OK | `steamdeck_publicbeta` channel |
| Desktop (Plasma) | KScreen detects panel, rotation OK | `kscreen` package included |

### Notes for the maintainer

- **No binaries in the repository.** All firmware is fetched at build time from
  `ROCKNIX/extra-firmware` (commit `30c56e2`). The `vendor/` directory is
  gitignored.
- The commit series is based on top of `make sync` against ROCKNIX `next`.
  Each commit is a logical delta: SoC enablement → kernel/DTS → firmware
  sourcing → boot/OOBE fixes.
- The `adsp_dtb.mbn` override in `devices/sm8750/firmware/` is needed because
  the upstream ROCKNIX version may lack battery authentication config required
  for some Odin 3 units. If upstream catches up, this can be dropped.
- `steamos-mandatory-update` does not exist in upstream SteamOS; it is a
  Pocknix shim used as a check gate by the OOBE. Returning 7 is correct.
- The Adreno a8xx patch (`0051`) complements ROCKNIX's `0050` — both are
  required. The `0050` defines `power_off` for the GX GDSC but only with
  `synced_poweroff`; `0051` is who triggers it in `a8xx_recover`.

### Commits (10)

```
d13f65d fix(steamos-shim): steamos-update/mandatory apply -> exit 7 (no 'system restart required')
b88018d feat(steamos-shim): OOBE marker + shims steamos-mandatory-update/jupiter-initial-firmware-update (pkgrel 8)
e574b2a fix(boot): pocknix-diag a timer (no bloquea multi-user.target) + gate DRM en pocknix-steam
fbe787e fix(sm8750): ship the Odin 3 firmware linux-firmware lacks (wifi/ADSP/audio)
d931c25 fix(sm8750): cmdline quiet/plymouth (mirror sm8550) + README.provenance SM8750 + sin binarios en el repo
eec2d4a build(emulation): emuladores -bin prebuilt a optdepends (fuentes upstream caducadas)
a953748 fix(firmware): blobs ADSP del Odin 3 + install_firmware tolerante al overlay de ROCKNIX
a3269dd fix(soc): anadir sm8750 a los paquetes tuneados por-SoC
ea3cfe9 build(kernel/sm8750): re-sync con ROCKNIX actual + parche a8xx
773b14f feat(sm8750): soporte de la familia AYN Odin 3 (kernel + BSP)
```
