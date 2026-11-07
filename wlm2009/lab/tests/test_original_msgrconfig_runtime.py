"""Execute the REAL backend WLM 2009 config renderer, isolated and offline.

This catches issues that checking raw XML alone misses: version selection,
template interpolation, nested GamesBrowserURL position and legacy sibling.
No production service, account, network, database or installation is touched.
"""
from __future__ import annotations

import ast
from pathlib import Path
import re
from types import SimpleNamespace
from typing import Optional
import unittest
import xml.etree.ElementTree as ET

SOURCE = Path(__file__).resolve().parents[3] / "front/msn/http/other.py"
TEMPLATE = Path(__file__).resolve().parents[3] / "front/msn/tmpl"
EXPECTED = "https://msn.hoststorm.com.br/AppDirectory/Directory.aspx?from=wlm2009"


def load_actual_backend_renderer():
    parsed = ast.parse(SOURCE.read_text(encoding="utf-8"), str(SOURCE))
    methods = [node for node in parsed.body
               if isinstance(node, ast.FunctionDef)
               and node.name == "_get_msgr_config"]
    if len(methods) != 1:
        raise AssertionError("_get_msgr_config not found")
    # Only the original backend function is compiled. The web server, routes,
    # credentials, databases and external modules are never initialized.
    ns = {
        "TMPL_DIR": str(TEMPLATE),
        "web": SimpleNamespace(Request=object),
        "Optional": Optional,
        "re": re,
    }
    exec(compile(ast.Module(body=methods, type_ignores=[]),
                 str(SOURCE), "exec"), ns)
    return ns["_get_msgr_config"]


class OriginalWlm2009ConfigRuntimeTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.render = staticmethod(load_actual_backend_renderer())

    def get_xml(self, ver: str):
        req = SimpleNamespace(query={"ver": ver})
        return ET.fromstring(self.render(req, None).encode("utf-8"))

    def test_actual_wlm_2009_version_route_has_native_games_path(self):
        root = self.get_xml("14.0.8117.0416")
        self.assertEqual(
            root.findtext("LocalizedConfig/AppDirConfig/GamesBrowserURL"),
            EXPECTED,
        )
        self.assertEqual(root.findtext("LocalizedConfig/GamesBrowserURL"), EXPECTED)

    def test_newer_client_uses_same_compatibility_config(self):
        root = self.get_xml("15.4.3508.1109")
        self.assertEqual(
            root.findtext("LocalizedConfig/AppDirConfig/GamesBrowserURL"),
            EXPECTED,
        )

    def test_xml_is_well_formed_with_real_tabs_rendered(self):
        root = self.get_xml("14.0.8117.0416")
        self.assertEqual(root.tag, "MsgrConfig")
        self.assertIsNotNone(root.find("TabConfig/msntabdata"))

    def test_game_and_directory_paths_agree(self):
        root = self.get_xml("14.0.8117.0416")
        ns = root.find("LocalizedConfig/AppDirConfig")
        self.assertIsNotNone(ns)
        self.assertEqual(ns.findtext("GamesBrowserURL"), EXPECTED)
        self.assertEqual(
            ns.findtext("AppDirSeviceURL"),
            "https://msn.hoststorm.com.br/AppDirectory/AppDirectory.asmx",
        )
        self.assertEqual(
            ns.findtext("AppDirVersionURL"),
            "https://msn.hoststorm.com.br/AppDirectory/GetAppdirVersion.aspx",
        )

    def test_games_tag_only_once_per_supported_path(self):
        root = self.get_xml("14.0.8117.0416")
        self.assertEqual(len(root.findall(
            "LocalizedConfig/AppDirConfig/GamesBrowserURL")), 1)
        self.assertEqual(len(root.findall(
            "LocalizedConfig/GamesBrowserURL")), 1)

    def test_old_wlm8_still_generates_xml(self):
        root = self.get_xml("8.5.1302.1018")
        self.assertEqual(root.tag, "MsgrConfig")

    def test_reject_non_numeric_version(self):
        req = SimpleNamespace(query={"ver": "bad.version"})
        self.assertEqual(self.render(req, None), "INVALID_VER")


if __name__ == "__main__":
    unittest.main()
