import threading
from pathlib import Path

from .system import run_cmd

# one implementation for both UIs (pocknix-tools owns it)
SHARE = "/usr/bin/pocknix-share"

# Polled every few seconds, so status reads the filesystem instead of spawning a transient
# unit per poll. The enable symlink and smb.service's PIDFile= are the contract.
SMBD = Path("/usr/bin/smbd")
ENABLED_LINK = Path("/etc/systemd/system/multi-user.target.wants/smb.service")
SMBD_PID = Path("/run/smbd.pid")

# Installing samba is a network operation behind a user tap; one at a time.
_install_lock = threading.Lock()


def _host(args, timeout):
    # This python is an x86_64 FEX guest whose rootfs shadows bash and systemctl; a direct call
    # would run the aarch64 script under an x86 bash. systemd-run hands it to PID 1 (updates.py).
    return run_cmd(
        ["systemd-run", "--quiet", "--collect", "--wait", "--pipe", *args],
        timeout=timeout,
    )


def share_status():
    return {
        "installed": SMBD.exists(),
        "on": ENABLED_LINK.exists(),
        "active": SMBD_PID.exists(),
    }


def set_share(on):
    # plugin runs as root: no pkexec
    proc = _host([SHARE, "on" if on else "off"], timeout=90)
    if proc is None or proc.returncode != 0:
        detail = ((proc.stderr if proc else "") or "").strip()[-200:]
        raise RuntimeError(f"Could not turn file sharing {'on' if on else 'off'}: {detail or 'no detail'}")
    return share_status()


def install_samba():
    if not _install_lock.acquire(blocking=False):
        raise RuntimeError("An install is already running")
    try:
        proc = _host([SHARE, "install"], timeout=600)
        if proc is None or proc.returncode != 0:
            detail = ((proc.stderr if proc else "") or "").strip()[-200:]
            raise RuntimeError(f"Could not install Samba: {detail or 'timed out (slow mirror or no network?)'}")
        return share_status()
    finally:
        _install_lock.release()
