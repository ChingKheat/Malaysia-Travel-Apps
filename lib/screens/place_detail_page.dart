import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../core/app_colors.dart';
import '../models/travel_stop.dart';
import '../services/google_places_service.dart';
import '../widgets/google_place_image.dart';

class PlaceDetailPage extends StatefulWidget {
  const PlaceDetailPage({super.key, required this.stop, this.placesService});
  final TravelStop stop;
  final GooglePlacesService? placesService;
  @override
  State<PlaceDetailPage> createState() => _PlaceDetailPageState();
}

class _PlaceDetailPageState extends State<PlaceDetailPage> {
  late TravelStop _stop;
  late final GooglePlacesService _service;
  bool _loading = false;
  String? _error;
  int _generation = 0;
  @override
  void initState() {
    super.initState();
    _stop = widget.stop;
    _service = widget.placesService ?? GooglePlacesService();
    if (_stop.isGooglePlace) _refresh();
  }

  Future<void> _refresh() async {
    final id = _stop.placeId;
    if (id == null) return;
    final generation = ++_generation;
    setState(() {
      _loading = true;
      _error = null;
    });
    final details = await _service.fetchDetails(id);
    if (!mounted || generation != _generation) return;
    setState(() {
      _loading = false;
      if (details != null) {
        _stop = widget.stop.withGoogleDetails(details);
      } else {
        _error = _service.lastError ?? 'Live place details unavailable.';
      }
    });
  }

  Future<void> _open(String? value) async {
    final uri = Uri.tryParse(value ?? '');
    if (uri == null || !['https', 'http'].contains(uri.scheme)) return;
    try {
      if (await launchUrl(uri, mode: LaunchMode.externalApplication)) return;
    } catch (_) {}
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Unable to open this link.')),
      );
    }
  }

  Widget _field(String label, String value, {VoidCallback? onTap}) => Card(
    child: ListTile(
      title: Text(label),
      subtitle: Text(value),
      onTap: onTap,
      trailing: onTap == null ? null : const Icon(Icons.open_in_new, size: 18),
    ),
  );
  @override
  Widget build(BuildContext context) {
    final details = _stop.googleDetails;
    return Scaffold(
      backgroundColor: const Color(0xFFF7F8FD),
      appBar: AppBar(title: Text(_stop.title)),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          if (_loading) const LinearProgressIndicator(),
          if (_error != null)
            Card(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  children: [
                    Text('$_error Your scheduled time remains saved.'),
                    TextButton(onPressed: _refresh, child: const Text('Retry')),
                  ],
                ),
              ),
            ),
          if (details != null && details.photos.isNotEmpty)
            ...details.photos.asMap().entries.map(
              (entry) => Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: GooglePlaceImage(
                  placeId: details.id,
                  photo: entry.value,
                  photoIndex: entry.key,
                  service: _service,
                ),
              ),
            )
          else if (_stop.primaryPhotoUrl != null)
            Image.network(
              _stop.primaryPhotoUrl!,
              height: 220,
              fit: BoxFit.cover,
              errorBuilder: (_, _, _) => const SizedBox(
                height: 120,
                child: Center(child: Text('Photo unavailable')),
              ),
            )
          else
            const SizedBox(
              height: 140,
              child: Center(child: Text('Photo unavailable')),
            ),
          Text(
            _stop.title,
            style: const TextStyle(
              fontSize: 26,
              fontWeight: FontWeight.bold,
              color: AppColors.ink,
            ),
          ),
          const SizedBox(height: 10),
          if (_stop.isGooglePlace)
            const Text(
              'Google Maps',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
          const SizedBox(height: 10),
          Text(_stop.description),
          const SizedBox(height: 16),
          _field('Scheduled time', widget.stop.time),
          _field('Planned duration', widget.stop.duration),
          _field('Opening hours', _stop.openingHours),
          if (_stop.isGooglePlace) ...[
            _field('Address', details?.address ?? 'Address unavailable'),
            _field(
              'Rating',
              details?.rating?.toString() ?? 'Rating unavailable',
            ),
            _field(
              'Reviews',
              details?.reviewCount?.toString() ?? 'Review count unavailable',
            ),
            _field('Phone', details?.phone ?? 'Phone unavailable'),
            _field(
              'Website',
              details?.website ?? 'Website unavailable',
              onTap: details?.website == null
                  ? null
                  : () => _open(details!.website),
            ),
            if (details?.mapsUri != null)
              FilledButton.icon(
                onPressed: () => _open(details!.mapsUri),
                icon: const Icon(Icons.directions),
                label: const Text('Open in Google Maps'),
              ),
            ...?details?.attributions.map(
              (a) => _field(
                'Source',
                a['provider']?.toString() ?? 'Google Maps',
                onTap: a['providerUri'] == null
                    ? null
                    : () => _open(a['providerUri'].toString()),
              ),
            ),
          ] else
            ..._stop.tips.map(
              (tip) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text(tip),
              ),
            ),
        ],
      ),
    );
  }
}
