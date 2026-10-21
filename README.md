# Smart Travel Planner

Smart Travel Planning Mobile Application for Tourists in Malaysia: Auto Smart
Scheduling Module. A TAR UMT final-year project by Khoh Ching Kheat, supervised by
Dr. Lim Fung Ji.

The Flutter application includes authentication, attraction browsing, smart trip
planning, saved itineraries, maps, an assistant UI, and an image recognition UI.
Its client-cloud architecture uses Supabase Auth and PostgreSQL, Google Maps
Platform, and OpenWeatherMap, with the existing local fallbacks available when
services cannot be reached. Image recognition currently supports sample results,
photo previews, and local history; live photo recognition is not connected.

The bottom navigation has five destinations: Home, Explore, Recognize, Plan, and AI.
Recognize is centered. Open My Trips from the Home card or the Plan shortcut to view
saved itineraries and the current plan; the itinerary preview also opens My Trips.

## Getting started

Use a Flutter SDK with Dart **3.12.2 or later, below 4.0.0**, as required by
`pubspec.yaml`. For Android development, configure the Android SDK and start an
emulator or connect a device. Run these commands from the project root:

```powershell
flutter pub get
flutter run
```

The dependency versions, configured defaults, and offline behavior are unchanged
by the folder reorganization. Configuration now lives in `lib/core/config/`.
To use another backend project, pass the existing build-time overrides:

```powershell
flutter run --dart-define=SUPABASE_URL=https://your-project.supabase.co --dart-define=SUPABASE_ANON_KEY=your-publishable-key
```

The existing API settings also accept `GOOGLE_MAPS_API_KEY` and
`OPENWEATHERMAP_API_KEY` through `--dart-define`. Native and web map setup remains
in its original platform folders. See the [current data-flow documentation](docs/architecture/google_places_data_flow.md)
for platform configuration and the distinction between client and server keys.
Backend function configuration remains documented by
[`supabase/functions/.env.example`](supabase/functions/.env.example).

After adding or changing a native plugin, stop and rerun the app so its platform
implementation is loaded. For Dart-only changes, use hot reload when connected.

## Folder map

```text
lib/
  main.dart                       Application entry point
  app/                            Application setup and bottom navigation
  core/
    config/                       API and backend configuration
    theme/                        App colors and card decorations
  shared/
    data/                         Malaysian states and cities
    models/                       Attraction, travel stop, route and weather
    services/                     Location, routing, weather and map bootstrap
    utils/                        Shared UI feedback and button styles
    widgets/                      App header and common controls
  features/
    auth/                         Welcome, login, registration and user identity
    home/                         Home dashboard and action/trip cards
    profile/                      User profile
    places/                       Explore, place details, catalog and providers
    itinerary/                    Planning, scheduling, saving and editing trips
    navigation/                   Map and navigation screens
    assistant/                    Travel assistant UI
    image_recognition/            Scanner, presets, result model and local history
    admin/                        Place administration and sync history

test/
  app/                            Application entry tests
  features/                       Tests grouped by their owning feature
  shared/                         Cross-feature backend/fallback integration tests
  manual/                         Explicitly run live API check

tool/
  catalog/                        Place fetching, review and classification scripts
  geography/                      Malaysian state/city data generator
  database/                       Schema backup and isolated validation scripts
  checks/                         Mocked backend proxy tests
  fixtures/places/                Existing place JSON fixtures

docs/
  architecture/                   Current application data flow
  fyp/                            FYP documents and figures
  testing/                        Planning validation and test instructions
  maintenance/                    Historical audits and repair reviews
  supabase_schema.sql             Canonical disaster-recovery schema
  place_sync_status_update.sql    Existing SQL maintenance script

assets/recognition/                Offline sample images and their source notes
supabase/                         Existing backend functions and configuration
```

Features use only the `screens`, `widgets`, `models`, `services`, and `data`
subfolders they need. Keep feature-specific code with its feature and reusable
code in `shared/`. Use package imports across folders and relative imports for
files in the same folder. The map bootstrap implementations remain together for
their conditional import.

Flutter's platform folders, root configuration files, generated caches, and asset
paths keep their original locations. The folder reorganization does not change
class names, service interfaces, local storage keys, or navigation behavior.

## Validation

Run the application checks from the project root:

```powershell
flutter analyze --no-pub
flutter test --no-pub
node --test tool/checks/google_places_proxy_test.mjs tool/checks/google_routes_proxy_test.mjs
```

The Node checks use mocked upstream services. The manual API check keeps its
original filename so Flutter's default `*_test.dart` discovery does not run it:

```powershell
flutter test test/manual/test_api.dart
```

That manual check makes live Google API requests. It is separate from the normal
test suite. Detailed validation is documented in
[planning flow validation](docs/testing/planning_flow_validation.md).

## Maintenance tools

All commands below assume the project root is the working directory. They are
optional maintenance operations and are not part of normal app startup or tests.

| Tool | Purpose |
| --- | --- |
| `tool/geography/fetch_malaysia_data.dart` | Fetch geography data and regenerate `lib/shared/data/malaysia_states.dart`. |
| `tool/catalog/seed_places.dart` | Fetch and upsert place data; save JSON copies under `tool/fixtures/places/`. |
| `tool/catalog/fetch_place_repairs.mjs` | Fetch detail-only repair information for supplied place IDs. |
| `tool/catalog/check_classification.ps1` | Review the existing indoor/outdoor classification. |
| `tool/catalog/check_penang_reviews.ps1` | Review Penang catalog entries. |
| `tool/catalog/execute_auto_classify.ps1` | Update classifications in the configured backend. |
| `tool/database/backup_schema.ps1` | Export the configured live schema to the canonical recovery file. |
| `tool/database/validate_schema.mjs` | Validate the recovery schema using isolated PGlite; setup is in the validation document. |

Run catalog writes or schema exports only as explicit maintenance work. The
folder cleanup itself does not execute them or deploy backend functions.

## Database recovery and documentation

[`docs/supabase_schema.sql`](docs/supabase_schema.sql) remains the single source
of truth for disaster recovery. Keep this exact location and update it immediately
when a future task changes database DDL. This reorganization leaves SQL contents
unchanged.

- [Current places, photos, routes and offline data flow](docs/architecture/google_places_data_flow.md)
- [Planning flow validation](docs/testing/planning_flow_validation.md)
- [Historical Google API migration audit](docs/maintenance/google_api_migration_check.md)
- [Place repair review](docs/maintenance/place_repair_review.md)
- [FYP literature review](docs/fyp/chapter_2_literature_review.md)
- [FYP methodology review](docs/fyp/chapter_3_methodology_review.md)
- [Original prototype demo notes](docs/fyp/fyp_demo_documentation.md)
- [Methodology figure](docs/fyp/figures/figure_3_1_agile_process.png)
