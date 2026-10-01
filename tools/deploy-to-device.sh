#!/bin/bash
# deploy-to-device.sh — compila un paquete NUESTRO y lo instala en la Odin por SSH.
#
# POR QUÉ EXISTE
#   Flashear la imagen entera (~30-45 min) solo hace falta para distribuir o para una
#   instalación desde cero. Para ITERAR sobre el sistema no hace falta nada de eso: se
#   compila el paquete afectado y se instala en caliente por SSH, que son minutos.
#
# QUÉ HACE (instalar)
#   0. comprueba que la Odin responde
#   1. sync-to-os.sh   (aplica el centro al árbol de compilación)
#   2. make packages PKG="..."  (compila solo esos)
#   3. busca los .pkg.tar.* recién compilados
#   4. scp + pacman -U --noconfirm --overwrite <rutas de runtime> en la Odin
#   5. reinicia los servicios afectados (el loader de Decky solo si no hay Steam)
#   6. estado final: systemctl --failed + el --check del desfase
#
# USO
#   tools/deploy-to-device.sh pocknix-bsp-sm8750
#   tools/deploy-to-device.sh pocknix-decky pocknix-tools        # varios de golpe
#   tools/deploy-to-device.sh --check                            # ver el DESFASE y salir
#   tools/deploy-to-device.sh --dry-run pocknix-decky             # ver qué haría, sin hacerlo
#
#   DEVICE_HOST=odin tools/deploy-to-device.sh ...   # por Tailscale en vez de por la LAN
#   NO_RESTART=1   tools/deploy-to-device.sh ...     # no reinicia NADA al terminar
#   FORCE_RESTART=1 tools/deploy-to-device.sh ...     # reinicia el loader aun con Steam en juego
#   PC_SUDO_PASS=... tools/deploy-to-device.sh ...   # sudo del PC para `make packages`
#
# ENTORNO
#   DEVICE_HOST      Odin. Default `odin-local` (192.168.4.22, la de casa). El alias
#                    `odin` de ~/.ssh/config es la de Tailscale (cambia de IP); también
#                    se acepta ODIN_HOST, el nombre que usa tools/flash-kernel.sh.
#   DEVICE           placa del build tree. Default sm8750.
#   DEVICE_SUDO_PASS sudo de 'deck' en la Odin. Default `pocknix` (la de la imagen).
#   PC_SUDO_PASS     sudo del PC, solo para el `make packages` (monta un chroot aarch64).
#
# 🔑 SUDO: askpass, NUNCA la contraseña en la línea de órdenes
#   `echo pocknix | sudo -S ...` deja la contraseña en el argv del ssh y del shell remoto
#   (la ven cualquiera con `ps`, y queda en el historial). Aquí se sube un askpass helper
#   a /tmp de la Odin, modo 700, y se usa `sudo -A` con SUDO_ASKPASS. Se borra al salir.
#   `--check` NO necesita sudo en absoluto: `pacman -Q` lee como 'deck'.
#
# ⚠️ LO QUE ESTÁ PROHIBIDO EN ESTE SCRIPT (AGENTS.md, "Estados CRÍTICOS")
#   Reiniciar pocknix-decky-loader en caliente con Steam corriendo -> CRASH LOOP de
#   steamwebhelper (NameError en main.py:118). Por eso el paso 5 mira antes si hay Steam
#   o sesión gráfica, y si la hay NO reinicia el loader: lo dice y sigue. FORCE_RESTART=1
#   lo fuerza, pero solo si sabes lo que haces.
#
# OJO: esto instala lo compilado, NO cambia el repo. Si tocas algo a mano en la Odin para
# probar, tráelo al centro después (regla de oro: el centro es la fuente de verdad).
set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
OS="${POCKNIX_OS_DIR:-${HERE}/../pocknix-os}"
DEVICE="${DEVICE:-sm8750}"
# La Odin de casa. `odin-local` = 192.168.4.22 (alias de ~/.ssh/config). El 192.168.4.29
# que tenía antes era la IP Tailscale de OTRA máquina (ArmadaOS), no la Odin: deploy fallaba.
HOST="${DEVICE_HOST:-${ODIN_HOST:-odin-local}}"
DEVICE_SUDO_PASS="${DEVICE_SUDO_PASS:-pocknix}"

CHECK=0
DRY=0
STRICT=0
PKGS=""
REMOTE_ASKPASS=""
LOCAL_ASKPASS=""

usage() { sed -n '2,/^set -euo/p' "${BASH_SOURCE[0]}" | sed 's/^# \{0,1\}//; $d'; }

while [ "$#" -gt 0 ]; do
  case "$1" in
    --check)     CHECK=1 ;;
    --dry-run)   DRY=1 ;;
    --strict)    STRICT=1 ;;   # con --check: también falla si un paquete NO está instalado
    -h|--help)   usage; exit 0 ;;
    -*)          echo "opción desconocida: $1 (prueba --help)" >&2; exit 2 ;;
    *)           PKGS="${PKGS:-} $1" ;;
  esac
  shift
done
PKGS="${PKGS# }"

# El askpass helper se monta en local y en la Odin SOLO cuando hace falta sudo, y se
# limpia al salir aunque el script se muera a mitad.
cleanup() {
  [ -n "${LOCAL_ASKPASS}" ] && rm -f "${LOCAL_ASKPASS}" "${LOCAL_ASKPASS}.pass"
  if [ -n "${REMOTE_ASKPASS}" ]; then
    ssh "${HOST}" "rm -f '${REMOTE_ASKPASS}' '${REMOTE_ASKPASS}.pass'" 2>/dev/null || true
  fi
}
trap cleanup EXIT

# --- helpers de -------------------------------------------------------------

ssh_do()  { ssh -o BatchMode=yes "${HOST}" "$@"; }

# ¿Hay Steam o sesión gráfica viva? Imprime lo que encuentra; vacío = seguro reiniciar.
# Tres señales, porque cada una se puede escapar:
#   1. el sentinel de sesión que escribe steamos-session-select (gamescope|plasma)
#   2. procesos: gamescope = Game Mode, kwin/plasmashell = escritorio, steam* = cliente
#   3. sesiones de loginctl de tipo x11/wayland
# El `echo` del final es para que la salida acabe en salto de línea aunque no haya nada.
session_probe() {
  ssh_do 's=$(cat /home/deck/.local/state/pocknix-session 2>/dev/null || true)
          [ -n "$s" ] && printf "sesion:%s " "$s"
          for p in gamescope steam steamwebhelper kwin_wayland kwin_x11 plasmashell sddm; do
            pgrep -x "$p" >/dev/null 2>&1 && printf "proc:%s " "$p"
          done
          loginctl list-sessions --no-legend 2>/dev/null | while read -r id rest; do
            t=$(loginctl show-session "$id" -p Type --value 2>/dev/null)
            case "$t" in x11|wayland) printf "login:%s(%s) " "$id" "$t";; esac
          done
          echo' 2>/dev/null || true
}

# Prepara el askpass (local + remoto). La contraseña viaja en un fichero 700, nunca en argv.
askpass_setup() {
  [ -n "${REMOTE_ASKPASS}" ] && return 0
  LOCAL_ASKPASS="$(mktemp "${TMPDIR:-/tmp}/pocknix-askpass.XXXXXX")"
  cat > "${LOCAL_ASKPASS}" <<'EOF'
#!/bin/sh
exec cat "${0}.pass"
EOF
  printf '%s\n' "${DEVICE_SUDO_PASS}" > "${LOCAL_ASKPASS}.pass"
  chmod 700 "${LOCAL_ASKPASS}" "${LOCAL_ASKPASS}.pass"
  # scp no puede renombrar: se sube a /tmp con el nombre del mktemp y se mueve al nombre
  # final (que incluye el PID, para no pisar el de otra instancia).
  REMOTE_ASKPASS="/tmp/.pocknix-askpass.$$"
  scp -q "${LOCAL_ASKPASS}" "${LOCAL_ASKPASS}.pass" "${HOST}:/tmp/" 2>/dev/null \
    || { echo "no pude subir el askpass a ${HOST}" >&2; exit 1; }
  local l
  l="$(basename "${LOCAL_ASKPASS}")"
  ssh_do "mv '/tmp/${l}' '${REMOTE_ASKPASS}' && mv '/tmp/${l}.pass' '${REMOTE_ASKPASS}.pass' && chmod 700 '${REMOTE_ASKPASS}' '${REMOTE_ASKPASS}.pass'" \
    || { echo "no pude preparar el askpass en ${HOST}" >&2; exit 1; }
}

# Corre algo como root en la Odin sin contraseña en la línea de órdenes.
#
# ⚠️ SIN `sh -c` A PROPÓSITO, y esto ya costó un bug: si se mete un texto ya citado dentro de
# `sh -c`, ese texto lo parsea el shell de ssh Y luego el de `sh -c` (DOS veces). Los `*` de
# `--overwrite` llegaban al segundo parseo como globs de verdad y se expandían contra el disco:
# pacman se comía `/opt/deckstation/Apps /opt/deckstation/arte …` como si fueran paquetes y
# moría con "cannot open package file" por 30 líneas. Con los args citados uno a uno (%q,
# que escapa el `*`) y viajando como argv de sudo, hay UN solo parseo y pacman recibe el
# glob literal. Por eso aquí no se pueden usar operadores de shell (&&, |, >): hay que
# llamar a lo que haga falta por separado.
dsudo() {
  local q=() a
  for a in "$@"; do
    local esc
    printf -v esc '%q' "${a}"
    q+=("${esc}")
  done
  ssh_do "SUDO_ASKPASS='${REMOTE_ASKPASS}' sudo -A ${q[*]}"
}

# ─────────────────────────────────────────────────────────────────────────────
# MODO COMPROBACIÓN: ¿la Odin está igualada al centro?
# ─────────────────────────────────────────────────────────────────────────────
# Compara, para cada paquete NUESTRO que tiene PKGBUILD en el centro, la versión
# instalada en la Odin contra la del PKGBUILD. No compila, no instala, no pide sudo.
# Salida: 0 = igualado · 1 = hay desfase · 2 = no se puede comprobar.
#
# Solo se miran los paquetes con PKGBUILD (los que versionamos nosotros). Los directorios
# sin PKGBUILD (pocknix-steam, pocknix-tools, soc-overrides/…) son parches sobre paquetes
# de upstream: su versión es la de upstream y no la nuestra, así que no se comparan.
centre_pkgs() {
  local f
  for f in "${HERE}"/packages/*/PKGBUILD "${HERE}"/packages/soc-overrides/*/PKGBUILD; do
    [ -f "${f}" ] || continue
    # Un PKGBUILD solo define variables y funciones, así que sourcearlo no ejecuta nada.
    # Hace falta para resolver los pkgver=${_var} (p. ej. el bootloader: 1.1.8).
    ( set +u +e
      unset pkgname pkgver pkgrel epoch
      # shellcheck disable=SC1090
      source "${f}" >/dev/null 2>&1
      [ -n "${pkgname:-}" ] || exit 1
      case "${pkgver:-}" in ''|*'$'*) exit 2;; esac   # vacío o dinámico -> no comparable
      # pacman imprime "epoch:pkgver-pkgrel" y solo si el epoch no es 0 (ej. gamescope,
      # que es 1:3.16... por el parche de fps). Sin esto salía como DESFASE falso.
      local e=""
      [ -n "${epoch:-}" ] && [ "${epoch}" != 0 ] && e="${epoch}:"
      printf '%s\t%s%s-%s\n' "${pkgname}" "${e}" "${pkgver}" "${pkgrel:-0}" )
  done
}

do_check() {
  echo "==> desfase: centro (PKGBUILD)  vs  ${HOST} (pacman -Q)"
  local list
  list="$(centre_pkgs | sort -u)"
  if [ -z "${list}" ]; then
    echo "no encuentro ningún PKGBUILD en ${HERE}/packages" >&2
    return 2
  fi

  local installed
  if ! installed="$(ssh -o BatchMode=yes -o ConnectTimeout=8 "${HOST}" 'pacman -Q' 2>/dev/null)"; then
    echo "no hay conexion con ${HOST} (encendida y en red?)" >&2
    return 2
  fi

  local drift=0 absent=0 name want have newest
  printf '  %-28s %-22s %-22s %s\n' "PAQUETE" "CENTRO" "ODIN" ""
  while IFS=$'\t' read -r name want; do
    have="$(printf '%s\n' "${installed}" | awk -v n="${name}" '$1==n {print $2; exit}')"
    if [ -z "${have}" ]; then
      printf '  %-28s %-22s %-22s %s\n' "${name}" "${want}" "— no instalado —" "AVISO"
      absent=$((absent + 1))
      continue
    fi
    if [ "${have}" = "${want}" ]; then
      printf '  %-28s %-22s %-22s %s\n' "${name}" "${want}" "${have}" "ok"
      continue
    fi
    # ¿está el paquete viejo en localrepo? Entonces compilar e instalar es el remedio.
    newest="$(ls -t "${OS}"/build/localrepo/*/"${name}"-*.pkg.tar.* 2>/dev/null | head -1 || true)"
    printf '  %-28s %-22s %-22s %s\n' "${name}" "${want}" "${have}" "DESFASE"
    if [ -n "${newest}" ]; then
      printf '  %-28s %-22s ya compilado en localrepo: %s\n' "" "" "${newest##*/}"
    else
      printf '  %-28s %-22s hay que compilarlo: tools/deploy-to-device.sh %s\n' "" "" "${name}"
    fi
    drift=$((drift + 1))
  done <<< "${list}"

  echo
  if [ "${drift}" -eq 0 ] && { [ "${STRICT}" = 0 ] || [ "${absent}" -eq 0 ]; }; then
    if [ "${absent}" -gt 0 ]; then
      echo "OK: nada desfasado (${absent} no instalado, que no cuenta como desfase; usa --strict si lo quieres contar)"
    else
      echo "OK: la Odin está igualada al centro."
    fi
    return 0
  fi
  echo "DESFASE: ${drift} paquete(s) instalados con otra versión que el centro"
  [ "${absent}" -gt 0 ] && echo "         (+${absent} del centro no instalados en la Odin)"
  return 1
}

if [ "${CHECK}" = 1 ]; then
  do_check
  exit $?
fi

[ -n "${PKGS}" ] || { usage >&2; exit 2; }

echo "==> 0/6 comprobando que la Odin responde"
ssh -o ConnectTimeout=8 -o BatchMode=yes "${HOST}" true 2>/dev/null \
  || { echo "no hay conexion con ${HOST} (encendida y en red?)" >&2; exit 1; }
echo "    ${HOST} responde"

echo "==> 1/6 sincronizando el centro al árbol de compilación"
if [ "${DRY}" = 1 ]; then
  "${HERE}/tools/sync-to-os.sh" --dry-run | sed 's/^/    /'
else
  "${HERE}/tools/sync-to-os.sh" >/dev/null
  "${HERE}/tools/check-sync.sh" >/dev/null || { echo "check-sync falló" >&2; exit 1; }
  echo "    OK"
fi

echo "==> 2/6 compilando: ${PKGS}"
# `make packages` monta un chroot aarch64 y hace bind mounts: necesita root.
# Si tu sudo pide contraseña y no hay tty, pásala en PC_SUDO_PASS (no se guarda en el script).
if [ "${DRY}" = 1 ]; then
  echo "    [dry-run] sudo env DEVICE=${DEVICE} PKG=\"${PKGS}\" make packages"
else
  if [ -n "${PC_SUDO_PASS:-}" ]; then
    ( cd "${OS}" && echo "${PC_SUDO_PASS}" | sudo -S env DEVICE="${DEVICE}" PKG="${PKGS}" make packages )
  else
    ( cd "${OS}" && sudo env DEVICE="${DEVICE}" PKG="${PKGS}" make packages )
  fi
fi

echo "==> 3/6 buscando los paquetes compilados"
FILES=()
for p in ${PKGS}; do
  # el paquete recién construido (el más nuevo que case con el nombre)
  f=$(ls -t "${OS}"/build/localrepo/*/"${p}"-*.pkg.tar.* 2>/dev/null | head -1 || true)
  if [ -z "${f}" ]; then
    if [ "${DRY}" = 1 ]; then
      echo "    [dry-run] aún no está compilado: ${p} (lo haría make packages)"
      continue
    fi
    echo "    no encuentro el paquete ${p} en build/localrepo" >&2; exit 1
  fi
  echo "    ${f##*/}"
  FILES+=("${f}")
done

# ─────────────────────────────────────────────────────────────────────────────
# POR QUÉ --overwrite, Y POR QUÉ SOLO EN ESTOS SITIOS
# ─────────────────────────────────────────────────────────────────────────────
# `pacman -U` aborta si algún fichero del paquete YA existe en el destino, esté o no
# tenga dueño. En la Odin hay dos árboles enteros que se crean en TIEMPO DE EJECUCIÓN y
# que luego el paquete vuelve a querer escribir:
#
#   /opt/deckstation/*            -> 2918 ficheros sin dueño. Los crea deckstation-setup.sh
#                                     y deploy-lanzar-sh.sh (wrappers lanzar.sh, configs,
#                                     .home, symlinks de cores, bios) y NO están en la
#                                     base de datos de pacman. Medido el 27/09: 2918 de
#                                     los 2924 ficheros de deckstation-arm 1.0.0-10
#                                     chocaban -> `pacman -U` fallaba SIEMPRE.
#   /usr/share/decky-plugins/*    -> 48 ficheros (24 en PocknixControl, 24 en Mako): los
#                                    plugins que pocknix-decky-loader despliega en homebrew.
#                                    Sin --overwrite tampoco se puede actualizar el plugin.
#   /usr/lib/modules/*            -> los módulos del kernel. Si el dispositivo se actualizó
#                                    alguna vez con `flash-kernel.sh` (que hace `tar`+`depmod`
#                                    a mano), ese /lib/modules/<ver>/ NO lo posee ningún
#                                    paquete -> `pacman -U` aborta con "exists in filesystem"
#                                    y el deploy entero falla. Pasó el 01/10/2026 al
#                                    instalar linux-pocknix-sm8750 7.2.6-1 en la Odin.
#                                    Es seguro: el paquete trae modules.dep/alias/builtin
#                                    recalculados por su post_install (depmod).
#
# Se limita a esas rutas a propósito: un `--overwrite '*'` también pisaría /usr/bin, /etc o
# las unidades de systemd, que es justo lo que no queremos que se silencie un cambio de
# versión. Si algún día choca en otro sitio, se añade AQUÍ y se documenta por qué, no se
# abre la puerta a todo el sistema.

OVERWRITE=( '/opt/deckstation/*' '/usr/share/decky-plugins/PocknixControl/*'
            '/usr/share/decky-plugins/Mako/*' '/usr/lib/modules/*' )

echo "==> 4/6 instalando en ${HOST}"
# Los globs van como argv (dsudo los cita uno a uno), NUNCA como texto para un shell.
PACMAN_ARGS=( pacman -U --noconfirm )
for g in "${OVERWRITE[@]}"; do PACMAN_ARGS+=( --overwrite "${g}" ); done

if [ "${DRY}" = 1 ]; then
  for f in ${FILES[@]+"${FILES[@]}"}; do
    printf '    [dry-run]'
    printf ' %q' "${PACMAN_ARGS[@]}"
    printf ' %q\n' "/tmp/${f##*/}"
  done
elif [ "${#FILES[@]}" -gt 0 ]; then
  scp -q "${FILES[@]}" "${HOST}:/tmp/"
  askpass_setup
  for f in "${FILES[@]}"; do
    echo "    pacman -U ${f##*/}"
    dsudo "${PACMAN_ARGS[@]}" "/tmp/${f##*/}"
    # el .pkg.tar es de 'deck' en su /tmp: se borra sin sudo
    ssh_do "rm -f '/tmp/${f##*/}'" || true
  done
fi

# ─────────────────────────────────────────────────────────────────────────────
# 5/6 servicios — CON LA COMPROBACIÓN DE SESIÓN (esto no es opcional)
# ─────────────────────────────────────────────────────────────────────────────
# El crash loop de steamwebhelper documentado en AGENTS.md salía de reiniciar
# pocknix-decky-loader con Steam en modo juego. Antes este script lo reiniciaba siempre.
# Ahora: se mira la sesión y, si hay Steam o escritorio, NO se toca el loader.
UNITS_SAFE=( oled-care-daemon mangohud-toggle-daemon power-button-daemon volume-button-daemon
             pocknix-power-profile pocknix-cpu-governor pocknix-pergame-power steamui-watchdog )
UNIT_RISKY=( pocknix-decky-loader )   # SOLO si no hay Steam ni sesión gráfica

echo "==> 5/6 servicios"
if [ "${DRY}" = 1 ]; then
  for s in "${UNITS_SAFE[@]}"; do echo "    [dry-run] systemctl try-restart ${s}.service"; done
  for s in "${UNIT_RISKY[@]}"; do
    echo "    [dry-run] systemctl try-restart ${s}.service  (solo si no hay Steam)"
  done
elif [ "${NO_RESTART:-0}" = "1" ]; then
  echo "    NO_RESTART=1 — no reinicio nada (mira 'systemctl --failed' para ver qué se queja)"
else
  askpass_setup
  # el sentinel de sesión + procesos: con Steam en modo juego el loader NO se toca
  BUSY="$(session_probe | tr -s ' \n' ' ' | sed 's/^ *//;s/ *$//')"
  if [ -n "${BUSY}" ]; then
    if [ "${FORCE_RESTART:-0}" = "1" ]; then
      echo "    aviso: sesión activa (${BUSY}) y FORCE_RESTART=1 — reinicio el loader AUNQUE"
      echo "          AGENTS.md documenta que esto puede hacer crashear steamwebhelper."
    else
      echo "    sesión activa detectada: ${BUSY}"
      echo "    ⛔ NO reinicio ${UNIT_RISKY[*]}.service (crash loop de steamwebhelper, AGENTS.md)."
      echo "      Reinícialo tú desde el escritorio, antes de entrar en Game Mode:"
      echo "        ssh ${HOST} 'sudo systemctl restart pocknix-decky-loader.service'"
    fi
  fi
  for s in "${UNITS_SAFE[@]}"; do
    dsudo systemctl try-restart "${s}.service" 2>/dev/null || true
  done
  for s in "${UNIT_RISKY[@]}"; do
    if [ -n "${BUSY}" ] && [ "${FORCE_RESTART:-0}" != "1" ]; then continue; fi
    dsudo systemctl try-restart "${s}.service" 2>/dev/null || true
  done
  echo "    daemons reiniciados (los que existían)"
fi

echo "==> 6/6 estado final en la Odin"
if [ "${DRY}" = 1 ]; then
  echo "    [dry-run] systemctl --failed"
else
  # systemctl --failed se puede leer como 'deck': no hace falta sudo
  ssh_do 'systemctl --failed --no-legend 2>/dev/null | sed "s/^/      /"' || true
  ssh_do 'systemctl --failed --no-legend 2>/dev/null | grep -q . || echo "      (sin servicios fallidos)"'
  # el desfase que queda, para el log
  "${BASH_SOURCE[0]}" --check || true
fi

echo
echo "listo. Si el cambio era de sesión (gamescope/Steam), reinicia la sesión desde la consola."
