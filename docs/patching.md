# Patching

This is the stage that turns decrypted stock images into ones a tethered
limera1n boot will accept. It is the **least-verified** part of the project and
the one that must be confirmed by an actual boot on the phone.

## What gets patched, and why

| Image | Patch | Why |
|---|---|---|
| **iBSS** | signature check | So it loads our (patched) iBEC instead of only Apple-signed ones. |
| **iBEC** | signature check + boot-args | Same, plus it sets the kernel boot-args. We boot `-v` (verbose) so the first boots print a log we can read. |
| **kernelcache** | AMFI / `cs_enforcement_disable` / `task_for_pid` / RSA | So a modified or iOS-3 userland can run. Needed for the hybrid; **not** needed just to watch how far the bootchain gets. |

The phone's own NAND bootloaders are never written. limera1n uploads these
patched images into RAM over USB; a reboot returns to the untethered 4.1 install.

## The version problem (read this before trusting `30-patch-boot.sh`)

`iBoot32Patcher` (what `30-patch-boot.sh` calls) was written against **iOS 5–9**
iBoots. The iPhone 4 iOS 4.0 iBoot is **889.24**. That gap is real: the
patcher's byte-pattern finders may simply not match an iBoot this old, and the
script will stop with a "failed on iBSS/iBEC" error. That is an expected
outcome, not a bug in the script.

Two ways forward when that happens:

1. **redsn0w fallback (recommended for the 4.0 baseline).** redsn0w natively
   supports iPhone 4 / iOS 4.0 and can tethered-boot a custom/patched 4.x. For
   the *baseline proof* (that we can boot a second 4.x at all), redsn0w is the
   shorter path and a known-good reference. Use it to confirm the phone + flow
   work, then compare against our own pipeline.
2. **Version-specific patches.** If we want our own pipeline to own the 889
   bootchain, the signature-check patch becomes a direct byte patch located for
   889.24 specifically, rather than via iBoot32Patcher's generic finder.

## The hybrid (iOS 3) has no existing tool

For the iOS 3 experiment there is no redsn0w path — nothing targets "iOS 3
userland on an iPhone 4 bootchain." That stage is genuinely custom: patch the
4.0 kernelcache for unsigned code, then resolve each userland/kernel interface
break (IOKit, IOMobileFramebuffer, OpenGL ES, launchd) by hand from the verbose
boot log. This is the research frontier of the project and comes only after the
4.0 baseline boots.

## Order of operations

```
20-decrypt.sh        # decrypt stock images              (verified)
30-patch-boot.sh     # patch iBSS/iBEC                   (shape correct; 889 untested)
40-boot-tethered.sh  # limera1n upload + boot -v         (not written yet)
# then, for the hybrid:
#   patch kernelcache, assemble iOS 3 userland, iterate on the boot log
```
