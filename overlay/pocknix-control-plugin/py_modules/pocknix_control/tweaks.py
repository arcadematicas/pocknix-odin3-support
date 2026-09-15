import copy
import json
import re
from pathlib import Path

from .system import atomically_write

# The tweaks file is consumed at game launch by pocknix-proton-wrapper; the profile contract
# ships with that wrapper, so the plugin-dir copy is only a fallback for a missing pocknix-steam.
TWEAKS_CONFIG = Path("/etc/pocknix/game-tweaks.json")
FEX_PROFILES_CONFIG = Path("/usr/share/pocknix/fex-profiles.json")
PLUGIN_FEX_PROFILES_CONFIG = Path(__file__).resolve().parent.parent.parent / "fex-profiles.json"
TURNIP_DIRS = {"arm": Path("/usr/share/pocknix/vk-arm"), "x86": Path("/usr/share/pocknix/vk-x86")}
CONTAINER_VK_LIST = Path("/usr/share/fex-emu/vk-x86-container.list")
# Modos validos por campo de /run/pocknix/game-mode; mismas listas que usa pocknix-proton-wrapper.
FAN_MODES = ("quiet", "moderate", "performance", "off")
LAVD_MODES = ("autopilot", "performance", "balanced", "powersave")
CPU_GOVERNORS = ("powersave", "schedutil", "performance", "ondemand")
POWER_PROFILES = ("bajo", "medio", "alto")
# Fichero pid-tagged que releen pocknix-fancontrol / pocknix-lavd / pergame-power cada ~3s.
GAME_MODE_FILE = Path("/run/pocknix/game-mode")
# Claves de entorno que identifican el appid de Steam en /proc/<pid>/environ; mismo orden de
# prioridad que appid() en pocknix-proton-wrapper.
_APPID_ENV_KEYS = ("STEAM_COMPAT_APP_ID", "SteamAppId", "SteamGameId")


def _appid_of_pid(pid):
    # Appid Steam (str) anunciado en el entorno del proceso pid, o None si no lleva ninguna de
    # las claves _APPID_ENV_KEYS o el valor no es solo digitos.
    try:
        raw_env = (Path("/proc") / str(pid) / "environ").read_bytes()
    except OSError:
        return None
    for key in _APPID_ENV_KEYS:
        needle = key.encode() + b"="
        for entry in raw_env.split(b"\0"):
            if entry.startswith(needle):
                value = entry[len(needle):].decode("utf-8", "replace").strip()
                if value.isdigit():
                    return value
    return None


def _pids_for_appid(appid):
    # Pids vivos (int, ascendente) cuyo entorno anuncia ese appid; un juego puede tener varios
    # procesos SteamAppId-tagged (wrapper + juego), cualquiera sirve de ancla para el override.
    pids = []
    try:
        procs = list(Path("/proc").iterdir())
    except OSError:
        return pids
    for proc in procs:
        if not proc.name.isdigit():
            continue
        # Si el proceso muere entre el listado y la lectura, _appid_of_pid devuelve None.
        if _appid_of_pid(proc.name) == appid:
            pids.append(int(proc.name))
    return sorted(pids)


def mesa_versions():
    # One entry per series ("25.2"); the wrapper resolves the point release per Proton flavor.
    # x86 SLR captures graphics from the FEX rootfs, so an x86 payload that is not embedded in
    # the image would be a pin the wrapper refuses at launch.
    try:
        embedded = set(CONTAINER_VK_LIST.read_text().split())
    except OSError:
        embedded = set()
    series = {}
    for arch, base in TURNIP_DIRS.items():
        try:
            versions = [p.name for p in base.iterdir() if (p / "icd.json").is_file()]
        except OSError:
            continue
        for v in versions:
            if arch == "x86" and v not in embedded:
                continue
            m = re.match(r"([0-9]+)\.([0-9]+)", v)
            if not m:
                continue
            entry = series.setdefault(f"{m.group(1)}.{m.group(2)}", {"archs": set(), "rc": True, "devel": True})
            entry["archs"].add(arch)
            entry["rc"] = entry["rc"] and "rc" in v
            entry["devel"] = entry["devel"] and "devel" in v
    choices = []
    for key, entry in series.items():
        # "git" marks an unreleased main snapshot, so a devel payload can't read as a
        # shipped release (the series key alone would show a bare "26.3").
        label = key + (" RC" if entry["rc"] else "") + (" git" if entry["devel"] else "")
        if entry["archs"] != {"arm", "x86"}:
            label += f" ({'ARM' if 'arm' in entry['archs'] else 'x86'} only)"
        choices.append({"data": key, "label": label})
    return sorted(choices, key=lambda c: tuple(int(x) for x in c["data"].split(".")))


def load_fex_contract():
    path = FEX_PROFILES_CONFIG if FEX_PROFILES_CONFIG.exists() else PLUGIN_FEX_PROFILES_CONFIG
    with path.open(encoding="utf-8") as f:
        contract = json.load(f)
    profiles = contract.get("profiles")
    if not isinstance(contract.get("defaults"), dict) or not isinstance(profiles, dict) or "default" not in profiles:
        raise ValueError("invalid FEX profile contract")
    for profile in profiles.values():
        if not isinstance(profile, dict) or not isinstance(profile.get("config"), dict):
            raise ValueError("invalid FEX profile contract")
    return contract


def fex_profile_labels(contract):
    # "steam" = the profile's STEAM_COMPAT_FEX_CONFIG string (see src/lib/launchOptions.ts).
    return {
        name: {
            "label": profile.get("label", name.title()),
            "config": profile.get("config", {}),
            "steam": profile.get("steam", ""),
        }
        for name, profile in contract["profiles"].items()
        if isinstance(profile, dict)
    }


def load_tweaks():
    contract = load_fex_contract()
    try:
        with TWEAKS_CONFIG.open(encoding="utf-8") as f:
            loaded = json.load(f)
    except (OSError, ValueError):
        return copy.deepcopy(contract["defaults"])
    data = copy.deepcopy(contract["defaults"])
    if isinstance(loaded, dict):
        if isinstance(loaded.get("global"), dict):
            data["global"].update(loaded["global"])
        if isinstance(loaded.get("games"), dict):
            data["games"] = {
                str(k): v for k, v in loaded["games"].items()
                if str(k).isdigit() and isinstance(v, dict)
            }
    for game in data["games"].values():
        if not isinstance(game, dict):
            continue
        game["enabled"] = bool(game.get("enabled", False))
    return data


def sanitize_tweaks(data):
    # The proton wrapper reads this at game launch, so a bad key here breaks launching.
    if not isinstance(data, dict):
        raise ValueError("tweaks must be an object")
    if len(json.dumps(data)) > 256 * 1024:
        raise ValueError("tweaks payload too large")
    clean = {"global": {}, "games": {}}
    if isinstance(data.get("global"), dict):
        clean["global"] = data["global"]
    raw_games = data.get("games")
    if isinstance(raw_games, dict):
        for gid, game in raw_games.items():
            if str(gid).isdigit() and isinstance(game, dict):
                clean["games"][str(gid)] = game
    return clean


def refresh_running_game_modes(data):
    # Re-aplica los tweaks per-juego EN VIVO al juego en curso. pocknix-proton-wrapper solo
    # escribe /run/pocknix/game-mode al lanzar juegos que pasan por su compat-tool (conserva su
    # pid via execv); los demas (atajos que lanzan un script propio) jamas crean el fichero, asi
    # que este refresco detecta ademas el proceso del juego por su appid en /proc y escribe el
    # fichero con ESE pid, para que los daemons (fancontrol, lavd, pergame-power), que releen
    # cada ~3s, apliquen los ajustes del juego abierto sin relanzarlo.
    games = data.get("games")
    if not isinstance(games, dict):
        return
    candidates = [gid for gid, game in games.items()
                  if isinstance(game, dict) and game.get("enabled") is True]

    # Ruta rapida (preferida): el fichero existe, su pid (el wrapper) esta vivo y su appid es un
    # juego habilitado que sigue corriendo => ese pid existente es la referencia autoritativa.
    appid = None
    pid = None
    try:
        line = GAME_MODE_FILE.read_text(encoding="utf-8").strip()
    except OSError:
        line = None
    if line:
        fields = line.split()
        if fields and fields[0].isdigit():
            file_pid = int(fields[0])
            if (Path("/proc") / str(file_pid)).exists():
                file_appid = _appid_of_pid(file_pid)
                if file_appid in candidates and _pids_for_appid(file_appid):
                    appid, pid = file_appid, file_pid

    # Fallback: sin fichero (o con pid muerto/ajeno) se busca el juego habilitado con proceso
    # vivo escaneando /proc; si hay varios, gana el appid con el pid minimo (sesion mas antigua).
    if pid is None:
        best = None
        for gid in candidates:
            pids = _pids_for_appid(gid)
            if pids and (best is None or pids[0] < best[0]):
                best = (pids[0], gid)
        if best is None:
            # Ningun juego habilitado esta corriendo: sin juego del que aplicar, nada que crear.
            return
        pid, appid = best

    # Misma logica de merged settings que el wrapper: base = global (solo strings) y, si el
    # juego existe con "enabled": true, sus valores (solo strings) ganan al hacer update.
    merged = {}
    if isinstance(data.get("global"), dict):
        merged.update({k: v for k, v in data["global"].items() if isinstance(v, str)})
    game = games.get(appid)
    if isinstance(game, dict) and game.get("enabled") is True:
        merged.update({k: v for k, v in game.items() if isinstance(v, str)})

    # Valor vacio o fuera de la lista de modos conocidos => "-" (sin override para el campo).
    def _pick(value, allowed):
        return value.strip() if isinstance(value, str) and value.strip() in allowed else "-"

    fan = _pick(merged.get("fanMode"), FAN_MODES)
    lavd = _pick(merged.get("lavdMode"), LAVD_MODES)
    governor = _pick(merged.get("cpuGovernor"), CPU_GOVERNORS)
    profile = _pick(merged.get("powerProfile"), POWER_PROFILES)

    if fan == "-" and lavd == "-" and governor == "-" and profile == "-":
        # Sin ningun override equivale a "modo global": se borra el fichero para que los daemons
        # reviertan a su logica global, pero SOLO si el fichero actual pertenece al juego elegido
        # (mismo appid) o su pid ya murio; un override de OTRO juego vivo no se toca.
        try:
            cur = GAME_MODE_FILE.read_text(encoding="utf-8").strip()
        except OSError:
            return
        cur_fields = cur.split()
        if cur_fields and cur_fields[0].isdigit():
            cur_pid = int(cur_fields[0])
            cur_alive = (Path("/proc") / str(cur_pid)).exists()
            if not cur_alive or _appid_of_pid(cur_pid) == appid:
                try:
                    GAME_MODE_FILE.unlink(missing_ok=True)
                except OSError:
                    pass
        return
    # Mismo pid y mismo formato de UNA linea (5 campos, un espacio entre ellos) que el wrapper.
    atomically_write(GAME_MODE_FILE, f"{pid} {fan} {lavd} {governor} {profile}\n", 0o644)


def save_tweaks(data):
    atomically_write(TWEAKS_CONFIG, json.dumps(sanitize_tweaks(data), indent=2, sort_keys=True) + "\n", 0o644)
    # Refresco en vivo: si hay un juego corriendo, re-escribe su game-mode con los ajustes
    # recien guardados. Un fallo aqui (p.ej. /run/pocknix no escribible) jamas debe romper
    # el guardado del JSON de arriba.
    try:
        refresh_running_game_modes(data)
    except OSError:
        pass
