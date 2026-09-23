#!/bin/bash
# ======================================================================
# deckstation-bios.sh — Informa y distribuye las BIOS/firmware del usuario
# ======================================================================
# Las BIOS y el firmware tienen copyright: NO se pueden distribuir con
# DeckStation. Solucion externa: el usuario deja SUS ficheros (obtenidos
# legalmente de sus propias consolas) en bios/, organizados por sistema,
# y este script los copia a donde cada emulador los espera (RetroArch
# system/, DuckStation bios/, ...).
#
# Reutiliza el motor de deckstation-configs.sh con el manifiesto bios/.
# No destructivo: solo copia lo que falte (--force para sobrescribir).
#
# Uso:
#   deckstation-bios.sh                 reparte lo que haya
#   deckstation-bios.sh --check         INFORME: que falta y donde va cada una
#   deckstation-bios.sh --dry-run       ver que haria, sin tocar nada
#   deckstation-bios.sh --force         sobrescribir lo que ya exista
#
# El informe (--check) se apoya en dos ficheros:
#   bios/required.txt    -> que ficheros espera cada sistema (y alternativas)
#   bios/deploy-bios.txt -> a donde va cada sistema
#
# Lo usan el Updater (pantalla BIOS) y Pocknix Tools.
# Ver bios/README.md para saber que ficheros necesita cada sistema.
# ======================================================================
set -u

SELF="$(readlink -f "${BASH_SOURCE[0]}")"
DECKSTATION_ROOT="${DECKSTATION_ROOT:-$(cd "$(dirname "$SELF")/.." && pwd)}"
BIOS_DIR="${DECKSTATION_ROOT}/bios"
REQUIRED="${BIOS_DIR}/required.txt"
MANIFEST="${BIOS_DIR}/deploy-bios.txt"

# ----------------------------------------------------------------------
# Informe: estado de cada sistema, lo que falta y el destino de cada una
# ----------------------------------------------------------------------

# Destino(s) de un sistema, en corto y reconocible:
#   {HOME:RetroArch}/.config/retroarch/system        -> "RetroArch system"
#   {HOME:RetroArch}/.config/retroarch/system/dc     -> "RetroArch system/dc"
#   {HOME:Duckstation}/.local/share/duckstation/bios -> "Duckstation bios"
destino_de() {
    local sis="$1" out="" dst app ruta ult
    while IFS='|' read -r _origen dst _pol; do
        [ -n "${dst:-}" ] || continue
        if printf '%s' "$dst" | grep -q '^{HOME:'; then
            app="${dst#\{HOME:}"; app="${app%%\}*}"
            ruta="${dst#*\}/}"
            ult="${ruta##*/}"
            # Componentes cortos ("dc", "keys") solos no dicen nada: anadir el padre.
            if [ "${#ult}" -le 4 ]; then
                ult="$(printf '%s' "$ruta" | awk -F/ '{ if (NF >= 2) print $(NF-1)"/"$NF; else print $NF }')"
            fi
            # Si el padre ya es el nombre de la app, no repetirlo ("Duckstation duckstation/bios").
            if [ "${ult%%/*}" != "$ult" ]; then
                case "$(printf '%s' "${ult%%/*}" | tr 'A-Z' 'a-z')" in
                    "$(printf '%s' "$app" | tr 'A-Z' 'a-z')") ult="${ult##*/}" ;;
                esac
            fi
            out="${out}${out:+ + }${app} ${ult}"
        else
            out="${out}${out:+ + }${dst##*/}"
        fi
    done < <(grep -E "^${sis}\|" "$MANIFEST" 2>/dev/null)
    printf '%s' "${out:-—}"
}

# ¿Esta cubierta una fila? Vale el fichero o cualquiera de sus alternativas.
# Comparacion sin distinguir mayusculas (los emuladores no se ponen de acuerdo).
tiene_fichero() {
    local sis="$1" fichero="$2" alternativas="${3:-}" dir cand
    dir="${BIOS_DIR}/${sis}"
    [ -d "$dir" ] || return 1
    for cand in "$fichero" $(printf '%s' "$alternativas" | tr ',' ' '); do
        [ -n "$cand" ] || continue
        # Candidato con subcarpetas (p. ej. Sys/GC/USA/IPL.bin): comprobacion directa.
        if [[ "$cand" == */* ]]; then
            [ -f "$dir/$cand" ] && return 0
            continue
        fi
        if find "$dir" -maxdepth 1 -type f -iname "$cand" 2>/dev/null | grep -q .; then
            return 0
        fi
    done
    return 1
}

check_bios() {
    echo ""
    echo "  BIOS de DeckStation — que te falta y donde va cada una"
    echo "  ======================================================="
    echo ""

    if [ ! -f "$REQUIRED" ]; then
        echo "  No encuentro ${REQUIRED}"
        return 1
    fi

    printf '  %-10s %-7s %-32s %s\n' "SISTEMA" "TIENES" "FALTAN" "DESTINO"
    printf '  %-10s %-7s %-32s %s\n' "----------" "------" "--------------------------------" "------------------"

    local sistemas sis total tengo faltan estado
    local ok_glob=0 tot_glob=0
    sistemas="$(grep -vE '^[[:space:]]*#|^[[:space:]]*$' "$REQUIRED" | cut -d'|' -f1 | awk '!v[$0]++')"

    for sis in $sistemas; do
        total=0; tengo=0; faltan=""
        while IFS='|' read -r _s fichero _nota alternativas; do
            [ "$_s" = "$sis" ] || continue
            total=$((total + 1))
            if tiene_fichero "$sis" "$fichero" "${alternativas:-}"; then
                tengo=$((tengo + 1))
            else
                faltan="${faltan}${faltan:+, }${fichero}"
            fi
        done < <(grep -vE '^[[:space:]]*#|^[[:space:]]*$' "$REQUIRED")

        tot_glob=$((tot_glob + 1))
        if [ "$tengo" -eq "$total" ]; then
            estado="OK"; ok_glob=$((ok_glob + 1)); faltan="—"
        elif [ "$tengo" -gt 0 ]; then
            estado="parcial"
        else
            estado="FALTA"
        fi
        printf '  %-10s %-7s %-32s %s\n' "$sis" "$tengo/$total" "${faltan:0:32}" "$(destino_de "$sis")"
    done

    echo ""
    echo "  Sistemas cubiertos: ${ok_glob}/${tot_glob}"
    echo ""
    echo "  Pon tus BIOS en:   ${BIOS_DIR}/<sistema>/"
    echo "  Por red (Samba):   copia a la carpeta bios/ de DeckStation"
    echo "  Luego reparte con: deckstation-bios.sh"
    echo ""
    echo "  Recuerda: no todas son obligatorias. Muchos cores de RetroArch"
    echo "  funcionan sin BIOS (o con HLE); si un sistema no arranca, el log"
    echo "  del emulador dira exactamente que fichero y que nombre espera."
    echo ""
}

case "${1:-}" in
    --check|--status)
        check_bios
        exit $?
        ;;
    -h|--help)
        sed -n '2,25p' "$SELF"
        exit 0
        ;;
esac

exec env DECKSTATION_ROOT="$DECKSTATION_ROOT" \
    "${DECKSTATION_ROOT}/scripts/deckstation-configs.sh" \
    --from "${BIOS_DIR}" \
    --manifest "${MANIFEST}" \
    --label bios "$@"
