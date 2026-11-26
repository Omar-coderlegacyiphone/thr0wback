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
- **Run 3:** the owner reported "same test, same thing", i.e. the same result as
  run 2 (stayed black until Power+Home).

**Conclusion:** the wake hook works and code we supply gets executed on this iOS
version. Not yet established: how reliable the 2-second auto-wake is on its own
(run 1 missed, runs 2 and 3 hit; too few runs to call it reliable, and the
reason for the miss is unknown).

## Corrected understanding

kloader runs its file as a **bootloader-style image** at physical `0x5f000000`
after the wake, not as a kernel Mach-O. It warns unless word 0 is `0xea00000e`,
and prints iBoot banner strings from `+0x200/+0x240/+0x280`. `thr0wback boot`
still looks for `kernel.macho` and needs to change to a decrypted `ibec.bin`.
See `docs/kloader-port.md`.

## Open items

1. Run a real decrypted iBEC (owner's own firmware, never committed) via kloader
   and observe.
2. Change `thr0wback boot` to use `ibec.bin`.
3. Auto-wake reliability: repeat runs. The 2.0 s delay is a compile-time constant.
4. Root filesystem / second-OS storage (the big one).

## Safety notes

- The hook lives in RAM: **restart after every run** (Power+Home, about 10 s).
- A black, frozen phone after `thr0wback test` is the expected "jump worked"
  result, not damage.
- A low battery makes results ambiguous. Charge first.
