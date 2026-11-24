import 'package:flutter/material.dart';
import 'package:smart_travel_planner/l10n/localized_labels.dart';

/// An offline illustration used only when the attraction has no visible photo.
class CategoryIllustration extends StatelessWidget {
  const CategoryIllustration({
    super.key,
    required this.category,
    required this.icon,
  });

  final String category;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final subject = switch (category.toLowerCase()) {
      'history' || 'culture' || 'museum' => Icons.account_balance_rounded,
      'nightlife' => Icons.nightlife_rounded,
      'adventure' => Icons.terrain_rounded,
      'family' || 'attraction' => Icons.attractions_rounded,
      _ => icon == Icons.place_rounded ? Icons.location_city_rounded : icon,
    };
    return CustomPaint(
      painter: const _Landscape(),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ExcludeSemantics(
              child: Icon(subject, size: 48, color: const Color(0xff273f39)),
            ),
            const SizedBox(height: 4),
            DecoratedBox(
              decoration: BoxDecoration(
                color: const Color(0xff273f39),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                child: Text(
                  context.l10n.categoryIllustration,
                  style: const TextStyle(color: Colors.white, fontSize: 11),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Landscape extends CustomPainter {
  const _Landscape();

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width, h = size.height;
    final ink = Paint()..color = const Color(0xffe6d7b4);
    canvas.drawRect(Offset.zero & size, ink);
    canvas.drawCircle(
      Offset(w * .76, h * .32),
      h * .13,
      ink..color = const Color(0xffd89c59),
    );
    final ridge = Path()
      ..moveTo(0, h * .48)
      ..quadraticBezierTo(w * .22, h * .25, w * .48, h * .60)
      ..quadraticBezierTo(w * .72, h * .84, w, h * .38)
      ..lineTo(w, h)
      ..lineTo(0, h)
      ..close();
    canvas.drawPath(ridge, ink..color = const Color(0xffa4b5a2));
    final hillside = Path()
      ..moveTo(0, h * .84)
      ..cubicTo(w * .32, h * .96, w * .70, h * .41, w, h * .64)
      ..lineTo(w, h)
      ..lineTo(0, h)
      ..close();
    canvas.drawPath(hillside, ink..color = const Color(0xff678677));
  }

  @override
  bool shouldRepaint(_Landscape oldDelegate) => false;
}
