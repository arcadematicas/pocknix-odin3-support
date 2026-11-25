#!/usr/bin/env bash
# Instala OpenABL 1.2 en una AYN Odin 3 / Odin 3 Portal (SM8750) desde fastboot,
# sin root y sin tocar el slot que tiene el ABL de serie.
set -u

VERSION="1.2"
ELF_NAME="abl_signed-SM8750.elf"
ELF_SIZE="532480"
ELF_SHA256="0dba7b90d1a36e13977c00fec87f4f5ccc8f49b98864ad495a1ed04d35e33c3a"
TARBALL_URL="https://github.com/OpenHandheldCollective/OpenABL/releases/download/v1.2/openabl-v1.2.tar.gz"
TARBALL_NAME="openabl-v1.2.tar.gz"
ELF_IN_TAR="openabl-v1.2/SM8750/abl_signed-SM8750.elf"

DRY_RUN=0
YES=0
ELF_ARG=""
SLOT_ARG=""
SHOW_HELP=0
FASTBOOT=""
ELF_PATH=""
WORK_DIR=""
CLEAN_WORK_DIR=""

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" 2>/dev/null && pwd)" || SCRIPT_DIR="$PWD"
STAMP="$(date +%Y%m%d-%H%M%S)"
LOG_FILE="$SCRIPT_DIR/openabl-flash-$STAMP.log"
if ! : > "$LOG_FILE" 2>/dev/null; then
  LOG_FILE="${TMPDIR:-/tmp}/openabl-flash-$STAMP.log"
  if ! : > "$LOG_FILE" 2>/dev/null; then
    LOG_FILE="/dev/null"
  fi
fi

log() {
  local msg="$*"
  printf '%s\n' "$msg"
  if [ "$LOG_FILE" != "/dev/null" ]; then
    printf '[%s] %s\n' "$(date +%Y%m%d-%H%M%S)" "$msg" >> "$LOG_FILE" 2>/dev/null || true
  fi
}

log_output_file() {
  local file="$1"
  [ -f "$file" ] || return 0
  while IFS= read -r line || [ -n "$line" ]; do
    log "  | $line"
  done < "$file"
}

cleanup() {
  if [ -n "$CLEAN_WORK_DIR" ] && [ -d "$CLEAN_WORK_DIR" ]; then
    rm -rf -- "$CLEAN_WORK_DIR" 2>/dev/null || true
  fi
}
trap cleanup EXIT

finish() {
  local code="$1"
  if [ "$LOG_FILE" != "/dev/null" ]; then
    printf 'Registro guardado en: %s\n' "$LOG_FILE"
  fi
  exit "$code"
}

usage() {
  while IFS= read -r line; do log "$line"; done <<'EOF'
Uso: flash-openabl.sh [opciones]

Instala OpenABL 1.2 en una AYN Odin 3 / Odin 3 Portal (SM8750) desde un PC,
sin root y sin saber fastboot. Escribe SOLO el slot inactivo y lo activa:
el ABL de serie del otro slot queda intacto.

Opciones:
  --help              Muestra esta ayuda.
  --dry-run           Muestra el plan sin descargar ni escribir nada en la consola.
  --elf <ruta>        Usa un ELF local en vez de descargar el tarball oficial.
  --slot a|b          Solo si no se puede leer el slot actual: indica cuál es el activo.
  --yes               No pide confirmar escribiendo FLASH. Solo para automatizar;
                      úsalo únicamente si sabes lo que estás haciendo.

Ejemplo:
  ./flash-openabl.sh
  ./flash-openabl.sh --dry-run
  ./flash-openabl.sh --elf /ruta/abl_signed-SM8750.elf

Códigos de salida: 0 correcto, 1 error, 2 cancelado por ti, 3 falta algo antes de empezar.
EOF
}

log "=== flash-openabl.sh - OpenABL $VERSION para SM8750 ==="

# ---------------------------------------------------------------- opciones ---
while [ "$#" -gt 0 ]; do
  case "$1" in
    --help|-Help)
      SHOW_HELP=1
      ;;
    --dry-run|-DryRun)
      DRY_RUN=1
      ;;
    --yes|-Yes)
      YES=1
      ;;
    --elf|-Elf)
      if [ "$#" -lt 2 ]; then
        log "ERROR: falta la ruta después de --elf."
        usage
        finish 1
      fi
      ELF_ARG="$2"
      shift
      ;;
    --slot|-Slot)
      if [ "$#" -lt 2 ]; then
        log "ERROR: falta a o b después de --slot."
        usage
        finish 1
      fi
      SLOT_ARG="$2"
      shift
      ;;
    *)
      log "ERROR: opción desconocida: $1"
      usage
      finish 1
      ;;
  esac
  shift
done

case "$SLOT_ARG" in
  ''|a|b) ;;
  *)
    log "ERROR: --slot solo admite a o b (has escrito: $SLOT_ARG)."
    usage
    finish 1
    ;;
esac

if [ "$SHOW_HELP" -eq 1 ]; then
  usage
  finish 0
fi

if [ "$DRY_RUN" -eq 1 ]; then
  log "Modo de prueba (--dry-run): no se descarga nada y no se escribe en la consola."
fi

WORK_DIR="$(mktemp -d "${TMPDIR:-/tmp}/openabl-flash.XXXXXX" 2>/dev/null)" || WORK_DIR=""
if [ -n "$WORK_DIR" ]; then
  CLEAN_WORK_DIR="$WORK_DIR"
else
  WORK_DIR="${TMPDIR:-/tmp}"
fi

# --------------------------------------------------------------- fastboot ----
FASTBOOT="$(command -v fastboot 2>/dev/null || true)"
if [ -z "$FASTBOOT" ] || [ ! -x "$FASTBOOT" ]; then
  log "ERROR: no encuentro 'fastboot' en el PATH del PC."
  log "QUÉ HACER:"
  log "  - Linux Debian/Ubuntu: sudo apt install android-tools-fastboot"
  log "  - Linux Arch:          sudo pacman -S android-tools"
  log "  - Linux Fedora:        sudo dnf install android-tools"
  log "  - macOS:               brew install android-platform-tools"
  log "  - Ojo: instala los platform-tools de Google (adb y fastboot juntos)."
  log "Después vuelve a abrir la terminal y ejecuta este script otra vez."
  finish 3
fi
log "fastboot encontrado: $FASTBOOT"

# --------------------------------------- ejecutar un comando con timeout -----
run_cmd_timeout() {
  local secs="$1" out="$2" pid i
  shift 2
  if command -v timeout >/dev/null 2>&1; then
    timeout "$secs" "$@" > "$out" 2>&1
    return $?
  fi
  "$@" > "$out" 2>&1 &
  pid=$!
  i=0
  while kill -0 "$pid" 2>/dev/null; do
    if [ "$i" -ge $((secs * 10)) ]; then
      kill "$pid" 2>/dev/null || true
      wait "$pid" 2>/dev/null || true
      return 124
    fi
    sleep 0.1
    i=$((i + 1))
  done
  wait "$pid"
}

UDEV_RULE='SUBSYSTEM=="usb", ATTR{idVendor}=="18d1", MODE="0666"'

show_cable_checks() {
  log "Comprobaciones que suelen arreglarlo:"
  log "  1. Usa un cable corto de DATOS (los cables solo de carga no sirven)."
  log "  2. Enchufa directamente en un puerto del PC, sin hub ni alargador."
  log "  3. Prueba otro cable y otro puerto (mejor trasero que frontal)."
  log "  4. Windows: instala el controlador 'Android Bootloader Interface'."
  log "  5. Linux: crea /etc/udev/rules.d/51-android.rules con esta regla:"
  log "     $UDEV_RULE"
  log "     Después: sudo udevadm control --reload-rules && sudo udevadm trigger"
  log "     y desenchufa y vuelve a enchufar el cable."
}

show_fastboot_help() {
  log "QUÉ HACER para entrar en fastboot:"
  log "  1. Apaga la consola del todo (no suspendida)."
  log "  2. Mantén pulsado Volumen - y, sin soltar, enchufa el cable al PC."
  log "  3. Suelta cuando aparezca la pantalla de fastboot."
  log "  4. Si no entra: mantén Power + Volumen - mientras enchufas el cable."
  log "Importante: debe ser el fastboot del ABL, no el fastbootd de recovery."
}

# -------------------------------------------------------------- el ELF -------
if [ "$DRY_RUN" -eq 1 ] && [ -z "$ELF_ARG" ]; then
  log "Modo de prueba: se omitiría la descarga de $TARBALL_NAME."
else
  if [ -n "$ELF_ARG" ]; then
    if [ ! -f "$ELF_ARG" ]; then
      log "ERROR: el ELF indicado no existe: $ELF_ARG"
      log "QUÉ HACER: revisa la ruta o quita --elf para descargar el oficial."
      finish 1
    fi
    ELF_PATH="$ELF_ARG"
    log "Usando ELF local: $ELF_PATH"
  else
    TARBALL_PATH="$WORK_DIR/$TARBALL_NAME"
    log "Descargando el tarball oficial de OpenABL $VERSION..."
    if command -v curl >/dev/null 2>&1; then
      curl -fL --retry 3 -o "$TARBALL_PATH" "$TARBALL_URL" >> "$WORK_DIR/curl.txt" 2>&1
      dl_rc=$?
    elif command -v wget >/dev/null 2>&1; then
      wget -O "$TARBALL_PATH" "$TARBALL_URL" >> "$WORK_DIR/wget.txt" 2>&1
      dl_rc=$?
    else
      log "ERROR: no hay curl ni wget en este PC."
      log "QUÉ HACER: instala curl (sudo apt install curl / brew install curl) o"
      log "          descarga el tarball a mano y usa --elf <ruta>."
      finish 1
    fi
    if [ "$dl_rc" -ne 0 ] || [ ! -s "$TARBALL_PATH" ]; then
      log "ERROR: no se pudo descargar el tarball."
      log_output_file "$WORK_DIR/curl.txt"
      log_output_file "$WORK_DIR/wget.txt"
      log "QUÉ HACER: comprueba la conexión o usa --elf con un ELF local."
      finish 1
    fi
    if ! command -v tar >/dev/null 2>&1; then
      log "ERROR: no hay tar en este PC, no puedo extraer el ELF."
      log "QUÉ HACER: instala tar o extrae el ELF a mano y usa --elf <ruta>."
      finish 1
    fi
    if ! tar -xzf "$TARBALL_PATH" -C "$WORK_DIR" "$ELF_IN_TAR" >> "$WORK_DIR/tar.txt" 2>&1; then
      log "ERROR: no se pudo extraer $ELF_IN_TAR del tarball."
      log_output_file "$WORK_DIR/tar.txt"
      log "QUÉ HACER: usa --elf con el fichero $ELF_NAME extraído a mano."
      finish 1
    fi
    ELF_PATH="$WORK_DIR/$ELF_IN_TAR"
    log "ELF extraído: $ELF_PATH"
  fi

  if [ ! -f "$ELF_PATH" ]; then
    log "ERROR: no aparece el fichero ELF esperado: $ELF_PATH"
    finish 1
  fi

  ACTUAL_SIZE="$(wc -c < "$ELF_PATH" | tr -d '[:space:]')"
  ACTUAL_SHA=""
  if command -v sha256sum >/dev/null 2>&1; then
    ACTUAL_SHA="$(sha256sum "$ELF_PATH" | awk '{print $1}')"
  elif command -v shasum >/dev/null 2>&1; then
    ACTUAL_SHA="$(shasum -a 256 "$ELF_PATH" | awk '{print $1}')"
  else
    log "ERROR: no hay sha256sum ni shasum para comprobar el ELF."
    log "QUÉ HACER: instala coreutils (Linux) o Perl (macOS trae shasum)."
    finish 1
  fi

  log "Comprobando ELF: tamaño=$ACTUAL_SIZE bytes (esperado $ELF_SIZE)."
  log "Comprobando ELF: sha256=$ACTUAL_SHA"
  if [ "$ACTUAL_SIZE" != "$ELF_SIZE" ] || [ "$ACTUAL_SHA" != "$ELF_SHA256" ]; then
    log "ERROR: el ELF no es válido. No se ha tocado el dispositivo."
    log "  Tamaño esperado: $ELF_SIZE bytes. Tamaño obtenido: $ACTUAL_SIZE bytes."
    log "  sha256 esperado: $ELF_SHA256"
    log "  sha256 obtenido: $ACTUAL_SHA"
    log "QUÉ HACER: vuelve a descargar el tarball oficial o pasa un ELF bueno con --elf."
    finish 1
  fi
  log "ELF correcto (tamaño y sha256 coinciden)."
fi

# ----------------------------------------------------------- dispositivo -----
OUT="$WORK_DIR/devices.txt"
run_cmd_timeout 15 "$OUT" "$FASTBOOT" devices
DEV_RC=$?
log "Salida de 'fastboot devices' (código $DEV_RC):"
log_output_file "$OUT"

if grep -qi 'no permissions' "$OUT" 2>/dev/null; then
  log "ERROR: fastboot ve el dispositivo pero no tiene permisos (no permissions)."
  log "QUÉ HACER:"
  log "  1. Crea /etc/udev/rules.d/51-android.rules con esta regla:"
  log "     $UDEV_RULE"
  log "  2. Ejecuta: sudo udevadm control --reload-rules && sudo udevadm trigger"
  log "  3. Desenchufa y vuelve a enchufar el cable."
  log "Este script no ejecuta sudo por ti."
  finish 3
fi

DEV_COUNT="$(grep -cE '^[^[:space:]]+[[:space:]]+fastboot' "$OUT" 2>/dev/null || true)"
if [ "$DEV_RC" -ne 0 ]; then
  log "ERROR: 'fastboot devices' agotó el tiempo de espera (15 s) o falló."
  show_fastboot_help
  show_cable_checks
  finish 3
fi
if [ -z "$DEV_COUNT" ] || [ "$DEV_COUNT" -eq 0 ]; then
  log "ERROR: no hay ninguna consola en fastboot. No se ha escrito nada."
  show_fastboot_help
  show_cable_checks
  finish 3
fi
if [ "$DEV_COUNT" -gt 1 ]; then
  log "ERROR: hay $DEV_COUNT dispositivos en fastboot. No voy a adivinar cuál es."
  log "QUÉ HACER: deja conectada solo la Odin 3 y vuelve a ejecutar el script."
  finish 3
fi
log "Se ha encontrado exactamente una consola en fastboot."

# -------------------------------------------------------------- getvars ------
OUT="$WORK_DIR/unlocked.txt"
run_cmd_timeout 12 "$OUT" "$FASTBOOT" getvar unlocked
UNLOCKED_RC=$?
log "Salida de 'getvar unlocked' (código $UNLOCKED_RC):"
log_output_file "$OUT"
UNLOCKED_VAL="$(sed -n 's/^unlocked:[[:space:]]*\([^[:space:]]*\).*/\1/p' "$OUT" | head -n 1 | tr -d '\r')"
if [ "$UNLOCKED_RC" -eq 0 ] && [ -n "$UNLOCKED_VAL" ]; then
  if [ "$UNLOCKED_VAL" = "no" ]; then
    log "ERROR: el bootloader está BLOQUEADO (unlocked: no)."
    log "QUÉ HACER: desbloquéalo tú desde los ajustes de Android antes de seguir."
    log "Advertencia: desbloquear borra los datos de la consola."
    log "Este script NUNCA desbloquea el bootloader por su cuenta."
    finish 3
  elif [ "$UNLOCKED_VAL" = "yes" ]; then
    log "Bootloader desbloqueado (unlocked: yes)."
  else
    log "Aviso: no se entiende la respuesta de 'getvar unlocked' ($UNLOCKED_VAL)."
    log "Siguiendo con cuidado; si el flash falla, comprueba el desbloqueo."
  fi
else
  log "Aviso: no se pudo leer 'getvar unlocked'. Siguiendo: no es obligatorio"
  log "para este método, pero si el flash falla comprueba el desbloqueo."
fi

OUT="$WORK_DIR/slot.txt"
run_cmd_timeout 12 "$OUT" "$FASTBOOT" getvar current-slot
SLOT_RC=$?
log "Salida de 'getvar current-slot' (código $SLOT_RC):"
log_output_file "$OUT"
CURRENT_SLOT="$(sed -n 's/^current-slot:[[:space:]]*\([^[:space:]]*\).*/\1/p' "$OUT" | head -n 1 | tr -d '\r')"

if [ -n "$CURRENT_SLOT" ]; then
  case "$CURRENT_SLOT" in
    a|b) ;;
    *)
      log "Aviso: respuesta de slot no reconocida ($CURRENT_SLOT)."
      CURRENT_SLOT=""
      ;;
  esac
fi

if [ -n "$CURRENT_SLOT" ]; then
  if [ -n "$SLOT_ARG" ] && [ "$SLOT_ARG" != "$CURRENT_SLOT" ]; then
    log "Aviso: se ha leído el slot actual ($CURRENT_SLOT), así que se ignora --slot $SLOT_ARG."
  fi
elif [ -n "$SLOT_ARG" ]; then
  log "Aviso: no se pudo leer el slot actual; usando --slot $SLOT_ARG como indicaste."
  CURRENT_SLOT="$SLOT_ARG"
else
  log "ERROR: no se pudo leer el slot actual con 'getvar current-slot'."
  log "Es un fallo conocido: en estas consolas 'fastboot getvar all' se cuelga"
  log "mientras que 'flash' funciona. Por seguridad no adivinamos el slot."
  log "QUÉ HACER: vuelve a ejecutar con --slot a o --slot b indicando cuál es"
  log "el slot activo (por ejemplo: ./flash-openabl.sh --slot a)."
  finish 3
fi

case "$CURRENT_SLOT" in
  a) TARGET_SLOT="b" ;;
  b) TARGET_SLOT="a" ;;
  *)
    log "ERROR: no se ha podido determinar el slot activo. No se escribe nada."
    finish 3
    ;;
esac

# ------------------------------------------------------------------ plan -----
log ""
log "PLAN (nada se ha escrito todavía):"
log "  Slot activo ahora:            $CURRENT_SLOT"
log "  Slot donde se escribirá:      $TARGET_SLOT (el inactivo)"
log "  ABL de serie:                 queda intacto en el slot $CURRENT_SLOT"
log "  Versión a instalar:           OpenABL $VERSION (SM8750)"
log "  Fichero:                      $ELF_NAME, $ELF_SIZE bytes"
log "  sha256:                       $ELF_SHA256"
log ""

if [ "$DRY_RUN" -eq 1 ]; then
  log "Fin del modo de prueba: no se ha descargado nada cuando no se pidió"
  log "y no se ha escrito ni activado ningún slot. No se reinicia la consola."
  finish 0
fi

# ----------------------------------------------------------- confirmación ----
if [ "$YES" -eq 1 ]; then
  log "Opción --yes: se omite la confirmación (solo para automatizar)."
else
  log "Escribe exactamente FLASH (mayúsculas) para autorizar el flash:"
  printf '> '
  ANSWER=""
  IFS= read -r ANSWER || ANSWER=""
  log "Has escrito: $ANSWER"
  if [ "$ANSWER" != "FLASH" ]; then
    log "Cancelado: no se ha escrito ni activado nada. El slot activo sigue siendo $CURRENT_SLOT."
    finish 2
  fi
fi

# ------------------------------------------------------------------ flash ----
OUT="$WORK_DIR/flash.txt"
log "Flasheando abl_$TARGET_SLOT (puede tardar hasta 3 minutos)..."
run_cmd_timeout 180 "$OUT" "$FASTBOOT" flash "abl_$TARGET_SLOT" "$ELF_PATH"
FLASH_RC=$?
log "Salida de 'flash abl_$TARGET_SLOT' (código $FLASH_RC):"
log_output_file "$OUT"

if [ "$FLASH_RC" -ne 0 ] || grep -qi 'FAILED' "$OUT" 2>/dev/null || ! grep -Eiq 'OKAY|Finished' "$OUT" 2>/dev/null; then
  if [ "$FLASH_RC" -eq 124 ]; then
    log "ERROR: el flash agotó el tiempo de espera (180 s)."
  else
    log "ERROR: el flash no terminó correctamente (código $FLASH_RC)."
  fi
  log "El slot activo NO se ha tocado: sigue siendo $CURRENT_SLOT."
  log "No se ha ejecutado --set-active."
  show_cable_checks
  finish 1
fi
log "Flash correcto: OpenABL está escrito en abl_$TARGET_SLOT."

# ------------------------------------------------------------- set-active ----
OUT="$WORK_DIR/active.txt"
log "Activando el slot $TARGET_SLOT..."
run_cmd_timeout 30 "$OUT" "$FASTBOOT" "--set-active=$TARGET_SLOT"
ACTIVE_RC=$?
log "Salida de '--set-active=$TARGET_SLOT' (código $ACTIVE_RC):"
log_output_file "$OUT"

if [ "$ACTIVE_RC" -ne 0 ] || grep -qi 'FAILED' "$OUT" 2>/dev/null || ! grep -Eiq 'OKAY|Finished|set to' "$OUT" 2>/dev/null; then
  log "ERROR: no se pudo activar el slot $TARGET_SLOT (código $ACTIVE_RC)."
  log "OpenABL SÍ está escrito en abl_$TARGET_SLOT, pero todavía no está activo."
  log "QUÉ HACER: puedes activarlo después desde fastboot con:"
  log "  fastboot --set-active=$TARGET_SLOT"
  log "El slot activo sigue siendo $CURRENT_SLOT por ahora."
  finish 1
fi
log "Slot $TARGET_SLOT activado correctamente."

# ---------------------------------------------------------------- resumen ----
log ""
log "=== HECHO ==="
log "  Versión instalada:  OpenABL $VERSION"
log "  sha256 (corto):     ${ELF_SHA256:0:12}"
log "  Slot escrito:       $TARGET_SLOT"
log "  Slot activo:        $TARGET_SLOT"
log "  Slot de serie:      $CURRENT_SLOT (intacto)"
log ""
log "Pasos siguientes en la consola:"
log "  1. Desconecta el cable USB."
log "  2. Enciende manteniendo Volumen - para abrir el menú de OpenABL."
log "  3. Elige Device model: AYN Odin 3 o AYN Odin 3 Portal (según tu modelo)."
log "  4. Elige Boot mode: Linux."
log "  5. Elige el origen: SD o Internal."
log "  6. Pulsa Start. Si es la primera vez y no eliges modelo, la pantalla queda negra."
log "La vuelta atrás: desde fastboot, fastboot --set-active=$CURRENT_SLOT,"
log "o en el menú de OpenABL elige 'Boot other slot'."
log "Este script no reinicia ni apaga la consola."
finish 0
