#!/usr/bin/env python3
# ============================================================================
#  inserta-cores-es-de.py — mete en el es_systems.xml de ES-DE un <command> por
#  cada core libretro instalado, para que TODOS aparezcan como emulador
#  alternativo (el primero de cada sistema sigue siendo el predeterminado).
#
#  Uso:
#    1) Genera el listado de cores instalados y sus metadatos EN EL DISPOSITIVO:
#         RA=$(ls -d /opt/deckstation/Apps/RetroArch/*.home | head -1)
#         for so in "$RA"/.config/retroarch/cores/*_libretro.so; do ... done > cores-meta.txt
#       (formato: core|corename|display_name|systemid|systemname)
#    2) Ajusta FICHERO y META abajo y ejecútalo. Hace copia de seguridad en
#       /tmp/es_systems-antes.xml y valida el XML resultante.
#
#  DECISIONES (importantes, no tocar a la ligera):
#   - La tabla DEST es EXPLÍCITA por core (sistema o lista de sistemas). Un
#     intento previo de "inferir familias" metía cores donde no tocaban (p.ej.
#     cores de NES en WonderSwan, porque mesen_2 aparece en varios sistemas).
#   - El comando nuevo se inserta DESPUÉS del último <command> del sistema (o
#     antes de <platform> si el sistema no tenía ninguno) -> el predeterminado
#     existente nunca cambia.
#   - La etiqueta sale del display_name del .info (texto del último paréntesis).
#   - Los cores que crashean NO deben estar en DEST (ver smoke-cores-es-de.sh).
# ============================================================================
"""v4 (final): añade cores como alternativas en es_systems.xml. Ancla = último <command>, o antes de <platform>."""
import re, shutil, xml.etree.ElementTree as ET

F = '/home/fransis/deckstation-arm/configs/es-de/custom_systems/es_systems.xml'
META = '/tmp/opencode/cores-meta.txt'
TM = '<command label="{lab}">%EMULATOR_RETROARCH% -L %CORE_RETROARCH%/{core}_libretro.so %ROM%</command>'

SNES = ['snes','sfc','snesna','snesh']
NES = ['nes','famicom','fds','nesh']
GB = ['gb','gbc','sgb']
MD = ['genesis','megadrive','megadrivejp','segacd','megacd','megacdjp']
GPX = MD + ['gamegear','mastersystem','sega32x','sega32xjp','sega32xna','sg-1000']
ARC = ['arcade','mame','cps','cps1','cps2','cps3','consolearcade','neogeocd','neogeocdjp']
NAO = ['dreamcast','atomiswave','naomi','naomi2','naomigd']
AMG = ['amiga','amiga1200','amiga600','amigacd32','cdtv']
DEST = {}
for c in ['bsnes2014_accuracy','bsnes2014_balanced','bsnes2014_performance','bsnes_cplusplus98',
          'bsnes_mercury_balanced','bsnes_mercury_performance','chimerasnes','mednafen_snes',
          'nside_sfc_balanced','snes9x2002','snes9x2005']: DEST[c] = SNES
for c in ['bnes','fixnes','rustynes','fceunext']: DEST[c] = NES
DEST['mesen2'] = NES + ['gb','gbc','snes','sfc','snesna','gba','pcengine','pcenginecd','mastersystem','gamegear','wonderswan']
for c in ['fixgb','irogb']: DEST[c] = GB
DEST['skyemu'] = ['gb','gbc','gba','nds']
for c in ['mednafen_gba','meteor','mgba_rumble']: DEST[c] = ['gba']
DEST['clownmdemu'] = MD
DEST['genesis_plus_gx_EX'] = GPX
for c in ['duckstation','pcsx_rearmed_rumble']: DEST[c] = ['psx']
for c in ['play','pcee2']: DEST[c] = ['ps2']
DEST['mupen64plus'] = ['n64','n64dd']
for c in ['fly_flycast','flycast_rumble']: DEST[c] = NAO
for c in ['mame2003_midway','mame2015','mame2016','hbmame','mametiger']: DEST[c] = ARC
DEST['km_fbneo_xtreme_amped'] = ['fbneo','arcade','cps','cps1','cps2','cps3','ngp','ngpc','neogeocd','neogeocdjp']
DEST['mess'] = ['mess']
for c in ['fsuae','uae4arm']: DEST[c] = AMG
DEST['dosbox'] = ['dos','pc','windows3x','windows9x']
DEST['tia'] = ['atari2600']
DEST['gearlynx'] = ['atarilynx']
DEST['hatari2014'] = ['atarist']
DEST['jollycv'] = ['colecovision']
DEST['fake08'] = ['pico8']
DEST['freej2me-plus'] = ['j2me']
DEST['emuscv'] = ['scv']
DEST['amiarcadia'] = ['arcadia']
DEST['daphne'] = ['daphne','laserdisc']
DEST['minivmac'] = ['macintosh']
DEST['cemu'] = ['wiiu']
ETIQ = {'mess':'MESS','fceunext':'FCEU-Next','flycast_rumble':'Flycast Rumble','mgba_rumble':'mGBA Rumble',
        'mupen64plus':'Mupen64Plus','pcsx_rearmed_rumble':'PCSX ReARMed Rumble','mametiger':'MAME TIGER',
        'km_fbneo_xtreme_amped':'FBNeo Xtreme Amped','genesis_plus_gx_EX':'Genesis Plus GX EX',
        'freej2me-plus':'FreeJ2ME-Plus'}

def etq(c, meta):
    if c in ETIQ: return ETIQ[c]
    dn = (meta.get(c, {}).get('dn','') or '').strip()
    m = re.findall(r'\(([^()]+)\)\s*$', dn)
    return m[0].strip() if m else c

def main():
    meta = {}
    for l in open(META, encoding='utf-8', errors='replace'):
        p = l.rstrip('\n').split('|')
        if len(p) >= 5: meta[p[0]] = {'dn': p[2]}
    shutil.copy(F, '/tmp/opencode/es_systems-antes.xml')
    L = open(F, encoding='utf-8').read().split('\n')
    bloques, act = [], None
    for i, l in enumerate(L):
        if '<system>' in l:
            act = {'nom': None, 'cmds': [], 'plat': None}
        elif act is not None:
            m = re.search(r'<name>([^<]+)</name>', l)
            if m and act['nom'] is None: act['nom'] = m.group(1)
            if re.match(r'\s*<command\s', l): act['cmds'].append(i)
            if '<platform>' in l and act['plat'] is None: act['plat'] = i
            if '</system>' in l: bloques.append(act); act = None
    norm = {}
    for b in bloques:
        norm[b['nom']] = set()
        for i in b['cmds']:
            mm = re.search(r'%CORE_RETROARCH%/([a-zA-Z0-9_\-]+)\.so', L[i])
            if mm: norm[b['nom']].add(mm.group(1)[:-9] if mm.group(1).endswith('_libretro') else mm.group(1))
    print("  sistemas:", len(bloques), "· sistemas de la tabla inexistentes:",
          sorted({s for v in DEST.values() for s in v} - set(norm)) or 'ninguno')
    dest = {}
    for c, sistemas in DEST.items():
        for s in sistemas:
            if s in norm and c not in norm[s]:
                dest.setdefault(s, [])
                if c not in dest[s]: dest[s].append(c)
    orden = list(DEST)
    for s in dest: dest[s] = sorted(set(dest[s]), key=orden.index)
    print(f"  comandos antes: {sum(len(b['cmds']) for b in bloques)} (libretro) · a añadir: "
          f"{sum(len(v) for v in dest.values())} en {len(dest)} sistemas")

    borrar, mover, ins_after, ins_before = set(), None, {}, {}
    for b in bloques:
        if b['nom'] == 'psx':
            for i in b['cmds']:
                if 'goosestation' in L[i]: borrar.add(i)
                if 'swanstation' in L[i]: mover = (i, b['cmds'][0])
            print("  psx: goosestation fuera · swanstation -> primero")
        if b['nom'] not in dest or not dest[b['nom']]: continue
        vivos = [i for i in b['cmds'] if i not in borrar]
        if vivos and len(vivos) > 1:
            vivos = [i for i in vivos if mover is None or i != mover[0]]
        nuevas = []
        vistos = set()
        for c in dest[b['nom']]:
            lab = etq(c, meta)
            if lab in vistos: lab = f"{lab} ({c})"
            vistos.add(lab); nuevas.append(TM.format(lab=lab, core=c))
        if vivos: ins_after[vivos[-1]] = nuevas
        elif b['plat'] is not None: ins_before[b['plat']] = nuevas
        else: print("  AVISO: sin ancla en", b['nom'])
    out, mov = [], False
    for i, l in enumerate(L):
        if mover and i == mover[0]: continue
        if mover and i == mover[1] and not mov:
            out.append(L[mover[0]]); mov = True
        if i in borrar: continue
        if i in ins_before: out.extend(ins_before[i])
        out.append(l)
        if i in ins_after: out.extend(ins_after[i])
    txt = '\n'.join(out)
    open(F, 'w', encoding='utf-8').write(txt)
    ET.parse(F)
    print("  XML válido: SÍ · comandos después:", len(re.findall(r'<command[ >]', txt)),
          "· cores sin .info:", [c for c in DEST if c not in meta] or 'ninguno')

main()
