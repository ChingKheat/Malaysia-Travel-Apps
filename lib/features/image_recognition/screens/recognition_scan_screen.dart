import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:smart_travel_planner/l10n/localized_labels.dart';
import 'package:smart_travel_planner/core/theme/app_colors.dart';
import 'package:smart_travel_planner/features/image_recognition/models/recognition_result.dart';
import 'package:smart_travel_planner/features/image_recognition/services/image_recognition_service.dart';

typedef ScanOutcome = ({RecognitionResult? result, String? error});

class RecognitionScanScreen extends StatefulWidget {
  const RecognitionScanScreen({
    super.key,
    required this.photo,
    required this.recognize,
  });

  final Uint8List photo;
  final Future<RecognitionResult> Function(Uint8List) recognize;

  @override
  State<RecognitionScanScreen> createState() => _RecognitionScanScreenState();
}

class _RecognitionScanScreenState extends State<RecognitionScanScreen>
    with SingleTickerProviderStateMixin {
  static const _sweepDuration = Duration(milliseconds: 1550);
  late final _sweep = AnimationController(
    vsync: this,
    duration: _sweepDuration,
  );
  final _firstSweep = Completer<void>();
  Timer? _minimumScanTime;
  bool _started = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    if (reduceMotion) {
      _sweep.stop();
      _sweep.value = 0.5;
      _completeFirstSweep();
    } else if (!_sweep.isAnimating) {
      unawaited(_sweep.repeat());
    }
    if (_started) return;
    _started = true;
    if (!reduceMotion) {
      _minimumScanTime = Timer(_sweepDuration, _completeFirstSweep);
    }
    unawaited(_scan());
  }

  void _completeFirstSweep() {
    _minimumScanTime?.cancel();
    if (!_firstSweep.isCompleted) _firstSweep.complete();
  }

  Future<void> _scan() async {
    try {
      final result = await widget.recognize(widget.photo);
      await _firstSweep.future;
      _finish((result: result, error: null));
    } on ImageRecognitionException catch (error) {
      _finish((result: null, error: error.message));
    } catch (_) {
      _finish((
        result: null,
        error: 'Image recognition is temporarily unavailable. Try a sample.',
      ));
    }
  }

  void _finish(ScanOutcome outcome) {
    if (mounted && ModalRoute.isCurrentOf(context) == true) {
      Navigator.pop(context, outcome);
    }
  }

  @override
  void dispose() {
    _completeFirstSweep();
    _sweep.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnnotatedRegion<SystemUiOverlayStyle>(
    value: SystemUiOverlayStyle.light.copyWith(
      statusBarColor: Colors.transparent,
      systemNavigationBarColor: Colors.white,
      systemNavigationBarIconBrightness: Brightness.dark,
    ),
    child: Scaffold(
      backgroundColor: AppColors.ink,
      body: Column(
        children: [
          Expanded(
            child: SafeArea(
              bottom: false,
              child: Center(
                child: ClipRect(
                  child: Stack(
                    children: [
                      Image.memory(
                        widget.photo,
                        fit: BoxFit.contain,
                        excludeFromSemantics: true,
                        errorBuilder: (_, _, _) => const Icon(
                          Icons.broken_image_outlined,
                          size: 48,
                          color: Colors.white70,
                        ),
                      ),
                      Positioned.fill(
                        child: IgnorePointer(
                          child: CustomPaint(painter: _ScanSweep(_sweep)),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          Material(
            color: Colors.white,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(26)),
            child: SafeArea(
              top: false,
              minimum: const EdgeInsets.fromLTRB(20, 14, 14, 14),
              child: Row(
                children: [
                  const Icon(Icons.auto_awesome, color: AppColors.primary),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Semantics(
                      liveRegion: true,
                      child: Text(
                        context.l10n.scanningPhoto,
                        style: const TextStyle(
                          color: AppColors.ink,
                          fontSize: 17,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ),
                  IconButton.filledTonal(
                    tooltip: context.l10n.cancelRecognition,
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    ),
  );
}

class _ScanSweep extends CustomPainter {
  _ScanSweep(this.sweep) : super(repaint: sweep);

  final Animation<double> sweep;
  static const _gold = Color(0xFFFFD76A);

  @override
  void paint(Canvas canvas, Size size) {
    final y = size.height * sweep.value;
    final glow = Rect.fromLTRB(0, y - 48, size.width, y);
    canvas.drawRect(
      glow,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0x00FFD76A), Color(0x88FFD76A)],
        ).createShader(glow),
    );
    canvas.drawLine(
      Offset(0, y),
      Offset(size.width, y),
      Paint()
        ..color = _gold
        ..strokeWidth = 3,
    );
  }

  @override
  bool shouldRepaint(_ScanSweep oldDelegate) => oldDelegate.sweep != sweep;
}
