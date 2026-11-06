"""Capability-URL image and file attachments for Storm MSN.

MSNP7 remains text-only. The attachment is uploaded to an authenticated HTTPS
endpoint and a short opaque HTTPS URL is sent through the existing chat.
Anyone possessing a URL can download it: this is not end-to-end encryption.
"""
import mimetypes
import os
import re
import secrets
import time
import urllib.parse
from pathlib import Path
from io import BytesIO

from aiohttp import web
from PIL import Image, UnidentifiedImageError

from .mobile_api import _authorized_user, _rate

STORAGE = Path("/data/mobile-attachments")
MAX_BYTES = 8 * 1024 * 1024
MAX_AGE_SECONDS = 14 * 86400
KEY_RE = re.compile(r"^[a-f0-9]{48}$")
NAME_RE = re.compile(r"^[A-Za-z0-9._() -]{1,100}$")
ALLOWED = {
    ".jpg": "image/jpeg",
    ".jpeg": "image/jpeg",
    ".png": "image/png",
    ".gif": "image/gif",
    ".webp": "image/webp",
    ".pdf": "application/pdf",
    ".txt": "text/plain",
    ".zip": "application/zip",
    ".docx": "application/vnd.openxmlformats-officedocument.wordprocessingml.document",
    ".xlsx": "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet",
}
PHOTO_EXTS = {".jpg", ".jpeg", ".png", ".gif", ".webp"}


def _valid_file(raw, suffix):
    if len(raw) < 4 or len(raw) > MAX_BYTES:
        return False
    if suffix in PHOTO_EXTS:
        try:
            with Image.open(BytesIO(raw)) as img:
                if img.format not in ("JPEG", "PNG", "GIF", "WEBP"):
                    return False
                if img.width * img.height > 24_000_000:
                    return False
                # Actually decode rather than trusting the extension.
                img.verify()
                kind = img.format.lower()
                return (
                    (suffix in (".jpg", ".jpeg") and kind == "jpeg")
                    or kind == suffix[1:]
                )
        except (UnidentifiedImageError, ValueError, OSError):
            return False
    if suffix == ".pdf":
        return raw.startswith(b"%PDF-")
    if suffix in (".zip", ".docx", ".xlsx"):
        return raw.startswith(b"PK\x03\x04")
    if suffix == ".txt":
        try:
            raw.decode("utf-8")
            return b"\x00" not in raw
        except UnicodeError:
            return False
    return False


def _name(raw):
    if not isinstance(raw, str) or len(raw) > 300:
        raise web.HTTPBadRequest(text="Nome do arquivo inválido.")
    parsed = urllib.parse.unquote(raw)
    parsed = parsed.rsplit("/", 1)[-1].rsplit("\\", 1)[-1].strip()
    if not NAME_RE.fullmatch(parsed) or parsed.startswith("."):
        raise web.HTTPBadRequest(text="Use nomes de arquivo simples, sem caracteres especiais.")
    ext = Path(parsed).suffix.lower()
    if ext not in ALLOWED:
        raise web.HTTPUnsupportedMediaType(text="Formato não permitido.")
    return parsed, ext


async def upload(req):
    _authorized_user(req)
    if not _rate(req, "mobile-attachment", 25, 3600):
        raise web.HTTPTooManyRequests(text="Limite de anexos atingido.")
    name, ext = _name(req.headers.get("X-Storm-Filename", ""))
    if req.content_length is not None and req.content_length > MAX_BYTES:
        raise web.HTTPRequestEntityTooLarge(
            max_size=MAX_BYTES, actual_size=req.content_length)
    payload = await req.content.read(MAX_BYTES + 1)
    if not _valid_file(payload, ext):
        raise web.HTTPBadRequest(text="Arquivo inválido ou maior que 8 MB.")
    STORAGE.mkdir(parents=True, mode=0o700, exist_ok=True)
    key = secrets.token_hex(24)
    dest = STORAGE / (key + ext)
    temp = STORAGE / (key + ".tmp")
    try:
        temp.write_bytes(payload)
        temp.chmod(0o600)
        os.replace(temp, dest)
    finally:
        temp.unlink(missing_ok=True)
    # Cleanup opportunistically on upload. No remote delete promise.
    for item in STORAGE.iterdir():
        try:
            if item.is_file() and item.stat().st_mtime < time.time() - MAX_AGE_SECONDS:
                item.unlink(missing_ok=True)
        except OSError:
            pass
    return web.json_response(
        {"url": "https://msn.hoststorm.com.br/api/mobile/attachment/" + key,
         "name": name, "mime": ALLOWED[ext], "expires_days": 14},
        headers={"Cache-Control": "no-store"},
    )


async def download(req):
    key = req.match_info.get("key", "")
    if not KEY_RE.fullmatch(key):
        raise web.HTTPNotFound()
    item = next((p for ext in ALLOWED
                 if (p := STORAGE / (key + ext)).is_file()), None)
    if item is None or time.time() - item.stat().st_mtime > MAX_AGE_SECONDS:
        raise web.HTTPNotFound()
    mime = ALLOWED[item.suffix]
    disposition = "inline" if item.suffix in PHOTO_EXTS else "attachment"
    return web.FileResponse(item, headers={
        "Content-Type": mime,
        "Content-Disposition": disposition + '; filename="storm-msn' +
                               item.suffix + '"',
        "Cache-Control": "private, max-age=120",
        "X-Content-Type-Options": "nosniff",
        "Referrer-Policy": "no-referrer",
        "X-Robots-Tag": "noindex",
        "Content-Security-Policy": "default-src 'none'; sandbox",
    })


def register(app):
    app.router.add_post("/api/mobile/attachment", upload)
    app.router.add_get("/api/mobile/attachment/{key}", download)

