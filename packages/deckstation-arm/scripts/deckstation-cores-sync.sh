#!/bin/bash
# ======================================================================
# deckstation-cores-sync.sh — ES-DE: solo cores realmente instalados
# ======================================================================
# ES-DE solo comprueba si el emulador (RetroArch) existe, NO si el core
# .so está instalado. Resultado: en el selector de emulador aparecen
# cores que no tenemos (p. ej. azahar_libretro, tsugaru_libretro...) y
# al lanzarlos fallan.
#
# Este script REGENERA el es_systems.xml ACTIVO (el que usa ES-DE) desde
# el SOURCE (la copia completa del repo), eliminando solo los <command>
# cuyo core %CORE_RETROARCH%/xxx.so no existe en la carpeta portable de
# RetroArch.
#
# Ventajas de regenerar desde el source:
#   - Si mañana se instala un core que hoy falta, el comando reaparece
#     solo (el source conserva todos los comandos).
#   - El activo siempre queda sincronizado con el source (p. ej. el
#     sistema openrom que se añadió y el activo no tenía).
#
# No destructivo: backup del activo en es_systems.xml.bak-cores antes de
# tocar nada. No modifica el source.
#
# Uso: deckstation-cores-sync.sh [--dry-run]
# Lo llaman deckstation-setup.sh y deckstation-launcher.sh.
# ======================================================================
set -u

SELF="$(readlink -f "${BASH_SOURCE[0]}")"
DECKSTATION_ROOT="${DECKSTATION_ROOT:-$(cd "$(dirname "$SELF")/.." && pwd)}"
APPS_DIR="${DECKSTATION_ROOT}/Apps"

DRY=0
while [ $# -gt 0 ]; do
    case "$1" in
        --dry-run) DRY=1 ;;
        -h|--help) sed -n '2,24p' "$SELF"; exit 0 ;;
    esac
    shift
done

log()  { echo "  [cores-sync] $*"; }
warn() { echo "  [cores-sync] AVISO: $*" >&2; }

# Localiza el .home portable de RetroArch (misma logica que deckstation-cores.sh).
resolve_retroarch_home() {
    local dir home img sub base low
    dir="$(find "$APPS_DIR" -maxdepth 1 -type d -iname "retroarch" 2>/dev/null | head -1)"
    [ -n "$dir" ] || return 1
    home="$(find "$dir" -maxdepth 3 -type d -name "*.home" 2>/dev/null | head -1)"
    [ -n "$home" ] && { printf '%s' "$home"; return 0; }
    img="$(find "$dir" -maxdepth 3 -type f \( -iname "*.AppImage" -o -iname "*.appimage" \) 2>/dev/null | head -1)"
    [ -n "$img" ] && { printf '%s' "${img}.home"; return 0; }
    for sub in "$dir"/*/; do
        [ -d "$sub" ] || continue
        base="$(basename "$sub")"
        low="$(printf '%s' "$base" | tr '[:upper:]' '[:lower:]')"
        case "$low" in retroarch*) printf '%s' "${sub%/}.AppImage.home"; return 0 ;; esac
    done
    return 1
}

RA_HOME="$(resolve_retroarch_home)" || {
    log "RetroArch no instalado todavia; nada que filtrar"
    exit 0
}
CORES_DIR="${RA_HOME}/.config/retroarch/cores"

SRC="${DECKSTATION_ROOT}/configs/es-de/custom_systems/es_systems.xml"
ACT="${DECKSTATION_ROOT}/DeckStation.AppImage.home/ES-DE/custom_systems/es_systems.xml"

[ -f "$SRC" ] || { log "No hay source ($SRC); nada que hacer"; exit 0; }
[ -f "$ACT" ] || { log "No hay activo ($ACT); nada que hacer"; exit 0; }

if [ ! -d "$CORES_DIR" ]; then
    log "No hay carpeta de cores ($CORES_DIR); nada que filtrar"
    exit 0
fi

# Backup del activo (una sola vez por generacion).
if [ "$DRY" = 0 ]; then
    cp "$ACT" "$ACT.bak-cores" 2>/dev/null || true
fi

# Filtrar: elimina las lineas <command> cuyo core no existe. Los comandos
# de es_systems.xml son de una sola linea (verificado), asi que el filtro
# linea a linea es seguro.
if [ "$DRY" = 1 ]; then
    python3 - "$CORES_DIR" "$SRC" << 'PYEOF'
import re, os, sys
cores_dir, src = sys.argv[1], sys.argv[2]
with open(src) as f:
    lines = f.readlines()
removed = []
for line in lines:
    m = re.search(r'%CORE_RETROARCH%/([^%/\s"]+\.so)', line)
    if m and not os.path.exists(os.path.join(cores_dir, m.group(1))):
        removed.append(m.group(1))
print("SIMULACION: se eliminarian %d comandos: %s" % (len(removed), ", ".join(sorted(set(removed)))))
PYEOF
else
    python3 - "$CORES_DIR" "$SRC" "$ACT" << 'PYEOF'
import re, os, sys
cores_dir, src, act = sys.argv[1], sys.argv[2], sys.argv[3]
with open(src) as f:
    lines = f.readlines()
out = []
removed = []
for line in lines:
    m = re.search(r'%CORE_RETROARCH%/([^%/\s"]+\.so)', line)
    if m and not os.path.exists(os.path.join(cores_dir, m.group(1))):
        removed.append(m.group(1))
        continue
    out.append(line)
with open(act, 'w') as f:
    f.writelines(out)
print("Eliminados %d comandos con core no instalado: %s" % (len(removed), ", ".join(sorted(set(removed)))))
PYEOF
fi