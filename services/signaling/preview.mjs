import http from 'node:http';
import {createReadStream} from 'node:fs';
import {readFile} from 'node:fs/promises';
import {realpath, stat} from 'node:fs/promises';
import {resolve, sep, extname} from 'node:path';
import {fileURLToPath, pathToFileURL} from 'node:url';
import {WebSocket, WebSocketServer} from 'ws';

const defaultRoot = fileURLToPath(new URL('../../build/web/', import.meta.url));
const mime = {'.html':'text/html; charset=utf-8','.js':'text/javascript; charset=utf-8',
  '.wasm':'application/wasm','.pck':'application/octet-stream','.png':'image/png','.svg':'image/svg+xml'};

// Runs before Godot's generated index.js creates the browser RTCPeerConnection.
// It observes the real browser object without replacing Godot's handlers.
const WEBRTC_PROBE = String.raw`<script>
(() => {
  const store = window.fatalLabRtc = window.fatalLabRtc || {events: []};
  const Native = window.RTCPeerConnection;
  if (!Native || store.installed) return;
  const log = (event, value) => { const item = event + (value ? '=' + value : ''); store.events.push(item); if (store.events.length > 16) store.events.shift(); console.info('[Fatal Kombat WebRTC]', item); };
  function Probe(config) {
    const pc = new Native(config);
    store.installed = true; store.created = true; store.config = config;
    const type = value => ((value || '').match(/ typ ([^ ]+)/) || [])[1] || 'other';
    const sync = () => { store.iceGatheringState = pc.iceGatheringState; store.iceConnectionState = pc.iceConnectionState; store.connectionState = pc.connectionState; };
    pc.addEventListener('icegatheringstatechange', () => { sync(); log('iceGatheringState', store.iceGatheringState); });
    pc.addEventListener('iceconnectionstatechange', () => { sync(); log('iceConnectionState', store.iceConnectionState); });
    pc.addEventListener('connectionstatechange', () => { sync(); log('connectionState', store.connectionState); });
    pc.addEventListener('icecandidate', event => log(event.candidate ? 'onicecandidate' : 'onicecandidate-end', event.candidate ? type(event.candidate.candidate) : 'complete'));
    pc.addEventListener('icecandidateerror', event => { store.iceCandidateError = String(event.errorCode || '') + ' ' + String(event.errorText || ''); log('onicecandidateerror', store.iceCandidateError.trim()); });
    sync(); log('created');
    return pc;
  }
  Probe.prototype = Native.prototype;
  Object.setPrototypeOf(Probe, Native);
  window.RTCPeerConnection = Probe;
})();
</script>`;

const withWebRtcProbe = html => html.replace('<script src="index.js"></script>', WEBRTC_PROBE + '\n\t\t<script src="index.js"></script>');

// Same-origin browser entrypoint. Lobby remains a separate process; no game inputs use this proxy.
export function createPreview({port=8000, host='0.0.0.0', root=defaultRoot,
  signalingUrl='ws://127.0.0.1:8001'} = {}) {
  const base=resolve(root);
  const server=http.createServer(async(req,res)=> {
    res.setHeader('Cache-Control','no-store');
    if(!['GET','HEAD'].includes(req.method)) {res.writeHead(405);res.end();return;}
    try {
      const pathname=decodeURIComponent(new URL(req.url,'http://preview').pathname);
      if(pathname==='/signaling') {res.writeHead(426);res.end('WebSocket required');return;}
      const file=await realpath(resolve(base,'.'+(pathname==='/'?'/index.html':pathname)));
      if(!file.startsWith(base+sep)) {res.writeHead(403);res.end();return;}
      const info=await stat(file);
      if(!info.isFile()) {res.writeHead(404);res.end();return;}
      if(extname(file)==='.html') {
        const body=withWebRtcProbe(await readFile(file,'utf8'));
        res.writeHead(200,{'Content-Type':mime['.html'],'Content-Length':Buffer.byteLength(body)});
        if(req.method==='HEAD') {res.end();return;}
        res.end(body);return;
      }
      res.writeHead(200,{'Content-Type':mime[extname(file)] || 'application/octet-stream','Content-Length':info.size});
      if(req.method==='HEAD') {res.end();return;}
      const stream=createReadStream(file);
      stream.on('error',()=>res.destroy());
      res.on('close',()=>stream.destroy());
      stream.pipe(res);
    } catch {res.writeHead(404);res.end('Not found');}
  });
  const wss=new WebSocketServer({noServer:true,maxPayload:65536});
  server.on('upgrade',(req,socket,head)=> {
    if(req.url!=='/signaling' || wss.clients.size>=100) {
      socket.end('HTTP/1.1 404 Not Found\r\nConnection: close\r\n\r\n');return;
    }
    wss.handleUpgrade(req,socket,head,client=>wss.emit('connection',client));
  });
  wss.on('connection',client=> {
    // Do not forward browser cookies or authorization to the internal service.
    const upstream=new WebSocket(signalingUrl,{handshakeTimeout:5000,maxPayload:65536});
    let pending=[], pendingBytes=0;
    const stop=()=>{pending=[];pendingBytes=0;};
    const unavailable=()=>{stop();client.close(1011,'Signaling service unavailable');};
    const forward=(target,data,isBinary)=> {
      if(target.readyState!==WebSocket.OPEN) return;
      if(target.bufferedAmount+data.length>131072) {target.close(1008,'Backpressure limit');return;}
      target.send(data,{binary:isBinary});
    };
    upstream.on('open',()=> {
      if(client.readyState!==WebSocket.OPEN) {upstream.close();stop();return;}
      for(const [data,isBinary] of pending) forward(upstream,data,isBinary);
      stop();
    });
    client.on('message',(data,isBinary)=> {
      if(upstream.readyState===WebSocket.CONNECTING) {
        pendingBytes+=data.length;
        if(pendingBytes>65536) {client.close(1008,'Pending limit');return;}
        pending.push([data,isBinary]);
      } else forward(upstream,data,isBinary);
    });
    upstream.on('message',(data,isBinary)=>forward(client,data,isBinary));
    upstream.on('error',unavailable);
    upstream.on('close',(code,reason)=> {
      stop();
      client.close(code===1006 || code===1005 ? 1011 : code,reason);
    });
    client.on('error',()=>upstream.terminate());
    client.on('close',()=>{stop();upstream.terminate();});
  });
  server.listen(port,host);
  return {server,wss,close:()=>{wss.clients.forEach(ws=>ws.terminate());wss.close();server.close();}};
}
if(process.argv[1] && import.meta.url===pathToFileURL(process.argv[1]).href) {
  createPreview();
  console.log('Preview 0.0.0.0:8000; /signaling proxies to separate service on 127.0.0.1:8001');
}
