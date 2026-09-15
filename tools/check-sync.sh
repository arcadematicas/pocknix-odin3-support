#!/bin/bash
# check-sync.sh — fail if the pocknix-os build tree drifted away from this repo (THE CENTER).
#
# The build calls this, so a stale build tree cannot silently produce an image missing our
# fixes. Exit codes: 0 = in sync, 1 = drift (run tools/sync-to-os.sh), 2 = cannot check.
#
# USAGE
#   tools/check-sync.sh
#   POCKNIX_OS_DIR=/path tools/check-sync.sh
set -uo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
OS="${POCKNIX_OS_DIR:-${HERE}/../pocknix-os}"

if [ ! -d "${OS}" ]; then
  echo "check-sync: pocknix-os not found at ${OS}" >&2
  exit 2
fi

drift=0
missing=0

# compare every file we own against its counterpart in the build tree
cmp_tree() {
  local src="$1" dst="$2" rel
  [ -d "${src}" ] || return 0
  while IFS= read -r -d '' f; do
    rel="${f#${src}/}"
    if [ ! -e "${dst}/${rel}" ]; then
      echo "  MISSING  ${dst#${OS}/}/${rel}"
      missing=$((missing + 1))
    elif ! cmp -s "${f}" "${dst}/${rel}"; then
      echo "  DIFFERS  ${dst#${OS}/}/${rel}"
      drift=$((drift + 1))
    fi
  done < <(find "${src}" -type f -print0)
}

echo "check-sync: comparing ${HERE} -> ${OS}"
cmp_tree "${HERE}/packages/pocknix-bsp-sm8750"    "${OS}/devices/sm8750/packages/pocknix-bsp-sm8750"
cmp_tree "${HERE}/packages/pocknix-device-sm8750" "${OS}/devices/sm8750/packages/pocknix-device-sm8750"
cmp_tree "${HERE}/packages/pocknix-bsp-common"    "${OS}/packages/shared/pocknix-bsp-common"
cmp_tree "${HERE}/kernel/patches/10-mainline"      "${OS}/kernel/sm8750/patches/10-mainline"
cmp_tree "${HERE}/kernel/patches/20-sm8750"        "${OS}/kernel/sm8750/patches/20-sm8750"
cmp_tree "${HERE}/kernel/dts"                     "${OS}/kernel/sm8750/dts/qcom"
cmp_tree "${HERE}/packages/gamescope"             "${OS}/packages/soc/gamescope"

if [ "${missing}" -eq 0 ] && [ "${drift}" -eq 0 ]; then
  echo "check-sync: OK — the build tree matches the centre."
  exit 0
fi

cat >&2 <<EOF

check-sync: FAILED — ${missing} missing, ${drift} differing file(s).
The build tree is NOT what this repo says it should be, so an image built from it would be
missing our fixes. Run:

    tools/sync-to-os.sh

EOF
exit 1
