BEGIN;
-- Independently sourced browsing catalog; no Google content is promoted automatically.
ALTER TABLE public.places ADD COLUMN IF NOT EXISTS catalog_status TEXT NOT NULL DEFAULT 'draft';
ALTER TABLE public.places ADD COLUMN IF NOT EXISTS catalog_source_url TEXT;
ALTER TABLE public.places ADD COLUMN IF NOT EXISTS catalog_license TEXT;
ALTER TABLE public.places ADD COLUMN IF NOT EXISTS catalog_verified_at TIMESTAMPTZ;
ALTER TABLE public.places DROP CONSTRAINT IF EXISTS places_catalog_publication;
ALTER TABLE public.places ADD CONSTRAINT places_catalog_publication CHECK (
  catalog_status IN ('draft','published','archived') AND
  (catalog_status <> 'published' OR (
    data_source <> 'google' AND place_id NOT LIKE 'ChI%' AND name <> 'Saved Google place'
    AND length(btrim(name)) > 0 AND length(btrim(category)) > 0
    AND latitude BETWEEN 1 AND 7.5 AND longitude BETWEEN 99 AND 120
    AND catalog_source_url IS NOT NULL AND catalog_license IS NOT NULL
    AND catalog_source_url LIKE 'https://%' AND length(btrim(catalog_license)) > 0
    AND catalog_verified_at IS NOT NULL
  ))
);
CREATE INDEX IF NOT EXISTS places_published_state_id ON public.places(state,place_id)
  WHERE catalog_status='published' AND data_source<>'google';
COMMIT;
