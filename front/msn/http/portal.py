"""Storm MSN account portal. HTTP must be deployed behind HTTPS."""
import html
import os
import re
import secrets
import time
import hmac
from collections import defaultdict, deque
from aiohttp import web, WSMsgType
import asyncio
from datetime import datetime, timedelta
from sqlalchemy import func
from sqlalchemy.exc import IntegrityError
from core.conn import Conn
from core.db import User as DBUser
from script.user import set_passwords
from util.misc import gen_uuid
import settings

SESSION = "storm_msn_session"
CSRF = "storm_msn_csrf"
RATE = defaultdict(deque)
ACTIVE_WS = defaultdict(int)
EMAIL = re.compile(r"^[A-Za-z0-9._%+\-]{1,64}@[A-Za-z0-9.\-]{3,190}$")
NAME = re.compile(r"^[A-Za-z0-9_.\-]{3,24}$")
HDR = {"Cache-Control":"no-store","X-Content-Type-Options":"nosniff","Referrer-Policy":"strict-origin-when-cross-origin","Content-Security-Policy":"default-src 'none'; style-src 'unsafe-inline'; form-action 'self'; frame-ancestors 'none'; base-uri 'none'"}
STYLE = """
*{box-sizing:border-box}body{margin:0;color:#214866;font:16px 'Segoe UI',Arial,sans-serif;background:linear-gradient(140deg,#f9fdff,#dff4ff 60%,#eef1ff);min-height:100vh}header{background:white;border-bottom:1px solid #b5d9ec;padding:17px 7%}
.logo{font-size:25px;font-weight:800;color:#0c81b3;text-decoration:none}nav{float:right;margin-top:9px}nav a{margin-left:16px;color:#1480b7;text-decoration:none;font-weight:600}
main{max-width:970px;margin:55px auto;padding:0 24px}h1{font-size:54px;line-height:1.06;letter-spacing:-2px;margin:0;color:#18476c}h1 span{color:#17abb8}h2{font-size:27px;margin-top:0}p{line-height:1.7}
.hero{display:grid;grid-template-columns:1fr 1fr;gap:36px;align-items:center}.card{border:1px solid #c2e1f2;border-radius:23px;background:white;box-shadow:0 18px 50px #4881a622;padding:32px}
.msg{padding:16px;border-radius:16px;background:#e3f6ff;margin:15px 0}.msg.right{background:#dcf6e6;margin-left:45px}.msg b{display:block;color:#1f97a8;font-size:13px;margin-bottom:7px}
.btn{display:inline-block;padding:13px 20px;background:linear-gradient(#36b9e5,#008bb7);color:white;text-decoration:none;font-weight:700;border:0;border-radius:11px;cursor:pointer;margin:10px 10px 0 0}.btn.alt{background:white;border:1px solid #b2d7e9;color:#1d78a9}
form label{display:block;font-weight:600;margin:18px 0 7px}input{width:100%;padding:13px;border:1px solid #afcfe5;border-radius:10px;font:inherit}.form{max-width:510px;margin:auto}
.note{background:#eaf6ff;padding:13px;border-radius:10px;margin:15px 0;font-size:14px}.err{background:#ffeaec;color:#a11f43;padding:13px;border-radius:10px;margin-bottom:14px}
.grid{display:grid;grid-template-columns:repeat(3,1fr);gap:14px;margin-top:35px}.feature{border:1px solid #c4dfef;border-radius:16px;padding:20px;background:#fff9}.feature b{color:#167eb1}footer{text-align:center;font-size:13px;color:#6c8da1;padding:36px}
@media(max-width:700px){nav{float:none;margin-top:16px}.hero,.grid{grid-template-columns:1fr}main{margin:32px auto}h1{font-size:43px}}
"""
def esc(v):return html.escape(str(v),quote=True)
def page(body,title="Storm MSN"):
    return web.Response(text=f'''<!doctype html><html lang="pt-br"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"><title>{esc(title)}</title><style>{STYLE}</style></head><body><header><a class="logo" href="/">🟢 Storm MSN</a><nav><a href="/clientes">Clientes</a><a href="/registrar">Cadastro</a><a href="/entrar">Entrar</a></nav></header><main>{body}</main><footer>Projeto independente de nostalgia MSN, sem afiliação à Microsoft ou Escargot.</footer></body></html>''',content_type="text/html",headers=HDR)
def csrf(req):
    if "csrf_storm" in req:return req["csrf_storm"]
    key=req.cookies.get(CSRF,"")
    if not re.fullmatch(r"[0-9a-f]{48}",key):key=secrets.token_hex(24)
    req["csrf_storm"]=key
    return key
def with_csrf(req,resp):
    if not re.fullmatch(r"[0-9a-f]{48}",req.cookies.get(CSRF,"")):
        resp.set_cookie(CSRF,csrf(req),max_age=3600,httponly=True,samesite="Strict",secure=req.secure or req.headers.get("Cf-Visitor","").find("https")>=0)
    return resp
def valid_csrf(req,post):
    return len(req.cookies.get(CSRF,""))==48 and hmac.compare_digest(req.cookies.get(CSRF,""),str(post.get("csrf","")))
def rate(req,tag,limit,window):
    client=req.headers.get("CF-Connecting-IP",req.remote) if req.remote in ("127.0.0.1","::1") else req.remote
    k=(client,tag);q=RATE[k];now=time.monotonic()
    while q and q[0]<now-window:q.popleft()
    if len(q)>=limit:return False
    q.append(now);return True
def token(req):return '<input type="hidden" name="csrf" value="'+csrf(req)+'">'
async def home(req):
    return page('''<div class="hero"><div><h1>O seu MSN <span>está de volta.</span></h1><p>Encontre seus amigos, mostre seu status e reviva o Messenger em uma rede independente.</p><p><a href="/registrar" class="btn">Criar conta</a><a href="/clientes" class="btn alt">Baixar Storm MSN</a></p><p style="font-size:13px">Cadastro de testes liberado. Windows Live Messenger 2009 ainda em validação.</p></div><div class="card"><h2>💬 Bate-papo clássico</h2><div class="msg"><b>Amigo • Online 🟢</b>Você lembra do MSN?</div><div class="msg right"><b>Você</b>Lembro até dos emoticons 😎</div><div class="msg"><b>Amigo</b>🔔 Chamando sua atenção!</div></div></div><div class="grid"><div class="feature"><b>🟢 Presença online</b><p>Veja quando seus amigos estiverem conectados.</p></div><div class="feature"><b>💬 Conversas</b><p>Conexão real utilizando o protocolo MSN.</p></div><div class="feature"><b>🖥️ Nostalgia</b><p>Instalação simplificada do Windows Live Messenger 2009 original.</p></div></div>''')
async def register_get(req,error="",success=""):
    if os.environ.get("MSN_PUBLIC_SIGNUP","0")!="1":
        return page('<div class="card form"><h2>Cadastro em preparação</h2><p>O servidor está em testes. O cadastro público será liberado após a configuração segura de HTTPS e do cliente.</p><a class="btn" href="/clientes">Ver clientes</a></div>')
    if success:return page('<div class="card form"><h2>Cadastro realizado</h2><p>'+esc(success)+'</p><a class="btn" href="/entrar">Entrar</a></div>')
    err='<div class="err">'+esc(error)+'</div>' if error else ''
    body=f'''<div class="card form"><h2>Crie sua conta</h2>{err}<form action="/registrar" method="post">{token(req)}
    <label>Usuário</label><input name="name" minlength="3" maxlength="24" required autocomplete="username" placeholder="Seu apelido">
    <label>E-mail</label><input type="email" name="email" maxlength="254" required autocomplete="email" placeholder="voce@exemplo.com">
    <label>Senha exclusiva do Storm MSN</label><input type="password" name="password" minlength="12" maxlength="15" required autocomplete="new-password">
    <input name="website" type="text" style="display:none" tabindex="-1" autocomplete="off" aria-hidden="true">
    <p class="note">Para o Windows Live Messenger 2009, utilize uma senha <strong>exclusiva de 12 a 15 caracteres</strong>. Não reutilize senhas de outros serviços. O protocolo antigo não oferece segurança moderna.</p><button class="btn">Criar conta</button></form></div>'''
    return with_csrf(req,page(body,"Cadastro — Storm MSN"))
async def register_post(req):
    if os.environ.get("MSN_PUBLIC_SIGNUP","0")!="1":raise web.HTTPForbidden()
    if req.content_length and req.content_length>4096:raise web.HTTPRequestEntityTooLarge(max_size=4096,actual_size=req.content_length)
    p=await req.post()
    if not valid_csrf(req,p):return await register_get(req,"Atualize a página e tente novamente.")
    if not rate(req,"reg",3,3600):return await register_get(req,"Muitas tentativas. Volte mais tarde.")
    if str(p.get("website","")).strip():raise web.HTTPForbidden()
    email=str(p.get("email","")).strip().lower();name=str(p.get("name","")).strip();pw=str(p.get("password",""))
    if not EMAIL.fullmatch(email) or ".." in email or not NAME.fullmatch(name) or not 12<=len(pw)<=15:
        return await register_get(req,"Confira seu e-mail, usuário e senha (senha entre 12 e 15 caracteres).")
    try:
        with Conn(settings.DB).session() as sess:
            if sess.query(DBUser).filter(DBUser.date_created >= datetime.utcnow()-timedelta(hours=24)).count() >= 40:
                return await register_get(req,"Novas contas limitadas temporariamente. Tente amanhã.")
            if sess.query(DBUser).filter((func.lower(DBUser.email)==email)|(func.lower(DBUser.username)==name.lower())).first():
                return await register_get(req,"Usuário ou e-mail já cadastrado.")
            user=DBUser(uuid=gen_uuid(),email=email,username=name,verified=False,friendly_name=name,groups={},settings={})
            set_passwords(user,pw,support_old_msn=True)
            sess.add(user)
    except IntegrityError:return await register_get(req,"Usuário ou e-mail já cadastrado.")
    return await register_get(req,success="Conta criada! Você já pode entrar no painel e, após instalar o WLM 2009 configurado, fazer login no Messenger.")
async def login_get(req,error=""):
    err='<div class="err">'+esc(error)+'</div>' if error else ''
    return with_csrf(req,page(f'''<div class="card form"><h2>Entrar</h2>{err}<form action="/entrar" method="post">{token(req)}
    <label>E-mail</label><input type="email" name="email" maxlength="254" required autocomplete="username">
    <label>Senha</label><input type="password" name="password" maxlength="128" required autocomplete="current-password"><button class="btn">Entrar</button></form></div>'''))
async def login_post(req):
    p=await req.post()
    if not valid_csrf(req,p):return await login_get(req,"Atualize a página.")
    if not rate(req,"login",10,600):return await login_get(req,"Muitas tentativas.")
    email=str(p.get("email","")).strip().lower();password=str(p.get("password",""))
    if not EMAIL.fullmatch(email):return await login_get(req,"Credenciais inválidas.")
    uid=req.app["backend"].user_service.login(email,password)
    if not uid:return await login_get(req,"Credenciais inválidas.")
    ticket,_=req.app["backend"].auth_service.create_token("storm-portal",uid,lifetime=43200)
    resp=web.HTTPFound("/conta")
    resp.set_cookie(SESSION,ticket,httponly=True,max_age=43200,samesite="Lax",secure=req.secure or req.headers.get("Cf-Visitor","").find("https")>=0)
    return resp
async def account(req):
    uid=req.app["backend"].auth_service.get_token("storm-portal",req.cookies.get(SESSION,""))
    if not uid:raise web.HTTPFound("/entrar")
    with Conn(settings.DB).session() as sess:
        user=sess.query(DBUser).filter(DBUser.uuid==uid).one_or_none()
        if not user:raise web.HTTPFound("/entrar")
        name,email=user.username,user.email
    return with_csrf(req,page(f'''<div class="card form"><h2>Bem-vindo, {esc(name)}!</h2><p>Conta ativa no Storm MSN.</p><p><strong>E-mail:</strong> {esc(email)}</p><p><a class="btn" href="/clientes">Configurar cliente</a></p><form action="/sair" method="post">{token(req)}<button class="btn alt">Sair</button></form></div>'''))
async def logout(req):
    p=await req.post()
    if not valid_csrf(req,p):raise web.HTTPForbidden()
    req.app["backend"].auth_service.pop_token("storm-portal",req.cookies.get(SESSION,""))
    r=web.HTTPFound("/");r.del_cookie(SESSION);return r
async def clients(req):
    return page("""<section class="card">
<h2>Windows Live Messenger 2009 original — em português</h2><p class="note"><strong>Storm MSN v1.0.2:</strong> Corrige a verificação do wlcomm.exe e oferece a correção oficial da lista de contatos no Windows 11 24H2/25H2. Se recebeu "Sua lista de contatos não está disponível", feche completamente o Messenger, instale esta versão, marque a opção de compatibilidade Win11 24H2/25H2 e confirme a abertura da ferramenta do Escargot. Depois, reinicie o computador. Sua conta permanece a mesma.</p>
<p>O Storm MSN usa o <strong>Windows Live Messenger 2009 da Microsoft (14.0.8117.0416)</strong>, com o Switcher configurado para nossa rede. É o Messenger clássico, com sua interface e lista de contatos originais. <strong>Não é o cliente experimental em Python.</strong></p>
<div class="grid">
  <div class="feature"><b>1. Instale o WLM 2009</b><p>Um EXE do Storm MSN baixa o cliente WLM 2009 PT-BR, configura os dois executáveis e faz backup automático. Sem usar PATCH ALL manualmente.</p><p><a class="btn" href="/downloads/StormMSN-Setup-v1.0.2.exe">Baixar Storm MSN v1.0.2 (.exe)</a></p></div>
  <div class="feature"><b>2. Configure o Storm MSN</b><p>Se preferir o método anterior, o pacote com os arquivos INI e o assistente PowerShell continua disponível.</p><p><a class="btn" href="/downloads/StormMSN-WLM2009-Configuracao.zip">Configuração Storm MSN</a></p></div>
  <div class="feature"><b>3. Entre na sua conta</b><p>Após instalar e configurar o cliente, entre com uma conta criada especificamente para o Storm MSN.</p><p><a class="btn alt" href="/registrar">Cadastro de usuário</a></p></div>
</div>
<h2 style="margin-top:38px">Windows 11 24H2/25H2: erro na lista de contatos</h2>
<p>Se ao tentar entrar aparecer "Sua lista de contatos não está disponível", é uma incompatibilidade conhecida do banco de contatos do Windows 11 mais novo com o WLM 2009. O <strong>StormMSN-Setup v1.0.2</strong> detecta esses Windows e permite executar, com sua autorização, a correção oficial Escargot. O programa de terceiros é iniciado em sua janela, pode modificar componentes do Windows e é recomendado reiniciar depois.</p>
<p><a class="btn alt" href="https://static.nina.chat/distro/EscargotWin24H2.zip" rel="noopener noreferrer">Baixar correção original NINA (ZIP)</a></p>
<h2 style="margin-top:38px">Endereços do serviço</h2>
<p><strong>Servidor de mensagens:</strong> im.hoststorm.com.br (TCP 1863 e 1864, via Oracle e AEROCOOL).<br>
<strong>Configuração e autenticação:</strong> msn.hoststorm.com.br (HTTPS).</p>
<p class="note"><strong>Status de testes:</strong> servidor MSNP15 acessível pela internet, serviços HTTPS operacionais e configuração de Switcher preparada. O login no cliente gráfico WLM 2009 foi confirmado em uma instalação existente, mas a <strong>nova versão de instalador único ainda precisa de teste manual no Windows</strong>. Cadastro de contas de teste habilitado. A compatibilidade final do WLM 2009 ainda está em validação.</p>
<p class="note">Para sua segurança, a configuração NÃO muda o arquivo HOSTS do Windows, não pede instalação de certificados raiz e não substitui executáveis da Microsoft. O WLM original é um programa antigo e as mensagens não possuem criptografia ponta a ponta.</p>
</section>""", "Windows Live Messenger 2009 — Storm MSN")

async def download_wlm_config(req):
    from pathlib import Path
    archive=Path("/data/downloads/StormMSN-WLM2009-Configuracao.zip")
    if not archive.is_file():
        raise web.HTTPNotFound()
    return web.FileResponse(archive, headers={
      "Content-Disposition": 'attachment; filename="StormMSN-WLM2009-Configuracao.zip"',
      "X-Content-Type-Options":"nosniff",
      "Cache-Control":"no-store",
    })

async def download_storm_setup(req):
    from pathlib import Path
    versioned=req.path.endswith("/StormMSN-Setup-v1.0.2.exe")
    filename="StormMSN-Setup-v1.0.2.exe" if versioned else "StormMSN-Setup.exe"
    executable=Path("/data/downloads") / filename
    if not executable.is_file():
        raise web.HTTPNotFound()
    return web.FileResponse(executable, headers={
        "Content-Disposition": 'attachment; filename="' + filename + '"',
        "X-Content-Type-Options": "nosniff",
        "Cache-Control": "no-store",
        "Content-Security-Policy": "default-src 'none'",
        "Content-Type": "application/octet-stream",
    })

async def download_wlm_installer(req):
    from pathlib import Path
    pack=Path("/data/downloads/StormMSN-WLM2009-Instalador.zip")
    if not pack.is_file():raise web.HTTPNotFound()
    return web.FileResponse(pack,headers={
        "Content-Disposition":'attachment; filename="StormMSN-WLM2009-Instalador.zip"',
        "X-Content-Type-Options":"nosniff",
        "Cache-Control":"no-store",
    })

async def health(req):return web.json_response({"service":"storm-msn","status":"ok"},headers={"Cache-Control":"no-store"})
async def websocket_bridge(req):
    """Encrypted WSS transport for native/client-local-gateway, fixed MSN ports only."""
    port=req.match_info.get("port")
    if port not in ("1863","1864"):raise web.HTTPNotFound()
    origin=req.headers.get("Origin","")
    if origin and origin!="https://msn.hoststorm.com.br":raise web.HTTPForbidden()
    public_ip=req.headers.get("CF-Connecting-IP",req.remote) if req.remote in ("127.0.0.1","::1") else req.remote
    if ACTIVE_WS[public_ip]>=8:raise web.HTTPTooManyRequests()
    if not rate(req,"wss",45,60):raise web.HTTPTooManyRequests()
    try:
        reader,writer=await asyncio.wait_for(asyncio.open_connection("127.0.0.1",int(port)),8)
    except (OSError,asyncio.TimeoutError):
        raise web.HTTPServiceUnavailable()
    ws=web.WebSocketResponse(max_msg_size=32768,heartbeat=30,compress=False)
    await ws.prepare(req)
    ACTIVE_WS[public_ip]+=1
    async def tcp_to_ws():
        try:
            while not ws.closed:
                chunk=await reader.read(16384)
                if not chunk:break
                await ws.send_bytes(chunk)
        finally:await ws.close()
    task=asyncio.create_task(tcp_to_ws())
    try:
        async for msg in ws:
            if msg.type==WSMsgType.BINARY:
                writer.write(msg.data)
                await asyncio.wait_for(writer.drain(),10)
            elif msg.type in (WSMsgType.TEXT,WSMsgType.ERROR):
                break
    finally:
        task.cancel()
        try:await task
        except asyncio.CancelledError:pass
        writer.close()
        try:await writer.wait_closed()
        except Exception:pass
        ACTIVE_WS[public_ip]-=1
    return ws

def register(app,backend):
    app["backend"]=backend
    app.router.add_get("/ws/{port}",websocket_bridge)
    app.router.add_get("/downloads/StormMSN-Setup.exe",download_storm_setup)
    app.router.add_get("/downloads/StormMSN-Setup-v1.0.2.exe",download_storm_setup)
    app.router.add_get("/downloads/StormMSN-WLM2009-Configuracao.zip",download_wlm_config)
    app.router.add_get("/downloads/StormMSN-WLM2009-Instalador.zip",download_wlm_installer)
    for route,path,handler in [('get','/',home),('get','/registrar',register_get),('post','/registrar',register_post),
        ('get','/entrar',login_get),('post','/entrar',login_post),('get','/conta',account),
        ('post','/sair',logout),('get','/clientes',clients),('get','/api/health',health)]:
        getattr(app.router,'add_'+route)(path,handler)
