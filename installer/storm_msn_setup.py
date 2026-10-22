"""Storm MSN Windows Live Messenger 2009 setup/bootstrapper.

Installs upstream original Microsoft Windows Live Messenger 2009 (via an
integrity-checked archive from Escargot) when absent, then automatically
imports the Escargot Switcher's ImportMe into WLM's MSNMSGR and WLCOMM
executables using LIEF. Writes Storm MSN-specific INIs, retaining per-file
backups and never changing system hosts or root certificates.

No proprietary Microsoft executable is bundled with this script or installer.
"""
import datetime
import hashlib
import io
import os
from pathlib import Path
import shutil
import subprocess
import sys
import tempfile
import threading
import traceback
from urllib.request import Request, urlopen
import zipfile
import tkinter as tk
from tkinter import scrolledtext, messagebox

APP_NAME = "Storm MSN"
UPSTREAM_ZIP_URL = (
    "https://storage.levelleap.com/nina/clients/msnp/"
    "patched-installer/msn/escargot-wlm-14.0.8117.0416-pt-br.zip"
)
UPSTREAM_ZIP_SHA256 = "4aa347b352dc33d4628c4e85bdf2e702e72aaaaf2fd86206f2611942ab72f2f0"
SWITCHER_ZIP_URL = "https://storage.levelleap.com/nina/clients/msnp/escargot-switcher.zip"
SWITCHER_SHA256 = "f3d88953c887c813887e37b5047173d104aeb3073fb44c235e231b028dc1d8b7"
NS_URL = "im.hoststorm.com.br"
WEB_URL = "msn.hoststorm.com.br"

SWITCHER_INI = (
    "[debug]\r\n"
    "enable = 0\r\n"
    "hooks = 0\r\n\r\n"
    "[options]\r\n"
    "type = msn\r\n"
    "passporturls = 1\r\n"
    f"server = {NS_URL}\r\n"
    f"configserver = {WEB_URL}\r\n"
).encode("ascii")

APPDATA = Path(os.environ.get("LOCALAPPDATA") or str(Path.home())) / "StormMSN"
BACKUPS = APPDATA / "Backups"
LOG_PATH = APPDATA / "instalador.log"


def write_log(message):
    APPDATA.mkdir(parents=True, exist_ok=True)
    with LOG_PATH.open("a", encoding="utf-8") as out:
        out.write(datetime.datetime.now().isoformat(timespec="seconds") + "  " + str(message) + "\n")


def program_paths():
    roots = []
    for env in ("ProgramFiles(x86)", "ProgramFiles"):
        value = os.environ.get(env)
        if value:
            roots.append(Path(value))
    roots += [Path("C:/Program Files (x86)"), Path("C:/Program Files")]
    seen = set()
    for root in roots:
        base = root / "Windows Live"
        if str(base).lower() in seen:
            continue
        seen.add(str(base).lower())
        msn = base / "Messenger" / "msnmsgr.exe"
        contacts = base / "Contacts" / "wlcomm.exe"
        if msn.is_file() and contacts.is_file():
            return [msn, contacts]
    return None


def read_verified(url, checksum, max_length, log):
    log("Baixando componentes da fonte oficial Escargot...")
    req = Request(url, headers={"User-Agent": "StormMSN-Setup/1.0"})
    with urlopen(req, timeout=60) as conn:
        data = conn.read(max_length + 1)
    if len(data) > max_length:
        raise RuntimeError("O arquivo ultrapassou o tamanho máximo esperado.")
    digest = hashlib.sha256(data).hexdigest()
    if digest != checksum:
        raise RuntimeError("Arquivo bloqueado: assinatura SHA-256 não coincide com a versão verificada.")
    log("Integridade SHA-256 confirmada.")
    return data


def load_switcher(log):
    data = read_verified(SWITCHER_ZIP_URL, SWITCHER_SHA256, 4_000_000, log)
    with zipfile.ZipFile(io.BytesIO(data)) as pack:
        dll = pack.read("escargot-switcher/escargot.dll")
    if len(dll) < 100_000 or dll[:2] != b"MZ":
        raise RuntimeError("A DLL do Switcher não é válida.")
    return dll


def open_installer(log):
    data = read_verified(UPSTREAM_ZIP_URL, UPSTREAM_ZIP_SHA256, 48_000_000, log)
    with zipfile.ZipFile(io.BytesIO(data)) as arc:
        exe = arc.read("escargot-wlm-14.0.8117.0416-pt-br.exe")
    if len(exe) < 8_000_000 or exe[:2] != b"MZ":
        raise RuntimeError("O instalador original não foi reconhecido.")
    with tempfile.TemporaryDirectory(prefix="StormMSN-original-") as d:
        exe_path = Path(d) / "WLM-2009-PTBR-original.exe"
        exe_path.write_bytes(exe)
        log("Abrindo o instalador WLM 2009. Conclua a instalação de Messenger e Contacts.")
        result = subprocess.run([str(exe_path)], cwd=d)
        log(f"Instalador WLM concluiu (código {result.returncode}).")
    paths = program_paths()
    if paths is None:
        raise RuntimeError(
            "O instalador foi fechado, mas Messenger e Contacts não foram encontrados.\n"
            "Instale os dois componentes e execute novamente o Storm MSN Setup."
        )
    return paths


def import_loaded(pe):
    for imp in pe.imports:
        if imp.name.lower() == "escargot.dll":
            for entry in imp.entries:
                if entry.name == "ImportMe":
                    return True
    return False


def check_pe(pe, path):
    import lief
    if pe is None:
        raise RuntimeError(f"O arquivo {path.name} não é um executável PE válido.")
    if pe.optional_header.magic != lief.PE.PE_TYPE.PE32:
        raise RuntimeError(f"Arquitetura inesperada para {path.name}: exige Windows Live 2009 x86.")
    if path.stat().st_size < 70_000:
        raise RuntimeError("Tamanho de executável inesperadamente pequeno: " + path.name)


def plan_backup(paths, log):
    stamp = datetime.datetime.now().strftime("%Y%m%d-%H%M%S")
    backup = BACKUPS / stamp
    backup.mkdir(parents=True, exist_ok=False)
    for path in paths:
        folder = backup / path.parent.name
        folder.mkdir(parents=True, exist_ok=True)
        for src in (
            path,
            path.parent / "escargot.dll",
            path.parent / (path.name + "-escargot.ini"),
        ):
            if src.is_file():
                shutil.copy2(src, folder / src.name)
        # A marker makes rollback skip files that didn't exist originally
        files = [item.name for item in folder.iterdir()]
        (folder / "manifest.txt").write_text("\n".join(files), encoding="utf-8")
    log("Backup completo salvo em: " + str(backup))
    return backup


def restore(paths, backup, log):
    log("Revertendo alterações por precaução...")
    for path in paths:
        directory = backup / path.parent.name
        manifest = directory / "manifest.txt"
        if not manifest.exists():
            continue
        files = set(manifest.read_text(encoding="utf-8").splitlines())
        for file_name in (path.name, "escargot.dll", path.name + "-escargot.ini"):
            target = path.parent / file_name
            if file_name in files:
                shutil.copy2(directory / file_name, target)
            elif target.exists():
                target.unlink()


def apply_patch_one(path, dll, log):
    import lief
    orig = lief.PE.parse(str(path))
    check_pe(orig, path)
    if import_loaded(orig):
        log("ImportMe já instalado em " + path.name + ". Mantendo o EXE atual.")
    else:
        imp = orig.add_import("escargot.dll")
        imp.add_entry("ImportMe")
        cfg = lief.PE.Builder.config_t()
        cfg.imports = True
        # Generate in the installation directory for atomic os.replace.
        fd, tmp = tempfile.mkstemp(prefix="storm-msn-", suffix=".exe", dir=str(path.parent))
        os.close(fd)
        try:
            orig.write(tmp, cfg)
            verify = lief.PE.parse(tmp)
            check_pe(verify, path)
            if not import_loaded(verify):
                raise RuntimeError("A validação do import ImportMe falhou para " + path.name)
            if Path(tmp).stat().st_size < path.stat().st_size // 3:
                raise RuntimeError("O executável recomposto é pequeno demais para ser seguro.")
            os.replace(tmp, path)
            log("ImportMe aplicado ao " + path.name + " e confirmado.")
        finally:
            if os.path.exists(tmp):
                os.unlink(tmp)
    (path.parent / "escargot.dll").write_bytes(dll)
    (path.parent / (path.name + "-escargot.ini")).write_bytes(SWITCHER_INI)
    log("Servidor Storm MSN aplicado a " + path.name + ".")


def install(log):
    log("Verificando instalações do Windows Live Messenger 2009...")
    paths = program_paths()
    if paths is None:
        paths = open_installer(log)
    else:
        log("WLM 2009 já encontrado. Não será reinstalado nem desinstalado.")
    # Don't kill processes or overwrite running files while the user is online.
    try:
        output = subprocess.run(
            ["tasklist", "/FI", "IMAGENAME eq msnmsgr.exe", "/FO", "CSV"],
            capture_output=True, text=True, timeout=8,
        ).stdout.lower()
        other = subprocess.run(
            ["tasklist", "/FI", "IMAGENAME eq wlcomm.exe", "/FO", "CSV"],
            capture_output=True, text=True, timeout=8,
        ).stdout.lower()
        if '"msnmsgr.exe"' in output or '"wlcomm.exe"' in other:
            raise RuntimeError("Feche completamente o Windows Live Messenger antes de instalar o patch.")
    except FileNotFoundError:
        pass
    import lief
    for path in paths:
        check_pe(lief.PE.parse(str(path)), path)
    dll = load_switcher(log)
    backup = plan_backup(paths, log)
    try:
        for path in paths:
            apply_patch_one(path, dll, log)
    except BaseException:
        restore(paths, backup, log)
        raise
    log("INSTALAÇÃO CONCLUÍDA! WLM original conectado ao Storm MSN.")
    log("Mensagens: " + NS_URL + ":1863 e :1864")
    log("Autenticação e contatos: https://" + WEB_URL)
    log("Abra o Windows Live Messenger 2009 e entre com sua conta do site.")


class SetupUI:
    def __init__(self):
        self.root = tk.Tk()
        self.root.title("Storm MSN — Instalação do Windows Live Messenger 2009")
        self.root.geometry("675x515")
        self.root.minsize(600, 480)
        self.root.configure(bg="#e5f5ff")
        label = tk.Label(
            self.root, text="🟢 Storm MSN", bg="#e5f5ff", fg="#087cae",
            font=("Segoe UI", 26, "bold"),
        )
        label.pack(pady=(28, 6))
        tk.Label(
            self.root, text="Windows Live Messenger 2009 original • Português do Brasil",
            bg="#e5f5ff", fg="#215b81", font=("Segoe UI", 11),
        ).pack(pady=(0, 14))
        tk.Label(
            self.root,
            text="Uma instalação: WLM 2009 + Switcher + servidor Storm MSN.\n"
                 "Se o Messenger original já estiver instalado, será apenas configurado.",
            bg="#e5f5ff", fg="#356784", justify="center",
        ).pack(pady=(0, 12))
        self.logbox = scrolledtext.ScrolledText(
            self.root, height=12, wrap="word", state="disabled", font=("Consolas", 9)
        )
        self.logbox.pack(fill="both", expand=True, padx=21, pady=10)
        self.button = tk.Button(
            self.root, text="INSTALAR STORM MSN",
            bg="#0885ba", fg="white", font=("Segoe UI", 13, "bold"),
            padx=28, pady=11, relief="flat", command=self.start,
        )
        self.button.pack(pady=(8, 15))
        tk.Label(
            self.root, text="Projeto independente. Sem alteração de HOSTS ou certificados raiz.",
            bg="#e5f5ff", fg="#647e95", font=("Segoe UI", 9),
        ).pack(pady=(0, 9))

    def append(self, text):
        write_log(text)
        self.root.after(0, self._append, str(text))

    def _append(self, text):
        self.logbox.config(state="normal")
        self.logbox.insert("end", text + "\n")
        self.logbox.see("end")
        self.logbox.config(state="disabled")

    def start(self):
        self.button.config(state="disabled", text="INSTALANDO...")
        def task():
            try:
                install(self.append)
                self.root.after(0, lambda: messagebox.showinfo(
                    "Storm MSN", "Instalação concluída!\n"
                    "Agora abra o Windows Live Messenger 2009 e entre com sua conta."
                ))
            except BaseException as exc:
                self.append("ERRO: " + str(exc))
                self.root.after(0, lambda error=str(exc): messagebox.showerror(
                    "Storm MSN", error + "\n\nLog: " + str(LOG_PATH)
                ))
            finally:
                self.root.after(0, lambda: self.button.config(
                    text="VERIFICAR / REINSTALAR", state="normal"
                ))
        threading.Thread(target=task, daemon=True).start()

    def mainloop(self):
        self.root.mainloop()


if __name__ == "__main__":
    SetupUI().mainloop()
