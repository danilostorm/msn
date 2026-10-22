# Storm MSN MSNP7 protocol transport (unencrypted legacy protocol).
import asyncio
import hashlib

class Protocol:
    def __init__(self,host,email,password,events):
        self.host=host
        self.email=email.lower()
        self.password=password
        self.events=events
        self.reader=None
        self.writer=None
        self.chats={}
        self.waiting={}
        self.calls=[]
        self.number=10
    def emit(self,*event):self.events.put(event)
    def send(self,w,command,data=b""):
        w.write(command.encode()+b"\r\n"+data)
    async def frame(self,r):
        line=await r.readline()
        if not line:raise ConnectionError("Conexão encerrada")
        words=line.decode("utf8","replace").strip().split()
        data=b""
        if words[0] in ("MSG","NOT","UBX","GCF","ADL") and words[-1].isdigit():
            data=await r.readexactly(int(words[-1]))
        return words,data
    async def until(self,r,op):
        for _ in range(30):
            words,data=await asyncio.wait_for(self.frame(r),12)
            if words[0]==op:return words,data
            if words[0].isdigit():raise RuntimeError("Resposta inesperada do MSN: "+str(words))
        raise RuntimeError("Protocolo sem resposta: "+op)
    async def login(self):
        try:
            self.reader,self.writer=await asyncio.open_connection(self.host,1863)
            r,w=self.reader,self.writer
            self.send(w,"VER 1 MSNP7 CVR0")
            response,_=await self.until(r,"VER")
            if response[2]!="MSNP7":raise RuntimeError("MSNP7 não suportado")
            self.send(w,"INF 2")
            await self.until(r,"INF")
            self.send(w,"USR 3 MD5 I "+self.email)
            response,_=await self.until(r,"USR")
            salt=response[4]
            proof=hashlib.md5((salt+self.password).encode()).hexdigest()
            self.password=""
            self.send(w,"USR 4 MD5 S "+proof)
            response,_=await self.until(r,"USR")
            if response[2]!="OK":raise RuntimeError("Credenciais inválidas")
            self.send(w,"SYN 5 0")
            await self.until(r,"SYN")
            self.send(w,"CHG 6 NLN")
            await self.until(r,"CHG")
            self.emit("online",self.email)
            while True:
                words,data=await self.frame(r)
                cmd=words[0]
                if cmd=="LST" and len(words)>5:
                    self.emit("contact",words[4],words[5])
                if cmd=="ADD" and len(words)>4:self.emit("contact",words[4],words[4])
                if cmd in ("NLN","ILN"):
                    mails=[s for s in words if "@" in s]
                    if mails:self.emit("presence",mails[0],"online")
                if cmd=="FLN" and len(words)>1:self.emit("presence",words[1],"offline")
                if cmd=="XFR" and len(words)>5 and words[2]=="SB" and self.calls:
                    email=self.calls.pop(0)
                    asyncio.create_task(self.outgoing(email,words[5]))
                if cmd=="RNG" and len(words)>5:
                    asyncio.create_task(self.incoming(words[1],words[4],words[5]))
        except Exception as ex:
            self.emit("error",str(ex))
        finally:self.emit("offline")
    async def outgoing(self,email,token):
        r,w=await asyncio.open_connection(self.host,1864)
        self.send(w,"USR 1 "+self.email+" "+token)
        await self.until(r,"USR")
        self.send(w,"CAL 2 "+email)
        await self.until(r,"CAL")
        await self.sb_loop(r,w,email)
    async def incoming(self,chat_id,token,email):
        r,w=await asyncio.open_connection(self.host,1864)
        self.send(w,"ANS 1 "+self.email+" "+token+" "+chat_id)
        await self.until(r,"ANS")
        self.chats[email]=w
        self.emit("ready",email)
        await self.sb_loop(r,w,email)
    async def sb_loop(self,r,w,email):
        try:
            while True:
                words,data=await self.frame(r)
                if words[0]=="JOI":
                    self.chats[email]=w
                    self.emit("ready",email)
                if words[0]=="MSG" and data and b"\r\n\r\n" in data:
                    head,body=data.split(b"\r\n\r\n",1)
                    if b"text/plain" in head.lower():
                        self.emit("message",email,body.decode("utf8","replace"))
                if words[0]=="BYE":break
        except (OSError,asyncio.IncompleteReadError,ConnectionError):pass
        finally:
            self.chats.pop(email,None)
            w.close()
            self.emit("closed",email)
    async def send_message(self,email,text):
        if email not in self.chats:
            self.waiting.setdefault(email,[]).append(text)
            if email not in self.calls:
                self.calls.append(email)
                self.number+=1
                self.send(self.writer,"XFR "+str(self.number)+" SB")
            return
        if text:
            body=("MIME-Version: 1.0\r\nContent-Type: text/plain; charset=UTF-8\r\n\r\n"+text).encode()
            if len(body)>1664:raise RuntimeError("Mensagem grande demais")
            self.number+=1
            self.send(self.chats[email],f"MSG {self.number} A {len(body)}",body)
    async def flush(self,email):
        for msg in self.waiting.pop(email,[]):
            await self.send_message(email,msg)
    async def add(self,email):
        self.number+=1
        self.send(self.writer,f"ADD {self.number} FL {email} {email}")
        self.number+=1
        self.send(self.writer,f"ADD {self.number} AL {email} {email}")
    async def change(self,status):
        self.number+=1
        self.send(self.writer,f"CHG {self.number} {status}")
    async def disconnect(self):
        if self.writer:self.send(self.writer,"OUT");self.writer.close()

