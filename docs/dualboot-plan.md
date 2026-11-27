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
   second OS boots from the new partition instead of the main one. kloader is
   what starts these.
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

## The catch for this project

1. **It doesn't keep the 4.1 host.** The existing method restores to 7.1.2 first.
2. **Only iOS 4.3 as the second OS**, not 4.0 to 7.1.2.
3. **Not phone-only.** Partitioning runs from an SSH ramdisk booted from a
   computer over DFU.
4. **Nobody has documented a dual boot from a 4.1 host.** Unknown: the 4.1
   partition table type (search summaries say LwVM arrived in iOS 5, and 4tify
   swaps LwVM for GPT on 7.1.2), whether the same partition numbers work, and
   whether a patched iBEC boots from a second partition on 4.1.
5. **The partition step can lose data or stop iOS 4.1 booting.** Recovery means
   restoring from a computer.

## Options

- **A. Follow 4tify** (host 7.1.2, second OS 4.3): exists, but gives up 4.1 and
  needs a Mac.
- **B. Pioneer partitioning on the 4.1 host:** matches the goal, but is new
  research. Needs a computer, a way to put 4.1 back (Legacy iOS Kit, how the
  phone got 4.1), and ideally a spare iPhone 4 to rehearse on.
- **C. Stay RAM-only** (what works today): safe, but no persistent second OS.

## Before any partition step

- The output of `thr0wback info` from the phone, so the 4.1 layout is known.
- Computer with the ramdisk tooling, and a tested way to restore 4.1.
- Full battery, and a backup of anything on the phone (it may be wiped).
- A spare iPhone 4 to rehearse on, if at all possible.
- A written, reviewed list of exact commands for the 4.1 layout.

## Open questions

- What partition table does iOS 4.1 use, and what do `disk0s1` / `disk0s2` hold?
  (`thr0wback info`, 0.1.3, is read-only and should show this. Paste its output here.)
- Can a patched iBEC started by kloader boot from a second partition on a 4.1 host?
- What do `boot.sh` and the 4tify app do?
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
