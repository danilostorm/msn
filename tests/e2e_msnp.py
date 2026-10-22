"""E2E real MSNP7 test: two ephemeral accounts, presence, switchboard message.
Exec: docker compose exec -T msn python -m tests.e2e_msnp
Accounts are deleted after test; uses random isolated email/password.
"""
import hashlib
import secrets
import socket
import time
from contextlib import closing
from sqlalchemy import func
from core.conn import Conn
from core.db import User as DBUser, UserContact
from script.user import set_passwords
from util.misc import gen_uuid
import settings

HOST = "127.0.0.1"
CODE = "storm-msn-e2e-" + secrets.token_hex(6)
SUFFIX = secrets.token_hex(6)
ACCOUNTS = [(f"e2e-a-{SUFFIX}@test.invalid", "e2eA"),(f"e2e-b-{SUFFIX}@test.invalid","e2eB")]
PASSWORDS = [secrets.token_urlsafe(20),secrets.token_urlsafe(20)]
conn = Conn(settings.DB)
clients = []

class Peer:
    def __init__(self,port):
        self.sock = socket.create_connection((HOST, port), 6)
        self.sock.settimeout(8)
        self.f = self.sock.makefile("rb")
        self.pending = []
        clients.append(self)
    def send(self, s, payload=b""):
        self.sock.sendall(s.encode() + b"\r\n" + payload)
    def next(self, timeout=8):
        self.sock.settimeout(timeout)
        line = self.f.readline()
        if not line:
            raise RuntimeError("connection ended")
        fields = line.decode("utf-8", "replace").strip().split(" ")
        payload = None
        if fields[0] in ("MSG", "NOT", "UUX", "QRY", "UBX", "GCF","ADL","FQY") and fields[-1].isdigit():
            payload = self.f.read(int(fields[-1]))
        return fields,payload
    def expect(self, op,tries=32):
        for i in range(tries):
            f,p = self.next()
            if f[0] == op: return f,p
            if f[0].isdigit(): raise AssertionError("Protocol error "+str(f))
        raise AssertionError("Did not receive "+op)
    def close(self):
        self.f.close()
        self.sock.close()

def register():
    with conn.session() as sess:
        for (email,name),pw in zip(ACCOUNTS,PASSWORDS):
            obj=DBUser(uuid=gen_uuid(),email=email,username=f"{name}_{SUFFIX}",
                verified=True, friendly_name=name,groups={},settings={})
            set_passwords(obj,pw,support_old_msn=True)
            sess.add(obj)

def login(email,pw):
    p=Peer(1863)
    p.send("VER 1 MSNP7 CVR0")
    f,_=p.expect("VER")
    assert f[2]=="MSNP7", f
    p.send("INF 2")
    f,_=p.expect("INF")
    assert f[-1]=="MD5", f
    p.send("USR 3 MD5 I "+email)
    f,_=p.expect("USR")
    assert f[3]=="S", f
    salt=f[4]
    proof=hashlib.md5((salt+pw).encode()).hexdigest()
    p.send("USR 4 MD5 S "+proof)
    f,_=p.expect("USR")
    assert f[2]=="OK" and f[3].lower()==email.lower(), f
    p.send("SYN 5 0")
    p.expect("SYN")
    p.send("CHG 6 NLN")
    f,_=p.expect("CHG")
    assert f[2]=="NLN", f
    print("PASS LOGIN + PRESENCE",email.split("@")[0][:5]+"…")
    return p

def run():
    register()
    a=login(ACCOUNTS[0][0],PASSWORDS[0])
    b=login(ACCOUNTS[1][0],PASSWORDS[1])
    a.send("XFR 7 SB")
    f,_=a.expect("XFR")
    assert f[2]=="SB" and f[4]=="CKI", f
    token=f[5]
    sb1=Peer(1864)
    sb1.send(f"USR 1 {ACCOUNTS[0][0]} {token}")
    sb1.expect("USR")
    sb1.send(f"CAL 2 {ACCOUNTS[1][0]}")
    f,_=sb1.expect("CAL")
    assert f[2]=="RINGING", f
    f,_=b.expect("RNG")
    session=f[1]
    reply_token=f[4]
    sb2=Peer(1864)
    sb2.send(f"ANS 1 {ACCOUNTS[1][0]} {reply_token} {session}")
    sb2.expect("ANS")
    mime=("MIME-Version: 1.0\r\nContent-Type: text/plain; charset=UTF-8\r\n\r\n"+CODE).encode("utf8")
    sb1.send(f"MSG 3 A {len(mime)}", mime)
    deadline=time.monotonic()+8
    arrived=False
    while time.monotonic()<deadline:
        f,p=sb2.next()
        if f[0]=="MSG" and p and CODE.encode() in p:
            arrived=True;break
    assert arrived, "No delivered chat message"
    print("PASS TWO ACCOUNTS, SB INVITATION, MESSAGE DELIVERED")
    a.send("OUT")
    b.send("OUT")

def cleanup():
    for p in clients:
        try:p.close()
        except Exception:pass
    with conn.session() as sess:
        for email,_ in ACCOUNTS:
            user=sess.query(DBUser).filter(DBUser.email==email).one_or_none()
            if user:
                sess.query(UserContact).filter((UserContact.user_id==user.id)|(UserContact.contact_id==user.id)).delete(synchronize_session=False)
                sess.delete(user)
    print("TEMP TEST ACCOUNTS DELETED")

if __name__=="__main__":
    try:run()
    finally:cleanup()
