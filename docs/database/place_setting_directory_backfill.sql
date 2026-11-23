-- Exact venue matches from official directories and operator records.
-- PriceCatcher data: KPDN and DOSM, CC BY 4.0 (source link on matched records).
-- Only still-pending rows matching the original identity can be saved.
WITH directory(place_id, state, name, category, is_indoor, source_url) AS (
  VALUES
    ('ChIJa8ez_XNs2jERpAWJ1R4yCkU', 'Johor', 'Giant Plentong', 'Shopping', true, 'https://data.gov.my/data-catalogue/lookup_premise'),
    ('ChIJI7aTNBBt2jERdDB_6OAW4AA', 'Johor', 'Giant Southern City', 'Shopping', true, 'https://data.gov.my/data-catalogue/lookup_premise'),
    ('ChIJS_6J4ety2jERND5yrP9bvzw', 'Johor', 'Giant Tampoi', 'Shopping', true, 'https://data.gov.my/data-catalogue/lookup_premise'),
    ('ChIJ1zoucoF02jERpTKyfB53KZo', 'Johor', 'HUTAN BANDAR MUTIARA RINI', 'Attraction', false, 'https://www.kpkt.gov.my/kpkt/resources/user_1/GALERI/PDF_PENERBITAN/PERANGKAAN%20TERPILIH/STATISTIK_KPKT_2024.pdf'),
    ('ChIJozbkb1Ft2jEREXQ1a2CSNdM', 'Johor', 'Merdeka Park', 'Attraction', false, 'https://www.kpkt.gov.my/kpkt/resources/user_1/GALERI/PDF_PENERBITAN/PERANGKAAN%20TERPILIH/STATISTIK_KPKT_2024.pdf'),
    ('ChIJpVPFCIB02jERXBE7MyhFWgU', 'Johor', 'Mydin Mall Mutiara Rini', 'Shopping', true, 'https://data.gov.my/data-catalogue/lookup_premise'),
    ('ChIJEVipoi1t2jERSAPBSPOsOpg', 'Johor', 'Plaza Pelangi', 'Shopping', true, 'https://www.ppkm.org.my/site/wp-content/uploads/2024/10/PPK-News-Network-63-September_2024.pdf'),
    ('ChIJMzH2uxlt2jERsbV0ysTBI8Q', 'Johor', 'SOGO Johor Bahru', 'Shopping', true, 'https://www.sogo.com.my/pages/contact'),
    ('ChIJPwYy4pmp0DERYKMsH1j5qZ4', 'Johor', 'Taman Negara Johor Tanjung Piai', 'Attraction', false, 'https://johornationalparks.gov.my/tanjung-piai/'),
    ('ChIJ8YYFyq-p0DERuL713yfGZWQ', 'Johor', 'Tanjung Piai Southern Tip of Mainland Eurasia', 'Culture', false, 'https://johornationalparks.gov.my/tanjung-piai/'),
    ('ChIJpRemiblESzARdkytmmL-ofQ', 'Kedah', 'Aman Central', 'Shopping', true, 'https://www.ppkm.org.my/site/wp-content/uploads/2024/10/PPK-News-Network-63-September_2024.pdf'),
    ('ChIJlVcoQO5FSzARIvqm6y3X3JE', 'Kedah', 'C-Mart Ampang Business Centre, Alor Setar', 'Shopping', true, 'https://data.gov.my/data-catalogue/lookup_premise'),
    ('ChIJHRM2s58pSzARnAhIXKvtoB0', 'Kedah', 'C-Mart Premium @ Amanjaya Mall', 'Shopping', true, 'https://data.gov.my/data-catalogue/lookup_premise'),
    ('ChIJm3kMz7d7TDAR9fwf06pgbGs', 'Kedah', 'Public Gardens Teluk Yu', 'Nature', false, 'https://www.kpkt.gov.my/kpkt/resources/user_1/GALERI/PDF_PENERBITAN/PERANGKAAN%20TERPILIH/STATISTIK_KPKT_2024.pdf'),
    ('ChIJzWDXfXxDSzARRyCKLw-faMA', 'Kedah', 'Taman Peremba, Alor Setar', 'Family', false, 'https://www.kpkt.gov.my/kpkt/resources/user_1/GALERI/PDF_PENERBITAN/PERANGKAAN%20TERPILIH/STATISTIK_KPKT_2024.pdf'),
    ('ChIJwWqJftmHSzAREAOCfNyMmHA', 'Kedah', 'Underwater World Langkawi', 'Family', true, 'https://underwaterworldlangkawi.com/'),
    ('ChIJVaPO0foYIzIR_w82FVCT51o', 'Labuan', 'Financial Park Complex Labuan', 'Shopping', true, 'https://www.ppkm.org.my/site/wp-content/uploads/2024/10/PPK-News-Network-63-September_2024.pdf'),
    ('ChIJHU_fVs_dzTERTzvSIRlJqs8', 'Negeri Sembilan', 'Family Store Sikamat', 'Shopping', true, 'https://data.gov.my/data-catalogue/lookup_premise'),
    ('ChIJBwvNbLTgzTERH8BJE0S4qmQ', 'Negeri Sembilan', 'Giant Senawang', 'Shopping', true, 'https://data.gov.my/data-catalogue/lookup_premise'),
    ('ChIJN7EK_JLGzTERZxVcqpdLtwQ', 'Negeri Sembilan', 'MesaMall', 'Shopping', true, 'https://www.ppkm.org.my/site/wp-content/uploads/2024/10/PPK-News-Network-63-September_2024.pdf'),
    ('ChIJOzXLK7XgzTERvzOV1IR_vWI', 'Negeri Sembilan', 'Mydin Mall Senawang', 'Shopping', true, 'https://data.gov.my/data-catalogue/lookup_premise'),
    ('ChIJoVUjycPnzTERFs8XZQ-ej2w', 'Negeri Sembilan', 'Mydin Mall Seremban 2', 'Shopping', true, 'https://data.gov.my/data-catalogue/lookup_premise'),
    ('ChIJmwiZg3-7yDEREO95KCC8QEc', 'Pahang', 'Kuantan Parade', 'Shopping', true, 'https://www.ppkm.org.my/site/wp-content/uploads/2024/10/PPK-News-Network-63-September_2024.pdf'),
    ('ChIJKbnWeSsKzzER1SFuM4tBkCA', 'Pahang', 'Pasaraya Gemilang Muadzam Sdn Bhd', 'Shopping', true, 'https://data.gov.my/data-catalogue/lookup_premise'),
    ('ChIJB2H3jMe7yDERIEk35CDHn-s', 'Pahang', 'TMG Mall Bandar Indera Mahkota', 'Shopping', true, 'https://data.gov.my/data-catalogue/lookup_premise'),
    ('ChIJkeyWM2rASjARicsI_i0aHtY', 'Penang', 'Sunshine Square', 'Shopping', true, 'https://data.gov.my/data-catalogue/lookup_premise'),
    ('ChIJe3IB0ZbsyjERg5spuuLsvEs', 'Perak', 'Gunung Lang', 'Adventure', false, 'https://www.mbi.gov.my/rekreasi/taman-rekreasi-gunung-lang'),
    ('ChIJ0ShXuMbtyjERwEIuzJpv7QQ', 'Perak', 'Gunung Lang Community Park', 'Attraction', false, 'https://www.mbi.gov.my/rekreasi/taman-rekreasi-gunung-lang'),
    ('ChIJgW014nyTyjERniPKVLArIEU', 'Perak', 'Mydin Mall Meru Raya', 'Shopping', true, 'https://data.gov.my/data-catalogue/lookup_premise'),
    ('ChIJD98sC7muyjERUb8s6sDFSi8', 'Perak', 'The Store Kamunting', 'Shopping', true, 'https://data.gov.my/data-catalogue/lookup_premise'),
    ('ChIJD_5olQQVyzERfSfLlexvQgk', 'Perak', 'The Store Teluk Intan', 'Shopping', true, 'https://data.gov.my/data-catalogue/lookup_premise'),
    ('ChIJ-YqL_ISbTDARhGDZJ4uBiFA', 'Perlis', 'Pasaraya Seri Utama Kuala Perlis', 'Attraction', true, 'https://data.gov.my/data-catalogue/lookup_premise'),
    ('ChIJxaW83GqZTDARUEiydHGp6ko', 'Perlis', 'Taman Bukit Lagi, Perlis', 'Attraction', false, 'https://www.kpkt.gov.my/kpkt/resources/user_1/GALERI/PDF_PENERBITAN/PERANGKAAN%20TERPILIH/STATISTIK_KPKT_2024.pdf'),
    ('ChIJqZXGIG5rOzIRhZnlYt3bFv4', 'Sabah', 'Aquarium & Marine Museum, Universiti Malaysia Sabah, Kota Kinabalu, Sabah.', 'Culture', true, 'https://www.ums.edu.my/v6/index.php/museum-gallery'),
    ('ChIJkce5cZFpOzIRjIoLqYz9yDE', 'Sabah', 'Centre Point Sabah', 'Attraction', true, 'https://www.ppkm.org.my/site/wp-content/uploads/2024/10/PPK-News-Network-63-September_2024.pdf'),
    ('ChIJ67qB8y7FODIRTSid5jAJRTY', 'Sabah', 'Harbour Mall Sandakan', 'Shopping', true, 'https://www.ppkm.org.my/site/wp-content/uploads/2024/10/PPK-News-Network-63-September_2024.pdf'),
    ('ChIJVf9vNQCZOzIR_lqlC8VrqYk', 'Sabah', 'Mount Kinabalu Park', 'Attraction', false, 'https://www.sabahparks.org.my/'),
    ('ChIJ44ErJFVVIzIRghYu9M2aOBw', 'Sabah', 'Pulau Tiga Park Malaysia', 'Attraction', false, 'https://www.sabahparks.org.my/'),
    ('ChIJKTb6OxWh-zERqTu8tWZFcqI', 'Sarawak', 'Farley Kuching', 'Attraction', true, 'https://data.gov.my/data-catalogue/lookup_premise'),
    ('ChIJncmJ0WeA9zERF1DV0AvSAow', 'Sarawak', 'Taman Awam Sibu', 'Family', false, 'https://www.kpkt.gov.my/kpkt/resources/user_1/GALERI/PDF_PENERBITAN/PERANGKAAN%20TERPILIH/STATISTIK_KPKT_2024.pdf'),
    ('ChIJxV2SUPtSzDERQ4GW7znn1UY', 'Selangor', 'Central i-City', 'Shopping', true, 'https://www.ppkm.org.my/site/wp-content/uploads/2024/10/PPK-News-Network-63-September_2024.pdf'),
    ('ChIJk0y_6eOtzTEREtrW6-lE6Jg', 'Selangor', 'GM Klang Wholesale City', 'Shopping', true, 'https://www.malaysia.travel/page/malaysia-national-sales-campaign'),
    ('ChIJW6IeoW9LzDERRhh2kBCUJaE', 'Selangor', 'IOI Mall Puchong', 'Shopping', true, 'https://www.ioiproperties.com.my/our-company/about-ioi-properties'),
    ('ChIJebTp9RxPzDERzQPNcVUbckY', 'Selangor', 'KidZania Kuala Lumpur', 'Family', true, 'https://visitpetalingjaya.com/attractions/kidzania-kuala-lumpur'),
    ('ChIJd3HmqG1TzDER96-aEJZcJME', 'Selangor', 'Klang Parade', 'Shopping', true, 'https://www.visitselangor.com/information/shopping-malls-in-klang-valley/'),
    ('ChIJ1dO4iFpMzDERNDCXYKfbsSg', 'Selangor', 'NU Empire', 'Shopping', true, 'https://www.visitselangor.com/information/shopping-malls-in-klang-valley/'),
    ('ChIJufVDm1NTzDERqqA6mwY8bxo', 'Selangor', 'Plaza Shah Alam', 'Shopping', true, 'https://www.ppkm.org.my/site/wp-content/uploads/2024/10/PPK-News-Network-63-September_2024.pdf'),
    ('ChIJdflQRONSzDERGjzEpdYig8I', 'Selangor', 'SnoWalk i-City', 'Family', true, 'https://iticket.i-city.my/'),
    ('ChIJq9te9e9JzDERX-ByCY7XagM', 'Selangor', 'the Starling', 'Shopping', true, 'https://www.ppkm.org.my/site/wp-content/uploads/2024/10/PPK-News-Network-63-September_2024.pdf'),
    ('ChIJAZIyB6twyDERd2EMEjhiD-I', 'Terengganu', 'Pasaraya TMC Mesra Mall', 'Shopping', true, 'https://data.gov.my/data-catalogue/lookup_premise'),
    ('ChIJKWgBk3m-tzERQo31ZdjbAsA', 'Terengganu', 'Paya Bunga Square', 'Shopping', true, 'https://www.ppkm.org.my/site/wp-content/uploads/2024/10/PPK-News-Network-63-September_2024.pdf'),
    ('ChIJ63Omr9i_tzER9I6-JAO6PdI', 'Terengganu', 'Taman Awam Batu Burok', 'Family', false, 'https://www.kpkt.gov.my/kpkt/resources/user_1/GALERI/PDF_PENERBITAN/PERANGKAAN%20TERPILIH/STATISTIK_KPKT_2024.pdf'),
    ('ChIJlw02HOO_tzERJMluk3x4v8I', 'Terengganu', 'Taman Awam Lagun Kuala Ibai', 'Attraction', false, 'https://www.kpkt.gov.my/kpkt/resources/user_1/GALERI/PDF_PENERBITAN/PERANGKAAN%20TERPILIH/STATISTIK_KPKT_2024.pdf')
), updated AS (
  UPDATE public.places AS p
  SET is_indoor = directory.is_indoor
  FROM directory
  WHERE p.place_id = directory.place_id
    AND p.state = directory.state
    AND p.name = directory.name
    AND p.category = directory.category
    AND p.is_indoor IS NULL
  RETURNING p.is_indoor
)
SELECT count(*) AS places_updated,
       count(*) FILTER (WHERE is_indoor) AS indoor_added,
       count(*) FILTER (WHERE NOT is_indoor) AS outdoor_added,
       (SELECT count(*) FROM public.places WHERE is_indoor IS NULL) - count(*) AS pending_after
FROM updated;
