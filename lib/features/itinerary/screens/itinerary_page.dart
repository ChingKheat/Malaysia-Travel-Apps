import 'package:flutter/material.dart';

import 'package:smart_travel_planner/core/theme/app_colors.dart';
import 'package:smart_travel_planner/shared/utils/demo_feedback.dart';
import 'package:smart_travel_planner/features/itinerary/data/sample_data.dart';
import 'package:smart_travel_planner/features/itinerary/models/itinerary_models.dart';
import 'package:smart_travel_planner/features/itinerary/models/saved_trip.dart';
import 'package:smart_travel_planner/shared/models/travel_stop.dart';
import 'package:smart_travel_planner/features/itinerary/models/trip_preferences.dart';
import 'package:smart_travel_planner/shared/models/weather_forecast.dart';
import 'package:smart_travel_planner/features/itinerary/services/smart_itinerary_service.dart';
import 'package:smart_travel_planner/features/itinerary/services/scheduling_engine.dart';
import 'package:smart_travel_planner/features/auth/services/auth_service.dart';
import 'package:smart_travel_planner/features/itinerary/services/supabase_itinerary_service.dart';
import 'package:smart_travel_planner/features/itinerary/services/trip_preferences_service.dart';
import 'package:smart_travel_planner/shared/services/weather_service.dart';
import 'package:smart_travel_planner/features/places/services/place_catalog_service.dart';
import 'package:smart_travel_planner/features/places/models/google_place_details.dart';

import 'package:smart_travel_planner/shared/widgets/demo_tap.dart';
import 'package:smart_travel_planner/features/itinerary/widgets/stop_card.dart';
import 'package:smart_travel_planner/features/itinerary/widgets/summary_bar.dart';
import 'edit_itinerary_screen.dart';
import 'package:smart_travel_planner/features/places/screens/place_detail_page.dart';

class ItineraryPage extends StatefulWidget {
  final VoidCallback? onPlanTap;
  const ItineraryPage({super.key, this.onPlanTap});

  @override
  State<ItineraryPage> createState() => _ItineraryPageState();
}

class _ItineraryPageState extends State<ItineraryPage> {
  int _selectedTripIndex = 0;
  int _selectedDay = 0;
  List<SavedTrip> _dbSavedTrips = [];
  List<Itinerary> _rawDbItineraries = [];
  WeatherForecast? _currentDayForecast;
  bool _isLoadingWeather = false;
  bool _isRegenerating = false;
  bool _isSavingTrip = false;
  String? _loadedUserId;
  final Map<String, Map<int, List<TravelStop>>> _editedTripStops = {};
  String? _liveDayKey;
  Map<String, GooglePlaceDetails> _liveDetails = {};
  int _detailsGeneration = 0;

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
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Regenerate itinerary?'),
        content: const Text(
          'Your current unsaved changes will be replaced. Saved trips will remain available.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Regenerate'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    final preferences = _preferences.copyWith(
      startDate: _dateForDay(0),
      endDate: _dateForDay(_totalDays - 1),
    );
    final validation = TripPreferencesService.validatePreferences(preferences);
    if (!validation.success) {
      showDemoSnackBar(
        context,
        'Complete trip preferences in Plan before regenerating.',
      );
      return;
    }
    setState(() => _isRegenerating = true);
    await SmartItineraryService.generateLiveItineraryForAllDays(
      preferences: preferences,
      seed: DateTime.now().microsecondsSinceEpoch,
    );
    if (!mounted) return;
    setState(() {
      _editedTripStops.clear();
      _selectedTripIndex = 0;
      _selectedDay = 0;
      _isRegenerating = false;
    });
    await _loadWeatherForDay(0);
  }

  Future<void> _loadWeatherForDay(int dayIndex) async {
    if (_availableTrips.isEmpty) return;
    _loadGoogleDetailsForDay(dayIndex);
    final tripIdentity =
        _selectedSavedItinerary?.itineraryId ?? _currentTrip.title;
    final requestDate = _dateForDay(dayIndex);
    final dest = _currentTrip.destination.split(',').first.trim();
    if (dest.isEmpty) return;
    setState(() => _isLoadingWeather = true);
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
        'Showing Day ${index + 1} Plan for ${_currentTrip.title}',
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
      backgroundColor: Colors.white,
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
                const Row(
                  children: [
                    Icon(Icons.folder_open, color: AppColors.primary),
                    SizedBox(width: 10),
                    Text(
                      'Select Planned Itinerary',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w900,
                        color: AppColors.ink,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                const Text(
                  'Switch between your active trips and custom generated plans',
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
                              'Switched to ${trip.title} (${trip.totalDays} Days)',
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
                                  : const Color(0xFFE6E9F4),
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
                                      trip.title,
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
                                      '${trip.destination} • ${trip.date}',
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
                                      : Colors.white,
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(
                                    color: isSelected
                                        ? AppColors.primary
                                        : const Color(0xFFE6E9F4),
                                  ),
                                ),
                                child: Text(
                                  '${trip.totalDays} Days',
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
                                  tooltip: 'Delete or clear itinerary',
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
                                          title: const Text(
                                            'Clear Active Plan?',
                                            style: TextStyle(
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                          content: const Text(
                                            'Are you sure you want to clear your current generated trip and reset to default?',
                                          ),
                                          actions: [
                                            TextButton(
                                              onPressed: () =>
                                                  Navigator.pop(ctx, false),
                                              child: const Text('Cancel'),
                                            ),
                                            FilledButton(
                                              style: FilledButton.styleFrom(
                                                backgroundColor:
                                                    Colors.redAccent,
                                              ),
                                              onPressed: () =>
                                                  Navigator.pop(ctx, true),
                                              child: const Text('Clear'),
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
                                          'Active trip plan cleared',
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
                                          title: const Text(
                                            'Delete Itinerary?',
                                            style: TextStyle(
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                          content: Text(
                                            'Are you sure you want to delete "${trip.title}"?',
                                          ),
                                          actions: [
                                            TextButton(
                                              onPressed: () =>
                                                  Navigator.pop(ctx, false),
                                              child: const Text('Cancel'),
                                            ),
                                            FilledButton(
                                              style: FilledButton.styleFrom(
                                                backgroundColor:
                                                    Colors.redAccent,
                                              ),
                                              onPressed: () =>
                                                  Navigator.pop(ctx, true),
                                              child: const Text('Delete'),
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
                                              : 'Unable to delete this itinerary.',
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
    if (_liveDayKey == key) return;
    final generation = ++_detailsGeneration;
    _liveDayKey = key;
    _liveDetails = {};
    final uid = AuthService().currentUser?.uid;
    final stops = _rawStopsForDay(
      day,
    ).where((s) => s.isGooglePlace && s.placeId != null);
    final ids = stops.map((s) => s.placeId).toSet();
    final rows = await PlaceCatalogService().load();
    final details = rows
        .where((r) => ids.contains(r['place_id']))
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
        if (day < itin.dailySchedules.length &&
            itin.dailySchedules[day].stops.isNotEmpty) {
          return itin.dailySchedules[day].stops
              .map((s) => s.toTravelStop())
              .toList();
        } else {
          return getDailyStops(day);
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
            const Text(
              'No Itineraries Yet',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w800,
                color: AppColors.ink,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'You have no active or saved trips. Set your travel preferences to generate a smart day-by-day schedule.',
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
              label: const Text('Plan Your Trip'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
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

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 28),
      children: [
        if (_selectedSavedItinerary == null &&
            SmartItineraryService.dayWarnings[_selectedDay]?.isNotEmpty == true)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Text(
              SmartItineraryService.dayWarnings[_selectedDay]!,
              style: const TextStyle(fontSize: 12, color: AppColors.muted),
            ),
          ),
        // Active Trip Switcher Bar
        InkWell(
          onTap: _showTripSelectorSheet,
          borderRadius: BorderRadius.circular(16),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFFE6E9F4), width: 1.5),
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
                      const Text(
                        'ACTIVE ITINERARY',
                        style: TextStyle(
                          color: AppColors.muted,
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.6,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        trip.title,
                        style: const TextStyle(
                          color: AppColors.ink,
                          fontSize: 15,
                          fontWeight: FontWeight.w900,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        '${trip.destination} • ${trip.date}',
                        style: const TextStyle(
                          color: AppColors.muted,
                          fontSize: 12,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.sky,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: AppColors.primary.withValues(alpha: 0.2),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        '$totalDays Days',
                        style: const TextStyle(
                          color: AppColors.primary,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(width: 4),
                      const Icon(
                        Icons.unfold_more,
                        size: 16,
                        color: AppColors.primary,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 14),

        // Horizontally Scrollable Day Selector (Supports 1 to 7+ days without overflowing)
        SizedBox(
          height: 46,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            itemCount: totalDays,
            separatorBuilder: (context, index) => const SizedBox(width: 8),
            itemBuilder: (context, index) {
              final isSelected = _selectedDay == index;
              return DayPill(
                label: 'Day ${index + 1}',
                active: isSelected,
                onTap: () => _selectDay(index),
              );
            },
          ),
        ),
        const SizedBox(height: 14),

        // Day Theme & Highlight Summary Badge
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
          decoration: BoxDecoration(
            color: AppColors.sky,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: AppColors.primary.withValues(alpha: 0.15),
            ),
          ),
          child: Row(
            children: [
              const Icon(
                Icons.calendar_today_outlined,
                size: 18,
                color: AppColors.primary,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Day ${_selectedDay + 1} Theme',
                      style: const TextStyle(
                        color: AppColors.muted,
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      stops.isNotEmpty
                          ? stops.take(3).map((s) => s.title).join(' • ')
                          : '${trip.destination} Day ${_selectedDay + 1} Highlights',
                      style: const TextStyle(
                        color: AppColors.ink,
                        fontSize: 13.5,
                        fontWeight: FontWeight.w800,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        _buildDayIntelligenceBanner(stops),
        const SizedBox(height: 16),

        // Daily Stops List for Selected Day
        ...stops.map(
          (stop) => StopCard(
            stop: stop,
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => PlaceDetailPage(stop: stop)),
            ),
          ),
        ),
        const SizedBox(height: 12),
        SummaryBar(stops: stops),
        TextButton.icon(
          onPressed: _isRegenerating ? null : _regenerate,
          icon: const Icon(Icons.refresh),
          label: Text(_isRegenerating ? 'Generating…' : 'Regenerate itinerary'),
        ),
        const SizedBox(height: 14),
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
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
                      final tripKey = _tripKey;
                      _editedTripStops.putIfAbsent(
                        tripKey,
                        () => {},
                      )[_selectedDay] = updatedStops;
                    });
                    showDemoSnackBar(
                      context,
                      'Day ${_selectedDay + 1} plan updated (${updatedStops.length} stops)',
                      icon: Icons.check_circle_outline,
                    );
                  }
                },
                icon: const Icon(Icons.edit_calendar_outlined),
                label: Text('Edit Day ${_selectedDay + 1}'),
                style: demoOutlinedButtonStyle(),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: FilledButton.icon(
                onPressed: _isSavingTrip
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
                              (sum, stops) =>
                                  sum + SchedulingEngine.cost(stops),
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
                                        ? dayStops[i].time
                                              .split('-')
                                              .first
                                              .trim()
                                        : '09:00 AM',
                                    departureTime:
                                        dayStops[i].time.contains('-')
                                        ? dayStops[i].time
                                              .split('-')
                                              .last
                                              .trim()
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

                        if (mounted) setState(() => _isSavingTrip = false);
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
                label: const Text('Save Itinerary'),
                style: primaryFilledButtonStyle(),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildDayIntelligenceBanner(List<TravelStop> stops) {
    final distanceKm = SmartItineraryService.calculateRouteDistanceKm(stops);
    final forecast = _currentDayForecast;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(
                        Icons.route_outlined,
                        color: AppColors.primary,
                        size: 18,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Day Route',
                            style: TextStyle(
                              color: AppColors.muted,
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '~$distanceKm km • ${stops.length} stops',
                            style: const TextStyle(
                              color: AppColors.ink,
                              fontSize: 13,
                              fontWeight: FontWeight.w800,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              if (_isLoadingWeather)
                const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              else if (forecast != null)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: forecast.badgeColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: forecast.badgeColor.withValues(alpha: 0.3),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        forecast.isSuitableForOutdoor
                            ? Icons.wb_sunny_outlined
                            : Icons.umbrella_outlined,
                        size: 15,
                        color: forecast.badgeColor,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        forecast.isAvailable
                            ? '${forecast.temperatureC}°C • ${forecast.condition}'
                            : forecast.condition,
                        style: TextStyle(
                          color: forecast.badgeColor,
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
          if (forecast != null && forecast.adviceText.isNotEmpty) ...[
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
              decoration: BoxDecoration(
                color: forecast.badgeColor.withValues(alpha: 0.06),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                children: [
                  Icon(
                    forecast.isSuitableForOutdoor
                        ? Icons.check_circle_outline
                        : Icons.info_outline,
                    size: 14,
                    color: forecast.badgeColor,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      '${forecast.suitabilityBadge} — ${forecast.adviceText}',
                      style: TextStyle(
                        color: forecast.badgeColor.withValues(alpha: 0.9),
                        fontSize: 11.5,
                        fontWeight: FontWeight.w600,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
          ],
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
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        decoration: BoxDecoration(
          color: active ? Theme.of(context).colorScheme.primary : Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: active
                ? Theme.of(context).colorScheme.primary
                : const Color(0xFFE6E9F4),
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
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: active ? Colors.white : const Color(0xFF151A3A),
              fontWeight: FontWeight.w800,
              fontSize: 13.5,
            ),
          ),
        ),
      ),
    );
  }
}
