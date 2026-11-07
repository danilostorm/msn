"""Unit tests for the passwordless WLM 2009 contract probe (no network)."""
import importlib.util
from pathlib import Path
import unittest
from unittest.mock import patch


SCRIPT = Path(__file__).resolve().parents[1] / "probe_wlm2009_contract.py"
spec = importlib.util.spec_from_file_location("wlm_contract", SCRIPT)
probe = importlib.util.module_from_spec(spec)
spec.loader.exec_module(probe)


class FakeSocket:
    def __init__(self, blocks):
        self.blocks = list(blocks)
        self.sent = []
        self.timeout = None

    def __enter__(self):
        return self

    def __exit__(self, *args):
        pass

    def settimeout(self, timeout):
        self.timeout = timeout

    def sendall(self, value):
        self.sent.append(value)

    def recv(self, maximum):
        if not self.blocks:
            return b""
        item = self.blocks.pop(0)
        if len(item) > maximum:
            self.blocks.insert(0, item[maximum:])
        return item[:maximum]


class ContractTests(unittest.TestCase):
    def test_fragmented_protocol_replies(self):
        fake = FakeSocket([
            b"VER 100 MSNP", b"18\r\n",
            b"CVR 101 14.0.", b"8117.0416 foo bar\r\n",
            b"GCF 0 10\r\nabcdefghij", b"USR 102 SSO ",
            b"S MBI_KEY_OLD confidential-challenge",
        ])
        with patch.object(probe.socket, "create_connection", return_value=fake):
            result = probe.probe_msnp("example.invalid", 1863, 3)
        self.assertTrue(result["MSNP18"])
        self.assertTrue(result["CVR_2009"])
        self.assertTrue(result["SSO_challenge_offered"])
        self.assertFalse(result["authenticated"])
        self.assertNotIn("confidential", repr(result))
        self.assertEqual(len(fake.sent), 3)
        self.assertTrue(fake.sent[-1].startswith(b"USR 102 SSO I "))

    def test_wrong_protocol_rejected(self):
        fake = FakeSocket([b"VER 100 MSNP15\r\n"])
        with patch.object(probe.socket, "create_connection", return_value=fake):
            with self.assertRaisesRegex(ValueError, "MSNP18"):
                probe.probe_msnp("example.invalid", 1863, 3)

    def test_https_route_availability_and_error_xml(self):
        responses = [
            (200, b"ok"), (200, b"config"),
            (200, b"<Envelope><Fault/></Envelope>"),
            (200, b"<Envelope><Fault/></Envelope>"),
            (405, b""), (405, b""), (405, b""),
        ]
        with patch.object(probe, "http_request", side_effect=responses) as fake:
            result = probe.probe_https("example.invalid", 3)
        self.assertEqual(fake.call_count, 7)
        self.assertTrue(result["RST2_rejects_empty_envelope"])
        self.assertTrue(result["address_book_route_present"])

    def test_missing_contact_endpoint_is_failure(self):
        responses = [
            (200, b"ok"), (200, b"config"),
            (200, b"<Envelope><Fault/></Envelope>"),
            (200, b"<Envelope><Fault/></Envelope>"),
            (404, b"not found"),
        ]
        with patch.object(probe, "http_request", side_effect=responses):
            with self.assertRaisesRegex(ValueError, "address_book_route"):
                probe.probe_https("example.invalid", 3)

    def test_invalid_rst_response_is_failure(self):
        responses = [
            (200, b"ok"), (200, b"config"),
            (200, b"not xml"),
        ]
        with patch.object(probe, "http_request", side_effect=responses):
            with self.assertRaisesRegex(ValueError, "parseable XML"):
                probe.probe_https("example.invalid", 3)

    def test_live_switch_required(self):
        with self.assertRaises(SystemExit):
            probe.main([])


if __name__ == "__main__":
    unittest.main()
