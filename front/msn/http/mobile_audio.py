"""Voice-note service for Storm MSN mobile, independent of legacy MSNP7 binary frames.

A sent MSNP7 text message contains the opaque HTTPS URL. This allows the
desktop client to open the audio link without altering the legacy protocol.
The bearer token is required for upload; download is capability-URL based.
"""
import os
import re
import secrets
import struct
import time
from pathlib import Path

from aiohttp import web

from .mobile_api import _authorized_user, _rate

STORAGE = Path("/data/voice-notes")
MAX_BYTES = 8 * 1024 * 1024
MAX_AGE_SECONDS = 30 * 86400
VOICE_RE = re.compile(r"^[a-f0-9]{48}$")


def _valid_m4a(raw: bytes) -> bool:
    """Reject truncated MP4/M4A. The old check accepted a file with 4 kB
    on disk while its mdat box declared 32 kB, making playback impossible.
    This is a structural check, not an AAC decoder.
    """
    if len(raw) < 128 or raw[4:8] != b"ftyp":
        return False
    if not any(t in raw[8:32] for t in (b"M4A ", b"isom", b"mp42", b"M4B ")):
        return False
    at = 0
    moov = False
    mdat = False
    box_count = 0
    while at < len(raw) and box_count < 256:
        if len(raw) - at < 8:
            return False
        size32, kind = struct.unpack_from(">I4s", raw, at)
        header = 8
        if size32 == 1:
            if len(raw) - at < 16:
                return False
            size = struct.unpack_from(">Q", raw, at + 8)[0]
            header = 16
        elif size32 == 0:
            size = len(raw) - at
        else:
            size = size32
        if size < header or at + size > len(raw):
            return False
        if kind == b"moov":
            moov = size > 100
        if kind == b"mdat":
            mdat = size - header >= 128
        at += size
        box_count += 1
    return at == len(raw) and moov and mdat


def _valid_wav(raw: bytes) -> bool:
    if len(raw) < 48 or raw[:4] != b"RIFF" or raw[8:12] != b"WAVE":
        return False
    if struct.unpack_from("<I", raw, 4)[0] + 8 != len(raw):
        return False
    position = 12
    fmt = audio_data = False
    while position + 8 <= len(raw):
        kind = raw[position:position + 4]
        size = struct.unpack_from("<I", raw, position + 4)[0]
        end = position + 8 + size
        if end > len(raw):
            return False
        if kind == b"fmt ":
            if size < 16:
                return False
            codec, channels, sample_rate, byte_rate, align, bits = struct.unpack_from(
                "<HHIIHH", raw, position + 8)
            if codec != 1 or channels != 1 or bits != 16 or not 8000 <= sample_rate <= 48000:
                return False
            if align != 2 or byte_rate != sample_rate * 2:
                return False
            fmt = True
        if kind == b"data" and size >= 3200 and size % 2 == 0:
            audio_data = True
        position = end + (size % 2)
    return fmt and audio_data and position == len(raw)


def _voice_type(raw: bytes):
    if _valid_wav(raw): return ".wav", "audio/wav"
    if _valid_m4a(raw): return ".m4a", "audio/mp4"
    return None


async def upload_voice(req):
    user = _authorized_user(req)
    if not _rate(req, "voice-upload", 30, 3600):
        raise web.HTTPTooManyRequests(text="Limite de mensagens de voz.")
    if req.content_length and req.content_length > MAX_BYTES:
        raise web.HTTPRequestEntityTooLarge(max_size=MAX_BYTES,
                                             actual_size=req.content_length)
    if req.content_type not in ("audio/mp4", "audio/x-m4a", "audio/wav",
                                 "audio/wave", "application/octet-stream"):
        raise web.HTTPUnsupportedMediaType(text="Envie áudio WAV ou AAC/M4A.")
    raw = await req.content.read(MAX_BYTES + 1)
    if len(raw) > MAX_BYTES:
        raise web.HTTPRequestEntityTooLarge(max_size=MAX_BYTES,
                                             actual_size=len(raw))
    detected = _voice_type(raw)
    if detected is None:
        raise web.HTTPBadRequest(
            text="Áudio incompleto ou formato inválido. Grave novamente."
        )
    extension, mimetype = detected
    STORAGE.mkdir(mode=0o750, parents=True, exist_ok=True)
    key = secrets.token_hex(24)
    tmp = STORAGE / (key + ".tmp")
    destination = STORAGE / (key + extension)
    try:
        tmp.write_bytes(raw)
        os.chmod(tmp, 0o640)
        os.replace(tmp, destination)
    finally:
        tmp.unlink(missing_ok=True)
    # Opportunistic retention cleanup, not a background worker.
    for pattern in ("*.m4a", "*.wav"):
        for name in STORAGE.glob(pattern):
            try:
                if name.stat().st_mtime < time.time() - MAX_AGE_SECONDS:
                    name.unlink(missing_ok=True)
            except OSError:
                continue
    url = "https://msn.hoststorm.com.br/api/mobile/voice/" + key
    return web.json_response(
        {"url": url, "format": mimetype, "expires_days": 30},
        headers={"Cache-Control": "no-store", "X-Content-Type-Options": "nosniff"},
    )


async def download_voice(req):
    key = req.match_info.get("key", "")
    if not VOICE_RE.fullmatch(key):
        raise web.HTTPNotFound()
    filename = next(
        (candidate for ext in (".wav", ".m4a")
         if (candidate := STORAGE / (key + ext)).is_file()), None)
    if filename is None or time.time() - filename.stat().st_mtime > MAX_AGE_SECONDS:
        raise web.HTTPNotFound()
    detected = _voice_type(filename.read_bytes())
    if detected is None or filename.suffix != detected[0]:
        raise web.HTTPGone(text="Áudio incompleto. Solicite nova gravação.")
    return web.FileResponse(filename, headers={
        "Content-Type": detected[1],
        "Content-Disposition": 'inline; filename="mensagem-de-voz' +
                               detected[0] + '"',
        "Cache-Control": "private, max-age=300",
        "Referrer-Policy": "no-referrer",
        "X-Content-Type-Options": "nosniff",
        "X-Robots-Tag": "noindex",
        "Content-Security-Policy": "default-src 'none'",
    })


def register(app):
    app.router.add_post("/api/mobile/voice", upload_voice)
    app.router.add_get("/api/mobile/voice/{key}", download_voice)

