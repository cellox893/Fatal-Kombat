import {chromium} from '@playwright/test';
import assert from 'node:assert/strict';

const browser=await chromium.launch({headless:true,args:['--no-sandbox']});
const pageA=await browser.newPage();
const pageB=await browser.newPage();
const url='http://127.0.0.1:8000';
const setup=initiator => {
  const result={events:[],localCandidates:[],remoteCandidates:[],addErrors:[],iceCandidateErrors:[],received:[]};
  const type=candidate => ((candidate.match(/ typ ([^ ]+)/)||[])[1]||'other');
  const pc=new RTCPeerConnection({iceServers:[],iceTransportPolicy:'all'});
  result.config=pc.getConfiguration();
  const record=event=>result.events.push(event);
  pc.onicegatheringstatechange=()=>record(`gathering=${pc.iceGatheringState}`);
  pc.oniceconnectionstatechange=()=>record(`ice=${pc.iceConnectionState}`);
  pc.onconnectionstatechange=()=>record(`connection=${pc.connectionState}`);
  pc.onicecandidateerror=event=>result.iceCandidateErrors.push(`${event.errorCode} ${event.errorText}`);
  pc.onicecandidate=event=> {
    if(!event.candidate) {record('candidate-end');return;}
    result.localCandidates.push({...event.candidate.toJSON(),type:type(event.candidate.candidate)});
    record(`candidate=${type(event.candidate.candidate)}`);
  };
  const accept=channel=> {
    channel.onopen=()=>{record('channel-open');if(initiator) channel.send('ping');};
    channel.onmessage=event=>{result.received.push(event.data);if(event.data==='ping') channel.send('pong');};
  };
  if(initiator) accept(pc.createDataChannel('isolated-inputs',{ordered:false,maxRetransmits:0}));
  else pc.ondatachannel=event=>accept(event.channel);
  window.isolated={pc,result};
};

try {
  await Promise.all([pageA.goto(url),pageB.goto(url)]);
  await pageA.evaluate(setup,true); await pageB.evaluate(setup,false);
  const offer=await pageA.evaluate(async()=>{const description=await isolated.pc.createOffer();await isolated.pc.setLocalDescription(description);return isolated.pc.localDescription;});
  assert.match(offer.sdp,/m=application/); assert.match(offer.sdp,/a=ice-ufrag:/); assert.match(offer.sdp,/a=ice-pwd:/); assert.match(offer.sdp,/a=fingerprint:/);
  const answer=await pageB.evaluate(async offer=>{await isolated.pc.setRemoteDescription(offer);const description=await isolated.pc.createAnswer();await isolated.pc.setLocalDescription(description);return isolated.pc.localDescription;},offer);
  await pageA.evaluate(answer=>isolated.pc.setRemoteDescription(answer),answer);
  await pageA.waitForTimeout(1000);
  const aCandidates=await pageA.evaluate(()=>isolated.result.localCandidates);
  const bCandidates=await pageB.evaluate(()=>isolated.result.localCandidates);
  await pageB.evaluate(async candidates=>{for(const candidate of candidates){try{await isolated.pc.addIceCandidate(candidate);isolated.result.remoteCandidates.push(candidate);}catch(error){isolated.result.addErrors.push(String(error));}}},aCandidates);
  await pageA.evaluate(async candidates=>{for(const candidate of candidates){try{await isolated.pc.addIceCandidate(candidate);isolated.result.remoteCandidates.push(candidate);}catch(error){isolated.result.addErrors.push(String(error));}}},bCandidates);
  await pageA.waitForFunction(()=>isolated.result.received.includes('pong'),null,{timeout:10000});
  const result=await Promise.all([pageA.evaluate(()=>isolated.result),pageB.evaluate(()=>isolated.result)]);
  assert(result.every(peer=>peer.config.iceTransportPolicy==='all'));
  assert(result.every(peer=>peer.localCandidates.length>0 && peer.remoteCandidates.length>0));
  assert(result.every(peer=>peer.localCandidates.every(candidate=>candidate.type==='host' || candidate.type==='srflx' || candidate.type==='relay' || candidate.type==='other')));
  assert(result.every(peer=>peer.addErrors.length===0 && peer.iceCandidateErrors.length===0));
  assert(result.every(peer=>peer.events.includes('candidate-end')));
  console.log('PASS isolated WebRTC: SDP application/ICE/DTLS, candidates, addIceCandidate and ping/pong',result);
} finally {
  await browser.close();
}
