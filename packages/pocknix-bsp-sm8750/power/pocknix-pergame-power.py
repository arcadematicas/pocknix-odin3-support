#!/usr/bin/env python3
"""pocknix-pergame-power — aplica el cpu-governor y el power-profile del juego en curso.

El pocknix-proton-wrapper escribe /run/pocknix/game-mode como:
    <pid> <fan> <lavd> <governor> <power-profile>
al lanzar un juego. Este daemon, cada ~3s:
  - si el pid vive y governor/profile no son "-", aplica ese governor/profile;
  - cuando el pid muere (o no hay override), restaura el governor/profile GLOBAL.

Los helpers (/usr/local/bin/pocknix-{cpu-governor,power-profile}) persisten el modo que
aplican en /var/lib/pocknix, asi que guardamos el global ANTES de aplicar un override
para poder restaurarlo exactamente cuando el juego termina.
"""
import os
import time
import pathlib
import syslog

GAME_MODE_FILE = pathlib.Path("/run/pocknix/game-mode")
GOV_FILE = pathlib.Path("/var/lib/pocknix/cpu-governor")
PROF_FILE = pathlib.Path("/var/lib/pocknix/power-profile")
GOV_HELPER = "/usr/local/bin/pocknix-cpu-governor"
PROF_HELPER = "/usr/local/bin/pocknix-power-profile"
CPU_GOVERNORS = ("powersave", "schedutil", "performance", "ondemand")
POWER_PROFILES = ("bajo", "medio", "alto")

GOV_DEFAULT = "schedutil"
PROF_DEFAULT = "alto"


def log(msg):
    syslog.syslog(syslog.LOG_INFO, f"pergame-power: {msg}")
    print(msg, flush=True)


def read_mode(path, allowed, default):
    try:
        v = path.read_text().strip()
    except OSError:
        return default
    return v if v in allowed else default


def apply_gov(gov):
    os.system(f"{GOV_HELPER} {gov} >/dev/null 2>&1")


def apply_prof(prof):
    os.system(f"{PROF_HELPER} {prof} >/dev/null 2>&1")


def current_override():
    """Devuelve (gov, prof) del override del juego activo, o (None, None)."""
    try:
        parts = GAME_MODE_FILE.read_text().split()
    except OSError:
        return None, None
    if len(parts) < 5 or not parts[0].isdigit():
        return None, None
    pid = parts[0]
    if not os.path.isdir(f"/proc/{pid}"):
        return None, None
    gov = parts[3] if parts[3] in CPU_GOVERNORS else None
    prof = parts[4] if parts[4] in POWER_PROFILES else None
    return gov, prof


def main():
    log("daemon iniciado")
    # Estado: guardamos el global antes de aplicar un override para restaurarlo al salir.
    had_override = False
    saved_gov = None
    saved_prof = None

    while True:
        try:
            gov, prof = current_override()
            if gov or prof:
                if not had_override:
                    # Guardar el global actual (aun no sobrescrito por el helper) y aplicar override.
                    saved_gov = read_mode(GOV_FILE, CPU_GOVERNORS, GOV_DEFAULT)
                    saved_prof = read_mode(PROF_FILE, POWER_PROFILES, PROF_DEFAULT)
                    had_override = True
                    log(f"override activo (global guardado: gov={saved_gov}, prof={saved_prof})")
                if gov:
                    log(f"aplicando governor del juego: {gov}")
                    apply_gov(gov)
                if prof:
                    log(f"aplicando power-profile del juego: {prof}")
                    apply_prof(prof)
            else:
                if had_override:
                    # El juego termino: restaurar el global guardado.
                    if saved_gov:
                        log(f"restaurando governor global: {saved_gov}")
                        apply_gov(saved_gov)
                    if saved_prof:
                        log(f"restaurando power-profile global: {saved_prof}")
                        apply_prof(saved_prof)
                    had_override = False
                    saved_gov = None
                    saved_prof = None
                    log("override liberado")
        except Exception as e:
            log(f"error: {e}")
        time.sleep(3)


if __name__ == "__main__":
    main()
