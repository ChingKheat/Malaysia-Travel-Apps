import 'package:smart_travel_planner/l10n/localized_labels.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:smart_travel_planner/core/theme/app_colors.dart';
import 'package:smart_travel_planner/shared/models/travel_stop.dart';
import 'package:smart_travel_planner/features/places/services/google_places_service.dart';
import 'package:smart_travel_planner/features/places/widgets/google_place_image.dart';

class PlaceDetailPage extends StatefulWidget {
  const PlaceDetailPage({
    super.key,
    required this.stop,
    this.visitDate,
    this.placesService,
  });
  final TravelStop stop;
  final DateTime? visitDate;
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
  int _activePhotoIndex = 0;
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
        if (_activePhotoIndex >= details.photos.length) {
          _activePhotoIndex = 0;
        }
      } else {
        _error = _service.lastError ?? 'Live place details unavailable.';
      }
    });
  }

  Future<void> _open(String? value, {bool phone = false}) async {
    final uri = phone
        ? Uri(scheme: 'tel', path: value)
        : Uri.tryParse(value ?? '');
    if (uri == null || (!phone && !['https', 'http'].contains(uri.scheme))) {
      return;
    }
    try {
      if (await launchUrl(uri, mode: LaunchMode.externalApplication)) return;
    } catch (_) {}
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.l10n.unableToOpenThisLink)),
      );
    }
  }

  Widget _field(String label, String value, {VoidCallback? onTap}) => Card(
    child: ListTile(
      title: Text(context.tr(label)),
      subtitle: Text(value),
      onTap: onTap,
      trailing: onTap == null ? null : const Icon(Icons.open_in_new, size: 18),
    ),
  );
  Widget _openingHours() {
    final descriptions = _stop.operatingHours['weekdayDescriptions'];
    final rows =
        (descriptions is List
                ? descriptions.whereType<String>()
                : _stop.openingHours.split(';'))
            .map((row) => row.trim())
            .where((row) => row.isNotEmpty)
            .toList();
    if (rows.length < 2) {
      return _field('Opening hours', rows.firstOrNull ?? _stop.openingHours);
    }

    final date = widget.visitDate;
    final weekday = date == null ? null : DateFormat.EEEE('en_US').format(date);
    final visitHours = weekday == null
        ? null
        : rows.where((row) => row.startsWith('$weekday:')).firstOrNull;
    return Card(
      child: ExpansionTile(
        title: Text(context.l10n.openingHours),
        subtitle: visitHours == null ? null : Text(visitHours),
        children: [
          for (final row in rows)
            Align(
              alignment: AlignmentDirectional.centerStart,
              child: Padding(
                padding: const EdgeInsetsDirectional.fromSTEB(16, 4, 16, 8),
                child: Text(row),
              ),
            ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final details = _stop.googleDetails;
    final description = _stop.description.trim();
    final hasDescription =
        description.isNotEmpty &&
        description.replaceFirst(RegExp(r'\.$'), '') !=
            'Description unavailable';
    final phone = details?.phone?.trim();
    final rating = details?.rating;
    final reviewCount = details?.reviewCount;
    final theme = Theme.of(context);
    return Scaffold(
      backgroundColor: AppColors.nightCanvas,
      appBar: AppBar(title: Text(_stop.title)),
      body: SafeArea(
        top: false,
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            if (widget.stop.time.trim().isNotEmpty)
              Card(
                color: theme.colorScheme.secondaryContainer,
                child: ListTile(
                  leading: const Icon(Icons.schedule),
                  iconColor: theme.colorScheme.onSecondaryContainer,
                  textColor: theme.colorScheme.onSecondaryContainer,
                  title: Text(
                    widget.stop.time,
                    style: theme.textTheme.titleMedium?.copyWith(
                      color: theme.colorScheme.onSecondaryContainer,
                    ),
                  ),
                  subtitle: Text(
                    '${context.tr('Scheduled time')} · ${widget.stop.duration}',
                  ),
                ),
              ),
            if (_loading) const LinearProgressIndicator(),
            if (_error != null)
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    children: [
                      Text(
                        context.l10n.valueYourScheduledTimeRemainsSaved(
                          (_error).toString(),
                        ),
                      ),
                      TextButton(
                        onPressed: _refresh,
                        child: Text(context.l10n.retry),
                      ),
                    ],
                  ),
                ),
              ),
            if (details != null && details.photos.isNotEmpty) ...[
              SizedBox(
                height: 220,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(14),
                  child: PageView.builder(
                    allowImplicitScrolling: true,
                    itemCount: details.photos.length,
                    onPageChanged: (index) {
                      setState(() => _activePhotoIndex = index);
                    },
                    itemBuilder: (context, index) => GooglePlaceImage(
                      placeId: details.id,
                      photo: details.photos[index],
                      photoIndex: index,
                      service: _service,
                      autoLoad: true,
                      fill: true,
                      showGoogleMapsAttribution: true,
                    ),
                  ),
                ),
              ),
              if (details.photos.length > 1)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Center(
                    child: Text(
                      '${_activePhotoIndex + 1} / ${details.photos.length}',
                      style: Theme.of(context).textTheme.labelMedium,
                    ),
                  ),
                ),
              const SizedBox(height: 12),
            ] else if (_stop.primaryPhotoUrl != null)
              Image.network(
                _stop.primaryPhotoUrl!,
                height: 220,
                fit: BoxFit.cover,
                errorBuilder: (_, _, _) => SizedBox(
                  height: 120,
                  child: Center(child: Text(context.l10n.photoUnavailable)),
                ),
              ),
            if (_stop.isGooglePlace)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 8),
                child: Text(
                  'Google Maps',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
              ),
            if (hasDescription)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Text(description),
              ),
            _openingHours(),
            if (_stop.isGooglePlace) ...[
              if (rating != null || reviewCount != null)
                Card(
                  child: ListTile(
                    leading: const Icon(Icons.star_outline),
                    title: Text(rating?.toString() ?? context.l10n.reviews),
                    subtitle: reviewCount == null
                        ? null
                        : Text(
                            context.l10n.valueReviews2(reviewCount.toString()),
                          ),
                  ),
                ),
              Card(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    ListTile(
                      title: Text(context.l10n.address),
                      subtitle: Text(
                        details?.address ?? context.l10n.addressUnavailable,
                      ),
                    ),
                    if (details?.mapsUri != null)
                      Padding(
                        padding: const EdgeInsetsDirectional.fromSTEB(
                          16,
                          0,
                          16,
                          8,
                        ),
                        child: TextButton.icon(
                          onPressed: () => _open(details!.mapsUri),
                          icon: const Icon(Icons.directions_outlined),
                          label: Text(context.l10n.openInGoogleMaps),
                        ),
                      ),
                  ],
                ),
              ),
              if (phone != null && phone.isNotEmpty)
                Card(
                  child: ListTile(
                    title: Text(context.l10n.phone),
                    subtitle: Text(phone),
                    trailing: const Icon(Icons.call_outlined),
                    onTap: () => _open(phone, phone: true),
                  ),
                ),
              _field(
                'Website',
                details?.website ?? 'Website unavailable',
                onTap: details?.website == null
                    ? null
                    : () => _open(details!.website),
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
      ),
    );
  }
}
