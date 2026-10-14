#!/usr/bin/env python3
# power-button-daemon.py — boton de encendido de la AYN Odin 3.
#
#   Toque corto  -> SUSPENDE la consola (systemctl suspend)
#   Mantener     -> MENU DE APAGADO de KDE (org.kde.Shutdown.logout)
#   En MODO JUEGO (sin plasmashell) NO actua: ahi lo maneja Steam/gamescope.
#
# El daemon original ("Power button display toggle") vivia SOLO en la consola (/usr/local/bin,
# sin fuente en los repos) y hacia un simple apagado/encendido de pantalla al pulsar, sin distinguir
# toque de mantener. Aqui esta versionado y con el comportamiento pedido por Fransis (14/10/2026).
import os
import struct
import subprocess
import threading
from pathlib import Path

EVENT_DEV = Path("/dev/input/event0")
EV_KEY = 0x01
KEY_POWER = 116
EVENT_SIZE = struct.calcsize("=QQHHi")
HOLD_SECONDS = 1.5
SESSION_UID = 1001


def desktop_session() -> bool:
    """True si hay una sesion de Plasma (modo escritorio). En modo juego (solo Steam) no la hay."""
    try:
        return subprocess.run(["pgrep", "-x", "plasmashell"],
                              stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL).returncode == 0
    except OSError:
        return False


def show_shutdown_menu() -> None:
    """Menu de apagado de KDE (el dialogo con Apagar/Reiniciar/Cerrar sesion)."""
    env = dict(os.environ)
    env["XDG_RUNTIME_DIR"] = f"/run/user/{SESSION_UID}"
    env["DBUS_SESSION_BUS_ADDRESS"] = f"unix:path=/run/user/{SESSION_UID}/bus"
    try:
        subprocess.run(["gdbus", "call", "--session",
                        "--dest", "org.kde.Shutdown", "--object-path", "/Shutdown",
                        "--method", "org.kde.Shutdown.logout"],
                       env=env, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
    except OSError:
        pass


def suspend() -> None:
    try:
        subprocess.run(["systemctl", "suspend"], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
    except OSError:
        pass


def main() -> None:
    fd = os.open(EVENT_DEV, os.O_RDONLY)
    hold: threading.Timer | None = None
    try:
        while True:
            data = os.read(fd, EVENT_SIZE)
            if len(data) != EVENT_SIZE:
                continue
            _, _, ev_type, code, value = struct.unpack("=QQHHi", data)
            if ev_type != EV_KEY or code != KEY_POWER:
                continue
            if value == 1:                      # pulsado
                if not desktop_session():
                    continue                    # modo juego: no intervenimos
                hold = threading.Timer(HOLD_SECONDS, show_shutdown_menu)
                hold.daemon = True
                hold.start()
            elif value == 0:                    # soltado
                if hold is not None:
                    disparado = hold.finished.is_set()
                    hold.cancel()
                    hold = None
                    if not disparado:
                        suspend()               # toque corto -> suspender
    finally:
        os.close(fd)


if __name__ == "__main__":
    main()
