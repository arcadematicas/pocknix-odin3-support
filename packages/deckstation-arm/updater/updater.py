#!/usr/bin/env python3
# -*- coding: utf-8 -*-

import os, sys, subprocess, requests, threading, traceback, shutil, re, platform, zipfile
from os.path import dirname, abspath, join, exists

# Modo headless: lo usa deckstation-setup.sh desde un terminal SIN escritorio
# (Pocknix Tools -> instalar DeckStation). Este modulo abre una ventana al
# cargarse, asi que SDL necesita un driver valido igualmente: se fuerza "dummy"
# ANTES de importar pygame. Sin esto: "pygame.error: No available video device".
if any(a in sys.argv for a in ("--install-all", "--bios-check")):
    os.environ.setdefault("SDL_VIDEODRIVER", "dummy")

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
    global ACCENT_COLOR, SEL_FG_COLOR, DIM_COLOR, GREEN_COLOR, ERROR_COLOR, RADIUS, WARN_COLOR
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
    WARN_COLOR = TH.get('warn', (235, 180, 70))
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
# Emuladores que NO son un AppImage: su payload es un binario nativo suelto.
# El lanzar.sh ya los soporta (busca el ejecutable en la carpeta del emulador:
# `[ -x "$DIR/retroarch" ]`). Sin esto RetroArch --el emulador BASE-- no se
# podia instalar: se extraia el .7z y no habia ningun .AppImage dentro.
NATIVOS = {'retroarch'}

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

        # Cola de "instalacion completa inicial"
        self._install_queue = []
        self._install_total = 0
        self._install_done = 0
        self._install_fallidos = []
        self._auto_pick_latest = False
        self._descarga_correcta = False
        self._bios_cache = None

        self.state = "HUB"
        self.hub_idx = 0
        self.theme_idx = 0
        self.openrom_idx = 0

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

    def _preparar_portable(self, app):
        """Deja el emulador listo para lanzar: wrapper lanzar.sh + configs.

        El es_find_rules.xml de ES-DE apunta a Apps/<Emulador>/lanzar.sh, no al
        AppImage. El setup despliega esos wrappers ANTES de que el Updater
        descargue nada, asi que un emulador recien instalado se quedaba sin
        lanzar.sh y ES-DE no podia arrancarlo. Aqui se completa al instante.
        """
        raiz = os.path.dirname(os.path.dirname(DIR))  # /opt/deckstation
        env = dict(os.environ, DECKSTATION_ROOT=raiz)
        helper = os.path.join(raiz, "scripts", "deploy-lanzar-sh.sh")
        try:
            if os.path.isfile(helper):
                subprocess.run([helper, app.get("name", "")], env=env,
                               timeout=60, capture_output=True)
        except Exception:
            pass
        # Configs de fabrica: el script omite solo las apps que no existen.
        try:
            confs = os.path.join(raiz, "scripts", "deckstation-configs.sh")
            if os.path.isfile(confs):
                subprocess.run([confs], env=env, timeout=120, capture_output=True)
        except Exception:
            pass

    def _raiz_deckstation(self):
        """Raiz de DeckStation (/opt/deckstation) vista desde Apps/Updater/."""
        return os.path.dirname(os.path.dirname(DIR))

    # ------------------------------------------------------------------
    # OpenROM (suite de conversion de ROMs, M5Devs, GPL-3.0)
    # Build ARM64 oficial: GUI Flutter (openrom_flutter) + CLI (openrom-core).
    # Se instala como app en Apps/OpenROM/ (no es un emulador AppImage, por
    # eso NO va en git.txt ni en el catalogo de emuladores).
    # ------------------------------------------------------------------
    OPENROM_URL = ("https://github.com/M5Devs/OpenROM/releases/download/v3.0.0/"
                   "OpenROM-v3.0.0_Linux_arm64.zip")
    OPENROM_DIR = os.path.join(APPS_DIR, "OpenROM")

    def _openrom_instalado(self):
        return os.path.isfile(os.path.join(self.OPENROM_DIR, "openrom_flutter"))

    def _openrom_opciones(self):
        """Opciones del menu OPENROM_MENU segun el estado de instalacion."""
        if self._openrom_instalado():
            return ["Abrir OpenROM (GUI)",
                    "Convertir ROMs a CHD (lote)",
                    "Reinstalar / actualizar"]
        return ["Descargar e instalar OpenROM"]

    def _openrom_descargar(self):
        """Descarga el zip ARM64 y lo instala en Apps/OpenROM/ con sus wrappers."""
        try:
            os.makedirs(self.OPENROM_DIR, exist_ok=True)
            tmp = os.path.join(self.OPENROM_DIR, "openrom.zip")
            self.status_msg = "Descargando OpenROM..."
            self._draw_and_flip()
            req = requests.get(self.OPENROM_URL, stream=True, timeout=60)
            req.raise_for_status()
            total = int(req.headers.get("content-length", 0))
            done = 0
            with open(tmp, "wb") as f:
                for chunk in req.iter_content(chunk_size=1 << 16):
                    f.write(chunk)
                    done += len(chunk)
                    if total:
                        self.status_msg = f"Descargando OpenROM... {done*100//total}%"
                        self._draw_and_flip()
            self.status_msg = "Extrayendo OpenROM..."
            self._draw_and_flip()
            with zipfile.ZipFile(tmp) as z:
                z.extractall(self.OPENROM_DIR)
            os.remove(tmp)
            for b in ("openrom_flutter", "openrom-core"):
                p = os.path.join(self.OPENROM_DIR, b)
                if os.path.exists(p):
                    os.chmod(p, 0o755)
            self._openrom_escribir_wrappers()
            # Enlace para ES-DE (sistema openrom -> ROMs/openrom/)
            try:
                roms_openrom = os.path.join(os.path.dirname(APPS_DIR), "ROMs", "openrom")
                os.makedirs(roms_openrom, exist_ok=True)
                link = os.path.join(roms_openrom, "OpenROM.sh")
                if not os.path.exists(link):
                    os.symlink(os.path.join(self.OPENROM_DIR, "OpenROM.sh"), link)
            except Exception:
                pass
            self.status_msg = "OpenROM instalado."
            return True
        except Exception as e:
            self.status_msg = f"Error descargando OpenROM: {e}"
            return False

    def _openrom_escribir_wrappers(self):
        gui = os.path.join(self.OPENROM_DIR, "OpenROM.sh")
        if not os.path.exists(gui):
            with open(gui, "w") as f:
                f.write("#!/bin/bash\n"
                        "cd \"$(dirname \"$0\")\"\n"
                        "export LANG=C.UTF-8 PYTHONIOENCODING=utf-8\n"
                        "exec ./openrom_flutter \"$@\"\n")
            os.chmod(gui, 0o755)
        batch = os.path.join(self.OPENROM_DIR, "openrom-batch.sh")
        if not os.path.exists(batch):
            with open(batch, "w") as f:
                f.write('''#!/bin/bash
# openrom-batch.sh [carpeta] [formato]
# Convierte por lotes las ROMs de una carpeta con openrom-core (CLI).
# Uso: openrom-batch.sh [carpeta] [CHD|CSO|ECM|RVZ|XISO|...]
set -u
cd "$(dirname "$0")"
export LANG=C.UTF-8 PYTHONIOENCODING=utf-8
DIR="${1:-/opt/deckstation/ROMs}"
FMT="${2:-CHD}"
if [ ! -d "$DIR" ]; then
    echo "La carpeta no existe: $DIR"
    exit 1
fi
mapfile -t FILES < <(find "$DIR" -type f \\( -iname '*.iso' -o -iname '*.bin' -o -iname '*.cue' -o -iname '*.gdi' -o -iname '*.img' -o -iname '*.chd' -o -iname '*.cso' -o -iname '*.zso' -o -iname '*.ecm' \\) | sort)
TOTAL=${#FILES[@]}
if [ "$TOTAL" -eq 0 ]; then
    echo "No hay ROMs convertibles en $DIR"
    exit 0
fi
echo "Convirtiendo $TOTAL ROMs a $FMT en $DIR"
OK=0; FAIL=0; N=0
for f in "${FILES[@]}"; do
    N=$((N+1))
    echo "[$N/$TOTAL] $f"
    if ./openrom-core --input "$f" --format "$FMT" >/dev/null 2>&1; then
        OK=$((OK+1)); echo "  -> OK"
    else
        FAIL=$((FAIL+1)); echo "  -> FALLO"
    fi
done
echo ""
echo "Resumen: $OK convertidas, $FAIL fallidas (de $TOTAL)"
''')
            os.chmod(batch, 0o755)

    def _openrom_lanzar(self):
        gui = os.path.join(self.OPENROM_DIR, "OpenROM.sh")
        if os.path.exists(gui):
            subprocess.Popen([gui], cwd=self.OPENROM_DIR,
                             env={**os.environ, "LANG": "C.UTF-8",
                                  "PYTHONIOENCODING": "utf-8"})

    def _openrom_batch(self):
        batch = os.path.join(self.OPENROM_DIR, "openrom-batch.sh")
        if os.path.exists(batch):
            subprocess.Popen(["konsole", "-e", "/bin/bash", batch],
                             env={**os.environ, "LANG": "C.UTF-8",
                                  "PYTHONIOENCODING": "utf-8"})

    def _openrom_ejecutar(self, idx):
        """Ejecuta la opcion idx del menu OPENROM_MENU."""
        opciones = self._openrom_opciones()
        if idx >= len(opciones):
            return
        accion = opciones[idx]
        if accion == "Descargar e instalar OpenROM":
            self._openrom_descargar()
        elif accion == "Reinstalar / actualizar":
            self._openrom_descargar()
        elif accion == "Abrir OpenROM (GUI)":
            self._openrom_lanzar()
        elif accion == "Convertir ROMs a CHD (lote)":
            self._openrom_batch()

    def _bios_lineas(self):
        """Salida de `deckstation-bios.sh --check`, cacheada hasta repartir."""
        if self._bios_cache is None:
            script = os.path.join(self._raiz_deckstation(), "scripts", "deckstation-bios.sh")
            try:
                r = subprocess.run([script, "--check"], capture_output=True,
                                   text=True, timeout=60)
                self._bios_cache = (r.stdout or r.stderr or "(sin salida)").split("\n")
            except Exception as e:
                self._bios_cache = [f"No se pudo consultar las BIOS: {e}"]
        return self._bios_cache

    def _bios_repartir(self):
        """Copia las BIOS de bios/ a donde cada emulador las espera."""
        script = os.path.join(self._raiz_deckstation(), "scripts", "deckstation-bios.sh")
        try:
            r = subprocess.run([script], capture_output=True, text=True, timeout=300)
            lineas = ((r.stdout or "") + (r.stderr or "")).split("\n")
            resumen = [l.strip() for l in lineas if "desplegad" in l or "ya presentes" in l]
            self.status_msg = resumen[-1] if resumen else "BIOS repartidas"
        except Exception as e:
            self.status_msg = f"No se pudieron repartir: {e}"
        self._bios_cache = None      # refrescar el informe

    def _lanzar_bezel_master(self):
        """Lanza BezelMaster (bezels de TheBezelProject) como proceso aparte.

        BezelMaster es una app pygame independiente (bezel_master.py) con su
        propio bucle y ventana. Para no mezclar dos estados de pygame en el
        mismo proceso, cerramos el nuestro, lo lanzamos y al volver
        re-inicializamos la ventana y las fuentes.
        """
        global screen, clock, font, font_title, font_small
        bezel = os.path.join(DIR, "bezel_master.py")
        if not os.path.exists(bezel):
            self.status_msg = "No encuentro bezel_master.py"
            return
        pygame.quit()
        try:
            subprocess.run([sys.executable, bezel], cwd=DIR)
        except Exception as e:
            self.status_msg = f"BezelMaster falló: {e}"
        # Re-inicializar pygame (el proceso hijo cerró la ventana)
        pygame.init()
        pygame.joystick.init()
        screen = pygame.display.set_mode((SCREEN_WIDTH, SCREEN_HEIGHT))
        try:
            pygame.display.set_caption("Centro de Mando DeckStation v11.3 - Clean Sweeper")
        except pygame.error:
            pass
        clock = pygame.time.Clock()
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
        self.state = "HUB"

    def _activate_current(self):
        """Activa la entrada seleccionada (instalar todo o gestionar un emulador)."""
        if not self.apps:
            return
        app = self.apps[self.current_app_idx]
        if app.get("special") == "install_all":
            self._start_install_all()
            return
        self._start_fetch_latest(self.current_app_idx)

    def _start_install_all(self):
        """Encola TODOS los emuladores que falten, en orden."""
        faltan = [a["name"] for a in self.apps
                  if not a.get("installed") and not a.get("special")]
        if not faltan:
            self.status_msg = "Ya estan instalados todos los emuladores"
            return
        self._install_queue = faltan
        self._install_total = len(faltan)
        self._install_done = 0
        self._install_fallidos = []
        self._next_queued_install()

    def _next_queued_install(self):
        """Instala el siguiente de la cola, o termina."""
        if not self._install_queue:
            self._auto_pick_latest = False
            ok_n = self._install_done - len(self._install_fallidos)
            if self._install_fallidos:
                muestra = ", ".join(self._install_fallidos[:6])
                if len(self._install_fallidos) > 6:
                    muestra += f" y {len(self._install_fallidos) - 6} mas"
                self.status_msg = (f"Instalacion terminada: {ok_n}/{self._install_total} OK. "
                                   f"Fallaron: {muestra}")
            else:
                self.status_msg = (f"Instalacion completa terminada "
                                   f"({ok_n} emuladores)")
            self.state = "HUB"
            return
        nombre = self._install_queue.pop(0)
        idx = next((i for i, a in enumerate(self.apps) if a["name"] == nombre), None)
        if idx is None:
            self._next_queued_install()
            return
        self.current_app_idx = idx
        self.state = "EMU_MENU"
        self.status_msg = (f"Instalando {self._install_done + 1}/{self._install_total}"
                           f": {nombre}")
        self._auto_pick_latest = True
        self._start_fetch_latest(idx)

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

    def _app_entry(self, nombre, instalado):
        """Entrada de la lista para un emulador, este instalado o no.

        instalado = (nombre_real, ruta, appimage) o None.
        """
        if instalado:
            _n, app_path, appimage = instalado
            version = "Desconocida (Caché vacía)"
            version_file = os.path.join(app_path, ".version")
            try:
                if os.path.exists(version_file):
                    v = open(version_file, 'r').read().strip()
                    if v:
                        version = v
            except Exception:
                pass
            return {
                "name": nombre,
                "path": app_path,
                "file": appimage,
                "filename": appimage,
                "version": version,
                "installed": True,
                "has_update": False,
                "latest_version": "",
            }
        # No instalado: entra igual en la lista para poder INSTALARLO.
        return {
            "name": nombre,
            "path": os.path.join(APPS_DIR, nombre),
            "file": "",
            "filename": "",
            "version": "No instalado",
            "installed": False,
            "has_update": False,
            "latest_version": "",
        }

    def scan_apps(self):
        """Lista TODOS los emuladores de git.txt, instalados o no.

        Antes solo devolvia los que YA tenian un .AppImage, asi que en un sistema
        recien instalado la lista salia VACIA y el Updater no servia como
        instalador inicial (el usuario no tenia forma de bajar nada).
        """
        apps = []
        try:
            if not os.path.exists(APPS_DIR):
                os.makedirs(APPS_DIR, exist_ok=True)
        except Exception:
            return apps

        # 1) Nombres "bonitos" y en el orden de git.txt (EXTERNAL_REPOS usa claves
        #    normalizadas: 'duckstation' en vez de 'Duckstation').
        orden = []
        try:
            with open(GIT_TXT_PATH, 'r', encoding='utf-8') as f:
                lineas = [l.strip() for l in f
                          if l.strip() and not l.strip().startswith('#')]
            it = iter(lineas)
            for nombre, _url in zip(it, it):
                orden.append(nombre)
        except Exception:
            pass

        # 2) Lo que hay de verdad en Apps/
        instalados = {}
        for name in sorted(os.listdir(APPS_DIR)):
            app_path = os.path.join(APPS_DIR, name)
            if name == "Updater" or not os.path.isdir(app_path):
                continue
            appimage = None
            try:
                for fname in os.listdir(app_path):
                    low = fname.lower()
                    if low.endswith(".appimage"):
                        appimage = fname
                        break
                    # Emulador NATIVO (RetroArch): no hay AppImage, pero si el
                    # binario. Sin esto saldria como "No instalado" para siempre
                    # y el Updater lo volveria a bajar en cada pasada.
                    if low in NATIVOS:
                        appimage = fname
                        break
            except Exception:
                continue
            if appimage:
                instalados[name.lower()] = (name, app_path, appimage)

        # 3) Union: primero los de git.txt (con su estado), luego lo instalado
        #    que no aparezca en la lista (por si hay algo de fuera).
        vistos = set()
        for nombre in orden:
            clave = nombre.lower()
            vistos.add(clave)
            apps.append(self._app_entry(nombre, instalados.get(clave)))
        for clave in sorted(instalados):
            if clave in vistos:
                continue
            apps.append(self._app_entry(instalados[clave][0], instalados[clave]))

        # Entrada destacada: instala de golpe todo lo que falte (primer arranque).
        pendientes = len([a for a in apps if not a.get("installed")])
        apps.insert(0, {
            "name": "Instalacion completa inicial",
            "path": "",
            "file": "",
            "filename": "",
            "version": (f"{pendientes} emuladores por instalar" if pendientes
                        else "todo instalado"),
            "installed": True,
            "special": "install_all",
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
        """Envoltorio de _descargar(): evita que un fallo corte la instalacion masiva.

        _descargar() tiene 13 salidas de error que hacen "return" sin avisar a
        nadie. En una instalacion de 30 emuladores, uno que falle (repo parado,
        sin asset aarch64, 404...) abortaba la cola entera. Aqui se detecta el
        fallo y se sigue con el siguiente, anotandolo para el resumen final.
        """
        self._descarga_correcta = False
        self._descargar(app, repo_info, tag)
        if not self._descarga_correcta and self._install_queue:
            # El camino de exito avanza la cola por su cuenta; este es el de fallo.
            self._install_fallidos.append(app.get("name", "?"))
            self._install_done += 1
            self.cancel_requested = False
            self.download_progress = 0.0
            self.download_speed = "0.0 MB/s"
            self._next_queued_install()

    def _descargar(self, app, repo_info, tag):
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
                # Gitea devuelve la LISTA de releases (GitHub, un release suelto):
                # hay que quedarse con el que corresponde al tag elegido. Sin esto
                # el Eden fallaba con "'list' object has no attribute 'get'".
                if repo_type == "gitea" and isinstance(data, list):
                    elegido = None
                    for rel in data:
                        if not isinstance(rel, dict):
                            continue
                        if rel.get("tag_name") == tag or rel.get("name") == tag:
                            elegido = rel
                            break
                    data = elegido if elegido else (data[0] if data else {})
                # Find asset
                best_url = None
                best_score = -1
                fallback_url = None
                for asset in (data.get("assets", []) if isinstance(data, dict) else []):
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
        # Emulador NUEVO: app["file"] esta vacio, asi que no se puede componer la
        # ruta final todavia. Si la URL es ya un .AppImage usamos su nombre; si es
        # un comprimido, se resuelve al extraer (basename del .AppImage hallado).
        # Sin esto, os.path.join(path, "") devolvia el DIRECTORIO y el rename final
        # fallaba con "Directory not empty" (no se podia instalar nada nuevo).
        _fichero_final = app.get("file") or ""
        if not _fichero_final:
            _base_url = best_url.split("?")[0].rstrip("/")
            _fichero_final = (os.path.basename(_base_url)
                              if _base_url.lower().endswith(".appimage") else None)
        appimage_path = (os.path.join(app["path"], _fichero_final)
                         if _fichero_final else None)

        # Asegurar que existe la carpeta del emulador (los nuevos no la tienen)
        try:
            os.makedirs(app["path"], exist_ok=True)
        except Exception:
            pass
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
        backup_path = (appimage_path + ".bak") if appimage_path else None
        if appimage_path and os.path.exists(appimage_path):
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
                    self.status_msg = ("❌ '7z' no instalado. "
                                       "Ejecuta: sudo pacman -S 7zip (o p7zip)")
                    self._cleanup_temp(app, temp_file)
                    if backup_path and os.path.exists(backup_path):
                        shutil.move(backup_path, appimage_path)
                    return
                except subprocess.CalledProcessError:
                    self.state = "EMU_MENU"
                    self.status_msg = "❌ Error al descomprimir. El archivo puede estar corrupto."
                    self._cleanup_temp(app, temp_file)
                    if backup_path and os.path.exists(backup_path):
                        shutil.move(backup_path, appimage_path)
                    return

                # Los .tar.gz/.tar.xz necesitan DOS pasadas: `7z x` sobre ellos solo
                # saca el tar de dentro, no su contenido.
                # OJO: 7z nombra la salida con el nombre del archivo SIN extension
                # (temp_update.archive -> "temp_update"), asi que buscarla por ".tar"
                # NO vale. Criterio robusto: si la 1a pasada dejo UN unico fichero y
                # ese no es instalable (AppImage o binario nativo), es el tar -> se
                # extrae tambien.
                internos = []
                for root, dirs, files in os.walk(temp_extract_dir):
                    for file in files:
                        internos.append(os.path.join(root, file))
                if len(internos) == 1:
                    unico = internos[0]
                    if (not unico.lower().endswith(".appimage")
                            and os.path.basename(unico).lower() not in NATIVOS):
                        try:
                            subprocess.run(["7z", "x", unico, "-y",
                                            f"-o{temp_extract_dir}"],
                                           check=True, capture_output=True, timeout=180)
                            os.remove(unico)
                        except Exception:
                            pass

                # Find extracted AppImage (o binario nativo, ver NATIVOS)
                extracted_appimage = None
                es_nativo = False
                for root, dirs, files in os.walk(temp_extract_dir):
                    for file in files:
                        if file.lower().endswith(".appimage"):
                            extracted_appimage = os.path.join(root, file)
                            break
                        if file.lower() in NATIVOS:
                            extracted_appimage = os.path.join(root, file)
                            es_nativo = True
                            break
                    if extracted_appimage:
                        break

                if extracted_appimage is None:
                    self.state = "EMU_MENU"
                    self.status_msg = "❌ No se encontró ningún archivo .AppImage dentro del comprimido."
                    self._cleanup_temp(app, temp_file)
                    if backup_path and os.path.exists(backup_path):
                        shutil.move(backup_path, appimage_path)
                    return

                # Move to final location
                if es_nativo:
                    # Nativo: copiar el arbol extraido ENTERO a la carpeta del
                    # emulador (RetroArch trae el binario y sus ficheros al lado).
                    for item in os.listdir(temp_extract_dir):
                        src = os.path.join(temp_extract_dir, item)
                        dst = os.path.join(app["path"], item)
                        if os.path.isdir(src):
                            shutil.copytree(src, dst, dirs_exist_ok=True)
                        else:
                            shutil.copy2(src, dst)
                    appimage_path = os.path.join(app["path"],
                                                 os.path.basename(extracted_appimage))
                    app["file"] = os.path.basename(extracted_appimage)
                    app["filename"] = app["file"]
                elif appimage_path is None:
                    appimage_path = os.path.join(app["path"],
                                                 os.path.basename(extracted_appimage))
                    app["file"] = os.path.basename(extracted_appimage)
                    app["filename"] = app["file"]
                os.rename(extracted_appimage, appimage_path)
                os.chmod(appimage_path, 0o755)
                # Cleanup temp
                if os.path.exists(temp_extract_dir):
                    shutil.rmtree(temp_extract_dir, ignore_errors=True)
                # El archivo descargado tambien se borra: en el camino de AppImage
                # se consume con el rename, pero en el de archivo/nativo se quedaba
                # ahi ocupando sitio (RetroArch dejaba 5 MB por instalacion).
                if os.path.exists(temp_file):
                    try:
                        os.remove(temp_file)
                    except Exception:
                        pass
            else:
                # Direct AppImage download, just move
                if appimage_path is None:
                    appimage_path = os.path.join(
                        app["path"], os.path.basename(best_url.split("?")[0]))
                    app["file"] = os.path.basename(appimage_path)
                    app["filename"] = app["file"]
                os.rename(temp_file, appimage_path)
                os.chmod(appimage_path, 0o755)
        except Exception as e:
            self.state = "EMU_MENU"
            self.status_msg = f"❌ Error crítico: {e} (restaurado desde backup)"
            self._cleanup_temp(app, temp_file)
            if backup_path and os.path.exists(backup_path):
                shutil.move(backup_path, appimage_path)
            return

        # Write version file
        try:
            with open(os.path.join(app["path"], ".version"), 'w') as vf:
                vf.write(tag.lstrip("v"))
        except Exception:
            pass

        self._descarga_correcta = True
        app["version"] = tag.lstrip("v")
        app["has_update"] = False
        app["installed"] = True
        # Dejarlo lanzable (lanzar.sh + configs) antes de seguir
        self._preparar_portable(app)
        if self._install_queue:
            # Venimos de "instalacion completa inicial": seguimos con el siguiente
            self._install_done += 1
            self.cancel_requested = False
            self.download_progress = 0.0
            self.download_speed = "0.0 MB/s"
            self.status_msg = (f"OK {app['name']} "
                               f"({self._install_done}/{self._install_total})")
            self._next_queued_install()
            return
        self.state = "SUCCESS"
        self.status_msg = f"¡{app['name']} actualizado con éxito!"
        self.cancel_requested = False
        self.download_progress = 0.0
        self.download_speed = "0.0 MB/s"

        # Remove backup on success
        if backup_path and os.path.exists(backup_path):
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
            ("BIOS / Firmware", "BIOS_MENU"),
            ("Bezels / Overlays", "BEZELS"),
            ("OpenROM (convertir ROMs)", "OPENROM_MENU"),
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
                    # Version / estado: instalado o pendiente de instalar
                    if app.get("installed"):
                        ver_txt = f"v{app['version']}"
                        ver_col = txt_color if is_selected else DIM_COLOR
                    else:
                        ver_txt = f"{app['version']}  -  A para instalar"
                        ver_col = SEL_FG_COLOR if is_selected else WARN_COLOR
                    ver_surf = font_small.render(ver_txt, True, ver_col)
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

            elif self.state == "BIOS_MENU":
                # Estado de las BIOS del usuario: que falta y donde va cada una.
                # El informe lo genera deckstation-bios.sh --check (mismo script
                # que usa Pocknix Tools, para no tener dos logicas).
                title = font_title.render(" BIOS / FIRMWARE", True, ACCENT_COLOR)
                screen.blit(title, (40, 20))
                hint = font_small.render("A/Enter=Repartir   |   Esc/B=Volver", True, DIM_COLOR)
                screen.blit(hint, (40, 58))

                y = 96
                for linea in self._bios_lineas():
                    if not linea.strip():
                        continue
                    if "FALTA" in linea:
                        col = ERROR_COLOR
                    elif " OK" in linea or linea.strip().startswith("SISTEMA"):
                        col = GREEN_COLOR if " OK" in linea else DIM_COLOR
                    elif "parcial" in linea:
                        col = WARN_COLOR
                    else:
                        col = TEXT_COLOR
                    screen.blit(font_small.render(linea[:150], True, col), (40, y))
                    y += 25
                    if y > SCREEN_HEIGHT - 70:
                        break

                if self.status_msg:
                    screen.blit(font_small.render(self.status_msg[:120], True, GREEN_COLOR),
                                (40, SCREEN_HEIGHT - 40))

            elif self.state == "OPENROM_MENU":
                # OpenROM: suite de conversion de ROMs (GUI Flutter + CLI).
                title = font_title.render(" OPENROM", True, ACCENT_COLOR)
                screen.blit(title, (40, 20))
                hint = font_small.render("A/Enter=Seleccionar   |   Esc/B=Volver   |   ↑↓=Navegar", True, DIM_COLOR)
                screen.blit(hint, (40, 58))

                sub = font_small.render("Convierte ROMs a CHD/CSO/ECM/RVZ... (PS1, PS2, GC, Wii, DC)", True, DIM_COLOR)
                screen.blit(sub, (40, 84))

                y = 130
                opciones = self._openrom_opciones()
                for idx, opt in enumerate(opciones):
                    is_sel = (idx == self.openrom_idx)
                    bg = ACCENT_COLOR if is_sel else PANEL_COLOR
                    txt_color = SEL_FG_COLOR if is_sel else TEXT_COLOR
                    pygame.draw.rect(screen, bg, (40, y, 700, 56), border_radius=RADIUS)
                    prefix = ">> " if is_sel else "   "
                    txt_surf = font.render(f"{prefix}{opt}", True, txt_color)
                    screen.blit(txt_surf, (60, y + 10))
                    y += 72

                if self.status_msg:
                    screen.blit(font_small.render(self.status_msg[:120], True, GREEN_COLOR),
                                (40, SCREEN_HEIGHT - 40))

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
                        if self._auto_pick_latest:
                            # Viene de "instalacion completa": no preguntar, la ultima
                            self._auto_pick_latest = False
                            _app = self.apps[app_idx]
                            _repo = None
                            _clave = _app["name"].lower().replace(" ", "").replace("-", "_")
                            for _k, _rd in EXTERNAL_REPOS.items():
                                if _k == _clave or _k == _app["name"].lower():
                                    _repo = _rd
                                    break
                            if _repo:
                                self.start_download(_app, _repo,
                                                    self.available_tags[0]["version"])
                            else:
                                self.status_msg = "❌ No se encontró repo para este emulador."
                                self.state = "SELECT_VERSION"
                        else:
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
                            elif sel == "BIOS_MENU":
                                self.state = "BIOS_MENU"
                            elif sel == "BEZELS":
                                self._lanzar_bezel_master()
                            elif sel == "OPENROM_MENU":
                                self.state = "OPENROM_MENU"
                                self.openrom_idx = 0
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
                            elif sel == "BIOS_MENU":
                                self.state = "BIOS_MENU"
                            elif sel == "BEZELS":
                                self._lanzar_bezel_master()
                            elif sel == "OPENROM_MENU":
                                self.state = "OPENROM_MENU"
                                self.openrom_idx = 0
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
                            self._activate_current()
                        elif event.key == pygame.K_ESCAPE or event.key == pygame.K_BACKSPACE:
                            self.state = "HUB"
                    elif event.type == pygame.JOYBUTTONDOWN:
                        if event.button == 0:  # A
                            self._activate_current()
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

                elif self.state == "BIOS_MENU":
                    if event.type == pygame.KEYDOWN:
                        if event.key in (pygame.K_RETURN, pygame.K_SPACE):
                            self._bios_repartir()
                        elif event.key in (pygame.K_ESCAPE, pygame.K_BACKSPACE):
                            self.state = "HUB"
                    elif event.type == pygame.JOYBUTTONDOWN:
                        if event.button == 0:      # A
                            self._bios_repartir()
                        elif event.button == 1:    # B
                            self.state = "HUB"

                elif self.state == "OPENROM_MENU":
                    if event.type == pygame.KEYDOWN:
                        if event.key == pygame.K_UP:
                            self.openrom_idx = (self.openrom_idx - 1) % len(self._openrom_opciones())
                        elif event.key == pygame.K_DOWN:
                            self.openrom_idx = (self.openrom_idx + 1) % len(self._openrom_opciones())
                        elif event.key in (pygame.K_RETURN, pygame.K_SPACE):
                            self._openrom_ejecutar(self.openrom_idx)
                        elif event.key in (pygame.K_ESCAPE, pygame.K_BACKSPACE):
                            self.state = "HUB"
                    elif event.type == pygame.JOYBUTTONDOWN:
                        if event.button == 0:      # A
                            self._openrom_ejecutar(self.openrom_idx)
                        elif event.button == 1:    # B
                            self.state = "HUB"
                        elif event.button == 11 or event.button == 13:  # DPAD up
                            self.openrom_idx = (self.openrom_idx - 1) % len(self._openrom_opciones())
                        elif event.button == 12 or event.button == 14:  # DPAD down
                            self.openrom_idx = (self.openrom_idx + 1) % len(self._openrom_opciones())
                    elif event.type == pygame.JOYHATMOTION:
                        if event.value[1] > 0:
                            self.openrom_idx = (self.openrom_idx - 1) % len(self._openrom_opciones())
                        elif event.value[1] < 0:
                            self.openrom_idx = (self.openrom_idx + 1) % len(self._openrom_opciones())

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


# ============================================================================
# Modo headless (--install-all): instalacion inicial completa sin interfaz
# ============================================================================

def _repo_de(app):
    """Repo (tipo, ruta) de una app segun git.txt, o None si no esta."""
    clave = app["name"].lower().replace(" ", "").replace("-", "_")
    for k, rd in EXTERNAL_REPOS.items():
        if k == clave or k == app["name"].lower():
            return rd
    return None


def _vigilar_progreso(eng, parar):
    """Refresca en la misma linea el estado de la descarga en curso."""
    ultimo = ""
    while not parar.wait(1.0):
        msg = (eng.status_msg or "").strip()
        if msg and msg != ultimo:
            print(f"      \r      {msg[:78]}", end="", flush=True)
            ultimo = msg


def run_install_all():
    """Instala TODOS los emuladores que falten, SIN interfaz grafica.

    La llama deckstation-setup.sh para la instalacion inicial completa.
    Reutiliza el MISMO motor que la GUI (fetch de releases, eleccion del asset
    aarch64, extraccion, wrapper lanzar.sh y configs), asi no hay dos logicas
    que puedan separarse y una quedarse rota.
    Devuelve 0 si todo fue bien y 1 si algo fallo.
    """
    eng = UpdaterEngine()
    todos = [a for a in eng.apps if not a.get("special")]
    pendientes = [a for a in todos if not a.get("installed")]
    print(f"DeckStation: {len(pendientes)} por instalar de {len(todos)} emuladores.")
    if not pendientes:
        print("DeckStation: ya esta todo instalado, nada que hacer.")
        return 0

    fallidos = []
    for n, app in enumerate(pendientes, 1):
        nombre = app["name"]
        # _cleanup_temp() deja cancel_requested=True tras un fallo, y en modo
        # headless NO hay cola que lo reinicie -> todos los siguientes salian
        # como "Descarga cancelada". Se limpia antes de cada emulador.
        eng.cancel_requested = False
        print(f"\n[{n}/{len(pendientes)}] {nombre}")
        try:
            repo = _repo_de(app)
            if repo is None:
                print("      sin repo en git.txt -> se omite")
                fallidos.append(nombre)
                continue
            versiones = eng.fetch_github_releases(nombre)
            if not versiones:
                print("      no se encontraron versiones -> se omite")
                fallidos.append(nombre)
                continue
            tag = versiones[0]["version"]
            print(f"      version: {str(versiones[0].get('name'))[:70]}")
            parar = threading.Event()
            threading.Thread(target=_vigilar_progreso, args=(eng, parar),
                             daemon=True).start()
            eng._download_worker(app, repo, tag)      # sincrono
            parar.set()
            print("")
            if eng._descarga_correcta:
                print("      instalado OK")
            else:
                print(f"      FALLO: {(eng.status_msg or '')[:70]}")
                fallidos.append(nombre)
        except KeyboardInterrupt:
            parar.set()
            print("\n      cancelado por el usuario")
            fallidos.append(nombre)
            break
        except Exception as e:
            print(f"      error inesperado: {type(e).__name__}: {str(e)[:60]}")
            fallidos.append(nombre)

    ok_n = len(pendientes) - len(fallidos)
    print("")
    print("=" * 62)
    print(f"  DeckStation: {ok_n}/{len(pendientes)} emuladores instalados")
    if fallidos:
        print(f"  Fallaron ({len(fallidos)}): {', '.join(fallidos)}")
        print("  Reintentalos desde el Updater (ES-DE -> Updater).")
    print("=" * 62)
    return 0 if not fallidos else 1


def main():
    pygame.key.set_repeat(200, 100)
    eng = UpdaterEngine()
    eng.render_loop()


if __name__ == "__main__":
    if "--install-all" in sys.argv:
        try:
            sys.exit(run_install_all())
        except KeyboardInterrupt:
            print("\nInterrumpido.")
            sys.exit(130)
    error_path = os.path.join(DIR, "error_log.txt")
    try:
        main()
    except SystemExit:
        pass
    except Exception as e:
        with open(error_path, "w", encoding="utf-8") as f:
            traceback.print_exc(file=f)
        print(f"CRASH CRÍTICO: {e}. Revisa error_log.txt en {DIR}")
