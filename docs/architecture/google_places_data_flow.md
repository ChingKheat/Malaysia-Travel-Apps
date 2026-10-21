# Admin-synced places and Google services

Updated 19 October 2026 (Malaysia).

## Normal app flow

`PlaceCatalogService` reads admin-synced Supabase places and maintains a persistent,
project-scoped local copy. Explore, the Saved Places Inspector, itinerary generation
and saved-day hydration use this catalog. They do not search Google. Empty or
unreachable catalogs use existing curated local data where available; absent states
never silently receive Kuala Lumpur's catalog. State caches can also hydrate saved
itineraries offline. Source names, coordinates, ratings and hours are preserved;
missing ratings remain unknown. Catalog reads exclude all stored photo URLs.

Admin **Fetch & Sync** is the Google Text Search entry point. The authenticated
`google-places` Edge Function checks the verified user's protected profile role;
only admins can search. Regular users can request live details, photos and routes.
No failed/unauthorized request falls back to a client-side Google key. Google
values returned during import are saved; country/state checks reject results
outside the selected state. Names and coordinates are validated before writing.
Existing importer update behavior is retained; no full import was run during
this migration fix. The last-success sync notice retains its original behavior.

Search requests omit photos and editorial summaries, reducing unnecessary fields.
Unknown fields stay unknown. Indoor classification, ticket budgets and visit times
remain app estimates and are not verified Google facts.

## Photos

No key-bearing media URLs are saved by future imports. Key parameters were removed
from 972 existing database photo URLs; place IDs and other place data were retained.
Verification found zero remaining key-bearing photo URLs across 983 rows.

Opening **details & photos** retrieves current photo references and author
attributions, then authenticated image bytes through the Edge Function. No image
or reference is persisted by this photo flow. Google photo HTTP 400 maps to 410;
the image widget refreshes details and retries once. The admin list does not
silently download every photograph; open the details screen when photos are needed.
The list retains real saved names/rating even without live photo access.

## Routes and maps

Google Maps replaces the OpenStreetMap widget. Explore uses GoogleRouteService,
not OpenRouteService. The old class name remains only as a compatibility wrapper
that delegates to Google. Initial Explore loading uses a labelled estimate;
selecting route stops can request real Google directions.

Both route polylines and the scheduler's travel matrix use the authenticated Edge
Function. Routes has an optional `GOOGLE_ROUTES_API_KEY` server secret, otherwise
it uses the existing Google Places server key. Points, mode, field masks and
request sizes are bounded server-side. A matrix is capped at 10×10 elements;
repeated identical results are reused in memory for 10 minutes. Candidates outside
the bounded matrix use labelled estimates. Offline/unavailable routes also use
estimates. No client REST request contains a Google key.

Routes API and Maps SDK for Android were enabled in project 127705868516. With
explicit user approval, SmartTravel's API restriction now allows exactly Places
API (New), Routes API and Maps SDK for Android. A live one-element matrix returned
HTTP 200 / ROUTE_EXISTS after this update.

## Platform configuration

- Android: provide `GOOGLE_MAPS_ANDROID_API_KEY` via environment or ignored
  `android/local.properties`. Gradle injects it into the manifest. The development
  key was moved out of tracked Dart source into this ignored local file.
  INTERNET is declared in the main manifest, including release builds. SDK min 24.
- Web: copy `web/maps-config.example.js` to ignored `web/maps-config.js`; use a
  dedicated website-restricted Maps JavaScript key. The JavaScript API must be
  enabled for that key. No web map key was configured by this fix; the list remains
  usable and the map shows a clear setup message. Do not put a server key here.
- iOS: copy `ios/Flutter/MapsKeys.example.xcconfig` to ignored
  `MapsKeys.xcconfig`, set a dedicated bundle-restricted iOS SDK key, and enable
  Maps SDK for iOS. No iOS key/device/build was available on this Windows host.
- Unsupported desktop platforms show a setup message while keeping list access.

The official Google Maps Flutter plugin is pinned to 2.18.1 for Dart 3.12.2
compatibility. On this Windows host, per-command `FLUTTER_WINDOWS=false` was used
for pub/build tooling to avoid unrelated desktop symlink requirements. No global
Windows/Developer Mode settings were changed. Native plugin installation needs a
full app restart rather than hot reload; the Android emulator was rebuilt/restarted.

API restrictions are configured; application restrictions still need dedicated
platform keys before production. Do not bind the shared existing server key to
Android, which would break Edge Function calls. Use separate restricted server,
Android, web and iOS keys. No key was rotated or new credential created here.

## Validation and limits

- Flutter tests: 83 passed, including pagination and persistent offline state caches.
- Edge Function tests: 11 passed, including admin-only search, auth, photo expiry,
  redirect safety, route bounds and fixed fields.
- Android debug and release APK builds passed; release merged manifest verified
  INTERNET and non-empty Maps SDK metadata without printing key values.
- Web release build passed. Maps rendering still needs a browser key as above.
- Analyzer clean after the final refinements.
- Hosted Edge Function version 4 deployed ACTIVE, using verified Auth requests.

An attempted signed-in end-to-end check through debugger session extraction was
rejected by automatic approval review. No session was read. Live signed-in photo
rendering and a route drawn on the map remain normal device checks; automated
coverage does not establish that the server secret matches every local key.

No tables, columns, RLS policies, triggers or schema constraints were changed.
`docs/supabase_schema.sql` remains the database recovery source. Server secrets,
Edge Function deployment and platform map keys require separate setup on recovery.

## Content retention

This restores the requested manually synced catalog behavior. It does not establish
permission to store Google-derived content permanently. Place IDs have a storage
exception; do not assume the same for names, ratings, coordinates, hours or photos.
Review the applicable Google Maps terms and approved retention before production:
https://developers.google.com/maps/documentation/places/web-service/policies

No general 30-day storage allowance for all Places fields is claimed.
