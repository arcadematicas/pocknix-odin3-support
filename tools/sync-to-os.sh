#!/bin/bash
# sync-to-os.sh — copy OUR content (this repo = THE CENTER) into the pocknix-os build tree.
#
# WHY THIS EXISTS
#   Until 15/09/2026 the fixes lived in two unsynchronised copies: the Odin (applied by hand),
#   this repo, and the pocknix-os build tree. The build only ever reads pocknix-os, so anything
#   that was not there simply never reached the image (the OOBE marker, the power sentinels, the
#   Odin 3 daemons, the adreno GX-collapse patch...). This script makes the copy one-directional
#   and repeatable: edit HERE, run this, build.
#
# USAGE
#   tools/sync-to-os.sh              # apply (idempotent)
#   tools/sync-to-os.sh --dry-run    # show what would change
#   POCKNIX_OS_DIR=/path tools/sync-to-os.sh
#
# The build calls tools/check-sync.sh, which fails if the tree drifted away from the centre.
set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
OS="${POCKNIX_OS_DIR:-${HERE}/../pocknix-os}"
DRY=0
[ "${1:-}" = "--dry-run" ] && DRY=1

[ -d "${OS}" ] || { echo "ERROR: pocknix-os not found at ${OS} (set POCKNIX_OS_DIR)" >&2; exit 1; }

RSYNC=(rsync -a --itemize-changes)
[ "${DRY}" = 1 ] && RSYNC+=(--dry-run)

log() { printf '  %s\n' "$*"; }

# mirror: our directory IS the whole content of the target (it is a package we own outright)
mirror() {
  local src="${HERE}/$1" dst="${OS}/$2"
  [ -d "${src}" ] || { log "SKIP (missing here): $1"; return 0; }
  echo "==> mirror $1 -> $2"
  mkdir -p "${dst}"
  "${RSYNC[@]}" --delete --exclude='.git' "${src}/" "${dst}/" | sed 's/^/    /'
}

# overlay: our files are ADDED into a directory that also holds upstream's files
overlay() {
  local src="${HERE}/$1" dst="${OS}/$2"
  [ -d "${src}" ] || { log "SKIP (missing here): $1"; return 0; }
  echo "==> overlay $1 -> $2"
  mkdir -p "${dst}"
  "${RSYNC[@]}" "${src}/" "${dst}/" | sed 's/^/    /'
}

# --- our own device packages (whole directories) -----------------------------
mirror "packages/pocknix-bsp-sm8750"    "devices/sm8750/packages/pocknix-bsp-sm8750"
mirror "packages/pocknix-device-sm8750" "devices/sm8750/packages/pocknix-device-sm8750"

# --- our versions of files that live in upstream's packages ------------------
# pocknix-bsp-common is upstream's device-neutral BSP; we carry newer fan control scripts
# (the "off" fan mode, the [ -f ] guard). Copied in, never deleted.
overlay "packages/pocknix-bsp-common" "packages/shared/pocknix-bsp-common"

# --- kernel patches + DTS ----------------------------------------------------
# 20-sm8750 also holds the ROCKNIX patches, so this is an overlay, not a mirror.
overlay "kernel/patches" "kernel/sm8750/patches/20-sm8750"
overlay "kernel/dts"     "kernel/sm8750/dts/qcom"

# --- NOT synced (needs manual work — see the note below) ---------------------
# gamescope/patches/0004-fps-limit-atom-persist.patch: copying the file is not enough, the
# gamescope PKGBUILD has to reference it in source=() and apply it. Left out on purpose so the
# sync never half-lands a patch that would silently not be applied.
# kernel/patches is an OVERLAY: a patch we REMOVE from the centre is NOT removed from the build.
# If you retire a patch, delete it in pocknix-os too (or the image keeps applying it).

echo
if [ "${DRY}" = 1 ]; then
  echo "dry run — nothing written."
else
  echo "sync done. Verify with: tools/check-sync.sh"
fi
