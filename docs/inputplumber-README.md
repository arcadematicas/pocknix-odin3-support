# InputPlumber overrides — AYN Odin 3 (SM8750)

Applied to the image rootfs **after** `install_local_packages` (see
`install_inputplumber_overrides()` in `scripts/build-image.sh`), so they win over
whatever the ROCKNIX overlay / inputplumber package ships. Paths are relative to
`/usr/share/inputplumber/`.

## Why

The ROCKNIX AYN capability map (`ayn_mcu.yaml`) maps `BTN_BACK` (the physical
Quick Access button) to **keyboard `KeyF1`** — a key ROCKNIX's own UI uses. On a
Steam Deck target that leaves Steam **without a Quick Access button**, and the
Steam/QAM buttons don't end up where they should (on opposite sides).

pocknix already applies the delta on SM8250/SM8550 (`rp5-gamepad.yaml`,
`sm8550-gamepad.yaml`): `BTN_BACK` -> gamepad **`QuickAccess`**. This directory
brings the same fix to the Odin 3.

## Contents

- `capability_maps/ayn_mcu.yaml` — AYN MCU map, taken from ArmadaOS: `BTN_MODE`
  -> Guide, **`BTN_BACK` -> QuickAccess**, `KEY_F24` -> keyboard `KeyHome`,
  paddles -> `LeftPaddle1`/`RightPaddle1`.
- `devices/01-ayn-controller.yaml` — composite device (dt-model gated on
  `AYN Odin 3`), target **`deck`** + `keyboard` (Steam-native pad, so Steam Input
  sees the Steam and Quick Access buttons).

Reference copies live in `pocknix-odin3-support/config/inputplumber/`.
