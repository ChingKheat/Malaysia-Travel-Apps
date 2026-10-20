-- ==============================================================================
-- SMART TRAVEL PLANNING MOBILE APPLICATION FOR TOURISTS IN MALAYSIA
-- Database Schema for Supabase PostgreSQL (Third Normal Form - 3NF)
-- Based on FYP 1 Report: Chapter 4.6 (ERD Figure 4.3 & Tables 4.2 - 4.9)
-- ==============================================================================

-- Enable UUID extension if not already enabled
BEGIN;
CREATE EXTENSION IF NOT EXISTS "pgcrypto";

-- ==============================================================================
-- 1. PROFILES TABLE (Table 4.2)
-- Stores tourist profiles tied to Supabase Authentication (auth.users)
-- ==============================================================================
CREATE TABLE IF NOT EXISTS public.profiles (
    user_id UUID PRIMARY KEY,
    email VARCHAR(255) NOT NULL UNIQUE,
    full_name VARCHAR(150) NOT NULL,
    travel_preferences JSONB DEFAULT '[]'::jsonb,
    preferred_language VARCHAR(10) NOT NULL DEFAULT 'en',
    role VARCHAR(20) NOT NULL DEFAULT 'user',
    created_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc'::text, now())
);

-- Legacy demo rows remain local-only; new cloud profiles must belong to Auth users.
ALTER TABLE public.profiles ADD COLUMN IF NOT EXISTS role VARCHAR(20) NOT NULL DEFAULT 'user';
DO $$ BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conrelid = 'public.profiles'::regclass AND conname = 'profiles_user_id_fkey') THEN
        ALTER TABLE public.profiles ADD CONSTRAINT profiles_user_id_fkey
          FOREIGN KEY (user_id) REFERENCES auth.users(id) ON DELETE CASCADE NOT VALID;
    END IF;
END $$;

-- ==============================================================================
-- 2. PLACES TABLE (Table 4.6)
-- Caches attractions, dining, and POIs fetched from Google Places API
-- ==============================================================================
CREATE TABLE IF NOT EXISTS public.places (
    place_id VARCHAR(255) PRIMARY KEY,
    name VARCHAR(255) NOT NULL,
    state VARCHAR(100) NOT NULL,
    category VARCHAR(100) NOT NULL,
    latitude DOUBLE PRECISION NOT NULL,
    longitude DOUBLE PRECISION NOT NULL,
    rating NUMERIC(3,2),
    photo_url TEXT, -- Primary photo URL or multi-photo URLs delimited by '|' for photo gallery caching
    operating_hours JSONB,
    is_indoor BOOLEAN, -- TRUE = indoor, FALSE = outdoor, NULL = unassigned / needs manual review
    user_ratings_total INTEGER DEFAULT 0
);
ALTER TABLE public.places ADD COLUMN IF NOT EXISTS is_indoor BOOLEAN;
ALTER TABLE public.places ADD COLUMN IF NOT EXISTS user_ratings_total INTEGER DEFAULT 0;

-- ==============================================================================
-- 3. INDOOR_PLACES TABLE (Table 4.7)
-- Sub-type table for indoor attractions (air conditioning, capacity)
-- ==============================================================================
CREATE TABLE IF NOT EXISTS public.indoor_places (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    place_id VARCHAR(255) NOT NULL UNIQUE REFERENCES public.places(place_id) ON DELETE CASCADE,
    is_air_conditioned BOOLEAN NOT NULL DEFAULT TRUE,
    max_capacity INTEGER
);

-- ==============================================================================
-- 4. OUTDOOR_PLACES TABLE (Table 4.7)
-- Sub-type table for outdoor attractions (rain sensitivity, weather conditions)
-- ==============================================================================
CREATE TABLE IF NOT EXISTS public.outdoor_places (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    place_id VARCHAR(255) NOT NULL UNIQUE REFERENCES public.places(place_id) ON DELETE CASCADE,
    is_rain_sensitive BOOLEAN NOT NULL DEFAULT TRUE,
    weather_condition VARCHAR(100)
);
-- Older installations allowed several subtype rows for the same place. Archive
-- every original row in each duplicate group before retaining the lowest ID.
-- The archive is outside the API schema and inaccessible to mobile clients.
CREATE SCHEMA IF NOT EXISTS recovery;
REVOKE ALL ON SCHEMA recovery FROM PUBLIC, anon, authenticated;
CREATE TABLE IF NOT EXISTS recovery.place_subtype_duplicates (
    source_table TEXT NOT NULL,
    original_id TEXT NOT NULL,
    snapshot_hash TEXT NOT NULL,
    row_data JSONB NOT NULL,
    archived_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    PRIMARY KEY (source_table, original_id, snapshot_hash)
);
REVOKE ALL ON recovery.place_subtype_duplicates FROM PUBLIC, anon, authenticated;
ALTER TABLE recovery.place_subtype_duplicates ENABLE ROW LEVEL SECURITY;
-- No client policies: only trusted database administration can read the archive.

DO $$
DECLARE subtype TEXT; duplicate_exists BOOLEAN;
BEGIN
  FOREACH subtype IN ARRAY ARRAY['indoor_places', 'outdoor_places'] LOOP
    EXECUTE format('LOCK TABLE public.%I IN ACCESS EXCLUSIVE MODE', subtype);
    EXECUTE format('SELECT EXISTS (SELECT 1 FROM public.%I GROUP BY place_id HAVING count(*) > 1)', subtype)
      INTO duplicate_exists;
    IF NOT duplicate_exists THEN CONTINUE; END IF;
    -- Unknown referencing tables need a tailored migration, not cascading deletion.
    IF EXISTS (SELECT 1 FROM pg_constraint WHERE contype = 'f'
      AND confrelid = to_regclass(format('public.%I', subtype))) THEN
      RAISE EXCEPTION 'Cannot consolidate public.%: another table references its rows. A tailored migration is required.', subtype;
    END IF;
    EXECUTE format($archive$
      INSERT INTO recovery.place_subtype_duplicates(source_table, original_id, snapshot_hash, row_data)
      SELECT %L, t.id::text, md5(to_jsonb(t)::text), to_jsonb(t)
      FROM public.%I t
      WHERE t.place_id IN (SELECT place_id FROM public.%I GROUP BY place_id HAVING count(*) > 1)
      ON CONFLICT DO NOTHING
    $archive$, subtype, subtype, subtype);
    EXECUTE format($consolidate$
      DELETE FROM public.%I t USING (
        SELECT id, row_number() OVER (PARTITION BY place_id ORDER BY id::text) AS occurrence
        FROM public.%I
      ) duplicates
      WHERE t.id = duplicates.id AND duplicates.occurrence > 1
    $consolidate$, subtype, subtype);
  END LOOP;
END $$;

CREATE UNIQUE INDEX IF NOT EXISTS idx_unique_indoor_place_id ON public.indoor_places(place_id);
CREATE UNIQUE INDEX IF NOT EXISTS idx_unique_outdoor_place_id ON public.outdoor_places(place_id);

-- ==============================================================================
-- 5. ITINERARIES TABLE (Table 4.3)
-- Master table for generated and saved user travel itineraries
-- ==============================================================================
CREATE TABLE IF NOT EXISTS public.itineraries (
    itinerary_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES public.profiles(user_id) ON DELETE CASCADE,
    title VARCHAR(200) NOT NULL,
    destination_state VARCHAR(100) NOT NULL,
    total_cost NUMERIC(10,2) NOT NULL DEFAULT 0.00,
    is_public BOOLEAN NOT NULL DEFAULT FALSE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc'::text, now())
);

-- ==============================================================================
-- 6. DAILY_SCHEDULES TABLE (Table 4.4)
-- Day-by-day segments of a multi-day itinerary (Day 1, Day 2, etc.)
-- ==============================================================================
CREATE TABLE IF NOT EXISTS public.daily_schedules (
    schedule_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    itinerary_id UUID NOT NULL REFERENCES public.itineraries(itinerary_id) ON DELETE CASCADE,
    day_number INTEGER NOT NULL,
    schedule_date DATE NOT NULL,
    total_distance_km NUMERIC(6,2) NOT NULL DEFAULT 0.00
);

-- ==============================================================================
-- 7. ITINERARY_STOPS TABLE (Table 4.5)
-- Specific scheduled stops and attractions ordered per day
-- ==============================================================================
CREATE TABLE IF NOT EXISTS public.itinerary_stops (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    schedule_id UUID NOT NULL REFERENCES public.daily_schedules(schedule_id) ON DELETE CASCADE,
    place_id VARCHAR(255) NOT NULL REFERENCES public.places(place_id) ON DELETE CASCADE,
    stop_order INTEGER NOT NULL,
    arrival_time TIME NOT NULL,
    departure_time TIME NOT NULL,
    is_visited BOOLEAN NOT NULL DEFAULT FALSE
);

-- ==============================================================================
-- 8. WEATHER_FORECASTS TABLE (Table 4.8)
-- Weather forecast snapshots associated with scheduled travel dates
-- ==============================================================================
CREATE TABLE IF NOT EXISTS public.weather_forecasts (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    itinerary_id UUID NOT NULL REFERENCES public.itineraries(itinerary_id) ON DELETE CASCADE,
    location_state VARCHAR(100) NOT NULL,
    schedule_date DATE NOT NULL,
    condition VARCHAR(100) NOT NULL,
    rain_probability NUMERIC(5,2) NOT NULL
);

-- ==============================================================================
-- 9. ASSISTANT_MESSAGES TABLE (Table 4.9)
-- Chat history between tourist and Google Gemini AI Assistant
-- ==============================================================================
CREATE TABLE IF NOT EXISTS public.assistant_messages (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES public.profiles(user_id) ON DELETE CASCADE,
    user_prompt TEXT NOT NULL,
    ai_response TEXT NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc'::text, now())
);

-- ==============================================================================
-- INDEXES FOR PERFORMANCE OPTIMIZATION
-- ==============================================================================
CREATE INDEX IF NOT EXISTS idx_itineraries_user_id ON public.itineraries(user_id);
CREATE INDEX IF NOT EXISTS idx_daily_schedules_itinerary_id ON public.daily_schedules(itinerary_id);
CREATE INDEX IF NOT EXISTS idx_itinerary_stops_schedule_id ON public.itinerary_stops(schedule_id);
CREATE INDEX IF NOT EXISTS idx_places_state ON public.places(state);
CREATE INDEX IF NOT EXISTS idx_places_category ON public.places(category);
CREATE INDEX IF NOT EXISTS idx_weather_forecasts_itinerary_id ON public.weather_forecasts(itinerary_id);
CREATE INDEX IF NOT EXISTS idx_assistant_messages_user_id ON public.assistant_messages(user_id);

-- ==============================================================================
-- AUTOMATED USER PROFILE CREATION TRIGGER
-- When a user registers via Supabase Auth, a profile row is created automatically
-- ==============================================================================
CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS TRIGGER AS $$
BEGIN
    INSERT INTO public.profiles (user_id, email, full_name, preferred_language, role)
    VALUES (
        NEW.id,
        NEW.email,
        COALESCE(NEW.raw_user_meta_data->>'full_name', split_part(NEW.email, '@', 1)),
        COALESCE(NEW.raw_user_meta_data->>'preferred_language', 'en'),
        'user'
    )
    ON CONFLICT (user_id) DO UPDATE
    SET email = EXCLUDED.email;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp;

-- Drop trigger if already exists then recreate
DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;
CREATE TRIGGER on_auth_user_created
    AFTER INSERT ON auth.users
    FOR EACH ROW EXECUTE FUNCTION public.handle_new_user();

-- ==============================================================================
-- ROW-LEVEL SECURITY (RLS) POLICIES
-- Enforce data isolation per ASR-3 & Constraints C5/C2
-- ==============================================================================
ALTER TABLE public.profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.itineraries ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.daily_schedules ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.itinerary_stops ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.places ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.indoor_places ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.outdoor_places ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.weather_forecasts ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.assistant_messages ENABLE ROW LEVEL SECURITY;

-- Replace legacy permissive policies, including installations made by older scripts.
DO $$ DECLARE p record; BEGIN
  FOR p IN SELECT schemaname, tablename, policyname FROM pg_policies
    WHERE schemaname = 'public' AND tablename IN
      ('profiles','itineraries','daily_schedules','itinerary_stops','places',
       'indoor_places','outdoor_places','weather_forecasts','assistant_messages')
  LOOP EXECUTE format('DROP POLICY IF EXISTS %I ON %I.%I',p.policyname,p.schemaname,p.tablename); END LOOP;
END $$;

CREATE OR REPLACE FUNCTION public.is_admin() RETURNS boolean
LANGUAGE sql STABLE SECURITY DEFINER SET search_path = public, pg_temp AS $$
 SELECT EXISTS (SELECT 1 FROM public.profiles WHERE user_id = auth.uid() AND role = 'admin');
$$;
REVOKE ALL ON FUNCTION public.is_admin() FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.is_admin() TO anon, authenticated;

-- BEGIN PLACE SYNC STATUS
-- Import metadata only: no Google content, keys, or private user data.
CREATE TABLE IF NOT EXISTS public.place_sync_status (
    state VARCHAR(100) PRIMARY KEY CHECK (length(btrim(state)) > 0),
    last_synced_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    place_count INTEGER NOT NULL CHECK (place_count >= 0),
    request_count INTEGER NOT NULL CHECK (request_count >= 0)
);
ALTER TABLE public.place_sync_status ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.place_sync_status FROM PUBLIC, anon, authenticated;
GRANT SELECT, INSERT, UPDATE ON public.place_sync_status TO authenticated;
DROP POLICY IF EXISTS place_sync_status_admin ON public.place_sync_status;
CREATE POLICY place_sync_status_admin ON public.place_sync_status
    FOR ALL TO authenticated
    USING ((SELECT public.is_admin())) WITH CHECK ((SELECT public.is_admin()));

-- Invoker permissions and RLS enforce admin access. Time comes from PostgreSQL,
-- and is recorded only after the app has completed all import batches.
CREATE OR REPLACE FUNCTION public.record_place_sync(
    p_state TEXT, p_place_count INTEGER, p_request_count INTEGER
) RETURNS SETOF public.place_sync_status
LANGUAGE sql SECURITY INVOKER SET search_path = '' AS $$
    INSERT INTO public.place_sync_status(state, last_synced_at, place_count, request_count)
    VALUES (p_state, clock_timestamp(), p_place_count, p_request_count)
    ON CONFLICT (state) DO UPDATE SET
        last_synced_at = EXCLUDED.last_synced_at,
        place_count = EXCLUDED.place_count,
        request_count = EXCLUDED.request_count
    RETURNING *;
$$;
REVOKE ALL ON FUNCTION public.record_place_sync(TEXT, INTEGER, INTEGER) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.record_place_sync(TEXT, INTEGER, INTEGER) TO authenticated;
-- END PLACE SYNC STATUS


-- Client-controlled metadata and profile updates cannot grant administrator access.
CREATE OR REPLACE FUNCTION public.protect_profile_role() RETURNS trigger
LANGUAGE plpgsql SET search_path = public, pg_temp AS $$
BEGIN
 IF auth.role() IN ('anon','authenticated') AND (
   (TG_OP = 'INSERT' AND NEW.role <> 'user') OR
   (TG_OP = 'UPDATE' AND (NEW.role IS DISTINCT FROM OLD.role OR NEW.user_id IS DISTINCT FROM OLD.user_id))
 ) THEN RAISE EXCEPTION 'Profile role and identity are managed by the server'; END IF;
 RETURN NEW;
END $$;
DROP TRIGGER IF EXISTS protect_profile_role ON public.profiles;
CREATE TRIGGER protect_profile_role BEFORE INSERT OR UPDATE ON public.profiles
FOR EACH ROW EXECUTE FUNCTION public.protect_profile_role();

CREATE POLICY profiles_read ON public.profiles FOR SELECT TO authenticated USING (user_id = auth.uid());
CREATE POLICY profiles_insert ON public.profiles FOR INSERT TO authenticated WITH CHECK (user_id = auth.uid() AND role = 'user');
CREATE POLICY profiles_update ON public.profiles FOR UPDATE TO authenticated USING (user_id = auth.uid()) WITH CHECK (user_id = auth.uid());
CREATE POLICY itineraries_read ON public.itineraries FOR SELECT TO authenticated USING (user_id = auth.uid() OR is_public);
CREATE POLICY itineraries_insert ON public.itineraries FOR INSERT TO authenticated WITH CHECK (user_id = auth.uid());
CREATE POLICY itineraries_update ON public.itineraries FOR UPDATE TO authenticated USING (user_id = auth.uid()) WITH CHECK (user_id = auth.uid());
CREATE POLICY itineraries_delete ON public.itineraries FOR DELETE TO authenticated USING (user_id = auth.uid());
CREATE POLICY schedules_read ON public.daily_schedules FOR SELECT TO authenticated USING (
 EXISTS (SELECT 1 FROM public.itineraries i WHERE i.itinerary_id = daily_schedules.itinerary_id AND (i.user_id = auth.uid() OR i.is_public)));
CREATE POLICY schedules_write ON public.daily_schedules FOR ALL TO authenticated USING (
 EXISTS (SELECT 1 FROM public.itineraries i WHERE i.itinerary_id = daily_schedules.itinerary_id AND i.user_id = auth.uid())) WITH CHECK (
 EXISTS (SELECT 1 FROM public.itineraries i WHERE i.itinerary_id = daily_schedules.itinerary_id AND i.user_id = auth.uid()));
CREATE POLICY stops_read ON public.itinerary_stops FOR SELECT TO authenticated USING (
 EXISTS (SELECT 1 FROM public.daily_schedules d JOIN public.itineraries i USING (itinerary_id)
 WHERE d.schedule_id = itinerary_stops.schedule_id AND (i.user_id = auth.uid() OR i.is_public)));
CREATE POLICY stops_write ON public.itinerary_stops FOR ALL TO authenticated USING (
 EXISTS (SELECT 1 FROM public.daily_schedules d JOIN public.itineraries i USING (itinerary_id)
 WHERE d.schedule_id = itinerary_stops.schedule_id AND i.user_id = auth.uid())) WITH CHECK (
 EXISTS (SELECT 1 FROM public.daily_schedules d JOIN public.itineraries i USING (itinerary_id)
 WHERE d.schedule_id = itinerary_stops.schedule_id AND i.user_id = auth.uid()));
CREATE POLICY weather_read ON public.weather_forecasts FOR SELECT TO authenticated USING (
 EXISTS (SELECT 1 FROM public.itineraries i WHERE i.itinerary_id = weather_forecasts.itinerary_id AND (i.user_id = auth.uid() OR i.is_public)));
CREATE POLICY weather_write ON public.weather_forecasts FOR ALL TO authenticated USING (
 EXISTS (SELECT 1 FROM public.itineraries i WHERE i.itinerary_id = weather_forecasts.itinerary_id AND i.user_id = auth.uid())) WITH CHECK (
 EXISTS (SELECT 1 FROM public.itineraries i WHERE i.itinerary_id = weather_forecasts.itinerary_id AND i.user_id = auth.uid()));
CREATE POLICY messages_read ON public.assistant_messages FOR SELECT TO authenticated USING (user_id = auth.uid());
CREATE POLICY messages_insert ON public.assistant_messages FOR INSERT TO authenticated WITH CHECK (user_id = auth.uid());
CREATE POLICY places_read ON public.places FOR SELECT USING (true);
CREATE POLICY places_admin ON public.places FOR ALL TO authenticated USING (public.is_admin()) WITH CHECK (public.is_admin());
ALTER TABLE public.indoor_places ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.outdoor_places ENABLE ROW LEVEL SECURITY;
CREATE POLICY indoor_read ON public.indoor_places FOR SELECT USING (true);
CREATE POLICY indoor_admin ON public.indoor_places FOR ALL TO authenticated USING (public.is_admin()) WITH CHECK (public.is_admin());
CREATE POLICY outdoor_read ON public.outdoor_places FOR SELECT USING (true);
CREATE POLICY outdoor_admin ON public.outdoor_places FOR ALL TO authenticated USING (public.is_admin()) WITH CHECK (public.is_admin());

-- ==============================================================================
-- AUTOMATIC TRIGGER: SYNC INDOOR & OUTDOOR PLACES
-- Keeps indoor_places and outdoor_places automatically in sync with places.is_indoor
-- ==============================================================================
CREATE OR REPLACE FUNCTION public.sync_indoor_outdoor_subtables()
RETURNS TRIGGER AS $$
BEGIN
    IF NEW.is_indoor = TRUE THEN
        INSERT INTO public.indoor_places (place_id, is_air_conditioned)
        VALUES (NEW.place_id, TRUE)
        ON CONFLICT (place_id) DO NOTHING;
        
        DELETE FROM public.outdoor_places WHERE place_id = NEW.place_id;
    ELSIF NEW.is_indoor = FALSE THEN
        INSERT INTO public.outdoor_places (place_id, is_rain_sensitive)
        VALUES (NEW.place_id, TRUE)
        ON CONFLICT (place_id) DO NOTHING;
        
        DELETE FROM public.indoor_places WHERE place_id = NEW.place_id;
    ELSE
        -- If is_indoor is NULL (needs manual review), remove from both sub-tables
        DELETE FROM public.indoor_places WHERE place_id = NEW.place_id;
        DELETE FROM public.outdoor_places WHERE place_id = NEW.place_id;
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp;

DROP TRIGGER IF EXISTS trg_sync_indoor_outdoor_subtables ON public.places;
CREATE TRIGGER trg_sync_indoor_outdoor_subtables
AFTER INSERT OR UPDATE OF is_indoor ON public.places
FOR EACH ROW
EXECUTE FUNCTION public.sync_indoor_outdoor_subtables();

-- ==============================================================================
-- SEED DATA: POPULAR MALAYSIAN ATTRACTIONS (FOR INSTANT READ-THROUGH CACHE HIT)
-- ==============================================================================
INSERT INTO public.places (place_id, name, state, category, latitude, longitude, rating, photo_url, operating_hours)
VALUES
('poi_kl_batu_caves', 'Batu Caves', 'Kuala Lumpur', 'Culture', 3.2379, 101.6841, 4.6, 'https://images.unsplash.com/photo-1596422846543-75c6fc197f07?auto=format&fit=crop&w=600&q=80', '{"open": "06:00", "close": "21:00"}'::jsonb),
('poi_kl_petronas', 'Petronas Twin Towers', 'Kuala Lumpur', 'Landmark', 3.1579, 101.7116, 4.8, 'https://images.unsplash.com/photo-1565008447742-97f6f38c985c?auto=format&fit=crop&w=600&q=80', '{"open": "09:00", "close": "21:00"}'::jsonb),
('poi_kl_central_market', 'Central Market (Pasar Seni)', 'Kuala Lumpur', 'Shopping', 3.1453, 101.6954, 4.4, 'https://images.unsplash.com/photo-1582533561751-ef6f6ab93a2e?auto=format&fit=crop&w=600&q=80', '{"open": "10:00", "close": "20:00"}'::jsonb),
('poi_kl_jalan_alor', 'Jalan Alor Food Street', 'Kuala Lumpur', 'Food', 3.1458, 101.7088, 4.5, 'https://images.unsplash.com/photo-1555396273-367ea4eb4db5?auto=format&fit=crop&w=600&q=80', '{"open": "16:00", "close": "02:00"}'::jsonb),
('poi_kl_klcc_park', 'KLCC Park', 'Kuala Lumpur', 'Nature', 3.1558, 101.7138, 4.6, 'https://images.unsplash.com/photo-1518684079-3c830dcef090?auto=format&fit=crop&w=600&q=80', '{"open": "07:00", "close": "22:00"}'::jsonb),
('poi_png_kek_lok_si', 'Kek Lok Si Temple', 'Penang', 'Culture', 5.3996, 100.2737, 4.7, 'https://images.unsplash.com/photo-1548013146-72479768bada?auto=format&fit=crop&w=600&q=80', '{"open": "08:30", "close": "17:30"}'::jsonb),
('poi_png_penang_hill', 'Penang Hill (Bukit Bendera)', 'Penang', 'Nature', 5.4244, 100.2691, 4.5, 'https://images.unsplash.com/photo-1506744038136-46273834b3fb?auto=format&fit=crop&w=600&q=80', '{"open": "06:30", "close": "23:00"}'::jsonb),
('poi_mlk_jonker_street', 'Jonker Street Night Market', 'Melaka', 'Food', 2.1950, 102.2475, 4.5, 'https://images.unsplash.com/photo-1514933651103-005eec06c04b?auto=format&fit=crop&w=600&q=80', '{"open": "18:00", "close": "23:59"}'::jsonb),
('poi_mlk_stadthuys', 'The Stadthuys (Red Square)', 'Melaka', 'Heritage', 2.1944, 102.2486, 4.6, 'https://images.unsplash.com/photo-1569154941061-e231b4725ef1?auto=format&fit=crop&w=600&q=80', '{"open": "09:00", "close": "17:00"}'::jsonb)
ON CONFLICT (place_id) DO NOTHING;

-- Seed classification for indoor vs outdoor
INSERT INTO public.outdoor_places (place_id, is_rain_sensitive, weather_condition)
VALUES
('poi_kl_batu_caves', TRUE, 'Clear/Cloudy'),
('poi_kl_klcc_park', TRUE, 'Clear/Cloudy'),
('poi_png_penang_hill', TRUE, 'Clear/Cloudy'),
('poi_mlk_jonker_street', TRUE, 'Dry evening')
ON CONFLICT DO NOTHING;

INSERT INTO public.indoor_places (place_id, is_air_conditioned, max_capacity)
VALUES
('poi_kl_petronas', TRUE, 1000),
('poi_kl_central_market', TRUE, 2500),
('poi_png_kek_lok_si', FALSE, 1500),
('poi_mlk_stadthuys', TRUE, 500)
ON CONFLICT DO NOTHING;

-- Planning snapshots and atomic, retry-safe itinerary synchronization.
ALTER TABLE public.itineraries ADD COLUMN IF NOT EXISTS preferences JSONB NOT NULL DEFAULT '{}'::jsonb;
ALTER TABLE public.itinerary_stops ADD COLUMN IF NOT EXISTS stop_data JSONB NOT NULL DEFAULT '{}'::jsonb;
CREATE OR REPLACE FUNCTION public.save_itinerary(payload jsonb) RETURNS uuid
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
DECLARE trip_id uuid := (payload->>'itinerary_id')::uuid;
        owner_id uuid := auth.uid(); d jsonb; st jsonb; day_id uuid;
BEGIN
 IF owner_id IS NULL OR owner_id <> (payload->>'user_id')::uuid THEN
   RAISE EXCEPTION 'Authentication required';
 END IF;
 -- Serialize retries of the same trip, including concurrent first inserts.
 PERFORM pg_advisory_xact_lock(hashtextextended(trip_id::text, 0));
 IF EXISTS (SELECT 1 FROM public.itineraries WHERE itinerary_id = trip_id AND user_id <> owner_id) THEN
   RAISE EXCEPTION 'Itinerary belongs to another user';
 END IF;
 INSERT INTO public.itineraries(itinerary_id,user_id,title,destination_state,total_cost,is_public,created_at,preferences)
 VALUES(trip_id,owner_id,payload->>'title',payload->>'destination_state',
 (payload->>'total_cost')::numeric,COALESCE((payload->>'is_public')::boolean,false),
 (payload->>'created_at')::timestamptz,COALESCE(payload->'preferences','{}'::jsonb))
 ON CONFLICT (itinerary_id) DO UPDATE SET title=EXCLUDED.title,destination_state=EXCLUDED.destination_state,
 total_cost=EXCLUDED.total_cost,is_public=EXCLUDED.is_public,preferences=EXCLUDED.preferences;
 DELETE FROM public.daily_schedules WHERE itinerary_id = trip_id;
 FOR d IN SELECT value FROM jsonb_array_elements(payload->'daily_schedules') LOOP
   day_id := (d->>'schedule_id')::uuid;
   INSERT INTO public.daily_schedules(schedule_id,itinerary_id,day_number,schedule_date,total_distance_km)
   VALUES(day_id,trip_id,(d->>'day_number')::integer,(d->>'schedule_date')::date,(d->>'total_distance_km')::numeric);
   FOR st IN SELECT value FROM jsonb_array_elements(d->'itinerary_stops') LOOP
     INSERT INTO public.places(place_id,name,state,category,latitude,longitude)
     VALUES(st->>'place_id',st->>'place_name',payload->>'destination_state',
       COALESCE(st->>'category','Attraction'),(st->>'latitude')::double precision,(st->>'longitude')::double precision)
     ON CONFLICT (place_id) DO NOTHING;
     INSERT INTO public.itinerary_stops(id,schedule_id,place_id,stop_order,arrival_time,departure_time,is_visited,stop_data)
     VALUES((st->>'id')::uuid,day_id,st->>'place_id',(st->>'stop_order')::integer,
       (st->>'arrival_time')::time,(st->>'departure_time')::time,COALESCE((st->>'is_visited')::boolean,false),st || COALESCE(st->'stop_data','{}'::jsonb));
   END LOOP;
 END LOOP;
 RETURN trip_id;
END $$;
REVOKE ALL ON FUNCTION public.save_itinerary(jsonb) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.save_itinerary(jsonb) TO authenticated;
COMMIT;
