import 'dart:math' as math;
import 'dart:convert';
import 'package:flutter/material.dart';

import 'package:smart_travel_planner/core/theme/app_colors.dart';
import 'package:smart_travel_planner/shared/models/travel_stop.dart';
import 'package:smart_travel_planner/shared/models/weather_forecast.dart';
import 'package:smart_travel_planner/features/itinerary/models/trip_preferences.dart';
import 'package:smart_travel_planner/features/places/services/google_places_service.dart';
import 'package:smart_travel_planner/features/places/services/place_catalog_service.dart';
import 'package:smart_travel_planner/core/config/supabase_config.dart';
import 'package:smart_travel_planner/features/places/data/curated_attractions.dart';
import 'package:smart_travel_planner/features/places/services/place_classifier.dart';
import 'scheduling_engine.dart';
import 'travel_matrix_service.dart';
import 'package:smart_travel_planner/shared/services/weather_service.dart';

class _AttractionTemplate {
  final String title;
  final String category;
  final String note;
  final String description;
  final int durationMinutes;
  final String openingHours;
  final List<String> tips;
  final IconData icon;
  final Color color;
  final bool isMeal;
  final double? latitude;
  final double? longitude;

  const _AttractionTemplate({
    required this.title,
    required this.category,
    required this.note,
    required this.description,
    required this.durationMinutes,
    required this.openingHours,
    required this.tips,
    required this.icon,
    required this.color,
    this.isMeal = false,
    this.latitude,
    this.longitude,
  });
}

class SmartItineraryService {
  static final Map<int, List<TravelStop>> _liveGeneratedDays = {};
  static String? _cacheKey;
  static int _generation = 0;
  static int _request = 0;
  static int get revision => _generation;
  static final Map<int, String> dayWarnings = {};
  static String _key(TripPreferences prefs) => jsonEncode(prefs.toJson());

  static void clearLiveCache() {
    _request++;
    _liveGeneratedDays.clear();
    _cacheKey = null;
    dayWarnings.clear();
    _generation++;
  }

  static List<TravelStop>? getLiveStops(int dayIndex) =>
      _liveGeneratedDays[dayIndex];
  static bool hasLiveStops(int dayIndex) =>
      _liveGeneratedDays.containsKey(dayIndex);

  /// Computes accurate route distance between consecutive stops using Haversine formula + winding road factor
  static double calculateRouteDistanceKm(List<TravelStop> stops) {
    if (stops.length < 2) return 0.0;
    double totalKm = 0.0;
    for (int i = 0; i < stops.length - 1; i++) {
      final s1 = stops[i];
      final s2 = stops[i + 1];
      if (s1.latitude != 0.0 &&
          s1.longitude != 0.0 &&
          s2.latitude != 0.0 &&
          s2.longitude != 0.0) {
        const p = 0.017453292519943295; // Math.PI / 180
        final a =
            0.5 -
            math.cos((s2.latitude - s1.latitude) * p) / 2 +
            math.cos(s1.latitude * p) *
                math.cos(s2.latitude * p) *
                (1 - math.cos((s2.longitude - s1.longitude) * p)) /
                2;
        final straightKm = 12742 * math.asin(math.sqrt(a));
        totalKm +=
            straightKm *
            1.28; // Standard Malaysian urban road network tortuosity factor
      } else {
        totalKm += 3.5;
      }
    }
    return double.parse(totalKm.toStringAsFixed(2));
  }

  static Future<bool> generateLiveItineraryForAllDays({
    required TripPreferences preferences,
    int seed = 0,
    bool requireVisits = false,
    Set<String> previousStopIds = const {},
    GooglePlacesService? placesService,
  }) async {
    final request = ++_request;
    final destination = preferences.destination ?? 'Kuala Lumpur';
    final dayCount = preferences.numberOfDays ?? 3;
    final dates = [
      for (var day = 0; day < dayCount; day++) preferences.dateForDay(day),
    ];
    final weatherService = WeatherService();
    final forecasts = <WeatherForecast>[];
    for (final date in dates) {
      forecasts.add(
        await weatherService.getForecastForDate(state: destination, date: date),
      );
      if (request != _request) return false;
    }
    final outdoorUnsuitableDays = forecasts
        .where((day) => day.isAvailable && !day.isSuitableForOutdoor)
        .length;
    final indoorShare = dates.isEmpty
        ? 0.0
        : outdoorUnsuitableDays / dates.length;
    bool hasOpeningWindow(TravelStop stop) => dates.any(
      (date) => SchedulingEngine.intervals(stop, date)?.isNotEmpty == true,
    );
    final places = placesService ?? GooglePlacesService();
    List<TravelStop> candidates = [];
    try {
      candidates = await _fetchDatabaseCandidates(
        destination,
        prioritizeIndoor: indoorShare > 0,
      );
    } catch (_) {}

    if (candidates.isEmpty) {
      try {
        final results = await Future.wait([
          places.fetchPlacesWithDatabaseCache(
            destinationState: destination,
            query: 'tourist attractions in $destination Malaysia',
            maxResults: 20,
            indoorShare: indoorShare,
            shouldContinue: () => request == _request,
          ),
          places.fetchPlacesWithDatabaseCache(
            destinationState: destination,
            query: 'local restaurants in $destination Malaysia',
            isMeal: true,
            maxResults: 12,
            indoorShare: indoorShare,
            shouldContinue: () => request == _request,
          ),
        ]);
        candidates = [
          for (var i = 0; i < results.length; i++)
            for (final place in results[i])
              GooglePlacesService.convertGooglePlaceToStop(
                place: place,
                timeRange: '',
                durationLabel: i == 1 ? '75 min' : '90 min',
                isMeal: i == 1,
              ),
        ];
      } catch (_) {
        /* Use the curated local catalog. */
      }
    }
    candidates = candidates
        .where(
          (s) => s.latitude != 0 && s.longitude != 0 && hasOpeningWindow(s),
        )
        .toList();
    if (candidates.isEmpty) {
      final localCandidates = _offlineCandidates(
        preferences,
      ).where(hasOpeningWindow).toList();
      candidates = localCandidates;
    }
    Future<TravelStop> resolve(TravelStop stop) async =>
        stop.latitude != 0 &&
            stop.longitude != 0 &&
            dates.every((date) => SchedulingEngine.intervals(stop, date) != null)
        ? stop
        : places.refreshStop(stop);
    final resolvedPriorities = await Future.wait(
      preferences.mustVisitPlaces.map(resolve),
    );
    final resolvedSelected = await Future.wait(
      preferences.selectedPlaces.map(resolve),
    );
    final origin = preferences.dailyOrigin;
    final resolvedOrigin = origin == null ? null : await resolve(origin);
    final effectivePreferences = preferences.copyWith(
      departurePoint: resolvedOrigin,
      mustVisitPlaces: resolvedPriorities,
      selectedPlaces: resolvedSelected,
    );
    final titles = <String>{};
    final ids = <String>{};
    candidates = [
      for (final stop in [
        ...resolvedPriorities,
        ...resolvedSelected,
        ...candidates,
      ])
        if (stop.latitude != 0 &&
            stop.longitude != 0 &&
            hasOpeningWindow(stop) &&
            !titles.contains(_normalizedTitle(stop.title)) &&
            ids.add(SchedulingEngine.identity(stop)) &&
            titles.add(_normalizedTitle(stop.title)))
          stop,
    ];
    final matrix = TravelMatrixService();
    final points = [
      if (resolvedOrigin != null &&
          resolvedOrigin.latitude != 0 &&
          resolvedOrigin.longitude != 0)
        resolvedOrigin,
      ...candidates,
    ];
    final mode = preferences.travelMode ?? 'Driving';
    final [legs, walkingLegs] = await Future.wait([
      matrix.fetch(points, mode),
      if (mode != 'Walking' &&
          preferences.secondaryTransportModes.contains('Walking'))
        matrix.fetch(points, 'Walking')
      else
        Future.value(<String, TravelLeg>{}),
    ]);
    final legsByDay = <Map<String, TravelLeg>>[];
    for (final date in dates) {
      final departureMinutes =
          TripPreferences.minutesOf(preferences.dailyStartTime) ?? 510;
      // Malaysia uses UTC+08:00 year-round.
      final localSightseeingStart = DateTime.utc(
        date.year,
        date.month,
        date.day,
      ).add(Duration(minutes: departureMinutes - 8 * 60));
      final dayLegs = mode == 'Public Transport'
          ? await matrix.fetch(
              points,
              mode,
              departureTime: localSightseeingStart,
            )
          : legs;
      legsByDay.add(dayLegs);
    }
    List<List<TravelStop>> plan(List<TravelStop> pool) =>
        SchedulingEngine.scheduleTrip(
          candidates: pool,
          preferences: effectivePreferences,
          dates: dates,
          weather: forecasts,
          dailyLegs: legsByDay,
          walkingLegs: walkingLegs,
          seed: seed,
          previousStopIds: previousStopIds,
        );
    var plannedDays = plan(candidates);
    final visitTarget = switch (preferences.paceCategory) {
      PaceCategory.relaxed => 3,
      PaceCategory.balanced => 4,
      PaceCategory.packed => 6,
      null => 2,
    };
    final searchedAnchors = <String>{};
    final sparseDays = List.generate(dates.length, (day) => day)
      ..sort((a, b) => plannedDays[a].length.compareTo(plannedDays[b].length));
    final extraStops = <TravelStop>[];
    for (final day in sparseDays) {
      if (request != _request) return false;
      if (plannedDays[day].length >= visitTarget ||
          searchedAnchors.length >= 2) {
        break;
      }
      final anchor = plannedDays[day].firstOrNull ?? resolvedOrigin;
      if (anchor == null ||
          !searchedAnchors.add(SchedulingEngine.identity(anchor))) {
        continue;
      }
      final nearby = await _nearbySuggestions(
        places: places,
        anchor: anchor,
        state: destination.split(',').first.trim(),
        indoorOnly:
            forecasts[day].isAvailable && !forecasts[day].isSuitableForOutdoor,
        knownIds: ids,
        shouldContinue: () => request == _request,
      );
      for (final stop in nearby) {
        if (hasOpeningWindow(stop) &&
            !titles.contains(_normalizedTitle(stop.title)) &&
            ids.add(SchedulingEngine.identity(stop))) {
          titles.add(_normalizedTitle(stop.title));
          extraStops.add(stop);
        }
      }
    }
    if (extraStops.isNotEmpty && request == _request) {
      final expanded = plan([...candidates, ...extraStops]);
      final chosenIds = [
        ...resolvedPriorities,
        ...resolvedSelected,
      ].map(SchedulingEngine.identity).toSet();
      final originalChosen = plannedDays
          .expand((day) => day)
          .map(SchedulingEngine.identity)
          .where(chosenIds.contains);
      final expandedIds = expanded
          .expand((day) => day)
          .map(SchedulingEngine.identity)
          .toSet();
      if (expandedIds.containsAll(originalChosen) &&
          sparseDays.any(
            (day) => expanded[day].length > plannedDays[day].length,
          ) &&
          sparseDays.every(
            (day) => expanded[day].length >= plannedDays[day].length,
          )) {
        plannedDays = expanded;
      }
    }
    final days = <int, List<TravelStop>>{
      for (var day = 0; day < plannedDays.length; day++) day: plannedDays[day],
    };
    final warnings = <int, String>{
      for (var day = 0; day < plannedDays.length; day++)
        day: _warning(plannedDays[day], forecasts[day].isAvailable),
    };
    final scheduled = days.values
        .expand((stops) => stops)
        .map((stop) => _normalizedTitle(stop.title))
        .toSet();
    final missed = resolvedPriorities
        .where((stop) => !scheduled.contains(_normalizedTitle(stop.title)))
        .map((stop) => stop.title)
        .join(', ');
    if (missed.isNotEmpty) {
      warnings[0] =
          '${warnings[0] ?? ''} Must-visit places that could not be scheduled: $missed.';
    }
    if (request != _request ||
        (requireVisits && days.values.every((stops) => stops.isEmpty))) {
      return false;
    }
    _generation++;
    _liveGeneratedDays.clear();
    dayWarnings.clear();
    _cacheKey = _key(preferences);
    _liveGeneratedDays.addAll(days);
    dayWarnings.addAll(warnings);
    return true;
  }

  static Future<List<TravelStop>> _nearbySuggestions({
    required GooglePlacesService places,
    required TravelStop anchor,
    required String state,
    required bool indoorOnly,
    required Set<String> knownIds,
    required bool Function() shouldContinue,
  }) async {
    final name = anchor.title.trim();
    if (name.isEmpty) return [];
    final area = name.substring(0, math.min(name.length, 100));
    final kind = indoorOnly
        ? 'indoor museums and galleries'
        : 'visitor attractions';
    final found = await places.searchPlannerPlaces(
      query: '$kind near $area',
      state: state,
    );
    if (!shouldContinue()) return [];
    final ids = found
        .map((item) => item['id'])
        .whereType<String>()
        .where((id) => !knownIds.contains(id))
        .toSet()
        .take(4);
    final details = await Future.wait(ids.map(places.fetchDetails));
    final nearby = <TravelStop>[];
    for (final place in details.nonNulls) {
      final title = place.name;
      final address = place.address?.toLowerCase() ?? '';
      final category = place.category ?? 'Attraction';
      final latitude = place.latitude;
      final longitude = place.longitude;
      if (title == null ||
          title.trim().isEmpty ||
          !address.trimRight().endsWith('malaysia') ||
          !GooglePlacesService.addressMatchesState(address, state) ||
          place.hours.isEmpty ||
          latitude == null ||
          longitude == null ||
          !latitude.isFinite ||
          !longitude.isFinite ||
          latitude < 1 ||
          latitude > 7.5 ||
          longitude < 99 ||
          longitude > 120) {
        continue;
      }
      final indoor = PlaceClassifier.classify(category: category, name: title);
      if (indoorOnly && indoor != true) continue;
      final stop = GooglePlacesService.convertGooglePlaceToStop(
        place: {...place.data, 'id': place.id, 'is_indoor': indoor},
        timeRange: '',
        durationLabel: '90 min',
        isMeal: PlaceCatalogService.isMeal({'category': category}),
      );
      if (SchedulingEngine.estimate(anchor, stop, 'Driving').distanceKm <= 20) {
        nearby.add(stop);
      }
    }
    return nearby;
  }

  static String _warning(List<TravelStop> stops, bool weatherAvailable) => [
    if (stops.isEmpty)
      'No additional places fit this day. Try fewer days or wider daily hours.',
    if (!weatherAvailable)
      'Forecast unavailable for this date; weather filtering was not applied.',
    if (stops.any((s) => s.travelMinutes >= 60))
      'Some stops require significant travel time (> 60 min). Consider spreading them across separate days or choosing closer places.',
    if (stops.any((s) => s.travelIsEstimated && s.travelMinutes > 0))
      stops.any((stop) => stop.inboundMode == 'Public Transport')
          ? 'Public transport times are planning estimates. Check departures before traveling.'
          : 'Travel times are distance-based estimates.',
    'Costs are planning estimates, excluding accommodation and travel to the first stop.',
  ].join(' ');

  static Future<List<TravelStop>> generateLiveItinerary({
    required TripPreferences preferences,
    int dayIndex = 0,
  }) async {
    if (_cacheKey != _key(preferences) ||
        !_liveGeneratedDays.containsKey(dayIndex)) {
      await generateLiveItineraryForAllDays(preferences: preferences);
    }
    return _liveGeneratedDays[dayIndex] ?? [];
  }

  static List<TravelStop> generateDailyStops({
    required TripPreferences preferences,
    required int dayIndex,
  }) {
    if (_cacheKey == _key(preferences) &&
        _liveGeneratedDays.containsKey(dayIndex)) {
      return _liveGeneratedDays[dayIndex]!;
    }
    if (dayIndex < 0) return [];
    final dayCount = math.max(preferences.numberOfDays ?? 3, dayIndex + 1);
    final days = SchedulingEngine.scheduleTrip(
      candidates: [
        ...preferences.mustVisitPlaces,
        ...preferences.selectedPlaces,
        ..._offlineCandidates(preferences),
      ],
      preferences: preferences,
      dates: List.generate(dayCount, preferences.dateForDay),
      weather: List.filled(dayCount, null),
      dailyLegs: List.filled(dayCount, const {}),
    );
    final stops = days[dayIndex];
    dayWarnings[dayIndex] = _warning(stops, false);
    return stops;
  }

  static String _normalizedTitle(String title) =>
      title.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');

  static double estimateVisitCost(
    String category, {
    String? placeId,
    String? title,
  }) {
    // Admission published by Yayasan Warisan Johor, Tourism Johor and JMM.
    // https://ywj.gov.my/faq/
    // https://tourism.johor.gov.my/making-waves-on-land-mersing-gallery-turns-marine-life-into-an-interactive-adventure/
    // https://www.jmm.gov.my/en/content/kota-johor-lama-museum
    const freeIds = {
      'ChIJwzwNUJlLxTERyUQ43zKJ0Ww',
      'ChIJfTGpsYFg2jER0-F7D-jajGo',
    };
    const freeNames = {
      'mersingmuseum',
      'muziummersing',
      'museumofmersing',
      'kotatinggimuseum',
      'muziumkotatinggi',
      'museumofkotatinggi',
      'datoonngallery',
      'galeridatoonn',
      'galleryofdatoonn',
      'mersingmarineparkgallery',
      'johormarineparkgallery',
      'galeritamanlautmersing',
      'kotajohorlamamuseum',
      'muziumkotajohorlama',
    };
    if (freeIds.contains(placeId) ||
        freeNames.contains(_normalizedTitle(title ?? ''))) {
      return 0;
    }
    final lower = category.toLowerCase();
    if (RegExp(
      'food|restaurant|dining|cafe',
      caseSensitive: false,
    ).hasMatch(lower)) {
      return 25;
    }
    if (RegExp(
      'nature|park|heritage|religio',
      caseSensitive: false,
    ).hasMatch(lower)) {
      return 15;
    }
    return 40;
  }

  static Future<List<TravelStop>> _fetchDatabaseCandidates(
    String state, {
    bool prioritizeIndoor = true,
  }) async {
    try {
      final db = SupabaseConfig.client;
      if (db == null) return [];

      final cleanState = state.split(',').first.trim();
      final responses = await Future.wait([
        // 1. Verified indoor attractions (essential for heavy rain/weather resilience)
        db
            .from('places')
            .select(
              'place_id,name,state,category,latitude,longitude,rating,user_ratings_total,operating_hours,is_indoor,photo_url',
            )
            .ilike('state', '%$cleanState%')
            .eq('is_indoor', true)
            .not('name', 'is', null)
            .neq('name', 'Saved Google place')
            .not('latitude', 'is', null)
            .neq('latitude', 0)
            .order('rating', ascending: false, nullsFirst: false)
            .limit(30)
            .timeout(const Duration(seconds: 8)),

        // 2. Sightseeing attractions
        db
            .from('places')
            .select(
              'place_id,name,state,category,latitude,longitude,rating,user_ratings_total,operating_hours,is_indoor,photo_url',
            )
            .ilike('state', '%$cleanState%')
            .neq('category', 'Food')
            .not('name', 'is', null)
            .neq('name', 'Saved Google place')
            .not('latitude', 'is', null)
            .neq('latitude', 0)
            .order('rating', ascending: false, nullsFirst: false)
            .limit(40)
            .timeout(const Duration(seconds: 8)),

        // 3. Local dining spots
        db
            .from('places')
            .select(
              'place_id,name,state,category,latitude,longitude,rating,user_ratings_total,operating_hours,is_indoor,photo_url',
            )
            .ilike('state', '%$cleanState%')
            .eq('category', 'Food')
            .not('name', 'is', null)
            .neq('name', 'Saved Google place')
            .not('latitude', 'is', null)
            .neq('latitude', 0)
            .order('rating', ascending: false, nullsFirst: false)
            .limit(25)
            .timeout(const Duration(seconds: 8)),
      ]);

      final seenIds = <String>{};
      final stops = <TravelStop>[];

      for (final rows in responses) {
        for (final item in rows) {
          final pId = item['place_id']?.toString() ?? '';
          if (pId.isEmpty || !seenIds.add(pId)) continue;

          final name = item['name']?.toString() ?? '';
          final category = item['category']?.toString() ?? 'Attraction';
          final isMeal = PlaceCatalogService.isMeal(item);
          final lat = (item['latitude'] as num?)?.toDouble() ?? 0.0;
          final lng = (item['longitude'] as num?)?.toDouble() ?? 0.0;
          if (lat == 0.0 || lng == 0.0) continue;

          final isIndoor = item['is_indoor'] as bool? ??
              PlaceClassifier.classify(category: category, name: name);

          Map<String, dynamic> opHours;
          if (item['operating_hours'] is Map &&
              (item['operating_hours'] as Map).isNotEmpty) {
            opHours = Map<String, dynamic>.from(item['operating_hours'] as Map);
          } else {
            opHours = isMeal
                ? {'open': '10:00', 'close': '22:00'}
                : {'open': '09:00', 'close': '21:00'};
          }

          final hoursStr =
              (opHours['weekdayDescriptions'] as List?)?.join('; ') ??
              (isMeal
                  ? 'Daily, 10:00 AM - 10:00 PM'
                  : 'Daily, 9:00 AM - 9:00 PM');

          final rating = item['rating'];
          final reviewCount = item['user_ratings_total'];
          final photoUrl = item['photo_url']?.toString();

          stops.add(
            TravelStop(
              placeId: pId,
              title: name,
              time: '',
              note: '$category • Database',
              description: '$category in $state',
              duration: isMeal ? '75 min' : '90 min',
              openingHours: hoursStr,
              operatingHours: opHours,
              category: category,
              latitude: lat,
              longitude: lng,
              isIndoor: isIndoor,
              visitMinutes: isMeal ? 75 : 90,
              estimatedCost: estimateVisitCost(category, placeId: pId, title: name),
              dataSource: 'database',
              photoUrls:
                  photoUrl != null && photoUrl.isNotEmpty ? [photoUrl] : const [],
              icon: isMeal
                  ? Icons.restaurant
                  : (isIndoor == true ? Icons.museum : Icons.place),
              color: isMeal
                  ? const Color(0xFFFF8A3D)
                  : (isIndoor == true
                      ? const Color(0xFF0D9488)
                      : AppColors.primary),
              tips: [
                if (rating != null) 'Rating: $rating',
                if (reviewCount != null) '$reviewCount reviews',
                'From Supabase Database',
              ],
            ),
          );
        }
      }
      return stops;
    } catch (_) {
      return [];
    }
  }

  static List<TravelStop> _offlineCandidates(TripPreferences preferences) {
    final destination = preferences.destination ?? 'Kuala Lumpur';
    final pool = <String, TravelStop>{};
    final hasTemplates = [
      'kuala lumpur',
      'penang',
      'melaka',
      'johor',
      'sabah',
    ].contains(destination.toLowerCase());
    for (var day = 0; hasTemplates && day < 4; day++) {
      for (final template in _getCandidatesForDestination(
        destination,
        day,
        preferences.interests,
      )) {
        final stop = _buildStop(template, 0, template.durationMinutes);
        if (stop.latitude != 0 && stop.longitude != 0) {
          pool[SchedulingEngine.identity(stop)] = stop;
        }
      }
    }
    const prefixes = {
      'kuala lumpur': 'kl',
      'penang': 'penang',
      'melaka': 'melaka',
      'selangor': 'selangor',
      'johor': 'johor',
      'perak': 'ipoh',
      'pahang': 'pahang',
      'sabah': 'sabah',
      'sarawak': 'sarawak',
      'putrajaya': 'putrajaya',
      'kedah': 'langkawi',
      'kelantan': 'klt',
      'terengganu': 'trg',
      'negeri sembilan': 'ns',
      'perlis': 'pls',
    };
    final prefix = prefixes[destination.toLowerCase()];
    if (prefix != null) {
      for (final a in curatedMalaysianAttractions.where(
        (a) => a.xid.startsWith('curated_${prefix}_'),
      )) {
        if (pool.containsKey(a.xid)) continue;
        final meal = RegExp(
          'food|dining|restaurant',
          caseSensitive: false,
        ).hasMatch(a.category);
        final isNight = RegExp(
          'night|pasar|bazaar|pub|bar',
          caseSensitive: false,
        ).hasMatch('${a.name} ${a.category}');
        final openingHours = isNight
            ? 'Daily, 5:00 PM - 11:00 PM'
            : meal
            ? 'Daily, 10:00 AM - 9:00 PM'
            : 'Daily, 9:00 AM - 6:00 PM';
        pool[a.xid] = TravelStop(
          title: a.name,
          time: '',
          note: 'Offline catalog • Hours and costs estimated',
          description: a.description ?? '',
          duration: meal ? '75 min' : '90 min',
          openingHours: openingHours,
          tips: const [
            'Confirm opening hours and ticket prices before visiting.',
          ],
          icon: Icons.place,
          color: AppColors.primary,
          category: a.category,
          placeId: a.xid,
          latitude: a.latitude,
          longitude: a.longitude,
          estimatedCost: estimateVisitCost(a.category, placeId: a.xid, title: a.name),
          visitMinutes: meal ? 75 : 90,
          isIndoor: PlaceClassifier.classify(
            category: a.category,
            name: a.name,
          ),
        );
      }
    }
    return pool.values.toList();
  }

  static TravelStop _buildStop(
    _AttractionTemplate template,
    int startMin,
    int endMin,
  ) {
    final durationMins = endMin - startMin;
    final hours = durationMins ~/ 60;
    final mins = durationMins % 60;
    final durationLabel = hours > 0
        ? (mins > 0 ? '$hours h $mins min' : '$hours h')
        : '$mins min';

    String normalize(String value) =>
        value.toLowerCase().replaceAll(RegExp(r'[^a-z0-9 ]'), '').trim();
    final title = normalize(
      template.title.replaceAll(RegExp(r'^(Lunch|Dinner) at '), ''),
    );
    final matches = curatedMalaysianAttractions.where((a) {
      final name = normalize(a.name);
      return name.contains(title) || title.contains(name);
    }).toList();
    final attraction = matches.isEmpty ? null : matches.first;
    return TravelStop(
      placeId: attraction?.xid,
      latitude: attraction?.latitude ?? template.latitude ?? 0,
      longitude: attraction?.longitude ?? template.longitude ?? 0,
      estimatedCost: estimateVisitCost(template.category, title: template.title),
      visitMinutes: template.durationMinutes,
      isIndoor: PlaceClassifier.classify(
        category: template.category,
        name: template.title,
      ),
      title: template.title,
      time: '${_formatClock(startMin)} - ${_formatClock(endMin)}',
      note: template.note,
      description: template.description,
      duration: durationLabel,
      openingHours: template.openingHours,
      category: template.category,
      tips: template.tips,
      icon: template.icon,
      color: template.color,
    );
  }

  static String _formatClock(int totalMinutes) {
    final hour24 = (totalMinutes ~/ 60) % 24;
    final minute = totalMinutes % 60;
    final period = hour24 >= 12 ? 'PM' : 'AM';
    final hour12 = hour24 % 12 == 0 ? 12 : hour24 % 12;
    final minStr = minute.toString().padLeft(2, '0');
    return '${hour12.toString().padLeft(2, '0')}:$minStr $period';
  }

  static List<_AttractionTemplate> _getCandidatesForDestination(
    String destination,
    int dayIndex,
    List<String> userInterests,
  ) {
    final destLower = destination.toLowerCase();

    // 1. PENANG
    if (destLower.contains('penang') || destLower.contains('george town')) {
      return [
        const _AttractionTemplate(
          title: 'George Town Street Art & Murals',
          category: 'Culture',
          note: 'UNESCO World Heritage street art trail',
          description:
              'Explore world-famous interactive murals by Ernest Zacharevic hidden across vibrant heritage Armenian Street shophouses.',
          durationMinutes: 90,
          openingHours: 'Open 24 hours',
          tips: [
            'Rent a bicycle for easy travel',
            'Wear sun protection',
            'Photograph Kids on Bicycle',
          ],
          icon: Icons.brush_outlined,
          color: Color(0xFF0D9488),
        ),
        const _AttractionTemplate(
          title: 'Cheong Fatt Tze Blue Mansion',
          category: 'Culture',
          note: '19th-century indigo heritage courtyard',
          description:
              'An architectural marvel blending traditional Chinese courtyard design with Western stained glass windows and Feng Shui principles.',
          durationMinutes: 75,
          openingHours: 'Daily, 10:00 AM - 5:00 PM',
          tips: [
            'Join the guided architectural tour',
            'Take photos by the courtyard fountain',
            'Stunning indigo blue walls',
          ],
          icon: Icons.account_balance,
          color: Color(0xFF2563EB),
        ),
        const _AttractionTemplate(
          title: 'Lunch at Gurney Drive Hawkers',
          category: 'Food',
          note: 'Legendary Penang street food capital',
          description:
              'Savor world-famous Penang Char Kway Teow, Assam Laksa, Rojak, and crispy Oyster Omelettes.',
          durationMinutes: 75,
          openingHours: 'Daily, 11:00 AM - 11:00 PM',
          tips: [
            'Ask for duck egg in Char Kway Teow',
            'Try fresh nutmeg juice',
            'Pair sweet and spicy snacks',
          ],
          icon: Icons.restaurant,
          color: Color(0xFFFF8A3D),
          isMeal: true,
        ),
        const _AttractionTemplate(
          title: 'Kek Lok Si Temple',
          category: 'Culture',
          note: 'Largest Buddhist temple complex in Malaysia',
          description:
              'Sprawling temple complex perched on the hillside of Air Itam, featuring the magnificent 36-meter bronze statue of Kuan Yin and the 7-tier Pagoda of Ten Thousand Buddhas.',
          durationMinutes: 105,
          openingHours: 'Daily, 8:30 AM - 5:30 PM',
          tips: [
            'Ride the incline lift to Kuan Yin statue',
            'Wear respectful clothing',
            'Climb the 7-tier pagoda for hill views',
          ],
          icon: Icons.temple_buddhist,
          color: Color(0xFFDC2626),
        ),
        const _AttractionTemplate(
          title: 'Penang Hill Funicular & Habitat',
          category: 'Nature',
          note: 'Panoramic island views & 130-million-year rainforest',
          description:
              'Ascend 833 meters on the modern funicular railway to enjoy cool highland breezes, the Curtis Crest treetop walk, and sweeping views over the Penang Straits.',
          durationMinutes: 120,
          openingHours: 'Daily, 6:30 AM - 10:00 PM',
          tips: [
            'Fast-track pass recommended on weekends',
            'Sweater recommended for cool breeze',
            'Visit Curtis Crest for 360° sunset panorama',
          ],
          icon: Icons.landscape,
          color: Color(0xFF16A34A),
        ),
        const _AttractionTemplate(
          title: 'Dinner at Chulia Street Hawker Stalls',
          category: 'Food',
          note: 'Historic street food night bazaar',
          description:
              'End the day sampling iconic Wanton Mee, Curry Mee, and refreshing herbal tea under the glow of historic shophouses.',
          durationMinutes: 90,
          openingHours: 'Daily, 6:00 PM - 12:00 AM',
          tips: [
            'Order Wanton Mee with pickled green chillies',
            'Try herbal dessert soup',
            'Walk down Love Lane after dinner',
          ],
          icon: Icons.nightlife,
          color: Color(0xFFEA580C),
          isMeal: true,
        ),
      ];
    }

    // 2. MELAKA
    if (destLower.contains('melaka') || destLower.contains('malacca')) {
      return [
        const _AttractionTemplate(
          title: 'Dutch Square & Christ Church',
          category: 'Culture',
          note: '18th-century red terracotta colonial landmarks',
          description:
              'The historic heart of Melaka featuring the Stadthuys, Queen Victoria Fountain, Christ Church, and vibrant decorated trishaws.',
          durationMinutes: 75,
          openingHours: 'Open 24 hours (Museums: 9:00 AM - 5:00 PM)',
          tips: [
            'Best morning photos before tour crowds',
            'Hire a colorful musical trishaw',
            'Walk across to the river promenade',
          ],
          icon: Icons.church,
          color: Color(0xFFDC2626),
        ),
        const _AttractionTemplate(
          title: 'A Famosa & St. Paul’s Hill',
          category: 'Culture',
          note: '1511 Portuguese fortress ruins',
          description:
              'Explore the iconic Porta de Santiago gateway built by the Portuguese in 1511, followed by a shaded climb up St. Paul’s Hill with views of the Malacca Strait.',
          durationMinutes: 80,
          openingHours: 'Open 24 hours',
          tips: [
            'Wear comfortable walking shoes for steps',
            'Listen to local hill buskers',
            'Historical gravestones inside church ruins',
          ],
          icon: Icons.castle,
          color: Color(0xFF7C3AED),
        ),
        const _AttractionTemplate(
          title: 'Lunch at Jonker Street Heritage Cafe',
          category: 'Food',
          note: 'Authentic Peranakan Nyonya cuisine',
          description:
              'Enjoy signature Chicken Rice Balls, Nyonya Laksa, Ayam Pongteh, and creamy Gula Melaka Cendol.',
          durationMinutes: 75,
          openingHours: 'Daily, 11:00 AM - 9:00 PM',
          tips: [
            'Try authentic Nyonya Laksa',
            'Order ice-cold Gula Melaka Cendol',
            'Heritage shophouse ambiance',
          ],
          icon: Icons.restaurant,
          color: Color(0xFFFF8A3D),
          isMeal: true,
        ),
        const _AttractionTemplate(
          title: 'Baba & Nyonya Heritage Museum',
          category: 'Culture',
          note: 'Exquisite 19th-century Peranakan townhouses',
          description:
              'Walk through three adjoining ancestral terraced townhouses showcasing antique teak furniture, porcelain, and authentic Peranakan lifestyles.',
          durationMinutes: 75,
          openingHours: 'Tue - Sun, 10:00 AM - 5:00 PM',
          tips: [
            'Guided tours provide rich family stories',
            'No indoor photography allowed',
            'Observe intricate gold-leaf woodwork',
          ],
          icon: Icons.museum,
          color: Color(0xFF0D9488),
        ),
        const _AttractionTemplate(
          title: 'Melaka River Cruise',
          category: 'Nature',
          note: '45-minute scenic heritage waterway journey',
          description:
              'Glide along the winding Melaka River past colorful street art murals, historic bridges, and traditional Kampung Morten wooden houses.',
          durationMinutes: 60,
          openingHours: 'Daily, 9:00 AM - 11:00 PM',
          tips: [
            'Late afternoon cruise offers gentle breeze',
            'Look out for giant street art murals',
            'Board at Muara Jetty near Maritime Museum',
          ],
          icon: Icons.directions_boat,
          color: Color(0xFF0284C7),
        ),
        const _AttractionTemplate(
          title: 'Jonker Walk Heritage Night Market',
          category: 'Food',
          note: 'Weekend street bazaar & artisan crafts',
          description:
              'Experience Malaysia’s most famous weekend market packed with street food, coconut shakes, quail egg skewers, and lively street performances.',
          durationMinutes: 90,
          openingHours: 'Fri - Sun, 6:00 PM - 12:00 AM',
          tips: [
            'Try freshly made Coconut Shake',
            'Bring small cash bills',
            'Live cultural stage shows at end of street',
          ],
          icon: Icons.nightlife,
          color: Color(0xFFEA580C),
          isMeal: true,
        ),
      ];
    }

    // 3. JOHOR
    if (destLower.contains('johor')) {
      final dayNum = (dayIndex % 3) + 1;
      switch (dayNum) {
        case 2:
          return [
            const _AttractionTemplate(
              title: 'The Mall, Mid Valley Southkey',
              category: 'Shopping Mall',
              note: 'Premier indoor shopping & lifestyle destination',
              description:
                  'Expansive air-conditioned indoor mega-mall in Johor Bahru featuring major retail brands, cinema, local dining, and family entertainment.',
              durationMinutes: 120,
              openingHours: 'Daily, 10:00 AM - 10:00 PM',
              tips: [
                'Over 300 international and local stores',
                'Fully air-conditioned indoor comfort',
                'Excellent rainy-day shopping & dining',
              ],
              icon: Icons.shopping_bag,
              color: Color(0xFFD97706),
              latitude: 1.5002,
              longitude: 103.7773,
            ),
            const _AttractionTemplate(
              title: 'Johor Bahru Chinese Heritage Museum',
              category: 'Museum',
              note: 'Air-conditioned 4-storey cultural legacy museum',
              description:
                  'Rich cultural museum downtown documenting the heritage, traditions, and early pioneer history of the Chinese community in Johor Bahru.',
              durationMinutes: 75,
              openingHours: 'Tue - Sun, 9:00 AM - 5:00 PM',
              tips: [
                'Explore all 4 floors of heritage artifacts',
                'Fully air-conditioned indoor gallery',
                'Short walk from Tan Hiok Nee street',
              ],
              icon: Icons.museum,
              color: Color(0xFF0D9488),
              latitude: 1.4563,
              longitude: 103.7640,
            ),
            const _AttractionTemplate(
              title: 'Johor Bahru City Square',
              category: 'Shopping Mall',
              note: 'Multi-level indoor shopping & entertainment center',
              description:
                  'Vibrant indoor shopping mall near the Causeway featuring a wide array of fashion outlets, restaurants, and entertainment.',
              durationMinutes: 90,
              openingHours: 'Daily, 10:00 AM - 10:00 PM',
              tips: [
                'Directly linked to JB Sentral',
                'Diverse indoor food court & cafes',
                'Popular rainy day lifestyle hub',
              ],
              icon: Icons.local_mall,
              color: Color(0xFF2563EB),
              latitude: 1.4626,
              longitude: 103.7638,
            ),
            const _AttractionTemplate(
              title: 'Legoland Malaysia Resort',
              category: 'Theme Park',
              note: 'Asia’s premier interactive Lego theme & water park',
              description:
                  'Over 70 hands-on rides, roller coasters, water slides, and incredible Miniland Asian landmarks built from Lego bricks.',
              durationMinutes: 180,
              openingHours: 'Daily, 10:00 AM - 6:00 PM',
              tips: [
                'Arrive early for popular coasters',
                'Bring swimwear for the water park',
                'Download mobile app for live wait times',
              ],
              icon: Icons.attractions,
              color: Color(0xFFE11D48),
              latitude: 1.4273,
              longitude: 103.6299,
            ),
            const _AttractionTemplate(
              title: 'Lunch at Medini Mall & Dining',
              category: 'Food',
              note: 'Modern air-conditioned dining hub near Legoland',
              description:
                  'Convenient mall directly opposite Legoland entrance featuring local Malaysian delicacies, cafes, and family restaurants.',
              durationMinutes: 75,
              openingHours: 'Daily, 10:00 AM - 9:00 PM',
              tips: [
                'Direct walkway from Legoland',
                'Family-friendly meal choices',
                'Air-conditioned comfort',
              ],
              icon: Icons.restaurant,
              color: Color(0xFFFF8A3D),
              isMeal: true,
              latitude: 1.4290,
              longitude: 103.6335,
            ),
            const _AttractionTemplate(
              title: 'Puteri Harbour Marina Walk',
              category: 'Nature',
              note: 'Scenic coastal marina promenade & yachts',
              description:
                  'Picturesque waterfront walkway overlooking Straits of Johor with luxury yachts, open-air cafes, and refreshing sea breeze.',
              durationMinutes: 75,
              openingHours: 'Daily, 10:00 AM - 10:00 PM',
              tips: [
                'Great waterfront photo views',
                'Relaxing afternoon breeze',
                'Sunset yacht views',
              ],
              icon: Icons.directions_boat,
              color: Color(0xFF0284C7),
              latitude: 1.4175,
              longitude: 103.6558,
            ),
            const _AttractionTemplate(
              title: 'Danga Bay Waterfront Promenade',
              category: 'Nature',
              note: 'Coastal sea breeze & waterfront boardwalk',
              description:
                  'Scenic recreational park along the Johor coast offering relaxing walks, boat views, and family-friendly sights.',
              durationMinutes: 90,
              openingHours: 'Daily, 3:00 PM - 11:00 PM',
              tips: [
                'Great sea breeze near sunset',
                'Theme park rides for kids',
                'Scenic boardwalk photos',
              ],
              icon: Icons.water,
              color: Color(0xFF16A34A),
              latitude: 1.4747,
              longitude: 103.7226,
            ),
            const _AttractionTemplate(
              title: 'Dinner at Senibong Cove Seafood Village',
              category: 'Food',
              note: 'Seaside dining overlooking Johor Straits',
              description:
                  'Famous waterfront seafood village known for chili crab, butter prawns, grilled fish, and scenic views across to Singapore.',
              durationMinutes: 90,
              openingHours: 'Daily, 5:00 PM - 11:30 PM',
              tips: [
                'Book outdoor seaside table for sunset',
                'Must try black pepper crab',
                'Live seafood selection',
              ],
              icon: Icons.nightlife,
              color: Color(0xFFEA580C),
              isMeal: true,
              latitude: 1.4880,
              longitude: 103.8290,
            ),
          ];

        case 3:
          return [
            const _AttractionTemplate(
              title: 'Kota Tinggi Waterfalls',
              category: 'Nature',
              note: 'Cascading natural falls at Gunung Muntahak',
              description:
                  'Scenic 34-meter natural cascading waterfall surrounded by lush tropical rainforest, natural pools, and cooling mountain streams.',
              durationMinutes: 120,
              openingHours: 'Daily, 9:00 AM - 5:00 PM',
              tips: [
                'Bring swimwear and waterproof pouch',
                'Natural cooling mountain water',
                'Wear slip-resistant footwear',
              ],
              icon: Icons.landscape,
              color: Color(0xFF16A34A),
              latitude: 1.8322,
              longitude: 103.8327,
            ),
            const _AttractionTemplate(
              title: 'Lunch at Kota Tinggi Local Delights',
              category: 'Food',
              note: 'Traditional bak kut teh & heritage noodles',
              description:
                  'Famous claypot herbal bak kut teh, river prawns, and fragrant local coffee in heritage town of Kota Tinggi.',
              durationMinutes: 75,
              openingHours: 'Daily, 10:00 AM - 8:30 PM',
              tips: [
                'Try claypot herbal soup with fried dough',
                'Local Hainanese toast and coffee',
                'Casual friendly service',
              ],
              icon: Icons.restaurant,
              color: Color(0xFFFF8A3D),
              isMeal: true,
              latitude: 1.7300,
              longitude: 103.8990,
            ),
            const _AttractionTemplate(
              title: 'Desaru Coast Beach & Promenade',
              category: 'Nature',
              note: 'Pristine 22km golden sand coastline',
              description:
                  'Sweeping sandy shores along the South China Sea offering gentle waves, beach walks, and tropical resort relaxation.',
              durationMinutes: 105,
              openingHours: 'Daily, 8:00 AM - 7:00 PM',
              tips: [
                'Wide open golden sand beach',
                'Great for relaxing coastal strolls',
                'Sun protection recommended',
              ],
              icon: Icons.beach_access,
              color: Color(0xFF0D9488),
              latitude: 1.5458,
              longitude: 104.2625,
            ),
            const _AttractionTemplate(
              title: 'The Mall, Mid Valley Southkey',
              category: 'Shopping Mall',
              note: 'Premier indoor shopping & lifestyle destination',
              description:
                  'Expansive air-conditioned indoor mega-mall in Johor Bahru featuring major retail brands, cinema, local dining, and family entertainment.',
              durationMinutes: 120,
              openingHours: 'Daily, 10:00 AM - 10:00 PM',
              tips: [
                'Over 300 international and local stores',
                'Fully air-conditioned indoor comfort',
                'Excellent rainy-day shopping & dining',
              ],
              icon: Icons.shopping_bag,
              color: Color(0xFFD97706),
              latitude: 1.5002,
              longitude: 103.7773,
            ),
            const _AttractionTemplate(
              title: 'Johor Premium Outlets (JPO)',
              category: 'Shopping',
              note: 'Southeast Asia’s first luxury outlet center',
              description:
                  'Open-air designer shopping haven featuring over 150 brand-name stores offering daily discounts in a modern landscaped center.',
              durationMinutes: 120,
              openingHours: 'Daily, 10:00 AM - 10:00 PM',
              tips: [
                'Over 150 designer brand stores',
                'Open-air landscaped mall with dining',
                'Comfortable covered walkways',
              ],
              icon: Icons.shopping_bag,
              color: Color(0xFF7C3AED),
              latitude: 1.6022,
              longitude: 103.6200,
            ),
            const _AttractionTemplate(
              title: 'Dinner at Meldrum Night Food Street',
              category: 'Food',
              note: 'Bustling downtown JB street gastronomy',
              description:
                  'Famous culinary back-alley in Johor Bahru renowned for barbecue chicken wings, fried kway teow, and crispy oyster omelettes.',
              durationMinutes: 80,
              openingHours: 'Daily, 5:00 PM - 11:30 PM',
              tips: [
                'Signature BBQ chicken wings',
                'Authentic local street atmosphere',
                'Short walk from JB Sentral',
              ],
              icon: Icons.nightlife,
              color: Color(0xFFEA580C),
              isMeal: true,
              latitude: 1.4600,
              longitude: 103.7660,
            ),
          ];

        default: // Day 1
          return [
            const _AttractionTemplate(
              title: 'Sultan Abu Bakar State Mosque',
              category: 'Culture',
              note: 'Victorian-Moorish architectural heritage',
              description:
                  'Overlooking the Straits of Johor, this 19th-century royal mosque features ornate minarets resembling British clocktowers.',
              durationMinutes: 75,
              openingHours: 'Daily, 9:00 AM - 5:00 PM',
              tips: [
                'Dress respectfully',
                'Stunning strait views',
                'Quiet morning atmosphere',
              ],
              icon: Icons.account_balance,
              color: Color(0xFF0D9488),
              latitude: 1.4569555555556,
              longitude: 103.75105277778,
            ),
            const _AttractionTemplate(
              title: 'Johor Zoo',
              category: 'Nature',
              note: 'Historic wildlife zoological gardens',
              description:
                  'One of the oldest zoos in Asia, featuring tropical birds, big cats, primates, and shaded walking paths near the royal palace.',
              durationMinutes: 75,
              openingHours: 'Daily, 9:00 AM - 5:00 PM',
              tips: [
                'Directly adjacent to State Mosque',
                'Shaded morning animal exhibits',
                'Family friendly walking paths',
              ],
              icon: Icons.pets,
              color: Color(0xFF16A34A),
              latitude: 1.4575,
              longitude: 103.75225,
            ),
            const _AttractionTemplate(
              title: 'Lunch at Johor Bahru Heritage Food Trail',
              category: 'Food',
              note: 'Traditional Hainanese chicken & noodles',
              description:
                  'Enjoy traditional JB-style Mee Rebus, fresh charcoal toast, aromatic kopi, and herbal duck noodles.',
              durationMinutes: 75,
              openingHours: 'Daily, 11:30 AM - 9:00 PM',
              tips: [
                'Pair charcoal toast with soft boiled eggs',
                'Try Johor style Mee Rebus',
                'Air-conditioned dining',
              ],
              icon: Icons.restaurant,
              color: Color(0xFFFF8A3D),
              isMeal: true,
              latitude: 1.4560,
              longitude: 103.7630,
            ),
            const _AttractionTemplate(
              title: 'Tan Hiok Nee Cultural Street',
              category: 'Culture',
              note: 'Heritage shophouses & artisan cafes',
              description:
                  'A vibrant heritage zone preserving traditional bakeries, antique stores, and modern lifestyle coffee shops in downtown Johor Bahru.',
              durationMinutes: 80,
              openingHours: 'Daily, 9:00 AM - 6:00 PM',
              tips: [
                'Buy charcoal banana bread at Hiap Joo',
                'Visit the Red House',
                'Pedestrian friendly walk',
              ],
              icon: Icons.storefront,
              color: Color(0xFF2563EB),
              latitude: 1.4566,
              longitude: 103.7638,
            ),
            const _AttractionTemplate(
              title: 'Johor Bahru Chinese Heritage Museum',
              category: 'Museum',
              note: 'Air-conditioned 4-storey cultural legacy museum',
              description:
                  'Rich cultural museum downtown documenting the heritage, traditions, and early pioneer history of the Chinese community in Johor Bahru.',
              durationMinutes: 75,
              openingHours: 'Tue - Sun, 9:00 AM - 5:00 PM',
              tips: [
                'Explore all 4 floors of heritage artifacts',
                'Fully air-conditioned indoor gallery',
                'Short walk from Tan Hiok Nee street',
              ],
              icon: Icons.museum,
              color: Color(0xFF0D9488),
              latitude: 1.4563,
              longitude: 103.7640,
            ),
            const _AttractionTemplate(
              title: 'Arulmigu Sri Rajakaliamman Glass Temple',
              category: 'Culture',
              note: 'Unique glass-mosaic Hindu sanctuary',
              description:
                  'World-famous Hindu temple covered in nearly 300,000 pieces of sparkling colored glass imported from Thailand and Belgium.',
              durationMinutes: 60,
              openingHours: 'Daily, 9:00 AM - 6:00 PM',
              tips: [
                'Spectacular glass mosaic interior',
                'Shoe removal required before entering',
                'Unique cultural architecture in JB',
              ],
              icon: Icons.temple_hindu,
              color: Color(0xFF7C3AED),
              latitude: 1.46861111,
              longitude: 103.75972222,
            ),
            const _AttractionTemplate(
              title: 'Dinner at Pasar Karat Night Bazaar',
              category: 'Food',
              note: 'Evening vintage market & street food',
              description:
                  'Vibrant night bazaar stretching through central JB streets with local skewers, roti john, and vintage shopping.',
              durationMinutes: 90,
              openingHours: 'Daily, 6:00 PM - 12:00 AM',
              tips: [
                'Bargain gently for vintage items',
                'Try grilled satay skewers',
                'Short walk from CIQ complex',
              ],
              icon: Icons.nightlife,
              color: Color(0xFFEA580C),
              isMeal: true,
              latitude: 1.4583,
              longitude: 103.7645,
            ),
          ];
      }
    }

    // 4. SABAH
    if (destLower.contains('sabah') || destLower.contains('kinabalu')) {
      return [
        const _AttractionTemplate(
          title: 'Kota Kinabalu City Floating Mosque',
          category: 'Culture',
          note: 'Contemporary Islamic architecture on a lagoon',
          description:
              'Surrounded by a serene man-made lagoon, this picturesque mosque reflects traditional blue and gold domes on still waters.',
          durationMinutes: 75,
          openingHours: 'Daily, 8:00 AM - 5:00 PM',
          tips: [
            'Rent traditional garments at entrance',
            'Best reflection photos on quiet mornings',
            'Walk around the outer lagoon boardwalk',
          ],
          icon: Icons.account_balance,
          color: Color(0xFF0284C7),
        ),
        const _AttractionTemplate(
          title: 'Tunku Abdul Rahman Marine Park',
          category: 'Nature',
          note: 'Tropical island coral reef adventure',
          description:
              'Take a quick 15-minute boat ride from Jesselton Point to Manukan or Sapi Island for crystal-clear snorkeling and soft white beaches.',
          durationMinutes: 135,
          openingHours: 'Daily, 8:30 AM - 4:30 PM',
          tips: [
            'Bring underwater camera for clownfish',
            'Book boat transfers at Jesselton Point',
            'Watch out for gentle monitor lizards',
          ],
          icon: Icons.beach_access,
          color: Color(0xFF10B981),
        ),
        const _AttractionTemplate(
          title: 'Lunch at Gaya Street Seafood Delicacies',
          category: 'Food',
          note: 'Fresh Sabah ocean catch & Tuaran mee',
          description:
              'Feast on freshly caught tiger prawns, steamed fish, local wild ferns (sayur manis), and wok-fried Tuaran egg noodles.',
          durationMinutes: 75,
          openingHours: 'Daily, 11:00 AM - 9:00 PM',
          tips: [
            'Try local sayur manis with eggs',
            'Order fresh Sabah lime juice',
            'Tuaran mee is a must-try',
          ],
          icon: Icons.restaurant,
          color: Color(0xFFFF8A3D),
          isMeal: true,
        ),
        const _AttractionTemplate(
          title: 'Mari Mari Cultural Village',
          category: 'Culture',
          note: 'Interactive indigenous ethnic tribal culture',
          description:
              'Explore traditional longhouses representing five indigenous Bornean tribes with blowpipe demonstrations and bamboo cooking.',
          durationMinutes: 105,
          openingHours: 'Daily, 10:00 AM - 5:00 PM',
          tips: [
            'Try traditional rice wine tasting',
            'Watch the Murut Lansaran trampoline jump',
            'Participate in fire-starting demo',
          ],
          icon: Icons.people_outline,
          color: Color(0xFF7C3AED),
        ),
        const _AttractionTemplate(
          title: 'Tanjung Aru Sunset Beach & Night Food',
          category: 'Food',
          note: 'World top-tier tropical sunset & night stalls',
          description:
              'Witness one of the world’s most celebrated tropical sunsets over the South China Sea followed by fresh avocado shakes and grilled seafood.',
          durationMinutes: 100,
          openingHours: 'Daily, 4:00 PM - 11:00 PM',
          tips: [
            'Arrive by 5:30 PM for prime sunset spot',
            'Order special 3-layer fruit juice',
            'Try Sabah chicken wings and grilled corn',
          ],
          icon: Icons.nightlife,
          color: Color(0xFFEA580C),
          isMeal: true,
        ),
      ];
    }

    // 5. DEFAULT / KUALA LUMPUR
    final dayNum = (dayIndex % 4) + 1;
    switch (dayNum) {
      case 2:
        return [
          const _AttractionTemplate(
            title: 'Thean Hou Temple',
            category: 'Culture',
            note: 'Ornate 6-tier temple with KL city panoramas',
            description:
                'A magnificent Chinese temple blending contemporary architectural styles with traditional designs and skyline views.',
            durationMinutes: 80,
            openingHours: 'Daily, 8:00 AM - 8:00 PM',
            tips: [
              'Climb to top floor for best photo',
              'Quiet prayer areas',
              'Free admission',
            ],
            icon: Icons.temple_buddhist,
            color: Color(0xFFDC2626),
          ),
          const _AttractionTemplate(
            title: 'Islamic Arts Museum',
            category: 'Culture',
            note: 'Southeast Asia’s largest Islamic art museum',
            description:
                'Showcases intricate calligraphy, scale models of famous world mosques, jewellery, and textiles.',
            durationMinutes: 90,
            openingHours: 'Daily, 9:30 AM - 6:00 PM',
            tips: [
              'Air-conditioned comfort',
              'Museum cafe available',
              'Great architecture',
            ],
            icon: Icons.museum,
            color: Color(0xFF0D9488),
          ),
          const _AttractionTemplate(
            title: 'Lunch at Petaling Street',
            category: 'Food',
            note: 'Chinatown heritage noodles & Kwai Chai Hong',
            description:
                'Explore historic shophouse alleyways with 1960s murals, famous roast duck, and refreshing soya bean drinks.',
            durationMinutes: 75,
            openingHours: 'Daily, 10:00 AM - 9:00 PM',
            tips: [
              'Try Madam Tang muah chee',
              'Visit Kwai Chai Hong murals',
              'Wear comfortable walking shoes',
            ],
            icon: Icons.restaurant,
            color: Color(0xFFEA580C),
            isMeal: true,
          ),
          const _AttractionTemplate(
            title: 'Merdeka Square',
            category: 'Culture',
            note: 'Historic Sultan Abdul Samad Building',
            description:
                'The birthplace of Malaysian independence featuring Moorish-style colonial architecture and a 95m flagpole.',
            durationMinutes: 75,
            openingHours: 'Open 24 hours',
            tips: [
              'Iconic photo backdrop',
              'River of Life nearby',
              'Best in late afternoon light',
            ],
            icon: Icons.account_balance,
            color: Color(0xFF2563EB),
          ),
          const _AttractionTemplate(
            title: 'KL Tower Sky Deck',
            category: 'Landmark',
            note: '360° open-air panoramic sunset view',
            description:
                'Seventh-tallest freestanding tower in the world with an open-air Sky Deck and thrilling glass Sky Boxes.',
            durationMinutes: 90,
            openingHours: 'Daily, 9:00 AM - 10:00 PM',
            tips: [
              'Catch the golden hour sunset',
              'Book Sky Box tickets ahead',
              'Eco-park forest nearby',
            ],
            icon: Icons.location_city,
            color: Color(0xFF7C3AED),
          ),
        ];

      case 3:
        return [
          const _AttractionTemplate(
            title: 'Aquaria KLCC',
            category: 'Nature',
            note: '90-meter underwater moving walkway',
            description:
                'World-class oceanarium with over 5,000 land and aquatic creatures including sand tiger sharks and sea turtles.',
            durationMinutes: 90,
            openingHours: 'Daily, 10:00 AM - 8:00 PM',
            tips: [
              'Check daily feeding show times',
              'Direct air-con link to KLCC',
              'Book online for discounts',
            ],
            icon: Icons.water,
            color: Color(0xFF0284C7),
          ),
          const _AttractionTemplate(
            title: 'Lunch at Lot 10 Hutong',
            category: 'Food',
            note: 'Legendary gourmet heritage food village',
            description:
                'Home to generational street food stalls gathered under one roof, famous for Hokkien mee and beef noodles.',
            durationMinutes: 75,
            openingHours: 'Daily, 10:00 AM - 10:00 PM',
            tips: [
              'Kim Lian Kee charcoal noodles',
              'Hon Kee porridge',
              'Air-conditioned dining',
            ],
            icon: Icons.lunch_dining,
            color: Color(0xFFE11D48),
            isMeal: true,
          ),
          const _AttractionTemplate(
            title: 'Pavilion Kuala Lumpur',
            category: 'Shopping',
            note: 'Bukit Bintang premier luxury retail hub',
            description:
                'Malaysia’s leading shopping mall with over 700 stores, Tokyo Street cultural zone, and iconic Crystal Fountain.',
            durationMinutes: 105,
            openingHours: 'Daily, 10:00 AM - 10:00 PM',
            tips: [
              'Explore Level 6 Tokyo Street',
              'Great indoor stop if it rains',
              'Currency exchange available',
            ],
            icon: Icons.shopping_bag,
            color: Color(0xFFD97706),
          ),
          const _AttractionTemplate(
            title: 'Saloma Link Bridge & Dinner',
            category: 'Food',
            note: 'Illuminated bridge & Kampung Baru food',
            description:
                'Admire the LED light show on Saloma Bridge followed by traditional Malaysian dinner in historic Kampung Baru.',
            durationMinutes: 90,
            openingHours: 'Open daily until midnight',
            tips: [
              'Spectacular view of Twin Towers',
              'Stunning night photo spot',
              'Try nasi lemak Wanjo',
            ],
            icon: Icons.nightlife,
            color: Color(0xFF4F46E5),
            isMeal: true,
          ),
        ];

      default:
        // Day 1 Standard
        return [
          const _AttractionTemplate(
            title: 'Batu Caves',
            category: 'Culture',
            note: 'Limestone caves & golden Murugan statue',
            description:
                'A famous limestone hill with Hindu temples, colorful 272 steps, cultural photo spots and a light morning climb.',
            durationMinutes: 90,
            openingHours: 'Daily, 7:00 AM - 9:00 PM',
            tips: [
              'Wear comfortable shoes',
              'Watch out for cheeky monkeys',
              'Dress respectfully covering knees and shoulders',
            ],
            icon: Icons.temple_buddhist,
            color: Color(0xFF2563EB),
          ),
          const _AttractionTemplate(
            title: 'Central Market & Pasar Seni',
            category: 'Culture',
            note: 'Heritage handicrafts, batik & local gifts',
            description:
                'A 1930s Art Deco heritage building celebrating Malaysian arts, batik painting, wood carvings, and souvenir stalls.',
            durationMinutes: 75,
            openingHours: 'Daily, 10:00 AM - 10:00 PM',
            tips: [
              'Try batik painting workshop',
              'Compare wood carvings',
              'Air-conditioned escape from heat',
            ],
            icon: Icons.storefront,
            color: AppColors.teal,
          ),
          const _AttractionTemplate(
            title: 'Lunch at Jalan Alor',
            category: 'Food',
            note: 'Vibrant hawker street & local specialties',
            description:
                'Iconic food street bustling with wok-tossed noodles, barbecue chicken wings, coconut ice cream, and satay.',
            durationMinutes: 75,
            openingHours: 'Daily, 11:00 AM - 12:00 AM',
            tips: [
              'Check stall menu prices first',
              'Share dishes among your group',
              'Try fresh sugar cane juice',
            ],
            icon: Icons.restaurant,
            color: Color(0xFFFF8A3D),
            isMeal: true,
          ),
          const _AttractionTemplate(
            title: 'Petronas Twin Towers',
            category: 'Landmark',
            note: 'World’s tallest twin towers & Skybridge',
            description:
                'An iconic 88-floor modern architectural wonder with a double-decker Skybridge connecting both towers and observation deck.',
            durationMinutes: 90,
            openingHours: 'Tue - Sun, 9:00 AM - 9:00 PM',
            tips: [
              'Pre-book Skybridge tickets online',
              'Look straight up from base for photo',
              'Direct tunnel link to KLCC LRT station',
            ],
            icon: Icons.location_city,
            color: AppColors.primary,
          ),
          const _AttractionTemplate(
            title: 'KLCC Park & Symphony Fountain',
            category: 'Nature',
            note: 'Evening skyline stroll & fountain water show',
            description:
                'A lush 50-acre tropical garden with walking tracks, reflecting pools, and the Lake Symphony musical light show.',
            durationMinutes: 60,
            openingHours: 'Daily, 7:00 AM - 10:00 PM',
            tips: [
              'Music & fountain show runs at 8:00 PM & 9:00 PM',
              'Spectacular sunset skyline backdrop',
              'Paved jogging path',
            ],
            icon: Icons.park,
            color: Color(0xFF16A34A),
          ),
        ];
    }
  }
}
