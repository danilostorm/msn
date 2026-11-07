#!/usr/bin/env python3
"""Read-only WLM 2009 Games/AppDirectory integration probe.

No account login, game launch, or remote changes; explicit --live opt-in.
Uses the system curl (rather than Python's urllib user agent) to accommodate
existing Cloudflare rules at the public Storm MSN domain.
"""
from __future__ import annotations

import argparse
import json
import re
import subprocess
import sys
import xml.etree.ElementTree as ET


BASE = "https://msn.hoststorm.com.br"
PLAYSTOR = "https://playstor.hoststorm.cloud/"
SOAP_NS = "http://schemas.xmlsoap.org/soap/envelope/"


def fetch(url: str, timeout: int = 12, payload: bytes | None = None) -> bytes:
    if not url.startswith(BASE + "/"):
        raise ValueError("probe only permits the Storm MSN public host")
    args = [
        "curl", "-fsS", "--max-time", str(timeout),
        "--connect-timeout", "5", "--proto", "=https",
    ]
    if payload is not None:
        args.extend([
            "-X", "POST", "-H", "Content-Type: text/xml",
            "-H", "SOAPAction: GetAppEntry",
            "--data-binary", "@-",
        ])
    args.append(url)
    result = subprocess.run(args, input=payload, capture_output=True, timeout=timeout + 4)
    if result.returncode:
        raise RuntimeError("curl failed (exit=" + str(result.returncode) + ")")
    if len(result.stdout) > 1024 * 1024:
        raise ValueError("AppDirectory response exceeded 1 MiB")
    return result.stdout


def local(tag: str) -> str:
    return tag.rsplit("}", 1)[-1]


def child_text(node: ET.Element, name: str) -> str:
    for c in node:
        if local(c.tag) == name:
            return (c.text or "").strip()
    return ""


def get_catalog_entry(doc: bytes) -> tuple[str, str, int]:
    root = ET.fromstring(doc)
    if local(root.tag) != "AppDir":
        raise ValueError("AppDirectory must return an AppDir root")
    entries = [node for node in root if local(node.tag) == "Entry"]
    for node in entries:
        appid = child_text(node, "AppID") or child_text(node, "ID")
        url = child_text(node, "URL")
        if re.fullmatch(r"[0-9]{1,12}", appid or "") and url.startswith(PLAYSTOR):
            return appid, url, len(entries)
    raise ValueError("catalog lacks a numeric PlayStor game entry")


def make_get_app_entry_request(appid: str) -> bytes:
    if not re.fullmatch(r"[0-9]{1,12}", appid):
        raise ValueError("numeric application ID is required")
    return (
        '<?xml version="1.0" encoding="utf-8"?>'
        '<soap:Envelope xmlns:soap="' + SOAP_NS + '">'
        '<soap:Body><GetAppEntry xmlns="http://www.msn.com/webservices/AppDirectory">'
        '<appId>' + appid + '</appId>'
        '</GetAppEntry></soap:Body></soap:Envelope>'
    ).encode("utf-8")


def get_soap_app_entry(doc: bytes) -> tuple[str, str]:
    root = ET.fromstring(doc)
    if local(root.tag) != "Envelope":
        raise ValueError("GetAppEntry response is not a SOAP envelope")
    result = [node for node in root.iter() if local(node.tag) == "GetAppEntryResponse"]
    if len(result) != 1:
        raise ValueError("GetAppEntryResponse is missing")
    entries = [node for node in result[0].iter() if local(node.tag) == "Entry"]
    if len(entries) != 1:
        raise ValueError("SOAP GetAppEntry must return exactly one game")
    return child_text(entries[0], "AppID"), child_text(entries[0], "URL")


def get_config_games_url(doc: bytes) -> str:
    root = ET.fromstring(doc)
    values = [(node.text or "").strip() for node in root.iter() if local(node.tag) == "GamesBrowserURL"]
    if len(values) != 1:
        raise ValueError("WLM 2009 configuration missing GamesBrowserURL")
    if values[0] != BASE + "/AppDirectory/Directory.aspx?from=wlm2009":
        raise ValueError("Unexpected GamesBrowserURL (client would not load the expected catalog)")
    return values[0]


def run() -> dict:
    config = fetch(BASE + "/etc/MsgrConfig?ver=14.0.8117.0416")
    games_url = get_config_games_url(config)
    directory = fetch(games_url)
    if b"PlayStor" not in directory:
        raise ValueError("GamesBrowserURL page does not contain PlayStor")
    catalog = fetch(BASE + "/AppDirectory/AppDirectory.asmx")
    appid, url, entries = get_catalog_entry(catalog)
    soap_reply = fetch(
        BASE + "/AppDirectory/AppDirectory.asmx",
        payload=make_get_app_entry_request(appid),
    )
    soap_id, soap_url = get_soap_app_entry(soap_reply)
    if (soap_id, soap_url) != (appid, url):
        raise ValueError("SOAP GetAppEntry does not match the published game")
    return {
        "ok": True,
        "native_client": "WLM 2009 / 14.0.8117.0416",
        "configuration_games_browser": games_url,
        "games_catalog_present": True,
        "catalog_entry_count": entries,
        "sample_app_id": appid,
        "sample_soap_matches_catalog": True,
        "account_authenticated": False,
        "game_launched": False,
        "peer_session_verified": False,
        "client_ui_modified": False,
    }


def main(argv=None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--live", action="store_true",
                        help="allow read-only public requests to Storm MSN")
    args = parser.parse_args(argv)
    if not args.live:
        parser.error("Use --live to enable public read-only Games/AppDirectory probes")
    try:
        result = run()
        print(json.dumps(result, ensure_ascii=False, indent=2))
        return 0
    except (ValueError, ET.ParseError, RuntimeError, OSError,
            subprocess.TimeoutExpired) as exc:
        print(json.dumps({"ok": False, "error": type(exc).__name__,
                          "detail": str(exc)}, ensure_ascii=False))
        return 1


if __name__ == "__main__":
    sys.exit(main())
