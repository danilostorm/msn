"""Voice-note service for Storm MSN mobile, independent of legacy MSNP7 binary frames.

A sent MSNP7 text message contains the opaque HTTPS URL. This allows the
desktop client to open the audio link without altering the legacy protocol.
The bearer token is required for upload; download is capability-URL based.
"""
import os
import re
import secrets
import time
from pathlib import Path

from aiohttp import web

from .mobile_api import _authorized_user, _rate

STORAGE = Path("/data/voice-notes")
MAX_BYTES = 3 * 1024 * 1024
MAX_AGE_SECONDS = 30 * 86400
VOICE_RE = re.compile(r"^[a-f0-9]{48}$")


def _valid_m4a(raw: bytes) -> bool:
    # MP4 family: length followed by ftyp. Reject arbitrary files/HTML.
    return (len(raw) >= 32 and raw[4:8] == b"ftyp"
            and any(t in raw[8:32] for t in (b"M4A ", b"isom", b"mp42", b"M4B "))
            and raw[:4] != b"\x00\x00\x00\x00")


async def upload_voice(req):
    user = _authorized_user(req)
    if not _rate(req, "voice-upload", 30, 3600):
        raise web.HTTPTooManyRequests(text="Limite de mensagens de voz.")
    if req.content_length and req.content_length > MAX_BYTES:
        raise web.HTTPRequestEntityTooLarge(max_size=MAX_BYTES,
                                             actual_size=req.content_length)
    if req.content_type not in ("audio/mp4", "audio/x-m4a", "application/octet-stream"):
        raise web.HTTPUnsupportedMediaType(text="Envie áudio AAC/M4A.")
    raw = await req.content.read(MAX_BYTES + 1)
    if len(raw) > MAX_BYTES:
        raise web.HTTPRequestEntityTooLarge(max_size=MAX_BYTES,
                                             actual_size=len(raw))
    if not _valid_m4a(raw):
        raise web.HTTPBadRequest(text="Áudio M4A inválido.")
    STORAGE.mkdir(mode=0o750, parents=True, exist_ok=True)
    key = secrets.token_hex(24)
    tmp = STORAGE / (key + ".tmp")
    destination = STORAGE / (key + ".m4a")
    try:
        tmp.write_bytes(raw)
        os.chmod(tmp, 0o640)
        os.replace(tmp, destination)
    finally:
        tmp.unlink(missing_ok=True)
    # Opportunistic retention cleanup, not a background worker.
    for name in STORAGE.glob("*.m4a"):
        try:
            if name.stat().st_mtime < time.time() - MAX_AGE_SECONDS:
                name.unlink(missing_ok=True)
        except OSError:
            continue
    url = "https://msn.hoststorm.com.br/api/mobile/voice/" + key
    return web.json_response(
        {"url": url, "format": "audio/mp4", "expires_days": 30},
        headers={"Cache-Control": "no-store", "X-Content-Type-Options": "nosniff"},
    )


async def download_voice(req):
    key = req.match_info.get("key", "")
    if not VOICE_RE.fullmatch(key):
        raise web.HTTPNotFound()
    filename = STORAGE / (key + ".m4a")
    if not filename.is_file() or time.time() - filename.stat().st_mtime > MAX_AGE_SECONDS:
        raise web.HTTPNotFound()
    return web.FileResponse(filename, headers={
        "Content-Type": "audio/mp4",
        "Content-Disposition": 'inline; filename="mensagem-de-voz.m4a"',
        "Cache-Control": "private, max-age=300",
        "Referrer-Policy": "no-referrer",
        "X-Content-Type-Options": "nosniff",
        "X-Robots-Tag": "noindex",
        "Content-Security-Policy": "default-src 'none'",
    })


def register(app):
    app.router.add_post("/api/mobile/voice", upload_voice)
    app.router.add_get("/api/mobile/voice/{key}", download_voice)

