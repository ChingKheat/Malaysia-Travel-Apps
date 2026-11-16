// Use the same quota reservation and field tier as the existing Places proxy.
export async function searchScanPlaces({env, fetcher, supabaseUrl, query, key}) {
  const serviceKey = env('SUPABASE_SERVICE_ROLE_KEY');
  if (!serviceKey) return {status: 503, error: 'Place lookup unavailable'};
  const reservation = await fetcher(`${supabaseUrl}/rest/v1/rpc/reserve_google_api_usage`, {
    method: 'POST',
    headers: {Authorization: `Bearer ${serviceKey}`, apikey: serviceKey, 'Content-Type': 'application/json'},
    body: JSON.stringify({p_sku: 'text_search_pro', p_units: 1}),
    signal: AbortSignal.timeout(8000),
    redirect: 'error',
  });
  if (!reservation.ok) return {status: 503, error: 'Place lookup unavailable'};
  if (await reservation.json() !== true) return {status: 429, error: 'Place lookup allowance unavailable'};

  const response = await fetcher('https://places.googleapis.com/v1/places:searchText', {
    method: 'POST',
    headers: {
      'Content-Type': 'application/json',
      'X-Goog-Api-Key': key,
      'X-Goog-FieldMask': 'places.id,places.displayName,places.formattedAddress,places.addressComponents,places.primaryTypeDisplayName,places.attributions',
    },
    body: JSON.stringify({textQuery: `${query}, Malaysia`, regionCode: 'MY', languageCode: 'en', pageSize: 5}),
    signal: AbortSignal.timeout(12000),
    redirect: 'error',
  });
  if (!response.ok) return {status: 502, error: 'Place lookup unavailable'};
  const {places} = await response.json();
  return {status: 200, places: (Array.isArray(places) ? places : []).slice(0, 5).flatMap(place => {
    if (!place || !/^[A-Za-z0-9_-]{5,255}$/.test(place.id ?? '') ||
        !place.displayName?.text || !Array.isArray(place.addressComponents) ||
        !place.addressComponents.some(component =>
          component?.shortText === 'MY' && Array.isArray(component.types) &&
          component.types.includes('country'))) return [];
    return [{
      id: place.id,
      displayName: place.displayName,
      formattedAddress: place.formattedAddress,
      primaryTypeDisplayName: place.primaryTypeDisplayName,
      attributions: place.attributions,
    }];
  })};
}
