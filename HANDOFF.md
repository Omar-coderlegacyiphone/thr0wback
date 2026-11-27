# Thr0wback — developer handoff

**Looking for:** the ask just got smaller. The kexec engine itself turns out to
already exist and already claim iOS 4.0 support (below) — what's left is
on-device verification and, if the jump works, figuring out the root-filesystem
side of booting a full second OS rather than just reaching its kernel. Someone
with 32-bit iOS / jailbreak internals experience to drive that. Details below.

## Goal

An **on-device** booter (CoolBooter-style) that runs from a **jailbroken iPhone 4
on iOS 4.1** and boots a second iOS (4.0–7.1.2) via `kloader`, with no computer.
Hardware the owner owns, their own firmware. The iOS 3 idea is dead (no A4
support in iOS 3 — hardware gap).

## Target device (fixed)

| | |
|---|---|
| Device | iPhone 4 GSM, 16 GB — **iPhone3,1** |
| Storage | GPT behind a protective MBR, 8192-byte sectors, fully allocated: System 1524 MB (`disk0s1`), Data 13824 MB (`disk0s2`, EMF type; var is the nested `disk0s2s1`, 12224 MB free), tiny `disk0s3` (8 MB) and `disk0s4` (under 1 MB) (see `docs/test-results.md`) |
| SoC | Apple A4 — **s5l8930x** |
| Host OS | **iOS 4.1 (8B117)**, codename Baker, jailbroken (untethered, Legacy iOS Kit / powdersn0w) |
| Bootrom | **limera1n** (unpatchable) |

## What's already done and verified (in this repo)

All on the real 8B117 firmware, host-side, no device needed:

- **Fetch + integrity** — `scripts/10-fetch-ipsw.sh` (per-file CRC; ipsw.me's
  outer SHA1 is stale, ignore it).
- **Decrypt** — `scripts/img3.py` + `scripts/20-decrypt.sh`. Keys pulled from
  the ipsw.me keys API. iBSS/iBEC → `iBoot-889.24`, kernelcache → `complzss`.
- **Kernel decompress** — `scripts/lzss.py` → coherent ARM Mach-O
  (`xnu-1504.*`, `MH_EXECUTE`). (Tail is ~38 bytes short of byte-exact; fine for
  analysis, must be fixed before recompression.)
- **Kernel offsets** — `scripts/ksyms.py`. The 4.x kernelcache is **fully
  symbolicated**, so the addresses kloader needs are a lookup, not a hunt.

### The offsets you need (iOS 4.1 / 8B117) — `config/offsets-iPhone3,1-8B117.json`

| symbol | address |
|---|---|
| `_kernel_pmap` | `0x8024e218` |
| `_kernel_map` | `0x8026eadc` |
| `_kernel_task` | `0x8026e3e0` |
| `_PE_i_can_has_debugger` | `0x801db80c` |
| `_copyin` / `_copyout` | `0x80066c60` / `0x80066ce0` |
| `_flush_dcache` / `_invalidate_icache` | `0x8005def4` / `0x8005e44c` |

(Re-extract any symbol: `python3 scripts/ksyms.py <decrypted-kernel.macho> _symbol`.)

## The remaining work (the ask) — updated after reading the real source

Confirmed by cloning and reading it directly, not secondhand: **use
[`axi0mX/ios-kexec-utils`](https://github.com/axi0mX/ios-kexec-utils)**.
winocm's original + axi0mX's later work. Its own README states the support
range outright: **"armv7 support for iOS 4.0-9.3.5 (requires a jailbreak with
tfp0 kernel patch)."** iPhone 4's SoC is in its chip table by name
(`S5L8930X` → `case 0x8930`, `gPhysBase 0x40000000` — matches our own
independently-derived value exactly).

It's one file (`kloader.c`, ~420 lines), nothing to strip — there's no
Trident/offsetfinder code in this lineage at all (that was a different,
unrelated iOS 9 fork we'd looked at earlier). And it needs **no per-version
offsets**: it finds its own kernel base at runtime and pattern-scans the live
kernel for a wake-resume trampoline instruction sequence, rather than using a
fixed address. So the offsets we extracted (`config/offsets-iPhone3,1-8B117.json`)
are good, verified analysis — and a nice cross-check, since the SoC physical
addresses line up — but this particular tool doesn't actually consume them.

It also already ships a **prebuilt universal binary** (armv7+arm64), signed
with the `tfp0.plist` entitlement it needs. No Xcode/Mac required to get a
runnable binary — CI now fetches that binary directly rather than trying to
compile it (`.github/workflows/build-deb.yml`).

**So the remaining work is no longer "write a kernel-access shim."** Status
after the on-device tests (details: `docs/test-results.md`):

1. ✅ **tfp0 works** under the Legacy iOS Kit / powdersn0w 4.1 jailbreak
   (`kernel_base: 0x80000000` printed; kloader only failed on a missing file).
2. ✅ **The jump works.** `thr0wback test` jumps into a 4 KB spin image we ship
   (no Apple files). The live kernel's hook address (`larm_init_tramp:
   0x80065008`) matched our offline analysis, and the phone ended up stuck in
   the spin loop until Power+Home. Caveat: the 2-second auto-wake is unreliable: of
   the runs with a known result, 4 hit and 3 missed; every redo right after a
   miss hit (3 of 3), first attempts hit 1 of 4 (see `docs/test-results.md`).
3. **Correction:** kloader runs its file as a *bootloader-style* image (a raw,
   decrypted iBEC, first word `0xea00000e`), **not** a kernel Mach-O as this
   doc previously said. `thr0wback boot` runs `<target>/ibec.bin` since 0.1.3
   (it used to look for `kernel.macho`).
4. **Next test:** run a real decrypted iBEC (from the owner's own firmware,
   never committed) and see what the phone does.
5. **The actual open question:** getting code to run is not the same as getting
   a usable second OS (Springboard, apps). That needs a matching **root
   filesystem** too. Old CoolStar-style dual-boot tools paired kexec with a
   second OS partition already restored onto the device, rather than
   conjuring a filesystem from nothing. That is a storage/partition question,
   not a kernel-exploit one.
   Research so far (including why the one existing iPhone 4 dual boot would
   replace the 4.1 host): `docs/dualboot-plan.md`.

Full writeup of the source-reading and the reasoning: `docs/kloader-port.md`.

## Safety / why it's low-risk to try

`kloader` does a **RAM-only kexec** — it never writes NAND, bootloaders, or
baseband. A failed boot = hold Power+Home → back in untethered 4.1, jailbreak
intact. So iterating on-device can't brick the phone or cost the jailbreak.

## Status, honestly

Proven on the real iPhone 4 / iOS 4.1: the package installs, kloader gets
tfp0, hooks the wake path, and our own code runs after the wake. Not proven: a
real iBEC running, the auto-wake's reliability, and (the big one) a usable
second OS with a root filesystem.

## Fast feedback loop available

The device owner has their own Cydia repo and can push an experimental
package to it and install on the actual iPhone 4 in minutes. That's a real
advantage for whoever picks this up: build → drop in the repo → install →
test → report back, all same-day, no waiting on someone else's hardware.
