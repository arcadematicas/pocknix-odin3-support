#!/bin/bash
# ======================================================================
# deckstation-emulators-sync.sh — ES-DE: solo emuladores instalados
# ======================================================================
# ES-DE resuelve %EMULATOR_X% con custom_systems/es_find_rules.xml. Si el
# emulador NO esta instalado, la opcion sigue apareciendo en el selector de
# emulador, se elige y NO ocurre nada (o sale "emulator not found"). Eso
# pasaba con los emuladores STANDALONE (Citra, Cemu, PPSSPP, Xenia...),
# porque nadie los filtraba: solo se filtraba el %CORE_RETROARCH% (eso lo
# hace deckstation-cores-sync.sh).
#
# Aqui se generaliza ese mecanismo a TODOS los emuladores:
#   1. es_find_rules.xml dice, por cada <emulator name="X">, DONDE buscarlo
#      (una o varias rutas, en reglas systempath / staticpath / corepath).
#   2. Un emulador esta AUSENTE si NINGUNA de sus rutas existe.
#   3. Se quitan del es_systems.xml los <command> que usen un emulador
#      ausente. Del resto del fichero no se toca NADA: solo lineas
#      <command> enteras, y el XML resultante se valida antes de escribir.
#
# Tambien caza el caso "regla que apunta al vacio": xbox360 daba "emulator
# not found" porque XENIA-EDGE apuntaba a un AppImage al que le anadieron
# la arquitectura al nombre (arreglado en 3d5aa63). Si un comando usa un
# emulador que no tiene <emulator name=...> en es_find_rules.xml, sale en el
# informe como REGLA ROTA: casi siempre es una ruta que cambio de nombre.
#
# DIFERENCIA CON deckstation-cores-sync.sh (deliberada):
#   - El de CORES REGENERA el activo desde el source (asi, si mañana se
#     instala un core, su comando reaparece solo). Este NO resucita nada:
#     filtra el ACTIVO en el sitio. Si regenerara desde el source,
#     desharia lo que acaba de hacer el de cores (volveria a poner
#     comandos con cores que faltan). Por eso va DESPUES de el: asi se
#     componen, y el source mandra siempre.
#   - El de cores mira si el .so del CORE existe; este mira si el
#     EMULADOR existe. Cada filtro deja el comando si lo suyo esta.
#
# No destructivo: backup del activo en es_systems.xml.bak-emus antes de
# tocar nada. Nunca toca el source. Si no hay nada que quitar, no escribe
# (no se cambia ni la fecha del fichero).
#
# Uso: deckstation-emulators-sync.sh [--dry-run]
# Lo llaman deckstation-setup.sh y deckstation-launcher.sh.
# ======================================================================
set -u

SELF="$(readlink -f "${BASH_SOURCE[0]}")"
DECKSTATION_ROOT="${DECKSTATION_ROOT:-$(cd "$(dirname "$SELF")/.." && pwd)}"

DRY=0
while [ $# -gt 0 ]; do
    case "$1" in
        --dry-run) DRY=1 ;;
        -h|--help) sed -n '2,37p' "$SELF"; exit 0 ;;
    esac
    shift
done

log() { echo "  [emus-sync] $*"; }

APPS_DIR="${DECKSTATION_ROOT}/Apps"
ESDE_DIR="${DECKSTATION_ROOT}/DeckStation.AppImage.home/ES-DE/custom_systems"

# Fuente de verdad de "donde esta cada emulador": las reglas. Preferimos las
# del ACTIVO (son las que ES-DE esta usando ahora mismo); si no estan
# desplegadas todavia, las del source.
RULES=""
for cand in "${ESDE_DIR}/es_find_rules.xml" \
            "${DECKSTATION_ROOT}/configs/es-de/custom_systems/es_find_rules.xml"; do
    [ -f "$cand" ] && { RULES="$cand"; break; }
done

[ -f "$RULES" ] || { log "No hay es_find_rules.xml; nada que filtrar"; exit 0; }
[ -f "${ESDE_DIR}/es_systems.xml" ] || { log "No hay es_systems.xml activo; nada que filtrar"; exit 0; }
[ -d "$APPS_DIR" ] || { log "No hay carpeta Apps; nada que filtrar"; exit 0; }

python3 - "$RULES" "${ESDE_DIR}/es_systems.xml" "$DECKSTATION_ROOT" "$DRY" << 'PYEOF'
import os, re, sys, glob, pwd, shutil
import xml.etree.ElementTree as ET

rules_f, act_f, root, dry = sys.argv[1], sys.argv[2], sys.argv[3], sys.argv[4] == "1"
RE_EMU = re.compile(r"%EMULATOR_([A-Za-z0-9_.:-]+)%")
RE_CMD = re.compile(r"^\s*<command[\s>]")
RE_ID = re.compile(r"^[A-Za-z][A-Za-z0-9_]*(\.[A-Za-z0-9_-]+){2,}$")
P = "  [emus-sync] "

# --------------------------------------------------------------- candidatos
# ES-DE es un AppImage: las reglas con "~" se resuelven contra el HOME con el
# que se lanzo, que aqui no se sabe cual es. Se prueban TODOS los candidatos
# y basta con que uno exista: ante la duda, el emulador se considera
# instalado y su comando NO se borra (conservador).
homes = []
for h in (os.environ.get("HOME"), os.path.join(root, "DeckStation.AppImage.home")):
    if h and h not in homes:
        homes.append(h)
try:
    pw = pwd.getpwuid(os.getuid()).pw_dir
    if pw and pw not in homes:
        homes.append(pw)
except Exception:
    pass


def candidatos(valor):
    """Rutas candidatas de una <entry>. No comprueba existencia."""
    valor = valor.split("|", 1)[0].strip()      # ES-DE admite '<ruta>|<args>'
    if not valor:
        return []
    if valor.startswith("~/"):
        return [os.path.join(h, valor[2:]) for h in homes]
    if valor.startswith("./") or valor.startswith("../"):
        return [os.path.join(root, valor), os.path.abspath(valor)]
    if "/" in valor:
        return [valor]
    # Nombre "pelado" (rule systempath): ES-DE lo busca en el PATH y, si
    # parece un AppID de flatpak, en los exports de flatpak.
    out = []
    p = shutil.which(valor)
    if p:
        out.append(p)
    if RE_ID.match(valor):
        for d in ("/var/lib/flatpak/exports",
                  os.path.expanduser("~/.local/share/flatpak/exports")):
            out += [os.path.join(d, "bin", valor), os.path.join(d, "share", valor)]
    return out


def existe(entrada):
    for c in candidatos(entrada):
        if any(g in c for g in "*?["):
            if glob.glob(c):
                return True
        elif os.path.exists(c):
            return True
    return False


# --------------------------------------------------------------- las reglas
# Parser por tokens (no con ET): es_find_rules.xml trae DOCTYPE y entidades
# HTML custom que ET revienta, y lo que interesa son las <entry> tal cual.
# Se tokeniza el TEXTO ENTERO, no linea a linea: asi da igual que un <rule>,
# sus <entry> y el </rule> esten en lineas separadas (como van en el fichero
# real) o en la misma linea (un reformateo los dejaria en el aire y el filtro
# creeria que un emulador no tiene ninguna ruta -> lo borraria de un Plumero).
TOK = re.compile(
    r'<emulator\s+name="([^"]+)"'          # 1 nombre del emulador
    r'|<core\b'                             # (marca de inicio de <core>)
    r'|</core>'                             # (marca de fin de <core>)
    r'|<rule\s+type="([A-Za-z_]+)"'         # 2 tipo de regla
    r'|<entry>(.*?)</entry>',                # 3 valor de la entrada
    re.S)


def leer_reglas(path):
    texto = open(path, encoding="utf-8", errors="replace").read()
    emus, tipo, actual, en_core = {}, "", None, 0
    for t in TOK.finditer(texto):
        txt, nombre, ntipo = t.group(0), t.group(1), t.group(2)
        if nombre is not None:                     # <emulator name="X">
            actual, tipo = nombre, ""
            emus.setdefault(actual, [])
        elif txt.startswith("<core"):
            en_core += 1
            tipo = ""
        elif txt == "</core>":
            en_core = max(0, en_core - 1)
            tipo = ""
        elif ntipo is not None:                    # <rule type="...">
            tipo = ntipo
        elif actual is not None and not en_core:   # <entry>...</entry>
            e = t.group(3).strip()
            if e:
                emus[actual].append((tipo, e))
    return emus


emus = leer_reglas(rules_f)

# ------------------------------------------------------ quien esta ausente
ausentes = {}
for nombre, reglas in sorted(emus.items()):
    if not reglas:
        ausentes[nombre] = "sin ninguna regla en es_find_rules.xml"
        continue
    rutas = [e for tipo, e in reglas if tipo != "corepath"]
    if not rutas:
        continue                 # solo corepath: eso lo lleva el script de cores
    if not any(existe(e) for e in rutas):
        ausentes[nombre] = "ninguna de sus %d rutas existe" % len(rutas)

# ----------------------------------------------- que sistema es cada linea
lineas = open(act_f, encoding="utf-8", errors="replace").read().split("\n")
sistema_de, nombre = {}, "(fuera)"
for i, l in enumerate(lineas):
    if "<system>" in l:
        nombre = "(desconocido)"
    m = re.search(r"<name>([^<]+)</name>", l)
    if m and nombre == "(desconocido)":
        nombre = m.group(1).strip()
    sistema_de[i] = nombre
    if "</system>" in l:
        nombre = "(fuera)"

# ------------------------------------------------------ comandos por sistema
usados, fuera, detalle, vacias = set(), [], {}, set()
por_sistema = {}
for i, l in enumerate(lineas):
    if not RE_CMD.match(l):
        continue
    sis = sistema_de[i]
    por_sistema.setdefault(sis, []).append(i)
    vs = RE_EMU.findall(l)
    usados.update(vs)
    malos = [v for v in vs if v in ausentes]
    if malos:
        et = re.search(r'label="([^"]*)"', l)
        fuera.append(i)
        detalle.setdefault(sis, []).append((et.group(1) if et else "(sin label)", malos[0]))

# Un sistema SIN ningun <command> se muestra en ES-DE pero no se puede jugar:
# eso es peor que dejar un comando que no arranca. Si el filtro lo vacia, se
# conserva el primero (el predeterminado) y se avisa.
for sis, idxs in sorted(por_sistema.items()):
    if all(i in fuera for i in idxs):
        vacias.add(sis)
        fuera.remove(idxs[0])

# ----------------------------------------------------------------- informe
rotas = sorted(n for n in usados if n not in emus)
sin_usar = sorted(set(emus) - usados - set(ausentes))

print(P + "reglas leidas: %d emuladores" % len(emus))
print(P + "AUSENTES (ninguna de sus rutas existe): %d" % len(ausentes))
for n, m in sorted(ausentes.items()):
    print(P + "   %-9s %-26s %s" % ("(en uso)" if n in usados else "(nunca)", n, m))

if rotas:
    print(P + "REGLA ROTA: %d emuladores usados que NO estan en es_find_rules.xml" % len(rotas))
    for n in rotas:
        print(P + "   %-26s falta <emulator name=\"%s\">" % (n, n))
else:
    print(P + "reglas rotas: ninguna")
print(P + "definidos pero no usados por ningun comando: %d (normal)" % len(sin_usar))

print(P + "comandos a quitar: %d" % len(fuera))
for sis, items in sorted(detalle.items()):
    for etiqueta, v in items:
        print(P + "   %-12s %-28s (%%%s%% no instalado)" % (sis, etiqueta, v))
for sis in sorted(vacias):
    print(P + "   AVISO: %s se quedaba sin comandos; se conserva el primero" % sis)

if not fuera:
    print(P + "nada que hacer (el activo ya esta filtrado)")
    sys.exit(0)
if dry:
    print(P + "SIMULACION: no se ha escrito nada")
    sys.exit(0)

fuera = set(fuera)
out = [l for i, l in enumerate(lineas) if i not in fuera]
txt = "\n".join(out)
try:
    ET.fromstring(txt)
except Exception as exc:
    print(P + "AVISO: el resultado no es XML valido (%s); NO se toca el activo" % exc)
    sys.exit(0)

bak = act_f + ".bak-emus"
shutil.copy(act_f, bak)
with open(act_f, "w", encoding="utf-8") as fh:
    fh.write(txt)
print(P + "quitados %d comandos | backup en %s" % (len(fuera), os.path.basename(bak)))
PYEOF
