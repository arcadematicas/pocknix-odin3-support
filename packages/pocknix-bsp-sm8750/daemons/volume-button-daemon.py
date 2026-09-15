#!/usr/bin/env python3
"""Volume button daemon for AYN Odin 3 (Pocknix).

In game mode (Steam/gamescope) the hardware volume buttons are not
handled by the desktop, so this daemon captures KEY_VOLUMEUP/DOWN and
adjusts the PipeWire volume. On the Plasma desktop it stays quiet
(KDE already handles the buttons).

Reads /dev/input/event1 (pmic_resin, VOLUMEDOWN) and event3
(gpio-keys, VOLUMEUP). Runs as root via systemd.
"""

import os
import select
import struct
import subprocess
import time
from pathlib import Path

EVENT_DEVICES = (Path("/dev/input/event1"), Path("/dev/input/event3"))
EV_KEY = 0x01
KEY_VOLUMEDOWN = 114
KEY_VOLUMEUP = 115
EVENT_SIZE = struct.calcsize("=QQHHi")  # 24 bytes
STEP = 0.05
LOG = Path("/tmp/volume-daemon.log")


def log(msg: str) -> None:
    try:
        with LOG.open("a") as f:
            f.write(f"{time.strftime('%H:%M:%S')} {msg}\n")
    except OSError:
        pass


def game_mode_active() -> bool:
    try:
        out = subprocess.run(
            ["pgrep", "-x", "steam"],
            capture_output=True, text=True, timeout=5,
        )
        return bool(out.stdout.strip())
    except (OSError, subprocess.SubprocessError):
        return False


def adjust(delta: float) -> None:
    try:
        out = subprocess.run(
            ["wpctl", "get-volume", "@DEFAULT_AUDIO_SINK@"],
            capture_output=True, text=True, timeout=5,
        )
        # Output like "Volume: 0.40" or "Volume: 0.40 [MUTED]"
        vol = float(out.stdout.split()[1])
        new_vol = max(0.0, min(1.0, vol + delta))
        subprocess.run(
            ["wpctl", "set-volume", "@DEFAULT_AUDIO_SINK@", f"{new_vol:.2f}"],
            capture_output=True, timeout=5,
        )
    except (OSError, subprocess.SubprocessError, ValueError, IndexError):
        pass


def main() -> None:
    log("daemon started")
    fds = [os.open(dev, os.O_RDONLY) for dev in EVENT_DEVICES]
    try:
        poll = select.poll()
        for fd in fds:
            poll.register(fd, select.POLLIN)
        while True:
            for fd, _ in poll.poll():
                data = os.read(fd, EVENT_SIZE)
                if len(data) != EVENT_SIZE:
                    continue
                _, _, ev_type, code, value = struct.unpack("=QQHHi", data)
                if ev_type != EV_KEY or value != 1:
                    continue
                game = game_mode_active()
                log(f"event code={code} value={value} game_mode={game}")
                if not game:
                    continue
                if code == KEY_VOLUMEUP:
                    adjust(STEP)
                elif code == KEY_VOLUMEDOWN:
                    adjust(-STEP)
    finally:
        for fd in fds:
            os.close(fd)


if __name__ == "__main__":
    main()