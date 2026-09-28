"""HDR de gamescope — interruptor de alto rango dinamico (AYN Odin 3 / Pocknix).

En el Odin 3 el HDR de la sesion de Steam lo controla gamescope con dos atomos
X11 en la raiz de SU Xwayland (el de la sesion de juego, DISPLAY=:0):

    GAMESCOPE_DISPLAY_SUPPORTS_HDR  — el output/backend soporta HDR
    GAMESCOPE_DISPLAY_HDR_ENABLED   — HDR activado (CARDINAL 0/1)

Son los mismos atomos que usa el cliente de Steam, asi que activarlos aqui es
equivalente a lo que haria el QAM (que en el cliente ARM64 no lo expone).

El PluginLoader de Decky corre como root SIN entorno grafico, por lo que no
tiene DISPLAY/XAUTHORITY: se reutiliza el mismo truco que el OLED care
(oled_care._session_env()) y se le pasa ese entorno a xprop. Si no hay sesion
gamescope (escritorio Plasma, o sin steam) no hay atomos -> available=False y la
UI muestra el interruptor deshabilitado.
"""

from __future__ import annotations

import re
import subprocess

from pocknix_control.oled_care import _session_env

# Atomos de gamescope para el HDR (ver gamescope: xatom / HDR support).
ATOM_SUPPORTS_HDR = "GAMESCOPE_DISPLAY_SUPPORTS_HDR"
ATOM_HDR_ENABLED = "GAMESCOPE_DISPLAY_HDR_ENABLED"

# La sesion de juego (gamescope) tiene SIEMPRE su Xwayland en :0; el de Plasma
# puede estar en otro, y ahi no hay atomos de gamescope. Igual que hace
# oled_care.run_refresher() para el modo juego, fijamos :0 a proposito.
GAMESCOPE_DISPLAY = ":0"

_XPROP_TIMEOUT = 5

# "GAMESCOPE_DISPLAY_HDR_ENABLED(CARDINAL) = 1"
_ATOM_RE = re.compile(r"^\s*([A-Z0-9_]+)\s*(?:\(\w+\))?\s*=\s*(.*)$")
_NUM_RE = re.compile(r"-?\d+")


def _xprop_env() -> dict:
    """Entorno para poder hablar con el Xwayland de gamescope."""
    env = {"DISPLAY": GAMESCOPE_DISPLAY}
    # XAUTHORITY / XDG_RUNTIME_DIR vienen del proceso de la sesion; DISPLAY lo
    # fijamos nosotros (ver GAMESCOPE_DISPLAY).
    for key, value in _session_env().items():
        if key != "DISPLAY":
            env[key] = value
    return env


def _read_atoms() -> dict:
    """Valores enteros de los atomos de HDR, o {} si no hay sesion gamescope."""
    try:
        out = subprocess.run(
            ["xprop", "-root"],
            capture_output=True, text=True,
            timeout=_XPROP_TIMEOUT, env=_xprop_env(),
        )
    except (OSError, subprocess.SubprocessError):
        return {}
    if out.returncode != 0:
        return {}

    valores: dict[str, int] = {}
    for linea in (out.stdout or "").splitlines():
        match = _ATOM_RE.match(linea)
        if not match:
            continue
        nombre, valor = match.group(1), match.group(2)
        if nombre not in (ATOM_SUPPORTS_HDR, ATOM_HDR_ENABLED):
            continue
        numeros = _NUM_RE.findall(valor)
        if numeros:
            valores[nombre] = int(numeros[0])
    return valores


def hdr_status() -> dict:
    """Estado del HDR de la sesion de juego.

    available = hay sesion gamescope (el atomo SUPPORTS_HDR existe)
    capable   = ese output soporta HDR
    enabled   = el HDR esta activado ahora mismo
    """
    atomes = _read_atoms()
    return {
        "available": ATOM_SUPPORTS_HDR in atomes,
        "capable": atomes.get(ATOM_SUPPORTS_HDR, 0) > 0,
        "enabled": atomes.get(ATOM_HDR_ENABLED, 0) > 0,
    }


def set_hdr(enabled: bool) -> dict:
    """Activa/desactiva el HDR escribiendo el atomo de gamescope (32c = CARDINAL)."""
    estado = hdr_status()
    if not estado["available"]:
        # Sin sesion gamescope no hay a quien avisar: escribir el atomo ahi solo
        # crearia una propiedad nueva en un Xwayland que no la escucha.
        print("[pocknix] set_hdr: no hay sesion gamescope", flush=True)
        return estado

    valor = 1 if enabled else 0
    try:
        subprocess.run(
            ["xprop", "-root", "-f", ATOM_HDR_ENABLED, "32c",
             "-set", ATOM_HDR_ENABLED, str(valor)],
            capture_output=True, text=True,
            timeout=_XPROP_TIMEOUT, env=_xprop_env(),
        )
    except (OSError, subprocess.SubprocessError) as err:
        # Si falla, se devuelve el estado real para que la UI revierta el toggle.
        print(f"[pocknix] set_hdr({enabled}) fallo: {err}", flush=True)
    return hdr_status()
