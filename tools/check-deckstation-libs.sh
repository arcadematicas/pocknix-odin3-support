#!/bin/bash
# ======================================================================
# check-deckstation-libs.sh — QA interno: librerías faltantes en DeckStation
# ======================================================================
# Herramienta de DESARROLLO (no va al usuario final). Recorre los emuladores
# de DeckStation y busca librerías que no se resuelven (ldd "not found").
#
# Por qué: los AppImages traen casi todo dentro, pero a veces enlazan contra
# libs del host que una imagen minimalista no tiene (el caso real: libXss de
# RetroArch). Este script lo detecta ANTES de desplegar.
#
# Uso:
#   check-deckstation-libs.sh             revisa todas las apps de /opt/deckstation
#   check-deckstation-libs.sh --app MAME  solo esa app
#   check-deckstation-libs.sh --quick     solo binarios nativos (no extrae AppImages)
#   check-deckstation-libs.sh --dir /ruta apuntar a otra raiz de DeckStation
#
# Notas:
#   - Los AppImages se extraen con --appimage-extract a un dir temporal y se
#     borran al terminar (puede tardar en apps grandes: RPCS3, MAME...).
#   - Los binarios nativos (RetroArch) se comprueban con ldd directo.
#   - Salida: por app, "OK" o la lista de librerias faltantes.
# ======================================================================
set -u

DECKSTATION="${DECKSTATION:-/opt/deckstation}"
ONLY_APP=""
QUICK=0

while [ $# -gt 0 ]; do
    case "$1" in
        --app) ONLY_APP="$2"; shift 2 ;;
        --quick) QUICK=1; shift ;;
        --dir) DECKSTATION="$2"; shift 2 ;;
        -h|--help) sed -n '2,24p' "$0"; exit 0 ;;
        *) echo "Argumento desconocido: $1" >&2; exit 1 ;;
    esac
done

APPS_DIR="${DECKSTATION}/Apps"
[ -d "$APPS_DIR" ] || { echo "No encuentro $APPS_DIR" >&2; exit 1; }

TMPDIR_BASE="$(mktemp -d)"
trap 'rm -rf "$TMPDIR_BASE"' EXIT

# ldd sobre una lista de binarios; devuelve las libs "not found" unicas
ldd_check() {
    local bin="$1"
    ldd "$bin" 2>/dev/null | grep -oP '=> not found' >/dev/null 2>&1
    ldd "$bin" 2>/dev/null | grep -oP '^\s*\S+ => not found' | awk '{print $1}' | sort -u
}

# Comprueba un binario (o AppImage extraido) y reporta
check_binaries() {
    local label="$1" dir="$2" missing="" lib
    local found=0
    while IFS= read -r bin; do
        [ -n "$bin" ] || continue
        # ldd sobre un .so/.bin puede dar "not a dynamic executable" -> se ignora
        libs=$(ldd_check "$bin")
        if [ -n "$libs" ]; then
            found=1
            while IFS= read -r lib; do
                [ -n "$lib" ] || continue
                missing="${missing}${missing:+ }${lib}"
            done <<< "$libs"
        fi
    done < <(find "$dir" -type f \( -perm -u+x -o -name "*.so*" \) 2>/dev/null)
    if [ "$found" -eq 1 ]; then
        printf '  %-16s FALTAN: %s\n' "$label" "$missing"
        return 1
    fi
    printf '  %-16s OK\n' "$label"
    return 0
}

# AppImage -> extraer a un dir temporal y comprobar
check_appimage() {
    local app="$1" img="$2" label
    label="$(basename "$img")"
    label="${label%.AppImage}"
    label="${label:0:16}"
    local tmp="$TMPDIR_BASE/$(basename "$img").d"
    mkdir -p "$tmp"
    ( cd "$tmp" && "$img" --appimage-extract >/dev/null 2>&1 )
    if [ -d "$tmp/squashfs-root" ]; then
        check_binaries "$label" "$tmp/squashfs-root"
    else
        printf '  %-16s ERROR al extraer\n' "$label"
        return 1
    fi
}

# Binario nativo -> ldd directo
check_native() {
    local app="$1" bin="$2"
    local libs
    libs=$(ldd_check "$bin")
    if [ -n "$libs" ]; then
        printf '  %-16s FALTAN: %s\n' "$app" "$libs"
        return 1
    fi
    printf '  %-16s OK\n' "$app"
    return 0
}

echo ""
echo "  QA de librerias — DeckStation en $DECKSTATION"
echo "  ==================================================="
echo ""

fail=0
total=0

for app_dir in "$APPS_DIR"/*/; do
    app="$(basename "$app_dir")"
    # El Updater no es un emulador
    [ "$app" = "Updater" ] && continue
    [ -n "$ONLY_APP" ] && [ "$app" != "$ONLY_APP" ] && continue

    total=$((total + 1))
    echo "  [$app]"

    # 1) AppImages
    if [ "$QUICK" -eq 0 ]; then
        while IFS= read -r img; do
            [ -n "$img" ] || continue
            check_appimage "$app" "$img" || fail=$((fail + 1))
        done < <(find "$app_dir" -maxdepth 1 -iname "*.AppImage" 2>/dev/null)
    fi

    # 2) Binarios nativos (retroarch, etc.) — excluye lanzar.sh y scripts
    while IFS= read -r bin; do
        [ -n "$bin" ] || continue
        case "$(basename "$bin")" in
            lanzar.sh|*.sh|*.py) continue ;;
        esac
        check_native "$app" "$bin" || fail=$((fail + 1))
    done < <(find "$app_dir" -maxdepth 1 -type f -perm -u+x 2>/dev/null | grep -v '\.AppImage$')

    echo ""
done

echo "  ==================================================="
if [ "$fail" -eq 0 ]; then
    echo "  RESULTADO: $total apps revisadas, sin librerias faltantes"
else
    echo "  RESULTADO: $total apps revisadas, $fail con librerias faltantes"
fi
echo ""
exit $([ "$fail" -eq 0 ] && echo 0 || echo 1)