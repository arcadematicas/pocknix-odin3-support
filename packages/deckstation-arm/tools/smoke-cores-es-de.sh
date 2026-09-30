#!/bin/bash
# ============================================================================
#  smoke-cores-es-de.sh — prueba cada core con una ROM real y dice si arranca.
#
#  Ejecutar EN el dispositivo (necesita pantalla para que RetroArch inicialice
#  el contexto grafico). Criterio de exito: el log de RetroArch contiene la
#  linea "Geometry: WxH" (prueba de que el core ha inicializado y renderiza).
#  OJO: un rc=0 sin "Geometry" NO es exito: RetroArch se queda en el menu y
#  tambien sale con 0. Un rc!=0 con "Geometry" suele ser CONTENIDO (romset que
#  no encaja, BIOS que falta), no un core roto.
#
#  Uso:  bash smoke-cores-es-de.sh            (lista core:sistema del script)
#        Luego revisa /tmp/sm-<core>.log
# ============================================================================
export LC_ALL=C DISPLAY=:1 XDG_RUNTIME_DIR=/run/user/1001
RA=$(ls -d /opt/deckstation/Apps/RetroArch/*.home | head -1)
C="$RA/.config/retroarch/cores"
R=/opt/deckstation/ROMs
LISTA="bsnes2014_accuracy:snes bsnes2014_balanced:snes bsnes2014_performance:snes bsnes_cplusplus98:snes bsnes_mercury_balanced:snes bsnes_mercury_performance:snes chimerasnes:snes mednafen_snes:snes nside_sfc_balanced:snes snes9x2002:snes snes9x2005:snes mesen2:nes bnes:nes fixnes:nes rustynes:nes fceunext:nes fixgb:gb irogb:gb skyemu:gb mednafen_gba:gba meteor:gba mgba_rumble:gba clownmdemu:genesis genesis_plus_gx_EX:genesis duckstation:psx pcsx_rearmed_rumble:psx play:ps2 pcee2:ps2 mupen64plus:n64 fly_flycast:dreamcast flycast_rumble:dreamcast mame2003_midway:arcade mame2015:arcade mame2016:arcade hbmame:arcade mametiger:arcade km_fbneo_xtreme_amped:fbneo mess:arcade fsuae:amiga uae4arm:amiga dosbox:dos tia:atari2600 gearlynx:atarilynx hatari2014:atarist jollycv:colecovision fake08:pico8 freej2me-plus:j2me emuscv:scv amiarcadia:arcadia daphne:daphne minivmac:macintosh cemu:wiiu"
ok=0; fallo=0; sinrom=0
for par in $LISTA; do
  core="${par%%:*}"; sis="${par##*:}"
  so="$C/${core}_libretro.so"
  rom=$(find "$R/$sis" -maxdepth 1 -type f ! -iname '*.txt' ! -iname '*.log' 2>/dev/null | head -1)
  if [ ! -f "$so" ]; then printf '  %-24s %-10s SIN CORE\n' "$core" "$sis"; fallo=$((fallo+1)); continue; fi
  if [ -z "$rom" ]; then printf '  %-24s %-10s sin ROM\n' "$core" "$sis"; sinrom=$((sinrom+1)); continue; fi
  L="/tmp/sm-$core.log"; : > "$L"
  HOME="$RA" XDG_CONFIG_HOME="$RA/.config" timeout 70 /opt/deckstation/Apps/RetroArch/retroarch \
     -L "$so" "$rom" --max-frames=150 --verbose >"$L" 2>&1
  rc=$?
  cargado=$(grep -c 'Loading dynamic libretro core' "$L")
  fatal=$(grep -aiE 'failed to load|not found|cannot open|fatal|segmentation|core failed|unsupported' "$L" | head -1 | cut -c1-70)
  if [ "$cargado" -ge 1 ] && [ -z "$fatal" ] && [ "$rc" -eq 0 ]; then
    printf '  %-24s %-10s ✅ OK (%s)\n' "$core" "$sis" "$(basename "$rom" | cut -c1-28)"; ok=$((ok+1))
  else
    printf '  %-24s %-10s ⚠️  rc=%s cargado=%s %s\n' "$core" "$sis" "$rc" "$cargado" "${fatal:-?}"; fallo=$((fallo+1))
  fi
done
echo "  ================ OK=$ok · fallos=$fallo · sin ROM=$sinrom ================"
