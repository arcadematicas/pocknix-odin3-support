#!/usr/bin/env python3
# -*- coding: utf-8 -*-

import os, sys, subprocess, requests, threading, traceback, shutil, re, platform
from os.path import dirname, abspath, join, exists

DIR = dirname(abspath(__file__))
sys.path.insert(0, os.path.join(DIR, 'libs'))
py_ver = f"py{sys.version_info.major}.{sys.version_info.minor}"
local_libs = os.path.join(DIR, 'libs', f'libs_{py_ver}')
if os.path.exists(local_libs):
    sys.path.insert(0, local_libs)

import pygame, io, time, json
from pygame.locals import *


pygame.init()
pygame.joystick.init()
SCREEN_WIDTH, SCREEN_HEIGHT = 1280, 800
screen = pygame.display.set_mode((SCREEN_WIDTH, SCREEN_HEIGHT))
try:
    pygame.display.set_caption("Centro de Mando DeckStation v11.3 - Clean Sweeper")
except pygame.error:
    pass
clock = pygame.time.Clock()

# Temas visuales: los mismos de WProton (clasico | moderno | arcade).
# Se elige con la variable de entorno UPDATER_THEME o en settings.conf (THEME=).
# Para añadir uno nuevo basta con copiar un bloque y cambiar los colores:
# el resto del dibujado se adapta solo. En 'ok'/'error' se mapea el verde de
# éxito y el rojo de error de cada paleta (si no se definen, caen a acc/warn).
THEMES = {
    'clasico': {
        'bg': (24, 26, 32), 'bg2': (24, 26, 32),
        'fg': (225, 228, 235), 'dim': (140, 145, 155),
        'sel_bg': (38, 92, 170), 'sel_fg': (255, 255, 255),
        'acc': (120, 200, 130), 'dir': (150, 190, 240),
        'warn': (230, 180, 90), 'kb_bg': (34, 37, 46),
        'panel': None, 'border': (60, 64, 74), 'card': (44, 48, 60),
        'radius': 6, 'pill': False, 'rule': True, 'glow': False,
        'layout': 'simple', 'row': 40,
        'ok': (120, 200, 130), 'error': (210, 80, 70),
    },
    'moderno': {
        'bg': (14, 17, 26), 'bg2': (24, 30, 46),
        'fg': (232, 240, 252), 'dim': (128, 142, 168),
        'sel_bg': (26, 60, 82), 'sel_fg': (150, 240, 255),
        'acc': (56, 214, 224), 'dir': (124, 200, 255),
        'warn': (250, 196, 106), 'kb_bg': (20, 26, 40),
        'panel': (22, 28, 42), 'border': (44, 60, 88), 'card': (26, 33, 50),
        'radius': 12, 'pill': True, 'rule': False, 'glow': True,
        'layout': 'panel', 'row': 48,
        'acc2': (168, 120, 255), 'ok': (86, 226, 160),
        'btn': True, 'labelcolor': True, 'shape': 'notch',
        'error': (255, 90, 110),
    },
    'arcade': {
        'bg': (12, 4, 30), 'bg2': (58, 12, 74),
        'fg': (255, 244, 252), 'dim': (170, 130, 200),
        'sel_bg': (92, 12, 96), 'sel_fg': (255, 255, 255),
        'acc': (255, 46, 147), 'dir': (94, 234, 255),
        'warn': (255, 214, 84), 'kb_bg': (24, 8, 44),
        'panel': (26, 8, 48), 'border': (120, 40, 140), 'card': (36, 12, 60),
        'radius': 0, 'pill': True, 'rule': False, 'glow': True,
        'layout': 'arcade', 'row': 48,
        'acc2': (94, 234, 255), 'ok': (120, 255, 170),
        'scan': True, 'gridbg': True, 'brackets': True,
        'marker': True, 'numbered': True, 'shadow': True,
        'btn': True, 'labelcolor': True, 'shape': 'rect',
        'error': (255, 60, 110),
    },
}


def _load_theme_name():
    """Elige el tema: UPDATER_THEME (env) > settings.conf (THEME=) > 'moderno'."""
    name = os.environ.get('UPDATER_THEME')
    if not name:
        conf = join(DIR, 'settings.conf')
        if exists(conf):
            try:
                with open(conf, 'r', encoding='utf-8') as f:
                    for line in f:
                        m = re.match(r'^\s*THEME="?([A-Za-z0-9_-]+)"?\s*$', line)
                        if m:
                            name = m.group(1)
                            break
            except Exception:
                name = None
    if not name or name not in THEMES:
        name = 'moderno'
    return name


def _apply_theme(name):
    """Aplica un tema al instante (colores y radios globales)."""
    global ACTIVE_THEME, TH, BG_COLOR, HUB_BG, PANEL_COLOR, TEXT_COLOR
    global ACCENT_COLOR, SEL_FG_COLOR, DIM_COLOR, GREEN_COLOR, ERROR_COLOR, RADIUS
    ACTIVE_THEME = name
    TH = THEMES[name]
    BG_COLOR = TH['bg']
    HUB_BG = TH['bg2']
    PANEL_COLOR = TH['panel'] if TH['panel'] else TH['card']
    TEXT_COLOR = TH['fg']
    ACCENT_COLOR = TH['acc']
    SEL_FG_COLOR = TH['sel_fg']
    DIM_COLOR = TH['dim']
    GREEN_COLOR = TH.get('ok', TH['acc'])
    ERROR_COLOR = TH.get('error', TH['warn'])
    RADIUS = TH['radius']


def _save_theme_conf(name):
    """Guarda el tema en settings.conf con el mismo formato que WProton."""
    conf = join(DIR, 'settings.conf')
    if exists(conf):
        try:
            with open(conf, 'r', encoding='utf-8') as f:
                lines = f.readlines()
            out = []
            for line in lines:
                m = re.match(r'^(\s*THEME="?)[^"]*("?\s*)$', line)
                if m:
                    out.append(f'{m.group(1)}{name}{m.group(2)}\n')
                else:
                    out.append(line)
            with open(conf, 'w', encoding='utf-8') as f:
                f.writelines(out)
            return
        except Exception:
            pass
    try:
        with open(conf, 'w', encoding='utf-8') as f:
            f.write('# ============================================\n')
            f.write('# Ajustes del actualizador DeckStation (editable a mano)\n')
            f.write('# ============================================\n')
            f.write('# Aspecto de la interfaz: clasico | moderno | arcade\n')
            f.write('# (los mismos temas de WProton)\n')
            f.write(f'THEME="{name}"\n')
    except Exception:
        pass


ACTIVE_THEME = _load_theme_name()
_apply_theme(ACTIVE_THEME)

# Icons
ICONS_DIR = os.path.join(DIR, 'icons')
_icon_cache = {}
EMULATOR_ICON_MAP = {}
_ICON_FILENAME_OVERRIDE = {}

def _load_icon_map():
    """Carga el mapeo de emuladores a iconos desde icons/map.json.
    Si falla, retorna diccionarios vacios y el sistema seguira funcionando
    con nombres genericos."""
    global EMULATOR_ICON_MAP, _ICON_FILENAME_OVERRIDE
    map_path = os.path.join(ICONS_DIR, 'map.json')
    if not os.path.exists(map_path):
        print(f"[Updater] Aviso: no se encuentra {map_path}, usando mapeo vacio")
        EMULATOR_ICON_MAP = {}
        _ICON_FILENAME_OVERRIDE = {}
        return
    try:
        with open(map_path, 'r', encoding='utf-8') as f:
            data = json.load(f)
        EMULATOR_ICON_MAP = data.get('icon_map', {})
        _ICON_FILENAME_OVERRIDE = data.get('filename_override', {})
        print(f"[Updater] Cargados {len(EMULATOR_ICON_MAP)} iconos + {len(_ICON_FILENAME_OVERRIDE)} overrides desde map.json")
    except Exception as e:
        print(f"[Updater] Error al cargar map.json: {e}")
        EMULATOR_ICON_MAP = {}
        _ICON_FILENAME_OVERRIDE = {}

def _load_png(path, size):
    try:
        img = pygame.image.load(path).convert_alpha()
        return pygame.transform.smoothscale(img, size)
    except Exception:
        return None

def load_icon(name, size=64):
    key = (name, size)
    if key in _icon_cache:
        return _icon_cache[key]
    icon_name = EMULATOR_ICON_MAP.get(name.lower(), name)
    filename_override = _ICON_FILENAME_OVERRIDE.get(icon_name)
    if filename_override:
        img_path = os.path.join(ICONS_DIR, filename_override)
    else:
        img_path = os.path.join(ICONS_DIR, f"{icon_name}.png")
    img = _load_png(img_path, (size, size))
    if img is None:
        img = _load_png(os.path.join(ICONS_DIR, "default.png"), (size, size))
    if img is None:
        img = pygame.Surface((size, size), pygame.SRCALPHA)
    _icon_cache[key] = img
    return img

def load_hub_icon(filename, size=128):
    key = ('hub', filename, size)
    if key in _icon_cache:
        return _icon_cache[key]
    img_path = os.path.join(ICONS_DIR, f"hub_{filename}")
    img = _load_png(img_path, (size, size))
    if img is None:
        img = _load_png(os.path.join(ICONS_DIR, "hub_default.png"), (size, size))
    if img is None:
        img = pygame.Surface((size, size), pygame.SRCALPHA)
    _icon_cache[key] = img
    return img

# Font
FONT_PATH = "/usr/share/fonts/TTF/DejaVuSans.ttf"
try:
    if os.path.exists(FONT_PATH):
        font = pygame.font.Font(FONT_PATH, 28)
        font_title = pygame.font.Font(FONT_PATH, 44)
        font_small = pygame.font.Font(FONT_PATH, 22)
    else:
        raise FileNotFoundError
except Exception:
    font = pygame.font.SysFont("trebuchetms, arial, sans-serif", 28)
    font_title = pygame.font.SysFont("trebuchetms, arial, sans-serif", 44, bold=True)
    font_small = pygame.font.SysFont("trebuchetms, arial, sans-serif", 22)

# Paths
APPS_DIR = os.path.normpath(os.path.join(DIR, '..'))
DECKSTATION_ROOT = os.path.normpath(os.path.join(DIR, '../..'))
TOKEN_FILE = os.path.join(DIR, 'github_token.txt')
CACHE_DIR = os.path.join(DIR, 'cache')
CACHE_TTL = 1800
GITHUB_ORG = 'pkgforge-dev'

# ── Arquitectura del host ────────────────────────────────────────────────────
# El updater debe bajar binarios de SU PROPIA arquitectura. En la AYN Odin 3
# (aarch64) los assets x86_64 NO arrancan, y viceversa. Deteccion en runtime
# para que el mismo codigo sirva en la Odin (aarch64) y en PC/Steam Deck (x86_64).
_MACHINE = platform.machine().lower()
IS_AARCH64 = _MACHINE in ('aarch64', 'arm64', 'armv8', 'armv8l')
# Etiquetas que identifican nuestra arquitectura / la contraria en el nombre del asset
ARCH_OK   = ('aarch64', 'arm64', 'armv8') if IS_AARCH64 else ('x86_64', 'amd64', 'x64')
ARCH_BAD  = ('x86_64', 'amd64', 'x64')    if IS_AARCH64 else ('aarch64', 'arm64', 'armv8')
# Etiquetas de sistemas que NO son Linux (un .zip de macOS no nos vale)
OS_BAD    = ('macos', 'darwin', 'osx', 'windows', 'win64', 'win32', '.exe', '.dmg', 'android', 'ios')

# ── Auto-actualización de DeckStation (payload de MediaFire) ──────────────────
# DESACTIVADA EN ARM. El auto-actualizador de DeckStation descarga un payload/
# de una carpeta de MediaFire y lo aplica ENCIMA de la instalación. Esa carpeta
# (MF_FOLDER_KEY) es la del proyecto **x86_64**: su payload trae AppImages y
# .AppImage.home de x86_64, así que aplicarlo en un dispositivo ARM **pisaría los
# emuladores ARM con binarios x86_64**, que no arrancan.
#
# Para volver a activarlo hace falta una carpeta de MediaFire con payload ARM:
# poner su clave en MF_FOLDER_KEY y SYSTEM_UPDATE_ENABLED = True. Mientras tanto
# la opción "Actualizar DeckStation" no se muestra en el menú.
MF_FOLDER_KEY = "1ixylxeqkr0wo"
SYSTEM_UPDATE_ENABLED = False

# Fallback repos (used only if git.txt is missing)
EXTERNAL_REPOS_FALLBACK = {
    'rpcs3': ('github', 'RPCS3/rpcs3-binaries-linux'),
    'duckstation': ('github', 'stenzek/duckstation'),
    'citron': ('github', 'citron-neo/CI'),
    'ppsspp': ('github', 'hrydgard/ppsspp'),
    'hypseus singe': ('github', 'DirtBagXon/hypseus-singe'),
    'hypseus': ('github', 'DirtBagXon/hypseus-singe'),
    'shadps4': ('github', 'shadps4-emu/shadps4-qtlauncher'),
    'eden': ('gitea', 'https://git.eden-emu.dev/api/v1/repos/eden-emu/eden/releases'),
    'retroarch': ('static', 'https://buildbot.libretro.com/nightly/linux/%s/RetroArch.7z'
                  % ('aarch64' if IS_AARCH64 else 'x86_64')),
}

GIT_TXT_PATH = os.path.join(DIR, 'git.txt')

def _load_git_txt():
    """Lee git.txt y lo convierte al mismo formato que EXTERNAL_REPOS.
    Las entradas de git.txt tienen prioridad sobre el fallback hardcodeado."""
    repos = dict(EXTERNAL_REPOS_FALLBACK)
    if not os.path.exists(GIT_TXT_PATH):
        return repos
    try:
        with open(GIT_TXT_PATH, 'r', encoding='utf-8') as f:
            # Se ignoran lineas vacias Y comentarios (# ...). Asi el git.txt puede
            # llevar secciones comentadas con emuladores desactivados sin romper
            # el emparejamiento nombre/URL.
            lines = [line.strip() for line in f.readlines()
                     if line.strip() and not line.strip().startswith('#')]
        it = iter(lines)
        for name, url in zip(it, it):
            name_lower = name.lower().replace(' ', '_').replace('-', '_')
            if 'github.com' in url:
                # Extraer solo owner/repo, descartando /releases, /releases/tag/xxx, /tag/xxx
                path = url.replace('https://github.com/', '')
                if '/releases/tag/' in path:
                    repo_path = path[:path.index('/releases/tag/')]
                elif '/releases' in path:
                    repo_path = path[:path.index('/releases')]
                elif '/tag/' in path:
                    repo_path = path[:path.index('/tag/')]
                else:
                    repo_path = path
                repo_path = repo_path.rstrip('/')
                repos[name_lower] = ('github', repo_path)
            elif 'git.eden-emu.dev' in url or 'git.ryujinx.app' in url:
                # Gitea API: si ya es API, usarla; si no, convertir web → API
                if '/api/v1/' in url:
                    api_url = url.rstrip('/')
                else:
                    # Web: https://git.DOMAIN/OWNER/REPO/releases
                    # API: https://git.DOMAIN/api/v1/repos/OWNER/REPO/releases
                    parts = url.replace('https://', '').split('/', 2)
                    if len(parts) >= 3:
                        domain = parts[0]
                        repo_path = parts[2].replace('/releases', '').rstrip('/')
                        # parts[1] es el owner, el resto (parts[2]) es el repo + /releases
                        owner = parts[1]
                        repo = repo_path.split('/')[0]
                        api_url = f'https://{domain}/api/v1/repos/{owner}/{repo}/releases'
                    else:
                        api_url = url
                repos[name_lower] = ('gitea', api_url)
            elif 'gitlab.com' in url:
                # Convertir web URL a API de GitLab
                if '/api/v4/' in url:
                    api_url = url.rstrip('/')
                else:
                    # Web URL: https://gitlab.com/owner/repo/-/releases
                    path = url.replace('https://gitlab.com/', '').split('/-/')[0]
                    import urllib.parse
                    encoded = urllib.parse.quote(path, safe='')
                    api_url = f'https://gitlab.com/api/v4/projects/{encoded}/releases'
                repos[name_lower] = ('gitlab', api_url)
            else:
                # URL directa (no es un repo con releases): descarga fija.
                # Ej: el buildbot de RetroArch -> .../nightly/linux/aarch64/RetroArch.7z
                repos[name_lower] = ('static', url)
        print(f"[Updater] Cargadas {len(lines)//2} entradas desde git.txt")
    except Exception as e:
        print(f"[Updater] Error al leer git.txt: {e}")
    return repos

EXTERNAL_REPOS = _load_git_txt()

# --- Temas para el menú de apariencia ---
THEME_ENTRIES = [
    ("clasico", "Clásico", "Sobrio, paneles planos y acento verde"),
    ("moderno", "Moderno", "Paneles con acento neón cian (por defecto)"),
    ("arcade", "Arcade", "Synthwave: rejilla, neón rosa y escaneo CRT"),
]


_load_icon_map()
def get_count(joystick_idx):
    try:
        js = pygame.joystick.Joystick(joystick_idx)
        js.init()
        return 1
    except pygame.error:
        return 0

# Detect gamepad
Joystick = None
for i in range(pygame.joystick.get_count()):
    try:
        js = pygame.joystick.Joystick(i)
        js.init()
        Joystick = js
        break
    except pygame.error:
        continue


class UpdaterEngine:
    def __init__(self):
        self.token = self.load_token()
        self.headers = {"Authorization": f"Bearer {self.token}"} if self.token else {}
        self.apps = self.scan_apps()

        self.state = "HUB"
        self.hub_idx = 0
        self.theme_idx = 0

        self.current_app_idx = 0
        self.available_tags = []
        self.selected_tag_idx = 0
        self.status_msg = ""
        self.download_progress = 0.0
        self.download_error = False
        self.cancel_requested = False
        self.download_speed = "0.0 MB/s"
        self.max_visible = 7
        self.top_visible_idx = 0
        self.fetching = False
        self._fetch_result = None

        # Fetch asíncrono de versión (no bloquear UI)
        self._fetch_loading = False
        self._latest_version_result = None
        self._fetch_app_idx = 0

        # Notificación de actualización de DeckStation
        self._system_update_available = False
        self._system_update_checked = False

        # Escáner de actualizaciones en segundo plano
        self._updates_checked = False
        self._update_scan_active = False

        self.changelog_lines = []
        self.changelog_scroll = 0

        self.mf_folder_key = MF_FOLDER_KEY
        self.update_dir = os.path.join(DECKSTATION_ROOT, "update")
        self.installed_dir = os.path.join(self.update_dir, ".installed")
        os.makedirs(self.update_dir, exist_ok=True)
        os.makedirs(self.installed_dir, exist_ok=True)

        # Limpiar archivos temporales de ejecuciones anteriores
        temp_patterns = ["temp_update.archive", "temp_update.AppImage", "temp_extract_archive"]
        for app in self.apps:
            for pattern in temp_patterns:
                path = os.path.join(app["path"], pattern)
                if os.path.exists(path):
                    if os.path.isfile(path):
                        os.remove(path)
                    elif os.path.isdir(path):
                        shutil.rmtree(path)

    def load_token(self):
        if os.path.exists(TOKEN_FILE):
            with open(TOKEN_FILE, 'r') as f:
                return f.read().strip()
        return None

    def _cache_get(self, key):
        cache_path = os.path.join(CACHE_DIR, f"{key}.json")
        if not os.path.exists(cache_path):
            return None
        try:
            with open(cache_path, 'r') as f:
                data = json.load(f)
            cached_at = data.get("_cached_at", 0)
            if time.time() - cached_at < CACHE_TTL:
                return data.get("_data")
        except Exception:
            pass
        return None

    def _cache_set(self, key, data):
        os.makedirs(CACHE_DIR, exist_ok=True)
        cache_path = os.path.join(CACHE_DIR, f"{key}.json")
        try:
            with open(cache_path, 'w') as f:
                json.dump({"_cached_at": time.time(), "_data": data}, f)
        except Exception:
            pass

    def _start_update_scan(self):
        if self._update_scan_active or self._updates_checked:
            return
        self._update_scan_active = True
        t = threading.Thread(target=self._update_scan_worker, daemon=True)
        t.start()

    def _update_scan_worker(self):
        for app in self.apps:
            try:
                result = self.fetch_github_releases(app["name"])
                if result:
                    tags = [r for r in result if r.get("name") != "Nightly Oficial (.7z)"]
                    if tags:
                        latest = tags[0]["version"].lstrip("v")
                        if latest != app["version"].lstrip("v"):
                            app["has_update"] = True
                            app["latest_version"] = latest
                time.sleep(0.5)
            except Exception:
                continue
        self._updates_checked = True
        self._update_scan_active = False

    def _start_fetch_latest(self, app_idx):
        """Fetch la última versión de un emulador en segundo plano (sin bloquear UI)."""
        self._fetch_loading = True
        self._latest_version_result = None
        self._fetch_app_idx = app_idx
        self.status_msg = "Buscando última versión..."
        t = threading.Thread(target=self._fetch_latest_worker, args=(app_idx,), daemon=True)
        t.start()

    def _fetch_latest_worker(self, app_idx):
        """Worker que obtiene las releases y guarda el resultado."""
        app = self.apps[app_idx]
        try:
            result = self.fetch_github_releases(app["name"])
            # Solo guardar si sigue siendo la misma selección (evita race conditions)
            if self._fetch_app_idx == app_idx:
                self._latest_version_result = result
        except Exception:
            if self._fetch_app_idx == app_idx:
                self._latest_version_result = None
        self._fetch_loading = False

    def _check_system_update(self):
        """Verifica en segundo plano si hay actualización de DeckStation disponible.

        Desactivado en ARM: el payload de MediaFire es de x86_64 y pisaría los
        emuladores ARM. Ver SYSTEM_UPDATE_ENABLED."""
        if not SYSTEM_UPDATE_ENABLED:
            return
        if self._system_update_checked:
            return
        self._system_update_checked = True
        t = threading.Thread(target=self._system_update_check_worker, daemon=True)
        t.start()

    def _system_update_check_worker(self):
        """Worker que consulta MediaFire y compara con lo instalado."""
        try:
            url = f"https://www.mediafire.com/api/1.5/folder/get_content.php?folder_key={self.mf_folder_key}&content_type=files&response_format=json"
            res = requests.get(url, timeout=15)
            if res.status_code != 200:
                return
            data = res.json()
            if data.get("response", {}).get("result") != "Success":
                return
            files = data["response"]["folder_content"]["files"]
            for fdata in files:
                filename = fdata["filename"]
                if not filename.endswith(".tar.gz"):
                    continue
                installed_flag = os.path.join(self.installed_dir, filename)
                if not os.path.exists(installed_flag):
                    self._system_update_available = True
                    return
        except Exception:
            pass

    def scan_apps(self):
        apps = []
        if not os.path.exists(APPS_DIR):
            return apps
        for name in sorted(os.listdir(APPS_DIR)):
            app_path = os.path.join(APPS_DIR, name)
            if name == "Updater" or not os.path.isdir(app_path):
                continue
            # Look for AppImage
            files = os.listdir(app_path)
            appimage = None
            for fname in files:
                if fname.lower().endswith(".appimage"):
                    appimage = fname
                    break
            if not appimage:
                continue
            # Read version if cached
            version_file = os.path.join(app_path, ".version")
            version = "Desconocida (Caché vacía)"
            if os.path.exists(version_file):
                with open(version_file, 'r') as f:
                    v = f.read().strip()
                    if v:
                        version = v
            apps.append({
                "name": name,
                "path": app_path,
                "file": appimage,
                "filename": appimage,
                "version": version,
                "has_update": False,
                "latest_version": "",
            })
        return apps

    def fetch_github_releases(self, app_name):
        cached = self._cache_get(f"releases_{app_name}")
        if cached is not None:
            return cached

        app_lower = app_name.lower().replace(" ", "_").replace("-", "_")
        # Intentar múltiples variaciones para encontrar el repo en pkgforge-dev
        raw_lower = app_name.lower()
        base_us = raw_lower.replace(" ", "").replace("-", "_")       # underscores, sin espacios
        base_hyphen = raw_lower.replace(" ", "-").replace("_", "-")  # guiones, espacios como guiones
        base_nospace = raw_lower.replace(" ", "").replace("-", "")   # todo pegado
        combinations = list(dict.fromkeys([
            base_us,
            base_hyphen,
            base_nospace,
            f"{base_us}-appimage", f"{base_hyphen}-appimage",
            f"{base_us}-appimage-enhanced", f"{base_hyphen}-appimage-enhanced",
            f"{base_us}-enhanced", f"{base_hyphen}-enhanced",
        ]))  # deduplicado preservando orden

        is_external = False
        for key, repo_data in EXTERNAL_REPOS.items():
            key_normalized = key.lower().replace(" ", "_").replace("-", "_")
            if key_normalized == app_lower or key_normalized == app_lower.replace("_", ""):
                is_external = True
                repo_type, repo_path = repo_data
                break

        if is_external:
            if repo_type == "static":
                result = [{"version": "static", "name": "Nightly Oficial (.7z)", "date": ""}]
                self._cache_set(f"releases_{app_name}", result)
                return result

            req_headers = dict(self.headers) if self.headers else {}
            if repo_type == "github":
                url = f"https://api.github.com/repos/{repo_path}/releases"
            elif repo_type == "gitlab":
                url = repo_path
                # GitLab no necesita token de GitHub
                req_headers.pop("Authorization", None)
            else:  # gitea
                url = repo_path
                # Gitea no entiende el token de GitHub, lo limpiamos
                req_headers.pop("Authorization", None)

            try:
                response = requests.get(url, headers=req_headers, timeout=15)
                if response.status_code == 200:
                    releases = response.json()
                    result = []
                    for rel in releases:
                        tag = rel.get("tag_name", "")
                        if repo_type == "github":
                            # Get asset info
                            assets = rel.get("assets", [])
                            if assets:
                                name = assets[0].get("name", tag)
                            else:
                                name = tag
                            date_str = rel.get("published_at", "")[:10]
                        elif repo_type == "gitlab":
                            # GitLab: assets bajo assets.links
                            links = rel.get("assets", {}).get("links", [])
                            if links:
                                name = links[0].get("name", tag)
                            else:
                                name = tag
                            date_str = rel.get("released_at", "")[:10]
                        else:  # gitea
                            name = tag
                            date_str = ""
                        result.append({"version": tag, "name": name, "date": date_str})
                    self._cache_set(f"releases_{app_name}", result)
                    return result
                elif response.status_code == 403:
                    reset_ts = int(response.headers.get("X-RateLimit-Reset", 0))
                    wait = max(0, reset_ts - int(time.time()))
                    print(f"Rate limit GitHub. Espera {wait}s o pon token en github_token.txt")
                    return None
                elif response.status_code == 401:
                    print(f"HTTP 401: Token no válido para {url}")
                    return None
                else:
                    print(f"HTTP {response.status_code} en {app_name}")
                    return None
            except requests.exceptions.Timeout:
                print("Timeout: sin conexion")
                return None
            except Exception as e:
                print(f"HTTP {e} en {app_name}")
                return None

        # Not in EXTERNAL_REPOS: try pkgforge-dev org
        req_headers = dict(self.headers) if self.headers else {}
        tags = []
        for combo in combinations:
            url = f"https://api.github.com/repos/{GITHUB_ORG}/{combo}/releases"
            try:
                response = requests.get(url, headers=req_headers, timeout=15)
                if response.status_code == 200:
                    tags = response.json()
                    break
            except Exception:
                continue

        if not tags:
            return None

        result = []
        for rel in tags:
            tag = rel.get("tag_name", "")
            assets = rel.get("assets", [])
            if assets:
                name = assets[0].get("name", tag)
            else:
                name = tag
            date_str = rel.get("published_at", "")[:10]
            result.append({"version": tag, "name": name, "date": date_str})
        self._cache_set(f"releases_{app_name}", result)
        return result

    def start_download(self, app, repo_info, tag):
        self.state = "DOWNLOADING"
        self.status_msg = f"Preparando descarga de {app['name']}..."
        self.download_progress = 0.0
        self.download_error = False
        self.cancel_requested = False
        self.download_speed = "0.0 MB/s"
        t = threading.Thread(target=self._download_worker, args=(app, repo_info, tag), daemon=True)
        t.start()

    def _download_worker(self, app, repo_info, tag):
        repo_type, repo_path = repo_info
        req_headers = dict(self.headers) if self.headers else {}

        if repo_type == "static":
            url = repo_path
        elif repo_type == "github":
            url = f"https://api.github.com/repos/{repo_path}/releases/tags/{tag}"
        else:  # gitea
            url = repo_path

        if repo_type != "static":
            try:
                res = requests.get(url, headers=req_headers, timeout=15)
                if res.status_code != 200:
                    self.state = "EMU_MENU"
                    self.status_msg = f"Error HTTP {res.status_code} al consultar release"
                    return
                data = res.json()
                # Find asset
                best_url = None
                best_score = -1
                fallback_url = None
                for asset in data.get("assets", []):
                    asset_name = asset.get("name", "")
                    score = 0
                    is_archive = False
                    if asset_name.lower().endswith(".appimage"):
                        score += 10
                    elif asset_name.lower().endswith((".7z", ".zip", ".tar.gz", ".tar.xz")):
                        score += 8
                        is_archive = True
                    else:
                        continue

                    # ── Arquitectura ─────────────────────────────────────
                    # ANTES esto premiaba x86_64 (+5). En la Odin (aarch64) eso
                    # bajaba el binario equivocado, que no arranca. Ahora se premia
                    # NUESTRA arquitectura y se DESCARTA la contraria.
                    al = asset_name.lower()
                    if any(t in al for t in ARCH_OK):
                        score += 6
                    elif any(t in al for t in ARCH_BAD):
                        continue          # binario de la otra arquitectura: fuera
                    # ── Sistema operativo ────────────────────────────────
                    if any(t in al for t in OS_BAD):
                        continue          # macOS/Windows/Android: fuera
                    if "linux" in al or "anylinux" in al:
                        score += 3
                    if "qt" in al:
                        score += 2
                    if "enhanced" in al:
                        score += 1

                    if score > best_score:
                        best_score = score
                        best_url = asset.get("browser_download_url")
                        if is_archive:
                            fallback_url = best_url
                    elif fallback_url is None and is_archive:
                        fallback_url = asset.get("browser_download_url")

                if best_score < 8 and fallback_url:
                    best_url = fallback_url

                if best_url is None:
                    self.state = "EMU_MENU"
                    self.status_msg = "Error: No se encontró AppImage ni comprimido válido para Linux."
                    return
            except Exception as e:
                self.state = "EMU_MENU"
                self.status_msg = f"Error al obtener release: {e}"
                return
        else:
            best_url = url

        temp_file = os.path.join(app["path"], "temp_update.archive")
        appimage_path = os.path.join(app["path"], app["file"])
        is_archive_url = any(best_url.lower().endswith(ext) for ext in [".7z", ".zip", ".tar.gz", ".tar.xz"])

        # Disk space check
        try:
            disk_usage = shutil.disk_usage(app["path"])
            free_bytes = disk_usage.free
            estimated = 500 * 1024 * 1024  # ~500 MB minimum
            if free_bytes < estimated:
                free_mb = free_bytes / (1024 * 1024)
                self.state = "EMU_MENU"
                self.cancel_requested = True
                self.status_msg = f"❌ Espacio insuficiente: {free_mb:.0f}MB libres (mínimo ~500MB)"
                self._cleanup_temp(app, temp_file)
                return
        except Exception:
            pass

        # Download with retry and resume
        max_retries = 3
        last_error = None
        downloaded = 0
        total_length = 0
        write_mode = "wb"

        for attempt in range(1, max_retries + 1):
            if self.cancel_requested:
                self.state = "EMU_MENU"
                self.status_msg = "Descarga cancelada."
                self._cleanup_temp(app, temp_file)
                return

            try:
                request_headers = dict(req_headers)
                if attempt > 1 and downloaded > 0:
                    request_headers["Range"] = f"bytes={downloaded}-"
                    write_mode = "ab"
                else:
                    write_mode = "wb"

                with requests.get(best_url, headers=request_headers, stream=True, timeout=(10, 30)) as r:
                    if attempt > 1 and downloaded > 0:
                        if r.status_code == 206:
                            write_mode = "ab"
                        else:
                            write_mode = "wb"
                            downloaded = 0
                    else:
                        if r.status_code != 200:
                            self.state = "EMU_MENU"
                            self.status_msg = f"Error HTTP {r.status_code}"
                            return

                    r.raise_for_status()
                    total_length = int(r.headers.get("content-length", 0))
                    if total_length == 0:
                        total_length = None

                    downloaded_local = 0
                    chunk_count_unknown = 0
                    start_time = time.time()

                    self.status_msg = f"Descargando (intento {attempt}/{max_retries})..."
                    if total_length:
                        self.download_progress = downloaded / total_length if total_length else 0

                    with open(temp_file, write_mode) as f:
                        for chunk in r.iter_content(chunk_size=8192):
                            if self.cancel_requested:
                                self.state = "EMU_MENU"
                                self.status_msg = "Descarga cancelada."
                                self._cleanup_temp(app, temp_file)
                                return
                            if chunk:
                                f.write(chunk)
                                downloaded_local += len(chunk)
                                downloaded += len(chunk)
                                if total_length:
                                    self.download_progress = downloaded / total_length
                                elapsed = time.time() - start_time
                                if elapsed > 0:
                                    speed_bps = downloaded_local / elapsed
                                    if speed_bps > 1024 * 1024:
                                        self.download_speed = f"{speed_bps / (1024*1024):.1f} MB/s"
                                    else:
                                        self.download_speed = f"{speed_bps / 1024:.1f} KB/s"
                                chunk_count_unknown += 1

                            if total_length:
                                self.status_msg = f"Descargando: {int(self.download_progress * 100)}%  ({self.download_speed})"
                            else:
                                self.status_msg = f"Descargando... ({self.download_speed})"

                    self.status_msg = "completado"
                    break  # success

            except (requests.exceptions.ConnectionError,
                    requests.exceptions.Timeout,
                    requests.exceptions.ChunkedEncodingError) as e:
                last_error = str(e)
                self.status_msg = f"Error en intento {attempt}: reconnecting..."
                if attempt < max_retries:
                    time.sleep(2 * attempt)
                continue
            except Exception as e:
                self.state = "EMU_MENU"
                self.status_msg = f"❌ Error crítico: {e}"
                self._cleanup_temp(app, temp_file)
                return

        else:
            # All retries failed
            self.state = "EMU_MENU"
            self.status_msg = f"❌ Descarga fallida tras {max_retries} intentos: {last_error}"
            self._cleanup_temp(app, temp_file)
            return

        # Backup existing AppImage
        backup_path = appimage_path + ".bak"
        if os.path.exists(appimage_path):
            try:
                if os.path.exists(backup_path):
                    os.remove(backup_path)
                os.rename(appimage_path, backup_path)
            except Exception:
                pass

        try:
            if is_archive_url:
                self.status_msg = "Descomprimiendo archivo (Puede tardar un poco)..."
                temp_extract_dir = os.path.join(app["path"], "temp_extract_archive")

                # Extract
                extract_cmd = ["7z", "x", temp_file, "-y", f"-o{temp_extract_dir}"]
                try:
                    subprocess.run(extract_cmd, check=True, capture_output=True, timeout=120)
                except FileNotFoundError:
                    self.state = "EMU_MENU"
                    self.status_msg = "❌ '7z' no instalado. Ejecuta: sudo pacman -S p7zip"
                    self._cleanup_temp(app, temp_file)
                    if os.path.exists(backup_path):
                        shutil.move(backup_path, appimage_path)
                    return
                except subprocess.CalledProcessError:
                    self.state = "EMU_MENU"
                    self.status_msg = "❌ Error al descomprimir. El archivo puede estar corrupto."
                    self._cleanup_temp(app, temp_file)
                    if os.path.exists(backup_path):
                        shutil.move(backup_path, appimage_path)
                    return

                # Find extracted AppImage
                extracted_appimage = None
                for root, dirs, files in os.walk(temp_extract_dir):
                    for file in files:
                        if file.lower().endswith(".appimage"):
                            extracted_appimage = os.path.join(root, file)
                            break
                    if extracted_appimage:
                        break

                if extracted_appimage is None:
                    self.state = "EMU_MENU"
                    self.status_msg = "❌ No se encontró ningún archivo .AppImage dentro del comprimido."
                    self._cleanup_temp(app, temp_file)
                    if os.path.exists(backup_path):
                        shutil.move(backup_path, appimage_path)
                    return

                # Move to final location
                os.rename(extracted_appimage, appimage_path)
                os.chmod(appimage_path, 0o755)
                # Cleanup temp
                if os.path.exists(temp_extract_dir):
                    shutil.rmtree(temp_extract_dir, ignore_errors=True)
            else:
                # Direct AppImage download, just move
                os.rename(temp_file, appimage_path)
                os.chmod(appimage_path, 0o755)
        except Exception as e:
            self.state = "EMU_MENU"
            self.status_msg = f"❌ Error crítico: {e} (restaurado desde backup)"
            self._cleanup_temp(app, temp_file)
            if os.path.exists(backup_path):
                shutil.move(backup_path, appimage_path)
            return

        # Write version file
        try:
            with open(os.path.join(app["path"], ".version"), 'w') as vf:
                vf.write(tag.lstrip("v"))
        except Exception:
            pass

        self.state = "SUCCESS"
        self.status_msg = f"¡{app['name']} actualizado con éxito!"
        app["version"] = tag.lstrip("v")
        app["has_update"] = False
        self.cancel_requested = False
        self.download_progress = 0.0
        self.download_speed = "0.0 MB/s"

        # Remove backup on success
        if os.path.exists(backup_path):
            try:
                os.remove(backup_path)
            except Exception:
                pass

    def _cleanup_temp(self, app, temp_file):
        """Limpia archivos temporales de una descarga cancelada/fallida."""
        if temp_file and os.path.exists(temp_file):
            try:
                os.remove(temp_file)
            except Exception:
                pass
        temp_extract = os.path.join(app["path"], "temp_extract_archive")
        if os.path.exists(temp_extract):
            try:
                shutil.rmtree(temp_extract, ignore_errors=True)
            except Exception:
                pass
        self.cancel_requested = True

    def start_system_update(self):
        # Salvaguarda: nunca aplicar un payload que no sea de nuestra arquitectura.
        if not SYSTEM_UPDATE_ENABLED:
            self.state = "HUB"
            self.status_msg = ("Actualización de DeckStation desactivada en ARM "
                               "(el payload disponible es x86_64)")
            return
        self.state = "DOWNLOADING"
        self.status_msg = "Consultando API de MediaFire..."
        self.download_progress = 0.0
        self.changelog_lines = []
        self.changelog_scroll = 0
        t = threading.Thread(target=self._system_update_worker, daemon=True)
        t.start()

    def _system_update_worker(self):
        try:
            url = f"https://www.mediafire.com/api/1.5/folder/get_content.php?folder_key={self.mf_folder_key}&content_type=files&response_format=json"
            res = requests.get(url, timeout=30)
            if res.status_code != 200:
                self.state = "EMU_MENU"
                self.status_msg = "MediaFire bloqueó la conexión."
                return
            data = res.json()
            if data.get("response", {}).get("result") != "Success":
                self.state = "EMU_MENU"
                self.status_msg = "MediaFire bloqueó la conexión."
                return

            files = data["response"]["folder_content"]["files"]
            # Sort by created date
            files.sort(key=lambda x: x.get("created", ""), reverse=True)

            self.status_msg = "Buscando actualizaciones..."
            for fdata in files:
                filename = fdata["filename"]
                if not filename.endswith(".tar.gz"):
                    continue

                # Check if already installed
                installed_flag = os.path.join(self.installed_dir, filename)
                if os.path.exists(installed_flag):
                    continue

                # Download
                quickkey = fdata.get("quickkey", "")
                dl_url = f"https://www.mediafire.com/file/{quickkey}/{filename}/file"
                self.status_msg = f"Localizando enlaces para {filename}..."

                dl_page = requests.get(dl_url, timeout=15)
                if dl_page.status_code != 200:
                    continue

                match = re.search(r'https://download\d*\.mediafire\.com/[^"<> ]+', dl_page.text)
                if not match:
                    continue
                real_url = match.group(0)

                temp_path = os.path.join(self.update_dir, "temp", filename)
                os.makedirs(os.path.dirname(temp_path), exist_ok=True)

                self.status_msg = f"Descargando {filename}..."
                self.download_progress = 0.0

                with requests.get(real_url, stream=True, timeout=(10, 60)) as r:
                    r.raise_for_status()
                    total = int(r.headers.get("content-length", 0))
                    dl = 0
                    with open(temp_path, "wb") as f:
                        for chunk in r.iter_content(chunk_size=8192):
                            if chunk:
                                f.write(chunk)
                                dl += len(chunk)
                                if total:
                                    self.download_progress = dl / total

                # Install
                self.status_msg = f"Instalando update: {filename}"
                extract_to = os.path.join(self.update_dir, "temp")
                subprocess.run(["tar", "-xzf", temp_path, "-C", extract_to], check=True)

                # Run install.sh if present
                install_sh = os.path.join(extract_to, "install.sh")
                if os.path.exists(install_sh):
                    env = os.environ.copy()
                    env["ROMs"] = os.path.join(DECKSTATION_ROOT, "ROMs")
                    env["desktop"] = os.path.join(DECKSTATION_ROOT, "desktop")
                    env["Apps"] = APPS_DIR
                    env["APPS_DIR"] = APPS_DIR
                    env["DECKSTATION_DIR"] = DECKSTATION_ROOT
                    result = subprocess.run(["bash", install_sh], cwd=extract_to, env=env, check=False)
                    if result.returncode != 0:
                        self.status_msg = f"install.sh falló (Cód: {result.returncode}). Revisa el bash script del payload."
                        self.state = "EMU_MENU"
                        return

                # Mark as installed
                with open(installed_flag, "w") as f:
                    f.write("1")

                # Read changelog
                changelog_file = os.path.join(extract_to, "changelog.txt")
                if os.path.exists(changelog_file):
                    try:
                        with open(changelog_file, "r", encoding="utf-8", errors="replace") as cf:
                            content = cf.read()
                        self.changelog_lines.append(f"----- {filename} -----")
                        self.changelog_lines.extend(content.strip().split("\n"))
                    except Exception:
                        pass

                # Cleanup temp
                shutil.rmtree(extract_to, ignore_errors=True)
                if os.path.exists(temp_path):
                    os.remove(temp_path)

            if self.changelog_lines:
                self.state = "SUCCESS"
                self.status_msg = f"¡{len([f for f in os.listdir(self.installed_dir) if os.path.isfile(os.path.join(self.installed_dir, f))])} actualizaciones aplicadas!"
            else:
                self.state = "SUCCESS"
                self.status_msg = "El sistema ya estaba en la última versión."

        except Exception as e:
            self.state = "ERROR"
            self.status_msg = f"Fallo del Sistema: {e}"

    def render_loop(self):
        running = True
        hub_options = [
            ("Actualizar Emuladores", "EMU_MENU"),
            ("Apariencia", "THEME_MENU"),
        ]
        # La opción de actualizar DeckStation (payload de MediaFire) solo se ofrece
        # si hay un payload de NUESTRA arquitectura. Ver SYSTEM_UPDATE_ENABLED.
        if SYSTEM_UPDATE_ENABLED:
            hub_options.insert(1, ("Actualizar DeckStation", "SYSTEM_UPDATE"))
        hub_spacing = 120
        while running:
            screen.fill(BG_COLOR)

            if self.state == "HUB":
                # Draw hub background
                screen.fill(HUB_BG)
                self._check_system_update()
                hub_icon = load_hub_icon("deckstation.png", 128)
                if hub_icon:
                    screen.blit(hub_icon, (SCREEN_WIDTH//2 - 64, 60))

                title_text = font_title.render("  CENTRO DE MANDO DECKSTATION", True, ACCENT_COLOR)
                title_rect = title_text.get_rect(center=(SCREEN_WIDTH//2, 240))
                screen.blit(title_text, title_rect)

                sub_text = font.render("¿Qué deseas actualizar hoy?", True, TEXT_COLOR)
                sub_rect = sub_text.get_rect(center=(SCREEN_WIDTH//2, 290))
                screen.blit(sub_text, sub_rect)
                icon_x, icon_y = SCREEN_WIDTH//2 - 200, 310
                for idx, (opt_text, opt_action) in enumerate(hub_options):
                    y_pos = icon_y + idx * hub_spacing
                    is_sel = (idx == self.hub_idx)
                    bg = ACCENT_COLOR if is_sel else PANEL_COLOR
                    txt_color = SEL_FG_COLOR if is_sel else TEXT_COLOR
                    pygame.draw.rect(screen, bg, (icon_x, y_pos, 400, 80), border_radius=RADIUS)
                    # Badge de actualización en "Actualizar DeckStation" (por ACCION,
                    # no por indice: si se oculta una opcion los indices se desplazan)
                    if opt_action == "SYSTEM_UPDATE" and self._system_update_available:
                        display_text = "⬆ Actualizar DeckStation ⬆"
                        txt_color_badge = SEL_FG_COLOR if is_sel else GREEN_COLOR
                        txt_surf = font.render(display_text, True, txt_color_badge)
                    else:
                        if opt_action == "THEME_MENU":
                            opt_text = f"{opt_text} · {ACTIVE_THEME.capitalize()}"
                        txt_surf = font.render(opt_text, True, txt_color)
                    screen.blit(txt_surf, (icon_x + 20, y_pos + 20))

            elif self.state == "THEME_MENU":
                title = font_title.render(" APARIENCIA", True, ACCENT_COLOR)
                screen.blit(title, (40, 30))
                hint = font_small.render("A/Enter=Seleccionar  |  Esc/B=Volver  |  ↑↓=Navegar", True, DIM_COLOR)
                screen.blit(hint, (40, 70))

                x, y_base, row_h = 60, 130, 100
                for i, (tkey, tname, tdesc) in enumerate(THEME_ENTRIES):
                    y_pos = y_base + i * row_h
                    is_sel = (i == self.theme_idx)
                    is_active = (tkey == ACTIVE_THEME)
                    bg = ACCENT_COLOR if is_sel else PANEL_COLOR
                    pygame.draw.rect(screen, bg, (x, y_pos, SCREEN_WIDTH - 120, 84), border_radius=RADIUS)
                    # Muestra de colores del tema (fondo + acento + selección)
                    ttheme = THEMES[tkey]
                    sw_x, sw_y = x + 20, y_pos + 22
                    pygame.draw.rect(screen, ttheme['bg'], (sw_x, sw_y, 90, 40), border_radius=4)
                    pygame.draw.rect(screen, ttheme['acc'], (sw_x, sw_y, 90, 18), border_radius=4)
                    pygame.draw.rect(screen, ttheme['sel_bg'], (sw_x + 10, sw_y + 24, 70, 12), border_radius=3)
                    name_col = SEL_FG_COLOR if is_sel else TEXT_COLOR
                    tname_surf = font.render(tname, True, name_col)
                    screen.blit(tname_surf, (sw_x + 110, y_pos + 12))
                    tdesc_surf = font_small.render(tdesc, True, SEL_FG_COLOR if is_sel else DIM_COLOR)
                    screen.blit(tdesc_surf, (sw_x + 110, y_pos + 48))
                    if is_active:
                        mark_col = SEL_FG_COLOR if is_sel else GREEN_COLOR
                        mark_surf = font.render("✓", True, mark_col)
                        screen.blit(mark_surf, (x + SCREEN_WIDTH - 150, y_pos + 22))

            elif self.state == "EMU_MENU":
                # Start update scan if not started
                self._start_update_scan()

                # Scroll logic
                if self.current_app_idx < self.top_visible_idx:
                    self.top_visible_idx = self.current_app_idx
                elif self.current_app_idx >= self.top_visible_idx + self.max_visible:
                    self.top_visible_idx = self.current_app_idx - self.max_visible + 1

                visible_apps = self.apps[self.top_visible_idx:self.top_visible_idx + self.max_visible]

                panel_x, panel_y = 40, 80
                panel_w = SCREEN_WIDTH - 80
                item_h = 88
                icon_size = 64

                # Title
                title = font_title.render(" ACTUALIZADOR DECKSTATION", True, ACCENT_COLOR)
                screen.blit(title, (40, 20))

                # Status bar con info de escaneo
                if self._update_scan_active:
                    scan_text = "Escaneando actualizaciones en segundo plano... " + self.status_msg
                elif self._fetch_loading:
                    scan_text = self.status_msg
                else:
                    scan_text = self.status_msg
                status_lbl = font_small.render(scan_text, True, TEXT_COLOR)
                screen.blit(status_lbl, (40, SCREEN_HEIGHT - 40))

                for i, app in enumerate(visible_apps):
                    y_pos = panel_y + i * item_h
                    actual_idx = self.top_visible_idx + i
                    is_selected = (actual_idx == self.current_app_idx)

                    # Background
                    bg_color = PANEL_COLOR
                    if is_selected:
                        bg_color = ACCENT_COLOR
                    pygame.draw.rect(screen, bg_color, (panel_x, y_pos, panel_w, item_h - 4), border_radius=RADIUS)

                    # Icon
                    icon = load_icon(app["name"], icon_size)
                    if icon:
                        screen.blit(icon, (panel_x + 10, y_pos + (item_h - 4 - icon_size) // 2))

                    # Name
                    txt_color = SEL_FG_COLOR if is_selected else TEXT_COLOR
                    name_surf = font.render(app["name"], True, txt_color)
                    screen.blit(name_surf, (panel_x + 80, y_pos + 8))

                    # Version
                    ver_surf = font_small.render(f"v{app['version']}", True, txt_color if is_selected else DIM_COLOR)
                    screen.blit(ver_surf, (panel_x + 80, y_pos + 44))

                    # Update indicator
                    if app.get("has_update"):
                        upd_surf = font.render("⬆", True, GREEN_COLOR)
                        screen.blit(upd_surf, (panel_x + panel_w - 50, y_pos + 20))

                # Scroll indicators
                if self.top_visible_idx > 0:
                    up_surf = font_small.render("▲ Usa la cruceta para subir", True, DIM_COLOR)
                    screen.blit(up_surf, (40, 50))

                if self.top_visible_idx + self.max_visible < len(self.apps):
                    down_surf = font_small.render("▼ Usa la cruceta para bajar", True, DIM_COLOR)
                    screen.blit(down_surf, (40, SCREEN_HEIGHT - 70))

            elif self.state == "SELECT_VERSION":
                # Version selection screen
                header = font_title.render(f"Versiones disponibles para {self.apps[self.current_app_idx]['name']}", True, ACCENT_COLOR)
                screen.blit(header, (40, 30))
                hint = font_small.render("A/Enter=Descargar seleccionada  |  Esc/B=Cancelar  |  ↑↓=Navegar", True, DIM_COLOR)
                screen.blit(hint, (40, 68))

                y_base = 100
                max_show = min(len(self.available_tags), 10)
                for idx, tag in enumerate(self.available_tags[:max_show]):
                    y_pos = y_base + idx * 40
                    is_sel = (idx == self.selected_tag_idx)
                    color = ACCENT_COLOR if is_sel else TEXT_COLOR
                    prefix = ">> " if is_sel else "   "
                    if tag["version"] == "static":
                        # Nightly (.7z) single-file — mostrar nombre descriptivo
                        display = "Nightly Oficial (.7z)"
                    else:
                        ver = tag["version"]
                        fecha = tag.get("date", "")
                        fecha_str = f" ({fecha})" if fecha else ""
                        display = f"{ver}{fecha_str}"
                    txt = f"{prefix}{display}"
                    surf = font.render(txt, True, color)
                    screen.blit(surf, (60, y_pos))
                if len(self.available_tags) > 10:
                    more_surf = font_small.render(f"... y {len(self.available_tags) - 10} versiones más. La última es la recomendada.", True, DIM_COLOR)
                    screen.blit(more_surf, (60, y_base + 10 * 40 + 10))

            elif self.state == "DOWNLOADING":
                # Download progress screen
                screen.fill(BG_COLOR)
                progress_text = font.render(self.status_msg, True, TEXT_COLOR)
                screen.blit(progress_text, (40, SCREEN_HEIGHT // 2 - 60))

                # Progress bar
                bar_w = SCREEN_WIDTH - 80
                bar_h = 30
                bar_x, bar_y = 40, SCREEN_HEIGHT // 2
                pygame.draw.rect(screen, PANEL_COLOR, (bar_x, bar_y, bar_w, bar_h), border_radius=RADIUS)
                fill_w = int(bar_w * self.download_progress) if self.download_progress > 0 else 0
                if fill_w > 0:
                    pygame.draw.rect(screen, ACCENT_COLOR, (bar_x, bar_y, fill_w, bar_h), border_radius=RADIUS)

                # Progress percentage + speed
                pct = int(self.download_progress * 100) if self.download_progress > 0 else 0
                info = font_small.render(f"{pct}%  —  {self.download_speed}", True, TEXT_COLOR)
                screen.blit(info, (40, bar_y + bar_h + 10))

                cancel_hint = font_small.render("Presiona ESC para cancelar la descarga", True, DIM_COLOR)
                screen.blit(cancel_hint, (40, bar_y + bar_h + 50))

            elif self.state == "SUCCESS":
                success_text = font.render(self.status_msg, True, GREEN_COLOR)
                text_rect = success_text.get_rect(center=(SCREEN_WIDTH // 2, SCREEN_HEIGHT // 2 - 40))
                screen.blit(success_text, text_rect)

                hint_text = font_small.render("Presiona (A), Espacio o ENTER para volver al menú.", True, TEXT_COLOR)
                hint_rect = hint_text.get_rect(center=(SCREEN_WIDTH // 2, SCREEN_HEIGHT // 2 + 20))
                screen.blit(hint_text, hint_rect)

                # Show changelog if present
                if self.changelog_lines:
                    y = SCREEN_HEIGHT // 2 + 60
                    for line in self.changelog_lines[self.changelog_scroll:self.changelog_scroll + 10]:
                        line_surf = font_small.render(line[:100], True, TEXT_COLOR)
                        screen.blit(line_surf, (40, y))
                        y += 24

            elif self.state == "ERROR":
                err_text = font.render(self.status_msg, True, ERROR_COLOR)
                text_rect = err_text.get_rect(center=(SCREEN_WIDTH // 2, SCREEN_HEIGHT // 2 - 20))
                screen.blit(err_text, text_rect)

                back_hint = font_small.render("Presiona (A), Espacio o ENTER para volver.", True, TEXT_COLOR)
                hint_rect = back_hint.get_rect(center=(SCREEN_WIDTH // 2, SCREEN_HEIGHT // 2 + 20))
                screen.blit(back_hint, hint_rect)

            pygame.display.flip()

            # Mostrar SELECT_VERSION si ya tenemos el resultado del fetch asíncrono
            if not self._fetch_loading and self._latest_version_result is not None and self.state == "EMU_MENU":
                result = self._latest_version_result
                app_idx = self._fetch_app_idx
                self._latest_version_result = None
                if result:
                    real_versions = [r for r in result if r.get("name") != "Nightly Oficial (.7z)"]
                    if real_versions:
                        # Limitar a 10 versiones para no abrumar
                        self.available_tags = real_versions[:10]
                        self.selected_tag_idx = 0  # última versión pre-seleccionada
                        self.current_app_idx = app_idx  # asegurar que muestra el emulador correcto
                        self.state = "SELECT_VERSION"
                        self.status_msg = f"Mostrando las {len(self.available_tags)} últimas versiones"
                    elif len(result) == 1 and result[0]["name"] == "Nightly Oficial (.7z)":
                        # Solo hay nightly, auto-descargar (no hay que elegir)
                        app = self.apps[app_idx]
                        repo_info = None
                        for key, rd in EXTERNAL_REPOS.items():
                            if key == app["name"].lower().replace(" ", "").replace("-", "_"):
                                repo_info = rd
                                break
                        if repo_info:
                            self.start_download(app, repo_info, result[0]["version"])
                        else:
                            self.status_msg = "❌ No se encontró repo para este emulador."
                    else:
                        self.status_msg = "❌ No hay versiones disponibles."
                else:
                    self.status_msg = "❌ No se pudieron obtener versiones."

            # Event handling
            for event in pygame.event.get():
                if event.type == pygame.QUIT:
                    running = False
                    return

                if self.state == "HUB":
                    if event.type == pygame.KEYDOWN:
                        if event.key == pygame.K_UP:
                            self.hub_idx = (self.hub_idx - 1) % len(hub_options)
                        elif event.key == pygame.K_DOWN:
                            self.hub_idx = (self.hub_idx + 1) % len(hub_options)
                        elif event.key in (pygame.K_RETURN, pygame.K_SPACE):
                            sel = hub_options[self.hub_idx][1]
                            if sel == "EMU_MENU":
                                self.state = "EMU_MENU"
                                self.current_app_idx = 0
                            elif sel == "SYSTEM_UPDATE":
                                self.start_system_update()
                            elif sel == "THEME_MENU":
                                for i, (tkey, _, _) in enumerate(THEME_ENTRIES):
                                    if tkey == ACTIVE_THEME:
                                        self.theme_idx = i
                                        break
                                self.state = "THEME_MENU"
                    elif event.type == pygame.JOYBUTTONDOWN:
                        if event.button == 0:  # A
                            sel = hub_options[self.hub_idx][1]
                            if sel == "EMU_MENU":
                                self.state = "EMU_MENU"
                                self.current_app_idx = 0
                            elif sel == "SYSTEM_UPDATE":
                                self.start_system_update()
                            elif sel == "THEME_MENU":
                                for i, (tkey, _, _) in enumerate(THEME_ENTRIES):
                                    if tkey == ACTIVE_THEME:
                                        self.theme_idx = i
                                        break
                                self.state = "THEME_MENU"
                        elif event.button == 1:  # B
                            pass
                        elif event.button == 11 or event.button == 13:  # DPAD up
                            self.hub_idx = (self.hub_idx - 1) % len(hub_options)
                        elif event.button == 12 or event.button == 14:  # DPAD down
                            self.hub_idx = (self.hub_idx + 1) % len(hub_options)
                    elif event.type == pygame.JOYHATMOTION:
                        if event.value[1] > 0:
                            self.hub_idx = (self.hub_idx - 1) % len(hub_options)
                        elif event.value[1] < 0:
                            self.hub_idx = (self.hub_idx + 1) % len(hub_options)

                elif self.state == "THEME_MENU":
                    if event.type == pygame.KEYDOWN:
                        if event.key == pygame.K_UP:
                            self.theme_idx = (self.theme_idx - 1) % len(THEME_ENTRIES)
                        elif event.key == pygame.K_DOWN:
                            self.theme_idx = (self.theme_idx + 1) % len(THEME_ENTRIES)
                        elif event.key in (pygame.K_RETURN, pygame.K_SPACE):
                            tkey = THEME_ENTRIES[self.theme_idx][0]
                            _save_theme_conf(tkey)
                            _apply_theme(tkey)
                            self.state = "HUB"
                        elif event.key in (pygame.K_ESCAPE, pygame.K_BACKSPACE):
                            self.state = "HUB"
                    elif event.type == pygame.JOYBUTTONDOWN:
                        if event.button == 0:  # A
                            tkey = THEME_ENTRIES[self.theme_idx][0]
                            _save_theme_conf(tkey)
                            _apply_theme(tkey)
                            self.state = "HUB"
                        elif event.button == 1:  # B
                            self.state = "HUB"
                        elif event.button == 11 or event.button == 13:  # DPAD up
                            self.theme_idx = (self.theme_idx - 1) % len(THEME_ENTRIES)
                        elif event.button == 12 or event.button == 14:  # DPAD down
                            self.theme_idx = (self.theme_idx + 1) % len(THEME_ENTRIES)
                    elif event.type == pygame.JOYHATMOTION:
                        if event.value[1] > 0:
                            self.theme_idx = (self.theme_idx - 1) % len(THEME_ENTRIES)
                        elif event.value[1] < 0:
                            self.theme_idx = (self.theme_idx + 1) % len(THEME_ENTRIES)

                elif self.state == "EMU_MENU":
                    if event.type == pygame.KEYDOWN:
                        if event.key == pygame.K_UP:
                            self.current_app_idx = max(0, self.current_app_idx - 1)
                        elif event.key == pygame.K_DOWN:
                            self.current_app_idx = min(len(self.apps) - 1, self.current_app_idx + 1)
                        elif event.key in (pygame.K_RETURN, pygame.K_SPACE):
                            if not self.apps:
                                continue
                            # Usar fetch asíncrono para no bloquear la UI
                            self._start_fetch_latest(self.current_app_idx)
                        elif event.key == pygame.K_ESCAPE or event.key == pygame.K_BACKSPACE:
                            self.state = "HUB"
                    elif event.type == pygame.JOYBUTTONDOWN:
                        if event.button == 0:  # A
                            if not self.apps:
                                continue
                            self._start_fetch_latest(self.current_app_idx)
                        elif event.button == 1:  # B
                            self.state = "HUB"
                        elif event.button == 11 or event.button == 13:  # DPAD up
                            self.current_app_idx = max(0, self.current_app_idx - 1)
                        elif event.button == 12 or event.button == 14:  # DPAD down
                            self.current_app_idx = min(len(self.apps) - 1, self.current_app_idx + 1)
                    elif event.type == pygame.JOYHATMOTION:
                        if event.value[1] > 0:
                            self.current_app_idx = max(0, self.current_app_idx - 1)
                        elif event.value[1] < 0:
                            self.current_app_idx = min(len(self.apps) - 1, self.current_app_idx + 1)

                elif self.state == "SELECT_VERSION":
                    if event.type == pygame.KEYDOWN:
                        if event.key == pygame.K_UP:
                            self.selected_tag_idx = max(0, self.selected_tag_idx - 1)
                        elif event.key == pygame.K_DOWN:
                            self.selected_tag_idx = min(len(self.available_tags) - 1, self.selected_tag_idx + 1)
                        elif event.key in (pygame.K_RETURN, pygame.K_SPACE):
                            tag = self.available_tags[self.selected_tag_idx]
                            app = self.apps[self.current_app_idx]
                            repo_info = None
                            for key, rd in EXTERNAL_REPOS.items():
                                if key == app["name"].lower().replace(" ", "").replace("-", "_"):
                                    repo_info = rd
                                    break
                            if repo_info:
                                self.start_download(app, repo_info, tag["version"])
                        elif event.key == pygame.K_ESCAPE or event.key == pygame.K_BACKSPACE:
                            self.state = "EMU_MENU"
                    elif event.type == pygame.JOYBUTTONDOWN:
                        if event.button == 0:  # A
                            tag = self.available_tags[self.selected_tag_idx]
                            app = self.apps[self.current_app_idx]
                            repo_info = None
                            for key, rd in EXTERNAL_REPOS.items():
                                if key == app["name"].lower().replace(" ", "").replace("-", "_"):
                                    repo_info = rd
                                    break
                            if repo_info:
                                self.start_download(app, repo_info, tag["version"])
                        elif event.button == 1:  # B
                            self.state = "EMU_MENU"
                        elif event.button == 11 or event.button == 13:  # DPAD up
                            self.selected_tag_idx = max(0, self.selected_tag_idx - 1)
                        elif event.button == 12 or event.button == 14:  # DPAD down
                            self.selected_tag_idx = min(len(self.available_tags) - 1, self.selected_tag_idx + 1)

                elif self.state == "DOWNLOADING":
                    if event.type == pygame.KEYDOWN:
                        if event.key in (pygame.K_ESCAPE, pygame.K_BACKSPACE):
                            self.cancel_requested = True
                            self.state = "EMU_MENU"
                            self.status_msg = "Cancelando descarga..."
                    elif event.type == pygame.JOYBUTTONDOWN:
                        if event.button == 1:  # B
                            self.cancel_requested = True
                            self.state = "EMU_MENU"
                            self.status_msg = "Cancelando descarga..."

                elif self.state in ("SUCCESS", "ERROR"):
                    if event.type == pygame.KEYDOWN:
                        if event.key in (pygame.K_RETURN, pygame.K_SPACE, pygame.K_ESCAPE, pygame.K_BACKSPACE):
                            if self.changelog_lines:
                                if event.key == pygame.K_UP:
                                    self.changelog_scroll = max(0, self.changelog_scroll - 1)
                                elif event.key == pygame.K_DOWN:
                                    self.changelog_scroll = min(len(self.changelog_lines) - 1, self.changelog_scroll + 1)
                                else:
                                    self.state = "EMU_MENU"
                                    self.changelog_lines = []
                                    self.changelog_scroll = 0
                            else:
                                self.state = "EMU_MENU"
                    elif event.type == pygame.JOYBUTTONDOWN:
                        if event.button == 0:  # A
                            self.state = "EMU_MENU"
                            self.changelog_lines = []
                            self.changelog_scroll = 0

            clock.tick(30)


def main():
    pygame.key.set_repeat(200, 100)
    eng = UpdaterEngine()
    eng.render_loop()


if __name__ == "__main__":
    error_path = os.path.join(DIR, "error_log.txt")
    try:
        main()
    except SystemExit:
        pass
    except Exception as e:
        with open(error_path, "w", encoding="utf-8") as f:
            traceback.print_exc(file=f)
        print(f"CRASH CRÍTICO: {e}. Revisa error_log.txt en {DIR}")
