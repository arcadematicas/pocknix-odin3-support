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


def send_report(text: str = "", timeout: int = 180) -> dict:
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

    cmd = [exe, "--send", "--yes", "--no-qr"]
    t = (text or "").strip()
    if t:
        cmd += ["--text", t[:1000]]

    try:
        # Sin text=True: el diagnostico incluye dmesg/journal y puede traer bytes que no son
        # UTF-8 valido. Con text=True el decode estricto lanzaba UnicodeDecodeError y el panel
        # mostraba "fallo" aunque el informe se hubiera enviado. Decodificamos con replace.
        # Entorno LIMPIO a proposito. Decky corre bajo PyInstaller/FEX y hereda
        # LD_LIBRARY_PATH apuntando a su /tmp: el python nativo del doctor cargaba sus
        # libssl/libcrypto y fallaba con errores de certificados. Solo pasamos lo basico.
        env = {
            "PATH": "/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin",
            "HOME": os.environ.get("HOME", "/root"),
            "USER": os.environ.get("USER", "root"),
            "LANG": "C.UTF-8",
            "LC_ALL": "C.UTF-8",
            "TERM": "dumb",
        }
        proc = subprocess.run(cmd, capture_output=True, timeout=timeout, env=env)
    except subprocess.TimeoutExpired:
        return {"ok": False, "error": "timeout ({}s): el informe tarda mas de lo normal".format(timeout)}
    except Exception as exc:  # noqa: BLE001 - se devuelve al panel, no se propaga
        return {"ok": False, "error": str(exc)}

    out = ((proc.stdout or b"") + (proc.stderr or b"")).decode("utf-8", "replace")
    match = _ISSUE.search(out)
    if match:
        return {"ok": True, "issue": match.group(1)}
    return {"ok": False, "error": "no se pudo enviar (rc={})".format(proc.returncode), "detail": out[-400:]}
