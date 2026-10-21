import test from 'node:test';
import assert from 'node:assert/strict';
import {createHandler} from '../../supabase/functions/google-places/handler.mjs';
const config={SUPABASE_URL:'https://db.test',SUPABASE_ANON_KEY:'public',GOOGLE_PLACES_API_KEY:'server-only'};
const req=body=>new Request('https://app.test',{method:'POST',headers:{Authorization:'Bearer signed-in','Content-Type':'application/json'},body:JSON.stringify(body)});
const points=[{latitude:3.1,longitude:101.7},{latitude:3.2,longitude:101.8}];
function setup(role='admin') {
 const calls=[];
 const handler=createHandler({env:n=>config[n],fetcher:async(url,options)=>{
  calls.push({url,options});
  if(url.endsWith('/auth/v1/user'))return Response.json({id:'user'});
  if(url.includes('/rest/v1/profiles?'))return Response.json([{role}]);
  return Response.json([{condition:'ROUTE_EXISTS',duration:'120s'}]);
 }});
 return {handler,calls};
}
test('Only admins can search; authenticated users can request details and routes',async()=>{
 const {handler,calls}=setup('user');
 assert.equal((await handler(req({operation:'search',query:'Malaysia'}))).status,403);
 assert.equal(calls.some(c=>c.url.includes('googleapis.com')),false);
 assert.equal((await handler(req({operation:'matrix',points,mode:'Walking'}))).status,200);
});
test('Matrix validates coordinates, caps billable elements, and fixes the field mask',async()=>{
 const {handler,calls}=setup();
 for(const p of [[],[...points,...Array(9).fill(points[0])],[{latitude:0,longitude:0},points[1]],[{latitude:'3',longitude:101},points[1]]]) {
  assert.equal((await handler(req({operation:'matrix',points:p}))).status,400);
 }
 assert.equal(calls.some(c=>c.url.includes('googleapis.com')),false);
 await handler(req({operation:'matrix',points,mode:'Walking',fieldMask:'*'}));
 const call=calls.at(-1);assert.equal(JSON.parse(call.options.body).travelMode,'WALK');
 assert.equal(call.options.headers['X-Goog-Api-Key'],'server-only');
 assert.equal(call.url.includes('server-only'),false);
 assert.equal(JSON.parse(call.options.body).origins.length,2);
});
test('Compute route sends bounded ordered stops without exposing a key',async()=>{
 const {handler,calls}=setup();
 assert.equal((await handler(req({operation:'route',points:[points[0],points[1],points[0]]}))).status,200);
 const call=calls.at(-1);assert.ok(call.url.includes('directions/v2:computeRoutes'));
 const body=JSON.parse(call.options.body);assert.equal(body.intermediates.length,1);
 assert.deepEqual(body.origin.location.latLng,points[0]);
 assert.deepEqual(body.destination.location.latLng,points[0]);
});
