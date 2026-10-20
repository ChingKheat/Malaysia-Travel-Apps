// One-off repair helper. Reads IDs from a JSON file and writes results to another.
// No search calls, photo downloads, automatic retries, or database writes.
// Keep output under ignored build/; it contains Google Places content.
import fs from 'node:fs';
const [input, output] = process.argv.slice(2);
if (!input || !output) throw new Error('Usage: node tool/fetch_place_repairs.mjs input.json output.json');
const ids = JSON.parse(fs.readFileSync(input, 'utf8').replace(/^\uFEFF/, ''));
if (!Array.isArray(ids) || !ids.every(id => typeof id === 'string' && /^[A-Za-z0-9_-]{5,255}$/.test(id))) throw new Error('Invalid ID list');
// Use an existing local development key without logging it. Production app calls
// continue to use the authenticated Edge Function and its server secret.
const key = process.env.GOOGLE_PLACES_API_KEY || fs.readFileSync('lib/core/api_keys.dart', 'utf8').match(/AIza[A-Za-z0-9_-]+/)?.[0];
if (!key) throw new Error('No local Google Places key available');
const fields = 'id,displayName,addressComponents,location,rating,userRatingCount,regularOpeningHours,primaryTypeDisplayName';
const results = [];
const rawResults = [];
for (const id of [...new Set(ids)]) {
  const response = await fetch(`https://places.googleapis.com/v1/places/${encodeURIComponent(id)}?languageCode=en`, {
    headers: {'X-Goog-Api-Key':key, 'X-Goog-FieldMask':fields}, signal:AbortSignal.timeout(15000),
  });
  if (!response.ok) {
    fs.writeFileSync(output, JSON.stringify(results));
    console.log(JSON.stringify({completed:results.length, stoppedAt:id, status:response.status}));
    process.exitCode = 1;
    break;
  }
  const p = await response.json();
  rawResults.push(p);
  fs.writeFileSync(output + '.raw.json', JSON.stringify(rawResults));
  const lat = p.location?.latitude, lng = p.location?.longitude;
  if (p.id !== id || !p.displayName?.text || !Number.isFinite(lat) || !Number.isFinite(lng) || lat < 1 || lat > 7.5 || lng < 99 || lng > 120) {
    console.log(JSON.stringify({skipped:id, reason:'Incomplete or outside Malaysia'}));
    continue;
  }
  const components = p.addressComponents ?? [];
  const country = components.find(c => c.types?.includes('country'))?.shortText;
  const region = components.find(c => c.types?.includes('administrative_area_level_1'))?.longText;
  const aliases = {'Wilayah Persekutuan Kuala Lumpur':'Kuala Lumpur','Federal Territory of Kuala Lumpur':'Kuala Lumpur','Pulau Pinang':'Penang','Malacca':'Melaka','Wilayah Persekutuan Putrajaya':'Putrajaya','Wilayah Persekutuan Labuan':'Labuan'};
  const state = aliases[region] ?? region?.replace(/ Darul.*$/i, '');
  const states = ['Kuala Lumpur','Selangor','Penang','Melaka','Johor','Perak','Pahang','Sabah','Sarawak','Kedah','Kelantan','Terengganu','Negeri Sembilan','Perlis','Putrajaya','Labuan'];
  if (country !== 'MY' || !states.includes(state)) { console.log(JSON.stringify({skipped:id,reason:'Unverified state'})); continue; }
  results.push({state,place_id:id,name:p.displayName.text,category:p.primaryTypeDisplayName?.text ?? 'Category unavailable',latitude:lat,longitude:lng,rating:p.rating ?? null,user_ratings_total:p.userRatingCount ?? null,operating_hours:p.regularOpeningHours ?? null});
  fs.writeFileSync(output, JSON.stringify(results));
  if (results.length % 25 === 0) console.log(JSON.stringify({completed:results.length,total:ids.length}));
}
console.log(JSON.stringify({completed:results.length,total:ids.length}));
