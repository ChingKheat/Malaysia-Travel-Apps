import 'package:url_launcher/url_launcher.dart';
import 'package:smart_travel_planner/features/itinerary/services/day_route_service.dart';
import 'package:smart_travel_planner/features/itinerary/widgets/day_route_map.dart';
import 'package:smart_travel_planner/l10n/presentation_formatters.dart';
import 'package:smart_travel_planner/l10n/localized_labels.dart';
import 'package:flutter/material.dart';

import 'package:smart_travel_planner/core/theme/app_colors.dart';
import 'package:smart_travel_planner/shared/utils/demo_feedback.dart';
import 'package:smart_travel_planner/features/itinerary/data/sample_data.dart';
import 'package:smart_travel_planner/features/itinerary/models/itinerary_models.dart';
import 'package:smart_travel_planner/features/itinerary/models/saved_trip.dart';
import 'package:smart_travel_planner/shared/models/travel_stop.dart';
import 'package:smart_travel_planner/features/itinerary/models/trip_preferences.dart';
import 'today_plan_page.dart';
import 'package:smart_travel_planner/shared/models/weather_forecast.dart';
import 'package:smart_travel_planner/features/itinerary/services/smart_itinerary_service.dart';
import 'package:smart_travel_planner/features/itinerary/services/scheduling_engine.dart';
import 'package:smart_travel_planner/features/auth/services/auth_service.dart';
import 'package:smart_travel_planner/features/itinerary/services/supabase_itinerary_service.dart';
import 'package:smart_travel_planner/features/itinerary/services/trip_preferences_service.dart';
import 'package:smart_travel_planner/shared/services/weather_service.dart';
import 'package:smart_travel_planner/features/places/services/place_catalog_service.dart';
import 'package:smart_travel_planner/features/places/services/google_places_service.dart';
import 'package:smart_travel_planner/features/places/models/google_place_details.dart';

import 'package:smart_travel_planner/shared/widgets/demo_tap.dart';
import 'package:smart_travel_planner/features/itinerary/widgets/stop_card.dart';
import 'edit_itinerary_screen.dart';
import 'package:smart_travel_planner/features/places/screens/place_detail_page.dart';

class ItineraryPage extends StatefulWidget {
  final VoidCallback? onPlanTap;
  final bool compactResult;
  final String? initialItineraryId;
  const ItineraryPage({
    super.key,
    this.onPlanTap,
    this.compactResult = false,
    this.initialItineraryId,
  });

  @override
  State<ItineraryPage> createState() => _ItineraryPageState();
}

class _ItineraryPageState extends State<ItineraryPage> {
  int _selectedTripIndex = 0;
  int _selectedDay = 0;
  final _dayRouteAnchor = GlobalKey();
  final _dayRoutes = DayRouteService();
  List<SavedTrip> _dbSavedTrips = [];
  List<Itinerary> _rawDbItineraries = [];
  WeatherForecast? _currentDayForecast;
  bool _isLoadingWeather = false;
  bool _isRegenerating = false;
  bool _isSavingTrip = false;
  ItinerarySaveResult? _draftSave;
  String? _loadedUserId;
  final Map<String, Map<int, List<TravelStop>>> _editedTripStops = {};
  String? _liveDayKey;
  Set<String> _livePlaceIds = {};
  Map<String, GooglePlaceDetails> _liveDetails = {};
  int _detailsGeneration = 0;
  bool _didSelectInitialItinerary = false;

  @override
  void initState() {
    super.initState();
    _loadedUserId = AuthService().currentUser?.uid;
    SupabaseItineraryService().addListener(_onRepositoryChanged);
    _loadSavedTripsFromDatabase().then((_) {
      if (mounted && _availableTrips.isNotEmpty) {
        _loadWeatherForDay(_selectedDay);
      }
    });
  }

  void _onRepositoryChanged() {
    if (!mounted) return;
    final uid = AuthService().currentUser?.uid;
    if (uid != _loadedUserId) {
      setState(() {
        _editedTripStops.clear();
        _liveDayKey = null;
        _livePlaceIds = {};
        _liveDetails.clear();
        _detailsGeneration++;
        _rawDbItineraries = [];
        _dbSavedTrips = [];
        _currentDayForecast = null;
        _selectedTripIndex = 0;
        _selectedDay = 0;
        _loadedUserId = uid;
      });
    }
    _loadSavedTripsFromDatabase(refresh: false);
  }

  @override
  void dispose() {
    SupabaseItineraryService().removeListener(_onRepositoryChanged);
    super.dispose();
  }

  Itinerary? get _selectedSavedItinerary {
    final offset = TripPreferencesService.storedPreferences == null ? 0 : 1;
    final index = _selectedTripIndex - offset;
    return index >= 0 && index < _rawDbItineraries.length
        ? _rawDbItineraries[index]
        : null;
  }

  TripPreferences get _preferences =>
      _selectedSavedItinerary?.preferences ??
      (_selectedSavedItinerary == null
          ? TripPreferencesService.storedPreferences
          : null) ??
      TripPreferences(
        destination: _availableTrips.isNotEmpty
            ? _currentTrip.destination.split(',').first.trim()
            : 'Kuala Lumpur',
        numberOfDays: _availableTrips.isNotEmpty ? _currentTrip.totalDays : 3,
      );
  DateTime _dateForDay(int day) {
    final saved = _selectedSavedItinerary;
    return saved != null && day < saved.dailySchedules.length
        ? saved.dailySchedules[day].scheduleDate
        : _preferences.dateForDay(day);
  }

  Future<void> _regenerate() async {
    if (_isRegenerating || _isSavingTrip) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(context.l10n.regenerateItinerary2),
        content: Text(
          context
              .l10n
              .yourCurrentUnsavedChangesWillBeReplacedSavedTripsWillRemainAvailable,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(context.l10n.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(context.l10n.regenerate),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    final preferences = _preferences.copyWith(
      startDate: _dateForDay(0),
      endDate: _dateForDay(_totalDays - 1),
    );
    final validation = TripPreferencesService.validatePreferences(
      preferences,
      store: false,
    );
    if (!validation.success) {
      showDemoSnackBar(
        context,
        context.l10n.completeTripPreferencesInPlanBeforeRegenerating,
      );
      return;
    }
    setState(() => _isRegenerating = true);
    try {
      final generated =
          await SmartItineraryService.generateLiveItineraryForAllDays(
            preferences: preferences,
            seed: DateTime.now().microsecondsSinceEpoch,
            requireVisits: true,
          );
      if (!mounted) return;
      if (!generated) {
        showDemoSnackBar(
          context,
          context
              .l10n
              .noAdditionalPlacesFitThisDayTryFewerDaysOrWiderDailyHours,
        );
        return;
      }
      TripPreferencesService.activate(preferences);
      setState(() {
        _selectedTripIndex = 0;
        _selectedDay = 0;
        _draftSave = null;
      });
      await _loadWeatherForDay(0);
    } catch (_) {
      if (mounted) showDemoSnackBar(context, context.l10n.tryAgain);
    } finally {
      if (mounted) setState(() => _isRegenerating = false);
    }
  }

  Future<void> _loadWeatherForDay(int dayIndex) async {
    if (_availableTrips.isEmpty) return;
    _loadGoogleDetailsForDay(dayIndex);
    final tripIdentity =
        _selectedSavedItinerary?.itineraryId ?? _currentTrip.title;
    final requestDate = _dateForDay(dayIndex);
    final dest = _currentTrip.destination.split(',').first.trim();
    if (dest.isEmpty) return;
    setState(() {
      _isLoadingWeather = true;
      _currentDayForecast = null;
    });
    try {
      final forecast = await WeatherService().getForecastForDate(
        state: dest,
        date: requestDate,
      );
      if (mounted &&
          dayIndex == _selectedDay &&
          requestDate == _dateForDay(dayIndex) &&
          tripIdentity ==
              (_selectedSavedItinerary?.itineraryId ?? _currentTrip.title)) {
        setState(() {
          _currentDayForecast = forecast;
          _isLoadingWeather = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() => _isLoadingWeather = false);
      }
    }
  }

  Future<void> _loadSavedTripsFromDatabase({bool refresh = true}) async {
    final userId = AuthService().currentUser?.uid;
    try {
      final dbTrips = await SupabaseItineraryService().getSavedItineraries(
        refresh: refresh,
      );
      if (mounted && userId == AuthService().currentUser?.uid) {
        setState(() {
          _rawDbItineraries = dbTrips;
          _dbSavedTrips = dbTrips.map((itin) => itin.toSavedTrip()).toList();
          if (!_didSelectInitialItinerary &&
              widget.initialItineraryId != null) {
            final index = dbTrips.indexWhere(
              (trip) => trip.itineraryId == widget.initialItineraryId,
            );
            if (index >= 0) {
              final offset = TripPreferencesService.storedPreferences == null
                  ? 0
                  : 1;
              _selectedTripIndex = offset + index;
            }
            _didSelectInitialItinerary = true;
          }
        });
        if (_availableTrips.isNotEmpty) {
          _loadGoogleDetailsForDay(_selectedDay);
        }
      }
    } catch (_) {}
  }

  List<SavedTrip> get _availableTrips {
    final list = <SavedTrip>[];
    final userPrefs = TripPreferencesService.storedPreferences;
    if (userPrefs != null && userPrefs.destination != null) {
      final days = userPrefs.numberOfDays ?? 3;
      list.add(
        SavedTrip(
          title: '${userPrefs.destination} Custom Schedule',
          isGenerated: true,
          date: 'Active Generated Plan',
          detail: '$days days itinerary',
          destination: '${userPrefs.destination}, Malaysia',
          budget: userPrefs.budgetCategory ?? 'Medium',
          interests: userPrefs.interests,
          totalDays: days,
        ),
      );
    }

    if (_dbSavedTrips.isNotEmpty) {
      list.addAll(_dbSavedTrips);
    }

    return list;
  }

  String get _tripKey =>
      _selectedSavedItinerary?.itineraryId ??
      'active:${SmartItineraryService.revision}';

  SavedTrip get _currentTrip {
    final trips = _availableTrips;
    if (trips.isEmpty) {
      return const SavedTrip(
        title: '',
        date: '',
        detail: '',
        destination: '',
        budget: '',
        interests: [],
        totalDays: 0,
      );
    }
    if (_selectedTripIndex >= trips.length) {
      _selectedTripIndex = 0;
    }
    return trips[_selectedTripIndex];
  }

  int get _totalDays => _availableTrips.isEmpty ? 0 : _currentTrip.totalDays;

  void _selectDay(int index) {
    if (_selectedDay == index) return;
    setState(() => _selectedDay = index);
    _loadWeatherForDay(index);
    if (_availableTrips.isNotEmpty) {
      showDemoSnackBar(
        context,
        context.l10n.showingDayValuePlanForValue(
          (index + 1).toString(),
          (_currentTrip.title).toString(),
        ),
        icon: Icons.calendar_today_outlined,
      );
    }
  }

  void _showTripSelectorSheet() {
    final trips = _availableTrips;
    if (trips.isEmpty) return;
    showModalBottomSheet(
      context: context,
      showDragHandle: true,
      backgroundColor: AppColors.nightSurface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetContext) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.folder_open, color: AppColors.primary),
                    SizedBox(width: 10),
                    Text(
                      context.l10n.selectPlannedItinerary,
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w900,
                        color: AppColors.ink,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  context
                      .l10n
                      .switchBetweenYourActiveTripsAndCustomGeneratedPlans,
                  style: TextStyle(color: AppColors.muted, fontSize: 13),
                ),
                const SizedBox(height: 16),
                Flexible(
                  child: ListView.separated(
                    shrinkWrap: true,
                    itemCount: trips.length,
                    separatorBuilder: (context, index) =>
                        const SizedBox(height: 10),
                    itemBuilder: (context, index) {
                      final trip = trips[index];
                      final isSelected = _selectedTripIndex == index;
                      return InkWell(
                        onTap: () {
                          Navigator.pop(context);
                          if (_selectedTripIndex != index) {
                            setState(() {
                              _selectedTripIndex = index;
                              _selectedDay = 0;
                            });
                            _loadWeatherForDay(0);
                            showDemoSnackBar(
                              context,
                              context.l10n.switchedToValueValueDays(
                                (trip.title).toString(),
                                (trip.totalDays).toString(),
                              ),
                              icon: Icons.swap_horiz,
                            );
                          }
                        },
                        borderRadius: BorderRadius.circular(16),
                        child: Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: isSelected
                                ? AppColors.primary.withValues(alpha: 0.08)
                                : Colors.grey.shade50,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: isSelected
                                  ? AppColors.primary
                                  : AppColors.nightLine,
                              width: isSelected ? 1.8 : 1,
                            ),
                          ),
                          child: Row(
                            children: [
                              CircleAvatar(
                                radius: 20,
                                backgroundColor: isSelected
                                    ? AppColors.primary
                                    : Colors.grey.shade200,
                                child: Icon(
                                  Icons.place,
                                  color: isSelected
                                      ? Colors.white
                                      : AppColors.muted,
                                  size: 20,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      context.tripTitle(trip),
                                      style: TextStyle(
                                        fontWeight: FontWeight.w900,
                                        fontSize: 15,
                                        color: isSelected
                                            ? AppColors.primary
                                            : AppColors.ink,
                                      ),
                                    ),
                                    const SizedBox(height: 3),
                                    Text(
                                      '${trip.destination} • ${context.tripDate(trip)}',
                                      style: const TextStyle(
                                        color: AppColors.muted,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: isSelected
                                      ? AppColors.primary
                                      : AppColors.nightSurface,
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(
                                    color: isSelected
                                        ? AppColors.primary
                                        : AppColors.nightLine,
                                  ),
                                ),
                                child: Text(
                                  context.l10n.valueDays(
                                    (trip.totalDays).toString(),
                                  ),
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                    color: isSelected
                                        ? Colors.white
                                        : AppColors.ink,
                                  ),
                                ),
                              ),
                              if (() {
                                final userPrefs =
                                    TripPreferencesService.storedPreferences;
                                final hasCustomTrip =
                                    userPrefs != null &&
                                    userPrefs.destination != null;
                                final isCustomTrip =
                                    hasCustomTrip && index == 0;
                                final dbTripIdx = hasCustomTrip
                                    ? index - 1
                                    : index;
                                final isDbTrip =
                                    dbTripIdx >= 0 &&
                                    dbTripIdx < _rawDbItineraries.length;
                                return isCustomTrip || isDbTrip;
                              }()) ...[
                                const SizedBox(width: 4),
                                IconButton(
                                  icon: const Icon(
                                    Icons.delete_outline,
                                    color: Colors.redAccent,
                                    size: 20,
                                  ),
                                  tooltip: context.l10n.deleteOrClearItinerary,
                                  padding: EdgeInsets.zero,
                                  constraints: const BoxConstraints(
                                    minWidth: 32,
                                    minHeight: 32,
                                  ),
                                  onPressed: () async {
                                    final userPrefs = TripPreferencesService
                                        .storedPreferences;
                                    final hasCustomTrip =
                                        userPrefs != null &&
                                        userPrefs.destination != null;
                                    final isCustomTrip =
                                        hasCustomTrip && index == 0;
                                    final dbTripIdx = hasCustomTrip
                                        ? index - 1
                                        : index;

                                    if (isCustomTrip) {
                                      final confirm = await showDialog<bool>(
                                        context: sheetContext,
                                        builder: (ctx) => AlertDialog(
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(
                                              16,
                                            ),
                                          ),
                                          title: Text(
                                            context.l10n.clearActivePlan,
                                            style: TextStyle(
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                          content: Text(
                                            context
                                                .l10n
                                                .areYouSureYouWantToClearYourCurrentGeneratedTripAndResetToDefault,
                                          ),
                                          actions: [
                                            TextButton(
                                              onPressed: () =>
                                                  Navigator.pop(ctx, false),
                                              child: Text(context.l10n.cancel),
                                            ),
                                            FilledButton(
                                              style: FilledButton.styleFrom(
                                                backgroundColor:
                                                    Colors.redAccent,
                                              ),
                                              onPressed: () =>
                                                  Navigator.pop(ctx, true),
                                              child: Text(context.l10n.clear),
                                            ),
                                          ],
                                        ),
                                      );
                                      if (confirm == true) {
                                        TripPreferencesService.clearPreferences();
                                        SmartItineraryService.clearLiveCache();
                                        _editedTripStops.clear();
                                        if (sheetContext.mounted) {
                                          Navigator.pop(sheetContext);
                                        }
                                        await _loadSavedTripsFromDatabase();
                                        if (!mounted) return;
                                        setState(() {
                                          _selectedTripIndex = 0;
                                          _selectedDay = 0;
                                        });
                                        showDemoSnackBar(
                                          this.context,
                                          this
                                              .context
                                              .l10n
                                              .activeTripPlanCleared,
                                          icon: Icons.refresh,
                                        );
                                      }
                                    } else if (dbTripIdx >= 0 &&
                                        dbTripIdx < _rawDbItineraries.length) {
                                      final confirm = await showDialog<bool>(
                                        context: sheetContext,
                                        builder: (ctx) => AlertDialog(
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(
                                              16,
                                            ),
                                          ),
                                          title: Text(
                                            context.l10n.deleteItinerary,
                                            style: TextStyle(
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                          content: Text(
                                            context.l10n
                                                .areYouSureYouWantToDeleteValue(
                                                  (trip.title).toString(),
                                                ),
                                          ),
                                          actions: [
                                            TextButton(
                                              onPressed: () =>
                                                  Navigator.pop(ctx, false),
                                              child: Text(context.l10n.cancel),
                                            ),
                                            FilledButton(
                                              style: FilledButton.styleFrom(
                                                backgroundColor:
                                                    Colors.redAccent,
                                              ),
                                              onPressed: () =>
                                                  Navigator.pop(ctx, true),
                                              child: Text(context.l10n.delete),
                                            ),
                                          ],
                                        ),
                                      );
                                      if (confirm == true &&
                                          dbTripIdx >= 0 &&
                                          dbTripIdx <
                                              _rawDbItineraries.length) {
                                        final itinId =
                                            _rawDbItineraries[dbTripIdx]
                                                .itineraryId;
                                        setState(() {
                                          _editedTripStops.remove(itinId);
                                          if (dbTripIdx <
                                              _rawDbItineraries.length) {
                                            _rawDbItineraries.removeAt(
                                              dbTripIdx,
                                            );
                                          }
                                          if (dbTripIdx <
                                              _dbSavedTrips.length) {
                                            _dbSavedTrips.removeAt(dbTripIdx);
                                          }
                                          _selectedTripIndex = 0;
                                          _selectedDay = 0;
                                        });
                                        if (sheetContext.mounted) {
                                          Navigator.pop(sheetContext);
                                        }
                                        final deleted =
                                            await SupabaseItineraryService()
                                                .deleteItinerary(itinId);
                                        await _loadSavedTripsFromDatabase();
                                        if (!mounted) return;
                                        setState(() {
                                          _selectedTripIndex = 0;
                                          _selectedDay = 0;
                                        });
                                        showDemoSnackBar(
                                          this.context,
                                          deleted
                                              ? SupabaseItineraryService()
                                                    .lastOperationMessage
                                              : this
                                                    .context
                                                    .l10n
                                                    .unableToDeleteThisItinerary,
                                          icon: deleted
                                              ? Icons.delete_outline
                                              : Icons.error_outline,
                                        );
                                      }
                                    }
                                  },
                                ),
                              ],
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _loadGoogleDetailsForDay(int day) async {
    final key = '$_tripKey:$day';
    final ids = _rawStopsForDay(day)
        .where((s) => s.isGooglePlace && s.placeId?.isNotEmpty == true)
        .map((s) => s.placeId!)
        .toSet();
    if (_liveDayKey == key &&
        ids.length == _livePlaceIds.length &&
        ids.containsAll(_livePlaceIds))
      return;
    final generation = ++_detailsGeneration;
    _liveDayKey = key;
    _livePlaceIds = ids;
    _liveDetails = {};
    final uid = AuthService().currentUser?.uid;
    if (ids.isEmpty) return;
    final references = await PlaceCatalogService().load();
    final rows = await GooglePlacesService().hydrateRows(
      [
        ...references.where((r) => ids.contains(r['place_id'])),
        for (final id in ids)
          if (!references.any((r) => r['place_id'] == id))
            {
              'place_id': id,
              'data_source': 'google',
              'state': _currentTrip.destination,
            },
      ],
      limit: 20,
      shouldContinue: () =>
          mounted &&
          generation == _detailsGeneration &&
          uid == AuthService().currentUser?.uid &&
          key == '$_tripKey:$_selectedDay',
    );
    final details = rows
        .where(
          (r) =>
              ids.contains(r['place_id']) &&
              (!PlaceCatalogService.isGoogleReference(r) || r['_live'] == true),
        )
        .map(
          (r) =>
              GooglePlaceDetails.fromApi(PlaceCatalogService.asGoogleShape(r)),
        )
        .toList();
    if (!mounted ||
        generation != _detailsGeneration ||
        uid != AuthService().currentUser?.uid ||
        key != '$_tripKey:$_selectedDay') {
      return;
    }
    setState(
      () => _liveDetails = {
        for (final detail in details.whereType<GooglePlaceDetails>())
          detail.id: detail,
      },
    );
  }

  List<TravelStop> _getStopsForDay(int day) {
    final raw = _rawStopsForDay(day);
    if (_liveDayKey != '$_tripKey:$day') return raw;
    return raw
        .map(
          (s) => _liveDetails[s.placeId] == null
              ? s
              : s.withGoogleDetails(_liveDetails[s.placeId]!),
        )
        .toList();
  }

  List<TravelStop> _rawStopsForDay(int day) {
    final trip = _currentTrip;
    final tripKey = _tripKey;
    if (_editedTripStops[tripKey] != null &&
        _editedTripStops[tripKey]![day] != null) {
      return _editedTripStops[tripKey]![day]!;
    }

    final userPrefs = TripPreferencesService.storedPreferences;
    final isCustomTrip = userPrefs != null && _selectedTripIndex == 0;
    if (isCustomTrip) {
      return getDailyStops(day);
    } else {
      final dbTripIdx = userPrefs != null
          ? _selectedTripIndex - 1
          : _selectedTripIndex;
      if (dbTripIdx >= 0 && dbTripIdx < _rawDbItineraries.length) {
        final itin = _rawDbItineraries[dbTripIdx];
        if (day < itin.dailySchedules.length) {
          return itin.dailySchedules[day].stops
              .map((s) => s.toTravelStop())
              .toList();
        } else {
          return [];
        }
      } else {
        return SmartItineraryService.generateDailyStops(
          preferences: TripPreferences(
            destination: trip.destination.split(',').first.trim(),
            numberOfDays: trip.totalDays,
            interests: trip.interests,
            budgetCategory: trip.budget,
          ),
          dayIndex: day,
        );
      }
    }
  }

  Widget _buildEmptyState() {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 48),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.calendar_month_outlined,
                size: 40,
                color: AppColors.primary,
              ),
            ),
            const SizedBox(height: 20),
            Text(
              context.l10n.noItinerariesYet,
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w800,
                color: AppColors.ink,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              context
                  .l10n
                  .youHaveNoActiveOrSavedTripsSetYourTravelPreferencesToGenerateASmartDayByDaySchedule,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: AppColors.muted,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: widget.onPlanTap,
              icon: const Icon(Icons.add_location_alt_outlined),
              label: Text(context.l10n.planYourTrip),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: AppColors.onNightAccent,
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 12,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget? _diningSuggestion() {
    final district = _preferences.destination;
    final diet = _preferences.dietaryPreference;
    final l = context.l10n;
    final (title, note, links) = switch (diet) {
      DietaryPreference.halalFriendly when district == 'Kuala Lumpur' => (
        "Nando's · Suria KLCC",
        l.planHalalBranchNote,
        [
          (l.planRestaurantSource, 'https://www.nandos.com.my/restaurants'),
          (
            l.planVerifyHalal,
            'https://www.islam.gov.my/en/law-legal/halal-status-check',
          ),
        ],
      ),
      DietaryPreference.halalFriendly => (
        l.planHalal,
        l.planHalalDirectoryNote,
        [
          (
            l.planVerifyHalal,
            'https://www.islam.gov.my/en/law-legal/halal-status-check',
          ),
        ],
      ),
      DietaryPreference.vegetarian when district == 'Kuala Lumpur' => (
        'WTF Bangsar',
        l.planVegetarianBranchNote,
        [(l.planRestaurantSource, 'https://kundrai.com/')],
      ),
      _ => (null, '', <(String, String)>[]),
    };
    if (title == null) return null;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: Theme.of(context).textTheme.titleSmall),
            Text(note),
            Wrap(
              spacing: 8,
              children: [
                for (final (label, address) in links)
                  TextButton(
                    onPressed: () async {
                      final opened = await launchUrl(
                        Uri.parse(address),
                        mode: LaunchMode.externalApplication,
                      );
                      if (!opened && mounted) {
                        showDemoSnackBar(
                          context,
                          context.l10n.unableToOpenThisLink,
                        );
                      }
                    },
                    child: Text(label),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_availableTrips.isEmpty) {
      return _buildEmptyState();
    }
    final trip = _currentTrip;
    final totalDays = _totalDays;
    if (_selectedDay >= totalDays) {
      _selectedDay = 0;
    }
    final stops = _getStopsForDay(_selectedDay);
    final primaryMode = _preferences.travelMode;
    final routeStops = [
      if (_preferences.dailyOrigin case final origin? when stops.isNotEmpty)
        origin,
      ...stops,
    ];

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 28),
      children: [
        if (widget.compactResult) ...[
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Text(
              '${MaterialLocalizations.of(context).formatShortDate(_dateForDay(0))}'
              ' – ${MaterialLocalizations.of(context).formatShortDate(_dateForDay(totalDays - 1))}'
              ' · ${context.l10n.valueDays(context.localNumber(totalDays))}',
            ),
          ),
          if (_draftSave case final saved?
              when saved.itineraryId ==
                  TripPreferencesService.activeItineraryId)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Text(
                saved.synced
                    ? context.l10n.itinerarySavedSuccessfullyToYourProfile
                    : context.l10n.savedOnThisDeviceCloudSyncIsPending,
              ),
            ),
        ] else
          InkWell(
            onTap: _showTripSelectorSheet,
            borderRadius: BorderRadius.circular(16),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: AppColors.nightSurface,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.nightLine, width: 1.5),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.03),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.1),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.flight_takeoff,
                      color: AppColors.primary,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          context.l10n.activeItinerary,
                          style: TextStyle(
                            color: AppColors.muted,
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.6,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          context.tripTitle(trip),
                          style: const TextStyle(
                            color: AppColors.ink,
                            fontSize: 15,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        Text(
                          '${MaterialLocalizations.of(context).formatShortDate(_dateForDay(0))} – ${MaterialLocalizations.of(context).formatShortDate(_dateForDay(totalDays - 1))} · ${context.l10n.valueDays(context.localNumber(totalDays))}',
                          style: const TextStyle(
                            color: AppColors.muted,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  const Icon(Icons.unfold_more, color: AppColors.primary),
                ],
              ),
            ),
          ),
        const SizedBox(height: 14),

        // Horizontally Scrollable Day Selector (Supports 1 to 7+ days without overflowing)
        SizedBox(
          height:
              56 * MediaQuery.textScalerOf(context).scale(1).clamp(1.0, 2.0),
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            itemCount: totalDays,
            separatorBuilder: (context, index) => const SizedBox(width: 8),
            itemBuilder: (context, index) {
              final isSelected = _selectedDay == index;
              return DayPill(
                label: context.l10n.dayValue((index + 1).toString()),
                active: isSelected,
                onTap: () => _selectDay(index),
              );
            },
          ),
        ),
        const SizedBox(height: 14),

        _buildDayIntelligenceBanner(stops),
        if (stops.any(
          (s) =>
              s.isGooglePlace &&
              (s.title == 'Saved Google place' || s.title == 'Attraction'),
        ))
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: () {
                _liveDayKey = null;
                _loadGoogleDetailsForDay(_selectedDay);
              },
              icon: const Icon(Icons.refresh),
              label: Text(context.l10n.retry),
            ),
          ),
        const SizedBox(height: 8),
        Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Wrap(
              spacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                if (stops.isNotEmpty &&
                    stops.every((stop) => stop.time.contains(' - ')))
                  OutlinedButton.icon(
                    onPressed: () => Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => TodayPlanPage(
                          storageKey:
                              '$_tripKey:$_selectedDay:${_dateForDay(_selectedDay).toIso8601String()}',
                          stops: stops,
                          date: _dateForDay(_selectedDay),
                          preferences: _preferences,
                        ),
                      ),
                    ),
                    icon: const Icon(Icons.play_arrow),
                    label: const Text('Today’s Plan'),
                  ),
                TextButton.icon(
                  onPressed: () {
                    final target = _dayRouteAnchor.currentContext;
                    if (target != null) {
                      Scrollable.ensureVisible(
                        target,
                        duration: MediaQuery.disableAnimationsOf(context)
                            ? Duration.zero
                            : const Duration(milliseconds: 350),
                        curve: Curves.easeOutCubic,
                      );
                    }
                  },
                  icon: const Icon(Icons.route_outlined),
                  label: const Text('View Route'),
                ),
              ],
            ),

            // A connected timeline makes the order and inbound legs explicit.
            for (var index = 0; index < stops.length; index++) ...[
              Builder(
                builder: (context) {
                  final stop = stops[index];
                  return IntrinsicHeight(
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        SizedBox(
                          width: 20,
                          child: Column(
                            children: [
                              const Icon(
                                Icons.circle,
                                size: 10,
                                color: AppColors.primary,
                              ),
                              Expanded(
                                child: Container(
                                  width: 2,
                                  color: AppColors.nightLine,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              if ((stop.inboundMode ?? primaryMode)
                                  case final transport?
                                  when index > 0 && stop.travelMinutes > 0)
                                Padding(
                                  padding: const EdgeInsets.only(
                                    left: 12,
                                    bottom: 6,
                                  ),
                                  child: Text(
                                    '${transport == 'E-hailing' ? context.l10n.planHailing : context.tr(transport)}'
                                    ' · ${stop.travelIsEstimated ? '~' : ''}'
                                    '${context.l10n.valueMin(context.localNumber(stop.travelMinutes))}',
                                    style: const TextStyle(
                                      color: AppColors.muted,
                                    ),
                                  ),
                                ),
                              StopCard(
                                stop: stop,
                                onTap: () => Navigator.of(context).push(
                                  MaterialPageRoute(
                                    builder: (_) => PlaceDetailPage(
                                      stop: stop,
                                      visitDate: _dateForDay(_selectedDay),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ],
            const SizedBox(height: 12),
            KeyedSubtree(
              key: _dayRouteAnchor,
              child: DayRouteMap(
                key: ValueKey((
                  _tripKey,
                  _selectedDay,
                  _preferences.travelMode,
                  routeStops
                      .map((stop) => '${stop.latitude},${stop.longitude}')
                      .join(';'),
                )),
                stops: routeStops,
                mode: _preferences.travelMode ?? 'Driving',
                service: _dayRoutes,
              ),
            ),
            const SizedBox(height: 12),
          ],
        ),
        ?_diningSuggestion(),
        if (_selectedSavedItinerary == null &&
            SmartItineraryService.dayWarnings[_selectedDay]?.isNotEmpty == true)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Text(
              context.itineraryWarnings(
                SmartItineraryService.dayWarnings[_selectedDay]!,
              ),
              style: const TextStyle(fontSize: 12, color: AppColors.muted),
            ),
          ),
        TextButton.icon(
          onPressed: _isRegenerating ? null : _regenerate,
          icon: const Icon(Icons.refresh),
          label: Text(
            _isRegenerating
                ? context.l10n.generating
                : context.l10n.regenerateItinerary,
          ),
        ),
        const SizedBox(height: 14),
        Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            OutlinedButton.icon(
              onPressed: () async {
                final currentStops = _getStopsForDay(_selectedDay);
                final otherDaysStops = <TravelStop>[];
                for (int d = 0; d < trip.totalDays; d++) {
                  if (d != _selectedDay) {
                    otherDaysStops.addAll(_getStopsForDay(d));
                  }
                }

                String? scheduleId;
                final userPrefs = TripPreferencesService.storedPreferences;
                final dbTripIdx = userPrefs != null
                    ? _selectedTripIndex - 1
                    : _selectedTripIndex;
                if (dbTripIdx >= 0 && dbTripIdx < _rawDbItineraries.length) {
                  final itin = _rawDbItineraries[dbTripIdx];
                  if (_selectedDay < itin.dailySchedules.length) {
                    scheduleId = itin.dailySchedules[_selectedDay].scheduleId;
                  }
                }

                final updatedStops = await Navigator.of(context)
                    .push<List<TravelStop>>(
                      MaterialPageRoute(
                        builder: (_) => EditItineraryScreen(
                          tripTitle: trip.title,
                          destination: trip.destination,
                          dayNumber: _selectedDay + 1,
                          initialStops: currentStops,
                          otherDaysStops: otherDaysStops,
                          weatherForecast: _currentDayForecast,
                          scheduleId: scheduleId,
                          preferences: _preferences,
                          scheduleDate: _dateForDay(_selectedDay),
                        ),
                      ),
                    );

                if (!mounted || !context.mounted) return;
                if (updatedStops != null) {
                  setState(() {
                    if (widget.compactResult) _draftSave = null;
                    final tripKey = _tripKey;
                    _editedTripStops.putIfAbsent(
                      tripKey,
                      () => {},
                    )[_selectedDay] = updatedStops;
                  });
                  showDemoSnackBar(
                    context,
                    context.l10n.dayValuePlanUpdatedValueStops(
                      (_selectedDay + 1).toString(),
                      (updatedStops.length).toString(),
                    ),
                    icon: Icons.check_circle_outline,
                  );
                }
              },
              icon: const Icon(Icons.edit_calendar_outlined),
              label: Text(
                context.l10n.editDayValue((_selectedDay + 1).toString()),
              ),
              style: demoOutlinedButtonStyle(),
            ),
            const SizedBox(height: 8),
            FilledButton.icon(
              onPressed: _isSavingTrip || _isRegenerating
                  ? null
                  : () async {
                      setState(() => _isSavingTrip = true);
                      final wasActive = _selectedSavedItinerary == null;
                      final revision = SmartItineraryService.revision;
                      final daysCount = trip.totalDays;
                      final userPrefs = _preferences;
                      final totalCost =
                          List.generate(
                            daysCount,
                            _getStopsForDay,
                          ).fold<double>(
                            0,
                            (sum, stops) => sum + SchedulingEngine.cost(stops),
                          );
                      final destState = trip.destination
                          .split(',')
                          .first
                          .trim();

                      final dailySchedules = <DailySchedule>[];
                      for (int day = 0; day < daysCount; day++) {
                        final dayStops = _getStopsForDay(day);
                        dailySchedules.add(
                          DailySchedule(
                            scheduleId: '',
                            itineraryId: '',
                            dayNumber: day + 1,
                            scheduleDate: _dateForDay(day),
                            totalDistanceKm:
                                SmartItineraryService.calculateRouteDistanceKm(
                                  dayStops,
                                ),
                            stops: [
                              for (int i = 0; i < dayStops.length; i++)
                                ItineraryStop(
                                  snapshot: dayStops[i],
                                  id: '',
                                  scheduleId: '',
                                  placeId:
                                      (dayStops[i].placeId != null &&
                                          dayStops[i].placeId!.isNotEmpty)
                                      ? dayStops[i].placeId!
                                      : 'poi_${destState.toLowerCase().replaceAll(' ', '_')}_d${day + 1}_$i',
                                  placeName: dayStops[i].title,
                                  stopOrder: i + 1,
                                  arrivalTime: dayStops[i].time.contains('-')
                                      ? dayStops[i].time.split('-').first.trim()
                                      : '09:00 AM',
                                  departureTime: dayStops[i].time.contains('-')
                                      ? dayStops[i].time.split('-').last.trim()
                                      : '11:00 AM',
                                  category: dayStops[i].category,
                                  latitude: dayStops[i].latitude,
                                  longitude: dayStops[i].longitude,
                                  photoUrl: dayStops[i].photoUrls.isNotEmpty
                                      ? dayStops[i].photoUrls.join('|')
                                      : (dayStops[i].primaryPhotoUrl ?? ''),
                                  photoUrls: dayStops[i].photoUrls,
                                ),
                            ],
                          ),
                        );
                      }

                      final result = await SupabaseItineraryService()
                          .saveItinerary(
                            preferences: userPrefs,
                            itineraryId:
                                _selectedSavedItinerary?.itineraryId ??
                                TripPreferencesService.activeItineraryId,
                            title: trip.title,
                            destinationState: destState,
                            totalCost: totalCost,
                            dailySchedules: dailySchedules,
                          );

                      if (mounted) {
                        setState(() {
                          _isSavingTrip = false;
                          if (result.success) _draftSave = result;
                        });
                      }
                      if (context.mounted) {
                        if (result.success) {
                          if (wasActive &&
                              revision == SmartItineraryService.revision) {
                            TripPreferencesService.activeItineraryId =
                                result.itineraryId;
                          }
                          await _loadSavedTripsFromDatabase();
                        }
                        if (!context.mounted) return;
                        showDemoSnackBar(
                          context,
                          result.message,
                          icon: result.success
                              ? Icons.cloud_done
                              : Icons.error_outline,
                        );
                      }
                    },
              icon: const Icon(Icons.bookmark_add_outlined),
              label: Text(context.l10n.saveItinerary),
              style: primaryFilledButtonStyle(),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildDayIntelligenceBanner(List<TravelStop> stops) {
    final saved = _selectedSavedItinerary;
    final distance =
        saved != null &&
            _editedTripStops[_tripKey]?[_selectedDay] == null &&
            _selectedDay < saved.dailySchedules.length
        ? saved.dailySchedules[_selectedDay].totalDistanceKm
        : 0.0;
    final forecast = _currentDayForecast;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Wrap(
        spacing: 12,
        runSpacing: 4,
        children: [
          Text(
            '${context.localNumber(stops.length)} ${context.l10n.attractions}',
          ),
          if (distance > 0) Text('${context.localNumber(distance)} km'),
          if (!_isLoadingWeather && forecast != null && forecast.isAvailable)
            Text('${forecast.temperatureC}°C · ${forecast.condition}'),
        ],
      ),
    );
  }
}

class DayPill extends StatelessWidget {
  const DayPill({
    super.key,
    required this.label,
    required this.onTap,
    this.active = false,
  });

  final String label;
  final VoidCallback onTap;
  final bool active;

  @override
  Widget build(BuildContext context) {
    return DemoTapCard(
      onTap: onTap,
      borderRadius: 14,
      child: Semantics(
        button: true,
        selected: active,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          decoration: BoxDecoration(
            color: active
                ? Theme.of(context).colorScheme.primary
                : AppColors.nightSurface,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: active
                  ? Theme.of(context).colorScheme.primary
                  : AppColors.nightLine,
              width: 1.4,
            ),
            boxShadow: active
                ? [
                    BoxShadow(
                      color: Theme.of(
                        context,
                      ).colorScheme.primary.withValues(alpha: 0.25),
                      blurRadius: 8,
                      offset: const Offset(0, 3),
                    ),
                  ]
                : null,
          ),
          child: Center(
            child: Text(
              context.tr(label),
              textAlign: TextAlign.center,
              style: TextStyle(
                color: active ? AppColors.onNightAccent : AppColors.nightBody,
                fontWeight: FontWeight.w800,
                fontSize: 13.5,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
