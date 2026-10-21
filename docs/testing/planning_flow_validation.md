# Planning flow implementation and verification

## Database rollout

The application now uses `public.save_itinerary(payload jsonb)` for atomic cloud
saves. Apply `docs/supabase_schema.sql` in your Supabase SQL editor before expecting
cloud synchronization to work. Until then, trips are saved locally with a pending
sync message. This change does not automatically modify a hosted database.

Run the entire current file, including `BEGIN` and `COMMIT`. Older databases may
contain duplicate `place_id` values in `indoor_places` or `outdoor_places`. Before
creating their unique indexes, recovery archives every row in each duplicate
group to `recovery.place_subtype_duplicates`, then retains the lowest-ID active
row unchanged. The archive preserves differing metadata and is inaccessible to
anonymous and authenticated app clients. A repeated run does not duplicate the
same archived snapshot. Original attractions and itineraries are not removed.
If another table references these subtype rows, migration stops for a tailored
repair rather than risking cascading deletion. Any failure rolls back the entire
schema update.

Back up an existing database first and validate in a separate test project. The
schema replaces policies on its nine application tables with ownership policies;
private trips, schedules, stops, forecasts, profiles, and chats are isolated.
Authenticated users may read explicitly public trips but cannot edit them.
Place catalog writes require an administrator; authenticated itinerary saves can
insert previously unknown place IDs through the checked save function without
overwriting existing shared places. Demo/guest users remain local-only.

Administrator roles must be assigned through trusted database administration.
Email addresses and registration metadata do not grant administrator access.
The profile foreign key is added `NOT VALID` for legacy demo rows: existing orphan
rows are retained, while new rows must reference Supabase Auth. Review/clean legacy
orphans before explicitly validating that constraint in a later migration.

## Dates and weather

Selected calendar dates are stored in preferences and each saved daily schedule.
Day counts are derived inclusively when dates exist. Legacy callers without dates
remain supported. Weather slots are matched in Malaysia time (UTC+8); a missing
date or failed request displays "Forecast unavailable" and does not trigger
weather substitutions. API responses are cached for 30 minutes per destination.

## Local persistence and synchronization

`LocalItineraryStore` maintains a JSON journal in device SharedPreferences,
partitioned by account ID. It preserves complete stop snapshots, preferences,
stable UUIDs, pending changes, and deletion tombstones. Demo accounts and guests
cannot synchronize without a matching authenticated Supabase session.

Saves are written locally before cloud requests. Synchronization retries on login,
opening saved trips, app resume, and once per minute while the shell is mounted.
The save RPC replaces a complete itinerary within one PostgreSQL transaction.
Stable IDs allow safe retries after a response is lost. Local pending changes
take precedence when merging cloud data. Successfully synced records removed
remotely are removed from the local cache on refresh.

Concurrent edits from different devices currently use last successful upload wins.
SharedPreferences is suitable for this prototype's small trip collection; larger
collections should migrate behind the store interface to a transactional local
database. Clearing app data or uninstalling removes unsynced local trips. Existing
in-memory trips from an older app session cannot be recovered after that session
has already closed.

## Scheduling

The shared scheduling engine scores feasible places by interests, travel time,
waiting time, visit duration, estimated cost, and weather suitability. It enforces
known opening intervals, daily end times, and a per-day budget (Low RM120, Medium
RM200, High RM350). The budget includes estimated visits/meals and inter-stop
transport; accommodation and travel to the first stop are excluded.

Google Routes `computeRouteMatrix` supplies directed travel times for up to 20
candidates. Enable Routes API for your configured Google key to use live results.
Missing/error entries use labelled Haversine road-factor estimates (walking
4.5 km/h; driving 28 km/h with a 5-minute allowance). Cost estimates are category
allowances and RM1.20/km for driving, not verified ticket prices or taxi quotes.
See Google's API contract:
https://developers.google.com/maps/documentation/routes/compute_route_matrix

Weekly opening periods support closed days, split hours, and overnight intervals.
Unknown opening hours are explicitly unverified and require confirmation before
travel. Rain filtering only applies when a forecast is available. The same
engine validates edits; infeasible edits cannot be saved. Regeneration varies
priority tie-breaking after confirmation. It may produce the same schedule when
constraints leave no equivalent alternatives.

Attractions are never reused to fill exhausted days. An empty day explains that
no further places fit. Offline coverage depends on the curated catalog; unsupported
destinations do not silently receive Kuala Lumpur attractions.

## Automated verification

Run:

```powershell
flutter analyze
flutter test
New-Item -ItemType Directory -Force .dart_tool/sql_validation
pnpm --dir .dart_tool/sql_validation add @electric-sql/pglite@0.5.10
node tool/database/validate_schema.mjs
node tool/database/validate_schema.mjs --legacy-duplicates
```

The PostgreSQL harness runs recovery twice, checks ownership using distinct
authenticated roles/identities, attempts role escalation and cross-user writes,
checks public read-only sharing, retries the same UUID, and verifies transaction
rollback. It emulates Supabase's Auth functions and grants. PGlite has built-in
`gen_random_uuid()`; the harness omits only the optional `pgcrypto` extension
installation. It does not verify a hosted project's configuration or deployment.

Flutter tests cover calendar boundaries, interest selection, opening windows,
budget/time limits, weather, directed route durations, catalog exhaustion,
account separation, persistence through repository recreation, concurrent saves,
storage failure, and retries following a lost cloud response.

## Device acceptance check

1. Generate a trip with a future date range. Check each schedule date and weather
   status, and review any unverified-hours/travel-estimate notices.
2. Save in airplane mode. Confirm "Saved on this device". Fully close and reopen
   the app, sign into the same account if needed, and reopen the same itinerary.
3. Edit a day and restart again. Confirm the changes remain. Try an order that
   exceeds daily hours and verify saving is blocked.
4. Restore connectivity with a real Supabase login and the updated schema applied.
   Resume the app or reopen saved trips; confirm one cloud itinerary is created.
5. Delete offline, restart, reconnect, and confirm the cloud trip is removed.
6. Sign into account B. Confirm account A's private trips cannot be retrieved or
   changed, including direct requests by known itinerary/schedule/stop IDs.

Use two real accounts in your test Supabase project for the final hosted RLS test.
