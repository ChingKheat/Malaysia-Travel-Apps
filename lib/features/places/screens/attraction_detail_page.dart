import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:smart_travel_planner/features/places/models/google_place_details.dart';
import 'package:smart_travel_planner/features/places/services/google_places_service.dart';
import 'package:smart_travel_planner/features/places/widgets/google_place_image.dart';
import 'package:smart_travel_planner/shared/models/attraction.dart';

/// Details remain usable with the information already available offline.
class AttractionDetailPage extends StatefulWidget {
  const AttractionDetailPage({
    super.key,
    required this.attraction,
    this.placesService,
    this.onToggleSaved,
    this.isSaved = false,
  });

  final Attraction attraction;
  final GooglePlacesService? placesService;
  final bool Function(Attraction)? onToggleSaved;
  final bool isSaved;

  @override
  State<AttractionDetailPage> createState() => _AttractionDetailPageState();
}

class _AttractionDetailPageState extends State<AttractionDetailPage> {
  late final GooglePlacesService _service;
  late bool _saved;
  GooglePlaceDetails? _details;
  bool _loading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _service = widget.placesService ?? GooglePlacesService();
    _saved = widget.isSaved;
    if (widget.attraction.googlePlaceId != null) _refresh();
  }

  Future<void> _refresh() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    GooglePlaceDetails? details;
    try {
      details = await _service.fetchDetails(widget.attraction.googlePlaceId!);
    } catch (_) {
      details = null;
    }
    if (!mounted) return;
    setState(() {
      _loading = false;
      _details = details;
      if (details == null) {
        _error = _service.lastError ?? 'Place details are unavailable.';
      }
    });
  }

  Future<void> _openMap() async {
    final a = widget.attraction;
    final uri = Uri.https('www.google.com', '/maps/search/', {
      'api': '1',
      'query': '${a.latitude},${a.longitude}',
      if (a.googlePlaceId != null) 'query_place_id': a.googlePlaceId!,
    });
    try {
      if (await launchUrl(uri, mode: LaunchMode.externalApplication)) return;
    } catch (_) {}
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Unable to open Google Maps.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final a = widget.attraction;
    final details = _details;
    final hours =
        (details?.hours['weekdayDescriptions'] as List?)
            ?.whereType<String>()
            .toList() ??
        [];
    final description = details?.description ?? a.description;
    final rating = details?.rating ?? a.rating;
    return Scaffold(
      appBar: AppBar(title: const Text('Attraction Details')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          if (_loading) const LinearProgressIndicator(),
          if (_error != null)
            Card(
              child: ListTile(
                title: Text(_error!),
                subtitle: const Text('Showing available place information.'),
                trailing: TextButton(
                  onPressed: _refresh,
                  child: const Text('Retry'),
                ),
              ),
            ),
          if (details != null && details.photos.isNotEmpty)
            ...details.photos.asMap().entries.map(
              (entry) => GooglePlaceImage(
                placeId: details.id,
                photo: entry.value,
                photoIndex: entry.key,
                service: _service,
              ),
            )
          else if (a.photoUrl != null && a.photoUrl!.startsWith('http'))
            Image.network(
              a.photoUrl!,
              height: 220,
              fit: BoxFit.cover,
              errorBuilder: (_, _, _) => _fallback(a.category),
            )
          else
            _fallback(a.category),
          const SizedBox(height: 16),
          Text(a.name, style: Theme.of(context).textTheme.headlineSmall),
          const SizedBox(height: 8),
          Text(a.category),
          if (rating != null) Text('Rating: ${rating.toStringAsFixed(1)} / 5'),
          const SizedBox(height: 20),
          Text('About', style: Theme.of(context).textTheme.titleMedium),
          Text(
            description == null || description.trim().isEmpty
                ? 'Description unavailable.'
                : description,
          ),
          const SizedBox(height: 20),
          Text('Opening hours', style: Theme.of(context).textTheme.titleMedium),
          Text(
            hours.isEmpty
                ? 'Opening hours unavailable. Check before visiting.'
                : hours.join('\n'),
          ),
          const SizedBox(height: 20),
          Text('Address', style: Theme.of(context).textTheme.titleMedium),
          Text(details?.address ?? 'Address unavailable.'),
          if (details != null) ...[
            const SizedBox(height: 12),
            const Text('Google Maps'),
            ...details.attributions.map(
              (a) => Text(a['provider']?.toString() ?? 'Google Maps'),
            ),
          ],
          const SizedBox(height: 20),
          FilledButton.icon(
            onPressed: _openMap,
            icon: const Icon(Icons.directions),
            label: const Text('Open in Google Maps'),
          ),
          if (widget.onToggleSaved != null)
            OutlinedButton.icon(
              onPressed: () {
                if (widget.onToggleSaved!(a)) setState(() => _saved = !_saved);
              },
              icon: Icon(_saved ? Icons.bookmark : Icons.bookmark_border),
              label: Text(_saved ? 'Remove from saved places' : 'Save place'),
            ),
        ],
      ),
    );
  }

  Widget _fallback(String category) {
    final kind = category.toLowerCase();
    final icon =
        kind.contains('food') ||
            kind.contains('restaurant') ||
            kind.contains('cafe')
        ? Icons.restaurant
        : kind.contains('nature') || kind.contains('park')
        ? Icons.park
        : Icons.place;
    return Container(
      height: 180,
      color: Theme.of(context).colorScheme.primaryContainer,
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [Icon(icon, size: 56), const Text('Photo unavailable')],
        ),
      ),
    );
  }
}
