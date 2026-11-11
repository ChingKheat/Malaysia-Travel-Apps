import 'package:smart_travel_planner/l10n/localized_labels.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../core/config/supabase_config.dart';
import '../../places/services/google_places_service.dart';
import '../../places/services/place_photo_storage_service.dart';
import '../services/admin_places_repository.dart';
import '../services/place_details_refresh_service.dart';

class PlaceDetailsRefreshPage extends StatefulWidget {
  const PlaceDetailsRefreshPage({super.key, required this.state, this.service});
  final String state;
  final PlaceDetailsRefreshService? service;
  @override
  State<PlaceDetailsRefreshPage> createState() =>
      _PlaceDetailsRefreshPageState();
}

class _PlaceDetailsRefreshPageState extends State<PlaceDetailsRefreshPage> {
  PlaceDetailsRefreshService? _service;
  PlaceRefreshProgress? _progress;
  bool _running = false, _stop = false;
  String? _error;

  bool _cachingPhotos = false;
  bool _stopPhotos = false;
  int _photoCurrent = 0;
  int _photoTotal = 0;
  String? _photoStatus;
  @override
  void initState() {
    super.initState();
    _prepare();
  }

  Future<void> _prepare() async {
    try {
      final user = SupabaseConfig.client?.auth.currentUser?.id;
      if (widget.service == null && user == null) {
        throw StateError('Sign in as an administrator.');
      }
      final service =
          widget.service ??
          PlaceDetailsRefreshService(
            repository: AdminPlacesRepository(),
            google: GooglePlacesService(),
            preferences: await SharedPreferences.getInstance(),
            scope: '${SupabaseConfig.supabaseUrl}:$user',
          );
      if (mounted) {
        setState(() {
          _service = service;
          _progress = service.read(widget.state);
        });
      }
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    }
  }

  Future<void> _run({bool restart = false}) async {
    setState(() {
      _running = true;
      _stop = false;
      _error = null;
    });
    try {
      await _service!.run(
        widget.state,
        restart: restart,
        shouldContinue: () => mounted && !_stop,
        onProgress: (value) {
          if (mounted) setState(() => _progress = value);
        },
      );
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _running = false);
    }
  }

  Future<void> _cachePhotos({int limit = 30}) async {
    final client = SupabaseConfig.client;
    if (client == null) return;
    setState(() {
      _cachingPhotos = true;
      _stopPhotos = false;
      _photoCurrent = 0;
      _photoTotal = 0;
      _photoStatus = 'Querying top places in ${widget.state}…';
    });

    try {
      final rows = await client
          .from('places')
          .select('place_id')
          .eq('state', widget.state)
          .order('rating', ascending: false, nullsFirst: false)
          .limit(limit);

      final ids = (rows as List)
          .map((r) => r['place_id'] as String)
          .where((id) => id.startsWith('ChI'))
          .toList();

      if (ids.isEmpty) {
        if (mounted) {
          setState(() {
            _photoStatus = 'No saved places found in ${widget.state}.';
            _cachingPhotos = false;
          });
        }
        return;
      }

      setState(() {
        _photoTotal = ids.length;
        _photoStatus = 'Caching real photos (0/${ids.length})…';
      });

      final google = _service?.google ?? GooglePlacesService();
      final saved = await PlacePhotoStorageService.batchCachePhotos(
        placeIds: ids,
        googleService: google,
        shouldContinue: () => mounted && !_stopPhotos,
        onProgress: (current, total, cached) {
          if (mounted) {
            setState(() {
              _photoCurrent = current;
              _photoStatus =
                  'Cached $cached of $current inspected ($total target)…';
            });
          }
        },
      );

      if (mounted) {
        setState(() {
          _photoStatus = _stopPhotos
              ? 'Paused photo caching. Cached $saved photos.'
              : 'Finished! $saved real photos cached to Supabase Storage.';
        });
      }
    } catch (e) {
      if (mounted) setState(() => _photoStatus = 'Photo caching failed: $e');
    } finally {
      if (mounted) setState(() => _cachingPhotos = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final progress = _progress;
    return Scaffold(
      appBar: AppBar(title: Text(context.l10n.updateSavedPlaces)),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Text(widget.state, style: Theme.of(context).textTheme.headlineSmall),
          const SizedBox(height: 12),
          Text(
            context
                .l10n
                .updatesEverySavedGooglePlaceInThisStateIncludingOpeningHoursRatingsNameAndLocationYourCate,
          ),
          const SizedBox(height: 12),
          Text(
            context
                .l10n
                .usesTheFullDetailsAllowanceKeepThisPageOpenLeavingPausesTheUpdateProgressIsSavedOnThisDevi,
          ),
          const SizedBox(height: 20),
          if (progress != null) ...[
            LinearProgressIndicator(
              value: progress.ids.isEmpty
                  ? 0
                  : progress.next / progress.ids.length,
            ),
            const SizedBox(height: 12),
            Text(context.tr(progress.summary)),
            Text(context.tr(progress.message)),
          ],
          if (_error != null)
            Text(
              context.tr(_error!),
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          const SizedBox(height: 20),
          FilledButton.icon(
            onPressed: _running || _service == null ? null : () => _run(),
            icon: const Icon(Icons.sync),
            label: Text(
              _running
                  ? context.l10n.updating
                  : progress == null ||
                        (progress.finished && progress.issues.isEmpty)
                  ? context.l10n.updateAllSavedPlaces
                  : progress.finished
                  ? context.l10n.retryPlacesWithIssues
                  : context.l10n.resumeUpdate,
            ),
          ),
          if (_running)
            OutlinedButton(
              onPressed: _stop ? null : () => setState(() => _stop = true),
              child: Text(
                _stop ? context.l10n.pausing : context.l10n.pauseUpdate,
              ),
            ),
          if (!_running && progress != null && !progress.finished)
            TextButton(
              onPressed: () async {
                final updated = await _service?.skipCurrent(widget.state);
                if (mounted && updated != null) {
                  setState(() => _progress = updated);
                }
              },
              child: Text(
                context.l10n.skipPlaceValueAndContinue(
                  (progress.ids[progress.next]).toString(),
                ),
              ),
            ),
          if (!_running &&
              progress != null &&
              progress.finished &&
              progress.issues.isNotEmpty)
            TextButton(
              onPressed: () => _run(restart: true),
              child: Text(context.l10n.startANewUpdateOfAllSavedPlaces),
            ),
          if (progress != null && progress.issues.isNotEmpty)
            ExpansionTile(
              title: Text(context.l10n.placesNeedingReview),
              children: [
                for (final issue in progress.issues.entries)
                  ListTile(
                    title: SelectableText(issue.key),
                    subtitle: Text(context.tr(issue.value)),
                  ),
              ],
            ),
          const Divider(height: 40),
          Text(
            context.l10n.batchCacheRealPhotos,
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 6),
          Text(
            context
                .l10n
                .downloadsOfficialGooglePhotosForTopPlacesAndSavesThemToSupabaseStoragePlacesAlreadyCachedA,
            style: TextStyle(fontSize: 13, color: Color(0xFF64748B)),
          ),
          const SizedBox(height: 12),
          if (_cachingPhotos) ...[
            LinearProgressIndicator(
              value: _photoTotal > 0 ? _photoCurrent / _photoTotal : null,
            ),
            const SizedBox(height: 8),
          ],
          if (_photoStatus != null) ...[
            Text(
              context.tr(_photoStatus!),
              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
            ),
            const SizedBox(height: 8),
          ],
          Row(
            children: [
              Expanded(
                child: FilledButton.tonalIcon(
                  onPressed: _running || _cachingPhotos
                      ? null
                      : () => _cachePhotos(limit: 30),
                  icon: const Icon(Icons.photo_library),
                  label: Text(
                    _cachingPhotos
                        ? context.l10n.cachingPhotos
                        : context.l10n.cacheTop30Photos,
                  ),
                ),
              ),
              if (_cachingPhotos) ...[
                const SizedBox(width: 8),
                OutlinedButton(
                  onPressed: _stopPhotos
                      ? null
                      : () => setState(() => _stopPhotos = true),
                  child: Text(
                    _stopPhotos ? context.l10n.pausing : context.l10n.stop,
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}
