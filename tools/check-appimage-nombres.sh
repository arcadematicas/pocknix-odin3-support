#!/bin/bash
# ======================================================================
# check-appimage-nombres.sh — Que AppImages de DeckStation son FRAGILES
# ======================================================================
# Herramienta de DESARROLLO (no va al usuario final). Solo LECTURA: no
# escribe nada ni en la consola ni en local.
#
# Que mira, por cada Apps/<app>/:
#   1) AUTO-UPDATE: si el AppImage trae informacion de actualizacion embebida
#      (seccion ELF .upd_info con un zsync). Esos son los que un
#      AppImageUpdate puede RENOMBRAR en cualquier momento, porque baja el
#      asset que le dice el zsync y lo deja con el nombre de ese asset.
#      Tambien mira si hay un .zsync suelto al lado y si existe una politica
#      de auto-update dentro del .home (auto-updates-policy/).
#   2) NOMBRE FRAGIL: si el fichero lleva version, arquitectura o commit hash
#      en el nombre. Cualquiera que apunte a el por ruta se rompe en la
#      siguiente actualizacion (el caso real: Xenia Edge, commit 3d5aa63).
#   3) .home HUERFANO: si el .home portable se llama distinto que el AppImage
#      que hay al lado. No rompe nada por si solo (lanzar.sh lo busca por
#      patron) pero avisa: si el Updater vuelve a instalar desde cero puede
#      crear un .home NUEVO y vacio al lado del viejo = partidas perdidas.
#   4) HUERFANOS .bak/.old: ficheros que el Updater dejo a medias. El Updater
#      solo ve como instalado un fichero que acabe en .appimage, asi que un
#      "X.AppImage.bak" sin su "X.AppImage" deja la app instalable pero
#      INLANZABLE para la plantilla generica de lanzar.sh.
#
# Por que: los nombres de AppImage los pone upstream, no nosotros. PkgForge
# cambia de nombre cada release (anadio la arquitectura, cambio el scheme de
# versiones...). No es un caso suelto, es el patron.
#
# Uso:
#   check-appimage-nombres.sh                 local, /opt/deckstation
#   check-appimage-nombres.sh --dir /ruta     otra raiz de DeckStation
#   check-appimage-nombres.sh --ssh odin      se ejecuta EN la consola
#                                             (solo lectura) y trae el
#                                             informe aqui
#   check-appimage-nombres.sh --ssh odin --raw   vuelca los datos sin
#                                             formatear (para pipelines)
#
# "--ssh" funciona porque el script se reenvia a si mismo por stdin:
#   ssh <host> bash -s -- <args>
# No se copia nada a la consola: no hay ficheros que instalar.
# ======================================================================
set -u

DECKSTATION="${DECKSTATION:-/opt/deckstation}"
SSH_HOST=""
RAW=0

while [ $# -gt 0 ]; do
    case "$1" in
        --dir) DECKSTATION="$2"; shift 2 ;;
        --ssh) SSH_HOST="$2"; shift 2 ;;
        --raw) RAW=1; shift ;;
        -h|--help) sed -n '2,46p' "$0"; exit 0 ;;
        *) echo "Argumento desconocido: $1" >&2; exit 1 ;;
    esac
done

# Modo remoto: nos pasamos por stdin al otro lado y ejecutamos alli.
# El codigo de abajo ya no lleva --ssh, asi que no rebota.
if [ -n "$SSH_HOST" ]; then
    extra=""
    [ "$RAW" -eq 1 ] && extra="--raw"
    # stdin lleva el propio script: no se copia nada al otro lado.
    exec ssh -o BatchMode=yes -o ConnectTimeout=10 "$SSH_HOST" bash -s -- \
        --dir "$DECKSTATION" $extra < "$0"
fi

APPS_DIR="${DECKSTATION}/Apps"
[ -d "$APPS_DIR" ] || { echo "No encuentro $APPS_DIR" >&2; exit 1; }

# ----------------------------------------------------------------------
# Marca un nombre como FRAGIL: lleva version, arquitectura o hash.
#
# Version:    0.289-1   v1.20.4   -8.3.0   Nightly-54ffbed26
# Arq:        aarch64   arm64     anylinux   x86_64
# Hash:       -ee018d00e6  -2a36099dc
#
# OJO: "Vita3K-aarch64.AppImage" y "ZSNES-5603f38df-anylinux-aarch64" ya son
# FRAGILES hoy, y eso es correcto: son los dos casos que se romperian.
# ----------------------------------------------------------------------
es_fragil() {
    local base="$1"
    # arquitectura explicita
    printf '%s' "$base" | grep -qiE '(aarch64|arm64|armv7|x86_64|amd64|i[3-6]86|anylinux|musl|linux-)' && return 0
    # hash de commit (7-12 hex tras un guion)
    printf '%s' "$base" | grep -qE -- '-[0-9a-f]{7,12}[.-]' && return 0
    # version con al menos un digito y un separador de version
    printf '%s' "$base" | grep -qE '[-_v][vV]?[0-9]+(\.[0-9]+)+' && return 0
    # "v1.20" suelto al principio (PPSSPP-v1.20.4 ya cae arriba, pero
    # "MAME_0.289" no lleva guion delante)
    printf '%s' "$base" | grep -qE '_[vV]?[0-9]+(\.[0-9]+)+' && return 0
    return 1
}

# Informacion de auto-update embebida en el ELF (.upd_info).
#
# readelf es lo limpio, pero NO es la unica fuente: si el fichero no tiene la
# seccion .upd_info (AppImage armado sin ella, o no es un ELF) hay que caer a las
# cadenas. Antes, cuando readelf existia y salia vacio, se hacia "return 1" y NUNCA
# se llegaba al fallback -> "no tiene auto-update" y "no he podido leerlo" salian
# igual, y el detector infraponia. Ahora, si readelf no dice nada, se prueba
# strings; y si tampoco hay nada se distingue con el codigo de salida.
#
#   0 = hay .upd_info (imprime el valor)
#   1 = se ha leido el fichero y NO hay informacion de auto-update
#   2 = no se ha podido leer (no es un ELF, o ilegible)
upd_info() {
    local img="$1" out
    if command -v readelf >/dev/null 2>&1; then
        out="$(readelf -p .upd_info "$img" 2>/dev/null \
               | sed -n 's/^ *\[ *[0-9]*\] *//p' | head -1)"
        if [ -n "$out" ]; then
            printf '%s' "$out"
            return 0
        fi
    fi
    # Fallback: la cadena en crudo (AppImage sin seccion, o ELF con la info
    # metida en otro sitio).
    out="$(strings -n 8 "$img" 2>/dev/null | grep -m1 -E '(^gh-releases-zsync\||^zsync\|)')"
    if [ -n "$out" ]; then
        printf '%s' "$out"
        return 0
    fi
    # Sin nada: si al menos es un ELF legible, es que no lleva info de auto-update.
    if command -v readelf >/dev/null 2>&1 \
       && readelf -h "$img" >/dev/null 2>&1; then
        return 1
    fi
    return 2
}

if [ "$RAW" -eq 0 ]; then
    echo ""
    echo "  Nombres y auto-actualizacion de AppImages — $APPS_DIR"
    echo "  ==========================================================="
    echo ""
    printf '  %-16s %-11s %-6s %-6s %-6s %s\n' \
        "APP" "NOMBRE" "AUTO" "POLIT" "ZSYNC" "APPIMAGE / NOTAS"
fi

n_fragil=0
n_auto=0
n_sin_home=0
n_huerfano=0
n_retazos=0
n_apps=0
n_appimages=0
n_ilegibles=0

for app_dir in "$APPS_DIR"/*/; do
    [ -d "$app_dir" ] || continue
    app="$(basename "${app_dir%/}")"
    n_apps=$((n_apps + 1))

    # El Updater no es un emulador
    [ "$app" = "Updater" ] && continue

    while IFS= read -r img; do
        [ -n "$img" ] || continue
        base="$(basename "$img")"
        n_appimages=$((n_appimages + 1))

        # auto: si / no / ?  ("?" = no se ha podido leer el ELF; no es lo mismo
        # que "no lleva info de auto-update" y no se cuenta como tal)
        auto="no"
        ui="$(upd_info "$img")"
        case $? in
            0) auto="si" ;;
            2) auto="?" ; n_ilegibles=$((n_ilegibles + 1)) ;;
        esac

        # .zsync suelto al lado (lo deja el AppImageUpdate al sincronizar)
        zsync="no"
        if ls "${img}"*.zsync >/dev/null 2>&1; then zsync="si"; fi

        # politica de auto-update dentro del .home
        home="$(find "$app_dir" -maxdepth 3 -name "*.home" -type d 2>/dev/null | head -n 1)"
        pol="no"
        [ -n "$home" ] && [ -d "$home/auto-updates-policy" ] && pol="si"

        frag="no"
        es_fragil "$base" && frag="si"

        [ "$frag" = "si" ] && n_fragil=$((n_fragil + 1))
        [ "$auto" = "si" ] && n_auto=$((n_auto + 1))
        [ -z "$home" ] && n_sin_home=$((n_sin_home + 1))

        notas=""
        # .home con nombre distinto del AppImage
        if [ -n "$home" ] && [ "$(basename "$home")" != "${base}.home" ]; then
            hn="$(basename "$home")"
            hn="${hn%.home}"
            notas="  .home se llama '$hn' (huerfano, sin cambios en el)"
            n_huerfano=$((n_huerfano + 1))
        fi
        [ -n "$home" ] || notas="  SIN .home portable"

        if [ "$RAW" -eq 1 ]; then
            printf '%s\t%s\tauto=%s\tfragil=%s\tzsync=%s\tpolitica=%s\thome=%s\t%s\n' \
                "$app" "$base" "$auto" "$frag" "$zsync" "$pol" \
                "${home:-NONE}" "${ui:-none}"
        else
            printf '  %-16s %-11s %-6s %-6s %-6s %s%s\n' \
                "$app" "$frag" "$auto" "$pol" "$zsync" "$base" "$notas"
        fi
    done < <(find "$app_dir" -maxdepth 2 -type f -iname "*.AppImage" 2>/dev/null | sort)

    # Retazos que el Updater dejo a medias: "X.AppImage.bak" sin "X.AppImage".
    # El Updater solo reconoce como instalado lo que acaba en ".appimage",
    # asi que esto = app instalable pero INLANZABLE.
    while IFS= read -r bak; do
        [ -n "$bak" ] || continue
        app_dir_real="$(dirname "$bak")"
        if find "$app_dir_real" -maxdepth 1 -type f -iname "*.AppImage" | grep -q .; then
            continue   # hay un AppImage sano: el .bak es solo el backup del Updater
        fi
        n_retazos=$((n_retazos + 1))
        if [ "$RAW" -eq 1 ]; then
            printf '%s\t%s\tauto=?\tfragil=?\tzsync=no\tpolitica=no\thome=NONE\tRETASO SIN APPIMAGE\n' \
                "$app" "$(basename "$bak")"
        else
            printf '  %-16s %-11s %-6s %-6s %-6s %s\n' \
                "$app" "RETAZO" "-" "-" "-" "$(basename "$bak")  NO HAY .AppImage"
        fi
    done < <(find "$app_dir" -maxdepth 2 -type f \
                \( -name "*.AppImage.bak" -o -name "*.AppImage.old" \
                   -o -name "*.AppImage.1" -o -name "*.AppImage.bak-*" \) 2>/dev/null | sort)

done

if [ "$RAW" -eq 0 ]; then
    echo ""
    echo "  ==========================================================="
    echo "  $n_apps apps, $n_appimages ficheros AppImage (+ $n_retazos sin .AppImage)"
    echo "    $n_auto con info de AUTO-UPDATE embebida (se pueden renombrar solos)"
    # Los ilegibles se dicen aparte: si se esconden, un "0 con AUTO-UPDATE"
    # puede ser en realidad "no he podido leer ninguno".
    [ "$n_ilegibles" -gt 0 ] && \
        echo "    ⚠ $n_ilegibles NO se han podido leer (no son ELF legibles): AUTO = '?' no significa 'no'"
    echo "    $n_fragil con nombre FRAGIL (version/arquitectura/hash)"
    echo "    $n_huerfano con .home de nombre distinto al AppImage"
    echo "    $n_sin_home sin .home portable"
    echo ""
    if [ "$n_fragil" -gt 0 ]; then
        echo "  Los FRAGILES importan solo si ALGO apunta a ellos por ruta."
        echo "  Para verlo:  tools/check-appimage-rutas.sh --ssh <host>"
        echo ""
    fi
    if [ "$n_huerfano" -gt 0 ]; then
        echo "  Un .home huerfano NO rompe nada por si mismo: lanzar.sh lo busca"
        echo "  por patron (*.home), no por nombre. Avisa porque reinstalar desde"
        echo "  cero crearia un .home NUEVO al lado del viejo = partidas perdidas."
        echo ""
    fi
fi

# 0 siempre: esto informa, no falla el build
exit 0