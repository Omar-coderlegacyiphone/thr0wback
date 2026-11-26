#!/usr/bin/env bash
#
# Patch the decrypted bootchain so a tethered limera1n boot will accept our
# images, and set boot-args. Runs on the Linux HOST, with the phone's boot
# driven over USB — nothing here is written to the phone's NAND.
#
#   ./scripts/30-patch-boot.sh [DEVICE] [BUILD]
#
# Input : work/<device>_<build>/dec/{iBSS,iBEC}.bin   (from 20-decrypt.sh)
# Output: work/<device>_<build>/patched/{iBSS,iBEC}.img3
#
# ─────────────────────────────────────────────────────────────────────────────
# NOT YET VERIFIED ON THIS DEVICE/VERSION.
#
# iBoot32Patcher targets iOS 5–9-era iBoots. The iPhone 4 iOS 4.0 iBoot is
# 889.24, which may be too old for its pattern finders. If the patch step below
# fails to find a pattern, that's expected for 4.0 — use the redsn0w fallback
# (see docs/patching.md). This script is correct in shape; the 4.0 baseline is
# the open question, and it must be confirmed by an actual tethered boot.
# ─────────────────────────────────────────────────────────────────────────────

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DEVICE="${1:-iPhone3,1}"
BUILD="${2:-8A293}"
WORK="${REPO_ROOT}/work/${DEVICE}_${BUILD}"
DEC="${WORK}/dec"
OUT="${WORK}/patched"

# Boot-args for the second OS. -v = verbose (so we can read the boot log, which
# is the whole point of the first boots). Add serial=3 if using a serial cable.
BOOT_ARGS="${BOOT_ARGS:--v}"

log()  { printf '\033[1;36m[patch]\033[0m %s\n' "$*"; }
die()  { printf '\033[1;31m[patch]\033[0m %s\n' "$*" >&2; exit 1; }

command -v iBoot32Patcher >/dev/null \
  || die "iBoot32Patcher not on PATH. Run 00-setup-linux.sh and: export PATH=\"${REPO_ROOT}/tools/bin:\$PATH\""
[[ -f "${DEC}/iBSS.bin" && -f "${DEC}/iBEC.bin" ]] \
  || die "Decrypted iBSS/iBEC missing. Run scripts/20-decrypt.sh ${DEVICE} ${BUILD} first."

mkdir -p "$OUT"

# iBSS: patch signature checks so it will load our patched iBEC.
log "Patching iBSS (signature checks)..."
if ! iBoot32Patcher "${DEC}/iBSS.bin" "${OUT}/iBSS.patched" -r; then
  die "iBoot32Patcher failed on iBSS. Likely the 889.24 version gap — see docs/patching.md (redsn0w fallback)."
fi

# iBEC: patch signature checks + inject boot-args.
log "Patching iBEC (signature checks + boot-args: ${BOOT_ARGS})..."
if ! iBoot32Patcher "${DEC}/iBEC.bin" "${OUT}/iBEC.patched" -r -b "${BOOT_ARGS}"; then
  die "iBoot32Patcher failed on iBEC. See docs/patching.md."
fi

log "Patched images:"
ls -la "${OUT}"
cat <<EOF

Next: the patched iBSS/iBEC are booted tethered via limera1n. The boot stage
(kloader / irecovery upload sequence) is scripts/40-boot-tethered.sh, which is
where we confirm whether 889.24 actually took the patches. The kernelcache also
needs its own patches (AMFI / cs_enforcement) before a full userland boot; that
is a separate stage (see docs/patching.md) and is not required just to see how
far the bootchain gets.
EOF
