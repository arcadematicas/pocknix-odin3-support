"""Informe de incidencias delegando en `calvos-doctor`.

El script del sistema (paquete `pocknix-bsp-sm8750`) es quien recoge el diagnostico, redacta los
datos personales (rutas de usuario, hostname, IP, MAC, SSID, claves...) y lo envia a nuestro
colector: un Worker que abre el issue en `arcadematicas/calvOS-reports`. Aqui no duplicamos nada de
eso: solo lanzamos el script y parseamos su salida. El token de GitHub vive SOLO en el Worker.
"""

from __future__ import annotations

import os
import re
import shutil
import subprocess

# `calvos-doctor` imprime "  issue: https://github.com/..." cuando el envio va bien.
_ISSUE = re.compile(r"issue:\s*(\S+)")


def send_report(text: str = "", timeout: int = 120) -> dict:
    """Lanza `calvos-doctor --send --yes` y devuelve `{ok, issue}` o `{ok: False, error, detail}`.

    Bloqueante (subprocess): el llamador debe usar `asyncio.to_thread`.
    """
    exe = "/usr/bin/calvos-doctor"
    if not os.path.exists(exe):
        exe = shutil.which("calvos-doctor") or ""
    if not exe:
        return {"ok": False, "error": "calvos-doctor no esta instalado"}

    cmd = [exe, "--send", "--yes"]
    t = (text or "").strip()
    if t:
        cmd += ["--text", t[:1000]]

    try:
        proc = subprocess.run(cmd, capture_output=True, text=True, timeout=timeout)
    except subprocess.TimeoutExpired:
        return {"ok": False, "error": "timeout"}
    except Exception as exc:  # noqa: BLE001 - se devuelve al panel, no se propaga
        return {"ok": False, "error": str(exc)}

    out = (proc.stdout or "") + (proc.stderr or "")
    match = _ISSUE.search(out)
    if match:
        return {"ok": True, "issue": match.group(1)}
    return {"ok": False, "error": "no se pudo enviar", "detail": out[-400:]}
