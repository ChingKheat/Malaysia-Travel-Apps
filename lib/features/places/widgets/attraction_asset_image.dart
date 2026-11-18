import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../shared/models/attraction.dart';
import '../utils/attraction_image_resolver.dart';

class AttractionAssetImage extends StatelessWidget {
  const AttractionAssetImage({
    super.key,
    required this.attraction,
    required this.asset,
    required this.fallback,
    this.creditAlignment = Alignment.bottomLeft,
    this.creditPadding = const EdgeInsets.all(8),
  });

  final Attraction attraction;
  final String asset;
  final Widget fallback;
  final Alignment creditAlignment;
  final EdgeInsets creditPadding;

  @override
  Widget build(BuildContext context) {
    final credit = AttractionImageResolver.photoCredit(attraction);
    return Image.asset(
      asset,
      fit: BoxFit.cover,
      excludeFromSemantics: true,
      errorBuilder: (_, _, _) => fallback,
      frameBuilder: (_, image, frame, _) {
        if (credit == null || frame == null) return image;
        return Stack(
          fit: StackFit.expand,
          children: [
            image,
            Padding(
              padding: creditPadding,
              child: Align(
                alignment: creditAlignment,
                child: Material(
                  color: Colors.black87,
                  borderRadius: BorderRadius.circular(4),
                  child: InkWell(
                    onTap: () => launchUrl(Uri.parse(credit.source)),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      child: Text(
                        '© ${credit.author} · ${credit.license}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}
