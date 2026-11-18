import test from 'node:test';
import assert from 'node:assert/strict';
import {searchScanPlaces} from '../../supabase/functions/image-recognition-context-yh/scan_places.mjs';

test('nearby search returns coordinates needed for distance', async () => {
  let mask;
  const fetcher = async (_url, options) => {
    if (_url.includes('/rpc/')) return Response.json(true);
    mask = options.headers['X-Goog-FieldMask'];
    return Response.json({places: [{
      id: 'validPlace123',
      displayName: {text: 'Museum Café'},
      formattedAddress: 'Kampar, Perak',
      addressComponents: [{shortText: 'MY', types: ['country']}],
      location: {latitude: 4.3, longitude: 101.15},
    }]});
  };
  const result = await searchScanPlaces({
    env: () => 'service-key', fetcher, supabaseUrl: 'https://example.test',
    query: 'restaurants near Kampar', key: 'google-key',
  });
  assert.match(mask, /places\.location/);
  assert.equal(result.status, 200);
  assert.deepEqual(result.places[0].location, {latitude: 4.3, longitude: 101.15});
});

test('food search biases nearby places to the device coordinates', async () => {
  let body;
  const fetcher = async (_url, options) => {
    if (_url.includes('/rpc/')) return Response.json(true);
    body = JSON.parse(options.body);
    return Response.json({places: []});
  };
  await searchScanPlaces({
    env: () => 'service-key', fetcher, supabaseUrl: 'https://example.test',
    query: 'nasi lemak restaurants', key: 'google-key',
    latitude: 3.14, longitude: 101.69,
  });
  assert.equal(body.textQuery, 'nasi lemak restaurants');
  assert.deepEqual(body.locationBias.circle.center, {
    latitude: 3.14, longitude: 101.69,
  });
});
