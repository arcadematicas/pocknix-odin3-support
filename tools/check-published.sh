#!/bin/bash
# check-published.sh — ¿está TODO lo nuestro publicado en el repositorio?
#
# POR QUE EXISTE
#   Un paquete puede estar perfecto en el centro y en el arbol de build y aun asi NO llegar a las
#   consolas: pacman solo ve una actualizacion si (a) sube pkgver/pkgrel y (b) esa version esta
#   PUBLICADA en el repo. Ya nos ha pasado: gamescope (el arreglo del HDR/QAM), fex-emu,
#   deckstation-arm, pocknix-decky, pocknix-vk-valve y toda la pila de sensores se quedaron sin
#   publicar. Este script es el recordatorio: un comando antes de dar algo por terminado.
#
# USO
#   tools/check-published.sh            # informe; exit 1 si hay deuda (vale para hooks/CI)
#   tools/check-published.sh --quiet    # solo la tabla
#
# DONDE PUBLICA CADA COSA (los repos que consumen las consolas, ver /etc/pacman.conf de la Odin)
#   [pocknix]        -> <bucket>/sm8750   los del SoC (gamescope, fex, kernel, BSP, firmware...)
#   [pocknix-shared] -> <bucket>/shared   neutrales de SoC (herramientas, emuladores, capas...)
#   [pocknix-base]   -> <bucket>/base     base congelada
#   Flujo: make packages -> make stage-shared / make stage -> make publish-shared / publish
set -u

BUCKET="${POCKNIX_BUCKET_URL:-https://pub-fd47305874674bf597b27eb7f880e73b.r2.dev}"
CENTRO="${POCKNIX_CENTRO:-$(cd "$(dirname "$0")/.." && pwd)}"
ARBOL="${POCKNIX_OS_DIR:-$(cd "$CENTRO/../pocknix-os" 2>/dev/null && pwd || echo "")}"
QUIET=0
[ "${1:-}" = "--quiet" ] && QUIET=1
say() { [ "$QUIET" = 1 ] || echo "$@"; }

# Paquetes que NO se publican a proposito: los 4 emuladores de pocknix-emulation-full (sus fuentes
# no existen o no se pueden construir con qemu; van como optdepends "bring your own").
# Ver docs/CIERRE-20261006-REPOSICION-PAQUETES.md
EXCLUIDOS="armsx2-bin rpcs3-bin xemu-bin vita3k-bin"

tmp="$(mktemp -d)"; trap 'rm -rf "$tmp"' EXIT

# --- 1) lo publicado ------------------------------------------------------------------------
: > "$tmp/pub.txt"
for R in "sm8750/pocknix.db.tar.gz" "shared/pocknix-shared.db.tar.gz" "base/pocknix-base.db.tar.gz"; do
	dir="${R%%/*}"
	if curl -sfL --max-time 60 -o "$tmp/db.tar.gz" "$BUCKET/$R"; then
		n="$(tar -tzf "$tmp/db.tar.gz" 2>/dev/null | sed 's|/$||' | awk -F/ 'NF{print $1}' | sort -u | wc -l | tr -d ' ')"
		tar -tzf "$tmp/db.tar.gz" 2>/dev/null | sed 's|/$||' | awk -F/ 'NF{print $1}' >> "$tmp/pub.txt"
		say "  [$dir]  $n paquetes"
	else
		echo "check-published: no puedo bajar $BUCKET/$R (¿red?)" >&2
	fi
done
sort -u -o "$tmp/pub.txt" "$tmp/pub.txt"
# los nombres publicados (sin version), para saber que paquetes son "nuestros"
sed -E 's/-[0-9][^-]*-[^-]+$//' "$tmp/pub.txt" | sort -u > "$tmp/pubnames.txt"
say "  paquetes publicados:      $(wc -l < "$tmp/pub.txt" | tr -d ' ')"

# --- 2) version completa de un PKGBUILD (con epoch, sin variables sin resolver) --------------
pkgversion() {
	local f="$1" e v r
	e="$(grep -m1 -E '^epoch=' "$f" | cut -d= -f2 | tr -d "\"'")"
	v="$(grep -m1 -E '^pkgver=' "$f" | cut -d= -f2 | tr -d "\"'")"
	r="$(grep -m1 -E '^pkgrel=' "$f" | cut -d= -f2 | tr -d "\"'")"
	[ -z "$v" ] && return 1
	case "$v$r" in *'$'*) return 1 ;; esac
	if [ -n "$e" ] && [ "$e" != "0" ]; then printf '%s:%s-%s' "$e" "$v" "$r"; else printf '%s-%s' "$v" "$r"; fi
}

# --- 3) comparar ----------------------------------------------------------------------------
: > "$tmp/informe.txt"
revisados=0
comparar() {   # $1=dir base  $2=etiqueta  $3=1 -> solo paquetes "nuestros" (ya publicados)
	local base="$1" etiqueta="$2" solo_nuestros="${3:-0}" f p v pv name otra
	[ -n "$base" ] && [ -d "$base" ] || return 0
	while IFS= read -r f; do
		p="$(basename "$(dirname "$f")")"
		case " $EXCLUIDOS " in *" $p "*) continue ;; esac
		[ "$solo_nuestros" = 1 ] && ! grep -qx "$p" "$tmp/pubnames.txt" && continue
		v="$(pkgversion "$f")" || continue
		pv="$p-$v"
		revisados=$((revisados + 1))
		if ! grep -qx "$pv" "$tmp/pub.txt"; then
			otra="$(grep -E "^${p}-" "$tmp/pub.txt" | tr '\n' ' ')"
			printf '%s|%s|%s\n' "$pv" "$etiqueta" "$otra" >> "$tmp/informe.txt"
		fi
	done < <(find "$base" -name PKGBUILD -not -path '*/build/*' -not -path '*/src/*' 2>/dev/null | sort)
}

comparar "$CENTRO/packages" "centro" 0
if [ -n "$ARBOL" ] && [ -d "$ARBOL" ]; then
	comparar "$ARBOL/packages" "arbol" 1
else
	say "  (aviso: no encuentro el arbol; define POCKNIX_OS_DIR si no está en ../pocknix-os)" >&2
fi

# --- 4) informe -----------------------------------------------------------------------------
deuda="$(grep -c . "$tmp/informe.txt" 2>/dev/null || echo 0)"
if [ "$deuda" -eq 0 ]; then
	say ""
	say "check-published: OK ✓ — los $revisados paquetes revisados están publicados."
	exit 0
fi

say ""
say "check-published: DEUDA ✗ — $deuda de $revisados paquetes sin publicar (o a otra versión):"
say ""
printf '  %-44s %-7s %s\n' "NUESTRA VERSIÓN" "ORIGEN" "PUBLICADO"
while IFS='|' read -r pv etiqueta otra; do
	printf '  %-44s %-7s %s\n' "$pv" "$etiqueta" "${otra:-nunca}"
done < "$tmp/informe.txt" | sort -u
say ""
say "Publicar: subir pkgrel -> tools/sync-to-os.sh -> make packages PKG=\"...\" ->"
say "          make stage-shared / make stage -> make publish-shared / publish"
say "Detalle del flujo: docs/PUBLICACION-PAQUETES.md"
exit 1
