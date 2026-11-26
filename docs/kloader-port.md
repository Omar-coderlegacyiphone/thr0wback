# kloader port — iPhone 4 / iOS 4.1 (Option B)

Goal: an **on-device** booter that runs from a jailbroken **iOS 4.1** host, so a
second OS boots with no computer. This is the moonshot path — it can only be
confirmed by booting the actual phone — but the groundwork below shows it's
genuinely feasible, not hopeless.

## Why it's safe to try

kloader does a **kexec in RAM**: it loads a kernel and jumps into it. It never
writes the NAND, the bootloaders, or the baseband. A failed boot = hold
Power+Home and you're back in your untethered 4.1, jailbreak intact. So trying
this cannot cost you the 4.1 jailbreak you worked for.

## What we reuse vs. replace

The `kloader.c` kexec engine (winocm lineage, via `trident-kloader`) is **not**
as version-locked as expected — it already knows the iPhone 4's SoC:

```c
#define S5L8930_PHYS_OFF 0x40000000       // iPhone 4 RAM base
if (strcasestr(osversion, "s5l8930x")) {  // iPhone 4 SoC
    PHYS_OFF = S5L8930_PHYS_OFF;
    phys_addr_remap = 0x5fe00000;
}
```

- **Reuse:** `kloader.c` — the kexec engine. Gets kernel r/w via
  `task_for_pid(0)` + `vm_read/vm_write`. Fetched in CI, credited, not vendored.
- **Drop:** `exploit.c` + `offsetfinder.c` — both are 100% iOS 9 (Trident
  exploit + 9.x offset tables). We don't need them: **4.1 is already
  jailbroken**, so kernel access already exists.

## Kernel access on 4.1

Two routes, both available on jailbroken iOS 4 (and both gone by iOS 6):

1. **`task_for_pid(0)`** — if the 4.1 jailbreak grants tfp0 (common), kloader.c
   works almost as-is (it already uses tfp0).
2. **`/dev/kmem`** — present and accessible on jailbroken iOS 4; a direct kernel
   memory interface. A clean fallback shim if tfp0 isn't granted.

## Offsets — the usually-hard part is easy here

The 4.x kernelcache is **fully symbolicated**, so `scripts/ksyms.py` reads the
addresses straight out. Reference set (iOS 4.0 / 8A293) in
`config/offsets-iPhone3,1-8A293.json`:

| symbol | 4.0 / 8A293 |
|---|---|
| `_kernel_pmap` | `0x80245218` |
| `_kernel_map`  | `0x80265adc` |
| `_kernel_task` | `0x802653e0` |
| `_copyin` / `_copyout` | `0x80066c60` / `0x80066ce0` |

**These are 4.0 values.** Your phone runs **4.1 (8B117)**, whose kernel differs.
Before on-device use, extract 4.1's offsets the same way:
`ksyms.py` on the decrypted 4.1 kernelcache. One command, once we pull that IPSW.

## Remaining work

1. Fetch + decrypt the **4.1 (8B117)** kernelcache; extract its offsets.
2. Strip Trident/offsetfinder; wire the 4.1 kernel-access shim (tfp0 or /dev/kmem).
3. Build armv7 (min-version 4.0) in CI; package in the `.deb`.
4. **On-device test** (the only real verdict).

Feasibility is established: the engine supports the SoC, kernel access exists on
4.1, and the offsets are readable. What's left is the shim + build + the boot
itself.
