import 'package:smart_travel_planner/l10n/localized_labels.dart';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:smart_travel_planner/features/auth/services/auth_service.dart';
import 'place_review_page.dart';
import 'place_details_refresh_page.dart';
import '../models/place_import_batch.dart';
import 'package:smart_travel_planner/core/theme/app_colors.dart';
import 'package:smart_travel_planner/core/theme/app_decorations.dart';
import 'package:smart_travel_planner/core/config/supabase_config.dart';
import 'package:smart_travel_planner/features/places/services/google_places_service.dart';
import 'package:smart_travel_planner/features/places/services/place_catalog_service.dart';
import 'package:smart_travel_planner/features/admin/services/place_sync_history_service.dart';
import 'package:smart_travel_planner/features/admin/models/place_sync_record.dart';
import 'package:smart_travel_planner/features/admin/widgets/place_sync_notice.dart';
import 'package:smart_travel_planner/features/admin/services/admin_places_repository.dart';
import 'package:smart_travel_planner/features/places/widgets/google_maps_attribution.dart';
import 'package:smart_travel_planner/shared/models/attraction.dart';
import 'package:smart_travel_planner/features/places/utils/attraction_image_resolver.dart';

class AdminPlacesScreen extends StatefulWidget {
  const AdminPlacesScreen({super.key});

  @override
  State<AdminPlacesScreen> createState() => _AdminPlacesScreenState();
}

class _AdminPlacesScreenState extends State<AdminPlacesScreen> {
  static const List<String> availableStates = [
    'Penang',
    'Kuala Lumpur',
    'Melaka',
    'Selangor',
    'Johor',
    'Perak',
    'Pahang',
    'Sabah',
    'Sarawak',
    'Kedah',
    'Terengganu',
    'Kelantan',
    'Negeri Sembilan',
    'Perlis',
    'Putrajaya',
    'Labuan',
  ];

  String _selectedState = 'Penang';
  bool _isLoading = false;
  bool _isFetchingList = false;
  bool _loadingNames = false;
  String? _namesNotice;
  final Map<String, Map<String, dynamic>> _liveNames = {};
  final List<String> _logs = [];

  List<Map<String, dynamic>> _currentPlaces = [];
  int _dbCount = 0;
  int _pageOffset = 0;
  bool _searchBudgetReady = false;
  String _budgetNotice = 'Checking verified Google allowance…';
  bool _rlsBlocked = false;
  bool _missingReviewColumn = false;
  double _syncProgress = 0.0;
  String _syncStatusText = '';
  String _syncSubStatusText = '';
  bool _showTerminalLogs = false;
  String? _activityState;
  final _syncHistory = PlaceSyncHistoryService();
  final _places = AdminPlacesRepository();
  String? _placesLoadError;
  PlaceSyncRecord? _lastSync;
  bool _loadingSyncHistory = true;
  bool _syncHistoryOffline = false;
  int _historyGeneration = 0;
  int _listGeneration = 0;
  String _placesState = 'Penang';
  Timer? _noticeTimer;

  @override
  void initState() {
    super.initState();
    _loadStateData();
    _noticeTimer = Timer.periodic(const Duration(minutes: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _noticeTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadSyncHistory() async {
    final state = _selectedState;
    final generation = ++_historyGeneration;
    setState(() {
      _loadingSyncHistory = true;
      _lastSync = null;
    });
    final reader = PlaceSyncHistoryService();
    final record = await reader.load(state);
    if (!mounted ||
        generation != _historyGeneration ||
        state != _selectedState) {
      return;
    }
    setState(() {
      _lastSync = record;
      _loadingSyncHistory = false;
      _syncHistoryOffline = reader.lastReadOffline;
    });
  }

  static String _formatReviewCount(int count) {
    if (count >= 1000) {
      return '${(count / 1000).toStringAsFixed(1)}k';
    }
    return count.toString();
  }

  void _addLog(String msg) {
    setState(() {
      _logs.add(msg);
    });
  }

  Future<void> _loadStateData({String? forState, int offset = 0}) async {
    final state = forState ?? _selectedState;
    if (state != _selectedState) return;
    final generation = ++_listGeneration;
    unawaited(_loadSyncHistory());
    setState(() {
      _isFetchingList = true;
      _loadingNames = false;
      _namesNotice = null;
      _liveNames.clear();
      _placesLoadError = null;
      _rlsBlocked = false;
      if (_placesState != state) {
        _currentPlaces = [];
        _dbCount = 0;
        _placesState = state;
        _syncProgress = 0;
        _syncStatusText = '';
        _syncSubStatusText = '';
        _logs.clear();
        _activityState = null;
        _showTerminalLogs = false;
      }
    });

    final client = SupabaseConfig.client;
    if (client != null && SupabaseConfig.isConfigured) {
      try {
        final page = await _places.load(state, offset: offset);
        if (!mounted ||
            generation != _listGeneration ||
            state != _selectedState) {
          return;
        }
        final status = await GooglePlacesService().budgetStatus();
        final budgets = (status?['budgets'] as List? ?? []).whereType<Map>();
        final searchBudget = budgets
            .where(
              (b) =>
                  b['sku'] == 'text_search_pro' &&
                  b['enabled'] == true &&
                  b['verified_at'] != null &&
                  (DateTime.tryParse(
                        b['valid_until']?.toString() ?? '',
                      )?.isAfter(DateTime.now()) ??
                      false),
            )
            .firstOrNull;
        final remaining = searchBudget == null
            ? 0
            : ((searchBudget['request_limit'] as num?)?.toInt() ?? 0) -
                  ((searchBudget['baseline_usage'] as num?)?.toInt() ?? 0) -
                  ((searchBudget['used_units'] as num?)?.toInt() ?? 0);

        final list = page.rows;
        final hasColumnInDb =
            list.isEmpty ||
            list.any((p) => p.containsKey('user_ratings_total'));

        if (!mounted ||
            generation != _listGeneration ||
            state != _selectedState) {
          return;
        }
        setState(() {
          _currentPlaces = list;
          _pageOffset = offset;
          _searchBudgetReady = remaining >= 48;
          _budgetNotice = remaining >= 48
              ? '$remaining verified search requests remaining. A full state sync uses up to 48.'
              : 'Fetch & Sync is blocked until the current Google allowance is verified with at least 48 requests remaining. Saved IDs and schedules remain available.';
          _dbCount = page.totalCount;
          _missingReviewColumn =
              !hasColumnInDb &&
              !page.rows.any(PlaceCatalogService.isGoogleReference);
        });
      } catch (e) {
        debugPrint('Error loading places: $e');
        if (mounted && generation == _listGeneration) {
          _placesLoadError =
              'Unable to read saved places. Refresh the database list before starting another import.';
        }
      }
    } else {
      _placesLoadError =
          'Database unavailable. Reconnect to check your saved places.';
    }

    if (!mounted || generation != _listGeneration) return;
    setState(() {
      _isFetchingList = false;
    });
  }

  Future<void> _syncPlacesFromGoogle() async {
    if (_isLoading ||
        _loadingSyncHistory ||
        _isFetchingList ||
        _placesLoadError != null) {
      return;
    }
    if (!_searchBudgetReady) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(context.tr(_budgetNotice))));
      return;
    }
    final db = SupabaseConfig.client;
    if (!GooglePlacesService.isAvailable ||
        AuthService().currentUser?.isAdmin != true ||
        db == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            context.l10n.signInAsAnAdministratorToImportGooglePlaceIds,
          ),
        ),
      );
      return;
    }
    final state = _selectedState;
    if (_lastSync != null || _dbCount > 0) {
      final previous = _lastSync;
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(context.l10n.syncValueAgain((state).toString())),
          content: Text(
            previous == null
                ? context
                      .l10n
                      .thisStateAlreadyHasStoredPlacesButItsPreviousSyncTimeWasNotRecordedSyncingAgainWillUseGoog
                : context.l10n
                      .lastSuccessfulSyncValueValueSyncingAgainWillUseGoogleApiQuotaYouCanKeepTheExistingDataInst(
                        (previous.ageLabel(DateTime.now())).toString(),
                        (previous.malaysiaDateLabel).toString(),
                      ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text(context.l10n.keepExistingData),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: Text(context.l10n.syncAgain),
            ),
          ],
        ),
      );
      if (confirmed != true ||
          !mounted ||
          state != _selectedState ||
          _isLoading) {
        return;
      }
    }
    setState(() {
      _isLoading = true;
      _logs.clear();
      _activityState = state;
      _rlsBlocked = false;
      _syncProgress = 0.05;
      _syncStatusText = 'Searching Google for $state';
      _syncSubStatusText =
          'Discovering new places. Existing records are preserved; use Update saved places to refresh their details.';
    });
    final service = GooglePlacesService();
    final batch = PlaceImportBatch(state);
    final live = batch.rows;
    var searchRequests = 0;
    final categorySpecs = [
      {
        'category': 'Culture',
        'icon': '🏛️',
        'queries': [
          'museums, art galleries and cultural centres in $state, Malaysia',
          'cultural heritage centres and architectural landmarks in $state, Malaysia',
        ],
      },
      {
        'category': 'Food',
        'icon': '🍜',
        'queries': [
          'hawker centres and local food courts in $state, Malaysia',
          'local restaurants and traditional eateries in $state, Malaysia',
        ],
      },
      {
        'category': 'Nature',
        'icon': '🌿',
        'queries': [
          'national parks, botanical gardens and waterfalls in $state, Malaysia',
          'beaches, islands and scenic nature viewpoints in $state, Malaysia',
        ],
      },
      {
        'category': 'Shopping',
        'icon': '🛍️',
        'queries': [
          'shopping malls and department stores in $state, Malaysia',
          'local markets, handicraft centres and souvenir shops in $state, Malaysia',
        ],
      },
      {
        'category': 'History',
        'icon': '🏰',
        'queries': [
          'historic monuments and colonial buildings in $state, Malaysia',
          'historic temples, clan houses, forts and memorials in $state, Malaysia',
        ],
      },
      {
        'category': 'Adventure',
        'icon': '🧗',
        'queries': [
          'hiking trails, mountain peaks and canopy walks in $state, Malaysia',
          'theme parks, water parks and outdoor adventure parks in $state, Malaysia',
        ],
      },
      {
        'category': 'Family',
        'icon': '👨‍👩‍👧',
        'queries': [
          'aquariums, science centres and zoos in $state, Malaysia',
          'family recreation parks and children’s attractions in $state, Malaysia',
        ],
      },
      {
        'category': 'Nightlife',
        'icon': '🌙',
        'queries': [
          'night markets and evening food bazaars in $state, Malaysia',
          'evening viewpoints and waterfront walks in $state, Malaysia',
        ],
      },
    ];

    try {
      for (int c = 0; c < categorySpecs.length; c++) {
        final queries = categorySpecs[c]['queries'] as List<String>;
        for (final query in queries) {
          String? pageToken;
          for (int page = 0; page < 3; page++) {
            searchRequests++;
            final data = await service.searchPage(
              query: query,
              state: state,
              pageToken: pageToken,
            );
            if (data == null) {
              throw StateError(
                service.lastError ?? 'Google Places unavailable',
              );
            }
            for (final p in (data['places'] as List? ?? []).whereType<Map>()) {
              batch.add(
                Map<String, dynamic>.from(p),
                categorySpecs[c]['category'] as String,
              );
            }
            if (!mounted) return;
            _addLog(batch.summary);
            pageToken = data['nextPageToken'] as String?;
            if (pageToken == null || pageToken.isEmpty) break;
          }
        }
        if (!mounted) return;
        setState(() {
          _syncProgress = (c + 1) / categorySpecs.length;
        });
      }
      final inserted = await _places.savePlaces(state, live.values);
      // A failed/cancelled search or database batch never advances this date.
      final completed = await _syncHistory.recordSuccess(
        state: state,
        placeCount: live.length,
        requestCount: searchRequests,
      );
      if (!mounted) return;
      final historyError = _syncHistory.lastError;
      setState(() {
        _syncStatusText = 'Refreshing the $state database list';
        _syncSubStatusText = '$inserted new places saved.';
      });
      await _loadStateData(forState: state);
      if (!mounted) return;
      final skipped = live.length - inserted;
      final refreshed = _placesLoadError == null;
      setState(() {
        _lastSync = completed;
        _syncHistoryOffline = completed.localOnly;
        _syncProgress = 1;
        _syncStatusText = refreshed
            ? '$state database list refreshed'
            : '$state sync saved. List refresh failed.';
        _syncSubStatusText =
            '${batch.summary} · $inserted new · $skipped already saved'
            '${refreshed ? ' · $_dbCount in database' : '. Tap Refresh to reload the list.'}';
      });
      _addLog(
        'Saved place IDs and app categories. Google details were not stored.',
      );
      if (historyError != null) _addLog(historyError);
    } catch (error) {
      if (mounted) {
        setState(() {
          _syncStatusText = 'Import stopped';
          _syncSubStatusText = '${batch.summary} · ${error.toString()}';
          _rlsBlocked = error.toString().contains('row-level security');
        });
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _clearStatePlaces() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(context.l10n.clearValuePlaces((_selectedState).toString())),
        content: Text(
          context.l10n
              .thisWillDeleteAllCachedPlacesForValueFromTheSupabaseDatabase(
                (_selectedState).toString(),
              ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(context.l10n.cancel),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: Text(context.l10n.delete),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() {
      _isLoading = true;
      _logs.clear();
      _syncProgress = 0.2;
      _syncStatusText = 'Clearing places for $_selectedState...';
      _activityState = _selectedState;
      _syncSubStatusText = 'Deleting records from Supabase';
    });

    final client = SupabaseConfig.client;
    if (client != null && SupabaseConfig.isConfigured) {
      try {
        await client
            .from('places')
            .delete()
            .ilike('state', '%$_selectedState%');
        GooglePlacesService.clearMemoryCache();
        _addLog('🗑️ Cleared places for $_selectedState in Supabase.');
        await _loadStateData();
        setState(() {
          _syncProgress = 1.0;
          _syncStatusText = 'Cleared $_selectedState Places 🗑️';
          _syncSubStatusText = 'All cached places for $_selectedState removed';
        });
      } catch (e) {
        _addLog('⚠️ Error deleting: $e');
        setState(() {
          _syncStatusText = 'Error deleting places';
          _syncSubStatusText = e.toString();
        });
      }
    }

    setState(() {
      _isLoading = false;
    });
  }

  Future<void> _loadPageNames() async {
    final generation = _listGeneration;
    final state = _selectedState;
    setState(() {
      _loadingNames = true;
      _namesNotice = null;
    });
    try {
      final rows = await GooglePlacesService().hydrateRows(
        _currentPlaces,
        shouldContinue: () =>
            mounted && generation == _listGeneration && state == _selectedState,
      );
      if (!mounted ||
          generation != _listGeneration ||
          state != _selectedState) {
        return;
      }
      final saved = await _places.saveFetchedRows(state, rows);
      if (!mounted ||
          generation != _listGeneration ||
          state != _selectedState) {
        return;
      }
      setState(() {
        for (final row in rows) {
          _liveNames[row['place_id'].toString()] = row;
        }
        final loaded = rows.where((r) => r['_live'] == true).length;
        final error = rows
            .map((r) => r['_loadError'])
            .whereType<String>()
            .firstOrNull;
        _namesNotice =
            'Loaded $loaded; saved $saved to database.${error == null ? '' : ' $error'}';
      });
    } catch (e) {
      if (mounted && generation == _listGeneration) {
        setState(() => _namesNotice = 'Fetch/save failed: $e');
      }
    } finally {
      if (mounted && generation == _listGeneration) {
        setState(() => _loadingNames = false);
      }
    }
  }

  Future<void> _autoClassifyPlaces() async {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          context
              .l10n
              .openReviewOnASavedPlaceLoadLiveDetailsCheckTheSuggestionThenConfirmItsCategoryAndSettingNo,
        ),
      ),
    );
  }

  Future<void> _togglePlaceIndoorOutdoor(Map<String, dynamic> place) async {
    final saved = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => PlaceReviewPage(row: Map<String, dynamic>.from(place)),
      ),
    );
    if (mounted && saved == true) {
      await _loadStateData(offset: _pageOffset);
    }
  }

  Widget _buildIndoorOutdoorBadge(Map<String, dynamic> place) {
    final isIndoor = place['is_indoor'] as bool?;
    final Color bgColor;
    final Color textColor;
    final String label;

    if (isIndoor == true) {
      bgColor = const Color(0xFFE0F2FE);
      textColor = const Color(0xFF0284C7);
      label = '🏠 Indoor';
    } else if (isIndoor == false) {
      bgColor = const Color(0xFFDCFCE7);
      textColor = const Color(0xFF16A34A);
      label = '☀️ Outdoor';
    } else {
      bgColor = const Color(0xFFFEF3C7);
      textColor = const Color(0xFFD97706);
      label = '❓ Review';
    }

    return InkWell(
      onTap: () => _togglePlaceIndoorOutdoor(place),
      borderRadius: BorderRadius.circular(6),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(
            color: textColor.withValues(alpha: 0.3),
            width: 0.8,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              context.tr(label),
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w700,
                color: textColor,
              ),
            ),
            const SizedBox(width: 2),
            Icon(
              Icons.touch_app,
              size: 9,
              color: textColor.withValues(alpha: 0.6),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCountBadge({
    required String label,
    required String icon,
    required int count,
    required Color color,
    required Color bgColor,
  }) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 6),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: color.withValues(alpha: 0.25)),
        ),
        child: Column(
          children: [
            Text(
              '$icon $count',
              style: TextStyle(
                fontWeight: FontWeight.w900,
                fontSize: 12.5,
                color: color,
              ),
            ),
            const SizedBox(height: 1),
            Text(
              context.tr(label),
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w700,
                color: color.withValues(alpha: 0.8),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSyncProgressBar() {
    if (_activityState != _selectedState || (_logs.isEmpty && !_isLoading)) {
      return const SizedBox.shrink();
    }

    final isDone = !_isLoading && _syncProgress >= 1.0;
    final percent = (_syncProgress * 100).toInt().clamp(0, 100);

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDone ? const Color(0xFFBBF7D0) : const Color(0xFFE2E8F0),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header & Percentage
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: isDone
                            ? const Color(0xFFDCFCE7)
                            : const Color(0xFFEFF6FF),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: isDone
                          ? const Icon(
                              Icons.check_circle_rounded,
                              color: Color(0xFF16A34A),
                              size: 24,
                            )
                          : _isLoading
                          ? const SizedBox(
                              width: 24,
                              height: 24,
                              child: CircularProgressIndicator(
                                strokeWidth: 2.5,
                                color: Color(0xFF2563EB),
                              ),
                            )
                          : const Icon(
                              Icons.info_outline_rounded,
                              color: Color(0xFF2563EB),
                              size: 24,
                            ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Expanded(
                                child: Text(
                                  context.tr(
                                    _syncStatusText.isNotEmpty
                                        ? _syncStatusText
                                        : (_isLoading
                                              ? 'Syncing places...'
                                              : 'Activity Status'),
                                  ),
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 14,
                                    color: Color(0xFF0F172A),
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 3,
                                ),
                                decoration: BoxDecoration(
                                  color: isDone
                                      ? const Color(0xFFDCFCE7)
                                      : const Color(0xFFEFF6FF),
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: Text(
                                  '$percent%',
                                  style: TextStyle(
                                    fontWeight: FontWeight.w800,
                                    fontSize: 12,
                                    color: isDone
                                        ? const Color(0xFF16A34A)
                                        : const Color(0xFF2563EB),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          if (_syncSubStatusText.isNotEmpty) ...[
                            const SizedBox(height: 4),
                            Text(
                              context.tr(_syncSubStatusText),
                              style: const TextStyle(
                                fontSize: 12,
                                color: Color(0xFF64748B),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),

                // Animated Linear Progress Bar
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: TweenAnimationBuilder<double>(
                    duration: const Duration(milliseconds: 300),
                    curve: Curves.easeInOut,
                    tween: Tween<double>(
                      begin: 0,
                      end: _syncProgress.clamp(0.0, 1.0),
                    ),
                    builder: (context, value, _) => LinearProgressIndicator(
                      value: value > 0 ? value : (_isLoading ? null : 0.0),
                      minHeight: 8,
                      backgroundColor: const Color(0xFFF1F5F9),
                      valueColor: AlwaysStoppedAnimation<Color>(
                        isDone
                            ? const Color(0xFF16A34A)
                            : const Color(0xFF2563EB),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Collapsible Terminal Toggle Bar
          InkWell(
            onTap: () {
              setState(() {
                _showTerminalLogs = !_showTerminalLogs;
              });
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                border: Border(
                  top: BorderSide(color: Colors.grey.shade200),
                  bottom: _showTerminalLogs
                      ? BorderSide(color: Colors.grey.shade200)
                      : BorderSide.none,
                ),
                borderRadius: _showTerminalLogs
                    ? BorderRadius.zero
                    : const BorderRadius.vertical(bottom: Radius.circular(16)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      const Icon(
                        Icons.terminal,
                        size: 15,
                        color: Color(0xFF64748B),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        _showTerminalLogs
                            ? context.l10n.hideRawLogs
                            : context.l10n.viewRawTerminalLogsValueLines(
                                (_logs.length).toString(),
                              ),
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF64748B),
                        ),
                      ),
                    ],
                  ),
                  Icon(
                    _showTerminalLogs
                        ? Icons.keyboard_arrow_up_rounded
                        : Icons.keyboard_arrow_down_rounded,
                    size: 18,
                    color: const Color(0xFF64748B),
                  ),
                ],
              ),
            ),
          ),

          // Collapsible Terminal Body
          if (_showTerminalLogs)
            Container(
              padding: const EdgeInsets.all(12),
              decoration: const BoxDecoration(
                color: Color(0xFF0F172A),
                borderRadius: BorderRadius.vertical(
                  bottom: Radius.circular(16),
                ),
              ),
              constraints: const BoxConstraints(maxHeight: 200),
              child: Scrollbar(
                thumbVisibility: true,
                child: SingleChildScrollView(
                  reverse: true,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: _logs
                        .map(
                          (log) => Padding(
                            padding: const EdgeInsets.only(bottom: 3),
                            child: Text(
                              log,
                              style: TextStyle(
                                fontFamily: 'monospace',
                                fontSize: 10.5,
                                color:
                                    log.contains('🎉') ||
                                        log.contains('✓') ||
                                        log.contains('✅')
                                    ? const Color(0xFF4ADE80)
                                    : (log.contains('❌') || log.contains('✗')
                                          ? const Color(0xFFF87171)
                                          : Colors.white70),
                              ),
                            ),
                          ),
                        )
                        .toList(),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F8FD),
      appBar: AppBar(
        title: Row(
          children: [
            Icon(Icons.admin_panel_settings, color: AppColors.primary),
            SizedBox(width: 8),
            Text(
              context.l10n.adminDatabaseHub,
              style: TextStyle(fontWeight: FontWeight.w900, fontSize: 18),
            ),
          ],
        ),
        backgroundColor: Colors.white,
        elevation: 0,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Banner
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF6366F1), Color(0xFF4F46E5)],
              ),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.cloud_sync, color: Colors.white, size: 24),
                    SizedBox(width: 8),
                    Text(
                      context.l10n.secretDataSeederPortal,
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 6),
                Text(
                  context
                      .l10n
                      .manuallyDiscoverGooglePlacesForTheSelectedStateSaveIdsAndAppCategoriesLoadCurrentDetailsWh,
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 12,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // State Selector Card
          Container(
            padding: const EdgeInsets.all(16),
            decoration: cardDecoration(),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      context.l10n.text1SelectDestinationState,
                      style: TextStyle(
                        fontWeight: FontWeight.w900,
                        fontSize: 15,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        context.l10n.text13StatesKl,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: AppColors.primary,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: availableStates.map((st) {
                    final isSel = st == _selectedState;
                    return ChoiceChip(
                      selected: isSel,
                      label: Text(st),
                      selectedColor: AppColors.primary,
                      labelStyle: TextStyle(
                        color: isSel ? Colors.white : AppColors.ink,
                        fontWeight: isSel ? FontWeight.w700 : FontWeight.w500,
                        fontSize: 12,
                      ),
                      onSelected: (val) {
                        if (val && !_isLoading) {
                          setState(() {
                            _selectedState = st;
                          });
                          _loadStateData();
                        }
                      },
                    );
                  }).toList(),
                ),
                const Divider(height: 24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        const Icon(
                          Icons.storage,
                          size: 18,
                          color: AppColors.primary,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          context.l10n.databaseCountForValue(
                            (_selectedState).toString(),
                          ),
                          style: const TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: _dbCount > 0
                            ? const Color(0xFFE8FDF2)
                            : const Color(0xFFFEE2E2),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        _isFetchingList
                            ? context.l10n.checking
                            : _placesLoadError != null
                            ? context.l10n.unavailable
                            : context.l10n.valuePlaces((_dbCount).toString()),
                        style: TextStyle(
                          color: _dbCount > 0
                              ? const Color(0xFF059669)
                              : Colors.red,
                          fontWeight: FontWeight.w800,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ],
                ),
                if (_currentPlaces.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      _buildCountBadge(
                        label: context.l10n.indoor,
                        icon: '🏠',
                        count: _currentPlaces
                            .where((p) => p['is_indoor'] == true)
                            .length,
                        color: const Color(0xFF0284C7),
                        bgColor: const Color(0xFFE0F2FE),
                      ),
                      const SizedBox(width: 8),
                      _buildCountBadge(
                        label: context.l10n.outdoor,
                        icon: '☀️',
                        count: _currentPlaces
                            .where((p) => p['is_indoor'] == false)
                            .length,
                        color: const Color(0xFF16A34A),
                        bgColor: const Color(0xFFDCFCE7),
                      ),
                      const SizedBox(width: 8),
                      _buildCountBadge(
                        label: context.l10n.review,
                        icon: '❓',
                        count: _currentPlaces
                            .where((p) => p['is_indoor'] == null)
                            .length,
                        color: const Color(0xFFD97706),
                        bgColor: const Color(0xFFFEF3C7),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 14),

          // RLS Alert Banner if blocked
          PlaceSyncNotice(
            state: _selectedState,
            record: _lastSync,
            loading: _loadingSyncHistory,
            offline: _syncHistoryOffline,
          ),
          const SizedBox(height: 14),
          if (_rlsBlocked) ...[
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFFFEF2F2),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: const Color(0xFFFCA5A5)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.lock, color: Colors.red, size: 20),
                      SizedBox(width: 8),
                      Text(
                        context.l10n.supabaseRowLevelSecurityRlsLocked,
                        style: TextStyle(
                          color: Colors.red,
                          fontWeight: FontWeight.w900,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    context
                        .l10n
                        .toAllowSavingPlacesRunThis1LineCommandInYourSupabaseSqlEditor,
                    style: TextStyle(fontSize: 11, color: Colors.black87),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.grey.shade300),
                    ),
                    child: Row(
                      children: [
                        const Expanded(
                          child: SelectableText(
                            'ALTER TABLE public.places DISABLE ROW LEVEL SECURITY;',
                            style: TextStyle(
                              fontFamily: 'monospace',
                              fontSize: 11,
                              color: Colors.black,
                            ),
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.copy, size: 16),
                          onPressed: () {
                            Clipboard.setData(
                              const ClipboardData(
                                text:
                                    'ALTER TABLE public.places DISABLE ROW LEVEL SECURITY;',
                              ),
                            );
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  context.l10n.sqlCommandCopiedToClipboard,
                                ),
                              ),
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
          ],

          // Missing Review Count Column Alert Banner
          if (_missingReviewColumn) ...[
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFFFEF3C7),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: const Color(0xFFFCD34D)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.star_half, color: Color(0xFFB45309), size: 20),
                      SizedBox(width: 8),
                      Text(
                        context.l10n.missingReviewCountColumnInSupabase,
                        style: TextStyle(
                          color: Color(0xFFB45309),
                          fontWeight: FontWeight.w900,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    context.l10n
                        .placesInValueAreCurrentlySavedWithoutReviewCountsToRankByPopularityScoreAndDisplayReviewsE(
                          (_selectedState).toString(),
                        ),
                    style: const TextStyle(fontSize: 11, color: Colors.black87),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.grey.shade300),
                    ),
                    child: Row(
                      children: [
                        const Expanded(
                          child: SelectableText(
                            'ALTER TABLE public.places ADD COLUMN IF NOT EXISTS user_ratings_total INTEGER DEFAULT 0;',
                            style: TextStyle(
                              fontFamily: 'monospace',
                              fontSize: 11,
                              color: Colors.black,
                            ),
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.copy, size: 16),
                          onPressed: () {
                            Clipboard.setData(
                              const ClipboardData(
                                text:
                                    'ALTER TABLE public.places ADD COLUMN IF NOT EXISTS user_ratings_total INTEGER DEFAULT 0;',
                              ),
                            );
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  context.l10n.sqlCommandCopiedToClipboard,
                                ),
                              ),
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 6),
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton.icon(
                      onPressed: () async {
                        final messenger = ScaffoldMessenger.of(context);
                        await _loadStateData();
                        if (!context.mounted) return;
                        messenger.showSnackBar(
                          SnackBar(
                            content: Text(context.l10n.checkingDatabaseSchema),
                            duration: Duration(seconds: 1),
                          ),
                        );
                      },
                      icon: const Icon(
                        Icons.refresh,
                        size: 16,
                        color: Color(0xFFB45309),
                      ),
                      label: Text(
                        context.l10n.alreadyRanItTapToRefreshDismiss,
                        style: TextStyle(
                          color: Color(0xFFB45309),
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
          ],

          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Text(context.tr(_budgetNotice)),
          ),
          // Action Buttons
          FilledButton.icon(
            onPressed: _isLoading || _isFetchingList || _loadingNames
                ? null
                : () async {
                    final state = _selectedState;
                    await Navigator.push<void>(
                      context,
                      MaterialPageRoute(
                        builder: (_) => PlaceDetailsRefreshPage(state: state),
                      ),
                    );
                    if (mounted) await _loadStateData();
                  },
            icon: const Icon(Icons.update),
            label: Text(
              context.l10n.updateSavedPlacesInValue(
                (_selectedState).toString(),
              ),
            ),
          ),
          Padding(
            padding: EdgeInsets.symmetric(vertical: 8),
            child: Text(
              context
                  .l10n
                  .refreshHoursRatingsNamesAndLocationsForAllSavedPlacesDiscoverNewPlacesBelowOnlyAddsNewIds,
            ),
          ),
          Row(
            children: [
              Expanded(
                flex: 3,
                child: FilledButton.icon(
                  onPressed:
                      _isLoading ||
                          _loadingSyncHistory ||
                          _isFetchingList ||
                          !_searchBudgetReady ||
                          _placesLoadError != null
                      ? null
                      : _syncPlacesFromGoogle,
                  icon: _isLoading
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.download_for_offline),
                  label: Text(
                    _isLoading
                        ? context.l10n.syncing
                        : context.l10n.discoverNewPlaces,
                  ),
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                flex: 1,
                child: OutlinedButton.icon(
                  onPressed: _isLoading ? null : _clearStatePlaces,
                  icon: const Icon(
                    Icons.delete_outline,
                    size: 18,
                    color: Colors.red,
                  ),
                  label: Text(
                    context.l10n.clear,
                    style: TextStyle(color: Colors.red, fontSize: 12),
                  ),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    side: const BorderSide(color: Color(0xFFFCA5A5)),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            child: FilledButton.tonalIcon(
              onPressed: _isLoading ? null : _autoClassifyPlaces,
              icon: const Icon(Icons.bolt, color: Color(0xFF4F46E5), size: 18),
              label: Text(
                context.l10n.howToReviewCategoriesAndSettings,
                style: TextStyle(
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF4F46E5),
                  fontSize: 13,
                ),
              ),
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFFEEF2FF),
                padding: const EdgeInsets.symmetric(vertical: 13),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Live Activity & Progress Bar
          _buildSyncProgressBar(),

          // Synced Places List
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  context.l10n.placesInDatabaseValue(
                    (_selectedState).toString(),
                  ),
                  style: const TextStyle(
                    fontWeight: FontWeight.w900,
                    fontSize: 15,
                  ),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.refresh, size: 20),
                onPressed: _isLoading ? null : _loadStateData,
              ),
            ],
          ),
          const SizedBox(height: 8),

          OutlinedButton.icon(
            onPressed:
                _loadingNames ||
                    _isFetchingList ||
                    _isLoading ||
                    _currentPlaces.isEmpty
                ? null
                : _loadPageNames,
            icon: const Icon(Icons.cloud_download_outlined),
            label: Text(
              _loadingNames
                  ? context.l10n.loadingNames
                  : context.l10n.fetchAndSaveThisPage,
            ),
          ),
          Text(context.l10n.loadsUpTo20NamesFromGoogleUsingTheCurrentAllowance),
          if (_namesNotice != null) Text(context.tr(_namesNotice!)),
          GoogleMapsAttribution(
            attributions: [
              for (final row in _liveNames.values)
                ...((row['attributions'] as List?) ?? []).whereType<Map>().map(
                  (a) => Map<String, dynamic>.from(a),
                ),
            ],
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              TextButton(
                onPressed: _isFetchingList || _isLoading || _pageOffset == 0
                    ? null
                    : () => _loadStateData(
                        offset: (_pageOffset - 20).clamp(0, _dbCount),
                      ),
                child: Text(context.l10n.previous20),
              ),
              Flexible(
                child: Text(
                  _dbCount == 0
                      ? context.l10n.text0Places
                      : context.l10n.valueValueOfValue(
                          (_pageOffset + 1).toString(),
                          ((_pageOffset + 20).clamp(0, _dbCount)).toString(),
                          (_dbCount).toString(),
                        ),
                ),
              ),
              TextButton(
                onPressed:
                    _isFetchingList ||
                        _isLoading ||
                        _pageOffset + 20 >= _dbCount
                    ? null
                    : () => _loadStateData(offset: _pageOffset + 20),
                child: Text(context.l10n.next20),
              ),
            ],
          ),
          const SizedBox(height: 8),
          if (_currentPlaces.any(
            (p) => p['name'] == 'Incomplete import — needs review',
          ))
            Padding(
              padding: EdgeInsets.only(bottom: 12),
              child: Text(
                context
                    .l10n
                    .someOlderImportsHaveUnverifiedCountriesOrStatesTheseAreMarkedForReviewRepeatingTheFullSync,
              ),
            ),
          if (_isFetchingList)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: CircularProgressIndicator(),
              ),
            )
          else if (_placesLoadError != null)
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                context.tr(_placesLoadError!),
                style: const TextStyle(color: Colors.red),
              ),
            )
          else if (_currentPlaces.isEmpty)
            Container(
              padding: const EdgeInsets.all(24),
              decoration: cardDecoration(),
              child: Column(
                children: [
                  Icon(
                    Icons.folder_open,
                    size: 48,
                    color: Colors.grey.shade400,
                  ),
                  const SizedBox(height: 10),
                  Text(
                    context.l10n.noPlacesStoredForValueYet(
                      (_selectedState).toString(),
                    ),
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      color: AppColors.muted,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    context
                        .l10n
                        .thisStateHasNoSavedRecordsSyncingItWillUseGoogleApiQuota,
                    style: TextStyle(fontSize: 12, color: AppColors.muted),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            )
          else
            ..._currentPlaces.map((p) {
              final value = p['photo_url']?.toString();
              final rawPhoto =
                  value != null &&
                      !value.contains('places.googleapis.com') &&
                      !value.contains('key=')
                  ? value
                  : null;
              final resolvedFallback = AttractionImageResolver.resolvePhotoUrl(
                Attraction(
                  xid: p['place_id']?.toString() ?? '',
                  name: p['name']?.toString() ?? '',
                  latitude: (p['latitude'] as num?)?.toDouble() ?? 0.0,
                  longitude: (p['longitude'] as num?)?.toDouble() ?? 0.0,
                  category: p['category']?.toString() ?? 'Attraction',
                ),
              );
              final primaryPhoto = rawPhoto != null && rawPhoto.isNotEmpty
                  ? (rawPhoto.contains('|')
                        ? rawPhoto.split('|').first
                        : rawPhoto)
                  : resolvedFallback;
              final photoCount = rawPhoto != null && rawPhoto.contains('|')
                  ? rawPhoto.split('|').length
                  : (primaryPhoto != null && primaryPhoto.isNotEmpty ? 1 : 0);

              return Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.all(10),
                decoration: cardDecoration(),
                child: Row(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: primaryPhoto != null
                          ? Image.network(
                              primaryPhoto,
                              width: 52,
                              height: 52,
                              fit: BoxFit.cover,
                              errorBuilder: (_, _, _) => Container(
                                width: 52,
                                height: 52,
                                color: Colors.grey.shade200,
                                child: const Icon(
                                  Icons.place,
                                  color: AppColors.primary,
                                ),
                              ),
                            )
                          : Container(
                              width: 52,
                              height: 52,
                              color: Colors.grey.shade200,
                              child: const Icon(
                                Icons.place,
                                color: AppColors.primary,
                              ),
                            ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _liveNames[p['place_id']]?['_live'] == true
                                ? _liveNames[p['place_id']]!['name'].toString()
                                : p['name'] == 'Saved Google place'
                                ? context.l10n.pendingSyncTapFetchAndSave
                                : p['name']?.toString() ?? 'Name unavailable',
                            style: const TextStyle(
                              fontWeight: FontWeight.w800,
                              fontSize: 13,
                              color: AppColors.ink,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'ID: ${p['place_id']}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          TextButton(
                            onPressed: () => _togglePlaceIndoorOutdoor(p),
                            child: Text(
                              context.l10n.reviewStoredDataLoadLiveDetails,
                            ),
                          ),
                          Wrap(
                            spacing: 6,
                            runSpacing: 4,
                            crossAxisAlignment: WrapCrossAlignment.center,
                            children: [
                              Text(
                                p['category']?.toString() ?? 'Attraction',
                                style: const TextStyle(
                                  fontSize: 11,
                                  color: AppColors.muted,
                                ),
                              ),
                              _buildIndoorOutdoorBadge(p),
                            ],
                          ),
                        ],
                      ),
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Row(
                          children: [
                            const Icon(
                              Icons.star,
                              size: 14,
                              color: Colors.amber,
                            ),
                            const SizedBox(width: 2),
                            Text(
                              p['rating']?.toString() ?? 'Unavailable',
                              style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            if (p['user_ratings_total'] != null &&
                                (p['user_ratings_total'] as num) > 0) ...[
                              const SizedBox(width: 3),
                              Text(
                                '(${_formatReviewCount((p['user_ratings_total'] as num).toInt())})',
                                style: const TextStyle(
                                  fontSize: 10,
                                  color: AppColors.muted,
                                ),
                              ),
                            ],
                          ],
                        ),
                        if (photoCount > 0) ...[
                          const SizedBox(height: 3),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 5,
                              vertical: 1,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.primary.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              '📷 $photoCount',
                              style: const TextStyle(
                                fontSize: 9.5,
                                fontWeight: FontWeight.w700,
                                color: AppColors.primary,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              );
            }),
        ],
      ),
    );
  }
}
