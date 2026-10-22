"""Tests against actual wlcomm.exe from the official WLM 2009 archive.
Windows runner supplies STORM_WLCOMM_FIXTURE after verifying archive SHA256.
"""
import os
import shutil
import tempfile
import unittest
from pathlib import Path

import lief

from storm_msn_setup import check_pe, import_loaded, apply_patch_one, SWITCHER_INI

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
if __name__=="__main__":
    unittest.main()
