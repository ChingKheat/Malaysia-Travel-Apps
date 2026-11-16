import 'package:latlong2/latlong.dart';
import 'package:smart_travel_planner/features/image_recognition/models/recognition_result.dart';
import 'package:smart_travel_planner/features/places/data/curated_attractions.dart';
import 'package:smart_travel_planner/shared/models/attraction.dart';

typedef ScanSpot = ({
  Attraction place,
  bool food,
  String? image,
  String? price,
  String distance,
});

const twinSpiresPhoto = 'assets/recognition/scan_twin_spires.png';

Attraction? scanLandmark(RecognitionResult result) =>
    result.kind == 'landmark' ? scanLandmarkByName(result.name) : null;

Attraction? scanLandmarkByName(String landmark) {
  final name = landmark.trim().toLowerCase().replaceAll('’', "'");
  final knownId = switch (name) {
    'batu caves & lord murugan' => 'curated_kl_02',
    'kuala lumpur tower' => 'curated_kl_06',
    _ => null,
  };
  return curatedMalaysianAttractions.where((place) {
        final title = place.name.toLowerCase().replaceAll('’', "'");
        return place.xid == knownId ||
            title == name ||
            title.startsWith('$name (') ||
            title.startsWith('$name ');
      }).firstOrNull ??
      switch (name) {
        'sultan abdul samad building' => const Attraction(
          xid: 'scan_sultan_abdul_samad',
          name: 'Sultan Abdul Samad Building',
          latitude: 3.14861,
          longitude: 101.69444,
          category: 'Historic Landmark',
        ),
        _ => null,
      };
}

List<ScanSpot> scanSpots(RecognitionResult result, Attraction? origin) {
  if (result.sampleId == 'petronas') return _sampleSpots;
  final isFood = result.kind == 'food';
  if (origin == null && !isFood) return [];
  final name = result.name.toLowerCase();
  final spots = <(Attraction, double?)>[];
  const distance = Distance(roundResult: false);
  for (final place in curatedMalaysianAttractions) {
    if (place.xid == origin?.xid) continue;
    final meters = origin == null ? null : distance(origin.point, place.point);
    if (meters != null && meters > 15000) continue;
    if (isFood &&
        !RegExp(
          '(^|[^a-z])${RegExp.escape(name)}'
          r'([^a-z]|$)',
        ).hasMatch((place.description ?? '').toLowerCase())) {
      continue;
    }
    spots.add((place, meters));
  }
  spots.sort((a, b) => (a.$2 ?? 0).compareTo(b.$2 ?? 0));
  return [
    for (final (place, meters) in spots.take(12))
      (
        place: place,
        food: _isDining(place.category),
        image: switch (place.xid) {
          'curated_kl_01' => 'assets/recognition/petronas.jpg',
          'curated_kl_02' => 'assets/recognition/batu_caves.jpg',
          _ => null,
        },
        price: null,
        distance: meters == null
            ? ''
            : meters < 1000
            ? '${meters.round()} m'
            : '${(meters / 1000).toStringAsFixed(1)} km',
      ),
  ];
}

bool _isDining(String category) => RegExp(
  r'food|dining|restaurant|caf[eé]|hawker',
  caseSensitive: false,
).hasMatch(category);

final _sampleSpots = <ScanSpot>[
  (
    place: const Attraction(
      xid: 'sample_madam_kwans',
      name: "Madam Kwan's · Suria KLCC",
      latitude: 3.158,
      longitude: 101.7118,
      category: 'Malaysian Restaurant',
      description:
          'Signature Nasi Bojari, chicken curry, and Penang char kway teow inside Level 4.',
    ),
    food: true,
    image: 'assets/recognition/scan_madam_kwans.png',
    price: 'RM 32–55',
    distance: '2 min walk · 140 m',
  ),
  (
    place: const Attraction(
      xid: 'sample_tapak_klcc',
      name: 'Tapak Urban Street Dining',
      latitude: 3.1609,
      longitude: 101.7147,
      category: 'Evening Food Trucks',
      description: 'Open-air street eats with charcoal satay and teh tarik.',
    ),
    food: true,
    image: 'assets/recognition/scan_tapak.png',
    price: 'RM 12–24',
    distance: '5 min walk · 420 m',
  ),
  (
    place: const Attraction(
      xid: 'sample_klcc_park',
      name: 'KLCC Park & Lake Symphony',
      latitude: 3.1554,
      longitude: 101.7142,
      category: 'Park & Fountain',
      description:
          'Urban park with shaded paths and the Lake Symphony fountains.',
    ),
    food: false,
    image: twinSpiresPhoto,
    price: 'Free entry',
    distance: '1 min walk · 80 m',
  ),
  (
    place: curatedMalaysianAttractions.firstWhere(
      (place) => place.xid == 'curated_kl_14',
    ),
    food: false,
    image: twinSpiresPhoto,
    price: 'Free entry',
    distance: '395 m',
  ),
];
