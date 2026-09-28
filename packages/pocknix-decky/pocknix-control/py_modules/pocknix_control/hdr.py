"""HDR de gamescope — interruptor de alto rango dinamico (AYN Odin 3 / Pocknix).

En el Odin 3 el HDR de la sesion de Steam lo controla gamescope con dos atomos
X11 en la raiz de SU Xwayland (el de la sesion de juego, DISPLAY=:0):

    GAMESCOPE_DISPLAY_SUPPORTS_HDR  — el output/backend soporta HDR
    GAMESCOPE_DISPLAY_HDR_ENABLED   — HDR activado (CARDINAL 0/1)

Son los mismos atomos que usa el cliente de Steam.

⚠️ El PluginLoader de Decky corre como ROOT, pero el Xwayland de gamescope exige
cookie X y root NO la tiene (xprop devuelve "Authorization required"). El usuario
`deck` SI puede abrirlo sin XAUTHORITY, asi que lanzamos `xprop` COMO `deck`
(runuser). Verificado en la Odin: root falla, deck funciona.

Si no hay sesion gamescope (escritorio Plasma puro, o sin steam) no hay atomos ->
available=False y la UI muestra el interruptor deshabilitado.
"""

from __future__ import annotations

import os
import re
import subprocess

# Atomos de gamescope para el HDR (ver gamescope: xatom / HDR support).
ATOM_SUPPORTS_HDR = "GAMESCOPE_DISPLAY_SUPPORTS_HDR"
ATOM_HDR_ENABLED = "GAMESCOPE_DISPLAY_HDR_ENABLED"

# La sesion de juego (gamescope) tiene SIEMPRE su Xwayland en :0; el de Plasma
# puede estar en otro, y ahi no hay atomos de gamescope.
GAMESCOPE_DISPLAY = ":0"

# uid/gid de `deck` (ver AGENTS.md: fransis=1000, deck=1001).
DECK_UID = 1001
DECK_GID = 1001

_XPROP_TIMEOUT = 5

# "GAMESCOPE_DISPLAY_HDR_ENABLED(CARDINAL) = 1"
_ATOM_RE = re.compile(r"^\s*([A-Z0-9_]+)\s*(?:\(\w+\))?\s*=\s*(.*)$")
_NUM_RE = re.compile(r"-?\d+")


def _xprop_attempts(args: list[str]) -> list[list[str]]:
    """Comandos xprop a probar, en orden (el plugin corre como root)."""
    intentos: list[list[str]] = []
    display = f"DISPLAY={GAMESCOPE_DISPLAY}"
    if os.geteuid() == 0:
        # Como `deck`: es quien puede abrir el X de gamescope sin cookie (root no).
        intentos.append(["runuser", "-u", "deck", "--", "env", display, "xprop"] + args)
        intentos.append([
            "setpriv", f"--reuid={DECK_UID}", f"--regid={DECK_GID}",
            "--init-groups", "env", display, "xprop",
        ] + args)
    # Fallback directo: vale si ya somos deck, o si el X no exige cookie.
    intentos.append(["env", display, "xprop"] + args)
    return intentos


def _run_xprop(args: list[str]) -> subprocess.CompletedProcess | None:
    """xprop contra el Xwayland de gamescope, probando los distintos metodos."""
    for cmd in _xprop_attempts(args):
        try:
            cp = subprocess.run(
                cmd, capture_output=True, text=True, timeout=_XPROP_TIMEOUT,
            )
        except (OSError, subprocess.SubprocessError):
            continue
        if cp.returncode == 0:
            return cp
    return None


def _read_atoms() -> dict:
    """Valores enteros de los atomos de HDR, o {} si no hay sesion gamescope."""
    cp = _run_xprop(["-root"])
    if cp is None:
        return {}

    valores: dict[str, int] = {}
    for linea in (cp.stdout or "").splitlines():
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
    cp = _run_xprop(["-root", "-f", ATOM_HDR_ENABLED, "32c",
                     "-set", ATOM_HDR_ENABLED, str(valor)])
    if cp is None:
        print(f"[pocknix] set_hdr({enabled}): xprop fallo (¿sin sesion gamescope?)",
              flush=True)
    # Si fallo, se devuelve el estado real para que la UI revierta el toggle.
    return hdr_status()
