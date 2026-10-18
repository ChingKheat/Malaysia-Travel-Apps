# Workspace Rules: Smart Travel Planning Mobile Application

## 1. Project Context & Objectives
* **Project Title:** Smart Travel Planning Mobile Application for Tourists in Malaysia: Auto Smart Scheduling Module
* **Author:** Khoh Ching Kheat (TAR UMT, FOCS - BMCS3404 Project I & II)
* **Supervisor:** Dr. Lim Fung Ji
* **Core Architecture:** Client-Cloud Layered Model (Flutter frontend + Supabase PostgreSQL & Auth + Google Maps Platform + OpenWeatherMap + Gemini AI Assistant).

---

## 2. CRITICAL RULE: Database Schema Sync & Disaster Recovery
1. **Always Keep `docs/supabase_schema.sql` Up-to-Date:**
   * Whenever any database table, column, constraint, relationship, RLS policy, or trigger is added, modified, or altered in this project, **YOU MUST IMMEDIATELY update `docs/supabase_schema.sql`**.
   * `docs/supabase_schema.sql` is the **Single Source of Truth** for the project's **1-Minute Disaster Recovery** (e.g. if the free Supabase project pauses or expires).
   * Ensure all DDL statements in `docs/supabase_schema.sql` remain idempotent (`IF NOT EXISTS`, `CREATE OR REPLACE`, `ON CONFLICT DO NOTHING`).

2. **Offline & Expiry Resilience:**
   * All database and API service wrappers (`AuthService`, `SupabaseItineraryService`, `PlacesService`, etc.) must maintain seamless offline/local fallbacks.
   * If Supabase is expired, unreachable, or in testing mode, the mobile app must never crash and must continue to operate using local persistent state.

---

## 3. Architecture & Standards Compliance
* Adhere to the submitted FYP 1 specifications:
  * **Use Cases:** UC100 (Register), UC200 (Login), UC300 (Manage Profile), UC400 (Browse Attractions), UC401 (View Place Details), UC500 (Change Language), UC600 (Generate Smart Itinerary), UC601 (Save Itinerary), UC602 (Edit Itinerary), UC603 (Regenerate Itinerary), UC700 (View Saved Itineraries), UC800 (Live GPS Navigation), UC900 (AI Travel Assistant).
  * **UML & ERD:** Conform to Chapter 4 Class Diagram (Fig 4.2), ERD (Fig 4.3), and Data Dictionary (Tables 4.2 to 4.9).
  * **Testing:** Maintain test integrity across `test/`. Run `flutter test` after significant logic changes.

---

## 4. Flutter Development Protocol
* When editing Dart or Flutter files, check for a running application connection via Dart Tooling Daemon (DTD) and trigger a hot reload if available. If no app is running, proceed smoothly without blocking.
