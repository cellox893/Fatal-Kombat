import test from 'node:test';
import assert from 'node:assert/strict';
import {once} from 'node:events';
import {WebSocket} from 'ws';
import {createSignaling, DEFAULT_ICE_SERVERS} from './server.mjs';
test('private room, version gate, ready, relay, full room and disconnect', async () => {
 const app=createSignaling({port:0,host:'127.0.0.1'});
 await once(app.server,'listening');
 const clients=[];
 async function connect(){const ws=new WebSocket(`ws://127.0.0.1:${app.server.address().port}`);clients.push(ws);await once(ws,'open');return ws;}
 const request=async(ws,m)=>{const result=once(ws,'message');ws.send(JSON.stringify(m));return JSON.parse((await result)[0]);};
 try {
  const a=await connect(), b=await connect(), c=await connect();
  const version='lab-4:'+'a'.repeat(64);
  const room=await request(a,{type:'create',version}); assert.match(room.code,/^[A-F0-9]{8}$/);
  assert.deepEqual(room.iceServers, DEFAULT_ICE_SERVERS);
  for(const incompatible of ['lab-3:'+'a'.repeat(64), 'lab-4:'+'b'.repeat(64)]) {
   assert.equal((await request(b,{type:'join',code:room.code,version:incompatible})).message,'Build o contenuti incompatibili');
   assert.equal(app.rooms.get(room.code).peers.length,1);
   assert.equal(app.rooms.get(room.code).started,false);
   assert.equal((await request(b,{type:'ready',character:'tesla',ready:true})).message,'Entra prima in una stanza');
  }
  assert.equal((await request(b,{type:'join',code:room.code,version})).slot,1);
  assert.equal((await request(c,{type:'join',code:room.code,version})).message,'Stanza piena');
  await request(a,{type:'ready',character:'leonidas',ready:true});
  const connected= new Promise(resolve=>a.on('message',raw=>{const m=JSON.parse(raw);if(m.type==='connect') resolve(m);}));
  await request(b,{type:'ready',character:'tesla',ready:true});await connected;
  const relayed=new Promise(resolve=>b.on('message',raw=>{const m=JSON.parse(raw);if(m.type==='sdp') resolve(m);}));a.send(JSON.stringify({type:'sdp',kind:'offer',sdp:'test'}));
  assert.equal((await relayed).sdp,'test');
  const relayedIce=new Promise(resolve=>b.on('message',raw=>{const m=JSON.parse(raw);if(m.type==='ice') resolve(m);}));
  a.send(JSON.stringify({type:'ice',mid:'0',index:0,candidate:'candidate:1 1 udp 1 127.0.0.1 9 typ host'}));
  assert.equal((await relayedIce).candidate,'candidate:1 1 udp 1 127.0.0.1 9 typ host');
  const completed=new Promise(resolve=>b.on('message',raw=>{const m=JSON.parse(raw);if(m.type==='ice-complete') resolve(m);}));
  a.send(JSON.stringify({type:'ice-complete'})); assert.equal((await completed).type,'ice-complete');
  const closed=once(a,'message'); b.close();assert.match(JSON.parse((await closed)[0]).message,/disconnesso/);
 } finally {clients.forEach(c=>c.terminate());app.close();}
});
