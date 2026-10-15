#!/usr/bin/env bash
# check-armada-deckard.sh — vigilancia de paquetes/parches de armada y Deckard
#
# Nuestro sistema (pocknix en AYN Odin 3, SM8750) se nutre de dos fuentes externas
# ademas de pocknix:
#
#   1) armada (armada-os/armada, rama main): parches y empaquetado para handhelds ARM.
#      Interesa sobre todo: gamescope/, gamescope-session/, gamescope-session-steam/,
#      inputplumber/, mangohud/, kernel/, kwin/, powerdevil/, plasma-mobile/,
#      umtp-responder/, networkmanager/, wpa_supplicant/, steamos-manager/,
#      scx-scheds/, mesa/, mesa-x86/, fex/, fex-rootfs-archlinux/, proton-cachyos/,
#      lepton/.
#
#   2) Deckard (Valve / Steam Frame aarch64): repositorio de paquetes en
#      https://holo-packages.steamos.cloud/archlinux-deckard-hotfixes/
#      Interesa sobre todo: deckard-mesa-linux-aarch64, deckard-mesa-android,
#      deckard-vulkan-layers-linux-aarch64, deckard-audio-config, deckard-hw-support,
#      mangohud, steamos-manager, linux-72-deckard, scx-scheds.
#
# SOLO INFORMA (no cambia nada). Salida clara en espanol. Pensado para lanzarlo a
# mano o desde un cron/timer.
#
# Uso:
#   tools/check-armada-deckard.sh [--dias N] [--json]
#
#     --dias N   ventana de commits de armada, en dias (por defecto 14)
#     --json     imprime el mismo informe en JSON
#     -h,--help  esta ayuda
#
# Opcional: exporta GITHUB_TOKEN (o GH_TOKEN) para subir el limite de la API de
# GitHub (60 peticiones/hora sin token -> puede no alcanzar para detallar cada
# commit de armada; la herramienta avisa y degrada sin romperse).
#
# Manejo de errores: sin red / HTTP != 200 / rate-limit (403/429) -> mensaje claro
# y salida 0 (es informativo, nunca debe romper un build/script que lo llame).
set -u

# Salida estable e independiente del idioma del usuario.
export LC_ALL=C

# ------------------------------------------------------------------ parametros
DIAS=14
MODO="texto"

ayuda() {
    printf '%s\n' \
        "check-armada-deckard.sh — vigilancia de paquetes/parches de armada y Deckard" \
        "" \
        "Uso: tools/check-armada-deckard.sh [--dias N] [--json]" \
        "" \
        "  --dias N   ventana de commits de armada, en dias (por defecto 14)" \
        "  --json     imprime el mismo informe en JSON" \
        "  -h,--help  esta ayuda" \
        "" \
        "Solo INFORMA (no cambia nada). Para subir el limite de la API de GitHub," \
        "exporta GITHUB_TOKEN o GH_TOKEN."
}

while [ $# -gt 0 ]; do
    case "$1" in
        --dias)    DIAS="${2:-}"; shift 2 ;;
        --dias=*)  DIAS="${1#*=}"; shift ;;
        --json)    MODO="json"; shift ;;
        -h|--help) ayuda; exit 0 ;;
        *) echo "opcion desconocida: $1 (usa -h para la ayuda)"; exit 0 ;;
    esac
done
case "$DIAS" in
    ''|*[!0-9]*) echo "--dias necesita un numero entero de dias"; exit 0 ;;
esac

# ------------------------------------------------------------------ config
API="https://api.github.com"
REPO="armada-os/armada"
RAMA="main"
DECKARD_URL="https://holo-packages.steamos.cloud/archlinux-deckard-hotfixes/"

# Paquetes de interes (primer nivel de packages/<algo>/ para armada; nombre de paquete para Deckard)
INTERES_ARMADA="gamescope gamescope-session gamescope-session-steam inputplumber mangohud kernel kwin powerdevil plasma-mobile umtp-responder networkmanager wpa_supplicant steamos-manager scx-scheds mesa mesa-x86 fex fex-rootfs-archlinux proton-cachyos lepton"
INTERES_DECKARD="deckard-mesa-linux-aarch64 deckard-mesa-android deckard-vulkan-layers-linux-aarch64 deckard-audio-config deckard-hw-support mangohud steamos-manager linux-72-deckard scx-scheds"

TOKEN="${GITHUB_TOKEN:-${GH_TOKEN:-}}"
AUTH=()
if [ -n "$TOKEN" ]; then
    AUTH=(-H "Authorization: Bearer $TOKEN")
fi

TMP="$(mktemp -d 2>/dev/null || mktemp -d -t armada-deckard.XXXXXX)"
trap 'rm -rf "$TMP"' EXIT

# ------------------------------------------------------------------ helpers
# http_get <url> <fichero-salida> -> imprime el codigo HTTP (000 si no hay red)
http_get() {
    local url="$1" out="$2" code=""
    code=$(curl -sS -L --max-time 40 \
                -H "Accept: application/vnd.github+json" "${AUTH[@]}" \
                -o "$out" -w '%{http_code}' "$url" 2>/dev/null) || code=""
    [ -n "$code" ] || code="000"
    printf '%s' "$code"
}

err_msg_http() {  # <codigo> <contexto>
    case "$1" in
        000|"")  printf 'sin conexion (%s)' "$2" ;;
        403|429) printf 'rate-limit de la API de GitHub (HTTP %s) (%s)' "$1" "$2" ;;
        *)       printf 'HTTP %s de la API de GitHub (%s)' "$1" "$2" ;;
    esac
}

# ================================================================== ARMADA
ARM_ERR=""
ARM_NOTA=""
: > "$TMP/arm_commits.tsv"
: > "$TMP/arm_files.tsv"

SINCE=$(python3 -c "import datetime;print((datetime.datetime.now(datetime.timezone.utc)-datetime.timedelta(days=int('$DIAS'))).strftime('%Y-%m-%dT%H:%M:%SZ'))")

pag=1
while : ; do
    code=$(http_get "$API/repos/$REPO/commits?sha=$RAMA&since=$SINCE&per_page=100&page=$pag" "$TMP/arm_page.json")
    if [ "$code" != "200" ]; then
        ARM_ERR="$(err_msg_http "$code" "al listar commits de $REPO")"
        break
    fi
    n=$(python3 -c "import json;print(len(json.load(open('$TMP/arm_page.json'))))" 2>/dev/null || echo 0)
    python3 -c "
import json
d=json.load(open('$TMP/arm_page.json'))
with open('$TMP/arm_commits.tsv','a') as f:
    for c in d:
        msg=c['commit']['message'].splitlines()[0].replace('\t',' ').strip()
        f.write('%s\t%s\t%s\n' % (c['commit']['author']['date'], c['sha'], msg))
" 2>/dev/null || true
    [ "$n" -lt 100 ] && break
    pag=$((pag+1))
    [ "$pag" -gt 10 ] && break
done

ARM_TOTAL=0
[ -s "$TMP/arm_commits.tsv" ] && ARM_TOTAL=$(wc -l < "$TMP/arm_commits.tsv" | tr -d ' ')

# Detallar cada commit (para saber que packages/ toca) respetando el limite de la API
ARM_DETAL=0
if [ -z "$ARM_ERR" ] && [ "$ARM_TOTAL" -gt 0 ]; then
    REM=0
    code=$(http_get "$API/rate_limit" "$TMP/rate.json")
    if [ "$code" = "200" ]; then
        REM=$(python3 -c "import json;print(json.load(open('$TMP/rate.json'))['resources']['core']['remaining'])" 2>/dev/null || echo 0)
        case "$REM" in ''|*[!0-9]*) REM=0 ;; esac
    fi
    # margen de seguridad de 4 peticiones
    if [ "$REM" -gt 4 ]; then PRES=$((REM-4)); else PRES=0; fi
    [ "$PRES" -gt "$ARM_TOTAL" ] && PRES="$ARM_TOTAL"

    while IFS=$'\t' read -r fecha sha asunto; do
        [ -n "$sha" ] || continue
        [ "$ARM_DETAL" -ge "$PRES" ] && break
        code=$(http_get "$API/repos/$REPO/commits/$sha" "$TMP/d_$sha.json")
        if [ "$code" != "200" ]; then
            ARM_ERR="$(err_msg_http "$code" "al detallar un commit de $REPO")"
            break
        fi
        ARM_DETAL=$((ARM_DETAL+1))
        python3 -c "
import json
d=json.load(open('$TMP/d_$sha.json'))
pkgs=set()
for f in (d.get('files') or []):
    fn=f.get('filename','')
    rest=fn[len('packages/'):] if fn.startswith('packages/') else ''
    if rest and '/' in rest:
        p=rest.split('/',1)[0]
        if p: pkgs.add(p)
if not pkgs:
    pkgs.add('(sin paquete: raiz/otros)')
with open('$TMP/arm_files.tsv','a') as fh:
    for p in sorted(pkgs):
        fh.write('%s\t%s\n' % ('$sha', p))
" 2>/dev/null || true
    done < "$TMP/arm_commits.tsv"

    if [ -z "$ARM_ERR" ] && [ "$ARM_DETAL" -lt "$ARM_TOTAL" ]; then
        if [ -z "$TOKEN" ]; then
            ARM_NOTA="solo se detallaron $ARM_DETAL de $ARM_TOTAL commits (limite de la API sin token; exporta GITHUB_TOKEN para el detalle completo)"
        else
            ARM_NOTA="solo se detallaron $ARM_DETAL de $ARM_TOTAL commits (limite de la API)"
        fi
    fi
fi

# ================================================================== DECKARD
DECK_ERR=""
DECK_TOTAL=0
: > "$TMP/deckard.tsv"

if [ -z "$DECK_ERR" ]; then
    code=$(http_get "$DECKARD_URL" "$TMP/deckard.html")
    if [ "$code" != "200" ]; then
        case "$code" in
            000|"")  DECK_ERR="sin conexion a $DECKARD_URL" ;;
            *)       DECK_ERR="HTTP $code de $DECKARD_URL" ;;
        esac
    else
        python3 - "$TMP/deckard.html" "$TMP/deckard.tsv" <<'PY' 2>/dev/null || DECK_ERR="no se pudo parsear el listado HTML"
import re, html, sys
src, dst = sys.argv[1], sys.argv[2]
data = open(src, encoding="utf-8", errors="replace").read()
rx = re.compile(r'<a href="([^"]+)"(?: title="([^"]*)")?>[^<]*</a></td><td class="size">[^<]*</td><td class="date">([^<]*)</td>')
seen = set()
with open(dst, "w", encoding="utf-8") as out:
    for m in rx.finditer(data):
        name = html.unescape(m.group(2) or "").strip()
        date = m.group(3).strip()
        if not name.endswith(".pkg.tar.zst"):
            continue
        key = (name, date)
        if key in seen:
            continue
        seen.add(key)
        out.write("%s\t%s\n" % (name, date))
PY
        [ -s "$TMP/deckard.tsv" ] && DECK_TOTAL=$(wc -l < "$TMP/deckard.tsv" | tr -d ' ')
    fi
fi

# ================================================================== informe
python3 - "$TMP" "$MODO" "$DIAS" "$INTERES_ARMADA" "$INTERES_DECKARD" "$ARM_ERR" "$ARM_NOTA" "$DECK_ERR" <<'PY'
import sys, json, datetime
from collections import OrderedDict

tmp, modo, dias, inter_arm, inter_deck, arm_err, arm_nota, deck_err = sys.argv[1:9]
inter_arm = set(inter_arm.split())
inter_deck = inter_deck.split()   # conserva el orden

def read(p):
    try:
        return open(p, encoding="utf-8").read().strip()
    except OSError:
        return ""

def rows(p):
    t = read(p)
    return [l.split("\t") for l in t.splitlines()] if t else []

def fmt_iso(s):
    try:
        d = datetime.datetime.strptime(s, "%Y-%m-%dT%H:%M:%SZ").replace(tzinfo=datetime.timezone.utc)
        return d.strftime("%Y-%m-%d %H:%M UTC")
    except ValueError:
        return s

_MESES = {"Jan": 1, "Feb": 2, "Mar": 3, "Apr": 4, "May": 5, "Jun": 6,
          "Jul": 7, "Aug": 8, "Sep": 9, "Oct": 10, "Nov": 11, "Dec": 12}

def pdate(s):
    # "2026-Oct-14 20:09" -> datetime, sin depender del locale (no usa date -d)
    fecha, hora = s.split()
    y, mon, d = fecha.split("-")
    hh, mm = hora.split(":")
    return datetime.datetime(int(y), _MESES[mon], int(d), int(hh), int(mm))

# ---------- armada ----------
commits = [(r[0], r[1], r[2]) for r in rows(tmp + "/arm_commits.tsv") if len(r) >= 3]
files = {}
for r in rows(tmp + "/arm_files.tsv"):
    if len(r) >= 2:
        files.setdefault(r[0], []).append(r[1])

grupos = OrderedDict()
for fecha, sha, asunto in commits:
    for p in (files.get(sha) or ["(sin detallar)"]):
        grupos.setdefault(p, []).append((fecha, sha, asunto))

# orden: interes (según lista) primero, luego el resto por nº de commits desc
orden_inter = [p for p in inter_arm if p in grupos]
resto = sorted((p for p in grupos if p not in inter_arm), key=lambda p: (-len(grupos[p]), p))
orden = orden_inter + resto

# ---------- deckard ----------
deck = [(r[0], r[1]) for r in rows(tmp + "/deckard.tsv") if len(r) >= 2]
deck_valido = []
for n, d in deck:
    try:
        deck_valido.append((n, d, pdate(d)))
    except Exception:
        pass
deck_valido.sort(key=lambda x: x[2], reverse=True)
recientes = [(n, d) for n, d, _ in deck_valido[:20]]
mas_reciente = (deck_valido[0][0], deck_valido[0][1]) if deck_valido else None

def es_debug(n):
    return "-debug" in n or "-assert" in n

inter_res = []
for pkg in inter_deck:
    cand = [(n, d, dt) for n, d, dt in deck_valido
            if (n == pkg or n.startswith(pkg + "-")) and not es_debug(n)]
    if cand:
        cand.sort(key=lambda x: x[2], reverse=True)
        n, d, _ = cand[0]
        inter_res.append((pkg, n, d))

# =========================================================== salida
if modo == "json":
    doc = {
        "generado": datetime.datetime.now(datetime.timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ"),
        "armada": {
            "repo": "armada-os/armada", "rama": "main", "dias": int(dias),
            "commits_total": len(commits), "commits_detallados": len(files),
            "error": arm_err or None, "nota": arm_nota or None,
            "grupos": [
                {
                    "paquete": p, "interes": p in inter_arm, "n_commits": len(grupos[p]),
                    "commits": [{"fecha": f, "fecha_utc": fmt_iso(f), "sha": s[:10], "asunto": a}
                                for f, s, a in sorted(grupos[p], reverse=True)],
                }
                for p in orden
            ],
        },
        "deckard": {
            "url": "https://holo-packages.steamos.cloud/archlinux-deckard-hotfixes/",
            "paquetes_total": len(deck_valido), "error": deck_err or None,
            "mas_reciente": ({"nombre": mas_reciente[0], "fecha": mas_reciente[1]} if mas_reciente else None),
            "recientes": [{"nombre": n, "fecha": d} for n, d in recientes],
            "interes": [{"paquete": p, "nombre": n, "fecha": d} for p, n, d in inter_res],
        },
    }
    print(json.dumps(doc, ensure_ascii=False, indent=2))
    sys.exit(0)

W = 74
def titulo(t):
    print("=" * W)
    print(t)
    print("=" * W)

# ---------- armada ----------
titulo("ARMADA — armada-os/armada @ main  (ventana: ultimos %s dias)" % dias)
if arm_err:
    print("  !! %s" % arm_err)
    print("     (no se pudo consultar armada; el resto del informe sigue)")
else:
    print("  commits en la ventana : %d" % len(commits))
    print("  commits detallados    : %d" % len(files))
    if arm_nota:
        print("  aviso                 : %s" % arm_nota)
    print()
    if not orden:
        print("  (ningun commit que agrupar)")
    for p in orden:
        marca = "*" if p in inter_arm else " "
        etq = " [INTERES]" if p in inter_arm else ""
        print("%s %s%s  (%d commit%s)" % (marca, p, etq, len(grupos[p]),
                                          "" if len(grupos[p]) == 1 else "s"))
        for f, s, a in sorted(grupos[p], reverse=True):
            print("      %s  %s  %s" % (fmt_iso(f), s[:10], a))
        print()
    print("  paquetes de interes tocados: %s" %
          (", ".join(orden_inter) if orden_inter else "(ninguno)"))
print()

# ---------- deckard ----------
titulo("DECKARD — holo-packages .../archlinux-deckard-hotfixes/")
if deck_err:
    print("  !! %s" % deck_err)
    print("     (no se pudo consultar Deckard)")
else:
    print("  paquetes .pkg.tar.zst (unicos): %d" % len(deck_valido))
    if mas_reciente:
        print("  paquete mas reciente          : %s" % mas_reciente[1])
        print("                                  %s" % mas_reciente[0])
    print()
    print("-- 20 paquetes .pkg.tar.zst mas recientes --")
    for n, d in recientes:
        print("  %s  %s" % (d, n))
    print()
    print("-- paquetes de interes (version mas nueva, sin -debug/-assert) --")
    for pkg, n, d in inter_res:
        print("  * %-38s %s" % (d, n))
    faltan = [p for p in inter_deck if p not in [x[0] for x in inter_res]]
    if faltan:
        print("  (sin coincidencias para: %s)" % ", ".join(faltan))
print()
print("Recordatorio: solo INFORMA. Revisa a mano si merece la pena adaptarlo a la Odin 3.")
PY

exit 0
