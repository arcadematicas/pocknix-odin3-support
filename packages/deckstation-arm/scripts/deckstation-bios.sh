#!/bin/bash
# ======================================================================
# deckstation-bios.sh — Distribuye las BIOS/firmware del usuario
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
#   deckstation-bios.sh [--force] [--dry-run]
#
# Ver bios/README.md para saber que ficheros necesita cada sistema y donde
# conseguirlos legalmente.
# ======================================================================
set -u

SELF="$(readlink -f "${BASH_SOURCE[0]}")"
DECKSTATION_ROOT="${DECKSTATION_ROOT:-$(cd "$(dirname "$SELF")/.." && pwd)}"

exec env DECKSTATION_ROOT="$DECKSTATION_ROOT" \
    "${DECKSTATION_ROOT}/scripts/deckstation-configs.sh" \
    --from "${DECKSTATION_ROOT}/bios" \
    --manifest "${DECKSTATION_ROOT}/bios/deploy-bios.txt" \
    --label bios "$@"
