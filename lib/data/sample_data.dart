import 'package:flutter/material.dart';

import '../core/app_colors.dart';
import '../models/saved_trip.dart';
import '../models/travel_stop.dart';
import '../services/smart_itinerary_service.dart';
import '../services/trip_preferences_service.dart';


const sampleStops = [
  TravelStop(
    title: 'Batu Caves',
    time: '08:30 - 10:00',
    note: '45 min from hotel - open now',
    description:
        'A famous limestone hill with Hindu temples, colorful stairs, cultural photo spots and a light morning climb.',
    duration: '1 h 30 min',
    openingHours: 'Daily, 7:00 AM - 9:00 PM',
    tips: ['Wear comfortable shoes', 'Bring water', 'Dress respectfully'],
    icon: Icons.temple_buddhist,
    color: Color(0xFF2563EB),
    placeId: 'poi_kl_batu_caves',
    latitude: 3.2379,
    longitude: 101.6841,
  ),
  TravelStop(
    title: 'Central Market',
    time: '10:45 - 12:30',
    note: 'Culture, souvenirs and local crafts',
    description:
        'A heritage market for Malaysian crafts, snacks, gifts and quick cultural discovery between major stops.',
    duration: '1 h 45 min',
    openingHours: 'Daily, 10:00 AM - 10:00 PM',
    tips: ['Compare souvenir prices', 'Try local snacks', 'Keep cash ready'],
    icon: Icons.storefront,
    color: AppColors.teal,
    placeId: 'poi_kl_central_market',
    latitude: 3.1453,
    longitude: 101.6954,
  ),
  TravelStop(
    title: 'Lunch at Jalan Alor',
    time: '12:30 - 14:00',
    note: 'Budget-friendly local food',
    description:
        'A famous food street with noodles, grilled dishes, desserts and many affordable local choices.',
    duration: '1 h 30 min',
    openingHours: 'Daily, 11:00 AM - 12:00 AM',
    tips: ['Check prices first', 'Share dishes', 'Try local drinks'],
    icon: Icons.restaurant,
    color: Color(0xFFFF8A3D),
    placeId: 'poi_kl_jalan_alor',
    latitude: 3.1458,
    longitude: 101.7088,
  ),
  TravelStop(
    title: 'Petronas Twin Towers',
    time: '14:15 - 16:00',
    note: 'Weather check: indoor backup available',
    description:
        'An iconic Kuala Lumpur landmark with photo spots, mall access, indoor attractions and nearby transit.',
    duration: '1 h 45 min',
    openingHours: 'Tue - Sun, 9:00 AM - 9:00 PM',
    tips: [
      'Book bridge tickets early',
      'Use KLCC station',
      'Good indoor rain backup',
    ],
    icon: Icons.location_city,
    color: AppColors.primary,
    placeId: 'poi_kl_petronas',
    latitude: 3.1579,
    longitude: 101.7116,
  ),
  TravelStop(
    title: 'KLCC Park',
    time: '16:15 - 17:15',
    note: 'Walk 5 min - relax before shopping',
    description:
        'A city park beside KLCC with skyline views, walking paths and a relaxed evening stop before dinner.',
    duration: '1 h',
    openingHours: 'Daily, 7:00 AM - 10:00 PM',
    tips: [
      'Best near sunset',
      'Watch weather alerts',
      'Stay near shaded paths',
    ],
    icon: Icons.park,
    color: Color(0xFF16A34A),
    placeId: 'poi_kl_klcc_park',
    latitude: 3.1558,
    longitude: 101.7138,
  ),
];

const savedTrips = [
  SavedTrip(
    title: 'Kuala Lumpur Smart Schedule',
    date: 'Active Smart Itinerary',
    detail: '3 days personalized schedule',
    destination: 'Kuala Lumpur, Malaysia',
    budget: 'Medium',
    interests: ['Culture', 'Food', 'Sights'],
    totalDays: 3,
  ),
  SavedTrip(
    title: 'Penang Food & Heritage',
    date: 'Heritage & Street Art Route',
    detail: '5 days cultural schedule',
    destination: 'George Town, Penang',
    budget: 'Medium',
    interests: ['Food', 'History', 'Street art'],
    totalDays: 5,
  ),
  SavedTrip(
    title: 'Langkawi Island & Nature',
    date: 'Beach & Nature Excursion',
    detail: '7 days island schedule',
    destination: 'Langkawi, Kedah',
    budget: 'Medium',
    interests: ['Nature', 'Beach', 'Relaxed'],
    totalDays: 7,
  ),
];

const daySummaries7Days = [
  'Batu Caves, Central Market & Jalan Alor',
  'Thean Hou Temple, Petaling St & KL Tower',
  'Aquaria, Pavilion KL & Saloma Bridge',
  'Perdana Botanical Gardens & Bird Park',
  'Putra Pink Mosque & Lake Cruise',
  'Genting SkyWay & Theme Park Excursion',
  'Little India, Artisan Crafts & Departure',
];

List<TravelStop> getDailyStops(int dayIndex) {
  final stored = TripPreferencesService.storedPreferences;
  if (stored != null && stored.destination != null && stored.destination!.trim().isNotEmpty) {
    return SmartItineraryService.generateDailyStops(
      preferences: stored,
      dayIndex: dayIndex,
    );
  }

  final dayNumber = (dayIndex % 7) + 1;
  switch (dayNumber) {
    case 1:
      return sampleStops;

    case 2:
      return const [
        TravelStop(
          title: 'Thean Hou Temple',
          time: '09:00 - 10:30',
          note: 'Ornate 6-tier temple with KL city panoramas',
          description:
              'A magnificent Chinese temple blending contemporary architectural styles with traditional designs and skyline views.',
          duration: '1 h 30 min',
          openingHours: 'Daily, 8:00 AM - 8:00 PM',
          tips: ['Climb to top floor for best photo', 'Quiet prayer areas', 'Free admission'],
          icon: Icons.temple_buddhist,
          color: Color(0xFFDC2626),
        ),
        TravelStop(
          title: 'Islamic Arts Museum',
          time: '11:00 - 12:30',
          note: 'Southeast Asia’s largest Islamic art museum',
          description:
              'Showcases intricate calligraphy, scale models of famous world mosques, jewellery, and textiles.',
          duration: '1 h 30 min',
          openingHours: 'Daily, 9:30 AM - 6:00 PM',
          tips: ['Air-conditioned comfort', 'Museum cafe available', 'Great architecture'],
          icon: Icons.museum,
          color: Color(0xFF0D9488),
        ),
        TravelStop(
          title: 'Lunch at Petaling Street',
          time: '12:45 - 14:15',
          note: 'Chinatown heritage noodles & Kwai Chai Hong',
          description:
              'Explore historic shophouse alleyways with 1960s murals, famous roast duck, and refreshing soya bean drinks.',
          duration: '1 h 30 min',
          openingHours: 'Daily, 10:00 AM - 9:00 PM',
          tips: ['Try Madam Tang muah chee', 'Visit Kwai Chai Hong murals', 'Wear comfortable walking shoes'],
          icon: Icons.restaurant,
          color: Color(0xFFEA580C),
        ),
        TravelStop(
          title: 'Merdeka Square',
          time: '14:30 - 16:00',
          note: 'Historic Sultan Abdul Samad Building',
          description:
              'The birthplace of Malaysian independence featuring Moorish-style colonial architecture and a 95m flagpole.',
          duration: '1 h 30 min',
          openingHours: 'Open 24 hours',
          tips: ['Iconic photo backdrop', 'River of Life nearby', 'Best in late afternoon light'],
          icon: Icons.account_balance,
          color: Color(0xFF2563EB),
        ),
        TravelStop(
          title: 'KL Tower Sky Deck',
          time: '16:30 - 18:30',
          note: '360° open-air panoramic sunset view',
          description:
              'Seventh-tallest freestanding tower in the world with an open-air Sky Deck and thrilling glass Sky Boxes.',
          duration: '2 h',
          openingHours: 'Daily, 9:00 AM - 10:00 PM',
          tips: ['Catch the golden hour sunset', 'Book Sky Box tickets ahead', 'Eco-park forest nearby'],
          icon: Icons.location_city,
          color: Color(0xFF7C3AED),
        ),
      ];
    case 3:
      return const [
        TravelStop(
          title: 'Aquaria KLCC',
          time: '10:00 - 12:00',
          note: '90-meter underwater moving walkway',
          description:
              'World-class oceanarium with over 5,000 land and aquatic creatures including sand tiger sharks and sea turtles.',
          duration: '2 h',
          openingHours: 'Daily, 10:00 AM - 8:00 PM',
          tips: ['Check daily feeding show times', 'Direct air-con link to KLCC', 'Book online for discounts'],
          icon: Icons.water,
          color: Color(0xFF0284C7),
        ),
        TravelStop(
          title: 'Lunch at Lot 10 Hutong',
          time: '12:15 - 13:45',
          note: 'Legendary gourmet heritage food village',
          description:
              'Home to generational street food stalls gathered under one roof, famous for Hokkien mee and beef noodles.',
          duration: '1 h 30 min',
          openingHours: 'Daily, 10:00 AM - 10:00 PM',
          tips: ['Kim Lian Kee charcoal noodles', 'Hon Kee porridge', 'Air-conditioned dining'],
          icon: Icons.lunch_dining,
          color: Color(0xFFE11D48),
        ),
        TravelStop(
          title: 'Pavilion Kuala Lumpur',
          time: '14:00 - 16:30',
          note: 'Bukit Bintang premier luxury retail hub',
          description:
              'Malaysia’s leading shopping mall with over 700 stores, Tokyo Street cultural zone, and iconic Crystal Fountain.',
          duration: '2 h 30 min',
          openingHours: 'Daily, 10:00 AM - 10:00 PM',
          tips: ['Explore Level 6 Tokyo Street', 'Great indoor stop if it rains', 'Currency exchange available'],
          icon: Icons.shopping_bag,
          color: Color(0xFFD97706),
        ),
        TravelStop(
          title: 'Saloma Link Bridge',
          time: '19:30 - 20:30',
          note: 'Iconic LED illuminated pedestrian bridge',
          description:
              'A modern 370-meter footbridge inspired by traditional Sirih Junjung betel nut leaf arrangements, lit with changing LEDs.',
          duration: '1 h',
          openingHours: 'Open daily until midnight',
          tips: ['Spectacular view of Twin Towers', 'Stunning night photo spot', 'Connects Kampung Baru to KLCC'],
          icon: Icons.alt_route,
          color: Color(0xFF4F46E5),
        ),
      ];
    case 4:
      return const [
        TravelStop(
          title: 'Perdana Botanical Gardens',
          time: '08:30 - 10:30',
          note: 'Historic shaded heritage park & lake',
          description:
              'Kuala Lumpur’s first recreational park featuring sunken gardens, hibiscus walk, bamboo playhouse, and scenic lakes.',
          duration: '2 h',
          openingHours: 'Daily, 7:00 AM - 8:00 PM',
          tips: ['Rent a bicycle or buggy', 'Morning breeze is coolest', 'Free admission'],
          icon: Icons.nature,
          color: Color(0xFF16A34A),
        ),
        TravelStop(
          title: 'KL Bird Park',
          time: '10:45 - 12:45',
          note: 'World’s largest free-flight walk-in aviary',
          description:
              'Home to over 3,000 birds across 200 species roaming freely in an expansive tropical valley ecosystem.',
          duration: '2 h',
          openingHours: 'Daily, 9:00 AM - 6:00 PM',
          tips: ['Catch bird feeding at 11:30 AM', 'Flamingo pond photo spot', 'Wear insect repellent'],
          icon: Icons.flutter_dash,
          color: Color(0xFF059669),
        ),
        TravelStop(
          title: 'Lunch at Old China Cafe',
          time: '13:00 - 14:30',
          note: 'Classic Peranakan & Nyonya cuisine',
          description:
              'Atmospheric vintage shophouse serving authentic Nyonya laksa, beef rendang, and pie tee.',
          duration: '1 h 30 min',
          openingHours: 'Daily, 11:00 AM - 10:00 PM',
          tips: ['Try Pai Tee appetizers', 'Antique guild atmosphere', 'Reserve table in advance'],
          icon: Icons.restaurant,
          color: Color(0xFFB45309),
        ),
        TravelStop(
          title: 'Forest Skywalk @ FRIM',
          time: '15:30 - 17:30',
          note: '50-meter canopy walkway above tropical rainforest',
          description:
              'Experience walking above the forest canopy with sweeping views across Kuala Lumpur’s cityscape.',
          duration: '2 h',
          openingHours: 'Tue - Sun, 8:30 AM - 3:30 PM',
          tips: ['Wear proper hiking shoes', 'Check weather before visiting', 'Limited daily visitor quota'],
          icon: Icons.forest,
          color: Color(0xFF15803D),
        ),
      ];
    case 5:
      return const [
        TravelStop(
          title: 'Putra Mosque (Pink Mosque)',
          time: '09:00 - 10:30',
          note: 'Rose-tinted granite dome on Putrajaya Lake',
          description:
              'One of Malaysia’s most photogenic mosques facing the scenic lake and Prime Minister’s office.',
          duration: '1 h 30 min',
          openingHours: 'Daily, non-prayer visiting hours',
          tips: ['Robes provided at entrance', 'Dress respectfully', 'Stunning water reflections'],
          icon: Icons.mosque,
          color: Color(0xFFDB2777),
        ),
        TravelStop(
          title: 'Putrajaya Lake Cruise',
          time: '10:45 - 12:00',
          note: 'Air-conditioned catamaran lake cruise',
          description:
              'Relaxing boat journey showcasing Putrajaya’s architectural bridges and federal administrative landmarks.',
          duration: '1 h 15 min',
          openingHours: 'Daily, 10:00 AM - 6:00 PM',
          tips: ['Board at Marina Putrajaya', 'Audio commentary included', 'Great photo perspectives'],
          icon: Icons.directions_boat,
          color: Color(0xFF0284C7),
        ),
        TravelStop(
          title: 'Lunch at IOI City Mall',
          time: '12:30 - 14:00',
          note: 'Malaysia’s largest shopping mall with vast dining',
          description:
              'State-of-the-art mega mall with over 200 international and Malaysian restaurants, cafes and eateries.',
          duration: '1 h 30 min',
          openingHours: 'Daily, 10:00 AM - 10:00 PM',
          tips: ['East wing has great cafes', 'Massive indoor garden', 'Plenty of local dessert stalls'],
          icon: Icons.local_dining,
          color: Color(0xFFCA8A04),
        ),
        TravelStop(
          title: 'Seri Wawasan Bridge',
          time: '16:30 - 17:30',
          note: 'Futuristic sail-shaped suspension bridge',
          description:
              'An architectural marvel resembling a soaring sailing vessel, especially dramatic during sunset.',
          duration: '1 h',
          openingHours: 'Open 24 hours',
          tips: ['Photographer favourite at sunset', 'Pedestrian walkway available', 'Bridge lights up at dusk'],
          icon: Icons.architecture,
          color: Color(0xFF6366F1),
        ),
      ];
    case 6:
      return const [
        TravelStop(
          title: 'Awana SkyWay Cable Car',
          time: '09:30 - 11:00',
          note: 'Gondola ride over 130-million-year-old rainforest',
          description:
              'High-speed cable car taking visitors up Genting Highlands with glass-floor options and cool mountain breezes.',
          duration: '1 h 30 min',
          openingHours: 'Daily, 7:00 AM - 11:00 PM',
          tips: ['Free stopover at Chin Swee Station', 'Bring a light jacket for cool air', 'Scan QR ticket for fast entry'],
          icon: Icons.airline_stops,
          color: Color(0xFF2563EB),
        ),
        TravelStop(
          title: 'Chin Swee Caves Temple',
          time: '11:15 - 13:00',
          note: '9-story pagoda perched on rocky mountain cliffs',
          description:
              'Peaceful cliffside temple honoring Reverend Master Chin Swee with panoramic mountain vistas.',
          duration: '1 h 45 min',
          openingHours: 'Daily, 9:00 AM - 6:00 PM',
          tips: ['Climb pagoda stairs for view', 'Walk through 10 Chambers of Hell path', 'Vegetarian restaurant on-site'],
          icon: Icons.temple_buddhist,
          color: Color(0xFFDC2626),
        ),
        TravelStop(
          title: 'Lunch at SkyAvenue Genting',
          time: '13:15 - 14:45',
          note: 'High-altitude dining & lifestyle hub',
          description:
              'Modern lifestyle boulevard featuring international celebrity restaurants, Malaysian food street and bakeries.',
          duration: '1 h 30 min',
          openingHours: 'Daily, 10:00 AM - 10:00 PM',
          tips: ['Try Madam Kwan’s or Burger & Lobster', 'Indoor LED symphony show at atrium', 'Cool 18°C temperature'],
          icon: Icons.restaurant,
          color: Color(0xFFD97706),
        ),
        TravelStop(
          title: 'Genting Premium Outlets',
          time: '15:30 - 18:00',
          note: 'Open-air designer outlet shopping village',
          description:
              'Over 150 designer brands offering everyday savings up to 65% in pleasant hilltop mountain weather.',
          duration: '2 h 30 min',
          openingHours: 'Daily, 10:00 AM - 10:00 PM',
          tips: ['Located at Awana mid-hill', 'Direct shuttle to SkyWay', 'Tax-free tourist shopping discounts'],
          icon: Icons.shopping_bag,
          color: Color(0xFF7C3AED),
        ),
      ];
    case 7:
    default:
      return const [
        TravelStop(
          title: 'Brickfields Little India',
          time: '09:30 - 11:30',
          note: 'Vibrant cultural enclave with Indian street food',
          description:
              'A sensory haven filled with colorful arches, Bollywood music, aromatic spice shops and flower garlands.',
          duration: '2 h',
          openingHours: 'Daily, 9:00 AM - 9:00 PM',
          tips: ['Authentic banana leaf rice', 'Try fresh sweet jalebi & masala tea', 'Walking distance from KL Sentral'],
          icon: Icons.palette,
          color: Color(0xFFE11D48),
        ),
        TravelStop(
          title: 'Batik Painting at Central Market',
          time: '12:00 - 13:30',
          note: 'Hands-on Malaysian handicraft experience',
          description:
              'Create your own hand-drawn traditional Malaysian batik masterpiece to take home as a memorable keepsake.',
          duration: '1 h 30 min',
          openingHours: 'Daily, 10:00 AM - 8:00 PM',
          tips: ['Instructor guided workshop', 'Colors dry in 20 minutes', 'Family friendly creative stop'],
          icon: Icons.brush,
          color: Color(0xFF059669),
        ),
        TravelStop(
          title: 'High Tea at The Majestic Hotel',
          time: '14:00 - 15:30',
          note: 'Colonial heritage afternoon tea in Orchid Room',
          description:
              'A relaxing British colonial afternoon tea with warm scones, pastries, and artisanal teas surrounded by orchids.',
          duration: '1 h 30 min',
          openingHours: 'Daily, 12:00 PM - 6:00 PM',
          tips: ['Smart casual dress code', 'Historic 1932 luxury hotel', 'Advance reservation advised'],
          icon: Icons.local_cafe,
          color: Color(0xFF9333EA),
        ),
        TravelStop(
          title: 'KLIA Ekspres Airport Departure',
          time: '16:30 - 17:30',
          note: 'Non-stop high speed 28-min transit to airport',
          description:
              'Comfortable air-conditioned express train with free Wi-Fi and in-town airline flight check-in at KL Sentral.',
          duration: '1 h',
          openingHours: 'Daily, 5:00 AM - 12:00 AM',
          tips: ['In-town baggage check-in available', 'Runs every 15 minutes', 'Arrive at airport stress-free'],
          icon: Icons.flight_takeoff,
          color: Color(0xFF2563EB),
        ),
      ];
  }
}
