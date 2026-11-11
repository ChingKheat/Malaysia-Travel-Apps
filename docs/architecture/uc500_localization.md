# UC500 — Change Language

Implemented 11 November 2026 (Asia/Kuala_Lumpur).

## User experience

App Language is available on Welcome, Login/Register, and Profile. The shared
bottom sheet lists English, Bahasa Melayu, and 简体中文 in their native scripts,
with a checkmark for the selected language. Selecting a language updates the
interface immediately and confirms in that language. Cancelling changes nothing.
The selection remains after logout and is restored before the app starts.

English is the initial and invalid/unreadable-preference fallback. This is a
device setting; there is no automatic device-language selection or account sync.
A failed local write leaves the chosen language active and explicitly explains
that it could not be saved for future sessions. It does not claim success.

## Implementation and boundaries

- `LanguageController` is a ChangeNotifier with injectable `LanguageStore`.
  `load()` reads the `app_language` SharedPreferences key; `changeLanguage()`
  accepts only `en`, `ms`, and `zh`, applies immediately, and returns save status.
  Writes are serialized so rapid selections cannot persist in the wrong order.
- `LanguageScope` exposes the controller. The existing MaterialApp uses generated
  localization delegates and supported locales without replacing Navigator or
  keying the widget tree by language. Authentication and screen state survive.
- The three ARB catalogs contain 739 matching message keys. Most UI text uses
  generated typed getters/methods. `localized_labels.dart` translates known
  app-owned enum labels and legacy service messages at the presentation boundary.
  It must not be used on arbitrary user or provider content.
- `presentation_formatters.dart` formats scheduling warnings and times; `intl`
  formats dates, numeric amounts, and MYR currency. SavedTrip carries optional
  typed start-date metadata and an explicit generated-title flag for rendering.
  These are UI model additions, not database fields or migrations.
- Navigation, auth/profile, planning/edit/save, browsing/details, recognition,
  assistant controls, and admin interface labels use the catalogs. Password
  visibility controls and language controls have localized accessibility labels.
- Assistant response language and recognition result translation are separate.
  Existing responses, original recognition results, user trip titles, place names,
  provider descriptions, URLs, and raw diagnostic output remain as supplied.
  Canonical category/budget/mode values and stored schedules are unchanged.
- Welcome scrolls on constrained screens; authentication labels wrap; navigation
  height adapts to its labels. iOS declares the three supported languages.

## Verification

`test/features/localization/` contains 21 passing cases covering:

- Invalid/missing/unreadable preferences, all three persisted choices, restart
  through a fresh controller, invalid input rejection, storage failures, and
  rapid writes.
- Switching from Welcome, Login, and Profile; translated success/failure
  feedback; preservation of login fields, selected auth tab, identity, and a
  pushed route; logout does not reset language.
- English, Malay, and Chinese welcome/auth forms, navigation/selector, and
  planner at 320 logical pixels with 2× text; existing selected interests survive.
- Catalog key/placeholder parity, date/currency formatting, composed scheduler
  warnings, and preservation of user-supplied itinerary names.

The full default-config suite recorded **165 passed, 2 failed**. The remaining
failures are outside UC500:

1. `popular_attractions_section_test.dart` still expects the literal heading
   “Attraction Details”, which the pre-existing attraction-detail redesign no
   longer displays. The test does reach AttractionDetailPage.
2. `supabase_integration_test.dart:79` expects a seeded local account to log in
   after initializing the configured backend. It fails before saving or rendering
   any localized interface; its setup mixes the configured backend with a local
   seeded identity.

Static analysis has no compile errors. An existing unused `_photoSaved` field in
`place_details_refresh_page.dart` remains outside this change.

DTD was inspected and initially reported an Android emulator connection. By the
reload attempt the VM endpoint had stopped accepting connections and the Flutter
run process had exited. No app was available for hot reload at completion.
Physical-device font rendering, TalkBack/VoiceOver review, and native-speaker
translation review remain release acceptance checks; widget tests do not certify
those outcomes.

## Maintaining translations

Edit `lib/l10n/app_en.arb`, `app_ms.arb`, and `app_zh.arb` together. Use descriptive
keys and placeholders for values. Run `flutter gen-l10n`, then `flutter analyze`
and `flutter test`. Do not edit generated `app_localizations*.dart` by hand.
Prefer `context.l10n` for new UI. For a legacy service message, add its mapping in
`localized_labels.dart`; keep services and persistent models language-neutral.
