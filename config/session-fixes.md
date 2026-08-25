# Session / streaming fixes that made pocknix-os work on the AYN Odin 3

These are the pocknix-os user-space fixes (on top of the kernel DTS + the
Adreno a8xx GPU patch) that got the Steam/gamescope session and the desktop
running on the **AYN Odin 3** (SM8750 / Snapdragon 8 Elite, Adreno 830).

All are applied on the device/rootfs. Credentials are intentionally omitted.

---

## 1. gamescope compositor `VkDeviceLost` (VkResult -4)

**Symptom:** gamescope compositor aborts with `vk.WaitSemaphores failed
(VkResult:-4)` / `DEVICE_LOST` under render load (Steam gamepadui).

- **Root cause (kernel):** the GMU hang left the GX GDSC voted on in HW, so the
  CX GDSC couldn't collapse in `a8xx_recover()` → next `hw_init` timed out on
  "GMU OOB GPU_SET". Fixed in the kernel — see
  `../kernel/0001-adreno-a8xx-force-gx-collapse-before-cx.patch`.
- On the 7.1.0 kernel with that patch, the compositor no longer loses the
  device.

## 2. Steam client `bin/vgui2_s.dll` ("Could not load module")

**Symptom:** Steam Deck (gamepadui) client fails at startup with
`Fatal Error: Could not load module 'bin/vgui2_s.dll'`.

- **Root cause:** the ARM64 client's `vgui2_s.so` had a missing dependency
  (`libopenal.so.1`). Without it, `dlopen` fails even though the .so exists.
- **Fix:** link the ARM64 `libopenal.so.1` (from the Steam runtime) into the
  client dir so `LD_LIBRARY_PATH` finds it:
  ```
  cp <steam-runtime-arm64(...)/lib/aarch64-linux-gnu/libopenal.so.1.19.1> \
     $HOME/.local/share/Steam/steamrtarm64/
  ln -sf libopenal.so.1.19.1 $HOME/.local/share/Steam/steamrtarm64/libopenal.so.1
  ```

## 3. Steam IPC `GetIPCConnectionDetails: command failed: 127`

**Symptom:** the gamepadui IPC never connects (shows the `0x3024` startup
error), Steam web transport connections are rejected.

- **Root cause:** Steam's IPC runs `lsof`, which isn't installed on the
  minimal rootfs (exit 127 = command not found).
- **Fix:** `pacman -S lsof`.

## 4. Controller not detected by Steam Input

**Symptom:** the built-in Odin 3 gamepad does not navigate the UI (only the
touchscreen works).

- **Root cause:** **InputPlumber** (the composite Steam Controller publisher)
  was not installed, so Steam Input saw no controller.
- **Fix:**
  ```
  pacman -S inputplumber
  systemctl enable --now inputplumber
  pocknix-gamepad-target deck   # exposes a "Generic Steam Controller" (VID 0x28de)
  ```
  Restart the session so Steam Input re-enumerates the controller.

## 5. WiFi "no networks found"

**Symptom:** the gamepadui WiFi page shows no networks even though the radio
works.

- **Root cause:** the WiFi is managed by a seed `wpa_supplicant@wlan0` that
  holds the interface, so **NetworkManager** (used by the session) can't scan.
- **Fix:**
  ```
  systemctl enable --now NetworkManager
  systemctl disable --now wpa_supplicant@wlan0.service   # stop the seed conflict
  nmcli radio wifi on
  nmcli con up <your-ssid>
  ```
  Also protect the RNDIS gadget from NetworkManager (so SSH over USB isn't
  dropped):
  ```
  # /etc/NetworkManager/conf.d/99-pocknix-usb0.conf
  [keyfile]
  unmanaged-devices=interface-name:usb0
  ```

## 6. pocknix-tools "kdialog not installed"

- `pacman -S kdialog`
