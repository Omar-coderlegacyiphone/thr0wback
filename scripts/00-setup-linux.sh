#!/usr/bin/env bash
#
# Thr0wback host setup (Linux).
#
# Installs the toolchain needed to download, decrypt, patch and tethered-boot
# IMG3-era iOS (iPhone 4 / A4). Run this on the Linux machine you plug the phone
# into, NOT in any cloud environment.
#
#   ./scripts/00-setup-linux.sh
#
# Idempotent: re-running it skips anything already present.

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TOOLS_DIR="${REPO_ROOT}/tools"
BUILD_DIR="${TOOLS_DIR}/build"
mkdir -p "${TOOLS_DIR}" "${BUILD_DIR}"

log()  { printf '\033[1;36m[setup]\033[0m %s\n' "$*"; }
warn() { printf '\033[1;33m[setup]\033[0m %s\n' "$*" >&2; }
die()  { printf '\033[1;31m[setup]\033[0m %s\n' "$*" >&2; exit 1; }

# --- distro packages ---------------------------------------------------------

install_apt() {
  log "Installing packages via apt (sudo may prompt)..."
  sudo apt-get update
  sudo apt-get install -y \
    build-essential git cmake autoconf automake libtool pkg-config \
    libusb-1.0-0-dev libssl-dev libzip-dev libcurl4-openssl-dev \
    libplist-dev libimobiledevice-dev libirecovery-dev \
    libimobiledevice6 usbmuxd idevicerestore unzip curl python3
}

install_pacman() {
  log "Installing packages via pacman..."
  sudo pacman -Sy --needed --noconfirm \
    base-devel git cmake autoconf automake libtool pkgconf \
    libusb openssl libzip curl libplist libimobiledevice libirecovery \
    usbmuxd idevicerestore unzip python
}

install_dnf() {
  log "Installing packages via dnf..."
  sudo dnf install -y \
    @development-tools git cmake autoconf automake libtool pkgconfig \
    libusb1-devel openssl-devel libzip-devel libcurl-devel \
    libplist-devel libimobiledevice-devel libirecovery-devel \
    usbmuxd idevicerestore unzip curl python3
}

if   command -v apt-get >/dev/null 2>&1; then install_apt
elif command -v pacman  >/dev/null 2>&1; then install_pacman
elif command -v dnf     >/dev/null 2>&1; then install_dnf
else
  warn "Unknown package manager. Install these yourself and re-run:"
  warn "  build tools, git, cmake, libusb-1.0, openssl, libzip, libcurl,"
  warn "  libplist, libimobiledevice, libirecovery, usbmuxd, idevicerestore."
  die  "Aborting after dependency check."
fi

# --- source-built tools ------------------------------------------------------
# These are the IMG3-era specialists that aren't packaged. Each is cloned,
# built, and its binary symlinked into tools/bin.

BIN_DIR="${TOOLS_DIR}/bin"
mkdir -p "${BIN_DIR}"

build_from_git() {
  # build_from_git <name> <git-url> <build-cmd> <relative-binary-path>
  local name="$1" url="$2" build_cmd="$3" bin_rel="$4"
  local src="${BUILD_DIR}/${name}"
  if [[ -x "${BIN_DIR}/${name}" ]]; then
    log "${name} already built, skipping."
    return 0
  fi
  log "Building ${name}..."
  [[ -d "${src}" ]] || git clone --depth 1 "${url}" "${src}"
  ( cd "${src}" && eval "${build_cmd}" )
  ln -sf "${src}/${bin_rel}" "${BIN_DIR}/${name}"
}

# xpwntool: decrypt/repack IMG3 images (iBSS, iBEC, kernelcache, ...).
build_from_git xpwntool \
  "https://github.com/planetbeing/xpwn.git" \
  "mkdir -p build && cd build && cmake .. && make xpwntool" \
  "build/ipsw-patch/xpwntool"

# iBoot32Patcher: disable signature checks in iBoot-class images (iBSS/iBEC/iBoot).
build_from_git iBoot32Patcher \
  "https://github.com/iBoot32Patcher/iBoot32Patcher.git" \
  "make" \
  "iBoot32Patcher"

log "Done. Add the tools to your PATH for this shell:"
log "  export PATH=\"${BIN_DIR}:\$PATH\""
log ""
log "Verify the device tools see your phone (plug it in first):"
log "  idevice_id -l        # should print the UDID once trusted"
log "  irecovery -m         # shows mode when in recovery/DFU"
