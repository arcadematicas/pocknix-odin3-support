#!/bin/bash
# ======================================================================
# check-appimage-rutas.sh — Guardian de rutas rotas de DeckStation
# ======================================================================
# Herramienta de DESARROLLO (no va al usuario final). Solo LECTURA.
#
# QUE HACE:
#   A) Recorre el es_find_rules.xml de la consola y comprueba que CADA
#      <entry> que apunta a ./Apps/... exista de verdad.
#      B) Recorre los Apps/<app>/lanzar.sh: que existan, sean ejecutables y
#      que la app tenga ALGO que lanzar detras.
#   Con eso el fallo de Xenia Edge (commit 3d5aa63) se habria visto en un
#   segundo en vez de aparecer como "el sistema xbox360 no lanza nada".
#
# POR QUE NO DA FALSOS POSITIVOS:
#   El es_find_rules.xml trae ~340 <entry> y solo ~40 son rutas nuestras de
#   DeckStation. El resto son de ES-DE upstream: /var/lib/flatpak/...,
#   ~/.local/bin/..., nombres de app ("mame", "dolphin-emu"), "bash", "sh"...
#   Esos se IGNORAN a proposito: no son rutas de ficheros de DeckStation y
#   many de ellas no existen en una consola ARM. Revisarlas todas daria
#   cientos de falsos positivos.
#
#   Y dentro de ./Apps/... se distinguen dos casos:
#     ROTA     -> la CARPETA existe pero el fichero no. Eso es un BUG: el
#                 emulador esta instalado y aun asi no se puede lanzar.
#     AUSENTE  -> la carpeta no existe: el emulador simplemente no esta
#                 instalado. No es un error, se informa aparte.
#
# Uso:
#   check-appimage-rutas.sh              local, /opt/deckstation
#   check-appimage-rutas.sh --dir /ruta  otra raiz
#   check-appimage-rutas.sh --ssh odin   se ejecuta EN la consola (solo
#                                        lectura) y trae el informe aqui
#   check-appimage-rutas.sh --ssh odin --solo-rotas   solo lo que esta roto
#
# Codigo de salida: 1 si hay rutas ROTAS, 0 si no.
# ======================================================================
set -u

DECKSTATION="${DECKSTATION:-/opt/deckstation}"
SSH_HOST=""
SOLO_ROTAS=0

while [ $# -gt 0 ]; do
    case "$1" in
        --dir) DECKSTATION="$2"; shift 2 ;;
        --ssh) SSH_HOST="$2"; shift 2 ;;
        --solo-rotas) SOLO_ROTAS=1; shift ;;
        -h|--help) sed -n '2,44p' "$0"; exit 0 ;;
        *) echo "Argumento desconocido: $1" >&2; exit 1 ;;
    esac
done

if [ -n "$SSH_HOST" ]; then
    extra=""
    [ "$SOLO_ROTAS" -eq 1 ] && extra="--solo-rotas"
    exec ssh -o BatchMode=yes -o ConnectTimeout=10 "$SSH_HOST" bash -s -- \
        --dir "$DECKSTATION" $extra < "$0"
fi

APPS_DIR="${DECKSTATION}/Apps"
[ -d "$APPS_DIR" ] || { echo "No encuentro $APPS_DIR" >&2; exit 1; }

# El es_find_rules.xml vive en el .home portable del AppImage de ES-DE.
# Se buscan TODOS los candidatos por si cambia de sitio.
ESDE_HOME=""
for cand in "$DECKSTATION"/DeckStation.AppImage.home/ES-DE \
            "$DECKSTATION"/DeckStation.AppImage.home/*/ES-DE \
            "$DECKSTATION"/Apps/ES-DE; do
    [ -f "$cand/custom_systems/es_find_rules.xml" ] && { ESDE_HOME="$cand"; break; }
done
RULES="${ESDE_HOME}/custom_systems/es_find_rules.xml"

echo ""
echo "  Guardian de rutas — $DECKSTATION"
echo "  ==========================================================="
echo ""

n_ok=0; n_rotas=0; n_ausentes=0; n_fragiles=0; n_ignoradas=0
lista_rotas=""; lista_ausentes=""; lista_fragiles=""

# Clasifica una entrada "./Apps/...":
#   OK      la ruta (con glob resuelto) existe
#   ROTA    el EMULADOR esta instalado (existe su carpeta en Apps/) pero el
#           fichero que apunta la regla no esta -> ES-DE no lo encontrara
#   AUSENTE el emulador no esta instalado -> no es un error
#
# El criterio de "instalado" es el PRIMER componente bajo Apps/, que es como
# esta organizada la cosa (Apps/<Emulador>/...). Asi
# ./Apps/RetroArch/RetroArch-Linux-aarch64/.../cores se marca ROTA (RetroArch
# esta instalado, el layout cambio y ese path ya no existe) en vez de
# AUSENTE, que seria un aviso blando y no serviria de nada.
clasificar() {
    local rel="$1"
    local primer sub comp=""
    local ctx="${emu} [${rule}]"

    sub="${rel#Apps/}"
    primer="${sub%%/*}"

    # Sin subcarpeta (p. ej. "./Apps/BasiliskII*.AppImage"): no hay emulador
    # que instalar, luego AUSENTE siempre.
    if [ "$primer" = "$sub" ]; then
        n_ausentes=$((n_ausentes + 1))
        lista_ausentes="${lista_ausentes}
  AUSENTE  ${ctx}  emulador sin carpeta propia, no instalado"
        return 0
    fi

    if [ ! -d "${APPS_DIR}/${primer}" ]; then
        n_ausentes=$((n_ausentes + 1))
        lista_ausentes="${lista_ausentes}
  AUSENTE  ${ctx}  Apps/${primer}/ no esta instalado"
        return 0
    fi

    # Emulador instalado: o esta el fichero o la regla esta ROTA.
    case "$rel" in
        *\**)
            comp="$(ls -d "${DECKSTATION}/${rel}" 2>/dev/null | head -1)"
            ;;
        *)
            [ -e "${DECKSTATION}/${rel}" ] && comp="${DECKSTATION}/${rel}"
            ;;
    esac

    if [ -n "${comp}" ]; then
        n_ok=$((n_ok + 1))
        [ -f "$comp" ] && [ ! -x "$comp" ] && \
            lista_rotas="${lista_rotas}
  NOEXEC   ${ctx}  ${ruta}  (existe pero sin permiso de ejecucion)"
        return 0
    fi

    n_rotas=$((n_rotas + 1))
    lista_rotas="${lista_rotas}
  ROTA     ${ctx}  ${ruta}"
    return 0
}

if [ ! -f "$RULES" ]; then
    echo "  AVISO: no encuentro es_find_rules.xml"
    echo "         (probado: $DECKSTATION/DeckStation.AppImage.home/ES-DE/custom_systems/)"
    echo ""
    echo "  Sigo solo con la revision de lanzar.sh."
    echo ""
else
    echo "  es_find_rules.xml: $RULES"
    echo "  ------------------------------------------------"
    echo "  Entradas que apuntan a ./Apps/... :"
    echo ""

    # Se parsea linea a linea manteniendo el <emulator name> y el tipo de rule
    # para poder decir QUE sistema esta roto.
    emu="?"; rule="?"; ruta="?"
    while IFS= read -r linea; do
        case "$linea" in
            *"<emulator name="*)
                e="$(printf '%s' "$linea" | sed -n 's/.*<emulator name="\([^"]*\)".*/\1/p')"
                [ -n "$e" ] && emu="$e"
                ;;
            *"<rule type="*)
                r="$(printf '%s' "$linea" | sed -n 's/.*<rule type="\([^"]*\)".*/\1/p')"
                [ -n "$r" ] && rule="$r"
                ;;
            *"<entry>"*"</entry>"*)
                entry="$(printf '%s' "$linea" | sed -n 's/.*<entry>\(.*\)<\/entry>.*/\1/p')"
                [ -n "$entry" ] || continue
                # SOLO las nuestras: rutas relativas dentro de Apps/.
                # El resto (~300) son de ES-DE upstream (flatpak, ~/.local/bin,
                # nombres de app) y se ignoran a proposito.
                case "$entry" in
                    ./Apps/*) ;;
                    *) n_ignoradas=$((n_ignoradas + 1)); continue ;;
                esac
                ruta="$entry"

                # FRAGIL: apunta a un AppImage por su nombre en vez de al
                # lanzador. Es el patron que rompio Xenia Edge (3d5aa63).
                case "$entry" in
                    */lanzar.sh) ;;
                    *.AppImage|*.appimage)
                        n_fragiles=$((n_fragiles + 1))
                        lista_fragiles="${lista_fragiles}
  FRAGIL   ${emu} [${rule}]  ${entry}"
                        ;;
                esac

                clasificar "${entry#./}"
                ;;
        esac
    done < "$RULES"

    if [ "$n_ok" -gt 0 ]; then
        echo "    $n_ok rutas de ./Apps/... existen y resuelven"
    fi
    [ "$SOLO_ROTAS" -eq 0 ] && echo "    ($n_ignoradas entradas de ES-DE upstream ignoradas a proposito)"

    if [ -n "$lista_fragiles" ]; then
        echo ""
        echo "  FRAGILES (apuntan a un AppImage por el nombre, no al lanzador):"
        printf '%s\n' "$lista_fragiles" | grep '^  ' | sort
        echo ""
        echo "    Es el patron que rompio Xenia Edge (3d5aa63). Si el upstream"
        echo "    renombra el AppImage, ES-DE deja de encontrarlo sin avisar."
    fi

    if [ -n "$lista_rotas" ]; then
        echo ""
        echo "  ROTAS (el emulador esta instalado, el fichero NO) — esto NO es normal:"
        printf '%s\n' "$lista_rotas" | grep '^  ' | sort
        echo ""
    fi

    if [ "$SOLO_ROTAS" -eq 0 ] && [ -n "$lista_ausentes" ]; then
        echo ""
        echo "  AUSENTES (emulador no instalado; NO es un error):"
        printf '%s\n' "$lista_ausentes" | grep '^  ' | sort
        echo "    en total $n_ausentes"
        echo ""
    fi
fi

# ----------------------------------------------------------------------
# B) Los lanzar.sh desplegados
# ----------------------------------------------------------------------
echo "  lanzar.sh desplegados en Apps/*/:"
echo "  ------------------------------------------------"

n_lz_ok=0; n_lz_bad=0
lista_lz=""
for app_dir in "$APPS_DIR"/*/; do
    [ -d "$app_dir" ] || continue
    app="$(basename "${app_dir%/}")"
    lz="${app_dir}lanzar.sh"

    if [ ! -f "$lz" ]; then
        # Sin lanzar.sh, pero es_find_rules.xml lo pide -> ES-DE no lo lanzara.
        if grep -q "<entry>./Apps/${app}/lanzar.sh</entry>" "$RULES" 2>/dev/null; then
            n_lz_bad=$((n_lz_bad + 1))
            lista_lz="${lista_lz}
  SIN LANZADOR  ${app}  (es_find_rules.xml lo pide y no existe)"
        fi
        continue
    fi

    if [ ! -x "$lz" ]; then
        n_lz_bad=$((n_lz_bad + 1))
        lista_lz="${lista_lz}
  SIN +x        ${app}  (lanzar.sh existe pero no es ejecutable)"
    fi

    # ¿Hay algo detras que lanzar? La plantilla mira: AppImage en la raiz,
    # app/AppRun, app/usr/bin/*, o retroarch nativo.
    tiene="no"
    find "$app_dir" -maxdepth 1 -type f -iname "*.AppImage" 2>/dev/null | grep -q . && tiene="appimage"
    [ "$tiene" = "no" ] && [ -x "${app_dir}app/AppRun" ] && tiene="appdir"
    [ "$tiene" = "no" ] && [ -x "${app_dir}retroarch" ] && tiene="nativo"
    if [ "$tiene" = "no" ]; then
        if find "$app_dir" -maxdepth 2 -type f -perm -u+x \
             ! -name "lanzar.sh" ! -name "*.sh" 2>/dev/null | grep -q .; then
            tiene="subcarpeta"
        fi
    fi

    if [ "$tiene" = "no" ]; then
        n_lz_bad=$((n_lz_bad + 1))
        lista_lz="${lista_lz}
  SIN BINARIO   ${app}  (lanzar.sh no encuentra nada que ejecutar)"
    else
        n_lz_ok=$((n_lz_ok + 1))
    fi
done

echo "    $n_lz_ok correctos, $n_lz_bad con problemas"
if [ -n "$lista_lz" ]; then
    printf '%s\n' "$lista_lz" | grep '^  ' | sort
fi
echo ""

echo "  ==========================================================="
if [ "$n_rotas" -eq 0 ] && [ "$n_lz_bad" -eq 0 ]; then
    echo "  RESULTADO: sin rutas rotas"
else
    echo "  RESULTADO: $n_rotas rutas rotas, $n_lz_bad problemas en lanzar.sh,"
    echo "            $n_fragiles rutas fragiles (ver arriba)"
fi
echo ""

[ "$n_rotas" -eq 0 ] && [ "$n_lz_bad" -eq 0 ] && exit 0
exit 1