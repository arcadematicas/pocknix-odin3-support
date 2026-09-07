import os
import select
import time
import subprocess
import syslog
import glob
import sys

# Configuration
IDLE_SECONDS = 180
REFRESHER_BIN = "/usr/local/bin/oled-refresher"
CELL_PX = 3
DURATION = 9 # 3 passes * 3 seconds
BACKLIGHT_PATH = "/sys/class/backlight/ae94000.dsi.0/brightness"
DRM_STATUS_PATH = "/sys/class/drm/card0-DSI-1/status"

def log(msg):
    syslog.syslog(syslog.LOG_INFO, f"oled-care-daemon: {msg}")
    print(msg, file=sys.stderr)

def get_steam_env():
    try:
        # Find steam pid
        out = subprocess.run(["pgrep", "-x", "steam"], capture_output=True, text=True)
        if not out.stdout.strip():
            return {}
        pid = out.stdout.strip().splitlines()[0]
        # Read environ
        with open(f"/proc/{pid}/environ", "rb") as f:
            data = f.read()
        env = {}
        for entry in data.split(b"\0"):
            if b"=" in entry:
                key, _, value = entry.partition(b"=")
                env[key.decode()] = value.decode()
        return env
    except Exception as e:
        log(f"Error getting steam env: {e}")
        return {}

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
    log("Launching refresher...")
    
    was_off = is_display_off()
    if was_off:
        log("Display was off, turning on...")
        set_display(True)
        time.sleep(1)
    
    # Check mode
    is_steam = subprocess.run(["pgrep", "-x", "steam"], capture_output=True).returncode == 0
    is_gamescope = subprocess.run(["pgrep", "-x", "gamescope"], capture_output=True).returncode == 0
    
    proc = None
    if is_steam or is_gamescope:
        log("Mode: Game (Steam/Gamescope)")
        env = get_steam_env()
        cmd = ["sudo", "-u", "deck"]
        if "XAUTHORITY" in env:
            cmd.extend(["env", f"XAUTHORITY={env['XAUTHORITY']}", "DISPLAY=:0", "SDL_VIDEODRIVER=x11"])
        else:
            cmd.extend(["env", "DISPLAY=:0", "SDL_VIDEODRIVER=x11"])
        cmd.extend([REFRESHER_BIN, str(DURATION), str(CELL_PX)])
        
        proc = subprocess.Popen(cmd, stdout=subprocess.DEVNULL, stderr=open("/tmp/oled-care-refresher.log", "a"))
    else:
        log("Mode: Desktop (Plasma)")
        env = os.environ.copy()
        env["WAYLAND_DISPLAY"] = "wayland-0"
        env["DISPLAY"] = ":0"
        env["XDG_RUNTIME_DIR"] = "/run/user/1001"
        env["SDL_VIDEODRIVER"] = "wayland"
        
        proc = subprocess.Popen([REFRESHER_BIN, str(DURATION), str(CELL_PX)], env=env, stdout=subprocess.DEVNULL, stderr=open("/tmp/oled-care-refresher.log", "a"))
    
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
    
    # Setup input monitoring
    devices = glob.glob("/dev/input/event*")
    fds = {os.open(d, os.O_RDONLY | os.O_NONBLOCK): d for d in devices}
    poll = select.poll()
    for fd in fds:
        poll.register(fd, select.POLLIN)
    
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

if __name__ == "__main__":
    main()
