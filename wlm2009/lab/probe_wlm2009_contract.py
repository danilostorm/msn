#!/usr/bin/env python3
"""Read-only public contract probe for Windows Live Messenger 2009 on Storm MSN.

Never sends passwords, reuses logins, follows authenticated redirects, or stores
SSO challenges. This does NOT prove actual Messenger login/contact sync.
"""
from __future__ import annotations

import argparse
import json
import re
import socket
import ssl
import sys
from urllib import request, error
from xml.etree import ElementTree


VERSION = b"14.0.8117.0416"
PROBE_ADDRESS = b"wlm2009-contract-probe@invalid.example"


def read_until(sock, marker: bytes, max_bytes: int = 65536) -> bytes:
    data = bytearray()
    while marker not in data:
        block = sock.recv(min(4096, max_bytes - len(data)))
        if not block:
            raise ValueError("connection closed before expected protocol response")
        data.extend(block)
        if len(data) >= max_bytes and marker not in data:
            raise ValueError("reply exceeded maximum read length")
    return bytes(data)


def probe_msnp(host: str, port: int, timeout: float) -> dict:
    with socket.create_connection((host, port), timeout=timeout) as sock:
        sock.settimeout(timeout)
        sock.sendall(b"VER 100 MSNP18 MSNP17 MSNP16 MSNP15 CVR0\r\n")
        ver = read_until(sock, b"\r\n")
        if b"VER 100 MSNP18\r\n" not in ver:
            raise ValueError("expected WLM 2009 MSNP18 negotiation")

        sock.sendall(
            b"CVR 101 0x0416 winnt 6.1 i386 MSNMSGR "
            + VERSION
            + b" MSMSGS "
            + PROBE_ADDRESS
            + b"\r\n"
        )
        cvr = read_until(sock, b"CVR 101 ")
        cvr = read_until(sock, b"\r\n") if b"\r\n" not in cvr else cvr
        if b"CVR 101 " not in cvr or VERSION not in cvr:
            raise ValueError("CVR response did not identify WLM 2009")
        sock.sendall(b"USR 102 SSO I " + PROBE_ADDRESS + b"\r\n")
        # The GCF frame can contain binary bytes; only search for the expected
        # public SSO stage in a bounded buffer. NEVER include challenge in output.
        sso = read_until(sock, b"USR 102 SSO S", max_bytes=131072)
        return {
            "MSNP18": True,
            "CVR_2009": True,
            "SSO_challenge_offered": b"USR 102 SSO S" in sso,
            "authenticated": False,
        }


def http_request(host: str, path: str, method: str, timeout: float, body: bytes | None = None) -> tuple[int, bytes]:
    url = "https://" + host + path
    headers = {"User-Agent": "StormMSN-WLM2009-contract-check/1.0"}
    if body is not None:
        headers["Content-Type"] = "text/xml; charset=utf-8"
    req = request.Request(url, data=body, method=method, headers=headers)
    try:
        with request.urlopen(req, timeout=timeout, context=ssl.create_default_context()) as response:
            return response.status, response.read(250000)
    except error.HTTPError as exc:
        return exc.code, exc.read(250000)


def probe_https(host: str, timeout: float) -> dict:
    result: dict[str, object] = {}
    for path, key in (
        ("/api/health", "health"),
        ("/etc/MsgrConfig", "messenger_config"),
    ):
        status, _ = http_request(host, path, "GET", timeout)
        if status != 200:
            raise ValueError(key + " HTTP status " + str(status))
        result[key] = status

    # Only deliberately invalid XML with no username/password/token is used.
    # Successful parsing of the error document is sufficient; no login occurs.
    for path, key in (("/RST.srf", "RST"), ("/RST2.srf", "RST2")):
        status, data = http_request(host, path, "POST", timeout, body=b"<empty/>")
        if status != 200:
            raise ValueError(key + " invalid-envelope HTTP status " + str(status))
        try:
            ElementTree.fromstring(data)
        except ElementTree.ParseError as exc:
            raise ValueError(key + " did not return parseable XML") from exc
        result[key + "_rejects_empty_envelope"] = True

    for path, key in (
        ("/abservice/abservice.asmx", "address_book_route"),
        ("/abservice/SharingService.asmx", "sharing_service_route"),
        ("/storageservice/SchematizedStore.asmx", "storage_service_route"),
    ):
        status, _ = http_request(host, path, "OPTIONS", timeout)
        if status not in (200, 204, 401, 403, 405):
            raise ValueError(key + " not available, HTTP " + str(status))
        result[key + "_present"] = True
    return result


def run(tcp_host: str, https_host: str, timeout: float) -> dict:
    result = {
        "purpose": "public handshake and endpoint availability only",
        "tcp_host": tcp_host,
        "https_host": https_host,
        "protocol": probe_msnp(tcp_host, 1863, timeout),
        "https": probe_https(https_host, timeout),
        "login_completed": False,
        "contacts_verified": False,
        "gui_verified": False,
        "visual_resources_changed": False,
    }
    return result


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--live", action="store_true", help="explicitly enable non-authenticated network checks")
    parser.add_argument("--tcp-host", default="im.hoststorm.com.br")
    parser.add_argument("--https-host", default="msn.hoststorm.com.br")
    parser.add_argument("--timeout", type=float, default=8.0)
    parser.add_argument("--output", help="write JSON report to this path")
    args = parser.parse_args(argv)
    if not args.live:
        parser.error("Use --live to explicitly allow live public protocol probes.")
    if args.timeout <= 0 or args.timeout > 30:
        parser.error("--timeout must be between 0 and 30 seconds")
    try:
        report = run(args.tcp_host, args.https_host, args.timeout)
    except (OSError, ValueError, error.URLError) as exc:
        print(json.dumps({"ok": False, "reason": type(exc).__name__, "details": str(exc)}, ensure_ascii=False))
        return 1
    report["ok"] = True
    output = json.dumps(report, indent=2, ensure_ascii=False)
    if args.output:
        with open(args.output, "w", encoding="utf-8") as file:
            file.write(output + "\n")
    print(output)
    return 0


if __name__ == "__main__":
    sys.exit(main())
