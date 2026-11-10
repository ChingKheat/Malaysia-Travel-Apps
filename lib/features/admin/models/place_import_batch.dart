import '../services/admin_places_repository.dart';

/// Import counters count occurrences; unique rows and conflicts count IDs.
class PlaceImportBatch {
  PlaceImportBatch(this.state);
  final String state;
  int returned = 0, stateAccepted = 0, invalid = 0, wrongState = 0;
  final Map<String, Map<String, dynamic>> rows = {};
  final Map<String, Set<String>> categories = {};
  int get conflicts => categories.values.where((v) => v.length > 1).length;
  void add(Map<String, dynamic> p, String category) {
    returned++;
    if (AdminPlacesRepository.googleState(p) != state) {
      wrongState++;
      return;
    }
    stateAccepted++;
    final location = p['location'] as Map?;
    final row = <String, dynamic>{
      'place_id': p['id'],
      'name': (p['displayName'] as Map?)?['text'],
      'latitude': location?['latitude'],
      'longitude': location?['longitude'],
      'app_category': category,
    };
    try {
      AdminPlacesRepository.importRow(state, row);
    } on FormatException {
      invalid++;
      return;
    }
    final lat = row['latitude'] as num;
    final lng = row['longitude'] as num;
    if (state == 'Kuala Lumpur' &&
        (lat < 2.8 || lat > 3.5 || lng < 101.4 || lng > 102.1)) {
      invalid++;
      return;
    }
    final id = row['place_id'] as String;
    categories.putIfAbsent(id, () => {}).add(category);
    // Ambiguous discoveries stay unclassified until an admin reviews them.
    row['app_category'] = categories[id]!.length > 1 ? 'Attraction' : category;
    rows[id] = row;
  }

  String get summary =>
      'Returned $returned · state accepted $stateAccepted · unique ${rows.length} · wrong state $wrongState · invalid $invalid · category review $conflicts';
}
