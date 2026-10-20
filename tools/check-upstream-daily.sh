#!/usr/bin/env bash
# check-upstream-daily.sh — ejecuta check-upstream.sh, guarda el informe del dia y
# resalta las NOVEDADES respecto a la ejecucion anterior.
#
# Lo lanza el timer de usuario `pocknix-upstream-check.timer` (cada dia a las 08:15),
# pero tambien se puede ejecutar a mano:
#   tools/check-upstream-daily.sh [--repo DIR]
#
# Salidas:
#   ~/.local/share/pocknix/upstream/YYYY-MM-DD.txt   informe del dia (90 dias)
#   ~/.local/share/pocknix/upstream/latest.txt       enlace al ultimo
#   ~/.local/share/pocknix/upstream/last-fingerprint.txt   estado para calcular novedades
#   journal (stdout): solo el bloque de NOVEDADES
#
# Lo que no se atienda ese dia NO se pierde: queda en el informe y, cuando se revisa,
# se anota en docs/UPSTREAM-BACKLOG.md (que es la memoria de decisiones).
set -u
export LC_ALL=C

HERE="$(CDPATH= cd -- "$(dirname -- "$0")" && pwd -P)"
REPO="${HOME}/pocknix-odin3-project/pocknix-os"
while [ $# -gt 0 ]; do
  case "$1" in
    --repo) REPO="$2"; shift 2 ;;
    -h|--help) sed -n '2,20p' "$0"; exit 0 ;;
    *) shift ;;
  esac
done

OUTDIR="${XDG_DATA_HOME:-${HOME}/.local/share}/pocknix/upstream"
mkdir -p "${OUTDIR}"

RAW="$(mktemp)"
"${HERE}/check-upstream.sh" --repo "${REPO}" > "${RAW}" 2>&1 || true

# Huella: solo las lineas que implican una decision (versiones marcadas, parches que
# faltan, resumen). Asi "novedad" = algo que merece mirarse, no ruido de commits.
fp_now="$(grep -aE '(<<<|ACTUALIZAR|FALTAN|^ +- |Resumen:)' "${RAW}" | sed -E 's/[[:space:]]+/ /g' | sort -u)"

day="$(date +%F)"
if [ -f "${OUTDIR}/last-fingerprint.txt" ]; then
  novedades="$(comm -13 "${OUTDIR}/last-fingerprint.txt" <(printf '%s\n' "${fp_now}"))"
else
  novedades="(primera ejecucion: se toma todo como referencia)"
fi

{
  echo "# Informe upstream ${day}"
  echo
  echo "## Novedades respecto a la ejecucion anterior"
  if [ -n "${novedades}" ]; then printf '%s\n' "${novedades}"; else echo "(sin novedades)"; fi
  echo
  echo "## Informe completo"
  cat "${RAW}"
} > "${OUTDIR}/${day}.txt"

printf '%s\n' "${fp_now}" > "${OUTDIR}/last-fingerprint.txt"
ln -sfn "${OUTDIR}/${day}.txt" "${OUTDIR}/latest.txt"
find "${OUTDIR}" -maxdepth 1 -name '20??-??-??.txt' -mtime +90 -delete 2>/dev/null || true
rm -f "${RAW}"

# stdout -> journal: solo el bloque de novedades
awk '/^## Novedades/{f=1;next} /^## Informe completo/{f=0} f' "${OUTDIR}/${day}.txt" | sed '/^[[:space:]]*$/d'
echo "informe: ${OUTDIR}/${day}.txt"
