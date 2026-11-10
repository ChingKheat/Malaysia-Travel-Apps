import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';

import 'package:smart_travel_planner/core/theme/app_colors.dart';
import 'package:smart_travel_planner/core/theme/app_decorations.dart';
import 'package:smart_travel_planner/features/image_recognition/data/recognition_presets.dart';
import 'package:smart_travel_planner/features/image_recognition/models/recognition_result.dart';
import 'package:smart_travel_planner/features/image_recognition/screens/recognition_scan_screen.dart';
import 'package:smart_travel_planner/features/image_recognition/services/recognition_history_store.dart';
import 'package:smart_travel_planner/features/image_recognition/services/image_recognition_service.dart';
import 'package:smart_travel_planner/features/image_recognition/widgets/recognition_result_sheet.dart';

/// Capturing or selecting a photo starts a live scan.
class ImageRecognitionPage extends StatefulWidget {
  const ImageRecognitionPage({
    super.key,
    this.userId = 'guest',
    this.service,
    this.imagePicker,
  });

  final String userId;
  final ImageRecognitionService? service;
  final ImagePicker? imagePicker;

  @override
  State<ImageRecognitionPage> createState() => _ImageRecognitionPageState();
}

class _ImageRecognitionPageState extends State<ImageRecognitionPage> {
  late final ImagePicker _picker;
  late final ImageRecognitionService _service;
  late final RecognitionHistoryStore _store;

  Future<void> _pendingWrite = Future.value();
  List<RecognitionResult> _history = [];
  int _tab = 0;
  String _filter = 'all';
  bool _picking = false;
  bool _recognizing = false;

  @override
  void initState() {
    super.initState();
    _picker = widget.imagePicker ?? ImagePicker();
    _service = widget.service ?? ImageRecognitionService();
    _store = RecognitionHistoryStore(userId: widget.userId);
    unawaited(_loadHistory());
  }

  Future<void> _loadHistory() async {
    final history = await _store.load();
    if (mounted) {
      setState(
        () => _history = history.where((item) => !item.isSample).toList(),
      );
    }
  }

  void _saveHistory() {
    final entries = List<RecognitionResult>.of(_history);
    _pendingWrite = _pendingWrite.then((_) async {
      await _store.save(entries);
    });
  }

  void _openSample(RecognitionPreset preset) {
    _showResult(preset.sampleResult());
  }

  void _showResult(RecognitionResult result, {Uint8List? photo}) {
    final preset = recognitionPresets
        .where((item) => item.id == result.sampleId)
        .firstOrNull;
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      backgroundColor: Colors.white,
      constraints: const BoxConstraints(maxWidth: 560),
      builder: (_) => RecognitionResultSheet(
        result: result,
        service: _service,
        image: photo != null
            ? _photo(photo, height: 220)
            : preset == null
            ? null
            : _PresetImage(preset: preset, height: 200),
      ),
    );
  }

  Future<void> _pickPhoto(ImageSource source) async {
    if (_picking || _recognizing) return;
    setState(() => _picking = true);
    late final Uint8List bytes;
    try {
      final photo = await _picker.pickImage(
        source: source,
        maxWidth: 1600,
        maxHeight: 1600,
        imageQuality: 85,
        requestFullMetadata: false,
      );
      if (photo == null || !mounted) return;
      if (await photo.length() > ImageRecognitionService.maxImageBytes) {
        _notify('Choose a photo smaller than 4 MB.');
        return;
      }
      bytes = await photo.readAsBytes();
      if (bytes.isEmpty ||
          bytes.length > ImageRecognitionService.maxImageBytes) {
        _notify('Choose a photo smaller than 4 MB.');
        return;
      }
    } on MissingPluginException {
      _notify('Restart the app to enable the camera and photo library.');
      return;
    } on PlatformException {
      _notify(
        'Camera or photo library unavailable. Check access in Settings or try a sample.',
      );
      return;
    } catch (_) {
      _notify('This photo could not be opened. Try another photo or a sample.');
      return;
    } finally {
      if (mounted) setState(() => _picking = false);
    }
    if (mounted) await _recognize(bytes);
  }

  Future<void> _recognize(Uint8List bytes) async {
    if (_recognizing) return;
    setState(() => _recognizing = true);
    try {
      final outcome = await Navigator.push<ScanOutcome>(
        context,
        MaterialPageRoute(
          fullscreenDialog: true,
          builder: (_) => RecognitionScanScreen(
            photo: bytes,
            recognize: _service.recognize,
          ),
        ),
      );
      if (!mounted || outcome == null) return;
      final result = outcome.result;
      if (result == null) {
        _notify(outcome.error!);
        return;
      }
      setState(
        () => _history = [
          result,
          ..._history,
        ].take(RecognitionHistoryStore.maxEntries).toList(),
      );
      _saveHistory();
      _showResult(result, photo: bytes);
    } finally {
      if (mounted) setState(() => _recognizing = false);
    }
  }

  void _notify(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
      );
  }

  Widget _photo(Uint8List bytes, {required double height}) => SizedBox(
    height: height,
    width: double.infinity,
    child: ColoredBox(
      color: AppColors.ink,
      child: Image.memory(
        bytes,
        fit: BoxFit.contain,
        errorBuilder: (_, _, _) => const Center(
          child: Text(
            'Photo preview unavailable',
            style: TextStyle(color: Colors.white),
          ),
        ),
      ),
    ),
  );

  Future<void> _clearHistory() async {
    final clear = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.white,
        title: const Text(
          'Clear scan history?',
          style: TextStyle(color: AppColors.ink),
        ),
        content: const Text(
          'Remove all scan results saved on this device? This cannot be undone.',
          style: TextStyle(color: AppColors.muted),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Clear'),
          ),
        ],
      ),
    );
    if (clear != true || !mounted) return;
    setState(() => _history = []);
    _saveHistory();
  }

  @override
  Widget build(BuildContext context) => Material(
    color: Theme.of(context).scaffoldBackgroundColor,
    child: Column(
      children: [
        _header(),
        Expanded(
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 180),
            child: switch (_tab) {
              1 => _presets(),
              2 => _historyTab(),
              _ => _scanner(),
            },
          ),
        ),
      ],
    ),
  );

  Widget _header() => Padding(
    padding: const EdgeInsets.fromLTRB(20, 4, 20, 0),
    child: Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.line),
      ),
      child: Row(
        children: [
          _tabButton(0, Icons.photo_camera_outlined, 'Scanner'),
          _tabButton(1, Icons.auto_awesome_outlined, 'Demo Results'),
          _tabButton(2, Icons.history, 'History (${_history.length})'),
        ],
      ),
    ),
  );

  Widget _tabButton(int index, IconData icon, String title) => Expanded(
    child: Semantics(
      selected: _tab == index,
      button: true,
      child: Material(
        color: _tab == index ? AppColors.primary : Colors.transparent,
        borderRadius: BorderRadius.circular(10),
        child: InkWell(
          borderRadius: BorderRadius.circular(10),
          onTap: () => setState(() => _tab = index),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 10),
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Row(
                children: [
                  Icon(
                    icon,
                    size: 15,
                    color: _tab == index ? Colors.white : AppColors.muted,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: _tab == index ? Colors.white : AppColors.muted,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    ),
  );

  Widget _scanner() => ListView(
    key: const PageStorageKey('recognition-scanner'),
    padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
    children: [
      const Text(
        'How to take a good photo',
        style: TextStyle(
          color: AppColors.ink,
          fontSize: 22,
          fontWeight: FontWeight.w800,
        ),
      ),
      const SizedBox(height: 5),
      const Text(
        'Frame one dish or landmark so it’s easy to identify.',
        style: TextStyle(color: AppColors.muted, fontSize: 13, height: 1.4),
      ),
      const SizedBox(height: 14),
      const IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: _PhotoTip(
                asset: 'assets/recognition/nasi_lemak.jpg',
                photoDescription: 'A plate of nasi lemak centered in the frame',
                category: '01  FOOD',
                caption: 'Center the subject',
                instruction:
                    'Shoot from above and leave a little space around the whole plate.',
                fit: BoxFit.contain,
              ),
            ),
            SizedBox(width: 12),
            Expanded(
              child: _PhotoTip(
                asset: 'assets/recognition/batu_caves.jpg',
                photoDescription: 'The golden statue and steps at Batu Caves',
                category: '02  LANDMARK',
                caption: 'Include the key feature',
                instruction:
                    'Step back to fit the statue and steps. Wait for a clear view.',
              ),
            ),
          ],
        ),
      ),
      const SizedBox(height: 12),
      DecoratedBox(
        decoration: BoxDecoration(
          color: AppColors.primary.withValues(alpha: 0.07),
          borderRadius: BorderRadius.circular(14),
        ),
        child: const Padding(
          padding: EdgeInsets.all(12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                Icons.light_mode_outlined,
                color: AppColors.primary,
                size: 20,
              ),
              SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Check the light and focus',
                      style: TextStyle(
                        color: AppColors.ink,
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      'Use soft light from the front or side. Tap the subject to focus and hold your phone steady.',
                      style: TextStyle(
                        color: AppColors.muted,
                        fontSize: 12,
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
      const SizedBox(height: 14),
      const Text(
        'Selected photos are sent to Google Vision for scanning. Only result text is saved in History on this device.',
        style: TextStyle(color: AppColors.muted, fontSize: 12, height: 1.4),
      ),
      const SizedBox(height: 10),
      IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: FilledButton.icon(
                onPressed: _picking || _recognizing
                    ? null
                    : () => _pickPhoto(ImageSource.camera),
                icon: const Icon(Icons.photo_camera_outlined, size: 20),
                label: const Text('Take Photo', textAlign: TextAlign.center),
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  minimumSize: const Size(0, 54),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 12,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                  textStyle: Theme.of(context).textTheme.labelLarge?.copyWith(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: OutlinedButton.icon(
                onPressed: _picking || _recognizing
                    ? null
                    : () => _pickPhoto(ImageSource.gallery),
                icon: const Icon(Icons.photo_library_outlined, size: 20),
                label: const Text(
                  'Upload from Gallery',
                  textAlign: TextAlign.center,
                ),
                style: OutlinedButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: AppColors.primaryDark,
                  minimumSize: const Size(0, 54),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 12,
                  ),
                  side: const BorderSide(color: AppColors.line),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                  textStyle: Theme.of(context).textTheme.labelLarge?.copyWith(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
      if (_picking) ...[
        const SizedBox(height: 12),
        const LinearProgressIndicator(color: AppColors.primary),
      ],
      const SizedBox(height: 16),
      const Text(
        'Sample scans work offline. Live recognition and translation require an online account.',
        textAlign: TextAlign.center,
        style: TextStyle(color: AppColors.muted, fontSize: 11, height: 1.5),
      ),
    ],
  );

  Widget _presets() {
    final presets = recognitionPresets
        .where((item) => _filter == 'all' || item.kind == _filter)
        .toList();
    return ListView(
      key: const PageStorageKey('recognition-presets'),
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 28),
      children: [
        const Text(
          'Try prepared recognition results',
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 10),
        const Text(
          'Browse prepared landmark and food results to understand what the finished recognition screen will show.',
          style: TextStyle(color: AppColors.muted, fontSize: 13, height: 1.6),
        ),
        const SizedBox(height: 16),
        Wrap(
          spacing: 8,
          runSpacing: 6,
          children: [
            for (final entry in {
              'all': 'All',
              'landmark': 'Landmarks',
              'food': 'Food',
            }.entries)
              ChoiceChip(
                label: Text(entry.value),
                selected: _filter == entry.key,
                selectedColor: AppColors.primary,
                backgroundColor: Colors.white,
                checkmarkColor: Colors.white,
                labelStyle: TextStyle(
                  color: _filter == entry.key ? Colors.white : AppColors.ink,
                ),
                onSelected: (_) => setState(() => _filter = entry.key),
              ),
          ],
        ),
        const SizedBox(height: 20),
        for (final preset in presets)
          Padding(
            padding: const EdgeInsets.only(bottom: 14),
            child: Material(
              color: Colors.white,
              borderRadius: BorderRadius.circular(18),
              clipBehavior: Clip.antiAlias,
              child: InkWell(
                onTap: () => _openSample(preset),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _PresetImage(preset: preset, height: 160),
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _Badge(preset.kind.toUpperCase()),
                          const SizedBox(height: 10),
                          Text(
                            preset.name,
                            style: const TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            preset.location,
                            style: const TextStyle(
                              color: AppColors.muted,
                              fontSize: 12,
                            ),
                          ),
                          const SizedBox(height: 14),
                          const Row(
                            children: [
                              Expanded(
                                child: Text(
                                  'View demo result',
                                  style: TextStyle(
                                    color: AppColors.primary,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                              SizedBox(width: 8),
                              Icon(
                                Icons.arrow_forward,
                                color: AppColors.primary,
                                size: 16,
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _historyTab() => ListView(
    key: const PageStorageKey('recognition-history'),
    padding: const EdgeInsets.fromLTRB(20, 24, 20, 28),
    children: [
      Row(
        children: [
          const Expanded(
            child: Text(
              'Recent scans',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
            ),
          ),
          if (_history.isNotEmpty)
            TextButton(
              onPressed: _clearHistory,
              child: const Text('Clear history'),
            ),
        ],
      ),
      const SizedBox(height: 10),
      const Text(
        'Your completed recognition results will appear here. Demo results stay separate. History is currently stored on this device.',
        style: TextStyle(color: AppColors.muted, fontSize: 13),
      ),
      const SizedBox(height: 24),
      if (_history.isEmpty)
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
          decoration: _panelDecoration(),
          child: Column(
            children: [
              const Icon(Icons.history, size: 44, color: AppColors.primary),
              const SizedBox(height: 18),
              const Text(
                'No scans yet',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 10),
              const Text(
                'After live recognition is connected, successful scans will be saved here automatically.',
                textAlign: TextAlign.center,
                style: TextStyle(color: AppColors.muted, height: 1.6),
              ),
              const SizedBox(height: 20),
              FilledButton(
                onPressed: () => setState(() => _tab = 0),
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                ),
                child: const Text('Go to Scanner'),
              ),
            ],
          ),
        ),
      for (final result in _history) ...[
        Builder(
          builder: (context) {
            final preset = recognitionPresets
                .where((item) => item.id == result.sampleId)
                .firstOrNull;
            final date = result.recognizedAt.toLocal();
            final timestamp =
                '${MaterialLocalizations.of(context).formatShortDate(date)} · '
                '${TimeOfDay.fromDateTime(date).format(context)}';
            return Material(
              color: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
                side: const BorderSide(color: AppColors.line),
              ),
              child: ListTile(
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                leading: preset == null
                    ? const Icon(Icons.image_outlined, color: AppColors.primary)
                    : ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: _PresetImage(
                          preset: preset,
                          height: 48,
                          width: 48,
                        ),
                      ),
                title: Text(
                  result.name,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                subtitle: Padding(
                  padding: const EdgeInsets.only(top: 5),
                  child: Text(
                    '${result.isSample ? 'Sample · ' : ''}$timestamp',
                    style: const TextStyle(
                      color: AppColors.muted,
                      fontSize: 10,
                    ),
                  ),
                ),
                trailing: const Icon(
                  Icons.chevron_right,
                  color: AppColors.muted,
                  size: 20,
                ),
                onTap: () => _showResult(result),
              ),
            );
          },
        ),
        const SizedBox(height: 10),
      ],
    ],
  );
}

BoxDecoration _panelDecoration() => cardDecoration();

class _PhotoTip extends StatelessWidget {
  const _PhotoTip({
    required this.asset,
    required this.photoDescription,
    required this.category,
    required this.caption,
    required this.instruction,
    this.fit = BoxFit.cover,
  });

  final String asset;
  final String photoDescription;
  final String category;
  final String caption;
  final String instruction;
  final BoxFit fit;

  @override
  Widget build(BuildContext context) => Container(
    clipBehavior: Clip.antiAlias,
    decoration: BoxDecoration(
      color: Colors.white,
      border: Border.all(color: AppColors.line),
      borderRadius: BorderRadius.circular(16),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AspectRatio(
          aspectRatio: 1.25,
          child: ColoredBox(
            color: const Color(0xFFF0EFED),
            child: Image.asset(
              asset,
              fit: fit,
              semanticLabel: photoDescription,
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(11, 10, 11, 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                category,
                style: const TextStyle(
                  color: AppColors.primaryDark,
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.6,
                ),
              ),
              const SizedBox(height: 5),
              Text(
                caption,
                style: const TextStyle(
                  color: AppColors.ink,
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 5),
              Text(
                instruction,
                style: const TextStyle(
                  color: AppColors.muted,
                  fontSize: 12,
                  height: 1.4,
                ),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}

class _PresetImage extends StatelessWidget {
  const _PresetImage({
    required this.preset,
    required this.height,
    this.width = double.infinity,
  });
  final RecognitionPreset preset;
  final double height;
  final double width;

  @override
  Widget build(BuildContext context) => Image.asset(
    preset.imageAsset,
    height: height,
    width: width,
    fit: BoxFit.cover,
    excludeFromSemantics: true,
    errorBuilder: (_, _, _) => Container(
      height: height,
      width: width,
      color: AppColors.primary.withValues(alpha: 0.2),
      child: Icon(
        preset.kind == 'food' ? Icons.restaurant : Icons.location_city,
        color: AppColors.primary,
      ),
    ),
  );
}

class _Badge extends StatelessWidget {
  const _Badge(this.label);
  final String label;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
    decoration: BoxDecoration(
      color: AppColors.primary.withValues(alpha: 0.1),
      borderRadius: BorderRadius.circular(6),
    ),
    child: Text(
      label,
      style: const TextStyle(
        color: AppColors.primary,
        fontSize: 9,
        fontWeight: FontWeight.w800,
        letterSpacing: 0.5,
      ),
    ),
  );
}
