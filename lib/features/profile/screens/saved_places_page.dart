import 'package:flutter/material.dart';
import 'dart:typed_data';
import 'package:smart_travel_planner/core/theme/app_colors.dart';
import 'package:smart_travel_planner/features/image_recognition/services/recognition_history_store.dart';
import 'package:smart_travel_planner/features/image_recognition/data/visual_scan_results.dart';
import 'package:smart_travel_planner/features/itinerary/services/scan_plan_places_store.dart';
import 'package:smart_travel_planner/features/places/screens/attraction_detail_page.dart';
import 'package:smart_travel_planner/features/places/services/place_wishlist_store.dart';
import 'package:smart_travel_planner/features/places/utils/attraction_image_resolver.dart';
import 'package:smart_travel_planner/features/places/widgets/wishlist_note_dialog.dart';
import 'package:smart_travel_planner/l10n/localized_labels.dart';
import 'package:smart_travel_planner/shared/models/attraction.dart';

class SavedPlacesPage extends StatefulWidget {
  const SavedPlacesPage({super.key, required this.userId});

  final String userId;

  @override
  State<SavedPlacesPage> createState() => _SavedPlacesPageState();
}

class _SavedPlacesPageState extends State<SavedPlacesPage> {
  late final PlaceWishlistStore _store = PlaceWishlistStore(widget.userId);
  List<Attraction> _places = [];
  Map<String, String> _notes = {};
  final Set<String> _selected = {};
  bool _selecting = false;
  bool _busy = true;
  List<RecognitionHistoryEntry> _history = [];
  final Map<String, Future<Uint8List?>> _photos = {};
  late final RecognitionHistoryStore _historyStore = RecognitionHistoryStore(
    userId: widget.userId,
  );

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final places = await _store.load();
    for (var i = 0; i < places.length; i++) {
      final place = places[i];
      if (place.latitude != 0 && place.longitude != 0) continue;
      final known = scanLandmarkByName(place.name);
      if (known == null) continue;
      final resolved = Attraction(
        xid: place.xid,
        name: place.name,
        latitude: known.latitude,
        longitude: known.longitude,
        category: place.category,
        description: place.description,
      );
      await _store.updatePlace(resolved);
      places[i] = resolved;
    }
    final notes = await _store.loadNotes();
    final history = await _historyStore.load();
    if (mounted) {
      setState(() {
        _places = places;
        _notes = notes;
        _history = history;
        _busy = false;
      });
    }
  }

  String? _photoId(Attraction place) => _history
      .where(
        (entry) => entry.result.name.toLowerCase() == place.name.toLowerCase(),
      )
      .map((entry) => entry.photoId)
      .nonNulls
      .firstOrNull;

  Future<Uint8List?> _photo(Attraction place) {
    final id = _photoId(place);
    if (id == null) return Future.value(null);
    return _photos.putIfAbsent(id, () => _historyStore.loadPhoto(id));
  }

  Future<void> _editNote(Attraction place) async {
    final note = await showWishlistNoteDialog(
      context,
      placeName: place.name,
      initialNote: _notes[place.xid],
    );
    if (note == null) return;
    try {
      await _store.saveNote(place.xid, note);
      await _load();
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.l10n.scanWishlistNoteFailed)),
        );
      }
    }
  }

  Future<void> _open(Attraction place) async {
    final photo = await _photo(place);
    if (!mounted) return;
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => AttractionDetailPage(
          attraction: place,
          heroPhoto: photo == null ? null : MemoryImage(photo),
          isSaved: true,
          onToggleSaved: (item) {
            _store.toggle(item).then((_) => _load());
            return true;
          },
        ),
      ),
    );
    await _load();
  }

  Future<void> _removeSelected() async {
    setState(() => _busy = true);
    for (final id in _selected) {
      await _store.remove(id);
    }
    _selected.clear();
    _selecting = false;
    await _load();
  }

  Future<void> _addSelectedToPlan() async {
    final plan = ScanPlanPlacesStore(widget.userId);
    await plan.load();
    var added = 0;
    for (final place in _places.where((p) => _selected.contains(p.xid))) {
      if (place.latitude == 0 || place.longitude == 0) continue;
      if (await plan.add(place)) added++;
    }
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          added == 0
              ? context.l10n.scanWishlistNothingToPlan
              : context.l10n.scanAddedToPlan,
        ),
      ),
    );
    setState(() {
      _selecting = false;
      _selected.clear();
    });
  }

  Widget _thumbnail(Attraction place) {
    if (_photoId(place) != null) {
      return FutureBuilder<Uint8List?>(
        future: _photo(place),
        builder: (context, snapshot) => snapshot.data == null
            ? _resolvedThumbnail(place)
            : Image.memory(snapshot.data!, fit: BoxFit.cover),
      );
    }
    return _resolvedThumbnail(place);
  }

  Widget _resolvedThumbnail(Attraction place) {
    final asset = AttractionImageResolver.resolveAsset(place);
    final url = AttractionImageResolver.resolvePhotoUrl(place);
    if (asset != null) {
      return Image.asset(
        asset,
        fit: BoxFit.cover,
        errorBuilder: (_, _, _) => const Icon(Icons.place_outlined),
      );
    }
    if (url != null) {
      return Image.network(
        url,
        fit: BoxFit.cover,
        errorBuilder: (_, _, _) => const Icon(Icons.place_outlined),
      );
    }
    return const Icon(Icons.place_outlined, color: AppColors.primary);
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: AppColors.nightCanvas,
    appBar: AppBar(
      title: Text(
        context.l10n.yourSavedPlaces,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      actions: [
        if (_places.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: Center(
              child: OutlinedButton(
                onPressed: () => setState(() {
                  _selecting = !_selecting;
                  _selected.clear();
                }),
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: AppColors.nightLine),
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  minimumSize: const Size(0, 40),
                ),
                child: Text(
                  _selecting
                      ? context.l10n.cancel
                      : context.l10n.scanRemoveSelected,
                ),
              ),
            ),
          ),
      ],
    ),
    body: _busy
        ? const Center(child: CircularProgressIndicator())
        : _places.isEmpty
        ? Center(child: Text(context.l10n.scanWishlistEmpty))
        : Column(
            children: [
              Expanded(
                child: ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: _places.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 12),
                  itemBuilder: (context, index) {
                    final place = _places[index];
                    final selected = _selected.contains(place.xid);
                    return Card(
                      color: AppColors.nightSurface,
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            InkWell(
                              onTap: _selecting
                                  ? () => setState(
                                      () => selected
                                          ? _selected.remove(place.xid)
                                          : _selected.add(place.xid),
                                    )
                                  : () => _open(place),
                              child: Row(
                                children: [
                                  if (_selecting)
                                    Checkbox(
                                      value: selected,
                                      onChanged: (_) => setState(
                                        () => selected
                                            ? _selected.remove(place.xid)
                                            : _selected.add(place.xid),
                                      ),
                                    ),
                                  ClipRRect(
                                    borderRadius: BorderRadius.circular(8),
                                    child: SizedBox(
                                      width: 56,
                                      height: 56,
                                      child: _thumbnail(place),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          place.name,
                                          style: const TextStyle(
                                            fontWeight: FontWeight.w700,
                                          ),
                                        ),
                                        Text(
                                          place.category,
                                          style: const TextStyle(
                                            color: AppColors.muted,
                                          ),
                                        ),
                                        if (_notes[place.xid]?.isNotEmpty ==
                                            true) ...[
                                          const SizedBox(height: 8),
                                          Text.rich(
                                            TextSpan(
                                              children: [
                                                TextSpan(
                                                  text:
                                                      '${context.l10n.savedPlaceNoteLabel}: ',
                                                  style: const TextStyle(
                                                    color: AppColors.primary,
                                                    fontWeight: FontWeight.w700,
                                                  ),
                                                ),
                                                TextSpan(
                                                  text: _notes[place.xid]!,
                                                  style: const TextStyle(
                                                    color: AppColors.muted,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ],
                                      ],
                                    ),
                                  ),
                                  if (!_selecting)
                                    const Icon(Icons.chevron_right),
                                ],
                              ),
                            ),
                            if (!_selecting) ...[
                              const SizedBox(height: 8),
                              OutlinedButton.icon(
                                onPressed: () => _editNote(place),
                                icon: const Icon(Icons.edit_note, size: 18),
                                label: Text(
                                  _notes[place.xid]?.isNotEmpty == true
                                      ? context.l10n.scanWishlistNote
                                      : context.l10n.scanWishlistAddNote,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
    bottomNavigationBar: !_selecting
        ? null
        : SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size(0, 56),
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                      ),
                      onPressed: () => setState(() {
                        if (_selected.length == _places.length) {
                          _selected.clear();
                        } else {
                          _selected.addAll(_places.map((p) => p.xid));
                        }
                      }),
                      child: Text(
                        context.l10n.scanSelectAll,
                        textAlign: TextAlign.center,
                        maxLines: 2,
                        style: const TextStyle(fontSize: 12),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size(0, 56),
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                      ),
                      onPressed: _selected.isEmpty ? null : _removeSelected,
                      child: Text(
                        context.l10n.scanRemoveSelected,
                        textAlign: TextAlign.center,
                        maxLines: 2,
                        style: const TextStyle(fontSize: 12),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: FilledButton(
                      style: FilledButton.styleFrom(
                        minimumSize: const Size(0, 56),
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                      ),
                      onPressed: _selected.isEmpty ? null : _addSelectedToPlan,
                      child: Text(
                        context.l10n.scanWishlistAddToPlan,
                        textAlign: TextAlign.center,
                        maxLines: 2,
                        style: const TextStyle(fontSize: 12),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
  );
}
