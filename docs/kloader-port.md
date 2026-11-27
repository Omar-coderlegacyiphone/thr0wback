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

- **argv[1] is a raw bootloader-style image, not a kernel Mach-O.** (Earlier
  versions of this doc said "decompressed kernel"; that was wrong, corrected
  after the on-device tests in `docs/test-results.md`.) kloader copies the file
  into RAM at `load_address` (`0x5f000000` for S5L8930X), then patches the
  kernel's wake-up trampoline so the CPU branches to that address on its next
  wake from sleep, with the MMU off. It warns unless the first word is
  `0xea00000e` (an iBoot-style entry branch) and prints banner strings from
  `+0x200/+0x240/+0x280`, so it expects a decrypted **iBEC/iBSS-style** image
  (raw, not IMG3/IM4P, which it refuses). A kernel Mach-O has no such entry
  point and would not run from a cold jump.
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
- The earlier `docs/on-device.md` per-target layout (iBEC + kernelcache +
  DeviceTree) is closer to right than "one `kernel.macho`": the image kloader
  runs is the iBEC, and that iBEC then has to find a kernel, DeviceTree and
  root filesystem for the second OS.

## Remaining work, in order

1. ~~Fetch + decrypt the **4.1 (8B117)** kernelcache; extract its offsets.~~ ✅ done
   (useful analysis; not actually consumed by this kloader).
2. ✅ **On-device test #1: does tfp0 work under this jailbreak?** Yes. kloader
   printed `kern.version ... S5L8930X` and `kernel_base: 0x80000000`, and failed
   only on the missing file (see `docs/test-results.md`).
3. ✅ **On-device test #2: can we jump at all?** Yes, using the built-in
   self-test image (`thr0wback test`, no Apple files). The printed
   `larm_init_tramp: 0x80065008` matched the offline analysis of the 8B117
   kernel, and the phone ended up stuck in our spin loop until Power+Home. The
   2-second auto-wake missed on the first run and hit on the next two, so
   reliability is still an open item.
4. **Next test: a real image.** Run a decrypted iBEC (from the owner's own
   firmware, never committed) via kloader and see what the phone does.
   `thr0wback boot <target>` runs `<target>/ibec.bin` since 0.1.3.
5. **The root-filesystem question**, once a real image runs: figure out what it
   takes to get a mounted, matching userspace for the second OS.

## Safety / why it's low-risk to try

`kloader` does a **RAM-only kexec** — it never writes NAND, bootloaders, or
baseband. A failed boot = hold Power+Home → back in untethered 4.1, jailbreak
intact. So iterating on-device can't brick the phone or cost the jailbreak.
