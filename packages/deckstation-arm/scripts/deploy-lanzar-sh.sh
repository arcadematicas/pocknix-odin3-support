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

desplegar_una() {
    local app_dir="$1" found
    [ -d "$app_dir" ] || return 0

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
