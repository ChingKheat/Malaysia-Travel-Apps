import 'package:smart_travel_planner/features/image_recognition/data/recognition_presets.dart';
import 'package:smart_travel_planner/features/image_recognition/models/recognition_result.dart';
import 'package:smart_travel_planner/features/places/data/curated_attractions.dart';

String scanNameKey(String text) =>
    text.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), ' ').trim();

bool _containsName(String text, String name) =>
    name.isNotEmpty && ' $text '.contains(' $name ');

const _forestPark = ReferenceSubject(
  id: 'kl_forest_eco_park',
  name: 'KL Forest Eco Park',
  kind: 'landmark',
);

const _genting = ReferenceSubject(
  id: 'resorts_world_genting',
  name: 'Resorts World Genting',
  kind: 'landmark',
);

Iterable<String> _placeAliases(String name) sync* {
  yield name;
  yield name.split(' (').first;
  for (final match in RegExp(r'\(([^)]+)\)').allMatches(name)) {
    final alias = match[1]!;
    if (alias.trim().contains(' ')) yield alias;
  }
}

final _knownNames = <String, ReferenceSubject>{
  for (final place in curatedMalaysianAttractions)
    for (final alias in _placeAliases(place.name))
      scanNameKey(alias): ReferenceSubject(
        id: place.xid,
        name: place.name,
        kind: 'landmark',
      ),
  for (final preset in recognitionPresets)
    for (final name in [preset.name, ...preset.aliases])
      scanNameKey(name): ReferenceSubject(
        id: preset.id,
        name: preset.name,
        kind: preset.kind,
      ),
  'kl forest eco park': _forestPark,
  'kuala lumpur forest eco park': _forestPark,
  'taman eko rimba kuala lumpur': _forestPark,
  'bukit nanas forest reserve': _forestPark,
  'resorts world genting': _genting,
  'genting highlands resort': _genting,
};

ReferenceSubject? knownScanLandmark(String name) {
  final subject = _knownNames[scanNameKey(name)];
  return subject?.kind == 'landmark' ? subject : null;
}

final _landmarkWord = RegExp(
  r'\b(bridge|caves?|castle|falls|waterfall|fort|garden|geopark|hill|'
  r'island|masjid|mosque|mount|museum|palace|park|building|'
  r'plaza|reserve|square|taman|temple|tower|walkway|market|church|aquarium|'
  r'resort|highlands|funicular|'
  r'air terjun|bukit|gua|istana|jambatan|menara|muzium)\b',
);
final _malaysia = RegExp(
  r'\b(malaysia|kuala lumpur|penang|melaka|malacca|selangor|johor|sabah|'
  r'sarawak|kedah|langkawi|putrajaya|kuching|pahang|perak|terengganu|'
  r'kelantan|perlis|labuan|negeri sembilan)\b',
);

bool _malaysianNameInTitle(String name, String title) {
  if (_malaysia.hasMatch(name)) return _containsName(title, name);
  for (final location in _malaysia.allMatches(title)) {
    final before = title.substring(0, location.start).trimRight();
    final after = title.substring(location.end).trimLeft();
    if (before == name ||
        before.endsWith(' $name') ||
        before.endsWith(' $name in') ||
        before == '$name in' ||
        after == name ||
        after.startsWith('$name ')) {
      return true;
    }
  }
  return false;
}

const _genericNames = {
  'architecture',
  'aerial',
  'bridge',
  'building',
  'canopy',
  'city',
  'forest',
  'garden',
  'high',
  'historic',
  'landmark',
  'national',
  'nature',
  'public',
  'park',
  'rainforest',
  'rise',
  'skyline',
  'suspension',
  'tourist',
  'tropical',
  'view',
  'walkway',
  'wooden',
};

typedef ClueMatch = ({
  ReferenceSubject? identified,
  List<ReferenceSubject> candidates,
  List<String> domains,
  bool web,
  List<String> searchNames,
  String? area,
  String? visualSuggestion,
  String? foodSuggestion,
});

ClueMatch matchPhotoClues(Map<String, dynamic> data) {
  final pages = <({String domain, String title, bool full})>[
    for (final page in (data['pages'] as List? ?? const []).whereType<Map>())
      if (page['domain'] is String && page['title'] is String)
        (
          domain: page['domain'] as String,
          title: scanNameKey(page['title'] as String),
          full: page['full'] == true,
        ),
  ];
  final rawText = data['text'] as String? ?? '';
  final text = scanNameKey(rawText);
  final signLines = (data['lines'] as List? ?? const []).whereType<String>();
  final searchNames = <String>{};
  for (final line in signLines) {
    final name = scanNameKey(line);
    if (name.contains(' ') &&
        _landmarkWord.hasMatch(name) &&
        !RegExp(r'[0-9@:/]').hasMatch(line) &&
        line.length <= 72) {
      searchNames.add(line);
    }
  }
  final subjects = <String, ReferenceSubject>{};
  final aliases = <String, Set<String>>{};
  final signSubjects = <String>{};
  final webSubjects = <String>{};
  final webNames = (data['names'] as List? ?? const []).whereType<String>();
  final suggestion = data['visualSuggestion'];
  final food = data['foodSuggestion'];
  final foodSuggestion =
      food is String && food.length <= 90 && scanNameKey(food).length >= 3
      ? food.trim()
      : null;
  final visualSuggestion =
      suggestion is String &&
          suggestion.length <= 90 &&
          scanNameKey(suggestion).contains(' ')
      ? suggestion.trim()
      : null;
  String? findArea(Iterable<String> names) => names
      .where((name) {
        final key = scanNameKey(name).replaceFirst(RegExp(r' malaysia$'), '');
        return key != 'malaysia' && _malaysia.stringMatch(key) == key;
      })
      .firstOrNull
      ?.trim()
      .replaceFirst(RegExp(r'[\s,]+malaysia$', caseSensitive: false), '');
  final signArea = findArea([...signLines, rawText]);
  final area = signArea ?? findArea(webNames);

  void add(ReferenceSubject subject, String name) {
    subjects[subject.id] = subject;
    (aliases[subject.id] ??= {}).add(name);
  }

  for (final entry in _knownNames.entries) {
    if (entry.key.length < 5) continue;
    if (pages.any((page) => _containsName(page.title, entry.key))) {
      add(entry.value, entry.key);
    }
    if (entry.value.kind == 'landmark' &&
        entry.key.contains(' ') &&
        _containsName(text, entry.key)) {
      add(entry.value, entry.key);
      signSubjects.add(entry.value.id);
    }
  }

  for (final name in webNames) {
    final key = scanNameKey(name);
    if (key.length < 6 || name.length > 88) {
      continue;
    }
    final exact = _knownNames[key];
    if (exact != null) {
      add(exact, key);
      webSubjects.add(exact.id);
      continue;
    }
    final known = _knownNames.entries
        .where((entry) => _containsName(key, entry.key))
        .firstOrNull;
    if (known != null) {
      add(known.value, known.key);
      webSubjects.add(known.value.id);
      continue;
    }
    if (!key.contains(' ') ||
        !key
            .split(' ')
            .any((word) => !_genericNames.contains(word) && word.length > 2)) {
      continue;
    }
    final namedPages = pages.where((page) => _containsName(page.title, key));
    if ((signArea != null && _landmarkWord.hasMatch(key)) ||
        namedPages.any((page) => page.full) ||
        namedPages.map((page) => page.domain).toSet().length >= 2) {
      searchNames.add(name);
    }
    if (!_landmarkWord.hasMatch(key)) continue;
    if (!pages.any((page) => _malaysianNameInTitle(key, page.title))) {
      continue;
    }
    add(ReferenceSubject(id: 'web:$key', name: name, kind: 'landmark'), key);
    webSubjects.add('web:$key');
  }

  final ranked =
      [
            for (final subject in subjects.values)
              (
                subject: subject,
                pages: [
                  for (final page in pages)
                    if (aliases[subject.id]!.any(
                          (name) => _containsName(page.title, name),
                        ) &&
                        (!subject.id.startsWith('web:') ||
                            _malaysianNameInTitle(
                              scanNameKey(subject.name),
                              page.title,
                            )))
                      page,
                ],
              ),
          ]
          .where(
            (entry) =>
                entry.pages.any((page) => page.full) ||
                entry.pages.map((page) => page.domain).toSet().length >= 2 ||
                signSubjects.contains(entry.subject.id) ||
                webSubjects.contains(entry.subject.id),
          )
          .toList();

  int score(List<({String domain, String title, bool full})> hits) =>
      hits.map((page) => page.domain).toSet().length +
      hits.where((page) => page.full).map((page) => page.domain).toSet().length;

  ranked.sort((a, b) => score(b.pages).compareTo(score(a.pages)));
  if (ranked.isEmpty) {
    return (
      identified: null,
      candidates: const [],
      domains: const [],
      web: false,
      searchNames: searchNames.take(2).toList(),
      area: area,
      visualSuggestion: visualSuggestion,
      foodSuggestion: foodSuggestion,
    );
  }
  final first = ranked.first;
  final domains = first.pages.map((page) => page.domain).toSet();
  final fullDomains = first.pages
      .where((page) => page.full)
      .map((page) => page.domain)
      .toSet();
  final strong =
      fullDomains.length >= 2 ||
      (fullDomains.isNotEmpty && signSubjects.contains(first.subject.id));
  final competing = ranked
      .skip(1)
      .any(
        (entry) =>
            (entry.pages.isNotEmpty &&
                score(first.pages) - score(entry.pages) < 2) ||
            signSubjects.contains(entry.subject.id),
      );
  return (
    identified: strong && !competing ? first.subject : null,
    candidates: [for (final entry in ranked.take(3)) entry.subject],
    domains: domains.take(3).toList(),
    web: ranked.any(
      (entry) =>
          entry.pages.isNotEmpty || webSubjects.contains(entry.subject.id),
    ),
    searchNames: searchNames.take(2).toList(),
    area: area,
    visualSuggestion: visualSuggestion,
    foodSuggestion: foodSuggestion,
  );
}
