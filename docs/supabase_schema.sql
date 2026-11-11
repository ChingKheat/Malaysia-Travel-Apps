-- SINGLE SOURCE OF TRUTH: structure recovery, not a production data repair script.
-- Requires Supabase Auth schemas/roles. No demo places or historical data cleanup.
-- Legacy duplicate subtype rows require docs/database/legacy_subtype_cleanup.sql first.
BEGIN;

-- 1. Tables, columns and constraints

CREATE EXTENSION IF NOT EXISTS "pgcrypto";

CREATE TABLE IF NOT EXISTS public.profiles (
    user_id UUID PRIMARY KEY,
    email VARCHAR(255) NOT NULL UNIQUE,
    full_name VARCHAR(150) NOT NULL,
    travel_preferences JSONB DEFAULT '[]'::jsonb,
    preferred_language VARCHAR(10) NOT NULL DEFAULT 'en',
    role VARCHAR(20) NOT NULL DEFAULT 'user',
    created_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc'::text, now())
);

ALTER TABLE public.profiles ADD COLUMN IF NOT EXISTS role VARCHAR(20) NOT NULL DEFAULT 'user';

DO $$ BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conrelid = 'public.profiles'::regclass AND conname = 'profiles_user_id_fkey') THEN
        ALTER TABLE public.profiles ADD CONSTRAINT profiles_user_id_fkey
          FOREIGN KEY (user_id) REFERENCES auth.users(id) ON DELETE CASCADE NOT VALID;
    END IF;
END $$;

CREATE TABLE IF NOT EXISTS public.places (
    place_id VARCHAR(255) PRIMARY KEY,
    name VARCHAR(255) NOT NULL,
    state VARCHAR(100) NOT NULL,
    category VARCHAR(100) NOT NULL,
    latitude DOUBLE PRECISION NOT NULL,
    longitude DOUBLE PRECISION NOT NULL,
    rating NUMERIC(3,2),
    photo_url TEXT, -- App-owned images only; always NULL for Google references
    operating_hours JSONB,
    is_indoor BOOLEAN, -- TRUE = indoor, FALSE = outdoor, NULL = unassigned / needs manual review
    user_ratings_total INTEGER DEFAULT 0
);

ALTER TABLE public.places ADD COLUMN IF NOT EXISTS is_indoor BOOLEAN;

ALTER TABLE public.places ADD COLUMN IF NOT EXISTS user_ratings_total INTEGER DEFAULT 0;
ALTER TABLE public.places ADD COLUMN IF NOT EXISTS google_fetched_at TIMESTAMPTZ;
ALTER TABLE public.places ADD COLUMN IF NOT EXISTS google_attributions JSONB NOT NULL DEFAULT '[]'::jsonb;

CREATE TABLE IF NOT EXISTS public.indoor_places (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    place_id VARCHAR(255) NOT NULL UNIQUE REFERENCES public.places(place_id) ON DELETE CASCADE,
    is_air_conditioned BOOLEAN NOT NULL DEFAULT TRUE,
    max_capacity INTEGER
);

CREATE TABLE IF NOT EXISTS public.outdoor_places (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    place_id VARCHAR(255) NOT NULL UNIQUE REFERENCES public.places(place_id) ON DELETE CASCADE,
    is_rain_sensitive BOOLEAN NOT NULL DEFAULT TRUE,
    weather_condition VARCHAR(100)
);

CREATE SCHEMA IF NOT EXISTS recovery;

CREATE TABLE IF NOT EXISTS recovery.place_subtype_duplicates (
    source_table TEXT NOT NULL,
    original_id TEXT NOT NULL,
    snapshot_hash TEXT NOT NULL,
    row_data JSONB NOT NULL,
    archived_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    PRIMARY KEY (source_table, original_id, snapshot_hash)
);

CREATE TABLE IF NOT EXISTS public.itineraries (
    itinerary_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES public.profiles(user_id) ON DELETE CASCADE,
    title VARCHAR(200) NOT NULL,
    destination_state VARCHAR(100) NOT NULL,
    total_cost NUMERIC(10,2) NOT NULL DEFAULT 0.00,
    is_public BOOLEAN NOT NULL DEFAULT FALSE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc'::text, now())
);

CREATE TABLE IF NOT EXISTS public.daily_schedules (
    schedule_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    itinerary_id UUID NOT NULL REFERENCES public.itineraries(itinerary_id) ON DELETE CASCADE,
    day_number INTEGER NOT NULL,
    schedule_date DATE NOT NULL,
    total_distance_km NUMERIC(6,2) NOT NULL DEFAULT 0.00
);

CREATE TABLE IF NOT EXISTS public.itinerary_stops (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    schedule_id UUID NOT NULL REFERENCES public.daily_schedules(schedule_id) ON DELETE CASCADE,
    place_id VARCHAR(255) NOT NULL REFERENCES public.places(place_id) ON DELETE CASCADE,
    stop_order INTEGER NOT NULL,
    arrival_time TIME NOT NULL,
    departure_time TIME NOT NULL,
    is_visited BOOLEAN NOT NULL DEFAULT FALSE
);

CREATE TABLE IF NOT EXISTS public.weather_forecasts (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    itinerary_id UUID NOT NULL REFERENCES public.itineraries(itinerary_id) ON DELETE CASCADE,
    location_state VARCHAR(100) NOT NULL,
    schedule_date DATE NOT NULL,
    condition VARCHAR(100) NOT NULL,
    rain_probability NUMERIC(5,2) NOT NULL
);

CREATE TABLE IF NOT EXISTS public.assistant_messages (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES public.profiles(user_id) ON DELETE CASCADE,
    user_prompt TEXT NOT NULL,
    ai_response TEXT NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc'::text, now())
);

CREATE TABLE IF NOT EXISTS public.place_sync_status (
    state VARCHAR(100) PRIMARY KEY CHECK (length(btrim(state)) > 0),
    last_synced_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    place_count INTEGER NOT NULL CHECK (place_count >= 0),
    request_count INTEGER NOT NULL CHECK (request_count >= 0)
);

ALTER TABLE public.itineraries ADD COLUMN IF NOT EXISTS preferences JSONB NOT NULL DEFAULT '{}'::jsonb;

ALTER TABLE public.itinerary_stops ADD COLUMN IF NOT EXISTS stop_data JSONB NOT NULL DEFAULT '{}'::jsonb;

ALTER TABLE public.places ADD COLUMN IF NOT EXISTS data_source TEXT NOT NULL DEFAULT 'local';

CREATE TABLE IF NOT EXISTS public.google_api_budgets (
  sku TEXT NOT NULL CHECK (sku IN ('text_search_pro','details_pro','details_enterprise','photos','routes_essentials','route_matrix_essentials')),
  billing_month DATE NOT NULL CHECK (extract(day FROM billing_month)=1),
  request_limit INTEGER NOT NULL DEFAULT 0 CHECK (request_limit>=0 AND request_limit <= CASE
    WHEN sku IN ('text_search_pro','details_pro') THEN 4000
    WHEN sku IN ('details_enterprise','photos') THEN 800 ELSE 8000 END),
  baseline_usage INTEGER NOT NULL DEFAULT 0 CHECK (baseline_usage>=0),
  used_units INTEGER NOT NULL DEFAULT 0 CHECK (used_units>=0),
  verified_at TIMESTAMPTZ,
  valid_until TIMESTAMPTZ,
  enabled BOOLEAN NOT NULL DEFAULT FALSE,
  PRIMARY KEY (sku,billing_month)
);

CREATE TABLE IF NOT EXISTS public.landmark_catalogue (
  id TEXT PRIMARY KEY,name TEXT NOT NULL,aliases TEXT[] NOT NULL DEFAULT '{}',
  description TEXT NOT NULL,category TEXT NOT NULL DEFAULT 'landmark',address TEXT,
  latitude DOUBLE PRECISION,longitude DOUBLE PRECISION,opening_hours TEXT,
  estimated_visit_minutes INTEGER,estimated_cost_myr NUMERIC(10,2),image_url TEXT,source_url TEXT,
  status TEXT NOT NULL DEFAULT 'draft' CHECK(status IN ('draft','published','archived')),
  last_verified_at DATE,created_at TIMESTAMPTZ NOT NULL DEFAULT now(),updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.food_catalogue (
  id TEXT PRIMARY KEY,name TEXT NOT NULL,aliases TEXT[] NOT NULL DEFAULT '{}',description TEXT NOT NULL,
  visual_cues TEXT,typical_area TEXT,image_url TEXT,source_url TEXT,
  status TEXT NOT NULL DEFAULT 'draft' CHECK(status IN ('draft','published','archived')),
  last_verified_at DATE,created_at TIMESTAMPTZ NOT NULL DEFAULT now(),updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.recognition_history (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  input_type TEXT NOT NULL CHECK(input_type IN ('camera','gallery','demo')),image_path TEXT,
  detected_type TEXT CHECK(detected_type IN ('landmark','food','unknown')),detected_name TEXT,
  confidence NUMERIC(5,4),catalogue_id TEXT,result_payload JSONB NOT NULL DEFAULT '{}',created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- 2. Indexes

CREATE UNIQUE INDEX IF NOT EXISTS idx_unique_indoor_place_id ON public.indoor_places(place_id);

CREATE UNIQUE INDEX IF NOT EXISTS idx_unique_outdoor_place_id ON public.outdoor_places(place_id);

CREATE INDEX IF NOT EXISTS idx_itineraries_user_id ON public.itineraries(user_id);

CREATE INDEX IF NOT EXISTS idx_daily_schedules_itinerary_id ON public.daily_schedules(itinerary_id);

CREATE INDEX IF NOT EXISTS idx_itinerary_stops_schedule_id ON public.itinerary_stops(schedule_id);

CREATE INDEX IF NOT EXISTS idx_places_state ON public.places(state);

CREATE INDEX IF NOT EXISTS idx_places_category ON public.places(category);

CREATE INDEX IF NOT EXISTS idx_weather_forecasts_itinerary_id ON public.weather_forecasts(itinerary_id);

CREATE INDEX IF NOT EXISTS idx_assistant_messages_user_id ON public.assistant_messages(user_id);

-- 3. Functions

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

CREATE OR REPLACE FUNCTION public.is_admin() RETURNS boolean
LANGUAGE sql STABLE SECURITY DEFINER SET search_path = public, pg_temp AS $$
 SELECT EXISTS (SELECT 1 FROM public.profiles WHERE user_id = auth.uid() AND role = 'admin');
$$;

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

CREATE OR REPLACE FUNCTION public.protect_profile_role() RETURNS trigger
LANGUAGE plpgsql SET search_path = public, pg_temp AS $$
BEGIN
 IF auth.role() IN ('anon','authenticated') AND (
   (TG_OP = 'INSERT' AND NEW.role <> 'user') OR
   (TG_OP = 'UPDATE' AND (NEW.role IS DISTINCT FROM OLD.role OR NEW.user_id IS DISTINCT FROM OLD.user_id))
 ) THEN RAISE EXCEPTION 'Profile role and identity are managed by the server'; END IF;
 RETURN NEW;
END $$;

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
        DELETE FROM public.indoor_places WHERE place_id = NEW.place_id;
        DELETE FROM public.outdoor_places WHERE place_id = NEW.place_id;
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp;

CREATE OR REPLACE FUNCTION public.save_itinerary(payload jsonb) RETURNS uuid
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
DECLARE trip_id uuid := (payload->>'itinerary_id')::uuid;
        owner_id uuid := auth.uid(); d jsonb; st jsonb; day_id uuid;
BEGIN
 IF owner_id IS NULL OR owner_id <> (payload->>'user_id')::uuid THEN
   RAISE EXCEPTION 'Authentication required';
 END IF;
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

CREATE OR REPLACE FUNCTION public.sanitize_google_place_reference() RETURNS trigger
LANGUAGE plpgsql SECURITY INVOKER SET search_path = '' AS $$
BEGIN
  IF NEW.data_source = 'google' OR NEW.place_id LIKE 'ChI%'
     OR NEW.name = 'Saved Google place'
     OR NEW.photo_url LIKE '%places.googleapis.com%'
     OR (TG_OP = 'UPDATE' AND OLD.data_source = 'google') THEN
    NEW.data_source := 'google';
    -- Reject key-bearing or dynamic Google proxy URLs. Retain clean Supabase Storage or custom URLs.
    IF NEW.photo_url LIKE '%places.googleapis.com%' OR NEW.photo_url LIKE '%key=%' THEN
      NEW.photo_url := NULL;
    END IF;
    IF NEW.name <> 'Saved Google place' AND NEW.latitude BETWEEN 1 AND 7.5
       AND NEW.longitude BETWEEN 99 AND 120 THEN
      IF TG_OP = 'INSERT' THEN
        NEW.google_fetched_at := clock_timestamp();
      ELSIF NEW.name IS DISTINCT FROM OLD.name OR NEW.latitude IS DISTINCT FROM OLD.latitude
         OR NEW.longitude IS DISTINCT FROM OLD.longitude OR NEW.google_fetched_at IS DISTINCT FROM OLD.google_fetched_at THEN
        NEW.google_fetched_at := clock_timestamp();
      END IF;
    END IF;
    IF NEW.category NOT IN ('Attraction','Culture','Food','Nature','Shopping','History','Adventure','Family','Nightlife') THEN
      NEW.category := 'Attraction';
    END IF;
  END IF;
  RETURN NEW;
END $$;

CREATE OR REPLACE FUNCTION public.reserve_google_api_usage(p_sku TEXT,p_units INTEGER)
RETURNS BOOLEAN LANGUAGE plpgsql SECURITY INVOKER SET search_path = '' AS $$
BEGIN
  IF p_units IS NULL OR p_units<1 OR p_units>100 THEN RETURN FALSE; END IF;
  UPDATE public.google_api_budgets SET used_units=used_units+p_units
  WHERE sku=p_sku
    AND billing_month=date_trunc('month',now() AT TIME ZONE 'America/Los_Angeles')::date
    AND enabled AND verified_at IS NOT NULL AND verified_at<=now()
    AND verified_at >= (billing_month::timestamp AT TIME ZONE 'America/Los_Angeles')
    AND valid_until>now()
    AND valid_until <= ((billing_month+INTERVAL '1 month')::timestamp AT TIME ZONE 'America/Los_Angeles')
    AND baseline_usage::bigint+used_units::bigint+p_units<=request_limit;
  RETURN FOUND;
END $$;

CREATE OR REPLACE FUNCTION public.sanitize_google_itinerary_stop() RETURNS trigger
LANGUAGE plpgsql SECURITY INVOKER SET search_path = '' AS $$
DECLARE own_keys TEXT[] := ARRAY['place_id','id','schedule_id','stop_order','arrival_time','departure_time',
  'is_visited','time','duration','estimated_cost','visit_minutes','is_indoor','travel_minutes',
  'travel_cost','travel_is_estimated','data_source','user_note'];
  clean JSONB; snap JSONB;
BEGIN
  IF EXISTS(SELECT 1 FROM public.places WHERE place_id=NEW.place_id AND data_source='google') THEN
    SELECT COALESCE(jsonb_object_agg(key,value),'{}'::jsonb) INTO clean
      FROM jsonb_each(COALESCE(NEW.stop_data,'{}'::jsonb)) WHERE key=ANY(own_keys);
    SELECT COALESCE(jsonb_object_agg(key,value),'{}'::jsonb) INTO snap
      FROM jsonb_each(CASE WHEN jsonb_typeof(NEW.stop_data->'snapshot')='object'
        THEN NEW.stop_data->'snapshot' ELSE '{}'::jsonb END) WHERE key=ANY(own_keys);
    snap := snap || jsonb_build_object('place_id',NEW.place_id,'data_source','google',
      'title','Saved Google place','place_name','Saved Google place','category','Attraction',
      'latitude',0,'longitude',0,'opening_hours','Hours unverified',
      'description','Place details require an internet connection.',
      'photo_urls','[]'::jsonb,'tips','[]'::jsonb,'operating_hours','{}'::jsonb);
    NEW.stop_data := clean || jsonb_build_object('place_id',NEW.place_id,
      'data_source','google','place_name','Saved Google place','category','Attraction',
      'latitude',0,'longitude',0,'snapshot',snap);
  END IF;
  RETURN NEW;
END $$;

-- 4. Triggers

DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;

CREATE TRIGGER on_auth_user_created
    AFTER INSERT ON auth.users
    FOR EACH ROW EXECUTE FUNCTION public.handle_new_user();

DROP TRIGGER IF EXISTS protect_profile_role ON public.profiles;

CREATE TRIGGER protect_profile_role BEFORE INSERT OR UPDATE ON public.profiles
FOR EACH ROW EXECUTE FUNCTION public.protect_profile_role();

DROP TRIGGER IF EXISTS trg_sync_indoor_outdoor_subtables ON public.places;

CREATE TRIGGER trg_sync_indoor_outdoor_subtables
AFTER INSERT OR UPDATE OF is_indoor ON public.places
FOR EACH ROW
EXECUTE FUNCTION public.sync_indoor_outdoor_subtables();

DROP TRIGGER IF EXISTS sanitize_google_place_reference ON public.places;

CREATE TRIGGER sanitize_google_place_reference BEFORE INSERT OR UPDATE ON public.places
FOR EACH ROW EXECUTE FUNCTION public.sanitize_google_place_reference();

DROP TRIGGER IF EXISTS sanitize_google_itinerary_stop ON public.itinerary_stops;

CREATE TRIGGER sanitize_google_itinerary_stop BEFORE INSERT OR UPDATE ON public.itinerary_stops
FOR EACH ROW EXECUTE FUNCTION public.sanitize_google_itinerary_stop();

CREATE OR REPLACE VIEW public.places_directory WITH (security_invoker = true) AS
SELECT place_id, COALESCE(NULLIF(state,''),'待确认') AS state,
COALESCE(NULLIF(category,''),'待审核') AS category,
CASE WHEN is_indoor IS TRUE THEN '室内' WHEN is_indoor IS FALSE THEN '室外' ELSE '待审核' END AS setting,
CASE WHEN name='Saved Google place' THEN '等待 Google 资料同步'
ELSE COALESCE(NULLIF(name,''),'名称待补充') END AS display_label,
CASE WHEN latitude IS NULL OR longitude IS NULL OR (latitude=0 AND longitude=0) THEN '位置待确认'
ELSE '已有位置' END AS location_status
FROM public.places;
REVOKE ALL ON public.places_directory FROM PUBLIC, anon, authenticated;
GRANT SELECT ON public.places_directory TO authenticated, service_role;
COMMENT ON VIEW public.places_directory IS 'Readable catalog; live Google details are loaded in the app. Underlying places RLS applies.';

-- 5. Permissions and row-level policies

-- Explicit Data API privileges: recovery must not depend on Dashboard defaults.
GRANT USAGE ON SCHEMA public TO anon, authenticated, service_role;
GRANT SELECT ON public.places,public.indoor_places,public.outdoor_places,
 public.profiles,public.itineraries,public.daily_schedules,public.itinerary_stops,
 public.weather_forecasts,public.assistant_messages TO anon, authenticated;
GRANT INSERT,UPDATE,DELETE ON public.places,public.indoor_places,public.outdoor_places,
 public.itineraries,public.daily_schedules,public.itinerary_stops,public.weather_forecasts TO authenticated;
GRANT INSERT,UPDATE ON public.profiles TO authenticated;
GRANT INSERT ON public.assistant_messages TO authenticated;
GRANT ALL ON public.places,public.indoor_places,public.outdoor_places,public.profiles,
 public.itineraries,public.daily_schedules,public.itinerary_stops,public.weather_forecasts,
 public.assistant_messages,public.place_sync_status,public.landmark_catalogue,
 public.food_catalogue,public.recognition_history TO service_role;

REVOKE ALL ON SCHEMA recovery FROM PUBLIC, anon, authenticated;

REVOKE ALL ON recovery.place_subtype_duplicates FROM PUBLIC, anon, authenticated;

ALTER TABLE recovery.place_subtype_duplicates ENABLE ROW LEVEL SECURITY;

ALTER TABLE public.profiles ENABLE ROW LEVEL SECURITY;

ALTER TABLE public.itineraries ENABLE ROW LEVEL SECURITY;

ALTER TABLE public.daily_schedules ENABLE ROW LEVEL SECURITY;

ALTER TABLE public.itinerary_stops ENABLE ROW LEVEL SECURITY;

ALTER TABLE public.places ENABLE ROW LEVEL SECURITY;

ALTER TABLE public.indoor_places ENABLE ROW LEVEL SECURITY;

ALTER TABLE public.outdoor_places ENABLE ROW LEVEL SECURITY;

ALTER TABLE public.weather_forecasts ENABLE ROW LEVEL SECURITY;

ALTER TABLE public.assistant_messages ENABLE ROW LEVEL SECURITY;

DO $$ DECLARE p record; BEGIN
  FOR p IN SELECT schemaname, tablename, policyname FROM pg_policies
    WHERE schemaname = 'public' AND tablename IN
      ('profiles','itineraries','daily_schedules','itinerary_stops','places',
       'indoor_places','outdoor_places','weather_forecasts','assistant_messages')
  LOOP EXECUTE format('DROP POLICY IF EXISTS %I ON %I.%I',p.policyname,p.schemaname,p.tablename); END LOOP;
END $$;

REVOKE ALL ON FUNCTION public.is_admin() FROM PUBLIC;

GRANT EXECUTE ON FUNCTION public.is_admin() TO anon, authenticated;

ALTER TABLE public.place_sync_status ENABLE ROW LEVEL SECURITY;

REVOKE ALL ON public.place_sync_status FROM PUBLIC, anon, authenticated;

GRANT SELECT, INSERT, UPDATE ON public.place_sync_status TO authenticated;

DROP POLICY IF EXISTS place_sync_status_admin ON public.place_sync_status;

CREATE POLICY place_sync_status_admin ON public.place_sync_status
    FOR ALL TO authenticated
    USING ((SELECT public.is_admin())) WITH CHECK ((SELECT public.is_admin()));

REVOKE ALL ON FUNCTION public.record_place_sync(TEXT, INTEGER, INTEGER) FROM PUBLIC, anon;

GRANT EXECUTE ON FUNCTION public.record_place_sync(TEXT, INTEGER, INTEGER) TO authenticated;

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

REVOKE ALL ON FUNCTION public.save_itinerary(jsonb) FROM PUBLIC;

GRANT EXECUTE ON FUNCTION public.save_itinerary(jsonb) TO authenticated;

REVOKE ALL ON FUNCTION public.sanitize_google_place_reference() FROM PUBLIC, anon, authenticated;

ALTER TABLE public.google_api_budgets ENABLE ROW LEVEL SECURITY;

REVOKE ALL ON public.google_api_budgets FROM PUBLIC, anon, authenticated;

GRANT SELECT ON public.google_api_budgets TO authenticated;

GRANT SELECT,INSERT,UPDATE ON public.google_api_budgets TO service_role;

DROP POLICY IF EXISTS google_budgets_admin_read ON public.google_api_budgets;

CREATE POLICY google_budgets_admin_read ON public.google_api_budgets
FOR SELECT TO authenticated USING ((SELECT public.is_admin()));

REVOKE ALL ON FUNCTION public.reserve_google_api_usage(TEXT,INTEGER) FROM PUBLIC, anon, authenticated;

GRANT EXECUTE ON FUNCTION public.reserve_google_api_usage(TEXT,INTEGER) TO service_role;

REVOKE ALL ON FUNCTION public.handle_new_user() FROM PUBLIC, anon, authenticated;

REVOKE ALL ON FUNCTION public.sync_indoor_outdoor_subtables() FROM PUBLIC, anon, authenticated;

REVOKE ALL ON FUNCTION public.protect_profile_role() FROM PUBLIC, anon, authenticated;

REVOKE ALL ON FUNCTION public.is_admin() FROM anon;

REVOKE ALL ON FUNCTION public.save_itinerary(JSONB) FROM PUBLIC, anon;

GRANT EXECUTE ON FUNCTION public.save_itinerary(JSONB) TO authenticated;

ALTER TABLE public.landmark_catalogue ENABLE ROW LEVEL SECURITY;

ALTER TABLE public.food_catalogue ENABLE ROW LEVEL SECURITY;

ALTER TABLE public.recognition_history ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "published landmarks are readable" ON public.landmark_catalogue;

CREATE POLICY "published landmarks are readable" ON public.landmark_catalogue FOR SELECT TO authenticated USING(status='published');

DROP POLICY IF EXISTS "published foods are readable" ON public.food_catalogue;

CREATE POLICY "published foods are readable" ON public.food_catalogue FOR SELECT TO authenticated USING(status='published');

DROP POLICY IF EXISTS "users can read their own recognition history" ON public.recognition_history;

CREATE POLICY "users can read their own recognition history" ON public.recognition_history FOR SELECT TO authenticated USING((SELECT auth.uid())=user_id);

DROP POLICY IF EXISTS "users can create their own recognition history" ON public.recognition_history;

CREATE POLICY "users can create their own recognition history" ON public.recognition_history FOR INSERT TO authenticated WITH CHECK((SELECT auth.uid())=user_id);

GRANT SELECT ON public.landmark_catalogue,public.food_catalogue TO authenticated;

GRANT SELECT,INSERT ON public.recognition_history TO authenticated;

REVOKE ALL ON FUNCTION public.sanitize_google_itinerary_stop() FROM PUBLIC, anon, authenticated;

-- 6. Disabled allowance defaults (never resets existing usage)

INSERT INTO public.google_api_budgets(sku,billing_month,request_limit)
SELECT sku,date_trunc('month',now() AT TIME ZONE 'America/Los_Angeles')::date,cap
FROM (VALUES ('text_search_pro',4000),('details_pro',4000),
  ('details_enterprise',800),('photos',800),('routes_essentials',8000),
  ('route_matrix_essentials',8000)) AS defaults(sku,cap)
ON CONFLICT DO NOTHING;

-- 7. Supabase Storage: Public Bucket for Place Photos
INSERT INTO storage.buckets (id, name, public)
VALUES ('place-photos', 'place-photos', true)
ON CONFLICT (id) DO UPDATE SET public = true;

DO $$ BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_policies WHERE schemaname = 'storage' AND tablename = 'objects' AND policyname = 'Public Access for Place Photos'
  ) THEN
    CREATE POLICY "Public Access for Place Photos"
    ON storage.objects FOR SELECT
    USING (bucket_id = 'place-photos');
  END IF;
  IF NOT EXISTS (
    SELECT 1 FROM pg_policies WHERE schemaname = 'storage' AND tablename = 'objects' AND policyname = 'Allow Upload to Place Photos'
  ) THEN
    CREATE POLICY "Allow Upload to Place Photos"
    ON storage.objects FOR INSERT
    TO authenticated, service_role, anon
    WITH CHECK (bucket_id = 'place-photos');
  END IF;
  IF NOT EXISTS (
    SELECT 1 FROM pg_policies WHERE schemaname = 'storage' AND tablename = 'objects' AND policyname = 'Allow Update to Place Photos'
  ) THEN
    CREATE POLICY "Allow Update to Place Photos"
    ON storage.objects FOR UPDATE
    TO authenticated, service_role, anon
    USING (bucket_id = 'place-photos');
  END IF;
END $$;

COMMIT;
