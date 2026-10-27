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


def send_report(text: str = "", kind: str = "bug", areas=None, timeout: int = 180) -> dict:
    """Lanza `calvos-doctor --send --yes` y devuelve `{ok, issue}` o `{ok: False, error, detail}`.

    Bloqueante (subprocess): el llamador debe usar `asyncio.to_thread`.
    """
    # El BSP lo instala en /usr/local/bin (no en /usr/bin). Probamos las rutas reales antes
    # de fiarnos de PATH: el backend de Decky corre como root con un PATH propio.
    exe = ""
    for cand in ("/usr/local/bin/calvos-doctor", "/usr/bin/calvos-doctor"):
        if os.path.exists(cand):
            exe = cand
            break
    if not exe:
        exe = shutil.which("calvos-doctor") or ""
    if not exe:
        return {"ok": False, "error": "calvos-doctor no esta instalado"}

    # OJO: Decky corre bajo FEX (python x86 de PyInstaller). Un hijo lanzado desde ahi se
    # ejecuta EMULADO y el informe sale con kernel/arch falsos (6.11.0 / x86_64). Por eso el
    # doctor se lanza a traves de systemd (PID 1), que lo ejecuta en el host con el python
    # nativo y un entorno limpio. Si systemd-run no esta, se cae al lanzamiento directo.
    base = ["/usr/bin/python3", exe, "--send", "--yes", "--no-qr", "--kind", kind if kind in ("bug", "idea") else "bug"]
    if areas:
        base += ["--areas", ",".join(a for a in areas if isinstance(a, str))]
    t = (text or "").strip()
    if t:
        base += ["--text", t[:1000]]

    env = {
        "PATH": "/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin",
        "HOME": os.environ.get("HOME", "/root"),
        "USER": os.environ.get("USER", "root"),
        "LANG": "C.UTF-8",
        "LC_ALL": "C.UTF-8",
        "TERM": "dumb",
    }
    unit = "pocknix-report-{}".format(os.getpid())
    runner = ["systemd-run", "--quiet", "--collect", "--wait", "--pipe", "--unit", unit]

    proc = None
    try:
        proc = subprocess.run(runner + base, capture_output=True, timeout=timeout, env=env)
    except FileNotFoundError:
        proc = None
    except subprocess.TimeoutExpired:
        return {"ok": False, "error": "timeout ({}s): el informe tarda mas de lo normal".format(timeout)}

    # Si systemd no pudo (no es root, no hay dbus...), intento directo como red de seguridad.
    if proc is None or (proc.returncode != 0 and b"issue:" not in (proc.stdout or b"") + (proc.stderr or b"")):
        try:
            proc = subprocess.run(base, capture_output=True, timeout=timeout, env=env)
        except subprocess.TimeoutExpired:
            return {"ok": False, "error": "timeout ({}s): el informe tarda mas de lo normal".format(timeout)}
        except Exception as exc:  # noqa: BLE001
            if proc is None:
                return {"ok": False, "error": str(exc)}

    out = ((proc.stdout or b"") + (proc.stderr or b"")).decode("utf-8", "replace")
    match = _ISSUE.search(out)
    if match:
        return {"ok": True, "issue": match.group(1)}
    return {"ok": False, "error": "no se pudo enviar (rc={})".format(proc.returncode), "detail": out[-400:]}
