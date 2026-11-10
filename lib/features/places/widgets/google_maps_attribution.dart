import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

/// Provider notices stay alongside the live content and are never persisted.
class GoogleMapsAttribution extends StatelessWidget {
  const GoogleMapsAttribution({super.key, this.attributions = const []});
  final List<Map<String, dynamic>> attributions;
  @override
  Widget build(BuildContext context) => Wrap(
    spacing: 8,
    crossAxisAlignment: WrapCrossAlignment.center,
    children: [
      const Text('Google Maps'),
      ...{
        for (final source in attributions)
          '${source['provider']}|${source['providerUri']}': source,
      }.values.map(
        (source) => TextButton(
          onPressed: () async {
            final uri = Uri.tryParse(source['providerUri']?.toString() ?? '');
            if (uri != null && ['http', 'https'].contains(uri.scheme)) {
              try {
                await launchUrl(uri, mode: LaunchMode.externalApplication);
              } catch (_) {}
            }
          },
          child: Text(source['provider']?.toString() ?? 'Source'),
        ),
      ),
    ],
  );
}
