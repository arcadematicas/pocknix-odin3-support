from pathlib import Path

from .system import atomically_write, run_cmd

# Both mode files live in /var/lib/pocknix and hold one bare word; both daemons treat an
# unknown/absent value as the default, so a bad write degrades gracefully.
FAN_MODE_FILE = Path("/var/lib/pocknix/fan-mode")
LAVD_MODE_FILE = Path("/var/lib/pocknix/lavd-mode")

FAN_MODES = ("quiet", "moderate", "performance")
FAN_DEFAULT = "quiet"
LAVD_MODES = ("autopilot", "performance")
LAVD_DEFAULT = "autopilot"


def _read_mode(path, allowed, default):
    try:
        mode = path.read_text(encoding="utf-8").strip()
    except OSError:
        return default
    return mode if mode in allowed else default


def fan_mode():
    return _read_mode(FAN_MODE_FILE, FAN_MODES, FAN_DEFAULT)


def lavd_mode():
    # pocknix-lavd-mode also accepts balanced/powersave for experiments; the UI only
    # offers autopilot/performance, so map anything else back to the default.
    return _read_mode(LAVD_MODE_FILE, LAVD_MODES, LAVD_DEFAULT)


def set_fan_mode(mode):
    if mode not in FAN_MODES:
        raise ValueError(f"unknown fan mode: {mode!r}")
    # pocknix-fancontrol re-reads this file every curve tick (~3s); no restart needed.
    atomically_write(FAN_MODE_FILE, mode + "\n", 0o644)


def set_lavd_mode(mode):
    if mode not in LAVD_MODES:
        raise ValueError(f"unknown lavd mode: {mode!r}")
    # The helper persists the mode and restarts pocknix-lavd.service (live scheduler swap).
    proc = run_cmd(["/usr/bin/pocknix-lavd-mode", mode], timeout=30)
    if proc is None:
        raise RuntimeError("pocknix-lavd-mode failed to spawn")
    if proc.returncode != 0:
        raise RuntimeError(f"pocknix-lavd-mode failed (rc={proc.returncode}): {(proc.stderr or '').strip()[:300]}")


# sched_ext scheduler selection (pocknix-scx-mode): scheduler + mode, persisted in
# /var/lib/pocknix/scx-mode as "<scheduler> <mode>".
# "auto" = the Steam QAM power profile drives the scheduler (mapping lives in
# /usr/local/bin/pocknix-power-profile). A manual pick creates /var/lib/pocknix/scx-manual,
# which makes the profile leave the scheduler alone until the user goes back to "auto".
# NOTE: scx_rusty 1.1.2 fails to load on this kernel ("kptr already had cpumask",
# main.bpf.c:119) so it is NOT offered. Re-add when upstream fixes it.
SCX_STATE_FILE = Path("/var/lib/pocknix/scx-mode")
SCX_MANUAL_FILE = Path("/var/lib/pocknix/scx-manual")
SCX_SCHEDULERS = ("lavd", "bpfland")
SCX_DEFAULT_SCHED = "lavd"
SCX_MODES = {
    "lavd": ("autopilot", "performance", "balanced", "powersave"),
    "bpfland": ("default", "performance", "powersave"),
}
SCX_DEFAULT_MODE = "autopilot"
POWER_PROFILE_FILE = Path("/var/lib/pocknix/power-profile")
POWER_PROFILE_HELPER = "/usr/local/bin/pocknix-power-profile"
POWER_PROFILES = ("bajo", "medio", "alto")
POWER_DEFAULT = "alto"


def _read_state():
    """(scheduler, mode) persisted in /var/lib/pocknix/scx-mode; sanitized."""
    try:
        sched, _, mode = SCX_STATE_FILE.read_text(encoding="utf-8").strip().partition(" ")
    except OSError:
        return SCX_DEFAULT_SCHED, SCX_DEFAULT_MODE
    if sched not in SCX_SCHEDULERS:
        return SCX_DEFAULT_SCHED, SCX_DEFAULT_MODE
    allowed = SCX_MODES[sched]
    if mode not in allowed:
        mode = allowed[0]
    return sched, mode


def scx_state():
    """(scheduler, mode) for the UI: ("auto", "") when the QAM profile drives it."""
    if SCX_MANUAL_FILE.exists():
        return _read_state()
    return "auto", ""


def scx_scheduler():
    return scx_state()[0]


def scx_mode():
    return scx_state()[1]


def scx_effective():
    """(scheduler, mode) actually running, regardless of auto/manual — lets the UI show
    what the QAM profile picked while the selector sits on "auto"."""
    return _read_state()


def _run_scx(args):
    proc = run_cmd(["/usr/bin/pocknix-scx-mode", *args], timeout=30)
    if proc is None:
        raise RuntimeError("pocknix-scx-mode failed to spawn")
    if proc.returncode != 0:
        raise RuntimeError(f"pocknix-scx-mode failed (rc={proc.returncode}): {(proc.stderr or '').strip()[:300]}")


def _current_power_profile():
    try:
        profile = POWER_PROFILE_FILE.read_text(encoding="utf-8").strip()
    except OSError:
        return POWER_DEFAULT
    return profile if profile in POWER_PROFILES else POWER_DEFAULT


def _run_power_profile(profile):
    proc = run_cmd([POWER_PROFILE_HELPER, profile], timeout=30)
    if proc is None:
        raise RuntimeError("pocknix-power-profile failed to spawn")
    if proc.returncode != 0:
        raise RuntimeError(f"pocknix-power-profile failed (rc={proc.returncode}): {(proc.stderr or '').strip()[:300]}")


def set_scx_scheduler(scheduler):
    if scheduler == "auto":
        # Back to profile-driven: drop the manual flag and re-apply the current profile,
        # which re-selects the recommended scheduler (mapping lives in power-profile only).
        try:
            SCX_MANUAL_FILE.unlink()
        except OSError:
            pass
        _run_power_profile(_current_power_profile())
        return
    if scheduler not in SCX_SCHEDULERS:
        raise ValueError(f"unknown scx scheduler: {scheduler!r}")
    SCX_MANUAL_FILE.write_text("manual\n")
    _run_scx([scheduler])


def set_scx_mode(mode):
    sched = scx_scheduler()
    if sched == "auto":
        # Picking a mode implies pinning the scheduler manually (default to lavd).
        sched = SCX_DEFAULT_SCHED
        SCX_MANUAL_FILE.write_text("manual\n")
    allowed = SCX_MODES[sched]
    if mode not in allowed:
        raise ValueError(f"unknown mode {mode!r} for scheduler {sched!r} (allowed: {allowed})")
    _run_scx([sched, mode])
