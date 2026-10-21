# Google API migration check — 19 October 2026 (Malaysia)

Follow-up: the fixes and current platform limitations are documented in [google_places_data_flow.md](../architecture/google_places_data_flow.md). The findings below are the original pre-fix audit.

Original result: Google Places is operational with the default key configured in the local source, but the migration is incomplete. This was an audit: no application code, database data, secrets, or cloud API settings were changed.

## Verified

- Flutter analyzer: no issues.
- Flutter tests: 78 passed.
- Edge Function Node tests: 8 passed.
- One live Places detail request: HTTP 200, actual name, coordinates, rating, hours and photo references.
- One live Text Search: HTTP 200, one result with address components.
- One live photo-media metadata request: HTTP 200 with a photo URI. This did not verify app image rendering or download the image.
- Google Routes matrix: HTTP 403. An additional one-element diagnostic request confirmed SERVICE_DISABLED for Routes API, project 127705868516.
- Hosted google-places function is ACTIVE, version 3. Unauthenticated request correctly returns HTTP 401 before Google is called. A registered user's full Edge Function request was not tested.
- Current database: 983 places; no placeholder names and no zero coordinates. This differs from the earlier repair snapshot and reflects the database at audit time.

There were five Google requests: one detail, one search, one photo-media metadata and two rejected one-element Routes requests. No full import or database repair was run. Actual billing/allowance and Google Cloud key restrictions were not inspected.

## Findings, in priority order

1. **Routes API disabled.** Google reports SERVICE_DISABLED. `lib/features/itinerary/services/travel_matrix_service.dart` returns an empty matrix on HTTP errors, so the scheduler uses estimates. Enable Routes API in the same project, verify the key allows it, then retest one element. Enabling this does not migrate the Explore route renderer from OpenRouteService.

2. **Keys in stored photo URLs and hidden images.** `lib/features/admin/screens/admin_places_screen.dart` constructs Google media URLs with a key and sends them to `AdminPlacesRepository.importRow`, which now includes photo_url. A count-only query found 972 rows containing a key query parameter. The database's places_read policy permits public SELECT; key-bearing URLs should not be exposed through it. The same screen rejects these URLs when rendering thumbnails, so saved photos are not displayed. Stop saving key-bearing URLs, use the authenticated photo service, and review existing URLs/key restrictions. No stored URL or key value was printed during this audit.

3. **Automatic calls conflict with the requested manual-sync flow.** `fetchPlacesWithDatabaseCache` directly calls live search and never reads the database. Each itinerary generation can start two searches. Explore loads live Google Places during initialization and location changes. The IndexedStack initializes Explore even when another tab is visible. This can spend quota without pressing admin Sync. A 20-by-20 scheduling matrix can additionally request up to 400 route elements when Routes is enabled. Restoring database-first selection needs an explicit content-retention design; Google does not give all Places fields the unlimited storage exception granted to IDs.

4. **Map and route provider migration incomplete.** `lib/features/navigation/screens/map_screen.dart` still uses FlutterMap with OpenStreetMap tiles. `ApiDemoPage` uses PlacesService (now Google) plus OpenRouteService (still the old provider). If ORS is not configured, routes are straight-line estimates. Google Places results displayed on a map require a Google map under the documented Places policy; changing the API key does not change the map widget.

5. **Direct fallback bypasses the authenticated server path.** GooglePlacesService now calls Google directly when logged out or when the Edge Function returns any error, including authentication and throttling errors. This can hide server configuration failures and bypass the endpoint's authentication/rate limit. The direct photo branch puts the key in a URL and does not translate Google's expired-photo HTTP 400 into the 410 status expected by the retry code. PlacesService and the API retrieval screen also call Google directly. Use a consistent authenticated server path and platform-appropriate restricted keys; do not interpret a successful desktop request as proof the key restrictions are correct for Android or web.

6. **Android release networking needs correction/verification.** The main Android manifest has no INTERNET permission. Only debug/profile source manifests declare it, and only debug merged artifacts currently exist. Add the permission in the main manifest as Flutter documents and verify a release build; this audit did not build a release APK or prove the final release merged manifest.

## First user action

Enable Routes API: https://console.developers.google.com/apis/api/routes.googleapis.com/overview?project=127705868516

The other findings require code/configuration fixes. Passing unit tests does not establish that the full migration is complete.

## References

- Google API security: https://developers.google.com/maps/api-security-best-practices
- Google Places policies: https://developers.google.com/maps/documentation/places/web-service/policies
- Routes setup: https://developers.google.com/maps/documentation/routes/get-api-key
- Flutter Android networking: https://docs.flutter.dev/data-and-backend/networking
