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
    description: 'A historic building facing Merdeka Square, known for its '
        'clock tower, copper domes and graceful arches. Photograph the facade '
        'from the square and explore the surrounding heritage district.',
    aliases: ['sultan abdul samad'],
  ),
  RecognitionPreset(
    id: 'petronas',
    name: 'Petronas Twin Towers',
    kind: 'landmark',
    location: 'KLCC, Kuala Lumpur',
    description: 'Malaysia’s iconic twin skyscrapers, linked by a skybridge. '
        'Explore KLCC Park and Suria KLCC nearby. Check the official visitor '
        'website for observation deck tickets and current opening hours.',
    aliases: ['petronas', 'petronas towers'],
  ),
  RecognitionPreset(
    id: 'batu_caves',
    name: 'Batu Caves & Lord Murugan',
    kind: 'landmark',
    location: 'Gombak, Selangor',
    description: 'A limestone cave temple complex with colourful steps and a '
        'large golden statue of Lord Murugan. Dress respectfully, bring water '
        'and keep food secured around the resident monkeys.',
    aliases: ['batu caves', 'lord murugan', 'murugan statue'],
  ),
  RecognitionPreset(
    id: 'nasi_lemak',
    name: 'Nasi Lemak',
    kind: 'food',
    location: 'Found throughout Malaysia',
    description: 'Fragrant coconut rice traditionally served with sambal, '
        'anchovies, peanuts, cucumber and egg. Variations may include fried '
        'chicken or rendang. Ingredients vary; ask the vendor about allergens '
        'and dietary requirements.',
    aliases: ['nasi lemak', 'nasi lemak bungkus'],
  ),
];
