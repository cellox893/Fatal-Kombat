import test from 'node:test';
import assert from 'node:assert/strict';
import {once} from 'node:events';
import {mkdtemp,writeFile,rm,symlink} from 'node:fs/promises';
import {tmpdir} from 'node:os';
import {join} from 'node:path';
import {WebSocket} from 'ws';
import {createPreview} from './preview.mjs';
import {createSignaling} from './server.mjs';
const listening=async app=>{await once(app.server,'listening');return app.server.address().port;};

test('same-origin preview serves only build files and proxies lobby requests', {timeout:10000}, async()=> {
 const dir=await mkdtemp(join(tmpdir(),'fk-preview-'));
 const lobby=createSignaling({port:0,host:'127.0.0.1'});
 const lobbyPort=await listening(lobby);
 await writeFile(join(dir,'index.html'),'<h1>test</h1>');
 await symlink('/etc/hostname',join(dir,'outside.txt'));
 const preview=createPreview({port:0,host:'127.0.0.1',root:dir,signalingUrl:`ws://127.0.0.1:${lobbyPort}`});
 const port=await listening(preview);
 const clients=[];
 try {
  const response=await fetch(`http://127.0.0.1:${port}/`);
  assert.equal(response.status,200);assert.equal(response.headers.get('cache-control'),'no-store');
  assert.equal((await fetch(`http://127.0.0.1:${port}/outside.txt`)).status,403);
  assert.equal((await fetch(`http://127.0.0.1:${port}/signaling`)).status,426);
  const a=new WebSocket(`ws://127.0.0.1:${port}/signaling`);clients.push(a);await once(a,'open');
  const created=once(a,'message');a.send(JSON.stringify({type:'create',version:'probe'}));
  const room=JSON.parse((await created)[0]);assert.equal(room.type,'room');
  const b=new WebSocket(`ws://127.0.0.1:${port}/signaling`);clients.push(b);await once(b,'open');
  const joined=once(b,'message');b.send(JSON.stringify({type:'join',code:room.code,version:'probe'}));
  assert.equal(JSON.parse((await joined)[0]).slot,1);
  const gone= new Promise(resolve=>a.on('message',raw=>{if(JSON.parse(raw).type==='error') resolve();}));
  b.close();await gone;
 } finally {clients.forEach(c=>c.terminate());preview.close();lobby.close();await rm(dir,{recursive:true,force:true});}
});

test('proxy reports unavailable signaling instead of silently hanging', {timeout:10000}, async()=> {
 const preview=createPreview({port:0,host:'127.0.0.1',signalingUrl:'ws://127.0.0.1:1'});
 const port=await listening(preview);
 const client=new WebSocket(`ws://127.0.0.1:${port}/signaling`);
 try {const [code]=await once(client,'close');assert.equal(code,1011);}
 finally {client.terminate();preview.close();}
});
