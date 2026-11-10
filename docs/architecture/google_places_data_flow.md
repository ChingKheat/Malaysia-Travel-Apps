# Manual Google discovery and live details

Updated 28 October 2026 (Malaysia).

## Admin Database Hub

Fetch & Sync remains the only production Google Text Search entry point. It
requires a verified registered administrator, a selected Malaysian state or
federal territory, and at least 48 verified search units. The 16 area choices,
eight app categories, duplicate removal and repeat-sync confirmation remain.
Each query returns up to three pages of 20 results. Country/state validation
rejects mismatches. Search requests use Pro basic fields; ratings, opening hours,
photographs and phone/website fields are not requested during discovery.

The import stores place IDs, the selected state and the app category in places.
Google records have data_source=google, the explicit name Saved Google place,
zero placeholder coordinates and no rating, review count, hours or photo URL.
Database triggers enforce this even for old clients. IDs and foreign keys are
preserved. Indoor/outdoor classifications are app data and survive migration.

The admin list uses stable 20-row pages with the full database count, including
records beyond 500. It loads basic details for the displayed page only. A database
refresh never starts a Google search. Current details can consume their own SKU.

## Normal app flow and offline behaviour

PlaceCatalogService reads references and app-owned local records from Supabase.
Its project-scoped persistent v2 cache stores only sanitized Google references.
Legacy v1 copies are sanitized and removed on access. Explore starts loading when
its tab becomes active and requests basic details for at most 20 saved IDs. Next
and Previous explicitly change the page. No normal screen searches Google.

Itinerary generation hydrates up to 20 saved attraction IDs and 12 meal IDs with
full details for scheduling. Day views hydrate at most 20 IDs with basic details.
Responses remain in memory. Local itinerary journals and database stop snapshots
strip provider details while retaining IDs, order, times, user notes and app cost
estimates. Offline/unverified-budget views show connection-required placeholders;
existing schedules remain usable and curated local fallbacks remain available.

## Photos and routes

Opening a detail screen requests full current details. Each photograph loads only
when its Load photo button is pressed. Photo bytes and author attributions stay
in memory; an expired photo refreshes details and retries once. The server never
returns a key-bearing photo URL. Google Maps and provider attribution accompany
live content.

Routes and route matrices use the same authenticated Edge Function. Matrices are
bounded to 10 by 10 elements and reserve each origin/destination element. Route
requests are bounded to five points. Existing short-lived in-memory reuse and
labelled offline estimates remain. No failure falls back to a client REST key.

## Verified allowances

Postgres reserves billable units atomically before every upstream request, shared
by all Edge Function instances. Separate rows cover search Pro, details Pro,
details Enterprise, photos, routes Essentials and matrix Essentials. Limits are
below the published free allowances. Baseline usage is included. Failed/time-out
requests are conservatively retained in the counter.

New budgets are disabled and unverified. Missing configuration, stale review,
missing current-month rows and exhausted limits block Google requests. Counters
do not reset on sync/restart/redeployment. New billing months need verification.
The mobile app can read an admin status but cannot approve or reserve allowance.

See maintenance/google_allowance_setup.md for trusted setup, key replacement,
external/shared-account usage, billing latency and recovery requirements.

## Configuration and recovery

Google keys stay in server secrets or dedicated platform map configuration.
GOOGLE_BACKEND_API_KEY serves Places; GOOGLE_ROUTES_API_KEY optionally overrides
Routes. Built-in SUPABASE_SERVICE_ROLE_KEY is used only by the Edge Function's
reservation request. Never expose it in Flutter. The legacy bulk seeder is
disabled; tracked fixture files now contain references only. Old keys in Git
history still require replacement and restrictions in Google Cloud.

Maps SDK/JavaScript, Vision, Translation, Weather and Gemini usage is separate
from this counter. Android, web and iOS keep their existing platform-specific map
setup; web/iOS still require their dedicated keys where not yet configured.

The complete recovery source is docs/supabase_schema.sql. It includes the three
live recognition tables, reference/snapshot sanitizers, budgets, RLS and function
grants. Edge Function deployment, server secrets and platform map keys require
separate recovery. No broad 30-day retention allowance is claimed for all Places
fields. Google IDs can be stored indefinitely; this flow keeps other details live.
