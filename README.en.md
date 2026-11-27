<div align="center">

# 🎮 CalvOS

*(🇪🇸 [Versión en español](README.md))*

**Arch Linux ARM + Steam, gamescope and emulation for the AYN Odin 3**
*(Qualcomm Snapdragon 8 Elite · SM8750 · Adreno 830)*

[![Release](https://img.shields.io/github/v/release/arcadematicas/pocknix-odin3-support?label=CalvOS&color=2f81f7)](https://github.com/arcadematicas/pocknix-odin3-support/releases/latest)
[![Arch](https://img.shields.io/badge/arch-aarch64-orange)]()
[![Kernel](https://img.shields.io/badge/kernel-7.2.15-informational)]()
[![License](https://img.shields.io/badge/license-GPL--2.0-green)](LICENSE.md)
[![Upstream](https://img.shields.io/badge/upstream-pocknix--os-8957e5)](https://github.com/shuuri-labs/pocknix-os)

**CalvOS** turns the **AYN Odin 3** into a gaming handheld/PC with the *SteamOS* experience:
Steam in **Game Mode** under **gamescope**, Windows games through **ARM64 Proton (FEX)**,
**Linux PC ports (decomps)**, **emulators ready out of the box with DeckStation**, **Decky**
plugins and a full **KDE Plasma** desktop.

An **[arcadematicas](https://github.com/arcadematicas)** project, built on
**[pocknix-os](https://github.com/shuuri-labs/pocknix-os)** (Arch Linux ARM).

</div>

---

> 📚 **[User manuals](docs/guias/README.md)** (Spanish): DeckStation, WProton, Linux decomps, power/HDR, capture and diagnostics.

## ✨ Out of the box

| | |
|---|---|
| 🕹️ **Steam games** | Native **Steam ARM64** client in Game Mode (gamepadui) under **gamescope** (OGC build). UI at the right scale (`--fake-output-mm`). |
| 🪟 **Windows games** | **ARM64 Proton + FEX**; **WProton** (`1.72`) to launch `.wsquashfs` titles with its runners. |
| 🐧 **Linux PC ports** | **Decomps** launched from a Steam tile: AppImage/ELF/.sh under **Box64**, **.NET x86_64** runtime and **persistent** AppImage extraction (no `/tmp`). See the [manual](docs/guias/DECOMP-LINUX.md) and [compatibility matrix](docs/CALVOS-DECOMP-COMPAT.md). |
| 🎮 **Emulation** | **DeckStation** (`/opt/deckstation`): **ES-DE** + ~30 aarch64 emulators (RetroArch + 200 cores, Dolphin, DuckStation, Cemu, Eden, MAME…). **New: PS2 with Armsx2 and PS3 with RPCS3** (portable ARM64 AppImages). First install **without limits**: it resolves assets without the GitHub API. |
| 🎞️ **Frame generation** | **MAKO on aarch64** managed from the **Control Panel**: its own **MAKO FG** engine (×2/×3, adaptive) and **LSFG** using your **Lossless Scaling**, plus MAKO scaling. |
| 🧩 **Plugins (Decky)** | **CalvOS Control** (TDP, manual HDR, OLED care, snapshots, updates), **CSS Loader** and the **Eclipse 0.3.2** theme (self-updating). |
| 🖥️ **Desktop** | **KDE Plasma 6 (Wayland + Plasma Mobile)** with KScreen working. |
| 🖼️ **Display** | **Hardware rotation** of the DPU (no GPU cost) and **HDR off by default** (keeps the QAM/MangoHUD on top; enable it by hand). |
| 🔋 **Power** | Real **`deep`** suspend (**0.14 %/h** idle; a third of `s2idle`), battery-auth charging and estimated percentage. |
| 🎥 **Video** | **Hardware decoding (VA-API)** on the **iris** decoder (`/dev/video0-1`): H.264/HEVC/VP9/AV1, H.264/HEVC encode. For **Moonlight**, mpv and browsers. |
| 🔊 **Audio & input** | LPASS stack + UCM (`SM8750AYN`) with speaker/headphone verbs and automatic jack switching; **headphone buzz fixed** (class-H port SSP). **InputPlumber** (UART gamepad + paddles). |
| 📦 **Updates** | **Own signed pacman repo on Cloudflare R2**, **no `[aur]`** → `pacman -Syu` brings everything (kernel, Mesa, Steam, Decky…). |
| 🧱 **Kernel** | **`linux-pocknix-sm8750 7.2.15-8`** (acceleration patches, Adreno 830 GPU, `ath12k` WCN7860 Wi-Fi, battery) + an **anti-bootloop** ath12k patch. |

## 📥 Install

1. **Download** the latest image from **[Releases](https://github.com/arcadematicas/pocknix-odin3-support/releases/latest)** (`pocknix-sm8750-sd.img`, ~25.6 GB).
2. **Flash** it to a **64 GB or larger** microSD:
   ```sh
   sudo dd if=pocknix-sm8750-sd.img of=/dev/sdX bs=4M conv=fsync status=progress
   ```
   *(double-check the device with `lsblk` first — `dd` does not forgive)*
3. **Boot** the Odin with the card inserted. User **`deck`** / root password **`pocknix`**.
   SSH is **OFF** by default (enable it in *CalvOS Tools*).

> 💡 The first boot takes a moment: the btrfs root expands to the whole card and Steam gets set up.

## 🔄 Update

```sh
sudo pacman -Syu      # or from the QAM / CalvOS Control
```

## 📸 Screenshots

<p align="center">
  <img src="docs/screenshots/01-biblioteca.jpg" width="49%">
  <img src="docs/screenshots/02-qam-pocknixcontrol.jpg" width="49%">
</p>
<p align="center">
  <img src="docs/screenshots/03-qam-tema-eclipse.jpg" width="49%">
  <img src="docs/screenshots/04-deckstation.jpg" width="49%">
</p>
<p align="center">
  <img src="docs/screenshots/05-wproton.jpg" width="49%">
  <img src="docs/screenshots/06-plasma.jpg" width="49%">
</p>
<p align="center">
  <img src="docs/screenshots/07-pocknix-tools.jpg" width="49%">
  <img src="docs/screenshots/08-ajustes-steam.jpg" width="49%">
</p>
<p align="center">
  <img src="docs/screenshots/09-qam-juego-detras.jpg" width="49%">
  <img src="docs/screenshots/10-sistema.jpg" width="49%">
</p>
<p align="center">
  <img src="docs/screenshots/11-informacion-sistema.jpg" width="49%">
  <img src="docs/screenshots/12-menu-inicio-plasma.jpg" width="49%">
</p>

## 📊 Status (2026-11-27)

| Area | Status |
|---|---|
| **Boot** | ✅ Kernel **7.2.15-8** + Odin 3 device tree · **OpenABL 1.2 on both slots** |
| **Rotation** | ✅ **Hardware** (DPU scanout) |
| **Steam** | ✅ gamescope session + Steam gamepadui, UI at the right scale |
| **HDR** | ⚠️ **OFF by default** (on purpose: with global HDR the QAM/MangoHUD fell behind). Manual toggle in CalvOS Control |
| **Graphics** | ✅ **Mesa 26.3.0** + our Turnip + **Valve's Turnip** (`pocknix-vk-valve`, per-game) |
| **Emulation** | ✅ **DeckStation**: full first install (**31/31**) with the GitHub API exhausted |
| **WProton** | ✅ **1.72** (`arm-2026-10-11a`) — download a runner from its menu |
| **Wi-Fi / BT** | ✅ `ath12k` WCN7860 + **anti-bootloop patch** (`0041b`) |
| **Audio / input / battery** | ✅ LPASS + UCM · InputPlumber · battery-auth charging |
| **Suspend** | ✅ real s2idle |

---

## 📚 Documentation & source of truth

This repo (`pocknix-odin3-support`) is **the source of truth** for our work: kernel and gamescope
patches, our packages, system overlay, tooling and the documentation — **in Spanish**, under
[`docs/`](docs/). The build tree lives in
**[`arcadematicas/pocknix-os`](https://github.com/arcadematicas/pocknix-os)** (branch
`odin3-sm8750`) and is regenerated from here, never the other way round.

## ⚖️ License

**GPL-2.0** (same as [pocknix-os](https://github.com/shuuri-labs/pocknix-os) and ROCKNIX).
Vendored third-party components keep their own licences (e.g. DeckStation / WProton: GPL-3.0).
See [`LICENSE.md`](LICENSE.md).
