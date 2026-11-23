  -- Run in the Supabase SQL Editor to preview places awaiting review.
  -- Set selected_state to a state name to review one destination at a time.
  -- Copy approved update_sql rows into a separate query to save their settings.
  -- Each update checks the saved name, state and ID, and preserves existing labels.

  WITH options AS (
    SELECT NULL::text AS selected_state
  ), unreviewed AS (
    SELECT p.place_id, p.state, p.name, p.category, p.user_ratings_total,
           count(*) OVER (PARTITION BY p.state) AS state_pending_count,
           lower(p.name) AS normalized_name
    FROM public.places AS p
    CROSS JOIN options AS o
    WHERE p.is_indoor IS NULL
      AND (o.selected_state IS NULL OR p.state = o.selected_state)
  ), matches AS (
    SELECT *,
           normalized_name ~ '\m(museum|muzium|aquarium)\M|\mshopping[ -]+mall\M'
             AS indoor_match,
           normalized_name ~ '\m(beach|pantai|waterfall)\M|\m(air[ -]+terjun|botanical[ -]+gardens?|national[ -]+park|hiking[ -]+trail)\M'
             AS outdoor_match,
         (normalized_name ~ '\m(resort|hotel|cafe|café|restaurant|office|department|board|entrance|ticket|parking|carpark|jetty|shop|store|mart|market|bazaar|bazaria|pasar|pasaraya|supermarket|hypermarket|petshop|pets|trading|rental)\M'
          OR normalized_name ~ '\m(open[ -]+air|shopping[ -]+cent(er|re)|clean[ -]?up)\M'
          OR normalized_name ~ '\m(lembaga|parkson)\M') AS mixed_use
    FROM unreviewed
  ), proposals AS (
    SELECT *, CASE
      WHEN mixed_use OR indoor_match = outdoor_match THEN NULL
      ELSE indoor_match
    END AS suggested_is_indoor
    FROM matches
  )
  SELECT state, state_pending_count, name, category, user_ratings_total, place_id,
         CASE WHEN suggested_is_indoor IS TRUE THEN 'Indoor'
              WHEN suggested_is_indoor IS FALSE THEN 'Outdoor'
              ELSE 'Needs venue review' END AS suggested_setting,
         CASE WHEN suggested_is_indoor IS NOT NULL THEN format(
           'UPDATE public.places SET is_indoor = %s WHERE place_id = %L AND state = %L AND name = %L AND is_indoor IS NULL RETURNING place_id, state, name, is_indoor;',
           suggested_is_indoor::text, place_id, state, name
         ) END AS update_sql
  FROM proposals
  ORDER BY (suggested_is_indoor IS NOT NULL) DESC,
           user_ratings_total DESC NULLS LAST, state, name, place_id
  LIMIT 200;
