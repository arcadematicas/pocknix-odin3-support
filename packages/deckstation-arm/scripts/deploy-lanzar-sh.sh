#!/bin/bash
# ======================================================================
# deploy-lanzar-sh.sh — Copia el wrapper portable lanzar.sh a los emuladores
# ======================================================================
# El es_find_rules.xml de ES-DE apunta a ./Apps/<Emulador>/lanzar.sh (no al
# AppImage), asi que un emulador SIN lanzar.sh NO se puede lanzar desde ES-DE.
#
# Por que hace falta un script aparte y no basta el setup:
#   deckstation-setup.sh desplegaba lanzar.sh ANTES de abrir el Updater, y es el
#   Updater quien DESCARGA los emuladores -> los recien instalados se quedaban
#   sin wrapper. Esto lo llaman las tres capas:
#     - deckstation-setup.sh  (tras cerrar el Updater)
#     - deckstation-launcher.sh (auto-reparacion en cada arranque)
#     - el Updater (justo despues de instalar un emulador)
#
# Idempotente: si el wrapper ya esta al dia no toca nada; si la plantilla cambio
# (p. ej. el fix de libXss) lo actualiza.
#
# Uso:
#   deploy-lanzar-sh.sh              -> recorre todas las carpetas de Apps/
#   deploy-lanzar-sh.sh <NombreApp>  -> solo esa (case-insensitive)
# ======================================================================
set -u

SELF="$(readlink -f "${BASH_SOURCE[0]}")"
DECKSTATION_ROOT="${DECKSTATION_ROOT:-$(cd "$(dirname "$SELF")/.." && pwd)}"
SCRIPTS_DIR="${DECKSTATION_ROOT}/scripts"
APPS_DIR="${DECKSTATION_ROOT}/Apps"
PLANTILLA="${SCRIPTS_DIR}/lanzar.sh"

[ -f "$PLANTILLA" ] || exit 0
[ -d "$APPS_DIR" ] || exit 0

# Asegura que el emulador tiene su .home portable.
#
# POR QUE: lanzar.sh solo redirige HOME si encuentra un *.home:
#     HOME_DIR=$(find "$DIR" -maxdepth 3 -name "*.home" -type d | head -n 1)
#     [ -n "$HOME_DIR" ] && export HOME="$HOME_DIR"
# Sin .home, HOME se queda en el real y el emulador escribe su config y sus
# partidas en ~/.config / ~/.local/share -> DEJA DE SER PORTABLE, que es justo lo
# que DeckStation promete (todo dentro de /opt/deckstation).
#
# Y el .home se creaba como EFECTO COLATERAL de desplegar una config de fabrica
# (deckstation-configs.sh hace mkdir -p del destino). Solo 15 emuladores tienen
# config -> los otros 18 (Amiberry, Dreamm, mGBA, ScummVM...) se quedaban sin
# .home. Y RetroArch, que es binario nativo, tampoco lo tenia.
#
# Aqui se crea para TODOS, independientemente de que tengan config. Mismo criterio
# de nombre que resolve_home() de deckstation-configs.sh.
asegurar_home() {
    local app_dir="$1" img base sub low home app

    app="$(basename "$app_dir")"

    # Ya tiene uno? no se toca (respeta el que haya, con sus datos dentro).
    find "$app_dir" -maxdepth 3 -type d -name "*.home" 2>/dev/null | grep -q . && return 0

    img="$(find "$app_dir" -maxdepth 3 -type f \( -iname "*.AppImage" -o -iname "*.appimage" \) 2>/dev/null | head -1)"
    if [ -n "$img" ]; then
        home="${img}.home"
    else
        # RetroArch y otros vienen como binario suelto (no AppImage).
        for sub in "$app_dir"/*/; do
            [ -d "$sub" ] || continue
            base="$(basename "$sub")"
            low="$(printf '%s' "$base" | tr '[:upper:]' '[:lower:]')"
            [ "$low" = "app" ] && continue
            # Se compara con el nombre de la APP, no con el de la carpeta: si se
            # compara consigo misma coincide cualquier subcarpeta (se colaba
            # __pycache__ y creaba "__pycache__.AppImage.home").
            case "$low" in
                "${app,,}"*) home="${sub%/}.AppImage.home"; break ;;
            esac
        done
        # Sin subcarpeta: el binario esta en la raiz (RetroArch del buildbot).
        if [ -z "${home:-}" ]; then
            for f in "$app_dir"/retroarch "$app_dir"/*.bin; do
                [ -x "$f" ] || continue
                home="${f}.AppImage.home"
                break
            done
        fi
    fi

    [ -n "${home:-}" ] || return 0
    mkdir -p "$home" 2>/dev/null && echo "  .home -> $(basename "$home")"
    return 0
}

desplegar_una() {
    local app_dir="$1" found
    [ -d "$app_dir" ] || return 0

    # El .home portable se asegura SIEMPRE, antes de cualquier salida temprana:
    # si el wrapper ya esta al dia (lo normal en un sistema en uso) se salia por
    # el return de abajo y el .home no se creaba nunca.
    asegurar_home "$app_dir"

    # Ya esta al dia? (cmp para no reescribir si no ha cambiado)
    if [ -f "${app_dir}/lanzar.sh" ] && cmp -s "$PLANTILLA" "${app_dir}/lanzar.sh"; then
        return 0
    fi

    # Solo si hay algo que lanzar: AppImage, RetroArch nativo o arbol extraido.
    found="$(find "$app_dir" -maxdepth 1 \
        \( -iname "*.AppImage" -o -iname "*.appimage" \) 2>/dev/null | head -1)"
    if [ -z "$found" ] && [ ! -x "${app_dir}/retroarch" ] && [ ! -x "${app_dir}/app/AppRun" ]; then
        return 0
    fi

    install -m755 "$PLANTILLA" "${app_dir}/lanzar.sh" 2>/dev/null \
        && echo "  lanzar.sh -> $(basename "$app_dir")"
}

if [ "$#" -ge 1 ]; then
    # Nombre de app concreto (case-insensitive, igual que deckstation-configs.sh)
    objetivo="$(find "$APPS_DIR" -maxdepth 1 -type d -iname "$1" 2>/dev/null | head -1)"
    [ -n "$objetivo" ] && desplegar_una "$objetivo"
else
    for app_dir in "$APPS_DIR"/*/; do
        [ -d "$app_dir" ] || continue
        desplegar_una "${app_dir%/}"
    done
fi

exit 0
