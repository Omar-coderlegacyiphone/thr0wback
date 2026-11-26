#!/usr/bin/env python3
"""
ksyms.py — pull kernel symbol addresses from a decompressed iOS kernelcache.

The iPhone 4 iOS 4.0/4.1 kernelcache ships with a full symbol table, so the
addresses a kloader port needs (kernel_pmap, kernel_map, kernel_task, ...) can
be read directly instead of pattern-scanned. Feed it the Mach-O that lzss.py
produces.

    ksyms.py <kernel.macho> [symbol ...]        # default: the kloader set
    ksyms.py <kernel.macho> --json              # dump all as JSON

Analysis only — reads a Mach-O symbol table, changes nothing.
"""
import json
import struct
import sys

# What a kloader port for this platform wants to know.
DEFAULT = [
    "_kernel_pmap", "_kernel_map", "_kernel_task",
    "_PE_i_can_has_debugger", "_flush_dcache", "_invalidate_icache",
    "_IOLog", "_copyin", "_copyout", "_cpu_number",
]


def read_symbols(path):
    d = open(path, "rb").read()
    if d[:4] not in (b"\xce\xfa\xed\xfe", b"\xfe\xed\xfa\xce"):
        raise SystemExit("not a 32-bit Mach-O (run lzss.py decompress first)")
    _, _, _, _, ncmds = struct.unpack("<5I", d[:20])
    off = 28
    syms = {}
    for _ in range(ncmds):
        cmd, csize = struct.unpack("<2I", d[off:off + 8])
        if cmd == 2:  # LC_SYMTAB
            symoff, nsyms, stroff, strsize = struct.unpack("<4I", d[off + 8:off + 24])
            strtab = d[stroff:stroff + strsize]
            for i in range(nsyms):
                e = symoff + i * 12
                n_strx, n_type, n_sect, n_desc, n_value = struct.unpack("<IBBHI", d[e:e + 12])
                if n_value:
                    end = strtab.find(b"\x00", n_strx)
                    syms[strtab[n_strx:end].decode("latin1")] = n_value
        off += csize
    return syms


def main():
    if len(sys.argv) < 2:
        raise SystemExit(__doc__)
    path = sys.argv[1]
    rest = sys.argv[2:]
    syms = read_symbols(path)
    if "--json" in rest:
        print(json.dumps({k: "0x%08x" % v for k, v in sorted(syms.items())}, indent=2))
        return
    wanted = [a for a in rest if not a.startswith("--")] or DEFAULT
    for w in wanted:
        print("%-26s %s" % (w, ("0x%08x" % syms[w]) if w in syms else "NOT FOUND"))


if __name__ == "__main__":
    main()
