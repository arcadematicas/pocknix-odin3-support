#!/usr/bin/env bash
# ===========================================================================
#  watch-wwhd-recomp-linux.sh — vigila el port de Wind Waker HD para Linux
# ===========================================================================
#  Estado a 03/10/2026 (ver docs/WIND-WAKER-HD-RECOMP-LINUX.md):
#    - Fork   : misael-urquidez/ZeldaWWHDRecomp-Linux  (0 estrellas, 0 issues, 0 releases)
#               Upstream: ZeldaWWHDRecomp/ZeldaWWHDRecomp (61 estrellas, 0 releases)
#    - DOS ramas: `main` = el port macOS/Metal intacto (NO es el de Linux);
#                 `linux-port` = el port real (SDL2 + OpenGL), 1 solo commit.
#    - APARCADO: no hay dump .wud/.wux valido ni claves, y la Odin no da
#                OpenGL 4.3 de escritorio (da GLES). El .wua de Batocera no vale.
#    - Lo que hay que mirar de verdad es el UPSTREAM: ahi viven los 60 fps, la
#      resolucion, el shader cache y (nuevo) la rama `linux` con Vulkan, que si
#      nos serviria: en la Odin el Vulkan (Turnip) funciona y el OpenGL, no.
#
#  USO
#    tools/watch-wwhd-recomp-linux.sh              # una consulta y sale
#    tools/watch-wwhd-recomp-linux.sh --wait       # revisa cada hora, avisa al vuelo
#    tools/watch-wwhd-recomp-linux.sh --wait 1800  # cada media hora
#    tools/watch-wwhd-recomp-linux.sh --help       # ayuda en una linea
#
#  Guarda estado en ~/.cache/wwhd-watch.state (o $XDG_CACHE_HOME). La PRIMERA
#  ejecucion solo guarda; las siguientes marcan NOVEDAD si algo cambio.
#
#  Token: lo lee de ~/.config/opencode/opencode.jsonc (GITHUB_PERSONAL_ACCESS_TOKEN).
#  Sin token funciona igual, con el rate limit de anonimo.
#
#  Sale con codigo 0 siempre (es un vigilante, no un test): si no hay red o
#  GitHub devuelve 403 (rate limit), lo dice y sale, sin stacktrace y SIN
#  tocar el estado guardado (para no perder la linea base).
# ===========================================================================
set -uo pipefail

REPO="misael-urquidez/ZeldaWWHDRecomp-Linux"
UPSTREAM="ZeldaWWHDRecomp/ZeldaWWHDRecomp"
INTERVALO=3600

STATE_FILE="${XDG_CACHE_HOME:-$HOME/.cache}/wwhd-watch.state"
[ -n "${XDG_CACHE_HOME:-}" ] || STATE_FILE="$HOME/.cache/wwhd-watch.state"

case "${1:-}" in
    -h|--help)
        echo "Uso: $(basename "$0") [--wait [segundos]]   vigila el port de Wind Waker HD para Linux (rama linux-port, ramas nuevas, releases y el upstream)"
        exit 0 ;;
    --wait)
        ESPERAR=1
        [ -n "${2:-}" ] && case "${2:-}" in ''|*[!0-9]*) ;; *) INTERVALO="$2" ;; esac ;;
    '')  ESPERAR=0 ;;
    *)   echo "$(basename "$0"): opcion no conocida: $1 (usa --help)" >&2; exit 0 ;;
esac

# --- token: del fichero de opencode, si esta. Sin el, modo anonimo. ---------
leer_token() {
    python3 - <<'PY' 2>/dev/null || true
import os, re
p = os.path.expanduser("~/.config/opencode/opencode.jsonc")
try:
    s = open(p, encoding="utf-8", errors="replace").read()
except Exception:
    raise SystemExit(0)
m = re.search(r'"GITHUB_PERSONAL_ACCESS_TOKEN"\s*:\s*"([^"]+)"', s)
print(m.group(1) if m else "")
PY
}

TOKEN="$(leer_token)"
[ -n "$TOKEN" ] || echo "aviso: sin token de GitHub; se va con el rate limit de anonimo (60 peticiones/h)"

consulta() {
    python3 - "$REPO" "$UPSTREAM" "$TOKEN" <<'PY'
import json, sys, urllib.request, urllib.error, datetime

repo, upstream, token = sys.argv[1], sys.argv[2], sys.argv[3]
API = "https://api.github.com"


def get(path):
    req = urllib.request.Request(API + path)
    req.add_header("Accept", "application/vnd.github+json")
    req.add_header("User-Agent", "pocknix-wwhd-watch")
    if token:
        req.add_header("Authorization", "Bearer " + token)
    try:
        with urllib.request.urlopen(req, timeout=25) as x:
            return json.load(x)
    except urllib.error.HTTPError as e:
        if e.code in (403, 429):
            print("ERROR\tGitHub devuelve HTTP %d (rate limit o acceso denegado). Sale sin tocar el estado." % e.code)
        elif e.code == 404:
            print("ERROR\tGitHub devuelve HTTP 404 (repo o rama no encontrada: %s)" % path)
        else:
            print("ERROR\tGitHub devuelve HTTP %d en %s" % (e.code, path))
        raise SystemExit(1)
    except urllib.error.URLError as e:
        print("ERROR\tsin red o no se pudo consultar GitHub: %s" % (e.reason,))
        raise SystemExit(1)
    except Exception as e:
        print("ERROR\tfallo inesperado consultando %s: %s" % (path, e))
        raise SystemExit(1)


def cuando(iso):
    if not iso:
        return "?"
    return (iso or "")[:19].replace("T", " ") + " UTC"


def es_arm(nombre):
    n = (nombre or "").lower()
    return any(k in n for k in ("aarch64", "arm64", "armv7", "armv8", "-arm."))


info = get("/repos/" + repo)
parent = (info.get("parent") or {}).get("full_name") or ""
up = parent or upstream

ramas = get("/repos/%s/branches?per_page=100" % repo)
nombres = sorted(b["name"] for b in ramas)
otras = [n for n in nombres if n not in ("main", "linux-port")]

lp = get("/repos/%s/commits/linux-port" % repo)
lp_sha = lp["sha"]
lp_msg = (lp["commit"]["message"] or "").splitlines()[0]
lp_fecha = lp["commit"]["committer"]["date"]

rel = get("/repos/%s/releases?per_page=10" % repo)

up_main = get("/repos/%s/commits?sha=main&per_page=5" % up)
up_lin = get("/repos/%s/commits?sha=linux&per_page=5" % up)
try:
    up_rel = get("/repos/%s/releases?per_page=10" % up)
except SystemExit:
    up_rel = []

print("\n\033[1m== FORK  %s  (ramas: %s, releases: %d, estrellas: %d)\033[0m"
      % (repo, ", ".join(nombres) or "-", len(rel), info.get("stargazers_count", 0)))
print("   upstream (parent): %s" % (up or "?"))
print("\n\033[1m-- rama linux-port (la que importa) --\033[0m")
print("   %s" % lp_sha[:12])
print("   %s" % cuando(lp_fecha))
print("   %s" % lp_msg)

print("\n\033[1m-- ramas nuevas ademas de main/linux-port --\033[0m")
if otras:
    for n in otras:
        print("   NUEVA: %s" % n)
else:
    print("   ninguna")

print("\n\033[1m-- releases del fork --\033[0m")
if rel:
    for r in rel:
        print("   %s  (%s)" % (r.get("tag_name"), cuando(r.get("published_at"))))
        assets = r.get("assets") or []
        if not assets:
            print("      (sin assets)")
        for a in assets:
            print("      asset: %-40s %.1f MB  %s"
                  % (a.get("name"), (a.get("size") or 0) / 1048576.0,
                     "** ARM64/AARCH64 **" if es_arm(a.get("name")) else ""))
else:
    print("   ninguna")

print("\n\033[1m== UPSTREAM  %s  (de aqui sale el avance de verdad)\033[0m" % up)
print("   60 fps, resolucion, shader cache y la rama `linux` con Vulkan/SDL3 viven aqui.")
for etiqueta, commits in (("main", up_main), ("linux", up_lin)):
    print("\n-- upstream %s --" % etiqueta)
    if not isinstance(commits, list) or not commits:
        print("   (sin commits o rama inexistente)")
        continue
    for c in commits[:3]:
        print("   %s  %s  %s"
              % (c["sha"][:10], cuando(c["commit"]["committer"]["date"]),
                 (c["commit"]["message"] or "").splitlines()[0]))

print("\n-- releases del upstream --")
if up_rel:
    for r in up_rel:
        print("   %s  (%s)" % (r.get("tag_name"), cuando(r.get("published_at"))))
        for a in (r.get("assets") or []):
            print("      asset: %-40s %.1f MB  %s"
                  % (a.get("name"), (a.get("size") or 0) / 1048576.0,
                     "** ARM64/AARCH64 **" if es_arm(a.get("name")) else ""))
else:
    print("   ninguna")

# --- huella para comparar con la ejecucion anterior ------------------------
huella = "|".join([
    lp_sha,
    ",".join(nombres),
    ",".join(sorted(r.get("tag_name") or "" for r in rel)),
    ";".join(sorted((r.get("tag_name") or "") + "/" + ",".join(sorted(a.get("name") or ""
                     for a in (r.get("assets") or []))) for r in rel)),
    ",".join(c["sha"] for c in (up_main if isinstance(up_main, list) else [])),
    ",".join(c["sha"] for c in (up_lin if isinstance(up_lin, list) else [])),
    ",".join(sorted(r.get("tag_name") or "" for r in (up_rel if isinstance(up_rel, list) else []))),
])
print("\nHUELLA\t%s" % huella)
PY
}

revisar() {
    local salida rc fp
    salida="$(consulta)"
    rc=$?
    # consulta() imprime ERROR<TAB>... y sale 1 si algo fallo (sin tocar estado)
    if [ "$rc" != 0 ] || printf '%s' "$salida" | grep -q '^ERROR	'; then
        printf '\n\033[33m⚠ %s\033[0m\n' "$(printf '%s' "$salida" | sed -n 's/^ERROR\t//p' | head -1)"
        echo "   (no se actualiza $STATE_FILE: el estado viejo se conserva)"
        return 2
    fi

    fp="$(printf '%s' "$salida" | sed -n 's/^HUELLA\t//p' | head -1)"
    printf '%s\n' "$salida" | grep -v '^HUELLA	'

    if [ ! -s "$STATE_FILE" ]; then
        mkdir -p "$(dirname "$STATE_FILE")" 2>/dev/null
        printf '%s\n' "$fp" > "$STATE_FILE"
        echo
        echo "primera ejecucion: no habia estado con que comparar."
        echo "  estado guardado en: $STATE_FILE"
        echo
        printf '\033[1m¿algo nuevo desde la ultima vez? NO\033[0m  (primera vez: solo se guarda estado)\n'
        return 0
    fi

    local previo
    previo="$(cat "$STATE_FILE")"
    if [ "$previo" = "$fp" ]; then
        echo
        printf '\033[1m¿algo nuevo desde la ultima vez? NO\033[0m  (sin novedades)\n'
        return 0
    fi

    # Si ha cambiado, explica que antes era y que es ahora.
    local viejo nuevo
    viejo="$previo"
    nuevo="$fp"
    echo
    printf '\033[1m🚨 ¡NOVEDAD!\033[0m\n'
    local campo
    for campo in 1 2 3 4 5 6 7 8; do
        local v n
        v="$(printf '%s' "$viejo" | cut -d'|' -f"$campo")"
        n="$(printf '%s' "$nuevo" | cut -d'|' -f"$campo")"
        if [ "$v" != "$n" ]; then
            printf '   campo %s cambio:\n      antes: %s\n      ahora: %s\n' "$campo" "${v:-?}" "${n:-?}"
        fi
    done
    mkdir -p "$(dirname "$STATE_FILE")" 2>/dev/null
    printf '%s\n' "$fp" > "$STATE_FILE"
    echo "   estado actualizado en: $STATE_FILE"
    echo
    printf '\033[1m¿algo nuevo desde la ultima vez? SI\033[0m  (mira lo de arriba)\n'
    return 0
}

if [ "$ESPERAR" = 0 ]; then
    revisar
    exit 0
fi

echo "Vigilando $REPO (linux-port + upstream) cada ${INTERVALO}s (Ctrl+C para salir)..."
vistos=0
while true; do
    revisar
    rc=$?
    # rc=0 con "SI" => algo nuevo: avisamos al vuelo y no esperamos mas.
    if [ "$rc" = 0 ]; then
        vistos=$((vistos + 1))
        if [ "$vistos" -ge 1 ]; then
            printf '\033[1mSe detectaron novedades; saliendo del modo --wait.\033[0m\n'
            exit 0
        fi
    fi
    sleep "$INTERVALO"
done
