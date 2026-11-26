# kloader on iPhone 4 / iOS 4.1 (Option B)

Goal: an **on-device** booter that runs from a jailbroken **iOS 4.1** host, so a
second OS boots with no computer. Confirmed against the real upstream source
(not secondhand): this is more done than we thought, with one real open
question left — see "The one real gap" below.

## The source: axi0mX's `ios-kexec-utils`

`github.com/axi0mX/ios-kexec-utils` — winocm's original kloader, with armv7
iOS 4.0–9.3.5 support added by axi0mX. This is the real, maintained, documented
tool (listed on the iPhone Wiki next to winocm's original). Its own README
states the support range directly: **"armv7 support for iOS 4.0-9.3.5
(requires a jailbreak with tfp0 kernel patch)."**

It's tiny: one file, `kloader.c` (~420 lines), no `exploit.c`/`offsetfinder.c`
at all — those were never part of this lineage; that was a mix-up with a
different (iOS 9 Trident-era) fork. Nothing to "drop."

## Why it needs no per-version offsets (reading the actual code)

Earlier docs here assumed we'd have to feed it fixed kernel-symbol addresses
per iOS build (hence `scripts/ksyms.py` and the `config/offsets-*.json` files).
Reading `kloader.c`, that's not how it works, and it's cleverer than that:

1. **Kernel access**: `task_for_pid(0)` → `kernel_task`. Standard jailbreak
   API. Needs the jailbreak to grant tfp0 (see "the one real gap" below).
2. **Finds its own kernel base** at runtime via `vm_region_recurse_64` —
   scanning the live process's memory map for a region over 1GB, which is the
   kernel. No hardcoded address.
3. **Dumps ~13MB of the live kernel** (`dump_kernel`) into a local buffer.
4. **Pattern-scans that dump** for a specific ARM instruction sequence
   (`find_larm_init_tramp` — the sleep/wake resume trampoline), rather than
   looking up a symbol address. This is what makes it version-flexible: the
   *instruction pattern* is stable across iOS versions even when its address
   isn't.
5. **Puts the device to sleep**, schedules an auto-wake via `IOPMSchedulePowerEvent`.
6. **On wake**, writes the given file into physical RAM at a SoC-specific
   `load_address`, then overwrites the wake trampoline with a branch to it.
   The "resume from sleep" path becomes "jump to the new image" instead.

So our offset-extraction work (`ksyms.py`, the 8B117 JSON) isn't what this
specific tool needs — it doesn't consume those offsets at all. It's still
good, verified analysis (and the SoC physical-RAM values it found —
`gPhysBase 0x40000000` for cpid `0x8930`, i.e. the iPhone 4 — match this
source's own `case 0x8930` table exactly, which is a nice independent
cross-check), just not a dependency of this path.

## The SoC table confirms the hardware fit

```c
case 0x8930:               // S5L8930X — iPhone 4's A4
  gPhysBase = 0x40000000;
  load_address = 0x5f000000;
  break;
```
`get_cpid()` reads `kern.version` and recognizes `S5L8930X` by name. The
iPhone 4 is a directly supported target, not an edge case being stretched to
fit.

## What ships as a binary already

The repo includes a **prebuilt universal binary** (`kloader`, armv7 + arm64),
already signed with `tfp0.plist` (`get-task-allow`, `task_for_pid-allow`,
`run-unsigned-code`). Rebuilding from source needs Xcode + an iPhoneOS SDK +
`ldid` — Mac-only — but installing the existing binary doesn't. CI
(`.github/workflows/build-deb.yml`) fetches this prebuilt binary directly
rather than trying to compile it.

## The one real gap: kernel-jump proof vs. a fully booted second OS

`kloader`'s job ends at: load `argv[1]` into RAM and jump to it. That's all —
one file in, one jump, no further handoff logic. For our use it means:

- **argv[1] is a decompressed kernel Mach-O** (`img3.py decrypt` →
  `lzss.py decompress` on the target version's kernelcache — exactly what this
  repo's scripts already produce). It is **not** an iBEC/iBSS — kloader
  explicitly refuses IMG3/IM4P files, and there's no bootloader-to-kernel
  handoff code in it; whatever you hand it must be able to run cold from a
  jump, the same way it would after iBoot handed off to it normally. (Why a
  bare jump can work at all: the hardware is already clocked and initialized
  by the *currently running* OS, which is normally iBoot's job — so a kexec
  from a live system skips needing iBoot a second time.)
- **A kernel booting is not a device booting.** Jumping to the target
  version's kernel should get you at least as far as that kernel's own early
  init — a real, checkable milestone (e.g. its panic/boot banner proves the
  jump worked, even if it goes no further). Going all the way to a usable
  second OS (Springboard, apps) additionally needs that version's **root
  filesystem mounted** — userspace and the kernel it boots have to be from a
  matching version; the old CoolStar-style dual-boot tools paired kexec with a
  pre-restored second-OS partition already on the device, rather than
  conjuring a filesystem from nothing. **This is the actual open question for
  the next phase, and it's a storage/partition question, not a kernel-exploit
  one.**
- The earlier `docs/on-device.md` target layout (iBEC + kernelcache +
  DeviceTree per target) should be read as aspirational for a fuller chain;
  the concrete next milestone is simpler: one `kernel.macho`, one jump, see
  what happens.

## Remaining work, in order

1. ~~Fetch + decrypt the **4.1 (8B117)** kernelcache; extract its offsets.~~ ✅ done
   (useful analysis; not actually consumed by this kloader).
2. **On-device test #1 — does tfp0 work at all under this jailbreak?** Install
   the prebuilt `kloader` via the `.deb`, run `thr0wback boot <target>` with
   any placeholder `kernel.macho` (even garbage) in a target dir, and check
   whether it gets *past* `task_for_pid(0)` (look for the `kernel_base:
   0x...` print) before failing on content. If `task_for_pid 0 failed`
   prints immediately, the Legacy iOS Kit / powdersn0w 4.1 jailbreak doesn't
   grant tfp0 as-is, and that becomes the real blocker to chase down.
3. **On-device test #2 — the real jump.** Prepare an actual target: decrypt +
   decompress a second iOS version's kernelcache into `kernel.macho`, boot it,
   see what appears on screen (panic banner = the jump worked; something else
   = debug from there).
4. **The root-filesystem question**, only once #3 proves the jump works —
   figure out what it takes to get a mounted, matching userspace for that
   kernel rather than a jump-and-panic.

## Safety / why it's low-risk to try

`kloader` does a **RAM-only kexec** — it never writes NAND, bootloaders, or
baseband. A failed boot = hold Power+Home → back in untethered 4.1, jailbreak
intact. So iterating on-device can't brick the phone or cost the jailbreak.
