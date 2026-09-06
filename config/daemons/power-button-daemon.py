#!/usr/bin/env python3
"""Power button daemon for AYN Odin 3 (Pocknix).

Short press of the power button toggles the display backlight (screen
off/on, like Android). Long press is handled by the PMIC hardware
(forced poweroff after ~10s).

Reads /dev/input/event0 (pmic_pwrkey) and flips bl_power on the OLED
backlight. Runs as root via systemd.
"""

import os
import struct
from pathlib import Path

EVENT_DEV = Path("/dev/input/event0")
BACKLIGHT = Path("/sys/class/backlight/ae94000.dsi.0")
BL_POWER = BACKLIGHT / "bl_power"
BRIGHTNESS = BACKLIGHT / "brightness"

EV_KEY = 0x01
KEY_POWER = 116  # KEY_POWER
EVENT_SIZE = struct.calcsize("=QQHHi")  # 24 bytes

_saved_brightness: int | None = None


def screen_is_off() -> bool:
    try:
        return int(BL_POWER.read_text().strip()) != 0
    except OSError:
        return False


def screen_off() -> None:
    global _saved_brightness
    try:
        _saved_brightness = int(BRIGHTNESS.read_text().strip())
        BL_POWER.write_text("4")
    except OSError:
        pass


def screen_on() -> None:
    global _saved_brightness
    try:
        BL_POWER.write_text("0")
        if _saved_brightness is not None:
            BRIGHTNESS.write_text(str(_saved_brightness))
            _saved_brightness = None
    except OSError:
        pass


def toggle() -> None:
    if screen_is_off():
        screen_on()
    else:
        screen_off()


def main() -> None:
    fd = os.open(EVENT_DEV, os.O_RDONLY)
    try:
        while True:
            data = os.read(fd, EVENT_SIZE)
            if len(data) != EVENT_SIZE:
                continue
            _, _, ev_type, code, value = struct.unpack("=QQHHi", data)
            if ev_type == EV_KEY and code == KEY_POWER and value == 1:
                toggle()
    finally:
        os.close(fd)


if __name__ == "__main__":
    main()