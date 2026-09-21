import os
import select
import time
import subprocess
import syslog
import glob
import sys
import json

# Configuration
IDLE_SECONDS = 600
REFRESHER_BIN = "/usr/local/bin/oled-refresher"
CELL_PX = 3
DURATION = 9 # 3 passes * 3 seconds
BACKLIGHT_PATH = "/sys/class/backlight/ae94000.dsi.0/brightness"
DRM_STATUS_PATH = "/sys/class/drm/card0-DSI-1/status"
DEVICE_RESCAN_SECONDS = 60

# Estado para que el plugin (pestana Lighting) pueda decir QUE HACE y CUANDO fue
# el ultimo refresco. En /run (tmpfs): es informativo y se reinicia con el equipo.
STATE_PATH = "/run/pocknix/oled-care.json"

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

# Reproduccion de medios: lo que el usuario hace SIN tocar el mando. Sin esto,
# a los 10 min de inactividad el flash de 9 s interrumpia un video o una cancion.
MEDIA_PROCESSES = (
    "mpv", "mplayer", "vlc", "celluloid", "totem", "smplayer",
    "kodi", "kodi.bin", "plexmediaplayer", "jellyfinmediaplayer",
)
# El propio refrescador (y cualquier cosa nuestra) abre un stream de audio que
# queda en "running" para siempre -> hay que ignorarlo o la deteccion seria
# siempre positiva.
AUDIO_NOISE = ("pocknix", "oled-refresher", "python", "pipewire alsa")

# El daemon corre como ROOT, pero PipeWire/PulseAudio son de la sesion de `deck`.
# Sin XDG_RUNTIME_DIR apuntando a su sesion, `pw-dump` no ve NADA (siempre diria
# que no hay audio). Mismo valor que usa launch_refresher().
DECK_RUNTIME_DIR = "/run/user/1001"


def _pgrep_exact(name):
    try:
        return subprocess.run(["pgrep", "-x", name],
                              capture_output=True).returncode == 0
    except Exception:
        return False


def audio_stream_running():
    """¿Hay un stream de audio REAL en reproduccion? (pw-dump, no pactl: el PCM
    de ALSA queda RUNNING siempre porque PipeWire mantiene el dispositivo)."""
    try:
        env = os.environ.copy()
        env["XDG_RUNTIME_DIR"] = DECK_RUNTIME_DIR
        out = subprocess.run(["pw-dump"], capture_output=True, text=True,
                             timeout=6, env=env)
        if out.returncode != 0:
            return False
        for obj in json.loads(out.stdout or "[]"):
            if obj.get("type") != "PipeWire:Interface:Node":
                continue
            info = obj.get("info") or {}
            props = info.get("props") or {}
            if "Stream/Output/Audio" not in (props.get("media.class") or ""):
                continue
            if (info.get("state") or "") != "running":
                continue
            nombre = (props.get("application.name") or props.get("node.name") or "").lower()
            if any(ruido in nombre for ruido in AUDIO_NOISE):
                continue
            return True
    except Exception:
        pass
    return False


def media_playing():
    """Que esta reproduciendo el usuario, o None.

    Basta con que haya AUDIO sonando, sea la app que sea (reproductor, navegador,
    Spotify...). Un navegador ABIERTO no cuenta: si no suena nada, el usuario no
    esta consumiendo nada y el refresco no le interrumpe.
    """
    for name in MEDIA_PROCESSES:
        if _pgrep_exact(name):
            return name
    if audio_stream_running():
        return "audio en reproduccion"
    return None


def write_state(**campos):
    """Deja el estado para el plugin (best effort, nunca debe tumbar el daemon)."""
    try:
        os.makedirs(os.path.dirname(STATE_PATH), exist_ok=True)
        actual = {}
        try:
            with open(STATE_PATH, "r", encoding="utf-8") as f:
                actual = json.load(f)
        except Exception:
            actual = {}
        actual.update(campos)
        actual["updated"] = int(time.time())
        tmp = STATE_PATH + ".tmp"
        with open(tmp, "w", encoding="utf-8") as f:
            json.dump(actual, f)
        os.replace(tmp, STATE_PATH)
    except Exception:
        pass


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

def _estado_count():
    try:
        with open(STATE_PATH, "r", encoding="utf-8") as f:
            return int(json.load(f).get("count", 0))
    except Exception:
        return 0


def launch_refresher():
    # No refrescar si hay una partida o un frontend en pantalla.
    game = running_game()
    if game:
        log(f"Skipping refresher: '{game}' en ejecucion (modo juego)")
        write_state(lastSkip=f"{game} en ejecucion")
        return

    # Tampoco si el usuario esta viendo/escuchando algo sin tocar el mando.
    media = media_playing()
    if media:
        log(f"Skipping refresher: reproduciendo '{media}'")
        write_state(lastSkip=f"reproduciendo ({media})")
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
            if proc.returncode == 0:
                write_state(lastRefresh=int(time.time()), lastSkip=None,
                            count=_estado_count() + 1)
        except subprocess.TimeoutExpired:
            log("Refresher timed out, killing...")
            proc.kill()

    if was_off:
        log("Restoring display off state...")
        set_display(False)

def main():
    log("Starting daemon...")
    write_state(started=int(time.time()), idleSeconds=IDLE_SECONDS)

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
