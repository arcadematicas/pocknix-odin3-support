import re
import shlex
import threading
from pathlib import Path

from .system import run_cmd

# The upgrade runs as a detached transient unit under PID 1 so the loader or Steam dying
# mid-update cannot kill the pacman transaction; the QAM re-attaches to the log on reopen.
UNIT = "pocknix-qam-update"
# Lives in /run so a reboot clears the finished/failed state together with the log.
LOG = Path("/run/pocknix-update.log")
EXIT_MARK = "POCKNIX_UPDATE_EXIT:"

# ONE updater, one policy: pocknix-base owns the update engine and the --overwrite rules, so
# this module only CALLS it. It used to build its own `pacman -Syu` here, which is why the
# "Pocknix Updater" entry and the QAM button could disagree about the same problem.
# Absolute paths: this python is an x86_64 FEX guest, so a bare "pocknix-update"/"pacman"
# resolves into the FEX rootfs overlay (a foreign pacman on a stock pacman.conf whose
# download sandbox also dies under emulation) instead of the host's.
UPDATER = "/usr/bin/pocknix-update"
PACMAN = "/usr/bin/pacman"

# Degraded fallback ONLY, for a system where pocknix-base is somehow absent: run pacman
# directly instead of refusing to update at all. Same bounded list of OUR paths as the
# engine's, kept as GLOBS because there is no self-heal here to narrow them from pacman's
# output. It can never authorise taking a file away from another installed package, and it
# covers the leftovers pocknix itself created (plutovg/plutosvg/libFLAC.so.8/
# libpcap.so.0.8 headers+sonames, and the Valve Turnip payload under /usr/share/pocknix/vk-arm).
# ⚠ Keep in step with OVERWRITE_BASE in pocknix-base's pocknix-update; that script is the
# source of truth. One line per path GROUP; the exact file list is `bsdtar -tf` of the four
# packages (plutovg, plutosvg, pocknix-soname-compat, pocknix-vk-valve).
OVERWRITE_BASE = (
    "/usr/include/plutovg/*",
    "/usr/include/plutosvg/*",
    "/usr/lib/cmake/plutovg/*",
    "/usr/lib/cmake/plutosvg/*",
    "/usr/lib/pkgconfig/plutovg.pc",
    "/usr/lib/pkgconfig/plutosvg.pc",
    "/usr/lib/libplutovg.so*",
    "/usr/lib/libplutosvg.so*",
    "/usr/lib/libFLAC.so.8*",
    "/usr/lib/libpcap.so.0.8*",
    "/usr/lib/libdisplay-info.so.1*",
    "/usr/share/pocknix/vk-arm/*",
)

# checkupdates(8) trick without pacman-contrib: refresh a THROWAWAY sync db copy and query
# against it, so the real db is never -Sy'd without -u (partial-upgrade setup).
CHECK_DB = Path("/run/pocknix-check-db")

VER_RE = re.compile(r"^(\S+)\s+(\S+)$")

# Serialization must live here, not in the frontend: its 'checking' state dies with the QAM
# panel, so close-mid-check then retap raced pacman on the throwaway db ("unable to lock database").
_check_lock = threading.Lock()


def _pacman(args, timeout):
    # Never call pacman in-process: this python is an x86_64 FEX guest, so a bare "pacman"
    # resolves into the FEX rootfs overlay - a foreign pacman on a stock pacman.conf (no
    # [pocknix] repo, so pins vanish) whose download sandbox also dies under emulation.
    return run_cmd(
        ["systemd-run", "--quiet", "--collect", "--wait", "--pipe", PACMAN, *args],
        timeout=timeout,
    )


def _unit_running():
    proc = run_cmd(["systemctl", "is-active", f"{UNIT}.service"], timeout=5)
    if proc is None:
        return False
    return (proc.stdout or "").strip() in ("active", "activating", "deactivating")


def check_updates():
    if _unit_running():
        raise RuntimeError("An update is already running")
    if not _check_lock.acquire(blocking=False):
        raise RuntimeError("Already checking for updates — give it a moment and try again")
    try:
        return _check_updates_locked()
    finally:
        _check_lock.release()


def _check_updates_locked():
    (CHECK_DB / "sync").mkdir(parents=True, exist_ok=True)
    local = CHECK_DB / "local"
    if not local.exists():
        local.symlink_to("/var/lib/pacman/local")
    # _check_lock serializes every real user of this throwaway db, so a db.lck here
    # is a leftover from a killed check — without this, checking stays broken until reboot
    (CHECK_DB / "db.lck").unlink(missing_ok=True)
    proc = _pacman(["-Sy", "--dbpath", str(CHECK_DB), "--logfile", "/dev/null"], timeout=180)
    if proc is None or proc.returncode != 0:
        detail = ((proc.stderr if proc else "") or "").strip()[-200:]
        raise RuntimeError(f"Could not refresh package databases: {detail or 'timed out (slow mirror or no network?)'}")
    # -Sup resolves like the real -Syu (repo order, IgnorePkg, replaces); -Qu would report any
    # repo's newer version and so falsely list packages held back by [pocknix] priority.
    proc = _pacman(["-Sup", "--dbpath", str(CHECK_DB), "--print-format", "%n %v"], timeout=60)
    if proc is None or proc.returncode != 0:
        detail = ((proc.stderr if proc else "") or "").strip()[-200:]
        raise RuntimeError(f"Could not resolve upgrades: {detail}")
    targets = {}
    for line in (proc.stdout or "").splitlines():
        line = line.strip()
        if not line or line.startswith("::"):
            continue
        match = VER_RE.match(line)
        if match:
            targets[match.group(1)] = match.group(2)
    if not targets:
        return []
    current = {}
    proc = _pacman(["-Q"], timeout=30)
    if proc and proc.returncode == 0:
        for line in (proc.stdout or "").splitlines():
            match = VER_RE.match(line.strip())
            if match:
                current[match.group(1)] = match.group(2)
    return [
        {"name": name, "current": current.get(name, "new"), "latest": latest}
        for name, latest in sorted(targets.items())
    ]


def _update_script():
    # sh -c runs on the HOST (systemd-run's binary), so the -x test and the --overwrite globs
    # below are evaluated by the host's /bin/sh and the host's pacman, not by FEX.
    ow = " ".join(f"--overwrite {shlex.quote(p)}" for p in OVERWRITE_BASE)
    return "\n".join([
        f"if [ -x {shlex.quote(UPDATER)} ]; then",
        f"  {shlex.quote(UPDATER)} --noninteractive",
        "else",
        f"  printf '%s\\n' {shlex.quote('pocknix-update is missing (pocknix-base not installed?); running pacman directly with the leftover-file policy.')}",
        f"  {shlex.quote(PACMAN)} -Syu --noconfirm --noprogressbar {ow}",
        "fi",
        f'echo "{EXIT_MARK}$?"',
    ])


def start_update():
    if _unit_running():
        raise RuntimeError("An update is already running")
    LOG.unlink(missing_ok=True)
    # The exit marker is how status() learns the result after --collect has reaped the unit,
    # and it must be the LAST thing written, so stderr goes to the same log (appending, not
    # inheriting the unit's own stderr): otherwise the conflict/error lines race ahead of the
    # marker and the user sees a log that ends on an error even after a successful retry.
    proc = run_cmd(
        ["systemd-run", "--quiet", "--collect", "--unit", UNIT,
         "--property", f"StandardOutput=append:{LOG}",
         "--property", f"StandardError=append:{LOG}",
         "/bin/sh", "-c", _update_script()],
        timeout=15,
    )
    if proc is None or proc.returncode != 0:
        detail = ((proc.stderr if proc else "") or "").strip()[-200:]
        raise RuntimeError(f"Could not start the update: {detail}")
    return update_status()


def update_status():
    try:
        lines = [line for line in LOG.read_text(encoding="utf-8", errors="replace").splitlines() if line.strip()]
    except OSError:
        lines = []
    exit_code = None
    if lines and lines[-1].startswith(EXIT_MARK):
        try:
            exit_code = int(lines[-1][len(EXIT_MARK):])
        except ValueError:
            exit_code = -1
        lines = lines[:-1]
    return {
        "running": _unit_running(),
        "log": "\n".join(lines[-6:]),
        "exitCode": exit_code,
    }