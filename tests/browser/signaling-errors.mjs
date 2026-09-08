import {chromium} from '@playwright/test';
import assert from 'node:assert/strict';
const browser=await chromium.launch({headless:true,args:['--no-sandbox','--enable-webgl','--use-gl=angle','--use-angle=swiftshader']});
try {
 for(const mode of ['silent','closed']) {
  const page=await browser.newPage({viewport:{width:1120,height:700}});
  await page.routeWebSocket('**/signaling',ws=> {
   ws.onMessage(()=>{if(mode==='closed') ws.close({code:1011,reason:'test unavailable'});});
  });
  await page.goto('http://127.0.0.1:8000');
  await page.waitForFunction(()=>window.fatalLab,null,{timeout:60000});
  await page.mouse.click(126,163);
  const expected=mode==='silent'?'la lobby non risponde':'codice 1011';
  await page.waitForFunction(value=>window.fatalLab.status.includes(value),expected,{timeout:20000});
  assert.equal(await page.evaluate(()=>window.fatalLab.running),false);
  console.log('PASS Godot signaling error:',await page.evaluate(()=>window.fatalLab.status));
  await page.close();
 }
} finally {await browser.close();}
