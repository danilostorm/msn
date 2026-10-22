"""Opt-in Messenger Plus! 5.02 for Storm MSN, no archive password required.

Source binary is the Escargot-adjusted Messenger Plus! 5.02.712 executable,
repacked as a plain ZIP without encryption. Do NOT silently accept any
third-party sponsored offers. The standalone original client remains WLM 2009.
"""
import hashlib
from pathlib import Path
import subprocess
import tempfile
from zipfile import ZipFile
import io

PLUS_URL = "https://msn.hoststorm.com.br/downloads/StormMSN-MsgPlus-5.02.712.zip"
PLUS_ARCHIVE_SHA256 = "e5d897a04a8c51156b6226608d31fbf726d7434135a46ade768ad2955f0e7038"
PLUS_EXE_SHA256 = "6bb92709e160a8410cd2fb465c40ddf6fd7b9d8891473fcc69760a2caa5b4918"
PLUS_EXE_SIZE = 7_614_344
PLUS_EXE_NAME = "MsgPlus-5.02.712.exe"


def extract_msgplus(archive: bytes, output: Path) -> Path:
    """Only extract one expected executable, with pinned hashes and size."""
    if hashlib.sha256(archive).hexdigest() != PLUS_ARCHIVE_SHA256:
        raise ValueError("A versão Messenger Plus! não corresponde ao SHA-256 esperado.")
    with ZipFile(io.BytesIO(archive)) as zipfile:
        files = zipfile.infolist()
        if len(files) != 1 or files[0].filename != PLUS_EXE_NAME:
            raise ValueError("O ZIP do Messenger Plus! possui arquivos inesperados.")
        info = files[0]
        if info.flag_bits & 1:
            raise ValueError("O novo pacote Messenger Plus! nao deveria ter senha.")
        if info.file_size != PLUS_EXE_SIZE:
            raise ValueError("O Messenger Plus! tem tamanho incorreto.")
        executable = zipfile.read(info)
    if executable[:2] != b"MZ":
        raise ValueError("O Messenger Plus! nao e um executavel PE.")
    if hashlib.sha256(executable).hexdigest() != PLUS_EXE_SHA256:
        raise ValueError("A assinatura SHA-256 do executável Messenger Plus! nao confere.")
    target = output / PLUS_EXE_NAME
    target.write_bytes(executable)
    return target


def install_msgplus(log, read_verified, ini_paths):
    """Run the vendor GUI only after separate checkbox + confirmation."""
    log("Messenger Plus! 5.02: instalação opcional confirmada.")
    payload = read_verified(PLUS_URL, PLUS_ARCHIVE_SHA256, 10_000_000, log)
    with tempfile.TemporaryDirectory(prefix="StormMSN-MsgPlus-") as d:
        directory = Path(d)
        exe = extract_msgplus(payload, directory)
        log("Pacote sem senha verificado. Instalador original confirmado por SHA-256.")
        log("Leia todas as telas e RECUSE ofertas patrocinadas do Messenger Plus!.")
        ret = subprocess.run([str(exe)], cwd=str(directory)).returncode
        if ret not in (0, 3010):
            raise RuntimeError(f"O instalador Messenger Plus! terminou com código {ret}.")
    # Vendor patches may point sound services at Escargot, but our MSN and
    # contacts host settings should always remain pointed at Storm MSN.
    for path, ini in ini_paths:
        f = Path(path)
        (f.parent / (f.name + "-escargot.ini")).write_bytes(ini)
    log("Instalação do Messenger Plus! finalizada; INIs Storm MSN restaurados.")
    log("Sons online do Plus! podem depender do servidor Escargot.")
    return True
