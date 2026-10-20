#!/usr/bin/env bash
#
# check-upstream.sh — informa (nunca falla) del estado de nuestro árbol
# pocknix para AYN Odin 3 (SM8750) frente a los upstream que seguimos:
#   pocknix (shuuri-labs/pocknix-os), ROCKNIX/distribution,
#   armada-os/armada, kernel.org y holo-packages Deckard.
#
# Salida en español. Sólo INFORMA: siempre termina con exit 0.

set -u
export LC_ALL=C

# Directorio de este script (para localizar check-upstream.waived)
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" 2>/dev/null && pwd)"
WAIVED="$SCRIPT_DIR/check-upstream.waived"

# ---------------------------------------------------------------------------
# Argumentos
# ---------------------------------------------------------------------------
REPO="/home/fransis/pocknix-odin3-project/pocknix-os"
DIAS=21

usage() {
  cat <<EOF
Uso: $0 [opciones]

Opciones:
  --repo DIR    Árbol de build pocknix (default: $REPO)
  --dias N      Ventana de días para la sección de commits (default: $DIAS)
  -h, --help    Esta ayuda

Sólo INFORMA del estado respecto a upstream; nunca modifica nada y siempre
termina con código 0.
EOF
}

while [ $# -gt 0 ]; do
  case "$1" in
    --repo) REPO="${2:-}"; shift 2 ;;
    --dias) DIAS="${2:-}"; shift 2 ;;
    -h|--help) usage; exit 0 ;;
    *) echo "opción desconocida: $1" >&2; usage; exit 0 ;;
  esac
done

# --dias debe ser un entero positivo
case "$DIAS" in
  ''|*[!0-9]*) DIAS=21 ;;
esac

# ---------------------------------------------------------------------------
# Token GitHub (nunca se imprime)
# ---------------------------------------------------------------------------
TOKEN=""
if [ -n "${GITHUB_TOKEN:-}" ]; then
  TOKEN="$GITHUB_TOKEN"
elif [ -n "${GH_TOKEN:-}" ]; then
  TOKEN="$GH_TOKEN"
elif [ -r "$HOME/.config/git/github-token" ]; then
  TOKEN="$(cat "$HOME/.config/git/github-token" 2>/dev/null)"
fi
AUTH=()
[ -n "$TOKEN" ] && AUTH=(-H "Authorization: Bearer $TOKEN")

# ---------------------------------------------------------------------------
# Utilidades de red
# ---------------------------------------------------------------------------
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

gh_rate_limited=0

# curl a la API de GitHub: devuelve el código HTTP y guarda el cuerpo
curl_gh() {
  local url="$1" out="$2" code
  code=$(curl -sS --max-time 40 "${AUTH[@]}" -o "$out" -w "%{http_code}" "$url" 2>/dev/null)
  if [ "$code" = "403" ] || [ "$code" = "429" ]; then gh_rate_limited=1; fi
  printf '%s' "$code"
}

# curl a un raw (github raw, kernel.org, deckard): guarda el cuerpo, devuelve código
curl_raw() {
  local url="$1" out="$2"
  curl -sS --max-time 40 -o "$out" -w "%{http_code}" "$url" 2>/dev/null
}

PKGS=(mesa pocknix-turnip-arm mangohud fex-emu gamescope inputplumber)

# ---------------------------------------------------------------------------
# Datos locales
# ---------------------------------------------------------------------------
# deckard-vulkan-layers: NO lo empaquetamos (se instala directo del repo Deckard).
# "Nuestra" versión = la instalada en la Odin; se mantiene a mano cuando se sube
# (ver docs/REVISION-UPSTREAM-*.md). p.ej. 20261001.1-4.
VK_LAYERS_OUR="?"
  if [ -f "${REPO}/packages/shared/pocknix-vk-valve/PKGBUILD" ]; then
    VK_LAYERS_OUR="$(grep -m1 '^pkgver=' "${REPO}/packages/shared/pocknix-vk-valve/PKGBUILD" | cut -d= -f2-)"
  elif [ -f "${REPO}/packages/soc/pocknix-vk-valve/PKGBUILD" ]; then
    VK_LAYERS_OUR="$(grep -m1 '^pkgver=' "${REPO}/packages/soc/pocknix-vk-valve/PKGBUILD" | cut -d= -f2-)"
  fi

# kernel.conf -> KERNEL_VERSION
grep -m1 '^: "${KERNEL_VERSION:=' "$REPO/kernel/sm8750/kernel.conf" 2>/dev/null \
  | sed 's/^.*KERNEL_VERSION:=//; s/}".*$//' > "$TMP/our_kernel.txt"
[ -s "$TMP/our_kernel.txt" ] || echo "?" > "$TMP/our_kernel.txt"

# recuento de parches por subdirectorio + total
: > "$TMP/patch_counts.txt"
total=0
for d in "$REPO"/kernel/sm8750/patches/*/; do
  [ -d "$d" ] || continue
  n=$(ls "$d"*.patch 2>/dev/null | wc -l)
  printf '%s\t%s\n' "$(basename "$d")" "$n" >> "$TMP/patch_counts.txt"
  total=$((total + n))
done
printf '%s\t%s\n' "TOTAL" "$total" >> "$TMP/patch_counts.txt"

# basenames de nuestros parches (activos y deshabilitados)
( cd "$REPO/kernel/sm8750/patches" 2>/dev/null && ls */*.patch 2>/dev/null ) \
  | xargs -r -n1 basename | sort > "$TMP/our_patches.txt"
( cd "$REPO/kernel/sm8750/patches" 2>/dev/null && ls */*.patch.disabled 2>/dev/null ) \
  | xargs -r -n1 basename | sed 's/\.disabled$//' | sort > "$TMP/our_patches_disabled.txt"

# pkgver de nuestros PKGBUILD
: > "$TMP/our_pkg.txt"
for pkg in "${PKGS[@]}"; do
  ver="?"
  for base in "$REPO/packages/soc/$pkg/PKGBUILD" "$REPO/packages/shared/$pkg/PKGBUILD"; do
    if [ -f "$base" ]; then
      v=$(grep -m1 '^pkgver=' "$base" 2>/dev/null | sed 's/^pkgver=//')
      [ -n "$v" ] && ver="$v"
      break
    fi
  done
  if [ "$ver" = "?" ]; then
    d=$(find "$REPO/packages" -maxdepth 2 -type d -name "$pkg" 2>/dev/null | head -n1)
    if [ -n "$d" ] && [ -f "$d/PKGBUILD" ]; then
      v=$(grep -m1 '^pkgver=' "$d/PKGBUILD" 2>/dev/null | sed 's/^pkgver=//')
      [ -n "$v" ] && ver="$v"
    fi
  fi
  printf '%s\t%s\n' "$pkg" "$ver" >> "$TMP/our_pkg.txt"
done

# ---------------------------------------------------------------------------
# Red: kernel.org
# ---------------------------------------------------------------------------
curl_raw "https://www.kernel.org/releases.json" "$TMP/kernel.json" >/dev/null

# ---------------------------------------------------------------------------
# Red: pocknix main (shuuri-labs) — PKGBUILD por paquete
# ---------------------------------------------------------------------------
for pkg in "${PKGS[@]}"; do
  f="$TMP/pocknix_$pkg.txt"
  found=0
  for path in "packages/soc/$pkg/PKGBUILD" "packages/shared/$pkg/PKGBUILD"; do
    code=$(curl_raw "https://raw.githubusercontent.com/shuuri-labs/pocknix-os/main/$path" "$f")
    if [ "$code" = "200" ]; then found=1; break; fi
  done
  [ "$found" = "1" ] || echo "MISSING" > "$f"
done

# ---------------------------------------------------------------------------
# Red: ROCKNIX next — package.mk por paquete
# ---------------------------------------------------------------------------
fetch_rocknix_pkgmk() {
  local pkg="$1" out="$2" p paths=()
  case "$pkg" in
    mesa)              paths=("projects/ROCKNIX/packages/graphics/mesa/package.mk"
                              "projects/ROCKNIX/packages/mesa/package.mk") ;;
    mangohud)          paths=("projects/ROCKNIX/packages/apps/mangohud/package.mk"
                              "projects/ROCKNIX/packages/mangohud/package.mk") ;;
    fex-emu)           paths=("projects/ROCKNIX/packages/compat/fex-emu/package.mk"
                              "projects/ROCKNIX/packages/fex/package.mk") ;;
    gamescope)         paths=("projects/ROCKNIX/packages/apps/gamescope/package.mk"
                              "projects/ROCKNIX/packages/gamescope/package.mk") ;;
    inputplumber)      paths=("projects/ROCKNIX/packages/tools/inputplumber/package.mk"
                              "projects/ROCKNIX/packages/inputplumber/package.mk") ;;
    pocknix-turnip-arm) paths=() ;;   # ROCKNIX usa armsx2-turnip (otro driver)
    *)                 paths=("projects/ROCKNIX/packages/$pkg/package.mk"
                              "projects/ROCKNIX/packages/$pkg/PKG/package.mk") ;;
  esac
  if [ ${#paths[@]} -eq 0 ]; then
    echo "SKIP:sin-equivalente" > "$out"; return
  fi
  for p in "${paths[@]}"; do
    code=$(curl_raw "https://raw.githubusercontent.com/ROCKNIX/distribution/next/$p" "$out")
    if [ "$code" = "200" ]; then return; fi
  done
  echo "MISSING" > "$out"
}
for pkg in "${PKGS[@]}"; do
  fetch_rocknix_pkgmk "$pkg" "$TMP/rocknix_$pkg.txt"
done

# ---------------------------------------------------------------------------
# Red: listados de parches (GitHub API)
# ---------------------------------------------------------------------------
curl_gh "https://api.github.com/repos/ROCKNIX/distribution/contents/projects/ROCKNIX/devices/SM8750/patches/linux?ref=next" \
  "$TMP/rocknix_patches.json" >/dev/null
# armada: usamos su fichero series (y nos limitamos al bloque SM8750) para no
# comparar contra el árbol multi-SoC entero; el listado del directorio queda
# como respaldo por si no encontramos el bloque.
curl_raw "https://raw.githubusercontent.com/armada-os/armada/main/packages/kernel/patches/series" \
  "$TMP/armada_series.txt" >/dev/null
curl_gh "https://api.github.com/repos/armada-os/armada/contents/packages/kernel/patches" \
  "$TMP/armada_patches.json" >/dev/null

# ---------------------------------------------------------------------------
# Red: commits recientes (GitHub API)
# ---------------------------------------------------------------------------
curl_gh "https://api.github.com/repos/shuuri-labs/pocknix-os/commits?sha=main&per_page=100" \
  "$TMP/commits_pocknix.json" >/dev/null
curl_gh "https://api.github.com/repos/ROCKNIX/distribution/commits?sha=next&per_page=100" \
  "$TMP/commits_rocknix.json" >/dev/null
curl_gh "https://api.github.com/repos/armada-os/armada/commits?sha=main&per_page=100" \
  "$TMP/commits_armada.json" >/dev/null

# ---------------------------------------------------------------------------
# Red: Deckard (holo-packages)
# ---------------------------------------------------------------------------
curl_raw "https://holo-packages.steamos.cloud/archlinux-deckard-hotfixes/" "$TMP/deckard.html" >/dev/null

# ---------------------------------------------------------------------------
# Informe (parseo en python3)
# ---------------------------------------------------------------------------
python3 - "$TMP" "$DIAS" "$WAIVED" "$VK_LAYERS_OUR" <<'PYEOF'
import sys, os, re, json, urllib.parse, datetime

tmp = sys.argv[1]
dias = int(sys.argv[2]) if len(sys.argv) > 2 else 21
waived_path = sys.argv[3] if len(sys.argv) > 3 else ''
vk_layers_our = sys.argv[4] if len(sys.argv) > 4 else '?'

PKGS = ['mesa', 'pocknix-turnip-arm', 'mangohud', 'fex-emu', 'gamescope', 'inputplumber']

def rd(name):
    p = os.path.join(tmp, name)
    try:
        with open(p, 'r', encoding='utf-8', errors='replace') as f:
            return f.read()
    except Exception:
        return None

def rdjson(name):
    raw = rd(name)
    if not raw:
        return None
    try:
        return json.loads(raw)
    except Exception:
        return None

def cut(s, n):
    s = s or ''
    return s if len(s) <= n else s[:n-1] + '…'

# ---- comparación de versiones (simple; no es semver perfecto) ----
def verkey(v):
    if v is None:
        return None
    v = v.strip().lstrip('vV')
    if not v:
        return None
    if re.fullmatch(r'[0-9a-f]{40}', v):
        return None  # git sha: no comparable
    ep = 0
    if ':' in v:
        a, b = v.split(':', 1)
        if a.isdigit():
            ep = int(a); v = b
    m = re.search(r'(20\d{2})(\d{2})(\d{2})', v)
    date = int(m.group(1)+m.group(2)+m.group(3)) if m else 0
    m2 = re.match(r'(\d+(?:\.\d+)+)', v)
    dotted = tuple(int(x) for x in m2.group(1).split('.')) if m2 else ()
    nums = tuple(int(x) for x in re.findall(r'\d+', v))
    return (ep, date, dotted, nums)

def cmp_ver(a, b):
    ka, kb = verkey(a), verkey(b)
    if ka is None or kb is None:
        return None
    if ka < kb: return -1
    if ka > kb: return 1
    return 0

def load_waivers(path):
    # tools/check-upstream.waived: líneas "repo|nombre|[motivo]"; '#' comenta.
    out = {}
    if not path:
        return out
    try:
        with open(path, 'r', encoding='utf-8', errors='replace') as f:
            lines = f.read().splitlines()
    except Exception:
        return out
    for line in lines:
        line = line.strip()
        if not line or line.startswith('#'):
            continue
        parts = line.split('|')
        if len(parts) < 2:
            continue
        repo = parts[0].strip()
        name = parts[1].strip()
        motivo = parts[2].strip() if len(parts) > 2 else ''
        if repo and name:
            out.setdefault(repo, []).append((name, motivo))
    return out

waivers = load_waivers(waived_path)

def is_waived(repo, name):
    for wname, _ in waivers.get(repo, []):
        if name == wname or name.startswith(wname):
            return True
    return False

def parse_armada_series(name):
    # devuelve la lista de parches del bloque "# ===== SM8750" o None si no está.
    raw = rd(name)
    if raw is None:
        return None
    block = []
    in_block = False
    for line in raw.splitlines():
        s = line.strip()
        if s.startswith('#') and '=' in s and 'SM8750' in s:
            in_block = True
            continue
        if in_block:
            if s.startswith('#') and '=' in s:
                break
            if not s or s.startswith('#'):
                continue
            nm = s.split('#')[0].strip()
            if nm:
                block.append(nm)
    return block if block else None

def cmp_deckard(dver, our):
    # 1 si deckard es claramente más nuevo, -1 más viejo, 0 igual, None incomparable.
    if not dver or not our or our == '?':
        return None
    kd, ko = verkey(dver), verkey(our)
    if kd is None or ko is None:
        return None
    if kd[1] and ko[1]:
        return (kd[1] > ko[1]) - (kd[1] < ko[1])
    if (kd[1] == 0) and (ko[1] == 0) and kd[2] and ko[2]:
        return (kd[2] > ko[2]) - (kd[2] < ko[2])
    return None

def parse_deckard_date(d):
    for fmt in ('%Y-%b-%d %H:%M', '%Y-%b-%d'):
        try:
            return datetime.datetime.strptime(d.strip(), fmt)
        except Exception:
            pass
    return None

DECKARD_INTEREST = [
    ('mangohud',         r'^mangohud-',                            ['debug']),
    ('linux-72-deckard', r'^linux-72-deckard-',                    ['headers', 'hwdebug', 'debug']),
    ('mesa',             r'^deckard-mesa-linux-aarch64-',          ['assert', 'deps', 'debug']),
    ('vulkan-layers',    r'^deckard-vulkan-layers-linux-aarch64-', ['debug']),
    ('steamos-manager',  r'^steamos-manager-',                     ['debug']),
]

def load_deckard():
    html = rd('deckard.html')
    if html is None:
        return None
    rows = re.findall(r'<a href="([^"]+)"[^>]*>[^<]*</a></td><td class="size">[^<]*</td><td class="date">([^<]*)</td>', html)
    if not rows:
        rows = re.findall(r'href="([^"]+)"[^>]*>.*?</td>.*?<td class="date">([^<]*)</td>', html)
    out = []
    for h, d in rows:
        h = urllib.parse.unquote(h)
        if not h.endswith('.pkg.tar.zst'):
            continue
        out.append((h, d, parse_deckard_date(d)))
    return out

def deckard_best(entries, pat, excl):
    best = None
    for h, d, dt in entries:
        if not re.match(pat, h):
            continue
        if any(e in h for e in excl):
            continue
        if best is None or (dt is not None and (best[0] is None or dt > best[0])):
            best = (dt, h, d)
    return best

def deckard_version(href, pat):
    body = href
    m = re.match(pat, body)
    if m:
        body = body[len(m.group(0)):]
    body = body.replace('-aarch64.pkg.tar.zst', '').replace('-any.pkg.tar.zst', '').replace('-x86_64.pkg.tar.zst', '')
    body = re.sub(r'-\d+(\.\d+)?$', '', body)
    return body

# ---- Deckard: una sola pasada sobre el listado ----
deck_entries = load_deckard()
deck_best = {}
if deck_entries is not None:
    for label, pat, excl in DECKARD_INTEREST:
        b = deckard_best(deck_entries, pat, excl)
        if b:
            deck_best[label] = (deckard_version(b[1], pat), b[2], b[0])

def hdr(t):
    print()
    print(t)
    print('-' * len(t))

# =========================================================
# 1) KERNEL
# =========================================================
hdr('1) KERNEL')
our_kernel = (rd('our_kernel.txt') or '?').strip()
kj = rdjson('kernel.json')
stable = mainline = None
if kj is None:
    print('   kernel.org: sin datos (sin red o error al descargar releases.json)')
else:
    for r in kj.get('releases', []):
        if r.get('moniker') == 'stable':
            stable = r.get('version')
        elif r.get('moniker') == 'mainline':
            mainline = r.get('version')

print('   Nuestra versión : %s' % our_kernel)
print('   kernel.org stable: %s' % (stable or '?'))
print('   kernel.org mainline: %s' % (mainline or '?'))

c = cmp_ver(stable, our_kernel) if stable else None
if c is not None and c > 0:
    print('   >> AVISO: hay estable más nueva: %s' % stable)
elif c == 0:
    print('   (estable == nuestra)')
elif c is not None:
    print('   (vamos por delante de la estable)')

c = cmp_ver(mainline, our_kernel) if mainline else None
if c is not None and c > 0 and mainline != stable:
    print('   >> informativo: mainline %s disponible' % mainline)

# parches
print()
print('   Parches en nuestro árbol:')
total = 0
for line in (rd('patch_counts.txt') or '').splitlines():
    if not line.strip():
        continue
    parts = line.split('\t')
    sub = parts[0]; n = parts[1]
    if sub == 'TOTAL':
        total = int(n)
    else:
        print('     %-18s %s' % (sub + '/', n))
print('     %-18s %s' % ('TOTAL', total))

# =========================================================
# 2) VERSIONES (nuestra vs upstream)
# =========================================================
hdr('2) VERSIONES (nuestra vs upstream)')

our_pkg = {}
for line in (rd('our_pkg.txt') or '').splitlines():
    if '\t' in line:
        k, v = line.split('\t', 1)
        our_pkg[k] = v.strip()

def pocknix_ver(pkg):
    body = rd('pocknix_%s.txt' % pkg)
    if body is None or body.strip() == 'MISSING' or not body.strip():
        return None
    m = re.search(r'(?m)^\s*pkgver\s*=\s*(.*?)\s*$', body)
    return m.group(1).strip() if m else None

def rocknix_ver(pkg):
    body = rd('rocknix_%s.txt' % pkg)
    if body is None or body.strip() in ('MISSING',) or not body.strip():
        return None, None  # (version, nota)
    if body.strip().startswith('SKIP'):
        return None, 'SKIP'
    m = re.search(r'(?m)^\s*PKG_VERSION\s*=\s*["\']([^"\']*)["\'](.*)$', body)
    if not m:
        m = re.search(r'(?m)^\s*PKG_VERSION\s*=\s*(.*?)\s*$', body)
        if not m:
            return None, None
        return m.group(1).strip(), None
    val = m.group(1).strip()
    note = ''
    tail = m.group(2)
    cm = re.search(r'#\s*(v?\d[\w.\-]*)', tail)
    if cm:
        note = cm.group(1)
    return val, note

print()
print('   %-18s %-30s %-30s %-28s %s' % ('Paquete', 'Nuestro', 'pocknix(main)', 'ROCKNIX(next)', 'Estado'))
print('   %s' % ('-' * 132))

resumen_updates = []
for pkg in PKGS:
    ours = our_pkg.get(pkg, '?')
    pn = pocknix_ver(pkg)
    rv, rnote = rocknix_ver(pkg)

    # presentación ROCKNIX
    if rnote == 'SKIP':
        rshow = '?'
    elif rv is None:
        rshow = '?'
    else:
        if verkey(rv) is None:  # git sha
            rshow = cut(rv, 12) + ' (sha)'
            if rnote:
                rshow = rnote + ' (%s)' % cut(rv, 8)
        else:
            rshow = rv
            if rnote:
                rshow = rnote
    pshow = pn if pn is not None else '?'

    # comparación
    flags = []
    if pn is not None:
        c = cmp_ver(pn, ours)
        if c is not None and c > 0:
            flags.append('pocknix')
    if rv is not None and rnote != 'SKIP':
        c = cmp_ver(rv, ours)
        if c is not None and c > 0:
            flags.append('rocknix')

    if flags:
        estado = '<<< ACTUALIZAR (%s)' % '+'.join(flags)
        resumen_updates.append(pkg)
    elif pn is None and (rv is None or rnote == 'SKIP'):
        estado = '?'
    else:
        estado = 'ok'

    print('   %-18s %-30s %-30s %-28s %s' % (pkg, cut(ours, 30), cut(pshow, 30), cut(rshow, 28), estado))

# fila extra: Deckard vulkan-layers (no está en PKGS porque no lo empaquetamos)
vk_d = deck_best.get('vulkan-layers')
if vk_d is not None:
    vk_ver, vk_date, vk_dt = vk_d
    vk_show = '%s (%s)' % (vk_ver, vk_dt.strftime('%Y-%m-%d') if vk_dt else vk_date)
    # No lo empaquetamos: fila solo informativa. Compararlo contra pocknix-vk-valve (que es
    # Turnip/mesa, no las layers) era un falso positivo diario -> nunca se marca ACTUALIZAR.
    estado_vk = 'informativo (no lo empaquetamos)'
else:
    vk_show = '?'
    estado_vk = '?'
print('   %-18s %-30s %-30s %-28s %s' % (
    'deckard-vulkan-layers',
    '-',
    '-',
    cut(vk_show, 28),
    estado_vk))

print('   Nota: pocknix-turnip-arm no tiene equivalente directo en ROCKNIX (usa armsx2-turnip).')
print('   Nota: deckard-vulkan-layers no lo empaquetamos; la fila es informativa y no cuenta como novedad.')

# =========================================================
# 3) PARCHES SM8750
# =========================================================
hdr('3) PARCHES SM8750 (los que seguimos a mano)')

our_active = set(l for l in (rd('our_patches.txt') or '').splitlines() if l.strip())
our_disabled = set(l for l in (rd('our_patches_disabled.txt') or '').splitlines() if l.strip())

def patch_names(name):
    j = rdjson(name)
    if j is None:
        return None
    if isinstance(j, dict):  # error de API
        return []
    return [x['name'] for x in j if isinstance(x, dict) and x.get('type') == 'file']

rocknix_names = patch_names('rocknix_patches.json')
armada_block = parse_armada_series('armada_series.txt')
if armada_block is not None:
    armada_names = armada_block
    armada_scope = 'series → bloque SM8750'
else:
    armada_names = patch_names('armada_patches.json')
    armada_scope = 'packages/kernel/patches (fallback multi-SoC)'

if rocknix_names is None:
    print('   ROCKNIX: sin datos (sin red o error de API).')
else:
    missing_raw = [n for n in rocknix_names if n not in our_active and n not in our_disabled]
    missing_r = [n for n in missing_raw if not is_waived('ROCKNIX', n)]
    waived_r = len(missing_raw) - len(missing_r)
    disabled_r = [n for n in rocknix_names if n in our_disabled and n not in our_active]
    print('   ROCKNIX next (SM8750/patches/linux): %d parches' % len(rocknix_names))
    print('   FALTAN (reales): %d' % len(missing_r))
    for n in sorted(missing_r):
        print('     - %s' % n)
    if waived_r:
        print('   omitidos por waiver: %d (ver check-upstream.waived)' % waived_r)
    if disabled_r:
        print('   Presentes pero DESHABILITADOS (ROCKNIX): %d' % len(disabled_r))
        for n in sorted(disabled_r):
            print('     - %s  (en 90-disabled)' % n)

if armada_names is None:
    print('   armada: sin datos (sin red o error de API).')
else:
    missing_a = [n for n in armada_names if n not in our_active and n not in our_disabled and not is_waived('armada', n)]
    print('   armada (%s): %d parches' % (armada_scope, len(armada_names)))
    print('   FALTAN de armada: %d' % len(missing_a))
    if armada_block is None:
        # fallback multi-SoC: filtramos por palabras clave y limitamos el listado
        print('   (nota: armada es multi-SoC; listado filtrado por palabras clave y máx. 10)')
        KEYW = ['sm8750', 'odin', 'aoss', 'soccp', 'cesta', 'disp']
        filt = [n for n in missing_a if any(k in n.lower() for k in KEYW)]
        shown = sorted(filt)[:10]
        for n in shown:
            print('     - %s' % n)
        if len(filt) > 10:
            print('     (%d más…)' % (len(filt) - 10))
    else:
        for n in sorted(missing_a):
            print('     - %s' % n)

upstream = (set(rocknix_names) if rocknix_names else set()) | (set(armada_names) if armada_names else set())
solo = our_active - upstream
print('   SOLO nuestros: %d (no se listan)' % len(solo))

# =========================================================
# 4) MOVIMIENTO RECIENTE (últimos %d días)
# =========================================================
hdr('4) MOVIMIENTO RECIENTE (últimos %d días)' % dias)

KEYWORDS = ['kernel','mesa','turnip','mangohud','gamescope','fex','steam',
            'suspend','sleep','s2idle','sm8750','odin','input','panel','hdr']

def parse_iso(s):
    try:
        return datetime.datetime.strptime(s, '%Y-%m-%dT%H:%M:%SZ').replace(tzinfo=datetime.timezone.utc)
    except Exception:
        return None

now = datetime.datetime.now(datetime.timezone.utc)
cutoff = now - datetime.timedelta(days=dias)

def commits(name):
    j = rdjson(name)
    if not isinstance(j, list):
        return None
    out = []
    for c in j:
        if not isinstance(c, dict):
            continue
        cc = c.get('commit', {})
        date = cc.get('committer', {}).get('date')
        dt = parse_iso(date) if date else None
        if dt is None or dt < cutoff:
            continue
        msg = (cc.get('message') or '').split('\n')[0]
        sha = (c.get('sha') or '')[:7]
        out.append((dt, sha, msg))
    return out

repos = [
    ('shuuri-labs/pocknix-os (main)', 'commits_pocknix.json'),
    ('ROCKNIX/distribution (next)',   'commits_rocknix.json'),
    ('armada-os/armada (main)',       'commits_armada.json'),
]

for label, fname in repos:
    print()
    print('   %s:' % label)
    cs = commits(fname)
    if cs is None:
        print('     sin datos (sin red o error de API).')
        continue
    cs.sort(key=lambda x: x[0], reverse=True)
    shown = 0
    for dt, sha, msg in cs:
        low = msg.lower()
        if not any(k in low for k in KEYWORDS):
            continue
        print('     %s  %s  %s' % (dt.strftime('%Y-%m-%d'), sha, cut(msg, 100)))
        shown += 1
        if shown >= 8:
            break
    if shown == 0:
        print('     (sin commits relevantes en la ventana)')

# =========================================================
# 5) DECKARD (rápido)
# =========================================================
hdr('5) DECKARD (holo-packages)')

if deck_entries is None:
    print('   sin datos (sin red o error al descargar el listado).')
else:
    print('   Paquete             versión más nueva (fecha)')
    print('   %s' % ('-' * 60))
    for label, pat, excl in DECKARD_INTEREST:
        if label not in deck_best:
            print('   %-19s ?' % label)
            continue
        vk_ver, vk_date, vk_dt = deck_best[label]
        d = vk_dt.strftime('%Y-%m-%d') if vk_dt else vk_date
        print('   %-19s %s (%s)' % (label, vk_ver, d))

# =========================================================
# Resumen
# =========================================================
print()
kernel_msg = 'al día (%s)' % our_kernel
if stable and cmp_ver(stable, our_kernel) is not None and cmp_ver(stable, our_kernel) > 0:
    kernel_msg = 'hay estable nueva %s' % stable
if mainline and cmp_ver(mainline, our_kernel) is not None and cmp_ver(mainline, our_kernel) > 0:
    kernel_msg += '; mainline %s disponible' % mainline

ver_msg = ', '.join(resumen_updates) if resumen_updates else 'ninguna'
mr = len(missing_r) if rocknix_names is not None else '?'
ma = len(missing_a) if armada_names is not None else '?'

# candidatos de Deckard (vulkan-layers/mesa/mangohud más nuevos que lo nuestro)
deck_candidates = []
if deck_entries is not None:
    our_deck = {
        'vulkan-layers': vk_layers_our,
        'mesa': our_pkg.get('mesa', '?'),
        'mangohud': our_pkg.get('mangohud', '?'),
    }
    # 'vulkan-layers' queda fuera: no lo empaquetamos (y our_deck['vulkan-layers'] es la
    # version de pocknix-vk-valve, que es mesa -> comparar daba un falso positivo).
    for label in ('mesa', 'mangohud'):
        b = deck_best.get(label)
        if not b:
            continue
        c = cmp_deckard(b[0], our_deck.get(label, '?'))
        if c is not None and c > 0:
            deck_candidates.append(label)
deck_msg = ', '.join(deck_candidates) if deck_candidates else 'ninguno'

print('Resumen: kernel: %s | versiones a actualizar: %s | parches que faltan: ROCKNIX=%s, armada=%s | candidatos Deckard: %s' %
      (kernel_msg, ver_msg, mr, ma, deck_msg))
PYEOF

exit 0
