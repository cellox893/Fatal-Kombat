import {chromium} from '@playwright/test';
import assert from 'node:assert/strict';
const browser=await chromium.launch({headless:true,args:['--no-sandbox','--enable-webgl','--use-gl=angle','--use-angle=swiftshader']});
try {
 const a=await browser.newPage({viewport:{width:1120,height:700}});
 const b=await browser.newPage({viewport:{width:1120,height:700}});
 const errors=[];
 for(const p of [a,b]) {p.on('pageerror',e=>errors.push(String(e)));p.on('console',m=>{if(m.type()==='error')errors.push(m.text());});}
 await Promise.all([a.goto('http://127.0.0.1:8000'),b.goto('http://127.0.0.1:8000')]);
 await Promise.all([a.waitForFunction(()=>window.fatalLab,{timeout:60000}),b.waitForFunction(()=>window.fatalLab,{timeout:60000})]);
 await a.screenshot({path:'build/lab.png'});
 await a.mouse.click(126,163);
 await a.waitForFunction(()=>window.fatalLab.room.length===8);
 const code=await a.evaluate(()=>window.fatalLab.room);
 await b.mouse.click(330,163);await b.keyboard.type(code);await b.mouse.click(432,163);
 await b.waitForFunction(()=>window.fatalLab.room.length===8);
 await a.mouse.click(720,163);await b.mouse.click(720,163);
 await Promise.all([a.waitForFunction(()=>window.fatalLab.running,null,{timeout:35000}),b.waitForFunction(()=>window.fatalLab.running,null,{timeout:35000})]);
 const x=await a.evaluate(()=>window.fatalLab.x);
 await a.keyboard.down('KeyD');
 await a.waitForFunction(start=>window.fatalLab.x>start+450,x);
 await a.keyboard.up('KeyD');
 await a.keyboard.down('KeyJ');
 await Promise.all([a.waitForFunction(()=>window.fatalLab.health[1]===92),b.waitForFunction(()=>window.fatalLab.health[1]===92)]);
 await a.keyboard.up('KeyJ');
 await a.waitForFunction(()=>window.fatalLab.confirmed>120);
 const states=await Promise.all([a.evaluate(()=>window.fatalLab),b.evaluate(()=>window.fatalLab)]);
 assert(states.every(s=>s.running && s.desyncs===0));
 assert(states.every(s=>s.iceGatheringState==='complete' && s.iceCompleteLocal && s.iceCompleteRemote));
 assert(states.every(s=>s.browser.config.iceTransportPolicy==='all' && s.browser.iceConnectionState==='connected' && s.browser.connectionState==='connected'));
 assert(states.every(s=>s.browser.events.some(event=>event.startsWith('onicecandidate=')) && s.browser.events.some(event=>event==='onicecandidate-end=complete')));
 assert.equal(errors.length,0,errors.join('\n'));
 console.log('PASS two Chromium contexts, Godot WebRTC movement and melee damage',states);
 await a.screenshot({path:'build/lab-connected.png'});
 await b.close();await a.waitForFunction(()=>!window.fatalLab.running);
 console.log('PASS disconnect stops simulation');
} finally {await browser.close();}
