# 🆘 HELP REQUEST: Odin 3 battery won't charge on Linux (Pocknix)

**Hi AYN / Armada community** 👋

I have an **AYN Odin 3** (Snapdragon 8 Elite / SM8750) running **Pocknix** (Arch Linux ARM, SteamOS-style). The system works great (Steam, games, GPU, controllers...), but there's **ONE issue I can't solve**: **the battery won't charge on Linux**.

## The problem

- **Pocknix (Linux)**: battery **does NOT charge**. It drains even with the charger plugged in.
- **ROCKNIX (another Linux)**: on the **same hardware**, battery **charges perfectly** (verified live).
- **Android**: also charges fine (the stock OS).

So the hardware charges — it's just **Pocknix that can't get it to charge**.

## Technical symptoms (measured live)

| | ROCKNIX (charges ✅) | Pocknix (no charge ❌) |
|---|---|---|
| Battery status | `Charging` (+198mA) | `Discharging` (-500mA) |
| PD negotiation | **9V / 3A** | Stuck at **5V** |
| `qcom-battmgr-usb online` | 1 | **0 always** |
| `ucsi` sees the charger | Yes | Yes (1.25A coming in) |
| Does the battery gain charge? | Yes | **No** (energy never reaches the battery) |

**The weird part**: on Pocknix the system DOES see the charger (UCSI reports 1.25A coming in), but the ADSP firmware **never routes that energy to the battery**. PD negotiation never completes (stuck at 5V instead of going to 9V).

## What I've already tested (all ruled out)

- ✅ Kernel config compared with ROCKNIX (nearly identical)
- ✅ Kernel 7.2.0 and 7.2.4 (latest) — both no charge
- ✅ Kernel built WITHOUT our patches (identical to ROCKNIX) — no charge
- ✅ ROCKNIX's ADSP firmware (adsp.mbn) tested on Pocknix — no fix
- ✅ battmgr.jsn byte-identical
- ✅ GCC 15.2 compiler (ROCKNIX's exact toolchain) — no charge
- ✅ Stock and patched battmgr module — no charge
- ✅ ABL/bootloader (same across all distros)
- ✅ No userspace charging scripts in ROCKNIX (all kernel/firmware)

## My remaining hypothesis

The difference is in **how the boot environment initializes `pmic-glink`** (the communication channel between the kernel and the ADSP firmware that manages charging). ROCKNIX and Pocknix boot the same kernel differently (initramfs / module load order), which might cause the firmware to never receive/respond to the right message.

## Can anyone help?

If anyone has experience with:
1. **UCSI never completing PD negotiation** (`ucsi voltage_max=0`) on Qualcomm devices
2. **qcom_battmgr** not receiving `charging_source=USB` from the firmware
3. **Module load order** of pmic-glink vs ucsi at boot
4. Or simply has an **Odin 3 with Linux** and the same issue (or not)

...I'd really appreciate any insight. 🙏

📄 **Full investigation details**: https://github.com/arcadematicas/pocknix-odin3-support/blob/master/BATTERY-ISSUE.md