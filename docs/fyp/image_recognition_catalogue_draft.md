# Image Recognition Catalogue Draft

Draft for the Image Recognition module. This file is a reviewable starting catalogue for the `YH` branch. It is not a Supabase migration and it is not ready to be treated as verified production data until the source links, opening hours, coordinates, and image licences are checked.

## How the catalogue will be used

- `landmark` records are schedulable places and can later connect to map, nearby-place, wishlist, and itinerary features.
- `food` records are recognition concepts. A food result must later be connected to a nearby restaurant or food location before it can be added to an itinerary.
- `aliases` are the names sent to the matching layer because users may upload an image or search with a different spelling.
- `source_url` is kept so the admin can verify the record before publishing it.
- `image_source` is intentionally marked for curation. Do not copy random images from Google Images into the app.

## Landmarks

| ID | Name | Aliases for matching | Area | Coordinates | Suggested visit | Cost | Recognition description | Source | Image source |
|---|---|---|---|---|---|---|---|---|---|
| `lm_petronas_twin_towers` | Petronas Twin Towers | KLCC, PETRONAS Towers, Petronas Towers, Twin Towers Kuala Lumpur | Kuala Lumpur City Centre, Kuala Lumpur | 3.1579, 101.7116 | 2–3 hours; verify current Skybridge hours before import | Outdoor view free; Skybridge ticketed | Two connected silver towers with a skybridge and pointed spires in central Kuala Lumpur. | [PETRONAS Twin Towers](https://www.petronastwintowers.com.my/) | Use an approved or CC-licensed exterior image; verify attribution. |
| `lm_batu_caves` | Batu Caves | Batu Caves Temple, Murugan Statue, Sri Subramaniar Swamy Temple | Gombak, Selangor | 3.2379, 101.6840 | 2–3 hours; verify temple access hours | Usually free; some attractions may charge | Large gold Murugan statue, a colourful staircase, limestone cliffs, and a cave temple. | [Tourism Malaysia – Batu Caves](https://www.malaysia.travel/explore/batu-caves) | Use an approved or CC-licensed image; verify attribution. |
| `lm_sultan_abdul_samad_building` | Sultan Abdul Samad Building | Bangunan Sultan Abdul Samad, Merdeka Square Building, Dataran Merdeka landmark | Merdeka Square, Kuala Lumpur | 3.1488, 101.6945 | 45–90 minutes for exterior and square | Free exterior visit | Historic red-brick building with Moorish arches, a central clock tower, and copper domes. | [Kuala Lumpur City Hall](https://www.dbkl.gov.my/) | Use a licensed exterior image; avoid images with unclear commercial rights. |
| `lm_kl_tower` | KL Tower | Menara Kuala Lumpur, Kuala Lumpur Tower | Bukit Nanas, Kuala Lumpur | 3.1528, 101.7038 | 1–2 hours; verify observation-deck hours | Ticketed | Tall communications tower with a round observation deck above Kuala Lumpur. | [KL Tower](https://kltower.com.my/) | Use an approved or CC-licensed tower image. |
| `lm_george_town` | George Town UNESCO World Heritage Site | George Town Heritage Area, Georgetown Penang, Penang old town | George Town, Penang | 5.4141, 100.3298 | Half day or full day | Free to walk; attractions vary | Dense historic streets with shophouses, colonial buildings, temples, murals, and street art. | [George Town World Heritage Incorporated](https://gtwhi.com.my/) | Curate a streetscape image with location and licence recorded. |
| `lm_kek_lok_si` | Kek Lok Si Temple | Temple of Supreme Bliss, Air Itam Temple, Penang Buddhist Temple | Air Itam, Penang | 5.3991, 100.2734 | 2–3 hours; verify opening and lift hours | Temple areas may be free; selected facilities may charge | Large hillside Buddhist temple complex with pagodas, statues, and views over Penang. | [Kek Lok Si Temple](https://kekloksitemple.com/) | Use an approved or CC-licensed temple image. |
| `lm_a_famosa` | A Famosa | Porta de Santiago, A Famosa Fort, Melaka Fort | Bandar Hilir, Melaka | 2.1896, 102.2501 | 30–60 minutes | Free exterior visit | Small stone gate that remains from the Portuguese fortress in historic Melaka. | [Melaka Historic City Council](https://www.mbmb.gov.my/) | Use an approved or CC-licensed exterior image. |
| `lm_jonker_walk` | Jonker Walk | Jonker Street, Jalan Hang Jebat, Melaka antique street | Melaka city centre | 2.1950, 102.2487 | 2–4 hours; night-market schedule varies | Free to walk; food and shopping vary | Historic street lined with Peranakan shophouses, antiques, crafts, cafes, and a weekend night market. | [Tourism Melaka](https://www.visitmelaka.com.my/) | Curate a street image and verify the night-market schedule. |
| `lm_kinabalu_park` | Kinabalu Park | Mount Kinabalu Park, Taman Kinabalu, Kinabalu National Park | Kundasang, Sabah | 6.0753, 116.5580 | Half day or longer; permits and trail rules apply | Ticketed or permit-based | Mountain park with rainforest, granite peaks, cool highland scenery, and Mount Kinabalu views. | [Sabah Parks](https://www.sabahparks.org.my/kinabalu-park) | Use an approved or CC-licensed landscape image. |
| `lm_langkawi_sky_bridge` | Langkawi Sky Bridge | Langkawi Cable Car Bridge, SkyCab Bridge, Gunung Mat Cincang Sky Bridge | Langkawi, Kedah | 6.3864, 99.6625 | 2–4 hours; weather and operating hours vary | Ticketed | Curved bridge high above the forest and mountain slopes of Langkawi. | [Langkawi SkyCab](https://panoramalangkawi.com/) | Use an approved or CC-licensed bridge image. |

## Malaysian food recognition records

| ID | Name | Aliases for matching | Common description | Suggested serving area | Recognition notes | Source | Image source |
|---|---|---|---|---|---|---|---|
| `fd_nasi_lemak` | Nasi Lemak | Nasi lemak, coconut rice, nasi lemak ayam, nasi lemak sambal | Fragrant coconut rice served with sambal, peanuts, fried anchovies, cucumber, and an optional egg or meat side. | Nationwide; especially common in breakfast stalls and Malay restaurants. | Look for rice with sambal, anchovies, peanuts, cucumber, and banana-leaf or packet presentation. | [Intake24-MY Malaysian Food List](https://bridges.monash.edu/articles/dataset/Intake24-MY_Malaysian_Food_List/27684102) | Use a CC-licensed image or obtain permission from the photographer. |
| `fd_char_kway_teow` | Char Kway Teow | Char koay teow, fried rice noodles, Penang char kway teow | Flat rice noodles stir-fried with soy sauce, egg, bean sprouts, seafood or meat, and sometimes Chinese sausage. | Especially associated with Penang hawker centres; also common nationwide. | Look for broad dark flat noodles, bean sprouts, egg, and wok-fried presentation. | [Intake24-MY Malaysian Food List](https://bridges.monash.edu/articles/dataset/Intake24-MY_Malaysian_Food_List/27684102) | Use a CC-licensed image or obtain permission. |
| `fd_asam_laksa` | Asam Laksa | Penang asam laksa, assam laksa, tamarind fish noodle soup | Sour and spicy fish-based noodle soup with tamarind, herbs, cucumber, onion, and rice noodles. | Penang and northern Malaysia; available in Malaysian restaurants elsewhere. | Look for reddish-brown broth, rice noodles, fish flakes, cucumber, onion, and herbs. | [Intake24-MY Malaysian Food List](https://bridges.monash.edu/articles/dataset/Intake24-MY_Malaysian_Food_List/27684102) | Use a CC-licensed image or obtain permission. |
| `fd_roti_canai` | Roti Canai | Roti chenai, roti prata, Malaysian flatbread, roti telur | Layered pan-fried flatbread commonly served with dhal or curry, sometimes with egg or other fillings. | Nationwide mamak and Indian-Muslim restaurants. | Look for flaky layered flatbread, curry or dhal accompaniment, and folded round pieces. | [Intake24-MY Malaysian Food List](https://bridges.monash.edu/articles/dataset/Intake24-MY_Malaysian_Food_List/27684102) | Use a CC-licensed image or obtain permission. |
| `fd_satay` | Satay | Sate, chicken satay, beef satay, skewered grilled meat | Marinated meat grilled on skewers and served with peanut sauce, cucumber, and compressed rice. | Nationwide night markets, hawker centres, and Malay restaurants. | Look for rows of grilled skewers, charred edges, peanut sauce, and ketupat or rice-cake pieces. | [Intake24-MY Malaysian Food List](https://bridges.monash.edu/articles/dataset/Intake24-MY_Malaysian_Food_List/27684102) | Use a CC-licensed image or obtain permission. |

## Fields to add when moving this into Supabase

For landmarks, create or confirm fields for `id`, `name`, `aliases`, `description`, `category`, `address`, `latitude`, `longitude`, `opening_hours`, `estimated_visit_minutes`, `estimated_cost_myr`, `image_url`, `source_url`, `status`, and `last_verified_at`.

For food concepts, use `id`, `name`, `aliases`, `description`, `category`, `ingredients_or_visual_cues`, `image_url`, `source_url`, `status`, and `last_verified_at`. Keep restaurant or stall locations in a separate place/recommendation table so a food concept can be offered by many venues.

Recommended initial status for every record in this draft: `draft`. Publish only after an admin verifies the details and the image licence.

## Next preparation task

1. Review the names and coverage with the project team.
2. Replace the flagged Penang source URL with a verified URL.
3. Choose one image per record and record its licence or permission.
4. Confirm coordinates and opening hours from the official source.
5. After approval, convert these records into a Supabase seed file or admin import sheet.
