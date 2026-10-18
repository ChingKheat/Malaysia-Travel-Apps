-- ==============================================================================
-- SMART TRAVEL PLANNING MOBILE APPLICATION FOR TOURISTS IN MALAYSIA
-- Database Schema for Supabase PostgreSQL (Third Normal Form - 3NF)
-- Based on FYP 1 Report: Chapter 4.6 (ERD Figure 4.3 & Tables 4.2 - 4.9)
-- ==============================================================================

-- Enable UUID extension if not already enabled
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

-- Ensure migration if column does not exist and relax foreign key for demo accounts
ALTER TABLE public.profiles ADD COLUMN IF NOT EXISTS role VARCHAR(20) NOT NULL DEFAULT 'user';
ALTER TABLE public.profiles DROP CONSTRAINT IF EXISTS profiles_user_id_fkey;

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
CREATE UNIQUE INDEX IF NOT EXISTS idx_unique_indoor_place_id ON public.indoor_places(place_id);

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
        COALESCE(NEW.raw_user_meta_data->>'role', 'user')
    )
    ON CONFLICT (user_id) DO UPDATE
    SET email = EXCLUDED.email;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

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

-- Profiles: Allow reading, inserting and updating profiles (authenticated and demo/guest)
DROP POLICY IF EXISTS "Users can view own profile" ON public.profiles;
DROP POLICY IF EXISTS "Public can view profiles" ON public.profiles;
CREATE POLICY "Public can view profiles" ON public.profiles FOR SELECT USING (TRUE);

DROP POLICY IF EXISTS "Users can update own profile" ON public.profiles;
DROP POLICY IF EXISTS "Public can update profiles" ON public.profiles;
CREATE POLICY "Public can update profiles" ON public.profiles FOR UPDATE USING (TRUE);

DROP POLICY IF EXISTS "Users can insert own profile" ON public.profiles;
DROP POLICY IF EXISTS "Public can insert profiles" ON public.profiles;
CREATE POLICY "Public can insert profiles" ON public.profiles FOR INSERT WITH CHECK (TRUE);

-- Itineraries: Allow viewing and managing itineraries
DROP POLICY IF EXISTS "Users can view own or public itineraries" ON public.itineraries;
DROP POLICY IF EXISTS "Public can view itineraries" ON public.itineraries;
CREATE POLICY "Public can view itineraries" ON public.itineraries FOR SELECT USING (TRUE);

DROP POLICY IF EXISTS "Users can insert own itineraries" ON public.itineraries;
DROP POLICY IF EXISTS "Public can insert itineraries" ON public.itineraries;
CREATE POLICY "Public can insert itineraries" ON public.itineraries FOR INSERT WITH CHECK (TRUE);

DROP POLICY IF EXISTS "Users can update own itineraries" ON public.itineraries;
DROP POLICY IF EXISTS "Public can update itineraries" ON public.itineraries;
CREATE POLICY "Public can update itineraries" ON public.itineraries FOR UPDATE USING (TRUE);

DROP POLICY IF EXISTS "Users can delete own itineraries" ON public.itineraries;
DROP POLICY IF EXISTS "Public can delete itineraries" ON public.itineraries;
CREATE POLICY "Public can delete itineraries" ON public.itineraries FOR DELETE USING (TRUE);

-- Daily Schedules: Allow viewing and managing daily schedules
DROP POLICY IF EXISTS "Users can view daily schedules of accessible itineraries" ON public.daily_schedules;
DROP POLICY IF EXISTS "Public can view daily schedules" ON public.daily_schedules;
CREATE POLICY "Public can view daily schedules" ON public.daily_schedules FOR SELECT USING (TRUE);

DROP POLICY IF EXISTS "Users can insert daily schedules of own itineraries" ON public.daily_schedules;
DROP POLICY IF EXISTS "Public can insert daily schedules" ON public.daily_schedules;
CREATE POLICY "Public can insert daily schedules" ON public.daily_schedules FOR INSERT WITH CHECK (TRUE);

DROP POLICY IF EXISTS "Users can update daily schedules of own itineraries" ON public.daily_schedules;
DROP POLICY IF EXISTS "Public can update daily schedules" ON public.daily_schedules;
CREATE POLICY "Public can update daily schedules" ON public.daily_schedules FOR UPDATE USING (TRUE);

DROP POLICY IF EXISTS "Users can delete daily schedules of own itineraries" ON public.daily_schedules;
DROP POLICY IF EXISTS "Public can delete daily schedules" ON public.daily_schedules;
CREATE POLICY "Public can delete daily schedules" ON public.daily_schedules FOR DELETE USING (TRUE);

-- Itinerary Stops: Allow viewing and managing scheduled stops
DROP POLICY IF EXISTS "Users can view stops of accessible itineraries" ON public.itinerary_stops;
DROP POLICY IF EXISTS "Public can view stops" ON public.itinerary_stops;
CREATE POLICY "Public can view stops" ON public.itinerary_stops FOR SELECT USING (TRUE);

DROP POLICY IF EXISTS "Users can insert stops of own itineraries" ON public.itinerary_stops;
DROP POLICY IF EXISTS "Public can insert stops" ON public.itinerary_stops FOR INSERT WITH CHECK (TRUE);

DROP POLICY IF EXISTS "Users can update stops of own itineraries" ON public.itinerary_stops;
DROP POLICY IF EXISTS "Public can update stops" ON public.itinerary_stops FOR UPDATE USING (TRUE);

DROP POLICY IF EXISTS "Users can delete stops of own itineraries" ON public.itinerary_stops;
DROP POLICY IF EXISTS "Public can delete stops" ON public.itinerary_stops FOR DELETE USING (TRUE);

-- Places: Anyone can view cached places (authenticated or anon)
CREATE POLICY "Public read for places"
    ON public.places FOR SELECT
    USING (TRUE);

DROP POLICY IF EXISTS "Authenticated users can insert/cache places" ON public.places;
DROP POLICY IF EXISTS "Public can insert/cache places" ON public.places;
CREATE POLICY "Public can insert/cache places"
    ON public.places FOR INSERT
    WITH CHECK (TRUE);

DROP POLICY IF EXISTS "Public can update places" ON public.places;
CREATE POLICY "Public can update places"
    ON public.places FOR UPDATE
    USING (TRUE);

ALTER TABLE public.indoor_places DISABLE ROW LEVEL SECURITY;
ALTER TABLE public.outdoor_places DISABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Public read for indoor places" ON public.indoor_places;
DROP POLICY IF EXISTS "Public can manage indoor places" ON public.indoor_places;
CREATE POLICY "Public can manage indoor places"
    ON public.indoor_places FOR ALL
    USING (TRUE)
    WITH CHECK (TRUE);

DROP POLICY IF EXISTS "Public read for outdoor places" ON public.outdoor_places;
DROP POLICY IF EXISTS "Public can manage outdoor places" ON public.outdoor_places;
CREATE POLICY "Public can manage outdoor places"
    ON public.outdoor_places FOR ALL
    USING (TRUE)
    WITH CHECK (TRUE);

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
$$ LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS trg_sync_indoor_outdoor_subtables ON public.places;
CREATE TRIGGER trg_sync_indoor_outdoor_subtables
AFTER INSERT OR UPDATE OF is_indoor ON public.places
FOR EACH ROW
EXECUTE FUNCTION public.sync_indoor_outdoor_subtables();

-- Assistant Messages: Allow reading and logging AI chats
DROP POLICY IF EXISTS "Users can view own chat messages" ON public.assistant_messages;
DROP POLICY IF EXISTS "Public can view assistant messages" ON public.assistant_messages;
CREATE POLICY "Public can view assistant messages" ON public.assistant_messages FOR SELECT USING (TRUE);

DROP POLICY IF EXISTS "Users can insert own chat messages" ON public.assistant_messages;
DROP POLICY IF EXISTS "Public can insert assistant messages" ON public.assistant_messages;
CREATE POLICY "Public can insert assistant messages" ON public.assistant_messages FOR INSERT WITH CHECK (TRUE);

-- Weather Forecasts: Allow viewing and caching daily weather snapshots
DROP POLICY IF EXISTS "Users can view weather forecasts" ON public.weather_forecasts;
DROP POLICY IF EXISTS "Public can view weather forecasts" ON public.weather_forecasts;
CREATE POLICY "Public can view weather forecasts" ON public.weather_forecasts FOR SELECT USING (TRUE);

DROP POLICY IF EXISTS "Users can insert weather forecasts" ON public.weather_forecasts;
DROP POLICY IF EXISTS "Public can insert weather forecasts" ON public.weather_forecasts;
CREATE POLICY "Public can insert weather forecasts" ON public.weather_forecasts FOR INSERT WITH CHECK (TRUE);

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
