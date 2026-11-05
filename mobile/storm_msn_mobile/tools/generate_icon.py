#!/usr/bin/env python3
"""Draw original Storm MSN Mobile launcher icons using only Python stdlib.

No Microsoft asset or third-party font is embedded in the launcher icon.
"""
import math
from pathlib import Path
import struct
import zlib

ROOT = Path(__file__).resolve().parents[1] / "android/app/src/main/res"
SIZES = {"mdpi": 48, "hdpi": 72, "xhdpi": 96, "xxhdpi": 144, "xxxhdpi": 192}

def oval(x,y,cx,cy,rx,ry):
    return ((x-cx)/rx)**2 + ((y-cy)/ry)**2 <= 1.0

def square(x,y):
    r=0.18
    a=max(abs(x-0.5)-(0.5-r),0.0)
    b=max(abs(y-0.5)-(0.5-r),0.0)
    return a*a+b*b <= r*r

def shade(x,y):
    if not square(x,y):
        return (0,0,0,0)
    blue = (14+int(15*y), 116+int(76*(1-y)), 194+int(30*(1-y)))
    if oval(x,y,.76,.12,.57,.40):
        blue=(min(255,blue[0]+26),min(255,blue[1]+19),min(255,blue[2]+9))
    # Original two-person Storm symbol, separate from WLM trademark graphics.
    if oval(x,y,.65,.73,.275,.205) or oval(x,y,.63,.34,.129,.125):
        return (248,169,44,255)
    if oval(x,y,.38,.72,.276,.22) or oval(x,y,.34,.335,.14,.14):
        return (101,204,51,255)
    if oval(x,y,.27,.23,.063,.052):
        return (249,255,255,220)
    return (*blue,255)

def png_chunk(kind,data):
    return struct.pack(">I",len(data))+kind+data+struct.pack(">I",zlib.crc32(kind+data)&0xffffffff)

def generate(n):
    # 2x SSAA stabilizes edges on 48px and 72px launcher icons.
    data=bytearray()
    for y in range(n):
        data.append(0)
        for x in range(n):
            pix=[shade((x+dx)/n,(y+dy)/n) for dx,dy in ((.25,.25),(.75,.25),(.25,.75),(.75,.75))]
            data.extend(sum(c[i] for c in pix)//4 for i in range(4))
    out=b"\x89PNG\r\n\x1a\n"+png_chunk(b"IHDR",struct.pack(">IIBBBBB",n,n,8,6,0,0,0))
    out+=png_chunk(b"IDAT",zlib.compress(bytes(data),9))+png_chunk(b"IEND",b"")
    return out

for dpi,size in SIZES.items():
    dest=ROOT / ("mipmap-"+dpi) / "ic_launcher.png"
    dest.write_bytes(generate(size))
    print(dpi, len(dest.read_bytes()), dest)

