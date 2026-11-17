# Database-first browsing (18 November 2026)

## Root cause and implementation

Previously `PlacesService.fetchPage` loaded state references, paginated them,
and called `GooglePlacesService.hydrateRows`. Each displayed Google reference
could consume a details request on a fresh load. Radius filtering happened
after paging, so a page could be empty despite nearby records later in the list.

Explore now defaults to `VerifiedCatalogService`: Supabase state/publication
filter -> independently reviewed records -> radius/search/category filter ->
deduplication -> distance and stable-ID order -> pagination. No Google service
is invoked by `PlacesService`. Filtering runs across the retrieved state, not
only currently displayed cards. State queries are indexed and retrieved in
1000-row batches; this first implementation still materializes the state's
published catalog for consistent offline filtering. Move to a geospatial RPC
if a reviewed state catalog becomes large, using the same ordering contract.

Only the new versioned cache stores independently licensed published content.
Old Google-reference caches are not promoted. A new service instance can reopen
the last good state snapshot after a connection failure, with its saved time.
A failed local cache write does not hide valid remote results. A successful
empty query displays empty results rather than silently reusing an old snapshot.
The prior nonempty snapshot remains available for a later connection failure;
offline snapshots can therefore be older than current publication decisions.

Google reference IDs and existing itinerary relationships are unchanged. Legacy
Google-backed detail pages still request full details on opening when no initial
details were supplied. Requests with identical endpoint, account token, place ID
and field profile are coalesced only while in flight; no completed Google response
is persisted. Independently sourced catalog entries do not automatically guess
a Google identity or perform live enrichment. Browsing does not invoke planner
candidate enrichment; planner/admin workflows retain their existing controls.

Detail pages no longer display a default positive rating or generate descriptions,
addresses, admission fees or visit recommendations from name/category matching.
Optional data remains unavailable until supplied or returned by a live provider.

## Data and policy boundary

The independent record's source URL, license/use basis, verification timestamp,
and publication status are mandatory. These fields are an operator attestation,
not automatic proof of truth or licensing. Review every source and every field
before publication. Ratings and image rights need their own review; the importer
does not import optional ratings/photos/hours. It is not a Google backfill tool.

Official references checked during implementation:
- https://developers.google.com/maps/documentation/places/web-service/policies
- https://cloud.google.com/maps-platform/terms/maps-service-terms
- https://developers.google.com/maps/documentation/places/web-service/place-id

Places IDs are exempt from general caching restrictions; this does not grant
unlimited storage of associated names, addresses, reviews or photographs. The
existing integration uses Places API (New) via `places.googleapis.com/v1`.
This change keeps provider sanitization, attribution, field masks, authentication,
budgets and photo proxy unchanged. It chooses independent licensed content
rather than relying on a generic Google-content retention period.

Google detail calls and Google photo calls are different operations. Independently
sourced cards have no Google photo references. Existing Google detail/photo
widgets can still request live content when explicitly entered from other flows.

## Measured remote catalog status

Read-only Kuala Lumpur inspection: 633 rows, all tagged `data_source=google`;
595 have the placeholder name `Saved Google place`. The other 38 names do not
make those Google rows eligible for independent publication. No independent
published record was established by this inspection. Global record counts,
source licenses, live signed-in device behavior, and production RLS execution
were not verified. No Google requests were used for the catalog inspection.

## Cloud work prepared, NOT executed

1. Review `docs/database/verified_catalog_migration.sql`. It adds four nullable/
   defaulted metadata columns, a publication check and a partial state/ID index.
   All existing rows remain draft. Existing policies, privileges, Google budgets
   and sanitization triggers remain in force. Recovery DDL is synchronized in
   `docs/supabase_schema.sql`. Test on a local/staging database first; no SQL
   engine was available to execute the migration during this change.
2. Obtain independently verified, storable source records. There is no ready
   production import in this change. Keep the app rollout blocked until data
   and migrations are ready; deploying the Flutter changes alone can show an
   empty/catalog-unavailable screen.
3. Prepare JSON records containing `place_id`, `name`, `state`, `category`,
   `latitude`, `longitude`, `data_source: independent`, `reviewed: true`,
   `catalog_source_url`, `catalog_license`, and ISO `catalog_verified_at`.
   Retain existing stable IDs only when the source is independently verified;
   the importer refuses Google-shaped IDs and does not rewrite Google rows.
4. Dry-run locally:
   `dart run tool/prepare_verified_catalog.dart --input reviewed.json`
5. Prepare a bounded SQL batch without connecting to Supabase:
   `dart run tool/prepare_verified_catalog.dart --input reviewed.json --output prepared.sql --batch-size 100`
   Resume using `--after <resume_after from the summary>`. Invalid records
   prevent SQL output. Repeated application upserts independent records only;
   Google/local-ID collisions are skipped by the conflict condition. Actual
   inserted/updated/skipped database counts must be measured by the operator
   executing the prepared SQL; local validation cannot establish those counts.
6. Review and explicitly authorize cloud execution separately. Verify published
   counts, record content, RLS using an ordinary user, local cache on a device,
   no details/photo calls when entering Explore, filters, and saved itineraries.

Rollback: first restore the prior Flutter build. Archive affected published rows
with `catalog_status='archived'` if needed; retain the additive columns/index and
source records for audit. Do not delete attraction rows or reset usage counters.

## Validation evidence

`test/features/places/verified_browsing_test.dart` measures zero Google requests
for browse/revisit/pagination/search with reviewed fixture data, rejects Google
references and unverified entries, checks stable pagination, proves offline
reopening from the asset-independent persisted catalog, and measures two calls
for concurrent full/full/basic detail requests (one per profile). A subsequent
full request is a new call; no permanent response cache is introduced.

Existing places tests exercise live field masks, photo refresh, authentication,
provider errors, card/details navigation, and missing values. Test fixtures use
`example.test` and are never production attraction sources.

No migrations, imports, deployments, quota changes, or paid production Google
calls were performed. A local DTD connection was discovered from the running Dart process and hot reload succeeded for smart_travel_planner. Device-level validation of actual catalog content remains unverified.

## Final checks and acceptance

| Check | Result |
|---|---|
| `flutter analyze --no-pub` | PASS, no issues |
| `flutter test --no-pub test/features/places` | PASS, 52 tests before final source-attribution addition; same tests pass within final full suite |
| `flutter test --no-pub --reporter expanded` | FAIL overall: 281 passed, 7 failed |
| Full-suite failures | Explore's Featured story expectation; home hero label expectations in en/ms/zh; planner selection expectations at 320px/2x in en/ms/zh |
| Importer dry-run with test-only JSON | PASS, 1 accepted, 0 rejected, 0 remote changes |
| Importer SQL generation with batch size 1 | PASS, prepared temporary test SQL only, 0 remote changes |
| Importer invalid input | PASS rejection, exit 1, no prepared output |
| `git diff --check` | PASS for changes (line-ending warnings only) |
| DTD hot reload | PASS, Flutter tooling returned Success for smart_travel_planner |
| Production SQL/RLS and real signed-in data display | NOT VERIFIED |

Final full-suite output is in `.dart_tool/verified_catalog_test_results.log`
(local generated log, not a production artifact). These failures relate to
current home/planner expectations; they are not classified as proven pre-existing
by an isolated baseline run. They remain unresolved and must not be reported as
a passing full suite. Four of five navigation tests pass after retaining the
home/trip header during catalog failures.

| Acceptance | Status and evidence |
|---|---|
| Database-first browse and no per-card hydration | PASS in local code/tests; NOT VERIFIED in deployed app |
| Revisit/pagination/offline Google detail calls | PASS: zero in fixture-driven request test |
| Full/full/basic concurrent details | PASS: two upstream requests, one per field profile |
| Single fresh Google detail request | PASS in existing provider/detail tests; no paid production request performed |
| Google photos separate from details | Preserved; no Google photo references attached to independent browse rows |
| Reference-only exclusion | PASS in validation and service tests |
| No fabricated catalog data | PASS: no production records or automatic conversions supplied |
| Offline usable records after service recreation | PASS in persisted-cache test |
| Honest optional values and provenance | Default rating/generated detail description removed; source/license/date shown in details |
| Saved itineraries | Persistence unchanged; four navigation checks pass, complete regression not green |
| Provider budgets/auth/attribution | Existing server safeguards unchanged |
| Schema documentation | PASS: additive migration mirrored in recovery DDL |
| Production catalog ready | BLOCKED: source review/import and approved migration still required |
| Unauthorized cloud mutations | None performed |

Field sources: identity, category, coordinates and any optional reviewed values
come from published independent Supabase rows or their versioned local snapshot.
Source URL/license/verification date accompany those records. Legacy Google
detail pages get current provider fields on demand and retain them only in the
existing screen's memory; server field profiles/attribution are preserved.
