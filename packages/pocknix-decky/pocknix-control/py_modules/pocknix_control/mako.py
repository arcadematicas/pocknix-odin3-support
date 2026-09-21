"""MAKO Decky (Lossless Scaling frame generation) integration.

MAKO activates per game through a wrapper (``~/.local/bin/mako-run``) that its
Decky plugin generates once the Renderer is installed; the wrapper exports the
Vulkan-layer environment for that game only. Turning it on is therefore a
launch-option edit, which the frontend performs through Steam's own
``SetAppLaunchOptions`` (the same channel as the FEX profile token).

This module only reports whether the wrapper is available, so the UI never
offers to enable MAKO on a device where the Renderer was never installed.
"""
from pathlib import Path

# The Pocknix deck user is fixed, and the backend runs as root, so it cannot use ~.
DECK_HOME = Path("/home/deck")
MAKO_WRAPPER = DECK_HOME / ".local" / "bin" / "mako-run"
MAKO_RENDERER_STATE = DECK_HOME / ".local" / "share" / "mako-render" / "active-renderer.json"


def mako_status():
    """Report whether MAKO's per-game wrapper is available on this device."""
    return {
        "installed": MAKO_WRAPPER.is_file(),
        "wrapper": str(MAKO_WRAPPER),
        "renderer": MAKO_RENDERER_STATE.is_file(),
    }
