#!/bin/bash
# ============================================================================
#  smoke-cores-es-de.sh (variante definitiva) — igual que el anterior pero lee
#  el log propio de RetroArch (~/.config/retroarch/logs/retroarch.log) y da por
#  bueno el core solo si aparece "Geometry: WxH". Es la version fiable.
# ============================================================================
export LC_ALL=C DISPLAY=:1 XDG_RUNTIME_DIR=/run/user/1001
RA=$(ls -d /opt/deckstation/Apps/RetroArch/*.home | head -1)
C="$RA/.config/retroarch/cores"; LGC="$RA/.config/retroarch/logs/retroarch.log"
LISTA="skyemu:gb mednafen_gba:gba meteor:gba mgba_rumble:gba irogb:gb fixgb:gb mesen2:nes rustynes:nes \
fceunext:nes chimerasnes:snes bsnes2014_accuracy:snes bsnes2014_balanced:snes bsnes2014_performance:snes \
bsnes_cplusplus98:snes bsnes_mercury_balanced:snes bsnes_mercury_performance:snes snes9x2002:snes \
pcsx_rearmed_rumble:psx dosbox:dos tia:atari2600 gearlynx:atarilynx fake08:pico8 mametiger:arcade \
clownmdemu:megadrive genesis_plus_gx_EX:megadrive play:ps2 pcee2:ps2 cemu:wiiu"
ok=0; mal=0
for par in $LISTA; do
  core="${par%%:*}"; sis="${par##*:}"
  rom=$(find /opt/deckstation/ROMs/$sis -maxdepth 1 -type f ! -iname '*.txt' ! -iname '*.log' 2>/dev/null | head -1)
  [ -z "$rom" ] && { printf '  %-24s %-10s sin ROM\n' "$core" "$sis"; continue; }
  : > "$LGC"
  HOME="$RA" XDG_CONFIG_HOME="$RA/.config" timeout 150 /opt/deckstation/Apps/RetroArch/retroarch \
     -L "$C/${core}_libretro.so" "$rom" --max-frames=100 >/dev/null 2>&1
  rc=$?
  geo=$(grep -aoE 'Geometry: [0-9]+x[0-9]+|Version de la API libretro: [0-9]+|Version of libretro API: [0-9]+' "$LGC" | tail -1)
  cras=$(grep -aciE 'double free|corruption|dumped core|segmentation' "$LGC")
  if [ -n "$geo" ] && [ "$cras" -eq 0 ]; then printf '  %-24s %-10s ✅ %s\n' "$core" "$sis" "${geo:0:34}"; ok=$((ok+1));
  else printf '  %-24s %-10s ⚠️  rc=%s core=%s cras=%s\n' "$core" "$sis" "$rc" "${geo:-NO}" "$cras"; mal=$((mal+1)); fi
done
echo "  ============ OK=$ok · dudosos=$mal ============"
