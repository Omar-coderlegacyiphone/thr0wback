# Thr0wback

Boot an older iOS as a second, tethered OS on a 32-bit iPhone, without
disturbing the install already on the phone.

Built for one concrete setup: an **iPhone 4 (iPhone3,1)** on **iOS 4.1**
(untethered downgrade via Legacy iOS Kit), driven from a **Linux** host.

> **Status:** early. Host setup and firmware fetching work; decrypt / patch /
> assemble / boot stages are being built on top of them.

## The goal, honestly stated

A phone can't run an iOS older than the first version built for it. For the
iPhone 4 that's **iOS 4.0** (floor) through **iOS 7.1.2** (ceiling).

- **iOS 4.0 – 7.1.2:** a normal custom IPSW, booted tethered. This works.
- **iOS 3.x:** only as a **hybrid** — the iPhone 4 bootchain and kernel with
  the iOS 3 userland on top, iOS 3 told it's running on a 3GS. This is a
  research experiment that may never reach the home screen; Retina and cellular
  are expected to be broken even if it boots.

Full reasoning is in [`docs/overview.md`](docs/overview.md).

## Safety

- The iPhone 4 bootrom (**limera1n**) can't be patched, so the phone can always
  enter DFU and be recovered. No permanent brick.
- The experimental OS boots from host RAM over USB. The phone's on-NAND
  bootloaders and the baseband are **never** written.
- The only thing at real risk is the untethered 4.1 install, which is restored
  by re-running Legacy iOS Kit. See [`docs/recovery.md`](docs/recovery.md).

## Usage (on the Linux host, phone plugged in)

```sh
./scripts/00-setup-linux.sh     # install toolchain (apt / pacman / dnf)
export PATH="$PWD/tools/bin:$PATH"
./scripts/10-fetch-ipsw.sh      # download + SHA1-verify the stock IPSWs
```

Firmware targets live in [`config/targets.json`](config/targets.json).

## Layout

```
config/targets.json         devices, builds, roles, hard limits
docs/overview.md            how the hybrid works, what's possible
docs/recovery.md            the one real risk and how to undo it
scripts/00-setup-linux.sh   host toolchain installer
scripts/10-fetch-ipsw.sh    IPSW downloader + verifier
```

## Legal / scope

For booting software on **hardware you own**. Uses only publicly documented
firmware keys and Apple's own signed IPSWs. The baseband is never modified.
