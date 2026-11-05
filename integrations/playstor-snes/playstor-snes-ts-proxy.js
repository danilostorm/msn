'use strict';
const net=require('net');
const allowed=new Set(['100.99.136.79','100.107.117.74']);
const s=net.createServer(client=>{
 const ip=(client.remoteAddress||'').replace(/^::ffff:/,'');
 if(!allowed.has(ip)){console.warn('blocked_source');client.destroy();return;}
 const upstream=net.createConnection({host:'127.0.0.1',port:18590});
 upstream.setTimeout(6000,()=>upstream.destroy());
 upstream.on('connect',()=>{upstream.setTimeout(0);client.pipe(upstream);upstream.pipe(client)});
 upstream.on('error',e=>{console.warn('upstream_error',e.code);client.destroy()});
 client.on('error',()=>upstream.destroy());
 client.on('close',()=>upstream.destroy());
 upstream.on('close',()=>client.destroy());
});
s.on('error',e=>{console.error('catalog_tailscale_error',e.code);process.exit(1)});
s.listen(18592,'100.114.49.54',()=>console.log('SNES_PRIVATE_GATEWAY_READY 100.114.49.54:18592'));
