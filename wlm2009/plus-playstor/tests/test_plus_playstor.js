'use strict';
const assert=require('assert');
const fs=require('fs'),path=require('path'),vm=require('vm');
const root=path.join(__dirname,'..');
const src=fs.readFileSync(path.join(root,'Main.js'),'utf8');
assert(!/OnEvent_ChatWnd(?:Receive|Send)Message|Interop\.Call|XMLHttpRequest|http:\/\//i.test(src));
assert(src.includes('OnGetScriptMenu'));
assert(src.includes('OnEvent_MenuClicked'));
let calls=[],exists=true;
const sandbox={
 ActiveXObject: function(name) {
  if(name==='Scripting.FileSystemObject')
    return {FileExists(file){calls.push(['exists',file]);return exists;}};
  if(name==='WScript.Shell')
    return {Run(command,mode,wait){calls.push(['run',command,mode,wait]);return 0;}};
  throw Error('unexpected ActiveX '+name);
 },
 MsgPlus:{DisplayToast(title,message){calls.push(['toast',title,message])}}
};
vm.createContext(sandbox);vm.runInContext(src,sandbox);
const menu=sandbox.OnGetScriptMenu(0);
assert(menu.includes('Jogos PlayStor (Edge)'));
assert(menu.includes('Id="StormPlayStorCatalog"'));
assert(!menu.includes('https://'));
sandbox.OnEvent_MenuClicked('OtherMenu',0,null);
assert.strictEqual(calls.length,0);
sandbox.OnEvent_MenuClicked('StormPlayStorCatalog',0,null);
assert.strictEqual(calls.length,2);
assert.strictEqual(calls[1][0],'run');
assert(calls[1][1].includes('StormEdgePlaystorLauncher.exe" --catalog'));
assert.strictEqual(calls[1][2],1);
assert.strictEqual(calls[1][3],false);
calls=[];exists=false;
sandbox.OnEvent_MenuClicked('StormPlayStorCatalog',0,null);
assert.strictEqual(calls.length,2);
assert.strictEqual(calls[1][0],'toast');
assert(!calls.some(x=>x[0]==='run'));
console.log('Messenger Plus! Storm MSN PlayStor: 9 checks passed');
