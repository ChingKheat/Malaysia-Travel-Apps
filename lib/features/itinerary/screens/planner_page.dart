import 'package:smart_travel_planner/features/profile/services/profile_preferences_service.dart';
import 'package:smart_travel_planner/features/places/services/google_places_service.dart';
import 'package:smart_travel_planner/shared/models/attraction.dart';
import '../services/planner_smart_fill.dart';
import 'package:smart_travel_planner/l10n/localized_labels.dart';
import 'package:flutter/material.dart';

import 'package:smart_travel_planner/core/theme/app_colors.dart';
import 'package:smart_travel_planner/shared/utils/demo_feedback.dart';
import 'package:smart_travel_planner/shared/data/malaysia_states.dart';
import 'package:smart_travel_planner/features/itinerary/models/trip_preferences.dart';
import 'package:smart_travel_planner/features/itinerary/services/smart_itinerary_service.dart';
import 'package:smart_travel_planner/features/itinerary/services/trip_preferences_service.dart';
import 'package:smart_travel_planner/features/itinerary/widgets/modern_date_range_picker.dart';
import 'itinerary_page.dart';
import 'package:smart_travel_planner/features/places/data/curated_attractions.dart';
import 'package:smart_travel_planner/shared/models/travel_stop.dart';
import 'package:smart_travel_planner/features/itinerary/services/scan_plan_places_store.dart';

class _DepartureSearch extends SearchDelegate<TravelStop?> {
  _DepartureSearch(this.options, this.destination, {this.excluded = const {}});

  final List<TravelStop> options;
  final String? destination;
  final Set<String> excluded;
  final _places = GooglePlacesService();
  String? _requestedQuery;
  Future<List<TravelStop>>? _pendingResults;

  @override
  List<Widget> buildActions(BuildContext context) => [
    IconButton(
      tooltip: MaterialLocalizations.of(context).deleteButtonTooltip,
      onPressed: () => query = '',
      icon: const Icon(Icons.clear),
    ),
  ];

  @override
  Widget buildLeading(BuildContext context) =>
      BackButton(onPressed: () => close(context, null));

  Future<List<TravelStop>> _search(String term, String state) async {
    final places = await _places.searchPlannerPlaces(query: term, state: state);
    final stops = <TravelStop>[];
    for (final place in places) {
      final stop = GooglePlacesService.convertGooglePlaceToStop(
        place: place,
        timeRange: '',
        durationLabel: '90 min',
      );
      if (!excluded.contains(stop.placeId) &&
          !excluded.contains(stop.title.toLowerCase())) {
        stops.add(stop);
      }
    }
    return stops;
  }

  @override
  Widget buildResults(BuildContext context) {
    final term = query.trim();
    final state = destination;
    if (term.length < 2 || state == null) return buildSuggestions(context);
    if (_requestedQuery != term) {
      _requestedQuery = term;
      _pendingResults = _search(term, state);
    }
    return FutureBuilder<List<TravelStop>>(
      key: ValueKey(term),
      future: _pendingResults,
      builder: (context, snapshot) => _resultsList(context, [
        ..._localResults,
        ...?snapshot.data,
      ], loading: snapshot.connectionState == ConnectionState.waiting),
    );
  }

  List<TravelStop> get _localResults => options
      .where(
        (place) =>
            place.title.toLowerCase().contains(query.trim().toLowerCase()),
      )
      .toList();

  @override
  Widget buildSuggestions(BuildContext context) => _resultsList(
    context,
    _localResults,
    searchOnline: query.trim().length >= 2 && destination != null,
  );

  Widget _resultsList(
    BuildContext context,
    List<TravelStop> stops, {
    bool searchOnline = false,
    bool loading = false,
  }) {
    final seen = <String>{};
    return ListView(
      children: [
        if (searchOnline)
          ListTile(
            leading: const Icon(Icons.public),
            title: Text(context.l10n.planSearchOnline),
            onTap: () => showResults(context),
          ),
        if (loading) const LinearProgressIndicator(),
        for (final stop in stops)
          if (seen.add(stop.title.toLowerCase()))
            ListTile(
              title: Text(stop.title),
              subtitle: stop.isGooglePlace ? Text(stop.note) : null,
              onTap: () => close(context, stop),
            ),
        if (stops.isEmpty && !loading && !searchOnline)
          ListTile(title: Text(context.l10n.planNoPlaces)),
      ],
    );
  }
}

enum _PlannerGroup { basics, who, backupTransport, dining, highlights }

enum PlanStep {
  destination,
  travelDates,
  tripLogistics,
  travelerPreferences,
  dailyPace,
  budget,
  travelMode,
  interests,
  generate,
}

class PlannerPage extends StatefulWidget {
  const PlannerPage({
    super.key,
    required this.onItineraryReady,
    this.onMyTripsTap,
    this.userId = 'guest',
    this.useModernPicker = false,
    @visibleForTesting this.enableTestingBypass = false,
    @visibleForTesting this.initialDestination,
    @visibleForTesting this.initialTravelDates,
    @visibleForTesting this.initialDailyStartTime,
    @visibleForTesting this.initialDailyEndTime,
    @visibleForTesting this.initialInterests,
    @visibleForTesting this.initialBudgetCategory,
    @visibleForTesting this.initialTravelMode,
  });

  final VoidCallback onItineraryReady;
  final VoidCallback? onMyTripsTap;
  final String userId;
  final bool useModernPicker;
  final bool enableTestingBypass;
  final String? initialDestination;
  final DateTimeRange? initialTravelDates;
  final TimeOfDay? initialDailyStartTime;
  final TimeOfDay? initialDailyEndTime;
  final Set<String>? initialInterests;
  final String? initialBudgetCategory;
  final String? initialTravelMode;

  @override
  State<PlannerPage> createState() => _PlannerPageState();
}

class _PlannerPageState extends State<PlannerPage> {
  // Trip Preference Form State variables
  String? destination;
  DateTimeRange? travelDates;
  TimeOfDay? dailyStartTime;
  TimeOfDay? dailyEndTime;
  final Set<String> interests = <String>{};
  String budgetCategory = '';
  String travelMode = '';
  int? _transitPlanningMinutes;
  TravelStop? _departurePoint;
  TravelStop? _accommodation;
  final _description = TextEditingController();
  String? _fillMessage;
  TimeOfDay? _arrival;
  TimeOfDay? _departure;
  bool _airport = false;
  int _airportTransferMinutes = 0;
  TravelerType _travelerType = TravelerType.solo;
  PaceCategory? _pace;
  PaceCategory get _selectedPace => _pace ?? PaceCategory.balanced;
  DietaryPreference _diet = DietaryPreference.unrestricted;
  final _mustVisit = <TravelStop>[];
  late final ScanPlanPlacesStore _scanPlanPlaces = ScanPlanPlacesStore(
    widget.userId,
  );
  final _secondaryModes = <String>{};

  static const _klOrigins = [
    ('Bukit Bintang', 3.1468, 101.7113),
    ('KLCC', 3.1579, 101.7123),
    ('KL Sentral', 3.1341, 101.6862),
  ];

  TravelStop _location((String, double, double) point) => TravelStop.fromJson({
    'title': point.$1,
    'latitude': point.$2,
    'longitude': point.$3,
    'opening_hours': 'Hours unverified',
  });

  Future<void> _chooseAccommodation() async {
    final point = await showSearch<TravelStop?>(
      context: context,
      delegate: _DepartureSearch([
        if (destination == 'Kuala Lumpur') ..._klOrigins.map(_location),
        ...curatedMalaysianAttractions.map(_highlight),
      ], destination),
    );
    if (mounted && point != null) {
      setState(() => _accommodation = point);
    }
  }

  TravelStop _highlight(Attraction place) => TravelStop.fromJson({
    ..._location((place.name, place.latitude, place.longitude)).toJson(),
    'place_id': place.xid,
    'category': place.category,
    'is_indoor': place.isIndoor,
  });

  List<TravelStop> get _allMustVisitPlaces {
    final seenNames = <String>{};
    return [
      ..._mustVisit,
      for (final place in _scanPlanPlaces.places)
        TravelStop(
          title: place.name,
          time: '',
          note: place.category,
          description: place.description ?? '',
          duration: '90 min',
          openingHours: 'Hours unverified',
          tips: const [],
          icon: Icons.place_outlined,
          color: AppColors.primary,
          category: place.category,
          placeId: place.googlePlaceId ?? place.xid,
          latitude: place.latitude,
          longitude: place.longitude,
          dataSource: place.googlePlaceId == null ? 'local' : 'google',
        ),
    ].where((stop) => seenNames.add(stop.title.trim().toLowerCase())).toList();
  }

  Future<void> _chooseHighlight() async {
    if (_mustVisit.length >= 3) return;
    final area = switch (destination) {
      'Kuala Lumpur' => 'kl',
      'Penang' => 'penang',
      'Melaka' => 'melaka',
      'Kedah' => 'langkawi',
      'Perak' => 'ipoh',
      _ => destination?.toLowerCase(),
    };
    final places = curatedMalaysianAttractions
        .where(
          (place) =>
              (area == null || place.xid.startsWith('curated_${area}_')) &&
              !_mustVisit.any((stop) => stop.placeId == place.xid),
        )
        .toList();
    final point = await showSearch<TravelStop?>(
      context: context,
      delegate: _DepartureSearch(
        places.map(_highlight).toList(),
        destination,
        excluded: {
          for (final stop in _mustVisit) ...[
            ?stop.placeId,
            stop.title.toLowerCase(),
          ],
        },
      ),
    );
    if (!mounted || point == null || _mustVisit.length >= 3) return;
    setState(() => _mustVisit.add(point));
  }

  bool _destinationConfirmed = false;
  bool _datesConfirmed = false;
  bool _logisticsConfirmed = false;
  bool _travelersConfirmed = false;
  bool _paceConfirmed = false;
  bool _budgetConfirmed = false;
  bool _modeConfirmed = false;
  bool _interestsConfirmed = false;
  bool _testingForm = false;

  PlanStep _activeStep = PlanStep.destination;
  final ScrollController _scrollController = ScrollController();

  final GlobalKey _destinationKey = GlobalKey();
  final GlobalKey _datesKey = GlobalKey();
  final GlobalKey _logisticsKey = GlobalKey();
  final GlobalKey _travelersKey = GlobalKey();
  final GlobalKey _paceKey = GlobalKey();
  final GlobalKey _budgetKey = GlobalKey();
  final GlobalKey _modeKey = GlobalKey();
  final GlobalKey _interestsKey = GlobalKey();
  final GlobalKey _generateKey = GlobalKey();

  GlobalKey _keyForStep(PlanStep step) {
    return switch (step) {
      PlanStep.destination => _destinationKey,
      PlanStep.travelDates => _datesKey,
      PlanStep.tripLogistics => _logisticsKey,
      PlanStep.travelerPreferences => _travelersKey,
      PlanStep.dailyPace => _paceKey,
      PlanStep.budget => _budgetKey,
      PlanStep.travelMode => _modeKey,
      PlanStep.interests => _interestsKey,
      PlanStep.generate => _generateKey,
    };
  }

  void _advanceToStep(PlanStep nextStep) {
    setState(() {
      _activeStep = nextStep;
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final key = _keyForStep(nextStep);
      final targetContext = key.currentContext;
      if (targetContext != null) {
        Scrollable.ensureVisible(
          targetContext,
          duration: _testingForm
              ? Duration.zero
              : const Duration(milliseconds: 550),
          curve: Curves.easeInOutCubic,
          alignment: 0.12,
        );
      }
    });
  }

  @override
  void dispose() {
    _scanPlanPlaces.removeListener(_onScanPlanPlacesChanged);
    ProfilePreferencesService.instance.removeListener(_loadProfileDefaults);
    _description.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  String? _errorMessage;
  Set<String> _highlightedEmptyFields = {};

  final List<TimeOfDay> _timeOptions = List.generate(
    18,
    (index) => TimeOfDay(hour: 6 + index, minute: 0),
  );

  @override
  void initState() {
    super.initState();
    _scanPlanPlaces.addListener(_onScanPlanPlacesChanged);
    _scanPlanPlaces.load();
    _testingForm = widget.enableTestingBypass;
    if (!_testingForm) {
      ProfilePreferencesService.instance.addListener(_loadProfileDefaults);
      _loadProfileDefaults();
    }
    if (widget.initialDestination != null) {
      destination = widget.initialDestination;
      _destinationConfirmed = true;
    }
    if (widget.initialTravelDates != null) {
      travelDates = widget.initialTravelDates;
      _datesConfirmed = true;
    }
    if (widget.initialDailyStartTime != null) {
      dailyStartTime = widget.initialDailyStartTime;
    }
    if (widget.initialDailyEndTime != null) {
      dailyEndTime = widget.initialDailyEndTime;
    }
    if (widget.initialDailyStartTime != null &&
        widget.initialDailyEndTime != null) {
      _logisticsConfirmed = true;
      _travelersConfirmed = true;
      _paceConfirmed = true;
    }
    if (widget.initialBudgetCategory != null) {
      budgetCategory = widget.initialBudgetCategory!;
      _budgetConfirmed = true;
    }
    if (widget.initialTravelMode != null) {
      travelMode = widget.initialTravelMode!;
      _modeConfirmed = true;
    }
    if (widget.initialInterests != null) {
      interests.addAll(widget.initialInterests!);
      _interestsConfirmed = true;
    }

    if (destination == null) {
      _activeStep = PlanStep.destination;
    } else if (travelDates == null) {
      _activeStep = PlanStep.travelDates;
    } else if (!_paceConfirmed) {
      _activeStep = PlanStep.dailyPace;
    } else if (travelMode.isEmpty ||
        (travelMode == 'Public Transport' && _transitPlanningMinutes == null)) {
      _activeStep = PlanStep.travelMode;
    } else if (budgetCategory.isEmpty) {
      _activeStep = PlanStep.budget;
    } else if (interests.isEmpty) {
      _activeStep = PlanStep.interests;
    } else {
      _activeStep = PlanStep.generate;
    }
  }

  void _onScanPlanPlacesChanged() {
    if (mounted) setState(() {});
  }

  String _formatDate(DateTime date) {
    return context.localDate(date);
  }

  String get _travelDateLabel {
    final dates = travelDates;
    if (dates == null) return context.l10n.selectTravelDates;
    return '${_formatDate(dates.start)} - ${_formatDate(dates.end)}';
  }

  int get _calculatedDays {
    final dates = travelDates;
    if (dates == null) return 0;
    return dates.end.difference(dates.start).inDays + 1;
  }

  String _formatTimeOfDay(TimeOfDay? time) {
    if (time == null) return context.l10n.selectTime;
    return time.format(context);
  }

  bool _isSuggestedStartTime(TimeOfDay time) {
    return time.hour == 8 || time.hour == 9;
  }

  bool _isSuggestedEndTime(TimeOfDay time) {
    return time.hour == 18 || time.hour == 21 || time.hour == 22;
  }

  bool _profilePaceOverridden = false;
  bool _profileDietOverridden = false;
  bool _profileBudgetOverridden = false;

  Future<void> _loadProfileDefaults() async {
    final result = await ProfilePreferencesService.instance.loadTravel();
    if (!mounted || result.preferences == null) return;
    final preferences = result.preferences!;
    setState(() {
      if (!_paceConfirmed && !_profilePaceOverridden) _pace = preferences.pace;
      if (!_profileDietOverridden) _diet = preferences.diet;
      if (!_budgetConfirmed && !_profileBudgetOverridden) {
        budgetCategory = preferences.budget.plannerValue;
      }
    });
  }

  Widget _buildTimePresetChip({
    required String title,
    required int startHour,
    required int endHour,
    required String hoursLabel,
  }) {
    final isSelected =
        dailyStartTime?.hour == startHour &&
        dailyStartTime?.minute == 0 &&
        dailyEndTime?.hour == endHour &&
        dailyEndTime?.minute == 0;
    return _PlanOption(
      title: title,
      subtitle: hoursLabel,
      selected: isSelected,
      onTap: () {
        setState(() {
          dailyStartTime = TimeOfDay(hour: startHour, minute: 0);
          dailyEndTime = TimeOfDay(hour: endHour, minute: 0);
          _errorMessage = null;
          _highlightedEmptyFields.remove('dailyStartTime');
          _highlightedEmptyFields.remove('dailyEndTime');
        });
      },
    );
  }

  Future<void> _pickDestination() async {
    final selected = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (context) {
        return DraggableScrollableSheet(
          expand: false,
          initialChildSize: 0.65,
          minChildSize: 0.4,
          maxChildSize: 0.9,
          builder: (context, scrollController) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: EdgeInsets.fromLTRB(20, 4, 20, 12),
                  child: Text(
                    context.l10n.selectDestination,
                    style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900),
                  ),
                ),
                Expanded(
                  child: ListView.separated(
                    controller: scrollController,
                    itemCount: malaysiaStates.length,
                    separatorBuilder: (_, _) => const Divider(
                      height: 1,
                      indent: 20,
                      endIndent: 20,
                      color: AppColors.line,
                    ),
                    itemBuilder: (context, index) {
                      final state = malaysiaStates[index];
                      final isSelected = state == destination;
                      return ListTile(
                        title: Text(
                          '$state, Malaysia',
                          style: TextStyle(
                            fontWeight: isSelected
                                ? FontWeight.w800
                                : FontWeight.w600,
                            color: isSelected
                                ? AppColors.primary
                                : AppColors.ink,
                          ),
                        ),
                        trailing: isSelected
                            ? const Icon(Icons.check, color: AppColors.primary)
                            : null,
                        onTap: () => Navigator.pop(context, state),
                      );
                    },
                  ),
                ),
              ],
            );
          },
        );
      },
    );

    if (mounted && selected != null) {
      setState(() {
        if (destination != selected) {
          _departurePoint = null;
          _accommodation = null;
          _mustVisit.clear();
        }
        destination = selected;
        _destinationConfirmed = true;
        _errorMessage = null;
        _highlightedEmptyFields.remove('destination');
      });
      _advanceToStep(PlanStep.travelDates);
    }
  }

  Future<void> _pickTravelDates() async {
    final now = DateTime.now();
    final firstDate = DateTime(now.year, now.month, now.day);
    final lastDate = now.add(const Duration(days: 365 * 2));
    final defaultRange =
        travelDates ??
        DateTimeRange(
          start: DateTime(now.year, now.month, now.day + 7),
          end: DateTime(now.year, now.month, now.day + 9),
        );

    final DateTimeRange? picked;
    if (widget.useModernPicker && !_testingForm) {
      picked = await showModernDateRangePicker(
        context: context,
        initialDateRange: travelDates ?? defaultRange,
        firstDate: firstDate,
        lastDate: lastDate,
      );
    } else {
      picked = await showDateRangePicker(
        context: context,
        firstDate: firstDate,
        lastDate: lastDate,
        initialDateRange: defaultRange,
        helpText: context.l10n.selectTravelDates,
        builder: (context, child) {
          final compact = MediaQuery.sizeOf(context).width < 360;
          final theme = Theme.of(context);
          final pickerTheme = DatePickerTheme.of(context);
          return Theme(
            data: theme.copyWith(
              colorScheme: ColorScheme.fromSeed(
                seedColor: AppColors.primary,
                primary: AppColors.primary,
              ),
              datePickerTheme: compact
                  ? pickerTheme.copyWith(
                      rangePickerHeaderHeadlineStyle:
                          (pickerTheme.rangePickerHeaderHeadlineStyle ??
                                  theme.textTheme.titleLarge)
                              ?.copyWith(fontSize: 20),
                    )
                  : pickerTheme,
            ),
            child: compact
                ? MediaQuery.withClampedTextScaling(
                    maxScaleFactor: 1.0,
                    child: child!,
                  )
                : child!,
          );
        },
      );
    }

    if (mounted && picked != null) {
      setState(() {
        travelDates = picked;
        _datesConfirmed = true;
        _errorMessage = null;
        _highlightedEmptyFields.remove('numberOfDays');
      });
      _advanceToStep(PlanStep.tripLogistics);
    }
  }

  bool _isGenerating = false;

  Future<void> _handleGenerateItinerary() async {
    if (_isGenerating) return;
    if (_isGenerating) return;
    demoHaptic();
    setState(() {
      _errorMessage = null;
      _highlightedEmptyFields.clear();
    });

    final currentPrefs = TripPreferences(
      destination: destination,
      numberOfDays: travelDates != null ? _calculatedDays : null,
      startDate: travelDates?.start,
      endDate: travelDates?.end,
      dailyStartTime: dailyStartTime,
      dailyEndTime: dailyEndTime,
      interests: interests.toList(),
      budgetCategory: budgetCategory,
      travelMode: travelMode,
      transitPlanningMinutes: _transitPlanningMinutes,
      departurePoint: _departurePoint,
      accommodationArea: _accommodation,
      arrivalTime: _arrival,
      departureTime: _departure,
      departureBufferMinutes: _airport ? 180 : 60,
      departureTransferMinutes: _airport && _departure != null
          ? _airportTransferMinutes
          : 0,
      travelerType: _travelerType,
      paceCategory: _selectedPace,
      dietaryPreference: _diet,
      mustVisitPlaces: List.unmodifiable(_allMustVisitPlaces),
      secondaryTransportModes: List.unmodifiable(
        _secondaryModes.where((mode) => mode != travelMode),
      ),
    );

    // Validate using TripPreferencesService (FR300_3 to FR300_9)
    final validationResult = TripPreferencesService.validatePreferences(
      currentPrefs,
      store: false,
    );

    if (!validationResult.success) {
      setState(() {
        _errorMessage = validationResult.message;
        _highlightedEmptyFields = validationResult.emptyFields;
        if (_highlightedEmptyFields.contains('destination')) {
          _activeStep = PlanStep.destination;
        } else if (_highlightedEmptyFields.contains('numberOfDays')) {
          _activeStep = PlanStep.travelDates;
        } else if (_highlightedEmptyFields.contains('dailyStartTime') ||
            _highlightedEmptyFields.contains('dailyEndTime')) {
          _activeStep = PlanStep.dailyPace;
        } else if (_highlightedEmptyFields.contains('budgetCategory')) {
          _activeStep = PlanStep.budget;
        } else if (_highlightedEmptyFields.contains('travelMode')) {
          _activeStep = PlanStep.travelMode;
        } else if (_highlightedEmptyFields.contains('interests')) {
          _activeStep = PlanStep.interests;
        }
      });
      _advanceToStep(_activeStep);
      return;
    }

    setState(() => _isGenerating = true);
    try {
      final generated =
          await SmartItineraryService.generateLiveItineraryForAllDays(
            preferences: currentPrefs,
            requireVisits: true,
          );
      if (!mounted) return;
      if (!generated) {
        setState(
          () => _errorMessage = context
              .l10n
              .noAdditionalPlacesFitThisDayTryFewerDaysOrWiderDailyHours,
        );
        return;
      }
      TripPreferencesService.activate(currentPrefs);
      await Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (context) => Scaffold(
            backgroundColor: AppColors.nightCanvas,
            appBar: AppBar(
              title: Text(currentPrefs.destination!),
              actions: [
                IconButton(
                  tooltip: context.l10n.planEditPreferences,
                  icon: const Icon(Icons.tune),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
            body: ItineraryPage(
              compactResult: true,
              onPlanTap: () => Navigator.of(context).pop(),
            ),
          ),
        ),
      );
    } catch (_) {
      if (mounted) {
        setState(
          () => _errorMessage =
              'Unable to create this itinerary. Check your connection and try again; your preferences are still here.',
        );
      }
    } finally {
      if (mounted) setState(() => _isGenerating = false);
    }
  }

  Widget _buildTimeField({
    required String label,
    required String field,
    required TimeOfDay? value,
    required bool Function(TimeOfDay) isSuggested,
    required ValueChanged<TimeOfDay?> onChanged,
  }) {
    final hasError = _highlightedEmptyFields.contains(field);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _PlanLabel(label),
        const SizedBox(height: 8),
        DecoratedBox(
          decoration: BoxDecoration(
            color: AppColors.nightCanvas,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: hasError ? Colors.red.shade700 : AppColors.line,
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<TimeOfDay>(
                value: value,
                isExpanded: true,
                itemHeight: null,
                borderRadius: BorderRadius.circular(16),
                icon: const Icon(Icons.expand_more, color: AppColors.muted),
                hint: Text(context.tr(label)),
                selectedItemBuilder: (context) => _timeOptions
                    .map(
                      (time) => Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          _formatTimeOfDay(time),
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: AppColors.ink,
                          ),
                        ),
                      ),
                    )
                    .toList(),
                items: _timeOptions.map((time) {
                  final suggested = isSuggested(time);
                  return DropdownMenuItem<TimeOfDay>(
                    value: time,
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(minHeight: 48),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        child: Row(
                          children: [
                            Expanded(child: Text(_formatTimeOfDay(time))),
                            if (suggested)
                              Tooltip(
                                message: context.l10n.suggestedTime,
                                child: Icon(
                                  Icons.check_circle_outline,
                                  color: AppColors.teal,
                                  size: 18,
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                  );
                }).toList(),
                onChanged: (time) {
                  setState(() {
                    onChanged(time);
                    if (_dailyDurationLabel == null) _paceConfirmed = false;
                    _errorMessage = null;
                    _highlightedEmptyFields.remove(field);
                  });
                },
              ),
            ),
          ),
        ),
        if (hasError) const _PlanFieldError('Choose a time.'),
      ],
    );
  }

  String? get _dailyDurationLabel {
    final start = dailyStartTime;
    final end = dailyEndTime;
    if (start == null || end == null) return null;
    final minutes = end.hour * 60 + end.minute - start.hour * 60 - start.minute;
    if (minutes <= 0) return null;
    final hours = minutes ~/ 60;
    final remainder = minutes % 60;
    return remainder == 0
        ? context.l10n.valueHoursOfSightseeingPerDay(context.localNumber(hours))
        : context.l10n.valueHoursValueMinutesOfSightseeingPerDay(
            context.localNumber(hours),
            context.localNumber(remainder),
          );
  }

  bool get _isInvalidTimeRange {
    final start = dailyStartTime;
    final end = dailyEndTime;
    if (start == null || end == null) return false;
    final minutes = end.hour * 60 + end.minute - start.hour * 60 - start.minute;
    return minutes <= 0;
  }

  String get _estimatedBudgetLabel {
    final days = _calculatedDays > 0 ? _calculatedDays : 1;
    return switch (budgetCategory) {
      'Low' => context.l10n.upToRmvalueTotal(context.localNumber(150 * days)),
      'Medium' => context.l10n.rmvalueRmvalueTotal(
        context.localNumber(150 * days),
        context.localNumber(300 * days),
      ),
      'High' => context.l10n.aboveRmvalueTotal(context.localNumber(300 * days)),
      _ => context.l10n.chooseYourDailyBudget,
    };
  }

  void _applyPreset(int index) {
    _profilePaceOverridden = true;
    _profileDietOverridden = true;
    setState(() {
      switch (index) {
        case 0:
          if (destination == null) {
            destination = 'Kuala Lumpur';
            _destinationConfirmed = true;
          }
          if (destination == 'Kuala Lumpur') {
            _accommodation ??= _location(_klOrigins.first);
            if (_mustVisit.isEmpty) {
              const landmarks = {
                'curated_kl_01',
                'curated_kl_02',
                'curated_kl_12',
              };
              _mustVisit.addAll(
                curatedMalaysianAttractions
                    .where((place) => landmarks.contains(place.xid))
                    .map(_highlight),
              );
            }
          }
          _pace ??= PaceCategory.balanced;
          if (travelMode.isEmpty) {
            travelMode = 'E-hailing';
            _modeConfirmed = false;
          }
          _secondaryModes.add('Public Transport');
          interests.addAll(['Culture', 'History']);
        case 1:
          _pace ??= PaceCategory.relaxed;
          if (_diet == DietaryPreference.unrestricted) {
            _diet = DietaryPreference.streetFood;
          }
          interests.addAll(['Food', 'Nightlife']);
        case 2:
          if (_travelerType == TravelerType.solo) {
            _travelerType = TravelerType.family;
          }
          _pace ??= PaceCategory.relaxed;
          interests.addAll(['Family', 'Adventure']);
      }
    });
  }

  Future<void> _reviewSmartFill() async {
    final suggestions = PlannerSmartFill.localSuggestions(
      _description.text.trim(),
    );
    if (suggestions.isEmpty) {
      setState(() => _fillMessage = context.l10n.planFillNoMatch);
      return;
    }
    final labels = <String, String>{
      'traveler': 'Travelers',
      'pace': 'Pace',
      'diet': 'Dining',
      'interest': 'Interest',
      'transport': 'Transport',
      'accommodation': 'Starting area',
    };
    final applicable = suggestions.entries
        .where(
          (entry) =>
              entry.key != 'accommodation' || destination == 'Kuala Lumpur',
        )
        .toList();
    if (applicable.isEmpty) {
      setState(() => _fillMessage = context.l10n.planFillNoMatch);
      return;
    }
    final apply = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Review suggestions'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Applying these suggestions may replace the corresponding current choices. You can edit them afterward.',
              ),
              const SizedBox(height: 12),
              for (final entry in applicable)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Text(
                    '${labels[entry.key] ?? entry.key}: ${entry.value}',
                  ),
                ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Apply suggestions'),
          ),
        ],
      ),
    );
    if (apply == true && mounted) _smartFill();
  }

  Future<void> _reviewPreset(int index, String title) async {
    const details = [
      'Adds culture and history, balanced pace, e-hailing and public transport. If empty, adds Kuala Lumpur, a starting area and landmarks.',
      'Adds food and nightlife, a relaxed pace and street food dining when unrestricted.',
      'Adds family and adventure interests, a relaxed pace and family travelers when currently solo.',
    ];
    final apply = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(
          '${details[index]} You can change these choices afterward.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Apply preset'),
          ),
        ],
      ),
    );
    if (apply == true && mounted) _applyPreset(index);
  }

  void _smartFill() {
    final text = _description.text.trim();
    if (text.isEmpty) return;
    final suggestions = PlannerSmartFill.localSuggestions(text);
    T? suggested<T extends Enum>(List<T> values, String key) =>
        values.where((value) => value.name == suggestions[key]).firstOrNull;
    setState(() {
      _travelerType =
          suggested(TravelerType.values, 'traveler') ?? _travelerType;
      if (suggested(PaceCategory.values, 'pace') case final pace?) {
        _profilePaceOverridden = true;
        _pace = pace;
      }
      if (suggested(DietaryPreference.values, 'diet') case final diet?) {
        _profileDietOverridden = true;
        _diet = diet;
      }
      if (suggestions['interest'] case final String interest) {
        interests.add(interest);
      }
      if (suggestions['transport'] case final String mode) {
        travelMode = mode;
        _modeConfirmed = false;
      }
      if (destination == 'Kuala Lumpur') {
        final origin = _klOrigins
            .where((point) => point.$1 == suggestions['accommodation'])
            .firstOrNull;
        if (origin != null) _accommodation = _location(origin);
      }
      _fillMessage = suggestions.isEmpty
          ? context.l10n.planFillNoMatch
          : context.l10n.planFillLocal;
    });
  }

  Widget _tripPickerTile({
    required String label,
    String? detail,
    required VoidCallback onTap,
    VoidCallback? onClear,
  }) {
    final theme = Theme.of(context);
    return Material(
      color: theme.scaffoldBackgroundColor,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: theme.colorScheme.outlineVariant),
      ),
      clipBehavior: Clip.antiAlias,
      child: ListTile(
        minTileHeight: 56,
        title: Text(label),
        subtitle: detail == null ? null : Text(detail),
        onTap: onTap,
        trailing: onClear == null
            ? const Icon(Icons.expand_more)
            : IconButton(
                icon: const Icon(Icons.clear),
                tooltip: MaterialLocalizations.of(context).deleteButtonTooltip,
                onPressed: onClear,
              ),
      ),
    );
  }

  List<Widget> _extraFields(_PlannerGroup group) {
    final l = context.l10n;
    Widget cards<T>(
      String title,
      List<T> values,
      List<String> labels,
      T? value,
      ValueChanged<T> select, {
      List<IconData>? icons,
      bool twoColumns = false,
    }) => Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title),
        const SizedBox(height: 8),
        _SelectionCardLayout(
          twoColumns: twoColumns,
          children: [
            for (var i = 0; i < values.length; i++)
              _SelectionCard(
                label: labels[i],
                icon: icons?[i],
                selected: value == values[i],
                onTap: () => setState(() => select(values[i])),
              ),
          ],
        ),
        const SizedBox(height: 16),
      ],
    );
    return switch (group) {
      _PlannerGroup.basics => [
        for (final arrival in [true, false]) ...[
          const SizedBox(height: 8),
          _tripPickerTile(
            label: arrival ? l.planArrival : l.planDeparture,
            detail: (arrival ? _arrival : _departure)?.format(context),
            onClear: (arrival ? _arrival : _departure) == null
                ? null
                : () => setState(() {
                    if (arrival) {
                      _arrival = null;
                    } else {
                      _departure = null;
                      _airport = false;
                    }
                  }),
            onTap: () async {
              final selected = await showTimePicker(
                context: context,
                initialTime:
                    (arrival ? _arrival : _departure) ??
                    TimeOfDay(hour: arrival ? 12 : 18, minute: 0),
              );
              if (!mounted || selected == null) return;
              setState(() {
                if (arrival) {
                  _arrival = selected;
                } else {
                  _departure = selected;
                }
              });
            },
          ),
        ],
        if (_departure != null)
          SwitchListTile(
            title: Text(l.planAirport),
            value: _airport,
            onChanged: (value) => setState(() => _airport = value),
          ),
        if (_departure != null && _airport)
          DropdownButtonFormField<int>(
            initialValue: _airportTransferMinutes,
            isExpanded: true,
            decoration: InputDecoration(labelText: l.planAirportTransfer),
            items: [
              DropdownMenuItem(value: 0, child: Text(l.planUndecided)),
              for (var minutes = 15; minutes <= 240; minutes += 15)
                DropdownMenuItem(
                  value: minutes,
                  child: Text(l.valueMin(context.localNumber(minutes))),
                ),
            ],
            onChanged: (minutes) {
              if (minutes != null) {
                setState(() => _airportTransferMinutes = minutes);
              }
            },
          ),
        const SizedBox(height: 8),
        _tripPickerTile(
          label: l.planAccommodation,
          detail: _accommodation?.title,
          onTap: _chooseAccommodation,
          onClear: _accommodation == null
              ? null
              : () => setState(() => _accommodation = null),
        ),
        const SizedBox(height: 8),
        Text(l.planLocalTime, style: Theme.of(context).textTheme.bodySmall),
      ],
      _PlannerGroup.who => [
        cards(
          l.planTravelers,
          TravelerType.values,
          [
            l.planSolo,
            l.planCouple,
            l.planFamilyType,
            l.planFriends,
            l.planSeniors,
          ],
          _travelerType,
          (value) => _travelerType = value,
          twoColumns: true,
          icons: const [
            Icons.person_outline,
            Icons.people_outline,
            Icons.family_restroom_outlined,
            Icons.groups_outlined,
            Icons.elderly_outlined,
          ],
        ),
        cards(
          l.planPace,
          PaceCategory.values,
          [l.planRelaxed, l.planBalanced, l.planPacked],
          _selectedPace,
          (value) {
            _profilePaceOverridden = true;
            _pace = value;
          },
        ),
      ],
      _PlannerGroup.backupTransport => [
        for (final option in [
          ('Public Transport', l.planRail),
          ('Walking', l.planWalk),
        ])
          if (option.$1 != travelMode)
            CheckboxListTile(
              title: Text(option.$2),
              value: _secondaryModes.contains(option.$1),
              onChanged: (enabled) => setState(() {
                if (enabled == true) {
                  _secondaryModes.add(option.$1);
                } else {
                  _secondaryModes.remove(option.$1);
                }
              }),
            ),
      ],
      _PlannerGroup.dining => [
        cards(
          l.planDiet,
          DietaryPreference.values,
          [
            l.planNoRestriction,
            l.planHalal,
            l.planVegetarian,
            l.planStreetFood,
          ],
          _diet,
          (value) {
            _profileDietOverridden = true;
            _diet = value;
          },
        ),
      ],
      _PlannerGroup.highlights => [
        ListTile(
          title: Text(l.planMustVisit),
          trailing: const Icon(Icons.search),
          onTap: _mustVisit.length >= 3 ? null : _chooseHighlight,
        ),
        Wrap(
          spacing: 8,
          children: [
            for (final stop in _mustVisit)
              InputChip(
                label: Text(stop.title),
                onDeleted: () => setState(() => _mustVisit.remove(stop)),
              ),
          ],
        ),
      ],
    };
  }

  @override
  Widget build(BuildContext context) {
    final canEditDates = _testingForm || _destinationConfirmed;
    final canEditTravelers =
        _testingForm ||
        (canEditDates &&
            _datesConfirmed &&
            _calculatedDays <= 30 &&
            _logisticsConfirmed);
    final canEditPace =
        _testingForm || (canEditTravelers && _travelersConfirmed);
    final canEditMode = _testingForm || (canEditPace && _paceConfirmed);
    final canEditBudget =
        _testingForm ||
        (canEditMode &&
            _modeConfirmed &&
            (travelMode != 'Public Transport' ||
                _transitPlanningMinutes != null));
    final canEditInterests =
        _testingForm || (canEditBudget && _budgetConfirmed);
    final canGenerate =
        _testingForm || (canEditInterests && _interestsConfirmed);
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;
    final days = _calculatedDays;
    final duration = _dailyDurationLabel;
    final budgetError = _highlightedEmptyFields.contains('budgetCategory');
    final modeError = _highlightedEmptyFields.contains('travelMode');
    final interestError = _highlightedEmptyFields.contains('interests');
    final completed = [
      _destinationConfirmed && _datesConfirmed,
      _logisticsConfirmed && _travelersConfirmed && _paceConfirmed,
      _modeConfirmed,
      _budgetConfirmed,
      _interestsConfirmed,
    ].where((value) => value).length;

    return Column(
      children: [
        Container(
          key: const ValueKey('plan-progress'),
          color: AppColors.nightCanvas,
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
          child: Semantics(
            label: 'Planning progress: $completed of 5 sections completed',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  '$completed of 5 sections completed',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                const SizedBox(height: 8),
                LinearProgressIndicator(value: completed / 5, minHeight: 4),
              ],
            ),
          ),
        ),
        Expanded(
          child: SingleChildScrollView(
            controller: _scrollController,
            padding: EdgeInsets.fromLTRB(20, 4, 20, 24 + bottomInset),
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (widget.onMyTripsTap != null) ...[
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton.icon(
                      key: const ValueKey('plan-my-trips'),
                      onPressed: widget.onMyTripsTap,
                      icon: const Icon(Icons.folder_outlined, size: 20),
                      label: Text(context.l10n.myTrips),
                      style: TextButton.styleFrom(
                        minimumSize: const Size(48, 48),
                        foregroundColor: AppColors.primary,
                      ),
                    ),
                  ),
                  const SizedBox(height: 4),
                ],
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: AppColors.nightAccentContainer,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: AppColors.primary.withValues(alpha: 0.3),
                    ),
                  ),
                  child: const Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        Icons.info_outline,
                        color: AppColors.primary,
                        size: 20,
                      ),
                      SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'Required: destination, dates, daily hours, transport, budget and interests.',
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                _PlannerShortcutCard(
                  icon: Icons.auto_awesome_outlined,
                  title: context.l10n.planSmartFill,
                  subtitle:
                      'Describe your trip to preview suggested preferences.',
                  children: [
                    TextField(
                      controller: _description,
                      maxLength: 1000,
                      maxLines: 3,
                      decoration: InputDecoration(
                        hintText: context.l10n.planDescribeTrip,
                      ),
                    ),
                    FilledButton(
                      onPressed: _reviewSmartFill,
                      child: Text(context.l10n.planSuggest),
                    ),
                    if (_fillMessage != null) ...[
                      const SizedBox(height: 8),
                      Text(_fillMessage!),
                    ],
                  ],
                ),
                const SizedBox(height: 10),
                _PlannerShortcutCard(
                  icon: Icons.tune_rounded,
                  title: context.l10n.planPresets,
                  subtitle:
                      'Start with a suggested travel style and review its choices.',
                  children: [
                    for (final entry in [
                      context.l10n.planClassic,
                      context.l10n.planFood,
                      context.l10n.planFamily,
                    ].indexed)
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        title: Text(entry.$2),
                        subtitle: Text(
                          [
                            'Culture and landmarks',
                            'Food and nightlife',
                            'Family-friendly adventures',
                          ][entry.$1],
                        ),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: () => _reviewPreset(entry.$1, entry.$2),
                      ),
                  ],
                ),
                const SizedBox(height: 12),
                _PlanSection(
                  key: const ValueKey('trip-basics-section'),
                  isHighlighted:
                      _activeStep == PlanStep.destination ||
                      _activeStep == PlanStep.travelDates ||
                      _activeStep == PlanStep.tripLogistics,
                  showHighlightBadge: false,
                  onTap: () => setState(() {
                    _activeStep = !_destinationConfirmed
                        ? PlanStep.destination
                        : !_datesConfirmed
                        ? PlanStep.travelDates
                        : PlanStep.tripLogistics;
                  }),
                  icon: Icons.luggage_outlined,
                  title: context.l10n.planBasics,
                  description: context.l10n.whereAndWhenWouldYouLikeToGo,
                  children: [
                    _PlanPickerField(
                      key: _destinationKey,
                      label: context.l10n.destination,
                      value: destination == null
                          ? context.l10n.selectDestination
                          : '$destination, Malaysia',
                      isPlaceholder: destination == null,
                      icon: Icons.place_outlined,
                      isHighlighted: _activeStep == PlanStep.destination,
                      hasError: _highlightedEmptyFields.contains('destination'),
                      errorText: context.l10n.chooseADestination,
                      onTap: () {
                        setState(() => _activeStep = PlanStep.destination);
                        _pickDestination();
                      },
                    ),
                    const SizedBox(height: 16),
                    _PlanPickerField(
                      key: _datesKey,
                      label: context.l10n.travelDates,
                      value: travelDates == null
                          ? context.l10n.selectTravelDates
                          : _travelDateLabel,
                      isPlaceholder: travelDates == null,
                      icon: Icons.calendar_month_outlined,
                      isHighlighted: _activeStep == PlanStep.travelDates,
                      supportingText: days > 0
                          ? '$days ${days == 1 ? 'day' : 'days'} to explore'
                          : null,
                      hasError: _highlightedEmptyFields.contains(
                        'numberOfDays',
                      ),
                      errorText: context.l10n.chooseYourTravelDates,
                      onTap: canEditDates
                          ? () {
                              setState(
                                () => _activeStep = PlanStep.travelDates,
                              );
                              _pickTravelDates();
                            }
                          : null,
                    ),
                    if (canEditDates && days > 30)
                      _PlanFieldError(TripPreferencesService.m4InvalidDays),
                    KeyedSubtree(
                      key: _logisticsKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          ExpansionTile(
                            tilePadding: EdgeInsets.zero,
                            title: Text(context.l10n.planOptionalDetails),
                            children: _extraFields(_PlannerGroup.basics),
                          ),
                          _PlanStepContinueButton(
                            onPressed:
                                !canEditDates || !_datesConfirmed || days > 30
                                ? null
                                : () {
                                    setState(() => _logisticsConfirmed = true);
                                    _advanceToStep(
                                      PlanStep.travelerPreferences,
                                    );
                                  },
                            label: context.l10n.planContinueWho,
                            disabledHint: context.l10n.planUnlockDates,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                _PlanSection(
                  key: _travelersKey,
                  enabled: canEditTravelers,
                  isHighlighted: _activeStep == PlanStep.travelerPreferences,
                  onTap: canEditTravelers
                      ? () => setState(
                          () => _activeStep = PlanStep.travelerPreferences,
                        )
                      : null,
                  icon: Icons.groups_outlined,
                  title: context.l10n.planWhoPace,
                  description: '',
                  children: [
                    ..._extraFields(_PlannerGroup.who),
                    _PlanStepContinueButton(
                      onPressed: !_testingForm && !_logisticsConfirmed
                          ? null
                          : () {
                              setState(() => _travelersConfirmed = true);
                              _advanceToStep(PlanStep.dailyPace);
                            },
                      label: context.l10n.planContinueHours,
                      disabledHint: context.l10n.planUnlockBasics,
                    ),
                    _PlanSection(
                      key: _paceKey,
                      nested: true,
                      enabled: canEditPace,
                      isHighlighted: _activeStep == PlanStep.dailyPace,
                      onTap: canEditPace
                          ? () =>
                                setState(() => _activeStep = PlanStep.dailyPace)
                          : null,
                      icon: Icons.schedule_outlined,
                      title: context.l10n.yourDailyPace,
                      description: context
                          .l10n
                          .setAsideTimeForAttractionsMealsAndGettingAround,
                      children: [
                        const _PlanLabel('Choose a suggested schedule'),
                        const SizedBox(height: 10),
                        _PlanChoices(
                          children: [
                            _buildTimePresetChip(
                              title: context.l10n.standard,
                              startHour: 8,
                              endHour: 22,
                              hoursLabel: context.l10n.text8Am10Pm,
                            ),
                            _buildTimePresetChip(
                              title: context.l10n.popular,
                              startHour: 9,
                              endHour: 21,
                              hoursLabel: context.l10n.text9Am9Pm,
                            ),
                            _buildTimePresetChip(
                              title: context.l10n.relaxed,
                              startHour: 9,
                              endHour: 18,
                              hoursLabel: context.l10n.text9Am6Pm,
                            ),
                          ],
                        ),
                        const SizedBox(height: 18),
                        LayoutBuilder(
                          builder: (context, constraints) {
                            final fields = [
                              _buildTimeField(
                                label: context.l10n.dailyStartTime,
                                field: 'dailyStartTime',
                                value: dailyStartTime,
                                isSuggested: _isSuggestedStartTime,
                                onChanged: (time) => dailyStartTime = time,
                              ),
                              _buildTimeField(
                                label: context.l10n.dailyEndTime,
                                field: 'dailyEndTime',
                                value: dailyEndTime,
                                isSuggested: _isSuggestedEndTime,
                                onChanged: (time) => dailyEndTime = time,
                              ),
                            ];
                            final scale =
                                MediaQuery.textScalerOf(context).scale(14) / 14;
                            if (constraints.maxWidth < 280 * scale) {
                              return Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  fields[0],
                                  const SizedBox(height: 14),
                                  fields[1],
                                ],
                              );
                            }
                            return Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(child: fields[0]),
                                const SizedBox(width: 12),
                                Expanded(child: fields[1]),
                              ],
                            );
                          },
                        ),
                        if (duration != null) ...[
                          const SizedBox(height: 14),
                          _PlanInlineNote(
                            icon: Icons.timelapse_outlined,
                            text: duration,
                          ),
                        ] else if (_isInvalidTimeRange)
                          _PlanFieldError(
                            TripPreferencesService.m5InvalidTimeRange,
                          ),
                        if (!_paceConfirmed)
                          _PlanStepContinueButton(
                            onPressed: !canEditPace || duration == null
                                ? null
                                : () {
                                    setState(() => _paceConfirmed = true);
                                    _advanceToStep(PlanStep.travelMode);
                                  },
                            label: MaterialLocalizations.of(
                              context,
                            ).continueButtonLabel,
                            disabledHint: context.l10n.planUnlockHours,
                          ),
                      ],
                    ),
                    _PlanSection(
                      key: _modeKey,
                      nested: true,
                      enabled: canEditMode,
                      isHighlighted: _activeStep == PlanStep.travelMode,
                      onTap: canEditMode
                          ? () => setState(
                              () => _activeStep = PlanStep.travelMode,
                            )
                          : null,
                      icon: Icons.route_outlined,
                      title: context.l10n.gettingAround,
                      description:
                          context.l10n.chooseHowYouWillTravelBetweenPlaces,
                      hasError: modeError,
                      children: [
                        _PlanChoices(
                          children: [
                            for (final option in const [
                              (
                                'Driving',
                                'Driving',
                                Icons.directions_car_outlined,
                              ),
                              (
                                'E-hailing',
                                'Grab / E-hailing',
                                Icons.local_taxi_outlined,
                              ),
                              (
                                'Walking',
                                'Walking',
                                Icons.directions_walk_outlined,
                              ),
                              (
                                'Public Transport',
                                'Transit',
                                Icons.directions_bus_outlined,
                              ),
                            ])
                              _PlanOption(
                                title: option.$1 == 'E-hailing'
                                    ? context.l10n.planHailing
                                    : context.tr(option.$2),
                                icon: option.$3,
                                selected: travelMode == option.$1,
                                onTap: () {
                                  setState(() {
                                    travelMode = option.$1;
                                    _modeConfirmed = false;
                                    _errorMessage = null;
                                    _highlightedEmptyFields.remove(
                                      'travelMode',
                                    );
                                  });
                                },
                              ),
                          ],
                        ),
                        if (modeError)
                          const _PlanFieldError('Choose a travel mode.'),
                        Material(
                          type: MaterialType.transparency,
                          child: ListTile(
                            leading: const Icon(Icons.trip_origin),
                            title: const Text('Daily starting point'),
                            subtitle: Text(
                              _departurePoint?.title ?? 'Choose a place',
                            ),
                            onTap: () async {
                              final point = await showSearch<TravelStop?>(
                                context: context,
                                delegate: _DepartureSearch([
                                  if (destination == 'Kuala Lumpur')
                                    ..._klOrigins.map(_location),
                                  ...curatedMalaysianAttractions.map(
                                    _highlight,
                                  ),
                                ], destination),
                              );
                              if (!mounted || point == null) return;
                              setState(() => _departurePoint = point);
                            },
                          ),
                        ),
                        if (travelMode.isNotEmpty) ...[
                          const SizedBox(height: 14),
                          _PlanInlineNote(
                            icon: travelMode == 'Public Transport'
                                ? Icons.info_outline
                                : Icons.check_circle_outline,
                            text: switch (travelMode) {
                              'Driving' || 'E-hailing' =>
                                'Explore further by car or e-hailing.',
                              'Walking' =>
                                'Enjoy nearby places at a walking pace.',
                              _ =>
                                'Enter a planning estimate per leg, including walking, waiting and transfers.',
                            },
                          ),
                        ],
                        if (travelMode == 'Public Transport')
                          TextFormField(
                            initialValue: _transitPlanningMinutes?.toString(),
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(
                              labelText: 'Estimated minutes per leg (1–240)',
                            ),
                            onChanged: (text) {
                              final minutes = int.tryParse(text);
                              setState(
                                () => _transitPlanningMinutes =
                                    minutes != null &&
                                        minutes >= 1 &&
                                        minutes <= 240
                                    ? minutes
                                    : null,
                              );
                            },
                          ),
                        if (travelMode.isNotEmpty) ...[
                          ..._extraFields(_PlannerGroup.backupTransport),
                          _PlanStepContinueButton(
                            onPressed:
                                travelMode == 'Public Transport' &&
                                    _transitPlanningMinutes == null
                                ? null
                                : () {
                                    setState(() => _modeConfirmed = true);
                                    _advanceToStep(PlanStep.budget);
                                  },
                            label: context.l10n.planContinueBudget,
                            disabledHint: context.l10n.planUnlockMode,
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                _PlanSection(
                  key: _budgetKey,
                  enabled: canEditBudget,
                  isHighlighted: _activeStep == PlanStep.budget,
                  onTap: canEditBudget
                      ? () => setState(() => _activeStep = PlanStep.budget)
                      : null,
                  icon: Icons.account_balance_wallet_outlined,
                  title: context.l10n.planBudgetDining,
                  description: context
                      .l10n
                      .perPersonIncludingMealsAttractionTicketsAndLocalTransport,
                  hasError: budgetError,
                  children: [
                    _PlanChoices(
                      children: [
                        for (final option in const [
                          ('Low', 'Under RM150'),
                          ('Medium', 'RM150–300'),
                          ('High', 'Over RM300'),
                        ])
                          _PlanOption(
                            title: context.tr(option.$1),
                            subtitle: context.tr(option.$2),
                            selected: budgetCategory == option.$1,
                            onTap: () {
                              setState(() {
                                _profileBudgetOverridden = true;
                                budgetCategory = option.$1;
                                _budgetConfirmed = false;
                                _errorMessage = null;
                                _highlightedEmptyFields.remove(
                                  'budgetCategory',
                                );
                              });
                            },
                          ),
                      ],
                    ),
                    if (budgetError)
                      const _PlanFieldError('Choose a daily budget.'),
                    const SizedBox(height: 14),
                    _PlanNotice(
                      icon: Icons.payments_outlined,
                      title: _estimatedBudgetLabel,
                      message: days <= 1
                          ? context.l10n.estimatedFor1DayPerPerson
                          : context.l10n.estimatedForValueDaysPerPerson(
                              context.localNumber(days),
                            ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Estimates in Malaysian ringgit (RM) include meals, attraction fees and local transport. Accommodation and travel to the first stop are excluded; prices are not confirmed.',
                    ),
                    ..._extraFields(_PlannerGroup.dining),
                    _PlanStepContinueButton(
                      onPressed: budgetCategory.isEmpty
                          ? null
                          : () {
                              setState(() => _budgetConfirmed = true);
                              _advanceToStep(PlanStep.interests);
                            },
                      label: context.l10n.planContinueHighlights,
                      disabledHint: context.l10n.planUnlockBudget,
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                _PlanSection(
                  key: _interestsKey,
                  enabled: canEditInterests,
                  isHighlighted: _activeStep == PlanStep.interests,
                  onTap: canEditInterests
                      ? () => setState(() => _activeStep = PlanStep.interests)
                      : null,
                  icon: Icons.favorite_border,
                  title: context.l10n.planHighlightsInterests,
                  description: context
                      .l10n
                      .pickOneOrMoreInterestsWeLlUseTheseToFindPlacesForYou,
                  hasError: interestError,
                  children: [
                    ..._extraFields(_PlannerGroup.highlights),
                    _SelectionCardLayout(
                      twoColumns: true,
                      children: [
                        for (final option in const [
                          ('Culture', Icons.museum_outlined),
                          ('Food', Icons.restaurant_outlined),
                          ('Nature', Icons.park_outlined),
                          ('Shopping', Icons.shopping_bag_outlined),
                          ('History', Icons.account_balance_outlined),
                          ('Adventure', Icons.hiking_outlined),
                          ('Family', Icons.family_restroom_outlined),
                          ('Nightlife', Icons.nightlife_outlined),
                        ])
                          _SelectionCard(
                            label: context.tr(option.$1),
                            icon: option.$2,
                            selected: interests.contains(option.$1),
                            multiple: true,
                            onTap: () {
                              setState(() {
                                if (!interests.add(option.$1)) {
                                  interests.remove(option.$1);
                                }
                                if (interests.isEmpty) {
                                  _interestsConfirmed = false;
                                }
                                _errorMessage = null;
                                _highlightedEmptyFields.remove('interests');
                              });
                            },
                          ),
                      ],
                    ),
                    if (_scanPlanPlaces.places.isNotEmpty) ...[
                      const SizedBox(height: 16),
                      Text(
                        context.l10n.scanPlanPlaces,
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      Text(
                        _scanPlanPlaces.places.length == 1
                            ? context.l10n.scanPlanOnePlace
                            : context.l10n.valuePlaces(
                                _scanPlanPlaces.places.length.toString(),
                              ),
                      ),
                      for (final place in _scanPlanPlaces.places)
                        ListTile(
                          key: ValueKey('plan-scan-place-${place.xid}'),
                          contentPadding: EdgeInsets.zero,
                          leading: const Icon(Icons.place_outlined),
                          title: Text(place.name),
                          subtitle: Text(place.category),
                          trailing: IconButton(
                            tooltip: context.l10n.removeStop,
                            onPressed: () => _scanPlanPlaces.remove(place.xid),
                            icon: const Icon(Icons.close),
                          ),
                        ),
                    ],
                    if (interestError)
                      const _PlanFieldError('Choose at least one interest.'),
                    if (!_interestsConfirmed)
                      _PlanStepContinueButton(
                        onPressed: !canEditInterests || interests.isEmpty
                            ? null
                            : () {
                                setState(() => _interestsConfirmed = true);
                                _advanceToStep(PlanStep.generate);
                              },
                        label: MaterialLocalizations.of(
                          context,
                        ).continueButtonLabel,
                        disabledHint: context.l10n.planUnlockInterests,
                      ),
                  ],
                ),
                const SizedBox(height: 24),
                if (_errorMessage != null) ...[
                  Semantics(
                    liveRegion: true,
                    child: _PlanNotice(
                      icon: Icons.error_outline,
                      title: context.l10n.checkYourTripPreferences,
                      message: _errorMessage!,
                      isError: true,
                    ),
                  ),
                  const SizedBox(height: 16),
                ],
                AnimatedContainer(
                  key: _generateKey,
                  duration: const Duration(milliseconds: 350),
                  curve: Curves.easeOutCubic,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: _activeStep == PlanStep.generate && canGenerate
                        ? [
                            BoxShadow(
                              color: AppColors.primary.withValues(alpha: 0.45),
                              blurRadius: 18,
                              spreadRadius: 2,
                            ),
                          ]
                        : null,
                  ),
                  child: FilledButton.icon(
                    onPressed: canGenerate && !_isGenerating
                        ? _handleGenerateItinerary
                        : null,
                    icon: const Icon(Icons.auto_awesome),
                    label: Text(
                      _isGenerating
                          ? context.l10n.generating
                          : context.l10n.generateMyItinerary,
                      textAlign: TextAlign.center,
                    ),
                    style: primaryFilledButtonStyle().copyWith(
                      minimumSize: const WidgetStatePropertyAll(
                        Size.fromHeight(56),
                      ),
                      padding: const WidgetStatePropertyAll(
                        EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _PlannerShortcutCard extends StatelessWidget {
  const _PlannerShortcutCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.children,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final shape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(16),
      side: const BorderSide(color: AppColors.line),
    );
    return Material(
      color: AppColors.nightSurface,
      shape: shape,
      clipBehavior: Clip.antiAlias,
      child: ExpansionTile(
        shape: const Border(),
        collapsedShape: const Border(),
        tilePadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
        childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        leading: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: AppColors.nightAccentContainer,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: AppColors.primary, size: 21),
        ),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Text(subtitle),
        ),
        children: children,
      ),
    );
  }
}

class _PlanSection extends StatelessWidget {
  const _PlanSection({
    super.key,
    required this.icon,
    required this.title,
    required this.description,
    required this.children,
    this.hasError = false,
    this.nested = false,
    this.enabled = true,
    this.isHighlighted = false,
    this.showHighlightBadge = true,
    this.onTap,
  });

  final IconData icon;
  final String title;
  final String description;
  final List<Widget> children;
  final bool hasError;
  final bool nested;
  final bool enabled;
  final bool isHighlighted;
  final bool showHighlightBadge;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final border = hasError
        ? Border.all(color: Colors.red.shade700, width: 1.5)
        : isHighlighted
        ? Border.all(color: AppColors.primary, width: 2.0)
        : Border.all(color: AppColors.line, width: 1.0);

    final shadows = isHighlighted
        ? [
            BoxShadow(
              color: AppColors.primary.withValues(alpha: 0.38),
              blurRadius: 16,
              spreadRadius: 1,
            ),
          ]
        : null;

    final content = AnimatedContainer(
      duration: const Duration(milliseconds: 350),
      curve: Curves.easeOutCubic,
      padding: EdgeInsets.all(nested ? 8 : 16),
      decoration: BoxDecoration(
        color: isHighlighted
            ? Color.alphaBlend(
                AppColors.primary.withValues(alpha: 0.05),
                AppColors.nightSurface,
              )
            : AppColors.nightSurface,
        borderRadius: BorderRadius.circular(22),
        border: border,
        boxShadow: shadows,
      ),
      child: Material(
        type: MaterialType.transparency,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                AnimatedContainer(
                  duration: const Duration(milliseconds: 350),
                  padding: const EdgeInsets.all(9),
                  decoration: BoxDecoration(
                    color: isHighlighted
                        ? AppColors.primary.withValues(alpha: 0.22)
                        : AppColors.nightAccentContainer,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(icon, size: 21, color: AppColors.primary),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    context.tr(title),
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: AppColors.ink,
                    ),
                  ),
                ),
                if (isHighlighted && showHighlightBadge)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 9,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.18),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: AppColors.primary.withValues(alpha: 0.6),
                        width: 1,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 6,
                          height: 6,
                          decoration: const BoxDecoration(
                            color: AppColors.primary,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 5),
                        const Text(
                          'Next',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                            color: AppColors.primary,
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
            if (description.isNotEmpty) ...[
              const SizedBox(height: 10),
              Text(
                context.tr(description),
                style: const TextStyle(
                  fontSize: 13,
                  height: 1.5,
                  color: AppColors.muted,
                ),
              ),
            ],
            const SizedBox(height: 18),
            if (enabled)
              ...children
            else
              _LockedPlanControls(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: children,
                ),
              ),
          ],
        ),
      ),
    );

    if (onTap != null) {
      return GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.translucent,
        child: content,
      );
    }
    return content;
  }
}

class _LockedPlanControls extends StatelessWidget {
  const _LockedPlanControls({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      enabled: false,
      child: ExcludeFocus(
        child: IgnorePointer(child: Opacity(opacity: 0.55, child: child)),
      ),
    );
  }
}

class _PlanPickerField extends StatelessWidget {
  const _PlanPickerField({
    super.key,
    required this.label,
    required this.value,
    required this.icon,
    required this.onTap,
    required this.hasError,
    required this.errorText,
    this.supportingText,
    this.isPlaceholder = false,
    this.isHighlighted = false,
  });

  final String label;
  final String value;
  final IconData icon;
  final VoidCallback? onTap;
  final bool hasError;
  final String errorText;
  final String? supportingText;
  final bool isPlaceholder;
  final bool isHighlighted;

  @override
  Widget build(BuildContext context) {
    final border = hasError
        ? Border.all(color: Colors.red.shade700, width: 1.5)
        : isHighlighted
        ? Border.all(color: AppColors.primary, width: 2.0)
        : Border.all(color: AppColors.line, width: 1.0);

    final shadows = isHighlighted
        ? [
            BoxShadow(
              color: AppColors.primary.withValues(alpha: 0.38),
              blurRadius: 14,
              spreadRadius: 1,
            ),
          ]
        : null;

    final field = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(child: _PlanLabel(label)),
            if (isHighlighted)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: AppColors.primary.withValues(alpha: 0.6),
                    width: 1,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 5,
                      height: 5,
                      decoration: const BoxDecoration(
                        color: AppColors.primary,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 4),
                    const Text(
                      'Select',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        color: AppColors.primary,
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
        const SizedBox(height: 8),
        Semantics(
          button: true,
          label: label,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 350),
            curve: Curves.easeOutCubic,
            decoration: BoxDecoration(
              color: isHighlighted
                  ? Color.alphaBlend(
                      AppColors.primary.withValues(alpha: 0.05),
                      AppColors.nightCanvas,
                    )
                  : AppColors.nightCanvas,
              borderRadius: BorderRadius.circular(14),
              border: border,
              boxShadow: shadows,
            ),
            clipBehavior: Clip.antiAlias,
            child: Material(
              type: MaterialType.transparency,
              child: InkWell(
                onTap: onTap,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(minHeight: 60),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 14,
                    ),
                    child: Row(
                      children: [
                        Icon(icon, size: 21, color: AppColors.primary),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                value,
                                style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: isPlaceholder
                                      ? FontWeight.w500
                                      : FontWeight.w700,
                                  color: isPlaceholder
                                      ? AppColors.muted
                                      : AppColors.ink,
                                ),
                              ),
                              if (supportingText != null) ...[
                                const SizedBox(height: 5),
                                Text(
                                  context.tr(supportingText!),
                                  style: const TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: AppColors.primary,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                        const SizedBox(width: 6),
                        const Icon(Icons.expand_more, color: AppColors.muted),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
        if (hasError) _PlanFieldError(errorText),
      ],
    );
    return onTap == null ? _LockedPlanControls(child: field) : field;
  }
}

class _SelectionCardLayout extends StatelessWidget {
  const _SelectionCardLayout({required this.children, this.twoColumns = false});

  final List<Widget> children;
  final bool twoColumns;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final useTwo =
          twoColumns &&
          constraints.maxWidth >= 300 &&
          MediaQuery.textScalerOf(context).scale(14) <= 18;
      final width = useTwo
          ? (constraints.maxWidth - 8) / 2
          : constraints.maxWidth;
      return Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          for (final child in children) SizedBox(width: width, child: child),
        ],
      );
    },
  );
}

class SelectionCard extends StatelessWidget {
  const SelectionCard({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
    this.icon,
    this.multiple = false,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;
  final IconData? icon;
  final bool multiple;

  @override
  Widget build(BuildContext context) => Semantics(
    container: true,
    button: true,
    selected: selected,
    label: label,
    onTap: onTap,
    child: ExcludeSemantics(
      child: Material(
        color: selected
            ? AppColors.primary.withValues(alpha: 0.12)
            : AppColors.nightCanvas,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: BorderSide(
            color: selected ? AppColors.primary : AppColors.line,
            width: selected ? 1.5 : 1,
          ),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 56),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
              child: Row(
                children: [
                  if (icon != null) ...[
                    Icon(
                      icon,
                      size: 21,
                      color: selected ? AppColors.primary : AppColors.muted,
                    ),
                    const SizedBox(width: 8),
                  ],
                  Expanded(
                    child: Text(
                      label,
                      style: TextStyle(
                        color: selected ? AppColors.primary : AppColors.ink,
                        fontWeight: selected
                            ? FontWeight.w700
                            : FontWeight.w500,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Icon(
                    multiple
                        ? (selected
                              ? Icons.check_box
                              : Icons.check_box_outline_blank)
                        : (selected
                              ? Icons.radio_button_checked
                              : Icons.radio_button_unchecked),
                    size: 20,
                    color: selected ? AppColors.primary : AppColors.muted,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    ),
  );
}

typedef _SelectionCard = SelectionCard;
typedef _PlanStepContinueButton = PlanStepContinueButton;

class PlanStepContinueButton extends StatelessWidget {
  const PlanStepContinueButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon = Icons.arrow_forward_rounded,
    this.hint,
    this.disabledHint,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData icon;
  final String? hint;
  final String? disabledHint;

  @override
  Widget build(BuildContext context) {
    final isEnabled = onPressed != null;
    final hintText = isEnabled
        ? (hint ?? context.l10n.planTapToProceed)
        : (disabledHint ?? context.l10n.planUnlockDates);

    return Padding(
      padding: const EdgeInsets.only(top: 18.0, bottom: 4.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.only(bottom: 8.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: [
                if (isEnabled)
                  Container(
                    width: 8,
                    height: 8,
                    decoration: const BoxDecoration(
                      color: AppColors.primary,
                      shape: BoxShape.circle,
                    ),
                  )
                else
                  const Icon(
                    Icons.info_outline_rounded,
                    size: 15,
                    color: AppColors.primary,
                  ),
                const SizedBox(width: 6),
                Flexible(
                  child: Text(
                    hintText,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: isEnabled
                          ? AppColors.primary
                          : AppColors.primary.withValues(alpha: 0.95),
                      letterSpacing: 0.2,
                    ),
                  ),
                ),
              ],
            ),
          ),
          AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOutCubic,
            decoration: BoxDecoration(
              color: isEnabled
                  ? AppColors.primary
                  : Color.alphaBlend(
                      AppColors.primary.withValues(alpha: 0.08),
                      AppColors.nightRaised,
                    ),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: isEnabled
                    ? AppColors.primary
                    : AppColors.primary.withValues(alpha: 0.7),
                width: 1.5,
              ),
              boxShadow: isEnabled
                  ? [
                      BoxShadow(
                        color: AppColors.primary.withValues(alpha: 0.45),
                        blurRadius: 16,
                        spreadRadius: 1,
                        offset: const Offset(0, 3),
                      ),
                    ]
                  : null,
            ),
            child: TextButton(
              onPressed: onPressed,
              style: TextButton.styleFrom(
                backgroundColor: Colors.transparent,
                foregroundColor: isEnabled
                    ? AppColors.onNightAccent
                    : AppColors.nightBody,
                disabledBackgroundColor: Colors.transparent,
                disabledForegroundColor: AppColors.nightBody,
                minimumSize: const Size.fromHeight(52),
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 14,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
                elevation: 0,
                textStyle: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.3,
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Flexible(
                    child: Text(
                      label,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.3,
                        color: isEnabled
                            ? AppColors.onNightAccent
                            : AppColors.nightBody,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Icon(
                    icon,
                    size: 20,
                    color: isEnabled
                        ? AppColors.onNightAccent
                        : AppColors.primary,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PlanChoices extends StatelessWidget {
  const _PlanChoices({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        const gap = 8.0;
        final scale = MediaQuery.textScalerOf(context).scale(14) / 14;
        final columns = ((constraints.maxWidth + gap) / (96 * scale + gap))
            .floor()
            .clamp(1, 3);
        final width = (constraints.maxWidth - gap * (columns - 1)) / columns;
        return Wrap(
          spacing: gap,
          runSpacing: gap,
          children: [
            for (final child in children) SizedBox(width: width, child: child),
          ],
        );
      },
    );
  }
}

class _PlanOption extends StatelessWidget {
  const _PlanOption({
    required this.title,
    required this.selected,
    required this.onTap,
    this.subtitle,
    this.icon,
  });

  final String title;
  final String? subtitle;
  final IconData? icon;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      selected: selected,
      button: true,
      child: Material(
        color: selected
            ? AppColors.primary.withValues(alpha: 0.12)
            : AppColors.nightCanvas,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: BorderSide(
            color: selected ? AppColors.primary : AppColors.line,
            width: selected ? 1.5 : 1,
          ),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 82),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    selected
                        ? Icons.check_circle
                        : icon ?? Icons.radio_button_unchecked,
                    size: 20,
                    color: selected ? AppColors.primary : AppColors.muted,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    context.tr(title),
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
                      color: selected ? AppColors.primary : AppColors.ink,
                    ),
                  ),
                  if (subtitle != null) ...[
                    const SizedBox(height: 4),
                    Text(
                      context.tr(subtitle!),
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 12,
                        height: 1.4,
                        color: AppColors.muted,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _PlanNotice extends StatelessWidget {
  const _PlanNotice({
    required this.icon,
    required this.title,
    required this.message,
    this.isError = false,
  });

  final IconData icon;
  final String title;
  final String message;
  final bool isError;

  @override
  Widget build(BuildContext context) {
    final foreground = isError ? const Color(0xFFFF8A80) : AppColors.primary;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isError
            ? const Color(0xFF2C1618)
            : AppColors.nightAccentContainer,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isError
              ? Colors.red.shade700.withValues(alpha: 0.6)
              : AppColors.primary.withValues(alpha: 0.35),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 21, color: foreground),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  context.tr(title),
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: foreground,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  context.tr(message),
                  style: TextStyle(
                    fontSize: 13,
                    height: 1.5,
                    color: isError ? const Color(0xFFFFCDD2) : AppColors.muted,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _PlanInlineNote extends StatelessWidget {
  const _PlanInlineNote({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 18, color: AppColors.primary),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            context.tr(text),
            style: const TextStyle(
              fontSize: 13,
              height: 1.5,
              color: AppColors.muted,
            ),
          ),
        ),
      ],
    );
  }
}

class _PlanLabel extends StatelessWidget {
  const _PlanLabel(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      context.tr(text),
      style: const TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.w700,
        color: AppColors.ink,
      ),
    );
  }
}

class _PlanFieldError extends StatelessWidget {
  const _PlanFieldError(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Text(
        context.tr(text),
        style: TextStyle(fontSize: 13, color: Colors.red.shade700),
      ),
    );
  }
}
