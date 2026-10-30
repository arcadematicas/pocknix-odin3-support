#!/bin/bash
# check-kernel-patches.sh — falla si algún parche del stack dejó un .rej al aplicar.
#
# POR QUÉ
#   scripts/build-kernel.sh aplica los parches con `patch -p1 --fuzz=5` y, si un hunk no
#   encaja, deja un .rej y SIGUE. El 30/10/2026 nos encontramos 5 .rej en el árbol (pm-clock
#   2111/2112 y jack 2119) y el build había "pasado" igual: los parches de audio no estaban
#   dentro y nadie lo sabía. Este chequeo convierte ese silencio en un fallo visible.
#
# USO
#   tools/check-kernel-patches.sh [SOC]        # por defecto sm8750
#   Sale 0 si no hay .rej/.orig de esta build; 1 si los hay (con la lista).

set -uo pipefail

SOC="${1:-sm8750}"
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
: "${POCKNIX_OS_DIR:=${ROOT}/../pocknix-os}"
BASE="${POCKNIX_OS_DIR}/build/kernel/${SOC}"

# El árbol se extrae de nuevo en cada build y patch deja .orig solo con -b; nos interesan los
# .rej, que son inequívocos. Los .orig se listan como aviso, no como fallo.
mapfile -t REJ < <(find "${BASE}" -name '*.rej' -newermt '-6 hours' 2>/dev/null | sort)
mapfile -t ORIG < <(find "${BASE}" -name '*.orig' -newermt '-6 hours' 2>/dev/null | sort)

if [ "${#REJ[@]}" -eq 0 ]; then
	echo "check-kernel-patches: OK (sin .rej en ${SOC})"
	if [ "${#ORIG[@]}" -gt 0 ]; then
		echo "  aviso: ${#ORIG[@]} .orig recientes (revisar si son de esta build):"
		printf '    %s\n' "${ORIG[@]}"
	fi
	exit 0
fi

echo "check-kernel-patches: FALLO — ${#REJ[@]} parche(s) dejaron .rej en ${SOC}:" >&2
for f in "${REJ[@]}"; do
	echo "  ${f#"${BASE}/"}" >&2
	# Primer hunk rechazado: ayuda a saber qué parche es sin abrir el fichero.
	sed -n '1,3p' "${f}" 2>/dev/null | sed 's/^/      /' >&2
done
echo "" >&2
echo "Localiza el parche con: grep -rl '<fragmento del hunk>' kernel/patches/ en el centro," >&2
echo "y adáptalo (o retíralo del stack) antes de volver a compilar." >&2
exit 1
