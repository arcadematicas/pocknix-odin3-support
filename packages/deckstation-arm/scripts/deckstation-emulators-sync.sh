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
#   4. Si a un sistema se le quedan CERO comandos, se borra el <system>
#      ENTERO (no se conserva el primero). Antes se conservaba el primero
#      "por si acaso" y era un fallo: ese comando era justamente el que
#      no arranca, y ademas ES-DE se queja al arrancar de un sistema sin
#      <command> (SystemData.cpp:1115 -> LogError "skipping entry").
#      ES-DE no tiene forma de "esconder" un sistema, asi que quitarlo del
#      <systemList> es lo unico limpio: el sistema no se carga, su gamelist
#      no se parsea (parseGamelist se llama desde el constructor de
#      SystemData, SystemData.cpp:568) y no sale ni el sistema ni su aviso.
#   5. Los gamelist guardan el emulador elegido por ETIQUETA, no por ruta:
#         <alternativeEmulator><label>GooseStation</label></alternativeEmulator>
#         <altemulator>DuckStation (Standalone)</altemulator>
#      Si esa etiqueta ya no corresponde a ningun <command label="..."> del
#      sistema, ES-DE 3.5 marca <INVALID>... (GamelistFileParser.cpp:210) y
#      saca un dialogo modal en CADA arranque (main.cpp:1202-1209). Por eso
#      aqui tambien se reparan los gamelist: se quita el <label> o el
#      <altemulator> huerfano. Es OJO con esto: pasa cada vez que se filtra
#      un comando, no solo al vaciar un sistema.
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
bloques = {}          # nombre -> (linea <system>, linea </system>)
_ini = None
for i, l in enumerate(lineas):
    if "<system>" in l:
        nombre = "(desconocido)"
        _ini = i
    m = re.search(r"<name>([^<]+)</name>", l)
    if m and nombre == "(desconocido)":
        nombre = m.group(1).strip()
    sistema_de[i] = nombre
    if "</system>" in l:
        if _ini is not None and nombre != "(desconocido)":
            bloques.setdefault(nombre, (_ini, i))
        nombre = "(fuera)"
        _ini = None

# ------------------------------------------------------ comandos por sistema
usados, fuera, detalle = set(), [], {}
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

# Un sistema al que el filtro le quita TODOS sus <command> se queda inservible:
# ES-DE no puede jugar y ademas se queja (SystemData.cpp:1115 -> LogError
# "is missing the fullname, path, extension, or command tag, skipping
# entry"). Antes aqui se conservaba el primer comando "por si acaso"; era un
# fallo, porque ese comando era justo el que no arranca. Ahora se borra el
# bloque <system> ENTERO: ES-DE 3.5 no tiene forma de esconder un sistema
# (no existe ningun isEnabled en SystemData.h), asi que quitarlo del
# <systemList> es lo unico limpio. El sistema no se carga, su gamelist no se
# parsea (parseGamelist se llama desde el constructor, SystemData.cpp:568)
# y no sale ni el sistema ni su aviso. Si el emulador aparece otro dia, el
# source lo devuelve solo en el siguiente arranque.
vacias = set()
for sis, idxs in sorted(por_sistema.items()):
    if all(i in fuera for i in idxs):
        if sis in bloques:
            vacias.add(sis)
        else:
            print(P + "AVISO: %s se queda sin comandos pero su <system> no se "
                       "puede borrar entero; se conserva el primero" % sis)
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

# ------------------------------------------------- borrar los <system> vacios
# Un sistema sin ningun <command> no se puede jugar y ES-DE lo rechaza con un
# LogError al arrancar (SystemData.cpp:1115 -> "is missing the fullname, path,
# extension, or command tag, skipping entry"). No hay forma de "esconderlo"
# (SystemData.h no tiene ningun isEnabled), asi que se borra el bloque entero:
# el sistema no se carga, su gamelist no se parsea (parseGamelist se llama
# desde el constructor de SystemData, SystemData.cpp:568) y no sale ni el
# sistema ni el aviso. Si el emulador aparece otro dia, el source lo devuelve.
n_sis_antes = len(bloques)
n_comandos_antes = sum(len(v) for v in por_sistema.values())
fuera_bloques = set()
for sis in sorted(vacias):
    ini, fin = bloques[sis]
    fuera_bloques.update(range(ini, fin + 1))
    print(P + "   SISTEMA FUERA: %-12s (ningun emulador installed; no se puede "
               "jugar y ES-DE lo rechaza al arrancar)" % sis)
print(P + "sistemas: %d -> %d | comandos: %d -> %d" %
      (n_sis_antes, n_sis_antes - len(vacias), n_comandos_antes,
       n_comandos_antes - len(fuera)))

# --------------------------------------------------- red de seguridad maxima
# Si esto se disparara en un despliegue donde, por lo que sea, casi todos los
# emuladores pareciesen ausentes, el filtro vaciaria ES-DE entero. Es mucho
# mejor quedarse como esta (y que se note en el log) que dejar un ES-DE sin
# sistemas. Los topes se pueden mover con el entorno si hace falta.
MAX_SISTEMAS_FUERA = int(os.environ.get("EMUS_MAX_SISTEMAS_FUERA", "25"))
MAX_COMANDOS_PCT = int(os.environ.get("EMUS_MAX_COMANDOS_PCT", "80"))
pct = (100.0 * len(fuera) / n_comandos_antes) if n_comandos_antes else 0.0
if len(vacias) > MAX_SISTEMAS_FUERA or pct > MAX_COMANDOS_PCT:
    print(P + "ABORTA: el filtro se llevaria %d sistemas (> %d) o el %.0f%% de "
               "los comandos (> %d%%); NO se ha escrito nada" %
          (len(vacias), MAX_SISTEMAS_FUERA, pct, MAX_COMANDOS_PCT))
    sys.exit(0)

# ------------------------------------------------- construir y validar el XML
borrar = set(fuera) | fuera_bloques
txt_final = "\n".join(l for i, l in enumerate(lineas) if i not in borrar)
try:
    raiz = ET.fromstring(txt_final)
except Exception as exc:
    print(P + "AVISO: el resultado no es XML valido (%s); NO se toca el activo" % exc)
    sys.exit(0)

# Etiquetas (<command label=...>) que quedan en cada sistema, ya filtrado.
labels_por_sistema = {}
for s in raiz.findall("system"):
    nm = (s.findtext("name") or "").strip()
    if nm:
        labels_por_sistema[nm] = {c.get("label") for c in s.findall("command")
                                  if c.get("label")}
sistemas_vivos = set(labels_por_sistema)

# --------------------------------------------------- reparar los gamelist.xml
# ES-DE guarda el emulador elegido por ETIQUETA, no por ruta:
#     <alternativeEmulator><label>GooseStation</label></alternativeEmulator>
#     <altemulator>DuckStation (Standalone)</altemulator>
# Si esa etiqueta ya no corresponde a ningun <command label> de ESE sistema,
# ES-DE la marca <INVALID> (GamelistFileParser.cpp:210) y saca un dialogo modal
# en CADA arranque (main.cpp:1202-1209). Y por juego solo avisa al lanzar y cae
# al comando por defecto (FileData.cpp:997-1005). Ocurre cada vez que se quita
# un comando, no solo al vaciar un sistema: por ejemplo, si un juego esta puesto
# en "Mednafen (Standalone)" y Mednafen no esta instalado. Aqui se quitan las
# referencias huerfanas, que es lo que hace el propio ES-DE al escribir el
# gamelist cuando ya no hay emulador alternativo (GamelistFileParser.cpp:452).
ESDE_DIR = os.path.join(root, "DeckStation.AppImage.home", "ES-DE")
GAMELISTS = os.path.join(ESDE_DIR, "gamelists")
RE_ALT_SYS = re.compile(
    r"[ \t]*<alternativeEmulator>\s*<label>([^<]*)</label>\s*</alternativeEmulator>"
    r"[ \t]*\r?\n?")
RE_ALT_JUEGO = re.compile(r"[ \t]*<altemulator>([^<]*)</altemulator>[ \t]*\r?\n?")


def xml_valido(t):
    """ET.fromstring tolerando el <alternativeEmulator> hermano de <gameList>
    que escribe ES-DE: eso no es XML bien formado para un parser estricto, pero
    ES-DE lo lee. Lo que nos importa es no romper NADA mas de lo que ya estaba."""
    try:
        ET.fromstring(t)
        return True
    except Exception:
        pass
    try:
        ET.fromstring("<w>" + t.split("?>", 1)[-1].lstrip("\n") + "</w>")
        return True
    except Exception:
        return False


reparados = []
if os.path.isdir(GAMELISTS):
    for d in sorted(os.listdir(GAMELISTS)):
        g = os.path.join(GAMELISTS, d, "gamelist.xml")
        # Si el sistema ya no existe, ES-DE no parsea su gamelist: no hay nada
        # que arreglar y ademas, si el emulador vuelve, la etiqueta serviria.
        if not os.path.isfile(g) or d not in sistemas_vivos:
            continue
        validas = labels_por_sistema[d]
        orig = open(g, encoding="utf-8", errors="replace").read()
        huerfanas = []

        def _quita(m, ok=validas, acc=huerfanas):
            et = m.group(1).strip()
            if not et or et in ok:
                return m.group(0)
            acc.append(et)
            return ""

        nuevo = RE_ALT_SYS.sub(_quita, orig)
        nuevo = RE_ALT_JUEGO.sub(_quita, nuevo)
        if nuevo == orig:
            continue
        if not xml_valido(nuevo):
            print(P + "AVISO: %s/gamelist.xml quedaria raro al repararlo; NO se toca" % d)
            continue
        reparados.append((d, nuevo, sorted(set(huerfanas))))

# ------------------------------------------------------------------ escribir
if not fuera and not reparados:
    print(P + "nada que hacer (el activo ya esta filtrado y ningun gamelist "
               "referencia una etiqueta desaparecida)")
    sys.exit(0)
if dry:
    for d, _, hs in reparados:
        print(P + "   gamelist %-12s -> quitaria: %s" % (d, ", ".join(hs)))
    print(P + "SIMULACION: no se ha escrito nada")
    sys.exit(0)

if fuera:
    bak = act_f + ".bak-emus"
    shutil.copy(act_f, bak)
    with open(act_f, "w", encoding="utf-8") as fh:
        fh.write(txt_final)
    print(P + "quitados %d comandos y %d sistemas | backup en %s" %
          (len(fuera), len(vacias), os.path.basename(bak)))

for d, nuevo, hs in reparados:
    g = os.path.join(GAMELISTS, d, "gamelist.xml")
    shutil.copy(g, g + ".bak-emus")
    with open(g, "w", encoding="utf-8") as fh:
        fh.write(nuevo)
    print(P + "gamelist %-12s quitada etiqueta huerfana: %-28s | backup en "
               "gamelist.xml.bak-emus" % (d, ", ".join(hs)))
PYEOF
