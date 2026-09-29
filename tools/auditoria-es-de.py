#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
auditoria-es-de.py
==================

Auditoria de SOLO LECTURA de la configuracion de ES-DE
(EmulationStation Desktop Edition).

NO escribe ni modifica NADA fuera de /tmp/opencode/.
Los ficheros de entrada se leen y nada mas.

Entradas (configurables por variable de entorno):

  ESDE_SYSTEMS        es_systems.xml        (define los SISTEMAS)
  ESDE_FIND_RULES     es_find_rules.xml     (define los EMULADORES)
  ESDE_APPS           apps.txt              (carpetas instaladas en ./Apps/)
  ESDE_CORES_PORT     cores-portables.txt   (cores en la carpeta portable)
  ESDE_CORES_SISTEMA  cores-sistema.txt     (cores en /usr/lib/libretro/)
  ESDE_ROMS           roms.txt              (sistemas que tienen ROMs)
  ESDE_ROOT           raiz real del DeckStation (opcional; si se define se
                                            comprueba el disco de verdad)
  ESDE_JSON_OUT       salida del modo --json (debe estar bajo /tmp/opencode)

Valores por defecto: todos en /tmp/opencode/audit/

Uso:
  python3 auditoria-es-de.py            # informe legible (10 lineas/seccion)
  python3 auditoria-es-de.py --all      # informe completo, sin truncar
  python3 auditoria-es-de.py --json     # ademas escribe el JSON
  python3 auditoria-es-de.py --which    # ademas comprueba 'command -v' local
"""

import json
import os
import re
import shutil
import sys
import xml.etree.ElementTree as ET

# --------------------------------------------------------------------------
# Rutas
# --------------------------------------------------------------------------
BASE_DIR = "/tmp/opencode/audit"
RAIZ_PERMITIDA = "/tmp/opencode"  # unico sitio donde se puede escribir


def ruta(env, nombre_defecto):
    return os.environ.get(env) or os.path.join(BASE_DIR, nombre_defecto)


F_SYSTEMS = ruta("ESDE_SYSTEMS", "es_systems.xml")
F_FIND_RULES = ruta("ESDE_FIND_RULES", "es_find_rules.xml")
F_APPS = ruta("ESDE_APPS", "apps.txt")
F_CORES_PORT = ruta("ESDE_CORES_PORT", "cores-portables.txt")
F_CORES_SISTEMA = ruta("ESDE_CORES_SISTEMA", "cores-sistema.txt")
F_ROMS = ruta("ESDE_ROMS", "roms.txt")
F_JSON = os.environ.get("ESDE_JSON_OUT") or "/tmp/opencode/auditoria-es-de.json"
RAIZ_DECKSTATION = os.environ.get("ESDE_ROOT") or ""

# Patrones
RE_EMULADOR = re.compile(r"%EMULATOR_([A-Za-z0-9_.-]+)%")
RE_CORE_REF = re.compile(r"%CORE_([A-Za-z0-9_.-]+)%/([A-Za-z0-9_.+-]+)")
RE_APPS = re.compile(r"^\.?/?(?:Apps)/(.+)$")
RE_ENTIDAD = re.compile(r"&([A-Za-z_][\w.-]*);")
ENTIDADES_XML = {"amp", "lt", "gt", "quot", "apos"}


# --------------------------------------------------------------------------
# Lectura de ficheros
# --------------------------------------------------------------------------
def leer_texto(path):
    if not path or not os.path.isfile(path):
        return None
    with open(path, "r", encoding="utf-8", errors="replace") as fh:
        return fh.read()


def leer_lista(path):
    """Un elemento por linea, ignorando vacios, comentarios y rutas de solo
    un elemento (p.ej. 'ls /x' -> '/x')."""
    texto = leer_texto(path)
    if texto is None:
        return []
    out = []
    for linea in texto.splitlines():
        s = linea.strip()
        if not s or s.startswith("#"):
            continue
        # "ls -1 /ruta" o "find /ruta -name x" -> quedarse con la ruta
        partes = s.split()
        if len(partes) > 1 and partes[0] in ("ls", "find", "echo", "cat"):
            s = partes[1] if partes[0] in ("ls", "find") else partes[-1]
        s = s.strip()
        if s.startswith("./"):
            s = s[2:]
        if s.endswith("/"):
            s = s[:-1]
        if s:
            out.append(s)
    return out


def norm_core(nombre):
    """Normaliza un nombre de core: quita carpetas y extensiones .so/.dll/.info."""
    n = os.path.basename(str(nombre).strip().strip('"').strip("'"))
    n = re.sub(r"\.(so|dylib|dll|info|zip)$", "", n, flags=re.IGNORECASE)
    return n


# --------------------------------------------------------------------------
# Parser XML tolerante
# --------------------------------------------------------------------------
class ErrorParser(str):
    pass


def _quitar_dtd_interno(texto):
    """Elimina el subconjunto interno '[...]' de un <!DOCTYPE ...> dejando el
    resto del DOCTYPE intacto. Evita que los tokens de sustitucion de entidades
    acaben dentro del DTD y que expat intente resolverlas."""
    i = texto.find("<!DOCTYPE")
    if i < 0:
        return texto, False
    j = texto.find("[", i)
    if j < 0:
        return texto, False
    k = texto.find("]", j)
    if k < 0:
        return texto, False
    # se quita solo '[...]' y se conserva el '>' que cierra el DOCTYPE
    return texto[:j] + texto[k + 1:], True


def _escapar_entidades_desconocidas(texto):
    """Sustituye entidades HTML custom (no estandar) por un token plano para
    que ElementTree no reviente, y devuelve (texto, mapa token->entidad)."""
    mapa = {}

    def sub(m):
        ent = m.group(1)
        if ent in ENTIDADES_XML:
            return m.group(0)
        token = "ENTIDAD_%d_X" % (len(mapa) + 1)
        mapa[token] = ent
        return token

    return RE_ENTIDAD.sub(sub, texto), mapa


def _revertir_entidades(texto, mapa):
    if not texto or not mapa:
        return texto
    for token, ent in mapa.items():
        texto = texto.replace(token, "&" + ent + ";")
    return texto


def parsear_xml(path):
    """Devuelve (root, avisos). Nunca lanza excepcion: si el XML esta roto
    degrada a un parser por lineas."""
    texto = leer_texto(path)
    if texto is None:
        raise SystemExit("ERROR: no existe el fichero %s" % path)

    intentos = []
    candidatos = []

    # 1) tal cual, por si el XML es valido de origen
    candidatos.append((texto, {}))

    # 2) sin el subconjunto interno del DOCTYPE + entidades sustituidas
    sin_dtd, habia_dtd = _quitar_dtd_interno(texto)
    limpio, mapa = _escapar_entidades_desconocidas(sin_dtd)
    if mapa or habia_dtd:
        intentos.append(
            "ajustes: subconjunto DTD interno eliminado=%s, entidades no estandar "
            "sustituidas=%s"
            % (
                "si" if habia_dtd else "no",
                ", ".join(sorted(set(mapa.values()))) or "(ninguna)",
            )
        )
    candidatos.append((limpio, mapa))

    for candidato, mp in candidatos:
        try:
            root = ET.fromstring(candidato)
            if mp:
                _restaurar_entidades(root, mp)
            return root, intentos
        except ET.ParseError as exc:
            intentos.append("XML no valido: %s" % exc)
    intentos.append("se usara el parser por lineas (degradado)")
    return None, intentos


def _restaurar_entidades(elem, mapa):
    for sub in elem.iter():
        if sub.text:
            sub.text = _revertir_entidades(sub.text, mapa)
        if sub.tail:
            sub.tail = _revertir_entidades(sub.tail, mapa)
        for k, v in list(sub.attrib.items()):
            sub.set(k, _revertir_entidades(v, mapa))


def _parsear_sistemas_lineas(texto):
    """Fallback por lineas: extrae <system>/<name>/<command> sin depender de un
    XML bien formado."""
    sistemas = []
    bloque = None
    cmd_re = re.compile(r"<command(\s[^>]*)?>(.*?)</command>", re.S)
    name_re = re.compile(r"<name>(.*?)</name>", re.S)

    def cerrar(bl):
        if not bl:
            return
        comandos = []
        for attrs, cuerpo in cmd_re.findall(bl["cuerpo"]):
            etiqueta = re.search(r'label="([^"]*)"', attrs or "")
            comandos.append(
                {
                    "label": etiqueta.group(1) if etiqueta else "(sin label)",
                    "texto": _revertir_entidades(cuerpo.strip(), MAPA_ENTIDADES_GLOBAL),
                }
            )
        m = name_re.search(bl["cuerpo"])
        sistemas.append(
            {
                "name": (m.group(1).strip() if m else "(desconocido)"),
                "fullname": "",
                "path": "",
                "commands": comandos,
            }
        )

    for linea in texto.splitlines():
        if "<system>" in linea:
            bloque = {"cuerpo": ""}
        if bloque is not None:
            bloque["cuerpo"] += linea + "\n"
        if "</system>" in linea:
            cerrar(bloque)
            bloque = None
    if bloque is not None:
        cerrar(bloque)
    return sistemas


def _parsear_reglas_lineas(texto):
    """Fallback por lineas para es_find_rules.xml."""
    emuladores = {}
    actual = None
    tipo = ""
    re_emu = re.compile(r'<emulator\s+name="([^"]+)"')
    re_entry = re.compile(r"<entry>(.*?)</entry>", re.S)
    for linea in texto.splitlines():
        m = re_emu.search(linea)
        if m:
            actual = m.group(1)
            emuladores.setdefault(actual, [])
            continue
        if "</emulator>" in linea:
            actual = None
            continue
        if actual is None:
            continue
        for e in re_entry.findall(linea):
            e = _revertir_entidades(e.strip(), MAPA_ENTIDADES_GLOBAL)
            if e:
                emuladores[actual].append(e)
    return emuladores


MAPA_ENTIDADES_GLOBAL = {}


# --------------------------------------------------------------------------
# Carga
# --------------------------------------------------------------------------
def cargar():
    global MAPA_ENTIDADES_GLOBAL
    avisos = []

    # --- sistemas ---------------------------------------------------------
    texto_sys = leer_texto(F_SYSTEMS)
    root_sys, avisos_sys = parsear_xml(F_SYSTEMS)
    avisos += avisos_sys
    sistemas = []
    if root_sys is not None:
        MAPA_ENTIDADES_GLOBAL = {}
        for s in root_sys.iter("system"):
            sistemas.append(
                {
                    "name": (s.findtext("name") or "(sin nombre)").strip(),
                    "fullname": (s.findtext("fullname") or "").strip(),
                    "path": (s.findtext("path") or "").strip(),
                    "commands": [
                        {
                            "label": (c.get("label") or "(sin label)").strip(),
                            "texto": (c.text or "").strip(),
                        }
                        for c in s.findall("command")
                    ],
                }
            )
    else:
        avisos.append(
            "es_systems.xml ilegible como XML -> se usa el parser por lineas"
        )
        MAPA_ENTIDADES_GLOBAL = _escapar_entidades_desconocidas(
            _quitar_dtd_interno(texto_sys or "")[0]
        )[1]
        sistemas = _parsear_sistemas_lineas(texto_sys or "")

    # --- reglas de busqueda (emuladores) ----------------------------------
    root_fr, avisos_fr = parsear_xml(F_FIND_RULES)
    avisos += avisos_fr
    emuladores = {}
    if root_fr is not None:
        for e in root_fr.iter("emulator"):
            nombre = (e.get("name") or "").strip()
            if not nombre:
                continue
            emuladores.setdefault(nombre, [])
            # cada <entry> cuelga de un <rule type="...">; se admite tambien
            # <entry> como hijo directo de <emulator> (formato abreviado)
            for hijo in e:
                if hijo.tag == "rule":
                    tipo = hijo.get("type") or ""
                    for ent in hijo.findall("entry"):
                        v = (ent.text or "").strip()
                        if v:
                            emuladores[nombre].append({"valor": v, "rule": tipo})
                elif hijo.tag == "entry":
                    v = (hijo.text or "").strip()
                    if v:
                        emuladores[nombre].append({"valor": v, "rule": ""})
    else:
        avisos.append(
            "es_find_rules.xml ilegible como XML -> se usa el parser por lineas"
        )
        MAPA_ENTIDADES_GLOBAL = _escapar_entidades_desconocidas(
            _quitar_dtd_interno(leer_texto(F_FIND_RULES) or "")[0]
        )[1]
        plano = _parsear_reglas_lineas(leer_texto(F_FIND_RULES) or "")
        emuladores = {k: [{"valor": v, "rule": "?"} for v in vs] for k, vs in plano.items()}

    # --- listas -----------------------------------------------------------
    apps = leer_lista(F_APPS)
    cores_port = [norm_core(c) for c in leer_lista(F_CORES_PORT)]
    cores_sis = [norm_core(c) for c in leer_lista(F_CORES_SISTEMA)]
    roms = leer_lista(F_ROMS)
    for nombre, path in (
        ("es_systems.xml", F_SYSTEMS),
        ("es_find_rules.xml", F_FIND_RULES),
        ("apps.txt", F_APPS),
        ("cores-portables.txt", F_CORES_PORT),
        ("cores-sistema.txt", F_CORES_SISTEMA),
        ("roms.txt", F_ROMS),
    ):
        if not os.path.isfile(path):
            avisos.append("FALTA el fichero de entrada: %s (%s)" % (nombre, path))

    return {
        "sistemas": sistemas,
        "emuladores": emuladores,
        "apps": apps,
        "cores_port": cores_port,
        "cores_sis": cores_sis,
        "roms": roms,
        "avisos": avisos,
    }


# --------------------------------------------------------------------------
# Analisis
# --------------------------------------------------------------------------
def carpeta_de_entry(valor):
    """'./Apps/Ymir/lanzar.sh' -> 'Ymir'   './Apps/BasiliskII*.AppImage' -> 'BasiliskII'
    '~/.local/bin/x' -> None (no es ruta ./Apps)."""
    v = valor.strip().split("|")[0].strip()
    m = RE_APPS.match(v.lstrip("./") if v.startswith("./") else v)
    if m:
        resto = m.group(1)
        # quita el fichero final; si hay glob en el primer componente, cortarlo
        partes = resto.split("/")
        carpeta = partes[0]
        carpeta = re.split(r"[*?\[]", carpeta)[0]
        return carpeta or None
    return None


def analizar(datos, usar_which=False):
    r = {}
    sistemas = datos["sistemas"]
    emuladores = datos["emuladores"]
    apps = datos["apps"]
    apps_set = set(apps)
    apps_ci = {a.lower(): a for a in apps}

    n_comandos = sum(len(s["commands"]) for s in sistemas)

    # -- 1. comandos muertos ------------------------------------------------
    muertos = []
    varset = set()
    n_comandos_afectados = 0
    for s in sistemas:
        for c in s["commands"]:
            usados = RE_EMULADOR.findall(c["texto"])
            varset.update(usados)
            faltan = [v for v in usados if v not in emuladores]
            if faltan:
                n_comandos_afectados += 1
                for v in faltan:
                    muertos.append(
                        {
                            "sistema": s["name"],
                            "label": c["label"],
                            "variable": "%%EMULATOR_%s%%" % v,
                            "comando": c["texto"],
                        }
                    )
    r["comandos_muertos"] = muertos
    r["n_comandos_afectados"] = n_comandos_afectados
    r["emuladores_sin_entradas"] = sorted(
        k for k, v in emuladores.items() if not v
    )

    # -- 2. rutas que no existen -------------------------------------------
    rutas_ok, rutas_missing, nombres_commandv, otras = [], [], [], []
    nombres_flatpak = []
    vistas = set()
    for nombre in sorted(emuladores):
        for it in emuladores[nombre]:
            val = it["valor"].strip()
            if not val:
                continue
            carpeta = carpeta_de_entry(val)
            if carpeta is not None:
                real = None
                if RAIZ_DECKSTATION:
                    real = os.path.isdir(os.path.join(RAIZ_DECKSTATION, "Apps", carpeta))
                clave = (nombre, carpeta)
                if clave in vistas:
                    continue
                vistas.add(clave)
                item = {"emulador": nombre, "entry": val, "carpeta": carpeta}
                if real is True:
                    item["disco"] = "existe"
                elif real is False:
                    item["disco"] = "NO existe"
                if carpeta in apps_set:
                    rutas_ok.append(item)
                else:
                    if carpeta.lower() in apps_ci:
                        item["aviso"] = "solo cambian las mayusculas (case): en apps.txt esta '%s'" % apps_ci[
                            carpeta.lower()
                        ]
                    rutas_missing.append(item)
            elif "/" not in val:
                if "." in val:
                    # AppID de flatpak o nombre .desktop: `command -v` no sirve
                    if val not in nombres_flatpak:
                        nombres_flatpak.append(val)
                elif val not in nombres_commandv:
                    nombres_commandv.append(val)
            else:
                if val not in otras:
                    otras.append(val)
    r["rutas_ok"] = rutas_ok
    r["rutas_missing"] = rutas_missing
    r["nombres_commandv"] = nombres_commandv
    r["nombres_flatpak"] = nombres_flatpak
    r["otras_rutas"] = otras
    r["which"] = {}
    if usar_which:
        for nom in nombres_commandv:
            r["which"][nom] = shutil.which(nom) or "NO ENCONTRADO"

    # -- 3. cores que no existen -------------------------------------------
    cores_disponibles = set(datos["cores_port"]) | set(datos["cores_sis"])
    cores_ci = {c.lower(): c for c in cores_disponibles}
    core_faltan, core_ok_set, refs_totales = [], set(), set()
    for s in sistemas:
        for c in s["commands"]:
            for familia, fichero in RE_CORE_REF.findall(c["texto"]):
                refs_totales.add((familia, fichero))
                n = norm_core(fichero)
                if n in cores_disponibles:
                    core_ok_set.add(n)
                else:
                    item = {
                        "sistema": s["name"],
                        "label": c["label"],
                        "core": fichero,
                        "familia": familia,
                    }
                    if n.lower() in cores_ci:
                        item["aviso"] = "solo cambian las mayusculas (case): en los listados esta '%s'" % cores_ci[
                            n.lower()
                        ]
                    core_faltan.append(item)
    # dedup por (sistema,label,core) conservando sistemas repetidos
    vistos = set()
    unicos = []
    for it in core_faltan:
        k = (it["sistema"], it["label"], it["core"])
        if k in vistos:
            continue
        vistos.add(k)
        unicos.append(it)
    r["cores_faltan"] = unicos
    r["cores_ok"] = sorted(core_ok_set)
    r["cores_referenciados"] = len(refs_totales)

    # -- 4. apps sin entrada ------------------------------------------------
    entradas_set = {it["valor"] for v in emuladores.values() for it in v}
    sin_entrada = []
    for app in apps:
        citado = any(
            v == app or v.startswith("./Apps/%s/" % app) or v.startswith("./Apps/%s*" % app)
            for v in entradas_set
        )
        if not citado:
            sin_entrada.append(app)
    r["apps_sin_entrada"] = sin_entrada

    # -- 5. sistemas sin comando -------------------------------------------
    r["sistemas_sin_comando"] = [
        {"sistema": s["name"], "path": s["path"]} for s in sistemas if not s["commands"]
    ]

    # -- 6. emuladores sin uso ---------------------------------------------
    r["emuladores_sin_uso"] = sorted(set(emuladores) - varset)
    r["emuladores_usados"] = sorted(varset)

    # -- 7. resumen ---------------------------------------------------------
    r["resumen"] = {
        "sistemas": len(sistemas),
        "comandos": n_comandos,
        "emuladores_definidos": len(emuladores),
        "emuladores_usados": len(varset),
        "comandos_muertos": n_comandos_afectados,
        "variables_emulador_sin_definir": sorted(varset - set(emuladores)),
        "rutas_apps_ok": len(rutas_ok),
        "rutas_apps_missing": len(rutas_missing),
        "cores_referenciados": len(refs_totales),
        "cores_faltan": len({(i["sistema"], i["label"], i["core"]) for i in unicos}),
        "cores_ok": len(core_ok_set),
        "apps_sin_entrada": len(sin_entrada),
        "sistemas_sin_comando": len(r["sistemas_sin_comando"]),
        "emuladores_sin_uso": len(r["emuladores_sin_uso"]),
        "nombres_para_command_v": len(nombres_commandv),
        "nombres_flatpak": len(nombres_flatpak),
    }

    r["entradas"] = {
        "es_systems": F_SYSTEMS,
        "es_find_rules": F_FIND_RULES,
        "apps": F_APPS,
        "cores_portables": F_CORES_PORT,
        "cores_sistema": F_CORES_SISTEMA,
        "roms": F_ROMS,
        "raiz_deckstation": RAIZ_DECKSTATION or None,
    }
    r["avisos"] = datos["avisos"]
    return r


# --------------------------------------------------------------------------
# Informe en texto
# --------------------------------------------------------------------------
def regla(char="="):
    return char * 78


def plural(n, singular, plural_forma=None):
    return "%d %s" % (n, singular if n == 1 else (plural_forma or singular + "s"))


def imprime(r, completo=False):
    lim = None if completo else 10
    out = []

    def p(s=""):
        out.append(s)

    res = r["resumen"]
    p(regla("#"))
    p("#  AUDITORIA DE CONFIGURACION DE ES-DE (solo lectura)")
    p(regla("#"))
    p("Ficheros analizados:")
    for k, v in r["entradas"].items():
        p("  %-18s %s" % (k, v))
    if r["avisos"]:
        p()
        p("Avisos del parser:")
        for a in r["avisos"]:
            p("  - %s" % a)
    p()

    def bloque(num, titulo, items, formato, nota=None, cabecera=None):
        p(regla())
        p("%d. %s  (%d)" % (num, titulo, len(items)))
        p(regla())
        if nota:
            p(nota)
        if cabecera:
            p(cabecera)
        if not items:
            p("   (ninguno)  [OK]")
            p()
            return
        mostrado = items if lim is None else items[:lim]
        for it in mostrado:
            p(formato(it))
        if lim is not None and len(items) > lim:
            p("   ... y %d mas (usa --all para verlas todas)" % (len(items) - lim))
        p()

    # 1
    bloque(
        1,
        "COMANDOS MUERTOS  (%%EMULATOR_X%% sin definir en es_find_rules.xml)",
        r["comandos_muertos"],
        lambda it: "   [%-14s] %-42s -> falta %s" % (it["sistema"], it["label"][:42], it["variable"]),
        nota="   %s afectados de un total de %d comandos."
        % (plural(r["n_comandos_afectados"], "comando"), res["comandos"]),
        cabecera="   sistema            label                                      variable ausente",
    )
    if r["emuladores_sin_entradas"]:
        p("   OJO: emuladores DEFINIDOS pero sin ninguna <entry>: %s"
          % ", ".join(r["emuladores_sin_entradas"]))
        p()

    # 2
    p(regla())
    p("2. RUTAS QUE NO EXISTEN  (entradas ./Apps/... sin carpeta en apps.txt)")
    p(regla())
    p("   %d rutas OK / %d rutas rotas de %d entradas './Apps/'"
      % (res["rutas_apps_ok"], res["rutas_apps_missing"], res["rutas_apps_ok"] + res["rutas_apps_missing"]))
    p()
    if r["rutas_ok"]:
        p("   [OK] rutas './Apps/...' cuya carpeta SI esta en apps.txt (%d rutas, %d carpetas):"
          % (len(r["rutas_ok"]), len({i["carpeta"] for i in r["rutas_ok"]})))
        carpetas_ok = []
        for i in r["rutas_ok"]:
            if i["carpeta"] not in carpetas_ok:
                carpetas_ok.append(i["carpeta"])
        for linea in _columnas(["./Apps/%s" % c for c in carpetas_ok], 4, 22):
            p("      %s" % linea)
    p()
    if r["rutas_missing"]:
        p("   ROAS a revisar:")
        p("   %-16s %-34s %s" % ("carpeta", "emulador", "entry"))
        for it in (r["rutas_missing"] if lim is None else r["rutas_missing"][:lim]):
            p("   [FALTA]    %-16s %-34s %s" % (it["carpeta"][:16], it["emulador"][:34], it["entry"]))
            if it.get("aviso"):
                p("               ^ %s" % it["aviso"])
        if lim is not None and len(r["rutas_missing"]) > lim:
            p("   ... y %d mas (usa --all)" % (len(r["rutas_missing"]) - lim))
    else:
        p("   (ninguna ruta ./Apps rota)")
    p()

    p("   >> A VERIFICAR EN EL DISPOSITIVO CON `command -v` (%d nombres sueltos, no son rutas):"
      % len(r["nombres_commandv"]))
    shown = r["nombres_commandv"] if lim is None else r["nombres_commandv"][:lim]
    for linea in _columnas(shown, 4, 26):
        p("      %s" % linea)
    if lim is not None and len(r["nombres_commandv"]) > lim:
        p("      ... y %d mas (usa --all)" % (len(r["nombres_commandv"]) - lim))
    if r["which"]:
        p("      resultado de shutil.which() en ESTA maquina:")
        for nom, resu in list(r["which"].items())[:lim or len(r["which"])]:
            p("         %-34s %s" % (nom, resu))
    p("      (los %d que llevan punto, p.ej. 'dev.ares.ares', NO son comandos: son AppID de"
      % len(r["nombres_flatpak"]))
    p("       flatpak. Comprobar con `flatpak list --app`, no con `command -v`:")
    for linea in _columnas(r["nombres_flatpak"][:lim], 3, 25):
        p("      %s" % linea)
    p()
    p("   (informativo) %d otras entradas con ruta (~/..., /usr/..., flatpak). No se pueden"
      % len(r["otras_rutas"]))
    p("   comprobar contra apps.txt. Primeras: %s"
      % ", ".join(r["otras_rutas"][:4]))
    p()

    # 3
    p(regla())
    p("3. CORES QUE NO EXISTEN  (%%CORE_RETROARCH%%/X.so no esta en ningun listado)")
    p(regla())
    p("   %d cores referenciados / %d de ellos OK / %s rotas"
      % (res["cores_referenciados"], len(r["cores_ok"]), plural(len(r["cores_faltan"]), "referencia")))
    p("   Nota: los listados estan normalizados sin extension (portables viene")
    p("   sin '.so', sistema con '.so'); se comparan por nombre base.")
    p("   %-14s %-40s %s" % ("sistema", "label", "core"))
    if not r["cores_faltan"]:
        p("   (ninguno)  [OK]")
    for it in (r["cores_faltan"] if lim is None else r["cores_faltan"][:lim]):
        p("   [FALTA]    %-14s %-40s %s" % (it["sistema"][:14], it["label"][:40], it["core"]))
        if it.get("aviso"):
            p("               ^ %s" % it["aviso"])
    if lim is not None and len(r["cores_faltan"]) > lim:
        p("   ... y %d mas (usa --all)" % (len(r["cores_faltan"]) - lim))
    p()

    # 4
    bloque(
        4,
        "APPS SIN ENTRADA  (carpetas de apps.txt que no aparecen en es_find_rules.xml)",
        r["apps_sin_entrada"],
        lambda it: "   [SUELTO]   ./Apps/%s" % it,
        nota="   candidatas a anadir como <emulator> nuevo.",
    )

    # 5
    bloque(
        5,
        "SISTEMAS SIN COMANDO  (bloque <system> sin ningun <command>)",
        r["sistemas_sin_comando"],
        lambda it: "   [VACIO]    %-16s %s" % (it["sistema"], it["path"]),
    )

    # 6
    bloque(
        6,
        "EMULADORES SIN USO  (definidos en es_find_rules.xml, no usados en es_systems.xml)",
        r["emuladores_sin_uso"],
        lambda it: "   [HUERFANO] %-16s entradas: %s"
        % (
            it,
            ", ".join(e["valor"] for e in r["_emu_entries"].get(it, [])) or "(ninguna)",
        ),
        nota="   si se borraron de es_systems.xml, se pueden quitar de las reglas.",
    )

    # 7
    p(regla("#"))
    p("7. RESUMEN")
    p(regla("#"))
    p("   Sistemas definidos .......................... %d" % res["sistemas"])
    p("   Comandos <command> totales ................... %d" % res["comandos"])
    p("   Emuladores definidos en es_find_rules.xml ... %d" % res["emuladores_definidos"])
    p("   Emuladores usados por algún comando .......... %d" % res["emuladores_usados"])
    p("   COMANDOS MUERTOS (emulador no definido) ...... %d  %s"
      % (res["comandos_muertos"],
         ("<-- " + ", ".join(res["variables_emulador_sin_definir"])) if res["variables_emulador_sin_definir"] else "(ninguno)"))
    p("   Rutas ./Apps/ que no existen ................. %d" % res["rutas_apps_missing"])
    p("   Nombres sueltos para `command -v` ........... %d  (+%d AppID de flatpak)"
      % (res["nombres_para_command_v"], res["nombres_flatpak"]))
    p("   CORES QUE FALTAN ............................ %d" % res["cores_faltan"])
    p("   Cores referenciados y disponibles ........... %d / %d" % (res["cores_ok"], res["cores_referenciados"]))
    p("   Apps instaladas sin entrada en find_rules ... %d  %s"
      % (res["apps_sin_entrada"], (", ".join(r["apps_sin_entrada"][:6]) + " ...") if r["apps_sin_entrada"] else "(ninguna)"))
    p("   Sistemas sin <command> ...................... %d" % res["sistemas_sin_comando"])
    p("   Emuladores definidos sin usar ............... %d" % res["emuladores_sin_uso"])
    p(regla("#"))
    return "\n".join(out)


def _columnas(items, ncols, ancho=30):
    lineas = []
    for i in range(0, len(items), ncols):
        trozo = items[i:i + ncols]
        lineas.append("".join(x.ljust(ancho)[:ancho] for x in trozo).rstrip())
    return lineas


# --------------------------------------------------------------------------
# main
# --------------------------------------------------------------------------
def main():
    completo = "--all" in sys.argv[1:] or "-a" in sys.argv[1:]
    con_json = "--json" in sys.argv[1:]
    usar_which = "--which" in sys.argv[1:]

    datos = cargar()
    r = analizar(datos, usar_which=usar_which)
    r["_emu_entries"] = datos["emuladores"]

    print(imprime(r, completo=completo))

    if con_json:
        destino = os.path.abspath(F_JSON)
        if not destino.startswith(os.path.abspath(RAIZ_PERMITIDA) + os.sep):
            print(
                "\nERROR: ESDE_JSON_OUT (%s) esta fuera de %s; no se escribe nada."
                % (destino, RAIZ_PERMITIDA)
            )
            return 2
        limpio = {k: v for k, v in r.items() if not k.startswith("_")}
        limpio["generado"] = __import__("datetime").datetime.now().isoformat(timespec="seconds")
        os.makedirs(os.path.dirname(destino), exist_ok=True)
        with open(destino, "w", encoding="utf-8") as fh:
            json.dump(limpio, fh, indent=2, ensure_ascii=False)
        print("\nJSON escrito en: %s" % destino)
    return 0


if __name__ == "__main__":
    sys.exit(main())
