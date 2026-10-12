import assert from 'node:assert/strict';
import { createCleanupHandler } from '../../supabase/functions/support-retention-cleanup/cleanup_handler.ts';
let checks=0;
const token='x'.repeat(72); // synthetic; never the real scheduled token
const request=(body={token},headers={})=>new Request('https://local.test', {method:'POST',body:JSON.stringify(body),headers});
const env=name=>name==='SUPABASE_URL'?'https://synthetic.supabase.co':'synthetic-service-key';
const noFetch=async()=>{throw Error('Unexpected network request')};
async function status(handler,req,expected){const response=await handler(req);assert.equal(response.status,expected);assert.equal(response.headers.get('Cache-Control'),'no-store');checks++}
await status(createCleanupHandler({env,fetch:noFetch}),new Request('https://local.test'),405);
await status(createCleanupHandler({env,fetch:noFetch}),request({token:'wrong'}),401);
await status(createCleanupHandler({env,fetch:noFetch}),request(null),401);
await status(createCleanupHandler({env,fetch:noFetch}),request({token},{'content-length':'1025'}),413);
await status(createCleanupHandler({env,fetch:noFetch}),request({token:'x'.repeat(1100)}),413);
await status(createCleanupHandler({env:()=>undefined,fetch:noFetch}),request(),503);
await status(createCleanupHandler({env:n=>n==='SUPABASE_URL'?'http://169.254.169.254':'key',fetch:noFetch}),request(),503);
await status(createCleanupHandler({env,fetch:async()=>new Response('{}',{status:400})}),request(),401);
await status(createCleanupHandler({env,fetch:async()=>Response.json([])}),request(),200);
for (const path of ['', '../unsafe', '/root', 'https://other.test', 'a\\b', 'a\u0000b']) {
  let calls=0;
  await status(createCleanupHandler({env,fetch:async()=>{calls++;return Response.json([{storage_path:path}])}}),request(),502);
  assert.equal(calls,1);
}
await status(createCleanupHandler({env,fetch:async()=>Response.json(Array(201).fill({storage_path:'valid/file.pdf'}))}),request(),502);
let calls=[];
const handler=createCleanupHandler({env,fetch:async(url,options)=>{
  calls.push({url,options});
  assert.equal(options.redirect,'error');assert.ok(options.signal);
  if(calls.length===1)return Response.json([{storage_path:'ticket/file.pdf'},{storage_path:'ticket/file.pdf'}]);
  return new Response('{}');
}});
const result=await handler(request()); assert.equal(result.status,200);assert.deepEqual(await result.json(),{ok:true,files:1});
assert.equal(calls.length,3); assert.equal(calls[1].url,'https://synthetic.supabase.co/storage/v1/object/support-attachments');
assert.deepEqual(JSON.parse(calls[1].options.body),{prefixes:['ticket/file.pdf']});checks++;
for (const failureAt of [2,3]) {
 let count=0;await status(createCleanupHandler({env,fetch:async()=>{count++;if(count===1)return Response.json([{storage_path:'ticket/file.pdf'}]);return new Response('{}',{status:count===failureAt?500:200})}}),request(),502);
 assert.equal(count,failureAt);
}
const stream=new ReadableStream({start(){}});
await status(createCleanupHandler({env,fetch:noFetch,bodyTimeoutMs:20}),new Request('https://local.test',{method:'POST',body:stream,duplex:'half'}),408);
await status(createCleanupHandler({env,fetch:async()=>{throw Error('synthetic secret')}}),request(),500);
console.log(`${checks} isolated cleanup-handler checks passed. No live files or tokens used.`);
