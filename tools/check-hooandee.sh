#!/usr/bin/env bash
# check-hooandee.sh — ¿vamos al día con los plugins de Hooandee que van en la imagen?
#
# Imprime 1-2 líneas, pensadas para el informe diario de `check-upstream-daily.sh`:
#
#   Hooandee Panel de Control: vendido panel-de-control-v0.70.1 | upstream v0.76.0 (2026-10-23)  <<< ACTUALIZAR
#   Hooandee Colores (no vendido; lo instala el usuario desde el panel): upstream v0.34.1 (2026-10-21)
#
# Por qué: el "Panel de Control" se vende en la imagen (copia semilla) y se autoactualiza en el
# dispositivo, pero una imagen NUEVA sigue sembrando la copia vieja hasta que bumpeamos el bundle.
# Y "Colores" no se vende, pero sus fallos de descarga ("no puedo instalarlo") acaban en nuestro
# tejado, así que interesa saber por qué versión va.
#
# Solo informa: no descarga ni modifica nada.
set -u
HERE="$(cd "$(dirname "$0")" && pwd)"
VENDORED_FILE="${HERE}/../packages/pocknix-decky/panel-de-control/VENDORED"
API="https://api.github.com/repos"

# último release de un repo -> "tag<TAB>fecha" (o vacío si falla)
latest() {
  local repo="$1" json
  json="$(timeout 40 curl -fsSL -H 'User-Agent: pocknix-upstream-check' \
          "${API}/${repo}/releases?per_page=1" 2>/dev/null || true)"
  HOO_JSON="${json}" python3 - <<'PY'
import json, os
raw = os.environ.get("HOO_JSON") or "[]"
try:
    r = json.loads(raw)[0]
    print("%s\t%s" % (r.get("tag_name", "?"), (r.get("published_at") or "")[:10]))
except Exception:
    print("\t")
PY
}

line() {  # $1=etiqueta  $2=repo  $3=version vendida ("" si no se vende)
  local label="$1" repo="$2" vend="$3" tag day extra
  IFS=$'\t' read -r tag day <<<"$(latest "${repo}")"
  if [ -z "${tag}" ]; then
    printf '%s: sin datos (API)\n' "${label}"
    return 0
  fi
  # normaliza: el tag puede venir como "panel-de-control-v0.76.0" o "v0.76.0"
  local short="${tag##*-v}"; [ "${short}" = "${tag}" ] && short="${tag#v}"
  local vend_short="${vend##*-v}"; [ "${vend_short}" = "${vend}" ] && vend_short="${vend#v}"
  if [ -n "${vend}" ]; then
    extra=""
    [ "${short}" != "${vend_short}" ] && extra="  <<< ACTUALIZAR"
    printf '%s: vendido %s | upstream %s (%s)%s\n' "${label}" "${vend}" "${tag}" "${day}" "${extra}"
  else
    printf '%s: upstream %s (%s)\n' "${label}" "${tag}" "${day}"
  fi
}

vend="?"
[ -r "${VENDORED_FILE}" ] && vend="$(tr -d '[:space:]' < "${VENDORED_FILE}")"

line "Hooandee Panel de Control" "Hooandee/panel-de-control" "${vend}"
line "Hooandee Colores (no vendido; lo instala el usuario desde el panel)" "Hooandee/decky-colores" ""
