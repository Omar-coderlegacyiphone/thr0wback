#!/usr/bin/env bash
#
# Tethered-boot the patched bootchain on the phone over USB (limera1n / A4).
# Runs on the Linux HOST. Nothing is written to NAND — every image lives in RAM
# for this one boot, and a reboot returns to the untethered 4.1 install.
#
#   ./scripts/40-boot-tethered.sh [DEVICE] [BUILD]
#
# ─────────────────────────────────────────────────────────────────────────────
# SKELETON — NOT YET RUN AGAINST A DEVICE.
#
# The command sequence below is the standard limera1n tethered-boot order, but
# the exact image format each stage expects (raw patched vs. re-wrapped IMG3)
# and the right recovery commands for 889.24 can only be pinned down with the
# phone in hand. Treat every step as "confirm on device", and read the verbose
# log the phone prints back.
# ─────────────────────────────────────────────────────────────────────────────

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DEVICE="${1:-iPhone3,1}"
BUILD="${2:-8A293}"
P="${REPO_ROOT}/work/${DEVICE}_${BUILD}/patched"
D="${REPO_ROOT}/work/${DEVICE}_${BUILD}/dec"

log()  { printf '\033[1;36m[boot]\033[0m %s\n' "$*"; }
die()  { printf '\033[1;31m[boot]\033[0m %s\n' "$*" >&2; exit 1; }

command -v irecovery >/dev/null \
  || die "irecovery not found (libirecovery). Run 00-setup-linux.sh."

# 1. The phone must already be in *pwned* DFU (limera1n bootrom exploit applied).
#    On Linux that's axi0mX's ipwndfu:  python2 ipwndfu -p
#    We only check that a device is visible; pwned-DFU state is confirmed by
#    whether the patched iBSS is accepted below.
MODE="$(irecovery -m 2>/dev/null || true)"
[[ -n "$MODE" ]] || die "No device on USB. Put the phone in pwned DFU first (ipwndfu -p), then rerun."
log "Device mode: ${MODE}"

[[ -f "${P}/iBSS.patched" && -f "${P}/iBEC.patched" ]] \
  || die "Patched iBSS/iBEC missing. Run scripts/30-patch-boot.sh ${DEVICE} ${BUILD} first."

# 2. Upload the bootchain. If the patched iBSS is rejected here, pwned DFU is not
#    active or the 889 patch didn't take (see docs/patching.md).
log "Uploading patched iBSS..."; irecovery -f "${P}/iBSS.patched"
log "Uploading patched iBEC..."; irecovery -f "${P}/iBEC.patched"

# 3. DeviceTree + kernelcache, then boot. (These may need IMG3 re-wrapping —
#    confirm on device.) boot-args were patched into iBEC in stage 30.
if [[ -f "${D}/DeviceTree.bin" ]]; then
  log "Uploading DeviceTree..."; irecovery -f "${D}/DeviceTree.bin"; irecovery -c "devicetree"
fi
[[ -f "${D}/Kernelcache.bin" ]] || die "Decrypted kernelcache missing (run 20-decrypt.sh)."
log "Uploading kernelcache..."; irecovery -f "${D}/Kernelcache.bin"

log "Booting (bootx). Watch the phone's verbose log..."
irecovery -c "bootx"

cat <<EOF

If the Apple logo appears and the verbose log scrolls: the bootchain took.
If it hangs at the logo: note the last log line — that's the first interface the
kernel/userland couldn't bring up, and the starting point for the hybrid work.
Reboot (hold Power+Home) to return to untethered 4.1.
EOF
