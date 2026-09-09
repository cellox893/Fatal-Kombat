import http from 'node:http';
import crypto from 'node:crypto';
import { WebSocketServer, WebSocket } from 'ws';
import { pathToFileURL } from 'node:url';

// STUN only discovers paths: gameplay traffic still goes directly between peers.
// TURN is deliberately opt-in, because it needs short-lived credentials.
export const DEFAULT_ICE_SERVERS = Object.freeze([{urls: ['stun:stun.cloudflare.com:3478']}]);

export function createSignaling({port = 8001, host = '0.0.0.0', iceServers = DEFAULT_ICE_SERVERS} = {}) {
  const rooms = new Map();
  const server = http.createServer((req, res) => {
    res.writeHead(200, {'Content-Type':'text/plain'}); res.end('Fatal Kombat signaling ready\n');
  });
  const wss = new WebSocketServer({server, maxPayload: 65536});
  const send = (ws, data) => { if(ws.readyState === WebSocket.OPEN) ws.send(JSON.stringify(data)); };
  const broadcast = room => room.peers.forEach((ws, slot) => send(ws, {type:'room', code:room.code, slot,
    players:room.peers.map(p => ({character:p.character, ready:p.ready})), iceServers}));
  wss.on('connection', ws => {
    if(wss.clients.size > 100) return ws.close(1013, 'capacity');
    ws.alive = true; ws.on('pong', () => ws.alive = true);
    ws.character = 'leonidas'; ws.ready = false; ws.count = 0; ws.bucket = Date.now();
    ws.on('message', raw => {
      try {
        if(Date.now()-ws.bucket > 1000) { ws.count=0; ws.bucket=Date.now(); }
        if(++ws.count > 100) return ws.close(1008, 'rate limit');
        const m = JSON.parse(raw);
        const error = message => send(ws, {type:'error', message});
        if(m.type === 'create' || m.type === 'join') {
          if(ws.room) return error('Sei già in una stanza: ricarica per uscire.');
          if(typeof m.version !== 'string' || m.version.length > 128) return error('Versione assente');
          let room;
          if(m.type === 'create') {
            let code; do {code=crypto.randomBytes(4).toString('hex').toUpperCase();} while(rooms.has(code));
            room={code, version:m.version, peers:[], started:false}; rooms.set(code, room);
          } else {
            room=rooms.get(String(m.code).toUpperCase());
            if(!room) return error('Stanza non trovata');
            if(room.peers.length >= 2) return error('Stanza piena');
            if(room.version !== m.version) return error('Build o contenuti incompatibili');
          }
          ws.room=room; room.peers.push(ws); broadcast(room);
        } else if(ws.room) {
          const room=ws.room;
          if(m.type === 'ready' && !room.started) {
            if(!['leonidas','tesla'].includes(m.character)) return error('Personaggio non valido');
            ws.character=m.character; ws.ready=Boolean(m.ready); broadcast(room);
            if(room.peers.length === 2 && room.peers.every(p=>p.ready)) {
              room.started=true; room.peers.forEach((p, slot)=>send(p,{type:'connect',slot}));
            }
          } else if(['sdp','ice'].includes(m.type) && room.started) {
            if(m.type === 'sdp' && (!['offer','answer'].includes(m.kind) || typeof m.sdp !== 'string')) return error('SDP non valido');
            if(m.type === 'ice' && (typeof m.mid !== 'string' || !Number.isInteger(m.index) || typeof m.candidate !== 'string')) return error('ICE non valido');
            room.peers.filter(p=>p!==ws).forEach(p=>send(p,m));
          }
        } else error('Entra prima in una stanza');
      } catch { send(ws,{type:'error',message:'Messaggio non valido'}); }
    });
    ws.on('close', () => {
      const room=ws.room; if(!room) return;
      rooms.delete(room.code);
      room.peers.filter(p=>p!==ws).forEach(p=> {p.room=null; send(p,{type:'error',message:'Avversario disconnesso. Ricarica per una nuova stanza.'});});
    });
    ws.on('error',()=>{});
  });
  const timer=setInterval(()=>wss.clients.forEach(ws=> {
    if(!ws.alive) return ws.terminate(); ws.alive=false; ws.ping();
  }),15000); timer.unref();
  server.listen(port,host);
  return {server,wss,rooms,close:()=>{clearInterval(timer); wss.clients.forEach(ws=>ws.terminate());wss.close();server.close();}};
}
if(process.argv[1] && import.meta.url === pathToFileURL(process.argv[1]).href) {
  const iceServers = process.env.ICE_SERVERS_JSON === undefined
    ? DEFAULT_ICE_SERVERS
    : JSON.parse(process.env.ICE_SERVERS_JSON);
  createSignaling({port:Number(process.env.PORT || 8001), iceServers});
  console.log('Signaling listening on 0.0.0.0:'+(process.env.PORT || 8001));
}
