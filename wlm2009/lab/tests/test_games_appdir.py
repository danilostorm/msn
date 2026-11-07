"""Offline tests for the native Messenger 2009 Games/AppDirectory contract."""
import importlib.util
from pathlib import Path
import unittest
import xml.etree.ElementTree as ET


FILE = Path(__file__).resolve().parents[1] / "probe_games_appdir.py"
spec = importlib.util.spec_from_file_location("games_probe", FILE)
games = importlib.util.module_from_spec(spec)
spec.loader.exec_module(games)

CATALOG = b'''<AppDir>
  <Category><CategoryID>SNES</CategoryID><CategoryName>Super Nintendo</CategoryName></Category>
  <Entry><AppID>673</AppID><ID>673</ID><Name>Test</Name>
    <Type>Game</Type><URL>https://playstor.hoststorm.cloud/?game=673</URL></Entry>
</AppDir>'''
SOAP_RESULT = b'''<soap:Envelope xmlns:soap="http://schemas.xmlsoap.org/soap/envelope/">
 <soap:Body><GetAppEntryResponse><GetAppEntryResult><AppDir>
   <Entry><AppID>673</AppID><URL>https://playstor.hoststorm.cloud/?game=673</URL></Entry>
 </AppDir></GetAppEntryResult></GetAppEntryResponse></soap:Body>
</soap:Envelope>'''
CONFIG = b'''<MsgrConfig><LocalizedConfig>
 <GamesBrowserURL>https://msn.hoststorm.com.br/AppDirectory/Directory.aspx?from=wlm2009</GamesBrowserURL>
</LocalizedConfig></MsgrConfig>'''


class GamesContractTests(unittest.TestCase):
    def test_catalog_has_numeric_playstor_app(self):
        self.assertEqual(games.get_catalog_entry(CATALOG), (
            "673", "https://playstor.hoststorm.cloud/?game=673", 1
        ))

    def test_single_entry_soap_matches_catalog(self):
        self.assertEqual(games.get_soap_app_entry(SOAP_RESULT), (
            "673", "https://playstor.hoststorm.cloud/?game=673"
        ))

    def test_exact_original_games_browser_route(self):
        self.assertEqual(
            games.get_config_games_url(CONFIG),
            "https://msn.hoststorm.com.br/AppDirectory/Directory.aspx?from=wlm2009",
        )

    def test_unknown_host_is_not_allowed(self):
        with self.assertRaises(ValueError):
            games.fetch("https://malicious.example/AppDirectory/", 2)

    def test_reject_unsafe_app_id(self):
        for value in ("../../path", "1&foo=x", "<bad>", ""):
            with self.subTest(value=value):
                with self.assertRaises(ValueError):
                    games.make_get_app_entry_request(value)

    def test_generated_soap_has_get_app_entry(self):
        request = games.make_get_app_entry_request("673")
        root = ET.fromstring(request)
        self.assertEqual(games.local(root.tag), "Envelope")
        self.assertEqual(
            [games.local(c.tag) for c in root.iter()].count("GetAppEntry"),
            1
        )

    def test_non_soap_response_is_not_success(self):
        with self.assertRaises(ValueError):
            games.get_soap_app_entry(CATALOG)

    def test_configuration_missing_games_url_is_not_success(self):
        with self.assertRaises(ValueError):
            games.get_config_games_url(b"<MsgrConfig/>")


if __name__ == "__main__":
    unittest.main()
