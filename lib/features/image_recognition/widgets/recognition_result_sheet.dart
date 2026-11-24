import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:smart_travel_planner/features/image_recognition/data/scan_place_facts.dart';
import 'package:smart_travel_planner/features/image_recognition/data/visual_scan_results.dart';
import 'package:smart_travel_planner/features/image_recognition/models/recognition_result.dart';
import 'package:smart_travel_planner/features/image_recognition/services/recognition_clues.dart';
import 'package:smart_travel_planner/features/image_recognition/services/image_recognition_service.dart';
import 'package:smart_travel_planner/features/image_recognition/widgets/scan_photo_guidance.dart';
import 'package:smart_travel_planner/features/image_recognition/widgets/scan_distance_label.dart';
import 'package:smart_travel_planner/features/image_recognition/widgets/visual_scan_style.dart';
import 'package:smart_travel_planner/features/places/screens/attraction_detail_page.dart';
import 'package:smart_travel_planner/features/places/models/google_place_details.dart';
import 'package:smart_travel_planner/features/places/services/google_places_service.dart';
import 'package:smart_travel_planner/features/places/services/place_wishlist_store.dart';
import 'package:smart_travel_planner/features/places/widgets/google_maps_attribution.dart';
import 'package:smart_travel_planner/features/places/widgets/google_place_image.dart';
import 'package:smart_travel_planner/shared/models/attraction.dart';
import 'package:smart_travel_planner/shared/services/location_service.dart';
import 'package:smart_travel_planner/features/itinerary/services/scan_plan_places_store.dart';
import 'package:smart_travel_planner/features/places/utils/attraction_image_resolver.dart';
import 'package:smart_travel_planner/l10n/localized_labels.dart';

class RecognitionResultSheet extends StatefulWidget {
  const RecognitionResultSheet({
    super.key,
    required this.result,
    required this.service,
    required this.onNewScan,
    this.onBack,
    this.onOpenWishlist,
    this.onOpenPlan,
    this.photo,
    this.onReferenceSelected,
    this.onTakeAnotherPhoto,
    this.onUploadAnotherPhoto,
    this.userId = 'guest',
  });

  final RecognitionResult result;
  final ImageRecognitionService service;
  final VoidCallback onNewScan;
  final VoidCallback? onBack;
  final VoidCallback? onOpenWishlist;
  final VoidCallback? onOpenPlan;
  final ImageProvider<Object>? photo;
  final ValueChanged<String>? onReferenceSelected;
  final VoidCallback? onTakeAnotherPhoto;
  final VoidCallback? onUploadAnotherPhoto;
  final String userId;

  @override
  State<RecognitionResultSheet> createState() => _RecognitionResultSheetState();
}

enum _SpotFilter { all, food, attractions }

class _RecognitionResultSheetState extends State<RecognitionResultSheet> {
  late final _origin = scanLandmark(widget.result);
  LatLng? _resolvedOrigin;
  LatLng? _currentGps = LocationService().isUsingRealGps
      ? LocationService().currentLocation
      : null;
  late final _spots = scanSpots(widget.result, _origin);
  final _translations = <String, Future<RecognitionResult>>{};
  final _lookupJobs = <String, Future<GooglePlaceDetails?>>{};
  final _nearbyJobs = <_SpotFilter, Future<List<GooglePlaceDetails>>>{};
  late final _googlePlaces = GooglePlacesService();
  late final _planPlaces = ScanPlanPlacesStore(widget.userId);
  Set<String> _saved = {};
  bool _saving = false;
  bool _adding = false;
  bool _openingDetails = false;
  _SpotFilter _filter = _SpotFilter.all;

  PlaceWishlistStore get _wishlist => PlaceWishlistStore(widget.userId);

  @override
  void initState() {
    super.initState();
    _loadSaved();
    _planPlaces.addListener(_onPlanPlacesChanged);
    _planPlaces.load();
    _loadCurrentGps();
    if (_origin == null &&
        (widget.result.kind == 'landmark' ||
            widget.result.kind == 'restaurant')) {
      _loadOrigin();
    }
  }

  void _onPlanPlacesChanged() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _planPlaces.removeListener(_onPlanPlacesChanged);
    super.dispose();
  }

  Future<void> _loadCurrentGps() async {
    try {
      final permission = await Geolocator.checkPermission();
      if (permission != LocationPermission.always &&
          permission != LocationPermission.whileInUse) {
        return;
      }
      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.medium,
          timeLimit: Duration(seconds: 8),
        ),
      );
      if (!mounted) return;
      final point = LatLng(position.latitude, position.longitude);
      LocationService().updateLocation(
        point,
        LocationService().currentAreaName,
        isRealGps: true,
      );
      setState(() {
        _currentGps = point;
        _nearbyJobs.clear();
      });
    } catch (_) {
      // Keep the scan usable when device location is unavailable.
    }
  }

  Future<void> _loadOrigin() async {
    final details = await _listing(widget.result.name, widget.result.placeId);
    final latitude = details?.latitude;
    final longitude = details?.longitude;
    if (mounted && latitude != null && longitude != null) {
      setState(() => _resolvedOrigin = LatLng(latitude, longitude));
    }
  }

  Future<void> _loadSaved() async {
    try {
      final places = await _wishlist.load();
      if (mounted && !_saving) {
        setState(() => _saved = places.map((place) => place.xid).toSet());
      }
    } catch (_) {
      // The scan remains usable if local storage is unavailable.
    }
  }

  Future<void> _save(Attraction spot) async {
    if (_saving) return;
    setState(() => _saving = true);
    try {
      final listing =
          !_saved.contains(spot.xid) &&
              spot.latitude == 0 &&
              spot.longitude == 0
          ? await _listing(spot.name, spot.googlePlaceId)
          : null;
      final resolved = listing?.latitude != null && listing?.longitude != null
          ? Attraction(
              xid: spot.xid,
              name: spot.name,
              latitude: listing!.latitude!,
              longitude: listing.longitude!,
              category: spot.category,
              description: spot.description ?? listing.description,
            )
          : spot;
      final places = await _wishlist.toggle(resolved);
      if (mounted) {
        setState(() => _saved = places.map((place) => place.xid).toSet());
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not save this spot. Try again.')),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _story(
    Attraction place, {
    ImageProvider<Object>? photo,
    GooglePlaceDetails? listing,
  }) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => AttractionDetailPage(
          attraction: place,
          showSaveFeedback: false,
          placesService: _googlePlaces,
          isSaved: _saved.contains(place.xid),
          onToggleSaved: (item) {
            _save(item);
            return true;
          },
          heroPhoto: photo,
          initialDetails: listing,
        ),
      ),
    );
  }

  Future<void> _openMapSearch(String query) async {
    final uri = Uri.https('www.google.com', '/maps/search/', {
      'api': '1',
      'query': query,
    });
    try {
      if (await launchUrl(uri, mode: LaunchMode.externalApplication)) return;
    } catch (_) {
      // Show the same message for unavailable and failed map handlers.
    }
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.l10n.unableToOpenGoogleMaps)),
      );
    }
  }

  Future<GooglePlaceDetails?> _listing(String name, [String? id]) =>
      _lookupJobs.putIfAbsent(id ?? name, () async {
        try {
          final summary = id == null
              ? await widget.service.lookupPlace(name)
              : null;
          final placeId = id ?? summary?.id;
          if (placeId == null) return null;
          final details = await _googlePlaces.fetchDetails(placeId);
          return details ?? summary ?? await widget.service.lookupPlace(name);
        } catch (_) {
          return null;
        }
      });

  Future<void> _openSpotDetails(
    ScanSpot spot, [
    GooglePlaceDetails? summary,
  ]) async {
    if (_openingDetails) return;
    _openingDetails = true;
    final place = spot.place;
    try {
      final listing =
          await _listing(place.name, place.googlePlaceId) ?? summary;
      if (!mounted) return;
      _story(
        place,
        listing: listing,
        photo: spot.image == null ? null : AssetImage(spot.image!),
      );
    } finally {
      _openingDetails = false;
    }
  }

  Future<void> _addToItinerary(Attraction place) async {
    if (_adding) return;
    setState(() => _adding = true);
    try {
      final listing = place.latitude == 0 && place.longitude == 0
          ? await _listing(place.name, place.googlePlaceId)
          : null;
      if (!mounted) return;
      final latitude = listing?.latitude ?? place.latitude;
      final longitude = listing?.longitude ?? place.longitude;
      if (latitude == 0 && longitude == 0) {
        _itineraryNotice(context.l10n.scanStopLocationUnavailable);
        return;
      }
      final added = await _planPlaces.add(
        Attraction(
          xid: place.xid,
          name: place.name,
          category: place.category,
          latitude: latitude,
          longitude: longitude,
          description: place.description ?? listing?.description,
        ),
      );
      if (mounted && !added) {
        _itineraryNotice(context.l10n.scanStopAlreadyAdded);
      }
    } catch (_) {
      if (mounted) {
        _itineraryNotice(context.l10n.unableToSaveItineraryChangesOnThisDevice);
      }
    } finally {
      if (mounted) setState(() => _adding = false);
    }
  }

  void _itineraryNotice(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  Widget _itineraryButton(Attraction place) => _ScanButton(
    label: _planPlaces.places.any((item) => item.xid == place.xid)
        ? context.l10n.scanAddedToPlan
        : context.l10n.scanAddToItinerary,
    icon: _planPlaces.places.any((item) => item.xid == place.xid)
        ? Icons.check_rounded
        : Icons.add_outlined,
    compact: true,
    stacked: true,
    onPressed:
        _adding || _planPlaces.places.any((item) => item.xid == place.xid)
        ? null
        : () => _addToItinerary(place),
  );

  Widget _planSelectionPanel() {
    final places = _planPlaces.places;
    return _ResultPanel(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    context.l10n.scanPlanPlaces,
                    style: VisualScanStyle.heading(18),
                  ),
                ),
                if (places.length > 1)
                  TextButton(
                    onPressed: _planPlaces.clear,
                    style: TextButton.styleFrom(
                      visualDensity: VisualDensity.compact,
                      foregroundColor: VisualScanStyle.muted,
                    ),
                    child: Text(context.l10n.clear),
                  ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              places.length == 1
                  ? context.l10n.scanPlanOnePlace
                  : context.l10n.valuePlaces(places.length.toString()),
              style: _supportText,
            ),
            for (final place in places)
              ListTile(
                dense: true,
                contentPadding: EdgeInsets.zero,
                leading: const Icon(
                  Icons.place_outlined,
                  color: VisualScanStyle.amber,
                ),
                title: Text(place.name),
                trailing: IconButton(
                  tooltip: context.l10n.removeStop,
                  onPressed: () => _planPlaces.remove(place.xid),
                  icon: const Icon(Icons.close),
                ),
              ),
            if (widget.onOpenPlan != null)
              _ScanButton(
                onPressed: widget.onOpenPlan,
                icon: Icons.arrow_forward_rounded,
                label: context.l10n.addToPlan,
                prominent: true,
                fullWidth: true,
              ),
          ],
        ),
      ),
    );
  }

  Future<RecognitionResult> _translate(String target) async {
    try {
      return await widget.service.translate(widget.result, target);
    } catch (_) {
      return widget.result;
    }
  }

  @override
  Widget build(BuildContext context) {
    final target = switch (Localizations.localeOf(context).languageCode) {
      'ms' => 'ms',
      'zh' => 'zh-CN',
      _ => 'en',
    };
    if (target == 'en' ||
        widget.result.isSample ||
        widget.result.kind == 'unknown') {
      return _body(widget.result);
    }
    return FutureBuilder<RecognitionResult>(
      key: ValueKey(target),
      future: _translations.putIfAbsent(target, () => _translate(target)),
      builder: (_, snapshot) => _body(snapshot.data ?? widget.result),
    );
  }

  Widget _body(RecognitionResult result) {
    final source = widget.result;
    final l10n = context.l10n;
    final candidates = source.referenceCandidates;
    final areaSuggestions = source.source == RecognitionSource.areaLookup;
    final facts = scanFacts(source.name, description: result.description);
    final needsRetry = source.kind == 'unknown' && !source.isSample;
    final placeId = source.placeId;
    final landmarkStory =
        (source.kind == 'landmark' || source.kind == 'restaurant')
        ? Attraction(
            xid:
                _origin?.xid ??
                (placeId == null
                    ? 'scan_${scanNameKey(source.name)}'
                    : 'google_$placeId'),
            name: source.name,
            latitude: _origin?.latitude ?? _resolvedOrigin?.latitude ?? 0,
            longitude: _origin?.longitude ?? _resolvedOrigin?.longitude ?? 0,
            category:
                _origin?.category ??
                (source.kind == 'restaurant'
                    ? l10n.scanFoodAndCafes
                    : l10n.landmark),
            description: facts.description,
          )
        : null;
    final status = switch (source.source) {
      _ when source.isSample => 'Sample landmark',
      RecognitionSource.userConfirmedReference => l10n.referenceMatchSelected,
      RecognitionSource.userConfirmedClue => l10n.referenceMatchSelected,
      RecognitionSource.web =>
        candidates.isEmpty
            ? l10n.scanWebMatchFound
            : l10n.referenceMatchUncertain,
      RecognitionSource.sign => l10n.scanSignClue,
      RecognitionSource.visualEvidence => l10n.referenceMatchUncertain,
      RecognitionSource.placeLookup => l10n.referenceMatchUncertain,
      RecognitionSource.foodSuggestion => l10n.referenceMatchUncertain,
      RecognitionSource.areaLookup => l10n.scanAreaOnly,
      RecognitionSource.vision when candidates.isNotEmpty =>
        l10n.referenceMatchUncertain,
      RecognitionSource.reference =>
        candidates.isEmpty
            ? l10n.referenceMatchFound
            : l10n.referenceMatchUncertain,
      _ =>
        source.kind == 'unknown'
            ? l10n.scanNeedsClue
            : source.confidence == null
            ? 'Possible visual match'
            : 'Confident visual match',
    };

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
      children: [
        Row(
          children: [
            if (widget.onBack != null)
              BackButton(
                color: VisualScanStyle.amber,
                onPressed: widget.onBack,
              ),
            Expanded(
              child: Text(l10n.scanResult, style: VisualScanStyle.heading(20)),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            if (widget.onOpenWishlist != null) ...[
              Expanded(
                child: OutlinedButton.icon(
                  style: VisualScanStyle.headerButton,
                  onPressed: widget.onOpenWishlist,
                  icon: const Icon(Icons.bookmark_border, size: 17),
                  label: Text(l10n.scanWishlist),
                ),
              ),
              const SizedBox(width: 10),
            ],
            Expanded(
              child: OutlinedButton.icon(
                style: VisualScanStyle.headerButton,
                onPressed: widget.onNewScan,
                icon: const Icon(Icons.restart_alt, size: 17),
                label: const Text('New Scan'),
              ),
            ),
          ],
        ),
        if (widget.photo case final photo?) ...[
          const SizedBox(height: 20),
          _ResultPanel(
            child: AspectRatio(
              aspectRatio: 1.82,
              child: ColoredBox(
                color: VisualScanStyle.navigation,
                child: Image(
                  image: photo,
                  fit: BoxFit.contain,
                  errorBuilder: (_, _, _) => Center(
                    child: Text(
                      l10n.photoPreviewUnavailable,
                      style: _supportText,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
        const SizedBox(height: 20),
        _ResultPanel(
          highlighted: true,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      source.kind == 'unknown'
                          ? Icons.info_outline
                          : Icons.check_circle_outline,
                      size: 16,
                      color: VisualScanStyle.amber,
                    ),
                    const SizedBox(width: 8),
                    Expanded(child: Text(status, style: _amberText)),
                  ],
                ),
                if (result.location.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Text(result.location, style: _supportText),
                ],
                const SizedBox(height: 5),
                Text(
                  candidates.isNotEmpty
                      ? areaSuggestions
                            ? l10n.scanPlacesInArea
                            : l10n.referencePossibleMatches
                      : source.kind == 'unknown' && !source.isSample
                      ? l10n.scanTryAnotherPhoto
                      : result.name,
                  style: VisualScanStyle.heading(24),
                ),
                if (source.visionLandmarkName case final name?) ...[
                  const SizedBox(height: 7),
                  Text(
                    [
                      if (name != source.name) name,
                      if (source.confidence case final score?)
                        l10n.visionConfidenceValue('${(score * 100).round()}'),
                    ].join(' · '),
                    style: _supportText,
                  ),
                ],
                if (candidates.isNotEmpty) ...[
                  const SizedBox(height: 7),
                  Text(
                    areaSuggestions
                        ? l10n.scanChooseAreaPlace
                        : l10n.referenceChooseSubject,
                    style: _supportText,
                  ),
                  const SizedBox(height: 12),
                  for (final candidate in candidates)
                    _ScanCandidateCard(
                      candidate: candidate,
                      listing:
                          !areaSuggestions &&
                              (candidate.kind == 'landmark' ||
                                  candidate.kind == 'restaurant') &&
                              candidateScanFacts(candidate).hours == null
                          ? _listing(candidate.name, candidate.placeId)
                          : null,
                      onTap: widget.onReferenceSelected == null
                          ? null
                          : () => widget.onReferenceSelected!(candidate.id),
                    ),
                  if (areaSuggestions) const GoogleMapsAttribution(),
                ],
                if (source.kind != 'unknown') ...[
                  const SizedBox(height: 8),
                  _ScanFactsBlock(
                    facts: facts,
                    placeName: source.name,
                    isDish: source.kind == 'food',
                    listing:
                        !source.isSample &&
                            (source.kind == 'landmark' ||
                                source.kind == 'restaurant') &&
                            (facts.hours == null || facts.description == null)
                        ? _listing(source.name, source.placeId)
                        : null,
                    showDescriptionHeading: source.kind == 'landmark',
                  ),
                ] else if (candidates.isEmpty &&
                    (!source.isSample || result.description.isNotEmpty)) ...[
                  const SizedBox(height: 7),
                  Text(
                    source.isSample
                        ? result.description
                        : l10n.scanAnotherPhotoHelp,
                    style: _supportText.copyWith(fontSize: 14, height: 1.5),
                  ),
                ],
                if (source.webSources.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  Text(source.webSources.join(' · '), style: _supportText),
                ],
                if (needsRetry) ...[
                  if (source.areaHint case final area?) ...[
                    const SizedBox(height: 10),
                    Text(l10n.scanSuggestedArea(area), style: _supportText),
                  ],
                  if (candidates.isEmpty && result.labels.isNotEmpty) ...[
                    const SizedBox(height: 14),
                    Text(l10n.scanPhotoClues, style: _amberText),
                    const SizedBox(height: 5),
                    Text(result.labels.join(' · '), style: _supportText),
                  ],
                  const SizedBox(height: 14),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      _ScanButton(
                        label: l10n.scanRetakePhoto,
                        icon: Icons.photo_camera_outlined,
                        prominent: true,
                        onPressed: widget.onTakeAnotherPhoto,
                      ),
                      _ScanButton(
                        label: l10n.scanUploadAnotherPhoto,
                        icon: Icons.file_upload_outlined,
                        onPressed: widget.onUploadAnotherPhoto,
                      ),
                    ],
                  ),
                ],
                if (_origin == null && source.kind == 'landmark') ...[
                  const SizedBox(height: 14),
                  _ScanButton(
                    label: l10n.scanOpenMaps,
                    icon: Icons.map_outlined,
                    onPressed: () => _openMapSearch('${source.name} Malaysia'),
                  ),
                ],
                if (landmarkStory case final place?) ...[
                  const SizedBox(height: 16),
                  _ActionRow(
                    children: [
                      _itineraryButton(place),
                      _saveButton(place),
                      _ScanButton(
                        label: l10n.scanCheckPlaceDetails,
                        icon: Icons.arrow_forward_rounded,
                        iconAfter: true,
                        prominent: true,
                        stacked: true,
                        onPressed: () => _story(place, photo: widget.photo),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ),
        if (needsRetry) ...[
          const SizedBox(height: 16),
          const _ResultPanel(
            child: Padding(
              padding: EdgeInsets.all(16),
              child: ScanPhotoGuidance(),
            ),
          ),
        ],
        const SizedBox(height: 24),
        if (_planPlaces.places.isNotEmpty) ...[
          _planSelectionPanel(),
          const SizedBox(height: 24),
        ],
        ..._nearbySection(result),
      ],
    );
  }

  List<Widget> _nearbySection(RecognitionResult display) {
    final l10n = context.l10n;
    final result = widget.result;
    final location = LocationService();
    final anchor = result.kind == 'landmark' || result.kind == 'restaurant'
        ? [
            result.name,
            if (result.location.trim().isNotEmpty) result.location,
          ].join(', ')
        : result.kind == 'food'
        ? (_currentGps != null
              ? l10n.scanMapLocation
              : result.areaHint ?? location.currentAreaName)
        : result.areaHint;
    final visible = _spots.where(
      (spot) =>
          (_filter == _SpotFilter.all ||
              spot.food == (_filter == _SpotFilter.food)) &&
          (result.kind != 'food' ||
              (_currentGps != null &&
                  const Distance(roundResult: false)(
                        _currentGps!,
                        spot.place.point,
                      ) <=
                      20000)),
    );
    return [
      Text(l10n.scanNearbyPlaces, style: VisualScanStyle.heading(20)),
      const SizedBox(height: 4),
      Text(
        _origin != null && _spots.isNotEmpty && !result.isSample
            ? l10n.scanNearbyDistance(display.name)
            : result.kind == 'food' && anchor != null && _currentGps == null
            ? l10n.scanDishAreaFallback(anchor)
            : anchor != null
            ? l10n.scanNearbyArea(
                display.kind == 'landmark' ? display.name : anchor,
              )
            : l10n.scanNearbyNoLocation,
        style: _supportText,
      ),
      const SizedBox(height: 10),
      if (anchor != null) ...[
        _ResultPanel(
          child: Padding(
            padding: const EdgeInsets.all(4),
            child: Row(
              children: [
                for (final (filter, label) in [
                  (_SpotFilter.all, l10n.all),
                  (_SpotFilter.food, l10n.scanFoodAndCafes),
                  (_SpotFilter.attractions, l10n.attractions),
                ])
                  Expanded(
                    child: Semantics(
                      selected: _filter == filter,
                      child: TextButton(
                        onPressed: () => setState(() => _filter = filter),
                        style: TextButton.styleFrom(
                          backgroundColor: _filter == filter
                              ? VisualScanStyle.amber
                              : null,
                          foregroundColor: _filter == filter
                              ? VisualScanStyle.background
                              : VisualScanStyle.muted,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 4,
                            vertical: 8,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(9),
                          ),
                          textStyle: const TextStyle(fontSize: 12),
                        ),
                        child: Text(label, textAlign: TextAlign.center),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
      ],
      Text(l10n.scanMapSearchHelp, style: VisualScanStyle.heading(20)),
      const SizedBox(height: 8),
      Row(
        children: [
          for (final (filter, label, term, icon) in [
            (
              _SpotFilter.attractions,
              l10n.scanFindAttractions,
              'tourist attractions',
              Icons.explore_outlined,
            ),
            (
              _SpotFilter.food,
              l10n.findRestaurants,
              'restaurants',
              Icons.restaurant,
            ),
          ])
            if (anchor == null ||
                _filter == _SpotFilter.all ||
                _filter == filter)
              Expanded(
                child: Padding(
                  padding: EdgeInsets.only(
                    right: filter == _SpotFilter.attractions ? 5 : 0,
                    left: filter == _SpotFilter.food ? 5 : 0,
                  ),
                  child: _ScanButton(
                    label: label,
                    icon: icon,
                    compact: true,
                    fullWidth: true,
                    onPressed: () => _openMapSearch(
                      anchor == null
                          ? '${filter == _SpotFilter.food && result.kind == 'food' ? result.name : term} near me'
                          : filter == _SpotFilter.food && result.kind == 'food'
                          ? foodVenueSearchQuery(
                              result.name,
                              _currentGps == null
                                  ? anchor
                                  : '${_currentGps!.latitude},${_currentGps!.longitude}',
                            )
                          : _currentGps != null && result.kind == 'food'
                          ? '$term near ${_currentGps!.latitude},${_currentGps!.longitude}'
                          : '$term near $anchor, Malaysia',
                    ),
                  ),
                ),
              ),
        ],
      ),
      if (result.kind == 'food' && visible.isNotEmpty)
        Padding(
          padding: const EdgeInsets.only(top: 12),
          child: Text(l10n.scanGuideDishVenues, style: _supportText),
        ),
      for (final spot in visible) ...[
        const SizedBox(height: 10),
        _NearbySpotCard(
          key: ValueKey(spot.place.xid),
          spot: spot,
          photoLookup: () =>
              _listing(spot.place.name, spot.place.googlePlaceId),
          placesService: _googlePlaces,
          add: _itineraryButton(spot.place),
          wishlist: _saveButton(spot.place),
          distanceOrigin: _origin,
          distanceCenter: _origin == null
              ? _resolvedOrigin ?? _currentGps
              : null,
          fromLandmark: result.kind == 'landmark' && _resolvedOrigin != null,
          onDetails: () => _openSpotDetails(spot),
        ),
      ],
      if (anchor != null)
        for (final (filter, food, term, label) in [
          (
            _SpotFilter.attractions,
            false,
            'tourist attractions',
            l10n.attractions,
          ),
          (_SpotFilter.food, true, 'restaurants', l10n.scanFoodAndCafes),
        ])
          if ((_filter == _SpotFilter.all || _filter == filter) &&
              (result.kind == 'food' ||
                  !visible.any((spot) => spot.food == food))) ...[
            const SizedBox(height: 12),
            Text(label, style: VisualScanStyle.heading(16)),
            FutureBuilder<List<GooglePlaceDetails>>(
              future: _nearbyJobs.putIfAbsent(filter, () async {
                final places = await widget.service.searchPlaces(
                  _currentGps != null
                      ? food && result.kind == 'food'
                            ? '${result.name} restaurants'
                            : term
                      : food && result.kind == 'food'
                      ? foodVenueSearchQuery(result.name, anchor)
                      : '$term near $anchor',
                  near: _currentGps,
                );
                final center = _origin?.point ?? _resolvedOrigin ?? _currentGps;
                return places
                    .where(
                      (place) =>
                          place.id != result.placeId &&
                          (place.name?.trim().isNotEmpty ?? false) &&
                          (!food ||
                              result.kind != 'food' ||
                              place.category == null ||
                              RegExp(
                                r'restaurant|caf[eé]|coffee|food|dining|hawker|bistro|bakery',
                                caseSensitive: false,
                              ).hasMatch(place.category ?? '')) &&
                          scanNameKey(place.name ?? '') !=
                              scanNameKey(result.name) &&
                          (center == null ||
                              place.latitude == null ||
                              place.longitude == null ||
                              const Distance(roundResult: false)(
                                    center,
                                    LatLng(place.latitude!, place.longitude!),
                                  ) <=
                                  20000),
                    )
                    .take(4)
                    .toList();
              }),
              builder: (context, snapshot) {
                if (snapshot.connectionState != ConnectionState.done) {
                  return Text(l10n.scanFindingNearby, style: _supportText);
                }
                final places = snapshot.data ?? const [];
                if (places.isEmpty) {
                  return Text(l10n.scanNoNearbyListings, style: _supportText);
                }
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (food && result.kind == 'food')
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Text(
                          l10n.scanDishVenuesHelp,
                          style: _supportText,
                        ),
                      ),
                    for (final listing in places) ...[
                      _listedSpotCard(listing, food: food),
                      const SizedBox(height: 10),
                    ],
                  ],
                );
              },
            ),
          ],
    ];
  }

  Widget _listedSpotCard(GooglePlaceDetails listing, {required bool food}) {
    final place = Attraction(
      xid: 'google_${listing.id}',
      name: listing.name!,
      latitude: listing.latitude ?? 0,
      longitude: listing.longitude ?? 0,
      category:
          listing.category ??
          (food ? context.l10n.scanFoodAndCafes : context.l10n.attractions),
      description: listing.description,
    );
    final spot = (
      place: place,
      food: food,
      image: null,
      price: null,
      distance: '',
    );
    return _NearbySpotCard(
      key: ValueKey(place.xid),
      spot: spot,
      initialDetails: listing,
      photoLookup: () => _listing(place.name, listing.id),
      placesService: _googlePlaces,
      add: _itineraryButton(place),
      wishlist: _saveButton(place),
      distanceOrigin: _origin,
      distanceCenter: _origin == null ? _resolvedOrigin ?? _currentGps : null,
      fromLandmark: widget.result.kind == 'landmark' && _resolvedOrigin != null,
      onDetails: () => _openSpotDetails(spot, listing),
    );
  }

  Widget _saveButton(Attraction spot) {
    final saved = _saved.contains(spot.xid);
    return _ScanButton(
      label: saved ? context.l10n.saved : context.l10n.scanAddToWishlist,
      icon: saved ? Icons.bookmark : Icons.bookmark_border,
      highlighted: saved,
      compact: true,
      stacked: true,
      onPressed: _saving ? null : () => _save(spot),
    );
  }
}

const _supportText = TextStyle(
  color: VisualScanStyle.muted,
  fontSize: 13,
  height: 1.35,
);
const _amberText = TextStyle(
  color: VisualScanStyle.amber,
  fontSize: 12,
  fontWeight: FontWeight.w700,
);

class _ResultPanel extends StatelessWidget {
  const _ResultPanel({required this.child, this.highlighted = false});

  final Widget child;
  final bool highlighted;

  @override
  Widget build(BuildContext context) => Material(
    color: VisualScanStyle.surface,
    clipBehavior: Clip.antiAlias,
    shape: RoundedRectangleBorder(
      side: BorderSide(
        color: highlighted ? const Color(0xFF805F34) : VisualScanStyle.border,
      ),
      borderRadius: BorderRadius.circular(16),
    ),
    child: child,
  );
}

class _NearbySpotCard extends StatelessWidget {
  const _NearbySpotCard({
    super.key,
    required this.spot,
    required this.add,
    required this.wishlist,
    this.distanceOrigin,
    this.distanceCenter,
    this.fromLandmark = false,
    required this.photoLookup,
    required this.placesService,
    this.initialDetails,
    required this.onDetails,
  });

  final ScanSpot spot;
  final Widget add;
  final Widget wishlist;
  final Attraction? distanceOrigin;
  final LatLng? distanceCenter;
  final bool fromLandmark;
  final Future<GooglePlaceDetails?> Function() photoLookup;
  final GooglePlacesService placesService;
  final GooglePlaceDetails? initialDetails;
  final VoidCallback onDetails;

  Widget _thumbnail() {
    final fallback = ColoredBox(
      color: const Color(0xFF292720),
      child: Icon(
        spot.food ? Icons.restaurant : Icons.place_outlined,
        color: VisualScanStyle.amber,
      ),
    );
    if ((spot.image ?? AttractionImageResolver.resolveAsset(spot.place))
        case final asset?) {
      return Image.asset(
        asset,
        fit: BoxFit.cover,
        errorBuilder: (_, _, _) => fallback,
      );
    }
    if (AttractionImageResolver.resolvePhotoUrl(spot.place) case final url?) {
      return Image.network(
        url,
        fit: BoxFit.cover,
        errorBuilder: (_, _, _) => fallback,
      );
    }
    Widget googlePhoto(String id, GooglePlacePhoto photo) => GooglePlaceImage(
      placeId: id,
      photo: photo,
      service: placesService,
      requestWidth: 200,
      fill: true,
      autoLoad: true,
      compactAttribution: true,
      showGoogleMapsAttribution: false,
      showPhotoAuthorAttribution: false,
      fallback: fallback,
    );
    if (initialDetails?.photos.firstOrNull case final photo?) {
      return googlePhoto(initialDetails!.id, photo);
    }
    return FutureBuilder<GooglePlaceDetails?>(
      future: photoLookup(),
      builder: (_, snapshot) {
        final details = snapshot.data;
        final photo = details?.photos.firstOrNull;
        return details == null || photo == null
            ? fallback
            : googlePhoto(details.id, photo);
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final place = spot.place;
    final origin = distanceOrigin;
    final center = origin?.point ?? distanceCenter;
    final meters =
        center == null || (place.latitude == 0 && place.longitude == 0)
        ? null
        : const Distance(roundResult: false)(center, place.point);
    return _ResultPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 11, top: 11),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  width: 76,
                  height: 64,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: _thumbnail(),
                  ),
                ),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(12, 0, 12, 11),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(
                              spot.food
                                  ? Icons.restaurant
                                  : Icons.explore_outlined,
                              color: VisualScanStyle.amber,
                              size: 12,
                            ),
                            const SizedBox(width: 4),
                            Expanded(
                              child: Text(
                                spot.place.category.split(',').first,
                                style: _amberText.copyWith(fontSize: 11),
                              ),
                            ),
                            if (spot.price case final price?) ...[
                              const SizedBox(width: 5),
                              Text(
                                price,
                                style: const TextStyle(
                                  color: VisualScanStyle.text,
                                  fontSize: 11,
                                ),
                              ),
                            ],
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          spot.place.name,
                          style: VisualScanStyle.heading(16),
                        ),
                        const SizedBox(height: 4),
                        if (nearbyScanFacts(spot.place).description
                            case final description?)
                          Text(
                            description,
                            style: _supportText,
                            maxLines: 3,
                            overflow: TextOverflow.ellipsis,
                          ),
                        FutureBuilder<GooglePlaceDetails?>(
                          future: meters == null ? photoLookup() : null,
                          initialData: initialDetails,
                          builder: (context, snapshot) {
                            final details = snapshot.data ?? initialDetails;
                            final latitude = details?.latitude;
                            final longitude = details?.longitude;
                            final resolvedMeters =
                                meters ??
                                (center == null ||
                                        latitude == null ||
                                        longitude == null
                                    ? null
                                    : const Distance(roundResult: false)(
                                        center,
                                        LatLng(latitude, longitude),
                                      ));
                            final label = resolvedMeters != null
                                ? scanDistanceLabel(
                                    context,
                                    resolvedMeters,
                                    fromLandmark:
                                        origin != null || fromLandmark,
                                    showWalkTime: false,
                                  )
                                : spot.distance.isNotEmpty
                                ? spot.distance
                                : context.l10n.scanDistanceUnavailable;
                            return Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                if (details?.address case final address?)
                                  Text(address, style: _supportText),
                                const SizedBox(height: 5),
                                Text(
                                  label,
                                  key: const ValueKey('scan-nearby-distance'),
                                  style: _supportText.copyWith(
                                    color: VisualScanStyle.amber,
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          FutureBuilder<GooglePlaceDetails?>(
            future: initialDetails == null ? photoLookup() : null,
            initialData: initialDetails,
            builder: (context, snapshot) {
              final photo = snapshot.data?.photos.firstOrNull;
              if (photo == null) return const SizedBox.shrink();
              final author = photo.authors.firstOrNull;
              final name = author?['displayName']?.toString();
              return Padding(
                padding: const EdgeInsets.fromLTRB(11, 0, 11, 7),
                child: Text(
                  name == null || name.isEmpty
                      ? 'Photo: Google Maps'
                      : 'Photo: $name · Google Maps',
                  style: _supportText.copyWith(fontSize: 10),
                ),
              );
            },
          ),
          const Divider(height: 1, color: VisualScanStyle.border),
          Container(
            color: VisualScanStyle.navigation,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _ActionRow(
                  children: [
                    add,
                    wishlist,
                    _ScanButton(
                      label: context.l10n.scanCheckPlaceDetails,
                      icon: Icons.arrow_forward,
                      iconAfter: true,
                      prominent: true,
                      compact: true,
                      stacked: true,
                      onPressed: onDetails,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ScanCandidateCard extends StatelessWidget {
  const _ScanCandidateCard({required this.candidate, this.onTap, this.listing});

  final ReferenceSubject candidate;
  final VoidCallback? onTap;
  final Future<GooglePlaceDetails?>? listing;

  @override
  Widget build(BuildContext context) {
    final facts = candidateScanFacts(candidate);
    final image = facts.image;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: _ResultPanel(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (image != null)
              Image.asset(
                image,
                height: 110,
                fit: BoxFit.cover,
                excludeFromSemantics: true,
              ),
            Material(
              type: MaterialType.transparency,
              child: ListTile(
                textColor: VisualScanStyle.text,
                iconColor: VisualScanStyle.amber,
                leading: Icon(
                  candidate.kind == 'food'
                      ? Icons.restaurant
                      : Icons.place_outlined,
                ),
                title: Text(candidate.name),
                subtitle: candidate.visionConfidence == null
                    ? null
                    : Text(
                        context.l10n.visionConfidenceValue(
                          '${(candidate.visionConfidence! * 100).round()}',
                        ),
                        style: _supportText,
                      ),
                trailing: const Icon(Icons.chevron_right),
                onTap: onTap,
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 0, 14, 12),
              child: _ScanFactsBlock(
                facts: facts,
                placeName: candidate.name,
                isDish: candidate.kind == 'food',
                listing: listing,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ScanFactsBlock extends StatelessWidget {
  const _ScanFactsBlock({
    required this.facts,
    required this.placeName,
    this.isDish = false,
    this.listing,
    this.showDescriptionHeading = false,
  });

  final ScanPlaceFacts facts;
  final String placeName;
  final bool isDish;
  final Future<GooglePlaceDetails?>? listing;
  final bool showDescriptionHeading;

  @override
  Widget build(BuildContext context) => listing == null
      ? _body(context, null, loading: false)
      : FutureBuilder<GooglePlaceDetails?>(
          future: listing,
          builder: (context, snapshot) => _body(
            context,
            snapshot.data,
            loading: snapshot.connectionState != ConnectionState.done,
          ),
        );

  Widget _body(
    BuildContext context,
    GooglePlaceDetails? place, {
    required bool loading,
  }) {
    final l10n = context.l10n;
    final schedule = (place?.hours['weekdayDescriptions'] as List? ?? const [])
        .whereType<String>()
        .where((line) => line.trim().isNotEmpty)
        .toList();
    final hours = schedule.isNotEmpty
        ? schedule.join('\n')
        : facts.hours ??
              (isDish
                  ? l10n.scanHoursVaryByVenue
                  : loading
                  ? l10n.scanCheckingPlaceDetails
                  : l10n.openingHoursUnavailableCheckBeforeVisiting);
    final source = facts.source;
    final summary = place?.description?.trim();
    final description =
        facts.description ??
        (summary != null && summary.isNotEmpty ? summary : null) ??
        (place == null
            ? null
            : l10n.scanListedPlaceDescription(
                placeName,
                place.category ?? l10n.landmark,
                place.address?.trim().isNotEmpty == true
                    ? place.address!.trim()
                    : 'Malaysia',
              ));
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (showDescriptionHeading) ...[
          Text(l10n.scanAboutLandmark, style: _amberText),
          const SizedBox(height: 4),
        ],
        Text(
          description ??
              (loading
                  ? l10n.scanCheckingPlaceDetails
                  : l10n.scanPlaceDescriptionPending(placeName)),
          style: _supportText,
        ),
        if (place?.address case final address?) ...[
          const SizedBox(height: 3),
          Text(address, style: _supportText),
        ],
        const SizedBox(height: 7),
        Text(l10n.openingHours, style: _amberText),
        Text(hours, style: _supportText),
        if (place != null) ...[
          const SizedBox(height: 6),
          DefaultTextStyle(
            style: _supportText,
            child: GoogleMapsAttribution(attributions: place.attributions),
          ),
        ],
        if (source != null)
          TextButton(
            style: TextButton.styleFrom(
              foregroundColor: VisualScanStyle.amber,
              padding: EdgeInsets.zero,
              minimumSize: const Size(0, 44),
              alignment: Alignment.centerLeft,
            ),
            onPressed: () async {
              try {
                if (await launchUrl(
                  Uri.parse(source),
                  mode: LaunchMode.externalApplication,
                )) {
                  return;
                }
              } catch (_) {
                // A missing browser is handled the same as a failed launch.
              }
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text(l10n.unableToOpenThisLink)),
                );
              }
            },
            child: Text(l10n.scanHoursSource),
          ),
      ],
    );
  }
}

class _ActionRow extends StatelessWidget {
  const _ActionRow({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) => Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      for (var index = 0; index < children.length; index++) ...[
        if (index > 0) const SizedBox(width: 6),
        Expanded(
          child: SizedBox(
            height: MediaQuery.textScalerOf(context).scale(14) > 19 ? 86 : 68,
            child: children[index],
          ),
        ),
      ],
    ],
  );
}

class _ScanButton extends StatelessWidget {
  const _ScanButton({
    required this.label,
    required this.icon,
    required this.onPressed,
    this.iconAfter = false,
    this.prominent = false,
    this.highlighted = false,
    this.compact = false,
    this.stacked = false,
    this.fullWidth = false,
  });

  final String label;
  final IconData icon;
  final VoidCallback? onPressed;
  final bool iconAfter;
  final bool prominent;
  final bool highlighted;
  final bool compact;
  final bool stacked;
  final bool fullWidth;

  @override
  Widget build(BuildContext context) => FilledButton(
    onPressed: onPressed,
    style: FilledButton.styleFrom(
      backgroundColor: prominent
          ? VisualScanStyle.amber
          : highlighted
          ? const Color(0xFF382E20)
          : const Color(0xFF262522),
      foregroundColor: prominent
          ? VisualScanStyle.background
          : highlighted
          ? VisualScanStyle.amber
          : VisualScanStyle.text,
      minimumSize: Size(0, compact ? 34 : 42),
      padding: EdgeInsets.symmetric(
        horizontal: stacked
            ? 4
            : compact
            ? 9
            : 13,
        vertical: stacked ? 4 : 7,
      ),
      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(compact ? 9 : 12),
      ),
      side: highlighted ? const BorderSide(color: Color(0xFF805F34)) : null,
      textStyle: Theme.of(context).textTheme.labelLarge?.copyWith(
        fontSize: compact ? 11 : 13,
        fontWeight: FontWeight.w600,
      ),
    ),
    child: SizedBox(
      width: fullWidth ? double.infinity : null,
      child: stacked
          ? Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, size: 16),
                const SizedBox(height: 2),
                Text(
                  label,
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            )
          : Row(
              mainAxisSize: fullWidth ? MainAxisSize.max : MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (!iconAfter) Icon(icon, size: compact ? 13 : 16),
                if (!iconAfter) const SizedBox(width: 6),
                Flexible(
                  child: Text(
                    label,
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (iconAfter) const SizedBox(width: 6),
                if (iconAfter) Icon(icon, size: compact ? 13 : 16),
              ],
            ),
    ),
  );
}
