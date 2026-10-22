"""Optional Messenger Plus! 5.02 integration with the WLM 2009 Storm MSN setup.

Messenger Plus! 5.02 is opt-in and may offer sponsored software (adware).
Never silently accept offers. Both original binaries are downloaded only
after explicit consent, with fixed SHA-256 integrity checks.
"""
import hashlib
from pathlib import Path
import subprocess
import tempfile

PLUS_URL = "https://storage.levelleap.com/nina/clients/msnp/msgplus/patched/MsgPlus-5.02.712.7z"
PLUS_ARCHIVE_SHA256 = "bc599c6640c5b9656434da810b2b7b25a7e7eaa8c4c2a7e38feb01ae485d1be8"
PLUS_EXE_SHA256 = "6bb92709e160a8410cd2fb465c40ddf6fd7b9d8891473fcc69760a2caa5b4918"
PLUS_EXE_SIZE = 7_614_344
PLUS_EXE_NAME = "MsgPlus-5.02.712.exe"

# The encrypted 7z uses AES + BCJ2 filters that py7zr cannot decode.
# The official standalone 7zr.exe handles 7z format and runs on Win32/Win64.
SEVENZIP_URL = "https://www.7-zip.org/a/7zr.exe"
SEVENZIP_SHA256 = "256feca8e274e5da655e2a284fabafd9f554365eb164862089dacd4e8276d282"


def extract_msgplus(archive: bytes, output: Path, sevenzip_path: Path) -> Path:
    """Unpack with official 7zr only after authenticating both downloads."""
    if hashlib.sha256(archive).hexdigest() != PLUS_ARCHIVE_SHA256:
        raise ValueError("O arquivo Messenger Plus! não corresponde ao SHA-256 oficial.")
    if not sevenzip_path.is_file() or hashlib.sha256(sevenzip_path.read_bytes()).hexdigest() != SEVENZIP_SHA256:
        raise ValueError("O extrator 7-Zip não corresponde ao download oficial.")
    archive_path = output / "MsgPlus-5.02.712.7z"
    archive_path.write_bytes(archive)
    options = [
        str(sevenzip_path), "x", "-y", "-pescargot",
        "-o" + str(output), str(archive_path),
    ]
    proc = subprocess.run(
        options, cwd=str(output), capture_output=True, text=True,
        timeout=120, creationflags=getattr(subprocess, "CREATE_NO_WINDOW", 0),
    )
    if proc.returncode != 0:
        raise RuntimeError(
            "Falha ao extrair o Messenger Plus! com o 7-Zip: " +
            (proc.stdout + proc.stderr)[-1000:]
        )
    exe = output / PLUS_EXE_NAME
    if not exe.is_file() or exe.stat().st_size != PLUS_EXE_SIZE:
        raise ValueError("O tamanho do executável Messenger Plus! não confere.")
    with exe.open("rb") as handle:
        if handle.read(2) != b"MZ":
            raise ValueError("O executável Messenger Plus! não é um PE válido.")
    if hashlib.sha256(exe.read_bytes()).hexdigest() != PLUS_EXE_SHA256:
        raise ValueError("A integridade do instalador Messenger Plus! falhou.")
    return exe


def install_msgplus(log, read_verified, ini_paths):
    """Launch Yuna Software's ORIGINAL GUI, without any silent flags."""
    log("Messenger Plus! 5.02 solicitado pelo usuário.")
    log("Obtendo o pacote criptografado do site oficial do Escargot.")
    payload = read_verified(PLUS_URL, PLUS_ARCHIVE_SHA256, 12_000_000, log)
    helper = read_verified(SEVENZIP_URL, SEVENZIP_SHA256, 2_000_000, log)
    with tempfile.TemporaryDirectory(prefix="StormMSN-MsgPlus-") as tmp:
        folder = Path(tmp)
        sevenzip = folder / "7zr.exe"
        sevenzip.write_bytes(helper)
        setup = extract_msgplus(payload, folder, sevenzip)
        log("SHA-256 do executável Messenger Plus! verificado.")
        log("Abrindo o instalador original do Messenger Plus! (Yuna Software).")
        log("Atenção: RECUSE ofertas patrocinadas e programas adicionais.")
        code = subprocess.run([str(setup)], cwd=str(folder)).returncode
        if code not in (0, 3010):
            raise RuntimeError(f"O instalador Messenger Plus! retornou o código {code}.")
    # The vendor installer can reconfigure WLM endpoints for Escargot.
    # Ensure the user's own Storm MSN host settings are preserved.
    for exe_path, ini_content in ini_paths:
        file = Path(exe_path)
        (file.parent / (file.name + "-escargot.ini")).write_bytes(ini_content)
    log("Configurações do Storm MSN restabelecidas.")
    log("O Messenger Plus! está instalado; sons online podem depender do Escargot.")
    return True
