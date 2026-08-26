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
- The daemon needs vendor sensor config files at `/vendor/etc/sensors/sns_reg_config`.
- **Status:** installs and runs, but IIO devices don't appear yet. The
  `sns_reg_config` format may need adjustment for the SM8750 ADSP firmware.
