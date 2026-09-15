from pathlib import Path

from .system import run_cmd
from .modes import _read_mode

# CPU governor + power-profile (pseudo-TDP: limita frecuencias CPU/GPU) del Odin 3.
# Los helpers CLI (/usr/local/bin/pocknix-*) aplican en caliente y persisten en
# /var/lib/pocknix; el servicio oneshot los re-aplica en cada arranque.
CPU_GOVERNOR_FILE = Path("/var/lib/pocknix/cpu-governor")
POWER_PROFILE_FILE = Path("/var/lib/pocknix/power-profile")

CPU_GOVERNORS = ("powersave", "schedutil", "performance", "ondemand")
CPU_GOVERNOR_DEFAULT = "schedutil"
POWER_PROFILES = ("bajo", "medio", "alto")
POWER_PROFILE_DEFAULT = "alto"


def cpu_governor():
    return _read_mode(CPU_GOVERNOR_FILE, CPU_GOVERNORS, CPU_GOVERNOR_DEFAULT)


def power_profile():
    return _read_mode(POWER_PROFILE_FILE, POWER_PROFILES, POWER_PROFILE_DEFAULT)


def set_cpu_governor(gov):
    if gov not in CPU_GOVERNORS:
        raise ValueError(f"unknown cpu governor: {gov!r}")
    # El helper aplica el governor a todas las CPUs en caliente y persiste el modo.
    proc = run_cmd(["/usr/local/bin/pocknix-cpu-governor", gov], timeout=30)
    if proc is None:
        raise RuntimeError("pocknix-cpu-governor failed to spawn")
    if proc.returncode != 0:
        raise RuntimeError(f"pocknix-cpu-governor failed (rc={proc.returncode}): {(proc.stderr or '').strip()[:300]}")


def set_power_profile(profile):
    if profile not in POWER_PROFILES:
        raise ValueError(f"unknown power profile: {profile!r}")
    # El helper limita/restaura las frecuencias maximas de CPU y GPU en caliente.
    proc = run_cmd(["/usr/local/bin/pocknix-power-profile", profile], timeout=30)
    if proc is None:
        raise RuntimeError("pocknix-power-profile failed to spawn")
    if proc.returncode != 0:
        raise RuntimeError(f"pocknix-power-profile failed (rc={proc.returncode}): {(proc.stderr or '').strip()[:300]}")
