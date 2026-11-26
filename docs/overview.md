# Thr0wback — how it works

Thr0wback builds a second, older iOS that an **iPhone 4 (iPhone3,1)** can boot
**tethered** from a Linux host over USB, without disturbing the iOS 4.1 install
already on the phone.

## What is and isn't possible

A phone can't run an iOS version older than the first one built for it. For the
iPhone 4 that floor is **iOS 4.0**, and the ceiling is **iOS 7.1.2**.

| Target | Feasibility | Approach |
|---|---|---|
| iOS 4.0 – 7.1.2 | Works | Ordinary custom IPSW: decrypt, patch signature checks, boot tethered |
| iOS 3.x | Experimental only | Hybrid: iPhone 4 bootchain + kernel, iOS 3 userland on top |

The iOS 3 path is a research experiment. It may never reach the home screen.
Retina and cellular are expected to be broken even if it boots. That's fine: it
runs tethered from its own space and never touches the 4.1 install.

## The two layers of the hybrid

iOS 3 was finished before the iPhone 4 existed, so it has no code for the A4's
chips. We keep the parts that must match the hardware and swap only the userland:

- **Bootchain + kernel (from iPhone 4 iOS 4.0):** LLB, iBoot, iBSS, iBEC,
  DeviceTree, kernelcache. These drive the real hardware.
- **Userland (from iPhone 3GS iOS 3.1.3):** SpringBoard, the apps, the
  frameworks — the part that looks and feels like iOS 3.
- **Identity spoof:** the model string handed to the iOS 3 userland reports
  `iPhone2,1` (3GS), so iOS 3 loads its 3GS configuration instead of refusing an
  unknown device. This is a software label only; it changes no hardware.

The seam between those two layers — the interfaces iOS 3 userland uses to talk
to the kernel (IOKit, IOMobileFramebuffer, OpenGL ES, launchd) — changed in 4.0
and is where boot failures will show up. Each break is handled by either
patching the iOS 3 file or pulling the matching 4.0 file across. We find them by
booting verbose and reading the serial/USB log.

## Why the phone can't be permanently bricked

- The iPhone 4 bootrom is read-only and always offers **DFU mode**; software
  can't erase it.
- The **limera1n** bootrom exploit can't be patched by Apple, so the host can
  always talk to the phone and recover it.
- The experimental OS is **tethered** — loaded into RAM from the host, not
  installed as the phone's startup. A failed boot is just a reboot.

The one thing genuinely at risk is the untethered 4.1 install (see
`recovery.md`). That's recoverable by re-running Legacy iOS Kit.

## Pipeline

1. `scripts/00-setup-linux.sh` — install host dependencies.
2. `scripts/10-fetch-ipsw.sh` — download + verify the stock IPSWs.
3. `scripts/img3.py decrypt` — decrypt the IMG3 images with the per-build keys
   (fetched from the ipsw.me keys API, e.g. `/v4/keys/ipsw/iPhone3,1/8A293`).
4. Patch the bootchain + kernel to skip signature checks.
5. (Hybrid) assemble the iOS 3 userland over the 4.0 bootchain.
6. Boot tethered and iterate on the log.

### Validated so far (on real iPhone3,1 4.0 / 8A293 firmware)

- Fetch + integrity: the stock IPSW downloads and every image passes its zip CRC.
  (Heads up: ipsw.me's *outer* SHA1 for this build is stale and won't match; the
  per-file CRCs are the real check.)
- Decrypt: `img3.py` decrypts iBSS/iBEC to the `iBoot-889.24` banner, the
  kernelcache to a valid `complzss` payload, and DeviceTree to a tree naming
  `iPhone3,1` / `N90AP`. Correct `complzss`/banner output confirms the AES-256
  key+IV path is right.

Steps 4–6 build on this.
