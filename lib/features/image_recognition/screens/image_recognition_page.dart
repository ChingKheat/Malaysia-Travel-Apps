import 'package:smart_travel_planner/l10n/localized_labels.dart';
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:uuid/uuid.dart';

import 'package:smart_travel_planner/core/theme/app_colors.dart';
import 'package:smart_travel_planner/features/image_recognition/models/recognition_result.dart';
import 'package:smart_travel_planner/features/image_recognition/screens/recognition_scan_screen.dart';
import 'package:smart_travel_planner/features/image_recognition/services/recognition_history_store.dart';
import 'package:smart_travel_planner/features/image_recognition/services/image_recognition_service.dart';
import 'package:smart_travel_planner/features/image_recognition/widgets/recognition_result_sheet.dart';
import 'package:smart_travel_planner/features/image_recognition/widgets/scan_photo_guidance.dart';

import 'package:smart_travel_planner/features/image_recognition/widgets/visual_scan_style.dart';

/// Capturing or selecting a photo starts a live scan.
class ImageRecognitionPage extends StatefulWidget {
  const ImageRecognitionPage({
    super.key,
    this.userId = 'guest',
    this.service,
    this.imagePicker,
    this.historyStore,
  });

  final String userId;
  final ImageRecognitionService? service;
  final ImagePicker? imagePicker;
  final RecognitionHistoryStore? historyStore;

  @override
  State<ImageRecognitionPage> createState() => _ImageRecognitionPageState();
}

class _ImageRecognitionPageState extends State<ImageRecognitionPage> {
  late final ImagePicker _picker;
  late final ImageRecognitionService _service;
  late final RecognitionHistoryStore _store;

  Future<void> _pendingWrite = Future.value();
  late final Future<void> _historyLoaded;
  List<RecognitionHistoryEntry> _history = [];
  bool _showHistory = false;
  int _scannerVersion = 0;
  RecognitionResult? _result;
  ImageProvider<Object>? _resultPhoto;
  bool _picking = false;
  bool _recognizing = false;

  @override
  void initState() {
    super.initState();
    _picker = widget.imagePicker ?? ImagePicker();
    _service = widget.service ?? ImageRecognitionService();
    _store =
        widget.historyStore ?? RecognitionHistoryStore(userId: widget.userId);
    _historyLoaded = _loadHistory();
  }

  Future<void> _loadHistory() async {
    final history = await _store.load();
    if (mounted) {
      setState(
        () =>
            _history = history.where((item) => !item.result.isSample).toList(),
      );
    }
  }

  void _saveHistory({(String, Uint8List)? photo}) {
    final entries = List<RecognitionHistoryEntry>.of(_history);
    _pendingWrite = _pendingWrite.then((_) async {
      await _store.save(entries, photo: photo);
    });
  }

  void _showResult(RecognitionResult result, {ImageProvider<Object>? photo}) {
    setState(() {
      _result = result;
      _resultPhoto = photo;
    });
  }

  Future<void> _showHistoryEntry(RecognitionHistoryEntry entry) async {
    _showResult(entry.result);
    if (entry.photoId == null) return;
    await _pendingWrite;
    final bytes = await _store.loadPhoto(entry.photoId);
    if (mounted && identical(_result, entry.result) && bytes != null) {
      setState(() => _resultPhoto = MemoryImage(bytes));
    }
  }

  void _confirmReference(RecognitionResult result, String id) {
    _replaceResult(result, _service.confirmReference(result, id));
  }

  void _replaceResult(RecognitionResult result, RecognitionResult selected) {
    if (_result != result) return;
    if (identical(selected, result)) return;
    setState(() {
      _result = selected;
      _history = [
        for (final entry in _history)
          identical(entry.result, result)
              ? (result: selected, photoId: entry.photoId)
              : entry,
      ];
    });
    _saveHistory();
  }

  void _closeResult({required bool newScan}) {
    setState(() {
      _result = null;
      _resultPhoto = null;
      if (newScan) {
        _showHistory = false;
        _scannerVersion++;
      }
    });
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
      _notify('Camera or photo library unavailable. Check access in Settings.');
      return;
    } catch (_) {
      _notify('This photo could not be opened. Try another photo.');
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
      await _historyLoaded;
      if (!mounted) return;
      final photoId = const Uuid().v4();
      setState(
        () => _history = [
          (result: result, photoId: photoId),
          ..._history,
        ].take(RecognitionHistoryStore.maxEntries).toList(),
      );
      _saveHistory(photo: (photoId, bytes));
      _showResult(result, photo: MemoryImage(bytes));
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
          content: Text(context.tr(message)),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
      );
  }

  Future<void> _clearHistory() async {
    final clear = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.white,
        title: Text(
          context.l10n.clearScanHistory,
          style: TextStyle(color: AppColors.ink),
        ),
        content: Text(
          context.l10n.removeAllScanResultsSavedOnThisDeviceThisCannotBeUndone,
          style: TextStyle(color: AppColors.muted),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(context.l10n.cancel),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(context.l10n.clear),
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
    color: VisualScanStyle.background,
    child: AnimatedSwitcher(
      duration: const Duration(milliseconds: 180),
      child: switch (_result) {
        final result? => RecognitionResultSheet(
          key: ObjectKey(result),
          result: result,
          service: _service,
          userId: widget.userId,
          photo: _resultPhoto,
          onReferenceSelected: (id) => _confirmReference(result, id),
          onTakeAnotherPhoto: _picking || _recognizing
              ? null
              : () => _pickPhoto(ImageSource.camera),
          onUploadAnotherPhoto: _picking || _recognizing
              ? null
              : () => _pickPhoto(ImageSource.gallery),
          onBack: _showHistory ? () => _closeResult(newScan: false) : null,
          onNewScan: () => _closeResult(newScan: true),
        ),
        null => _showHistory ? _historyTab() : _scanner(),
      },
    ),
  );

  Widget _scanner() => ListView(
    key: PageStorageKey('recognition-scanner-$_scannerVersion'),
    padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
    children: [
      Container(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 23),
        decoration: _scanPanel(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                const Expanded(
                  child: Text('Visual Landmark Guide', style: _scanEyebrow),
                ),
                const SizedBox(width: 8),
                OutlinedButton.icon(
                  key: const ValueKey('scan-history'),
                  onPressed: () => setState(() => _showHistory = true),
                  icon: const Icon(Icons.history, size: 17),
                  label: Text(context.l10n.history),
                  style: VisualScanStyle.headerButton,
                ),
              ],
            ),
            Text(
              context.l10n.scanIdentifyLandmark,
              style: VisualScanStyle.heading(22),
            ),
            const SizedBox(height: 19),
            Text(
              context.l10n.scanPhotoIntro,
              style: const TextStyle(
                color: VisualScanStyle.muted,
                fontSize: 14,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 20),
            LayoutBuilder(
              builder: (context, constraints) {
                final actions = [
                  _scanAction(
                    label: context.l10n.takePhoto,
                    icon: Icons.photo_camera_outlined,
                    source: ImageSource.camera,
                  ),
                  _scanAction(
                    label: Localizations.localeOf(context).languageCode == 'en'
                        ? 'Upload Image'
                        : context.l10n.uploadFromGallery,
                    icon: Icons.file_upload_outlined,
                    source: ImageSource.gallery,
                  ),
                ];
                if (constraints.maxWidth < 235 ||
                    MediaQuery.textScalerOf(context).scale(14) > 19) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      actions.first,
                      const SizedBox(height: 8),
                      actions.last,
                    ],
                  );
                }
                return Row(
                  children: [
                    Expanded(child: actions.first),
                    const SizedBox(width: 10),
                    Expanded(child: actions.last),
                  ],
                );
              },
            ),
            if (_picking) ...[
              const SizedBox(height: 12),
              const LinearProgressIndicator(color: VisualScanStyle.amber),
            ],
          ],
        ),
      ),
      const SizedBox(height: 25),
      Container(
        decoration: _scanPanel(),
        padding: const EdgeInsets.all(16),
        child: const ScanPhotoGuidance(),
      ),
      const SizedBox(height: 14),
      Text(
        context.l10n.scanHistoryPhotoPrivacy,
        style: const TextStyle(color: VisualScanStyle.muted, fontSize: 12),
      ),
    ],
  );

  Widget _scanAction({
    required String label,
    required IconData icon,
    required ImageSource source,
  }) {
    final primary = source == ImageSource.camera;
    return FilledButton.icon(
      onPressed: _picking || _recognizing ? null : () => _pickPhoto(source),
      icon: Icon(icon, size: 16),
      label: Text(label, textAlign: TextAlign.center),
      style: FilledButton.styleFrom(
        backgroundColor: primary
            ? VisualScanStyle.amber
            : const Color(0xFF262522),
        foregroundColor: primary
            ? VisualScanStyle.background
            : VisualScanStyle.text,
        disabledBackgroundColor: VisualScanStyle.border,
        disabledForegroundColor: VisualScanStyle.muted,
        minimumSize: const Size(0, 48),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(13)),
        side: primary ? null : const BorderSide(color: Color(0xFF38352F)),
        textStyle: Theme.of(context).textTheme.labelLarge?.copyWith(
          fontSize: 14,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Widget _historyTab() => ListView(
    key: const PageStorageKey('recognition-history'),
    padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
    children: [
      Row(
        children: [
          BackButton(
            color: VisualScanStyle.amber,
            onPressed: () => setState(() => _showHistory = false),
          ),
          Expanded(
            child: Text(
              context.l10n.history,
              style: VisualScanStyle.heading(22),
            ),
          ),
          if (_history.isNotEmpty)
            TextButton(
              onPressed: _clearHistory,
              style: TextButton.styleFrom(
                foregroundColor: VisualScanStyle.amber,
              ),
              child: Text(context.l10n.clearHistory),
            ),
        ],
      ),
      const SizedBox(height: 12),
      if (_history.isEmpty)
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 36),
          decoration: _scanPanel(),
          child: Column(
            children: [
              const Icon(Icons.history, size: 36, color: VisualScanStyle.amber),
              const SizedBox(height: 12),
              Text(context.l10n.noScansYet, style: VisualScanStyle.heading(18)),
              const SizedBox(height: 12),
              TextButton(
                onPressed: () => setState(() => _showHistory = false),
                style: TextButton.styleFrom(
                  foregroundColor: VisualScanStyle.amber,
                ),
                child: Text(context.l10n.goToScanner),
              ),
            ],
          ),
        ),
      for (final entry in _history) ...[
        Material(
          color: VisualScanStyle.surface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
            side: const BorderSide(color: VisualScanStyle.border),
          ),
          child: ListTile(
            leading: const Icon(
              Icons.image_outlined,
              color: VisualScanStyle.amber,
            ),
            title: Text(
              entry.result.source == RecognitionSource.areaLookup
                  ? context.l10n.scanPlacesInArea
                  : entry.result.referenceCandidates.isNotEmpty
                  ? context.l10n.referencePossibleMatches
                  : entry.result.kind == 'unknown'
                  ? context.l10n.scanTryAnotherPhoto
                  : entry.result.name,
              style: const TextStyle(
                color: VisualScanStyle.text,
                fontWeight: FontWeight.w700,
              ),
            ),
            subtitle: Text(
              '${MaterialLocalizations.of(context).formatShortDate(entry.result.recognizedAt.toLocal())}'
              ' · ${TimeOfDay.fromDateTime(entry.result.recognizedAt.toLocal()).format(context)}',
              style: const TextStyle(color: VisualScanStyle.muted),
            ),
            trailing: const Icon(
              Icons.chevron_right,
              color: VisualScanStyle.muted,
            ),
            onTap: () => _showHistoryEntry(entry),
          ),
        ),
        const SizedBox(height: 8),
      ],
    ],
  );
}

const _scanEyebrow = TextStyle(
  color: VisualScanStyle.amber,
  fontSize: 12,
  fontWeight: FontWeight.w600,
);

BoxDecoration _scanPanel() => BoxDecoration(
  color: VisualScanStyle.surface,
  border: Border.all(color: VisualScanStyle.border),
  borderRadius: BorderRadius.circular(17),
);
