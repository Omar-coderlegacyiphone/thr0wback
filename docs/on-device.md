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

`thr0wback boot <target>` boots whatever sits at
`/var/mobile/thr0wback/<target>/kernel.macho` — a single **raw, decompressed**
kernel (kloader itself refuses IMG3/IM4P files and has no further handoff
logic; see `docs/kloader-port.md` for why one file is all it needs for the
jump itself). Producing that file is the decrypt + decompress pipeline already
in this repo:

```
scripts/img3.py decrypt <target-version-kernelcache.img3> --key ... --iv ... -o complzss.bin
scripts/lzss.py decompress complzss.bin -o kernel.macho
```
then drop `kernel.macho` into `/var/mobile/thr0wback/<target>/` on the phone.
Either on-device (if these get ported to run under the phone's own Python/shell)
or prepped elsewhere and copied over — either way it comes from **your**
firmware, not the repo.

**Getting a kernel to jump is not the same as getting a second OS to boot.**
See "The one real gap" in `docs/kloader-port.md` — the realistic first
milestone is proving the jump itself (even just a panic banner from the other
version's kernel is a real result), not a fully usable second OS on the first
try.

## First test milestones

1. Install the `.deb` (Cydia / Filza / `dpkg -i`).
2. **tfp0 sanity check first** — put *any* placeholder file at
   `/var/mobile/thr0wback/test/kernel.macho` and run `thr0wback boot test`.
   Watch for `kernel_base: 0x...` printing before it fails on bad content —
   that confirms `task_for_pid(0)` works under this jailbreak at all, which is
   the one precondition everything else depends on.
3. Once that's confirmed, prepare a real **4.0** `kernel.macho` and
   `thr0wback boot 4.0`. See what lands on screen.
4. Only after a jump is confirmed working does the harder "mount a matching
   root filesystem" question become worth chasing.

If a boot hangs, hold **Power+Home** to return to your normal iOS. Nothing is
written to the active system.
