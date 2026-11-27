# On-device test results

Run by the device owner on the real target: **iPhone 4 GSM (iPhone3,1), iOS 4.1
(8B117), untethered jailbreak from Legacy iOS Kit / powdersn0w**, with kloader
from `axi0mX/ios-kexec-utils` (sha256
`e5a5625b758492930c5c51012731de20bb86c39fb5a78684b7485add40bdda33`). Results were
read off the phone's screen, so timings are approximate.

## Packaging: what it took to install on iOS 4.1

| .deb | Result |
|---|---|
| 0.1.0 (Ubuntu `dpkg-deb` default) | Cydia: `dpkg-deb --control returned error exit status 2`. The members were zstd, which iOS 4's dpkg can't read. |
| hand-built `ar` attempt | Never reached the phone. `dpkg-deb` rejected it: `debian-binary` had no trailing newline. |
| 0.1.1, 0.1.2 (`dpkg-deb -Zgzip --root-owner-group`) | Installs. Members must be exactly `debian-binary`, `control.tar.gz`, `data.tar.gz`. |

## Test 1: can kloader get into the kernel?

`kloader /var/mobile/nothing` (a file that doesn't exist, on purpose):

- `kern.version: ... xnu-1504.55.33~10/RELEASE_ARM_S5L8930X`
- `kernel_base: 0x80000000`
- `ERROR: Failed to open the image file.` (the only failure, as intended)
- Screen went off and came back about 2 s later (kloader's sleep + auto-wake).

**Conclusion:** `task_for_pid(0)` works under this jailbreak.

## Test 2: does the jump happen? (`thr0wback test`)

Image: `/usr/share/thr0wback/selftest.bin`, 4096 bytes made for this repo (not
Apple's). Word 0 is `0xea00000e` (branch to `+0x40`); the word at `+0x40` is
`0xeafffffe` (`b .`, spin forever).

Printed: `Read image into buffer ... length: 4096`,
`larm_init_tramp: 0x80065008`, `Magic happening now. Device should wake up in 2.0 seconds.`

- `0x80065008` is what an offline re-run of kloader's pattern search predicted on
  the decrypted 8B117 and 8A293 kernels, so the live kernel matches the files we
  analysed.
- **Run 1:** the phone woke back into normal iOS after about 2 s (no jump at the
  auto-wake). It was not restarted. Later it went black by itself and needed
  Power+Home. Most likely the hook was still in RAM and fired on the next real
  sleep/wake. Battery was also low, so this is not proven.
- **Run 2:** same output. The phone did not come back and stayed black until
  Power+Home.
- **Run 3:** the owner said "same test, same thing". Which result that meant was
  never confirmed, so run 3 is unknown. (An earlier version of these notes
  recorded it as a hit; that was an assumption.)
- **Run 4 (next day):** the phone went off for about 2 s and came back to normal
  iOS: no jump.
- **Run 5:** an immediate redo of run 4. The phone stayed black: the jump worked.

Runs 6 to 8 were filmed by the owner (launcher 0.1.6, so no log). Timings are
from frames of the videos, so they are approximate:

- **Run 6:** a first attempt. The screen went dark about 0.3 s after the
  `kernel_base` line printed, stayed dark about 2.4 s, then the terminal came
  back showing "Magic happening now": a miss.
- **Run 7:** an immediate redo of run 6, no restart (run 6's output was still on
  screen). Dark about 0.3 s after `kernel_base` again, and it was still black
  when the video ended 2.9 s or more later: a hit.
- **Run 8:** a first attempt in a fresh terminal (whether the phone had just been
  restarted is not known). This time the terminal printed everything up to
  "Magic happening now" and the screen stayed on for about **3.6 s more** before
  going dark. The video ends 0.9 s after that, too soon to show whether it came
  back; the owner's caption says "Stays off", so it is counted as a hit.

**Conclusion:** the wake hook works and code we supply gets executed on this iOS
version. The 2-second auto-wake is **not reliable**: of the runs with a
known result, 4 hit (runs 2, 5, 7, 8) and 3 missed (runs 1, 4, 6). Every redo
straight after a miss hit (3 of 3); first attempts hit 1 of 4 (run 3 unknown).

Ideas, unproven. (a) A miss may mean the phone had not fully powered down inside
the 2 s window (for example while still busy after a restart), so the wake took
the normal path. Run 1's later random freeze fits the hook having been installed
but not triggered by that wake. (b) Runs may miss more often as the first
attempt after a restart. (c) kloader writes its kernel patch just as the phone starts to sleep. If the patch
is still only in the CPU cache when the CPU powers down, the wake reads the
original code (a miss) and a later sleep flushes it, so a redo hits and an
un-restarted phone freezes later. Prediction: after a miss, the next sleep
jumps. (d) Supporting hint from the videos: in the two quick-sleep runs (6, 7)
the screen went dark within ~0.3 s of `kernel_base`; run 6 missed, and run 7 hit
only because run 6's patch was already there. In run 8 the sleep came ~3.6 s
after kloader had finished writing, and it hit on a first attempt. So a slow
sleep may mean the patch is flushed in time. Three videos are not proof. To
check, 0.1.7 records every attempt (see Open items).

## Test 3: storage layout (`thr0wback info`, 0.1.3, read-only)

Phone: iPhone 4 GSM, 16 GB (iPhone3,1), kernel 10.3.1 (iOS 4.1).

- Mounted: `/dev/disk0s1` on `/` (hfs, noatime) and `/dev/disk0s2s1` on
  `/private/var` (hfs, journaled, noatime, protect).
- Disk names: `disk0 disk0s1 disk0s2 disk0s2s1 disk0s3 disk0s4`.
- fstab: `/dev/disk0s1 / hfs rw 0 1`, `/dev/disk0s2s1 /private/var hfs rw 0 2`.
- Tools found: `newfs_hfs fsck_hfs mount_hfs dd fdisk`. Not found: `asr`, `gptfdisk`.

**Conclusions:** the 4.1 layout is the old style (root `disk0s1`, var
`disk0s2s1`), not the iOS 5+ LwVM names (`disk0s1s1`, `disk0s1s2`). `disk0s3`
and `disk0s4` already exist and are not mounted; what they hold is unknown
(4tify's scripts use these same two names for the second OS on its 7.1.2 host).
The partition and format tools exist on the phone itself. Still unknown: slice
sizes, the table type (`fdisk` is present, so probably MBR) and free space.
`thr0wback disk` follows up (Test 4).

## Test 4: partition table (`thr0wback disk`, 0.1.4, read-only)

Only the lower half of the output fit on the screen (the free-space lines
scrolled off).

- `fdisk /dev/rdisk0`: sector size **8192 bytes**, geometry `975/32/63`
  (1,965,744 sectors, about 16.1 GB, the whole disk). Entry 1 is id **EE**
  (GPT protective MBR) covering sectors 1 to 1,965,743. Entries 2 to 4 are unused.
- `disk0s3` and `disk0s4`: the HFS-signature check said "not HFS (empty or other)".
  **Withdrawn:** the same check also called the mounted root `disk0s1` not HFS, so
  it did not work on this phone (see Test 5).

**Conclusions:** the real partition table is a **GPT** behind a protective MBR
(fdisk can't list GPT slices, so their names and sizes are still unseen). The
disk's sectors are 8192 bytes, so GPT LBAs are 8 KB. `thr0wback disk` (0.1.5)
reads the GPT entries directly (Test 5).

## Test 5: GPT slices (`thr0wback disk`, 0.1.5, read-only)

Output, as photographed:

```
/: 628 MB used, 880 MB free
/private/var: 1600 MB used, 12224 MB free
GPT: 8192-byte sectors, 15357 MB usable
#1 System        1524 MB  type 00534648
#2 Data         13824 MB  type 00464d45
#3 Apple HFS+       8 MB  type 00534648
#4 Apple HFS+       0 MB  type 00534648
free after the last slice: 0 MB
HFS volumes: none
not HFS: disk0s1 disk0s2 disk0s2s1 disk0s3 disk0s4
```

- Type `00534648` is the bytes `00 'S' 'F' 'H'`, the first field `48465300` of
  Apple's HFS GUID. `00464d45` is `00 'F' 'M' 'E'`, first field `454d4600`, the
  ASCII letters "EMF". Probably Apple's encrypted-data partition type (iOS 4
  wraps the data volume, which would explain the nested `disk0s2s1`). That is my
  reading and is unverified.
- **The disk is fully allocated:** 1524 + 13824 + 8 + under 1 MB, and under 1 MB
  free after the last slice. A second OS needs space from somewhere.
- `/private/var` has 12224 MB free inside the 13824 MB Data slice, so that is the
  only place the space can come from, by shrinking it.
- `disk0s3` (8 MB) and `disk0s4` (under 1 MB) are tiny HFS-typed slots, far too
  small for a second OS.
- **Correction:** the last two lines ("HFS volumes: none / not HFS: ...") are
  wrong. The same check calls the mounted root `disk0s1` not HFS. It read 1024
  bytes from a block device with 8192-byte sectors, which probably fails.
  Test 4's claim that `disk0s3` / `disk0s4` aren't HFS is therefore withdrawn.
  0.1.6 drops that check and shows the GPT type (HFS / EMF) instead.

## Corrected understanding

kloader runs its file as a **bootloader-style image** at physical `0x5f000000`
after the wake, not as a kernel Mach-O. It warns unless word 0 is `0xea00000e`,
and prints iBoot banner strings from `+0x200/+0x240/+0x280`. `thr0wback boot`
used to look for `kernel.macho`; since 0.1.3 it runs a decrypted `ibec.bin`.
See `docs/kloader-port.md`.

## Open items

1. Run a real decrypted iBEC (owner's own firmware, never committed) via kloader
   and observe.
2. ~~Change `thr0wback boot` to use `ibec.bin`.~~ Done in 0.1.3 (untested with a real iBEC).
3. Auto-wake reliability: since 0.1.7 `thr0wback test` retries up to 3 times and
   logs every attempt to `/var/mobile/thr0wback/test-log.txt` (uptime at the
   start, and a START with nothing after it means the phone froze). `thr0wback
   log` summarises hits per run. Collect runs, including ones right after a
   restart, and paste the log here. The 2.0 s delay is a compile-time constant
   in the prebuilt binary.
4. Root filesystem / second-OS storage (the big one).
5. ~~Run `thr0wback info`~~ Done, see Test 3. Next: `thr0wback disk` (0.1.5, reads the
   GPT) for slice names, sizes and free space.

## Safety notes

- The hook lives in RAM: **restart after every run** (Power+Home, about 10 s).
- A black, frozen phone after `thr0wback test` is the expected "jump worked"
  result, not damage.
- A low battery makes results ambiguous. Charge first.
