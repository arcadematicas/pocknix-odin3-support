#!/bin/bash
# check-upstream-packages.sh — ¿vamos por detrás de pocknix (upstream) en paquetes?
#
# Compara los paquetes de packages/shared/ entre NUESTRO arbol de compilacion y el ref de upstream
# (por defecto origin/main) y lista solo las diferencias:
#   NUEVO          — upstream lo tiene y nosotros no
#   solo nuestro   — no esta en upstream
#   DESFASADO?     — existe en los dos, pero cambia pkgver/pkgrel (ojo: pkgver dinamicos -> mirar)
# Solo LEE (git ls-tree / git show / grep). No toca nada.
#
# Uso: tools/check-upstream-packages.sh [ruta-al-arbol]   (UPSTREAM_REF=origin/main por defecto)
set -u
OS="${1:-$HOME/pocknix-odin3-project/pocknix-os}"
UP="${UPSTREAM_REF:-origin/main}"
cd "$OS" 2>/dev/null || { echo "!! no existe el arbol: $OS"; exit 1; }
git rev-parse --verify --quiet "$UP" >/dev/null || { echo "!! falta el ref '$UP' (haz: git fetch origin)"; exit 1; }

echo "arbol    : $OS"
echo "upstream : $UP  ($(git log --oneline -1 "$UP" | cut -c1-58))"
echo

up=$(git ls-tree -r --name-only "$UP" -- packages/shared | sed -n 's|^packages/shared/\([^/]*\)/PKGBUILD$|\1|p' | sort -u)
our=$(find packages/shared -mindepth 2 -maxdepth 2 -name PKGBUILD 2>/dev/null | sed -n 's|^packages/shared/\([^/]*\)/PKGBUILD$|\1|p' | sort -u)
v_our() { grep -hE '^pkgver=|^pkgrel=' "packages/shared/$1/PKGBUILD" 2>/dev/null | paste -sd. -; }
v_up()  { git show "$UP:packages/shared/$1/PKGBUILD" 2>/dev/null | grep -hE '^pkgver=|^pkgrel=' | paste -sd. -; }

printf '%-38s %-24s %-24s %s\n' PAQUETE NUESTRO UPSTREAM ESTADO
n=0; d=0; s=0
for p in $(printf '%s\n' $our $up | sort -u); do
  a=$(v_our "$p"); b=$(v_up "$p")
  case "${a:-X}|${b:-X}" in
    X|*)  est="NUEVO"; n=$((n+1)) ;;
    *|X)  est="solo nuestro"; s=$((s+1)) ;;
  esac
  [ -n "${a:-}" ] && [ -n "${b:-}" ] && { [ "$a" = "$b" ] && continue; est="DESFASADO?"; d=$((d+1)); }
  printf '%-38s %-24s %-24s %s\n' "$p" "${a:--}" "${b:--}" "$est"
done
echo
echo "resumen: $n nuevo(s) de upstream | $d desfasado(s) | $s solo nuestro(s)"
echo "total: upstream $(printf '%s\n' $up | grep -c .)  |  nosotros $(printf '%s\n' $our | grep -c .)"
