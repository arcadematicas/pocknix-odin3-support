#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
╔═══════════════════════════════════════════════════════════════╗
║   BezelMaster para DeckStation  (Pygame UI)                 ║
║   Descarga bezels de TheBezelProject y los empareja         ║
║   con tus ROMs usando fuzzy matching + detección de series  ║
║                                                            ║
║   Navegación: ↑↓ / D-Pad  |  A/Enter = Seleccionar        ║
║               Esc/B = Atrás  |  X = Salir                  ║
╚═══════════════════════════════════════════════════════════════╝
"""

import os, sys, re, json, shutil, zipfile, time, threading, difflib, glob
from pathlib import Path
from datetime import datetime, timedelta
import requests

# ─── Pygame ────────────────────────────────────────────────
DIR = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.join(DIR, 'libs'))
py_ver = f"py{sys.version_info.major}.{sys.version_info.minor}"
local_libs = os.path.join(DIR, 'libs', f'libs_{py_ver}')
if os.path.exists(local_libs):
    sys.path.insert(0, local_libs)

import pygame
from pygame.locals import *

# No pedir el teclado en pantalla al compositor (Plasma Mobile lo muestra si una
# app activa el input method de Wayland; SDL lo activa al crear la ventana).
os.environ.setdefault("SDL_HINT_IME_EMBEDDED_TEXT_INPUT", "0")

pygame.init()
pygame.joystick.init()

# ─── Constantes de pantalla ────────────────────────────────
# GUI: pantalla completa (usa la resolucion actual del compositor, ya rotada).
# SCREEN_WIDTH/HEIGHT se usan en todo el dibujado -> definir SIEMPRE.
_info = pygame.display.Info()
SCREEN_WIDTH, SCREEN_HEIGHT = _info.current_w, _info.current_h
screen = pygame.display.set_mode((0, 0), pygame.FULLSCREEN)
try:
    pygame.display.set_caption("BezelMaster para DeckStation")
except pygame.error:
    pass
clock = pygame.time.Clock()

# Colores (como el updater)
BG_COLOR        = (20, 24, 30)
PANEL_COLOR     = (32, 38, 46)
TEXT_COLOR      = (240, 240, 240)
ACCENT_COLOR    = (0, 162, 232)
GREEN_COLOR     = (46, 204, 113)
ERROR_COLOR     = (231, 76, 60)
HUB_BG          = (15, 18, 22)
SUBTLE_COLOR    = (100, 100, 120)

# Fuentes
FONT_PATH = "/usr/share/fonts/TTF/DejaVuSans.ttf"
try:
    if os.path.exists(FONT_PATH):
        font      = pygame.font.Font(FONT_PATH, 28)
        font_title = pygame.font.Font(FONT_PATH, 38)
        font_small = pygame.font.Font(FONT_PATH, 22)
        font_big   = pygame.font.Font(FONT_PATH, 52)
    else:
        raise FileNotFoundError
except Exception:
    font      = pygame.font.SysFont("trebuchetms, arial, sans-serif", 28)
    font_title = pygame.font.SysFont("trebuchetms, arial, sans-serif", 38, bold=True)
    font_small = pygame.font.SysFont("trebuchetms, arial, sans-serif", 22)
    font_big   = pygame.font.SysFont("trebuchetms, arial, sans-serif", 52, bold=True)

# ─── Gamepad ────────────────────────────────────────────────
Joystick = None
for i in range(pygame.joystick.get_count()):
    try:
        js = pygame.joystick.Joystick(i)
        js.init()
        Joystick = js
        break
    except pygame.error:
        continue

# ─── Constantes de DeckStation ─────────────────────────────
# DECK_ROOT se detecta solo: primero la variable de entorno (por si alguien
# tiene DeckStation en otra ruta), luego la instalacion estandar de la Odin
# (/opt/deckstation) y por ultimo la ruta del PC de desarrollo. Antes estaba
# hardcodeada a la del PC, asi que en la Odin BezelMaster no encontraba las
# ROMs y no lanzaba nada.
DECK_ROOT = os.environ.get("DECK_ROOT", "")
if not DECK_ROOT or not os.path.isdir(DECK_ROOT):
    for _cand in ("/opt/deckstation", "/run/media/fransis/8TB/DeckStation"):
        if os.path.isdir(_cand):
            DECK_ROOT = _cand
            break
# La carpeta de ROMs se llama "ROMs" en la Odin y "ROMS" en el PC: se aceptan
# las dos (Linux distingue mayusculas).
ROMS_ROOT = ""
for _cand in (f"{DECK_ROOT}/ROMs", f"{DECK_ROOT}/ROMS"):
    if os.path.isdir(_cand):
        ROMS_ROOT = _cand
        break
if not ROMS_ROOT:
    ROMS_ROOT = f"{DECK_ROOT}/ROMs"
BEZEL_ROOT  = f"{DECK_ROOT}/bezels/arcadematicas/games"
SIMILARITY_THRESHOLD = 0.70

# ─── Aliases de sistemas ───────────────────────────────────
ALIAS_SISTEMAS = {
    "3do": "3do", "amstradcpc": "amstradcpc", "atari2600": "atari2600",
    "atari5200": "atari5200", "atari7800": "atari7800", "atarilynx": "atarilynx",
    "dreamcast": "dreamcast", "gamegear": "gamegear",
    "gb": "gb", "gameboy": "gb", "gba": "gba", "gameboyadvance": "gba",
    "gbc": "gbc", "gameboycolor": "gbc",
    "gc": "gc", "gamecube": "gc", "nintendogamecube": "gc",
    "genesis": "megadrive", "md": "megadrive", "megadrive": "megadrive",
    "mastersystem": "mastersystem", "sms": "mastersystem",
    "n64": "n64", "nintendo64": "n64",
    "nds": "nds", "nintendods": "nds",
    "nes": "nes", "nintendo": "nes", "nintendoentertainmentsystem": "nes",
    "ngp": "ngp", "neogeopocket": "ngp",
    "ngpc": "ngpc", "neogeopocketcolor": "ngpc",
    "pcengine": "pcengine", "tg16": "tg16", "turbografx16": "pcengine",
    "pcfx": "pcfx",
    "ps1": "psx", "psx": "psx", "playstation": "psx",
    "ps2": "ps2", "playstation2": "ps2",
    "psp": "psp", "playstationportable": "psp",
    "saturn": "saturn", "segasaturn": "saturn",
    "sega32x": "sega32x", "32x": "sega32x",
    "segacd": "segacd", "megacd": "segacd",
    "snes": "snes", "supernintendo": "snes", "supernes": "snes",
    "virtualboy": "virtualboy", "vb": "virtualboy",
    "wonderswan": "wonderswan", "ws": "wonderswan",
    "wonderswancolor": "wonderswancolor", "wsc": "wonderswancolor"
}

TRADUCCIONES_CLAVE = {
    "rojo": "red", "roja": "red", "azul": "blue", "amarillo": "yellow",
    "oro": "gold", "plata": "silver", "cristal": "crystal",
    "rubi": "ruby", "zafiro": "sapphire", "esmeralda": "emerald",
    "fuego": "fire", "hoja": "leaf", "verde": "green",
    "leyenda": "legend", "enlace": "link", "despertar": "awakening",
    "pasado": "past", "tiempo": "time", "mundo": "world",
    "hermanos": "bros", "fusion": "fusion", "fantasia": "fantasy",
    "final": "final", "dragon": "dragon", "bola": "ball",
    "guerrero": "warrior", "mision": "quest", "callejero": "street",
    "luchador": "fighter", "sinfonia": "symphony", "noche": "night",
    "edicion": "", "la": "", "el": "", "los": "", "las": "", "de": "",
    "del": "", "y": "", "un": "", "una": "", "unos": "", "unas": "",
    "especial": "", "version": ""
}

SERIES_KEYWORDS = [
    "the legend of zelda", "zelda", "pokemon", "super mario all-stars",
    "super mario bros", "super mario kart", "super mario world",
    "yoshi's island", "yoshi's", "mario kart", "mario", "donkey kong",
    "final fantasy", "dragon ball", "street fighter", "mega man",
    "megaman", "rockman", "castlevania", "metroid", "super metroid",
    "kirby", "contra", "chrono trigger", "secret of mana", "sonic",
    "tetris", "bomberman", "mortal kombat", "king of fighters",
    "earthbound", "mother", "star fox", "f zero", "pilotwings",
    "super punch-out", "punch out", "duck hunt", "balloon fight",
    "kid icarus", "ice climber", "excitebike", "pro wrestling",
    "double dragon", "teenage mutant ninja turtles", "tmnt",
    "ghosts n goblins", "ghouls n ghosts", "gradius", "r type",
    "parodius", "twinbee", "shinobi", "altered beast",
    "golden axe", "streets of rage", "toejam and earl",
    "comix zone", "sparkster", "rocket knight adventures",
    "earthworm jim", "battletoads", "double dragon",
    "simpcity", "sim city", "sim earth", "sim ant",
    "lemmings", "populous", "rainbow islands", "bubble bobble",
    "rainbow six", "theme park", "theme hospital", "transport tycoon",
    "captain commando", "knights of the round", "king of dragons",
    "dungeons and dragons", "capcom", "snk vs capcom",
    "marvel vs capcom", "x men", "spider man", "batman",
    "disney", "tale spin", "ducktales", "chip n dale", "darkwing duck",
    "goof troop", "lion king", "aladdin", "jungle book",
    "fifa", "pro evolution soccer", "winning eleven",
    "madden nfl", "nba jam", "nba live", "nhl", "mario tennis",
    "mario golf", "mario party", "mario picross",
    "wario", "warioware", "yoshi", "yoshi cookery",
    "dr mario", "tetris attack", "panel de pon", "magical drop",
    "puyo puyo", "puzzle bobble", "bust a move",
]

PATRONES_NORMALIZACION = [
    r"\s*\(.+?\)", r"\s*\[.+?\]", r"\s*-\s*", r"[\s_.]+",
    r"^\s*(the|a|an)\s+", r"\s+(the|a|an)\s*$", r"\s+and\s+",
    r"(20[0-9]{2}|19[0-9]{2})\b", r"[^a-zA-Z0-9\s]"
]

EXTENSIONES_ROM = [".zip", ".7z", ".iso", ".chd", ".bin", ".cue", ".img",
    ".sfc", ".smc", ".nes", ".gba", ".gbc", ".gb", ".n64",
    ".z64", ".nds", ".fds", ".3ds", ".wbfs", ".rvz", ".gcm",
    ".gdi", ".cdi", ".pce", ".a26", ".a52", ".a78", ".j64",
    ".lnx", ".gg", ".32x", ".md", ".smd", ".pce", ".atr",
    ".st", ".msx", ".dsk", ".adf", ".hdf", ".cpr", ".jag",
    ".pbp", ".psv", ".m3u", ".wad", ".smdh", ".cia", ".app"]

# =====================================================================
#  FUNCIONES DE LÓGICA (sin Pygame, reutilizables)
# =====================================================================

def normalizar(nombre):
    nombre_lower = nombre.strip().lower()
    # Fase 1: eliminar (USA), [b], años, etc. ANTES de dividir en palabras
    for patron in PATRONES_NORMALIZACION:
        nombre_lower = re.sub(patron, " ", nombre_lower, flags=re.IGNORECASE).strip()
    # Fase 2: dividir, traducir, re-ensamblar
    palabras = re.split(r'[\s_.-]+', nombre_lower)
    traducidas = []
    for p in palabras:
        if not p: continue
        p_limpia = re.sub(r"[^a-zA-Z0-9áéíóúüñ]", "", p)
        if p_limpia in TRADUCCIONES_CLAVE:
            t = TRADUCCIONES_CLAVE[p_limpia]
            if t: traducidas.append(t)
        else:
            traducidas.append(p)
    return "".join(traducidas)

def identificar_serie(nombre_norm):
    for keyword in SERIES_KEYWORDS:
        kw_norm = re.sub(r"\s+", "", keyword)
        if kw_norm in nombre_norm:
            return keyword
    return None

def obtener_repos():
    """Obtiene la lista de repos de TheBezelProject (con caché de 24h)."""
    cache_dir = Path.home() / ".cache" / "bezelmaster"
    cache_dir.mkdir(parents=True, exist_ok=True)
    cache_file = cache_dir / "repos.json"

    if cache_file.exists():
        try:
            data = json.loads(cache_file.read_text())
            if datetime.now() - datetime.fromisoformat(data['ts']) < timedelta(hours=24):
                return data['repos']
        except: pass

    repos = []
    try:
        for page in range(1, 4):
            r = requests.get(
                f"https://api.github.com/users/thebezelproject/repos?per_page=100&page={page}",
                timeout=15
            )
            r.raise_for_status()
            for repo in r.json():
                name = repo['name']
                if name.lower().startswith(('bezelproject-', 'bezelprojectsa-')):
                    repos.append(name)
    except Exception:
        pass

    if not repos:
        # Fallback completo
        fallback = [
            'BezelProject-3DO','BezelProject-Amiga','BezelProject-AmstradCPC',
            'BezelProject-Atari2600','BezelProject-Atari5200','BezelProject-Atari7800',
            'BezelProject-Atari800','BezelProject-AtariJaguar','BezelProject-AtariLynx',
            'BezelProject-AtariST','BezelProject-Atomiswave','BezelProject-C64',
            'BezelProject-CD32','BezelProject-CDiMono1','BezelProject-CDTV',
            'BezelProject-ColecoVision','BezelProject-Daphne','BezelProject-Dreamcast',
            'BezelProject-Famicom','BezelProject-FDS','BezelProject-GameGear',
            'BezelProject-GB','BezelProject-GBA','BezelProject-GBC','BezelProject-GC',
            'BezelProject-GCEVectrex','BezelProject-Intellivision','BezelProject-MAME',
            'BezelProject-MasterSystem','BezelProject-MegaDrive','BezelProject-MSX',
            'BezelProject-MSX2','BezelProject-N3DS','BezelProject-N64',
            'BezelProject-Naomi','BezelProject-NDS','BezelProject-NES',
            'BezelProject-NG-CD','BezelProject-NGP','BezelProject-NGPC',
            'BezelProject-PCE-CD','BezelProject-PCEngine','BezelProject-PCFX',
            'BezelProject-PS2','BezelProject-PSX','BezelProject-Saturn',
            'BezelProject-ScummVM','BezelProject-Sega32X','BezelProject-SegaCD',
            'BezelProject-SFC','BezelProject-SG-1000','BezelProject-SNES',
            'BezelProject-SuperGrafx','BezelProject-TG16','BezelProject-Virtualboy',
            'BezelProject-WonderSwan','BezelProject-WonderSwanColor',
            'BezelProject-X68000','BezelProject-ZXSpectrum',
            'BezelProjectSA-3DO','BezelProjectSA-Amiga','BezelProjectSA-AmstradCPC',
            'BezelProjectSA-Atari2600','BezelProjectSA-Atari5200','BezelProjectSA-Atari7800',
            'BezelProjectSA-Atari800','BezelProjectSA-AtariJaguar','BezelProjectSA-AtariLynx',
            'BezelProjectSA-AtariST','BezelProjectSA-Atomiswave','BezelProjectSA-C64',
            'BezelProjectSA-CD32','BezelProjectSA-CDiMono1','BezelProjectSA-CDTV',
            'BezelProjectSA-ChannelF','BezelProjectSA-ColecoVision','BezelProjectSA-Daphne',
            'BezelProjectSA-Dreamcast','BezelProjectSA-Famicom','BezelProjectSA-FDS',
            'BezelProjectSA-GameGear','BezelProjectSA-GB','BezelProjectSA-GBA',
            'BezelProjectSA-GBC','BezelProjectSA-GC','BezelProjectSA-GCEVectrex',
            'BezelProjectSA-Intellivision','BezelProjectSA-MAME',
            'BezelProjectSA-MasterSystem','BezelProjectSA-MegaDrive','BezelProjectSA-MSX',
            'BezelProjectSA-MSX2','BezelProjectSA-N3DS','BezelProjectSA-N64',
            'BezelProjectSA-Naomi','BezelProjectSA-NDS','BezelProjectSA-NES',
            'BezelProjectSA-NG-CD','BezelProjectSA-NGP','BezelProjectSA-NGPC',
            'BezelProjectSA-PCE-CD','BezelProjectSA-PCEngine','BezelProjectSA-PCFX',
            'BezelProjectSA-PS2','BezelProjectSA-PSP','BezelProjectSA-PSX',
            'BezelProjectSA-Saturn','BezelProjectSA-ScummVM','BezelProjectSA-Sega32X',
            'BezelProjectSA-SegaCD','BezelProjectSA-SFC','BezelProjectSA-SG-1000',
            'BezelProjectSA-SNES','BezelProjectSA-SuperGrafx','BezelProjectSA-TG16',
            'BezelProjectSA-Virtualboy','BezelProjectSA-WonderSwan','BezelProjectSA-WonderSwanColor',
            'BezelProjectSA-X68000','BezelProjectSA-ZXSpectrum',
        ]
        repos = fallback

    repos = sorted(set(repos), key=lambda x: x.lower())
    cache_file.write_text(json.dumps({'ts': datetime.now().isoformat(), 'repos': repos}))
    return repos

def procesar_repos(repos):
    """Agrupa repos: {nombre_limpio: {'normal': repo|None, 'sa': repo|None}}"""
    sistemas = {}
    for r in repos:
        clean = r.lower().replace("bezelproject-", "").replace("bezelprojectsa-", "").strip()
        if clean not in sistemas:
            sistemas[clean] = {'normal': None, 'sa': None}
        if 'sa-' in r.lower():
            sistemas[clean]['sa'] = r
        else:
            sistemas[clean]['normal'] = r
    return dict(sorted(sistemas.items()))

def descargar(repo, destino, progress_callback=None):
    """Descarga un repo y extrae PNGs. progress_callback(pct, msg)."""
    cache_dir = Path.home() / ".cache" / "bezelmaster"
    cache_dir.mkdir(parents=True, exist_ok=True)
    zip_path = cache_dir / f"{repo}.zip"

    if not zip_path.exists():
        if progress_callback:
            progress_callback(0, f"Descargando {repo}...")
        exito = False
        for rama in ["main", "master"]:
            url = f"https://github.com/thebezelproject/{repo}/archive/refs/heads/{rama}.zip"
            try:
                r = requests.get(url, stream=True, timeout=120)
                r.raise_for_status()
                total = int(r.headers.get("content-length", 0))
                dl = 0
                with open(zip_path, "wb") as f:
                    for chunk in r.iter_content(8192):
                        f.write(chunk)
                        dl += len(chunk)
                        if total and progress_callback:
                            progress_callback(int(dl * 90 / total), f"Descargando {repo}... {int(dl*100/total)}%")
                exito = True
                break
            except requests.HTTPError as e:
                if e.response.status_code != 404:
                    if progress_callback:
                        progress_callback(0, f"Error HTTP: {e}")
                    return False
        if not exito:
            if progress_callback:
                progress_callback(0, "No se pudo descargar")
            return False
    else:
        if progress_callback:
            progress_callback(10, "Usando caché de descarga")

    es_sa = 'SA-' in repo.upper()
    destino = Path(destino)
    destino.mkdir(parents=True, exist_ok=True)
    extraidos = 0
    try:
        with zipfile.ZipFile(zip_path) as z:
            # Pre-contar PNGs válidos para barra de progreso real
            miembros = z.infolist()
            total_pngs = 0
            indices_png = []
            for i, member in enumerate(miembros):
                if member.is_dir(): continue
                if not member.filename.lower().endswith('.png'): continue
                if es_sa and '/overlays/' not in member.filename.lower() and '/overlay/' not in member.filename.lower():
                    continue
                total_pngs += 1
                indices_png.append(i)

            if progress_callback and total_pngs > 0:
                progress_callback(90, f"Extrayendo 0/{total_pngs} PNGs...")

            for idx_interno, member_idx in enumerate(indices_png):
                member = miembros[member_idx]
                name = Path(member.filename).name
                if (destino / name).exists(): continue
                with z.open(member) as src, open(destino / name, "wb") as dst:
                    shutil.copyfileobj(src, dst)
                extraidos += 1
                if progress_callback and total_pngs > 0 and (idx_interno % 25 == 0 or idx_interno == len(indices_png) - 1):
                    pct = 90 + int(9 * (idx_interno + 1) / total_pngs)
                    progress_callback(pct, f"Extrayendo {idx_interno+1}/{total_pngs} PNGs...")
    except Exception as e:
        if progress_callback:
            progress_callback(0, f"Error extrayendo: {e}")
        return False

    if progress_callback:
        progress_callback(100, f"{extraidos} bezels extraídos ✓")
    return True

def emparejar(roms_dir, bezel_dir, progress_callback=None):
    """
    Empareja bezels con ROMs. progress_callback(pct, msg).
    Retorna (asignadas, total, sin_coincidencia).
    """
    roms_dir = Path(roms_dir)
    bezel_dir = Path(bezel_dir)

    # Escanear ROMs
    roms = set()
    for f in roms_dir.rglob("*"):
        if f.suffix.lower() in EXTENSIONES_ROM and f.is_file():
            roms.add(f.stem)

    total_roms = len(roms)
    if total_roms == 0:
        return 0, 0, []

    # Escanear bezels
    bezels = {}
    for f in bezel_dir.glob("*.png"):
        bezels[normalizar(f.stem)] = f

    if not bezels:
        return 0, total_roms, list(roms)

    if progress_callback:
        progress_callback(0, f"Emparejando {total_roms} ROMs...")

    # Fase 1: Emparejamiento directo
    asignadas = set()
    map_maestros = {}
    series_map = {}

    roms_sorted = sorted(roms, key=lambda r: len(normalizar(r)))
    for idx, rom in enumerate(roms_sorted):
        if rom in asignadas: continue
        rom_norm = normalizar(rom)
        mejor = None
        mejor_punt = -1
        for bez_norm, bez_path in bezels.items():
            punt = difflib.SequenceMatcher(None, rom_norm, bez_norm).ratio()
            if punt > mejor_punt and punt >= SIMILARITY_THRESHOLD:
                mejor_punt = punt
                mejor = (bez_norm, bez_path)

        if mejor:
            bez_norm, bez_path = mejor
            dst = bezel_dir / f"{rom}.png"
            if bez_path.resolve() != dst.resolve():
                bez_path.rename(dst)
            asignadas.add(rom)
            map_maestros[rom_norm] = dst
            del bezels[bez_norm]

        if progress_callback and idx % 5 == 0:
            progress_callback(int(25 * idx / total_roms), f"Fase 1: {len(asignadas)}/{total_roms}")

    # Mapa de series desde maestros
    for rom_norm, path in map_maestros.items():
        serie = identificar_serie(rom_norm)
        if serie and serie not in series_map:
            series_map[serie] = path

    # Fase 2: Emparejamiento por serie + similitud contra maestros
    no_asignadas = sorted([r for r in roms if r not in asignadas])
    nuevas = 0

    for idx, rom in enumerate(no_asignadas):
        rom_norm = normalizar(rom)
        origen = None

        # Por serie
        serie = identificar_serie(rom_norm)
        if serie and serie in series_map:
            origen = series_map[serie]

        # Por similitud con maestros
        if not origen:
            mejor_punt = -1
            mejor_path = None
            for m_norm, m_path in map_maestros.items():
                punt = difflib.SequenceMatcher(None, rom_norm, m_norm).ratio()
                if punt > mejor_punt and punt >= SIMILARITY_THRESHOLD:
                    mejor_punt = punt
                    mejor_path = m_path
            if mejor_path:
                origen = mejor_path

        # Por substring contra bezels restantes (una palabra clave coincide)
        if not origen and bezels:
            for bez_norm, bez_path in bezels.items():
                # Si el nombre normalizado del ROM está contenido en el bezel, o viceversa
                if (rom_norm in bez_norm and len(rom_norm) >= 4) or \
                   (bez_norm in rom_norm and len(bez_norm) >= 4):
                    origen = bez_path
                    break

        if origen:
            dst_png = bezel_dir / f"{rom}.png"
            if not dst_png.exists():
                try:
                    os.symlink(os.path.relpath(origen, bezel_dir), dst_png)
                except:
                    shutil.copy2(origen, dst_png)
                asignadas.add(rom)
                nuevas += 1

        if progress_callback:
            total_por_hacer = len(no_asignadas)
            pct = 25 + int(70 * (idx + 1) / max(total_por_hacer, 1))
            progress_callback(min(pct, 99), f"Fase 2: {len(asignadas)}/{total_roms}")

    # Sin limpieza: los bezels no matcheados se conservan
    total_bezels = sum(1 for _ in bezel_dir.glob("*.png"))

    if progress_callback:
        extras = total_bezels - len(asignadas)
        msg = f"✔ {len(asignadas)}/{total_roms} ROMs con bezel"
        if extras > 0:
            msg += f"  (+{extras} bezels extra conservados)"
        progress_callback(100, msg)

    sin_coincidencia = [r for r in roms if r not in asignadas]
    return len(asignadas), total_roms, sin_coincidencia

def encontrar_carpeta_roms(sistema):
    """Busca la carpeta de ROMs para un sistema, probando alias."""
    # Directo
    roms_dir = f"{ROMS_ROOT}/{sistema}"
    if os.path.isdir(roms_dir):
        return roms_dir

    # Por alias
    for carpeta in sorted(os.listdir(ROMS_ROOT)):
        c_lower = carpeta.lower()
        if c_lower == sistema:
            return f"{ROMS_ROOT}/{carpeta}"
        if ALIAS_SISTEMAS.get(c_lower) == sistema:
            return f"{ROMS_ROOT}/{carpeta}"
        for k, v in ALIAS_SISTEMAS.items():
            if v == sistema and k == c_lower:
                return f"{ROMS_ROOT}/{carpeta}"
    return None


def _retroarch_config_dir():
    """Devuelve la ruta del config dir de RetroArch o None."""
    if not DECK_ROOT:
        return None
    pattern = os.path.join(DECK_ROOT, "Apps", "RetroArch", "*.home")
    for home_dir in glob.glob(pattern):
        cfg_dir = os.path.join(home_dir, ".config", "retroarch")
        if os.path.isdir(cfg_dir):
            return cfg_dir
    return None


def _cores_del_repo(repo):
    """Devuelve una lista con los nombres de las carpetas de core que trae el zip cacheado."""
    zip_path = Path.home() / ".cache" / "bezelmaster" / f"{repo}.zip"
    if not zip_path.exists():
        return []
    cores = set()
    try:
        with zipfile.ZipFile(zip_path, "r") as z:
            for member in z.namelist():
                if "/retroarch/config/" in member:
                    parts = member.split("/retroarch/config/")
                    if len(parts) > 1:
                        subparts = parts[1].split("/")
                        if subparts and subparts[0]:
                            cores.add(subparts[0])
    except Exception:
        pass
    return sorted(cores)


def _activar_overlay(ra):
    """Asegura que input_overlay_enable = "true" en retroarch.cfg."""
    cfg_path = os.path.join(ra, "retroarch.cfg")
    if not os.path.exists(cfg_path):
        return
    try:
        with open(cfg_path, "r", encoding="utf-8", errors="ignore") as f:
            lines = f.readlines()

        encontrado = False
        nuevas_lineas = []
        for line in lines:
            clave = line.split("=", 1)[0].strip() if "=" in line else ""
            if clave == "input_overlay_enable":
                nuevas_lineas.append('input_overlay_enable = "true"\n')
                encontrado = True
            else:
                nuevas_lineas.append(line)

        if not encontrado:
            nuevas_lineas.append('input_overlay_enable = "true"\n')

        with open(cfg_path, "w", encoding="utf-8") as f:
            f.writelines(nuevas_lineas)
    except Exception:
        pass


def instalar_en_retroarch(roms_dir, bezel_dir, repo, sistema, progress_callback=None):
    """Mueve bezels emparejados desde el workspace a RetroArch y genera sus configs."""
    ra = _retroarch_config_dir()
    if not ra:
        return 0, 0
    cores = _cores_del_repo(repo)
    if not cores:
        return 0, 0

    ov_dir = os.path.join(ra, "overlays", "GameBezels", sistema)
    os.makedirs(ov_dir, exist_ok=True)

    roms_dir = Path(roms_dir)
    bezel_dir = Path(bezel_dir)

    roms = set()
    for f in roms_dir.rglob("*"):
        if f.suffix.lower() in EXTENSIONES_ROM and f.is_file():
            roms.add(f.stem)

    if not roms:
        return 0, 0

    roms_sorted = sorted(roms)
    total_roms = len(roms_sorted)
    n_overlays = 0
    n_configs = 0

    if progress_callback:
        progress_callback(0, f"Instalando en RetroArch ({total_roms} ROMs)...")

    for idx, rom in enumerate(roms_sorted):
        png_src = bezel_dir / f"{rom}.png"
        if png_src.exists():
            try:
                # Mover PNG (los ficheros finales viven en RetroArch, sin duplicar)
                png_dst = os.path.join(ov_dir, f"{rom}.png")
                if os.path.abspath(png_src) != os.path.abspath(png_dst):
                    shutil.move(png_src, png_dst)

                # Escribir cfg de overlay
                cfg_ov_path = os.path.join(ov_dir, f"{rom}.cfg")
                cfg_ov_content = (
                    f"overlays = 1\n\n"
                    f'overlay0_overlay = "{rom}.png"\n\n'
                    f"overlay0_full_screen = true\n\n"
                    f"overlay0_descs = 0\n"
                )
                with open(cfg_ov_path, "w", encoding="utf-8") as f:
                    f.write(cfg_ov_content)
                n_overlays += 1

                # Escribir cfg por core
                overlay_ref_path = f"~/.config/retroarch/overlays/GameBezels/{sistema}/{rom}.cfg"
                for core in cores:
                    core_config_dir = os.path.join(ra, "config", core)
                    os.makedirs(core_config_dir, exist_ok=True)
                    core_cfg_path = os.path.join(core_config_dir, f"{rom}.cfg")
                    core_cfg_content = (
                        f'input_overlay = "{overlay_ref_path}"\n'
                        f'input_overlay_enable = "true"\n'
                    )
                    with open(core_cfg_path, "w", encoding="utf-8") as f:
                        f.write(core_cfg_content)
                    n_configs += 1
            except Exception:
                pass

        if progress_callback and (idx % 25 == 0 or idx == total_roms - 1):
            pct = int(100 * (idx + 1) / total_roms)
            progress_callback(pct, f"RetroArch: {n_overlays} overlays instalados...")

    _activar_overlay(ra)

    if progress_callback:
        progress_callback(100, f"RetroArch: {n_overlays} overlays, {n_configs} configs instalados ✓")

    return n_overlays, n_configs


# =====================================================================
#  UI PYGAME
# =====================================================================

class BezelMasterApp:
    def __init__(self):
        self.state = "LOADING"  # LOADING → SYSTEM_MENU → DOWNLOADING → MATCHING → DONE
        self.sistemas = {}
        self.sistema_keys = []
        self.selected_idx = 0
        self.top_visible = 0
        self.max_visible = 8
        self.overlays_instalados = (0, 0)

        # Sistema + variante seleccionados
        self.selected_sistema = None
        self.selected_repo = None
        self.selected_clean = None
        self.showing_variant = False
        self.variant_idx = 0

        # Progreso
        self.progress = 0
        self.status_msg = "Iniciando..."
        self.result_msg = ""
        self.sin_coincidencia = []

        # Botón de salir
        self.exit_requested = False

        # Cargar en hilo
        self._loading_done = False
        self._loading_error = None
        threading.Thread(target=self._load_worker, daemon=True).start()

    def _load_worker(self):
        try:
            repos = obtener_repos()
            if not repos:
                self._loading_error = "No se pudieron obtener repositorios"
                self._loading_done = True
                return
            self.sistemas = procesar_repos(repos)
            self.sistema_keys = list(self.sistemas.keys())
            self._loading_done = True
        except Exception as e:
            self._loading_error = str(e)
            self._loading_done = True

    def _start_download_and_match(self):
        self.state = "DOWNLOADING"
        self.progress = 0
        self.status_msg = "Preparando..."
        # Para no bloquear, primero descargamos (síncrono en hilo) y luego matcheamos
        threading.Thread(target=self._download_match_worker, daemon=True).start()

    def _download_match_worker(self):
        def on_progress(pct, msg):
            self.progress = pct
            self.status_msg = msg

        clean = self.selected_clean
        repo = self.selected_repo

        bezel_dir = f"{BEZEL_ROOT}/{clean}"
        ok = descargar(repo, bezel_dir, on_progress)
        if not ok:
            self.state = "DONE"
            self.result_msg = f"❌ Error descargando {repo}"
            return

        roms_dir = encontrar_carpeta_roms(clean)
        if not roms_dir:
            self.state = "DONE"
            self.result_msg = f"❌ No se encontró carpeta de ROMs para {clean}"
            return

        self.state = "MATCHING"
        self.progress = 0
        self.status_msg = "Emparejando..."

        asignadas, total, sin_coincidencia = emparejar(roms_dir, bezel_dir, on_progress)
        self.sin_coincidencia = sin_coincidencia

        if total == 0:
            result = f"No se encontraron ROMs en {clean}"
        elif asignadas == total:
            result = f"✔ {asignadas}/{total} ROMs con bezel perfecto"
        else:
            result = f"✔ {asignadas}/{total} ROMs con bezel ({total - asignadas} sin coincidencia)"

        n_ov, n_cfg = instalar_en_retroarch(roms_dir, bezel_dir, repo, clean, on_progress)
        self.overlays_instalados = (n_ov, n_cfg)

        if n_ov > 0:
            result += f" · RetroArch: {n_ov} overlays, {n_cfg} configs"
        else:
            result += " · ⚠ RetroArch no encontrado"

        self.result_msg = result
        self.state = "DONE"

    # ─── Eventos ────────────────────────────────────────────────

    def handle_event(self, event):
        if event.type == QUIT:
            self.exit_requested = True
            return

        if self.state == "SYSTEM_MENU":
            self._handle_system_menu(event)
        elif self.state == "VARIANT":
            self._handle_variant(event)
        elif self.state in ("DOWNLOADING", "MATCHING"):
            self._handle_progress(event)
        elif self.state == "DONE":
            self._handle_done(event)

    def _is_confirm(self, event):
        return (event.type == KEYDOWN and event.key in (K_RETURN, K_SPACE, K_a)) or \
               (event.type == JOYBUTTONDOWN and event.button in (0, 9))  # A button

    def _is_cancel(self, event):
        return (event.type == KEYDOWN and event.key in (K_ESCAPE, K_b, K_x)) or \
               (event.type == JOYBUTTONDOWN and event.button in (1,))  # B button

    def _is_up(self, event):
        return (event.type == KEYDOWN and event.key in (K_UP, K_w)) or \
               (event.type == JOYHATMOTION and event.value[1] == 1) or \
               (event.type == JOYBUTTONDOWN and event.button in (11,))  # D-Pad up

    def _is_down(self, event):
        return (event.type == KEYDOWN and event.key in (K_DOWN, K_s)) or \
               (event.type == JOYHATMOTION and event.value[1] == -1) or \
               (event.type == JOYBUTTONDOWN and event.button in (12,))  # D-Pad down

    def _is_left(self, event):
        return (event.type == KEYDOWN and event.key in (K_LEFT,)) or \
               (event.type == JOYHATMOTION and event.value[0] == -1)

    def _is_right(self, event):
        return (event.type == KEYDOWN and event.key in (K_RIGHT,)) or \
               (event.type == JOYHATMOTION and event.value[0] == 1)

    def _handle_system_menu(self, event):
        n = len(self.sistema_keys)
        if self._is_up(event):
            self.selected_idx = (self.selected_idx - 1) % n
        elif self._is_down(event):
            self.selected_idx = (self.selected_idx + 1) % n
        elif self._is_confirm(event):
            clean = self.sistema_keys[self.selected_idx]
            data = self.sistemas[clean]
            if data['normal'] and data['sa']:
                # Elegir variante
                self.selected_clean = clean
                self.showing_variant = True
                self.variant_idx = 0
                self.state = "VARIANT"
            elif data['normal']:
                self.selected_clean = clean
                self.selected_repo = data['normal']
                self._start_download_and_match()
            elif data['sa']:
                self.selected_clean = clean
                self.selected_repo = data['sa']
                self._start_download_and_match()
        elif self._is_cancel(event):
            self.exit_requested = True

        # Scroll
        if self.selected_idx < self.top_visible:
            self.top_visible = self.selected_idx
        elif self.selected_idx >= self.top_visible + self.max_visible:
            self.top_visible = self.selected_idx - self.max_visible + 1

    def _handle_variant(self, event):
        if self._is_left(event):
            self.variant_idx = 0
        elif self._is_right(event):
            self.variant_idx = 1
        elif self._is_confirm(event):
            data = self.sistemas[self.selected_clean]
            if self.variant_idx == 0 and data['normal']:
                self.selected_repo = data['normal']
            elif self.variant_idx == 1 and data['sa']:
                self.selected_repo = data['sa']
            else:
                # Fallback al que esté disponible
                self.selected_repo = data['normal'] or data['sa']
            self.state = "SYSTEM_MENU"
            self._start_download_and_match()
        elif self._is_cancel(event):
            self.state = "SYSTEM_MENU"
            self.showing_variant = False

    def _handle_progress(self, event):
        if self._is_cancel(event):
            self.status_msg = "Operación cancelada"
            self.state = "DONE"
            self.result_msg = "Cancelado por el usuario"

    def _handle_done(self, event):
        if self._is_confirm(event) or self._is_cancel(event):
            self.state = "SYSTEM_MENU"
            self.selected_idx = 0
            self.top_visible = 0
            self.progress = 0
            self.status_msg = ""
            self.result_msg = ""
            self.sin_coincidencia = []

    # ─── Render ──────────────────────────────────────────────────

    def render(self):
        screen.fill(BG_COLOR)

        if self.state == "LOADING":
            self._render_loading()
        elif self.state == "SYSTEM_MENU":
            self._render_system_menu()
        elif self.state == "VARIANT":
            self._render_variant()
        elif self.state in ("DOWNLOADING", "MATCHING"):
            self._render_progress()
        elif self.state == "DONE":
            self._render_done()

        pygame.display.flip()

    def _render_loading(self):
        y_center = SCREEN_HEIGHT // 2
        titulo = font_big.render("BezelMaster", True, ACCENT_COLOR)
        screen.blit(titulo, (SCREEN_WIDTH // 2 - titulo.get_width() // 2, y_center - 60))

        if self._loading_error:
            msg = font.render(f"❌ {self._loading_error}", True, ERROR_COLOR)
        elif self._loading_done:
            msg = font.render("Cargado ✓", True, GREEN_COLOR)
            if not hasattr(self, '_load_transition'):
                self._load_transition = time.time()
            if time.time() - self._load_transition > 0.5:
                self.state = "SYSTEM_MENU"
        else:
            msg = font.render("Cargando repositorios...", True, TEXT_COLOR)

        screen.blit(msg, (SCREEN_WIDTH // 2 - msg.get_width() // 2, y_center + 20))

    def _render_system_menu(self):
        # Título
        title = font_title.render("🎮 BezelMaster — Selecciona sistema", True, ACCENT_COLOR)
        screen.blit(title, (40, 20))

        # Ayuda
        hint = font_small.render("↑↓ Navegar  |  A/Enter Seleccionar  |  B/Esc Salir", True, SUBTLE_COLOR)
        screen.blit(hint, (40, 62))

        # Sistema en la lista
        visible = self.sistema_keys[self.top_visible:self.top_visible + self.max_visible]
        panel_x, panel_y = 40, 95
        panel_w = SCREEN_WIDTH - 80
        item_h = 70

        for i, clean in enumerate(visible):
            y_pos = panel_y + i * item_h
            actual_idx = self.top_visible + i
            is_sel = (actual_idx == self.selected_idx)
            data = self.sistemas[clean]

            # Fondo
            bg = ACCENT_COLOR if is_sel else PANEL_COLOR
            pygame.draw.rect(screen, bg, (panel_x, y_pos, panel_w, item_h - 4), border_radius=8)

            # Nombre del sistema
            label = clean.upper()
            txt_color = (0, 0, 0) if is_sel else TEXT_COLOR
            name_surf = font.render(label, True, txt_color)
            screen.blit(name_surf, (panel_x + 16, y_pos + 12))

            # Badges de variantes
            badges = []
            if data['normal']: badges.append("N")
            if data['sa']:     badges.append("SA")
            badge_color = (0, 0, 0) if is_sel else ACCENT_COLOR
            badge_surf = font_small.render(f"[{','.join(badges)}]", True, badge_color)
            screen.blit(badge_surf, (panel_x + panel_w - 80, y_pos + 18))

        # Scroll indicators
        if self.top_visible > 0:
            up = font_small.render("▲ Más arriba", True, SUBTLE_COLOR)
            screen.blit(up, (40, 80))
        if self.top_visible + self.max_visible < len(self.sistema_keys):
            down = font_small.render("▼ Más abajo", True, SUBTLE_COLOR)
            screen.blit(down, (40, SCREEN_HEIGHT - 35))

        # Pie con total
        total_txt = font_small.render(f"{len(self.sistema_keys)} sistemas  |  {len([c for c,d in self.sistemas.items() if d['normal']])}N  {len([c for c,d in self.sistemas.items() if d['sa']])}SA", True, SUBTLE_COLOR)
        screen.blit(total_txt, (panel_x + panel_w - total_txt.get_width(), SCREEN_HEIGHT - 35))

    def _render_variant(self):
        data = self.sistemas[self.selected_clean]
        screen.fill(BG_COLOR)

        titulo = font_title.render(f"Elige variante para {self.selected_clean.upper()}", True, ACCENT_COLOR)
        screen.blit(titulo, (SCREEN_WIDTH // 2 - titulo.get_width() // 2, 100))

        hint = font_small.render("← → Cambiar  |  A/Enter Confirmar  |  B/Esc Atrás", True, SUBTLE_COLOR)
        screen.blit(hint, (SCREEN_WIDTH // 2 - hint.get_width() // 2, 150))

        opts = []
        if data['normal']: opts.append(("Normal", data['normal']))
        if data['sa']:     opts.append(("Standalone", data['sa']))

        for idx, (label, _) in enumerate(opts):
            x_center = SCREEN_WIDTH // 2 + (idx - 0.5) * 250
            y_center = 350
            w, h = 220, 100
            is_sel = (idx == self.variant_idx)
            bg = ACCENT_COLOR if is_sel else PANEL_COLOR
            rect = pygame.Rect(x_center - w // 2, y_center - h // 2, w, h)
            pygame.draw.rect(screen, bg, rect, border_radius=16)
            if is_sel:
                pygame.draw.rect(screen, (255, 255, 255), rect, 3, border_radius=16)

            txt = font.render(label, True, (0,0,0) if is_sel else TEXT_COLOR)
            screen.blit(txt, (x_center - txt.get_width() // 2, y_center - txt.get_height() // 2))

        # Flechas visuales
        if self.variant_idx > 0:
            arr = font_big.render("◀", True, TEXT_COLOR)
            screen.blit(arr, (SCREEN_WIDTH // 2 - 280, 330))
        if self.variant_idx < len(opts) - 1:
            arr = font_big.render("▶", True, TEXT_COLOR)
            screen.blit(arr, (SCREEN_WIDTH // 2 + 260, 330))

    def _render_progress(self):
        y_center = SCREEN_HEIGHT // 2
        label = "Descargando..." if self.state == "DOWNLOADING" else "Emparejando..."

        titulo = font_title.render(label, True, ACCENT_COLOR)
        screen.blit(titulo, (SCREEN_WIDTH // 2 - titulo.get_width() // 2, y_center - 80))

        # Mensaje
        msg = font.render(self.status_msg, True, TEXT_COLOR)
        screen.blit(msg, (SCREEN_WIDTH // 2 - msg.get_width() // 2, y_center - 30))

        # Barra de progreso
        bar_w = 600
        bar_h = 30
        bar_x = (SCREEN_WIDTH - bar_w) // 2
        bar_y = y_center + 10
        pygame.draw.rect(screen, PANEL_COLOR, (bar_x, bar_y, bar_w, bar_h), border_radius=6)
        fill_w = int(bar_w * self.progress / 100) if self.progress > 0 else 0
        if fill_w > 0:
            pygame.draw.rect(screen, ACCENT_COLOR, (bar_x, bar_y, fill_w, bar_h), border_radius=6)

        # Porcentaje
        pct = font_small.render(f"{self.progress}%", True, TEXT_COLOR)
        screen.blit(pct, (SCREEN_WIDTH // 2 - pct.get_width() // 2, bar_y + bar_h + 10))

        cancel_hint = font_small.render("Presiona B/Esc para cancelar", True, SUBTLE_COLOR)
        screen.blit(cancel_hint, (SCREEN_WIDTH // 2 - cancel_hint.get_width() // 2, bar_y + bar_h + 40))

    def _render_done(self):
        y_center = SCREEN_HEIGHT // 2 - 40

        # Icono/título según resultado
        if "Error" in self.result_msg or "❌" in self.result_msg:
            icono = "❌"
            color = ERROR_COLOR
        elif "✔" in self.result_msg:
            icono = "✅"
            color = GREEN_COLOR
        else:
            icono = "ℹ️"
            color = TEXT_COLOR

        result = font.render(self.result_msg, True, color)
        screen.blit(result, (SCREEN_WIDTH // 2 - result.get_width() // 2, y_center))

        # Sin coincidencia
        if self.sin_coincidencia and len(self.sin_coincidencia) <= 20:
            y = y_center + 50
            miss = font_small.render("Sin coincidencia:", True, SUBTLE_COLOR)
            screen.blit(miss, (SCREEN_WIDTH // 2 - miss.get_width() // 2, y))
            y += 30
            for rom in self.sin_coincidencia[:10]:
                r = font_small.render(f"  • {rom}", True, TEXT_COLOR)
                screen.blit(r, (SCREEN_WIDTH // 2 - 150, y))
                y += 24
            if len(self.sin_coincidencia) > 10:
                more = font_small.render(f"  ... y {len(self.sin_coincidencia) - 10} más", True, SUBTLE_COLOR)
                screen.blit(more, (SCREEN_WIDTH // 2 - 150, y))
        elif self.sin_coincidencia:
            miss = font_small.render(f"{len(self.sin_coincidencia)} ROMs sin coincidencia (ver _sin_bezel_*.txt)", True, SUBTLE_COLOR)
            screen.blit(miss, (SCREEN_WIDTH // 2 - miss.get_width() // 2, y_center + 50))

        hint = font_small.render("Presiona A/Enter/Espacio para volver al menú", True, SUBTLE_COLOR)
        screen.blit(hint, (SCREEN_WIDTH // 2 - hint.get_width() // 2, SCREEN_HEIGHT - 60))


# =====================================================================
#  MAIN LOOP
# =====================================================================

def main():
    if not os.path.isdir(ROMS_ROOT):
        print(f"❌ No se encuentra {ROMS_ROOT}")
        sys.exit(1)
    os.makedirs(BEZEL_ROOT, exist_ok=True)

    app = BezelMasterApp()
    running = True
    dt_fps = 0
    # Cola de eventos para no perder eventos durante LOADING
    pygame.event.set_allowed(None)
    pygame.event.set_allowed([QUIT, KEYDOWN, KEYUP, JOYBUTTONDOWN, JOYAXISMOTION, JOYHATMOTION])

    while running and not app.exit_requested:
        dt = clock.tick(30)  # 30 FPS es suficiente para este menú
        dt_fps += dt

        # Procesar eventos
        for event in pygame.event.get():
            if event.type == QUIT:
                running = False
                break
            app.handle_event(event)

        # Render
        app.render()

        # Permitir que durante LOADING la transición se haga sola
        if app.state == "LOADING" and app._loading_done:
            # Ya se auto-transiciona en render, pero force un event check
            pass

    pygame.quit()

if __name__ == "__main__":
    main()
