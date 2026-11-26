#!/usr/bin/env python3
"""
img3.py — parse and decrypt IMG3 firmware images (32-bit iOS / A4-era devices).

IMG3 wraps a payload (iBSS, iBEC, kernelcache, DeviceTree, ...) in tagged
sections. The DATA tag holds the payload, encrypted with a per-image AES key/IV
(published for old builds; see the ipsw.me / AppleWiki key sets). This tool reads
the structure and, given key+IV, decrypts the DATA payload.

It does NOT modify signatures or defeat any check — it only decrypts firmware
with keys the owner supplies.

    img3.py info    <image.img3>
    img3.py decrypt <image.img3> --key HEX --iv HEX -o out.bin

AES is done via the openssl CLI (AES-256-CBC, no padding) so there's no Python
crypto dependency. Trailing bytes shorter than one block are copied through
undecrypted, matching how xpwntool/redsn0w handle IMG3 DATA.
"""
import argparse
import struct
import subprocess
import sys
import tempfile
import os

IMG3_MAGIC = b"3gmI"  # "Img3" stored little-endian


def parse(data: bytes):
    if data[:4] != IMG3_MAGIC:
        raise ValueError("not an IMG3 image (magic is %r)" % data[:4])
    full_size, size_no_pack, sig_area = struct.unpack("<III", data[4:16])
    ident = data[16:20][::-1]  # stored reversed, e.g. "ibss"
    tags = {}
    off = 20
    while off + 12 <= len(data):
        magic = data[off:off + 4][::-1]            # e.g. "ATAD" -> "DATA"
        total_len, data_len = struct.unpack("<II", data[off + 4:off + 12])
        if total_len < 12 or off + total_len > len(data):
            break
        tags.setdefault(magic, data[off + 12:off + 12 + data_len])
        off += total_len
    return ident, tags


def openssl_decrypt(blob: bytes, key_hex: str, iv_hex: str) -> bytes:
    """AES-256-CBC decrypt the block-aligned part; pass the short tail through."""
    aligned = (len(blob) // 16) * 16
    head, tail = blob[:aligned], blob[aligned:]
    with tempfile.NamedTemporaryFile(delete=False) as fin:
        fin.write(head)
        in_path = fin.name
    out_path = in_path + ".dec"
    try:
        subprocess.run(
            ["openssl", "enc", "-d", "-aes-256-cbc", "-nopad",
             "-K", key_hex, "-iv", iv_hex, "-in", in_path, "-out", out_path],
            check=True,
        )
        with open(out_path, "rb") as f:
            return f.read() + tail
    finally:
        for p in (in_path, out_path):
            try:
                os.unlink(p)
            except OSError:
                pass


def describe(payload: bytes) -> str:
    """Best-effort identification of a decrypted payload."""
    if payload[:8] == b"complzss":
        return "LZSS-compressed kernelcache (complzss)"
    if payload[:4] in (b"\xfe\xed\xfa\xce", b"\xce\xfa\xed\xfe",
                        b"\xfe\xed\xfa\xcf", b"\xcf\xfa\xed\xfe"):
        return "Mach-O"
    if b"iBoot-" in payload[:4096] or b"iBoot" in payload[:4096]:
        return "iBoot-class image (iBSS/iBEC/iBoot/LLB)"
    if payload[:4] == b"\xd0\x0d\xfe\xed" or b"CADT" in payload[:64]:
        return "DeviceTree"
    return "unknown"


def main():
    ap = argparse.ArgumentParser(description="parse/decrypt IMG3 images")
    sub = ap.add_subparsers(dest="cmd", required=True)
    p_info = sub.add_parser("info", help="print structure")
    p_info.add_argument("image")
    p_dec = sub.add_parser("decrypt", help="decrypt DATA payload")
    p_dec.add_argument("image")
    p_dec.add_argument("--key", required=True)
    p_dec.add_argument("--iv", required=True)
    p_dec.add_argument("-o", "--out", required=True)
    a = ap.parse_args()

    data = open(a.image, "rb").read()
    ident, tags = parse(data)

    if a.cmd == "info":
        print("ident     :", ident.decode("latin1"))
        print("tags      :", ", ".join(t.decode("latin1") for t in tags))
        d = tags.get(b"DATA")
        print("DATA bytes:", len(d) if d else 0)
        print("encrypted :", "yes (KBAG present)" if b"KBAG" in tags else "no KBAG")
        return

    payload = tags.get(b"DATA")
    if payload is None:
        sys.exit("no DATA tag in %s" % a.image)
    out = openssl_decrypt(payload, a.key, a.iv)
    with open(a.out, "wb") as f:
        f.write(out)
    print("wrote %s (%d bytes) — looks like: %s"
          % (a.out, len(out), describe(out)))


if __name__ == "__main__":
    main()
