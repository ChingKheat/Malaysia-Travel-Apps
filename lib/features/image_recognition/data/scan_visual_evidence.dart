import 'package:smart_travel_planner/features/image_recognition/models/recognition_result.dart';

// Each group represents a distinct feature. A single generic label such as
// "bridge", "food" or "building" cannot suggest a named subject by itself.
const _subjects = [
  (
    ReferenceSubject(
      id: 'kl_forest_eco_park',
      name: 'KL Forest Eco Park',
      kind: 'landmark',
    ),
    [
      ['bridge', 'canopy walkway', 'suspension bridge'],
      ['forest', 'tree', 'trees', 'rainforest', 'jungle'],
    ],
  ),
  (
    ReferenceSubject(
      id: 'batu_caves',
      name: 'Batu Caves & Lord Murugan',
      kind: 'landmark',
    ),
    [
      ['cave', 'limestone', 'karst'],
      ['statue', 'hindu temple', 'murugan', 'rainbow stairs'],
    ],
  ),
  (
    ReferenceSubject(
      id: 'petronas',
      name: 'Petronas Twin Towers',
      kind: 'landmark',
    ),
    [
      ['twin towers', 'twin skyscrapers', 'skybridge'],
      ['tower', 'skyscraper', 'high rise building'],
    ],
  ),
  (
    ReferenceSubject(id: 'satay', name: 'Satay', kind: 'food'),
    [
      ['skewer', 'kebab', 'yakitori'],
      ['grilled meat', 'barbecue', 'peanut sauce'],
    ],
  ),
  (
    ReferenceSubject(id: 'nasi_lemak', name: 'Nasi Lemak', kind: 'food'),
    [
      ['coconut rice', 'rice'],
      ['sambal', 'anchovies'],
    ],
  ),
];

List<ReferenceSubject> suggestionsFromVisualEvidence(List<String> labels) {
  final normalized = labels
      .map(
        (label) =>
            ' ${label.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), ' ').trim()} ',
      )
      .toSet();
  final matches = <ReferenceSubject>[];
  for (final (subject, groups) in _subjects) {
    // Keep matched labels separate so one description cannot satisfy two clues.
    final features = [
      for (final group in groups)
        normalized
            .where((label) => group.any((word) => label.contains(' $word ')))
            .toSet(),
    ];
    if (features.every((group) => group.isNotEmpty) &&
        features.expand((group) => group).toSet().length >= features.length) {
      matches.add(subject);
    }
  }
  return matches;
}
