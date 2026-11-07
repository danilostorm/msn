"""Regression tests: preserve binary WLM 2009 P2P/game/voice invites.

Dependency-free isolated AST extraction from the real source. Never opens any
account, socket, database, WLM installation, or production process.
"""
from __future__ import annotations

import ast
from email.parser import Parser
from enum import Enum
from pathlib import Path
from types import SimpleNamespace
import re
import unittest


SOURCE = Path(__file__).resolve().parents[3] / "front" / "msn" / "msnp_sb.py"


class MessageType(Enum):
    Chat = "Chat"
    Typing = "Typing"
    TypingDone = "TypingDone"
    Nudge = "Nudge"


class MessageData:
    def __init__(self, sender=None, sender_pop_id=None, type=None, text=None):
        self.sender = sender
        self.sender_pop_id = sender_pop_id
        self.type = type
        self.text = text
        self.front_cache = {}


class SpecialMessageNotSentWithDType(Exception):
    pass


def functions_under_test():
    original = ast.parse(SOURCE.read_text(encoding="utf-8"), str(SOURCE))
    wanted = {"messagedata_from_msnp", "messagedata_to_msnp"}
    nodes = [
        node for node in original.body
        if isinstance(node, ast.FunctionDef) and node.name in wanted
    ]
    if len(nodes) != 2:
        raise AssertionError("Required parser functions missing")
    ns = {
        "Parser": Parser,
        "MessageType": MessageType,
        "MessageData": MessageData,
        "User": object,
        "Optional": __import__("typing").Optional,
        "re": re,
        "error": SimpleNamespace(
            SpecialMessageNotSentWithDType=SpecialMessageNotSentWithDType
        ),
    }
    exec(compile(ast.Module(body=nodes, type_ignores=[]), str(SOURCE), "exec"), ns)
    return ns["messagedata_from_msnp"], ns["messagedata_to_msnp"]


class NativePayloadRegressionTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.receive, cls.send = functions_under_test()

    def invoke(self, data: bytes, ack: str = "D"):
        sender = SimpleNamespace(email="synthetic@example.invalid")
        return self.receive(sender, None, ack, data)

    def test_binary_p2p_is_forwarded_byte_identical(self):
        raw = (
            b"MIME-Version: 1.0\r\nContent-Type: application/x-msnmsgrp2p\r\n"
            b"P2P-Dest: synthetic@example.invalid\r\n\r\n"
            b"\x00\xff\xfe\x01\x11\x22\x80\x81"
        )
        message = self.invoke(raw)
        self.assertEqual(message.type, MessageType.Chat)
        self.assertEqual(self.send(message), raw)

    def test_original_legacy_voice_invite_passes_through(self):
        raw = (
            b"MIME-Version: 1.0\r\nContent-Type: text/x-msmsgsinvite; charset=UTF-8\r\n\r\n"
            b"Invitation-Command: INVITE\r\nApplication-Name: Voice Conversation\r\n"
        )
        self.assertEqual(self.send(self.invoke(raw)), raw)

    def test_game_invite_passes_through(self):
        raw = (
            b"MIME-Version: 1.0\r\nContent-Type: text/x-msmsgsinvite\r\n\r\n"
            b"Invitation-Command: INVITE\r\nApplication-Name: Games\r\n"
        )
        self.assertEqual(self.send(self.invoke(raw)), raw)

    def test_malformed_headers_no_longer_trigger_unbound_local_error(self):
        raw = b"this is not MIME, nor a header separator"
        msg = self.invoke(raw)
        self.assertEqual(msg.text, "(Unsupported MSNP Content-Type)")
        self.assertEqual(self.send(msg), raw)

    def test_non_utf8_header_no_longer_triggers_unbound_local_error(self):
        raw = b"MIME-Version: 1.0\r\nX-Invalid: \xff\r\n\r\nbinary"
        msg = self.invoke(raw)
        self.assertEqual(msg.text, "(Unsupported MSNP Content-Type)")
        self.assertEqual(self.send(msg), raw)

    def test_malformed_datacast_no_longer_raises(self):
        raw = b"MIME-Version: 1.0\r\nContent-Type: text/x-msnmsgr-datacast\r\n\r\nNO_ID\r\n"
        msg = self.invoke(raw)
        self.assertEqual(msg.text, "(Unsupported MSNP Content-Type)")
        self.assertEqual(self.send(msg), raw)

    def test_datacast_nudge(self):
        raw = b"MIME-Version: 1.0\r\nContent-Type: text/x-msnmsgr-datacast\r\n\r\nID: 1\r\n"
        msg = self.invoke(raw)
        self.assertIs(msg.type, MessageType.Nudge)
        self.assertEqual(self.send(msg), raw)

    def test_p2p_requires_legacy_d_ack(self):
        raw = b"MIME-Version: 1.0\r\nContent-Type: application/x-msnmsgrp2p\r\n\r\n\x00"
        with self.assertRaises(SpecialMessageNotSentWithDType):
            self.invoke(raw, "A")

    def test_text_message_still_reads_as_text(self):
        raw = (
            b"MIME-Version: 1.0\r\nContent-Type: text/plain; charset=UTF-8\r\n\r\n"
            + "Olá".encode("utf-8")
        )
        msg = self.invoke(raw)
        self.assertEqual(msg.text, "Olá")
        self.assertEqual(self.send(msg), raw)


if __name__ == "__main__":
    unittest.main()
