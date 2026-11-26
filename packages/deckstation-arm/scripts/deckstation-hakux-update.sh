#!/bin/bash
# ======================================================================
# deckstation-hakux-update.sh — hakuX-lr directo desde GitHub (usuario)
# ======================================================================
# Baja el ULTIMO release estable de portare-ch/hakuX-lr (tags linux-v*,
# los nightly-* son prerelease y se ignoran) y lo instala como core suelto
# en la carpeta portable de RetroArch de DeckStation. Sin root.
#
# Uso: deckstation-hakux-update.sh [--dry-run] [--force] [--help]
# ======================================================================
set -u

SELF="$(readlink -f "${BASH_SOURCE[0]}")"
DECKSTATION_ROOT="${DECKSTATION_ROOT:-$(cd "$(dirname "$SELF")/.." && pwd)}"
APPS_DIR="${DECKSTATION_ROOT}/Apps"

# Resolucion de rutas copiada de scripts/deckstation-cores.sh (no se importa:
# este script debe funcionar suelto, tambien desde Pocknix Tools).
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

log()   { echo "[hakux] $*"; }
err()   { echo "[hakux] ERROR: $*" >&2; }
usage() {
    sed -n '2,9p' "$SELF"
    echo "  --dry-run  consulta GitHub y muestra que se instalaria, sin escribir"
    echo "  --force    reinstala aunque la version sea la misma"
    echo "  --help     muestra esta ayuda"
}

DRY=0
FORCE=0
while [ $# -gt 0 ]; do
    case "$1" in
        --dry-run) DRY=1 ;;
        --force) FORCE=1 ;;
        -h|--help) usage; exit 0 ;;
        *) err "opcion desconocida: $1"; usage >&2; exit 2 ;;
    esac
    shift
done

for cmd in curl python3 tar; do
    command -v "$cmd" >/dev/null 2>&1 || { err "falta $cmd"; exit 1; }
done

# HAKUX_CORES_DIR permite probar con un destino alternativo (no toca la install).
if [ -n "${HAKUX_CORES_DIR:-}" ]; then
    CORES_DIR="$HAKUX_CORES_DIR"
else
    if RA_HOME="$(resolve_retroarch_home)"; then
        CORES_DIR="${RA_HOME}/.config/retroarch/cores"
    elif [ "$DRY" = 1 ]; then
        # En un repo sin RetroArch instalado, la simulacion igual muestra un destino.
        log "aviso: RetroArch portable no encontrado; destino estimado"
        CORES_DIR="${APPS_DIR}/RetroArch/.config/retroarch/cores"
    else
        err "no se encontro el RetroArch portable en ${APPS_DIR}"
        exit 1
    fi
fi

TMP="$(mktemp -d)" || { err "no se pudo crear el directorio temporal"; exit 1; }
trap 'rm -rf "$TMP"' EXIT

API="https://api.github.com/repos/portare-ch/hakuX-lr/releases?per_page=20"
log "consultando releases de portare-ch/hakuX-lr..."
curl -fsSL --max-time 60 -H 'User-Agent: deckstation-arm-hakux-updater' "$API" -o "$TMP/releases.json" \
    || { err "no se pudo consultar la API de GitHub"; exit 1; }

# Elige el primer release estable con tag linux-v*. Salida: version, nombre del
# asset, URL, nombre del sidecar, URL del sidecar (campos separados por TAB).
python3 - "$TMP/releases.json" > "$TMP/meta" <<'PY' || { err "no se pudo leer la respuesta de GitHub"; exit 1; }
import json, re, sys

try:
    with open(sys.argv[1]) as f:
        releases = json.load(f)
except (OSError, ValueError) as e:
    print("respuesta de GitHub no valida: %s" % e, file=sys.stderr)
    sys.exit(1)
if not isinstance(releases, list):
    print("respuesta de GitHub inesperada", file=sys.stderr)
    sys.exit(1)

for rel in releases:
    if rel.get("prerelease"):
        continue
    tag = rel.get("tag_name", "")
    m = re.match(r"^linux-v(.+)$", tag)
    if not m:
        continue
    version = m.group(1)
    assets = rel.get("assets") or []
    tarballs = [a for a in assets if re.search(r"aarch64.*\.tar\.gz$", a.get("name", ""), re.I)]
    if not tarballs:
        print("el release %s no tiene asset *aarch64*.tar.gz" % tag, file=sys.stderr)
        sys.exit(1)
    if len(tarballs) > 1:
        print("el release %s tiene varios assets aarch64: %s" % (tag, ", ".join(a["name"] for a in tarballs)), file=sys.stderr)
        sys.exit(1)
    tar_asset = tarballs[0]
    name = tar_asset["name"]
    sidecars = [a for a in assets if a.get("name") == name + ".sha256"]
    if not sidecars:
        sidecars = [a for a in assets if re.search(r"aarch64.*\.sha256$", a.get("name", ""), re.I)]
    if len(sidecars) != 1:
        print("el release %s no tiene un unico .sha256 para %s" % (tag, name), file=sys.stderr)
        sys.exit(1)
    print("\t".join([version, name, tar_asset["browser_download_url"],
                     sidecars[0]["name"], sidecars[0]["browser_download_url"]]))
    break
else:
    print("no hay ningun release estable con tag linux-v* en los ultimos 20", file=sys.stderr)
    sys.exit(1)
PY

IFS=$'\t' read -r VERSION ASSET ASSET_URL SHA_FILE SHA_URL < "$TMP/meta" \
    || { err "no se pudo interpretar el release seleccionado"; exit 1; }

# Version instalada: primero nuestro hakux.version; si no, display_version del .info.
installed_version() {
    local f="$CORES_DIR/hakux.version" v
    if [ -f "$f" ]; then
        v="$(sed -n 's/^[[:space:]]*version[[:space:]]*=[[:space:]]*//p' "$f" | head -1 | tr -d '\042\047' | tr -d '\r')"
        [ -n "$v" ] && { printf '%s' "$v"; return 0; }
    fi
    f="$CORES_DIR/hakux_libretro.info"
    [ -f "$f" ] || return 0
    sed -n 's/^[[:space:]]*display_version[[:space:]]*=[[:space:]]*"\{0,1\}\([^"]*\)"\ \{0,1\}.*/\1/p' "$f" | head -1 | sed 's/[[:space:]]*$//'
}

INSTALLED="$(installed_version)"

log "remoto: ${VERSION} (${ASSET})"
log "destino: ${CORES_DIR}"
if [ -n "$INSTALLED" ]; then
    log "instalado: ${INSTALLED}"
else
    log "instalado: (ninguno)"
fi

if [ "$DRY" = 1 ]; then
    log "sha256: ${SHA_FILE}"
    log "SIMULACION: no se escribio nada"
    exit 0
fi

if [ "$INSTALLED" = "$VERSION" ] && [ "$FORCE" = 0 ]; then
    log "ya esta la ultima (${VERSION})"
    exit 0
fi

log "descargando ${ASSET}..."
curl -fsSL --retry 2 --max-time 600 -H 'User-Agent: deckstation-arm-hakux-updater' "$ASSET_URL" -o "$TMP/$ASSET" \
    || { err "no se pudo descargar ${ASSET}"; exit 1; }
curl -fsSL --retry 2 --max-time 60 -H 'User-Agent: deckstation-arm-hakux-updater' "$SHA_URL" -o "$TMP/$SHA_FILE" \
    || { err "no se pudo descargar ${SHA_FILE}"; exit 1; }

# El sidecar trae "<sha>  <fichero>". Verificamos nombre y suma antes de extraer.
python3 - "$TMP/$SHA_FILE" "$TMP/$ASSET" "$ASSET" <<'PY' || { err "checksum incorrecto; no se instala nada"; exit 1; }
import hashlib, os, sys

sidecar, tarball, expected_name = sys.argv[1:4]
with open(sidecar) as f:
    parts = f.read().split()
if len(parts) < 2:
    print("sidecar sin suma y nombre de fichero", file=sys.stderr)
    sys.exit(1)
expected, side_name = parts[0].lower(), os.path.basename(parts[1])
if side_name != expected_name:
    print("el sidecar nombra %s, esperabamos %s" % (side_name, expected_name), file=sys.stderr)
    sys.exit(1)
h = hashlib.sha256()
with open(tarball, "rb") as f:
    for chunk in iter(lambda: f.read(1024 * 1024), b""):
        h.update(chunk)
if h.hexdigest() != expected:
    print("sha256 no coincide: %s != %s" % (h.hexdigest(), expected), file=sys.stderr)
    sys.exit(1)
PY
log "checksum verificado"

mkdir -p "$TMP/extract" || { err "no se pudo preparar la extraccion"; exit 1; }
tar -xzf "$TMP/$ASSET" -C "$TMP/extract" || { err "no se pudo extraer ${ASSET}"; exit 1; }

SO="$(find "$TMP/extract" -type f -name '*_libretro.so' -print)"
INFO="$(find "$TMP/extract" -type f -name '*_libretro.info' -print)"
if [ "$(printf '%s\n' "$SO" | sed '/^$/d' | wc -l)" -ne 1 ] || [ "$(printf '%s\n' "$INFO" | sed '/^$/d' | wc -l)" -ne 1 ]; then
    err "el tarball no trae exactamente un *_libretro.so y un *_libretro.info; no se instala nada"
    exit 1
fi

mkdir -p "$CORES_DIR" || { err "no se pudo crear ${CORES_DIR}"; exit 1; }
DST_SO="$CORES_DIR/hakux_libretro.so"
DST_INFO="$CORES_DIR/hakux_libretro.info"

if [ -f "$DST_SO" ]; then
    OLD="${INSTALLED:-desconocida}"
    cp -f "$DST_SO" "$DST_SO.bak-${OLD}" || { err "no se pudo guardar la copia de seguridad"; exit 1; }
    log "copia anterior: hakux_libretro.so.bak-${OLD}"
fi

cp -f "$SO" "$DST_SO" || { err "no se pudo instalar hakux_libretro.so"; exit 1; }
cp -f "$INFO" "$DST_INFO" || { err "no se pudo instalar hakux_libretro.info"; exit 1; }
chmod 755 "$DST_SO" 2>/dev/null || true

INSTANT="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
cat > "$CORES_DIR/hakux.version" <<EOF || { err "no se pudo escribir hakux.version"; exit 1; }
version=${VERSION}
source=github:portare-ch/hakuX-lr
installed=${INSTANT}
EOF

# El puente deckstation-cores.sh respeta esta lista (una linea por fichero, sin duplicados).
# Van el .so Y el .info: el puente copia los dos y, si solo protegemos el .so, deja el
# display_version del sistema (paso el 26/11: core 0.39.0 con .info que decia 0.38.0).
OVERRIDES="$CORES_DIR/.loose-overrides"
touch "$OVERRIDES" || { err "no se pudo crear .loose-overrides"; exit 1; }
for _f in hakux_libretro.so hakux_libretro.info; do
    grep -Fxq "$_f" "$OVERRIDES" && continue
    if [ -s "$OVERRIDES" ] && [ "$(tail -c 1 "$OVERRIDES" | wc -l)" -eq 0 ]; then
        printf '\n' >> "$OVERRIDES"
    fi
    printf '%s\n' "$_f" >> "$OVERRIDES" || { err "no se pudo actualizar .loose-overrides"; exit 1; }
done

log "actualizado a ${VERSION} (desde GitHub)"
