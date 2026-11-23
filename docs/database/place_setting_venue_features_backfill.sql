-- Preview the next batch, then set apply_changes to true to save it.
-- Only clear venue features qualify. Existing labels are preserved.
WITH options AS (
  SELECT false AS apply_changes
), pending AS (
  SELECT place_id, name, state, category, lower(btrim(name)) AS venue_name
  FROM public.places
  WHERE is_indoor IS NULL
), features AS (
  SELECT *,
    (venue_name ~ '\m(mega[ -]?mall|hyper[ -]?mall|shopping gallery|convention cent(er|re)|performing arts cent(er|re)|planetarium|science cent(er|re)|indoor (play cent(er|re)|playground|theme[ -]?park))\M') AS indoor,
    (venue_name ~ '\m(recreational forest|forest reserve|forest eco park|eco forest park|taman eko[ -]rimba|hutan lipur|hutan rekreasi|hutan simpan|taman rimba)\M'
      OR venue_name ~ '\m(marine park|lake gardens?|nature reserve|wetlands|seafront promenade|waterfront promenade|mangrove (forest|park)|taman rekreasi|taman tasik)\M'
      OR venue_name ~ '\m(puncak gunung|puncak bukit|mountain trail|forest trail)\M'
      OR (venue_name ~ '\m(peak|summit)\M' AND venue_name ~ '\m(mount|bukit|gunung|hill|trail)\M')) AS outdoor
  FROM pending
  WHERE category <> 'Food'
    AND venue_name !~ '\m(resort|hotel|chalet|cafe|café|kopi|restaurant|makan|kedai|office|entrance|carpark|parking|outlet|shop|store|station|tower|pavilion|pondok|teratak|watsons|parkson|kiztopia|high cultured|padang bola)\M'
    AND venue_name !~ '[@|/]'
    AND venue_name NOT IN ('taman rekreasi')
), proposals AS (
  SELECT place_id, name, state, category, indoor AS is_indoor
  FROM features
  WHERE indoor <> outdoor
    AND (indoor OR category <> 'Shopping')
), applied AS (
  UPDATE public.places AS place
  SET is_indoor = proposal.is_indoor
  FROM proposals AS proposal, options
  WHERE options.apply_changes
    AND place.place_id = proposal.place_id
    AND place.name = proposal.name
    AND place.state = proposal.state
    AND place.category = proposal.category
    AND place.is_indoor IS NULL
  RETURNING place.place_id
)
SELECT count(*) AS proposed,
       count(*) FILTER (WHERE is_indoor) AS indoor,
       count(*) FILTER (WHERE NOT is_indoor) AS outdoor,
       (SELECT count(*) FROM applied) AS saved,
       (SELECT count(*) FROM pending) - (SELECT count(*) FROM applied) AS pending_after
FROM proposals;
