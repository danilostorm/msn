'use strict';
// Storm MSN x PlayStor: SNES catalog gateway. No ROMs, secrets, or legacy plugins.
const http=require('http'),https=require('https'),fs=require('fs');
const URL=require('url').URL;
const PLAY='https://playstor.hoststorm.cloud',MSN='https://msn.hoststorm.com.br';
const BACKENDS={aerocool:'100.99.136.79',superframe:'100.107.117.74'};
let saved=[],cachedAt=0;
function esc(x){return String(x===null||x===undefined?'':x).replace(/[&<>"']/g,c=>({'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;',"'":'&#39;'}[c]));}
function upstream(url,max=900000){
 return new Promise((ok,bad)=>{
  const u=url.startsWith('https:')?https:http;let parts=[],size=0;
  const r=u.get(url,{timeout:8500,headers:{'accept':'application/json,text/xml,*/*','user-agent':'StormMSN-PlayStor-1.0'}},resp=>{
   if(resp.statusCode!==200){resp.resume();bad(Error('HTTP_'+resp.statusCode));return;}
   resp.on('data',b=>{size+=b.length;if(size>max){r.destroy(Error('size_limit'));return;}parts.push(b)});
   resp.on('end',()=>ok(Buffer.concat(parts)));
   resp.on('error',bad);
  });
  r.on('timeout',()=>r.destroy(Error('timeout')));
  r.on('error',bad);
 });
}
async function games(){
 const age=Date.now()-cachedAt;
 if(saved.length&&age<180000)return saved;
 try{
  const json=JSON.parse((await upstream(PLAY+'/api/games?system=snes')).toString('utf8'));
  if(!Array.isArray(json.items))throw Error('invalid_api_shape');
  const list=json.items.filter(g=>g&&g.system==='snes'&&Number.isSafeInteger(g.id)&&g.id>0&&typeof g.title==='string'&&g.title.trim())
   .slice(0,500).map(g=>({id:g.id,title:g.title.slice(0,150),
    cover:/^\/covers\/[0-9a-f-]{36}\.(png|webp|jpg|jpeg)$/i.test(g.cover||'')?PLAY+g.cover:null}));
  if(!list.length)throw Error('empty_snes_catalog');
  saved=list;cachedAt=Date.now();
 }catch(e){console.error('catalog_refresh',e.message);if(!saved.length||age>3600000)throw e;}
 return saved;
}
const style='body{font:13px Arial,Verdana,sans-serif;color:#164166;margin:0;background:#e9f3fc}.frame{max-width:870px;margin:0 auto;background:#fff;min-height:100vh}.head{padding:16px;background:#137bad;color:white;border-bottom:4px solid #82d0eb}.head b{font-size:22px}.main{padding:14px}.note{background:#eaf6ff;padding:10px;border:1px solid #c4e5f7;line-height:1.5}.finder{padding:14px 0}.finder input{padding:7px;width:60%;border:1px solid #8db5d2}.finder button{padding:7px;background:#0586bc;border:1px solid #0481b3;color:white}.tile{display:inline-block;vertical-align:top;width:45%;min-width:238px;margin:0 1.5% 10px 0;border:1px solid #d3e8f4;height:148px;overflow:hidden;background:#f8fdff}.cover{float:left;width:104px;padding:8px}.cover img{max-width:90px;max-height:122px}.detail{padding:9px 4px;overflow:hidden}.detail strong{display:block;height:50px;overflow:hidden;font-size:14px}.sub{font-size:11px;color:#668094;margin:6px 0 10px}.play{background:#007eb5;color:#fff;text-decoration:none;display:inline-block;padding:8px;font-weight:bold}.foot{padding:10px;color:#5a6e80;border-top:1px solid #dce9f4;font-size:11px}.pages{text-align:center;padding:18px}.pages a{color:#006da0;margin:0 12px}.empty{padding:25px}@media(max-width:560px){.tile{width:96%;min-width:0}}';
function renderList(list,q,page){
 const query=q.toLocaleLowerCase().trim();
 const matches=query?list.filter(g=>g.title.toLocaleLowerCase().indexOf(query)!==-1):list;
 const totalPages=Math.max(1,Math.ceil(matches.length/24));
 page=Math.max(1,Math.min(totalPages,page));
 const tiles=matches.slice((page-1)*24,page*24).map(g=>'<div class="tile"><div class="cover">'+
  (g.cover?'<img src="'+esc(g.cover)+'" width="90" height="120" alt="">':'SNES')+
  '</div><div class="detail"><strong>'+esc(g.title)+'</strong><div class="sub">Super Nintendo · PlayStor</div>'+
  '<a class="play" target="_blank" rel="noopener noreferrer" href="'+PLAY+'/?game='+g.id+'">Abrir no PlayStor</a></div></div>').join('');
 const path='/AppDirectory/Directory.aspx?q='+encodeURIComponent(q);
 const pages='<div class="pages">'+(page>1?'<a href="'+esc(path+'&page='+(page-1))+'">Anterior</a>':'')+
  'Página '+page+' de '+totalPages+(page<totalPages?'<a href="'+esc(path+'&page='+(page+1))+'">Próxima</a>':'')+'</div>';
 return '<!doctype html><html lang="pt-BR"><head><meta charset="utf-8"><meta http-equiv="X-UA-Compatible" content="IE=edge"><meta name="viewport" content="width=device-width,initial-scale=1"><title>Storm MSN Jogos — SNES PlayStor</title><style>'+style+'</style></head><body><div class="frame">'+
 '<div class="head"><b>Storm MSN · Jogos</b><div>Catálogo SNES conectado ao PlayStor</div></div><div class="main">'+
 '<div class="note"><b>Teste SNES:</b> jogos abertos no navegador moderno, mediante login no PlayStor. O Windows Live Messenger 2009 exibe o catálogo, mas não executa emuladores WebAssembly no navegador antigo. Partidas entre contatos ainda não são sincronizadas.</div>'+
 '<form class="finder" method="get" action="/AppDirectory/Directory.aspx"><label for="q">Pesquisar jogo: </label><input name="q" id="q" maxlength="80" value="'+esc(q)+'" placeholder="Mario, Zelda, Donkey Kong"><button>Buscar</button></form>'+
 '<p>'+matches.length+' jogos encontrados · '+list.length+' no catálogo SNES</p>'+(tiles||'<div class="empty">Nenhum jogo encontrado.</div>')+pages+
 '</div><div class="foot">PlayStor fornece apenas metadados e capas neste catálogo; ROMs exigem conta PlayStor. Projeto independente.</div></div></body></html>';
}
function xml(list,id){
 const items=id?list.filter(g=>g.id===Number(id)):list.slice(0,100);
 return '<?xml version="1.0" encoding="utf-8"?><AppDir><Category><CategoryID>SNES</CategoryID><Locale>pt-BR</Locale><CategoryName>Super Nintendo</CategoryName></Category>'+
 items.map(g=>'<Entry><AppID>'+g.id+'</AppID><ID>'+g.id+'</ID><Name>'+esc(g.title)+'</Name><Description>SNES PlayStor - navegador moderno</Description><CategoryID>SNES</CategoryID><Type>Game</Type><URL>'+PLAY+'/?game='+g.id+'</URL></Entry>').join('')+'</AppDir>';
}
function configPatch(s){
 if(!/<MsgrConfig[\s>]/i.test(s)||!/<AppDirConfig>/i.test(s)||!/<LocalizedConfig[\s>]/i.test(s)||/<GamesBrowserURL>/i.test(s))return s;
 return s.replace('</AppDirConfig>','</AppDirConfig>\n      <GamesBrowserURL>'+MSN+'/AppDirectory/Directory.aspx?from=wlm2009</GamesBrowserURL>');
}
function active(){
 const r=JSON.parse(fs.readFileSync('/var/lib/storm-msn-ha/role.json','utf8')).active;
 if(!Object.prototype.hasOwnProperty.call(BACKENDS,r))throw Error('no active MSN role');
 return BACKENDS[r];
}
function respond(res,status,type,body){
 res.writeHead(status,{'Content-Type':type,'Cache-Control':'no-store','X-Content-Type-Options':'nosniff','X-Frame-Options':'SAMEORIGIN'});
 res.end(body);
}
async function handle(req,res){
 try{
  const u=new URL(req.url,'http://localhost'),path=u.pathname;
  if(path==='/healthz'){respond(res,200,'application/json',JSON.stringify({ok:true,service:'storm-msn-snes',cached:saved.length}));return;}
  if(req.method==='GET'&&/^\/(Config\/MsgrConfig\.asmx|etc\/MsgrConfig)$/i.test(path)&&/^(14|15|16|17)\./.test(u.searchParams.get('ver')||'')){
   const b=await upstream('http://'+active()+':18181'+req.url,200000);
   const t=b.toString('utf8');
   if(!/<MsgrConfig[\s>]/i.test(t))throw Error('bad_config_source');
   respond(res,200,'text/xml; charset=utf-8',configPatch(t));return;
  }
  if(path==='/AppDirectory/GetAppdirVersion.aspx'){respond(res,200,'text/xml; charset=utf-8','<?xml version="1.0"?><AppDirVersion><Version>1</Version></AppDirVersion>');return;}
  if(req.method==='GET'&&(path==='/AppDirectory/Directory.aspx'||path==='/AppDirectory/Games.aspx')){
   const list=await games(),q=(u.searchParams.get('q')||'').slice(0,80);
   const page=Math.max(1,Math.min(1000,parseInt(u.searchParams.get('page'),10)||1));
   respond(res,200,'text/html; charset=utf-8',renderList(list,q,page));return;
  }
  if(path==='/AppDirectory/AppDirectory.asmx'){
   const list=await games();
   if(req.method==='GET'){respond(res,200,'text/xml; charset=utf-8',xml(list,u.searchParams.get('id')));return;}
   if(req.method==='POST'){
    let buffers=[],size=0;
    req.on('data',b=>{size+=b.length;if(size>32000){req.destroy();return;}buffers.push(b)});
    req.on('end',()=>{
     const b=Buffer.concat(buffers).toString('utf8'),action=(req.headers.soapaction||'')+' '+b.slice(0,2000);
     const method=/GetAppEntry/i.test(action)?'GetAppEntry':'GetFilteredDataSet2';
     const match=b.match(/<(?:\w+:)?(?:AppID|appID|id)>(\d+)<\/(?:\w+:)?(?:AppID|appID|id)>/i);
     const content=xml(list,method==='GetAppEntry'&&match?match[1]:null).replace(/^<\?xml[^>]*\?>/,'');
     const soap='<?xml version="1.0" encoding="utf-8"?><soap:Envelope xmlns:soap="http://schemas.xmlsoap.org/soap/envelope/"><soap:Body><'+method+'Response xmlns="http://tempuri.org/"><'+method+'Result>'+content+'</'+method+'Result></'+method+'Response></soap:Body></soap:Envelope>';
     respond(res,200,'text/xml; charset=utf-8',soap);
    });return;
   }
  }
  respond(res,404,'text/plain','Not found');
 }catch(e){console.error('gateway_error',e.message);respond(res,503,'text/plain','Catalogo SNES indisponivel temporariamente.');}
}
if(require.main===module){http.createServer(handle).listen(18590,'127.0.0.1',()=>console.log('MSN_SNES_GATEWAY_READY 127.0.0.1:18590'));}
module.exports={renderList,configPatch,xml,esc,games};

