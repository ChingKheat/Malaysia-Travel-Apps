import 'package:flutter/material.dart';
import '../../places/models/google_place_details.dart';
import '../../places/services/google_places_service.dart';
import '../../places/services/place_catalog_service.dart';
import '../../places/services/place_classifier.dart';
import '../../places/widgets/google_place_image.dart';
import '../../places/widgets/google_maps_attribution.dart';
import '../services/admin_places_repository.dart';

class PlaceReviewPage extends StatefulWidget {
  const PlaceReviewPage({
    super.key,
    required this.row,
    this.repository,
    this.google,
  });
  final Map<String, dynamic> row;
  final AdminPlacesRepository? repository;
  final GooglePlacesService? google;
  @override
  State<PlaceReviewPage> createState() => _PlaceReviewPageState();
}

class _PlaceReviewPageState extends State<PlaceReviewPage> {
  late final _google = widget.google ?? GooglePlacesService();
  late String _category = widget.row['category'] as String;
  late String _setting = widget.row['is_indoor'] == true
      ? 'Indoor'
      : widget.row['is_indoor'] == false
      ? 'Outdoor'
      : 'Needs review';
  GooglePlaceDetails? _details;
  bool _busy = false;
  String? _error;
  Future<void> _load() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final details = await _google.fetchDetails(
        widget.row['place_id'] as String,
      );
      if (!mounted) return;
      setState(() {
        _details = details;
        _error = details == null
            ? _google.lastError ?? 'Details unavailable'
            : null;
      });
    } catch (_) {
      if (mounted) setState(() => _error = 'Unable to load details. Retry.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _save() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await (widget.repository ?? AdminPlacesRepository()).saveReview(
        widget.row,
        _category,
        _setting == 'Needs review' ? null : _setting == 'Indoor',
      );
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _busy = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final suggestion = _details == null
        ? null
        : PlaceClassifier.classify(
            category: _details!.category ?? '',
            name: _details!.name ?? '',
          );
    return Scaffold(
      appBar: AppBar(title: const Text('Review saved place')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Text(
            'Stored database information',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          SelectableText(
            'ID: ${widget.row['place_id']}\nState: ${widget.row['state']}\nCategory: ${widget.row['category']}',
          ),
          const Text(
            'Google references store IDs only. Zero coordinates are placeholders, not the location.',
          ),
          const SizedBox(height: 20),
          Text(
            'Live Google information',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          FilledButton(
            onPressed: _busy ? null : _load,
            child: const Text('Load / retry live details'),
          ),
          if (_busy) const LinearProgressIndicator(),
          if (_error != null)
            Text(
              _error!,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          if (_details != null) ...[
            Text(_details!.name ?? 'Name unavailable'),
            Text(_details!.address ?? 'Address unavailable'),
            Text('Google type: ${_details!.category ?? 'Unknown'}'),
            GoogleMapsAttribution(attributions: _details!.attributions),
            Text(
              'Detected state: ${AdminPlacesRepository.googleState(_details!.data) ?? 'Unverified'}',
            ),
            Text(
              'Setting suggestion: ${suggestion == null
                  ? 'Needs review'
                  : suggestion
                  ? 'Indoor'
                  : 'Outdoor'} — confirm using your knowledge; this is not verified.',
            ),
            ..._details!.photos.asMap().entries.map(
              (e) => GooglePlaceImage(
                placeId: _details!.id,
                photo: e.value,
                photoIndex: e.key,
                service: _google,
              ),
            ),
          ],
          const SizedBox(height: 20),
          DropdownButtonFormField<String>(
            isExpanded: true,
            initialValue: _category,
            decoration: const InputDecoration(labelText: 'App category'),
            items: {
              ...PlaceCatalogService.appCategories,
              _category,
            }.map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(),
            onChanged: _busy ? null : (v) => setState(() => _category = v!),
          ),
          DropdownButtonFormField<String>(
            isExpanded: true,
            initialValue: _setting,
            decoration: const InputDecoration(labelText: 'Confirmed setting'),
            items: [
              'Needs review',
              'Indoor',
              'Outdoor',
            ].map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(),
            onChanged: _busy ? null : (v) => setState(() => _setting = v!),
          ),
          const SizedBox(height: 12),
          FilledButton(
            onPressed: _busy ? null : _save,
            child: const Text('Confirm and save review'),
          ),
          const Text(
            'Only app category and setting are saved. Existing Google details are not stored.',
          ),
        ],
      ),
    );
  }
}
