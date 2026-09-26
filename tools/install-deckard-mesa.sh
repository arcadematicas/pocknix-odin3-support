#!/bin/bash
# install-deckard-mesa.sh — instala la Mesa (Turnip) de VALVE del Steam Frame como un payload
# MAS de /usr/share/pocknix/vk-arm, para poder compararla por juego con la nuestra.
#
# Por que como payload y no como paquete del sistema:
#   - el selector "Mesa Version" de PocknixControl (pestana Games -> Use Per-Game Settings)
#     apunta VK_DRIVER_FILES a /usr/share/pocknix/vk-arm/<version>/icd.json, asi que cualquier
#     directorio ahi es una opcion mas, sin tocar el driver del sistema.
#   - el paquete de Valve (deckard-mesa-linux-aarch64) es Mesa COMPLETO: ademas del ICD trae
#     usr/lib/libgallium-*.so y usr/lib/libfreedreno_noop_drm_shim.so. Este script copia solo
#     el driver y lo que este necesita para que el loader dinamico lo encuentre al lado.
#   - el driver de Valve pide ademas libdisplay-info con el soname .so.1 (la build de SteamOS),
#     que NO es el .so.3 que trae nuestro sistema: sin eso el ICD no carga. El script revisa
#     TODAS las dependencias con ldd y avisa de las que falten.
#   - el wrapper (pocknix-proton-wrapper) acepta el nombre COMPLETO del directorio cuando la
#     version no es una serie "X.Y" limpia, asi que el directorio se llama <version>-valve
#     (p. ej. 26.3.0-valve) y sale como opcion propia en el desplegable.
#
# Uso:
#   tools/install-deckard-mesa.sh --dry-run                  # solo dice que haria (descarga e inspecciona)
#   tools/install-deckard-mesa.sh                            # instala la ultima del repo de Valve (root)
#   tools/install-deckard-mesa.sh --file <pkg.pkg.tar.zst>   # instala un paquete ya descargado (root)
#
# Opciones:
#   --dry-run          no escribe nada en DEST_ROOT (no hace falta root)
#   --file RUTA        usa ese .pkg.tar.zst en vez de buscar la ultima version en el repo
#   --keep RUTA        guarda una copia del paquete descargado en RUTA
#   --prune            borra los otros directorios *-valve (deja el nuevo y su .prev)
#   --no-verificar     no lanza vulkaninfo al final (util sin GPU visible)
#   -h, --help         esta ayuda
#
# Al final comprueba de verdad que el ICD carga (VK_DRIVER_FILES=<payload>/icd.json
# vulkaninfo --summary) y avisa si turnip no aparece; si el fallo es culpa de un symlink
# de compatibilidad que ha creado el propio script, lo borra y deja el sistema como estaba.
#
# El recorrido del indice de Valve es el mismo que usa
# /home/fransis/deckard-paquetes/vigilar-deckard.sh (raiz + release/, mr-XXXX/, staging/,
# goldmaster/). El ICD se reescribe igual que packages/soc/pocknix-turnip-arm/PKGBUILD (~L103).
set -euo pipefail

REPO_URL="${DECKARD_REPO_URL:-https://holo-packages.steamos.cloud/archlinux-deckard-hotfixes}"
PKG_PREFIX="deckard-mesa-linux-aarch64"
DEST_ROOT="${POCKNIX_VK_ARM:-/usr/share/pocknix/vk-arm}"
SUFFIX="-valve"
# donde se busca la gemela de una lib que falta y donde se crea el symlink de compatibilidad
LIB_DIR="${POCKNIX_LIB_DIR:-/usr/lib}"
# usuario "de consola" para lanzar vulkaninfo: root no ve el /dev/dri del usuario
CONSOLE_USER="${POCKNIX_CONSOLE_USER:-deck}"

DRY_RUN=0
FILE=""
KEEP=""
PRUNE=0
VERIFICAR=1
WORK=""

# symlinks del sistema que ha hecho este script (para poder deshacerlos si algo falla)
SYMLINKS_CREADOS=()
# ficheros extra que se meten EN el payload (deps resueltas sin tocar /usr/lib)
DEPS_LOCAL=()
# sonames que siguen sin resolver -> el ICD no va a cargar
DEP_FALTANTES=()

# ----------------------------------------------------------------------------- utilidades
log()  { printf '%s\n' "$*"; }
warn() { printf 'AVISO: %s\n' "$*" >&2; }
have() { command -v "$1" >/dev/null 2>&1; }

# Deja el sistema como estaba: borra los symlinks de compatibilidad que ha creado este script.
# Solo toca lo que ha creado EL (nunca un symlink preexistente).
deshacer_symlinks() {
    local s
    if [ "${#SYMLINKS_CREADOS[@]}" -eq 0 ]; then return 0; fi
    for s in "${SYMLINKS_CREADOS[@]}"; do
        if [ -L "$s" ]; then
            rm -f "$s" || warn "no he podido borrar ${s}"
            log "   revertido: ${s} (lo habia creado este script)"
        fi
    done
    SYMLINKS_CREADOS=()
}

# con limite de tiempo, por si vulkaninfo se queda colgado
con_timeout() {  # $1 = segundos, $2... = comando
    local s="$1"; shift
    if have timeout; then timeout "$s" "$@"; else "$@"; fi
}

die()  {
    printf 'ERROR: %s\n' "$*" >&2
    [ "$DRY_RUN" -eq 1 ] || deshacer_symlinks
    exit 1
}

cleanup() {
    if [ -n "$WORK" ] && [ -d "$WORK" ]; then rm -rf "$WORK"; fi
    return 0
}
trap cleanup EXIT

usage() {
    # cabecera del script (hasta el "set -euo pipefail"), sin las almohadillas
    sed -e '1d' -e '/^set -euo/,$d' -e 's/^#\{1,\} \{0,1\}//' "${BASH_SOURCE[0]}"
    exit 0
}

# Nombre del directorio del payload: la version de Mesa SIN el sufijo de desarrollo.
# "26.3.0_devel+gitabc426bb" -> "26.3.0", y el directorio queda "26.3.0-valve". Asi el nombre es
# ESTABLE entre bumps devel/git del mismo punto de release (mismo 26.3.0 -> se sobrescribe en vez
# de acumular un directorio por hash), y el desplegable no muestra un hash de 8 caracteres.
# La pkgver completa (con _devel+git<hash>) queda en VERSION.txt dentro del directorio.
#
# El nombre tiene que EMPEZAR POR UN DIGITO a proposito: tanto mesa_versions() como
# pocknix-proton-wrapper descartan cualquier payload que no lo haga, asi que un "deckard-valve"
# no apareceria en el desplegable y el wrapper no lo resolveria nunca.
version_directorio() {
    local v="$1"
    v="${v%%+*}"        # fuera el +git<hash>
    v="${v%%_*}"        # fuera el _devel
    if [[ "$v" =~ ^([0-9]+(\.[0-9]+){0,2}) ]]; then
        printf '%s' "${BASH_REMATCH[1]}"
    else
        die "la pkgver '$1' no empieza por una version numerica ('$v'): el directorio tiene que"
        die "empezar por un digito para que lo vean mesa_versions() y el wrapper"
    fi
}

# de "deckard-mesa-linux-aarch64-<pkgver>-<pkgrel>-aarch64.pkg.tar.zst" saca "<pkgver> <pkgrel>"
parse_pkg() {
    local base="$1" rel ver
    base="${base%.pkg.tar.zst}"
    base="${base%-aarch64}"
    base="${base#"${PKG_PREFIX}-"}"
    rel="${base##*-}"                # arch: el pkgver no lleva guiones
    ver="${base%-*}"
    printf '%s %s' "$ver" "$rel"
}

descargar() {  # $1 = url, $2 = fichero destino
    log "  bajando $(basename "$1")"
    if [ -t 1 ]; then
        curl -fL --max-time 300 --progress-bar -o "$2" "$1" || die "fallo la descarga: $1"
    else
        curl -fsL --max-time 300 -o "$2" "$1" || die "fallo la descarga: $1"
    fi
}

# bsdtar (libarchive) es lo natural para .pkg.tar.zst; si no esta, zstd|tar tambien vale.
listar_miembros() {  # $1 = paquete
    if have bsdtar; then
        bsdtar -tf "$1"
    elif have zstd && have tar; then
        zstd -dc "$1" | tar -tf -
    else
        die "no encuentro bsdtar ni (zstd + tar) para leer el paquete"
    fi
}

extraer_miembros() {  # $1 = paquete, $2 = destino, $3... = miembros
    local pkg="$1" dest="$2"
    shift 2
    # --no-same-owner: aqui da igual de quien es el .so (despues se instala con
    # install -Dm755), y asi el script tambien funciona en un destino escribible sin root.
    if have bsdtar; then
        bsdtar --no-same-owner -xf "$pkg" -C "$dest" "$@"
    else
        zstd -dc "$pkg" | tar --no-same-owner -xf - -C "$dest" "$@"
    fi
}

# ¿El driver necesita libgallium? Miramos NEEDED y ademas la cadena "libgallium" en el .so,
# por si la carga con dlopen() en runtime en vez de por DT_NEEDED. readelf si esta; si no,
# patchelf --print-needed; si no hay ninguna de las dos, avisamos y seguimos a ciegas.
necesita_libgallium() {  # $1 = .so -> 0 si la necesita, 1 si no
    local so="$1" visto=0
    if have readelf; then
        if readelf -d "$so" 2>/dev/null | grep -q 'NEEDED.*libgallium'; then return 0; fi
        visto=1
    elif have patchelf; then
        if patchelf --print-needed "$so" 2>/dev/null | grep -q '^libgallium'; then return 0; fi
        visto=1
    else
        warn "ni readelf ni patchelf: no puedo comprobar si el driver necesita libgallium"
    fi
    if [ "$visto" -eq 1 ] && strings -a "$so" 2>/dev/null | grep -q 'libgallium'; then
        return 0   # la nombra a mano -> casi seguro dlopen por soname
    fi
    return 1
}

# RPATH/RUNPATH actual de un .so, o "(ninguno)"
rpath_actual() {
    local so="$1" out=""
    if have readelf; then
        # readelf imprime localized: "0x…f (RPATH)  Library rpath: [$ORIGIN]" -> "RPATH=$ORIGIN"
        out="$(readelf -d "$so" 2>/dev/null | sed -nE 's/.*\((RPATH|RUNPATH)\).*\[([^]]*)\].*/\1=\2/p' | tr '\n' ' ')"
    elif have patchelf; then
        local r
        r="$(patchelf --print-rpath "$so" 2>/dev/null || true)"
        if [ -n "$r" ]; then out="RPATH=$r"; fi
    fi
    if [ -z "$out" ]; then out="(ninguno)"; fi
    printf '%s' "$out"
}

# ----------------------------------------------------------------- dependencias del driver
# El driver de Valve esta compilado contra las libs de SteamOS, no contra las nuestras: el caso
# que nos ha pasado es libdisplay-info, que SteamOS construye con soname libdisplay-info.so.1 y
# nuestro sistema (libdisplay-info 0.3.0) instala libdisplay-info.so.3. El loader solo busca
# por soname EXACTO, asi que sin un .so.1 el ICD no carga (y no da ningun error visible).

# Arquitectura de un .so, en el formato de "uname -m".
# LC_ALL=C es OBLIGATORIO: readelf sale traducido ("Máquina:") segun el locale y el patron
# no encaja. (Los tokens tecnicos como NEEDED o RPATH si se mantienen, pero no hay que fiarse.)
maquina_de() {  # $1 = .so
    local ma
    [ -f "$1" ] || return 1
    ma="$(LC_ALL=C readelf -h "$1" 2>/dev/null | sed -nE 's/^[[:space:]]*Machine:[[:space:]]*(.*)$/\1/p')"
    case "$ma" in
        *AArch64*)    printf 'aarch64' ;;
        *X86-64*)     printf 'x86_64' ;;
        *Intel*80386*) printf 'i686' ;;
        *ARM*)        printf 'arm' ;;
        *RISC-V*)     printf 'riscv64' ;;
        *)            printf 'desconocida' ;;
    esac
}

# sonames de DT_NEEDED
necesitados() {  # $1 = .so
    if have readelf; then
        LC_ALL=C readelf -d "$1" 2>/dev/null | sed -nE 's/.*\(NEEDED\).*\[([^]]+)\].*/\1/p'
    elif have patchelf; then
        patchelf --print-needed "$1" 2>/dev/null
    fi
}

# ¿El loader del sistema encontraria este soname? (cache de ldconfig + directorios habituales)
soname_resuelto() {  # $1 = soname
    local s="$1" d
    if have ldconfig && ldconfig -p 2>/dev/null | awk -v s="$s" '$1 == s { f = 1 } END { exit !f }'; then
        return 0
    fi
    for d in "$LIB_DIR" /usr/lib /lib /usr/lib/aarch64-linux-gnu /usr/local/lib; do
        if [ -e "$d/$s" ]; then return 0; fi
    done
    return 1
}

# ldd solo vale si el .so es de la misma arquitectura que este host (nuestro PC es x86_64 y el
# driver es aarch64: ldd no vale y hay que mirar DT_NEEDED a mano)
ldd_utilizable() {  # $1 = .so
    have ldd || return 1
    [ "$(maquina_de "$1")" = "$(uname -m)" ] || return 1
    return 0
}

# sonames que el loader NO encuentra, uno por linea.
# El cargador dinamico (ld-linux*, linux-vdso*) se descarta: no es una libreria que se pueda
# arreglar con un symlink, y si de verdad faltara no arrancaria NADA, tampoco este driver.
deps_faltantes() {  # $1 = .so
    local so="$1" s
    if ldd_utilizable "$so"; then
        ldd "$so" 2>/dev/null | awk '/not found/ { print $1 }' | sort -u | grep -vE '^(ld-|ld\.so|linux-vdso|linux-gate)'
        return 0
    fi
    while read -r s; do
        [ -n "$s" ] || continue
        case "$s" in ld-*|ld\.so*|linux-vdso*|linux-gate*) continue ;; esac
        soname_resuelto "$s" || printf '%s\n' "$s"
    done < <(necesitados "$so")
}

# Una lib con el MISMO nombre base y otro soname. Es el apaño clasico de ABI: SteamOS tiene
# libdisplay-info.so.1 y el fichero real es libdisplay-info.so.0.3.0 (= .so.3 aqui).
# LIB_DIR tiene prioridad (es donde va a mirar el loader) y, dentro de un directorio, se queda
# con la version mas alta. sort -V ordena como numeros de version: .so.0 < .so.0.3.0 < .so.3.
buscar_lib_hermana() {  # $1 = soname pedido -> ruta del fichero
    local soname="$1" base="${1%%.so*}" cands f d
    for d in "$LIB_DIR" "/usr/lib" "/lib" "/usr/lib/aarch64-linux-gnu" "/usr/local/lib"; do
        [ -d "$d" ] || continue
        cands="$(for f in "$d/$base".so.*; do
                    [ -f "$f" ] || continue                 # -f: sigue symlinks, queremos el fichero
                    [ "${f##*/}" = "$soname" ] && continue  # no es justo lo que buscamos
                    printf '%s\n' "${f##*/}"                 # version relative al directorio
                 done | sort -V)"
        if [ -n "$cands" ]; then
            printf '%s/%s' "$d" "$(printf '%s\n' "$cands" | tail -n 1)"
            return 0
        fi
    done
    return 1
}

# Comprobacion final de verdad: cargar el ICD del payload en el Vulkan loader y mirar que sale
# turnip. Sin esto, un driver con una dependencia sin resolver se instala "bien" y falla luego
# en pleno juego, sin decir nada.
verificar_icd() {  # $1 = icd.json instalado -> 0 si el driver carga
    local icd="$1" out="" quien="" falta=0 resumen=""
    if [ "$DRY_RUN" -eq 1 ]; then
        log "   [dry-run] VK_DRIVER_FILES=${icd} vulkaninfo --summary"
        return 0
    fi
    if ! have vulkaninfo; then
        warn "vulkaninfo no esta instalado: no puedo comprobar que el ICD cargue"
        warn "  (paquete 'vulkan-tools'); el payload queda instalado pero SIN verificar"
        return 0
    fi
    # root no ve el /dev/dri del usuario: se prueba como el usuario de la sesion
    if [ "$(id -u)" -eq 0 ] && have runuser && id -u "$CONSOLE_USER" >/dev/null 2>&1; then
        quien=" (como '${CONSOLE_USER}': root no ve el nodo de render)"
        out="$(con_timeout 60 runuser -u "$CONSOLE_USER" -- \
                env VK_DRIVER_FILES="$icd" vulkaninfo --summary 2>&1)" || falta=1
    else
        out="$(con_timeout 60 env VK_DRIVER_FILES="$icd" vulkaninfo --summary 2>&1)" || falta=1
    fi
    resumen="$(printf '%s\n' "$out" | grep -Ei 'deviceName|driverName|driverInfo|apiVersion|ERROR|error:' \
        | sed 's/^[[:space:]]*/     /' || true)"
    if [ -n "$resumen" ]; then
        printf '%s\n' "$resumen"
    else
        # ni una linea util: al menos las primeras, que es donde esta el motivo
        printf '%s\n' "$out" | head -n 8 | sed 's/^[[:space:]]*/     /'
    fi

    if ! printf '%s' "$out" | grep -qi 'turnip'; then
        warn "el ICD de ${DEST} NO ha cargado: vulkaninfo no ve ningun driver turnip${quien}"
        if [ "$falta" -ne 0 ]; then
            warn "  vulkaninfo ha fallado o se ha colgado (timeout 60 s)"
        fi
        if [ "${#DEP_FALTANTES[@]}" -gt 0 ]; then
            warn "  dependencias sin resolver: ${DEP_FALTANTES[*]}"
        fi
        if [ "${#SYMLINKS_CREADOS[@]}" -gt 0 ]; then
            warn "  quito el apaño que he hecho, para no dejar basura en el sistema:"
            deshacer_symlinks
        fi
        return 1
    fi
    if printf '%s' "$out" | grep -q "$VERSION"; then
        log "   OK${quien}: el ICD carga y el driver es turnip ${VERSION}"
    else
        warn "el ICD carga con turnip, pero no veo la version esperada (${VERSION}) en el resumen:"
        warn "  revisa 'driverInfo' arriba: puede ser que el paquete no sea el que creias"
    fi
    return 0
}

# ----------------------------------------------------------------------------- argumentos
while [ $# -gt 0 ]; do
    case "$1" in
        --dry-run) DRY_RUN=1; shift ;;
        --file)    FILE="${2:?--file necesita una ruta}"; shift 2 ;;
        --keep)    KEEP="${2:?--keep necesita un directorio}"; shift 2 ;;
        --prune)   PRUNE=1; shift ;;
        --no-verificar) VERIFICAR=0; shift ;;
        -h|--help) usage ;;
        *)         die "opcion desconocida: $1 (--help para la ayuda)" ;;
    esac
done

WORK="$(mktemp -d)"

# ----------------------------------------------------------------------------- 1) paquete
PKGVER=""; PKGREL=""; PKG_URL=""; PKG_FILE=""
if [ -n "$FILE" ]; then
    [ -f "$FILE" ] || die "no existe el paquete: $FILE"
    PKG_FILE="$FILE"
    read -r PKGVER PKGREL <<<"$(parse_pkg "$(basename "$FILE")")"
    PKG_URL="(paquete local) $FILE"
    log "== MESA DE VALVE (paquete local, sin red) =="
else
    log "== MESA DE VALVE: buscando la ultima en el repo de Valve =="
    log "   repo: $REPO_URL"
    mkdir -p "$WORK/idx"
    curl -fs --max-time 60 "$REPO_URL/" -o "$WORK/idx/root.html" || die "no se pudo descargar el indice del repo"

    # mismo regex que vigilar-deckard.sh; "%2B" es el '+' escapado en el indice
    grep -oE 'href="[^"]+/"' "$WORK/idx/root.html" | sed 's/href="//;s/\/"//' \
        | grep -vE '^(\.\.?|Parent)' | sort -u > "$WORK/idx/dirs" || true
    NDIRS="$(grep -c . "$WORK/idx/dirs" || true)"
    log "   subcarpetas: ${NDIRS} (release/, mr-XXXX/, staging/, goldmaster/...)"

    CANDS="$WORK/cands"
    {
        grep -oE "${PKG_PREFIX}-[0-9][^\"<]*\.pkg\.tar\.zst" "$WORK/idx/root.html" | sed 's/%2B/+/g' \
            | sed "s|^|${REPO_URL}/|"
        # en paralelo: 46 subcarpetas x curl tardaba ~47 s en serie
        if [ "${NDIRS:-0}" -gt 0 ]; then
            xargs -P 8 -I{} sh -c "curl -fs --max-time 30 '${REPO_URL}/{}/' 2>/dev/null \
                | grep -oE '${PKG_PREFIX}-[0-9][^\"<]*\.pkg\.tar\.zst' \
                | sed 's/%2B/+/g' | sed 's|^|${REPO_URL}/{}/|'" < "$WORK/idx/dirs" || true
        fi
    } | grep -E "^${REPO_URL}/.*${PKG_PREFIX}-[0-9].*\.pkg\.tar\.zst$" | sort -u > "$CANDS"
    [ -s "$CANDS" ] || die "el repo no ofrece ningun ${PKG_PREFIX}-*.pkg.tar.zst"

    log "   candidatos:"
    sed 's/^/     /' "$CANDS"

    # pkgver mas alta: sort -V ordena por la serie (sin el +git<hash>), luego la raiz del repo
    # gana al empatar (goldmaster/staging/mr-* son canales de trabajo, no release), luego nombre.
    BEST="$(while read -r url; do
                name="${url##*/}"
                read -r ver rel <<<"$(parse_pkg "$name")"
                serie="${ver%%+*}"
                is_root=0
                case "$url" in "${REPO_URL}/"*) is_root=1 ;; esac
                printf '%s\t%s\t%s\t%s\t%s\n' "$serie" "$is_root" "$ver" "$rel" "$url"
            done < "$CANDS" | sort -V | tail -1)"
    read -r _serie _is_root PKGVER PKGREL PKG_URL <<<"$BEST"
    [ -n "$PKG_URL" ] || die "no se pudo elegir ningun paquete"
    log ""
    log "   elegido: pkgver=${PKGVER} pkgrel=${PKGREL}"
    log "            ${PKG_URL}"

    PKG_FILE="$WORK/${PKG_URL##*/}"
    descargar "$PKG_URL" "$PKG_FILE"
fi

VERSION="$(version_directorio "$PKGVER")"
DEST="${DEST_ROOT}/${VERSION}${SUFFIX}"
PREV="${DEST}.prev"
log ""
log "   pkgver     : ${PKGVER}"
log "   directorio : ${DEST}"
if [ "$DRY_RUN" -eq 1 ]; then
    log "   MODO DRY-RUN: no se escribe nada en ${DEST_ROOT}"
fi

if [ -n "$KEEP" ]; then
    mkdir -p "$KEEP"
    cp -f "$PKG_FILE" "$KEEP/"
    log "   copia del paquete: ${KEEP}/${PKG_FILE##*/}"
fi

# ----------------------------------------------------------------------------- 2) extraer
STAGE="$WORK/stage"
mkdir -p "$STAGE"
log ""
log "== Extrayendo del paquete =="
# listamos primero para no depender de los globs de bsdtar/tar
mapfile -t WANT < <(
    listar_miembros "$PKG_FILE" | grep -E \
'^usr/lib/libvulkan_freedreno\.so$|^usr/lib/libgallium-[^/]*\.so$|^usr/lib/libfreedreno_noop_drm_shim\.so$|^usr/share/vulkan/icd\.d/freedreno_icd[^/]*\.json$'
)
if [ "${#WANT[@]}" -eq 0 ]; then
    die "el paquete no trae ni libvulkan_freedreno.so ni el ICD de freedreno"
fi
printf '   %s\n' "${WANT[@]}"
extraer_miembros "$PKG_FILE" "$STAGE" "${WANT[@]}"

SO="$STAGE/usr/lib/libvulkan_freedreno.so"
ICD=""
for m in "${WANT[@]}"; do
    case "$m" in
        usr/share/vulkan/icd.d/*.json) ICD="$m"; break ;;
    esac
done
[ -f "$SO" ] || die "no se extrajo libvulkan_freedreno.so"
[ -n "$ICD" ] || die "no se extrajo el ICD de freedreno"

# ----------------------------------------------------------------------------- 3) enlazado
log ""
log "== Enlazado =="
GALLIUM=0
for f in "$STAGE"/usr/lib/libgallium-*.so; do
    if [ -f "$f" ]; then GALLIUM=1; fi
done
NEEDS_GALLIUM=0
if necesita_libgallium "$SO"; then
    NEEDS_GALLIUM=1
    log "   el driver NECESITA libgallium"
elif [ "$GALLIUM" -eq 1 ]; then
    log "   el driver NO necesita libgallium (no esta en NEEDED ni la nombra para dlopen)"
    log "   -> se copia igualmente: esta en el paquete y sirve si Valve cambia el build"
else
    log "   el driver NO necesita libgallium (y el paquete no trae libgallium-*.so)"
fi

# ------------------------------------------------------------------ 3b) dependencias
log ""
log "== Dependencias del driver =="
if ldd_utilizable "$SO"; then
    log "   ldd ${SO##*/} ($(maquina_de "$SO"))"
else
    log "   ldd NO utilizable (${SO##*/} es $(maquina_de "$SO") y este host es $(uname -m)):"
    log "   reviso a mano los DT_NEEDED (sonames que el loader no encuentra)"
fi
mapfile -t FALTAN < <(deps_faltantes "$SO")
if [ "${#FALTAN[@]}" -eq 0 ]; then
    log "   todas las dependencias resuelven"
else
    log "   SIN RESOLVER (${#FALTAN[@]}):"
    printf '     - %s\n' "${FALTAN[@]}"
fi

for soname in ${FALTAN[@]+"${FALTAN[@]}"}; do
    case "$soname" in
        libdisplay-info.so.*)
            # Valve la pide con el soname de SteamOS (.so.1) y nosotros tenemos .so.3
            src="$(buscar_lib_hermana "$soname" || true)"
            if [ -z "$src" ]; then
                warn "${soname}: no hay NINGUNA libdisplay-info en el sistema. El ICD no cargara."
                warn "  instala la del sistema (paquete 'libdisplay-info') y repite el script."
                DEP_FALTANTES+=("$soname")
                continue
            fi
            log "   ${soname}: en el sistema si hay, pero con otro soname -> ${src##*/}"
            if have patchelf; then
                # Lo mejor: copia DENTRO del payload + RPATH $ORIGIN. No se toca /usr/lib y el
                # payload es autocontenido (es lo que hace falta si libdisplay-info actualiza).
                # En dry-run tambien se copia: el scratch es un temporal, no el sistema.
                install -Dm644 "$src" "$STAGE/usr/lib/$soname"
                DEPS_LOCAL+=("$STAGE/usr/lib/$soname")
                log "   copiada al payload como ${soname} con RPATH \$ORIGIN: /usr/lib NO se toca"
            else
                warn "patchelf NO esta instalado: no puedo meter ${soname} en el payload con RPATH"
                warn "   -> creo el symlink ${LIB_DIR}/${soname} -> ${src##*/}"
                warn "   es un apaño: si libdisplay-info cambia de soname, hay que repetir esto"
                if [ "$DRY_RUN" -eq 1 ]; then
                    log "   [dry-run] ln -sfn ${src##*/} ${LIB_DIR}/${soname}"
                else
                    [ -w "$LIB_DIR" ] || die "no puedo escribir en ${LIB_DIR}: hace falta root"
                    # relativa si la gemela esta en el mismo directorio (enlazado en cadena),
                    # absoluta si vino de otro sitio
                    if [ "${src%/*}" = "$LIB_DIR" ]; then
                        ln -sfn "${src##*/}" "$LIB_DIR/$soname"
                    else
                        ln -sfn "$(readlink -f "$src")" "$LIB_DIR/$soname"
                    fi
                    SYMLINKS_CREADOS+=("$LIB_DIR/$soname")
                fi
            fi
            ;;
        *)
            warn "${soname} no se resuelve y este script no sabe arreglarlo:"
            warn "  el ICD de Valve CASI SEGURAMENTE no cargara. Instala la libreria que lo pide."
            DEP_FALTANTES+=("$soname")
            ;;
    esac
done

# hace falta $ORIGIN si el driver busca algo que hemos puesto AL LADO (libgallium o una dep)
NEEDS_ORIGIN="$NEEDS_GALLIUM"
for f in ${DEPS_LOCAL[@]+"${DEPS_LOCAL[@]}"}; do
    NEEDS_ORIGIN=1
done

# ----------------------------------------------------------------------------- 3c) RPATH
if [ "$NEEDS_ORIGIN" -eq 1 ]; then
    if have patchelf; then
        # --force-rpath = DT_RPATH (no RUNPATH): el loader solo busca en el DT_RPATH del objeto
        # que llama a dlopen(), asi que es lo que hace falta para hallar las libs al vuelo.
        log ""
        log "   aplicando: patchelf --force-rpath --set-rpath '\$ORIGIN'"
        patchelf --force-rpath --set-rpath '$ORIGIN' "$SO"
        R="$(rpath_actual "$SO")"
        case "$R" in
            *'$ORIGIN'*) log "   RPATH verificado: ${R}" ;;
            *) die "el RPATH no ha quedado en \$ORIGIN (queda: ${R})" ;;
        esac
    else
        warn "patchelf NO esta instalado: el driver se queda SIN RPATH \$ORIGIN y podria no"
        warn "encontrar libgallium. Instalalo con 'sudo pacman -S patchelf' y repite."
    fi
else
    log "   sin patchelf: no hace falta (no hay nada que buscar junto al driver)"
fi
RPATH_FINAL="$(rpath_actual "$SO")"

# ----------------------------------------------------------------------------- 4) instalar
log ""
log "== Instalando =="
FILES=()
for f in "$SO" "$STAGE"/usr/lib/libgallium-*.so "$STAGE"/usr/lib/libfreedreno_noop_drm_shim.so \
         ${DEPS_LOCAL[@]+"${DEPS_LOCAL[@]}"}; do
    if [ -f "$f" ]; then FILES+=("$(basename "$f")"); fi
done

if [ "$DRY_RUN" -eq 1 ]; then
    log "   [dry-run] mkdir -p ${DEST}"
    for n in "${FILES[@]}"; do
        log "   [dry-run] install -Dm755 ${STAGE}/usr/lib/${n}  ->  ${DEST}/${n}"
    done
    log "   [dry-run] sed -E 's|\"library_path\": *\"[^\"]*\"|\"library_path\": \"${DEST}/libvulkan_freedreno.so\"|'"
    log "            ${STAGE}/${ICD}  ->  ${DEST}/icd.json   (chmod 0644)"
    log "   [dry-run] ${DEST}/VERSION.txt  (pkgver, pkgrel, origen y fecha)"
    if [ -e "$DEST" ]; then
        log "   [dry-run] ${DEST} ya existe -> se renombraria a ${PREV}"
    fi
else
    [ "$(id -u)" -eq 0 ] || die "instalar en ${DEST_ROOT} necesita root (usa sudo, o --dry-run)"
    mkdir -p "$DEST_ROOT"
    # idempotente: si ya estaba ESTA version, se aparta a .prev antes de escribir la nueva
    if [ -e "$DEST" ]; then
        if [ -e "$PREV" ]; then
            warn "${PREV} ya existia: lo borro (solo se conserva una version anterior)"
            rm -rf "$PREV"
        fi
        log "   ${DEST} existia -> ${PREV}"
        mv "$DEST" "$PREV"
        # el .prev no debe verse como opcion: el wrapper matchea p.name == version, con lo que
        # un "<version>-valve.prev" CON icd.json entraria como candidato empatado con el nuevo.
        if [ -f "$PREV/icd.json" ]; then
            mv "$PREV/icd.json" "$PREV/icd.json.prev"
            log "   ${PREV}/icd.json -> icd.json.prev (que no se pueda elegir por error)"
        fi
    fi
    mkdir -p "$DEST"
    for n in "${FILES[@]}"; do
        install -Dm755 "$STAGE/usr/lib/$n" "$DEST/$n"
    done
    # mismo reescrito que packages/soc/pocknix-turnip-arm/PKGBUILD (~linea 103): el ICD de Valve
    # apunta a /usr/lib/libvulkan_freedreno.so, que aqui no existe -> ruta absoluta instalada.
    sed -E "s|\"library_path\": *\"[^\"]*\"|\"library_path\": \"${DEST}/libvulkan_freedreno.so\"|" \
        "$STAGE/$ICD" > "$DEST/icd.json"
    chmod 0644 "$DEST/icd.json"
    {
        printf 'pkgver: %s\n' "$PKGVER"
        printf 'pkgrel: %s\n' "$PKGREL"
        printf 'origen: %s\n' "$PKG_URL"
        printf 'instalado: %s\n' "$(date -Iseconds)"
        printf 'instalado por: tools/install-deckard-mesa.sh\n'
    } > "$DEST/VERSION.txt"
    chmod 0644 "$DEST/VERSION.txt"
    log "   escrito en ${DEST}"
    if [ "$PRUNE" -eq 1 ]; then
        for d in "$DEST_ROOT"/*"${SUFFIX}" "$DEST_ROOT"/*"${SUFFIX}.prev"; do
            if [ -d "$d" ] && [ "$d" != "$DEST" ] && [ "$d" != "$PREV" ]; then
                log "   --prune: borro ${d}"
                rm -rf "$d"
            fi
        done
    fi
fi

# ----------------------------------------------------------------------------- 5) verificar
log ""
log "== Verificacion =="
VERIF_OK="(no comprobada)"
if [ "$DRY_RUN" -eq 1 ]; then
    log "   [dry-run] VK_DRIVER_FILES=${DEST}/icd.json vulkaninfo --summary"
    VERIF_OK="(dry-run: no comprobada)"
elif [ "$VERIFICAR" -eq 1 ]; then
    if verificar_icd "$DEST/icd.json"; then
        VERIF_OK="OK (vulkaninfo ve turnip)"
    else
        VERIF_OK="FALLO (vulkaninfo NO ve turnip)"
    fi
else
    log "   --no-verificar: me salto vulkaninfo"
fi

# ----------------------------------------------------------------------------- 6) resumen
log ""
log "== RESUMEN =="
log "   Mesa de Valve    : ${VERSION}${SUFFIX}"
if [ "$DRY_RUN" -eq 1 ]; then
    log "   Directorio       : ${DEST}  (dry-run: NO escrito)"
else
    log "   Directorio       : ${DEST}"
fi
log "   Ficheros         : ${FILES[*]}"
log "   ICD              : ${DEST}/icd.json  (library_path = ${DEST}/libvulkan_freedreno.so)"
log "   RPATH del driver : ${RPATH_FINAL}"
if [ "$NEEDS_GALLIUM" -eq 1 ]; then
    log "   libgallium       : necesaria"
else
    log "   libgallium       : no necesaria"
fi
if [ "${#DEP_FALTANTES[@]}" -gt 0 ]; then
    log "   Deps SIN resolver: ${DEP_FALTANTES[*]}  <- el ICD no cargara"
else
    log "   Deps sin resolver: ninguna"
fi
if [ "${#SYMLINKS_CREADOS[@]}" -gt 0 ]; then
    log "   Symlinks apaño   : ${SYMLINKS_CREADOS[*]}"
fi
log "   Verificacion     : ${VERIF_OK}"

if [ "$DRY_RUN" -eq 0 ]; then
    log ""
    log "   Contenido:"
    ls -l "$DEST" | sed 's/^/     /'
    log ""
    log "   Como elegirla (POR JUEGO; no esta en el menu global del QAM):"
    log "     PocknixControl -> pestana Games -> juego -> 'Use Per-Game Settings' -> 'Mesa Version'"
    log "     -> elegir '${VERSION}${SUFFIX}'"
    log "   Otros directorios '${SUFFIX}*' ya instalados:"
    otros=0
    for d in "$DEST_ROOT"/*"${SUFFIX}"*; do
        if [ -d "$d" ] && [ "$d" != "$DEST" ]; then
            log "     - ${d}"
            otros=1
        fi
    done
    if [ "$otros" -eq 0 ]; then
        log "     (ninguno)"
    fi
else
    log ""
    log "   (dry-run: no se ha tocado ${DEST_ROOT})"
fi
