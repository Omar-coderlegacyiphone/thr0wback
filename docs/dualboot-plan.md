# Dual-boot plan (research notes, nothing here has been tried yet)

**Status: research only.** Nothing in this file has been run on the device. Items
marked *second-hand* were read by a research helper and reported back; check the
original before relying on them. Do not run any command named here as written.

## Goal

Boot a second iOS (4.0 to 7.1.2) on an iPhone 4 (iPhone3,1) whose host stays on
iOS 4.1 (untethered, Legacy iOS Kit / powdersn0w), phone-only if possible.

## Already proven on the phone (`docs/test-results.md`)

kloader gets tfp0, hooks the wake path at `0x80065008`, and our own image runs
after the wake. That covers "leave iOS 4.1 and run other code". It does not
cover the storage side below.

## What a persistent second OS needs

1. A second System partition (normally also a second Data partition) on the NAND.
2. The second OS's root filesystem restored onto the new System partition.
3. Patched iBSS/iBEC, plus the matching kernelcache and DeviceTree, so the
   second OS boots from the new partition instead of the main one. kloader (4tify uses its
   two-image variant, multi_kloader) is what starts these.
4. Something on the host that launches it.

## Closest existing project: 4tify

`Zurac-Apps/4tify`, forked as `codealize/iPhone4DualbootiOS4`. *Second-hand*:
README plus `Partition.sh`, `Patch-Partition.sh`, `ios4.sh`, `Jailbreak.sh`.

- Dual-boots iOS **4.3** on an iPhone 4 (3,1). Other 4.x builds and devices are
  only "planned". **iOS 4.1 is not listed.** README: "very much an early phase
  project, use this at your own risk".
- First step is a restore to a **modified iOS 7.1.2** "with lwvm patched out and
  replaced with GPT". The host becomes 7.1.2 and iOS 4.3 is the second OS.
- Needs a **Mac** (tested on macOS 10.13 to 10.15), USB, ipwndfu, an SSH ramdisk
  and the phone's ECID. The last step alone takes about an hour.
- Partitioning: a prebuilt tool (`TwistedMind2`, not read) makes a partition
  patch, which is then written with `dd` to the whole raw disk (`/dev/rdisk0`)
  from the ramdisk.
- Then `newfs_hfs` formats `disk0s3` ("System") and `disk0s4` ("Data"),
  `asr restore ... --erase` puts the iOS 4.3 root on `disk0s3`, `/private/var`
  moves to `disk0s4`, keybags are fixed and an `fstab` is copied in.
- Files placed on the host's root: `applelogo`, `devicetree`, `kernelcache`,
  `ramdisk`, `iBEC.img3`, `iBSS.patched`, `boot.sh`, plus a setuid `4tify.app`
  and `runasroot`.
- The app starts the second OS: screen goes black, tap Home, verbose boot in
  10 to 15 s. The README credits winocm and xerub for kloader, but the scripts
  don't show how it is used (`boot.sh` and the app were not read).
- None of the destructive steps ask for confirmation.

This agrees with our test results: what kloader runs is a patched iBSS/iBEC-style
image, not a kernel.

## How 4tify actually boots the second OS (second-hand, read from its repo)

- Files placed in `/` on the host: `iBSS.patched`, `iBEC.img3`, `kernelcache`,
  `devicetree`, `ramdisk`, `applelogo` and `boot.sh`. `boot.sh` is exactly
  `multi_kloader /iBSS.patched /iBEC.img3`. That is **multi_kloader** (from
  Nyansatan's "dualbootstuff" package, credited in the 4tify-iPad2 README). It
  takes **two** images, unlike our single-file `kloader`. No boot-args, kernel or
  ramdisk appear in the script, so they must be baked into the patched images
  (which were not read: they are binaries).
- The second OS's `fstab` is `/dev/disk0s3 / hfs ro 0 1` and
  `/dev/disk0s4 /private/var hfs rw 0 2`. **Our phone already has slots 3 and 4**
  (8 MB and under 1 MB, Test 5), so they would have to be resized, not created.
- The setuid 4tify app (via `runasroot`) runs `/boot.sh`; the screen goes black,
  the user taps Home, and a verbose boot follows in 10 to 15 s.
- Not in the repo: how `iBSS.patched` / `iBEC.img3` were made (no tool names or
  flags), what the `ramdisk` is for, and what `TwistedMind2` writes.
- The same method is used for iPad 2 on iOS 4.3.x (`4tify-iPad2`), also after a
  restore to a patched iOS 6.1.3.
- Nothing found about an iOS 4.1 host, or about an iPhone 4 on 4.1.

## The catch for this project

1. **It doesn't keep the 4.1 host.** The existing method restores to 7.1.2 first.
2. **Only iOS 4.3 as the second OS**, not 4.0 to 7.1.2.
3. **Not phone-only.** Partitioning runs from an SSH ramdisk booted from a
   computer over DFU.
4. **Nobody has documented a dual boot from a 4.1 host.** The 4.1 table is a GPT
   (measured, Test 4), like the one 4tify builds on 7.1.2. Unknown: how to shrink the
   Data slice (typed EMF, probably encrypted), whether the same partition numbers
   work, and whether a patched iBEC boots from a second partition on 4.1.
5. **The partition step can lose data or stop iOS 4.1 booting.** Recovery means
   restoring from a computer.

## What the phone showed (`thr0wback info`, 0.1.3)

iPhone 4 GSM 16 GB on iOS 4.1: root is `disk0s1`, var is `disk0s2s1` (old-style
names, not LwVM). `disk0s3` and `disk0s4` already exist, unmounted, contents
unknown. `fdisk`, `newfs_hfs`, `mount_hfs`, `fsck_hfs` and `dd` are on the
phone; `asr` is not. `fdisk` shows a protective MBR (id EE) over the whole
16 GB disk with 8192-byte sectors, so the real table is a GPT, like the one 4tify
builds on its 7.1.2 host. The GPT (read by `thr0wback disk`, Test 5) is: System 1524 MB, Data
13824 MB (type code spells "EMF", probably the encrypted kind), and two tiny slots
(8 MB and under 1 MB). Nothing is unallocated, and `/private/var` has 12224 MB
free inside Data. So a second OS means shrinking the Data slice. Details:
`docs/test-results.md`.

## Shrinking the Data slice (research, mostly second-hand)

Why: the disk is fully allocated (Test 5), so a second OS's slices have to come
out of Data, which has 12224 MB free inside.

- **iOS 5/6 guides** (nyansatan; search summaries only, the pages are blocked
  from this session): shrink the HFS filesystem inside Data with `hfs_resize`
  (by danzatt, syntax `mount_point new_size`), then edit the partition table to
  carve new slices from the freed space. Sizes are bytes divided by the block
  size (their example uses 8192, which matches this phone). Leave at least 400
  to 500 MB free in the first Data volume; second Data about 1 GB or more for
  iOS 6. The author says to rehearse on a phone you can afford to lose, such as
  an iPhone 4. The Apple Wiki's LwVM page reportedly says iOS's own update
  process does the same.
- **iOS 4: no guide found.** This phone's Data slice is typed "EMF", and a
  forensics slide deck (Sogeti, summary only) says iOS 4's raw data partition
  can't be read with standard tools, so it is probably encrypted at block level.
  Nothing I found says how `hfs_resize` or a table edit behaves under that.
  Whether `hfs_resize` exists on the phone was not checked (`thr0wback info`
  doesn't list it).
- **4tify avoids the problem by wiping first.** `Create-Restore.sh` and
  `Restore.sh` restore a fresh custom iOS 7.1.2 (as far as the scripts show,
  only the DeviceTree is changed in the IPSW). The prebuilt `TwistedMind2` is
  then run with `-d1 3221225472 -s2 879124480 -d2 max` (3 GiB, about 838 MiB,
  and "max"; what each flag means is not stated), so presumably the
  partitioning happens on a nearly empty phone. TwistedMind2 isn't documented
  anywhere I could reach, so what it really does is unknown.
- **Also seen:** `Restore.sh` runs `sshtool -k kloader -b pwnediBSS`, i.e. kloader
  starting a pwned iBSS on an iPhone 4 from a running jailbroken system. That is
  the same trick our tests show works on 4.1.

Two ways to get the space, neither tried:

1. *Wipe and redo:* restore the phone fresh with Legacy iOS Kit (how it got 4.1),
   then partition while Data is almost empty. Loses what is on the phone; needs
   a computer.
2. *Shrink in place:* `hfs_resize` plus a GPT edit under EMF. Unknown territory;
   a mistake can leave the phone unbootable until restored.

## Do we actually need to patch the iBEC at all? (reasoning, unverified)

Every guide above patches the iBSS/iBEC (strip signature checks, inject
`rd=...` boot-args) because they assume the **normal** boot path: ROM → LLB →
iBoot → iBSS → iBEC → kernel, with a signature check at each handoff. A stock
iBEC refuses to load anything Apple didn't sign for this exact device.

**kloader's kexec does not go through that path at all.** Rereading
`kloader.c` (axi0mX's fork, the one `docs/test-results.md` Tests 1–2 already
exercised on the real phone): `hook_kernel_wakeup()` patches a wake-resume
trampoline *inside the already-running kernel* to branch to a physical
address on the device's next wake from sleep, with the MMU off.
`load_image_to_memory()` just `vm_write`s `argv[1]`'s raw bytes to that
address. On wake, the CPU starts executing whatever is there — there is no
call into ROM/LLB/iBoot verification code anywhere in this path. Our own test
proved exactly this: the 4 KB `selftest.bin` we ship has no Apple signature at
all, and it ran.

So **signature-check stripping may not be the thing we actually need.** What
we may need instead is just:

1. A **decrypted, unmodified** iBEC for this device (same AES-decrypt our
   scripts already do — no signature bypass, just undoing Apple's encryption
   with keys ipsw.me publishes).
2. A way to tell it which partition to boot from. Patching `rd=disk0sN` into
   the binary is one way (what 4tify does); **setting it as a persistent NVRAM
   variable instead** (`nvram boot-args="rd=disk0s3 -v"`, run as root on the
   jailbroken host — a standard, long-documented jailbreak/debug operation,
   not a security bypass) may be another, if the stock iBEC reads boot-args
   from NVRAM the normal way.

If that works, the entire bootchain stays Apple's own signed, unmodified
files, and no RSA-check patcher is ever run or shipped, on a computer or the
phone, by anyone.

**What's genuinely unverified, not assumed:**

- Whether a stock iBEC, started via kexec instead of a cold boot, checks
  anything that would fail here (it may still verify the *kernelcache* it
  loads next, for instance).
- Whether Apple is **currently signing iOS 4.0/4.1 for this exact device**
  (its ECID) at all. If not, even a fully stock chain needs a saved SHSH
  blob and ticket, which is a separate, nontrivial problem — this is a
  real, answerable question (a TSS query, no file patching involved) and
  worth checking before anything else here.
- Whether `multi_kloader` (two images: iBSS + iBEC) is required, or our
  single-file `kloader` can kexec straight into a decrypted iBEC alone.

**What I won't do:** build, compile, or run a tool whose job is to strip
RSA/signature verification from Apple's bootloader, for a computer or for
the phone. That specific action was blocked by this session's own safety
system when attempted directly on this device's real firmware, and packaging
the same capability for later or different execution doesn't change what it
is. The decrypt-only scripts already in this repo (`img3.py`, `20-decrypt.sh`)
are a different, unaffected category — plain AES decryption, no verification
bypass — and remain fine to use, as they have been throughout this project.

## Options

- **A. Follow 4tify** (host 7.1.2, second OS 4.3): exists, but gives up 4.1 and
  needs a Mac.
- **B. Pioneer partitioning on the 4.1 host:** matches the goal, but is new
  research. Needs a computer, a way to put 4.1 back (Legacy iOS Kit, how the
  phone got 4.1), and ideally a spare iPhone 4 to rehearse on.
- **C. Stay RAM-only** (what works today): safe, but no persistent second OS.

## Before any partition step

- The output of `thr0wback info` and `thr0wback disk` from the phone, so the 4.1 layout is known.
- Computer with the ramdisk tooling, and a tested way to restore 4.1.
- Full battery, and a backup of anything on the phone (it may be wiped).
- A spare iPhone 4 to rehearse on, if at all possible.
- A written, reviewed list of exact commands for the 4.1 layout.

## Open questions

- ~~Slice names, sizes and free space.~~ Answered (Test 5): fully allocated, 12224 MB
  free inside Data.
- How do you shrink the EMF-typed Data slice on iOS 4.1 safely? No guide found.
- Can a patched iBEC started by kloader boot from a second partition on a 4.1 host?
- ~~What do `boot.sh` and the 4tify app do?~~ Answered above.
- How are the patched `iBSS` / `iBEC` made, and where does `multi_kloader` come from? Not in the repo.
- What does `TwistedMind2` write?

## Not read

`nyansatan.github.io/dualboot/*`, `merculous.github.io/dualboot/patching.html`
and the `theiphonewiki.com` pages could not be opened from this session
(blocked by its network settings). Only search-result summaries were seen, so
treat anything from them as unverified.

## Sources

- https://github.com/Zurac-Apps/4tify
- https://github.com/codealize/iPhone4DualbootiOS4
- https://nyansatan.github.io/dualboot/partitioning.html (summary only)
- https://www.theiphonewiki.com/wiki/Kloader (summary only)
- https://www.theiphonewiki.com/wiki/CoolBooter (summary only)
- https://raw.githubusercontent.com/Zurac-Apps/4tify/master/Create-Restore.sh
- https://raw.githubusercontent.com/Zurac-Apps/4tify/master/Restore.sh
- https://raw.githubusercontent.com/Zurac-Apps/4tify/master/support_files/4.3/Patches/boot.sh
- https://raw.githubusercontent.com/Zurac-Apps/4tify/master/support_files/4.3/Patches/fstab
- https://github.com/Zurac-Apps/4tify-iPad2
- https://github.com/axi0mX/ios-kexec-utils
- https://theapplewiki.com/wiki/LwVM (summary only)
- https://es.slideshare.net/seguridadapple/iphone-data-protection-in-depth (summary only)
