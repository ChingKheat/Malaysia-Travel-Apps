import '../models/attraction.dart';

/// Curated Malaysian tourist attractions across various states.
/// Serves as the primary offline-resilient catalog for Browse Attractions (UC400)
/// whenever Google Places API is unreachable or returns empty results.
const List<Attraction> curatedMalaysianAttractions = [
  // ==================== KUALA LUMPUR ====================
  Attraction(
    xid: 'curated_kl_01',
    name: 'Petronas Twin Towers (KLCC)',
    latitude: 3.1579,
    longitude: 101.7116,
    category: 'Sights, Landmark, Architecture',
    description:
        'World-famous 88-storey twin skyscrapers featuring an iconic double-decker skybridge, Suria KLCC shopping mall, and observation deck.',
  ),
  Attraction(
    xid: 'curated_kl_02',
    name: 'Batu Caves Temple & Murugan Statue',
    latitude: 3.2374,
    longitude: 101.6839,
    category: 'Religion, Cultural, Historic, Sights',
    description:
        'Iconic limestone hill housing sacred Hindu cave temples, guarded by a towering 42.7m golden statue of Lord Murugan and 272 rainbow steps.',
  ),
  Attraction(
    xid: 'curated_kl_03',
    name: 'Central Market (Pasar Seni)',
    latitude: 3.1453,
    longitude: 101.6958,
    category: 'Shops, Culture, Handicrafts, Market',
    description:
        'Heritage Art Deco bazaar built in 1928, showcasing Malaysian batik, woodcarvings, local souvenirs, handicrafts, and cultural performances.',
  ),
  Attraction(
    xid: 'curated_kl_04',
    name: 'Jalan Alor Night Food Street',
    latitude: 3.1458,
    longitude: 101.7087,
    category: 'Foods, Dining, Street Food',
    description:
        'Bustling open-air dining street renowned for local street delicacies, grilled chicken wings, seafood, durian, satay, and char kway teow.',
  ),
  Attraction(
    xid: 'curated_kl_05',
    name: 'Thean Hou Temple',
    latitude: 3.1219,
    longitude: 101.6874,
    category: 'Religion, Cultural, Sights',
    description:
        'A magnificent multi-tiered Chinese temple blending contemporary design with traditional architecture, offering panoramic views of Kuala Lumpur.',
  ),
  Attraction(
    xid: 'curated_kl_06',
    name: 'KL Tower (Menara Kuala Lumpur)',
    latitude: 3.1528,
    longitude: 101.7037,
    category: 'Sights, Landmark, Viewpoint',
    description:
        'Seventh-tallest telecommunications tower in the world, featuring an open-air Sky Deck, thrilling glass Sky Boxes, and 360-degree skyline views.',
  ),
  Attraction(
    xid: 'curated_kl_07',
    name: 'Petaling Street (Chinatown)',
    latitude: 3.1444,
    longitude: 101.6978,
    category: 'Shops, Foods, Culture, Market',
    description:
        'Historic Chinatown commercial strip famous for bustling market stalls, local Chinese herbal teas, roast duck, and heritage shophouses.',
  ),
  Attraction(
    xid: 'curated_kl_08',
    name: 'Pavilion Kuala Lumpur',
    latitude: 3.1488,
    longitude: 101.7131,
    category: 'Shops, Shopping Mall, Dining',
    description:
        'Bukit Bintang luxury shopping paradise featuring over 700 retail stores, Tokyo Street cultural district, and high-end international dining.',
  ),
  Attraction(
    xid: 'curated_kl_09',
    name: 'Perdana Botanical Gardens',
    latitude: 3.1432,
    longitude: 101.6845,
    category: 'Park, Nature, Outdoor',
    description:
        'Kuala Lumpur’s heritage botanical sanctuary spanning 91 hectares, boasting sunken gardens, hibiscus collections, bamboo trails, and tranquil lakes.',
  ),
  Attraction(
    xid: 'curated_kl_10',
    name: 'KL Bird Park',
    latitude: 3.1430,
    longitude: 101.6883,
    category: 'Park, Nature, Wildlife',
    description:
        'The world’s largest free-flight walk-in aviary, sheltering over 3,000 birds from 200 species in an expansive tropical rainforest canopy valley.',
  ),
  Attraction(
    xid: 'curated_kl_11',
    name: 'Aquaria KLCC',
    latitude: 3.1534,
    longitude: 101.7127,
    category: 'Tourism, Sights, Aquarium',
    description:
        'State-of-the-art oceanarium beneath the KL Convention Centre, showcasing a 90m underwater tunnel with sand tiger sharks and giant stingrays.',
  ),
  Attraction(
    xid: 'curated_kl_12',
    name: 'Merdeka Square (Dataran Merdeka)',
    latitude: 3.1492,
    longitude: 101.6936,
    category: 'Historic, Cultural, Sights',
    description:
        'Birthplace of Malaysian independence where the Union Jack was lowered in 1957, surrounded by the Moorish Sultan Abdul Samad heritage building.',
  ),
  Attraction(
    xid: 'curated_kl_13',
    name: 'Islamic Arts Museum Malaysia',
    latitude: 3.1428,
    longitude: 101.6896,
    category: 'Culture, Museum, Sights',
    description:
        'Southeast Asia’s largest Islamic art museum, featuring intricate calligraphy, scale architectural models of world mosques, and royal textiles.',
  ),
  Attraction(
    xid: 'curated_kl_14',
    name: 'Saloma Link Bridge',
    latitude: 3.1601,
    longitude: 101.7088,
    category: 'Sights, Landmark, Architecture',
    description:
        'Pedestrian footbridge inspired by Malay betel-nut leaf arrangements, dramatically illuminated with kaleidoscopic state-of-the-art LED patterns.',
  ),
  Attraction(
    xid: 'curated_kl_15',
    name: 'Kwai Chai Hong (Ghost Lane Murals)',
    latitude: 3.1419,
    longitude: 101.6975,
    category: 'Culture, Artwork, Sights',
    description:
        'Restored heritage alleyway in Chinatown depicting nostalgic 1960s daily life through vibrant interactive murals and quaint speakeasies.',
  ),

  // ==================== PENANG ====================
  Attraction(
    xid: 'curated_penang_01',
    name: 'George Town Street Art & Murals',
    latitude: 5.4141,
    longitude: 100.3396,
    category: 'Culture, Artwork, Sights',
    description:
        'World-famous interactive street murals by Ernest Zacharevic scattered across UNESCO heritage lanes, including "Kids on Bicycle".',
  ),
  Attraction(
    xid: 'curated_penang_02',
    name: 'Kek Lok Si Temple',
    latitude: 5.3995,
    longitude: 100.2736,
    category: 'Religion, Cultural, Sights',
    description:
        'Malaysia’s largest Buddhist temple complex perched in Air Itam, featuring a 36.5m bronze statue of Guanyin and 7-tier Pagoda of Rama VI.',
  ),
  Attraction(
    xid: 'curated_penang_03',
    name: 'Penang Hill Funicular Railway',
    latitude: 5.4085,
    longitude: 100.2770,
    category: 'Park, Nature, Viewpoint',
    description:
        'Ride the historic Swiss funicular railway up 833 meters into cool mountain air, featuring Habitat canopy walkways and panoramic island views.',
  ),
  Attraction(
    xid: 'curated_penang_04',
    name: 'Gurney Drive Hawker Centre',
    latitude: 5.4398,
    longitude: 100.3090,
    category: 'Foods, Dining, Street Food',
    description:
        'Famous seaside gastronomic hub serving Penang laksa, rojak, oyster omelette, char kway teow, and cendol along the northern coastline.',
  ),
  Attraction(
    xid: 'curated_penang_05',
    name: 'Cheong Fatt Tze - The Blue Mansion',
    latitude: 5.4200,
    longitude: 100.3347,
    category: 'Historic, Culture, Museum',
    description:
        'Magnificent 19th-century indigo-blue courtyard mansion combining traditional Chinese feng shui with European Art Nouveau architecture.',
  ),
  Attraction(
    xid: 'curated_penang_06',
    name: 'Chew Jetty (Clan Jetties)',
    latitude: 5.4128,
    longitude: 100.3402,
    category: 'Historic, Cultural, Sights',
    description:
        'Historic waterfront wooden stilt settlements established in the 19th century by early Chinese maritime immigrants along Weld Quay.',
  ),

  // ==================== MELAKA ====================
  Attraction(
    xid: 'curated_melaka_01',
    name: 'Jonker Walk Heritage Night Market',
    latitude: 2.1953,
    longitude: 102.2478,
    category: 'Shops, Foods, Market, Historic',
    description:
        'The heart of Chinatown Melaka, famous for vibrant weekend street markets, antique shophouses, chicken rice balls, and Peranakan crafts.',
  ),
  Attraction(
    xid: 'curated_melaka_02',
    name: 'The Stadthuys & Dutch Square',
    latitude: 2.1944,
    longitude: 102.2492,
    category: 'Historic, Museum, Sights',
    description:
        'Distinctive terra-cotta red colonial Dutch administrative building built in 1650, housing the History & Ethnography Museum.',
  ),
  Attraction(
    xid: 'curated_melaka_03',
    name: 'A Famosa (Porta de Santiago)',
    latitude: 2.1917,
    longitude: 102.2505,
    category: 'Historic, Sights, Monument',
    description:
        'One of the oldest surviving European architectural remains in Southeast Asia, built by the Portuguese in 1511 at the foot of St. Paul’s Hill.',
  ),
  Attraction(
    xid: 'curated_melaka_04',
    name: 'Melaka River Cruise',
    latitude: 2.1983,
    longitude: 102.2498,
    category: 'Tourism, Sights, Waterway',
    description:
        'Relaxing 45-minute river boat excursion passing colonial bridges, illuminated traditional Malay kampung houses, and colorful murals.',
  ),

  // ==================== SELANGOR & PUTRAJAYA ====================
  Attraction(
    xid: 'curated_putrajaya_01',
    name: 'Putra Mosque (Pink Mosque)',
    latitude: 2.9358,
    longitude: 101.6896,
    category: 'Religion, Cultural, Architecture',
    description:
        'Striking rose-tinted granite mosque situated on Putrajaya Lake, accommodating 15,000 worshippers with a 116m minaret.',
  ),
  Attraction(
    xid: 'curated_selangor_01',
    name: 'Sunway Lagoon Theme Park',
    latitude: 3.0716,
    longitude: 101.6053,
    category: 'Tourism, Sights, Theme Park',
    description:
        'Multi-award winning 88-acre amusement and water park featuring 6 adventure zones, including the world’s largest surf beach.',
  ),
  Attraction(
    xid: 'curated_selangor_02',
    name: 'Sultan Salahuddin Abdul Aziz Mosque (Blue Mosque)',
    latitude: 3.0784,
    longitude: 101.5208,
    category: 'Religion, Cultural, Architecture',
    description:
        'Malaysia’s largest mosque in Shah Alam, renowned for its majestic blue-and-silver dome and four soaring 142m minarets.',
  ),

  // ==================== KEDAH & LANGKAWI ====================
  Attraction(
    xid: 'curated_langkawi_01',
    name: 'Langkawi Sky Bridge & SkyCab',
    latitude: 6.3860,
    longitude: 99.6623,
    category: 'Sights, Nature, Viewpoint',
    description:
        'Curved 125m cable-stayed pedestrian bridge suspended 660 meters above sea level atop Gunung Mat Cincang, offering breathtaking Andaman Sea views.',
  ),
  Attraction(
    xid: 'curated_langkawi_02',
    name: 'Eagle Square (Dataran Lang)',
    latitude: 6.3082,
    longitude: 99.8522,
    category: 'Sights, Landmark, Monument',
    description:
        'Langkawi’s most iconic landmark featuring a colossal 12-meter reddish-brown eagle sculpture poised for flight overlooking Kuah harbor.',
  ),
  Attraction(
    xid: 'curated_langkawi_03',
    name: 'Pantai Cenang Beach',
    latitude: 6.2917,
    longitude: 99.7289,
    category: 'Park, Nature, Beach',
    description:
        'Langkawi’s liveliest beach town with powdery white sands, vibrant beach bars, water sports, and duty-free shopping.',
  ),

  // ==================== PERAK (IPOH) ====================
  Attraction(
    xid: 'curated_ipoh_01',
    name: 'Concubine Lane (Panglima Lane)',
    latitude: 4.5966,
    longitude: 101.0780,
    category: 'Shops, Foods, Historic',
    description:
        'Nostalgic restored lane in Ipoh Old Town featuring artisan souvenir stalls, rainbow cheese toast, tau foo fah, and famous Ipoh white coffee.',
  ),
  Attraction(
    xid: 'curated_ipoh_02',
    name: 'Perak Cave Temple (Perak Tong)',
    latitude: 4.6436,
    longitude: 101.0994,
    category: 'Religion, Cultural, Sights',
    description:
        'Historic limestone cave temple founded in 1926 featuring a 40-foot golden Buddha statue and intricate Buddhist wall frescoes.',
  ),
  Attraction(
    xid: 'curated_ipoh_03',
    name: 'Kellie’s Castle',
    latitude: 4.4752,
    longitude: 101.0878,
    category: 'Historic, Sights, Architecture',
    description:
        'Unfinished Scottish estate in Batu Gajah built in 1915, filled with secret underground wine cellars, tunnels, and romantic legends.',
  ),

  // ==================== SABAH & SARAWAK ====================
  Attraction(
    xid: 'curated_sabah_01',
    name: 'Kinabalu National Park (UNESCO)',
    latitude: 6.0048,
    longitude: 116.5413,
    category: 'Park, Nature, Outdoor',
    description:
        'Malaysia’s first World Heritage site dominated by 4,095m Mount Kinabalu, harboring extraordinary biodiversity with carnivorous pitcher plants and orchids.',
  ),
  Attraction(
    xid: 'curated_sarawak_01',
    name: 'Kuching Waterfront & Darul Hana Bridge',
    latitude: 1.5583,
    longitude: 110.3444,
    category: 'Sights, Cultural, Outdoor',
    description:
        'Scenic riverside esplanade facing the Astana and Fort Margherita, connected by the illuminated S-curved Darul Hana suspension bridge.',
  ),

  // ==================== JOHOR ====================
  Attraction(
    xid: 'curated_johor_01',
    name: 'Legoland Malaysia Resort',
    latitude: 1.4273,
    longitude: 103.6299,
    category: 'Tourism, Sights, Theme Park',
    description:
        'First international Lego theme park in Asia featuring over 70 hands-on rides, slides, Miniland landmarks, and water park.',
  ),
  Attraction(
    xid: 'curated_johor_02',
    name: 'Tan Hiok Nee Cultural Street',
    latitude: 1.4566,
    longitude: 103.7638,
    category: 'Foods, Culture, Historic',
    description:
        'Charming heritage enclave in Johor Bahru celebrating traditional Chinese bakeries (Hiap Joo banana cake), hipster cafes, and cultural street fairs.',
  ),
];
