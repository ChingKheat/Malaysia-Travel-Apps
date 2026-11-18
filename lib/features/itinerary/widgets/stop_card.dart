import 'package:smart_travel_planner/l10n/localized_labels.dart';
import 'package:smart_travel_planner/l10n/presentation_formatters.dart';
import 'package:flutter/material.dart';

import 'package:smart_travel_planner/core/theme/app_colors.dart';
import 'package:smart_travel_planner/core/theme/app_decorations.dart';
import 'package:smart_travel_planner/features/places/models/google_place_details.dart';
import 'package:smart_travel_planner/features/places/services/google_places_service.dart';
import 'package:smart_travel_planner/features/places/widgets/google_place_image.dart';
import 'package:smart_travel_planner/shared/models/travel_stop.dart';
import 'package:smart_travel_planner/shared/widgets/demo_tap.dart';

class StopCard extends StatelessWidget {
  const StopCard({super.key, required this.stop, required this.onTap});

  final TravelStop stop;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return DemoTapCard(
      onTap: onTap,
      margin: const EdgeInsets.only(bottom: 12),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: cardDecoration(),
        child: Row(
          children: [
            StopThumbnail(stop: stop),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _StopTitle(
                    key: ValueKey('stop-title-${stop.placeId ?? stop.title}'),
                    stop: stop,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    [
                      context.scheduledTime(stop.time),
                      if (stop.visitMinutes > 0 && stop.time.contains(' - '))
                        context.l10n.valueMin(
                          context.localNumber(stop.visitMinutes),
                        ),
                    ].join(' · '),
                    style: const TextStyle(
                      color: AppColors.primary,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          stop.note,
                          style: const TextStyle(
                            color: AppColors.muted,
                            fontSize: 12,
                          ),
                        ),
                      ),
                      if (!stop.isGooglePlace && stop.photoUrls.length > 1) ...[
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 5,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.primary.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(
                                Icons.photo_library_outlined,
                                size: 11,
                                color: AppColors.primary,
                              ),
                              const SizedBox(width: 3),
                              Text(
                                '${stop.photoUrls.length}',
                                style: const TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.primary,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, color: AppColors.muted),
          ],
        ),
      ),
    );
  }
}

class _StopTitle extends StatefulWidget {
  const _StopTitle({super.key, required this.stop});

  final TravelStop stop;

  @override
  State<_StopTitle> createState() => _StopTitleState();
}

class _StopTitleState extends State<_StopTitle> {
  late final Future<GooglePlaceDetails?>? _details =
      widget.stop.isGooglePlace &&
          (widget.stop.title.trim().isEmpty ||
              widget.stop.title == 'Saved Google place' ||
              widget.stop.title == 'Attraction') &&
          widget.stop.placeId != null
      ? GooglePlacesService().fetchDetails(widget.stop.placeId!, basic: true)
      : null;

  @override
  Widget build(BuildContext context) {
    final stop = widget.stop;
    final knownTitle =
        stop.title.trim().isNotEmpty &&
        stop.title != 'Saved Google place' &&
        !(stop.title == 'Attraction' && stop.isGooglePlace);
    final title = knownTitle ? stop.title : null;
    if (title != null) return _text(title);
    if (_details == null) return _text(context.l10n.placeDetailsAreUnavailable);
    return FutureBuilder<GooglePlaceDetails?>(
      future: _details,
      builder: (context, snapshot) {
        final fetchedName = snapshot.data?.name?.trim();
        return _text(
          fetchedName != null && fetchedName.isNotEmpty
              ? fetchedName
              : context.l10n.placeDetailsAreUnavailable,
        );
      },
    );
  }

  Widget _text(String value) => Text(
    value,
    style: const TextStyle(fontWeight: FontWeight.w600, color: AppColors.ink),
  );
}

class StopThumbnail extends StatelessWidget {
  const StopThumbnail({super.key, required this.stop, this.size = 58});

  final TravelStop stop;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: stop.color.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(14),
      ),
      child: stop.isGooglePlace && stop.placeId != null
          ? ClipRRect(
              borderRadius: BorderRadius.circular(14),
              child: _GoogleStopThumbnail(
                key: ValueKey(stop.placeId),
                placeId: stop.placeId!,
                photo: stop.googleDetails?.photos.firstOrNull,
                requestWidth: size > 58 ? 320 : 160,
                fallback: Icon(stop.icon, color: stop.color, size: 28),
              ),
            )
          : stop.primaryPhotoUrl != null
          ? ClipRRect(
              borderRadius: BorderRadius.circular(14),
              child: Image.network(
                stop.primaryPhotoUrl!,
                width: size,
                height: size,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) =>
                    Icon(stop.icon, color: stop.color, size: 28),
                loadingBuilder: (context, child, loadingProgress) {
                  if (loadingProgress == null) return child;
                  return Center(
                    child: SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: stop.color,
                      ),
                    ),
                  );
                },
              ),
            )
          : Icon(stop.icon, color: stop.color, size: 28),
    );
  }
}

class _GoogleStopThumbnail extends StatefulWidget {
  const _GoogleStopThumbnail({
    super.key,
    required this.placeId,
    required this.photo,
    required this.requestWidth,
    required this.fallback,
  });

  final String placeId;
  final GooglePlacePhoto? photo;
  final int requestWidth;
  final Widget fallback;

  @override
  State<_GoogleStopThumbnail> createState() => _GoogleStopThumbnailState();
}

class _GoogleStopThumbnailState extends State<_GoogleStopThumbnail> {
  final _service = GooglePlacesService();
  late final Future<GooglePlaceDetails?>? _details = widget.photo == null
      ? _service.fetchDetails(widget.placeId, basic: true)
      : null;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<GooglePlaceDetails?>(
      future: _details,
      builder: (context, snapshot) {
        final photo = widget.photo ?? snapshot.data?.photos.firstOrNull;
        if (photo == null) return widget.fallback;
        return GooglePlaceImage(
          placeId: widget.placeId,
          photo: photo,
          service: _service,
          requestWidth: widget.requestWidth,
          compactAttribution: true,
          autoLoad: true,
          fill: true,
          fallback: widget.fallback,
        );
      },
    );
  }
}
