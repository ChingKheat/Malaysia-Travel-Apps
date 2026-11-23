-- Live batch based on independent venue records and operator directories.
-- Only exact catalog matches still awaiting review are updated.
WITH verified(place_id, state, name, category, is_indoor, source_url) AS (
  VALUES
    ('ChIJt0xtwktz2jERRS2DKtCZfp0', 'Johor', 'ÆON Mall Bukit Indah', 'Shopping', true, 'https://aeonmallmy.com/page/home'),
    ('ChIJ2St8mxxu2jERTeACpDMGci4', 'Johor', 'AEON Mall Dato'' Onn Town', 'Shopping', true, 'https://aeonmallmy.com/page/home'),
    ('ChIJ0dhK26Fs2jERQRHi53-CWwc', 'Johor', 'AEON Mall Permas Jaya', 'Shopping', true, 'https://aeonmallmy.com/page/home'),
    ('ChIJsQTqQ11t2jERF_ULAhUiHKs', 'Johor', 'AEON Mall Tebrau City', 'Shopping', true, 'https://aeonmallmy.com/page/home'),
    ('ChIJH9Llir9y2jERFryY-pcx09Y', 'Johor', 'Angsana Johor Bahru Mall', 'Attraction', true, 'http://www.wikidata.org/entity/Q14473351'),
    ('ChIJj17Dt8IS2jERpo41GcSpoJE', 'Johor', 'GALLERIA@KOTARAYA', 'Shopping', true, 'http://www.wikidata.org/entity/Q95711073'),
    ('ChIJb-pU-W5t2jER2KyRwu_opLc', 'Johor', 'Holiday Plaza', 'Shopping', true, 'http://www.wikidata.org/entity/Q95676803'),
    ('ChIJe9c4GyBs2jERc0GAMX_D0Lc', 'Johor', 'IKEA Tebrau', 'Shopping', true, 'http://www.wikidata.org/entity/Q95676274'),
    ('ChIJZ6vyT8MS2jERZbHkx3oUHnQ', 'Johor', 'Johor Bahru City Square', 'Attraction', true, 'http://www.wikidata.org/entity/Q6268872'),
    ('ChIJIyLLVcMS2jER0xwvgEmFUk4', 'Johor', 'KOMTAR JBCC', 'Shopping', true, 'http://www.wikidata.org/entity/Q19840304'),
    ('ChIJIf-ff_9y2jERb19MfG9Nuw0', 'Johor', 'Paradigm Mall Johor Bahru', 'Attraction', true, 'http://www.wikidata.org/entity/Q61109487'),
    ('ChIJVYHWPTJt2jERwzbuMKY3FDQ', 'Johor', 'Paragon Market Place', 'Shopping', true, 'http://www.wikidata.org/entity/Q96619212'),
    ('ChIJozOVa_zI2jERXact62x_TI0', 'Johor', 'Pasir Tiang Berusong Besar', 'Nature', false, 'http://www.wikidata.org/entity/Q33329751'),
    ('ChIJMzC4uXVz2jERDMi3_zkpoB0', 'Johor', 'Tasek Central', 'Shopping', true, 'http://www.wikidata.org/entity/Q94670388'),
    ('ChIJtc_vgOFs2jERtTpxahI--kw', 'Johor', 'The Mall, Mid Valley Southkey', 'Attraction', true, 'http://www.wikidata.org/entity/Q65050183'),
    ('ChIJCdRS-Bx3TDAR0E8l7H26KJM', 'Kedah', 'Langkawi Craft Complex', 'Attraction', true, 'http://www.wikidata.org/entity/Q115396068'),
    ('ChIJH_SaK1hESzARb-DM5mQFu2k', 'Kedah', 'Mydin Mall Taman Saga, Alor Setar', 'Shopping', true, 'https://mydin.my/store-location/'),
    ('ChIJ18Ei9fjVSjARV1iipwUO0wo', 'Kedah', 'Mydin Taman Batik, Sungai Petani', 'Shopping', true, 'https://mydin.my/store-location/'),
    ('ChIJDetvNZOvtjERYI9DEER4m2s', 'Kelantan', 'ÆON Mall Kota Bharu', 'Shopping', true, 'https://aeonmallmy.com/page/home'),
    ('ChIJw6soFdbx0TERjNXnPt6ax80', 'Melaka', 'Mahkota Parade', 'Nightlife', true, 'http://www.wikidata.org/entity/Q3277764'),
    ('ChIJ0xT023Ll0TERb4kQN4vvAdk', 'Melaka', 'Mydin MITC Ayer Keroh', 'Nightlife', true, 'https://mydin.my/store-location/'),
    ('ChIJgah8Tx7u0TERsG1uMVUKSMU', 'Melaka', 'Proclamation of Independence Memorial', 'History', true, 'http://www.wikidata.org/entity/Q7386272'),
    ('ChIJ66_dAS_HzTERCsqE42E13uY', 'Negeri Sembilan', 'AEON MALL Nilai', 'Shopping', true, 'https://aeonmallmy.com/page/home'),
    ('ChIJl3dCKuvnzTERjsPXEP6qFXk', 'Negeri Sembilan', 'AEON Mall Seremban 2', 'Shopping', true, 'https://aeonmallmy.com/page/home'),
    ('ChIJzxprXr9pzjERw270pllcJDA', 'Negeri Sembilan', 'Lotus''s Bahau', 'Shopping', true, 'https://corp.lotuss.com.my/stores/store-locator'),
    ('ChIJU2bwn9huzjER8fnvikdBvRc', 'Negeri Sembilan', 'Teratak Za''ba', 'Culture', true, 'http://www.wikidata.org/entity/Q106532097'),
    ('ChIJBUGS-XrXzjERWPc7jrjAL4U', 'Pahang', 'Pasir Datuk', 'Nature', false, 'http://www.wikidata.org/entity/Q33328824'),
    ('ChIJJ765yjbISjARftvwF1hc4Io', 'Penang', 'AEON MALL Bukit Mertajam', 'Shopping', true, 'https://aeonmallmy.com/page/home'),
    ('ChIJs7Ms0R3tyjERlXknc_qhkh4', 'Perak', 'AEON Kinta City Ipoh', 'Shopping', true, 'https://aeonmallmy.com/page/home'),
    ('ChIJLcUk0q7pyjERwTcw38YrjBs', 'Perak', 'AEON Mall Ipoh Station 18', 'Shopping', true, 'https://aeonmallmy.com/page/home'),
    ('ChIJUw2YE6styzERNKfnnqTzfXQ', 'Perak', 'AEON Seri Manjung', 'Shopping', true, 'https://aeonmallmy.com/page/home'),
    ('ChIJ79sYUHzsyjERtPkfWlkqPSU', 'Perak', 'Han Chin Pet Soo', 'Attraction', true, 'http://www.wikidata.org/entity/Q22079917'),
    ('ChIJexNEPDjtyjERgZb_jf0yDCE', 'Perak', 'Ipoh Parade', 'Shopping', true, 'http://www.wikidata.org/entity/Q85769912'),
    ('ChIJybsZLLHTNDARZzDtrLWwir0', 'Perak', 'Pasir Bogak', 'Nature', false, 'http://www.wikidata.org/entity/Q33328696'),
    ('ChIJ76eeTcLTNDARm9gPpb8ugOQ', 'Perak', 'Pasir Ketapang', 'Nature', false, 'http://www.wikidata.org/entity/Q33329016'),
    ('ChIJh3-SrCvFODIRuCIa5kDztis', 'Sabah', 'Agnes Keith House', 'Culture', true, 'http://www.wikidata.org/entity/Q64615217'),
    ('ChIJl47lj5NpOzIRWdYgNk33guk', 'Sabah', 'Oceanus Waterfront Mall', 'Attraction', true, 'http://www.wikidata.org/entity/Q28219551'),
    ('ChIJZzdhHIZpOzIRr_9CABl11w8', 'Sabah', 'Suria Sabah', 'Attraction', true, 'http://www.wikidata.org/entity/Q12496276'),
    ('ChIJcyR-UI9pOzIRZMlZt7wUqik', 'Sabah', 'Wisma Merdeka', 'Shopping', true, 'http://www.wikidata.org/entity/Q28219535'),
    ('ChIJSaiwZHun-zERqaT-wcKEGOU', 'Sarawak', 'AEON Mall Kuching Central', 'Shopping', true, 'https://aeonmallmy.com/page/home'),
    ('ChIJ1wle21gA-zERGs0NNqRNPEA', 'Sarawak', 'Pasir Sengki', 'Nature', false, 'http://www.wikidata.org/entity/Q33329492'),
    ('ChIJ-RCB3RtTzDERgjFNARnOeLg', 'Selangor', 'ÆON Mall Bukit Raja', 'Shopping', true, 'https://aeonmallmy.com/page/home'),
    ('ChIJh-JZSc00zDERXdQzHBRaqy8', 'Selangor', 'AEON Mall Cheras Selatan', 'Shopping', true, 'https://aeonmallmy.com/page/home'),
    ('ChIJh-4j0IlDzDERlED_h9E2NiU', 'Selangor', 'AEON Mall Rawang', 'Shopping', true, 'https://aeonmallmy.com/page/home'),
    ('ChIJ5U48LKBNzDER-vfQfcuk_44', 'Selangor', 'AEON Mall Shah Alam', 'Shopping', true, 'https://aeonmallmy.com/page/home'),
    ('ChIJURCa6nxPzDERIbpqvPUmBMw', 'Selangor', 'IOI Mall Damansara', 'Attraction', true, 'http://www.wikidata.org/entity/Q139577774'),
    ('ChIJBUOBtYLLzTER5_Zo3qj_voE', 'Selangor', 'Kajang Heritage Centre', 'Culture', true, 'http://www.wikidata.org/entity/Q116614792'),
    ('ChIJH4fKE1tMzDERdH2TyRMZgSY', 'Selangor', 'Subang Parade', 'Shopping', true, 'http://www.wikidata.org/entity/Q7442496'),
    ('ChIJJwdomU5TzDERLuRfw43IhXs', 'Selangor', 'Sultan Abdul Aziz Royal Gallery', 'Attraction', true, 'http://www.wikidata.org/entity/Q27526877'),
    ('ChIJ2R7lHxO8tzERyX-TSBViH4s', 'Terengganu', 'Mydin Mall Gong Badak', 'Shopping', true, 'https://mydin.my/store-location/')
), applied AS (
  UPDATE public.places AS place
  SET is_indoor = verified.is_indoor
  FROM verified
  WHERE place.place_id = verified.place_id
    AND place.state = verified.state
    AND place.name = verified.name
    AND place.category = verified.category
    AND place.is_indoor IS NULL
  RETURNING place.place_id, place.is_indoor
)
SELECT count(*) AS places_updated,
       count(*) FILTER (WHERE is_indoor IS TRUE) AS indoor_added,
       count(*) FILTER (WHERE is_indoor IS FALSE) AS outdoor_added
FROM applied;
