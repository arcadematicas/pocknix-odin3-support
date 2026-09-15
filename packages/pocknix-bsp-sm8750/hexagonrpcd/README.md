# hexagonrpcd for Odin 3 (SM8750)

Cross-compile from the host:

```bash
# Clone
git clone https://gitlab.com/sdm670-mainline/hexagonrpc.git /tmp/hexagonrpc
cd /tmp/hexagonrpc

# Cross-compile
meson setup build --cross-file /path/to/hexagonrpc-cross.txt
ninja -C build

# Strip
aarch64-linux-gnu-strip build/hexagonrpcd/hexagonrpcd
aarch64-linux-gnu-strip build/libhexagonrpc/libhexagonrpc.so
```

## Install on Odin

```bash
cp build/hexagonrpcd/hexagonrpcd /usr/bin/
cp build/libhexagonrpc/libhexagonrpc.so /usr/lib/
echo "/usr/lib" > /etc/ld.so.conf.d/hexagonrpc.conf
ldconfig

# Service
cp hexagonrpcd-adsp-sensorspd.service /etc/systemd/system/
systemctl daemon-reload
systemctl enable hexagonrpcd-adsp-sensorspd
systemctl start hexagonrpcd-adsp-sensorspd
```

## Notes

- Requires ADSP to be enabled (see DTS fixes).
- `/dev/fastrpc-adsp-secure` must exist (kernel FastRPC driver).
- The daemon serves a virtual filesystem to the ADSP (HexagonFS). With
  `-R /usr/lib/firmware` it maps:
  - `/usr/lib/firmware/sensors/config/`  -> `/vendor/etc/sensors/config`
  - `/usr/lib/firmware/sensors/sns_reg.conf` -> `/vendor/etc/sensors/sns_reg_config`
  - `/usr/lib/firmware/sensors/registry/` -> `/mnt/vendor/persist/sensors/registry/registry`
  - `/usr/lib/firmware/acdb/` -> `/vendor/etc/acdbdata`
  - `/usr/lib/firmware/dsp/` -> `/usr/lib/qcom/adsp/`

## Sensor config files (REAL, from Android firmware)

Extracted from the stock Android firmware `Odin3_20251206` (vendor partition,
`super_7.img`) into the image:

- `/usr/lib/firmware/sensors/config/` — 140 JSON files incl. the SM8750
  `pakala_*.json` set + `json.lst` (the ADSP registry input list).
- `/usr/lib/firmware/sensors/sns_reg.conf` — real `sns_reg_config` from Android
  (points the registry output to `/mnt/vendor/persist/sensors/registry/registry`,
  which HexagonFS maps to `/usr/lib/firmware/sensors/registry/`).
- `/usr/lib/firmware/sensors/registry/` — writable dir; the daemon writes the
  compiled sensor registry here.
- `/vendor/etc/sensors/` — mirror of the same files (Android paths).

Extraction recipe (host):

```bash
# vendor partition is super_7.img (a plain ext4 image, not a super partition)
debugfs -R "ls -l /etc/sensors/config" super_7.img
# dump each file, e.g.:
debugfs -R "dump /etc/sensors/config/pakala_default_sensors.json ./pakala_default_sensors.json" super_7.img
```

- **Status:** daemon runs with the real configs; check IIO devices with
  `ls /sys/bus/iio/devices/` after boot. If a sensor still doesn't appear,
  check `journalctl -u hexagonrpcd-adsp-sensorspd` and the ADSP log
  (`cat /sys/kernel/debug/remoteproc/remoteproc0/...`).
