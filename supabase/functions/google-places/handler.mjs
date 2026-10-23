const fields = 'id,displayName,formattedAddress,addressComponents,location,rating,userRatingCount,regularOpeningHours,primaryTypeDisplayName,types,photos,websiteUri,nationalPhoneNumber,googleMapsUri,attributions';
const cors = {'Access-Control-Allow-Origin':'*','Access-Control-Allow-Headers':'authorization,apikey,content-type,x-client-info','Access-Control-Allow-Methods':'POST,OPTIONS','Cache-Control':'no-store'};
const json = (body,status=200) => Response.json(body,{status,headers:cors});

export function createHandler({env,fetcher=fetch}) {
  // A small per-instance burst limit supplements Supabase gateway controls.
  const requests=new Map();
  return async function handler(req) {
    if(req.method==='OPTIONS') return new Response('ok',{headers:cors});
    if(req.method!=='POST') return json({error:'POST required'},405);
    const token=req.headers.get('authorization');
    if(!token?.startsWith('Bearer ')) return json({error:'Sign in to load Google place data'},401);
    const supabaseUrl=env('SUPABASE_URL');
    let authKey=env('SUPABASE_ANON_KEY');
    if(!authKey) {try {authKey=JSON.parse(env('SUPABASE_PUBLISHABLE_KEYS')||'{}').default;} catch { /* Missing configuration below. */ }}
    if(!supabaseUrl || !authKey) return json({error:'Server authentication is not configured'},503);
    try {
      // Verify with Auth, not by decoding untrusted JWT claims.
      const auth=await fetcher(`${supabaseUrl}/auth/v1/user`,{headers:{Authorization:token,apikey:authKey},signal:AbortSignal.timeout(8000)});
      if(!auth.ok) return json({error:'Sign in again to load Google place data'},401);
      const user=await auth.json();
      if(!user.id || user.is_anonymous===true) return json({error:'A registered account is required'},403);
      const minute=Math.floor(Date.now()/60000);
      if(requests.size>2000) {for(const [id,value] of requests) if(value.minute!==minute) requests.delete(id);}
      const usage=requests.get(user.id);
      const count=usage?.minute===minute?usage.count+1:1;
      requests.set(user.id,{minute,count});
      if(count>90) return json({error:'Too many place requests. Try again shortly.'},429);
      const key=env('GOOGLE_BACKEND_API_KEY');
      if(!key) return json({error:'Google Places is not configured on the server'},503);
      let body;
      try { body=await req.json(); } catch { return json({error:'Invalid JSON request'},400); }
      if(!body || typeof body!=='object') return json({error:'Invalid request'},400);
      const headers={'X-Goog-Api-Key':key,'Content-Type':'application/json'};
      let url,options;
      if(body.operation==='matrix' || body.operation==='route') {
        const points=body.points;
        const max=body.operation==='matrix'?10:5;
        if(!Array.isArray(points) || points.length<2 || points.length>max ||
          !points.every(p=>p && typeof p.latitude==='number' && typeof p.longitude==='number' && Number.isFinite(p.latitude) && Number.isFinite(p.longitude) && p.latitude>=1 && p.latitude<=7.5 && p.longitude>=99 && p.longitude<=120)) return json({error:'Invalid Malaysian route points'},400);
        const waypoint=p=>({location:{latLng:{latitude:p.latitude,longitude:p.longitude}}});
        const travelMode=body.mode==='Walking'?'WALK':'DRIVE';
        const routeKey=env('GOOGLE_ROUTES_API_KEY') || key;
        if(body.operation==='matrix') {
          url='https://routes.googleapis.com/distanceMatrix/v2:computeRouteMatrix';
          options={method:'POST',headers:{...headers,'X-Goog-Api-Key':routeKey,'X-Goog-FieldMask':'originIndex,destinationIndex,status,condition,distanceMeters,duration'},body:JSON.stringify({origins:points.map(p=>({waypoint:waypoint(p)})),destinations:points.map(p=>({waypoint:waypoint(p)})),travelMode})};
        } else {
          url='https://routes.googleapis.com/directions/v2:computeRoutes';
          options={method:'POST',headers:{...headers,'X-Goog-Api-Key':routeKey,'X-Goog-FieldMask':'routes.duration,routes.distanceMeters,routes.polyline.encodedPolyline'},body:JSON.stringify({origin:waypoint(points[0]),destination:waypoint(points.at(-1)),intermediates:points.slice(1,-1).map(waypoint),travelMode,languageCode:'en',units:'METRIC'})};
        }
      } else if(body.operation==='search') {
        // Only administrators may spend search quota to populate the catalog.
        const profile=await fetcher(`${supabaseUrl}/rest/v1/profiles?user_id=eq.${encodeURIComponent(user.id)}&select=role`,{headers:{Authorization:token,apikey:authKey},signal:AbortSignal.timeout(8000)});
        if(!profile.ok || (await profile.json())[0]?.role!=='admin') return json({error:'Only admins can sync Google places. Browse the saved catalog instead.'},403);
        if(typeof body.query!=='string' || !body.query.trim() || body.query.length>200) return json({error:'Invalid search query'},400);
        const pageSize=Math.floor(Math.max(1,Math.min(20,Number(body.pageSize)||8)));
        url='https://places.googleapis.com/v1/places:searchText';
        const searchFields=fields.split(',').filter(f=>f!=='photos');
        options={method:'POST',headers:{...headers,'X-Goog-FieldMask':searchFields.map(f=>`places.${f}`).join(',')+',nextPageToken'},
          body:JSON.stringify({textQuery:body.query,languageCode:'en',regionCode:'MY',pageSize,
            ...(typeof body.pageToken==='string' && body.pageToken.length<2048?{pageToken:body.pageToken}:{})})};
      } else if(body.operation==='details') {
        if(typeof body.placeId!=='string' || !/^[A-Za-z0-9_-]{5,255}$/.test(body.placeId)) return json({error:'Invalid Google place ID'},400);
        url=`https://places.googleapis.com/v1/places/${encodeURIComponent(body.placeId)}?languageCode=en`;
        options={headers:{...headers,'X-Goog-FieldMask':fields}};
      } else if(body.operation==='photo') {
        // Only Google-provided photo resource paths are accepted; arbitrary URLs cannot be proxied.
        if(typeof body.photoName!=='string' || !/^places\/[A-Za-z0-9_-]{5,255}\/photos\/[A-Za-z0-9_-]{1,4096}$/.test(body.photoName)) return json({error:'Invalid photo resource'},400);
        const width=Math.floor(Math.max(100,Math.min(1600,Number(body.width)||800)));
        url=`https://places.googleapis.com/v1/${body.photoName}/media?maxWidthPx=${width}&skipHttpRedirect=true`;
        options={headers};
      } else return json({error:'Unknown place operation'},400);
      const upstream=await fetcher(url,{...options,signal:AbortSignal.timeout(12000)});
      if(!upstream.ok) return json({error:body.operation==='photo'?'Photo unavailable; refresh place details':(['matrix','route'].includes(body.operation)?'Google Routes unavailable; showing labelled estimates':'Google Places request failed'),upstreamStatus:upstream.status},body.operation==='photo' && upstream.status===400?410:502);
      if(body.operation==='photo') {
        // Retrieve the signed image URL first. Never forward the Google API key
        // across a redirect to the image host, or expose the URL to the client.
        const media=await upstream.json();
        let uri;
        try {uri=new URL(media.photoUri);} catch {return json({error:'Photo unavailable'},502);}
        if(uri.protocol!=='https:' || uri.username || uri.password ||
          !['googleusercontent.com','ggpht.com'].some(domain=>uri.hostname===domain || uri.hostname.endsWith(`.${domain}`))) {
          return json({error:'Unexpected photo host'},502);
        }
        const image=await fetcher(uri.href,{redirect:'error',signal:AbortSignal.timeout(12000)});
        const type=image.headers.get('content-type')||'';
        if(!image.ok) return json({error:'Photo unavailable'},502);
        if(!type.startsWith('image/')) return json({error:'Photo unavailable'},502);
        return new Response(image.body,{headers:{...cors,'Content-Type':type}});
      }
      return json(await upstream.json());
    } catch {return json({error:'Place service temporarily unavailable'},502);}
  };
}
