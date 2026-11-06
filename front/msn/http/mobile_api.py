"""Authenticated Storm MSN mobile profile and avatar endpoints."""
import asyncio
import io
import os
import re
import secrets
from pathlib import Path

from aiohttp import web
from PIL import Image, ImageOps, UnidentifiedImageError
from . import avatar_shared
from sqlalchemy import func

from core.conn import Conn
from core.db import User as DBUser, LoginToken as DBLoginToken
import settings

EMAIL_RE = re.compile(r"^[A-Za-z0-9._%+\-]{1,64}@[A-Za-z0-9.\-]{3,190}$")
USER_RE = re.compile(r"^[A-Za-z0-9_.\-]{3,24}$")
AVATAR_DIR = avatar_shared.AVATAR_DIR
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
    # Persisted login tokens survive Docker restarts. Older in-memory tokens
    # are accepted during migration until their original expiry.
    backend = req.app["backend"]
    token_data = backend.login_auth_service.get_token("storm-mobile", token)
    if token_data is None:
        token_data = backend.auth_service.get_token("storm-mobile", token)
    if not token_data:
        raise web.HTTPUnauthorized(text="Sessão expirada. Autentique novamente.")
    user_uuid = token_data[0] if isinstance(token_data, (list, tuple)) else token_data
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
    # Per-device HTTPS bearer session, persisted to SQLite instead of RAM.
    # 30-day lifetime; the app can renew or reauthenticate without logout.
    ticket, _ = req.app["backend"].login_auth_service.create_token(
        "storm-mobile", [uuid], lifetime=30 * 86400
    )
    with Conn(settings.DB).session() as sess:
        user = sess.query(DBUser).filter(DBUser.uuid == uuid).one()
        profile = {"email": user.email, "username": user.username}
    return web.json_response(
        {**profile, "token": ticket}, headers=RESP_HEADERS
    )


async def mobile_refresh(req):
    user = _authorized_user(req)
    auth = req.headers.get("Authorization", "")
    token = auth[7:]
    backend = req.app["backend"]
    ticket, _ = backend.login_auth_service.create_token(
        "storm-mobile", [user["uuid"]], lifetime=30 * 86400
    )
    # Also revoke a pre-migration token from RAM during rotation.
    backend.auth_service.pop_token('storm-mobile', token)
    with Conn(settings.DB).session() as sess:
        sess.query(DBLoginToken).filter(
            DBLoginToken.token == token,
            DBLoginToken.purpose == "storm-mobile",
        ).delete()
    return web.json_response(
        {"email": user["email"], "username": user["username"],
         "token": ticket},
        headers=RESP_HEADERS,
    )


async def mobile_logout(req):
    _authorized_user(req)
    token = req.headers.get("Authorization", "")[7:]
    req.app['backend'].auth_service.pop_token('storm-mobile', token)
    with Conn(settings.DB).session() as sess:
        sess.query(DBLoginToken).filter(
            DBLoginToken.token == token,
            DBLoginToken.purpose == "storm-mobile",
        ).delete()
    return web.json_response({"ok": True}, headers=RESP_HEADERS)


async def mobile_profile(req):
    user = _authorized_user(req)
    return web.json_response(
        {"email": user["email"], "username": user["username"]},
        headers=RESP_HEADERS,
    )


async def avatar_get(req):
    email = req.match_info.get("email", "").strip().lower()
    if not EMAIL_RE.fullmatch(email):
        raise web.HTTPNotFound()
    with Conn(settings.DB).session() as sess:
        user = sess.query(DBUser).filter(func.lower(DBUser.email) == email).one_or_none()
        if not user:
            raise web.HTTPNotFound()
        uuid = user.uuid
    source = avatar_shared.avatar_path(uuid, req.app.get("backend"))
    if source is None:
        raise web.HTTPNotFound()
    ext = source.suffix.lower()
    mime = ("image/jpeg" if ext in (".jpeg", ".jpg")
            else "image/png" if ext == ".png"
            else "image/gif" if ext == ".gif" else "image/webp")
    return web.FileResponse(source, headers={
        "Content-Type": mime,
        "Cache-Control": "no-cache, must-revalidate",
        "X-Content-Type-Options": "nosniff",
        "Access-Control-Allow-Origin": "https://msn.hoststorm.com.br",
    })


async def avatar_post(req):
    user = _authorized_user(req)
    if not _rate(req, "avatar-upload", 20, 3600):
        raise web.HTTPTooManyRequests(text="Muitas imagens enviadas.")
    limit = 4 * 1024 * 1024
    if req.content_length and req.content_length > limit:
        raise web.HTTPRequestEntityTooLarge(max_size=limit,
                                             actual_size=req.content_length)
    raw = await req.content.read(limit + 1)
    if not raw or len(raw) > limit:
        raise web.HTTPRequestEntityTooLarge(max_size=limit,
                                             actual_size=len(raw))
    try:
        avatar_shared.write_shared_avatar(user["uuid"], raw)
    except (UnidentifiedImageError, OSError, ValueError):
        raise web.HTTPBadRequest(
            text="Imagem inválida. Envie JPG, PNG ou WebP com até 4 MB."
        )
    return web.json_response({
        "ok": True,
        "avatar_url": "/api/mobile/avatar/" + user["email"],
    }, headers=RESP_HEADERS)


async def avatar_delete(req):
    user = _authorized_user(req)
    avatar_shared.remove_shared_avatar(user["uuid"])
    return web.json_response({"ok": True}, headers=RESP_HEADERS)


def register(app):
    app.router.add_post("/api/mobile/session", mobile_session)
    app.router.add_post("/api/mobile/session/refresh", mobile_refresh)
    app.router.add_post("/api/mobile/session/logout", mobile_logout)
    app.router.add_get("/api/mobile/profile", mobile_profile)
    app.router.add_get("/api/mobile/avatar/{email}", avatar_get)
    app.router.add_post("/api/mobile/avatar", avatar_post)
    app.router.add_delete("/api/mobile/avatar", avatar_delete)

