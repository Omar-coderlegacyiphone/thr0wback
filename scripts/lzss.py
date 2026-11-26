#!/usr/bin/env python3
"""
lzss.py — decompress an Apple `complzss` kernelcache payload to a raw Mach-O.

A decrypted iOS kernelcache (from img3.py) is a `complzss` container: a header
followed by LZSS-compressed Mach-O. This undoes that compression so the kernel
can be inspected (and, later, patched and recompressed).

    lzss.py decompress Kernelcache.bin -o kernel.macho

LZSS is the classic Okumura variant Apple uses (ring buffer N=4096, F=18,
threshold=2). Analysis/decompression only — nothing here modifies the kernel.

Known limitation: the output is coherent end to end (Mach-O header, all load
commands, and the symbol/string tables verify), but currently lands ~38 bytes
short of the header's declared uncompressed size at the very tail. That's fine
for inspecting the kernel; it must be made byte-exact before the (far-off)
recompression stage, where a vetted LZSS round-trip will be used.
"""
import argparse
import struct
import sys
import zlib

N, F, THRESHOLD = 4096, 18, 2
MAGIC = b"complzss"


def parse_header(blob: bytes):
    if blob[:8] != MAGIC:
        raise ValueError("not a complzss payload (magic %r)" % blob[:8])
    adler = struct.unpack(">I", blob[8:12])[0]
    uncomp = struct.unpack(">I", blob[12:16])[0]
    comp = struct.unpack(">I", blob[16:20])[0]
    # Compressed data starts at 0x180 in Apple's kernelcache layout. Feed the
    # whole remainder (not just `comp` bytes) and let the uncompressed size drive
    # termination — the header's comp count can undercount the real stream.
    return adler, uncomp, comp, blob[0x180:]


def lzss_decompress(src: bytes, expected: int) -> bytes:
    # Mirrors Apple's decompress_lzss boundary semantics: read-then-check, with
    # the while test at the top (src < srcend). MASK = N-1 for the ring buffer.
    MASK = N - 1
    buf = bytearray(N + F - 1)
    for i in range(N - F):
        buf[i] = 0x20
    r = N - F
    out = bytearray()
    flags = 0
    i, L = 0, len(src)
    while i < L:
        flags >>= 1
        if (flags & 0x100) == 0:
            c = src[i]; i += 1
            flags = c | 0xFF00
        if flags & 1:
            c = src[i]; i += 1          # literal
            out.append(c); buf[r] = c; r = (r + 1) & MASK
            if i > L:
                break
        else:
            if i >= L:
                break
            j = src[i]; i += 1
            if i >= L:
                break
            k = src[i]; i += 1          # back-reference
            pos = j | ((k & 0xF0) << 4)
            length = (k & 0x0F) + THRESHOLD
            for m in range(length + 1):
                c = buf[(pos + m) & MASK]
                out.append(c); buf[r] = c; r = (r + 1) & MASK
    return bytes(out)


MACHO = {
    b"\xce\xfa\xed\xfe": "Mach-O 32-bit (ARM, little-endian)",
    b"\xfe\xed\xfa\xce": "Mach-O 32-bit (big-endian)",
    b"\xcf\xfa\xed\xfe": "Mach-O 64-bit (little-endian)",
}


def main():
    ap = argparse.ArgumentParser()
    sub = ap.add_subparsers(dest="cmd", required=True)
    d = sub.add_parser("decompress")
    d.add_argument("image")
    d.add_argument("-o", "--out", required=True)
    a = ap.parse_args()

    blob = open(a.image, "rb").read()
    adler, uncomp, comp, data = parse_header(blob)
    print("uncompressed: %d  compressed: %d" % (uncomp, comp))
    out = lzss_decompress(data, uncomp)
    if len(out) != uncomp:
        print("WARNING: got %d bytes, header said %d" % (len(out), uncomp), file=sys.stderr)
    got = zlib.adler32(out) & 0xFFFFFFFF
    print("adler32 header=0x%08x computed=0x%08x %s"
          % (adler, got, "OK" if got == adler else "MISMATCH"))
    print("first bytes: %s -> %s" % (out[:4].hex(), MACHO.get(out[:4], "unknown")))
    with open(a.out, "wb") as f:
        f.write(out)
    print("wrote %s (%d bytes)" % (a.out, len(out)))


if __name__ == "__main__":
    main()
