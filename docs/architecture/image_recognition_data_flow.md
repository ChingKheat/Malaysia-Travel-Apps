# Photo recognition and result translation

## Using the feature

Sign in with an online registered account, open **Scan**, and take a photo or
choose one from the gallery. Scanning starts after you select the photo. JPEG,
PNG and WebP photos are accepted, with a 4 MB limit after the picker's
resizing/compression.

The Scan Page shows how to steady the camera, frame the whole landmark, and
include a readable sign. An uncertain result offers both **Retake photo** and
**Upload another photo**. Landmark results show catalogue or listing details.
The nearby section uses the landmark or detected area to find attractions and
food. If the scan gives no location, the Maps actions search around the user.

The result sheet shows matched guide information, Vision confidence when
available, and detected labels. Choose **English**, **Bahasa Melayu** or
**简体中文** under Result language to translate the displayed text. English
restores the original without an API request. Successful translations are reused
while that sheet stays open. Translation failures keep the original result.

Photo guidance, catalogue details and saved history remain available offline. Live recognition and
translation require connectivity and a registered Supabase session. A failed
recognition never creates a successful sample result or overwrites history.
History keeps the original English result and a copy of the scan photo in the
account's private app storage on the device. Clearing history or aging a scan
out of the 30-entry limit removes its saved photo. Older entries can still show
their results. Landmark Story reuses the saved photo as its header. The app
forwards images to Google for recognition and stores no photo in Supabase.

## Keys and backend

Android map rendering continues to use `GOOGLE_MAPS_ANDROID_API_KEY` from ignored
`android/local.properties` or the build environment. This flow does not read
that map key or put the Google backend key in Flutter.

`ImageRecognitionService` sends a user bearer token and the project's public
Supabase key to `functions/v1/image-recognition`. The function verifies the user
with Supabase Auth, rejects anonymous users, validates bounded inputs, and reads
the `GOOGLE_BACKEND_API_KEY` Edge Function secret. Its value is the
**SmartTravel-Backend** key, allowed to access
Places API (New), Routes API, Cloud Vision API and Cloud Translation API.

The context function can also use the existing server-side `GEMINI_API_KEY`
to suggest a landmark or Malaysian dish from the photo on an uncertain scan. `GEMINI_SCAN_MODEL`
can override the scan model independently of the planner. Context scans still
use Vision for OCR and web clues when Gemini is unavailable.

- Recognition: fixed `LANDMARK_DETECTION` and `LABEL_DETECTION` requests to
  `https://vision.googleapis.com/v1/images:annotate`.
- Translation: bounded plain English text, translated through Cloud Translation
  **Basic v2** at `https://translation.googleapis.com/language/translate/v2`.
- The Google key is sent in `X-Goog-Api-Key`, never in request URLs or responses.
- Only normalized names and scores are returned from Vision. Error responses
  contain app messages rather than Google's raw response bodies.
- Requests are capped at 10 per verified user per minute in each running
  function instance. This supplements, but does not replace, provider quotas;
  it is not a global persistent usage limit.
- Request bodies are bounded even when streamed without Content-Length. Only
  image bytes are accepted; clients cannot supply arbitrary URLs or features.

The handler performs its own verified Auth check before Google calls, matching
the existing `google-places` function pattern. `verify_jwt = false` in the local
function configuration does not mean the handler accepts unsigned callers.

## Accuracy

The app first checks specific Vision names against the Malaysian catalog. An
uncertain scan compares Vision candidates with OCR, web clues and the local
image index. An optional Gemini suggestion must resolve to a matching Malaysian
Google Places listing before the app presents it for user confirmation. An
optional dish suggestion can include a dish outside the bundled index. The app
confirms an agreeing local photo match or presents the dish as a candidate,
without querying Google Places for it. An
OCR area narrows the place lookup. If the photo yields only an area, the app
looks up places in that area and labels them as suggestions. If it cannot narrow
the search, it suggests taking a photo of a sign, entrance, or wider view. A
confirmed choice updates the original scan in device history. General labels
remain supporting evidence. Translation preserves the scan identity.

## Deployment, checks and recovery

On 22 October 2026, `image-recognition` version 1 was deployed ACTIVE. Validation
passed: 102 Flutter tests, 20 backend tests, clean Flutter analysis and an Android
debug APK build. Live requests with a missing or invalid user token returned
HTTP 401. A successful signed-in Vision/Translation request remains a normal
device check; no user's session token was extracted for testing.

Deploy the three files in `supabase/functions/image-recognition/` together and
restore `GOOGLE_BACKEND_API_KEY` in Edge Function secrets. The existing
`google-places` deployment is separate and must also be restored on recovery.
Deploy `image-recognition-context-yh` with its entry point, Places lookup,
Gemini helper and the shared recognition handler.
No database table, column, trigger, relationship or RLS policy is changed here;
`docs/supabase_schema.sql` therefore remains unchanged.

```powershell
flutter analyze --no-pub
flutter test --no-pub
node --test tool/checks/image_recognition_proxy_test.mjs tool/checks/google_places_proxy_test.mjs tool/checks/google_routes_proxy_test.mjs
```

Automated checks use mocked Google responses and do not establish recognition
accuracy or prove the configured key's Google permissions. To check the full
deployed flow, sign in normally, recognize a clear supported landmark, switch
the result to Malay/Chinese, then reopen its original result from History.
Switch offline and confirm that photo guidance and saved history still work. No Google
key should appear in Flutter's request URL or payload.

Official references:
- https://docs.cloud.google.com/vision/docs/detecting-landmarks
- https://docs.cloud.google.com/vision/docs/labels
- https://docs.cloud.google.com/translate/docs/reference/rest/v2/translate
- https://docs.cloud.google.com/docs/authentication/api-keys-use
- https://supabase.com/docs/guides/functions/secrets
