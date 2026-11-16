import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:smart_travel_planner/features/image_recognition/data/scan_place_facts.dart';
import 'package:smart_travel_planner/features/image_recognition/data/visual_scan_results.dart';
import 'package:smart_travel_planner/features/image_recognition/models/recognition_result.dart';
import 'package:smart_travel_planner/features/image_recognition/services/recognition_clues.dart';
import 'package:smart_travel_planner/features/image_recognition/services/image_recognition_service.dart';
import 'package:smart_travel_planner/features/image_recognition/widgets/scan_photo_guidance.dart';
import 'package:smart_travel_planner/features/image_recognition/widgets/visual_scan_style.dart';
import 'package:smart_travel_planner/features/places/screens/attraction_detail_page.dart';
import 'package:smart_travel_planner/features/places/models/google_place_details.dart';
import 'package:smart_travel_planner/features/places/services/google_places_service.dart';
import 'package:smart_travel_planner/features/places/widgets/google_maps_attribution.dart';
import 'package:smart_travel_planner/shared/models/attraction.dart';
import 'package:smart_travel_planner/l10n/localized_labels.dart';

class RecognitionResultSheet extends StatefulWidget {
  const RecognitionResultSheet({
    super.key,
    required this.result,
    required this.service,
    required this.onNewScan,
    this.onBack,
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
  late final _spots = scanSpots(widget.result, _origin);
  final _translations = <String, Future<RecognitionResult>>{};
  final _lookupJobs = <String, Future<GooglePlaceDetails?>>{};
  final _nearbyJobs = <_SpotFilter, Future<List<GooglePlaceDetails>>>{};
  late final _googlePlaces = GooglePlacesService();
  Set<String> _saved = {};
  bool _saving = false;
  _SpotFilter _filter = _SpotFilter.all;

  String get _savedKey => 'visual_scan_saved_spots:${widget.userId}';

  @override
  void initState() {
    super.initState();
    _loadSaved();
  }

  Future<void> _loadSaved() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (mounted && !_saving) {
        setState(() => _saved = (prefs.getStringList(_savedKey) ?? []).toSet());
      }
    } catch (_) {
      // The scan remains usable if local storage is unavailable.
    }
  }

  Future<void> _save(Attraction spot) async {
    if (_saving) return;
    setState(() => _saving = true);
    try {
      final prefs = await SharedPreferences.getInstance();
      final updated = (prefs.getStringList(_savedKey) ?? []).toSet();
      if (!updated.add(spot.xid)) updated.remove(spot.xid);
      if (!await prefs.setStringList(_savedKey, updated.toList())) {
        throw StateError('Unable to save spot');
      }
      if (mounted) setState(() => _saved = updated);
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
    final landmarkStory = source.kind == 'landmark'
        ? _origin?.copyWith(description: facts.description) ??
              Attraction(
                xid: placeId == null
                    ? 'scan_${scanNameKey(source.name)}'
                    : 'google_$placeId',
                name: source.name,
                latitude: 0,
                longitude: 0,
                category: l10n.landmark,
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
              child: Text(
                source.isSample
                    ? 'Offline sample'
                    : switch (source.source) {
                        RecognitionSource.vision =>
                          'Photo scan · Google Vision',
                        RecognitionSource.reference ||
                        RecognitionSource.userConfirmedReference =>
                          l10n.referenceScanSource,
                        RecognitionSource.web => l10n.scanWebSource,
                        RecognitionSource.sign => l10n.scanSignSource,
                        RecognitionSource.visualEvidence =>
                          l10n.scanVisualClueSource,
                        RecognitionSource.placeLookup =>
                          l10n.scanPlaceListingSource,
                        RecognitionSource.foodSuggestion =>
                          'Photo scan · Gemini',
                        RecognitionSource.areaLookup =>
                          l10n.scanPlaceListingSource,
                        RecognitionSource.userConfirmedClue =>
                          l10n.scanSelectedSource,
                      },
                style: _supportText,
              ),
            ),
            OutlinedButton.icon(
              style: VisualScanStyle.headerButton,
              onPressed: widget.onNewScan,
              icon: const Icon(Icons.restart_alt, size: 17),
              label: const Text('New Scan'),
            ),
          ],
        ),
        if (widget.photo case final photo?) ...[
          const SizedBox(height: 20),
          _ResultPanel(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                AspectRatio(
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
                Padding(
                  padding: const EdgeInsets.fromLTRB(10, 8, 10, 9),
                  child: Text(
                    source.isSample ? 'Sample photo' : 'Original photo',
                    style: const TextStyle(
                      fontSize: 12,
                      color: VisualScanStyle.text,
                    ),
                  ),
                ),
              ],
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
                              candidate.kind == 'landmark' &&
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
                    isDish: source.kind == 'food',
                    listing:
                        !source.isSample &&
                            source.kind == 'landmark' &&
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
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      _ScanButton(
                        label: 'Open Landmark Story',
                        icon: Icons.arrow_forward_rounded,
                        iconAfter: true,
                        prominent: true,
                        onPressed: () => _story(place, photo: widget.photo),
                      ),
                      _saveButton(place),
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
        ..._nearbySection(result),
      ],
    );
  }

  List<Widget> _nearbySection(RecognitionResult display) {
    final l10n = context.l10n;
    final result = widget.result;
    final anchor = result.kind == 'landmark'
        ? [
            result.name,
            if (result.location.trim().isNotEmpty) result.location,
          ].join(', ')
        : result.areaHint;
    final visible = _spots.where(
      (spot) =>
          _filter == _SpotFilter.all ||
          spot.food == (_filter == _SpotFilter.food),
    );
    return [
      Text(l10n.scanNearbyPlaces, style: VisualScanStyle.heading(20)),
      const SizedBox(height: 4),
      Text(
        _origin != null && _spots.isNotEmpty && !result.isSample
            ? l10n.scanNearbyDistance(display.name)
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
      Wrap(
        spacing: 8,
        runSpacing: 8,
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
              _ScanButton(
                label: label,
                icon: icon,
                onPressed: () => _openMapSearch(
                  anchor == null
                      ? '${filter == _SpotFilter.food && result.kind == 'food' ? result.name : term} near me'
                      : '$term near $anchor, Malaysia',
                ),
              ),
        ],
      ),
      if (anchor == null && result.kind == 'food' && visible.isNotEmpty)
        Padding(
          padding: const EdgeInsets.only(top: 12),
          child: Text(l10n.scanGuideDishVenues, style: _supportText),
        ),
      for (final spot in visible) ...[
        const SizedBox(height: 10),
        _NearbySpotCard(
          key: ValueKey(spot.place.xid),
          spot: spot,
          lookup: () => _listing(spot.place.name, spot.place.googlePlaceId),
          save: _saveButton(spot.place, compact: true),
          onStory: () => _story(spot.place),
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
              !visible.any((spot) => spot.food == food)) ...[
            const SizedBox(height: 12),
            Text(label, style: VisualScanStyle.heading(16)),
            FutureBuilder<List<GooglePlaceDetails>>(
              future: _nearbyJobs.putIfAbsent(filter, () async {
                final places = await widget.service.searchPlaces(
                  '$term near $anchor',
                );
                return places
                    .where(
                      (place) =>
                          place.id != result.placeId &&
                          (place.name?.trim().isNotEmpty ?? false) &&
                          scanNameKey(place.name ?? '') !=
                              scanNameKey(result.name),
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
    return _NearbySpotCard(
      key: ValueKey(place.xid),
      spot: (place: place, food: food, image: null, price: null, distance: ''),
      initialDetails: listing,
      lookup: () => _listing(place.name, listing.id),
      save: _saveButton(place, compact: true),
      onStory: () => _story(place, listing: listing),
    );
  }

  Widget _saveButton(Attraction spot, {bool compact = false}) {
    final saved = _saved.contains(spot.xid);
    return _ScanButton(
      label: saved ? context.l10n.saved : 'Save spot',
      icon: saved ? Icons.bookmark : Icons.bookmark_border,
      highlighted: saved,
      compact: compact,
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
    required this.save,
    required this.lookup,
    this.initialDetails,
    required this.onStory,
  });

  final ScanSpot spot;
  final Widget save;
  final Future<GooglePlaceDetails?> Function() lookup;
  final GooglePlaceDetails? initialDetails;
  final VoidCallback onStory;

  @override
  Widget build(BuildContext context) => _ResultPanel(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SizedBox(
                width: 88,
                child: spot.image == null
                    ? ColoredBox(
                        color: const Color(0xFF292720),
                        child: Icon(
                          spot.food ? Icons.restaurant : Icons.place_outlined,
                          color: VisualScanStyle.amber,
                        ),
                      )
                    : Image.asset(
                        spot.image!,
                        fit: BoxFit.cover,
                        excludeFromSemantics: true,
                      ),
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(12, 11, 12, 11),
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
                      Text(spot.place.name, style: VisualScanStyle.heading(16)),
                      const SizedBox(height: 4),
                      _NearbyScanFacts(
                        facts: nearbyScanFacts(spot.place),
                        lookup: lookup,
                        initialDetails: initialDetails,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
        const Divider(height: 1, color: VisualScanStyle.border),
        Container(
          color: VisualScanStyle.navigation,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
          child: Wrap(
            alignment: spot.distance.isEmpty
                ? WrapAlignment.end
                : WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 8,
            runSpacing: 6,
            children: [
              if (spot.distance.isNotEmpty)
                Text(spot.distance, style: _supportText.copyWith(fontSize: 11)),
              Wrap(
                spacing: 7,
                children: [
                  save,
                  _ScanButton(
                    label: 'Story',
                    icon: Icons.arrow_forward,
                    iconAfter: true,
                    prominent: true,
                    compact: true,
                    onPressed: onStory,
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

class _NearbyScanFacts extends StatefulWidget {
  const _NearbyScanFacts({
    required this.facts,
    required this.lookup,
    this.initialDetails,
  });
  final ScanPlaceFacts facts;
  final Future<GooglePlaceDetails?> Function() lookup;
  final GooglePlaceDetails? initialDetails;

  @override
  State<_NearbyScanFacts> createState() => _NearbyScanFactsState();
}

class _NearbyScanFactsState extends State<_NearbyScanFacts> {
  Future<GooglePlaceDetails?>? _details;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      _ScanFactsBlock(
        facts: widget.facts,
        listing: _details,
        initialDetails: widget.initialDetails,
      ),
      if (widget.facts.hours == null && _details == null)
        TextButton(
          style: TextButton.styleFrom(foregroundColor: VisualScanStyle.amber),
          onPressed: () => setState(() => _details = widget.lookup()),
          child: Text(context.l10n.scanCheckPlaceDetails),
        ),
    ],
  );
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
    this.isDish = false,
    this.listing,
    this.initialDetails,
    this.showDescriptionHeading = false,
  });

  final ScanPlaceFacts facts;
  final bool isDish;
  final Future<GooglePlaceDetails?>? listing;
  final GooglePlaceDetails? initialDetails;
  final bool showDescriptionHeading;

  @override
  Widget build(BuildContext context) => listing == null
      ? _body(context, initialDetails, loading: false)
      : FutureBuilder<GooglePlaceDetails?>(
          future: listing,
          builder: (context, snapshot) => _body(
            context,
            snapshot.data ?? initialDetails,
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
        (summary != null && summary.isNotEmpty ? summary : null);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (showDescriptionHeading) ...[
          Text(l10n.scanAboutLandmark, style: _amberText),
          const SizedBox(height: 4),
        ],
        Text(
          description ??
              place?.category ??
              (loading
                  ? l10n.scanCheckingPlaceDetails
                  : l10n.descriptionUnavailable),
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

class _ScanButton extends StatelessWidget {
  const _ScanButton({
    required this.label,
    required this.icon,
    required this.onPressed,
    this.iconAfter = false,
    this.prominent = false,
    this.highlighted = false,
    this.compact = false,
  });

  final String label;
  final IconData icon;
  final VoidCallback? onPressed;
  final bool iconAfter;
  final bool prominent;
  final bool highlighted;
  final bool compact;

  @override
  Widget build(BuildContext context) => FilledButton.icon(
    onPressed: onPressed,
    icon: Icon(icon, size: compact ? 13 : 16),
    iconAlignment: iconAfter ? IconAlignment.end : IconAlignment.start,
    label: Text(label),
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
      padding: EdgeInsets.symmetric(horizontal: compact ? 9 : 13, vertical: 7),
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
  );
}
