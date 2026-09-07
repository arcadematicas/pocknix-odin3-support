#!/usr/bin/env python3
"""MangoHud toggle daemon.

Escucha la tecla F13 (KEY_F13=183) emitida por el teclado virtual de
InputPlumber (el paddle trasero M2 del Odin 3 se re-mapeo a F13 en
ayn_mcu.yaml) y alterna `no_display` en la config de MangoHud.

mangoapp relee ~/.config/MangoHud/MangoHud.conf periodicamente, asi que al
alternar el archivo el HUD se oculta/muestra en ~1s.
"""
import os
import struct
import time
import glob
import syslog
import signal
import subprocess

KEY_F13 = 183
CONF = "/home/deck/.config/MangoHud/MangoHud.conf"


def log(msg):
    syslog.syslog(syslog.LOG_INFO, f"mangohud-toggle: {msg}")
    print(msg, file=__import__("sys").stderr)


def find_ip_keyboard():
    """Busca el teclado virtual que crea InputPlumber por su nombre."""
    for path in glob.glob("/dev/input/event*"):
        name_path = f"/sys/class/input/{os.path.basename(path)}/device/name"
        try:
            with open(name_path) as f:
                if "InputPlumber Keyboard" in f.read():
                    return path
        except OSError:
            pass
    return None


def reload_mangoapp():
    """mangoapp no monitorea la config: tras cambiarla hay que avisarle
    con SIGHUP para que la recargue."""
    try:
        out = subprocess.run(["pgrep", "-x", "mangoapp"],
                             capture_output=True, text=True, timeout=5)
        for pid in out.stdout.strip().splitlines():
            os.kill(int(pid), signal.SIGHUP)
            log(f"SIGHUP enviado a mangoapp ({pid})")
    except Exception as e:
        log(f"Error enviando SIGHUP a mangoapp: {e}")


def toggle():
    try:
        with open(CONF) as f:
            content = f.read()
        if "no_display" in content:
            content = content.replace("no_display", "").replace("\n\n", "\n").strip() + "\n"
            log("HUD -> visible")
        else:
            content = content.rstrip() + "\nno_display\n"
            log("HUD -> oculto")
        with open(CONF, "w") as f:
            f.write(content)
        reload_mangoapp()
    except Exception as e:
        log(f"Error alternando config: {e}")


def main():
    log("Daemon iniciado")
    dev = find_ip_keyboard()
    if not dev:
        log("No encontre el teclado virtual de InputPlumber (saldre, systemd reintenta)")
        return
    log(f"Escuchando {dev} por F13")
    try:
        fd = os.open(dev, os.O_RDONLY | os.O_NONBLOCK)
    except OSError as e:
        log(f"No pude abrir {dev}: {e}")
        return
    try:
        while True:
            try:
                data = os.read(fd, 24)
                if len(data) == 24:
                    _sec, _usec, type_, code, value = struct.unpack("llHHi", data)
                    if type_ == 1 and code == KEY_F13 and value == 1:
                        toggle()
            except BlockingIOError:
                time.sleep(0.02)
            except OSError:
                log("Error leyendo (probable reinicio de InputPlumber), salgo")
                break
    finally:
        os.close(fd)


if __name__ == "__main__":
    main()
