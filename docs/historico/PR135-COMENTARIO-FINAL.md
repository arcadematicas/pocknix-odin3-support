# PR #135 — comentario final (listo para publicar)

> Texto en inglés, pensado para pegar tal cual en `shuuri-labs/pocknix-os#135`.
> Todo lo de aquí está **medido en una AYN Odin 3** con un build fresco de `sm8750-odin3`
> (kernel 7.2.10) el 14/10/2026. Lo generamos nosotros (`@arcadematicas`).

---

Hi! We built `sm8750-odin3` from scratch on an Odin 3 (chroot reused, `DEVICE=sm8750`) and ran the full
B1 checklist on the console. **Short version: it boots, and everything you asked us to watch is fine.**
Details, plus a few things you'll want to fix, below.

## Build

~20 packages built fine (kernel 7.2.10, `gamescope 1:3.16.31.rocknix.20260927.f6916aa`, `mesa 2:26.2.4`,
`fex-emu-2610`, `cemu`, `dolphin-emu`, `azahar`, `es-de`, `deckstation-arm`, `fex-rootfs`,
`pocknix-bootloader-sm8750 1.2`, …). Five packages fail, all of them upstream emulation/sched_ext ones,
not your enablement:

1. `armsx2-bin`, `rpcs3-bin`, `xemu-bin` (and probably `vita3k-bin`): the AppImages no longer ship a
   `.DirIcon`, so `prepare()` dies in `cp -L "${root}/.DirIcon"` **before** reaching the
   `[ -s "${srcdir}/icon.svg" ]` guard. A `|| true` (or extracting the icon from another path) fixes it.
2. `vita3k-bin`: `ERROR: One or more files did not pass the validity check!` → stale source sha256.
3. `scx-scheds 1.1.3`: `thread 'main' panicked at scheds/rust/scx_p2dq/build.rs:23` →
   `failed to generate .../bpf.bpf.o` → `Broken pipe (os error 32)` (BPF skeleton generation).

## `make sd-image` — two bugs, both in your tree

4. **`SD_SLACK_MIB` is too tight**: `config/pocknix.conf` defaults it to `1024`, and
   `scripts/build-sd-image.sh` requires **≥512 MiB free** after populating →
   `error btrfs root has only 493 MiB free after populate (< 512 MiB)`. We run `2048` in our fork for
   exactly this. Workaround that needs no patch: `sudo DEVICE=sm8750 SD_SLACK_MIB=2048 make sd-image`
   (the `:=` respects the environment).
5. **`copy_abl_kit()` runs `rsync -a` onto a vfat partition** (the ABL/qcom path, i.e. the Odin 3):
   ```
   rsync: [generator] chown ".../rocknix_abl" failed: Operation not permitted (1)
   rsync error: some files/attrs were not transferred ... (code 23)
   ```
   vfat has no ownership and `-a` implies `-o -g`. Fix: `rsync -rltD --no-owner --no-group`
   (same for `populate_arm_efi_boot`). **Note:** #5 only shows up *after* fixing #4, so you probably
   haven't generated an Odin 3 image from this branch yet. With both patched, `make sd-image` completes
   (21 GB image, `sha256 6e3da7b036c23caa2351ed5518169737b1dc87c72e5671884935c01c7d77441b`).

## ⚠️ The image can't install or update *anything* on sm8750

`/etc/pacman.conf` in the image:
```
[pocknix]        Server = https://pocknix.shuuri.net/repo/sm8750     ← always 404 (upstream never published sm8750)
[pocknix-shared] Server = .../shared
[pocknix-base]   Server = .../base
   ↑ and there are NO [core]/[extra] ALARM stanzas at all
```
So `pacman -Sy` fails outright, and the **PocknixControl (Decky) updater dies with a traceback**:
```
decky_loader/... Exception: Could not refresh package databases: error: failed retrieving file
'pocknix.db' from pocknix.shuuri.net ... error: failed to synchronize all databases
```
(the desktop updater fails the same way, for the same reason). On a fresh device you can't install
emulators, packages — nothing.

What we do in our fork: `render_pacman_conf()` in `scripts/build-image.sh` **always appends
`[core]/[extra]/[alarm]/[aur]` from ALARM** under the pocknix stanzas, and the per-SoC stanza is skippable
with **`POCKNIX_SHIP_SOC_REPO=0`** when that repo doesn't exist. Happy to open a PR with it.

## Battery

Two things here:

- Your question about the numbers: the pack itself answers it —
  `/sys/class/power_supply/battery/model_name` = `8055207_QUECTEL_LIVESTREAMING_8000MAH_AVERAGED_MASTERSLAVE_SEP7TH2025`
  (it literally says `8000MAH`), `charge_full ≈ 7852514 uAh` (measured on our image, where the node still exists), and AYN's product page says *8000 mAh*.
  The `18500000 uWh` (18.5 Wh) that produced the original "5000" is the inconsistent value
  (18.5 Wh / 3.7 V ≈ 5000 mAh), so `charge_full_design = 8000 mAh` with a consistent `energy_full_design`
  is the right shape.
- **With the `simple-battery` node dropped, the battery loses its time estimate** (only % is left):
  ```
  upower -d → energy: 0 Wh · energy-empty: 0 Wh · energy-full: 0 Wh · energy-full-design: 0 Wh
  ```
  UPower cannot estimate runtime without `energy-full`. Restoring the node brings the estimate back —
  that's one more reason to put it back, not just the % number.

## WiFi on a freshly flashed device is a dead end (worth fixing)

`wlan0` comes up fine (`ath12k` + `iwd`, `-24 dBm` on channel 52), but:

- NM uses **`iwd` as the backend** and the image ships **no saved network**;
- the **Steam OOBE (ARM64 client) never offers a WiFi picker**, so the user reaches the login with no network;
- and the image ships **SSH off** (`SSH is OFF in this image`).

⇒ a freshly flashed device is stuck unless you seed the WiFi by hand. To test we had to patch the SD
offline with `/etc/NetworkManager/system-connections/<SSID>.nmconnection` **and**
`/var/lib/iwd/<SSID>.psk` (NM doesn't pass the keyfile PSK to iwd) plus enabling `sshd`. Suggest either a
first-boot WiFi mechanism or shipping `sshd` enabled in test images.

## B1 checklist (measured on the console)

- **wifi**: ✅ connects and holds (`Lacueva`, ch52 DFS, -24 dBm, 1200/1080 Mbit/s); reconnects by itself on a cold boot.
- **audio**: ✅ PipeWire up, both sinks present (Speaker default + Headphones).
- **suspend**: ✅ `[s2idle] deep` + `mem_sleep_default=s2idle` in the cmdline.
- **gamepad + paddles**: ✅ `/dev/input/event0..6` present.
- **gamescope rotation**: ✅ no black screen, no 30 fps lock — **and your inline rotation patch holds up**.
- **dock DP**: not tested (no dock on hand right now).
- **battery**: ✅ `capacity=56`, `state=discharging`, values coherent (see above).
- **cold boots with `POCKNIX_PANEL_WAIT=0`**: ✅ 3 consecutive cold boots, panel up every time, **0 panel/DRM
  errors** in the journal → looks like the panel wait really isn't needed, your call.
- **QAM/MangoHUD with HDR on**: ✅ stays in front of the game (HDR comes up enabled here and we couldn't
  force the "behind the game" case). Good news: the issue we hit on our own stack does **not** reproduce
  with your gamescope.

## Smaller observations

- `country 00: DFS-UNSET` — the same thing we fixed on our side: `CONFIG_CFG80211=y` (built-in) means
  `regulatory.db` never loads (no initramfs, no userspace fallback), so `iw reg set` is a no-op and the
  5 GHz band stays passive-only. Doesn't block the connection, but worth knowing (`cfg80211`/`mac80211`
  as modules fixes it).
- `usr/lib/firmware/ath12k/` has **no `WCN7860`** blob (only `WCN7850`, …) — the chip works anyway, but
  the module asks for the real one; our fork pulls ROCKNIX's `extra-firmware` set.
- `qcom,apr 6800000.remoteproc: Handover signaled, but it already happened` ×88–200 per boot (ADSP ends up
  `running`); plus `qcom-soundwire 7630000.soundwire: dout-ports (0) mismatch with controller (1)` and one
  `qcom-apm gprsvc:service:2:1: CMD timeout` on the audio path.
- On one earlier boot we saw `ath12k` crash-and-recover twice (`Hardware restart was requested`,
  `failed to stopt 11d scan vdev 0 ret: -108`) — that's the loop our `0041b` patch stops; we agreed to send
  it as a PR to `kernel/common`. Not seen again in later boots.
- `oops=panic panic=5` is missing from your cmdline (ours has it) — intentional?

Thanks — and happy to send PRs for #4, #5 and the pacman.conf one (we have them).
