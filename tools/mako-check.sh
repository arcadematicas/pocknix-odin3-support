#!/usr/bin/env bash
# Comprueba si el Renderer ARM de MAKO y el parche del Panel siguen al día.
# Solo bash + curl + python3 (stdlib) + patch + sha256sum.
# Códigos: 0 todo al día; 1 hay que actualizar/rebasar; 2 error de red o de configuración.
set -uo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PATCH="$ROOT/overlay/usr/share/pocknix/patches/panel-de-control-arm64-mako.patch"
API_RELEASE="https://api.github.com/repos/Ken5998/mako-arm64/releases/latest"
MAKO_RAW="https://raw.githubusercontent.com/Hooandee/panel-de-control/main/py_modules/upscalers/mako.py"
UA="mako-check/1.0 (stdlib; comprobación ARM personal)"
RUTA_ENV="${HOME:-/root}/peanuts-watch/telegram.env"

NOTIFY=0
DRY_RUN=0
DOWNLOAD=0

while [[ $# -gt 0 ]]; do
    case "$1" in
        --notify)   NOTIFY=1; shift ;;
        --dry-run)  DRY_RUN=1; shift ;;
        --download) DOWNLOAD=1; shift ;;
        --env)      [[ $# -ge 2 ]] || { echo "Error: --env necesita una ruta" >&2; exit 2; }; RUTA_ENV="$2"; shift 2 ;;
        -h|--help)
            echo "Uso: mako-check.sh [--notify] [--dry-run] [--download] [--env <ruta>]"
            echo "  --notify    envía Telegram solo si hay algo que actualizar"
            echo "  --dry-run   no descarga el asset (usa el digest) y no envía nada"
            echo "  --download  descarga el asset aunque la API traiga digest"
            exit 0 ;;
        *) echo "Error: opción desconocida '$1' (usa --help)" >&2; exit 2 ;;
    esac
done

fallo_red() {
    echo "Error de red: $1" >&2
    exit 2
}

# Credenciales: se validan antes de tocar la red para fallar con mensaje claro.
TG_TOKEN=""
TG_CHAT=""
if [[ $NOTIFY -eq 1 && $DRY_RUN -eq 0 ]]; then
    if [[ ! -f "$RUTA_ENV" ]]; then
        echo "Error de credenciales: no existe $RUTA_ENV (usa --env <ruta> con TG_TOKEN y TG_CHAT)" >&2
        exit 2
    fi
    while IFS='=' read -r CLAVE VALOR; do
        CLAVE="${CLAVE//[[:space:]]/}"
        VALOR="${VALOR#"${VALOR%%[![:space:]]*}"}"
        VALOR="${VALOR%"${VALOR##*[![:space:]]}"}"
        VALOR="${VALOR%\"}"; VALOR="${VALOR#\"}"
        VALOR="${VALOR%\'}"; VALOR="${VALOR#\'}"
        case "$CLAVE" in
            TG_TOKEN) TG_TOKEN="$VALOR" ;;
            TG_CHAT)  TG_CHAT="$VALOR" ;;
        esac
    done < "$RUTA_ENV"
    if [[ -z "$TG_TOKEN" || -z "$TG_CHAT" ]]; then
        echo "Error de credenciales: faltan TG_TOKEN o TG_CHAT en $RUTA_ENV (usa --env <ruta>)" >&2
        exit 2
    fi
fi

if [[ ! -f "$PATCH" ]]; then
    echo "Error: no se encontró el parche $PATCH" >&2
    exit 2
fi

TMP="$(mktemp -d "${TMPDIR:-/tmp}/mako-check.XXXXXX")" || exit 2
trap 'rm -rf "$TMP"' EXIT

echo "=== MAKO / Panel de Control — comprobación de versiones ==="

# 1) Última release del Renderer ARM.
if ! curl -fsSL --connect-timeout 10 --max-time 40 --retry 2 --retry-delay 1 \
        -A "$UA" "$API_RELEASE" -o "$TMP/release.json"; then
    fallo_red "no se pudo consultar $API_RELEASE"
fi

if ! python3 - "$TMP/release.json" > "$TMP/asset.tsv" <<'PY'
import json, sys
with open(sys.argv[1], encoding="utf-8") as f:
    datos = json.load(f)
assets = [a for a in (datos.get("assets") or [])
          if "linux-arm64" in str(a.get("name") or "").lower()]
if not assets:
    sys.exit(1)
a = assets[0]
print("\t".join([
    str(a.get("name") or ""),
    str(a.get("digest") or ""),
    str(a.get("size") or 0),
    str(a.get("browser_download_url") or ""),
    str(datos.get("tag_name") or ""),
]))
PY
then
    echo "Error: la última release no trae un asset con 'linux-arm64' en el nombre" >&2
    exit 2
fi
IFS=$'\t' read -r ASSET_NOMBRE DIGEST ASSET_TAMANO ASSET_URL TAG < "$TMP/asset.tsv"

# 2) Valores del parche (bloque +ASSET5_ARM, que ocupa varias líneas).
if ! python3 - "$PATCH" > "$TMP/parche.tsv" <<'PY'
import ast, pathlib, sys
lineas = pathlib.Path(sys.argv[1]).read_text(encoding="utf-8").splitlines()
bloque = []
dentro = False
for linea in lineas:
    if linea.startswith("+ASSET5_ARM"):
        dentro = True
    if dentro:
        bloque.append(linea[1:] if linea.startswith("+") else linea)
        if "))" in linea:
            break
if not bloque:
    sys.exit(1)
arbol = ast.parse("\n".join(bloque))
for nodo in arbol.body:
    if isinstance(nodo, ast.Assign) and any(
        isinstance(t, ast.Name) and t.id == "ASSET5_ARM" for t in nodo.targets
    ) and isinstance(nodo.value, ast.Call):
        args = [ast.literal_eval(a) for a in nodo.value.args]
        nombre = str(args[1])
        sha = str(args[2])
        tamano = int(args[3])
        url = str(args[4][0]) if isinstance(args[4], (tuple, list)) else str(args[4])
        print("\t".join([nombre, sha, str(tamano), url]))
        break
else:
    sys.exit(1)
PY
then
    echo "Error: no se pudo leer +ASSET5_ARM de $PATCH" >&2
    exit 2
fi
IFS=$'\t' read -r PAR_NOMBRE PAR_SHA PAR_TAMANO PAR_URL < "$TMP/parche.tsv"

echo "Release ARM: $TAG"
echo "Asset publicado: $ASSET_NOMBRE ($ASSET_TAMANO bytes)"
echo "Asset en el parche: $PAR_NOMBRE ($PAR_TAMANO bytes)"

CAMBIOS=0
comparar() {
    if [[ "$2" == "$3" ]]; then
        echo "  $1: coincide ($2)"
    else
        echo "  $1: DIFIERE → release '$2' | parche '$3'"
        CAMBIOS=1
    fi
}

comparar "nombre del asset" "$ASSET_NOMBRE" "$PAR_NOMBRE"
comparar "tamaño" "$ASSET_TAMANO" "$PAR_TAMANO"
comparar "URL" "$ASSET_URL" "$PAR_URL"

HASH_COMPARABLE=1
HASH_ASSET=""
if [[ $DRY_RUN -eq 1 ]]; then
    if [[ -n "$DIGEST" ]]; then
        HASH_ASSET="${DIGEST#sha256:}"
        echo "  sha256: desde el digest de la API (--dry-run no descarga)"
    else
        HASH_COMPARABLE=0
        echo "  sha256: SIN VERIFICAR — el asset no trae digest y --dry-run no descarga; no se puede comparar el hash"
    fi
else
    if [[ $DOWNLOAD -eq 1 || -z "$DIGEST" ]]; then
        if ! curl -fsSL --connect-timeout 10 --max-time 180 --retry 2 --retry-delay 1 \
                -A "$UA" "$ASSET_URL" -o "$TMP/asset.bin"; then
            fallo_red "no se pudo descargar el asset $ASSET_URL"
        fi
        HASH_ASSET="$(sha256sum "$TMP/asset.bin" | awk '{print $1}')"
        if [[ $DOWNLOAD -eq 1 ]]; then
            echo "  sha256: calculado de la descarga temporal (forzada por --download)"
        else
            echo "  sha256: calculado de la descarga temporal (sin digest en la API)"
        fi
    else
        HASH_ASSET="${DIGEST#sha256:}"
        echo "  sha256: desde el digest de la API"
    fi
fi
if [[ $HASH_COMPARABLE -eq 1 ]]; then
    comparar "sha256" "$HASH_ASSET" "$PAR_SHA"
fi

# 3) El parche contra el mako.py actual del main del Panel.
echo "Panel de Control (main): comprobando el parche..."
if ! curl -fsSL --connect-timeout 10 --max-time 40 --retry 2 --retry-delay 1 \
        -A "$UA" "$MAKO_RAW" -o "$TMP/mako.py"; then
    fallo_red "no se pudo descargar $MAKO_RAW"
fi
mkdir -p "$TMP/py_modules/upscalers"
cp "$TMP/mako.py" "$TMP/py_modules/upscalers/mako.py"
SALIDA=$( (cd "$TMP" && patch -p1 --dry-run < "$PATCH" 2>&1) )
RC=$?
if [[ $RC -eq 0 ]]; then
    echo "  Parche: APLICA LIMPIO sobre el main actual del Panel."
    echo "$SALIDA" | sed 's/^/    /'
else
    echo "  Parche: NO APLICA sobre el main actual del Panel — hay que rebasarlo (diff contra el mako.py nuevo)."
    echo "$SALIDA" | sed 's/^/    /'
    CAMBIOS=1
fi

if [[ $CAMBIOS -eq 1 ]]; then
    echo "Resultado: HAY ALGO QUE ACTUALIZAR (actualiza ASSET5_ARM/PAYLOAD5_ARM o rebasea el parche)."
    if [[ $NOTIFY -eq 1 && $DRY_RUN -eq 0 ]]; then
        MENSAJE="mako-check: hay algo que actualizar. Release $TAG, asset $ASSET_NOMBRE (sha256 $HASH_ASSET, $ASSET_TAMANO bytes). Revisar $PATCH y el main del Panel."
        CUERPO="$(python3 - "$TG_CHAT" "$MENSAJE" <<'PY'
import json, sys
chat = sys.argv[1]
if chat.lstrip("-").isdigit():
    chat = int(chat)
print(json.dumps({"chat_id": chat, "text": sys.argv[2], "disable_web_page_preview": True}))
PY
)"
        if RESPUESTA="$(curl -fsSL --connect-timeout 10 --max-time 20 \
                -H 'Content-Type: application/json' -A "$UA" \
                -d "$CUERPO" "https://api.telegram.org/bot${TG_TOKEN}/sendMessage")"; then
            if echo "$RESPUESTA" | grep -q '"ok":true'; then
                echo "Telegram: ok:true"
            else
                echo "Telegram: ok:false (respuesta inesperada)"
            fi
        else
            echo "Telegram: ok:false (error de red al enviar)"
        fi
    fi
    exit 1
fi

echo "Resultado: TODO AL DÍA — el asset del parche coincide y el parche aplica limpio."
exit 0
