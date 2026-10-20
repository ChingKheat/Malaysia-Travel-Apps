-- Requires the existing public.is_admin() helper. Safe to rerun.
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
