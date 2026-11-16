import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:smart_travel_planner/features/image_recognition/data/scan_place_facts.dart';
import 'package:smart_travel_planner/features/image_recognition/data/visual_scan_results.dart';
import 'package:smart_travel_planner/features/image_recognition/models/recognition_result.dart';
import 'package:smart_travel_planner/features/image_recognition/services/image_recognition_service.dart';
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
    this.image,
    this.onReferenceSelected,
    this.userId = 'guest',
  });

  final RecognitionResult result;
  final ImageRecognitionService service;
  final VoidCallback onNewScan;
  final VoidCallback? onBack;
  final Widget? image;
  final ValueChanged<String>? onReferenceSelected;
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

  void _story(Attraction place) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => AttractionDetailPage(attraction: place),
      ),
    );
  }

  Future<void> _findRestaurants() =>
      _openMapSearch('${widget.result.name} restaurants');

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

  Future<void> _searchForPlace({String? clue}) async {
    final l10n = context.l10n;
    var query = clue ?? '';
    final selection = await showDialog<({String query, bool maps})>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.scanSearchPlace),
        content: TextFormField(
          initialValue: clue == null ? null : '$clue ',
          autofocus: true,
          maxLength: 120,
          textInputAction: TextInputAction.search,
          decoration: InputDecoration(hintText: l10n.scanPlaceSearchHint),
          onChanged: (value) => query = value,
          onFieldSubmitted: (value) {
            if (value.trim().isNotEmpty) {
              Navigator.pop(context, (query: value.trim(), maps: false));
            }
          },
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(l10n.cancel),
          ),
          FilledButton(
            onPressed: () {
              if (query.trim().isNotEmpty) {
                Navigator.pop(context, (query: query.trim(), maps: false));
              }
            },
            child: Text(MaterialLocalizations.of(context).searchFieldLabel),
          ),
          TextButton(
            onPressed: () {
              if (query.trim().isNotEmpty) {
                Navigator.pop(context, (query: query.trim(), maps: true));
              }
            },
            child: Text(l10n.scanOpenMaps),
          ),
        ],
      ),
    );
    if (!mounted || selection == null) return;
    if (selection.maps) {
      await _openMapSearch('${selection.query} Malaysia');
      return;
    }
    final search = widget.service.searchPlaces(selection.query);
    final place = await showModalBottomSheet<GooglePlaceDetails>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: SizedBox(
          height: MediaQuery.sizeOf(context).height * .55,
          child: FutureBuilder<List<GooglePlaceDetails>>(
            future: search,
            builder: (context, snapshot) {
              if (snapshot.connectionState != ConnectionState.done) {
                return const Center(child: CircularProgressIndicator());
              }
              final places = snapshot.data ?? const [];
              return ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  Text(
                    l10n.searchResults,
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  if (places.isEmpty) Text(l10n.noPlacesFound),
                  for (final place in places)
                    ListTile(
                      title: Text(place.name ?? ''),
                      subtitle: place.address == null
                          ? null
                          : Text(place.address!),
                      onTap: () => Navigator.pop(context, place),
                    ),
                  if (places.isNotEmpty)
                    GoogleMapsAttribution(
                      attributions: [
                        for (final place in places) ...place.attributions,
                      ],
                    ),
                  TextButton(
                    onPressed: () =>
                        _openMapSearch('${selection.query} Malaysia'),
                    child: Text(l10n.scanOpenMaps),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
    if (!mounted || place == null) return;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      backgroundColor: VisualScanStyle.surface,
      builder: (context) => SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 26),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                place.name ?? selection.query,
                style: VisualScanStyle.heading(22),
              ),
              const SizedBox(height: 8),
              _ScanFactsBlock(
                facts: scanFacts(place.name ?? selection.query),
                initialListing: place,
                listing: _listing(place.name ?? selection.query, place.id),
              ),
              _ScanButton(
                label: l10n.scanOpenMaps,
                icon: Icons.map_outlined,
                onPressed: () =>
                    _openMapSearch(place.address ?? '${place.name} Malaysia'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<GooglePlaceDetails?> _listing(String name, [String? id]) =>
      _lookupJobs.putIfAbsent(id ?? name, () async {
        try {
          final summary = id == null
              ? await widget.service.lookupPlace(name)
              : null;
          final placeId = id ?? summary?.id;
          return placeId == null
              ? null
              : await _googlePlaces.fetchDetails(placeId) ?? summary;
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
        widget.result.referenceCandidates.isNotEmpty) {
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
    final facts = scanFacts(source.name, description: result.description);
    final sample = visualScanSamples
        .where((item) => item.id == source.sampleId)
        .firstOrNull;
    final spots = _spots.where(
      (spot) => switch (_filter) {
        _SpotFilter.all => true,
        _SpotFilter.food => spot.food,
        _SpotFilter.attractions => !spot.food,
      },
    );
    final status = switch ((source.sampleId, source.source)) {
      ('petronas', _) => 'Confident visual match',
      ('domes', _) => 'Plausible matches',
      ('archway', _) => 'Needs a clue',
      (_, RecognitionSource.userConfirmedReference) =>
        l10n.referenceMatchSelected,
      (_, RecognitionSource.userConfirmedClue) => l10n.referenceMatchSelected,
      (_, RecognitionSource.web) =>
        candidates.isEmpty
            ? l10n.scanWebMatchFound
            : l10n.referenceMatchUncertain,
      (_, RecognitionSource.sign) => l10n.scanSignClue,
      (_, RecognitionSource.visualEvidence) => l10n.referenceMatchUncertain,
      (_, RecognitionSource.placeLookup) => l10n.referenceMatchUncertain,
      (_, RecognitionSource.vision) when candidates.isNotEmpty =>
        l10n.referenceMatchUncertain,
      (_, RecognitionSource.reference) =>
        candidates.isEmpty
            ? l10n.referenceMatchFound
            : l10n.referenceMatchUncertain,
      _ =>
        source.kind == 'unknown'
            ? 'Needs a clue'
            : source.confidence == null
            ? 'Possible visual match'
            : 'Confident visual match',
    };
    final evidence = source.sampleId == 'petronas'
        ? const [
            (
              'Double-decker Skybridge',
              'Hinged two-level span linking floors 41 and 42 at 170 m.',
            ),
            (
              'Stepped Islamic Star Plan',
              'Alternating triangular and rounded stainless-steel bays.',
            ),
            (
              'KLCC Lakefront Basin',
              'Reflective fountain promenade and tropical park foreground.',
            ),
          ]
        : [for (final label in result.labels.toSet().take(3)) (label, '')];

    return ListView(
      key: const PageStorageKey('visual-scan-result'),
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
                    ? 'Built-in sample · Mock recognition'
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
                        RecognitionSource.userConfirmedClue =>
                          l10n.scanSelectedSource,
                      },
                style: _supportText,
              ),
            ),
            _ScanButton(
              label: 'New scan',
              icon: Icons.restart_alt,
              compact: true,
              onPressed: widget.onNewScan,
            ),
          ],
        ),
        if (widget.image != null) ...[
          const SizedBox(height: 20),
          _ResultPanel(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                AspectRatio(aspectRatio: 1.82, child: widget.image),
                Padding(
                  padding: const EdgeInsets.fromLTRB(10, 8, 10, 9),
                  child: Text(
                    sample == null
                        ? 'Original photo'
                        : 'Original photo · ${sample.title}',
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
                  candidates.isEmpty
                      ? result.name
                      : l10n.referencePossibleMatches,
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
                  Text(l10n.referenceChooseSubject, style: _supportText),
                  const SizedBox(height: 12),
                  for (final candidate in candidates)
                    _ScanCandidateCard(
                      candidate: candidate,
                      listing:
                          candidate.kind == 'landmark' &&
                              candidateScanFacts(candidate).hours == null
                          ? _listing(candidate.name, candidate.placeId)
                          : null,
                      onTap: widget.onReferenceSelected == null
                          ? null
                          : () => widget.onReferenceSelected!(candidate.id),
                    ),
                ],
                if (source.kind != 'unknown') ...[
                  const SizedBox(height: 8),
                  _ScanFactsBlock(
                    facts: facts,
                    isDish: source.kind == 'food',
                    listing:
                        !source.isSample &&
                            source.kind == 'landmark' &&
                            facts.hours == null
                        ? _listing(source.name, source.placeId)
                        : null,
                  ),
                ] else if (result.description.isNotEmpty) ...[
                  const SizedBox(height: 7),
                  Text(
                    result.description,
                    style: _supportText.copyWith(fontSize: 14, height: 1.5),
                  ),
                ],
                if (source.webSources.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  Text(source.webSources.join(' · '), style: _supportText),
                ],
                if (!source.isSample && source.kind == 'unknown') ...[
                  const SizedBox(height: 14),
                  _ScanButton(
                    label: l10n.scanSearchPlace,
                    icon: Icons.search,
                    onPressed: _searchForPlace,
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
                if (_origin case final place?) ...[
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
                        onPressed: () => _story(place),
                      ),
                      _saveButton(place),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ),
        if (evidence.isNotEmpty) ...[
          const SizedBox(height: 16),
          _ResultPanel(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Supporting visual evidence',
                    style: VisualScanStyle.heading(17),
                  ),
                  const SizedBox(height: 12),
                  if (!source.isSample && source.kind == 'unknown') ...[
                    Text(l10n.scanSearchWithClue, style: _supportText),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 4,
                      children: [
                        for (final (title, _) in evidence)
                          ActionChip(
                            avatar: const Icon(Icons.search, size: 16),
                            label: Text(title),
                            onPressed: () => _searchForPlace(clue: title),
                          ),
                      ],
                    ),
                  ] else
                    for (final (index, (title, detail))
                        in evidence.indexed) ...[
                      if (index > 0)
                        const Divider(
                          height: 20,
                          color: VisualScanStyle.border,
                        ),
                      Text(
                        title,
                        style: const TextStyle(
                          color: VisualScanStyle.text,
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      if (detail.isNotEmpty) ...[
                        const SizedBox(height: 3),
                        Text(detail, style: _supportText),
                      ],
                    ],
                ],
              ),
            ),
          ),
        ],
        if (_origin != null || _spots.isNotEmpty || source.kind == 'food') ...[
          const SizedBox(height: 24),
          Text(
            source.kind == 'food'
                ? 'Where to try it'
                : 'Nearby attractions & food',
            style: VisualScanStyle.heading(20),
          ),
          const SizedBox(height: 4),
          Text(
            source.sampleId == 'petronas'
                ? 'Walking distance around KLCC Skyline District · sample estimates'
                : _origin != null
                ? 'Within 15 km of ${result.name} · straight-line distances'
                : 'Places in the travel guide that list this dish',
            style: _supportText,
          ),
          if (_spots.isNotEmpty) ...[
            const SizedBox(height: 12),
            _ResultPanel(
              child: Padding(
                padding: const EdgeInsets.all(4),
                child: Row(
                  children: [
                    for (final (filter, label) in const [
                      (_SpotFilter.all, 'All'),
                      (_SpotFilter.food, 'Food & Cafés'),
                      (_SpotFilter.attractions, 'Attractions'),
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
                              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(9),
                              ),
                              textStyle: Theme.of(
                                context,
                              ).textTheme.labelLarge?.copyWith(fontSize: 12),
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
            if (spots.isEmpty)
              const Text('No places in this category.', style: _supportText),
            for (final spot in spots) ...[
              _NearbySpotCard(
                key: ValueKey(spot.place.xid),
                spot: spot,
                lookup: () =>
                    _listing(spot.place.name, spot.place.googlePlaceId),
                save: _saveButton(spot.place, compact: true),
                onStory: spot.food ? null : () => _story(spot.place),
              ),
              const SizedBox(height: 10),
            ],
          ],
          if (source.kind == 'food')
            Align(
              alignment: Alignment.centerLeft,
              child: _ScanButton(
                label: context.l10n.findRestaurants,
                icon: Icons.search,
                onPressed: _findRestaurants,
              ),
            ),
        ],
      ],
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
  Widget build(BuildContext context) => Container(
    clipBehavior: Clip.antiAlias,
    decoration: BoxDecoration(
      color: VisualScanStyle.surface,
      border: Border.all(
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
    this.onStory,
  });

  final ScanSpot spot;
  final Widget save;
  final Future<GooglePlaceDetails?> Function() lookup;
  final VoidCallback? onStory;

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
            alignment: WrapAlignment.spaceBetween,
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
                  if (onStory != null)
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
  const _NearbyScanFacts({required this.facts, required this.lookup});
  final ScanPlaceFacts facts;
  final Future<GooglePlaceDetails?> Function() lookup;

  @override
  State<_NearbyScanFacts> createState() => _NearbyScanFactsState();
}

class _NearbyScanFactsState extends State<_NearbyScanFacts> {
  Future<GooglePlaceDetails?>? _details;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      _ScanFactsBlock(facts: widget.facts, listing: _details),
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
    this.initialListing,
  });

  final ScanPlaceFacts facts;
  final bool isDish;
  final Future<GooglePlaceDetails?>? listing;
  final GooglePlaceDetails? initialListing;

  @override
  Widget build(BuildContext context) => listing == null
      ? _body(context, initialListing, loading: false)
      : FutureBuilder<GooglePlaceDetails?>(
          future: listing,
          builder: (context, snapshot) => _body(
            context,
            snapshot.data ?? initialListing,
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          place?.description ??
              facts.description ??
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
