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


# "26.2.3" -> one entry per series ("26.2"); the wrapper resolves the point release per Proton
# flavor. Anything with a suffix ("26.3.0devel", "26.3.0-valve") is a one-off build and gets its
# OWN entry keyed by the full directory name, which the wrapper also accepts verbatim.
_SERIES_HEAD = re.compile(r"[0-9]+\.[0-9]+")
_PLAIN_VERSION = re.compile(r"[0-9]+(\.[0-9]+)*")


def _mesa_choice_key(choice):
    # Series first ("26.2" sorts before "26.3.0…"), then a standalone payload of the same
    # version sorts by name so the list order is stable between calls.
    nums = tuple(int(x) for x in re.findall(r"[0-9]+", choice["data"]))
    return (nums, len(nums), choice["data"])


def mesa_versions():
    # x86 SLR captures graphics from the FEX rootfs, so an x86 payload that is not embedded in
    # the image would be a pin the wrapper refuses at launch.
    try:
        embedded = set(CONTAINER_VK_LIST.read_text().split())
    except OSError:
        embedded = set()
    series, standalone = {}, {}
    for arch, base in TURNIP_DIRS.items():
        try:
            versions = [p.name for p in base.iterdir() if (p / "icd.json").is_file()]
        except OSError:
            continue
        for v in versions:
            if arch == "x86" and v not in embedded:
                continue
            if not _SERIES_HEAD.match(v):
                continue
            if _PLAIN_VERSION.fullmatch(v):
                # Clean X.Y[.Z]: several point releases of one series are one option, and the
                # wrapper picks the highest one installed.
                key, bucket = ".".join(v.split(".")[:2]), series
            else:
                # Suffixed build (Valve Mesa, a devel snapshot, …): listing it inside the
                # series would make the wrapper's "highest numbers wins" tie-break pick between
                # "26.3.0devel" and "26.3.0-valve" arbitrarily, so it gets its own entry.
                key, bucket = v, standalone
            entry = bucket.setdefault(key, {"archs": set(), "rc": True, "devel": True})
            entry["archs"].add(arch)
            entry["rc"] = entry["rc"] and "rc" in v
            entry["devel"] = entry["devel"] and "devel" in v
    choices = []
    for bucket in (series, standalone):
        for key, entry in bucket.items():
            # "git" marks an unreleased main snapshot, so a devel payload can't read as a
            # shipped release (the series key alone would show a bare "26.3").
            label = key + (" RC" if entry["rc"] else "") + (" git" if entry["devel"] else "")
            if entry["archs"] != {"arm", "x86"}:
                label += f" ({'ARM' if 'arm' in entry['archs'] else 'x86'} only)"
            choices.append({"data": key, "label": label})
    return sorted(choices, key=_mesa_choice_key)


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


def save_tweaks(data):
    atomically_write(TWEAKS_CONFIG, json.dumps(sanitize_tweaks(data), indent=2, sort_keys=True) + "\n", 0o644)
