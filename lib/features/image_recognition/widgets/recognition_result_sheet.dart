import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:smart_travel_planner/features/image_recognition/data/visual_scan_results.dart';
import 'package:smart_travel_planner/features/image_recognition/models/recognition_result.dart';
import 'package:smart_travel_planner/features/image_recognition/services/image_recognition_service.dart';
import 'package:smart_travel_planner/features/image_recognition/widgets/visual_scan_style.dart';
import 'package:smart_travel_planner/features/places/screens/attraction_detail_page.dart';
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
    this.userId = 'guest',
  });

  final RecognitionResult result;
  final ImageRecognitionService service;
  final VoidCallback onNewScan;
  final VoidCallback? onBack;
  final Widget? image;
  final String userId;

  @override
  State<RecognitionResultSheet> createState() => _RecognitionResultSheetState();
}

enum _SpotFilter { all, food, attractions }

class _RecognitionResultSheetState extends State<RecognitionResultSheet> {
  late final _origin = scanLandmark(widget.result);
  late final _spots = scanSpots(widget.result, _origin);
  final _translations = <String, Future<RecognitionResult>>{};
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

  Future<void> _findRestaurants() async {
    final uri = Uri.https('www.google.com', '/maps/search/', {
      'api': '1',
      'query': '${widget.result.name} restaurants',
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
    if (target == 'en' || widget.result.isSample) return _body(widget.result);
    return FutureBuilder<RecognitionResult>(
      key: ValueKey(target),
      future: _translations.putIfAbsent(target, () => _translate(target)),
      builder: (_, snapshot) => _body(snapshot.data ?? widget.result),
    );
  }

  Widget _body(RecognitionResult result) {
    final source = widget.result;
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
    final status = switch (source.sampleId) {
      'petronas' => 'Confident visual match',
      'domes' => 'Plausible matches',
      'archway' => 'Needs a clue',
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
                    : 'Photo scan · Google Vision',
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
                Text(result.name, style: VisualScanStyle.heading(24)),
                if (result.description.isNotEmpty) ...[
                  const SizedBox(height: 7),
                  Text(
                    result.description,
                    style: _supportText.copyWith(fontSize: 14, height: 1.5),
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
                  for (final (index, (title, detail)) in evidence.indexed) ...[
                    if (index > 0)
                      const Divider(height: 20, color: VisualScanStyle.border),
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
                spot: spot,
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
  const _NearbySpotCard({required this.spot, required this.save, this.onStory});

  final ScanSpot spot;
  final Widget save;
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
                      if (spot.place.description case final description?) ...[
                        const SizedBox(height: 4),
                        Text(
                          description,
                          style: _supportText.copyWith(fontSize: 12),
                          maxLines: 3,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
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
