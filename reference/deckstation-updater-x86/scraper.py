#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
scraper.py — Modulo de escrapeo para DeckStation
Conecta con ScreenScraper.fr para descargar caratulas, videos y medios
para ES-DE (EmulationStation Desktop Edition).

Uso:
    python3 scraper.py                    # Modo interactivo (UI Pygame)
    python3 scraper.py --sistema snes     # Escrapeo directo desde terminal
"""

import os
import sys
import json
import time
import hashlib
import logging
import threading
import queue
import random
import xml.etree.ElementTree as ET
from datetime import datetime
from pathlib import Path

import requests

# Configuracion de logging
logger = logging.getLogger("scraper")

# ── Constantes ──────────────────────────────────────────────────────────────

CONFIG_FILE = os.path.expanduser("~/.deckstation_screenscraper.json")

SISTEMAS_SCREENSCRAPER = {
    "snes": 4, "psx": 3, "ps2": 14, "psp": 34,
    "n64": 2, "gba": 12, "gb": 9, "gbc": 10,
    "nds": 15, "3ds": 29, "genesis": 1, "megadrive": 1,
    "mastersystem": 6, "nes": 7, "saturn": 32,
    "dreamcast": 23, "atari2600": 22, "neogeo": 27,
    "mame": 75, "nswitch": 97, "wii": 37, "gamecube": 13,
    "ps3": 109, "xbox": 72, "xbox360": 69,
    "segacd": 20, "pcengine": 31, "ngpc": 28,
    "wonderswan": 45, "wonderswancolor": 46,
}

# Mapeo de tipos de medio ScreenScraper -> directorios ES-DE
MEDIOS_ESDE = {
    "box-2D": "images",
    "box-3D": "box3d",
    "ss": "screenshots",
    "sstitle": "titlescreens",
    "video": "videos",
    "marquee": "marquee",
    "wheel": "wheel",
    "wheel-hd": "wheel",
    "fanart": "fanart",
    "support": "support",
    "screenmarquee": "screenmarquee",
}

# Extensiones de ROM reconocidas por sistema (generalista)
EXTENSIONES_ROM = {
    ".7z", ".zip", ".rar", ".gz", ".chd",
    ".sfc", ".smc", ".fig", ".swc",
    ".nes", ".fds", ".unf",
    ".gba", ".gb", ".gbc",
    ".gen", ".md", ".smd", ".bin",
    ".iso", ".cue", ".img", ".mdf",
    ".n64", ".v64", ".z64",
    ".nds", ".3ds", ".cia",
    ".pce", ".sgx",
    ".a78", ".rom",
    ".lnx", ".jag",
    ".col", ".int",
    ".pck", ".xex",
    ".wbfs", ".wad",
    ".psv", ".pkg",
}

# ── Excepciones ─────────────────────────────────────────────────────────────

class ScraperError(Exception):
    pass

class ScraperAPIError(ScraperError):
    pass

# ── Configuracion ───────────────────────────────────────────────────────────

def cargar_config():
    """Carga configuracion desde ~/.deckstation_screenscraper.json"""
    defaults = {
        "devid": "DeckStation",
        "devpassword": "deckstation123",
        "ssid": "",
        "sspassword": "",
        "softname": "DeckStation",
        "ultimo_sistema": "",
        "media_seleccionados": ["box-2D", "video", "marquee", "wheel"],
        "roms_dir": "/run/media/fransis/8TB/DeckStation/ROMs",
        "motores": 0,  # 0 = auto (4 con cuenta, 1 sin cuenta)
    }
    try:
        if os.path.exists(CONFIG_FILE):
            with open(CONFIG_FILE, "r") as f:
                cfg = json.load(f)
            for k, v in defaults.items():
                cfg.setdefault(k, v)
            return cfg
    except Exception as e:
        logger.warning(f"Error cargando config: {e}")
    return defaults

def guardar_config(cfg):
    """Guarda configuracion"""
    try:
        with open(CONFIG_FILE, "w") as f:
            json.dump(cfg, f, indent=2)
    except Exception as e:
        logger.error(f"Error guardando config: {e}")

# ── ScreenScraper API ──────────────────────────────────────────────────────

class ScreenScraperAPI:
    """Cliente para la API v2 de ScreenScraper.fr"""

    BASE_URL = "https://www.screenscraper.fr/api2/"

    # Rate limiter COMPARTIDO entre todas las instancias (todos los hilos)
    # Esto asegura que las peticiones totales no superen el limite acordado
    _lock_compartido = threading.Lock()
    _ultima_peticion_global = 0
    _intervalo_base = 1.0          # se ajusta segun numero de motores
    _intervalo_actual = None       # None = usar _intervalo_base (se inicializa en __init__)
    _racha_exitosa_global = 0
    _max_intervalo = 6.0

    def __init__(self, devid, devpassword, ssid=None, sspassword=None,
                 softname="DeckStation", thread_id=0, motores_totales=1):
        self.devid = devid
        self.devpassword = devpassword
        self.ssid = ssid or ""
        self.sspassword = sspassword or ""
        self.softname = softname
        self.thread_id = thread_id
        self.session = requests.Session()
        self.session.headers.update({
            "Referer": "https://screenscraper.fr/membreinfos.php",
            "User-Agent": f"{softname}/1.0"
        })
        # Ajustar el intervalo base compartido segun numero de motores
        # Ej: 4 motores → intervalo_base = 0.25s → 4 req/s totales
        with self._lock_compartido:
            nuevo_base = 1.0 / max(1, motores_totales)
            ScreenScraperAPI._intervalo_base = nuevo_base
            # Inicializar o resetear el intervalo actual al base
            actual = ScreenScraperAPI._intervalo_actual
            if actual is None or actual < nuevo_base or actual > nuevo_base * 4:
                ScreenScraperAPI._intervalo_actual = nuevo_base
            logger.info(
                f"[RateLimit] Base={nuevo_base:.3f}s "
                f"Actual={ScreenScraperAPI._intervalo_actual:.3f}s "
                f"({motores_totales} motores)")

    def _esperar_rate_limit(self):
        """Espera COMPARTIDA entre todos los hilos.
        Todos los hilos esperan en el mismo candado, asegurando
        que el total de peticiones no exceda el limite configurado."""
        with self._lock_compartido:
            # Asegurar que _intervalo_actual esta inicializado
            if ScreenScraperAPI._intervalo_actual is None:
                ScreenScraperAPI._intervalo_actual = ScreenScraperAPI._intervalo_base
            ahora = time.time()
            # Anadir jitter ±20% para suavizar
            jitter = random.uniform(0.8, 1.2)
            intervalo = ScreenScraperAPI._intervalo_actual * jitter
            espera = intervalo - (ahora - ScreenScraperAPI._ultima_peticion_global)
            if espera > 0:
                time.sleep(espera)
            ScreenScraperAPI._ultima_peticion_global = time.time()

    @classmethod
    def _notificar_exito(cls):
        """Reduce el intervalo compartido tras exitos consecutivos"""
        with cls._lock_compartido:
            if cls._intervalo_actual is None:
                cls._intervalo_actual = cls._intervalo_base
            cls._racha_exitosa_global += 1
            if cls._racha_exitosa_global >= 10 and cls._intervalo_actual > cls._intervalo_base:
                cls._intervalo_actual = max(
                    cls._intervalo_base,
                    cls._intervalo_actual * 0.9
                )
                cls._racha_exitosa_global = 0
                logger.info(f"[RateLimit] Reduciendo intervalo a "
                            f"{cls._intervalo_actual:.3f}s")

    @classmethod
    def _notificar_error(cls, factor=1.5):
        """Incrementa el intervalo COMPARTIDO ante errores (backoff global)"""
        with cls._lock_compartido:
            if cls._intervalo_actual is None:
                cls._intervalo_actual = cls._intervalo_base
            cls._racha_exitosa_global = 0
            cls._intervalo_actual = min(
                cls._max_intervalo,
                cls._intervalo_actual * factor
            )
            logger.info(f"[RateLimit] Aumentando intervalo a "
                        f"{cls._intervalo_actual:.3f}s")

    def _request(self, endpoint, params=None):
        """Hace una peticion a la API con control de rate limit adaptativo"""
        if params is None:
            params = {}

        # Anadir parametros comunes
        params.update({
            "devid": self.devid,
            "devpassword": self.devpassword,
            "softname": self.softname,
            "output": "json",
        })
        if self.ssid and self.sspassword:
            params["ssid"] = self.ssid
            params["sspassword"] = self.sspassword

        self._esperar_rate_limit()

        url = self.BASE_URL + endpoint
        MAX_INTENTOS = 5  # mas reintentos que antes
        for intento in range(MAX_INTENTOS):
            try:
                resp = self.session.get(url, params=params, timeout=30)
                content_type = resp.headers.get("Content-Type", "")

                # Si la respuesta NO es JSON (HTML de error, rate limit, etc.)
                if "json" not in content_type:
                    status = resp.status_code
                    logger.warning(
                        f"[Hilo-{self.thread_id}] Respuesta no-JSON "
                        f"(HTTP {status}, intento {intento+1}/{MAX_INTENTOS}): "
                        f"{resp.text[:100]}"
                    )
                    # Backoff proporcional al codigo HTTP
                    if status in (429, 503):
                        # Rate limit del servidor: esperar mas
                        espera_backoff = 5.0 * (intento + 1)
                        factor = 3.0
                    elif status in (403, 401):
                        # Acceso denegado
                        logger.error(
                            f"[Hilo-{self.thread_id}] Acceso denegado "
                            f"(HTTP {status}). Verifica credenciales.")
                        self._notificar_error(factor=4.0)
                        return None
                    else:
                        # Error generico
                        espera_backoff = 2.0 * (intento + 1)
                        factor = 2.0
                    logger.info(
                        f"  Esperando {espera_backoff:.0f}s antes de "
                        f"reintentar...")
                    self._notificar_error(factor=factor)
                    time.sleep(espera_backoff)
                    continue

                data = resp.json()

                # Verificar si la API devuelve error (quota, etc.)
                if isinstance(data, dict) and "error" in data:
                    cod = str(data["error"].get("code", ""))
                    if cod in ("403", "429"):
                        retry_after = int(resp.headers.get("Retry-After", 10))
                        logger.warning(
                            f"[Hilo-{self.thread_id}] Quota exceeded. "
                            f"Esperando {retry_after}s...")
                        self._notificar_error(factor=3.0)
                        time.sleep(retry_after)
                        continue
                    logger.error(f"[Hilo-{self.thread_id}] Error API: "
                                 f"{data['error']}")
                    self._notificar_error()
                    return None

                # Exito
                self._notificar_exito()
                return data

            except requests.exceptions.Timeout:
                logger.warning(
                    f"[Hilo-{self.thread_id}] Timeout (intento "
                    f"{intento+1}/{MAX_INTENTOS})")
                self._notificar_error()
                time.sleep(3.0)
            except requests.exceptions.RequestException as e:
                logger.error(
                    f"[Hilo-{self.thread_id}] Error de conexion: {e}")
                self._notificar_error()
                time.sleep(4.0)
            except (json.JSONDecodeError, ValueError) as e:
                logger.warning(
                    f"[Hilo-{self.thread_id}] JSON invalido (intento "
                    f"{intento+1}/{MAX_INTENTOS}): {e}")
                self._notificar_error(factor=1.8)
                if intento < MAX_INTENTOS - 1:
                    time.sleep(3.0 * (intento + 1))
                    continue
                return None

        logger.error(f"[Hilo-{self.thread_id}] Agotados {MAX_INTENTOS} "
                     f"intentos para {endpoint}")
        return None

    def buscar_por_nombre(self, sistema_id, nombre):
        """Busca un juego por nombre en ScreenScraper"""
        data = self._request("jeuRecherche.php", {
            "systemeid": sistema_id,
            "recherche": nombre,
        })
        if not data:
            return []
        try:
            return data.get("jeux", [])
        except (AttributeError, KeyError):
            return []

    def get_jeu_info(self, sistema_id, rom_filename, rom_size,
                     crc=None, md5=None, sha1=None):
        """Obtiene informacion de un juego por sus datos de ROM"""
        params = {
            "systemeid": sistema_id,
            "romnom": rom_filename,
            "romtaille": rom_size,
        }
        if crc:
            params["crc"] = crc
        if md5:
            params["md5"] = md5
        if sha1:
            params["sha1"] = sha1

        data = self._request("jeuInfos.php", params)
        if not data:
            return None
        try:
            return data.get("jeu", None)
        except (AttributeError, KeyError):
            return None

    def get_media_url(self, media_info):
        """Extrae la URL de descarga de un objeto media de ScreenScraper"""
        if isinstance(media_info, dict):
            return media_info.get("url", "")
        return ""

    def calcular_hashes(self, ruta_rom):
        """Calcula CRC (como string hex), MD5 y SHA1 de un archivo"""
        crc_val = None
        md5_val = None
        sha1_val = None
        try:
            with open(ruta_rom, "rb") as f:
                data = f.read()
            sha1_val = hashlib.sha1(data).hexdigest().upper()
            md5_val = hashlib.md5(data).hexdigest().upper()
            # CRC32: usar zlib (incluido en CPython)
            import zlib
            crc_val = format(zlib.crc32(data) & 0xFFFFFFFF, '08X')
        except Exception as e:
            logger.warning(f"Error calculando hashes de {ruta_rom}: {e}")
        return crc_val, md5_val, sha1_val


# ── ES-DE Media Manager ────────────────────────────────────────────────────

class ESDEMediaManager:
    """Gestiona la estructura de medios y gamelist.xml para ES-DE"""

    def __init__(self, roms_dir, sistema):
        self.roms_dir = roms_dir
        self.sistema = sistema
        self.ruta_sistema = os.path.join(roms_dir, sistema)
        self.ruta_media = os.path.join(self.ruta_sistema, "media")

    def listar_roms(self):
        """Escanea el directorio del sistema y devuelve lista de ROMs"""
        roms = []
        if not os.path.isdir(self.ruta_sistema):
            return roms

        for f in sorted(os.listdir(self.ruta_sistema)):
            ruta = os.path.join(self.ruta_sistema, f)
            if not os.path.isfile(ruta):
                continue
            if f.startswith("."):
                continue
            # Extension
            ext = os.path.splitext(f)[1].lower()
            if ext not in EXTENSIONES_ROM:
                continue
            if f.lower() in ("gamelist.xml",):
                continue

            name = os.path.splitext(f)[0]
            size = os.path.getsize(ruta)
            roms.append({
                "filename": f,
                "name": name,
                "path": ruta,
                "size": size,
            })

        return roms

    def media_existentes(self, rom_name):
        """Devuelve los tipos de medio que ya existen para una ROM"""
        existentes = set()
        if not os.path.isdir(self.ruta_media):
            return existentes

        for tipo_ss, directorio in MEDIOS_ESDE.items():
            dir_media = os.path.join(self.ruta_media, directorio)
            if not os.path.isdir(dir_media):
                continue
            for f in os.listdir(dir_media):
                if f.startswith("."):
                    continue
                f_name = os.path.splitext(f)[0]
                if f_name == rom_name:
                    existentes.add(tipo_ss)
                    break

        return existentes

    def get_media_path(self, tipo_ss, rom_name, extension):
        """Devuelve la ruta donde guardar un medio, creando directorios si
        hace falta"""
        directorio = MEDIOS_ESDE.get(tipo_ss)
        if not directorio:
            return None
        dir_path = os.path.join(self.ruta_media, directorio)
        os.makedirs(dir_path, exist_ok=True)
        return os.path.join(dir_path, f"{rom_name}.{extension}")

    def leer_gamelist(self):
        """Lee el gamelist.xml del sistema, devuelve ElementTree o None"""
        ruta = os.path.join(self.ruta_sistema, "gamelist.xml")
        if not os.path.exists(ruta):
            return None
        try:
            tree = ET.parse(ruta)
            return tree
        except ET.ParseError as e:
            logger.warning(f"Error parseando gamelist.xml: {e}")
            return None

    def _sanitizar_rating(self, rating):
        """Convierte el rating al formato ES-DE (0-1)"""
        try:
            r = float(rating)
            if r > 1:
                r = r / 100.0  # ScreenScraper usa 0-100
            return max(0.0, min(1.0, r))
        except (ValueError, TypeError):
            return None

    def _sanitizar_fecha(self, fecha):
        """Convierte fecha ScreenScraper a formato ES-DE (YYYYMMDDTHHMMSS)"""
        if not fecha:
            return None
        # ScreenScraper suele devolver fechas en formato YYYY-MM-DD
        try:
            fecha = fecha.replace("/", "-")
            if len(fecha) == 10 and fecha[4] == "-":
                dt = datetime.strptime(fecha, "%Y-%m-%d")
                return dt.strftime("%Y%m%dT000000")
            return fecha
        except (ValueError, TypeError):
            return fecha

    def actualizar_gamelist(self, juegos_info):
        """
        Actualiza o crea gamelist.xml con los datos de juegos scrapeados.
        `juegos_info` es una lista de dicts con datos de ScreenScraper.
        """
        ruta_gl = os.path.join(self.ruta_sistema, "gamelist.xml")
        tree = self.leer_gamelist()

        if tree is None:
            # Crear nuevo
            root = ET.Element("gameList")
            provider = ET.SubElement(root, "provider")
            ET.SubElement(provider, "System").text = self.sistema.capitalize()
            ET.SubElement(provider, "software").text = "DeckStation Scraper"
            ET.SubElement(provider, "database").text = "ScreenScraper.fr"
            ET.SubElement(provider, "web").text = "http://www.screenscraper.fr"
            tree = ET.ElementTree(root)
        else:
            root = tree.getroot()

        # Indexar juegos existentes por path
        juegos_existentes = {}
        for game_elem in root.findall("game"):
            path_elem = game_elem.find("path")
            if path_elem is not None:
                juegos_existentes[path_elem.text] = game_elem

        for juego in juegos_info:
            juego_data = juego.get("jeu", juego) if isinstance(juego, dict) else {}
            # Obtener nombre de ROM y detalles
            rom_filename = juego.get("rom_filename", "")
            if not rom_filename:
                continue

            path_rel = f"./{rom_filename}"

            # Buscar o crear elemento <game>
            if path_rel in juegos_existentes:
                game_elem = juegos_existentes[path_rel]
            else:
                game_elem = ET.SubElement(root, "game")
                ET.SubElement(game_elem, "path").text = path_rel
                juegos_existentes[path_rel] = game_elem

            # Extraer datos del juego (ScreenScraper estructura)
            info = juego_data.get("infos", juego_data) if isinstance(juego_data, dict) else {}

            # Mapear campos ScreenScraper a ES-DE
            campos = {
                "name": ["noms", "EU", "US", "JP", "nom"],
                "desc": ["synopsis", "synopsis_fr", "synopsis_en",
                         "description", "desc"],
                "rating": ["note", "rating", "score"],
                "releasedate": ["dates", "date", "releasedate"],
                "developer": ["developpeur", "developer", "developers"],
                "publisher": ["editeur", "publisher", "editors"],
                "players": ["joueurs", "players"],
            }

            for campo_esde, posibles in campos.items():
                valor = None
                for key in posibles:
                    v = self._buscar_en_nested(info, key)
                    if v:
                        valor = v
                        break
                if not valor:
                    continue

                if campo_esde == "rating":
                    valor = self._sanitizar_rating(valor)
                    if valor is None:
                        continue
                    valor = str(valor)
                elif campo_esde == "releasedate":
                    valor = self._sanitizar_fecha(valor)
                    if valor is None:
                        continue

                # Buscar si ya existe el elemento
                elem = game_elem.find(campo_esde)
                if elem is not None:
                    # Solo actualizar si esta vacio
                    if not elem.text or not elem.text.strip():
                        elem.text = str(valor)
                else:
                    ET.SubElement(game_elem, campo_esde).text = str(valor)

            # Anadir region
            region = self._buscar_en_nested(info, "region")
            if region:
                elem = game_elem.find("region")
                if elem is not None:
                    if not elem.text:
                        elem.text = str(region)
                else:
                    ET.SubElement(game_elem, "region").text = str(region)

        # Guardar
        self._guardar_xml(tree, ruta_gl)

    def _buscar_en_nested(self, d, key):
        """Busca una clave en un dict anidado y por keys multiples"""
        if not isinstance(d, dict):
            return None
        if key in d:
            val = d[key]
            if isinstance(val, str) and val.strip():
                return val.strip()
            return val
        # Buscar en sub-dicts
        for v in d.values():
            if isinstance(v, dict):
                res = self._buscar_en_nested(v, key)
                if res:
                    return res
            elif isinstance(v, list):
                for item in v:
                    if isinstance(item, dict):
                        res = self._buscar_en_nested(item, key)
                        if res:
                            return res
        return None

    def _guardar_xml(self, tree, ruta):
        """Guarda el XML con formato legible (indentacion)"""
        # Indentar manualmente
        root = tree.getroot()
        self._indentar(root)
        try:
            tree.write(ruta, encoding="utf-8", xml_declaration=True)
            logger.info(f"gamelist.xml guardado: {ruta}")
        except Exception as e:
            logger.error(f"Error guardando gamelist.xml: {e}")

    def _indentar(self, elem, level=0):
        """Anade indentacion legible al XML"""
        i = "\n" + "  " * level
        if len(elem):
            if not elem.text or not elem.text.strip():
                elem.text = i + "  "
            if not elem.tail or not elem.tail.strip():
                elem.tail = i
            for child in elem:
                self._indentar(child, level + 1)
            if not child.tail or not child.tail.strip():
                child.tail = i
        else:
            if level and (not elem.tail or not elem.tail.strip()):
                elem.tail = i


# ── Scraper Principal ──────────────────────────────────────────────────────

class Scraper:
    """Orquesta el proceso de escrapeo completo"""

    def __init__(self, config=None):
        self.config = config or cargar_config()
        self.detener = False
        self.estado = {
            "actual": "",
            "progreso": 0,
            "total": 0,
            "completados": 0,
            "errores": 0,
            "medios_descargados": 0,
        }
        self._estado_lock = threading.Lock()
        # Numero de motores (hilos paralelos)
        # Con cuenta: hasta 6, sin cuenta: solo 1
        self.num_motores = self.config.get("motores", 0)
        if self.num_motores <= 0:
            # Auto-detectar
            if self.config.get("ssid") and self.config.get("sspassword"):
                self.num_motores = 4
            else:
                self.num_motores = 1

    def _crear_api(self, thread_id=0):
        """Crea una nueva instancia de la API (cada hilo necesita la suya)"""
        return ScreenScraperAPI(
            devid=self.config.get("devid", "DeckStation"),
            devpassword=self.config.get("devpassword", "deckstation123"),
            ssid=self.config.get("ssid", ""),
            sspassword=self.config.get("sspassword", ""),
            softname=self.config.get("softname", "DeckStation"),
            thread_id=thread_id,
            motores_totales=self.num_motores,
        )

    def sistemas_disponibles(self):
        """Devuelve los sistemas que tienen ROMs"""
        roms_dir = self.config.get("roms_dir", "")
        if not roms_dir or not os.path.isdir(roms_dir):
            return []
        sistemas = []
        for f in sorted(os.listdir(roms_dir)):
            ruta = os.path.join(roms_dir, f)
            if not os.path.isdir(ruta):
                continue
            if f.startswith("."):
                continue
            if f.lower() in ("$recycle.bin", "aaiherramientas"):
                continue
            # Comprobar si tiene ROMs
            has_roms = False
            for root_dir, _, files in os.walk(ruta):
                for fn in files:
                    ext = os.path.splitext(fn)[1].lower()
                    if ext in EXTENSIONES_ROM:
                        has_roms = True
                        break
                if has_roms:
                    break
            if has_roms:
                sistemas.append(f)
        return sistemas

    def escrapear_sistema(self, sistema, tipos_media=None, solo_faltantes=True,
                          progreso_callback=None):
        """
        Escrapea un sistema completo usando multiples motores (hilos) en paralelo.
        - sistema: nombre del sistema (ej: "snes")
        - tipos_media: lista de tipos de medio a descargar (None=todos)
        - solo_faltantes: si True, solo descarga lo que no existe
        - progreso_callback: funcion a llamar con dict de estado
        """
        sistema_id = SISTEMAS_SCREENSCRAPER.get(sistema)
        if sistema_id is None:
            raise ScraperError(f"Sistema desconocido: {sistema}")

        mm = ESDEMediaManager(self.config.get("roms_dir", ""), sistema)
        roms = mm.listar_roms()
        if not roms:
            raise ScraperError(f"No se encontraron ROMs en {sistema}")

        if tipos_media is None:
            tipos_media = list(MEDIOS_ESDE.keys())

        self.estado["total"] = len(roms)
        self.estado["progreso"] = 0
        self.estado["completados"] = 0
        self.estado["errores"] = 0
        self.estado["medios_descargados"] = 0
        self.detener = False

        juegos_info = []
        juegos_info_lock = threading.Lock()

        motores = self.num_motores
        logger.info(f"Usando {motores} motor(es) para escrapear {len(roms)} ROMs")

        # ── Cola compartida de ROMs ──────────────────────────────────────
        rom_queue = queue.Queue()
        for idx_rom in enumerate(roms):
            rom_queue.put(idx_rom)

        resultados_parciales = [None] * len(roms)  # mantener orden

        def trabajador_motor(tid):
            """Ejecutado en un hilo: procesa ROMs de la cola reutilizando
            la misma instancia de API para todas ellas."""
            api_local = self._crear_api(thread_id=tid)
            logger.info(f"[Motor-{tid}] Arrancado.")

            while not self.detener:
                try:
                    item = rom_queue.get_nowait()
                except queue.Empty:
                    break  # No mas ROMs

                rom_idx, rom = item

                try:
                    # Verificar que medios faltan
                    if solo_faltantes:
                        existentes = mm.media_existentes(rom["name"])
                        tipos_necesarios = [t for t in tipos_media
                                            if t not in existentes]
                    else:
                        tipos_necesarios = tipos_media

                    if not tipos_necesarios:
                        # ROM ya completa
                        with self._estado_lock:
                            self.estado["completados"] += 1
                            self.estado["progreso"] = (
                                self.estado["completados"] + self.estado["errores"]
                            )
                        continue

                    # ── Consultar ScreenScraper ──────────────────────────
                    logger.info(f"[Motor-{tid}] Consultando: {rom['name']}...")

                    # Opcion 1: identificar por hash
                    crc, md5_hash, sha1_hash = api_local.calcular_hashes(rom["path"])

                    juego_data = api_local.get_jeu_info(
                        sistema_id, rom["filename"], rom["size"],
                        crc=crc, md5=md5_hash, sha1=sha1_hash
                    )

                    # Opcion 2: buscar por nombre
                    if juego_data is None:
                        nombre_busqueda = rom["name"]
                        # Intentar con todas las variantes de limpieza
                        nombres_a_probar = [nombre_busqueda]
                        # Quitar parentesis al final: "Juego (info)" -> "Juego"
                        import re
                        nombre_limpio = re.sub(r'\s*\([^)]*\)\s*$', '', nombre_busqueda).strip()
                        if nombre_limpio and nombre_limpio != nombre_busqueda:
                            nombres_a_probar.append(nombre_limpio)
                        # Quitar todo parentesis
                        nombre_mas_limpio = re.sub(r'\s*\([^)]*\)', '', nombre_busqueda).strip()
                        if nombre_mas_limpio and nombre_mas_limpio not in nombres_a_probar:
                            nombres_a_probar.append(nombre_mas_limpio)

                        for n in nombres_a_probar:
                            resultados = api_local.buscar_por_nombre(
                                sistema_id, n)
                            if resultados:
                                juego_data = resultados[0]
                                logger.info(
                                    f"[Motor-{tid}] Encontrado por "
                                    f"nombre '{n}'")
                                break

                    if juego_data is None:
                        logger.warning(
                            f"[Motor-{tid}] No se encontro info para: "
                            f"{rom['name']}")
                        with self._estado_lock:
                            self.estado["errores"] += 1
                            self.estado["completados"] += 1
                            self.estado["progreso"] = (
                                self.estado["completados"] + self.estado["errores"]
                            )
                        continue

                    # ── Descargar medios ─────────────────────────────────
                    medias = juego_data.get("medias", [])
                    if isinstance(medias, dict):
                        medias = [medias]
                    elif not isinstance(medias, list):
                        medias = []

                    tipos_descargados = set()
                    for media in medias:
                        if self.detener or len(tipos_descargados) >= len(tipos_necesarios):
                            break
                        if not isinstance(media, dict):
                            continue
                        tipo = media.get("type", "")
                        if tipo not in tipos_necesarios or tipo in tipos_descargados:
                            continue

                        url = api_local.get_media_url(media)
                        if not url:
                            continue

                        ext = url.rsplit(".", 1)[-1].split("?")[0][:4]
                        if ext not in ("jpg", "jpeg", "png", "gif", "webp",
                                       "mp4", "avi", "mov", "mkv"):
                            ext = "jpg"

                        ruta_destino = mm.get_media_path(
                            tipo, rom["name"], ext)
                        if ruta_destino is None:
                            continue

                        try:
                            self._descargar_media(url, ruta_destino)
                            with self._estado_lock:
                                self.estado["medios_descargados"] += 1
                            tipos_descargados.add(tipo)
                        except Exception as e:
                            logger.warning(
                                f"[Motor-{tid}] Error descargando {tipo} "
                                f"para {rom['name']}: {e}")

                    # Actualizar estado compartido
                    with self._estado_lock:
                        self.estado["completados"] += 1
                        self.estado["progreso"] = (
                            self.estado["completados"] + self.estado["errores"]
                        )

                    if juego_data is not None:
                        resultado = {
                            "jeu": juego_data,
                            "rom_filename": rom["filename"],
                            "rom_idx": rom_idx,
                        }
                        with juegos_info_lock:
                            resultados_parciales[rom_idx] = resultado

                    # Reportar progreso
                    if progreso_callback:
                        with self._estado_lock:
                            est = dict(self.estado)
                            est["actual"] = rom["name"]
                        progreso_callback(est)

                except Exception as e:
                    logger.error(
                        f"[Motor-{tid}] Error procesando {rom['name']}: {e}")
                    with self._estado_lock:
                        self.estado["errores"] += 1
                        self.estado["completados"] += 1
                        self.estado["progreso"] = (
                            self.estado["completados"] + self.estado["errores"]
                        )

            logger.info(f"[Motor-{tid}] Terminado.")

        # ── Lanzar hilos ─────────────────────────────────────────────────
        hilos = []
        for tid in range(motores):
            h = threading.Thread(target=trabajador_motor, args=(tid,),
                                 daemon=True, name=f"scraper-{tid}")
            hilos.append(h)
            h.start()
            # Arranque escalonado: separar salidas 300ms para evitar rafagas
            time.sleep(0.3)

        # Esperar a que terminen
        for h in hilos:
            h.join()

        # Reconstruir juegos_info en orden original
        juegos_info = [r for r in resultados_parciales if r is not None]

        # ── Finalizar ────────────────────────────────────────────────────
        # Actualizar gamelist.xml
        if juegos_info:
            try:
                mm.actualizar_gamelist(juegos_info)
                logger.info(f"gamelist.xml actualizado para {sistema}")
            except Exception as e:
                logger.error(f"Error actualizando gamelist.xml: {e}")

        if progreso_callback:
            self.estado["actual"] = "Completado"
            self.estado["progreso"] = self.estado["total"]
            progreso_callback(dict(self.estado))

        return {
            "total": len(roms),
            "completados": self.estado["completados"],
            "errores": self.estado["errores"],
            "medios": self.estado["medios_descargados"],
        }

    def _descargar_media(self, url, ruta_destino):
        """Descarga un archivo multimedia con la sesion de la API"""
        os.makedirs(os.path.dirname(ruta_destino), exist_ok=True)
        for intento in range(3):
            try:
                resp = self.session.get(url, timeout=60, stream=True)
                resp.raise_for_status()

                # Verificar que no sea HTML de error
                content_type = resp.headers.get("Content-Type", "")
                if "text/html" in content_type:
                    raise ScraperAPIError(
                        "El servidor devolvio HTML en vez de media")

                with open(ruta_destino, "wb") as f:
                    for chunk in resp.iter_content(chunk_size=8192):
                        if chunk:
                            f.write(chunk)

                # Verificar que no este vacio
                if os.path.getsize(ruta_destino) == 0:
                    os.remove(ruta_destino)
                    raise ScraperAPIError("Archivo descargado vacio")

                return  # Exito

            except (requests.exceptions.RequestException,
                    ScraperAPIError) as e:
                if intento < 2:
                    logger.warning(
                        f"  Reintentando descarga media ({intento+2}/3): {e}")
                    time.sleep(2.0 * (intento + 1))
                    continue
                raise


# ── UI Pygame ──────────────────────────────────────────────────────────────

def ejecutar_ui(config):
    """Ejecuta la interfaz grafica Pygame para el scraper"""
    try:
        import pygame
    except ImportError:
        logger.error("pygame no instalado. No se puede usar la UI.")
        print("Error: pygame no instalado. Usa modo terminal con --sistema.")
        return

    pygame.init()
    ANCHO, ALTO = 800, 600
    pantalla = pygame.display.set_mode((ANCHO, ALTO))
    pygame.display.set_caption("DeckStation - ScreenScraper")
    font_grande = pygame.font.Font(None, 36)
    font_media = pygame.font.Font(None, 28)
    font_pequena = pygame.font.Font(None, 22)

    COLOR_BG = (15, 15, 20)
    COLOR_TEXTO = (200, 200, 210)
    COLOR_RESALTO = (255, 200, 50)
    COLOR_ACTIVO = (80, 200, 80)
    COLOR_INACTIVO = (120, 120, 130)
    COLOR_BARRA = (50, 120, 200)
    COLOR_BARRA_FONDO = (30, 30, 40)
    BLANCO = (255, 255, 255)

    scraper = Scraper(config)
    sistemas = scraper.sistemas_disponibles()

    if not sistemas:
        print("No se encontraron sistemas con ROMs.")
        return

    # Estados de la UI
    SELECCION_SISTEMA = 0
    CONFIGURACION = 1
    SCRAPING = 2
    RESUMEN = 3
    CONFIG_CUENTA = 4

    estado_ui = SELECCION_SISTEMA
    selected_idx = 0
    scroll_offset = 0
    max_visibles = 15

    # Tipos de medio disponibles
    tipos_media = list(MEDIOS_ESDE.keys())
    tipos_seleccionados = config.get("media_seleccionados",
                                     ["box-2D", "video", "marquee"])
    modo_faltantes = True

    # Resultado del scraping
    resultado_scrape = None
    progreso_actual = {}

    # Configuracion de cuenta
    cuenta_ssid = config.get("ssid", "")
    cuenta_sspassword = config.get("sspassword", "")
    campo_cuenta_activo = 0  # 0 = ssid, 1 = sspassword
    editando_texto = ""
    editando_campo = False
    mensaje_cuenta = ""

    def render_texto(texto, font, color, x, y, center=False):
        sup = font.render(texto, True, color)
        rect = sup.get_rect()
        if center:
            rect.center = (x, y)
        else:
            rect.topleft = (x, y)
        pantalla.blit(sup, rect)
        return rect

    def render_barra(x, y, ancho, alto, progreso):
        """Dibuja una barra de progreso"""
        pygame.draw.rect(pantalla, COLOR_BARRA_FONDO, (x, y, ancho, alto))
        if progreso > 0:
            ancho_lleno = int(ancho * min(progreso, 1.0))
            pygame.draw.rect(pantalla, COLOR_BARRA,
                             (x, y, ancho_lleno, alto))

    def progreso_callback(estado):
        nonlocal progreso_actual
        progreso_actual = estado

    running = True
    while running:
        pantalla.fill(COLOR_BG)

        for event in pygame.event.get():
            if event.type == pygame.QUIT:
                running = False

            elif event.type == pygame.KEYDOWN:
                if estado_ui == SELECCION_SISTEMA:
                    if event.key == pygame.K_UP:
                        selected_idx = max(0, selected_idx - 1)
                        if selected_idx < scroll_offset:
                            scroll_offset = max(0, scroll_offset - 1)
                    elif event.key == pygame.K_DOWN:
                        selected_idx = min(len(sistemas) - 1,
                                           selected_idx + 1)
                        if selected_idx >= scroll_offset + max_visibles:
                            scroll_offset += 1
                    elif event.key == pygame.K_RETURN:
                        config["ultimo_sistema"] = sistemas[selected_idx]
                        estado_ui = CONFIGURACION
                        selected_idx = 0
                    elif event.key == pygame.K_ESCAPE:
                        running = False
                    elif event.unicode and event.unicode.isalpha():
                        # Navegacion rapida por letra
                        letra = event.unicode.lower()
                        # Buscar desde la posicion actual
                        sistemas_lower = [s.lower() for s in sistemas]
                        # Buscar primero desde selected_idx+1 hasta el final
                        idx = -1
                        start = selected_idx + 1
                        for i in range(start, len(sistemas_lower)):
                            if sistemas_lower[i].startswith(letra):
                                idx = i
                                break
                        # Si no se encontro, buscar desde el principio
                        if idx == -1:
                            for i in range(0, selected_idx):
                                if sistemas_lower[i].startswith(letra):
                                    idx = i
                                    break
                        # Si aun no, buscar que contenga la letra
                        if idx == -1:
                            for i in range(len(sistemas_lower)):
                                if letra in sistemas_lower[i]:
                                    idx = i
                                    break
                        if idx != -1:
                            selected_idx = idx
                            # Ajustar scroll
                            if selected_idx < scroll_offset:
                                scroll_offset = selected_idx
                            elif selected_idx >= scroll_offset + max_visibles:
                                scroll_offset = selected_idx - max_visibles + 1

                elif estado_ui == CONFIGURACION:
                    n_tipos = len(tipos_media)
                    # tipos + faltantes + motores + iniciar + cuenta
                    n_opciones = n_tipos + 4
                    if event.key == pygame.K_UP:
                        selected_idx = max(0, selected_idx - 1)
                    elif event.key == pygame.K_DOWN:
                        selected_idx = min(n_opciones - 1, selected_idx + 1)
                    elif event.key == pygame.K_RETURN:
                        if selected_idx < n_tipos:
                            # Alternar seleccion de tipo de medio
                            t = tipos_media[selected_idx]
                            if t in tipos_seleccionados:
                                tipos_seleccionados.remove(t)
                            else:
                                tipos_seleccionados.append(t)
                        elif selected_idx == n_tipos:
                            modo_faltantes = not modo_faltantes
                        elif selected_idx == n_tipos + 1:
                            # Cambiar numero de motores
                            motores_actual = config.get("motores", 0)
                            # Ciclo: 0 -> 1 -> 2 -> 3 -> 4 -> 5 -> 6 -> 0
                            if motores_actual >= 6:
                                config["motores"] = 0
                            else:
                                config["motores"] = motores_actual + 1
                            guardar_config(config)
                            # Actualizar el scraper existente
                            scraper.config = config
                            if config.get("ssid") and config.get("sspassword"):
                                scraper.num_motores = config["motores"] if config["motores"] > 0 else 4
                            else:
                                scraper.num_motores = config["motores"] if config["motores"] > 0 else 1
                        elif selected_idx == n_tipos + 2:
                            # Iniciar scraping
                            estado_ui = SCRAPING
                            config["media_seleccionados"] = tipos_seleccionados
                            guardar_config(config)

                            # Ejecutar en hilo separado
                            def ejecutar():
                                nonlocal resultado_scrape
                                try:
                                    resultado_scrape = scraper.escrapear_sistema(
                                        config["ultimo_sistema"],
                                        tipos_media=tipos_seleccionados,
                                        solo_faltantes=modo_faltantes,
                                        progreso_callback=progreso_callback,
                                    )
                                except Exception as e:
                                    resultado_scrape = {"error": str(e)}

                            hilo = threading.Thread(target=ejecutar, daemon=True)
                            hilo.start()
                        elif selected_idx == n_tipos + 3:
                            # Ir a configuracion de cuenta
                            estado_ui = CONFIG_CUENTA
                            selected_idx = 0
                            campo_cuenta_activo = 0
                            editando_texto = ""
                            editando_campo = False
                            mensaje_cuenta = ""
                    elif event.key == pygame.K_LEFT and selected_idx == n_tipos + 1:
                        # Reducir motores
                        motores_actual = config.get("motores", 0)
                        if motores_actual <= 0:
                            config["motores"] = 6
                        else:
                            config["motores"] = motores_actual - 1
                        guardar_config(config)
                        scraper.config = config
                        if config.get("ssid") and config.get("sspassword"):
                            scraper.num_motores = config["motores"] if config["motores"] > 0 else 4
                        else:
                            scraper.num_motores = config["motores"] if config["motores"] > 0 else 1
                    elif event.key == pygame.K_RIGHT and selected_idx == n_tipos + 1:
                        # Aumentar motores
                        motores_actual = config.get("motores", 0)
                        if motores_actual >= 6:
                            config["motores"] = 0
                        else:
                            config["motores"] = motores_actual + 1
                        guardar_config(config)
                        scraper.config = config
                        if config.get("ssid") and config.get("sspassword"):
                            scraper.num_motores = config["motores"] if config["motores"] > 0 else 4
                        else:
                            scraper.num_motores = config["motores"] if config["motores"] > 0 else 1
                    elif event.key == pygame.K_ESCAPE:
                        estado_ui = SELECCION_SISTEMA
                        selected_idx = 0

                elif estado_ui == CONFIG_CUENTA:
                    if editando_campo:
                        # Modo edicion de texto
                        if event.key == pygame.K_RETURN:
                            # Confirmar el texto del campo actual
                            if campo_cuenta_activo == 0:
                                cuenta_ssid = editando_texto
                            else:
                                cuenta_sspassword = editando_texto
                            editando_campo = False
                            editando_texto = ""
                        elif event.key == pygame.K_ESCAPE:
                            # Cancelar edicion
                            editando_campo = False
                            editando_texto = ""
                        elif event.key == pygame.K_BACKSPACE:
                            editando_texto = editando_texto[:-1]
                        elif event.unicode and event.unicode.isprintable():
                            editando_texto += event.unicode
                    else:
                        if event.key == pygame.K_UP:
                            campo_cuenta_activo = max(0, campo_cuenta_activo - 1)
                        elif event.key == pygame.K_DOWN:
                            campo_cuenta_activo = min(2, campo_cuenta_activo + 1)
                        elif event.key == pygame.K_RETURN:
                            if campo_cuenta_activo == 0:
                                # Editar usuario
                                editando_campo = True
                                editando_texto = cuenta_ssid
                            elif campo_cuenta_activo == 1:
                                # Editar contrasena
                                editando_campo = True
                                editando_texto = cuenta_sspassword
                            elif campo_cuenta_activo == 2:
                                # Guardar y volver
                                config["ssid"] = cuenta_ssid
                                config["sspassword"] = cuenta_sspassword
                                guardar_config(config)
                                # Recrear api con nuevas credenciales
                                scraper.api = ScreenScraperAPI(
                                    devid=config.get("devid", "DeckStation"),
                                    devpassword=config.get("devpassword", "deckstation123"),
                                    ssid=cuenta_ssid,
                                    sspassword=cuenta_sspassword,
                                    softname=config.get("softname", "DeckStation"),
                                    motores_totales=scraper.num_motores,
                                )
                                # Actualizar motores segun cuenta
                                scraper.config = config
                                if cuenta_ssid and cuenta_sspassword:
                                    scraper.num_motores = config.get("motores", 0)
                                    if scraper.num_motores <= 0:
                                        scraper.num_motores = 4
                                else:
                                    scraper.num_motores = 1
                                mensaje_cuenta = "Cuenta guardada correctamente"
                                estado_ui = CONFIGURACION
                                selected_idx = 0
                        elif event.key == pygame.K_ESCAPE:
                            estado_ui = CONFIGURACION
                            selected_idx = 0

                elif estado_ui == SCRAPING:
                    if event.key == pygame.K_ESCAPE:
                        scraper.detener = True

                elif estado_ui == RESUMEN:
                    if event.key in (pygame.K_ESCAPE, pygame.K_RETURN):
                        estado_ui = SELECCION_SISTEMA
                        selected_idx = 0
                        resultado_scrape = None

            elif event.type == pygame.JOYBUTTONDOWN:
                # Gamepad support basico
                if event.button == 1:  # B button
                    if estado_ui == SCRAPING:
                        scraper.detener = True
                    elif estado_ui in (SELECCION_SISTEMA, CONFIGURACION):
                        running = False
                    elif estado_ui == RESUMEN:
                        estado_ui = SELECCION_SISTEMA

        # ── Renderizado ──────────────────────────────────────────────

        if estado_ui == SELECCION_SISTEMA:
            render_texto("Selecciona sistema:", font_grande, COLOR_RESALTO,
                         ANCHO // 2, 30, center=True)
            render_texto("(↑↓ navegar, Enter confirmar, Esc salir, "
                         "LETRA=saltar a letra)",
                         font_pequena, COLOR_INACTIVO,
                         ANCHO // 2, 60, center=True)

            y = 100
            for i, sis in enumerate(sistemas):
                if i < scroll_offset:
                    continue
                if i >= scroll_offset + max_visibles:
                    break
                color = COLOR_RESALTO if i == selected_idx else COLOR_TEXTO
                prefix = "> " if i == selected_idx else "  "
                render_texto(f"{prefix}{sis}", font_media, color, 50, y)
                y += 32

            # Indicador de teclas rapidas
            render_texto("Pulsa una letra para saltar a esa seccion",
                         font_pequena, COLOR_INACTIVO,
                         ANCHO // 2, ALTO - 20, center=True)

        elif estado_ui == CONFIGURACION:
            sistema = config.get("ultimo_sistema", "")
            render_texto(f"Configurar: {sistema}", font_grande, COLOR_RESALTO,
                         ANCHO // 2, 30, center=True)
            render_texto("(↑↓ navegar, Enter alternar, Esc volver)",
                         font_pequena, COLOR_INACTIVO,
                         ANCHO // 2, 60, center=True)

            y = 100
            # Tipos de medio
            for i, t in enumerate(tipos_media):
                color = COLOR_RESALTO if i == selected_idx else COLOR_TEXTO
                check = "[X]" if t in tipos_seleccionados else "[ ]"
                dir_name = MEDIOS_ESDE.get(t, t)
                render_texto(f"  {check} {t} -> media/{dir_name}/",
                             font_media, color, 50, y)
                y += 28

            # Modo solo faltantes
            y += 10
            i_falt = len(tipos_media)
            color = COLOR_RESALTO if selected_idx == i_falt else COLOR_TEXTO
            txt_falt = "Solo faltantes" if modo_faltantes else "Sobre escribir todo"
            render_texto(f"  [{'X' if modo_faltantes else ' '}] Modo: "
                         f"{txt_falt}", font_media, color, 50, y)

            # Motores (hilos paralelos)
            y += 28
            i_mot = len(tipos_media) + 1
            color = COLOR_RESALTO if selected_idx == i_mot else COLOR_TEXTO
            if config.get("motores", 0) > 0:
                txt_mot = f"{config['motores']} motores"
            elif cuenta_ssid and cuenta_sspassword:
                txt_mot = "4 motores (auto)"
            else:
                txt_mot = "1 motor (auto)"
            render_texto(f"  Motores paralelos: {txt_mot}",
                         font_media, color, 50, y)
            if selected_idx == i_mot:
                render_texto("(← → cambiar, auto si es 0)",
                             font_pequena, COLOR_INACTIVO, 50, y + 22)

            # Boton iniciar
            y += 40
            i_btn = len(tipos_media) + 2
            color = COLOR_RESALTO if selected_idx == i_btn else COLOR_ACTIVO
            render_texto("  [INICIAR SCRAPING]", font_grande, color,
                         ANCHO // 2, y, center=True)

            # Configurar cuenta
            y += 40
            i_cuenta = len(tipos_media) + 3
            color = COLOR_RESALTO if selected_idx == i_cuenta else COLOR_TEXTO
            cuenta_estado = f"({cuenta_ssid})" if cuenta_ssid else "(anonimo)"
            render_texto(f"  Configurar cuenta ScreenScraper {cuenta_estado}",
                         font_media, color, ANCHO // 2, y, center=True)

            # Estado de la cuenta
            if mensaje_cuenta:
                render_texto(mensaje_cuenta, font_pequena, COLOR_ACTIVO,
                             ANCHO // 2, y + 25, center=True)

        elif estado_ui == SCRAPING:
            render_texto("Scrapeando...", font_grande, COLOR_RESALTO,
                         ANCHO // 2, 30, center=True)
            render_texto("(ESC para cancelar)", font_pequena, COLOR_INACTIVO,
                         ANCHO // 2, 60, center=True)

            if progreso_actual:
                total = progreso_actual.get("total", 0)
                progreso = progreso_actual.get("progreso", 0)
                actual = progreso_actual.get("actual", "")
                completados = progreso_actual.get("completados", 0)
                errores = progreso_actual.get("errores", 0)
                medios = progreso_actual.get("medios_descargados", 0)

                bar_ancho = 600
                bar_alto = 30
                bar_x = (ANCHO - bar_ancho) // 2
                bar_y = 150

                frac = progreso / max(total, 1)
                render_barra(bar_x, bar_y, bar_ancho, bar_alto, frac)
                pct = int(frac * 100)
                render_texto(f"{pct}%", font_media, BLANCO,
                             ANCHO // 2, bar_y + bar_alto // 2, center=True)

                y = bar_y + bar_alto + 20
                render_texto(f"ROM: {actual}", font_media, COLOR_TEXTO,
                             50, y)
                y += 30
                render_texto(f"Progreso: {progreso}/{total}", font_media,
                             COLOR_TEXTO, 50, y)
                y += 28
                render_texto(f"Completados: {completados}  |  "
                             f"Errores: {errores}", font_media, COLOR_TEXTO,
                             50, y)
                y += 28
                render_texto(f"Medios descargados: {medios}", font_media,
                             COLOR_TEXTO, 50, y)

                # Verificar si termino
                if scraper.detener:
                    render_texto("CANCELADO", font_grande, (255, 100, 100),
                                 ANCHO // 2, ALTO - 80, center=True)
                elif completados + errores >= total and total > 0:
                    estado_ui = RESUMEN
                    continue

        elif estado_ui == CONFIG_CUENTA:
            render_texto("Configurar cuenta ScreenScraper", font_grande,
                         COLOR_RESALTO, ANCHO // 2, 30, center=True)
            render_texto("(Enter para editar, ↑↓ navegar, Esc volver)",
                         font_pequena, COLOR_INACTIVO,
                         ANCHO // 2, 60, center=True)

            y = 120
            # Campo usuario
            color = COLOR_RESALTO if campo_cuenta_activo == 0 else COLOR_TEXTO
            txt_ssid = cuenta_ssid if cuenta_ssid else "(vacio)"
            if editando_campo and campo_cuenta_activo == 0:
                txt_ssid = editando_texto + "▌"
            render_texto(f"Usuario: {txt_ssid}", font_media, color, 50, y)
            if campo_cuenta_activo == 0 and not editando_campo:
                render_texto("(Introduce tu usuario de screenscraper.fr)",
                             font_pequena, COLOR_INACTIVO, 50, y + 24)

            # Campo contrasena
            y += 50
            color = COLOR_RESALTO if campo_cuenta_activo == 1 else COLOR_TEXTO
            if editando_campo and campo_cuenta_activo == 1:
                # Mostrar asteriscos + cursor
                asteriscos = "*" * len(editando_texto) + "▌"
                txt_pass = asteriscos
            elif cuenta_sspassword:
                txt_pass = "*" * max(4, min(12, len(cuenta_sspassword)))
            else:
                txt_pass = "(vacio)"
            render_texto(f"Contrasena: {txt_pass}", font_media, color, 50, y)
            if campo_cuenta_activo == 1 and not editando_campo:
                render_texto("(Introduce tu contrasena de screenscraper.fr)",
                             font_pequena, COLOR_INACTIVO, 50, y + 24)

            # Boton guardar
            y += 50
            color = COLOR_RESALTO if campo_cuenta_activo == 2 else COLOR_ACTIVO
            render_texto("  [GUARDAR Y VOLVER]", font_media, color,
                         ANCHO // 2, y, center=True)

            # Info
            render_texto("(Deja los campos vacios para modo anonimo)",
                         font_pequena, COLOR_INACTIVO,
                         ANCHO // 2, ALTO - 60, center=True)

        elif estado_ui == RESUMEN:
            render_texto("Scraping completado", font_grande, COLOR_RESALTO,
                         ANCHO // 2, 40, center=True)
            render_texto("(Enter o Esc para continuar)", font_pequena,
                         COLOR_INACTIVO, ANCHO // 2, 70, center=True)

            if isinstance(resultado_scrape, dict):
                if "error" in resultado_scrape:
                    render_texto(f"ERROR: {resultado_scrape['error']}",
                                 font_media, (255, 80, 80),
                                 50, 120)
                else:
                    y = 120
                    render_texto(f"Total ROMs:    "
                                 f"{resultado_scrape.get('total', 0)}",
                                 font_media, COLOR_TEXTO, 50, y)
                    y += 32
                    render_texto(f"Completados:   "
                                 f"{resultado_scrape.get('completados', 0)}",
                                 font_media, COLOR_ACTIVO, 50, y)
                    y += 32
                    render_texto(f"Errores:       "
                                 f"{resultado_scrape.get('errores', 0)}",
                                 font_media, (255, 150, 80), 50, y)
                    y += 32
                    render_texto(f"Medios descargados: "
                                 f"{resultado_scrape.get('medios', 0)}",
                                 font_media, COLOR_RESALTO, 50, y)

        pygame.display.flip()
        pygame.time.wait(50)

    pygame.quit()


# ── Modo terminal (sin UI) ─────────────────────────────────────────────────

def ejecutar_terminal(config, sistema, motores=0):
    """Ejecuta el scraper en modo terminal"""
    if motores > 0:
        config["motores"] = motores
    scraper = Scraper(config)
    print(f"Iniciando scraping de {sistema}...")
    print(f"  ScreenScraper: {config.get('ssid', 'anónimo')}")
    print(f"  Motores: {scraper.num_motores}")
    print()

    sistemas = scraper.sistemas_disponibles()
    if sistema not in sistemas:
        print(f"Error: sistema '{sistema}' no encontrado o sin ROMs.")
        print(f"Sistemas disponibles: {', '.join(sistemas)}")
        return

    def progreso_callback(estado):
        total = estado.get("total", 0)
        progreso = estado.get("progreso", 0)
        actual = estado.get("actual", "")
        pct = int(progreso / max(total, 1) * 100) if total > 0 else 0
        barra = "█" * (pct // 5) + "░" * (20 - pct // 5)
        print(f"\r[{barra}] {pct}%  [{progreso}/{total}] "
              f"{actual[:50]:50}", end="", flush=True)

    try:
        resultado = scraper.escrapear_sistema(
            sistema,
            tipos_media=config.get("media_seleccionados"),
            solo_faltantes=True,
            progreso_callback=progreso_callback,
        )
        print("\n\n✅ Scraping completado:")
        print(f"  Total ROMs:    {resultado['total']}")
        print(f"  Completados:   {resultado['completados']}")
        print(f"  Errores:       {resultado['errores']}")
        print(f"  Medios descargados: {resultado['medios']}")
    except ScraperError as e:
        print(f"\n❌ Error: {e}")
    except KeyboardInterrupt:
        scraper.detener = True
        print("\n\n⚠️  Cancelado por el usuario.")


# ── Punto de entrada ───────────────────────────────────────────────────────

def main():
    """Punto de entrada principal"""
    # Configurar logging
    logging.basicConfig(
        level=logging.INFO,
        format="%(asctime)s - %(name)s - %(levelname)s - %(message)s",
    )

    config = cargar_config()
    motores = 0

    if "--motores" in sys.argv:
        idx = sys.argv.index("--motores")
        if idx + 1 < len(sys.argv):
            try:
                motores = int(sys.argv[idx + 1])
                if motores < 1 or motores > 6:
                    print("⚠️  Los motores deben estar entre 1 y 6. Usando auto.")
                    motores = 0
            except ValueError:
                print("⚠️  Valor de motores invalido. Usando auto.")
                motores = 0

    if "--sistema" in sys.argv:
        idx = sys.argv.index("--sistema")
        if idx + 1 < len(sys.argv):
            sistema = sys.argv[idx + 1]
            ejecutar_terminal(config, sistema, motores)
        else:
            print("Uso: python3 scraper.py [--sistema NOMBRE] [--motores N]")
            sys.exit(1)
    else:
        if motores > 0:
            config["motores"] = motores
        ejecutar_ui(config)


if __name__ == "__main__":
    main()
