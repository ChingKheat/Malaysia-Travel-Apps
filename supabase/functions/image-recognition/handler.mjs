const maxImageBytes = 4 * 1024 * 1024;
const maxBodyBytes = Math.ceil(maxImageBytes / 3) * 4 + 1024;
const oversized = Symbol('oversized');
const headers = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization,apikey,content-type,x-client-info',
  'Access-Control-Allow-Methods': 'POST,OPTIONS',
  'Cache-Control': 'no-store',
};
const json = (body, status = 200) => Response.json(body, {status, headers});

// Bound streamed requests as well as requests with a Content-Length header.
async function readBody(req) {
  if (Number(req.headers.get('content-length')) > maxBodyBytes) return oversized;
  const reader = req.body?.getReader();
  if (!reader) throw new Error('Empty request');
  const chunks = [];
  let length = 0;
  try {
    while (true) {
      const {done, value} = await reader.read();
      if (done) break;
      length += value.byteLength;
      if (length > maxBodyBytes) {
        await reader.cancel();
        return oversized;
      }
      chunks.push(value);
    }
  } finally {
    reader.releaseLock();
  }
  const bytes = new Uint8Array(length);
  let offset = 0;
  for (const chunk of chunks) { bytes.set(chunk, offset); offset += chunk.byteLength; }
  return JSON.parse(new TextDecoder().decode(bytes));
}

function validImage(image) {
  if (typeof image !== 'string' || !image.length || image.length % 4 !== 0 ||
      !/^[A-Za-z0-9+/]+={0,2}$/.test(image)) return false;
  const prefix = atob(image.slice(0, 16));
  return prefix.startsWith('\xff\xd8\xff') ||
    prefix.startsWith('\x89PNG\r\n\x1a\n') ||
    (prefix.startsWith('RIFF') && prefix.slice(8, 12) === 'WEBP');
}

function detections(items) {
  return (Array.isArray(items) ? items : []).slice(0, 10).flatMap(item => {
    if (typeof item.description !== 'string' || !item.description.trim() ||
        !Number.isFinite(item.score)) return [];
    return [{name: item.description.slice(0, 200), score: Math.max(0, Math.min(1, item.score))}];
  });
}

export function createHandler({env, fetcher = fetch, now = Date.now}) {
  const usage = new Map();
  return async function handler(req) {
    if (req.method === 'OPTIONS') return new Response('ok', {headers});
    if (req.method !== 'POST') return json({error: 'POST required'}, 405);
    const authorization = req.headers.get('authorization');
    if (!authorization?.startsWith('Bearer ') || !authorization.slice(7).trim()) {
      return json({error: 'Sign in to recognize or translate'}, 401);
    }
    const supabaseUrl = env('SUPABASE_URL');
    let authKey = env('SUPABASE_ANON_KEY');
    if (!authKey) {
      try { authKey = JSON.parse(env('SUPABASE_PUBLISHABLE_KEYS') || '{}').default; } catch { /* Configuration checked below. */ }
    }
    if (!supabaseUrl || !authKey) return json({error: 'Authentication is unavailable'}, 503);
    try {
      // Verify with Auth; never trust a decoded JWT or user-editable metadata.
      const auth = await fetcher(`${supabaseUrl}/auth/v1/user`, {
        headers: {Authorization: authorization, apikey: authKey},
        signal: AbortSignal.timeout(8000),
      });
      if (!auth.ok) return json({error: 'Sign in again'}, 401);
      const user = await auth.json();
      if (!user.id || user.is_anonymous === true) return json({error: 'An online registered account is required'}, 403);

      let body;
      try { body = await readBody(req); } catch { return json({error: 'Invalid JSON request'}, 400); }
      if (body === oversized) return json({error: 'Choose an image smaller than 4 MB'}, 413);
      if (!body || typeof body !== 'object' || Array.isArray(body)) return json({error: 'Invalid request'}, 400);
      const operation = body.operation ?? 'recognize';
      let url, payload;
      if (operation === 'recognize') {
        const image = body.image;
        if (typeof image === 'string') {
          const size = image.length / 4 * 3 - (image.endsWith('==') ? 2 : image.endsWith('=') ? 1 : 0);
          if (size > maxImageBytes) return json({error: 'Choose an image smaller than 4 MB'}, 413);
        }
        if (!validImage(image)) return json({error: 'Choose a JPEG, PNG or WebP photo'}, 400);
        url = 'https://vision.googleapis.com/v1/images:annotate';
        payload = {requests: [{image: {content: image}, features: [
          {type: 'LANDMARK_DETECTION', maxResults: 5},
          {type: 'LABEL_DETECTION', maxResults: 10},
        ]}]};
      } else if (operation === 'translate') {
        const {texts, target} = body;
        if (!['en', 'ms', 'zh-CN'].includes(target) || !Array.isArray(texts) ||
            texts.length < 1 || texts.length > 12 ||
            texts.some(text => typeof text !== 'string' || !text.trim() || text.length > 3000) ||
            texts.reduce((size, text) => size + text.length, 0) > 6000) {
          return json({error: 'Invalid translation request'}, 400);
        }
        url = 'https://translation.googleapis.com/language/translate/v2';
        payload = {q: texts, source: 'en', target, format: 'text'};
      } else return json({error: 'Unsupported operation'}, 400);

      const key = env('GOOGLE_PLACES_API_KEY');
      if (!key) return json({error: 'Recognition and translation are not configured'}, 503);
      const minute = Math.floor(now() / 60000);
      for (const [id, entry] of usage) if (entry.minute !== minute) usage.delete(id);
      const count = (usage.get(user.id)?.count ?? 0) + 1;
      if (count > 10 || (!usage.has(user.id) && usage.size >= 10000)) return json({error: 'Too many requests. Try again in a minute'}, 429);
      usage.set(user.id, {minute, count});

      const upstream = await fetcher(url, {
        method: 'POST',
        headers: {'Content-Type': 'application/json', 'X-Goog-Api-Key': key},
        body: JSON.stringify(payload),
        signal: AbortSignal.timeout(20000),
        redirect: 'error',
      });
      // Never return Google's response body on failure; it may contain credentials.
      if (!upstream.ok) return json({error: 'Google service is temporarily unavailable'}, upstream.status === 429 ? 429 : 502);
      const data = await upstream.json();
      if (operation === 'translate') {
        const translations = data.data?.translations;
        if (!Array.isArray(translations) || translations.length !== body.texts.length ||
            translations.some(item => typeof item.translatedText !== 'string')) return json({error: 'Translation is unavailable'}, 502);
        return json({translations: translations.map(item => item.translatedText), target: body.target});
      }
      const result = data.responses?.[0];
      if (!result || result.error) return json({error: 'This image could not be analyzed'}, result?.error?.code === 3 ? 400 : 502);
      return json({landmarks: detections(result.landmarkAnnotations), labels: detections(result.labelAnnotations)});
    } catch {
      return json({error: 'Recognition or translation is temporarily unavailable'}, 503);
    }
  };
}
