"""Authenticated Storm MSN mobile profile and avatar endpoints."""
import asyncio
import io
import os
import re
import secrets
from pathlib import Path

from aiohttp import web
from PIL import Image, ImageOps, UnidentifiedImageError
from sqlalchemy import func

from core.conn import Conn
from core.db import User as DBUser
import settings

EMAIL_RE = re.compile(r"^[A-Za-z0-9._%+\-]{1,64}@[A-Za-z0-9.\-]{3,190}$")
USER_RE = re.compile(r"^[A-Za-z0-9_.\-]{3,24}$")
AVATAR_DIR = Path("/data/avatars")
RESP_HEADERS = {
    "Cache-Control": "no-store",
    "X-Content-Type-Options": "nosniff",
    "Referrer-Policy": "no-referrer",
}


def _rate(req, tag, limit, period):
    # Reuse the same per-IP request limiter used by the portal.
    from .portal import rate
    return rate(req, tag, limit, period)


def _authorized_user(req):
    auth = req.headers.get("Authorization", "")
    if not auth.startswith("Bearer "):
        raise web.HTTPUnauthorized()
    token = auth[7:]
    if not re.fullmatch(r"[A-Za-z0-9._\-]{16,2048}", token):
        raise web.HTTPUnauthorized()
    user_uuid = req.app["backend"].auth_service.get_token("storm-mobile", token)
    if not user_uuid:
        raise web.HTTPUnauthorized()
    with Conn(settings.DB).session() as sess:
        user = sess.query(DBUser).filter(DBUser.uuid == user_uuid).one_or_none()
        if not user:
            raise web.HTTPUnauthorized()
        return {"uuid": user.uuid, "email": user.email, "username": user.username}


async def mobile_session(req):
    if not _rate(req, "mobile-login", 15, 600):
        raise web.HTTPTooManyRequests(text="Muitas tentativas. Aguarde.")
    if req.content_length and req.content_length > 2048:
        raise web.HTTPRequestEntityTooLarge(max_size=2048, actual_size=req.content_length)
    try:
        payload = await req.json()
    except Exception:
        raise web.HTTPBadRequest(text="Formato inválido.")
    identifier = str(payload.get("identifier", "")).strip().lower()
    password = str(payload.get("password", ""))
    if not (EMAIL_RE.fullmatch(identifier) or USER_RE.fullmatch(identifier)) or len(password) > 128 or not password:
        raise web.HTTPUnauthorized(text="Usuário, e-mail ou senha inválidos.")
    with Conn(settings.DB).session() as sess:
        field = DBUser.email if "@" in identifier else DBUser.username
        user = sess.query(DBUser).filter(func.lower(field) == identifier).one_or_none()
        if not user:
            raise web.HTTPUnauthorized(text="Usuário, e-mail ou senha inválidos.")
        address = user.email
    # Check the original password verifier, never copy/save a password.
    uuid = req.app["backend"].user_service.login(address, password)
    if not uuid:
        raise web.HTTPUnauthorized(text="Usuário, e-mail ou senha inválidos.")
    ticket, _ = req.app["backend"].auth_service.create_token(
        "storm-mobile", uuid, lifetime=43200
    )
    with Conn(settings.DB).session() as sess:
        user = sess.query(DBUser).filter(DBUser.uuid == uuid).one()
        profile = {"email": user.email, "username": user.username}
    return web.json_response(
        {**profile, "token": ticket}, headers=RESP_HEADERS
    )


async def mobile_profile(req):
    user = _authorized_user(req)
    return web.json_response(
        {"email": user["email"], "username": user["username"]},
        headers=RESP_HEADERS,
    )


async def avatar_get(req):
    email = req.match_info.get("email", "").lower()
    if not EMAIL_RE.fullmatch(email):
        raise web.HTTPNotFound()
    with Conn(settings.DB).session() as sess:
        user = sess.query(DBUser).filter(func.lower(DBUser.email) == email).one_or_none()
        if not user:
            raise web.HTTPNotFound()
        path = AVATAR_DIR / (user.uuid + ".jpg")
    if not path.is_file():
        raise web.HTTPNotFound()
    return web.FileResponse(
        path,
        headers={
            "Content-Type": "image/jpeg",
            "Cache-Control": "public, max-age=120",
            "X-Content-Type-Options": "nosniff",
        },
    )


async def avatar_post(req):
    user = _authorized_user(req)
    if not _rate(req, "avatar-upload", 20, 3600):
        raise web.HTTPTooManyRequests()
    if req.content_length and req.content_length > 2 * 1024 * 1024:
        raise web.HTTPRequestEntityTooLarge(max_size=2*1024*1024, actual_size=req.content_length)
    raw = await req.content.read(2 * 1024 * 1024 + 1)
    if not raw or len(raw) > 2 * 1024 * 1024:
        raise web.HTTPRequestEntityTooLarge(max_size=2*1024*1024, actual_size=len(raw))
    try:
        with Image.open(io.BytesIO(raw)) as img:
            if img.width * img.height > 16_000_000:
                raise ValueError("Dimensão excessiva.")
            if img.format not in ("JPEG", "PNG", "WEBP"):
                raise ValueError("Formato inválido.")
            img = ImageOps.exif_transpose(img)
            img = ImageOps.fit(img.convert("RGB"), (256, 256), method=Image.Resampling.LANCZOS)
            out = io.BytesIO()
            img.save(out, format="JPEG", quality=85, optimize=True)
            processed = out.getvalue()
    except (UnidentifiedImageError, OSError, ValueError):
        raise web.HTTPBadRequest(text="Use uma imagem JPG, PNG ou WebP válida.")
    AVATAR_DIR.mkdir(parents=True, exist_ok=True)
    destination = AVATAR_DIR / (user["uuid"] + ".jpg")
    temporary = AVATAR_DIR / (user["uuid"] + "." + secrets.token_hex(6) + ".tmp")
    try:
        temporary.write_bytes(processed)
        temporary.chmod(0o644)
        os.replace(temporary, destination)
    finally:
        temporary.unlink(missing_ok=True)
    return web.json_response({"ok": True, "avatar_url": "/api/mobile/avatar/" + user["email"]}, headers=RESP_HEADERS)


async def avatar_delete(req):
    user = _authorized_user(req)
    (AVATAR_DIR / (user["uuid"] + ".jpg")).unlink(missing_ok=True)
    return web.json_response({"ok": True}, headers=RESP_HEADERS)


def register(app):
    app.router.add_post("/api/mobile/session", mobile_session)
    app.router.add_get("/api/mobile/profile", mobile_profile)
    app.router.add_get("/api/mobile/avatar/{email}", avatar_get)
    app.router.add_post("/api/mobile/avatar", avatar_post)
    app.router.add_delete("/api/mobile/avatar", avatar_delete)

