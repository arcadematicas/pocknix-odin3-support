import os
import select
import time
import subprocess
import syslog
import glob
import sys

# Configuration
IDLE_SECONDS = 600
REFRESHER_BIN = "/usr/local/bin/oled-refresher"
CELL_PX = 3
DURATION = 9 # 3 passes * 3 seconds
BACKLIGHT_PATH = "/sys/class/backlight/ae94000.dsi.0/brightness"
DRM_STATUS_PATH = "/sys/class/drm/card0-DSI-1/status"
DEVICE_RESCAN_SECONDS = 60

# Procesos que indican que hay una partida o un frontend en pantalla. Mientras
# alguno corra NO se refresca: el destello del refrescador es muy intrusivo en
# mitad de una partida (y tambien molesta navegando por ES-DE o Steam).
GAME_PROCESSES = (
    "es-de",             # ES-DE (DeckStation)
    "emulationstation",  # ES-DE (nombre alternativo)
    "retroarch",         # RetroArch
    "steam",             # Steam (Game Mode)
    "steamwebhelper",    # Steam (helper)
    "gamescope",         # gamescope
)

def log(msg):
    syslog.syslog(syslog.LOG_INFO, f"oled-care-daemon: {msg}")
    print(msg, file=sys.stderr)

def running_game():
    """Nombre del primer proceso de juego/frontend activo, o None si no hay."""
    for name in GAME_PROCESSES:
        try:
            if subprocess.run(["pgrep", "-x", name],
                              capture_output=True).returncode == 0:
                return name
        except Exception:
            continue
    return None

def is_display_off():
    try:
        with open(BACKLIGHT_PATH, "r") as f:
            return int(f.read().strip()) == 0
    except:
        return False

def set_display(on):
    try:
        with open(DRM_STATUS_PATH, "w") as f:
            f.write("on" if on else "off")
        with open(BACKLIGHT_PATH, "w") as f:
            f.write("3072" if on else "0")
    except Exception as e:
        log(f"Error setting display: {e}")

def launch_refresher():
    # No refrescar si hay una partida o un frontend en pantalla.
    game = running_game()
    if game:
        log(f"Skipping refresher: '{game}' en ejecucion (modo juego)")
        return

    log("Launching refresher...")

    was_off = is_display_off()
    if was_off:
        log("Display was off, turning on...")
        set_display(True)
        time.sleep(1)

    log("Mode: Desktop (Plasma)")
    env = os.environ.copy()
    env["WAYLAND_DISPLAY"] = "wayland-0"
    env["DISPLAY"] = ":0"
    env["XDG_RUNTIME_DIR"] = "/run/user/1001"
    env["SDL_VIDEODRIVER"] = "wayland"

    proc = subprocess.Popen([REFRESHER_BIN, str(DURATION), str(CELL_PX)], env=env,
                            stdout=subprocess.DEVNULL,
                            stderr=open("/tmp/oled-care-refresher.log", "a"))

    if proc:
        try:
            proc.wait(timeout=DURATION + 10)
            log(f"Refresher finished with code {proc.returncode}")
        except subprocess.TimeoutExpired:
            log("Refresher timed out, killing...")
            proc.kill()

    if was_off:
        log("Restoring display off state...")
        set_display(False)

def main():
    log("Starting daemon...")

    poll = select.poll()
    fds = {}
    last_scan = 0.0

    def rescan_devices(force=False):
        """(Re)abre /dev/input/event* — los nodos pueden recrearse en caliente,
        y si el daemon se queda con fds muertos deja de detectar actividad."""
        nonlocal last_scan
        if not force and time.monotonic() - last_scan < DEVICE_RESCAN_SECONDS:
            return
        last_scan = time.monotonic()
        current = set(glob.glob("/dev/input/event*"))
        known = set(fds.values())
        if current == known and fds:
            return
        for fd, dev in list(fds.items()):
            if dev not in current:
                try:
                    poll.unregister(fd)
                except Exception:
                    pass
                try:
                    os.close(fd)
                except Exception:
                    pass
                del fds[fd]
        for dev in sorted(current - known):
            try:
                fd = os.open(dev, os.O_RDONLY | os.O_NONBLOCK)
            except OSError:
                continue
            try:
                poll.register(fd, select.POLLIN)
            except Exception:
                os.close(fd)
                continue
            fds[fd] = dev
        log(f"Input devices monitored: {len(fds)}")

    rescan_devices(force=True)

    last_activity = time.monotonic()

    while True:
        events = poll.poll(1000)
        if events:
            last_activity = time.monotonic()
            for fd, _ in events:
                try:
                    os.read(fd, 1024)
                except:
                    pass
        elif time.monotonic() - last_activity > IDLE_SECONDS:
            launch_refresher()
            last_activity = time.monotonic() # Reset timer

        rescan_devices()

if __name__ == "__main__":
    main()
