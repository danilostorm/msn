'use strict';
const assert=require('assert');
const mod=require('./playstor-snes.js');
const xml='<MsgrConfig><LocalizedConfig><AppDirConfig></AppDirConfig></LocalizedConfig></MsgrConfig>';
const patched=mod.configPatch(xml);
assert(patched.includes('<GamesBrowserURL>https://msn.hoststorm.com.br/AppDirectory/Directory.aspx?from=wlm2009</GamesBrowserURL>'));
assert.strictEqual(mod.configPatch(patched),patched);
assert.strictEqual(mod.configPatch('<hello/>'),'<hello/>');
assert.strictEqual(mod.esc('<img src=x onerror="alert(1)">'),'&lt;img src=x onerror=&quot;alert(1)&quot;&gt;');
const fake=[
 {id:99,title:'A <script>alert(1)</script>',cover:null},
 {id:200,title:'Mario & Luigi',cover:null}
];
const html=mod.renderList(fake,'',1);
assert(html.includes('A &lt;script&gt;alert(1)&lt;/script&gt;'));
assert(html.includes('Mario &amp; Luigi'));
assert(html.includes('https://playstor.hoststorm.cloud/?game=99'));
assert(!html.includes('<script>alert(1)</script>'));
assert(!html.includes('/api/games/99/rom'));
const searched=mod.renderList(fake,'Mario',1);
assert(searched.includes('1 jogos encontrados'));
assert(!searched.includes('alert(1)'));
const directory=mod.xml(fake,null);
assert(directory.includes('<AppDir>'));
assert(directory.includes('<AppID>99</AppID>'));
assert(directory.includes('<Name>Mario &amp; Luigi</Name>'));
console.log('SNES PLAYSTOR CATALOG UNIT TESTS OK');
