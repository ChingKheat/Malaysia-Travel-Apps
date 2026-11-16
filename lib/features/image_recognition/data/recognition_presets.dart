import 'package:smart_travel_planner/features/image_recognition/models/recognition_result.dart';

class RecognitionPreset {
  const RecognitionPreset({
    required this.id,
    required this.name,
    required this.kind,
    required this.location,
    required this.description,
    required this.aliases,
  });

  final String id;
  final String name;
  final String kind;
  final String location;
  final String description;
  final List<String> aliases;

  String get imageAsset => 'assets/recognition/$id.jpg';

  RecognitionResult sampleResult() => RecognitionResult(
    name: name,
    kind: kind,
    description: description,
    location: location,
    recognizedAt: DateTime.now(),
    sampleId: id,
  );
}

const recognitionPresets = [
  RecognitionPreset(
    id: 'sultan_abdul_samad',
    name: 'Sultan Abdul Samad Building',
    kind: 'landmark',
    location: 'Merdeka Square, Kuala Lumpur',
    description:
        'Built in 1897 for the British administration, the Sultan '
        'Abdul Samad Building faces Merdeka Square. Look for its Moorish-style '
        'arches, copper domes and central clock tower. The open square gives '
        'you room to photograph the long facade in one frame.',
    aliases: ['sultan abdul samad'],
  ),
  RecognitionPreset(
    id: 'petronas',
    name: 'Petronas Twin Towers',
    kind: 'landmark',
    location: 'KLCC, Kuala Lumpur',
    description:
        'These twin skyscrapers have an eight-pointed floor plan '
        'inspired by Islamic geometry. The double-deck Skybridge links the '
        'towers at levels 41 and 42, and visitors can see Kuala Lumpur from '
        'the observation deck on level 86. KLCC Park offers a view of both '
        'towers from the ground.',
    aliases: ['petronas', 'petronas towers'],
  ),
  RecognitionPreset(
    id: 'batu_caves',
    name: 'Batu Caves & Lord Murugan',
    kind: 'landmark',
    location: 'Gombak, Selangor',
    description:
        'Batu Caves is a Hindu temple complex set into a limestone '
        'hill in Gombak. A golden statue of Lord Murugan stands beside the '
        '272 colourful steps to the main temple cave. The site is a centre '
        'for Thaipusam celebrations. Dress respectfully and keep food secured '
        'around the resident monkeys.',
    aliases: ['batu caves', 'lord murugan', 'murugan statue'],
  ),
  RecognitionPreset(
    id: 'nasi_lemak',
    name: 'Nasi Lemak',
    kind: 'food',
    location: 'Found throughout Malaysia',
    description:
        'Fragrant coconut rice traditionally served with sambal, '
        'anchovies, peanuts, cucumber and egg. Variations may include fried '
        'chicken or rendang. Ingredients vary; ask the vendor about allergens '
        'and dietary requirements.',
    aliases: ['nasi lemak', 'nasi lemak bungkus'],
  ),
];
