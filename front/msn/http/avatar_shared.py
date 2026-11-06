"""Shared Windows Live Messenger 2009 and mobile avatar storage.

Desktop SOAP user tiles were written to a nonpersistent relative path.
This module unifies their storage with the Docker /data volume.
"""
import base64
import binascii
import io
import json
import os
import re
import secrets
from pathlib import Path
from xml.etree import ElementTree

from PIL import Image, ImageOps

DATA = Path("/data")
AVATAR_DIR = DATA / "avatars"
LEGACY_ROOT = DATA / "storage" / "dp"
CACHE_ROOT = DATA / "legacy_tiles"
INDEX_FILE = CACHE_ROOT / "msnobj_index.json"
UUID_RE = re.compile(r"^[a-fA-F0-9-]{36}$")
EXTS = ("jpeg", "jpg", "png", "gif", "webp")


def storage_path(uuid):
    if not UUID_RE.fullmatch(uuid):
        raise ValueError("Invalid user UUID")
    return LEGACY_ROOT / uuid[:1] / uuid[:2]


def _find_legacy(uuid):
    for root in (storage_path(uuid), Path("storage/dp") / uuid[:1] / uuid[:2]):
        for ext in EXTS:
            candidate = root / (uuid + "." + ext)
            if candidate.is_file() and candidate.stat().st_size > 0:
                return candidate
    return None


def _msnobj_digest(raw):
    if not isinstance(raw, str) or len(raw) > 4096:
        return None
    try:
        root = ElementTree.fromstring(raw)
        encoded = root.attrib.get("SHA1D", "")
        sha = base64.b64decode(encoded, validate=True)
        return sha.hex() if len(sha) == 20 else None
    except (ElementTree.ParseError, ValueError, binascii.Error):
        return None


def record_msnobj(uuid, raw):
    digest = _msnobj_digest(raw)
    if not digest or not UUID_RE.fullmatch(uuid):
        return
    CACHE_ROOT.mkdir(parents=True, exist_ok=True)
    try:
        index = json.loads(INDEX_FILE.read_text()) if INDEX_FILE.is_file() else {}
        if not isinstance(index, dict):
            index = {}
    except (ValueError, OSError):
        index = {}
    if index.get(uuid) == digest:
        return
    index[uuid] = digest
    path = CACHE_ROOT / ("." + secrets.token_hex(6) + ".tmp")
    try:
        path.write_text(json.dumps(index))
        os.replace(path, INDEX_FILE)
    finally:
        path.unlink(missing_ok=True)


def avatar_path(uuid, backend=None):
    """Most recent own/desktop-uploaded photo or a matching MSNObject cache."""
    canonical = AVATAR_DIR / (uuid + ".jpg")
    legacy = _find_legacy(uuid)
    direct = [p for p in (canonical, legacy) if p and p.is_file()]
    if direct:
        return max(direct, key=lambda p: p.stat().st_mtime)
    digest = None
    if backend is not None:
        try:
            user = backend.user_service.get(uuid)
            if user:
                for session in backend.util_get_sessions_by_user(user):
                    digest = _msnobj_digest(session.front_data.get("msn_msnobj"))
                    if digest:
                        record_msnobj(uuid, session.front_data["msn_msnobj"])
                        break
        except (AttributeError, KeyError, TypeError):
            pass
    if not digest and INDEX_FILE.is_file():
        try:
            index = json.loads(INDEX_FILE.read_text())
            digest = index.get(uuid)
        except (ValueError, OSError):
            pass
    if digest and re.fullmatch(r"[a-f0-9]{40}", digest):
        for extension in (".png", ".gif"):
            path = CACHE_ROOT / (digest + extension)
            if path.is_file() and path.stat().st_size > 0:
                return path
    return None


def normalize_avatar(raw):
    """Check dimensions/type and convert any supported bitmap to small JPEG."""
    if not raw or len(raw) > 4 * 1024 * 1024:
        raise ValueError("Image too large")
    with Image.open(io.BytesIO(raw)) as picture:
        if picture.width * picture.height > 16_000_000:
            raise ValueError("Image dimensions too large")
        if picture.format not in ("JPEG", "PNG", "WEBP", "GIF"):
            raise ValueError("Invalid image type")
        picture = ImageOps.exif_transpose(picture)
        fitted = ImageOps.fit(picture.convert("RGB"), (256, 256),
                              method=Image.Resampling.LANCZOS)
        stream = io.BytesIO()
        fitted.save(stream, format="JPEG", quality=86, optimize=True)
        return stream.getvalue()


def _write_atomic(path, payload):
    path.parent.mkdir(parents=True, exist_ok=True)
    temp = path.with_name("." + secrets.token_hex(8) + ".tmp")
    try:
        temp.write_bytes(payload)
        temp.chmod(0o644)
        os.replace(temp, path)
    finally:
        temp.unlink(missing_ok=True)


def write_shared_avatar(uuid, raw):
    """Publish the same photo to the mobile API and WLM storage service."""
    converted = normalize_avatar(raw)
    storage = storage_path(uuid)
    _write_atomic(AVATAR_DIR / (uuid + ".jpg"), converted)
    _write_atomic(storage / (uuid + ".jpeg"), converted)
    # WLM static GetProfile expects thumbnail with *same* extension.
    with Image.open(io.BytesIO(converted)) as picture:
        small = picture.resize((21, 21), Image.Resampling.LANCZOS)
        data = io.BytesIO()
        small.save(data, "JPEG", quality=82)
        _write_atomic(storage / (uuid + "_thumb.jpeg"), data.getvalue())
    # Eliminate obsolete variants to prevent nondeterministic GetProfile.
    for ext in EXTS:
        if ext == "jpeg":
            continue
        for suffix in ("", "_thumb"):
            (storage / (uuid + suffix + "." + ext)).unlink(missing_ok=True)
    return converted


def remove_shared_avatar(uuid):
    (AVATAR_DIR / (uuid + ".jpg")).unlink(missing_ok=True)
    storage = storage_path(uuid)
    for ext in EXTS:
        for suffix in ("", "_thumb"):
            (storage / (uuid + suffix + "." + ext)).unlink(missing_ok=True)

