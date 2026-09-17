#!/bin/bash
# lanzar.sh — Wrapper portable universal para DeckStation (ARM)
# Redirige HOME al .home del AppImage para que todo quede portable.
#
# Plantilla genérica: se copia a cada carpeta Apps/<Emulador>/ como `lanzar.sh`
# (deckstation-setup debería encargarse de copiarla por emulador). El
# es_find_rules.xml de ES-DE apunta a `./Apps/*/lanzar.sh` en vez de al AppImage
# directo, así el wrapper limpia la herencia de ES-DE y fija el HOME portable.
set -e

# Directorio de este script
DIR="$(dirname "$(readlink -f "$0")")"

# 1. Limpiamos la herencia toxica de ES-DE
unset APPIMAGE
unset APPDIR
unset OWD

# 2. Buscamos que lanzar: el AppImage, o un arbol ya extraido.
#
#    Por que el arbol extraido: algunos AppImages traen el AppRun MAL generado y
#    buscan el binario en ruta absoluta del sistema (p. ej. `exec /usr/bin/retroarch`)
#    en vez de dentro del propio AppImage (`$APPDIR/...`). Cuando eso pasa, se
#    extrae con `--appimage-extract` y se deja el resultado en `app/`; aqui se
#    detecta y se lanza igual.
EXEC_TARGET=""
APPIMAGE_FILE=$(find "$DIR" -maxdepth 1 \( -iname "*.AppImage" -o -iname "*.appimage" \) | head -n 1)
if [ -n "$APPIMAGE_FILE" ]; then
  EXEC_TARGET="$APPIMAGE_FILE"
elif [ -x "$DIR/app/AppRun" ]; then
  EXEC_TARGET="$DIR/app/AppRun"
else
  # Buscamos el ejecutable principal dentro de app/usr/bin
  CANDIDATE=$(find "$DIR/app/usr/bin" -maxdepth 1 -type f -executable 2>/dev/null | head -n 1)
  if [ -n "$CANDIDATE" ]; then
    EXEC_TARGET="$CANDIDATE"
  fi
fi
if [ -z "$EXEC_TARGET" ]; then
  echo "[lanzar.sh] No se encontro ni AppImage ni arbol extraido en $DIR" >&2
  exit 1
fi

# 3. Buscamos el .home portable (junto al AppImage o en subcarpeta)
HOME_DIR=$(find "$DIR" -maxdepth 3 -name "*.home" -type d | head -n 1)
if [ -n "$HOME_DIR" ]; then
  export HOME="$HOME_DIR"
fi

# 4. Forzamos SDL al compositor existente (gamescope/Plasma)
if [ -n "$WAYLAND_DISPLAY" ] && [ -z "$SDL_VIDEODRIVER" ]; then
  export SDL_VIDEODRIVER=wayland
elif [ -n "$DISPLAY" ] && [ -z "$SDL_VIDEODRIVER" ]; then
  export SDL_VIDEODRIVER=x11
fi

# 5. Lanzamos
exec "$EXEC_TARGET" "$@"
