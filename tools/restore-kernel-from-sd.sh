#!/bin/bash
# restore-kernel-from-sd.sh — rescata la Odin restaurando el KERNEL desde una SD
# montada en el PC. Uso: tools/restore-kernel-from-sd.sh [ruta-de-la-SD]
# Por defecto busca el montaje que contenga KERNEL.bak-20260918-*.
set -euo pipefail
SD="${1:-}"
if [ -z "$SD" ]; then
    for d in /run/media/fransis/*/; do
        if ls "$d"/KERNEL.bak-20260918-* >/dev/null 2>&1; then SD="$d"; break; fi
    done
fi
[ -n "$SD" ] && [ -d "$SD" ] || { echo "no encuentro una SD con KERNEL.bak-20260918-*" >&2; echo "uso: $0 /run/media/fransis/XXXX" >&2; exit 1; }
echo "SD: $SD"
ls -la "$SD"/KERNEL.bak-20260918-* 2>/dev/null | sed 's/^/  backup: /'
BAK="$(ls -t "$SD"/KERNEL.bak-20260918-* 2>/dev/null | head -1)"
echo "  KERNEL actual: $(ls -la "$SD/KERNEL" 2>/dev/null | awk '{print $5" bytes"}' )"
cp -v "$BAK" "$SD/KERNEL"
sync
echo "  restaurado. KERNEL ahora: $(ls -la "$SD/KERNEL" | awk '{print $5" bytes"}')"
echo "  -> expulsa la SD, ponla en la Odin y enciende."
