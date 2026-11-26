# On-device (phone-only) flow

The goal: no computer to *run* it. You install one `.deb` on the jailbroken
iPhone and boot a second OS from the phone itself, CoolBooter-style, using
**kloader**.

A computer (or CI) still **builds** the `.deb` once — but that's open-source
components only, and you just install the result.

## What the .deb contains

- `kloader` — the open-source on-device loader (boots a prepared bootchain out
  of the running iOS; no USB).
- `/usr/bin/thr0wback` — the launcher (`thr0wback list` / `thr0wback boot 4.0`).

It does **not** contain any Apple firmware. That stays off the public repo for
copyright reasons; it's supplied per-device, from your own firmware.

## The honest gap: preparing a target

`thr0wback boot <target>` boots whatever patched images sit in
`/var/mobile/thr0wback/<target>/` (iBEC, kernelcache, DeviceTree). Producing
those images is the decrypt + **patch** pipeline (`scripts/20`–`30`). Two ways:

1. **On-device prep** — run the decrypt/patch steps on the phone (ports of
   img3.py + the patcher). This is the fully phone-only path and still needs the
   patcher, which is the one piece under review (see `patching.md`).
2. **Prep once, copy over** — the images get prepared wherever the patcher runs,
   then dropped into `/var/mobile/thr0wback/<target>/` on the phone.

Either way the patched images come from **your** firmware, not the repo.

## First test milestone

1. Install the `.deb` (Cydia / Filza / `dpkg -i`).
2. Put a prepared **4.0** target in `/var/mobile/thr0wback/4.0/`.
3. `thr0wback boot 4.0`.
4. If 4.0 boots → the loader works. Then try a `3.x` target (the moonshot).

If a boot hangs, hold **Power+Home** to return to your normal iOS. Nothing is
written to the active system.
