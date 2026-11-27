#!/usr/bin/env python3
"""Revisa diariamente las entradas de docs/UPSTREAM-TRACKER.md contra GitHub.

Solo stdlib, sin token: API pública con User-Agent, 1 s entre llamadas y hasta
2 reintentos en 403/429 respetando Retry-After. Compara state, número de
comentarios/reseñas y updated_at con ~/.local/share/upstream-tracker/state.json.

No modifica el markdown (la columna "Siguiente acción" es manual). --print-md
imprime las filas listas para pegar. Avisa por Telegram solo si hay cambios.

Uso:
  upstream-tracker.py --dry-run
  upstream-tracker.py --notify
  upstream-tracker.py --notify --force
  upstream-tracker.py --print-md
  upstream-tracker.py --state <dir> --env <ruta> --doc <ruta>
"""

import argparse
import datetime
import email.utils
import json
import pathlib
import re
import sys
import time
import urllib.error
import urllib.request

API = "https://api.github.com"
UA = "upstream-tracker/1.0 (stdlib; registro personal)"
URL_RE = re.compile(
    r"https://github\.com/([A-Za-z0-9_.-]+)/([A-Za-z0-9_.-]+)/(issues|pulls?)/(\d+)"
)
LIMITE_MENSAJE = 4000
_ultima_llamada = 0.0


def espaciado():
    """Garantiza al menos 1 segundo entre llamadas a la API de GitHub."""
    global _ultima_llamada
    if _ultima_llamada:
        restante = 1.0 - (time.monotonic() - _ultima_llamada)
        if restante > 0:
            time.sleep(restante)
    _ultima_llamada = time.monotonic()


def espera_reintento(respuesta):
    cabeceras = respuesta.headers if respuesta else {}
    segundos = 3
    retry_after = cabeceras.get("Retry-After")
    if retry_after:
        if str(retry_after).isdigit():
            segundos = int(retry_after)
        else:
            try:
                hasta = email.utils.parsedate_to_datetime(str(retry_after))
                ahora = datetime.datetime.now(datetime.timezone.utc)
                if hasta.tzinfo is None:
                    hasta = hasta.replace(tzinfo=datetime.timezone.utc)
                segundos = int((hasta - ahora).total_seconds()) + 1
            except (TypeError, ValueError, OverflowError):
                segundos = 3
    else:
        reset = cabeceras.get("X-RateLimit-Reset")
        if reset and str(reset).isdigit():
            segundos = int(reset) - int(time.time()) + 1
    return max(2, min(segundos, 30))


def fetch_json(url, etiqueta):
    """Devuelve (datos, error). Nunca lanza excepciones."""
    for intento in range(3):  # petición inicial + 2 reintentos como máximo
        espaciado()
        peticion = urllib.request.Request(
            url,
            headers={"User-Agent": UA, "Accept": "application/vnd.github+json"},
        )
        try:
            with urllib.request.urlopen(peticion, timeout=20) as respuesta:
                return json.load(respuesta), None
        except urllib.error.HTTPError as exc:
            if exc.code in (403, 429) and intento < 2:
                segundos = espera_reintento(exc)
                print(
                    "GitHub: {} HTTP {}; esperando {} s (reintento {}/2)".format(
                        etiqueta, exc.code, segundos, intento + 1
                    )
                )
                time.sleep(segundos)
                continue
            return None, "{} (HTTP {})".format(etiqueta, exc.code)
        except Exception as exc:
            return None, "{} ({})".format(etiqueta, type(exc).__name__)
    return None, "{} (sin respuesta tras 2 reintentos)".format(etiqueta)


def leer_documento(ruta):
    """Extrae las filas de la tabla markdown; devuelve una lista de entradas."""
    try:
        texto = ruta.read_text(encoding="utf-8")
    except OSError as exc:
        print("Error: no se pudo leer {} ({})".format(ruta, exc), file=sys.stderr)
        return None

    entradas = []
    for linea in texto.splitlines():
        linea = linea.strip()
        if not linea.startswith("|"):
            continue
        celdas = [celda.strip() for celda in linea.strip("|").split("|")]
        if len(celdas) < 7 or celdas[0] == "Fecha":
            continue
        if all(set(celda) <= set("-: ") for celda in celdas):
            continue
        coincidencia = URL_RE.search(celdas[2])
        if not coincidencia:
            continue
        propietario, repo, tipo_url, numero = coincidencia.groups()
        entradas.append(
            {
                "fecha": celdas[0],
                "proyecto": celdas[1],
                "url": coincidencia.group(0),
                "tipo": celdas[3],
                "estado_md": celdas[4],
                "revision_md": celdas[5],
                "accion": celdas[6],
                "propietario": propietario,
                "repo": repo,
                "numero": numero,
                "es_pr": tipo_url.startswith("pull"),
            }
        )
    if not entradas:
        print("Error: no se encontraron entradas con URL de GitHub en {}".format(ruta), file=sys.stderr)
    return entradas


def cargar_estado(ruta):
    try:
        datos = json.loads(ruta.read_text(encoding="utf-8"))
        if isinstance(datos, dict) and isinstance(datos.get("entradas"), dict):
            return datos
    except (OSError, ValueError):
        pass
    return {"entradas": {}}


def guardar_estado(ruta, datos):
    ruta.parent.mkdir(parents=True, exist_ok=True)
    temporal = ruta.with_suffix(".json.tmp")
    temporal.write_text(
        json.dumps(datos, indent=2, ensure_ascii=False) + "\n", encoding="utf-8"
    )
    temporal.replace(ruta)


def consultar(entrada, anterior, errores):
    """Consultar una entrada. Devuelve (registro, marca)."""
    url = entrada["url"]
    base = "{}/repos/{}/{}/".format(API, entrada["propietario"], entrada["repo"])
    ruta = "pulls" if entrada["es_pr"] else "issues"
    datos, error = fetch_json(
        "{}{}/{}".format(base, ruta, entrada["numero"]), url
    )

    reviews = []
    if datos and entrada["es_pr"]:
        revis, error_rev = fetch_json(
            "{}{}/{}/reviews".format(base, ruta, entrada["numero"]),
            url + " (reviews)",
        )
        if isinstance(revis, list):
            reviews = revis
        elif error_rev:
            errores.append(error_rev)

    previo = anterior.get(url, {})
    if datos is None:
        registro = dict(previo)
        registro.update(
            {
                "proyecto": entrada["proyecto"],
                "url": url,
                "tipo": entrada["tipo"],
                "titulo": previo.get("titulo", ""),
            }
        )
        return registro, "ERROR"

    total = int(datos.get("comments") or 0)
    if entrada["es_pr"]:
        total += int(datos.get("review_comments") or 0) + len(reviews)
    registro = {
        "proyecto": entrada["proyecto"],
        "url": url,
        "tipo": entrada["tipo"],
        "state": datos.get("state") or "",
        "total": total,
        "updated_at": datos.get("updated_at") or "",
        "titulo": datos.get("title") or "",
    }

    if not previo:
        marca = "NUEVO"
    else:
        cambia = any(
            previo.get(clave) != registro.get(clave)
            for clave in ("state", "total", "updated_at")
        )
        marca = "CAMBIADO" if cambia else ""

    if error:
        errores.append(error)
    return registro, marca


def recortar(texto, anchura):
    texto = " ".join(str(texto or "").split())
    if len(texto) > anchura:
        return texto[: anchura - 1] + "…"
    return texto


def celda(texto, anchura):
    texto = recortar(texto, anchura)
    return texto + " " * max(0, anchura - len(texto))


def imprimir_reporte(registros, marcas, ahora):
    abiertas = sum(1 for r in registros if r.get("state") == "open")
    cerradas = sum(1 for r in registros if r.get("state") == "closed")
    print("REGISTRO DE UPSTREAM — revisión del {}".format(ahora))
    print(
        "Entradas: {} | Abiertas: {} | Cerradas: {} | NUEVAS/CAMBIADAS: {}".format(
            len(registros),
            abiertas,
            cerradas,
            sum(1 for m in marcas if m in ("NUEVO", "CAMBIADO")),
        )
    )
    cabecera = (
        celda("PROYECTO", 28)
        + celda("ESTADO", 9)
        + celda("N.º", 4)
        + celda("ACTUALIZADO", 21)
        + celda("MARCA", 10)
        + "TÍTULO"
    )
    print(cabecera)
    print("-" * len(cabecera))
    for registro, marca in zip(registros, marcas):
        print(
            celda(registro.get("proyecto", ""), 28)
            + celda(registro.get("state", "?"), 9)
            + celda(str(registro.get("total", "?")), 4)
            + celda(registro.get("updated_at", "")[:20], 21)
            + celda(marca, 10)
            + recortar(registro.get("titulo", ""), 60)
        )
        print("  " + registro.get("url", ""))


def filas_markdown(entradas, registros):
    print("--- filas para pegar en docs/UPSTREAM-TRACKER.md ---")
    print("| Fecha | Proyecto | Enlace | Tipo | Estado | Última revisión | Siguiente acción |")
    print("|---|---|---|---|---|---|---|")
    for entrada, registro in zip(entradas, registros):
        total = registro.get("total", 0)
        sufijo = "comentarios/reseñas" if entrada["es_pr"] else "comentarios"
        estado = "{} ({} {})".format(registro.get("state", "?"), total, sufijo)
        revision = str(registro.get("updated_at", ""))[:10] or entrada["revision_md"]
        print(
            "| {} | {} | {} | {} | {} | {} | {} |".format(
                entrada["fecha"],
                entrada["proyecto"],
                registro.get("url", entrada["url"]),
                entrada["tipo"],
                estado,
                revision,
                entrada["accion"],
            )
        )


def cargar_credenciales(ruta):
    token, chat = "", ""
    try:
        lineas = ruta.read_text(encoding="utf-8").splitlines()
    except OSError:
        return "", ""
    for linea in lineas:
        if "=" not in linea:
            continue
        clave, valor = linea.split("=", 1)
        clave = clave.strip()
        valor = valor.strip().strip('"').strip("'")
        if clave == "TG_TOKEN":
            token = valor
        elif clave == "TG_CHAT":
            chat = valor
    return token, chat


def construir_mensaje(cambios):
    lineas = ["UPSTREAM-TRACKER: cambios detectados"]
    for entrada, registro, marca in cambios:
        sufijo = "comentarios/reseñas" if entrada["es_pr"] else "comentarios"
        lineas.append(
            "{} [{}] {} — {} ({} {}), actualizado {}".format(
                marca,
                registro.get("proyecto", ""),
                registro.get("url", ""),
                registro.get("state", "?"),
                registro.get("total", "?"),
                sufijo,
                str(registro.get("updated_at", ""))[:19],
            )
        )
        if registro.get("titulo"):
            lineas.append("  " + recortar(registro["titulo"], 110))
    mensaje = "\n".join(lineas)
    return mensaje[:LIMITE_MENSAJE]


def enviar_telegram(token, chat, texto):
    chat_id = int(chat) if chat.lstrip("-").isdigit() else chat
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


def main():
    parser = argparse.ArgumentParser(
        description="Revisa el registro de upstream en GitHub y avisa de cambios"
    )
    parser.add_argument("--report", action="store_true", help="imprime el informe (es lo habitual)")
    parser.add_argument("--notify", action="store_true", help="envía Telegram solo si hay cambios")
    parser.add_argument("--dry-run", action="store_true", help="no envía ni guarda estado")
    parser.add_argument("--force", action="store_true", help="envía aunque no haya cambios")
    parser.add_argument("--print-md", action="store_true", help="imprime filas listas para pegar")
    parser.add_argument(
        "--state", metavar="DIR", default="~/.local/share/upstream-tracker",
        help="directorio del state.json (por defecto ~/.local/share/upstream-tracker)",
    )
    parser.add_argument(
        "--env", metavar="RUTA", default="~/peanuts-watch/telegram.env",
        help="fichero telegram.env (por defecto ~/peanuts-watch/telegram.env)",
    )
    parser.add_argument("--doc", metavar="RUTA", help="ruta del markdown (por defecto la del repo)")
    args = parser.parse_args()

    ruta_doc = (
        pathlib.Path(args.doc).expanduser()
        if args.doc
        else pathlib.Path(__file__).resolve().parent.parent / "docs" / "UPSTREAM-TRACKER.md"
    )
    ruta_estado = pathlib.Path(args.state).expanduser() / "state.json"
    ruta_env = pathlib.Path(args.env).expanduser()

    token, chat = "", ""
    if args.notify and not args.dry_run:
        token, chat = cargar_credenciales(ruta_env)
        if not token or not chat:
            print(
                "Error de credenciales: faltan TG_TOKEN o TG_CHAT en {} "
                "(usa --env <ruta>)".format(ruta_env),
                file=sys.stderr,
            )
            return 2

    entradas = leer_documento(ruta_doc)
    if not entradas:
        return 2

    anterior = cargar_estado(ruta_estado)
    registros, marcas, errores = [], [], []
    for entrada in entradas:
        registro, marca = consultar(entrada, anterior, errores)
        registros.append(registro)
        marcas.append(marca)

    consultas_ok = sum(1 for marca in marcas if marca != "ERROR")
    if consultas_ok == 0:
        print(
            "Error de red: no se pudo consultar ninguna entrada"
            + ("; " + "; ".join(errores) if errores else ""),
            file=sys.stderr,
        )
        return 2

    ahora = datetime.datetime.now(datetime.timezone.utc).replace(microsecond=0).isoformat()
    imprimir_reporte(registros, marcas, ahora)
    if args.print_md:
        filas_markdown(entradas, registros)
    if errores:
        print("Avisos: " + "; ".join(errores))

    cambios = [
        (e, r, m)
        for e, r, m in zip(entradas, registros, marcas)
        if m in ("NUEVO", "CAMBIADO")
    ]
    mensaje = construir_mensaje(cambios)

    if args.dry_run:
        print("MODO DRY-RUN: no se envía nada y no se guarda estado.")
        if cambios or args.force:
            print("--- aviso que se enviaría ---")
            print(mensaje)
        else:
            print("Sin cambios: no se enviaría nada a Telegram (sin --force).")
        return 0

    try:
        guardar_estado(
            ruta_estado,
            {
                "last_run": ahora,
                "entradas": {r["url"]: r for r in registros},
            },
        )
    except OSError as exc:
        print("Error: no se pudo guardar {} ({})".format(ruta_estado, exc), file=sys.stderr)
        return 2
    print("Estado guardado en " + str(ruta_estado))

    if not args.notify:
        print("Sin --notify: solo se imprime, no se envía nada.")
        return 0
    if not cambios and not args.force:
        print("Sin cambios: no se envía nada a Telegram.")
        return 0
    print("Aviso ({} caracteres):".format(len(mensaje)))
    print(mensaje)
    return 0 if enviar_telegram(token, chat, mensaje) else 1


if __name__ == "__main__":
    sys.exit(main())
