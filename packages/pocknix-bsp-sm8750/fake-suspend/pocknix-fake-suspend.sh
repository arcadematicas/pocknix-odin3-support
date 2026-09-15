#!/bin/bash
# /usr/local/bin/pocknix-fake-suspend
# Fake suspend for AYN Odin 3 (SM8750) to avoid hardware hang.

case "$1" in
  suspend)
    # 1. Screen off
    echo 4 > /sys/class/backlight/ae94000.dsi.0/bl_power
    # 2. CPU to powersave
    echo powersave | tee /sys/devices/system/cpu/cpu*/cpufreq/scaling_governor > /dev/null
    # 3. Sync disks
    sync
    ;;
  resume)
    # 1. CPU to schedutil
    echo schedutil | tee /sys/devices/system/cpu/cpu*/cpufreq/scaling_governor > /dev/null
    # 2. Screen on
    echo 0 > /sys/class/backlight/ae94000.dsi.0/bl_power
    ;;
esac
