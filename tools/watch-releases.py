#!/usr/bin/env python3
"""Vigilante genérico de repos de GitHub: avisa de releases y commits por Telegram.

Solo stdlib. Sin token de GitHub: usa la API pública con cabecera User-Agent.
Convive con watch-peanuts.py: comparte ~/peanuts-watch/telegram.env, pero usa
estado, script y timer propios (vigilar-releases.service / .timer).

Qué vigila
  - la última release de cada repo (tag, fecha, nombres y tamaños de assets);
  - el último commit de la rama por defecto (sha, fecha y mensaje corto).

Avisa si cambia el tag, aparecen/quitan/cambian assets (nombre o tamaño) o
cambia el sha del último commit. Si no hay cambios y no se usa --force, calla.

Instalación (PC de sobremesa, timer de sistema, separado del de Peanuts)
   1. Copiar a ~/peanuts-watch/watch-releases.py y dar permisos de ejecución.
   2. ~/peanuts-watch/telegram.env con TG_TOKEN=... y TG_CHAT=... (chmod 600).
   3. /etc/systemd/system/vigilar-releases.service  (Type=oneshot,
      ExecStart=/home/fransis/peanuts-watch/watch-releases.py --notify)
      /etc/systemd/system/vigilar-releases.timer    (OnCalendar=*-*-* 09:30:00,
      Persistent=true, WantedBy=timers.target) -> systemctl enable --now
      vigilar-releases.timer

Uso
   watch-releases.py --dry-run                 # imprime, no envía ni guarda
   watch-releases.py --notify                  # envía solo si hay cambios
   watch-releases.py --notify --force          # envía aunque no haya cambios
   watch-releases.py --state <dir> --env <ruta>
"""

import argparse
import datetime
import email.utils
import json
import os
import pathlib
import sys
import time
import urllib.error
import urllib.request

API = "https://api.github.com"
UA = "watch-releases/1.0 (stdlib; vigilancia personal)"
REPOS = [
    ("MAKO arm64 (Ken5998)", "Ken5998/mako-arm64"),
    ("Panel de Control (Hooandee)", "Hooandee/panel-de-control"),
    ("ARMSX2 (PS2)", "ARMSX2/ARMSX2"),
    ("Syluxium Motion (motor FG)", "Syluxium-Industries/Syluxium-motion"),
]
LIMITE_MENSAJE = 4000
_ultima_llamada = 0.0


def espaciado():
    """Garantiza al menos 1 s entre llamadas a la API de GitHub."""
    global _ultima_llamada
    if _ultima_llamada:
        restante = 1.0 - (time.monotonic() - _ultima_llamada)
        if restante > 0:
            time.sleep(restante)
    _ultima_llamada = time.monotonic()


def fecha(valor):
    if not valor:
        return "fecha desconocida"
    try:
        dt = datetime.datetime.fromisoformat(str(valor).replace("Z", "+00:00"))
        return dt.strftime("%Y-%m-%d %H:%M UTC")
    except (ValueError, TypeError):
        return str(valor)


def recortar(texto, limite=80):
    texto = " ".join(str(texto or "").split())
    return texto if len(texto) <= limite else texto[: limite - 1] + "."


def mb(num_bytes):
    return "{:.2f} MB".format(int(num_bytes or 0) / 1048576.0)


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
    """Devuelve (datos, error, codigo_http). Nunca lanza."""
    for intento in range(3):  # petición inicial + 2 reintentos como máximo
        espaciado()
        peticion = urllib.request.Request(
            url,
            headers={
                "User-Agent": UA,
                "Accept": "application/vnd.github+json",
            },
        )
        try:
            with urllib.request.urlopen(peticion, timeout=20) as respuesta:
                return json.load(respuesta), None, None
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
            return None, "{} (HTTP {})".format(etiqueta, exc.code), exc.code
        except Exception as exc:
            return None, "{} ({})".format(etiqueta, type(exc).__name__), None
    return None, "{} (sin respuesta tras 2 reintentos)".format(etiqueta), None


def datos_release(datos):
    if not isinstance(datos, dict):
        return None
    assets = []
    for asset in datos.get("assets") or []:
        try:
            size = int(asset.get("size") or 0)
        except (TypeError, ValueError):
            size = 0
        assets.append({"name": asset.get("name") or "asset", "size": size})
    return {
        "tag": datos.get("tag_name") or "",
        "published": datos.get("published_at"),
        "url": datos.get("html_url") or "",
        "assets": assets,
    }


def datos_commit(datos):
    if not isinstance(datos, list) or not datos:
        return None
    item = datos[0]  # per_page=1 -> el más reciente de la rama por defecto
    if not isinstance(item, dict):
        return None
    commit = item.get("commit") or {}
    autor = commit.get("committer") or commit.get("author") or {}
    return {
        "sha": item.get("sha") or "",
        "date": autor.get("date"),
        "message": recortar(commit.get("message")),
        "url": item.get("html_url") or "",
    }


def recoger_repo(anterior, nombre, repo, errores):
    """Consulta un repo; conserva lo que no se pudo consultar. Devuelve (estado, ok)."""
    actual = dict(anterior)
    actual["nombre"] = nombre
    ok = 0

    datos, error, code = fetch_json(
        API + "/repos/" + repo + "/releases/latest", "release de " + repo
    )
    if error:
        if code == 404:
            actual.update({"tag": None, "published": None, "assets": [], "release_url": ""})
            print("{}: sin release (HTTP 404)".format(nombre))
        else:
            errores.append("{} release: {}".format(nombre, error))
    elif isinstance(datos, dict):
        rel = datos_release(datos)
        if rel is None:
            errores.append("{} release: respuesta inesperada".format(nombre))
        else:
            actual.update(
                {
                    "tag": rel["tag"],
                    "published": rel["published"],
                    "assets": rel["assets"],
                    "release_url": rel["url"],
                }
            )
            ok += 1
    else:
        errores.append("{} release: respuesta inesperada".format(nombre))

    datos, error, code = fetch_json(
        API + "/repos/" + repo + "/commits?per_page=1", "commit de " + repo
    )
    if error:
        errores.append("{} commit: {}".format(nombre, error))
    elif isinstance(datos, list):
        comm = datos_commit(datos)
        if comm is None:
            errores.append("{} commit: respuesta inesperada".format(nombre))
        else:
            actual.update(
                {
                    "sha": comm["sha"],
                    "commit_date": comm["date"],
                    "commit_message": comm["message"],
                    "commit_url": comm["url"],
                }
            )
            ok += 1
    else:
        errores.append("{} commit: respuesta inesperada".format(nombre))

    return actual, ok


def indice_assets(items):
    indice = {}
    for item in items or []:
        try:
            size = int(item.get("size") or 0)
        except (TypeError, ValueError, AttributeError):
            size = 0
        indice[item.get("name") or "asset"] = size
    return indice


def cambios_assets(antes, ahora):
    a, b = indice_assets(antes), indice_assets(ahora)
    salida = []
    for name in sorted(b):
        if name not in a:
            salida.append("+{} ({})".format(name, mb(b[name])))
        elif a[name] != b[name]:
            salida.append("~{} ({} -> {})".format(name, mb(a[name]), mb(b[name])))
    for name in sorted(a):
        if name not in b:
            salida.append("-{}".format(name))
    return salida


def cambios_repo(antes, ahora):
    """Devuelve la lista de cambios de un repo (Ya vacía si no hay novedades)."""
    cambios = []
    tag_antes, tag_ahora = antes.get("tag"), ahora.get("tag")
    if tag_antes != tag_ahora:
        if tag_ahora:
            cambios.append(
                "release {} ({}) {}".format(
                    tag_ahora, fecha(ahora.get("published")), ahora.get("release_url") or ""
                ).strip()
            )
        else:
            cambios.append(
                "sin release (antes {}) {}".format(tag_antes or "ninguna", antes.get("release_url") or "")
                .strip()
            )

    assets = cambios_assets(antes.get("assets"), ahora.get("assets"))
    if assets:
        cambios.append("assets: " + "; ".join(assets) + " " + (ahora.get("release_url") or ""))

    sha_antes, sha_ahora = antes.get("sha"), ahora.get("sha")
    if sha_antes != sha_ahora:
        if sha_ahora:
            cambios.append(
                "commit {} «{}» ({}) {}".format(
                    str(sha_ahora)[:7],
                    ahora.get("commit_message") or "",
                    fecha(ahora.get("commit_date")),
                    ahora.get("commit_url") or "",
                ).strip()
            )
        else:
            cambios.append("sin commit disponible (antes {})".format(str(sha_antes)[:7]))
    return cambios


def compactar(texto, limite=LIMITE_MENSAJE):
    if len(texto) <= limite:
        return texto
    sufijo = "\n… (recortado a {} caracteres)".format(limite)
    return texto[: limite - len(sufijo)] + sufijo


def construir_mensaje(cambios_por_repo, errores, forzado):
    lineas = ["Vigilancia de releases/commits:"]
    for nombre, detalles in cambios_por_repo:
        lineas.append("- {}: {}".format(nombre, " | ".join(detalles)))
    if forzado and not cambios_por_repo:
        lineas.append("- Sin cambios desde la última revisión (envío forzado).")
    if errores:
        lineas.append("No se pudo consultar: " + "; ".join(errores))
    return compactar("\n".join(lineas))


def resumen(estado):
    lineas = []
    for nombre, repo in REPOS:
        entry = estado.get("repos", {}).get(repo, {})
        if entry.get("tag"):
            assets = ", ".join(
                "{} ({})".format(a.get("name"), mb(a.get("size"))) for a in entry.get("assets") or []
            )
            lineas.append(
                "{} [{}]: release {} ({}) - assets: {} {}".format(
                    nombre,
                    repo,
                    entry["tag"],
                    fecha(entry.get("published")),
                    assets or "sin assets",
                    entry.get("release_url") or "",
                ).strip()
            )
        else:
            lineas.append("{} [{}]: sin release".format(nombre, repo))
        if entry.get("sha"):
            lineas.append(
                "  commit {} «{}» ({}) {}".format(
                    str(entry["sha"])[:7],
                    entry.get("commit_message") or "",
                    fecha(entry.get("commit_date")),
                    entry.get("commit_url") or "",
                ).strip()
            )
        else:
            lineas.append("  commit: sin datos")
    return lineas


def cargar_estado(ruta):
    if not ruta.exists():
        return {}
    try:
        datos = json.loads(ruta.read_text(encoding="utf-8"))
        if isinstance(datos, dict) and isinstance(datos.get("repos"), dict):
            return datos
    except (OSError, ValueError) as exc:
        print(
            "Aviso: state.json no legible ({}); se empieza de cero".format(type(exc).__name__),
            file=sys.stderr,
        )
    return {}


def guardar(ruta, estado):
    ruta.parent.mkdir(parents=True, exist_ok=True)
    temporal = ruta.with_suffix(".json.tmp")
    temporal.write_text(
        json.dumps(estado, ensure_ascii=False, indent=2) + "\n", encoding="utf-8"
    )
    os.replace(temporal, ruta)


def cargar_credenciales(ruta):
    """Lee TG_TOKEN y TG_CHAT del fichero dado. Nunca imprime el token."""
    token, chat = "", ""
    if not ruta.exists():
        return token, chat
    try:
        lineas = ruta.read_text(encoding="utf-8").splitlines()
    except OSError as exc:
        print("Aviso: no se pudo leer {} ({})".format(ruta, type(exc).__name__), file=sys.stderr)
        return token, chat
    for linea in lineas:
        linea = linea.strip()
        if not linea or linea.startswith("#") or "=" not in linea:
            continue
        clave, valor = linea.split("=", 1)
        clave, valor = clave.strip(), valor.strip().strip('"').strip("'")
        if clave == "TG_TOKEN":
            token = valor
        elif clave == "TG_CHAT":
            chat = valor
    return token, chat


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
        description="Vigila releases y commits de repos de GitHub y avisa por Telegram"
    )
    parser.add_argument("--notify", action="store_true", help="envía avisos a Telegram")
    parser.add_argument("--dry-run", action="store_true", help="imprime, no envía ni guarda")
    parser.add_argument("--force", action="store_true", help="envía aunque no haya cambios")
    parser.add_argument(
        "--state", metavar="DIR", help="directorio del state.json (por defecto ~/.local/share/watch-releases)"
    )
    parser.add_argument(
        "--env", metavar="RUTA", help="fichero telegram.env (por defecto ~/peanuts-watch/telegram.env)"
    )
    args = parser.parse_args()

    carpeta = pathlib.Path(args.state).expanduser() if args.state else (
        pathlib.Path.home() / ".local" / "share" / "watch-releases"
    )
    ruta_estado = carpeta / "state.json"
    ruta_env = pathlib.Path(args.env).expanduser() if args.env else (
        pathlib.Path.home() / "peanuts-watch" / "telegram.env"
    )

    anterior = cargar_estado(ruta_estado)
    token, chat = "", ""
    if args.notify and not args.dry_run:
        token, chat = cargar_credenciales(ruta_env)
        if not token or not chat:
            print(
                "Error de credenciales: faltan TG_TOKEN o TG_CHAT en "
                + str(ruta_env)
                + " (usa --env <ruta>)",
                file=sys.stderr,
            )
            return 2

    ahora = datetime.datetime.now(datetime.timezone.utc).replace(microsecond=0).isoformat()
    actual = {"last_run": ahora, "repos": {}}
    errores = []
    consultas_ok = 0
    for nombre, repo in REPOS:
        try:
            entry, ok = recoger_repo(anterior.get("repos", {}).get(repo, {}), nombre, repo, errores)
        except Exception as exc:
            entry = dict(anterior.get("repos", {}).get(repo, {}))
            entry["nombre"] = nombre
            ok = 0
            errores.append("{} ({})".format(nombre, type(exc).__name__))
        actual["repos"][repo] = entry
        consultas_ok += ok

    if consultas_ok == 0:
        print(
            "Error de red: no se pudo consultar ningún repositorio"
            + ("; " + "; ".join(errores) if errores else ""),
            file=sys.stderr,
        )
        return 1

    primera = not anterior.get("repos")
    cambios_por_repo = []
    if not primera:
        for nombre, repo in REPOS:
            detalles = cambios_repo(
                anterior["repos"].get(repo, {}), actual["repos"].get(repo, {})
            )
            if detalles:
                cambios_por_repo.append((nombre, detalles))

    hay_cambios = bool(cambios_por_repo)
    mensaje = construir_mensaje(cambios_por_repo, errores, args.force)
    envia = args.notify and (hay_cambios or args.force)

    if args.dry_run:
        print("MODO DRY-RUN: no se envía nada y no se guarda estado")
        print("--- estado actual ---")
        print("\n".join(resumen(actual)))
        if errores:
            print("No se pudo consultar: " + "; ".join(errores))
        print("--- aviso ---")
        if hay_cambios or args.force:
            print(mensaje)
        else:
            print("Sin cambios desde la última revisión: no se enviaría nada a Telegram (sin --force).")
        print("Fin del dry-run ({}/repositorios consultados correctamente).".format(consultas_ok))
        return 0

    try:
        guardar(ruta_estado, actual)
    except OSError as exc:
        print("Error: no se pudo guardar {} ({})".format(ruta_estado, exc), file=sys.stderr)
        return 2
    print("Estado guardado en " + str(ruta_estado))

    if not args.notify:
        print("Sin --notify: solo se imprime, no se envía nada.")
        return 0
    if not envia:
        print("Sin cambios: no se envía nada a Telegram.")
        return 0
    print("Aviso ({} caracteres):".format(len(mensaje)))
    print(mensaje)
    return 0 if enviar_telegram(token, chat, mensaje) else 1


if __name__ == "__main__":
    sys.exit(main())
