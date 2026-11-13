import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'place_details_refresh_service.dart';
import 'place_sync_history_service.dart';

/// Owns running work independently of any route. Checkpoints remain on disk.
class PlaceRefreshTask extends ChangeNotifier {
  PlaceRefreshTask._(this.service, this.state);
  static final _tasks = <String, PlaceRefreshTask>{};
  static const _channel = MethodChannel('smart_travel/place_sync');
  static int _leases = 0;
  static bool _handlerInstalled = false;
  static PlaceRefreshTask attach(
    PlaceDetailsRefreshService service,
    String state,
  ) {
    final key = '${service.scope}:$state';
    final existing = _tasks[key];
    if (existing != null && existing.running) return existing;
    return _tasks[key] = PlaceRefreshTask._(service, state);
  }

  final PlaceDetailsRefreshService service;
  final String state;
  PlaceRefreshProgress? get progress => _progress ?? service.read(state);
  PlaceRefreshProgress? _progress;
  Future<PlaceRefreshProgress>? _future;
  bool running = false;
  bool stopping = false;
  String? error;
  void pause() {
    stopping = true;
    notifyListeners();
  }

  Future<PlaceRefreshProgress> run({
    bool restart = false,
    bool Function()? allowed,
  }) {
    if (_future != null) return _future!;
    running = true;
    stopping = false;
    error = null;
    _future = _execute(restart, allowed);
    notifyListeners();
    return _future!;
  }

  Future<PlaceRefreshProgress> _execute(
    bool restart,
    bool Function()? allowed,
  ) async {
    var leased = false;
    final android = !kIsWeb && defaultTargetPlatform == TargetPlatform.android;
    try {
      if (android) {
        if (!_handlerInstalled) {
          _channel.setMethodCallHandler((call) async {
            if (call.method == 'stopped') {
              for (final task in _tasks.values.where((t) => t.running)) {
                task.pause();
              }
            }
          });
          _handlerInstalled = true;
        }
        if (_leases++ == 0) {
          try {
            await _channel.invokeMethod<void>('start');
          } catch (_) {
            _leases--;
            rethrow;
          }
        }
        leased = true;
      }
      final result = await service.run(
        state,
        restart: restart,
        shouldContinue: () => !stopping && (allowed?.call() ?? true),
        onProgress: (value) {
          _progress = value;
          notifyListeners();
        },
      );
      if (service.scope.endsWith(':unified') &&
          result.finished &&
          result.issues.isEmpty) {
        final key = 'places_sync_pending:${service.scope}:$state';
        if (service.preferences.containsKey(key)) {
          await PlaceSyncHistoryService().recordSuccess(
            state: state,
            placeCount: result.saved,
            requestCount: service.preferences.getInt('$key:requests') ?? 0,
          );
          await service.preferences.remove(key);
          await service.preferences.remove('$key:requests');
        }
      }
      return result;
    } catch (e) {
      error = e is MissingPluginException
          ? 'Install the rebuilt Android app to enable background sync. Saved progress is retained.'
          : e.toString();
      rethrow;
    } finally {
      if (leased && --_leases == 0) {
        try {
          await _channel.invokeMethod<void>('stop');
        } catch (_) {}
      }
      running = false;
      _future = null;
      notifyListeners();
    }
  }
}
