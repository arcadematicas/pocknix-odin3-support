#!/bin/bash
# Lanzador de la interfaz de DosBoxPure desde ES-DE (sistema "Emulators").
# Se ubica a si mismo para no depender del cwd con el que ES-DE lanza.
DIR="$(dirname "$(readlink -f "$0")")"
cd "$DIR/../.."
exec ./Apps/DosBoxPure/lanzar.sh
