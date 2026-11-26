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
# En aarch64 el Renderer lo instala y gestiona el Panel de Control (Hooandee) en su prefijo,
# con la build aarch64; ahi el wrapper por juego es su `bin/mako-launch`, no `~/.local/bin/mako-run`.
PANEL_MAKO_LAUNCH = DECK_HOME / ".local" / "share" / "panel-de-control" / "mako" / "5" / "bin" / "mako-launch"


def mako_status():
    """Report whether MAKO's per-game wrapper is available on this device."""
    panel = PANEL_MAKO_LAUNCH.is_file()
    return {
        "installed": MAKO_WRAPPER.is_file() or panel,
        "wrapper": str(PANEL_MAKO_LAUNCH if panel else MAKO_WRAPPER),
        "renderer": MAKO_RENDERER_STATE.is_file() or panel,
        "panel": panel,
    }
