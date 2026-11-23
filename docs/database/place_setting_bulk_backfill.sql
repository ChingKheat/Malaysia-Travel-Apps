-- Preview the full NULL backlog in Supabase SQL Editor. The summary shows
-- pending, proposed, applied, and remaining counts by destination.
-- Review the proposals before setting apply_changes to true and rerunning.
-- The rules use the saved venue name and category. Unknown stays NULL.

WITH options AS (
  SELECT false AS apply_changes
), pending AS (
  SELECT place_id, state, name, category, lower(btrim(name)) AS venue_name
  FROM public.places
  WHERE is_indoor IS NULL
), evidence AS (
  SELECT *,
    CASE
      WHEN venue_name ~ '\mindoor[ -]+(playground|stadium|arena|sports[ -]+cent(er|re)|theme[ -]+park|karting|pool)\M'
        THEN 'Named indoor facility'
      WHEN venue_name ~ '\m(shopping[ -]+(mall|cent(er|re))|department[ -]+store|supermarket|hypermarket)\M'
        OR (category = 'Shopping' AND venue_name ~ '\mmall$')
        THEN 'Named shopping facility'
      WHEN venue_name ~ '\m(art[ -]+gallery|museum|muzium|library|cinema|theatre|theater)\M'
        THEN 'Named cultural venue'
    END AS indoor_reason,
    CASE
      WHEN venue_name ~ '\m(beach|pantai|waterfall|air[ -]+terjun)\M'
        THEN 'Named beach or waterfall'
      WHEN venue_name ~ '\m((national|nature|recreational|city)[ -]+park|botanic(al)?[ -]+gardens?|taman[ -]+botani)\M'
        THEN 'Named park or botanical garden'
      WHEN venue_name ~ '\m(hiking[ -]+trail|trailhead|campsite|campground|viewpoint|lookout[ -]+point)\M'
        THEN 'Named trail, campsite or lookout'
    END AS outdoor_reason,
    (venue_name ~ '\m(resort|hotel|chalet|cafe|café|restaurant|kedai|kopi|dining|office|board|corporation|lembaga|pejabat|surau)\M'
      OR venue_name ~ '\m(entrance|ticket|parking|carpark|jetty|herbarium|discovery|rooftop|tower|pavilion|winterland)\M'
      OR venue_name ~ '\m(market|bazaar|bazaria|pasar|pasaraya|petshop|pets|trading|rental|parkson|muji|padini|aquarium)\M'
      OR venue_name ~ '\m(open[ -]+air|food[ -]+truck|clean[ -]?up|department[ -]+of|taman[ -]+muzium)\M'
      OR venue_name ~ '\m(pedestrian[ -]+mall|(army|archaeological|archeology|living)[ -]+museum)\M'
      OR venue_name IN ('saved google place', 'incomplete import — needs review',
                       'kota johor lama museum', 'jugra insitu museum',
                       'petroleum museum miri', 'replica royal palace melawar (rembau museum)')
      OR venue_name ~ '(^|[[:space:]])(@|at|near)[[:space:]]') AS needs_review
  FROM pending
), proposals AS (
  SELECT place_id, state, name, category,
         indoor_reason IS NOT NULL AS is_indoor,
         coalesce(indoor_reason, outdoor_reason) AS reason
  FROM evidence
  WHERE NOT needs_review
    AND (indoor_reason IS NOT NULL) <> (outdoor_reason IS NOT NULL)
    AND category <> 'Food'
    AND (outdoor_reason IS NULL OR category <> 'Shopping')
), applied AS (
  UPDATE public.places AS place
  SET is_indoor = proposal.is_indoor
  FROM proposals AS proposal, options AS settings
  WHERE settings.apply_changes
    AND place.place_id = proposal.place_id
    AND place.state = proposal.state
    AND place.name = proposal.name
    AND place.category = proposal.category
    AND place.is_indoor IS NULL
  RETURNING place.place_id
), report AS (
  SELECT CASE WHEN grouping(p.state) = 1 THEN 0 ELSE 1 END AS sort_order,
         'Summary' AS section, coalesce(p.state, 'All destinations') AS state,
         NULL::text AS place_id, NULL::text AS name, NULL::text AS category,
         NULL::text AS suggested_setting, NULL::text AS reason,
         count(*)::int AS pending_before,
         count(proposal.place_id)::int AS proposed_count,
         count(proposal.place_id) FILTER (WHERE proposal.is_indoor)::int AS indoor_proposed,
         count(proposal.place_id) FILTER (WHERE NOT proposal.is_indoor)::int AS outdoor_proposed,
         count(saved.place_id)::int AS applied_count,
         (count(*) - count(saved.place_id))::int AS pending_after
  FROM pending AS p
  LEFT JOIN proposals AS proposal USING (place_id)
  LEFT JOIN applied AS saved USING (place_id)
  GROUP BY GROUPING SETS ((), (p.state))

  UNION ALL

  SELECT 2, 'Proposal', state, place_id, name, category,
         CASE WHEN is_indoor THEN 'Indoor' ELSE 'Outdoor' END, reason,
         NULL, NULL, NULL, NULL, NULL, NULL
  FROM proposals
)
SELECT section, state, place_id, name, category, suggested_setting, reason,
       pending_before, proposed_count, indoor_proposed, outdoor_proposed,
       applied_count, pending_after
FROM report
ORDER BY sort_order, state, name, place_id;
