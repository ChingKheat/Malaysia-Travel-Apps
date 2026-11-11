import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../../places/services/google_places_service.dart';
import '../../places/services/place_catalog_service.dart';
import 'admin_places_repository.dart';

class PlaceRefreshProgress {
  PlaceRefreshProgress({
    required this.ids,
    this.next = 0,
    this.saved = 0,
    Map<String, String>? issues,
    this.message = '',
  }) : issues = issues ?? {};
  final List<String> ids;
  int next;
  int saved;
  final Map<String, String> issues;
  String message;
  bool get finished => next == ids.length;
  String get summary =>
      '$saved updated · ${issues.length} need review · ${ids.length - next} remaining';
  Map<String, dynamic> toJson() => {
    'ids': ids,
    'next': next,
    'saved': saved,
    'issues': issues,
    'message': message,
  };
  factory PlaceRefreshProgress.fromJson(Map<String, dynamic> data) =>
      PlaceRefreshProgress(
        ids: List<String>.from(data['ids'] as List),
        next: data['next'] as int,
        saved: data['saved'] as int,
        issues: Map<String, String>.from(data['issues'] as Map),
        message: data['message'] as String,
      );
}

/// Snapshot IDs once; resume by ID, not an offset into a changing catalog.
/// Checkpoints contain IDs/status only and are scoped to project + admin account.
class PlaceDetailsRefreshService {
  PlaceDetailsRefreshService({
    required this.repository,
    required this.google,
    required this.preferences,
    required this.scope,
    this.interval = const Duration(milliseconds: 850),
  });
  final AdminPlacesRepository repository;
  final GooglePlacesService google;
  final SharedPreferences preferences;
  final String scope;
  final Duration interval;
  static final Set<String> _running = {};
  String _key(String state) => 'place_details_refresh_v1:$scope:$state';
  PlaceRefreshProgress? read(String state) {
    final raw = preferences.getString(_key(state));
    return raw == null
        ? null
        : PlaceRefreshProgress.fromJson(
            jsonDecode(raw) as Map<String, dynamic>,
          );
  }

  Future<void> _persist(String state, PlaceRefreshProgress progress) async {
    if (!await preferences.setString(
      _key(state),
      jsonEncode(progress.toJson()),
    )) {
      throw StateError(
        'Unable to save progress. Stop and retry before continuing.',
      );
    }
  }

  Future<PlaceRefreshProgress?> skipCurrent(String state) async {
    final progress = read(state);
    if (progress == null || progress.finished) return progress;
    final id = progress.ids[progress.next];
    progress.issues[id] = 'Skipped by administrator; existing data preserved.';
    progress.next++;
    progress.message = progress.finished
        ? (progress.issues.isEmpty
            ? 'All saved places updated.'
            : 'Pass finished with issues. Retry to review failed places.')
        : 'Skipped $id. Resume to continue updating places in $state.';
    await _persist(state, progress);
    return progress;
  }

  Future<PlaceRefreshProgress> run(
    String state, {
    bool restart = false,
    required bool Function() shouldContinue,
    required void Function(PlaceRefreshProgress) onProgress,
  }) async {
    if (!_running.add(_key(state))) {
      throw StateError('This state is already updating.');
    }
    try {
      var progress = restart ? null : read(state);
      if (progress == null || (progress.finished && progress.issues.isEmpty)) {
        final ids = <String>{};
        for (var offset = 0; ; offset += 20) {
          if (!shouldContinue()) {
            throw StateError('Stopped before refresh started.');
          }
          final page = await repository.load(state, offset: offset);
          ids.addAll(
            page.rows
                .where(PlaceCatalogService.isGoogleReference)
                .map((r) => r['place_id'] as String),
          );
          if (offset + page.rows.length >= page.totalCount ||
              page.rows.isEmpty) {
            break;
          }
        }
        progress = PlaceRefreshProgress(ids: ids.toList());
        await _persist(state, progress);
      } else if (progress.finished) {
        // A completed pass with invalid places retries those IDs only.
        progress = PlaceRefreshProgress(ids: progress.issues.keys.toList());
        await _persist(state, progress);
      }
      onProgress(progress);
      while (!progress.finished) {
        if (!shouldContinue()) {
          progress.message = 'Paused. Resume to continue from the next place.';
          break;
        }
        final id = progress.ids[progress.next];
        try {
          final details = await google.fetchDetails(id, basic: false);
          if (details == null) {
            if (google.lastStatusCode == 404 ||
                google.lastStatusCode == 410 ||
                google.lastStatusCode == 400) {
              progress.issues[id] =
                  'Google place unavailable (${google.lastStatusCode}); existing data preserved.';
              progress.next++;
              await _persist(state, progress);
              onProgress(progress);
              if (!progress.finished) await Future<void>.delayed(interval);
              continue;
            }
            // Includes quota, sign-in, network and invalid ID. Keep the cursor.
            progress.message =
                '${google.lastError ?? 'Details unavailable'} Resume to retry $id.';
            break;
          }
          if (!shouldContinue()) {
            progress.message =
                'Paused before saving. Resume to retry this place.';
            break;
          }
          if (details.id != id ||
              AdminPlacesRepository.googleState(details.data) != state) {
            progress.issues[id] =
                'ID or state mismatch; existing data preserved.';
          } else {
            final row = <String, dynamic>{
              'place_id': id,
              '_live': true,
              '_fullDetails': true,
              '_addressComponents': details.data['addressComponents'],
              'name': details.name,
              'latitude': details.latitude,
              'longitude': details.longitude,
              'rating': details.rating,
              'user_ratings_total': details.reviewCount,
              'operating_hours': details.data['regularOpeningHours'],
              'attributions': details.attributions,
            };
            try {
              AdminPlacesRepository.importRow(state, row);
            } on FormatException {
              progress.issues[id] =
                  'Missing name or valid coordinates; existing data preserved.';
            }
            if (!progress.issues.containsKey(id)) {
              if (await repository.saveFetchedRows(state, [row]) != 1) {
                throw StateError('Database update was not confirmed');
              }
              progress.saved++;
            }
          }
          progress.next++;
          progress.message = progress.finished
              ? (progress.issues.isEmpty
                    ? 'All saved places updated.'
                    : 'Pass finished with issues. Retry to review failed places.')
              : 'Updating existing places in $state…';
          await _persist(state, progress);
          onProgress(progress);
          if (!progress.finished) await Future<void>.delayed(interval);
        } catch (error) {
          progress.message =
              'Paused: $error. Previously saved updates are retained.';
          break;
        }
      }
      if (progress.ids.isEmpty) {
        progress.message = 'No saved Google places in this state.';
      } else if (progress.finished && progress.issues.isNotEmpty) {
        progress.message =
            'Pass finished with issues. Existing data for those places was preserved.';
      }
      await _persist(state, progress);
      onProgress(progress);
      return progress;
    } finally {
      _running.remove(_key(state));
    }
  }
}
