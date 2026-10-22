"""Tests against actual wlcomm.exe from the official WLM 2009 archive.
Windows runner supplies STORM_WLCOMM_FIXTURE after verifying archive SHA256.
"""
import os
import shutil
import tempfile
import hashlib
import unittest
from pathlib import Path

import lief

from storm_msn_setup import (
    check_pe, import_loaded, apply_patch_one, SWITCHER_INI,
    unpack_official_win11_patch, WIN11_CONTACTS_SHA256,
    WIN11_CONTACTS_FILES
)

class WindowsLive2009Tests(unittest.TestCase):
    def test_wlcomm_original_32768_bytes_is_valid_and_patchable(self):
        path=os.environ.get("STORM_WLCOMM_FIXTURE")
        if not path:
            self.skipTest("Original WLM 2009 test fixture only on Windows CI")
        self.assertEqual(Path(path).stat().st_size,32768)
        with tempfile.TemporaryDirectory() as d:
            exe=Path(d)/"wlcomm.exe"
            shutil.copy2(path,exe)
            original=lief.PE.parse(str(exe))
            check_pe(original,exe)
            # The verified vendor Switcher DLL is imported at runtime;
            # a signature-correct fixture is sufficient for import table tests.
            fake_dll=b"MZ"+b"\0"*120000
            result=[]
            apply_patch_one(exe,fake_dll,result.append)
            final=lief.PE.parse(str(exe))
            self.assertIsNotNone(final)
            self.assertTrue(import_loaded(final),"Missing Escargot Switcher ImportMe")
            self.assertIn(b"im.hoststorm.com.br", (Path(d)/"wlcomm.exe-escargot.ini").read_bytes())
            self.assertEqual((Path(d)/"escargot.dll").read_bytes(),fake_dll)
            before=exe.read_bytes()
            apply_patch_one(exe,fake_dll,result.append)
            self.assertEqual(before,exe.read_bytes(),"Second run modified an already patched EXE")
            self.assertTrue(any("ImportMe" in x for x in result))
class Windows11CompatibilityTests(unittest.TestCase):
    def test_original_vendor_patch_archive_extracts_all_four_files(self):
        fixture = os.environ.get("STORM_WIN11_FIX_FIXTURE")
        if not fixture:
            self.skipTest("Official Win11 compatibility ZIP is only present in CI")
        payload = Path(fixture).read_bytes()
        self.assertEqual(hashlib.sha256(payload).hexdigest(), WIN11_CONTACTS_SHA256)
        with tempfile.TemporaryDirectory() as directory:
            folder = Path(directory)
            executable = unpack_official_win11_patch(payload, folder)
            self.assertEqual(executable.name, "EscargotWin11Patcher.exe")
            for filename, size in WIN11_CONTACTS_FILES.items():
                self.assertEqual((folder / filename).stat().st_size, size)

    def test_corrupted_vendor_patch_zip_is_rejected(self):
        import io
        import zipfile
        with tempfile.TemporaryDirectory() as directory:
            bad = io.BytesIO()
            with zipfile.ZipFile(bad, "w") as arc:
                arc.writestr("unexpected.exe", b"MZ")
            with self.assertRaisesRegex(RuntimeError, "Conteúdo inesperado"):
                unpack_official_win11_patch(bad.getvalue(), Path(directory))

if __name__=="__main__":
    unittest.main()
