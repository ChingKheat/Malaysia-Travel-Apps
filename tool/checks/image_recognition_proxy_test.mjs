import test from 'node:test';
import assert from 'node:assert/strict';
import {createHandler} from '../../supabase/functions/image-recognition/handler.mjs';

const image = Buffer.from([0xff, 0xd8, 0xff, 0xe0, ...Array(12).fill(0)]).toString('base64');
const config = {SUPABASE_URL: 'https://db.test', SUPABASE_ANON_KEY: 'public', GOOGLE_BACKEND_API_KEY: 'server-only'};
const request = (body, token = 'valid') => new Request('https://app.test', {
  method: 'POST', headers: {...(token ? {Authorization: `Bearer ${token}`} : {}), 'Content-Type': 'application/json'},
  body: JSON.stringify(body),
});
function setup({user = {id: 'tourist'}, upstream, missingKey = false, secrets = {}} = {}) {
  const calls = [];
  const handler = createHandler({env: name => missingKey && name === 'GOOGLE_BACKEND_API_KEY' ? '' : {...config,...secrets}[name], fetcher: async (url, options) => {
    calls.push({url, options});
    if (url.endsWith('/auth/v1/user')) return user ? Response.json(user) : new Response('', {status: 401});
    return upstream ? upstream(url, options) : Response.json({responses: [{
      landmarkAnnotations: [{description: 'Petronas Towers', score: 0.94, locations: ['not returned']}],
      labelAnnotations: [{description: 'Tower', score: 0.91}],
    }]});
  }});
  return {handler, calls};
}

test('Missing, invalid and anonymous authentication cannot reach Google', async () => {
  const {handler, calls} = setup();
  assert.equal((await handler(request({image}, ''))).status, 401);
  assert.equal(calls.length, 0);
  for (const user of [null, {id: 'guest', is_anonymous: true}, {}]) {
    const run = setup({user});
    assert.ok([401, 403].includes((await run.handler(request({image}))).status));
    assert.equal(run.calls.length, 1);
  }
});

test('Vision uses only the server secret and fixed features; responses exclude raw metadata', async () => {
  const {handler, calls} = setup();
  const response = await handler(request({image, url: 'https://evil.test', features: ['FACE_DETECTION']}));
  assert.equal(response.status, 200);
  assert.equal(response.headers.get('Cache-Control'), 'no-store');
  assert.deepEqual(await response.json(), {landmarks: [{name: 'Petronas Towers', score: 0.94}], labels: [{name: 'Tower', score: 0.91}]});
  const {url, options} = calls.at(-1);
  assert.equal(url, 'https://vision.googleapis.com/v1/images:annotate');
  assert.equal(options.headers['X-Goog-Api-Key'], 'server-only');
  assert.equal(url.includes('server-only'), false);
  assert.equal(options.redirect, 'error');
  assert.deepEqual(JSON.parse(options.body).requests[0].features.map(f => f.type), ['LANDMARK_DETECTION', 'LABEL_DETECTION']);
});

test('Vision and Translation use only the shared backend secret', async () => {
  for (const secrets of [
    {GOOGLE_BACKEND_API_KEY:'shared-backend'},
    {GOOGLE_BACKEND_API_KEY:'shared-backend',GOOGLE_PLACES_API_KEY:'legacy-key'},
  ]) {
    const {handler,calls}=setup({secrets,upstream:url=>Response.json(url.includes('vision.googleapis.com')
      ? {responses:[{}]}
      : {data:{translations:[{translatedText:'Helo'}]}})});
    assert.equal((await handler(request({image}))).status,200);
    assert.equal(calls.at(-1).options.headers['X-Goog-Api-Key'],'shared-backend');
    assert.equal((await handler(request({operation:'translate',texts:['Hello'],target:'ms'}))).status,200);
    assert.equal(calls.at(-1).options.headers['X-Goog-Api-Key'],'shared-backend');
  }
  const {handler,calls}=setup({secrets:{GOOGLE_BACKEND_API_KEY:undefined,GOOGLE_PLACES_API_KEY:'removed-secret'}});
  assert.equal((await handler(request({image}))).status,503);
  assert.equal((await handler(request({operation:'translate',texts:['Hello'],target:'ms'}))).status,503);
  assert.equal(calls.length,2);
});

test('Rejects malformed images, arbitrary URLs, unsupported operations and oversized bodies', async () => {
  for (const body of [{image: 'bad!'}, {image: ''}, {image: 'https://evil.test/a.jpg'},
    {image: Buffer.from('not an image').toString('base64')}, {operation: 'fetch', image}, [], null]) {
    const {handler, calls} = setup();
    assert.equal((await handler(request(body))).status, 400);
    assert.equal(calls.length, 1);
  }
  const {handler, calls} = setup();
  assert.equal((await handler(request({image: 'A'.repeat(6 * 1024 * 1024)}))).status, 413);
  assert.equal(calls.length, 1);
});

test('Streaming size limits also apply without Content-Length', async () => {
  const {handler, calls} = setup();
  let cancelled = false;
  const stream = new ReadableStream({pull(c) {c.enqueue(new Uint8Array(6 * 1024 * 1024));}, cancel() {cancelled = true;}});
  const req = new Request('https://app.test', {method: 'POST', headers: {Authorization: 'Bearer valid'}, body: stream, duplex: 'half'});
  assert.equal((await handler(req)).status, 413);
  assert.equal(cancelled, true);
  assert.equal(calls.length, 1);
});

test('Translation uses Basic v2 with bounded plain text and the same backend key', async () => {
  const {handler, calls} = setup({upstream: () => Response.json({data: {translations: [{translatedText: 'Menara Berkembar Petronas'}]}})});
  const response = await handler(request({operation: 'translate', texts: ['Petronas Twin Towers'], target: 'ms'}));
  assert.equal(response.status, 200);
  assert.deepEqual(await response.json(), {translations: ['Menara Berkembar Petronas'], target: 'ms'});
  const call = calls.at(-1);
  assert.equal(call.url, 'https://translation.googleapis.com/language/translate/v2');
  assert.equal(call.options.headers['X-Goog-Api-Key'], 'server-only');
  assert.deepEqual(JSON.parse(call.options.body), {q: ['Petronas Twin Towers'], source: 'en', target: 'ms', format: 'text'});
});

test('Invalid translation input cannot start billable calls', async () => {
  for (const change of [{target: 'invalid'}, {texts: []}, {texts: ['']}, {texts: [42]},
    {texts: ['x'.repeat(3001)]}, {texts: Array(13).fill('x')}, {texts: Array(3).fill('x'.repeat(2500))}]) {
    const {handler, calls} = setup();
    assert.equal((await handler(request({operation: 'translate', texts: ['hello'], target: 'ms', ...change}))).status, 400);
    assert.equal(calls.length, 1);
  }
});

test('Missing server secret, upstream errors and timeouts never leak credentials', async () => {
  const missing = setup({missingKey: true});
  assert.equal((await missing.handler(request({image}))).status, 503);
  assert.equal(missing.calls.length, 1);
  for (const upstream of [() => new Response('server-only', {status: 403}),
    () => Response.json({responses: [{error: {code: 7, message: 'server-only'}}]}),
    () => {throw Error('server-only');},
    () => Response.json({})]) {
    const {handler} = setup({upstream});
    const response = await handler(request({image}));
    assert.ok(response.status >= 500);
    assert.equal((await response.text()).includes('server-only'), false);
  }
});

test('Malformed translations and per-image errors are not treated as success', async () => {
  const {handler} = setup({upstream: () => Response.json({data: {translations: []}})});
  assert.equal((await handler(request({operation: 'translate', texts: ['hello'], target: 'ms'}))).status, 502);
  const invalid = setup({upstream: () => Response.json({responses: [{error: {code: 3}}]})});
  assert.equal((await invalid.handler(request({image}))).status, 400);
});

test('A shared per-user burst limit bounds recognition and translation calls', async () => {
  const {handler, calls} = setup();
  for (let i = 0; i < 10; i++) assert.equal((await handler(request({image}))).status, 200);
  assert.equal((await handler(request({operation: 'translate', texts: ['hello'], target: 'ms'}))).status, 429);
  assert.equal(calls.filter(c => c.url.includes('googleapis.com')).length, 10);
});
