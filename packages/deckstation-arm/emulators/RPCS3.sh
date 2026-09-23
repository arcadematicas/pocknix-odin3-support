#!/bin/bash
# RPCS3 — PlayStation 3 (AppImage aarch64)
DIR="$(dirname "$(readlink -f "$0")")"
cd "$DIR/../.."
exec ./Apps/RPCS3/lanzar.sh "$@"
