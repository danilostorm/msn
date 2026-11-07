"""Isolated switchboard relay tests for WLM 2009 games, voice and binary P2P.

Exercise the REAL _m_msg() and ChatEventHandler.on_message() method bodies,
extracted by AST from source, with a fake 2-client chat. No accounts or network,
no database, no production updates and no proprietary client files.
"""
from __future__ import annotations
import ast
from pathlib import Path
from types import SimpleNamespace
import unittest

from test_msnp_native_invites import (
    MessageType,
    SpecialMessageNotSentWithDType,
    functions_under_test,
)

SOURCE = Path(__file__).resolve().parents[3] / "front" / "msn" / "msnp_sb.py"


def load_real_handlers():
    original = ast.parse(SOURCE.read_text(encoding="utf-8"), str(SOURCE))
    methods = {}
    for node in original.body:
        if not isinstance(node, ast.ClassDef):
            continue
        if node.name == "MSNPCtrlSB":
            method = "_m_msg"
        elif node.name == "ChatEventHandler":
            method = "on_message"
        else:
            continue
        fn = next(
            item for item in node.body
            if isinstance(item, ast.FunctionDef) and item.name == method
        )
        methods[method] = fn
    if set(methods) != {"_m_msg", "on_message"}:
        raise AssertionError("native switchboard methods not found")
    parse, serialize = functions_under_test()
    ns = {
        "messagedata_from_msnp": parse,
        "messagedata_to_msnp": serialize,
        "MessageType": MessageType,
        "error": SimpleNamespace(
            SpecialMessageNotSentWithDType=SpecialMessageNotSentWithDType
        ),
        "Optional": __import__("typing").Optional,
    }
    exec(compile(ast.Module(body=list(methods.values()), type_ignores=[]),
                 str(SOURCE), "exec"), ns)
    return ns["_m_msg"], ns["on_message"]


class NativeSwitchboardRelayTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        msg, forward = load_real_handlers()
        cls.real_msg = staticmethod(msg)
        cls.real_forward = staticmethod(forward)

    def run_pair(self, data: bytes, ack: str = "D"):
        sender = SimpleNamespace(
            email="wlm-test-sender@example.invalid",
            status=SimpleNamespace(name="Online"),
        )
        ctrl_out = SimpleNamespace(replies=[], closed=False)
        ctrl_out.send_reply = lambda *args: ctrl_out.replies.append(args)
        receiver_handler = SimpleNamespace(ctrl=ctrl_out)
        delivered = []

        def deliver(message):
            delivered.append(message)
            self.real_forward(receiver_handler, message)

        cs = SimpleNamespace(user=sender, send_message_to_everyone=deliver)
        ctrl_in = SimpleNamespace(
            bs=SimpleNamespace(front_data={"msn_pop_id": None}),
            cs=cs,
            replies=[],
            closed=False,
        )
        ctrl_in.send_reply = lambda *args: ctrl_in.replies.append(args)
        ctrl_in.close = lambda: setattr(ctrl_in, "closed", True)
        self.real_msg(ctrl_in, "31", ack, data)
        return ctrl_in, ctrl_out, delivered

    def test_games_invitation_reaches_second_original_client_unchanged(self):
        raw = (
            b"MIME-Version: 1.0\r\nContent-Type: text/x-msmsgsinvite\r\n\r\n"
            b"Invitation-Command: INVITE\r\nApplication-Name: Games\r\n"
            b"Invitation-Cookie: 123456\r\n"
        )
        left, right, delivered = self.run_pair(raw)
        self.assertFalse(left.closed)
        self.assertEqual(left.replies, [("ACK", "31")])
        self.assertEqual(len(delivered), 1)
        self.assertEqual(right.replies, [
            ("MSG", "wlm-test-sender@example.invalid", "Online", raw)
        ])

    def test_voice_invitation_reaches_second_original_client_unchanged(self):
        raw = (
            b"MIME-Version: 1.0\r\nContent-Type: text/x-msmsgsinvite\r\n\r\n"
            b"Invitation-Command: INVITE\r\nApplication-Name: Voice Conversation\r\n"
        )
        left, right, delivered = self.run_pair(raw)
        self.assertFalse(left.closed)
        self.assertEqual(right.replies[0][3], raw)

    def test_binary_p2p_reaches_second_client_without_utf8_corruption(self):
        raw = (
            b"MIME-Version: 1.0\r\nContent-Type: application/x-msnmsgrp2p\r\n"
            b"P2P-Dest: synthetic@example.invalid\r\n\r\n"
            b"\xff\xfe\x00\x80" * 5
        )
        left, right, delivered = self.run_pair(raw, ack="D")
        self.assertFalse(left.closed)
        self.assertEqual(right.replies[0][3], raw)

    def test_malformed_invitation_does_not_disconnect_both_clients(self):
        raw = b"MIME-Version: 1.0\r\nContent-Type: text/x-msmsgsinvite\r\nBROKEN"
        left, right, delivered = self.run_pair(raw)
        self.assertFalse(left.closed)
        self.assertEqual(right.replies[0][3], raw)

    def test_invalid_p2p_ack_closes_initiating_session(self):
        raw = (
            b"MIME-Version: 1.0\r\nContent-Type: application/x-msnmsgrp2p\r\n\r\n"
            b"\x00\x80"
        )
        left, right, delivered = self.run_pair(raw, "A")
        self.assertTrue(left.closed)
        self.assertEqual(delivered, [])
        self.assertEqual(right.replies, [])

    def test_oversize_message_is_rejected_without_forwarding(self):
        left, right, delivered = self.run_pair(b"X" * 1665)
        self.assertTrue(left.closed)
        self.assertEqual(delivered, [])
        self.assertEqual(right.replies, [])

    def test_typing_and_nudges_survive_switchboard(self):
        for body in (
            b"MIME-Version: 1.0\r\nContent-Type: text/x-msmsgscontrol\r\n\r\n",
            b"MIME-Version: 1.0\r\nContent-Type: text/x-msnmsgr-datacast\r\n\r\nID: 1\r\n"
        ):
            with self.subTest(body=body[:20]):
                left, right, delivered = self.run_pair(body)
                self.assertFalse(left.closed)
                self.assertEqual(right.replies[0][3], body)


if __name__ == "__main__":
    unittest.main()
