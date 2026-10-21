import test from 'node:test';
import assert from 'node:assert/strict';
import { createHandler } from '../../supabase/functions/google-places/handler.mjs';

const config = {SUPABASE_URL:'https://example.supabase.co', SUPABASE_ANON_KEY:'public-test-key', GOOGLE_PLACES_API_KEY:'private-server-test-key'};
const request = (body, auth='Bearer registered-session') => new Request('https://app.test/google-places', {
  method:'POST',headers:{'content-type':'application/json',...(auth?{authorization:auth}:{})}, body:JSON.stringify(body),
});
function setup(responder, overrides={}) {
  const calls=[];
  const handler=createHandler({env:name=>({...config,...overrides})[name],fetcher:async(url,options={})=>{
    calls.push({url,options});
    if(url.endsWith('/auth/v1/user')) return Response.json({id:'registered-user',is_anonymous:false});
    if(url.includes('/rest/v1/profiles?')) return Response.json([{role:'admin'}]);
    return responder(url,options);
  }});
  return {handler,calls};
}
test('Rejects missing, invalid and anonymous authentication before Google is called', async()=>{
  const {handler,calls}=setup(()=>{throw Error('Google must not be called');});
  assert.equal((await handler(request({operation:'details',placeId:'ChIJ123'},null))).status,401);
  assert.equal(calls.length,0);
  const invalid=createHandler({env:n=>config[n],fetcher:async()=>new Response('',{status:401})});
  assert.equal((await invalid(request({operation:'search',query:'KL'}))).status,401);
  const anonymous=createHandler({env:n=>config[n],fetcher:async()=>Response.json({id:'guest',is_anonymous:true})});
  assert.equal((await anonymous(request({operation:'search',query:'KL'}))).status,403);
});
test('Missing server key gives a clear error and never calls Google',async()=>{
  const {handler,calls}=setup(()=>{throw Error('unexpected');},{GOOGLE_PLACES_API_KEY:undefined});
  const result=await handler(request({operation:'search',query:'KL'}));
  assert.equal(result.status,503);assert.equal(calls.length,1);
});
test('Search uses fixed fields and server headers; preserves real values and pagination',async()=>{
  const {handler,calls}=setup(()=>Response.json({places:[{id:'ChIJ123',rating:4.2,userRatingCount:0}],nextPageToken:'page2'}));
  const result=await handler(request({operation:'search',query:'Museums in Kuala Lumpur',pageSize:100,fieldMask:'*'}));
  const google=calls[2];
  assert.equal(JSON.parse(google.options.body).pageSize,20);
  assert.equal(google.options.headers['X-Goog-Api-Key'],config.GOOGLE_PLACES_API_KEY);
  assert.ok(google.options.headers['X-Goog-FieldMask'].includes('places.regularOpeningHours'));
  assert.ok(google.options.headers['X-Goog-FieldMask'].includes('places.addressComponents'));
  assert.ok(!google.url.includes(config.GOOGLE_PLACES_API_KEY));
  assert.equal(result.headers.get('cache-control'),'no-store');
  const data=await result.json();assert.equal(data.places[0].rating,4.2);assert.equal(data.places[0].userRatingCount,0);
  assert.equal(data.nextPageToken,'page2');
});
test('Validates place IDs, resource paths, operations and JSON',async()=>{
  const {handler,calls}=setup(()=>{throw Error('unexpected');});
  for(const body of [null,{operation:'other'},{operation:'details',placeId:'../../secret'},
    {operation:'photo',photoName:'https://evil.test/image'}, {operation:'search',query:''}]) {
    assert.equal((await handler(request(body))).status,400);
  }
  assert.ok(calls.every(c=>c.url.endsWith('/auth/v1/user') || c.url.includes('/rest/v1/profiles?')));
  const bad = new Request('https://app.test',{method:'POST',headers:{authorization:'Bearer real-session'},body:'bad json'});
  assert.equal((await handler(bad)).status,400);
});
test('Photo fetch never forwards API key to the image host and returns only bytes',async()=>{
  const {handler,calls}=setup((url,options)=> {
    if(url.startsWith('https://places.googleapis.com/')) {
      assert.ok(url.includes('skipHttpRedirect=true'));
      return Response.json({photoUri:'https://lh3.googleusercontent.com/image'});
    }
    assert.equal(options.headers,undefined);assert.equal(options.redirect,'error');
    return new Response(new Uint8Array([1,2,3]),{headers:{'content-type':'image/jpeg'}});
  });
  const result=await handler(request({operation:'photo',photoName:'places/ChIJ123/photos/ABC123'}));
  assert.equal(result.status,200);assert.deepEqual([...new Uint8Array(await result.arrayBuffer())],[1,2,3]);
  assert.equal(calls.length,3);assert.equal(result.headers.get('cache-control'),'no-store');
});
test('Rejects unexpected photo destinations and maps expired references to 410',async()=>{
  for(const photoUri of ['http://lh3.googleusercontent.com/image','https://evil.test/image', 'https://googleusercontent.com.evil.test/image']) {
    const {handler,calls}=setup(()=>Response.json({photoUri}));
    assert.equal((await handler(request({operation:'photo',photoName:'places/ChIJ123/photos/ABC123'}))).status,502);
    assert.equal(calls.length,2);
  }
  const {handler}=setup(()=>new Response('expired',{status:400}));
  assert.equal((await handler(request({operation:'photo',photoName:'places/ChIJ123/photos/ABC123'}))).status,410);
});
test('Upstream errors do not disclose Google response bodies or secrets',async()=>{
  const {handler}=setup(()=>new Response(config.GOOGLE_PLACES_API_KEY,{status:403}));
  const result=await handler(request({operation:'details',placeId:'ChIJ123'}));
  assert.equal(result.status,502);assert.ok(!(await result.text()).includes(config.GOOGLE_PLACES_API_KEY));
});
test('Rate limit bounds repeated authenticated calls per instance',async()=>{
  const {handler}=setup(()=>Response.json({places:[]}));
  for(let i=0;i<90;i++) assert.equal((await handler(request({operation:'search',query:'KL'}))).status,200);
  assert.equal((await handler(request({operation:'search',query:'KL'}))).status,429);
});
