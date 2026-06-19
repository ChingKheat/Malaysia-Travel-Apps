import 'package:flutter/material.dart';

import '../core/app_colors.dart';
import '../core/app_decorations.dart';
import '../data/sample_data.dart';
import '../models/travel_stop.dart';
import '../screens/place_detail_page.dart';
import 'demo_tap.dart';

class MockMap extends StatelessWidget {
  const MockMap({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 430,
      decoration: BoxDecoration(
        color: const Color(0xFFEAF1EA),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppColors.line),
      ),
      child: Stack(
        children: [
          Positioned.fill(child: CustomPaint(painter: RoutePainter())),
          Positioned(
            top: 28,
            left: 24,
            child: MapPin(number: 1, stop: sampleStops[0]),
          ),
          Positioned(
            top: 112,
            right: 42,
            child: MapPin(number: 2, stop: sampleStops[1]),
          ),
          Positioned(
            top: 192,
            left: 60,
            child: MapPin(number: 3, stop: sampleStops[2]),
          ),
          Positioned(
            top: 258,
            right: 38,
            child: MapPin(number: 4, stop: sampleStops[4]),
          ),
          const Positioned(bottom: 26, left: 32, right: 32, child: MapLegend()),
        ],
      ),
    );
  }
}

class RoutePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final gridPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.8)
      ..strokeWidth = 2;
    for (var x = 30.0; x < size.width; x += 56) {
      canvas.drawLine(Offset(x, 0), Offset(x + 40, size.height), gridPaint);
    }
    for (var y = 30.0; y < size.height; y += 58) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y + 20), gridPaint);
    }

    final route = Paint()
      ..color = AppColors.primary
      ..strokeWidth = 5
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    final path = Path()
      ..moveTo(size.width * 0.28, 62)
      ..cubicTo(
        size.width * 0.58,
        110,
        size.width * 0.52,
        160,
        size.width * 0.75,
        160,
      )
      ..cubicTo(
        size.width * 0.48,
        206,
        size.width * 0.35,
        240,
        size.width * 0.54,
        294,
      )
      ..cubicTo(
        size.width * 0.72,
        334,
        size.width * 0.64,
        360,
        size.width * 0.36,
        390,
      );
    canvas.drawPath(path, route);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class MapPin extends StatelessWidget {
  const MapPin({super.key, required this.number, required this.stop});

  final int number;
  final TravelStop stop;

  @override
  Widget build(BuildContext context) {
    return DemoTapCard(
      onTap: () => Navigator.of(
        context,
      ).push(MaterialPageRoute(builder: (_) => PlaceDetailPage(stop: stop))),
      borderRadius: 14,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          CircleAvatar(
            radius: 15,
            backgroundColor: AppColors.primary,
            child: Text(
              '$number',
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
          const SizedBox(width: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              stop.title,
              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800),
            ),
          ),
        ],
      ),
    );
  }
}

class MapLegend extends StatelessWidget {
  const MapLegend({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: cardDecoration(),
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Optimized order',
            style: TextStyle(fontWeight: FontWeight.w900, color: AppColors.ink),
          ),
          SizedBox(height: 8),
          Text(
            'Batu Caves -> Central Market -> Jalan Alor -> KLCC Park',
            style: TextStyle(color: AppColors.muted),
          ),
        ],
      ),
    );
  }
}
