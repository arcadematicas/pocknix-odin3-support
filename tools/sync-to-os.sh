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

# --- the SoC packages our branch was missing entirely ------------------------
# Without these two the image could not rebuild its own kernel or bootloader: it silently kept
# whatever was in the localrepo (a 09-11 kernel package whose modules no longer matched the
# freshly built Image). They came from odin3-pr, which had them all along.
mirror "packages/linux-pocknix-sm8750"      "packages/soc/linux-pocknix-sm8750"
mirror "packages/pocknix-bootloader-sm8750" "packages/soc/pocknix-bootloader-sm8750"

# --- our files that the build copies verbatim into the rootfs ----------------
overlay "overlay" "overlay"

# --- our versions of files that live in upstream's packages ------------------
# pocknix-bsp-common is upstream's device-neutral BSP; we carry newer fan control scripts
# (the "off" fan mode, the [ -f ] guard). Copied in, never deleted.
overlay "packages/pocknix-bsp-common" "packages/shared/pocknix-bsp-common"

# --- kernel patches + DTS ----------------------------------------------------
# kernel/patches/ mirrors the build's kernel/sm8750/patches/ layout (10-mainline, 20-sm8750...).
# Those dirs also hold ROCKNIX's patches, so these are overlays, not mirrors.
overlay "kernel/patches/10-mainline" "kernel/sm8750/patches/10-mainline"
overlay "kernel/patches/20-sm8750"   "kernel/sm8750/patches/20-sm8750"
overlay "kernel/patches/30-version"  "kernel/sm8750/patches/30-version"
overlay "kernel/dts"                 "kernel/sm8750/dts/qcom"

# --- gamescope: our patch + our PKGBUILD -------------------------------------
# packages/gamescope/PKGBUILD is a FULL COPY of the build's, with 0009 added to source=() and
# prepare(). It is an override: if upstream changes its gamescope PKGBUILD, this copy has to be
# re-merged (the check will NOT notice that, only that the two files match).
overlay "packages/gamescope" "packages/soc/gamescope"

# --- NOT synced (needs manual work — see the note below) ---------------------
# kernel/patches is an OVERLAY: a patch we REMOVE from the centre is NOT removed from the build.
# If you retire a patch, delete it in pocknix-os too (or the image keeps applying it).

echo
if [ "${DRY}" = 1 ]; then
  echo "dry run — nothing written."
else
  echo "sync done. Verify with: tools/check-sync.sh"
fi
