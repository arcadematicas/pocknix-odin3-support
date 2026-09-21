"""system_info.py — Pestaña "Sistema": informacion de la bateria.

QUE SE PORTA AQUI (de Panel de Control, Hooandee)
  Lo unico que Steam NO ensena: salud y ciclos de la bateria, y el voltaje y la
  corriente reales. Es todo LECTURA.

LO QUE NO SE PONE A PROPOSITO (avisado por Fransis)
  - Selector de perfil de potencia: REDUNDANTE. El QAM nativo de Steam ya lo
    tiene, y su shim (pocknix-steamos-manager) traduce
    low-power/balanced/performance a nuestro `pocknix-power-profile`. Duplicarlo
    solo confundia.
  - Control de brillo: redundante, Steam lo controla de forma nativa.


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






def system_status():
    """Lo que consume la pestaña: solo la bateria (el perfil y el brillo ya los
    controla Steam de forma nativa)."""
    return {"battery": battery()}
