"""Optional, opt-in Messenger Plus! 5.02 setup for WLM 2009.

No bundled adware or third-party binaries. Downloads the original encrypted
7z archive from Escargot only after an explicit user request. Extraction and
PE integrity are validated; the vendor installer UI is never silent.
"""
import hashlib
import io
from pathlib import Path
import subprocess
import tempfile

PLUS_URL = "https://storage.levelleap.com/nina/clients/msnp/msgplus/patched/MsgPlus-5.02.712.7z"
PLUS_ARCHIVE_SHA256 = "bc599c6640c5b9656434da810b2b7b25a7e7eaa8c4c2a7e38feb01ae485d1be8"
PLUS_EXE_SHA256 = "6bb92709e160a8410cd2fb465c40ddf6fd7b9d8891473fcc69760a2caa5b4918"
PLUS_EXE_SIZE = 7_614_344
PLUS_EXE_NAME = "MsgPlus-5.02.712.exe"


def extract_msgplus(archive: bytes, output: Path) -> Path:
    """Decrypt the official archive only, avoiding unpacking arbitrary paths."""
    if hashlib.sha256(archive).hexdigest() != PLUS_ARCHIVE_SHA256:
        raise ValueError("O arquivo Messenger Plus! não corresponde ao SHA-256 oficial.")
    import py7zr
    with py7zr.SevenZipFile(io.BytesIO(archive), "r", password="escargot") as z:
        names = z.getnames()
        if names != [PLUS_EXE_NAME]:
            raise ValueError("O 7z do Messenger Plus! contém arquivos inesperados.")
        z.extractall(path=output)
    exe = output / PLUS_EXE_NAME
    if not exe.is_file() or exe.stat().st_size != PLUS_EXE_SIZE:
        raise ValueError("O tamanho do executável Messenger Plus! não confere.")
    if exe.read_bytes()[:2] != b"MZ":
        raise ValueError("O executável Messenger Plus! não é um PE válido.")
    if hashlib.sha256(exe.read_bytes()).hexdigest() != PLUS_EXE_SHA256:
        raise ValueError("A integridade do instalador Messenger Plus! falhou.")
    return exe


def install_msgplus(log, read_verified, ini_paths):
    log("Messenger Plus! 5.02: opção solicitada pelo usuário.")
    log("Baixando o arquivo original criptografado no site Escargot.")
    payload = read_verified(PLUS_URL, PLUS_ARCHIVE_SHA256, 12_000_000, log)
    with tempfile.TemporaryDirectory(prefix="StormMSN-MsgPlus-") as tmp:
        setup = extract_msgplus(payload, Path(tmp))
        log("SHA-256 do executável Messenger Plus! validado.")
        log("Abrindo o instalador ORIGINAL do Messenger Plus!.")
        log("ATENÇÃO: recuse programas patrocinados e ofertas extras na tela do instalador.")
        code = subprocess.run([str(setup)], cwd=str(setup.parent)).returncode
        if code not in (0, 3010):
            raise RuntimeError(f"O instalador Messenger Plus! retornou o código {code}.")
    log("Instalador Messenger Plus! encerrado. Verifique o menu Plus! no WLM 2009.")
    log("Recursos de som e serviços online do Plus! podem depender da rede Escargot.")
    # The third-party installer may reconfigure patched host URLs; restore
    # the user's own Storm MSN configuration without changing passwords.
    for exe_path, ini_content in ini_paths:
        Path(exe_path).with_name(Path(exe_path).name + "-escargot.ini").write_bytes(ini_content)
    log("Endereços de servidor do Storm MSN reafirmados nos INIs.")
    return True
