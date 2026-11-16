import 'package:smart_travel_planner/features/image_recognition/data/recognition_presets.dart';
import 'package:smart_travel_planner/features/image_recognition/data/visual_scan_results.dart';
import 'package:smart_travel_planner/features/image_recognition/models/recognition_result.dart';
import 'package:smart_travel_planner/shared/models/attraction.dart';

class ScanPlaceFacts {
  const ScanPlaceFacts({this.description, this.hours, this.source, this.image});

  final String? description;
  final String? hours;
  final String? source;
  final String? image;
}

const _park = ScanPlaceFacts(
  description:
      'A rainforest reserve in central Kuala Lumpur with elevated canopy bridges and views of the city skyline.',
  hours: 'Sat–Thu 8:00 AM–4:30 PM · Closed Friday',
  source: 'https://www.forestry.gov.my/en/your-voice',
  image: 'assets/recognition/kl_forest_eco_park.jpg',
);
const _towers = ScanPlaceFacts(
  hours:
      'Skybridge and observation deck: Tue–Sun 9:00 AM–10:30 PM. Selected Mondays 9:00 AM–8:00 PM.',
  source:
      'https://www.petronastwintowers.com.my/plan-your-visit/admission-ticketing/',
  image: 'assets/recognition/petronas.jpg',
);
const _batuCaves = ScanPlaceFacts(
  hours: 'Daily 6:00 AM–9:00 PM',
  source:
      'https://www.malaysia.travel/explore/4-top-cultural-destinations-in-selangor',
  image: 'assets/recognition/batu_caves.jpg',
);

const _guideFacts = {
  'kl forest eco park': _park,
  'kuala lumpur forest eco park': _park,
  'taman eko rimba kuala lumpur': _park,
  'petronas twin towers': _towers,
  'petronas twin towers (klcc)': _towers,
  'batu caves': _batuCaves,
  'batu caves & lord murugan': _batuCaves,
  'batu caves temple & murugan statue': _batuCaves,
  'nasi lemak': ScanPlaceFacts(image: 'assets/recognition/nasi_lemak.jpg'),
  'satay': ScanPlaceFacts(
    description:
        'Grilled meat skewers commonly served with peanut sauce, cucumber and rice cakes.',
  ),
  'aquaria klcc': ScanPlaceFacts(
    hours: 'Daily 10:00 AM–8:00 PM',
    source: 'https://www.suriaklcc.com.my/attractions/aquaria-klcc/',
  ),
  'resorts world genting': ScanPlaceFacts(
    description: 'A mountain resort in Pahang with hotels, SkyAvenue and the outdoor Genting SkyWorlds theme park.',
    hours: 'SkyWorlds: 10:00 AM–6:00 PM. Closed Tuesdays except public and school holidays. Other venues set their own hours.',
    source: 'https://www.gentingskyworlds.com/en.html',
  ),
  'central market (pasar seni)': ScanPlaceFacts(
    hours: 'Daily 10:00 AM–10:00 PM',
    source: 'https://centralmarket.com.my/',
  ),
  'thean hou temple': ScanPlaceFacts(
    hours: 'Daily 9:00 AM–6:00 PM',
    source: 'https://www.malaysia.travel/explore/top-places-to-visit-in-kuala-lumpur',
  ),
  'telaga tujuh waterfall': ScanPlaceFacts(
    description: 'A waterfall with a series of natural pools in the hills of Langkawi, also known as Seven Wells.',
  ),
  "madam kwan's · suria klcc": ScanPlaceFacts(
    hours: '8:00 AM–10:00 PM',
    source: 'https://www.madamkwans.com.my/store-locator',
  ),
  'klcc park & lake symphony': ScanPlaceFacts(
    hours: 'Park: daily 10:00 AM–10:00 PM',
    source: 'https://www.suriaklcc.com.my/attractions/klcc-park/',
  ),
};

ScanPlaceFacts scanFacts(
  String name, {
  String? description,
  String? subjectId,
}) {
  final key = name.trim().toLowerCase().replaceAll('’', "'");
  final facts = _guideFacts[key] ?? const ScanPlaceFacts();
  final preset = recognitionPresets
      .where(
        (preset) => preset.id == subjectId || preset.name.toLowerCase() == key,
      )
      .firstOrNull;
  return ScanPlaceFacts(
    description: description != null && description.trim().isNotEmpty
        ? description
        : facts.description ??
              preset?.description ??
              scanLandmarkByName(name)?.description,
    hours: facts.hours,
    source: facts.source,
    image: facts.image,
  );
}

ScanPlaceFacts candidateScanFacts(ReferenceSubject subject) =>
    scanFacts(subject.name, subjectId: subject.id);

ScanPlaceFacts nearbyScanFacts(Attraction place) =>
    scanFacts(place.name, description: place.description);
