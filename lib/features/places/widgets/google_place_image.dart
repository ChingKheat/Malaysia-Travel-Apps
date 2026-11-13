import 'package:smart_travel_planner/l10n/localized_labels.dart';
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
    this.autoLoad = false,
    this.fill = false,
    this.attributionTop,
    this.fallback,
    this.showGoogleMapsAttribution = false,
  });
  final String placeId;
  final GooglePlacePhoto photo;
  final int photoIndex;
  final GooglePlacesService service;
  final bool autoLoad;
  final bool fill;
  final double? attributionTop;
  final Widget? fallback;
  final bool showGoogleMapsAttribution;
  @override
  State<GooglePlaceImage> createState() => _GooglePlaceImageState();
}

class _GooglePlaceImageState extends State<GooglePlaceImage> {
  Uint8List? _bytes;
  late GooglePlacePhoto _photo;
  bool _loading = false;
  bool _requested = false;
  int _generation = 0;
  @override
  void initState() {
    super.initState();
    _photo = widget.photo;
    if (widget.autoLoad) {
      _load();
    }
  }

  @override
  void didUpdateWidget(covariant GooglePlaceImage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.photo.name != widget.photo.name ||
        oldWidget.placeId != widget.placeId) {
      _generation++;
      _photo = widget.photo;
      _bytes = null;
      _loading = false;
      _requested = false;
      if (widget.autoLoad) {
        _load();
      }
    }
  }

  Future<void> _load() async {
    final generation = ++_generation;
    setState(() {
      _photo = widget.photo;
      _bytes = null;
      _loading = true;
      _requested = true;
    });
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
  Widget build(BuildContext context) {
    final imageWidget = (_loading || (!_requested && widget.autoLoad))
        ? Container(
            color: const Color(0xFFE2E8F0),
            child: const Center(
              child: CircularProgressIndicator(strokeWidth: 2.5),
            ),
          )
        : _bytes == null
        ? widget.fallback ??
              Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (_requested) ...[
                      Text(
                        context.l10n.photoUnavailable,
                        style: TextStyle(
                          color: Color(0xFF64748B),
                          fontSize: 13,
                        ),
                      ),
                      const SizedBox(height: 8),
                    ],
                    ConstrainedBox(
                      constraints: const BoxConstraints(minHeight: 44),
                      child: FilledButton.icon(
                        onPressed: _load,
                        icon: const Icon(Icons.refresh, size: 18),
                        label: Text(
                          _requested
                              ? context.l10n.retryPhoto
                              : context.l10n.loadPhoto,
                        ),
                      ),
                    ),
                  ],
                ),
              )
        : Image.memory(
            _bytes!,
            fit: BoxFit.cover,
            width: double.infinity,
            height: double.infinity,
            errorBuilder: (_, _, _) =>
                widget.fallback ??
                Center(child: Text(context.l10n.photoUnavailable)),
          );

    if (widget.fill) {
      final authorName = _photo.authors.firstOrNull?['displayName']?.toString();
      final authorUri = _photo.authors.firstOrNull?['uri']?.toString();

      return Stack(
        fit: StackFit.expand,
        children: [
          imageWidget,
          if (_bytes != null && widget.showGoogleMapsAttribution)
            const PositionedDirectional(
              start: 8,
              top: 8,
              child: DecoratedBox(
                decoration: BoxDecoration(color: Colors.black87),
                child: Padding(
                  padding: EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                  child: Text(
                    'Google Maps',
                    style: TextStyle(color: Colors.white, fontSize: 11),
                  ),
                ),
              ),
            ),
          if (_bytes != null && authorName != null)
            Positioned(
              left: 14,
              right: 14,
              top: widget.attributionTop,
              bottom: widget.attributionTop == null ? 14 : null,
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: authorUri != null
                      ? () => _openAuthor(authorUri)
                      : null,
                  borderRadius: BorderRadius.circular(20),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 5,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.65),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.2),
                        width: 0.8,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.camera_alt_outlined,
                          size: 13,
                          color: Colors.white70,
                        ),
                        const SizedBox(width: 5),
                        Flexible(
                          child: Text(
                            'Google Maps • $authorName',
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(height: 220, width: double.infinity, child: imageWidget),
        if (_bytes != null) ...[
          const Text('Google Maps'),
          ..._photo.authors.map(
            (author) => TextButton(
              onPressed: author['uri'] == null
                  ? null
                  : () => _openAuthor(author['uri']?.toString()),
              child: Text(
                context.l10n.photoValue(
                  (author['displayName'] ?? 'Google Maps contributor')
                      .toString(),
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }
}
