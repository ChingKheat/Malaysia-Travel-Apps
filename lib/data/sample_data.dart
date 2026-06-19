import 'package:flutter/material.dart';

import '../core/app_colors.dart';
import '../models/saved_trip.dart';
import '../models/travel_stop.dart';

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
  ),
];

const savedTrips = [
  SavedTrip(
    title: 'Kuala Lumpur Getaway',
    date: '20 - 22 May 2026',
    detail: '3 days 2 nights',
    destination: 'Kuala Lumpur, Malaysia',
    budget: 'RM150 - RM300 per day',
    interests: ['Food', 'Shopping', 'Culture'],
  ),
  SavedTrip(
    title: 'Penang Food Trip',
    date: '15 - 17 Jun 2026',
    detail: 'Food, culture and street art',
    destination: 'George Town, Penang',
    budget: 'Below RM150 per day',
    interests: ['Food', 'History', 'Street art'],
  ),
  SavedTrip(
    title: 'Langkawi Relaxing Trip',
    date: '10 - 13 Jul 2026',
    detail: 'Nature and beach route',
    destination: 'Langkawi, Kedah',
    budget: 'RM150 - RM300 per day',
    interests: ['Nature', 'Family', 'Relaxed'],
  ),
];
