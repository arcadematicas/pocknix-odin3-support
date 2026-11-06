#!/bin/sh
# xbox-diag.sh — recoge el estado de Xbox/hakuX en la Odin (solo lectura).
# Uso: sh tools/xbox-diag.sh [/ruta/al/juego.xiso]
set -u
ROM="${1:-}"
echo "===== sistema ====="
uname -a
echo
echo "===== cores hakuX/xemu ====="
find /home/deck /usr/lib/libretro -maxdepth 7 \( -name "hakux_libretro.so" -o -name "xemu_libretro.so" -o -name "hakux_libretro.info" \) 2>/dev/null | while read -r f; do ls -l "$f"; done
echo
echo "===== .info: extensiones soportadas ====="
find /home/deck /usr/share/libretro -maxdepth 7 -name "hakux_libretro.info" 2>/dev/null | while read -r f; do
  echo "-- $f"
  grep -iE "^(display_name|library_name|supported_extensions|need_fullpath)" "$f" 2>/dev/null
done
echo
echo "===== Vulkan ====="
if command -v vulkaninfo >/dev/null 2>&1; then vulkaninfo --summary 2>&1 | head -25; else echo "vulkaninfo no instalado"; fi
echo
echo "===== ES-DE: bloque xbox del activo ====="
find /home/deck -maxdepth 7 -name "es_systems.xml" 2>/dev/null | while read -r f; do
  if grep -q "<name>xbox</name>" "$f" 2>/dev/null; then
    echo "-- $f"
    awk '/<name>xbox<\/name>/{p=1} p{print} p&&/<\/system>/{exit}' "$f"
  fi
done
echo
echo "===== ES-DE: log (cola) ====="
find /home/deck -maxdepth 7 -name "es_log.txt" 2>/dev/null | while read -r f; do echo "-- $f"; tail -40 "$f"; done
echo
echo "===== RetroArch: logs (cola) ====="
find /home/deck -maxdepth 7 -name "retroarch.log" 2>/dev/null | while read -r f; do echo "-- $f"; tail -40 "$f"; done
if [ -n "$ROM" ]; then
  echo
  echo "===== ROM ====="
  ls -l "$ROM" 2>&1
  file "$ROM" 2>&1
  echo "-- magic XDVDFS (offset 0x10000):"
  dd if="$ROM" bs=1 skip=65536 count=24 2>/dev/null | strings
fi
