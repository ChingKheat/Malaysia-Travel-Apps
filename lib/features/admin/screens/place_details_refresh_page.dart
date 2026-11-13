import 'package:smart_travel_planner/l10n/localized_labels.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../core/config/supabase_config.dart';
import '../../places/services/google_places_service.dart';
import '../services/admin_places_repository.dart';
import '../services/place_details_refresh_service.dart';
import '../services/place_refresh_task.dart';

class PlaceDetailsRefreshPage extends StatefulWidget {
  const PlaceDetailsRefreshPage({
    super.key,
    required this.state,
    this.service,
    this.syncFlow = false,
    this.restartOnStart = false,
  });
  final String state;
  final PlaceDetailsRefreshService? service;
  final bool syncFlow;
  final bool restartOnStart;
  @override
  State<PlaceDetailsRefreshPage> createState() =>
      _PlaceDetailsRefreshPageState();
}

class _PlaceDetailsRefreshPageState extends State<PlaceDetailsRefreshPage> {
  PlaceDetailsRefreshService? _service;
  PlaceRefreshTask? _task;
  PlaceRefreshProgress? _progress;
  bool _running = false, _stop = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _prepare();
  }

  void _observeTask() {
    if (!mounted) return;
    setState(() {
      _progress = _task?.progress;
      _running = _task?.running ?? false;
      _stop = _task?.stopping ?? false;
      _error = _task?.error;
    });
  }

  @override
  void dispose() {
    _task?.removeListener(_observeTask);
    super.dispose();
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
        _task = PlaceRefreshTask.attach(service, widget.state);
        _task!.addListener(_observeTask);
        setState(() {
          _service = _task!.service;
          _progress = _task!.progress;
        });
        if (widget.syncFlow &&
            !widget.restartOnStart &&
            !_task!.running &&
            _progress?.finished == true &&
            _progress!.issues.isEmpty) {
          Navigator.pop(context, _progress!.saved);
        } else if (widget.syncFlow) {
          await _run(restart: widget.restartOnStart);
        } else {
          _observeTask();
        }
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
      final user = SupabaseConfig.client?.auth.currentUser?.id;
      final result = await _task!.run(
        restart: restart,
        allowed: () =>
            user == null || SupabaseConfig.client?.auth.currentUser?.id == user,
      );
      if (mounted &&
          widget.syncFlow &&
          result.finished &&
          result.issues.isEmpty &&
          ModalRoute.of(context)?.isCurrent == true) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(result.coverSummary)));
        Navigator.pop(context, result.saved);
      }
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _running = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final progress = _progress;
    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.syncFlow
              ? 'Sync places · 2/2'
              : context.l10n.updateSavedPlaces,
        ),
      ),
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
          const Text(
            'On Android, updates continue when you leave this page, switch apps or lock the screen. A sync notification stays active. Pause stops the task. Force-stopping the app interrupts it; saved progress can be resumed. Missing Google hours remain unknown.',
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
            Text(progress.coverSummary),
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
              onPressed: _stop ? null : () => _task?.pause(),
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
        ],
      ),
    );
  }
}
