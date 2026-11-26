#!/usr/bin/env bash
#
# Decrypt the boot-critical images from a fetched IPSW.
#
#   ./scripts/20-decrypt.sh [DEVICE] [BUILD]
#   ./scripts/20-decrypt.sh iPhone3,1 8A293     # default
#
# Pulls the per-image key/IV (and each image's path inside the IPSW) from the
# ipsw.me keys API, extracts the images, and decrypts them with img3.py.
# Output goes to work/<device>_<build>/dec/.
#
# Decrypts only — no signatures are touched here. That's the next stage.

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DEVICE="${1:-iPhone3,1}"
BUILD="${2:-8A293}"
KEYS_API="https://api.ipsw.me/v4/keys/ipsw/${DEVICE}/${BUILD}"

# Boot-critical images to decrypt (names match the "image" field in the API).
IMAGES=(iBSS iBEC LLB iBoot Kernelcache DeviceTree)

log()  { printf '\033[1;36m[decrypt]\033[0m %s\n' "$*"; }
die()  { printf '\033[1;31m[decrypt]\033[0m %s\n' "$*" >&2; exit 1; }

FW_DIR="${REPO_ROOT}/firmware/${DEVICE}_${BUILD}"
IPSW="$(ls "${FW_DIR}"/*.ipsw 2>/dev/null | head -1)" \
  || die "No IPSW in ${FW_DIR}. Run scripts/10-fetch-ipsw.sh ${DEVICE} ${BUILD} first."
[[ -f "$IPSW" ]] || die "No IPSW in ${FW_DIR}. Run 10-fetch-ipsw.sh first."

WORK="${REPO_ROOT}/work/${DEVICE}_${BUILD}"
mkdir -p "${WORK}/img" "${WORK}/dec"
KEYS_JSON="${WORK}/keys.json"

log "Fetching keys for ${DEVICE} ${BUILD}..."
curl -fsSL "$KEYS_API" -o "$KEYS_JSON" || die "keys lookup failed (${KEYS_API})"

# For an image name, print "<path-in-ipsw>\t<key>\t<iv>".
lookup() {
  IMG="$1" python3 -I -c '
import json, os, sys
d = json.load(open(sys.argv[1]))
img = os.environ["IMG"]
for k in d["keys"]:
    if k["image"] == img:
        if k.get("key") in (None, "", "0") or k.get("iv") in (None, "", "0"):
            sys.stderr.write("image %s is not encrypted / no key\n" % img); sys.exit(2)
        print("%s\t%s\t%s" % (k["filename"], k["key"], k["iv"])); sys.exit(0)
sys.stderr.write("image %s not in key set\n" % img); sys.exit(1)' "$KEYS_JSON"
}

for img in "${IMAGES[@]}"; do
  if ! line="$(lookup "$img" 2>/dev/null)"; then
    log "skip ${img} (not in key set for this build)"; continue
  fi
  path="$(cut -f1 <<<"$line")"; key="$(cut -f2 <<<"$line")"; iv="$(cut -f3 <<<"$line")"
  base="$(basename "$path")"
  log "extract + decrypt ${img} (${base})"
  unzip -o -j "$IPSW" "$path" -d "${WORK}/img" >/dev/null \
    || die "could not extract ${path} from IPSW"
  python3 -I "${REPO_ROOT}/scripts/img3.py" decrypt "${WORK}/img/${base}" \
    --key "$key" --iv "$iv" -o "${WORK}/dec/${img}.bin"
done

log "Decrypted images in ${WORK}/dec/:"
ls -la "${WORK}/dec/"
