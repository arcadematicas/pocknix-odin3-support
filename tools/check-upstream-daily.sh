#!/usr/bin/env bash
# check-upstream-daily.sh — ejecuta check-upstream.sh, guarda el informe del dia y
# resalta las NOVEDADES respecto a la ejecucion anterior.
#
# Lo lanza el timer de usuario `pocknix-upstream-check.timer` (cada dia a las 08:15),
# pero tambien se puede ejecutar a mano:
#   tools/check-upstream-daily.sh [--repo DIR]
#
# Salidas:
#   ~/.local/share/pocknix/upstream/YYYY-MM-DD.txt   informe del dia (90 dias)
#   ~/.local/share/pocknix/upstream/latest.txt       enlace al ultimo
#   ~/.local/share/pocknix/upstream/last-fingerprint.txt   estado para calcular novedades
#   journal (stdout): solo el bloque de NOVEDADES
#
# Lo que no se atienda ese dia NO se pierde: queda en el informe y, cuando se revisa,
# se anota en docs/UPSTREAM-BACKLOG.md (que es la memoria de decisiones).
set -u
export LC_ALL=C

HERE="$(CDPATH= cd -- "$(dirname -- "$0")" && pwd -P)"
REPO="${HOME}/pocknix-odin3-project/pocknix-os"
while [ $# -gt 0 ]; do
  case "$1" in
    --repo) REPO="$2"; shift 2 ;;
    -h|--help) sed -n '2,20p' "$0"; exit 0 ;;
    *) shift ;;
  esac
done

OUTDIR="${XDG_DATA_HOME:-${HOME}/.local/share}/pocknix/upstream"
mkdir -p "${OUTDIR}"

# --- MAKO: seguimiento de soporte AArch64 -------------------------------------
# Interesa saber (a) si hay release nueva del Renderer y (b) si esa release ya trae
# binarios aarch64/arm64. Mientras siga en x86_64 no hay nada que hacer en nuestro lado.
mako_line() {
  timeout 40 curl -fsSL -H 'User-Agent: pocknix-upstream-check' \
    'https://api.github.com/repos/eugeniosegala/MAKO/releases?per_page=10' 2>/dev/null \
  | python3 -c '
import json, sys
try:
    rel = json.load(sys.stdin)
except Exception:
    print("MAKO: sin datos (API)"); raise SystemExit
render = next((r for r in rel if str(r.get("tag_name","")).startswith("render-")), None)
plugin = next((r for r in rel if str(r.get("tag_name","")).startswith("plugin-")), None)
if not render:
    print("MAKO: sin releases"); raise SystemExit
assets = " ".join(a.get("name","") for a in render.get("assets", []))
arm = any(t in assets.lower() for t in ("aarch64", "arm64"))
print("MAKO: %s (%s) | aarch64=%s | plugin=%s" % (
    render.get("tag_name"),
    (render.get("published_at") or "")[:10],
    "SI" if arm else "NO",
    (plugin or {}).get("tag_name", "?")))
' 2>/dev/null || echo "MAKO: sin datos (red)"
}
# --- Hooandee: plugins que van en la imagen -----------------------------------
# Delegado en tools/check-hooandee.sh. El "Panel de Control" se vende y se autoactualiza en el
# dispositivo, pero una imagen NUEVA sigue sembrando nuestra copia semilla; y "Colores" no se
# vende, aunque sus fallos de descarga acaban en nuestro tejado. Solo avisa: actualizar es un build.
HOOANDEE_LINES="$("${HERE}/check-hooandee.sh" 2>/dev/null || echo 'Hooandee: sin datos (API)')"

# --- Holodor: proyecto hermano (Holo Core + kernel ROCKNIX) para Odin 3/RP5 ----------
# Interesa su release (Odin 3), sus issues abiertos (bugs que nos afectan: p. ej. el ACD de la
# GPU, issue #3) y la fecha del ultimo commit. Ver docs/HOLODOR-HALLAZGOS.md.
holodor_line() {
  timeout 50 python3 - <<'PY' 2>/dev/null || echo "HOLODOR: sin datos (red)"
import json, urllib.request
UA = {"User-Agent": "pocknix-upstream-check", "Accept": "application/vnd.github+json"}
def get(u):
    req = urllib.request.Request(u, headers=UA)
    return json.load(urllib.request.urlopen(req, timeout=20))
try:
    rel = get("https://api.github.com/repos/transentient/holodor/releases?per_page=10")
    iss = get("https://api.github.com/repos/transentient/holodor/issues?state=open&per_page=10&sort=updated&direction=desc")
    com = get("https://api.github.com/repos/transentient/holodor/commits?per_page=1")
except Exception:
    print("HOLODOR: sin datos (API)"); raise SystemExit
od = [r for r in rel if "rp5" not in str(r.get("tag_name", "")).lower()] or rel
r = od[0] if od else {}
issues = [i for i in iss if "pull_request" not in i]
last_commit = (com[0]["commit"]["author"]["date"][:10] if com else "?")
extra = ""
if issues:
    i0 = issues[0]
    extra = " | ultimo: #%s %s (%s)" % (i0["number"], i0["title"][:70], i0["updated_at"][:10])
print("HOLODOR: release %s (%s) | issues abiertos=%d | ultimo commit %s%s" % (
    r.get("tag_name", "?"), (r.get("published_at") or "")[:10], len(issues), last_commit, extra))
PY
}

HOLODOR_LINE="$(holodor_line)"

# --- Nova-Deck: otro SteamOS para Snapdragon (Odin 3) --------------------------------
# Su DTS y su pila de parches son referencia directa (audio DP, display, GPU).
# Ver docs/NOVA-DECK-HALLAZGOS.md.
novadeck_line() {
  timeout 50 python3 - <<'PY' 2>/dev/null || echo "NOVADECK: sin datos (red)"
import json, urllib.request
UA = {"User-Agent": "pocknix-upstream-check", "Accept": "application/vnd.github+json"}
def get(u):
    req = urllib.request.Request(u, headers=UA)
    return json.load(urllib.request.urlopen(req, timeout=20))
try:
    rel = get("https://api.github.com/repos/Nova-Deck/os-build/releases?per_page=1")
    iss = get("https://api.github.com/repos/Nova-Deck/os-build/issues?state=open&per_page=100")
    com = get("https://api.github.com/repos/Nova-Deck/os-build/commits?per_page=1")
except Exception:
    print("NOVADECK: sin datos (API)"); raise SystemExit
r = rel[0] if rel else {}
issues = [i for i in iss if "pull_request" not in i]
last = com[0]["commit"]["author"]["date"][:10] if com else "?"
print("NOVADECK: release %s (%s) | issues abiertos=%d | ultimo commit %s" % (
    r.get("tag_name", "?"), (r.get("published_at") or "")[:10], len(issues), last))
PY
}

NOVADECK_LINE="$(novadeck_line)"

MAKO_LINE="$(mako_line)"

RAW="$(mktemp)"
"${HERE}/check-upstream.sh" --repo "${REPO}" > "${RAW}" 2>&1 || true

# Huella: solo las lineas que implican una decision (versiones marcadas, parches que
# faltan, resumen). Asi "novedad" = algo que merece mirarse, no ruido de commits.
fp_now="$( { grep -aE '(<<<|ACTUALIZAR|FALTAN|^ +- |Resumen:)' "${RAW}"; printf '%s\n' "${HOOANDEE_LINES}"; printf '%s\n' "${MAKO_LINE}"; printf '%s\n' "${HOLODOR_LINE}"; printf '%s\n' "${NOVADECK_LINE}"; } | sed -E 's/[[:space:]]+/ /g' | sort -u )"

day="$(date +%F)"
if [ -f "${OUTDIR}/last-fingerprint.txt" ]; then
  novedades="$(comm -13 "${OUTDIR}/last-fingerprint.txt" <(printf '%s\n' "${fp_now}"))"
else
  novedades="(primera ejecucion: se toma todo como referencia)"
fi

{
  echo "# Informe upstream ${day}"
  echo
  echo "## Novedades respecto a la ejecucion anterior"
  if [ -n "${novedades}" ]; then printf '%s\n' "${novedades}"; else echo "(sin novedades)"; fi
  echo
  echo "## Hooandee (plugins)"
  printf '%s\n' "${HOOANDEE_LINES}"
  echo
  echo "## MAKO (seguimiento ARM)"
  printf '%s\n' "${MAKO_LINE}"
  echo "  (aarch64=SI significa que la release ya trae binarios ARM: avisar y probar)"
  echo
  echo "## Holodor (proyecto hermano: Holo Core + kernel ROCKNIX)"
  printf '%s\n' "${HOLODOR_LINE}"
  echo "  (sus bugs de kernel/GPU nos afectan; ver docs/HOLODOR-HALLAZGOS.md)"
  echo
  echo "## Nova-Deck (SteamOS para Snapdragon; referencia de DTS/parches)"
  printf '%s\n' "${NOVADECK_LINE}"
  echo "  (ver docs/NOVA-DECK-HALLAZGOS.md: audio DP, display, GPU)"
  echo
  echo "## Informe completo"
  cat "${RAW}"
} > "${OUTDIR}/${day}.txt"

printf '%s\n' "${fp_now}" > "${OUTDIR}/last-fingerprint.txt"
ln -sfn "${OUTDIR}/${day}.txt" "${OUTDIR}/latest.txt"
find "${OUTDIR}" -maxdepth 1 -name '20??-??-??.txt' -mtime +90 -delete 2>/dev/null || true
rm -f "${RAW}"

# stdout -> journal: solo el bloque de novedades
awk '/^## Novedades/{f=1;next} /^## Informe completo/{f=0} f' "${OUTDIR}/${day}.txt" | sed '/^[[:space:]]*$/d'
echo "informe: ${OUTDIR}/${day}.txt"
