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

## 7. QAM (Quick Access Menu) - Botón Select no abre el menú derecho

**Symptom:** pressing Select in the game session doesn't open the Steam Quick
Access menu (the "..." sidebar).

- **Root cause:** InputPlumber's default `ayn_mcu.yaml` maps Select to `Select`
  (button event passthrough), but Steam expects `QuickAccess` for the QAM.
- **Fix:** replace the capability map:
  ```
  cp config/ayn_mcu.yaml /usr/share/inputplumber/capability_maps/ayn_mcu.yaml
  systemctl restart inputplumber
  ```
- See `config/ayn_mcu.yaml` for the patched file (line 84: `button: QuickAccess`).

## 8. Audio - No sound card detected

**Symptom:** `aplay -l` shows no sound cards; `/proc/asound/cards` is empty.
dmesg: `qcom,fastrpc` and `qcom,apr` fail to probe.

- **Root cause:** the ADSP (remote processor 0) was **disabled** in the DTS
  (`status = "disabled"`) with a wrong firmware path
  (`qcom/sm8750/ayn/odin3/adsp.mbn` — directory doesn't exist). The audio
  DSP chain (q6apm/q6prmcc/lpass) requires the ADSP to be running.
- **Fix (kernel DTS):** re-enable the ADSP and fix firmware paths:
  ```dts
  &remoteproc_adsp {
      firmware-name = "qcom/sm8750/adsp.mbn",
              "qcom/sm8750/adsp_dtb.mbn";
      status = "okay";
  };
  ```
  Firmware files exist at `/usr/lib/firmware/qcom/sm8750/` (not
  `qcom/sm8750/ayn/odin3/`). After boot with the ADSP running, the
  `SM8750-AYN` sound card appears automatically.
- See `kernel/cq8725s-ayn-odin3.dts` for the fixed DTS.

## 9. Battery - pmic_glink not reporting capacity

**Symptom:** `/sys/class/power_supply/battery/capacity` is empty. dmesg shows
`qcom_pmic_glink: Failed to create device link (0x180)`.

- **Root cause:** the pmic_glink (charger/USB power data) communicates through
  the ADSP via the GPR/APR protocol. With the ADSP disabled, the data doesn't
  flow.
- **Fix:** same as #8 — re-enable the ADSP. Once the ADSP boots, the
  pmic_glink data flows and `battery capacity` reports correctly (e.g. 100).

## 10. Plasma Mobile screen inverted (180°)

**Symptom:** the Plasma Mobile desktop is rotated 180° (upside down). KScreen
settings don't show any output controls. Auto-rotate is enabled but has no
effect (gyroscope not detected).

- **Root cause:** KWin reads the DRM rotation property (set to 90° in DTS for
  the boot logo) and adds its own 90° transform on top → total 180°. KScreen
  doesn't enumerate the DSI-1 panel, so no manual controls are available.
- **Fix:** override KWin's output config:
  ```python
  # In ~/.config/kwinoutputconfig.json, for DSI-1:
  #   "autoRotation": "Disabled"
  #   "transform": "Normal"
  ```
  Then make it immutable so KWin can't overwrite on restart:
  ```
  chattr +i ~/.config/kwinoutputconfig.json
  ```
- See `config/odin3-post-boot-setup.sh` for the automated fix.
- **Note:** KScreen still doesn't enumerate DSI-1 — this is a pocknix/rocknix
  upstream issue. See `KSCREEN-ISSUE.md`.

## 11. System suspension on idle

**Symptom:** the Odin suspends after a period of inactivity, losing WiFi and
USB RNDIS connection. The screen goes black and the device becomes unreachable.

- **Root cause:** systemd-logind's idle action defaults to suspend, and WiFi
  power save causes the wireless chip to disconnect after inactivity.
- **Fix (comprehensive):**
  ```bash
  # systemd targets
  systemctl mask sleep.target suspend.target hibernate.target \
      hybrid-sleep.target suspend-then-hibernate.target

  # logind.conf
  echo 'HandleSuspendKey=ignore' >> /etc/systemd/logind.conf
  echo 'HandleLidSwitch=ignore' >> /etc/systemd/logind.conf
  echo 'IdleAction=ignore' >> /etc/systemd/logind.conf
  echo 'IdleActionSec=infinity' >> /etc/systemd/logind.conf

  # WiFi power save off
  mkdir -p /etc/NetworkManager/conf.d
  cat > /etc/NetworkManager/conf.d/no-wifi-powersave.conf << EOF
  [connection]
  wifi.powersave = 2
  EOF
  iw dev wlan0 set power_save off
  ```
- See `config/odin3-post-boot-setup.sh` for the automated fix.

## 12. hexagonrpcd (sensor daemon) - IIO sensors not detected

**Symptom:** no IIO accelerometer/gyroscope devices appear in
`/sys/bus/iio/devices/`. `iio-sensor-proxy` reports `'registry' sensor
unavailable, is hexagonrpcd running?`.

- **Root cause:** `hexagonrpcd` needs vendor sensor config files that are not
  present in the pocknix rootfs:
  - `/vendor/etc/sensors/sns_reg_config` — sensor registry configuration
  - `/etc/sensors/config/json.lst` — sensor config list
  These are normally provided by the Android vendor partition.
- **Fix:** cross-compile hexagonrpcd from
  `gitlab.com/sdm670-mainline/hexagonrpc` (meson, aarch64), then install:
  ```bash
  # Build (on host)
  meson setup build --cross-file hexagonrpc-cross.txt
  ninja -C build
  aarch64-linux-gnu-strip build/hexagonrpcd/hexagonrpcd
  aarch64-linux-gnu-strip build/libhexagonrpc/libhexagonrpc.so

  # Install on device
  cp build/hexagonrpcd/hexagonrpcd /usr/bin/
  cp build/libhexagonrpc/libhexagonrpc.so /usr/lib/
  ldconfig

  # Create sensor config
  mkdir -p /vendor/etc/sensors /etc/sensors/config
  echo '{"accel":{"sensor_id":1},"gyro":{"sensor_id":2}}' \
      > /vendor/etc/sensors/sns_reg_config
  cp /vendor/etc/sensors/sns_reg_config /etc/sensors/sns_reg_config
  echo -e "accel.json\ngyro.json" > /etc/sensors/config/json.lst

  # Enable service
  systemctl daemon-reload
  systemctl restart hexagonrpcd-adsp-sensorspd
  ```
- **Current status:** hexagonrpcd installs and runs (exit 0), but IIO devices
  still don't appear. The sensor config files may need to match the exact
  format expected by the ADSP firmware. Further investigation needed.
- See `config/hexagonrpcd/` for service files and cross-compile setup.
