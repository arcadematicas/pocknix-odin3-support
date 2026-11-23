#!/usr/bin/env python3
"""Genera appman.json: el catalogo de AM (AppMan) filtrado a juegos y multimedia.

De donde sale la lista de entrada:
  - De la propia app en la consola:  ~/.local/share/AM/aarch64-appimages
  - O del repo de AM:                 https://github.com/ivan-hc/AM (rama main, modules/database.am
                                      descarga esas mismas listas)

Cada linea tiene el formato:  ◆ id : descripcion

Uso:
  tools/gen-appman-catalogue.py ENTRADA [SALIDA]
  (por defecto SALIDA = packages/pocknix-store/appman.json, junto a este script)

El resultado lo consume pocknix-store: las entradas se sirven en la seccion "AppImages" y se
instalan con `appman -i <id>` como usuario (sin root). El filtro es por palabras clave en la
descripcion; si se afina, basta con editar GAMING / MULTI y volver a lanzar el script.
"""
import json
import re
import sys
from collections import Counter
from pathlib import Path

GAMING = re.compile(r"""(?ix)
 ( game|gaming|emulat|retro|arcade|mame|console|nintendo|snes|\bnes\b|genesis|megadrive|
   dreamcast|saturn|playstation|\bps[1-3x]\b|\bpsp\b|xbox|switch|\b3ds\b|game ?boy|\bgba\b|
   atari|amiga|dosbox|scummvm|duckstation|dolphin|pcsx|melon|\bcitra\b|azahar|ryujinx|86box|
   \bvice\b|\bc64\b|msx|neogeo|fightcade|libretro|gamepad|joystick|controller profile|steam|
   lutris|heroic|\bwine\b|proton|doom|quake|minecraft|\bmods?\b|recomp|decompil|rpg maker|suyu|
   yuzu|eden emulator|ppsspp|cemu|vpinball|pinball|mugen|openra|dhewm|ioquake|prboom|gzdoom|
   \bn64\b|harkinian|2ship|zelda|mario|sonic|xash3d|vkquake|vkdoom|game engine|raylib|godot|
   \bemu\b|snes9x|fceux|mupen|project64|flycast|redream|yaba|mednafen|xemu|cemuhook|
   gamepad|dualsense|dualshock|8bitdo|steam deck|gamescope|mangohud
 )""")

MULTI = re.compile(r"""(?ix)
 ( video|audio|music|\bplayer\b|media player|codec|ffmpeg|\bobs\b|stream|radio|podcast|subtitle|
   kdenlive|davinci|blender|\bgimp\b|krita|\bimage\b|photo|paint|screen record|capture|
   equalizer|\bdj\b|midi|synth|tracker|\bmpv\b|\bvlc\b|youtube|spotify|plex|jellyfin|kodi|
   handbrake|audacity|ardour|reaper|\bmp3\b|flac|video editor|video converter|transcod|
   \bodio\b|podcast|audiobook|daw\b|instrument|metronome|tablature|guitar|karaoke|wallpaper|
   comic|ebook|pdf viewer|image viewer|screenshot|gif|animation
 )""")

LINE = re.compile(r"^◆\s+([^\s:]+)\s*:\s*(.*)$")


def main() -> int:
    if len(sys.argv) < 2:
        print(__doc__)
        return 2
    src = Path(sys.argv[1]).expanduser()
    out = Path(sys.argv[2]) if len(sys.argv) > 2 else (
        Path(__file__).resolve().parent.parent / "packages/pocknix-store/appman.json")

    entries, seen = [], set()
    for line in src.read_text(encoding="utf-8", errors="replace").splitlines():
        m = LINE.match(line.strip())
        if not m:
            continue
        aid, desc = m.group(1), m.group(2).strip()
        if aid in seen:
            continue
        cats = []
        if GAMING.search(desc) or GAMING.search(aid):
            cats.append("juegos")
        if MULTI.search(desc) or MULTI.search(aid):
            cats.append("multimedia")
        if not cats:
            continue
        seen.add(aid)
        entries.append({"id": aid, "name": aid,
                        "description": re.sub(r"^Unofficial\.\s*", "", desc), "cats": cats})

    entries.sort(key=lambda e: e["id"].lower())
    out.write_text(json.dumps(entries, ensure_ascii=False, indent=0) + "\n", encoding="utf-8")
    print(f"{len(entries)} entradas -> {out}")
    print(Counter(tuple(e["cats"]) for e in entries))
    return 0


if __name__ == "__main__":
    sys.exit(main())
