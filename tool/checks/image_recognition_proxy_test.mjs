import test from 'node:test';
import assert from 'node:assert/strict';
import {createHandler} from '../../supabase/functions/image-recognition/handler.mjs';
import {searchScanPlaces} from '../../supabase/functions/image-recognition-context-yh/scan_places.mjs';
import {suggestVisualLandmark} from '../../supabase/functions/image-recognition-context-yh/visual_suggestion.mjs';

const image = Buffer.from([0xff, 0xd8, 0xff, 0xe0, ...Array(12).fill(0)]).toString('base64');

test('Gemini food suggestions are routed to the food field for enabled clients', async () => {
  const {handler} = setup({
    contextOnly: true,
    visualSuggestion: suggestVisualLandmark,
    secrets: {GEMINI_API_KEY: 'scan-secret'},
    upstream(url, options) {
      if (url.includes('vision.googleapis.com')) return Response.json({responses: [{}]});
      assert.deepEqual(JSON.parse(options.body).generationConfig.responseJsonSchema.required, ['name', 'kind']);
      return Response.json({candidates: [{content: {parts: [{text: '{"name":"Satay","kind":"food"}'}]}}]});
    },
  });
  const response = await handler(request({operation: 'recognize_context', image, include_visual_suggestion: true, include_food_suggestion: true}));
  const result = await response.json();
  assert.equal(result.foodSuggestion, 'Satay');
  assert.equal(result.visualSuggestion, undefined);
});
const config = {SUPABASE_URL: 'https://db.test', SUPABASE_ANON_KEY: 'public', GOOGLE_BACKEND_API_KEY: 'server-only'};
const request = (body, token = 'valid') => new Request('https://app.test', {
  method: 'POST', headers: {...(token ? {Authorization: `Bearer ${token}`} : {}), 'Content-Type': 'application/json'},
  body: JSON.stringify(body),
});
function setup({user = {id: 'tourist'}, upstream, missingKey = false, secrets = {}, contextOnly = false, placeSearch, visualSuggestion} = {}) {
  const calls = [];
  const handler = createHandler({contextOnly, searchScanPlaces: placeSearch, suggestVisualLandmark: visualSuggestion, env: name => missingKey && name === 'GOOGLE_BACKEND_API_KEY' ? '' : {...config,...secrets}[name], fetcher: async (url, options) => {
    calls.push({url, options});
    if (url.endsWith('/auth/v1/user')) return user ? Response.json(user) : new Response('', {status: 401});
    return upstream ? upstream(url, options) : Response.json({responses: [{
      landmarkAnnotations: [{description: 'Petronas Towers', score: 0.94, locations: ['not returned']}],
      labelAnnotations: [{description: 'Tower', score: 0.91}],
    }]});
  }});
  return {handler, calls};
}

test('Context scan combines OCR and an optional visual suggestion, independently of provider failures', async () => {
  for (const [visionOK, geminiOK] of [[true, true], [false, true], [true, false]]) {
    const {handler, calls} = setup({
      contextOnly: true,
      visualSuggestion: suggestVisualLandmark,
      secrets: {GEMINI_API_KEY: 'scan-secret'},
      upstream(url, options) {
        if (url.includes('vision.googleapis.com')) {
          return visionOK ? Response.json({responses: [{fullTextAnnotation: {text: 'LANGKAWI'}}]})
            : new Response(null, {status: 502});
        }
        assert.match(url, /^https:\/\/generativelanguage\.googleapis\.com\//);
        assert.equal(options.headers['x-goog-api-key'], 'scan-secret');
        assert.deepEqual(JSON.parse(options.body).contents[0].parts,
          [{inlineData: {mimeType: 'image/jpeg', data: image}}]);
        return geminiOK ? Response.json({candidates: [{content: {parts: [{text: '{"name":"Eagle Square"}'}]}}]})
          : new Response(null, {status: 429});
      },
    });
    const body = {operation: 'recognize_context', image, include_visual_suggestion: true};
    assert.equal((await handler(request(body, ''))).status, 401);
    assert.equal(calls.length, 0);
    const result = await handler(request(body));
    assert.equal(result.status, 200);
    assert.deepEqual(await result.json(), {
      ...(visionOK && {names: [], pages: [], text: 'LANGKAWI', lines: ['LANGKAWI']}),
      ...(geminiOK && {visualSuggestion: 'Eagle Square'}),
    });
    assert.equal(calls.length, 3);
    await handler(request({...body, include_visual_suggestion: false}));
    assert.equal(calls.filter(({url}) => url.includes('generativelanguage')).length, 1);
  }
});

test('Scan place search reserves quota and returns Malaysian listings only', async () => {
  const body = {operation: 'scan_places', query: 'Kinta Tin Mining Museum'};
  const listing = (id, country) => ({
    id, displayName: {text: body.query},
    addressComponents: [{shortText: country, types: ['country']}],
  });
  const options = {
    contextOnly: true,
    placeSearch: searchScanPlaces,
    secrets: {SUPABASE_SERVICE_ROLE_KEY: 'service-role'},
  };
  const {handler, calls} = setup({...options, upstream(url, init) {
    if (url.includes('/rpc/reserve_google_api_usage')) {
      assert.deepEqual(JSON.parse(init.body), {p_sku: 'text_search_pro', p_units: 1});
      return Response.json(true);
    }
    assert.equal(url, 'https://places.googleapis.com/v1/places:searchText');
    assert.equal(JSON.parse(init.body).textQuery, 'Kinta Tin Mining Museum, Malaysia');
    assert.equal(JSON.parse(init.body).image, undefined);
    return Response.json({places: [listing('malaysiaId', 'MY'), listing('foreignId', 'SG')]});
  }});
  assert.equal((await handler(request(body, ''))).status, 401);
  assert.equal((await handler(request({...body, query: ''}))).status, 400);
  const response = await handler(request(body));
  assert.equal(response.status, 200);
  assert.deepEqual((await response.json()).places.map(place => place.id), ['malaysiaId']);
  assert.equal(calls.filter(({url}) => url.includes('places.googleapis.com')).length, 1);
  const denied = setup({...options, upstream: () => Response.json(false)});
  assert.equal((await denied.handler(request(body))).status, 429);
  assert.equal(denied.calls.length, 2);
  assert.equal((await setup().handler(request(body))).status, 400);
});

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

test('Context scan submits fixed web and text features and returns bounded clues', async () => {
  const {handler, calls} = setup({upstream: () => Response.json({responses: [{
    webDetection: {
      webEntities: [{description: 'Telaga Tujuh Waterfall', score: 3.4}],
      bestGuessLabels: [{label: 'Telaga Tujuh Waterfall'}],
      pagesWithMatchingImages: [
        {url: 'https://news.example.com.my/page?token=private', pageTitle: '<b>Telaga Tujuh Waterfall</b>, Langkawi',
          fullMatchingImages: [{url: 'https://photo.test/image.jpg'}]},
        {url: 'https://www.example.com.my/another', pageTitle: 'Langkawi Telaga Tujuh Waterfall',
          partialMatchingImages: [{url: 'https://photo.test/partial.jpg'}]},
        {url: 'https://pinterest.test/tree', pageTitle: 'Trees'},
        {url: 'file:///private', pageTitle: 'Private'},
      ],
      visuallySimilarImages: [{url: 'https://similar.test/image.jpg'}],
    },
    fullTextAnnotation: {text: 'TELAGA\nTUJUH ' + 'X'.repeat(700)},
  }]} )});
  const response = await handler(request({operation: 'recognize_context', image, features: ['FACE_DETECTION']}));
  assert.equal(response.status, 200);
  assert.equal(calls.length, 2);
  assert.deepEqual(JSON.parse(calls.at(-1).options.body).requests[0].features.map(f => f.type),
    ['WEB_DETECTION', 'TEXT_DETECTION']);
  const result = await response.json();
  assert.deepEqual(result.names, ['Telaga Tujuh Waterfall']);
  assert.deepEqual(result.pages, [
    {domain: 'example.com.my', title: 'Telaga Tujuh Waterfall , Langkawi', full: true},
    {domain: 'example.com.my', title: 'Langkawi Telaga Tujuh Waterfall', full: false},
  ]);
  assert.ok(result.text.startsWith('TELAGA TUJUH'));
  assert.equal(result.text.length, 300);
  assert.ok(!JSON.stringify(result).includes('image.jpg'));
  assert.equal((await handler(request({operation: 'recognize_context', image: 'bad'}))).status, 400);
  assert.equal(calls.length, 3);
});

test('The separate context endpoint authenticates and rejects other operations', async () => {
  const {handler, calls} = setup({contextOnly: true});
  assert.equal((await handler(request({operation: 'recognize_context', image}, ''))).status, 401);
  assert.equal((await handler(request({operation: 'recognize', image}))).status, 400);
  assert.equal((await handler(request({operation: 'translate', texts: ['Hi'], target: 'ms'}))).status, 400);
  assert.equal((await handler(request({operation: 'recognize_context', image}))).status, 200);
  assert.equal(calls.filter(call => call.url.includes('googleapis.com')).length, 1);
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
