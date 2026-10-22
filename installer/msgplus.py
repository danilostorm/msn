"""Opt-in Messenger Plus! 5.02 for Storm MSN, no archive password required.

Source binary is the Escargot-adjusted Messenger Plus! 5.02.712 executable,
repacked as a plain ZIP without encryption. Do NOT silently accept any
third-party sponsored offers. The standalone original client remains WLM 2009.
"""
import hashlib
import sys
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

# Original Messenger Plus 5.02.712 user-supplied ZIP and EXE.
USER_PLUS_ZIP_NAME = "MsgPlusSetup.zip"
USER_PLUS_ZIP_SHA256 = "5355326b50e7b22de8b3fa3493f1c186b800e2e357d679e2cdf52c2bff0bfb70"
USER_PLUS_EXE_NAME = "MsgPlusSetup.exe"
USER_PLUS_EXE_SIZE = 7_980_544
USER_PLUS_EXE_SHA256 = "c83bdc6d48290b2ff9c54e7cb84a82404d7ee46bf1d385bfaf5804f3b8d6b55a"

def extract_user_msgplus(data: bytes, output: Path) -> Path:
    """Unpack only the exact user copy, avoiding zip-slip."""
    if hashlib.sha256(data).hexdigest() != USER_PLUS_ZIP_SHA256:
        raise ValueError("MsgPlusSetup.zip local não corresponde ao pacote enviado.")
    with ZipFile(io.BytesIO(data)) as archive:
        items=archive.infolist()
        if len(items)!=1 or items[0].filename != USER_PLUS_EXE_NAME:
            raise ValueError("Conteúdo inesperado no MsgPlusSetup.zip local.")
        if items[0].flag_bits & 1 or items[0].file_size != USER_PLUS_EXE_SIZE:
            raise ValueError("Versão inesperada ou arquivo com senha.")
        exe_bytes=archive.read(items[0])
    if exe_bytes[:2] != b"MZ" or hashlib.sha256(exe_bytes).hexdigest() != USER_PLUS_EXE_SHA256:
        raise ValueError("O Messenger Plus! enviado não corresponde ao executável validado.")
    output_file=output/USER_PLUS_EXE_NAME
    output_file.write_bytes(exe_bytes)
    return output_file

def find_user_msgplus():
    """Lookup a verified local copy next to the user-invoked installer."""
    bases=[Path(sys.executable).resolve().parent,Path.cwd()]
    for folder in bases:
        candidate=folder/USER_PLUS_ZIP_NAME
        if candidate.is_file():
            data=candidate.read_bytes()
            if hashlib.sha256(data).hexdigest() != USER_PLUS_ZIP_SHA256:
                raise ValueError("Arquivo MsgPlusSetup.zip encontrado, mas checksum incorreto.")
            return data
    return None



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
    """Install exact user version if present; otherwise use tested Escargot."""
    log("Messenger Plus! 5.02: instalação solicitada e confirmada pelo usuário.")
    local=find_user_msgplus()
    if local is not None:
        log("Encontrado MsgPlusSetup.zip do usuário ao lado do instalador.")
        source="local"
    else:
        log("Arquivo local ausente: usando Plus! 5.02.712 distribuído pelo Escargot.")
        local=read_verified(PLUS_URL, PLUS_ARCHIVE_SHA256, 10_000_000, log)
        source="escargot"
    with tempfile.TemporaryDirectory(prefix="StormMSN-MsgPlus-") as d:
        directory=Path(d)
        exe=(extract_user_msgplus(local,directory) if source=="local"
             else extract_msgplus(local,directory))
        log("Integridade verificada. Abrindo instalador Messenger Plus! ("+source+").")
        log("Revise as telas e recuse ofertas patrocinadas, caso apareçam.")
        ret=subprocess.run([str(exe)],cwd=str(directory)).returncode
        if ret not in (0,3010):
            raise RuntimeError(f"O Messenger Plus! terminou com código {ret}.")
    # Retain Storm MSN / WLM 2009 server settings.
    for path,ini in ini_paths:
        f=Path(path)
        (f.parent/(f.name+"-escargot.ini")).write_bytes(ini)
    log("Messenger Plus! instalado, preservando os INIs do Storm MSN.")
    return True
