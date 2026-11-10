"""Escritorio del Odin 3 — que sabor de Plasma se abre al salir del modo juego.

El escritorio no lo arranca Steam: `steamos-session-select plasma` solo escribe el
estado de la sesion y mata gamescope; el supervisor `pocknix-session` lee despues
`~/.config/pocknix/desktop-session` (via `pocknix-desktop-select current`) y lanza
ese escritorio. O sea que para "cambiar a escritorio" hay que hacer las dos cosas:

    1. fijar el sabor      -> /usr/bin/pocknix-desktop-select <plasma|plasma-mobile>
    2. pedir el cambio     -> /usr/bin/steamos-session-select plasma

⚠️ El PluginLoader de Decky corre como ROOT. Todo lo que toca el home de `deck`
(config, runtime de la sesion) se lanza como `deck` con `runuser` + HOME y
XDG_RUNTIME_DIR explicitos (mismo patron que hdr.py).

⚠️ `steamos-session-select` TERMINA gamescope, y con el muere este plugin: el
comando se lanza desacoplado con systemd-run y NO se espera su salida.
"""

from __future__ import annotations

import subprocess
import time
from pathlib import Path

DECK_HOME = Path("/home/deck")
PICK = DECK_HOME / ".config/pocknix/desktop-session"
SELECT = "/usr/bin/pocknix-desktop-select"
SWITCH = "/usr/bin/steamos-session-select"

# Solo estos dos existen en la consola; el resto de sesiones wayland no nos vale.
FLAVOURS = ("plasma", "plasma-mobile")
DEFAULT = "plasma-mobile"

# uid de `deck` (fransis=1000, deck=1001) -> runtime de PipeWire/wayland/D-Bus.
DECK_RUNTIME = "/run/user/1001"

_TIMEOUT = 20


def _as_deck(cmd: list[str]) -> list[str]:
    """Comando con el entorno minimo de `deck` (el plugin corre como root)."""
    return ["runuser", "-u", "deck", "--", "env",
            "HOME=/home/deck", f"XDG_RUNTIME_DIR={DECK_RUNTIME}"] + cmd


def desktop_flavour() -> str:
    """Sabor elegido, tal como lo vera el supervisor al arrancar el escritorio."""
    try:
        name = PICK.read_text(encoding="utf-8").strip()
    except OSError:
        name = ""
    if name in FLAVOURS:
        return name
    # Sin fichero (o con basura) manda el propio selector: `current` resuelve el
    # default y descarta sabores que ya no esten instalados. Best-effort.
    try:
        proc = subprocess.run(_as_deck([SELECT, "current"]),
                              capture_output=True, text=True, timeout=10)
        if proc.returncode == 0:
            name = (proc.stdout or "").strip()
            if name in FLAVOURS:
                return name
    except (OSError, subprocess.SubprocessError):
        pass
    return DEFAULT


def set_desktop_flavour(name: str) -> str:
    """Fija el sabor en la preferencia (sin tocar la sesion en curso)."""
    if name not in FLAVOURS:
        raise ValueError(f"unknown desktop flavour: {name!r}")
    proc = subprocess.run(_as_deck([SELECT, name]),
                          capture_output=True, text=True, timeout=_TIMEOUT)
    if proc.returncode != 0:
        raise RuntimeError((proc.stderr or proc.stdout
                            or "pocknix-desktop-select failed").strip())
    return desktop_flavour()


def _unit_names() -> list[str]:
    """Nombres de unidad a probar: el fijo y, si esta ocupado, uno con marca de tiempo."""
    return ["pocknix-desktop-switch",
            f"pocknix-desktop-switch-{int(time.time())}"]


def _systemd_run(unit: str) -> None:
    subprocess.run([
        "systemd-run", "--quiet", "--collect", f"--unit={unit}",
        "runuser", "-u", "deck", "--", "env", "HOME=/home/deck",
        f"XDG_RUNTIME_DIR={DECK_RUNTIME}", SWITCH, "plasma",
    ], check=True, timeout=15, capture_output=True, text=True)


def switch_to_desktop(name: str) -> bool:
    """Fija el sabor y pide el cambio de sesion (desacoplado: nos mata)."""
    set_desktop_flavour(name)

    # Una unidad previa atascada (p.ej. el switch anterior no llego a salir) haria
    # fallar systemd-run con "Unit ... already exists".
    try:
        subprocess.run(["systemctl", "reset-failed", "pocknix-desktop-switch"],
                       capture_output=True, timeout=10)
    except (OSError, subprocess.SubprocessError):
        pass

    error: Exception | None = None
    for unit in _unit_names():
        try:
            _systemd_run(unit)
            return True
        except subprocess.CalledProcessError as exc:  # unidad ya existente / systemd-run KO
            error = exc
            detalle = ((exc.stderr or "") + (exc.stdout or "")).strip()
            print(f"[pocknix] switch_to_desktop: {unit} fallo: {detalle}", flush=True)
            if "already exists" not in detalle:
                break
        except (OSError, subprocess.SubprocessError) as exc:
            error = exc
            break
    raise RuntimeError(f"no se pudo lanzar el cambio a escritorio: {error}")
