#!/usr/bin/env bash
#
# Fetch and verify the stock IPSWs listed in config/targets.json.
#
#   ./scripts/10-fetch-ipsw.sh                 # fetch all unique firmwares
#   ./scripts/10-fetch-ipsw.sh iPhone3,1 8A293 # fetch one specific build
#
# IPSWs are plain signed firmware bundles from Apple's CDN; this only downloads
# and checksums them. Decryption/patching happens in later steps.
#
# Downloads land in firmware/<identifier>_<build>/ and are SHA1-verified against
# the metadata API so a truncated or swapped file is caught before use.

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FW_DIR="${REPO_ROOT}/firmware"
API="https://api.ipsw.me/v4/device"

log()  { printf '\033[1;36m[fetch]\033[0m %s\n' "$*"; }
warn() { printf '\033[1;33m[fetch]\033[0m %s\n' "$*" >&2; }
die()  { printf '\033[1;31m[fetch]\033[0m %s\n' "$*" >&2; exit 1; }

command -v curl    >/dev/null || die "curl not found (run 00-setup-linux.sh)."
command -v python3 >/dev/null || die "python3 not found (run 00-setup-linux.sh)."

# Resolve download URL + sha1 for a device/build from the metadata API.
# Prints: "<url>\t<sha1>\t<version>"
resolve() {
  local device="$1" build="$2"
  curl -fsSL "${API}/${device}?type=ipsw" \
    | DEVICE="$device" BUILD="$build" python3 -I -c '
import json, os, sys
device = os.environ["DEVICE"]; build = os.environ["BUILD"]
data = json.load(sys.stdin)
for fw in data.get("firmwares", []):
    if fw.get("buildid") == build:
        print("%s\t%s\t%s" % (fw["url"], fw.get("sha1sum",""), fw.get("version","")))
        sys.exit(0)
sys.stderr.write("no firmware with build %s for %s\n" % (build, device))
sys.exit(1)'
}

fetch_one() {
  local device="$1" build="$2"
  local line url sha1 version
  line="$(resolve "$device" "$build")" || die "lookup failed for ${device} ${build}"
  url="$(cut -f1 <<<"$line")"; sha1="$(cut -f2 <<<"$line")"; version="$(cut -f3 <<<"$line")"

  local out_dir="${FW_DIR}/${device}_${build}"
  local out="${out_dir}/$(basename "$url")"
  mkdir -p "$out_dir"

  if [[ -f "$out" ]] && [[ -n "$sha1" ]] && echo "${sha1}  ${out}" | sha1sum -c - >/dev/null 2>&1; then
    log "${device} ${version} (${build}) already present and verified."
    printf '%s\n' "$out"; return 0
  fi

  log "Downloading ${device} ${version} (${build})..."
  log "  ${url}"
  curl -fL --retry 4 --retry-delay 3 -C - -o "$out" "$url"

  if [[ -n "$sha1" ]]; then
    log "Verifying SHA1..."
    echo "${sha1}  ${out}" | sha1sum -c - || die "SHA1 mismatch — delete ${out} and retry."
  else
    warn "No SHA1 in metadata for ${build}; skipped verification."
  fi
  log "Saved ${out}"
  printf '%s\n' "$out"
}

# One explicit build, or every unique firmware in targets.json.
if [[ $# -eq 2 ]]; then
  fetch_one "$1" "$2"
  exit 0
fi

mapfile -t pairs < <(
  python3 -I - "${REPO_ROOT}/config/targets.json" <<'PY'
import json, sys
seen = set()
data = json.load(open(sys.argv[1]))
for t in data["firmware_targets"]:
    key = (t["device"], t["build"])
    if key not in seen:
        seen.add(key)
        print("%s %s" % key)
PY
)

[[ ${#pairs[@]} -gt 0 ]] || die "No firmware targets found in config/targets.json."
for p in "${pairs[@]}"; do
  # shellcheck disable=SC2086
  fetch_one $p
done
log "All target firmwares fetched."
