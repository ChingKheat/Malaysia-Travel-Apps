import 'package:smart_travel_planner/l10n/localized_labels.dart';
import 'package:flutter/material.dart';
import 'package:smart_travel_planner/core/theme/app_colors.dart';
import 'package:smart_travel_planner/features/image_recognition/models/recognition_result.dart';
import 'package:smart_travel_planner/features/image_recognition/services/image_recognition_service.dart';

class RecognitionResultSheet extends StatefulWidget {
  const RecognitionResultSheet({
    super.key,
    required this.result,
    required this.service,
    this.image,
  });

  final RecognitionResult result;
  final ImageRecognitionService service;
  final Widget? image;

  @override
  State<RecognitionResultSheet> createState() => _RecognitionResultSheetState();
}

class _RecognitionResultSheetState extends State<RecognitionResultSheet> {
  late RecognitionResult _display = widget.result;
  final _translations = <String, RecognitionResult>{};
  String _language = 'en';
  bool _busy = false;
  String? _error;

  Future<void> _translate(String? language) async {
    if (language == null || _busy || language == _language) return;
    final cached = language == 'en' ? widget.result : _translations[language];
    if (cached != null) {
      setState(() {
        _display = cached;
        _language = language;
        _error = null;
      });
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final result = await widget.service.translate(widget.result, language);
      if (!mounted) return;
      setState(() {
        _display = result;
        _language = language;
        _translations[language] = result;
      });
    } on ImageRecognitionException catch (error) {
      if (mounted) setState(() => _error = error.message);
    } catch (_) {
      if (mounted) {
        setState(
          () => _error =
              'Translation is unavailable. Your original result is still available.',
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => SafeArea(
    top: false,
    child: SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
      child: DefaultTextStyle(
        style: Theme.of(
          context,
        ).textTheme.bodyMedium!.copyWith(color: AppColors.ink),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (widget.image != null) ...[
              ClipRRect(
                borderRadius: BorderRadius.circular(18),
                child: widget.image,
              ),
              const SizedBox(height: 20),
            ],
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                Chip(label: Text(context.tr(widget.result.kind).toUpperCase())),
                if (widget.result.isSample)
                  Chip(label: Text(context.l10n.samplePreview)),
                if (widget.result.confidence != null)
                  Chip(
                    label: Text(
                      context.l10n.visionConfidenceValue(
                        ((widget.result.confidence! * 100).round()).toString(),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 14),
            Text(
              _display.name,
              style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w800),
            ),
            if (_display.location.isNotEmpty) ...[
              const SizedBox(height: 12),
              Text(
                _display.location,
                style: const TextStyle(color: AppColors.muted),
              ),
            ],
            const SizedBox(height: 16),
            Text(
              _display.description,
              style: const TextStyle(color: AppColors.muted, height: 1.6),
            ),
            if (_display.labels.isNotEmpty) ...[
              const SizedBox(height: 16),
              Text(
                context.l10n.detectedLabels,
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  for (final label in _display.labels) Chip(label: Text(label)),
                ],
              ),
            ],
            const SizedBox(height: 20),
            InputDecorator(
              decoration: InputDecoration(
                labelText: context.l10n.resultLanguage,
                border: OutlineInputBorder(),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  value: _language,
                  isExpanded: true,
                  items: const [
                    DropdownMenuItem(value: 'en', child: Text('English')),
                    DropdownMenuItem(value: 'ms', child: Text('Bahasa Melayu')),
                    DropdownMenuItem(value: 'zh-CN', child: Text('简体中文')),
                  ],
                  onChanged: _busy ? null : _translate,
                ),
              ),
            ),
            if (_busy) ...[
              const SizedBox(height: 12),
              const LinearProgressIndicator(),
              const SizedBox(height: 6),
              Text(context.l10n.translating),
            ],
            if (_error != null) ...[
              const SizedBox(height: 12),
              Text(
                context.tr(_error!),
                style: const TextStyle(color: Colors.red),
              ),
            ],
            if (_language != 'en') ...[
              const SizedBox(height: 10),
              Text(
                context
                    .l10n
                    .machineTranslatedTextTheOriginalEnglishResultStaysInYourHistory,
                style: TextStyle(color: AppColors.muted, fontSize: 12),
              ),
            ],
            const SizedBox(height: 16),
            Text(
              widget.result.isSample
                  ? context
                        .l10n
                        .thisIsAPreparedDemoResultItHasNotAnalysedYourUploadedPhotoAndIsNotAddedToScanHistory
                  : context
                        .l10n
                        .identificationUsesVisionDetectionsGuideDescriptionsComeFromTheAppSCuratedCatalog,
              style: const TextStyle(
                color: AppColors.muted,
                fontSize: 12,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              context.l10n.exploreThisResult,
              style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 8),
            Text(
              context
                  .l10n
                  .theseActionsWillBeAvailableWhenLiveRecognitionAndTourismDetailsAreConnected,
              style: TextStyle(
                color: AppColors.muted,
                fontSize: 12,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                Tooltip(
                  message: context.l10n.availableAfterSetup,
                  child: OutlinedButton.icon(
                    onPressed: null,
                    icon: const Icon(Icons.favorite_border, size: 18),
                    label: Text(context.l10n.addToWishlist),
                  ),
                ),
                Tooltip(
                  message: context.l10n.availableAfterSetup,
                  child: OutlinedButton.icon(
                    onPressed: null,
                    icon: const Icon(Icons.near_me_outlined, size: 18),
                    label: Text(
                      _display.kind == 'food'
                          ? context.l10n.findRestaurants
                          : context.l10n.viewNearby,
                    ),
                  ),
                ),
                if (_display.kind != 'food') ...[
                  Tooltip(
                    message: context.l10n.availableAfterSetup,
                    child: OutlinedButton.icon(
                      onPressed: null,
                      icon: const Icon(Icons.map_outlined, size: 18),
                      label: Text(context.l10n.viewOnMap),
                    ),
                  ),
                  Tooltip(
                    message: context.l10n.availableAfterSetup,
                    child: OutlinedButton.icon(
                      onPressed: null,
                      icon: const Icon(
                        Icons.event_available_outlined,
                        size: 18,
                      ),
                      label: Text(context.l10n.addToTravelPlan),
                    ),
                  ),
                ],
              ],
            ),
            if (_display.kind == 'food') ...[
              const SizedBox(height: 12),
              Text(
                context
                    .l10n
                    .chooseARestaurantBeforeAddingThisDishToYourTravelPlan,
                style: TextStyle(
                  color: AppColors.muted,
                  fontSize: 12,
                  height: 1.5,
                ),
              ),
            ],
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                onPressed: () => Navigator.pop(context),
                child: Text(context.l10n.done),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}
