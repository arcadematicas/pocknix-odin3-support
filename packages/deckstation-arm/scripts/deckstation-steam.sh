#!/bin/bash
# ======================================================================
# deckstation-steam.sh — Añade DeckStation a Steam con sus imágenes
# ======================================================================
# Añade DeckStation como juego NO-Steam en la biblioteca de Steam (modo
# Escritorio) y le pone las imágenes de grid (portada vertical, cabecera,
# hero y logo), igual que hace WProton consigo mismo.
#
# Sin esto, DeckStation no aparece en la biblioteca de Steam y en el modo
# Juego no hay forma de entrar en la emulación sin salir al escritorio.
#
# Uso: deckstation-steam [--force]
#   --force  Re-escribir shortcuts.vdf aunque DeckStation ya esté añadido
#            (por defecto solo se añade si no existe).
#
# NOTA: solo funciona desde el modo Escritorio (en el modo Juego la sesión
# ES Steam y habría que cerrarlo).
# ======================================================================

set -euo pipefail

# ============================================================================
# Configuración
# ============================================================================

DECKSTATION_ROOT="${DECKSTATION_ROOT:-/opt/deckstation}"
ARTE_DIR="${DECKSTATION_ROOT}/arte"
STEAM_ADD_PY="${DECKSTATION_ROOT}/scripts/.steam_add.py"

# El comando que lanza DeckStation (ES-DE) y su nombre en la biblioteca.
DECKSTATION_EXE="/usr/bin/deckstation"
DECKSTATION_NAME="DeckStation"

FORCE=false

# ============================================================================
# Funciones auxiliares
# ============================================================================

say() { printf '%s\n' "$1" >&2; }

# ----------------------------------------------------------------------------
# steam_add.py — helper embebido (patrón WProton, GPL, autoría de stshunz)
#   uso: steam_add.py <shortcuts.vdf> <nombre> <exe> <startdir> <launchopts> <icono>
#   uso: steam_add.py appid <exe> <nombre>   -> imprime el appid calculado
# ----------------------------------------------------------------------------
write_steam_add() {
    grep -q "DECKSTATION_HELPER steam_add.py 3f6725b2040c" "$STEAM_ADD_PY" 2>/dev/null && return 0
    cat > "$STEAM_ADD_PY" <<'SAEOF'
# DECKSTATION_HELPER steam_add.py 3f6725b2040c
#!/usr/bin/env python3
# DeckStation - accesos directos de Steam
#
# Adaptado del helper de WProton (Copyright (C) 2026 stshunz y colaboradores),
# licencia GPL v3 o posterior. Mismo formato binario de shortcuts.vdf y mismo
# algoritmo de appid (crc32(EXE+NAME) | 0x80000000).
#
# DECKSTATION_STEAMADD_V1 - anade un acceso directo no-Steam a shortcuts.vdf
# uso: steam_add.py <shortcuts.vdf> <nombre> <exe> <startdir> <launchopts> <icono>
# uso: steam_add.py appid <exe> <nombre>   -> imprime el appid calculado
import sys, os, struct, zlib

def appid_acceso_directo(exe, nombre):
    return (zlib.crc32((exe + nombre).encode()) | 0x80000000) & 0xFFFFFFFF

if sys.argv[1] == "appid":
    print(appid_acceso_directo(sys.argv[2], sys.argv[3]))
    sys.exit(0)

VDF, NAME, EXE, STARTDIR, OPTS, ICON = sys.argv[1:7]

def parse(data):
    # parser minimo del VDF binario de shortcuts
    pos = [0]
    def u8():
        b = data[pos[0]]; pos[0] += 1; return b
    def cstr():
        end = data.index(b'\x00', pos[0])
        sres = data[pos[0]:end].decode('utf-8', 'replace')
        pos[0] = end + 1
        return sres
    def obj():
        out = {}
        while True:
            t = u8()
            if t == 0x08:
                return out
            k = cstr()
            if t == 0x00:
                out[k] = obj()
            elif t == 0x01:
                out[k] = cstr()
            elif t == 0x02:
                out[k] = struct.unpack('<I', data[pos[0]:pos[0]+4])[0]
                pos[0] += 4
            else:
                raise ValueError('tipo %d' % t)
    t = u8(); root_key = cstr()
    assert t == 0x00
    return {root_key: obj()}

def ser_obj(d):
    out = b''
    for k, v in d.items():
        kb = k.encode('utf-8') + b'\x00'
        if isinstance(v, dict):
            out += b'\x00' + kb + ser_obj(v) + b'\x08'
        elif isinstance(v, int):
            out += b'\x02' + kb + struct.pack('<I', v & 0xFFFFFFFF)
        else:
            out += b'\x01' + kb + str(v).encode('utf-8') + b'\x00'
    return out

def serialize(root):
    (k, v), = root.items()
    return b'\x00' + k.encode() + b'\x00' + ser_obj(v) + b'\x08\x08'

if os.path.isfile(VDF) and os.path.getsize(VDF) > 2:
    root = parse(open(VDF, 'rb').read())
else:
    root = {'shortcuts': {}}
key = 'shortcuts' if 'shortcuts' in root else list(root)[0]
sc = root[key]

# ya existe uno con el mismo LaunchOptions? -> actualizar en vez de duplicar
idx = None
for i, e in sc.items():
    if isinstance(e, dict) and e.get('LaunchOptions', '') == OPTS:
        idx = i
        break
if idx is None:
    nums = [int(i) for i in sc.keys() if i.isdigit()]
    idx = str(max(nums) + 1 if nums else 0)

appid = appid_acceso_directo(EXE, NAME)
sc[idx] = {
    'appid': appid, 'AppName': NAME, 'Exe': '"%s"' % EXE,
    'StartDir': '"%s"' % STARTDIR, 'icon': ICON, 'ShortcutPath': '',
    'LaunchOptions': OPTS, 'IsHidden': 0, 'AllowDesktopConfig': 1,
    'AllowOverlay': 1, 'OpenVR': 0, 'Devkit': 0, 'DevkitGameID': '',
    'DevkitOverrideAppID': 0, 'LastPlayTime': 0, 'FlatpakAppID': '',
    'tags': {'0': 'DeckStation'},
}
open(VDF, 'wb').write(serialize(root))
print('OK idx=%s appid=%d' % (idx, appid))
SAEOF
}

# ----------------------------------------------------------------------------
# Steam: localizar la config del usuario, saber si está abierto, cerrarlo y
# reabrirlo (mismo patrón que WProton: Steam reescribe shortcuts.vdf al
# salir, así que hay que tocarlo con Steam cerrado).
# ----------------------------------------------------------------------------
find_steam_userdata_config() {
    local base d best="" bestt=0 t
    for base in "$HOME/.steam/steam" "$HOME/.local/share/Steam" \
                "$HOME/.var/app/com.valvesoftware.Steam/.local/share/Steam"; do
        [ -d "$base/userdata" ] || continue
        for d in "$base"/userdata/*/config; do
            [ -d "$d" ] || continue
            t="$(stat -c %Y "$d" 2>/dev/null || echo 0)"
            [ "$t" -gt "$bestt" ] && { bestt=$t; best="$d"; }
        done
    done
    [ -n "$best" ] && printf '%s' "$best"
}

steam_esta_abierto() {
    pgrep -x steam >/dev/null 2>&1
}

steam_cerrar() {
    steam_esta_abierto || return 0
    say "Cerrando Steam..."
    if command -v steam >/dev/null 2>&1; then
        steam -shutdown >/dev/null 2>&1 &
    else
        pkill -x steam 2>/dev/null
    fi
    local i
    for i in $(seq 1 30); do            # hasta 15 segundos
        steam_esta_abierto || { say "[+] Steam cerrado"; sleep 1; return 0; }
        sleep 0.5
    done
    say "AVISO: Steam sigue abierto tras 15 segundos"
    return 1
}

steam_abrir() {
    command -v steam >/dev/null 2>&1 || return 1
    say "Abriendo Steam..."
    nohup steam >/dev/null 2>&1 &
    sleep 1
    return 0
}

# ----------------------------------------------------------------------------
# Imágenes de la biblioteca: las del paquete (arte/) o las de una carpeta
# art/ junto al script (para quien las quiera propias). Sin red ni fallback
# dibujado: las imágenes viajan DENTRO del paquete.
# ----------------------------------------------------------------------------
arte_conseguir() {
    local f faltan=0
    for f in deckstation_p deckstation_header deckstation_hero deckstation_logo deckstation_icono; do
        if [ -s "$ARTE_DIR/$f.png" ]; then
            continue
        elif [ -s "$(dirname "$0")/../art/$f.png" ]; then
            mkdir -p "$ARTE_DIR" 2>/dev/null
            cp -f "$(dirname "$0")/../art/$f.png" "$ARTE_DIR/$f.png" 2>/dev/null && continue
        fi
        faltan=1
    done
    [ "$faltan" = 1 ] && { say "AVISO: faltan imágenes en $ARTE_DIR"; return 1; }
    return 0
}

steam_poner_imagenes() {
    # $1 = carpeta userdata/<id>/config, $2 = appid
    local cfg="$1" appid="$2"
    [ -n "$appid" ] || return 1
    arte_conseguir || return 1
    local grid="$cfg/grid"
    mkdir -p "$grid" || return 1
    # nombres que usa Steam: <appid>p (vertical), <appid> (apaisada),
    # <appid>_hero (cabecera) y <appid>_logo (logotipo encima)
    cp -f "$ARTE_DIR/deckstation_p.png"      "$grid/${appid}p.png"     2>/dev/null
    cp -f "$ARTE_DIR/deckstation_header.png" "$grid/${appid}.png"      2>/dev/null
    cp -f "$ARTE_DIR/deckstation_hero.png"   "$grid/${appid}_hero.png" 2>/dev/null
    cp -f "$ARTE_DIR/deckstation_logo.png"   "$grid/${appid}_logo.png" 2>/dev/null
    say "[+] Imágenes de la biblioteca puestas (appid $appid)"
    return 0
}

# ============================================================================
# Main
# ============================================================================

main() {
    while [[ $# -gt 0 ]]; do
        case $1 in
            --force) FORCE=true; shift ;;
            --help|-h)
                echo "Uso: deckstation-steam [--force]"
                echo ""
                echo "Añade DeckStation a Steam (modo Escritorio) con sus imágenes."
                echo ""
                echo "Opciones:"
                echo "  --force   Re-escribir shortcuts.vdf aunque ya esté añadido"
                echo "  --help    Mostrar esta ayuda"
                exit 0
                ;;
            *) echo "Opción desconocida: $1" >&2; exit 1 ;;
        esac
    done

    # Solo desde el modo Escritorio: en el modo Juego la sesión ES Steam.
    # Se comprueba con las variables de la sesión gráfica Y con pgrep (por si
    # se ejecuta por SSH, donde esas variables no existen).
    if [ -n "${GAMESCOPE_WAYLAND_DISPLAY:-}" ] || [ "${XDG_CURRENT_DESKTOP:-}" = "gamescope" ] \
       || pgrep -f gamescope >/dev/null 2>&1; then
        say "ERROR: esto solo se puede hacer desde el modo Escritorio."
        say "En el modo Juego, la sesión ES Steam y habría que cerrarlo."
        exit 1
    fi

    local cfg; cfg="$(find_steam_userdata_config)"
    [ -n "$cfg" ] || { say "ERROR: no se encontró la carpeta de Steam"; exit 1; }

    local reabrir=0
    if steam_esta_abierto; then
        # Transparente: se cierra Steam solo (Steam reescribe shortcuts.vdf al
        # salir, así que hay que tocarlo con Steam cerrado) y se reabre al final.
        say "Steam está abierto: se cierra para añadir DeckStation y se reabre después."
        steam_cerrar || { say "ERROR: no se pudo cerrar Steam"; exit 1; }
        reabrir=1
    fi

    write_steam_add
    local vdf="$cfg/shortcuts.vdf"
    [ -f "$vdf" ] && cp -f "$vdf" "$vdf.deckstation.bak"

    local appid
    appid="$(python3 "$STEAM_ADD_PY" appid "$DECKSTATION_EXE" "$DECKSTATION_NAME")"

    # Si ya está añadido y no se pide --force, no se toca nada.
    if ! $FORCE && [ -f "$vdf" ] && grep -q "DeckStation" "$vdf" 2>/dev/null; then
        say "DeckStation ya está en Steam (usa --force para re-escribirlo)."
        steam_poner_imagenes "$cfg" "$appid" || \
            say "AVISO: no se pudieron poner las imágenes de la biblioteca"
        [ "$reabrir" = 1 ] && steam_abrir
        exit 0
    fi

    if ! python3 "$STEAM_ADD_PY" "$vdf" "$DECKSTATION_NAME" "$DECKSTATION_EXE" \
         "/" "" "$ARTE_DIR/deckstation_icono.png"; then
        say "ERROR: fallo escribiendo shortcuts.vdf"
        [ "$reabrir" = 1 ] && steam_abrir
        exit 1
    fi

    steam_poner_imagenes "$cfg" "$appid" || \
        say "AVISO: no se pudieron poner las imágenes de la biblioteca"

    [ "$reabrir" = 1 ] && steam_abrir

    echo ""
    echo "DeckStation añadido a Steam."
    echo "Lo encontrarás en la sección NO STEAM, con su imagen."
    echo "Desde el modo Juego podrás abrir tu biblioteca sin salir al escritorio."
    echo ""
    return 0
}

main "$@"