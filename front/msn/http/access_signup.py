"""Validate the signed Cloudflare Access identity for public MSN signup."""
import asyncio
import base64
import json
import os
import time

from aiohttp import ClientSession, ClientTimeout, web
from cryptography.hazmat.primitives.asymmetric import padding, rsa
from cryptography.hazmat.primitives import hashes

TEAM_DOMAIN = "https://hoststorm.cloudflareaccess.com"
APP_AUDIENCE = "735b2775cb1bcd8ca9b6fe896b18b6034e3125b8a4811d7df392321921d2a300"
_jwks = {}
_expires_at = 0.0


def _decode(segment):
    return base64.urlsafe_b64decode(segment + "=" * (-len(segment) % 4))


async def verified_signup_email(req):
    """Return verified email only when Access-signed RS256 JWT is valid."""
    token = req.headers.get("Cf-Access-Jwt-Assertion", "")
    parts = token.split(".")
    if len(parts) != 3 or len(token) > 8192:
        raise web.HTTPForbidden(text="Primeiro confirme seu e-mail pelo Cloudflare Access.")
    try:
        header = json.loads(_decode(parts[0]))
        claims = json.loads(_decode(parts[1]))
        if header.get("alg") != "RS256" or not header.get("kid"):
            raise ValueError("Algoritmo inválido.")
        aud = claims.get("aud", [])
        if isinstance(aud, str):
            aud = [aud]
        now = time.time()
        if (APP_AUDIENCE not in aud or
                claims.get("iss", "").rstrip("/") != TEAM_DOMAIN or
                not isinstance(claims.get("exp"), (int, float)) or
                claims["exp"] < now or
                claims.get("nbf", 0) > now + 60 or
                claims.get("iat", now) > now + 60):
            raise ValueError("Sessão Access inválida.")
        email = str(claims.get("email", "")).strip().lower()
        if not email or "@" not in email:
            raise ValueError("E-mail não confirmado.")
        global _jwks, _expires_at
        if now >= _expires_at:
            async with ClientSession(timeout=ClientTimeout(total=8)) as session:
                async with session.get(TEAM_DOMAIN + "/cdn-cgi/access/certs") as response:
                    response.raise_for_status()
                    data = await response.json()
            _jwks = {k["kid"]: k for k in data.get("keys", []) if k.get("kty") == "RSA"}
            _expires_at = now + 900
        jwk = _jwks.get(header["kid"])
        if jwk is None:
            _expires_at = 0
            raise ValueError("Chave Access desconhecida.")
        modulus = int.from_bytes(_decode(jwk["n"]), "big")
        exponent = int.from_bytes(_decode(jwk["e"]), "big")
        pubkey = rsa.RSAPublicNumbers(exponent, modulus).public_key()
        pubkey.verify(
            _decode(parts[2]),
            (parts[0] + "." + parts[1]).encode("ascii"),
            padding.PKCS1v15(),
            hashes.SHA256(),
        )
        return email
    except web.HTTPException:
        raise
    except Exception:
        raise web.HTTPForbidden(text="Não foi possível validar seu código. Entre novamente pelo Cloudflare Access.")

