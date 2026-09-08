import {chromium} from '@playwright/test';
import {spawn} from 'node:child_process';
import assert from 'node:assert/strict';
const browser=await chromium.launch({headless:true,args:['--no-sandbox','--enable-webgl','--use-gl=angle','--use-angle=swiftshader']});
let native;
try {
 const page=await browser.newPage({viewport:{width:1120,height:700}});
 await page.goto('http://127.0.0.1:8000');await page.waitForFunction(()=>window.fatalLab,null,{timeout:60000});
 await page.mouse.click(126,163);await page.waitForFunction(()=>window.fatalLab.room.length===8);
 const code=await page.evaluate(()=>window.fatalLab.room);
 native=spawn('.tools/godot',['--headless','--max-fps','60','--path','game','--script','tests/native_client.gd','--',code]);
 let output='';native.stdout.on('data',d=>output+=d);native.stderr.on('data',d=>output+=d);
 const done=new Promise(resolve=>native.on('close',code=>resolve(code)));
 await page.mouse.click(720,163);await page.waitForFunction(()=>window.fatalLab.running,null,{timeout:35000});
 await page.keyboard.down('KeyA');await page.waitForFunction(()=>window.fatalLab.x<270);await page.keyboard.up('KeyA');
 assert.equal(await done,0,output);assert.match(output,/PASS native Linux/);
 assert.equal(await page.evaluate(()=>window.fatalLab.desyncs),0);
 console.log(output);
} finally {native?.kill();await browser.close();}
