# On-device (phone-only) flow

The goal: no computer to *run* it. You install one `.deb` on the jailbroken
iPhone and boot a second OS from the phone itself, CoolBooter-style, using
**kloader**.

A computer (or CI) still **builds** the `.deb` once — but that's open-source
components only, and you just install the result.

## What the .deb contains

- `kloader` — the open-source on-device loader (boots a prepared bootchain out
  of the running iOS; no USB).
- `/usr/bin/thr0wback` — the launcher. Run `thr0wback` for a menu (press a number), or use
  `test` / `log` / `info` / `disk` / `list` / `boot <target>` directly.
- `/usr/share/thr0wback/selftest.bin` — a 4 KB do-nothing image for `thr0wback test`.

It does **not** contain any Apple firmware. That stays off the public repo for
copyright reasons; it's supplied per-device, from your own firmware.

## The honest gap: preparing a target

kloader jumps to a **raw bootloader-style image** (a decrypted iBEC/iBSS, first
word `0xea00000e`), not to a kernel Mach-O; see `docs/test-results.md`.
`thr0wback boot <target>` (0.1.3) runs `<target>/ibec.bin`, a decrypted iBEC.
`thr0wback test` needs no Apple files, and `thr0wback info` only reads and
shows how the phone's storage is laid out.

Whatever the image is, it comes from **your** firmware, never the repo: decrypt
with `scripts/img3.py` (keys from ipsw.me), keep it raw (not IMG3), and put it
in `/var/mobile/thr0wback/<target>/` on the phone.

**Getting code to run is not the same as getting a second OS to boot.** See
"The one real gap" in `docs/kloader-port.md`.

## Test milestones

1. ✅ Install the `.deb` through Cydia (members must be gzip; see
   `docs/test-results.md`).
2. ✅ `kloader /var/mobile/nothing` printed `kernel_base: 0x80000000`, so
   `task_for_pid(0)` works under this jailbreak.
3. ✅ `thr0wback test` hooked the wake path (`larm_init_tramp: 0x80065008`) and
   the phone ran our 4 KB image (stuck black until Power+Home).
4. Next: a real decrypted iBEC through kloader, then the root-filesystem
   question.

If the phone hangs, hold **Power+Home**. Restart after every run, because the
hook stays in RAM until a reboot. Nothing is written to the active system.
