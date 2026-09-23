#!/bin/bash
# Xenia Edge — Xbox 360 (AppImage aarch64)
DIR="$(dirname "$(readlink -f "$0")")"
cd "$DIR/../.."
exec ./Apps/xenia_edge/lanzar.sh "$@"
