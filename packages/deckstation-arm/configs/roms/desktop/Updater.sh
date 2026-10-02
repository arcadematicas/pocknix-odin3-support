#!/bin/bash
# Lanzador del UPDATER de DeckStation desde ES-DE (sistema "Desktop Applications").
#
# Sigue el mismo patron que ROMs/emulators/*.sh: se ubica a si mismo para no
# depender del cwd con el que ES-DE lanza, se coloca en la raiz de DeckStation y
# llama al launcher.sh del Updater (que ya comprueba python/pygame/requests y
# elige el driver grafico del compositor).
DIR="$(dirname "$(readlink -f "$0")")"
cd "$DIR/../.."
exec ./Apps/Updater/launcher.sh
