"""Turns the ABC 47.16 blocks that ASC 2.0 writes into ABC 46.16, which Flash Player 32 verifies.

47.16 only adds a float constant pool after the doubles: it must be empty, and is dropped.
The SWF must be uncompressed (mxmlc -compress=false). Usage: abc46.py in.swf out.swf"""
import struct, sys

def u30(buf, p):
    value = shift = 0
    while True:
        b = buf[p]
        p += 1
        value |= (b & 0x7F) << shift
        shift += 7
        if not b & 0x80:
            return value, p

def patch_abc(abc):
    minor, major = struct.unpack_from("<HH", abc, 0)
    if (major, minor) != (47, 16):
        return abc
    p = 4
    for size in (None, None, 8):  # ints, uints (u30 each), doubles (8 bytes each)
        count, p = u30(abc, p)
        for _ in range(max(0, count - 1)):
            if size is None:
                _, p = u30(abc, p)
            else:
                p += size
    floats, end = u30(abc, p)
    if floats > 1:
        sys.exit("the ABC uses float constants, which ABC 46.16 cannot hold")
    return struct.pack("<HH", 16, 46) + abc[4:p] + abc[end:]

def main(src, dst):
    data = open(src, "rb").read()
    if data[:3] != b"FWS":
        sys.exit("compile with -compress=false")
    nbits = data[8] >> 3
    pos = 8 + (5 + 4 * nbits + 7) // 8 + 4
    out = bytearray(data[:pos])
    while pos < len(data):
        code_len = struct.unpack_from("<H", data, pos)[0]
        code, length, head = code_len >> 6, code_len & 0x3F, 2
        if length == 0x3F:
            length, head = struct.unpack_from("<I", data, pos + 2)[0], 6
        body = data[pos + head:pos + head + length]
        if code in (72, 82):  # DoABC, DoABC2
            prefix = b""
            if code == 82:
                name_end = body.index(b"\0", 4) + 1
                prefix, body = body[:name_end], body[name_end:]
            body = prefix + patch_abc(body)
            out += struct.pack("<HI", (code << 6) | 0x3F, len(body)) + body
        else:
            out += data[pos:pos + head + length]
        pos += head + length
        if code == 0:
            break
    struct.pack_into("<I", out, 4, len(out))
    open(dst, "wb").write(bytes(out))

main(sys.argv[1], sys.argv[2])
