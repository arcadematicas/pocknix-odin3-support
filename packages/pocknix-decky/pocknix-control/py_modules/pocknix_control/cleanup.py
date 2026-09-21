"""cleanup.py — Limpieza de cachés y logs (pestaña "Limpieza").

POR QUE ESTA PESTAÑA
  En un handheld el disco es el recurso escaso: las cachés de shaders de Steam
  (DXVK/Vulkan), las de los emuladores y los logs crecen solos y se comen GBs.
  Aqui se ven y se borran de una vez.

REGLA DE ORO: NUNCA se toca una partida ni una configuracion.
  Solo se borran CACÉS, LOGS y TEMPORALES. Todo lo que hay aqui se regenera
  solo (peor caso: unos segundos de tirones mientras se recompilan shaders).
  Si alguna vez se anade una categoria que pueda contener datos del usuario,
  NO va aqui.

OJO (arquitectura del plugin): este Python es un invitado x86_64 bajo FEX, asi
que NO se pueden ejecutar binarios aarch64 directamente (por eso sharing.py y
updates.py usan `systemd-run`). Aqui solo se usan operaciones de fichero de
Python (os.walk/rmtree), que no tienen ese problema. Para `journalctl` y
`pacman` si hace falta pasar por systemd-run.
"""

import glob
import os
import shutil
import threading
from pathlib import Path

from .system import run_cmd

# OJO: este backend corre como ROOT, asi que Path.home() seria /root y no veria
# NINGUNA cache del usuario (Steam, emuladores...). El usuario de Pocknix es fijo
# y vive en /home/deck (misma convencion que mako.py).
HOME = Path("/home/deck")

# Un borrado a la vez: son operaciones largas y el usuario puede pulsar dos veces.
_lock = threading.Lock()

# Raices bajo las que SI se puede borrar. Cualquier ruta que no cuelgue de una de
# estas se ignora (cinturon de seguridad: si alguien anade una categoria mal, no
# se lleva por delante algo de fuera).
SAFE_ROOTS = (
    HOME / ".cache",
    HOME / ".steam",
    HOME / ".local" / "share" / "Steam",
    HOME / ".config",
    Path("/var/cache"),
    Path("/var/log"),
    Path("/tmp"),
    Path("/opt/deckstation"),
)


def _steam_roots():
    """Las dos rutas donde Steam puede vivir (depende de como se instalo)."""
    return [
        HOME / ".steam" / "steam",
        HOME / ".local" / "share" / "Steam",
    ]


def _expand(cat):
    """Rutas de una categoria, expandiendo los globs (para los emuladores, cuyas
    cachés viven dentro de carpetas con nombre variable: <Emu>.AppImage.home)."""
    paths = list(cat.get("paths", []))
    for patron in cat.get("globs", []):
        try:
            paths.extend(Path(p) for p in glob.glob(patron))
        except OSError:
            pass
    return paths


def _categories():
    """Categorias de limpieza, con sus rutas. Se recalcula cada vez (rutas vivas)."""
    steam = _steam_roots()
    shadercache = [s / "steamapps" / "shadercache" for s in steam]
    return [
        {
            "id": "steam_shaders",
            "label": "Caché de shaders de Steam",
            "description": "Shaders Vulkan/DXVK de los juegos. Se regenera al jugar (unos segundos de tirones la primera vez).",
            "paths": shadercache + [s / "steamapps" / "compattool" / "shadercache" for s in steam],
        },
        {
            "id": "steam_logs",
            "label": "Logs de Steam",
            "description": "Registros del cliente y de los juegos. No afecta a nada.",
            "paths": [s / "logs" for s in steam] + [s / "dumps" for s in steam],
        },
        {
            "id": "mesa_shaders",
            "label": "Caché de shaders de Mesa",
            "description": "Shaders OpenGL del sistema (Adreno/Turnip). Se regenera solo.",
            "paths": [HOME / ".cache" / "mesa_shader_cache", HOME / ".cache" / "mesa_shader_cache_db"],
        },
        {
            "id": "fex_cache",
            "label": "Caché de FEX",
            "description": "Traducciones x86->ARM ya compiladas. Se regeneran (tarda un poco la primera vez).",
            "paths": [HOME / ".cache" / "fex-emu", HOME / ".fex-emu" / "Cache"],
        },
        {
            "id": "emulator_shaders",
            "label": "Caché de shaders de emuladores",
            "description": "Cachés de Switch (Suyu/Citron/Eden) y demás. Se regeneran al jugar.",
            "paths": [
                HOME / ".local" / "share" / "suyu" / "cache",
                HOME / ".local" / "share" / "citron" / "cache",
                HOME / ".local" / "share" / "eden" / "cache",
                HOME / ".local" / "share" / "yuzu" / "cache",
                HOME / ".cache" / "yuzu",
                HOME / ".cache" / "citron",
            ],
        },
        {
            "id": "deckstation_caches",
            "label": "Caché de emuladores (DeckStation)",
            "description": "Cachés de shaders y temporales de los emuladores (DuckStation, Dolphin, Suyu…). Se regeneran al jugar.",
            # Globs porque cada emulador vive en <Nombre>.AppImage.home, que cambia
            # de nombre segun la version. Solo se tocan .cache y .../cache: NUNCA
            # los .config ni los saves.
            "globs": [
                "/opt/deckstation/Apps/*/*.AppImage.home/.cache",
                "/opt/deckstation/Apps/*/*.AppImage.home/.local/share/*/cache",
                "/opt/deckstation/Apps/*/*.AppImage.home/.local/share/*/Cache",
                "/opt/deckstation/Apps/*/*.AppImage.home/.local/share/*/shader_cache",
                "/opt/deckstation/Apps/*/*.AppImage.home/.local/share/*/ShaderCache",
                "/opt/deckstation/Apps/*/*.AppImage.home/.local/share/*/shaders",
                "/opt/deckstation/Apps/*/*.AppImage.home/.config/*/cache",
                "/opt/deckstation/Apps/*/*.AppImage.home/.config/*/Cache",
                # PSP/Switch guardan ahi sus caches compiladas
                "/opt/deckstation/Apps/*/*.AppImage.home/.config/*/SYSTEM/CACHE",
                "/opt/deckstation/Apps/*/*.AppImage.home/.local/share/*/dump",
            ],
        },
        {
            "id": "wproton_cache",
            "label": "Caché de WProton",
            "description": "Caché de WProton (Proton ARM). Se regenera sola.",
            "paths": [Path("/opt/wproton/cache")],
        },
        {
            "id": "wproton_logs",
            "label": "Logs de WProton",
            "description": "Registros de WProton. No afecta a nada.",
            "paths": [Path("/opt/wproton/logs")],
        },
        {
            "id": "wproton_prefixes",
            "label": "Prefijos de WProton",
            "description": "⚠️ Los prefijos de Wine llevan PARTIDAS y ajustes de los juegos. Libera mucho, pero se pierde todo lo guardado y habrá que reinstalar el prefijo.",
            "paths": [Path("/opt/wproton/prefixes")],
            # Va como avanzada A PROPOSITO: es lo unico de esta pestaña que puede
            # destruir datos del usuario. No se marca por defecto.
            "advanced": True,
        },
        {
            "id": "deckstation_logs",
            "label": "Logs de DeckStation",
            "description": "Registros del front-end y del Updater. No afecta a los emuladores.",
            "paths": [Path("/opt/deckstation/logs")],
        },
        {
            "id": "browser_cache",
            "label": "Caché de navegadores",
            "description": "Caché web de Firefox/Chromium. No borra contraseñas ni sesiones.",
            "paths": [
                HOME / ".cache" / "mozilla",
                HOME / ".cache" / "chromium",
                HOME / ".cache" / "google-chrome",
                HOME / ".cache" / "zen",
                HOME / ".cache" / "BraveSoftware",
            ],
        },
        {
            "id": "thumbnails",
            "label": "Miniaturas y caché gráfica",
            "description": "Miniaturas del escritorio y cachés de Qt/GTK. Se regeneran.",
            "paths": [HOME / ".cache" / "thumbnails", HOME / ".cache" / "kioexec", HOME / ".cache" / "ksvg-elements"],
        },
        {
            "id": "crash_dumps",
            "label": "Volcados de fallos",
            "description": "Core dumps y coredumps del sistema. Ocupan mucho y no sirven para nada normal.",
            "paths": [HOME / ".cache" / "coredumps", Path("/var/lib/systemd/coredump")],
        },
        {
            "id": "pacman_cache",
            "label": "Caché de paquetes (pacman)",
            "description": "Paquetes .pkg ya instalados. Ojo: sin ellos no se puede revertir una actualización sin red.",
            "paths": [Path("/var/cache/pacman/pkg")],
            "advanced": True,
        },
    ]


def _allowed(path: Path) -> bool:
    """Solo se borra dentro de las raices seguras (y nunca una raiz entera)."""
    try:
        real = path.resolve()
    except OSError:
        return False
    for root in SAFE_ROOTS:
        try:
            r = root.resolve()
        except OSError:
            continue
        if real == r:
            return False          # la raiz en si NO se borra, solo su contenido
        if r in real.parents:
            return True
    return False


def _size_of(path: Path, budget=6.0) -> int:
    """Tamano de un arbol en bytes. Con presupuesto de tiempo: un `du` lento no
    puede colgar la pestaña (si se agota, se devuelve lo medido)."""
    if not path.exists():
        return 0
    if path.is_file():
        try:
            return path.stat().st_size
        except OSError:
            return 0
    total = 0
    import time

    t0 = time.monotonic()
    for dirpath, dirnames, filenames in os.walk(path, onerror=lambda e: None):
        for name in filenames:
            try:
                total += os.stat(os.path.join(dirpath, name)).st_size
            except OSError:
                continue
        if time.monotonic() - t0 > budget:
            break
    return total


def scan():
    """Tamano de cada categoria + espacio libre del disco."""
    items = []
    total = 0
    for cat in _categories():
        rutas = _expand(cat)
        size = sum(_size_of(p) for p in rutas)
        # Solo se muestran las que existen: menos ruido y mas claro.
        exists = any(p.exists() for p in rutas)
        if not exists:
            continue
        total += size
        items.append({
            "id": cat["id"],
            "label": cat["label"],
            "description": cat["description"],
            "size": size,
            "advanced": cat.get("advanced", False),
        })
    try:
        st = os.statvfs(str(HOME))
        free = st.f_bavail * st.f_frsize
        disk_total = st.f_blocks * st.f_frsize
    except OSError:
        free = disk_total = 0
    return {"items": items, "total": total, "free": free, "diskTotal": disk_total}


def clean(ids):
    """Borra las categorias indicadas. Devuelve lo liberado y lo que fallo."""
    if not ids:
        return {"freed": 0, "errors": []}
    wanted = set(ids)
    freed = 0
    errors = []
    with _lock:
        for cat in _categories():
            if cat["id"] not in wanted:
                continue
            for path in _expand(cat):
                if not path.exists():
                    continue
                if not _allowed(path):
                    errors.append(f"{path}: fuera de las rutas permitidas")
                    continue
                # Borrar el CONTENIDO, no la carpeta: asi los programas no se
                # encuentran su directorio de cache desaparecido a mitad de uso.
                if path.is_dir():
                    for child in path.iterdir():
                        freed += _size_of(child)
                        try:
                            if child.is_dir() and not child.is_symlink():
                                shutil.rmtree(child, ignore_errors=False)
                            else:
                                child.unlink()
                        except OSError as exc:
                            errors.append(f"{child.name}: {exc.strerror or exc}")
                else:
                    freed += _size_of(path)
                    try:
                        path.unlink()
                    except OSError as exc:
                        errors.append(f"{path.name}: {exc.strerror or exc}")
    # El journal y los coredumps del sistema necesitan binarios aarch64: van por
    # systemd-run (este python es un invitado x86_64 bajo FEX).
    if "crash_dumps" in wanted:
        out = run_cmd(
            ["systemd-run", "--quiet", "--collect", "--wait", "--pipe",
             "journalctl", "--vacuum-time=7d"],
            timeout=60,
        )
        if out is None or out.returncode != 0:
            errors.append("journal: no se pudo limpiar")
    return {"freed": freed, "errors": errors}


def biggest(limit=8):
    """Los directorios que mas ocupan en el home (analizador de disco sencillo).

    Se queda a un nivel util: recorre el home y devuelve las carpetas de primer y
    segundo nivel ordenadas por tamano, que es lo que ayuda a decidir que borrar.
    """
    found = []
    try:
        first = sorted(HOME.iterdir(), key=lambda p: p.name)
    except OSError:
        return []
    for entry in first:
        if not entry.is_dir() or entry.is_symlink():
            continue
        # Dos niveles: en el home lo util casi siempre esta en subcarpetas
        # (~/.local/share, ~/.steam/steam/steamapps...).
        children = []
        try:
            for sub in entry.iterdir():
                if sub.is_dir() and not sub.is_symlink():
                    children.append(sub)
        except OSError:
            children = []
        if children:
            for sub in children:
                size = _size_of(sub, budget=2.0)
                if size > 100 * 1024 * 1024:      # solo lo que pasa de 100 MB
                    found.append({"path": str(sub), "size": size})
        else:
            size = _size_of(entry, budget=2.0)
            if size > 100 * 1024 * 1024:
                found.append({"path": str(entry), "size": size})
    found.sort(key=lambda x: x["size"], reverse=True)
    return found[:limit]
