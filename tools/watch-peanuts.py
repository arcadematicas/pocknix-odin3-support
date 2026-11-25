#!/usr/bin/env python3
"""Vigila peanuts-native y nxnative y avisa de cambios por Telegram.

Solo stdlib. Sin token de GitHub: usa la API publica con cabecera User-Agent.

Qué vigila
  - igawa6/peanuts-native: ultima release, PR #130 (AppImage para Linux aarch64) con su
    estado y ultimos comentarios, y cualquier issue/PR nuevo que mencione "linux".
  - seedds/nxnative (upstream): issue #3250 (port del lanzador a Linux) y lo mismo.

Instalacion (en el PC de sobremesa; corre como timer de sistema)
  1. Copiar a ~/peanuts-watch/watch-peanuts.py y dar permisos de ejecucion.
  2. ~/peanuts-watch/telegram.env con TG_TOKEN=... y TG_CHAT=... (chmod 600; NO va al repo).
  3. /etc/systemd/system/vigilar-peanuts.service  (Type=oneshot,
     ExecStart=/home/fransis/peanuts-watch/watch-peanuts.py --notify)
     /etc/systemd/system/vigilar-peanuts.timer    (OnCalendar=*-*-* 09:00:00, Persistent=true,
     WantedBy=timers.target) -> systemctl enable --now vigilar-peanuts.timer
  Estado y snapshots en ~/peanuts-watch/ (30 snapshots como maximo).

Uso
  watch-peanuts.py --dry-run   # imprime, no envia ni guarda
  watch-peanuts.py --notify    # envia solo si hay cambios (--force para forzar el envio)
"""

import argparse
import datetime
import json
import os
import pathlib
import sys
import time
import urllib.error
import urllib.parse
import urllib.request

API = "https://api.github.com"
UA = "peanuts-watch/1.0 (stdlib; vigilancia personal)"
SECCIONES = {
    "release": "la ultima release de peanuts-native",
    "pr130": "el PR #130 de peanuts-native",
    "pr130_comments": "los comentarios del PR #130",
    "peanuts_search": "la busqueda linux en peanuts-native",
    "issue3250": "el issue #3250 de nxnative",
    "issue3250_comments": "los comentarios del issue #3250",
    "nx_search": "la busqueda linux en nxnative",
}
URL_PR = "https://github.com/igawa6/peanuts-native/pull/130"
URL_ISSUE = "https://github.com/seedds/nxnative/issues/3250"


def fecha(valor):
    if not valor:
        return "fecha desconocida"
    try:
        dt = datetime.datetime.fromisoformat(str(valor).replace("Z", "+00:00"))
        return dt.strftime("%Y-%m-%d %H:%M UTC")
    except (ValueError, TypeError):
        return str(valor)


def estado(valor):
    return "abierto" if valor == "open" else ("cerrado" if valor == "closed" else str(valor))


def recortar(texto, limite=55):
    texto = " ".join(str(texto or "").split())
    return texto if len(texto) <= limite else texto[: limite - 1] + "."


def urls_endpoints():
    def busqueda(repo):
        return API + "/search/issues?" + urllib.parse.urlencode(
            {
                "q": "repo:" + repo + " linux",
                "sort": "created",
                "order": "desc",
                "per_page": 10,
            }
        )

    return [
        ("release", API + "/repos/igawa6/peanuts-native/releases/latest"),
        ("pr130", API + "/repos/igawa6/peanuts-native/pulls/130"),
        (
            "pr130_comments",
            API + "/repos/igawa6/peanuts-native/issues/130/comments?per_page=100",
        ),
        ("peanuts_search", busqueda("igawa6/peanuts-native")),
        ("issue3250", API + "/repos/seedds/nxnative/issues/3250"),
        (
            "issue3250_comments",
            API + "/repos/seedds/nxnative/issues/3250/comments?per_page=100",
        ),
        ("nx_search", busqueda("seedds/nxnative")),
    ]


def espera_reintento(respuesta):
    cabeceras = respuesta.headers if respuesta else {}
    segundos = 3
    retry_after = cabeceras.get("Retry-After")
    if retry_after and retry_after.isdigit():
        segundos = max(2, min(int(retry_after), 20))
    else:
        reset = cabeceras.get("X-RateLimit-Reset")
        if reset and reset.isdigit():
            segundos = max(2, min(int(reset) - int(time.time()) + 1, 20))
    return segundos


def fetch_json(url, etiqueta):
    """Devuelve (datos, error). Nunca lanza: registra el fallo."""
    es_busqueda = "/search/issues" in url
    for intento in (0, 1):
        peticion = urllib.request.Request(
            url, headers={"User-Agent": UA, "Accept": "application/vnd.github+json"}
        )
        try:
            with urllib.request.urlopen(peticion, timeout=20) as respuesta:
                return json.load(respuesta), None
        except urllib.error.HTTPError as exc:
            if es_busqueda and intento == 0 and exc.code in (403, 429):
                time.sleep(espera_reintento(exc))
                continue
            return None, "{} (HTTP {})".format(etiqueta, exc.code)
        except Exception as exc:
            return None, "{} ({})".format(etiqueta, type(exc).__name__)
    return None, "{} (sin respuesta tras reintento)".format(etiqueta)


def datos_release(datos):
    if not isinstance(datos, dict):
        return None
    assets = []
    for asset in datos.get("assets") or []:
        assets.append(
            {
                "name": asset.get("name") or "asset",
                "mb": round((asset.get("size") or 0) / 1048576.0, 1),
            }
        )
    return {
        "tag": datos.get("tag_name") or "",
        "published": datos.get("published_at"),
        "url": datos.get("html_url") or "",
        "assets": assets,
    }


def datos_pr(datos):
    if not isinstance(datos, dict):
        return None
    return {
        "state": datos.get("state"),
        "merged": bool(datos.get("merged")),
        "updated": datos.get("updated_at"),
        "comments": datos.get("comments") or 0,
        "url": datos.get("html_url") or URL_PR,
    }


def datos_comentarios(datos):
    if not isinstance(datos, list):
        return None
    return [
        {
            "id": comm.get("id"),
            "author": (comm.get("user") or {}).get("login") or "desconocido",
            "date": comm.get("created_at"),
            "url": comm.get("html_url") or "",
        }
        for comm in datos[-3:]
    ]


def datos_busqueda(datos):
    if not isinstance(datos, dict):
        return None
    items = []
    for item in (datos.get("items") or [])[:10]:
        items.append(
            {
                "number": item.get("number"),
                "title": item.get("title") or "",
                "state": item.get("state"),
                "date": item.get("created_at"),
                "url": item.get("html_url") or "",
            }
        )
    return {"total": datos.get("total_count") or 0, "items": items}


def datos_issue(datos):
    if not isinstance(datos, dict):
        return None
    return {
        "state": datos.get("state"),
        "comments": datos.get("comments") or 0,
        "updated": datos.get("updated_at"),
        "url": datos.get("html_url") or URL_ISSUE,
    }


CONVERTIDORES = {
    "release": datos_release,
    "pr130": datos_pr,
    "pr130_comments": datos_comentarios,
    "peanuts_search": datos_busqueda,
    "issue3250": datos_issue,
    "issue3250_comments": datos_comentarios,
    "nx_search": datos_busqueda,
}


def recoger_estado(anterior, errores):
    actual = dict(anterior)
    for indice, (clave, url) in enumerate(urls_endpoints()):
        if indice:
            time.sleep(1)
        datos, error = fetch_json(url, SECCIONES[clave])
        if error:
            errores.append(error)
            continue
        try:
            convertido = CONVERTIDORES[clave](datos)
        except (AttributeError, KeyError, TypeError):
            convertido = None
        if convertido is None:
            errores.append("{} (respuesta inesperada)".format(SECCIONES[clave]))
            continue
        actual[clave] = convertido
    return actual


def comentarios_nuevos(antes, despues):
    vistos = {comm.get("id") for comm in (antes or [])}
    return [comm for comm in (despues or []) if comm.get("id") not in vistos]


def items_nuevos(antes, despues):
    vistos = {item.get("number") for item in (antes or {}).get("items", [])}
    return [
        item
        for item in (despues or {}).get("items", [])
        if item.get("number") not in vistos
    ]


def linea_items(items):
    return " | ".join(
        "#{} {} ({}) {}".format(
            item.get("number"),
            recortar(item.get("title")),
            estado(item.get("state")),
            item.get("url"),
        )
        for item in items[:3]
    )


def linea_comentario(comm):
    return "@{} el {} {}".format(
        comm.get("author"), fecha(comm.get("date")), comm.get("url")
    )


def resumen(estado_actual, errores):
    lineas = []
    lib = estado_actual.get("release")
    if lib:
        assets = "; ".join(
            "{}: {} MB".format(a.get("name"), a.get("mb")) for a in lib.get("assets", [])
        )
        lineas.append(
            "Release peanuts-native: {} ({}) - {} {}".format(
                lib.get("tag"), fecha(lib.get("published")), assets or "sin assets", lib.get("url")
            )
        )
    else:
        lineas.append("Release peanuts-native: no disponible")

    pr = estado_actual.get("pr130")
    if pr:
        lineas.append(
            "PR #130: {}, {}, actualizado {} {}".format(
                estado(pr.get("state")),
                "MERGEADO" if pr.get("merged") else "sin fusionar",
                fecha(pr.get("updated")),
                pr.get("url"),
            )
        )
    comms = estado_actual.get("pr130_comments")
    if comms:
        lineas.append("Ultimo comentario PR #130: " + linea_comentario(comms[-1]))

    busq = estado_actual.get("peanuts_search")
    if busq:
        lineas.append(
            "Linux en peanuts-native: {} resultados; recientes: {}".format(
                busq.get("total"), linea_items(busq.get("items", [])) or "ninguno"
            )
        )

    issue = estado_actual.get("issue3250")
    if issue:
        lineas.append(
            "Issue #3250 (nxnative): {}, {} comentarios, actualizado {} {}".format(
                estado(issue.get("state")),
                issue.get("comments"),
                fecha(issue.get("updated")),
                issue.get("url"),
            )
        )
    icomms = estado_actual.get("issue3250_comments")
    if icomms:
        lineas.append("Ultimo comentario #3250: " + linea_comentario(icomms[-1]))

    busq2 = estado_actual.get("nx_search")
    if busq2:
        lineas.append(
            "Linux en nxnative: {} resultados; recientes: {}".format(
                busq2.get("total"), linea_items(busq2.get("items", [])) or "ninguno"
            )
        )
    if errores:
        lineas.append("No se pudo consultar: " + "; ".join(errores))
    return lineas


def cambios_detectados(anterior, actual, errores):
    cambios = []
    hubo_antes = bool(anterior)

    def recuperado(clave, texto):
        if hubo_antes and clave not in anterior and clave in actual:
            cambios.append("Datos disponibles ahora - " + texto)

    rel_antes, rel_ahora = anterior.get("release"), actual.get("release")
    if rel_antes and rel_ahora and rel_antes.get("tag") != rel_ahora.get("tag"):
        cambios.append(
            "Release nueva: {} ({}) {}".format(
                rel_ahora.get("tag"), fecha(rel_ahora.get("published")), rel_ahora.get("url")
            )
        )
    recuperado("release", "release " + str((rel_ahora or {}).get("tag", "")))

    pr_antes, pr_ahora = anterior.get("pr130"), actual.get("pr130")
    if pr_antes and pr_ahora:
        if pr_ahora.get("merged") and not pr_antes.get("merged"):
            cambios.append("PR #130 MERGEADO (fusionado) " + pr_ahora.get("url"))
        elif pr_ahora.get("state") != pr_antes.get("state"):
            cambios.append(
                "PR #130 cambio a {} {}".format(estado(pr_ahora.get("state")), pr_ahora.get("url"))
            )
    recuperado("pr130", "PR #130 " + str((pr_ahora or {}).get("state", "")))

    nuevos = comentarios_nuevos(
        anterior.get("pr130_comments"), actual.get("pr130_comments")
    )
    for comm in nuevos:
        cambios.append("Nuevo comentario en PR #130: " + linea_comentario(comm))
    if (
        pr_antes
        and pr_ahora
        and pr_ahora.get("comments") != pr_antes.get("comments")
        and not nuevos
    ):
        cambios.append(
            "PR #130: ahora {} comentarios {}".format(pr_ahora.get("comments"), pr_ahora.get("url"))
        )

    for clave, nombre in (("peanuts_search", "peanuts-native"), ("nx_search", "nxnative")):
        antes, ahora = anterior.get(clave), actual.get(clave)
        for item in items_nuevos(antes, ahora):
            cambios.append(
                'Nuevo con "linux" en {}: #{} {} ({}, {}) {}'.format(
                    nombre,
                    item.get("number"),
                    recortar(item.get("title")),
                    estado(item.get("state")),
                    fecha(item.get("date")),
                    item.get("url"),
                )
            )
        recuperado(clave, "busqueda linux en " + nombre)

    iss_antes, iss_ahora = anterior.get("issue3250"), actual.get("issue3250")
    if iss_antes and iss_ahora:
        if iss_antes.get("state") != iss_ahora.get("state"):
            cambios.append(
                "Issue #3250 (nxnative) cambio a {} {}".format(
                    estado(iss_ahora.get("state")), iss_ahora.get("url")
                )
            )
        elif iss_ahora.get("comments") != iss_antes.get("comments"):
            cambios.append(
                "Issue #3250: ahora {} comentarios {}".format(
                    iss_ahora.get("comments"), iss_ahora.get("url")
                )
            )
    recuperado("issue3250", "issue #3250 " + str((iss_ahora or {}).get("state", "")))

    nuevos_issue = comentarios_nuevos(
        anterior.get("issue3250_comments"), actual.get("issue3250_comments")
    )
    for comm in nuevos_issue:
        cambios.append("Nuevo comentario en #3250: " + linea_comentario(comm))

    if errores:
        cambios.append("No se pudo consultar: " + "; ".join(errores))
    return cambios


def cargar_credenciales(carpeta):
    token = os.environ.get("TG_TOKEN", "").strip()
    chat = os.environ.get("TG_CHAT", "").strip()
    fichero = carpeta / "telegram.env"
    if fichero.exists():
        if fichero.stat().st_mode & 0o077:
            print("Aviso: telegram.env deberia tener permisos 600", file=sys.stderr)
        for linea in fichero.read_text(encoding="utf-8").splitlines():
            linea = linea.strip()
            if not linea or linea.startswith("#") or "=" not in linea:
                continue
            clave, valor = linea.split("=", 1)
            clave, valor = clave.strip(), valor.strip().strip('"').strip("'")
            if clave == "TG_TOKEN" and not token:
                token = valor
            elif clave == "TG_CHAT" and not chat:
                chat = valor
    return token, chat


def enviar_telegram(token, chat, texto):
    chat_id = int(chat) if chat.isdigit() else chat
    cuerpo = json.dumps(
        {"chat_id": chat_id, "text": texto, "disable_web_page_preview": True}
    ).encode("utf-8")
    peticion = urllib.request.Request(
        "https://api.telegram.org/bot" + token + "/sendMessage",
        data=cuerpo,
        headers={"Content-Type": "application/json", "User-Agent": UA},
    )
    try:
        with urllib.request.urlopen(peticion, timeout=20) as respuesta:
            resultado = json.load(respuesta)
        ok = bool(resultado.get("ok"))
        print("Telegram: ok:{}".format("true" if ok else "false"))
        if not ok:
            print("Telegram: " + str(resultado.get("description", "respuesta inesperada")))
        return ok
    except urllib.error.HTTPError as exc:
        print("Telegram: ok:false (HTTP {})".format(exc.code))
    except Exception as exc:
        print("Telegram: ok:false ({})".format(type(exc).__name__))
    return False


def guardar(carpeta, estado_actual, texto):
    carpeta.mkdir(parents=True, exist_ok=True)
    ruta_estado = carpeta / "state.json"
    temporal = carpeta / "state.json.tmp"
    temporal.write_text(
        json.dumps(estado_actual, ensure_ascii=False, indent=2) + "\n", encoding="utf-8"
    )
    os.replace(temporal, ruta_estado)

    directorio_snaps = carpeta / "snapshots"
    directorio_snaps.mkdir(exist_ok=True)
    ahora = datetime.datetime.now()
    ruta_snap = directorio_snaps / ("peanuts-" + ahora.strftime("%Y%m%d") + ".txt")
    ruta_snap.write_text(
        "Snapshot " + ahora.strftime("%Y-%m-%d %H:%M:%S") + "\n" + "\n".join(texto) + "\n",
        encoding="utf-8",
    )
    antiguos = sorted(directorio_snaps.glob("peanuts-*.txt"))
    for fichero in antiguos[:-30]:
        fichero.unlink()


def main():
    parser = argparse.ArgumentParser(description="Vigilancia de peanuts-native y nxnative")
    parser.add_argument("--notify", action="store_true", help="envia avisos a Telegram")
    parser.add_argument("--dry-run", action="store_true", help="no envia ni guarda estado")
    parser.add_argument("--force", action="store_true", help="envia aunque no haya cambios")
    args = parser.parse_args()

    carpeta = pathlib.Path(
        os.environ.get("PEANUTS_WATCH_DIR") or (pathlib.Path.home() / "peanuts-watch")
    ).expanduser()
    ruta_estado = carpeta / "state.json"
    anterior = {}
    if ruta_estado.exists():
        try:
            contenido = json.loads(ruta_estado.read_text(encoding="utf-8"))
            if isinstance(contenido, dict):
                anterior = contenido
        except (OSError, ValueError) as exc:
            print("Aviso: state.json no legible ({}); se empieza de cero".format(type(exc).__name__), file=sys.stderr)

    token, chat = cargar_credenciales(carpeta)
    if args.notify and not args.dry_run and (not token or not chat):
        print(
            "Error de configuracion: faltan TG_TOKEN o TG_CHAT (entorno o "
            + str(carpeta / "telegram.env")
            + ")",
            file=sys.stderr,
        )
        return 2

    errores = []
    actual = recoger_estado(anterior, errores)
    primera = not anterior

    if primera:
        lineas = ["Vigilancia activada: peanuts-native / nxnative"] + resumen(actual, errores)
    else:
        cambios = cambios_detectados(anterior, actual, errores)
        if cambios:
            lineas = ["Cambios detectados:"] + ["- " + cambio for cambio in cambios]
        elif args.force:
            lineas = ["Sin cambios desde la ultima revision (envio forzado)."]
            if errores:
                lineas.append("No se pudo consultar: " + "; ".join(errores))
        else:
            lineas = ["Sin cambios desde la ultima revision."]
            if errores:
                lineas.append("No se pudo consultar: " + "; ".join(errores))

    if args.dry_run:
        print("MODO DRY-RUN: no se envia nada y no se guarda estado")
    print("\n".join(lineas))

    if args.dry_run:
        print("Fin del dry-run.")
        return 0

    try:
        guardar(carpeta, actual, lineas)
    except OSError as exc:
        print("Error de configuracion: no se pudo guardar el estado ({})".format(exc), file=sys.stderr)
        return 2
    print("Estado guardado en " + str(ruta_estado))

    if not args.notify:
        print("Sin --notify: solo se imprime, no se envia nada.")
        return 0

    if not primera and not cambios and not args.force:
        print("Sin cambios: no se envia nada a Telegram.")
        return 0

    enviar_telegram(token, chat, "\n".join(lineas))
    return 0


if __name__ == "__main__":
    sys.exit(main())
