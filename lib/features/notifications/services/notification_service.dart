import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:smart_travel_planner/features/auth/services/auth_service.dart';
import 'package:smart_travel_planner/features/community/community_service.dart';
import 'package:smart_travel_planner/features/itinerary/models/itinerary_models.dart';
import 'package:smart_travel_planner/features/itinerary/services/supabase_itinerary_service.dart';
import 'package:smart_travel_planner/features/notifications/models/app_notification.dart';

typedef NotificationLoader =
    Future<List<AppNotification>> Function(String accountId);

/// Builds notifications from saved itineraries and actual community comments.
/// Read state and a cache remain on-device so the inbox works offline.
class NotificationService extends ChangeNotifier {
  NotificationService._({this._loader, bool initialize = true}) {
    _accountId = AuthService().currentUser?.uid ?? 'guest';
    if (!initialize) {
      _initialization = Future.value();
      return;
    }
    AuthService().addListener(_handleAccountChange);
    _initialization = _restoreCache();
    unawaited(_initialization.then((_) => refresh()));
  }

  @visibleForTesting
  NotificationService.forTesting({required NotificationLoader loader})
    : this._(loader: loader, initialize: false);

  static final NotificationService _instance = NotificationService._();
  factory NotificationService() => _instance;

  final NotificationLoader? _loader;
  late String _accountId;
  List<AppNotification> _notifications = [];
  bool _isRefreshing = false;
  late Future<void> _initialization;
  int _generation = 0;

  List<AppNotification> get notifications => List.unmodifiable(_notifications);
  int get unreadCount => _notifications.where((item) => !item.isRead).length;
  bool get isRefreshing => _isRefreshing;

  void _handleAccountChange() {
    final nextAccount = AuthService().currentUser?.uid ?? 'guest';
    if (nextAccount == _accountId) return;
    _accountId = nextAccount;
    _notifications = [];
    _isRefreshing = false;
    final generation = ++_generation;
    notifyListeners();
    _initialization = _restoreCache(generation: generation);
    unawaited(_initialization.then((_) => refresh()));
  }

  Future<void> _restoreCache({int? generation}) async {
    final account = _accountId;
    final loadGeneration = generation ?? _generation;
    try {
      final preferences = await SharedPreferences.getInstance();
      await preferences.remove('notifications.read.v1:$account');
      final encoded = preferences.getString(_cacheKey(account));
      if (encoded == null) return;
      final raw = jsonDecode(encoded) as List<dynamic>;
      final cached = raw
          .whereType<Map>()
          .map(
            (row) => AppNotification.fromJson(Map<String, dynamic>.from(row)),
          )
          .toList();
      if (account != _accountId || loadGeneration != _generation) return;
      _notifications = cached;
      notifyListeners();
    } catch (_) {
      // An unreadable cache leaves the inbox empty until the next refresh.
    }
  }

  Future<void> refresh() async {
    if (_isRefreshing) return;
    final account = _accountId;
    final generation = _generation;
    _isRefreshing = true;
    notifyListeners();
    try {
      final loaded = _loader == null
          ? await _loadFromApplication(account)
          : await _loader(account);
      if (account != _accountId || generation != _generation) return;
      final prior = {for (final item in _notifications) item.id: item};
      _notifications = [
        for (final incoming in loaded)
          incoming.copyWith(
            isRead: prior[incoming.id]?.isRead ?? incoming.isRead,
            createdAt: prior[incoming.id]?.createdAt,
          ),
      ]..sort((a, b) => b.createdAt.compareTo(a.createdAt));
      await _persistCache(account);
    } catch (_) {
      // Retain cached notifications when Supabase or local storage is offline.
    } finally {
      if (generation == _generation) {
        _isRefreshing = false;
        notifyListeners();
      }
    }
  }

  Future<List<AppNotification>> _loadFromApplication(String account) async {
    final itineraryService = SupabaseItineraryService();
    await itineraryService.syncPending();
    final trips = await itineraryService.getSavedItineraries(refresh: false);
    final result = <AppNotification>[..._tripReminders(trips)];

    final community = CommunityService();
    if (account != 'guest') {
      if (community.canSync) {
        try {
          final comments = await community.loadCommentActivity();
          for (final row in comments) {
            final id = row['id']?.toString();
            final postId = row['post_id']?.toString();
            final createdAt = DateTime.tryParse(
              row['created_at']?.toString() ?? '',
            );
            if (id == null || postId == null || createdAt == null) continue;
            result.add(
              AppNotification(
                id: 'comment:$id',
                type: AppNotificationType.communityComment,
                createdAt: createdAt.toLocal(),
                isRead: false,
                relatedEntityId: postId,
                commentPreview: row['body']?.toString(),
              ),
            );
          }
        } catch (_) {
          _appendCachedComments(result);
        }
      } else {
        _appendCachedComments(result);
      }
    }
    return result;
  }

  void _appendCachedComments(List<AppNotification> result) {
    final cutoff = DateTime.now().subtract(const Duration(days: 30));
    result.addAll(
      _notifications.where(
        (item) =>
            item.type == AppNotificationType.communityComment &&
            item.createdAt.isAfter(cutoff),
      ),
    );
  }

  List<AppNotification> _tripReminders(List<Itinerary> trips) {
    final now = DateTime.now();
    final reminders = <AppNotification>[];
    for (final trip in trips) {
      final schedules = [...trip.dailySchedules]
        ..sort((a, b) => a.scheduleDate.compareTo(b.scheduleDate));
      if (trip.itineraryId.isEmpty ||
          schedules.isEmpty ||
          schedules.first.stops.isEmpty) {
        continue;
      }
      final firstDay = schedules.first;
      final firstStop = [...firstDay.stops]
        ..sort((a, b) => a.stopOrder.compareTo(b.stopOrder));
      final timeParts = firstStop.first.arrivalTime.split(':');
      final hour = int.tryParse(timeParts.first) ?? 9;
      final minute = timeParts.length > 1 ? int.tryParse(timeParts[1]) ?? 0 : 0;
      final startsAt = DateTime(
        firstDay.scheduleDate.year,
        firstDay.scheduleDate.month,
        firstDay.scheduleDate.day,
        hour,
        minute,
      );
      final untilStart = startsAt.difference(now);
      if (untilStart.isNegative || untilStart > const Duration(hours: 36)) {
        continue;
      }
      reminders.add(
        AppNotification(
          id: 'trip:${trip.itineraryId}:${firstDay.scheduleDate.toIso8601String().split('T').first}',
          type: AppNotificationType.tripReminder,
          createdAt: now,
          isRead: false,
          relatedEntityId: trip.itineraryId,
          relatedTitle: trip.title,
          relatedDestination: trip.destinationState,
          relatedDate: firstDay.scheduleDate,
        ),
      );
    }
    return reminders;
  }

  Future<void> markRead(String id) async {
    final index = _notifications.indexWhere((item) => item.id == id);
    if (index < 0 || _notifications[index].isRead) return;
    _notifications = [
      for (final item in _notifications)
        if (item.id == id) item.copyWith(isRead: true) else item,
    ];
    notifyListeners();
    await _persistCache(_accountId);
  }

  Future<void> markAllRead() async {
    if (unreadCount == 0) return;
    _notifications = [
      for (final item in _notifications) item.copyWith(isRead: true),
    ];
    notifyListeners();
    await _persistCache(_accountId);
  }

  Future<void> _persistCache(String account) async {
    try {
      final preferences = await SharedPreferences.getInstance();
      await preferences.setString(
        _cacheKey(account),
        jsonEncode(_notifications.map((item) => item.toJson()).toList()),
      );
    } catch (_) {
      // Keep the current inbox usable in memory even when persistence is down.
    }
  }

  String _cacheKey(String account) => 'notifications.cache.v2:$account';
}
