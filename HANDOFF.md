# Thr0wback — developer handoff

**Looking for:** someone who writes 32-bit iOS kexec / kernel-access code, to
finish the on-device booter engine. Most of the groundwork is done; what's left
is one well-scoped piece. Details below.

## Goal

An **on-device** booter (CoolBooter-style) that runs from a **jailbroken iPhone 4
on iOS 4.1** and boots a second iOS (4.0–7.1.2) via `kloader`, with no computer.
Hardware the owner owns, their own firmware. The iOS 3 idea is dead (no A4
support in iOS 3 — hardware gap).

## Target device (fixed)

| | |
|---|---|
| Device | iPhone 4 GSM — **iPhone3,1** |
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

## The remaining work (the ask)

Base: the public `kloader.c` (e.g. `ganoninc/trident-kloader-updated`). Its
kexec engine **already supports s5l8930x** (`S5L8930_PHYS_OFF 0x40000000`,
`phys_addr_remap 0x5fe00000`). So:

1. **Drop the iOS 9 parts** — `exploit.c`, `offsetfinder.c`. Not needed: the
   host is already jailbroken.
2. **Kernel read/write for 4.1** — the one piece to write. kloader expects
   `task_for_pid(0)` + `vm_read`/`vm_write`. On jailbroken iOS 4 either tfp0 is
   already granted, or use **`/dev/kmem`** (open on iOS 4). This shim is the
   heart of the ask.
3. **Feed the 8B117 offsets** above.
4. **Build** armv7, `-miphoneos-version-min=4.0`, via theos (CI scaffold exists
   at `.github/workflows/build-deb.yml`).
5. **Package** into the `.deb` (`packaging/deb/`, launcher `thr0wback boot <t>`).
6. **Boot-test on device** — the only real verdict.

## Safety / why it's low-risk to try

`kloader` does a **RAM-only kexec** — it never writes NAND, bootloaders, or
baseband. A failed boot = hold Power+Home → back in untethered 4.1, jailbreak
intact. So iterating on-device can't brick the phone or cost the jailbreak.

## Status, honestly

Nobody has run kloader on a 4.1 host before — this is unproven and may not boot.
But the hard analysis (offsets, feasibility, SoC support) is done, and the
remaining piece is well-scoped. That's the part a kexec dev can actually pick up.
