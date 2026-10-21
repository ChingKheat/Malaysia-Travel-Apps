import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:smart_travel_planner/features/places/models/google_place_details.dart';
import 'package:smart_travel_planner/features/places/services/google_places_service.dart';

/// Authenticated image bytes live only in this screen's memory. No photo
/// reference, signed media URL, image file or API key is written to storage.
class GooglePlaceImage extends StatefulWidget {
  const GooglePlaceImage({
    super.key,
    required this.placeId,
    required this.photo,
    required this.service,
    this.photoIndex = 0,
  });
  final String placeId;
  final GooglePlacePhoto photo;
  final int photoIndex;
  final GooglePlacesService service;
  @override
  State<GooglePlaceImage> createState() => _GooglePlaceImageState();
}

class _GooglePlaceImageState extends State<GooglePlaceImage> {
  Uint8List? _bytes;
  late GooglePlacePhoto _photo;
  bool _loading = true;
  int _generation = 0;
  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(covariant GooglePlaceImage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.photo.name != widget.photo.name ||
        oldWidget.placeId != widget.placeId) {
      _load();
    }
  }

  Future<void> _load() async {
    final generation = ++_generation;
    _photo = widget.photo;
    _bytes = null;
    _loading = true;
    final result = await widget.service.fetchPhotoResult(_photo);
    var bytes = result.bytes;
    // A photo reference can expire. Ask Google for new details and retry once.
    if (bytes == null && result.expired) {
      final details = await widget.service.fetchDetails(widget.placeId);
      final photos = details?.photos ?? [];
      if (photos.length > widget.photoIndex) {
        final fresh = photos[widget.photoIndex];
        bytes = await widget.service.fetchPhoto(fresh);
        if (!mounted || generation != _generation) return;
        _photo = fresh;
      }
    }
    if (!mounted || generation != _generation) return;
    setState(() {
      _bytes = bytes;
      _loading = false;
    });
  }

  Future<void> _openAuthor(String? value) async {
    final uri = Uri.tryParse(value ?? '');
    if (uri == null || uri.scheme != 'https') return;
    try {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      SizedBox(
        height: 220,
        width: double.infinity,
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : _bytes == null
            ? const Center(child: Text('Photo unavailable'))
            : Image.memory(
                _bytes!,
                fit: BoxFit.cover,
                errorBuilder: (_, _, _) =>
                    const Center(child: Text('Photo unavailable')),
              ),
      ),
      if (_bytes != null) ...[
        const Text('Google Maps'),
        ..._photo.authors.map(
          (author) => TextButton(
            onPressed: author['uri'] == null
                ? null
                : () => _openAuthor(author['uri']?.toString()),
            child: Text(
              'Photo: ${author['displayName'] ?? 'Google Maps contributor'}',
            ),
          ),
        ),
      ],
    ],
  );
}
