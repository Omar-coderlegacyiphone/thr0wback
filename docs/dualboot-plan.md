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

**Update: iOS 4 predates Apple's current per-device signing system — this
probably matters a lot, and probably helps.** (Web search, sources below;
second-hand, not independently confirmed against primary Apple docs.)

- Apple's "every boot re-checks a device-personalized, nonce-based ticket"
  system (**APTicket**) started with **iOS 5** in 2011. For **iOS 4** and
  earlier, the per-device check ("SHSH blob") was **static** — the same
  blob for a given device + iOS version combination every time, not tied to
  a fresh random nonce. A 2012 jailbreak-community talk puts it plainly for
  this era: *"Only LLB & iBSS are SHSH signed"* — i.e. the device-specific
  check happens when loading **LLB and iBSS**, not at every later stage.
  (iH8sn0w, Jailbreakcon 2012 slides, via papers.put.as.)
- That's consistent with what we already found in `iBoot32Patcher`'s own
  source: it unconditionally runs `patch_rsa_check()` on every image
  ("All loaders have the RSA check" — its own comment), which reads as a
  **built-in, non-personalized** Apple-key signature check baked into the
  loader's code, separate from the device-specific SHSH/ticket system. For
  our use this matters because: **our phone is already past LLB/iBSS** (it's
  a running, booted OS) before kloader ever runs, so whichever check(s) only
  apply at that earlier stage don't apply to us at all.
- **What I checked directly:** ipsw.me currently shows iOS 4.1 (8B117) for
  iPhone3,1 as **"✗ This firmware is not signed"** — meaning Apple's live
  servers won't issue a new restore ticket for it today. But per the above,
  that live-signing-server gate is specifically the **iOS 5+ mechanism**;
  whether it has any bearing on a **static-era iOS 4.x file's own, baked-in**
  RSA check (not a live ticket check) is the open question just below. If
  the iOS 4.x-era check really is non-personalized, Apple's current signing
  status for 8B117/8A293 may be irrelevant to us — we're not doing a live
  restore, just decrypting a file we already hold and handing its bytes to
  kloader.

**What's still genuinely unverified, not assumed:**

- Whether a stock iBEC, started via kexec instead of a cold boot, still runs
  its own internal RSA check on the *kernelcache* it loads next (plausible,
  per `patch_rsa_check()` above), and whether that check is the
  non-personalized iOS-4-era kind or something stricter.
- Whether `multi_kloader` (two images: iBSS + iBEC) is required, or our
  single-file `kloader` can kexec straight into a decrypted iBEC alone.
- The only way to actually answer these is to try it: kexec a fully stock,
  decrypted (not patched) iBEC via `thr0wback boot` and see what happens.
  We already have one sitting in this repo's `work/iPhone3,1_8A293/dec/`
  from earlier project work (iBoot-889.24, decrypted months ago, never
  patched). This needs no storage/partition step first — a bare kexec jump
  into a stock file is itself the next real test, phone-only, once the
  file is on the phone.

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
- ~~Does the LwVM-vs-GPT split ("Addition 3: iOS 4 dualboot") apply to us?~~ No.
  That guide solves a **newer** (iOS 5+, LwVM) host running iOS 4.x as the
  second OS — the whole page is about forcing a modern host off LwVM and onto
  plain GPT so an old-style second OS can coexist, which needs a rejailbreak
  (redsn0w/Pangu7) because LwVM-vs-GPT changes partition device names. Our
  host (4.1) and our second OS (4.0, later the iOS 3/4.0 hybrid) are **both
  already** old-style GPT (Test 4-5) — there's no LwVM on either side, so
  there's no conflict to work around, and none of that page's steps apply.
  Bonus: its keybag-version table puts iOS 4.0-4.2.x in one bucket
  ("Version 1"); our host and target both fall inside it, so we likely also
  skip the keybag-downgrade dance it describes for mismatched-era pairs. Its
  iBEC auto-boot patches (`boot-command=upgrade`, `boot-partition`, skip
  ramdisk) are a nice-to-have for later polish, but run through `ibsspatch` —
  signature stripping, same category already ruled out below.

## Not read

`nyansatan.github.io/dualboot/*`, `merculous.github.io/dualboot/patching.html`
and the `theiphonewiki.com` pages could not be opened from this session
(blocked by its network settings). Only search-result summaries were seen, so
treat anything from them as unverified.

## `thr0wback fetch`'s curl is a dead end — the phone's TLS is too old, full stop

On the owner's real phone, `thr0wback fetch` (0.1.9) failed:
`curl: (35) error:1407742E:SSL routines:SSL23_GET_SERVER HELLO:tlsv1 alert
protocol version`. Forcing `--tlsv1` (0.1.10) changed the error but didn't fix
it: `error:1409442E:SSL routines:SSL3 READ BYTES:tlsv1 alert protocol
version` — getting further into the handshake, still rejected.

`curl --version` / `openssl version` on the phone: **curl 7.33.0, libcurl
linked directly against OpenSSL 0.9.8zg (11 Jun 2015)**. This is not a config
issue: **OpenSSL's 0.9.8 branch never implemented TLS 1.1 or 1.2 at all** —
the protocol code isn't in the library, so no flag can add it. `--tlsv1` was
already asking for the most this exact binary can do. A web search confirms
curl 7.33.0-9 / OpenSSL 0.9.8zg-13 is the last version either package ever
reached in the classic Cydia/Telesphoreo repo — there is no newer `curl` to
install for this platform. **This specific tool cannot be fixed.**

Visiting the same Apple URL in Safari gave "Access Denied" — initially read
(wrongly) as an unrelated anti-hotlinking block; more likely the same root
cause, since iOS 4.1's own system TLS dates from the same era and may have
the identical ceiling. Unconfirmed, but the simpler, more consistent
explanation given curl's now-confirmed hard limit.

**Next real candidate: TLSFix** (`github.com/ObscureMosquito/TLSFix` /
`nfzerox/TLSFix` — forked/renamed, same project; "Modern HTTPS for legacy
iPhone, iPad, and iPod touch running iOS 3 to iOS 9"). Per its README
(second-hand, only the GitHub README read): it's a MobileSubstrate tweak that
hooks **Apple's Secure Transport API** per-process and reroutes those calls
through a bundled **OpenSSL 1.1.1**, needs a separate modern root-certificate
bundle (`tlsroot.litten.ca`), and says to reboot after installing. Cydia
repos listed: `cydia.skyglow.es` or `nfzerox.github.io/cydia`.

**This would not have fixed `curl`** — confirmed, not just theoretical:
`curl --version` shows it's linked directly against its own OpenSSL, never
calling Secure Transport, so TLSFix's hook has nothing to intercept there.
It's a candidate for **Safari** specifically (and other apps using the
system's own networking), not for the standalone curl binary.

**Unverified:** whether TLSFix actually fixes Safari's connection on this
exact device (untested); whether old iOS 4-era Safari can even save an
arbitrary downloaded file once the connection works — historically it
could not without a tweak ("Safari Download Manager" / "Safari Download
Enabler", from BigBoss, works with iFile or a cloud service) built for
exactly that gap. If Safari does download it, it would be the **full ~600 MB
IPSW** (no Range control via browser UI), not the small slice `fetch` tries —
a new target-preparation path (`unzip -p` on an already-downloaded local
file, not a curl fetch) would be needed; the decrypt half of that is already
proven (see above).

## Getting a stock decrypted file onto the phone, with no computer

The project has always deliberately kept Apple's firmware out of the public
`.deb`/repo (see `build-deb.yml`'s own comment) — that's a copyright line we
shouldn't cross by bundling a decrypted Apple file into the public package
either. So a phone-only path means the **phone itself** fetches and decrypts
its own copy, the same way `scripts/10-fetch-ipsw.sh` + `scripts/img3.py`
already do on a computer: download from Apple's CDN, decrypt with the
published per-build AES key (ipsw.me's keys API) via `openssl enc`. Nothing
here is different in kind from what those scripts already do — same keys,
same operation, just run from a different machine.

The one snag: the file sits inside the IPSW's zip archive, compressed, and
downloading the whole IPSW (100+ MB) just for one 120 KB file is wasteful —
our host scripts use a partial-zip-read trick (fetch the small bits of the
zip structure needed, then range-fetch just the one entry). Reimplementing
that on-device needs *something* that can inflate a raw deflate stream
(`unzip`/`funzip`, `python3`'s `zlib`, or similar) — plain shell/dd alone
can't decompress.

**0.1.8 added a check for this to `thr0wback info`** (read-only): it reports
whether `curl`/`wget`, `openssl`, and a zip/deflate-capable tool
(`unzip`/`funzip`/`gzip`/`zcat`/`python3`/`python`/`perl`/`busybox`) are on
the phone already. Once we know what's there, the exact on-device
fetch+decrypt script writes itself around those tools. If nothing suitable
is there, `busybox` (a single, common, unprivileged Cydia package, not a
security tool) would add most of them at once.

## Phone-only fetch+decrypt: tested in this sandbox, mixed result

The owner's phone (`thr0wback info`, 0.1.8) has: `openssl unzip funzip gzip
zcat bzip2` — but **no `curl` or `wget`**: something to decrypt/unpack, but
nothing to download with.

**The decrypt half is solved and proven, using only those tools.** Built and
tested in this sandbox, entirely in POSIX shell + `dd`/`od`/`openssl` (no
Python): reading the exact IMG3 `DATA` tag by hand (offset/length parsed byte
by byte, same style as `thr0wback disk`'s GPT reader) and piping it through
`openssl enc -d -aes-256-cbc -nopad`. Result is **byte-identical** (same
SHA-256) to the iBEC this repo already decrypted with `img3.py` months ago.
Also proved: `funzip`, fed only a `{local file header}{compressed bytes}`
slice (no central directory, no whole-archive needed), decompresses a single
IPSW zip entry correctly — also byte-identical to `unzip -p`'s output. So
pulling one ~120 KB file out of a 600 MB IPSW, decompressing it, and
decrypting it needs no Python and no full download, just a correct byte
range.

**The download half is not solved.** With no `curl`/`wget`, I tried using
`openssl s_client` itself as a raw HTTPS client (handwritten HTTP/1.1
request, strip headers from the response). Tested against a local HTTPS test
server:
- A full-file transfer (≈600 MB) came back **byte-corrupted partway through**
  (diverged at byte ~54M of ~182M received before timing out) — `s_client`
  piped this way isn't reliable at that scale.
- A **range request** (the ~125 KB we'd actually need) avoids the scale
  problem, but my only local test server (`openssl s_server -WWW`) doesn't
  honor `Range` at all, so I could not verify real partial-content handling
  against anything resembling Apple's actual CDN. (This sandbox's outbound
  network goes through a proxy that blocks the raw TCP connect a real
  `s_client` test against Apple's servers would need, so that couldn't be
  tested directly either.)

Given a real, measured corruption failure on one path and an unverifiable
gap on the other, **I'm not shipping this as the download step.** The clean
fix: install `curl` via Cydia (BigBoss, Cydia's default repo, has shipped it
for exactly this device era — `apt-get install curl`). Ordinary network
tool, not a security-relevant install. One documented catch: Cydia's curl
build has sometimes lacked a default CA bundle, so HTTPS may need `-k` or an
explicit `--cacert`.

Once `curl` (or any reliable fetcher) is confirmed present, the decrypt half
above is ready to wire in as-is — that part doesn't need re-proving.

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
- https://papers.put.as/papers/ios/2012/iH8sn0w-Jailbreakcon2012.pdf (iOS 4 vs 5 signing era)
- https://ipsw.me/install/iPhone3,1/8B117/ (current signing status, checked)
- https://gist.github.com/2353599 (curl via Cydia/apt-get, CA-bundle caveat)
- https://theapplewiki.com/wiki/LwVM (summary only)
- https://es.slideshare.net/seguridadapple/iphone-data-protection-in-depth (summary only)
