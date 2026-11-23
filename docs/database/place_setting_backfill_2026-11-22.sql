-- Review the returned rows in the Supabase SQL Editor. This run rolls back.
-- To apply the reviewed batch, change the final ROLLBACK to COMMIT and rerun.
-- Only rows still awaiting review and matching the saved identity are updated.

BEGIN;

WITH reviewed(place_id, state, name, is_indoor, source_url) AS (
  VALUES
    ('ChIJJSAtCNNJzDERETbGF9iz7CI', 'Kuala Lumpur', 'Muzium Telekom', true,
     'https://www.malaysia.travel/explore/telekom-museum'),
    ('ChIJfdXRW9zx0TER8SK9p2bE-kg', 'Melaka', 'Baba & Nyonya Heritage Museum', true,
     'https://www.visitmelaka.com.my/index.php/culture-heritagemenu/heritage/49-baba-nyonya-heritage-museum'),
    ('ChIJVVWFJdzx0TERMv7qo6qtDSQ', 'Melaka', 'Cheng Ho Cultural Museum, Malacca.', true,
     'https://www.visitmelaka.com.my/index.php/culture-heritagemenu/heritage/48-cheng-ho-cultural-museum'),
    ('ChIJiZjld97x0TER5GUuRxTpMQc', 'Melaka', 'The History and Ethnography Museum', true,
     'https://visitmelaka.com.my/index.php/culture-heritagemenu/history'),
    ('ChIJkfbISQDDSjARrJVBVNxII7g', 'Penang', 'Penang Ferry Museum', true,
     'https://mypenang.gov.my/view_directory.php?id=Y1ByZW12YzMreHpKcTNRTmNTZkFaQT09'),
    ('ChIJm1PqREbpSjARSxtx8fttmW8', 'Penang', 'Keracut Beach', false,
     'https://www.wildlife.gov.my/en/taman-negara-pulau-pinang/')
)
UPDATE public.places AS place
SET is_indoor = reviewed.is_indoor
FROM reviewed
WHERE place.place_id = reviewed.place_id
  AND place.state = reviewed.state
  AND place.name = reviewed.name
  AND place.is_indoor IS NULL
RETURNING place.place_id, place.state, place.name, place.is_indoor, reviewed.source_url;

ROLLBACK;
