// Uses an administrator's normal session and the existing metered proxy.
// No service-role key, quota resets, photo downloads or category updates.
export async function refreshGooglePlaces({ token, baseUrl, publishableKey, limit = 20, full = false, onProgress = () => {} }) {
  const headers = { apikey: publishableKey, Authorization: `Bearer ${token}`, 'Content-Type': 'application/json' };
  const request = async (path, options = {}) => {
    const response = await fetch(baseUrl + path, { ...options, headers: { ...headers, ...options.headers }, signal: AbortSignal.timeout(20000) });
    if (!response.ok) throw new Error(`Request failed (${response.status}): ${(await response.text()).slice(0, 180)}`);
    return response.json();
  };
  const user = await request('/auth/v1/user');
  const profile = await request(`/rest/v1/profiles?user_id=eq.${encodeURIComponent(user.id)}&select=role`);
  if (profile[0]?.role !== 'admin') throw Error('Administrator session required');
  const rows = await request(`/rest/v1/places?select=place_id,state&name=eq.Saved%20Google%20place&order=place_id&limit=${Math.min(limit, 1000)}`);
  const report = { checkedAt: new Date().toISOString(), selected: rows.length, saved: 0, issues: [] };
  const aliases = { 'pulau pinang': 'Penang', penang: 'Penang', melaka: 'Melaka', malacca: 'Melaka', 'kuala lumpur': 'Kuala Lumpur', 'federal territory of kuala lumpur': 'Kuala Lumpur', 'wilayah persekutuan kuala lumpur': 'Kuala Lumpur' };
  for (const row of rows) {
    try {
      const data = await request('/functions/v1/google-places', { method: 'POST', body: JSON.stringify({ operation: 'details', profile: full ? 'full' : 'basic', placeId: row.place_id }) });
      const country = data.addressComponents?.find(c => c.types?.includes('country'))?.shortText;
      const region = data.addressComponents?.find(c => c.types?.includes('administrative_area_level_1'))?.longText?.toLowerCase();
      const { latitude, longitude } = data.location ?? {};
      const name = data.displayName?.text?.trim();
      if (data.id !== row.place_id || !name || country !== 'MY' || aliases[region] !== row.state ||
          !Number.isFinite(latitude) || !Number.isFinite(longitude) || latitude < 1 || latitude > 7.5 || longitude < 99 || longitude > 120) {
        report.issues.push({ place_id: row.place_id, reason: 'Identity, state or required fields could not be verified' });
        continue;
      }
      const saved = await request(`/rest/v1/places?place_id=eq.${encodeURIComponent(row.place_id)}&state=eq.${encodeURIComponent(row.state)}&select=place_id,name,latitude,longitude,google_fetched_at,operating_hours,rating,user_ratings_total`, {
        method: 'PATCH', headers: { Prefer: 'return=representation' },
        body: JSON.stringify({ name, latitude, longitude, google_attributions: data.attributions ?? [], google_fetched_at: new Date().toISOString(),
          ...(full ? { operating_hours: data.regularOpeningHours ?? null, rating: data.rating ?? null, user_ratings_total: data.userRatingCount ?? null } : {}) }),
      });
      if (saved.length !== 1 || saved[0].name !== name ||
          typeof saved[0].latitude !== 'number' || typeof saved[0].longitude !== 'number' ||
          Math.abs(saved[0].latitude - latitude) > 1e-9 || Math.abs(saved[0].longitude - longitude) > 1e-9 ||
          !saved[0].google_fetched_at) throw Error('Saved values did not match Google response');
      if (full) {
        const canonical = value => JSON.stringify(value, (_, v) => v && typeof v === 'object' && !Array.isArray(v)
          ? Object.fromEntries(Object.entries(v).sort(([a],[b]) => a.localeCompare(b))) : v);
        if (canonical(saved[0].operating_hours) !== canonical(data.regularOpeningHours ?? null) ||
            saved[0].rating !== (data.rating ?? null) || saved[0].user_ratings_total !== (data.userRatingCount ?? null)) {
          throw Error('Saved hours or ratings did not match the full response');
        }
      }
      report.saved++;
      onProgress({ saved: report.saved, selected: rows.length });
    } catch (error) {
      report.issues.push({ place_id: row.place_id, reason: error.message });
      // Authentication, quota, network and database failures stop this run.
      break;
    }
    await new Promise(resolve => setTimeout(resolve, 800));
  }
  return report;
}
