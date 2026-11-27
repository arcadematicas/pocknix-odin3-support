#!/usr/bin/env bash
# Construye el AppImage aarch64 de Peanuts (host Linux del PR #130) con Docker cross.
#
# Uso:
#   tools/peanuts-build.sh [--ref <rama-o-commit>] [--work <dir>] [--out <dir>] [--deploy [usuario@host]]
#
# Por defecto usa la rama del PR (titooo7/pr-linux-appimage). Cuando el PR se fusione en
# igawa6/peanuts-native, basta con --ref main (o PEANUTS_REPO=...).
#
# Requisitos: git, docker (el usuario en el grupo docker) y ~4 GB libres. La primera vez
# construye la imagen de cross (linux/Dockerfile) y SDL3; tarda ~10-15 min. Luego ~5 min.
set -euo pipefail

REPO=${PEANUTS_REPO:-https://github.com/titooo7/peanuts-native.git}
REF=${PEANUTS_REF:-pr-linux-appimage}
WORK=${PEANUTS_WORK:-$HOME/peanuts-build}
OUT=""
DEPLOY=""

while [[ $# -gt 0 ]]; do
    case "$1" in
        --ref) REF=$2; shift 2 ;;
        --work) WORK=$2; shift 2 ;;
        --out) OUT=$2; shift 2 ;;
        --deploy) DEPLOY=${2:-}; [[ -n "$DEPLOY" ]] && shift; shift ;;
        -h|--help) sed -n '2,12p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
        *) echo "opción desconocida: $1" >&2; exit 2 ;;
    esac
done

command -v git >/dev/null || { echo "falta git" >&2; exit 2; }
command -v docker >/dev/null || { echo "falta docker" >&2; exit 2; }
docker info >/dev/null 2>&1 || { echo "docker no responde (¿grupo docker?)" >&2; exit 2; }

SRC="$WORK/peanuts-native"
mkdir -p "$WORK"
if [ ! -d "$SRC/.git" ]; then
    git clone -q "$REPO" "$SRC"
fi
git -C "$SRC" fetch -q origin
git -C "$SRC" checkout -q "$REF" 2>/dev/null || git -C "$SRC" checkout -q -B "$REF" "origin/$REF"
if [ "$REF" = "pr-linux-appimage" ] || [[ "$REF" == origin/* ]]; then
    git -C "$SRC" pull -q --ff-only || true
fi
echo "== fuente: $(git -C "$SRC" rev-parse --short=12 HEAD) ($REF)"

cd "$SRC"
./peanuts/linux/build-appimage.sh

ART=$(ls -t linux/build/appimage/PeanutsNative-*-aarch64.AppImage | head -1)
[ -n "$ART" ] || { echo "no se generó el AppImage" >&2; exit 1; }

if [ -n "$OUT" ]; then
    mkdir -p "$OUT"
    cp -f "$ART" "$OUT/"
    ART="$OUT/$(basename "$ART")"
fi

echo "AppImage: $ART"
ls -lh "$ART"
sha256sum "$ART"

if [ -n "$DEPLOY" ]; then
    DEST="$DEPLOY"
    [[ "$DEST" == *@* ]] || DEST="deck@$DEST"
    echo "== copiando a $DEST:~/Peanuts/ =="
    ssh "$DEST" 'mkdir -p ~/Peanuts'
    scp "$ART" "$DEST:~/Peanuts/PeanutsNative.AppImage.new"
    ssh "$DEST" 'set -e; cd ~/Peanuts; [ -f PeanutsNative.AppImage ] && cp -f PeanutsNative.AppImage PeanutsNative.AppImage.bak; mv -f PeanutsNative.AppImage.new PeanutsNative.AppImage; chmod +x PeanutsNative.AppImage; ./PeanutsNative.AppImage --selftest >/tmp/peanuts-selftest.log 2>&1 && echo "selftest OK" || { echo "SELFTEST FALLO"; tail -5 /tmp/peanuts-selftest.log; }'
fi
