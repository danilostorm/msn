"""Isolated, dependency-free regression tests for WLM 2009 SOAP member deletion.

Compiles only the function AST with fake services. No database, account, socket,
Windows client, Microsoft binary, or production configuration is loaded.
"""
from __future__ import annotations

import ast
from datetime import datetime
from pathlib import Path
from types import SimpleNamespace
import unittest
import xml.etree.ElementTree as ET


REPO_ROOT = Path(__file__).resolve().parents[3]
SOURCE = REPO_ROOT / "front" / "msn" / "http" / "abservice.py"
XSI_TYPE = "{http://www.w3.org/2001/XMLSchema-instance}type"
CIRCLE_ID = "00000000-0000-0000-0009-ABCDEF123456"


class Lists:
    BL = "BL"
    RL = "RL"
    PL = "PL"

    @staticmethod
    def Parse(value):
        if value in {"BL", "RL", "PL"}:
            return value
        return None


class FakeSession:
    def __init__(self, contacts=None):
        self.user = SimpleNamespace(detail=SimpleNamespace(contacts=contacts or {}))
        self.removed = []
        self.unblocked = []

    def me_contact_remove(self, uuid, lst):
        self.removed.append((uuid, lst))

    def me_unblock_circle(self, circle):
        self.unblocked.append(circle)


def find_element(parent, name):
    node = parent.find(".//{*}" + name)
    return None if node is None else node.text


def build_action(*members, role="BL"):
    root = ET.Element("Envelope")
    memberships = ET.SubElement(root, "memberships")
    membership = ET.SubElement(memberships, "Membership")
    ET.SubElement(membership, "MemberRole").text = role
    elements = ET.SubElement(membership, "Members")
    for type_name, values in members:
        item = ET.SubElement(elements, "Member", {XSI_TYPE: type_name})
        for name, value in values.items():
            ET.SubElement(item, name).text = value
    return root


def circle_member(circle_id=CIRCLE_ID):
    return ("CircleMember", {"Type": "Circle", "State": "Accepted", "CircleId": circle_id})


def passport_member(uuid="contact-001"):
    return ("PassportMember", {
        "Type": "Passport", "State": "Accepted",
        "MembershipId": "contact/" + uuid,
    })


def load_real_function():
    tree = ast.parse(SOURCE.read_text(encoding="utf-8"), filename=str(SOURCE))
    func = next(node for node in tree.body
                if isinstance(node, (ast.FunctionDef, ast.AsyncFunctionDef))
                and node.name == "sharing_DeleteMember")
    module = ast.Module(body=[func], type_ignores=[])
    ns = {
        "Any": object,
        "Backend": object,
        "BackendSession": object,
        "web": SimpleNamespace(
            Request=object,
            Response=object,
            HTTPInternalServerError=lambda: ("HTTP", 500),
        ),
        "models": SimpleNamespace(Lst=Lists),
        "secrets": SimpleNamespace(token_urlsafe=lambda n: "safe-dummy-cache"),
        "datetime": datetime,
        "find_element": find_element,
        "util": SimpleNamespace(misc=SimpleNamespace(gen_uuid=lambda: "dummy-uuid")),
        "settings": SimpleNamespace(LOGIN_HOST="localhost"),
        "render": lambda req, template, payload=None, status=200:
            ("RENDER", template, status),
    }
    exec(compile(module, str(SOURCE), "exec"), ns)
    return ns["sharing_DeleteMember"]


class SharingDeleteMemberTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.handle = staticmethod(load_real_function())

    def _invoke(self, action, session, groupchat=None):
        groupchat = groupchat or object()
        backend = SimpleNamespace(
            user_service=SimpleNamespace(get_groupchat=lambda chat_id:
                groupchat if chat_id == "ABCDEF123456" else None),
            util_get_uuid_from_email=lambda email: None,
        )
        req = SimpleNamespace(app={"backend": backend})
        result = self.handle(req, None, action, session)
        return result, groupchat

    def test_valid_circle_is_unblocked(self):
        session = FakeSession()
        result, groupchat = self._invoke(build_action(circle_member()), session)
        self.assertEqual(session.unblocked, [groupchat])
        self.assertEqual(session.removed, [])
        self.assertEqual(result[0], "RENDER")
        self.assertIn("DeleteMemberResponse", result[1])

    def test_passport_then_circle_do_not_reuse_contact_uuid(self):
        session = FakeSession(contacts={"contact-001": object()})
        result, circle = self._invoke(
            build_action(passport_member(), circle_member()), session)
        self.assertEqual(session.removed, [("contact-001", "BL")])
        self.assertEqual(session.unblocked, [circle])
        self.assertEqual(result[0], "RENDER")

    def test_reverse_list_cannot_unblock_circle(self):
        session = FakeSession()
        result, _ = self._invoke(build_action(circle_member(), role="RL"), session)
        self.assertEqual(result, ("HTTP", 500))
        self.assertEqual(session.unblocked, [])

    def test_invalid_circle_id_is_rejected(self):
        session = FakeSession()
        result, _ = self._invoke(build_action(circle_member("invalid")), session)
        self.assertEqual(result, ("HTTP", 500))
        self.assertEqual(session.unblocked, [])

    def test_unaccepted_circle_member_is_ignored(self):
        session = FakeSession()
        result, _ = self._invoke(build_action(("CircleMember", {
            "Type": "Circle", "State": "Pending",
            "CircleId": CIRCLE_ID,
        })), session)
        self.assertEqual(result[0], "RENDER")
        self.assertEqual(session.unblocked, [])


if __name__ == "__main__":
    unittest.main()
