"""system_info.py — Pestaña "Sistema": perfil de potencia, batería y brillo.

QUE SE PORTA AQUI (de Panel de Control, Hooandee)
  De su plugin nos interesaban tres cosas que NO teniamos expuestas en el QAM:
    1. El perfil de potencia de un vistazo (nosotros YA tenemos la herramienta
       `pocknix-power-profile` — bajo/medio/alto — pero no estaba en el panel).
    2. La bateria con su salud y ciclos, no solo el porcentaje.
    3. El brillo con el numero exacto, que Steam esconde.
  El resto de su plugin (TDP real por firmware, curvas por juego, ecualizador,
  editor de MangoHud, opciones de lanzamiento) o no aplica a este SoC o es mucho
  mas trabajo; queda anotado como hoja de ruta.

OJO (arquitectura del plugin): este Python es un invitado x86_64 bajo FEX, asi que
los scripts del sistema (aarch64) NO se pueden llamar directamente -> systemd-run,
igual que hacen sharing.py y updates.py.
"""

from pathlib import Path

from .system import run_cmd

POWER_PROFILE = "/usr/local/bin/pocknix-power-profile"
PROFILES = ("bajo", "medio", "alto")
PROFILE_LABELS = {
    "bajo": "Bajo — batería",
    "medio": "Medio — equilibrado",
    "alto": "Alto — máximo rendimiento",
}

# El nodo de la bateria no tiene un nombre fijo entre kernels/drivers.
BATTERY_GLOBS = (
    "/sys/class/power_supply/*/capacity",
)


def _read(path):
    try:
        return Path(path).read_text(encoding="utf-8", errors="replace").strip()
    except OSError:
        return None


def _read_int(path):
    try:
        return int(Path(path).read_text(encoding="utf-8", errors="replace").strip())
    except (OSError, ValueError):
        return None


def _battery_dir():
    """Directorio del nodo de la bateria (el nombre varia)."""
    import glob

    for patron in ("/sys/class/power_supply/*/type",):
        for node in glob.glob(patron):
            if _read(node) == "Battery":
                return Path(node).parent
    return None


def power_profile():
    """Perfil de potencia actual (bajo|medio|alto)."""
    out = run_cmd(["systemd-run", "--quiet", "--collect", "--wait", "--pipe", POWER_PROFILE], timeout=15)
    if out is None or out.returncode != 0:
        return None
    valor = (out.stdout or "").strip().splitlines()
    actual = valor[0].strip() if valor else ""
    return actual if actual in PROFILES else None


def set_power_profile(profile):
    if profile not in PROFILES:
        raise ValueError(f"perfil desconocido: {profile!r}")
    out = run_cmd(
        ["systemd-run", "--quiet", "--collect", "--wait", "--pipe", POWER_PROFILE, profile],
        timeout=30,
    )
    if out is None or out.returncode != 0:
        raise RuntimeError("no se pudo aplicar el perfil")
    return {"profile": power_profile()}


def battery():
    """Estado, salud, ciclos y capacidad. Lo que no exista se devuelve en None
    (la UI muestra '-' en vez de inventarse un valor)."""
    node = _battery_dir()
    if node is None:
        return {"available": False}
    datos = {
        "available": True,
        "capacity": _read_int(node / "capacity"),
        "status": _read(node / "status"),
        "health": _read(node / "health"),
        "cycles": _read_int(node / "cycle_count"),
        # capacity_level y los microvatios/amperios dan el detalle fino
        "voltageNow": _read_int(node / "voltage_now"),
        "currentNow": _read_int(node / "current_now"),
        "chargeFull": _read_int(node / "charge_full"),
        "chargeFullDesign": _read_int(node / "charge_full_design"),
        "powerNow": _read_int(node / "power_now"),
    }
    # Salud calculada si el driver no la da: capacidad real / capacidad de diseño.
    if not datos["health"] and datos["chargeFull"] and datos["chargeFullDesign"]:
        pct = round(100 * datos["chargeFull"] / datos["chargeFullDesign"])
        datos["health"] = f"{pct}%"
    return datos


def backlight():
    """Brillo actual y maximo del panel principal."""
    import glob

    for patron in ("/sys/class/backlight/*/brightness",):
        for node in glob.glob(patron):
            path = Path(node)
            actual = _read_int(path)
            maximo = _read_int(path.parent / "max_brightness")
            if actual is None or not maximo:
                continue
            return {"available": True, "value": actual, "max": maximo,
                    "percent": round(100 * actual / maximo)}
    return {"available": False}


def set_backlight(percent):
    """Fija el brillo en % (0-100)."""
    import glob

    try:
        percent = max(1, min(100, int(percent)))     # 0 dejaria la pantalla negra
    except (TypeError, ValueError):
        raise ValueError("porcentaje invalido")
    for node in glob.glob("/sys/class/backlight/*/brightness"):
        path = Path(node)
        maximo = _read_int(path.parent / "max_brightness")
        if not maximo:
            continue
        try:
            path.write_text(str(round(maximo * percent / 100)), encoding="utf-8")
        except OSError as exc:
            raise RuntimeError(f"no se pudo cambiar el brillo: {exc.strerror or exc}")
        return backlight()
    raise RuntimeError("no hay backlight")


def system_status():
    return {
        "profile": power_profile(),
        "profiles": [{"id": p, "label": PROFILE_LABELS[p]} for p in PROFILES],
        "battery": battery(),
        "backlight": backlight(),
    }
