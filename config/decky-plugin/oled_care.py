"""OLED Care — pixel refresher for the AYN Odin 3 OLED panel.

Runs /usr/local/bin/oled-refresher (a small SDL2 binary that paints
fullscreen 3x3px random-noise cells for a few seconds) to prevent
OLED image retention / burn-in, mirroring AYN OdinSettings' "Pixel
refresher".
"""

from __future__ import annotations

import os
import shutil
import subprocess
from pathlib import Path

REFRESHER_BIN = Path("/usr/local/bin/oled-refresher")
DEFAULT_DURATION = 3  # seconds per pass
DEFAULT_PASSES = 3
CELL_PX = 3

# The Decky PluginLoader runs as root without a graphical session env, so the
# SDL2 refresher would not know which display to open. Pull the session env
# from a running graphical-session process (best effort). kwin_wayland itself
# is the compositor and does not export WAYLAND_DISPLAY, so look at clients.
# In game mode the visible compositor is gamescope (Steam carries its env);
# on the desktop it is kwin (plasma-keyboard/plasmashell carry the env).
_SESSION_KEYS = (
    "WAYLAND_DISPLAY",
    "DISPLAY",
    "XDG_RUNTIME_DIR",
    "DBUS_SESSION_BUS_ADDRESS",
    "XDG_SESSION_TYPE",
    "XAUTHORITY",
)
_SESSION_PATTERNS = ("steam", "plasma-keyboard", "plasmashell")


def _session_env() -> dict:
    env: dict = {}
    try:
        for name in _SESSION_PATTERNS:
            out = subprocess.run(
                ["pgrep", "-x", name],
                capture_output=True, text=True, timeout=5,
            )
            pid = out.stdout.strip().splitlines()[0] if out.stdout.strip() else None
            if not pid:
                continue
            data = Path(f"/proc/{pid}/environ").read_bytes()
            for entry in data.split(b"\0"):
                if b"=" not in entry:
                    continue
                key, _, value = entry.partition(b"=")
                if key.decode() in _SESSION_KEYS:
                    env[key.decode()] = value.decode()
            if env.get("WAYLAND_DISPLAY") or env.get("DISPLAY"):
                break
    except (OSError, subprocess.SubprocessError, IndexError):
        pass
    return env


def refresher_available() -> bool:
    return REFRESHER_BIN.is_file() and os.access(REFRESHER_BIN, os.X_OK)


def refresher_running() -> bool:
    try:
        out = subprocess.run(
            ["pgrep", "-x", "oled-refresher"],
            capture_output=True, text=True, timeout=5,
        )
        return bool(out.stdout.strip())
    except (OSError, subprocess.SubprocessError):
        return False


def _game_mode_active() -> bool:
    try:
        out = subprocess.run(
            ["pgrep", "-x", "steam"],
            capture_output=True, text=True, timeout=5,
        )
        return bool(out.stdout.strip())
    except (OSError, subprocess.SubprocessError):
        return False


def run_refresher(duration: int | None = None, passes: int | None = None) -> dict:
    """Launch the OLED pixel refresher (non-blocking)."""
    if not refresher_available():
        raise RuntimeError("oled-refresher is not installed on this image")
    if refresher_running():
        raise RuntimeError("An OLED refresh is already in progress")
    dur = max(1, int(duration or DEFAULT_DURATION))
    pas = max(1, int(passes or DEFAULT_PASSES))
    total = dur * pas
    if _game_mode_active():
        # Game mode: the visible compositor is gamescope and Steam runs on its
        # Xwayland (:0). Root has no X authorization, so run as the deck user
        # against the X11 display (verified working).
        env = _session_env()
        cmd = [
            "sudo", "-u", "deck",
            "env",
        ]
        if "XAUTHORITY" in env:
            cmd.append(f"XAUTHORITY={env['XAUTHORITY']}")
        cmd.extend(["DISPLAY=:0", "SDL_VIDEODRIVER=x11", str(REFRESHER_BIN), str(total), str(CELL_PX)])
        
        subprocess.Popen(
            cmd,
            stdout=subprocess.DEVNULL,
            stderr=subprocess.DEVNULL,
            start_new_session=True,
        )
    else:
        # Desktop (Plasma): run as root against the Wayland session env pulled
        # from the running graphical-session client.
        full_env = os.environ.copy()
        full_env.update(_session_env())
        subprocess.Popen(
            [str(REFRESHER_BIN), str(total), str(CELL_PX)],
            stdout=subprocess.DEVNULL,
            stderr=subprocess.DEVNULL,
            start_new_session=True,
            env=full_env,
        )
    return oled_care_status()


def oled_care_status() -> dict:
    return {
        "available": refresher_available(),
        "running": refresher_running(),
        "defaultDuration": DEFAULT_DURATION,
        "defaultPasses": DEFAULT_PASSES,
    }