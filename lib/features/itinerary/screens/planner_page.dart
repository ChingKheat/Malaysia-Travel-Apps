import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:smart_travel_planner/features/profile/services/profile_preferences_service.dart';
import 'package:smart_travel_planner/features/places/services/google_places_service.dart';
import 'package:smart_travel_planner/features/places/utils/attraction_image_resolver.dart';
import 'package:smart_travel_planner/shared/models/attraction.dart';
import 'package:smart_travel_planner/l10n/localized_labels.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';

import 'package:smart_travel_planner/core/theme/app_colors.dart';
import 'package:smart_travel_planner/shared/utils/demo_feedback.dart';
import 'package:smart_travel_planner/shared/data/malaysia_states.dart';
import 'package:smart_travel_planner/features/itinerary/models/destination_leg.dart';
import 'package:smart_travel_planner/features/itinerary/models/trip_preferences.dart';
import 'package:smart_travel_planner/features/itinerary/services/smart_itinerary_service.dart';
import 'package:smart_travel_planner/features/itinerary/services/supabase_itinerary_service.dart';
import 'package:smart_travel_planner/features/itinerary/services/transfer_manager.dart';
import 'package:smart_travel_planner/features/itinerary/services/trip_preferences_service.dart';
import 'package:smart_travel_planner/features/itinerary/widgets/modern_date_range_picker.dart';
import 'package:smart_travel_planner/features/itinerary/widgets/multi_destination_picker_sheet.dart';
import 'package:smart_travel_planner/features/home/models/spotlight_destination.dart';
import 'itinerary_page.dart';
import 'trip_selection_screen.dart';
import 'package:smart_travel_planner/features/places/data/curated_attractions.dart';
import 'package:smart_travel_planner/shared/models/travel_stop.dart';
import 'package:smart_travel_planner/features/itinerary/services/scan_plan_places_store.dart';
import 'package:smart_travel_planner/features/places/services/place_wishlist_store.dart';
import 'package:url_launcher/url_launcher.dart';

enum _LocationStatus { idle, locating, unavailable }

class _DepartureSearch extends SearchDelegate<TravelStop?> {
  _DepartureSearch(
    this.options,
    this.destination, {
    this.excluded = const {},
    this.forStartingPoint = false,
    GooglePlacesService? places,
  }) : _places = places ?? GooglePlacesService();

  final List<TravelStop> options;
  final String? destination;
  final Set<String> excluded;
  final bool forStartingPoint;
  final GooglePlacesService _places;
  static final _curatedById = {
    for (final place in curatedMalaysianAttractions) place.xid: place,
  };
  String? _requestedQuery;
  Future<List<TravelStop>>? _pendingResults;
  int _suggestionVersion = 0;
  final _locationStatus = ValueNotifier(_LocationStatus.idle);

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
      if (forStartingPoint &&
          !GooglePlacesService.addressMatchesState(
            place['formattedAddress'],
            state,
          )) {
        continue;
      }
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
      _pendingResults = forStartingPoint
          ? _searchAfterPause(context, term, state)
          : _search(term, state);
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

  Future<List<TravelStop>> _searchAfterPause(
    BuildContext context,
    String term,
    String state,
  ) async {
    final route = ModalRoute.of(context);
    final version = ++_suggestionVersion;
    await Future<void>.delayed(const Duration(milliseconds: 500));
    if (version != _suggestionVersion ||
        route?.isActive != true ||
        query.trim() != term) {
      return [];
    }
    return _search(term, state);
  }

  List<TravelStop> get _localResults => options
      .where(
        (place) =>
            place.title.toLowerCase().contains(query.trim().toLowerCase()),
      )
      .toList();

  @override
  Widget buildSuggestions(BuildContext context) {
    final canSearch = query.trim().length >= 2 && destination != null;
    if (forStartingPoint) {
      if (canSearch) return buildResults(context);
      if (_requestedQuery != null) {
        _requestedQuery = null;
        _pendingResults = null;
        _suggestionVersion++;
      }
    }
    return _resultsList(context, _localResults, searchOnline: canSearch);
  }

  Future<void> _addManualOrigin(BuildContext context) async {
    final l = context.l10n;
    final formKey = GlobalKey<FormState>();
    final initialName = query.trim();
    late String name;
    late (double, double) coordinates;
    final origin = await showDialog<TravelStop>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(l.planAddManualOrigin),
        scrollable: true,
        content: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(l.planManualOriginHelp),
              const SizedBox(height: 16),
              TextFormField(
                initialValue: initialName,
                textInputAction: TextInputAction.next,
                textCapitalization: TextCapitalization.words,
                decoration: InputDecoration(
                  labelText: l.planManualOriginName,
                  errorMaxLines: 3,
                ),
                validator: (value) => (value ?? '').trim().isEmpty
                    ? l.planManualOriginNameRequired
                    : null,
                onSaved: (value) => name = value!.trim(),
              ),
              const SizedBox(height: 12),
              TextFormField(
                decoration: InputDecoration(
                  labelText: l.planManualOriginCoordinates,
                  hintText: '3.1579, 101.7123',
                  errorMaxLines: 3,
                ),
                autocorrect: false,
                enableSuggestions: false,
                validator: (value) => _parseCoordinates(value) == null
                    ? l.planManualOriginInvalidCoordinates
                    : null,
                onSaved: (value) => coordinates = _parseCoordinates(value)!,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: Text(l.cancel),
          ),
          FilledButton(
            onPressed: () {
              final form = formKey.currentState!;
              if (!form.validate()) return;
              form.save();
              Navigator.of(
                dialogContext,
              ).pop(_location((name, coordinates.$1, coordinates.$2)));
            },
            child: Text(l.save),
          ),
        ],
      ),
    );
    if (context.mounted && origin != null) close(context, origin);
  }

  Future<TravelStop?> _currentOrigin(String title) async {
    try {
      if (!await Geolocator.isLocationServiceEnabled()) return null;
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        return null;
      }
      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          timeLimit: Duration(seconds: 10),
        ),
      );
      final coordinates = _validCoordinates(
        position.latitude,
        position.longitude,
      );
      return coordinates == null
          ? null
          : _location((title, coordinates.$1, coordinates.$2));
    } catch (_) {
      return null;
    }
  }

  Future<void> _chooseCurrentLocation(BuildContext context) async {
    if (_locationStatus.value == _LocationStatus.locating) return;
    final route = ModalRoute.of(context);
    final navigationContext = Navigator.of(context).context;
    _locationStatus.value = _LocationStatus.locating;
    final point = await _currentOrigin(context.l10n.planCurrentLocation);
    _locationStatus.value = point == null
        ? _LocationStatus.unavailable
        : _LocationStatus.idle;
    if (point != null &&
        navigationContext.mounted &&
        route?.isCurrent == true) {
      close(navigationContext, point);
    }
  }

  Widget _currentLocationTile() => ValueListenableBuilder(
    valueListenable: _locationStatus,
    builder: (context, status, _) {
      final l = context.l10n;
      final locating = status == _LocationStatus.locating;
      return ListTile(
        leading: locating
            ? const SizedBox.square(
                dimension: 24,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : const Icon(Icons.my_location),
        title: Text(l.planUseCurrentLocation),
        subtitle: status == _LocationStatus.unavailable
            ? Text(l.planCurrentLocationUnavailable)
            : null,
        enabled: !locating,
        onTap: locating ? null : () => _chooseCurrentLocation(context),
      );
    },
  );

  (double, double)? _parseCoordinates(String? input) {
    final parts = input?.split(',');
    if (parts == null || parts.length != 2) return null;
    return _validCoordinates(
      double.tryParse(parts.first),
      double.tryParse(parts.last),
    );
  }

  (double, double)? _validCoordinates(double? latitude, double? longitude) {
    // The trip planner uses zero coordinates to indicate a missing location.
    if (latitude == null ||
        longitude == null ||
        !latitude.isFinite ||
        !longitude.isFinite ||
        latitude == 0 ||
        longitude == 0 ||
        latitude.abs() > 90 ||
        longitude.abs() > 180) {
      return null;
    }
    return (latitude, longitude);
  }

  Widget _resultsList(
    BuildContext context,
    List<TravelStop> stops, {
    bool searchOnline = false,
    bool loading = false,
  }) {
    final seen = <String>{};
    return ListView(
      children: [
        if (forStartingPoint) _currentLocationTile(),
        if (searchOnline)
          ListTile(
            leading: const Icon(Icons.public),
            title: Text(context.l10n.planSearchOnline),
            onTap: () => showResults(context),
          ),
        if (loading) const LinearProgressIndicator(),
        for (final stop in stops)
          if (seen.add(stop.title.toLowerCase())) _placeResult(context, stop),
        if (stops.isEmpty && !loading && !searchOnline)
          ListTile(title: Text(context.l10n.planNoPlaces)),
        if (forStartingPoint)
          ListTile(
            leading: const Icon(Icons.add_location_alt_outlined),
            title: Text(context.l10n.planAddManualOrigin),
            onTap: () => _addManualOrigin(context),
          ),
      ],
    );
  }

  Widget _placeResult(BuildContext context, TravelStop stop) {
    final attraction = _curatedById[stop.placeId];
    final asset = attraction == null
        ? null
        : AttractionImageResolver.resolveAsset(attraction);
    final credit = asset != null && attraction != null
        ? AttractionImageResolver.photoCredit(attraction)
        : null;
    const placeholder = ColoredBox(
      color: AppColors.nightRaised,
      child: Center(child: Icon(Icons.place_outlined, color: AppColors.muted)),
    );
    return ListTile(
      minTileHeight: 72,
      leading: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: SizedBox.square(
          dimension: 56,
          child: asset == null
              ? placeholder
              : Image.asset(
                  asset,
                  fit: BoxFit.cover,
                  cacheWidth: (56 * MediaQuery.devicePixelRatioOf(context))
                      .round(),
                  excludeFromSemantics: true,
                  errorBuilder: (_, _, _) => placeholder,
                ),
        ),
      ),
      title: Text(stop.title),
      subtitle: credit != null
          ? Text(
              '© ${credit.author} · ${credit.license}',
              style: Theme.of(context).textTheme.bodySmall,
            )
          : stop.isGooglePlace
          ? Text(stop.note)
          : null,
      trailing: credit == null
          ? null
          : IconButton(
              tooltip: context.l10n.source,
              icon: const Icon(Icons.info_outline),
              onPressed: () => launchUrl(Uri.parse(credit.source)),
            ),
      onTap: () => close(context, stop),
    );
  }
}

TravelStop _location((String, double, double) point) => TravelStop.fromJson({
  'title': point.$1,
  'latitude': point.$2,
  'longitude': point.$3,
  'opening_hours': 'Hours unverified',
});

enum _PlannerGroup { basics, who, dining, highlights }

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
    this.onContinueExisting,
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
    @visibleForTesting this.startingPointPlaces,
    this.isVisible = true,
    @visibleForTesting this.promptOnLaunch = false,
    this.pendingSpotlightRequest,
    this.onSpotlightRequestHandled,
  });

  final VoidCallback onItineraryReady;
  final VoidCallback? onMyTripsTap;
  final VoidCallback? onContinueExisting;
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
  final GooglePlacesService? startingPointPlaces;
  final bool isVisible;
  final bool promptOnLaunch;
  final SpotlightPlannerRequest? pendingSpotlightRequest;
  final ValueChanged<int>? onSpotlightRequestHandled;

  @override
  State<PlannerPage> createState() => _PlannerPageState();
}

class _PlannerPageState extends State<PlannerPage> {
  // Trip Preference Form State variables
  String? destination;
  PlanningMode _planningMode = PlanningMode.singleDestination;
  List<DestinationLeg> _legs = [];
  bool _autoOptimizeRouteOrder = true;
  DateTimeRange? travelDates;
  TimeOfDay? dailyStartTime;
  TimeOfDay? dailyEndTime;
  final Set<String> interests = <String>{};
  String budgetCategory = '';
  String travelMode = '';
  String _transitMinutesInput = '';
  int? get _transitPlanningMinutes {
    final minutes = int.tryParse(_transitMinutesInput.trim(), radix: 10);
    return minutes != null && minutes >= 1 && minutes <= 240 ? minutes : null;
  }

  TravelStop? _departurePoint;
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

  static const _klOrigins = [
    ('Bukit Bintang', 3.1468, 101.7113),
    ('KLCC', 3.1579, 101.7123),
    ('KL Sentral', 3.1341, 101.6862),
  ];

  Future<void> _chooseStartingPoint() async {
    final state = destination;
    final point = await showSearch<TravelStop?>(
      context: context,
      delegate: _DepartureSearch(
        [
          if (state == 'Kuala Lumpur') ..._klOrigins.map(_location),
          if (state != null)
            ...curatedAttractionsForState(state).map(_highlight),
        ],
        state,
        forStartingPoint: true,
        places: widget.startingPointPlaces,
      ),
    );
    if (mounted && point != null) {
      setState(() => _departurePoint = point);
    }
  }

  TravelStop _highlight(Attraction place) => TravelStop.fromJson({
    ..._location((place.name, place.latitude, place.longitude)).toJson(),
    'place_id': place.googlePlaceId ?? place.xid,
    'category': place.category,
    'is_indoor': place.isIndoor,
    'operating_hours': place.operatingHours ?? const <String, dynamic>{},
    'data_source': place.googlePlaceId == null ? 'local' : 'google',
  });

  List<TravelStop> get _selectedScanPlaces {
    final seenNames = <String>{};
    return [
      for (final place in _scanPlanPlaces.places)
        TravelStop(
          title: place.name,
          time: '',
          note: place.category,
          description: place.description ?? '',
          duration: '90 min',
          openingHours: 'Hours unverified',
          operatingHours: place.operatingHours ?? const {},
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

  Future<List<Attraction>> _loadSavedPlaces() async {
    final seen = <String>{};
    final result = <Attraction>[];

    try {
      final wishlist = await PlaceWishlistStore(widget.userId).load();
      for (final p in wishlist) {
        final key = p.xid.isNotEmpty ? p.xid : p.name.trim().toLowerCase();
        if (seen.add(key)) {
          result.add(p);
        }
      }
    } catch (_) {}

    for (final p in _scanPlanPlaces.places) {
      final key = p.xid.isNotEmpty ? p.xid : p.name.trim().toLowerCase();
      if (seen.add(key)) {
        result.add(p);
      }
    }

    return result;
  }

  Future<void> _chooseFromSavedPlaces() async {
    if (_mustVisit.length >= 3) return;
    final savedPlaces = await _loadSavedPlaces();
    if (!mounted) return;

    if (savedPlaces.isEmpty) {
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(context.l10n.noSavedPlacesToApply),
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 3),
        ),
      );
      return;
    }

    final remaining = 3 - _mustVisit.length;
    final selectedToAdd = await showModalBottomSheet<List<Attraction>>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _SavedPlacesSelectionSheet(
        savedPlaces: savedPlaces,
        alreadyAddedIds: {
          for (final stop in _mustVisit) ...[
            if (stop.placeId != null) stop.placeId!,
            stop.title.trim().toLowerCase(),
          ],
          for (final place in _scanPlanPlaces.places) ...[
            if (place.xid.isNotEmpty) place.xid,
            if (place.googlePlaceId != null && place.googlePlaceId!.isNotEmpty)
              place.googlePlaceId!,
            place.name.trim().toLowerCase(),
          ],
        },
        remainingSlots: remaining,
        destination: destination,
      ),
    );

    if (!mounted || selectedToAdd == null || selectedToAdd.isEmpty) return;

    setState(() {
      for (final place in selectedToAdd) {
        if (_mustVisit.length < 3) {
          _mustVisit.add(_highlight(place));
        }
      }
    });

    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(context.l10n.savedPlacesApplied),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 2),
      ),
    );
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
  bool _hasPromptedPreviousSelection = false;
  bool _isCheckingPreviousSelection = false;
  bool _isCurrentPlanSaved = false;
  int _lastKnownSaveRevision = 0;
  bool _hasUserEditedDraft = false;
  bool _hubSelectedExplicitly = false;
  Future<void>? _draftLoadFuture;
  int? _handledSpotlightRequestId;
  bool _isResolvingSpotlightRequest = false;
  bool get _hasPreviousSelection =>
      destination != null || _legs.isNotEmpty || travelDates != null;
  bool get _hasEditableDraft =>
      _hasUserEditedDraft ||
      destination != null ||
      _legs.isNotEmpty ||
      travelDates != null ||
      _destinationConfirmed ||
      _datesConfirmed ||
      _mustVisit.isNotEmpty ||
      _departurePoint != null ||
      interests.isNotEmpty;
  bool get _hasHubDayConflict =>
      _planningMode == PlanningMode.multiDestination &&
      travelDates != null &&
      _calculatedDays > 0 &&
      _legs.length > _calculatedDays;
  String get _visibleDestinationLabel {
    if (destination == null) return '';
    if (_hubSelectedExplicitly &&
        _planningMode == PlanningMode.singleDestination &&
        _legs.length == 1) {
      final leg = _legs.first;
      if (leg.hubName.toLowerCase() != leg.stateName.toLowerCase()) {
        return '${leg.hubName}, ${leg.stateName}';
      }
      return leg.hubName;
    }
    return destination!;
  }

  PlanStep _activeStep = PlanStep.travelDates;
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
          alignment: 0.0,
          alignmentPolicy: ScrollPositionAlignmentPolicy.explicit,
        );
      }
    });
  }

  @override
  void dispose() {
    _scanPlanPlaces.removeListener(_onScanPlanPlacesChanged);
    ProfilePreferencesService.instance.removeListener(_loadProfileDefaults);
    SupabaseItineraryService().removeListener(_onItineraryRepositoryChanged);
    _scrollController.dispose();
    super.dispose();
  }

  void _onItineraryRepositoryChanged() {
    final currentRevision =
        SupabaseItineraryService().plannerDraftClearedRevision;
    if (currentRevision != _lastKnownSaveRevision) {
      _lastKnownSaveRevision = currentRevision;
      _isCurrentPlanSaved = true;
      _hasPromptedPreviousSelection = true;
    }
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
    _scanPlanPlaces.load().then((_) {
      if (mounted) _applyScanPlaceDefaults();
    });
    _lastKnownSaveRevision =
        SupabaseItineraryService().plannerDraftClearedRevision;
    SupabaseItineraryService().addListener(_onItineraryRepositoryChanged);
    _testingForm = widget.enableTestingBypass;
    if (!_testingForm) {
      ProfilePreferencesService.instance.addListener(_loadProfileDefaults);
      _loadProfileDefaults();
      _draftLoadFuture = _loadDraftIfAvailable();
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

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (widget.isVisible && widget.pendingSpotlightRequest != null) {
        _resolvePendingSpotlightRequest();
      } else if (widget.promptOnLaunch) {
        _checkAndPromptPreviousSelection();
      }
    });
  }

  @override
  void didUpdateWidget(PlannerPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    final hasNewSpotlight =
        widget.pendingSpotlightRequest != null &&
        widget.pendingSpotlightRequest!.id != _handledSpotlightRequestId &&
        widget.pendingSpotlightRequest!.id !=
            oldWidget.pendingSpotlightRequest?.id;
    final becameVisible = widget.isVisible && !oldWidget.isVisible;
    if (widget.isVisible && (hasNewSpotlight || becameVisible)) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        if (widget.pendingSpotlightRequest != null &&
            widget.pendingSpotlightRequest!.id != _handledSpotlightRequestId) {
          _resolvePendingSpotlightRequest();
        } else if (becameVisible && !_isResolvingSpotlightRequest) {
          _checkAndPromptPreviousSelection();
        }
      });
    }
  }

  bool _scanAutoFilled = false;

  void _onScanPlanPlacesChanged() {
    if (!mounted) return;
    _applyScanPlaceDefaults();
    setState(() {});
  }

  void _applyScanPlaceDefaults() {
    if (_testingForm ||
        _scanPlanPlaces.places.isEmpty ||
        widget.pendingSpotlightRequest != null) {
      return;
    }
    if (widget.initialDestination != null || widget.initialInterests != null) {
      return;
    }

    var changed = false;

    if (destination == null && !_hasUserEditedDraft) {
      final stateCounts = <String, int>{};
      for (final place in _scanPlanPlaces.places) {
        if (place.latitude == 0 && place.longitude == 0) continue;
        final state = nearestMalaysiaState(
          LatLng(place.latitude, place.longitude),
        );
        stateCounts[state] = (stateCounts[state] ?? 0) + 1;
      }
      if (stateCounts.isNotEmpty) {
        final topState = stateCounts.entries
            .reduce((a, b) => a.value >= b.value ? a : b)
            .key;
        destination = topState;
        _planningMode = PlanningMode.singleDestination;
        _legs = [DestinationLeg.fromStateName(topState)];
        _destinationConfirmed = true;
        _scanAutoFilled = true;
        if (_activeStep == PlanStep.destination) {
          _activeStep = travelDates == null
              ? PlanStep.travelDates
              : PlanStep.tripLogistics;
        }
        changed = true;
      }
    }

    if (interests.isEmpty && !_hasUserEditedDraft) {
      final inferred = _inferInterestsFromScanPlaces(_scanPlanPlaces.places);
      if (inferred.isNotEmpty) {
        interests.addAll(inferred);
        _interestsConfirmed = true;
        _scanAutoFilled = true;
        changed = true;
      }
    }

    if (changed && mounted) {
      setState(() {});
    }
  }

  Set<String> _inferInterestsFromScanPlaces(List<Attraction> places) {
    final result = <String>{};
    for (final place in places) {
      final text =
          '${place.category} ${place.description ?? ''} ${place.name}'
              .toLowerCase();
      if (text.contains('food') ||
          text.contains('restaurant') ||
          text.contains('cafe') ||
          text.contains('street food') ||
          text.contains('dining')) {
        result.add('Food');
      }
      if (text.contains('park') ||
          text.contains('nature') ||
          text.contains('garden') ||
          text.contains('beach') ||
          text.contains('island') ||
          text.contains('waterfall') ||
          text.contains('lake')) {
        result.add('Nature');
      }
      if (text.contains('shop') ||
          text.contains('mall') ||
          text.contains('market') ||
          text.contains('bazaar')) {
        result.add('Shopping');
      }
      if (text.contains('history') ||
          text.contains('heritage') ||
          text.contains('museum') ||
          text.contains('mosque') ||
          text.contains('temple') ||
          text.contains('church') ||
          text.contains('fort') ||
          text.contains('palace')) {
        result.add('History');
      }
      if (text.contains('adventure') ||
          text.contains('hike') ||
          text.contains('cave') ||
          text.contains('theme park') ||
          text.contains('hill')) {
        result.add('Adventure');
      }
      if (text.contains('family') ||
          text.contains('aquarium') ||
          text.contains('zoo')) {
        result.add('Family');
      }
      if (text.contains('night') || text.contains('bar')) {
        result.add('Nightlife');
      }
      if (text.contains('sight') ||
          text.contains('landmark') ||
          text.contains('architecture') ||
          text.contains('tower') ||
          text.contains('bridge') ||
          text.contains('culture') ||
          text.contains('attraction')) {
        result.add('Culture');
      }
    }
    if (result.isEmpty) {
      result.add('Culture');
    }
    return result;
  }

  Widget _buildScanPlanPlacesCard({bool compact = false}) {
    final places = _scanPlanPlaces.places;
    final l = context.l10n;
    return Container(
      key: const ValueKey('planner-scan-places-card'),
      padding: EdgeInsets.all(compact ? 12 : 16),
      decoration: BoxDecoration(
        color: AppColors.nightSurface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.photo_camera_outlined,
                size: 18,
                color: AppColors.primary,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  l.scanPlanPlaces,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: AppColors.ink,
                  ),
                ),
              ),
              if (places.length > 1)
                TextButton(
                  onPressed: () {
                    setState(() => _scanAutoFilled = false);
                    _scanPlanPlaces.clear();
                  },
                  style: TextButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                    foregroundColor: AppColors.muted,
                  ),
                  child: Text(l.clear),
                ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            '${places.length == 1 ? l.scanPlanOnePlace : l.valuePlaces(places.length.toString())} · ${l.selectedPlacesHelp}',
            style: const TextStyle(fontSize: 12, color: AppColors.muted),
          ),
          if (_scanAutoFilled && !compact) ...[
            const SizedBox(height: 6),
            Text(
              l.scanPlacesAutoFilled,
              style: const TextStyle(
                fontSize: 12,
                color: AppColors.primary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
          const SizedBox(height: 8),
          for (final place in places)
            ListTile(
              key: ValueKey('plan-scan-place-${place.xid}'),
              dense: compact,
              contentPadding: EdgeInsets.zero,
              leading: const Icon(
                Icons.place_outlined,
                color: AppColors.primary,
              ),
              title: Text(
                place.name,
                style: const TextStyle(
                  fontWeight: FontWeight.w600,
                  color: AppColors.ink,
                ),
              ),
              subtitle: Text(
                place.category,
                style: const TextStyle(fontSize: 12, color: AppColors.muted),
              ),
              trailing: IconButton(
                tooltip: l.removeStop,
                onPressed: () => _scanPlanPlaces.remove(place.xid),
                icon: const Icon(Icons.close, size: 18),
              ),
            ),
        ],
      ),
    );
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

  Future<void> _loadDraftIfAvailable() async {
    if (widget.enableTestingBypass) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString('planner_draft_v1_${widget.userId}');
      if (raw == null || !mounted) return;
      final data = jsonDecode(raw) as Map<String, dynamic>;
      final draftDest = data['destination'] as String?;
      final draftLegs = data['legs'] is List
          ? (data['legs'] as List)
                .whereType<Map>()
                .map(
                  (m) => DestinationLeg.fromJson(Map<String, dynamic>.from(m)),
                )
                .toList()
          : <DestinationLeg>[];
      final draftMode =
          PlanningMode.values
              .where((m) => m.name == data['planningMode'])
              .firstOrNull ??
          (draftLegs.length > 1
              ? PlanningMode.multiDestination
              : PlanningMode.singleDestination);
      DateTimeRange? draftDates;
      if (data['startDate'] != null && data['endDate'] != null) {
        final start = DateTime.tryParse(data['startDate'] as String);
        final end = DateTime.tryParse(data['endDate'] as String);
        if (start != null && end != null) {
          draftDates = DateTimeRange(start: start, end: end);
        }
      }
      if (draftDest != null || draftDates != null || draftLegs.isNotEmpty) {
        if (destination == null && travelDates == null && _legs.isEmpty) {
          setState(() {
            destination = draftDest;
            _legs = draftLegs;
            _planningMode = draftMode;
            _autoOptimizeRouteOrder = data['autoOptimizeRouteOrder'] != false;
            travelDates = draftDates;
            _destinationConfirmed =
                data['destinationConfirmed'] == true ||
                draftDest != null ||
                draftLegs.isNotEmpty;
            _datesConfirmed = data['datesConfirmed'] == true;
            _hubSelectedExplicitly = data['hubSelectedExplicitly'] == true;
            _hasUserEditedDraft = true;
            if (data['travelMode'] is String) {
              travelMode = data['travelMode'] as String;
            }
            if (data['budgetCategory'] is String) {
              budgetCategory = data['budgetCategory'] as String;
            }
            if (data['interests'] is List) {
              interests.addAll((data['interests'] as List).cast<String>());
            }
            _activeStep = destination == null
                ? PlanStep.destination
                : travelDates == null
                ? PlanStep.travelDates
                : PlanStep.tripLogistics;
          });
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!mounted) return;
            if ((widget.isVisible || widget.promptOnLaunch) &&
                widget.pendingSpotlightRequest == null &&
                !_isResolvingSpotlightRequest) {
              _checkAndPromptPreviousSelection();
            }
          });
        }
      }
    } catch (_) {}
  }

  Future<void> _saveDraft() async {
    if (widget.enableTestingBypass) return;
    if (_isCurrentPlanSaved) {
      _isCurrentPlanSaved = false;
      _hasPromptedPreviousSelection = false;
    }
    try {
      final prefs = await SharedPreferences.getInstance();
      final key = 'planner_draft_v1_${widget.userId}';
      if (!_hasPreviousSelection) {
        await prefs.remove(key);
        return;
      }
      final data = {
        'destination': destination,
        'planningMode': _planningMode.name,
        'legs': _legs.map((l) => l.toJson()).toList(),
        'autoOptimizeRouteOrder': _autoOptimizeRouteOrder,
        'startDate': travelDates?.start.toIso8601String(),
        'endDate': travelDates?.end.toIso8601String(),
        'travelMode': travelMode,
        'budgetCategory': budgetCategory,
        'interests': interests.toList(),
        'destinationConfirmed': _destinationConfirmed,
        'datesConfirmed': _datesConfirmed,
        'hubSelectedExplicitly': _hubSelectedExplicitly,
      };
      await prefs.setString(key, jsonEncode(data));
    } catch (_) {}
  }

  Future<void> _resolvePendingSpotlightRequest() async {
    final initialRequest = widget.pendingSpotlightRequest;
    if (!mounted ||
        initialRequest == null ||
        initialRequest.id == _handledSpotlightRequestId ||
        _isResolvingSpotlightRequest) {
      return;
    }
    _isResolvingSpotlightRequest = true;
    try {
      await (_draftLoadFuture ?? Future<void>.value());
      if (!mounted) return;
      final request = widget.pendingSpotlightRequest;
      if (request == null || request.id == _handledSpotlightRequestId) return;

      if (_hasEditableDraft) {
        final summary = _visibleDestinationLabel.isNotEmpty
            ? _visibleDestinationLabel
            : (travelDates != null
                  ? _travelDateLabel
                  : context.l10n.destination);
        final replaceDraft = await showDialog<bool>(
          context: context,
          barrierDismissible: true,
          builder: (dialogContext) => AlertDialog(
            backgroundColor: AppColors.nightSurface,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
              side: const BorderSide(color: AppColors.line),
            ),
            title: Text(
              context.l10n.spotlightDraftConflictTitle,
              style: const TextStyle(
                color: AppColors.ink,
                fontWeight: FontWeight.w700,
                fontSize: 18,
              ),
            ),
            content: Text(
              context.l10n.spotlightDraftConflictMessage(summary),
              style: const TextStyle(
                color: AppColors.muted,
                fontSize: 14,
                height: 1.5,
              ),
            ),
            actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            actions: [
              OutlinedButton(
                key: const ValueKey('spotlight-keep-draft-btn'),
                onPressed: () => Navigator.of(dialogContext).pop(false),
                child: Text(context.l10n.spotlightKeepCurrentDraft),
              ),
              FilledButton(
                key: const ValueKey('spotlight-new-draft-btn'),
                onPressed: () => Navigator.of(dialogContext).pop(true),
                child: Text(context.l10n.spotlightStartNewDraft),
              ),
            ],
          ),
        );
        if (!mounted) return;
        _handledSpotlightRequestId = request.id;
        _hasPromptedPreviousSelection = true;
        widget.onSpotlightRequestHandled?.call(request.id);
        if (replaceDraft == true) {
          _applySpotlightDestinations(
            request.destinations,
            resetExistingDraft: true,
          );
        }
      } else {
        _handledSpotlightRequestId = request.id;
        _hasPromptedPreviousSelection = true;
        widget.onSpotlightRequestHandled?.call(request.id);
        _applySpotlightDestinations(
          request.destinations,
          resetExistingDraft: false,
        );
      }
    } finally {
      _isResolvingSpotlightRequest = false;
    }
  }

  void _applySpotlightDestinations(
    List<SpotlightDestination> selected, {
    required bool resetExistingDraft,
  }) {
    final seenIds = <String>{};
    final unique = [
      for (final item in selected)
        if (seenIds.add(item.id)) item,
    ];
    if (unique.isEmpty) return;

    setState(() {
      if (resetExistingDraft) {
        travelDates = null;
        _datesConfirmed = false;
        _departurePoint = null;
        _mustVisit.clear();
        interests.clear();
        _logisticsConfirmed = false;
        _travelersConfirmed = false;
        _paceConfirmed = false;
        _budgetConfirmed = false;
        _modeConfirmed = false;
        _interestsConfirmed = false;
        _errorMessage = null;
        _highlightedEmptyFields.clear();
      }

      if (unique.length == 1) {
        final picked = unique.first;
        final days = (travelDates != null && _calculatedDays > 0)
            ? _calculatedDays.clamp(1, 30)
            : 3;
        _planningMode = PlanningMode.singleDestination;
        _legs = [picked.toDestinationLeg(allocatedDays: days, sequence: 1)];
        destination = picked.stateName;
        _hubSelectedExplicitly = true;
      } else {
        final rawLegs = [
          for (int i = 0; i < unique.length; i++)
            unique[i].toDestinationLeg(allocatedDays: 1, sequence: i + 1),
        ];
        final ordered = TransferManager.optimizeLegOrder(rawLegs);
        _legs =
            (travelDates != null &&
                _calculatedDays > 0 &&
                ordered.length <= _calculatedDays)
            ? TransferManager.autoDistributeDays(ordered, _calculatedDays)
            : ordered;
        _planningMode = PlanningMode.multiDestination;
        _autoOptimizeRouteOrder = true;
        _hubSelectedExplicitly = true;
        destination = TripPreferences(
          planningMode: PlanningMode.multiDestination,
          legs: _legs,
        ).effectiveDestinationLabel;
      }

      _destinationConfirmed = true;
      _hasUserEditedDraft = true;
      _isCurrentPlanSaved = false;
      _hasPromptedPreviousSelection = true;
      _errorMessage = null;
      _highlightedEmptyFields.remove('destination');
      _activeStep = travelDates == null
          ? PlanStep.travelDates
          : PlanStep.tripLogistics;
    });
    _saveDraft();
  }

  void _removeMultiCityLeg(int index) {
    if (index < 0 || index >= _legs.length) return;
    setState(() {
      final remaining = List<DestinationLeg>.from(_legs)..removeAt(index);
      if (remaining.length <= 1) {
        _planningMode = PlanningMode.singleDestination;
        if (remaining.isEmpty) {
          _legs = [];
          destination = null;
          _destinationConfirmed = false;
          _activeStep = PlanStep.destination;
        } else {
          final days = (travelDates != null && _calculatedDays > 0)
              ? _calculatedDays.clamp(1, 30)
              : 3;
          final single = remaining.first.copyWith(
            allocatedDays: days,
            sequence: 1,
          );
          _legs = [single];
          destination = single.stateName;
          _destinationConfirmed = true;
        }
      } else {
        final ordered = _autoOptimizeRouteOrder
            ? TransferManager.optimizeLegOrder(remaining)
            : [
                for (int i = 0; i < remaining.length; i++)
                  remaining[i].copyWith(sequence: i + 1),
              ];
        _legs =
            (travelDates != null &&
                _calculatedDays > 0 &&
                ordered.length <= _calculatedDays)
            ? TransferManager.autoDistributeDays(ordered, _calculatedDays)
            : ordered;
        _planningMode = PlanningMode.multiDestination;
        destination = TripPreferences(
          planningMode: PlanningMode.multiDestination,
          legs: _legs,
        ).effectiveDestinationLabel;
      }
      _hasUserEditedDraft = true;
      _errorMessage = null;
    });
    _saveDraft();
  }

  Future<void> _openMultiCityEditor() async {
    final totalDays = _datesConfirmed && _calculatedDays > 0
        ? _calculatedDays
        : (_legs.length >= 2 ? _legs.length : 7);
    final multiResult = await showModalBottomSheet<MultiDestinationResult>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (_) => MultiDestinationPickerSheet(
        totalDays: totalDays.clamp(2, 30),
        initialLegs: _legs.isNotEmpty
            ? _legs
            : (destination != null
                  ? [DestinationLeg.fromStateName(destination!)]
                  : const []),
        initialAutoOptimize: _autoOptimizeRouteOrder,
      ),
    );
    if (mounted && multiResult != null) {
      final tempPrefs = TripPreferences(
        planningMode: PlanningMode.multiDestination,
        legs: multiResult.legs,
      );
      setState(() {
        _planningMode = PlanningMode.multiDestination;
        _legs = multiResult.legs;
        _autoOptimizeRouteOrder = multiResult.autoOptimizeOrder;
        destination = tempPrefs.effectiveDestinationLabel;
        _destinationConfirmed = true;
        _hasUserEditedDraft = true;
        _departurePoint = null;
        _mustVisit.clear();
        _errorMessage = null;
        _highlightedEmptyFields.remove('destination');
        _activeStep = _datesConfirmed
            ? PlanStep.tripLogistics
            : PlanStep.travelDates;
      });
      _saveDraft();
    }
  }

  Future<void> _clearSavedDraft() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('planner_draft_v1_${widget.userId}');
    } catch (_) {}
  }

  Future<void> _checkAndPromptPreviousSelection() async {
    if (!mounted ||
        widget.enableTestingBypass ||
        (!widget.isVisible && !widget.promptOnLaunch) ||
        _isCheckingPreviousSelection ||
        _isCurrentPlanSaved ||
        _hasPromptedPreviousSelection ||
        _isResolvingSpotlightRequest ||
        widget.pendingSpotlightRequest != null) {
      return;
    }
    _isCheckingPreviousSelection = true;
    try {
      await (_draftLoadFuture ?? Future<void>.value());
      if (!mounted ||
          widget.enableTestingBypass ||
          (!widget.isVisible && !widget.promptOnLaunch) ||
          _isCurrentPlanSaved ||
          _hasPromptedPreviousSelection ||
          _isResolvingSpotlightRequest ||
          widget.pendingSpotlightRequest != null) {
        return;
      }
      if (!_hasPreviousSelection) return;

      _hasPromptedPreviousSelection = true;

      final destName = destination ?? context.l10n.destination;
      final datesSummary = travelDates != null ? ' ($_travelDateLabel)' : '';
      final fullSummary = '$destName$datesSummary';

      final shouldReset = await showDialog<bool>(
        context: context,
        barrierDismissible: true,
        builder: (dialogContext) => AlertDialog(
          backgroundColor: AppColors.nightSurface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
            side: const BorderSide(color: AppColors.line),
          ),
          icon: Container(
            width: 50,
            height: 50,
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.restore_outlined,
              color: AppColors.primary,
              size: 26,
            ),
          ),
          title: Text(
            context.l10n.planPreviousSelectionTitle,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: AppColors.ink,
              fontWeight: FontWeight.w700,
              fontSize: 18,
            ),
          ),
          content: Text(
            context.l10n.planPreviousSelectionMessage(fullSummary),
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: AppColors.muted,
              fontSize: 14,
              height: 1.5,
            ),
          ),
          actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          actionsAlignment: MainAxisAlignment.spaceBetween,
          actions: [
            OutlinedButton(
              key: const ValueKey('plan-prompt-redo-btn'),
              onPressed: () => Navigator.of(dialogContext).pop(true),
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.red.shade400,
                side: BorderSide(
                  color: Colors.red.shade400.withValues(alpha: 0.5),
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
              ),
              child: Text(
                context.l10n.planStartOver,
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
            ),
            FilledButton(
              key: const ValueKey('plan-prompt-continue-btn'),
              onPressed: () => Navigator.of(dialogContext).pop(false),
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: AppColors.nightCanvas,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 12,
                ),
              ),
              child: Text(
                context.l10n.planContinueExisting,
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
          ],
        ),
      );

      if (shouldReset == true && mounted) {
        _resetPlanToCleanSlate();
      } else if (shouldReset == false && mounted) {
        widget.onContinueExisting?.call();
      }
    } finally {
      _isCheckingPreviousSelection = false;
    }
  }

  Future<void> _confirmAndReset() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: AppColors.nightSurface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: const BorderSide(color: AppColors.line),
        ),
        title: Text(
          context.l10n.planStartOver,
          style: const TextStyle(
            color: AppColors.ink,
            fontWeight: FontWeight.w700,
          ),
        ),
        content: Text(
          context.l10n.planResetConfirmation,
          style: const TextStyle(color: AppColors.muted, fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(MaterialLocalizations.of(context).cancelButtonLabel),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Colors.red.shade700,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(context.l10n.planStartOver),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      _resetPlanToCleanSlate();
    }
  }

  void _resetPlanToCleanSlate() {
    setState(() {
      destination = null;
      _planningMode = PlanningMode.singleDestination;
      _legs = [];
      _autoOptimizeRouteOrder = true;
      _hasUserEditedDraft = false;
      _hubSelectedExplicitly = false;
      travelDates = null;
      _departurePoint = null;
      _mustVisit.clear();
      dailyStartTime = const TimeOfDay(hour: 8, minute: 0);
      dailyEndTime = const TimeOfDay(hour: 22, minute: 0);
      travelMode = 'Driving';
      _transitMinutesInput = '';
      budgetCategory = '';
      interests.clear();
      _travelerType = TravelerType.solo;
      _pace = PaceCategory.balanced;
      _diet = DietaryPreference.unrestricted;

      _destinationConfirmed = false;
      _datesConfirmed = false;
      _logisticsConfirmed = false;
      _travelersConfirmed = false;
      _paceConfirmed = false;
      _budgetConfirmed = false;
      _modeConfirmed = false;
      _interestsConfirmed = false;

      _activeStep = PlanStep.destination;
      _errorMessage = null;
      _highlightedEmptyFields.clear();
      _isCurrentPlanSaved = false;
      _hasPromptedPreviousSelection = false;
    });

    _clearSavedDraft();

    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(context.l10n.planResetSuccess),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 2),
      ),
    );
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
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
                  child: SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: () => Navigator.pop(context, '__MULTI_CITY__'),
                      icon: const Icon(Icons.route_outlined, size: 18),
                      label: const Text(
                        'Multi-City Tour (All States)',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
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
                          state,
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

    if (mounted && selected == '__MULTI_CITY__') {
      await _openMultiCityEditor();
      return;
    }

    if (mounted && selected != null) {
      setState(() {
        if (destination != selected ||
            _planningMode == PlanningMode.multiDestination) {
          _departurePoint = null;
          _mustVisit.clear();
        }
        _planningMode = PlanningMode.singleDestination;
        _legs = [
          DestinationLeg.fromStateName(
            selected,
            allocatedDays: _datesConfirmed ? _calculatedDays : 3,
          ),
        ];
        destination = selected;
        _destinationConfirmed = true;
        _hubSelectedExplicitly = false;
        _hasUserEditedDraft = true;
        _errorMessage = null;
        _highlightedEmptyFields.remove('destination');
        if (_datesConfirmed && _calculatedDays <= 30) {
          _activeStep = PlanStep.tripLogistics;
        } else {
          _activeStep = PlanStep.travelDates;
        }
      });
      _saveDraft();
    }
  }

  Future<void> _pickTravelDates() async {
    final now = DateTime.now();
    final firstDate = DateTime(now.year, now.month, now.day);
    final lastDate = now.add(const Duration(days: 365 * 2));
    final defaultRange =
        travelDates ??
        DateTimeRange(
          start: DateTime(now.year, now.month, now.day + 1),
          end: DateTime(now.year, now.month, now.day + 3),
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
      final pickedDays = picked.end.difference(picked.start).inDays + 1;
      setState(() {
        travelDates = picked;
        _datesConfirmed = true;
        _hasUserEditedDraft = true;
        _errorMessage = null;
        _highlightedEmptyFields.remove('numberOfDays');
        if (_planningMode == PlanningMode.multiDestination &&
            _legs.length >= 2 &&
            pickedDays >= _legs.length) {
          _legs = TransferManager.autoDistributeDays(_legs, pickedDays);
        }
        if (_destinationConfirmed &&
            _calculatedDays <= 30 &&
            !_hasHubDayConflict) {
          _activeStep = PlanStep.tripLogistics;
        } else {
          _activeStep = PlanStep.destination;
        }
      });
      _saveDraft();
    }
  }

  bool _isGenerating = false;

  Future<void> _handleGenerateItinerary() async {
    if (_isGenerating) return;
    if (_hasHubDayConflict) {
      setState(() {
        _errorMessage = context.l10n.plannerDurationConflictMessage(
          _legs.length,
          _calculatedDays,
        );
        _activeStep = PlanStep.destination;
      });
      _advanceToStep(PlanStep.destination);
      return;
    }
    if (_isGenerating) return;
    demoHaptic();
    setState(() {
      _errorMessage = null;
      _highlightedEmptyFields.clear();
    });

    final resolvedLegs =
        (_planningMode == PlanningMode.multiDestination &&
            _legs.isNotEmpty &&
            travelDates != null &&
            _legs.fold<int>(0, (s, l) => s + l.allocatedDays) !=
                _calculatedDays)
        ? TransferManager.autoDistributeDays(_legs, _calculatedDays)
        : _legs;

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
      arrivalTime: _arrival,
      departureTime: _departure,
      departureBufferMinutes: _airport ? 180 : 60,
      departureTransferMinutes: _airport && _departure != null
          ? _airportTransferMinutes
          : 0,
      travelerType: _travelerType,
      paceCategory: _selectedPace,
      dietaryPreference: _diet,
      mustVisitPlaces: List.unmodifiable([
        ..._mustVisit,
        for (final scanStop in _selectedScanPlaces)
          if (!_mustVisit.any(
            (m) =>
                (m.placeId != null && m.placeId == scanStop.placeId) ||
                m.title.trim().toLowerCase() ==
                    scanStop.title.trim().toLowerCase(),
          ))
            scanStop,
      ]),
      selectedPlaces: const [],
      secondaryTransportModes: const [],
      planningMode: _planningMode,
      legs: resolvedLegs,
      autoOptimizeRouteOrder: _autoOptimizeRouteOrder,
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
                  onPressed: () => Navigator.of(context).maybePop(),
                ),
              ],
            ),
            body: ItineraryPage(
              compactResult: true,
              onPlanTap: () => Navigator.of(context).maybePop(),
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
        _PlanLabel(title),
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
        ExpansionTile(
          tilePadding: EdgeInsets.zero,
          initiallyExpanded: _mustVisit.isNotEmpty || _testingForm,
          title: Row(
            children: [
              const Expanded(
                child: Text(
                  'Optional: Add must-visit places',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppColors.muted,
                  ),
                ),
              ),
              if (_mustVisit.isNotEmpty)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '${_mustVisit.length}/3',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: AppColors.primary,
                    ),
                  ),
                ),
            ],
          ),
          childrenPadding: const EdgeInsets.only(top: 4, bottom: 8),
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l.planMustVisit,
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: AppColors.ink,
                  ),
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    OutlinedButton.icon(
                      key: const ValueKey('plan-from-saved-places-btn'),
                      onPressed: _mustVisit.length >= 3
                          ? null
                          : _chooseFromSavedPlaces,
                      icon: const Icon(
                        Icons.bookmark_outline_rounded,
                        size: 17,
                      ),
                      label: Text(l.planFromSavedPlaces),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.primary,
                        side: BorderSide(
                          color: _mustVisit.length >= 3
                              ? AppColors.line.withValues(alpha: 0.5)
                              : AppColors.primary.withValues(alpha: 0.6),
                        ),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 10,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                    ),
                    OutlinedButton.icon(
                      key: const ValueKey('plan-search-highlight-btn'),
                      onPressed: _mustVisit.length >= 3
                          ? null
                          : _chooseHighlight,
                      icon: const Icon(Icons.search_rounded, size: 17),
                      label: Text(l.planSearchAttractions),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.ink,
                        side: const BorderSide(color: AppColors.line),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 10,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                    ),
                  ],
                ),
                if (_mustVisit.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    runSpacing: 6,
                    children: [
                      for (final stop in _mustVisit)
                        InputChip(
                          key: ValueKey(
                            'must-visit-chip-${stop.placeId ?? stop.title}',
                          ),
                          avatar: const Icon(
                            Icons.place_outlined,
                            size: 16,
                            color: AppColors.primary,
                          ),
                          label: Text(stop.title),
                          onDeleted: () =>
                              setState(() => _mustVisit.remove(stop)),
                        ),
                    ],
                  ),
                ],
              ],
            ),
          ],
        ),
      ],
    };
  }

  @override
  Widget build(BuildContext context) {
    if (widget.useModernPicker &&
        !_testingForm &&
        travelDates == null &&
        !_datesConfirmed &&
        !_destinationConfirmed) {
      final now = DateTime.now();
      return Column(
        children: [
          if (widget.onMyTripsTap != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton.icon(
                    key: const ValueKey('plan-my-trips'),
                    onPressed: () => Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => const TripSelectionScreen(),
                      ),
                    ),
                    icon: const Icon(Icons.luggage_outlined, size: 18),
                    label: Text(context.l10n.myTrips),
                    style: TextButton.styleFrom(
                      foregroundColor: AppColors.primary,
                      textStyle: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                  ),
                ],
              ),
            ),
          Expanded(
            child: ModernDateRangePicker(
              firstDate: DateTime(now.year, now.month, now.day),
              lastDate: now.add(const Duration(days: 365 * 2)),
              stepText: 'STEP 1 • TRAVEL DATES',
              topBanner: _scanPlanPlaces.places.isEmpty
                  ? null
                  : _buildScanPlanPlacesCard(compact: true),
              onDateRangeSelected: (range) {
                setState(() {
                  travelDates = range;
                  _datesConfirmed = true;
                  _hasUserEditedDraft = true;
                  _errorMessage = null;
                  _highlightedEmptyFields.remove('numberOfDays');
                  final pickedDays =
                      range.end.difference(range.start).inDays + 1;
                  if (_planningMode == PlanningMode.multiDestination &&
                      _legs.length >= 2 &&
                      pickedDays >= _legs.length) {
                    _legs = TransferManager.autoDistributeDays(
                      _legs,
                      pickedDays,
                    );
                  }
                  _activeStep = destination == null
                      ? PlanStep.destination
                      : PlanStep.tripLogistics;
                });
                _saveDraft();
              },
            ),
          ),
        ],
      );
    }

    final hasHubDayConflict = _hasHubDayConflict;
    final canEditTravelers =
        _testingForm ||
        (_destinationConfirmed &&
            _datesConfirmed &&
            _calculatedDays <= 30 &&
            !hasHubDayConflict &&
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
        (_testingForm || (canEditInterests && _interestsConfirmed)) &&
        !hasHubDayConflict;
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
                if (_hasPreviousSelection || widget.onMyTripsTap != null) ...[
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      if (_hasPreviousSelection)
                        Flexible(
                          child: TextButton.icon(
                            key: const ValueKey('plan-start-over-btn'),
                            onPressed: _confirmAndReset,
                            icon: const Icon(Icons.restart_alt, size: 16),
                            label: Text(
                              context.l10n.planStartOver,
                              overflow: TextOverflow.ellipsis,
                            ),
                            style: TextButton.styleFrom(
                              visualDensity: VisualDensity.compact,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 4,
                              ),
                              foregroundColor: AppColors.muted,
                            ),
                          ),
                        )
                      else
                        const Spacer(),
                      if (widget.onMyTripsTap != null)
                        Flexible(
                          child: Align(
                            alignment: Alignment.centerRight,
                            child: TextButton.icon(
                              key: const ValueKey('plan-my-trips'),
                              onPressed: () => Navigator.of(context).push(
                                MaterialPageRoute<void>(
                                  builder: (_) => const TripSelectionScreen(),
                                ),
                              ),
                              icon: const Icon(Icons.folder_outlined, size: 18),
                              label: Text(
                                context.l10n.myTrips,
                                overflow: TextOverflow.ellipsis,
                              ),
                              style: TextButton.styleFrom(
                                visualDensity: VisualDensity.compact,
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 6,
                                  vertical: 4,
                                ),
                                foregroundColor: AppColors.primary,
                              ),
                            ),
                          ),
                        ),
                    ],
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
                if (_scanPlanPlaces.places.isNotEmpty) ...[
                  _buildScanPlanPlacesCard(),
                  const SizedBox(height: 16),
                ],
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
                      key: _datesKey,
                      label: context.l10n.travelDates,
                      value: travelDates == null
                          ? context.l10n.selectTravelDates
                          : _travelDateLabel,
                      isPlaceholder: travelDates == null,
                      icon: Icons.calendar_month_outlined,
                      isHighlighted:
                          travelDates == null ||
                          _activeStep == PlanStep.travelDates,
                      supportingText: days > 0
                          ? '$days ${days == 1 ? 'day' : 'days'} to explore${days >= 5 ? ' • Multi-city recommended' : ''}'
                          : null,
                      hasError: _highlightedEmptyFields.contains(
                        'numberOfDays',
                      ),
                      errorText: context.l10n.chooseYourTravelDates,
                      onTap: () {
                        setState(() => _activeStep = PlanStep.travelDates);
                        _pickTravelDates();
                      },
                    ),
                    if (days > 30)
                      _PlanFieldError(TripPreferencesService.m4InvalidDays),
                    const SizedBox(height: 16),
                    _PlanPickerField(
                      key: _destinationKey,
                      label: context.l10n.destination,
                      value: destination == null
                          ? context.l10n.selectDestination
                          : _visibleDestinationLabel,
                      isPlaceholder: destination == null,
                      icon: Icons.place_outlined,
                      isHighlighted:
                          destination == null ||
                          _activeStep == PlanStep.destination,
                      hasError:
                          _highlightedEmptyFields.contains('destination') ||
                          hasHubDayConflict,
                      errorText: context.l10n.chooseADestination,
                      onTap: () {
                        setState(() => _activeStep = PlanStep.destination);
                        _pickDestination();
                      },
                    ),
                    if (_planningMode == PlanningMode.multiDestination &&
                        _legs.isNotEmpty) ...[
                      const SizedBox(height: 12),
                      _ProposedMultiCityRouteCard(
                        legs: _legs,
                        showAllocatedDays:
                            travelDates != null && !hasHubDayConflict,
                        onEditRoute: _openMultiCityEditor,
                        onRemoveLeg: _removeMultiCityLeg,
                      ),
                    ],
                    if (hasHubDayConflict) ...[
                      const SizedBox(height: 12),
                      KeyedSubtree(
                        key: const ValueKey('planner-duration-conflict-notice'),
                        child: _PlanNotice(
                          icon: Icons.warning_amber_rounded,
                          title: context.l10n.plannerDurationConflictTitle,
                          message: context.l10n.plannerDurationConflictMessage(
                            _legs.length,
                            days,
                          ),
                          isError: true,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: OutlinedButton.icon(
                          key: const ValueKey('planner-extend-dates-btn'),
                          onPressed: _pickTravelDates,
                          icon: const Icon(Icons.date_range_outlined, size: 18),
                          label: Text(context.l10n.plannerExtendTripDates),
                        ),
                      ),
                    ],
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
                                !_destinationConfirmed ||
                                    !_datesConfirmed ||
                                    days > 30 ||
                                    hasHubDayConflict
                                ? null
                                : () {
                                    setState(() => _logisticsConfirmed = true);
                                    _advanceToStep(
                                      PlanStep.travelerPreferences,
                                    );
                                  },
                            label: context.l10n.planContinueWho,
                            disabledHint: !_destinationConfirmed
                                ? context.l10n.planUnlockBasics
                                : context.l10n.planUnlockDates,
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
                      showHighlightBadge: false,
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
                                  _saveDraft();
                                },
                              ),
                          ],
                        ),
                        if (modeError)
                          const _PlanFieldError('Choose a travel mode.'),
                        const SizedBox(height: 8),
                        ListTile(
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 8,
                          ),
                          leading: const Icon(Icons.place_outlined),
                          title: Text(context.l10n.planAccommodation),
                          subtitle: Text(
                            _departurePoint?.title ??
                                context.l10n.planChooseStartingPoint,
                          ),
                          onTap: _chooseStartingPoint,
                          trailing: _departurePoint == null
                              ? const Icon(Icons.chevron_right)
                              : IconButton(
                                  icon: const Icon(Icons.clear),
                                  tooltip: context.l10n.planClearStartingPoint,
                                  onPressed: () =>
                                      setState(() => _departurePoint = null),
                                ),
                        ),
                        if (travelMode.isNotEmpty &&
                            travelMode != 'Public Transport') ...[
                          const SizedBox(height: 8),
                          const _PlanInlineNote(
                            icon: Icons.check_circle_outline,
                            text: 'Explore further by car or e-hailing.',
                          ),
                        ],
                        if (travelMode == 'Public Transport') ...[
                          const SizedBox(height: 8),
                          TextFormField(
                            initialValue: _transitMinutesInput,
                            keyboardType: TextInputType.number,
                            decoration: InputDecoration(
                              labelText: context.l10n.planTransitMinutes,
                              floatingLabelBehavior:
                                  FloatingLabelBehavior.always,
                              helper: Text(context.l10n.planTransitMinutesHelp),
                              errorMaxLines: 3,
                            ),
                            forceErrorText:
                                _transitMinutesInput.isNotEmpty &&
                                    _transitPlanningMinutes == null
                                ? context.l10n.planTransitMinutesError
                                : null,
                            onChanged: (text) =>
                                setState(() => _transitMinutesInput = text),
                          ),
                        ],
                        if (travelMode.isNotEmpty) ...[
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
                            showDecorations: false,
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
                              _saveDraft();
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
                    const SizedBox(height: 16),
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
                              _saveDraft();
                            },
                          ),
                      ],
                    ),
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
    final emphasize = isHighlighted;
    final border = hasError
        ? Border.all(color: Colors.red.shade700, width: 1.5)
        : emphasize
        ? Border.all(color: AppColors.primary, width: 2.0)
        : Border.all(color: AppColors.line, width: 1.0);

    final shadows = emphasize
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
        color: emphasize
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
                    color: emphasize
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
                if (emphasize && showHighlightBadge)
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
        _PlanLabel(label),
        const SizedBox(height: 8),
        Semantics(
          key: ValueKey('picker-semantics-$label'),
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
    this.showDecorations = true,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData icon;
  final String? hint;
  final String? disabledHint;
  final bool showDecorations;

  @override
  Widget build(BuildContext context) {
    final isEnabled = onPressed != null;
    final hintText = isEnabled
        ? (hint ?? context.l10n.planTapToProceed)
        : (disabledHint ?? context.l10n.planUnlockDates);

    return Padding(
      padding: EdgeInsets.only(top: showDecorations ? 18 : 16, bottom: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          if (showDecorations)
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
              boxShadow: isEnabled && showDecorations
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

        final rows = <List<Widget>>[];
        for (var i = 0; i < children.length; i += columns) {
          final end = (i + columns < children.length)
              ? i + columns
              : children.length;
          rows.add(children.sublist(i, end));
        }

        return Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (var r = 0; r < rows.length; r++) ...[
              if (r > 0) const SizedBox(height: gap),
              IntrinsicHeight(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    for (var c = 0; c < columns; c++) ...[
                      if (c > 0) const SizedBox(width: gap),
                      if (c < rows[r].length)
                        Expanded(child: rows[r][c])
                      else
                        const Expanded(child: SizedBox.shrink()),
                    ],
                  ],
                ),
              ),
            ],
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
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 12),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    selected
                        ? Icons.check_circle
                        : icon ?? Icons.radio_button_unchecked,
                    size: 20,
                    color: selected ? AppColors.primary : AppColors.muted,
                  ),
                  const SizedBox(height: 8),
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      context.tr(title),
                      textAlign: TextAlign.center,
                      maxLines: 1,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: selected
                            ? FontWeight.w800
                            : FontWeight.w600,
                        color: selected ? AppColors.primary : AppColors.ink,
                      ),
                    ),
                  ),
                  if (subtitle != null) ...[
                    const SizedBox(height: 4),
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        context.tr(subtitle!),
                        textAlign: TextAlign.center,
                        maxLines: 1,
                        style: const TextStyle(
                          fontSize: 12,
                          height: 1.4,
                          color: AppColors.muted,
                        ),
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
        fontSize: 14,
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

class _SavedPlacesSelectionSheet extends StatefulWidget {
  const _SavedPlacesSelectionSheet({
    required this.savedPlaces,
    required this.alreadyAddedIds,
    required this.remainingSlots,
    this.destination,
  });

  final List<Attraction> savedPlaces;
  final Set<String> alreadyAddedIds;
  final int remainingSlots;
  final String? destination;

  @override
  State<_SavedPlacesSelectionSheet> createState() =>
      _SavedPlacesSelectionSheetState();
}

class _SavedPlacesSelectionSheetState
    extends State<_SavedPlacesSelectionSheet> {
  final Set<Attraction> _selected = {};

  bool _matchesDestination(Attraction place) {
    if (widget.destination == null || widget.destination!.isEmpty) return false;
    final dest = widget.destination!.toLowerCase();
    final area = switch (widget.destination) {
      'Kuala Lumpur' => 'kl',
      'Penang' => 'penang',
      'Melaka' => 'melaka',
      'Kedah' => 'langkawi',
      'Perak' => 'ipoh',
      _ => dest,
    };
    if (place.xid.toLowerCase().contains(area)) return true;
    if (place.name.toLowerCase().contains(dest)) return true;
    if (place.description?.toLowerCase().contains(dest) ?? false) return true;
    return false;
  }

  bool _isAlreadyAdded(Attraction place) {
    return widget.alreadyAddedIds.contains(place.xid) ||
        widget.alreadyAddedIds.contains(place.name.trim().toLowerCase());
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final sortedPlaces = [...widget.savedPlaces]
      ..sort((a, b) {
        final aMatch = _matchesDestination(a) ? 1 : 0;
        final bMatch = _matchesDestination(b) ? 1 : 0;
        return bMatch.compareTo(aMatch);
      });

    final maxCanSelect = widget.remainingSlots;

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.sizeOf(context).height * 0.75,
      ),
      decoration: BoxDecoration(
        color: AppColors.nightSurface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        border: Border.all(color: AppColors.line),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Center(
            child: Container(
              margin: const EdgeInsets.only(top: 10, bottom: 6),
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.muted.withValues(alpha: 0.35),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        l.selectSavedPlaces,
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(
                              fontWeight: FontWeight.w800,
                              color: AppColors.ink,
                            ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        l.selectSavedPlacesHelp(maxCanSelect.toString()),
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.muted,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(
                    Icons.close,
                    size: 20,
                    color: AppColors.muted,
                  ),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: AppColors.line),
          Flexible(
            child: ListView.separated(
              shrinkWrap: true,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              itemCount: sortedPlaces.length,
              separatorBuilder: (_, _) =>
                  const Divider(height: 1, indent: 52, color: AppColors.line),
              itemBuilder: (context, index) {
                final place = sortedPlaces[index];
                final isAdded = _isAlreadyAdded(place);
                final isSelected = _selected.contains(place);
                final matches = _matchesDestination(place);
                final canSelectMore = _selected.length < maxCanSelect;

                return InkWell(
                  key: ValueKey('saved-place-item-${place.xid}'),
                  borderRadius: BorderRadius.circular(12),
                  onTap: isAdded
                      ? null
                      : () {
                          setState(() {
                            if (isSelected) {
                              _selected.remove(place);
                            } else if (canSelectMore) {
                              _selected.add(place);
                            } else {
                              ScaffoldMessenger.of(
                                context,
                              ).hideCurrentSnackBar();
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(
                                    l.selectSavedPlacesHelp(
                                      maxCanSelect.toString(),
                                    ),
                                  ),
                                  duration: const Duration(seconds: 2),
                                  behavior: SnackBarBehavior.floating,
                                ),
                              );
                            }
                          });
                        },
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 10,
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: matches
                                ? AppColors.primary.withValues(alpha: 0.15)
                                : AppColors.nightCanvas,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: matches
                                  ? AppColors.primary.withValues(alpha: 0.4)
                                  : AppColors.line,
                            ),
                          ),
                          child: Icon(
                            matches
                                ? Icons.star_border_rounded
                                : Icons.place_outlined,
                            size: 20,
                            color: matches
                                ? AppColors.primary
                                : AppColors.muted,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                place.name,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: isAdded
                                      ? AppColors.muted
                                      : AppColors.ink,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Wrap(
                                crossAxisAlignment: WrapCrossAlignment.center,
                                spacing: 4,
                                children: [
                                  if (place.category.isNotEmpty)
                                    Text(
                                      place.category,
                                      style: const TextStyle(
                                        fontSize: 11,
                                        color: AppColors.muted,
                                      ),
                                    ),
                                  if (matches && widget.destination != null)
                                    Text(
                                      '• ${l.matchesDestination(widget.destination!)}',
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        fontSize: 11,
                                        color: AppColors.primary,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        if (isAdded)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.nightCanvas,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(
                                  Icons.check,
                                  size: 13,
                                  color: AppColors.muted,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  l.placeAlreadyAdded,
                                  style: const TextStyle(
                                    fontSize: 11,
                                    color: AppColors.muted,
                                  ),
                                ),
                              ],
                            ),
                          )
                        else
                          Checkbox(
                            value: isSelected,
                            activeColor: AppColors.primary,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(4),
                            ),
                            onChanged: isAdded
                                ? null
                                : (checked) {
                                    setState(() {
                                      if (checked == true) {
                                        if (canSelectMore) {
                                          _selected.add(place);
                                        } else {
                                          ScaffoldMessenger.of(
                                            context,
                                          ).hideCurrentSnackBar();
                                          ScaffoldMessenger.of(
                                            context,
                                          ).showSnackBar(
                                            SnackBar(
                                              content: Text(
                                                l.selectSavedPlacesHelp(
                                                  maxCanSelect.toString(),
                                                ),
                                              ),
                                              duration: const Duration(
                                                seconds: 2,
                                              ),
                                              behavior:
                                                  SnackBarBehavior.floating,
                                            ),
                                          );
                                        }
                                      } else {
                                        _selected.remove(place);
                                      }
                                    });
                                  },
                          ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
          const Divider(height: 1, color: AppColors.line),
          Padding(
            padding: EdgeInsets.fromLTRB(
              20,
              12,
              20,
              12 + MediaQuery.paddingOf(context).bottom,
            ),
            child: SizedBox(
              width: double.infinity,
              height: 48,
              child: FilledButton(
                key: const ValueKey('apply-saved-places-confirm-btn'),
                onPressed: _selected.isEmpty
                    ? null
                    : () => Navigator.of(context).pop(_selected.toList()),
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.black,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: Text(
                  l.applySelectedPlaces(_selected.length.toString()),
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ProposedMultiCityRouteCard extends StatelessWidget {
  const _ProposedMultiCityRouteCard({
    required this.legs,
    required this.showAllocatedDays,
    required this.onEditRoute,
    required this.onRemoveLeg,
  });

  final List<DestinationLeg> legs;
  final bool showAllocatedDays;
  final VoidCallback onEditRoute;
  final ValueChanged<int> onRemoveLeg;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;

    return Container(
      key: const ValueKey('planner-multi-city-route-card'),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.nightCanvas,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Icon(
                Icons.route_outlined,
                color: AppColors.primary,
                size: 18,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  l10n.plannerProposedRouteTitle,
                  style: const TextStyle(
                    color: AppColors.ink,
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              TextButton(
                key: const ValueKey('planner-edit-route-btn'),
                onPressed: onEditRoute,
                style: TextButton.styleFrom(
                  visualDensity: VisualDensity.compact,
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                ),
                child: Text(l10n.plannerEditRoute),
              ),
            ],
          ),
          Text(
            l10n.plannerRouteAutoOrdered,
            style: const TextStyle(color: AppColors.muted, fontSize: 12),
          ),
          const SizedBox(height: 10),
          for (int i = 0; i < legs.length; i++) ...[
            if (i > 0) const SizedBox(height: 8),
            Row(
              children: [
                Container(
                  width: 24,
                  height: 24,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: i == 0 ? AppColors.primary : AppColors.nightSurface,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: i == 0 ? AppColors.primary : AppColors.line,
                    ),
                  ),
                  child: Text(
                    '${i + 1}',
                    style: TextStyle(
                      color: i == 0 ? AppColors.onNightAccent : AppColors.ink,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        legs[i].hubName.toLowerCase() ==
                                legs[i].stateName.toLowerCase()
                            ? legs[i].hubName
                            : '${legs[i].hubName}, ${legs[i].stateName}',
                        style: const TextStyle(
                          color: AppColors.ink,
                          fontSize: 13.5,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      if (i == 0 || showAllocatedDays)
                        Text(
                          [
                            if (i == 0) l10n.spotlightStartBadge,
                            if (showAllocatedDays)
                              l10n.plannerDaysAllocatedShort(
                                legs[i].allocatedDays,
                              ),
                          ].join(' · '),
                          style: const TextStyle(
                            color: AppColors.muted,
                            fontSize: 12,
                          ),
                        ),
                    ],
                  ),
                ),
                IconButton(
                  key: ValueKey('remove-leg-${legs[i].destinationId}'),
                  tooltip: l10n.plannerRemoveDestinationTooltip(
                    legs[i].hubName,
                  ),
                  onPressed: () => onRemoveLeg(i),
                  constraints: const BoxConstraints(
                    minWidth: 40,
                    minHeight: 40,
                  ),
                  icon: const Icon(
                    Icons.close_rounded,
                    size: 18,
                    color: AppColors.muted,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
