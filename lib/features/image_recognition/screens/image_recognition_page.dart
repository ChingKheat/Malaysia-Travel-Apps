import 'package:smart_travel_planner/l10n/localized_labels.dart';
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:latlong2/latlong.dart';
import 'package:uuid/uuid.dart';

import 'package:smart_travel_planner/features/image_recognition/models/recognition_result.dart';
import 'package:smart_travel_planner/features/image_recognition/data/visual_scan_results.dart';
import 'package:smart_travel_planner/features/image_recognition/screens/recognition_scan_screen.dart';
import 'package:smart_travel_planner/features/image_recognition/services/recognition_history_store.dart';
import 'package:smart_travel_planner/features/image_recognition/services/image_recognition_service.dart';
import 'package:smart_travel_planner/features/image_recognition/widgets/recognition_result_sheet.dart';
import 'package:smart_travel_planner/features/image_recognition/widgets/scan_photo_guidance.dart';
import 'package:smart_travel_planner/features/image_recognition/widgets/scan_distance_label.dart';
import 'package:smart_travel_planner/features/places/screens/attraction_detail_page.dart';
import 'package:smart_travel_planner/features/places/data/curated_attractions.dart';
import 'package:smart_travel_planner/features/places/utils/attraction_image_resolver.dart';
import 'package:smart_travel_planner/features/places/services/place_wishlist_store.dart';
import 'package:smart_travel_planner/features/places/services/google_places_service.dart';
import 'package:smart_travel_planner/features/places/models/google_place_details.dart';
import 'package:smart_travel_planner/features/places/widgets/google_place_image.dart';
import 'package:smart_travel_planner/shared/models/attraction.dart';
import 'package:smart_travel_planner/shared/data/malaysia_states.dart';
import 'package:smart_travel_planner/shared/services/location_service.dart';
import 'package:smart_travel_planner/features/itinerary/services/scan_plan_places_store.dart';

import 'package:smart_travel_planner/features/image_recognition/widgets/visual_scan_style.dart';

/// Capturing or selecting a photo starts a live scan.
class ImageRecognitionPage extends StatefulWidget {
  const ImageRecognitionPage({
    super.key,
    this.userId = 'guest',
    this.service,
    this.imagePicker,
    this.historyStore,
    this.onOpenPlan,
  });

  final String userId;
  final ImageRecognitionService? service;
  final ImagePicker? imagePicker;
  final RecognitionHistoryStore? historyStore;
  final VoidCallback? onOpenPlan;

  @override
  State<ImageRecognitionPage> createState() => _ImageRecognitionPageState();
}

class _ImageRecognitionPageState extends State<ImageRecognitionPage> {
  late final ImagePicker _picker;
  late final ImageRecognitionService _service;
  late final RecognitionHistoryStore _store;

  Future<void> _pendingWrite = Future.value();
  late final Future<void> _historyLoaded;
  List<RecognitionHistoryEntry> _history = [];
  final Map<String, Future<Uint8List?>> _historyPhotos = {};
  final Map<String, Future<GooglePlaceDetails?>> _wishlistDetails = {};
  late final GooglePlacesService _placesService = GooglePlacesService();
  bool _showHistory = false;
  bool _showWishlist = false;
  bool _selectingHistory = false;
  bool _selectingWishlist = false;
  bool _planningWishlist = false;
  bool _resolvingWishlist = false;
  final Set<int> _selectedHistory = {};
  final Set<int> _selectedWishlist = {};
  List<Attraction> _wishlistPlaces = [];
  Map<String, String> _wishlistNotes = {};
  PlaceWishlistStore get _wishlist => PlaceWishlistStore(widget.userId);
  final LocationService _location = LocationService();
  int _scannerVersion = 0;
  RecognitionResult? _result;
  ImageProvider<Object>? _resultPhoto;
  bool _picking = false;
  bool _recognizing = false;

  @override
  void initState() {
    super.initState();
    _picker = widget.imagePicker ?? ImagePicker();
    _service = widget.service ?? ImageRecognitionService();
    _store =
        widget.historyStore ?? RecognitionHistoryStore(userId: widget.userId);
    _historyLoaded = _loadHistory();
    _location.addListener(_onLocationChanged);
  }

  void _onLocationChanged() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _location.removeListener(_onLocationChanged);
    super.dispose();
  }

  Future<void> _loadHistory() async {
    final history = await _store.load();
    if (mounted) {
      setState(
        () =>
            _history = history.where((item) => !item.result.isSample).toList(),
      );
    }
  }

  Widget _historyThumbnail(String? photoId) {
    final id = photoId;
    if (id == null) return _missingHistoryThumbnail();
    return FutureBuilder<Uint8List?>(
      future: _historyPhotos.putIfAbsent(id, () => _store.loadPhoto(id)),
      builder: (context, snapshot) {
        final bytes = snapshot.data;
        if (bytes == null) return _missingHistoryThumbnail();
        return ClipRRect(
          borderRadius: BorderRadius.circular(9),
          child: Image.memory(
            bytes,
            width: 56,
            height: 56,
            fit: BoxFit.cover,
            errorBuilder: (_, _, _) => _missingHistoryThumbnail(),
          ),
        );
      },
    );
  }

  Widget _missingHistoryThumbnail() => const SizedBox(
    width: 56,
    height: 56,
    child: Icon(Icons.image_outlined, color: VisualScanStyle.amber),
  );

  Widget _wishlistThumbnail(Attraction place) {
    final photoId = _wishlistPhotoId(place);
    if (photoId != null) return _historyThumbnail(photoId);
    final asset = AttractionImageResolver.resolveAsset(place);
    if (asset != null) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(9),
        child: Image.asset(asset, width: 56, height: 56, fit: BoxFit.cover),
      );
    }
    final placeId = place.googlePlaceId;
    if (placeId == null) return _missingHistoryThumbnail();
    return FutureBuilder<GooglePlaceDetails?>(
      future: _wishlistDetails.putIfAbsent(
        placeId,
        () => _placesService.fetchDetails(placeId, basic: true),
      ),
      builder: (context, snapshot) {
        final photo = snapshot.data?.photos.firstOrNull;
        if (photo == null) return _missingHistoryThumbnail();
        return ClipRRect(
          borderRadius: BorderRadius.circular(9),
          child: SizedBox(
            width: 56,
            height: 56,
            child: GooglePlaceImage(
              placeId: placeId,
              photo: photo,
              service: _placesService,
              requestWidth: 112,
              autoLoad: true,
              fill: true,
              showGoogleMapsAttribution: false,
              showPhotoAuthorAttribution: false,
              fallback: _missingHistoryThumbnail(),
            ),
          ),
        );
      },
    );
  }

  String? _wishlistPhotoId(Attraction place) => _history
      .where(
        (entry) => entry.result.name.toLowerCase() == place.name.toLowerCase(),
      )
      .map((entry) => entry.photoId)
      .nonNulls
      .firstOrNull;

  Future<void> _openWishlistPlace(Attraction place) async {
    await _pendingWrite;
    final photoId = _wishlistPhotoId(place);
    final bytes = await _store.loadPhoto(photoId);
    if (!mounted) return;
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => AttractionDetailPage(
          attraction: place,
          placesService: _placesService,
          showSaveFeedback: false,
          heroPhoto: bytes == null ? null : MemoryImage(bytes),
          isSaved: true,
          onToggleSaved: (item) {
            _toggleWishlist(item);
            return true;
          },
        ),
      ),
    );
  }

  void _saveHistory({(String, Uint8List)? photo}) {
    final entries = List<RecognitionHistoryEntry>.of(_history);
    _pendingWrite = _pendingWrite.then((_) async {
      await _store.save(entries, photo: photo);
    });
  }

  void _showResult(RecognitionResult result, {ImageProvider<Object>? photo}) {
    setState(() {
      _result = result;
      _resultPhoto = photo;
    });
  }

  Future<void> _showHistoryEntry(RecognitionHistoryEntry entry) async {
    _showResult(entry.result);
    if (entry.photoId == null) return;
    await _pendingWrite;
    final bytes = await _store.loadPhoto(entry.photoId);
    if (mounted && identical(_result, entry.result) && bytes != null) {
      setState(() => _resultPhoto = MemoryImage(bytes));
    }
  }

  void _confirmReference(RecognitionResult result, String id) {
    _replaceResult(result, _service.confirmReference(result, id));
  }

  void _replaceResult(RecognitionResult result, RecognitionResult selected) {
    if (_result != result) return;
    if (identical(selected, result)) return;
    setState(() {
      _result = selected;
      _history = [
        for (final entry in _history)
          identical(entry.result, result)
              ? (result: selected, photoId: entry.photoId)
              : entry,
      ];
    });
    _saveHistory();
  }

  void _closeResult({required bool newScan}) {
    setState(() {
      _result = null;
      _resultPhoto = null;
      if (newScan) {
        _showHistory = false;
        _scannerVersion++;
      }
    });
  }

  Future<void> _openWishlist() async {
    final places = await _wishlist.load();
    final notes = await _wishlist.loadNotes();
    if (mounted) {
      setState(() {
        _wishlistPlaces = places;
        _wishlistNotes = notes;
        _showWishlist = true;
        _showHistory = false;
        _result = null;
        _resultPhoto = null;
      });
      _resolveWishlistLocations();
    }
  }

  Future<void> _resolveWishlistLocations() async {
    if (_resolvingWishlist) return;
    _resolvingWishlist = true;
    try {
      for (final saved in List<Attraction>.of(_wishlistPlaces)) {
        if ((saved.latitude != 0 && saved.longitude != 0) ||
            saved.name == 'Saved place') {
          continue;
        }
        final known = scanLandmarkByName(saved.name);
        GooglePlaceDetails? details;
        if (known == null) {
          try {
            details = saved.googlePlaceId != null
                ? await _placesService.fetchDetails(
                    saved.googlePlaceId!,
                    basic: true,
                  )
                : await _service.lookupPlace(saved.name);
          } catch (_) {
            continue;
          }
        }
        final latitude = known?.latitude ?? details?.latitude;
        final longitude = known?.longitude ?? details?.longitude;
        if (latitude == null ||
            longitude == null ||
            latitude < 0.8 ||
            latitude > 7.5 ||
            longitude < 99 ||
            longitude > 120) {
          continue;
        }
        final resolved = Attraction(
          xid: saved.xid,
          name: saved.name,
          latitude: latitude,
          longitude: longitude,
          category: saved.category,
          description: saved.description,
        );
        try {
          await _wishlist.updatePlace(resolved);
          if (mounted) {
            setState(() {
              final index = _wishlistPlaces.indexWhere(
                (place) => place.xid == saved.xid,
              );
              if (index >= 0) _wishlistPlaces[index] = resolved;
            });
          }
        } catch (_) {
          // Keep the saved place visible if local storage is unavailable.
        }
      }
    } finally {
      _resolvingWishlist = false;
    }
  }

  Future<void> _toggleWishlist(Attraction place) async {
    try {
      final places = await _wishlist.toggle(place);
      if (mounted) {
        setState(() {
          _wishlistPlaces = places;
          _wishlistNotes.remove(place.xid);
        });
      }
    } catch (_) {
      _notify('Could not update your wishlist. Try again.');
    }
  }

  Future<void> _openQuickPlace(Attraction place, String? photo) async {
    final saved = await _wishlist.load();
    if (!mounted) return;
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => AttractionDetailPage(
          attraction: place,
          showSaveFeedback: false,
          heroPhoto: photo == null ? null : AssetImage(photo),
          isSaved: saved.any((item) => item.xid == place.xid),
          onToggleSaved: (item) {
            _toggleWishlist(item);
            return true;
          },
        ),
      ),
    );
  }

  Future<void> _pickPhoto(ImageSource source) async {
    if (_picking || _recognizing) return;
    setState(() => _picking = true);
    late final Uint8List bytes;
    try {
      final photo = await _picker.pickImage(
        source: source,
        maxWidth: 1600,
        maxHeight: 1600,
        imageQuality: 85,
        requestFullMetadata: false,
      );
      if (photo == null || !mounted) return;
      if (await photo.length() > ImageRecognitionService.maxImageBytes) {
        _notify('Choose a photo smaller than 4 MB.');
        return;
      }
      bytes = await photo.readAsBytes();
      if (bytes.isEmpty ||
          bytes.length > ImageRecognitionService.maxImageBytes) {
        _notify('Choose a photo smaller than 4 MB.');
        return;
      }
    } on MissingPluginException {
      _notify('Restart the app to enable the camera and photo library.');
      return;
    } on PlatformException {
      _notify('Camera or photo library unavailable. Check access in Settings.');
      return;
    } catch (_) {
      _notify('This photo could not be opened. Try another photo.');
      return;
    } finally {
      if (mounted) setState(() => _picking = false);
    }
    if (mounted) await _recognize(bytes);
  }

  Future<void> _recognize(Uint8List bytes) async {
    if (_recognizing) return;
    setState(() => _recognizing = true);
    try {
      final outcome = await Navigator.push<ScanOutcome>(
        context,
        MaterialPageRoute(
          fullscreenDialog: true,
          builder: (_) => RecognitionScanScreen(
            photo: bytes,
            recognize: _service.recognize,
          ),
        ),
      );
      if (!mounted || outcome == null) return;
      final result = outcome.result;
      if (result == null) {
        _notify(outcome.error!);
        return;
      }
      await _historyLoaded;
      if (!mounted) return;
      final photoId = const Uuid().v4();
      setState(
        () => _history = [
          (result: result, photoId: photoId),
          ..._history,
        ].take(RecognitionHistoryStore.maxEntries).toList(),
      );
      _saveHistory(photo: (photoId, bytes));
      _showResult(result, photo: MemoryImage(bytes));
    } finally {
      if (mounted) setState(() => _recognizing = false);
    }
  }

  void _notify(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(context.tr(message)),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
      );
  }

  Future<void> _clearHistory() async {
    if (_selectedHistory.isEmpty) return;
    setState(() {
      _history = [
        for (var i = 0; i < _history.length; i++)
          if (!_selectedHistory.contains(i)) _history[i],
      ];
      _historyPhotos.clear();
      _selectedHistory.clear();
      _selectingHistory = false;
    });
    _saveHistory();
  }

  Future<void> _clearWishlist() async {
    if (_selectedWishlist.isEmpty) return;
    final places = [
      for (var i = 0; i < _wishlistPlaces.length; i++)
        if (_selectedWishlist.contains(i)) _wishlistPlaces[i],
    ];
    for (final place in places) {
      await _toggleWishlist(place);
    }
    if (mounted) {
      setState(() {
        _selectedWishlist.clear();
        _selectingWishlist = false;
      });
    }
  }

  String _wishlistDestination(Attraction place) {
    if (place.latitude == 0 || place.longitude == 0) {
      return context.l10n.scanWishlistOtherPlaces;
    }
    final point = LatLng(place.latitude, place.longitude);
    CityArea? closestArea;
    var closestMeters = double.infinity;
    for (final state in malaysiaStatesData) {
      for (final area in state.areas) {
        final meters = const Distance().as(
          LengthUnit.Meter,
          point,
          LatLng(area.latitude, area.longitude),
        );
        if (meters < closestMeters) {
          closestMeters = meters;
          closestArea = area;
        }
      }
    }
    return closestMeters <= 35000 && closestArea != null
        ? closestArea.name
        : nearestMalaysiaState(point);
  }

  Future<void> _editWishlistNote(Attraction place) async {
    final controller = TextEditingController(text: _wishlistNotes[place.xid]);
    final note = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(context.l10n.scanWishlistNote),
        content: TextField(
          controller: controller,
          autofocus: true,
          maxLength: 200,
          maxLines: 3,
          decoration: InputDecoration(
            hintText: context.l10n.scanWishlistNoteHint,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: Text(context.l10n.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, controller.text),
            child: Text(context.l10n.save),
          ),
        ],
      ),
    );
    if (note == null) return;
    try {
      await _wishlist.saveNote(place.xid, note);
      if (mounted) {
        setState(() {
          if (note.trim().isEmpty) {
            _wishlistNotes.remove(place.xid);
          } else {
            _wishlistNotes[place.xid] = note.trim();
          }
        });
      }
    } catch (_) {
      if (mounted) _notify(context.l10n.scanWishlistNoteFailed);
    }
  }

  Future<void> _addSelectedWishlistToPlan() async {
    final selected = [
      for (var i = 0; i < _wishlistPlaces.length; i++)
        if (_selectedWishlist.contains(i)) _wishlistPlaces[i],
    ];
    final store = ScanPlanPlacesStore(widget.userId);
    await store.load();
    var added = 0;
    for (final place in selected) {
      if (place.latitude == 0 || place.longitude == 0) continue;
      if (await store.add(place)) added++;
    }
    if (!mounted) return;
    _cancelSelection();
    if (added == 0) {
      _notify(context.l10n.scanWishlistNothingToPlan);
      return;
    }
    widget.onOpenPlan?.call();
  }

  void _cancelSelection() => setState(() {
    _selectingHistory = false;
    _selectingWishlist = false;
    _selectedHistory.clear();
    _selectedWishlist.clear();
    _planningWishlist = false;
  });

  Widget _selectionBar({required bool history}) {
    final selected = history ? _selectedHistory : _selectedWishlist;
    final count = history ? _history.length : _wishlistPlaces.length;
    return SafeArea(
      top: false,
      child: Container(
        decoration: const BoxDecoration(
          color: VisualScanStyle.surface,
          border: Border(top: BorderSide(color: VisualScanStyle.border)),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Row(
          children: [
            Expanded(
              child: TextButton(
                onPressed: () => setState(() {
                  if (selected.length == count) {
                    selected.clear();
                  } else {
                    selected.addAll(List.generate(count, (index) => index));
                  }
                }),
                child: Text(context.l10n.scanSelectAll),
              ),
            ),
            Expanded(
              child: TextButton(
                onPressed: _cancelSelection,
                child: Text(context.l10n.cancel),
              ),
            ),
            Expanded(
              child: FilledButton(
                onPressed: selected.isEmpty
                    ? null
                    : history
                    ? _clearHistory
                    : _planningWishlist
                    ? _addSelectedWishlistToPlan
                    : _clearWishlist,
                child: Text(
                  !history && _planningWishlist
                      ? context.l10n.scanWishlistAddToPlan
                      : context.l10n.clear,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) => Material(
    color: VisualScanStyle.background,
    child: Column(
      children: [
        Expanded(
          child: switch (_result) {
            final result? => RecognitionResultSheet(
              key: ObjectKey(result),
              result: result,
              service: _service,
              userId: widget.userId,
              photo: _resultPhoto,
              onReferenceSelected: (id) => _confirmReference(result, id),
              onTakeAnotherPhoto: _picking || _recognizing
                  ? null
                  : () => _pickPhoto(ImageSource.camera),
              onUploadAnotherPhoto: _picking || _recognizing
                  ? null
                  : () => _pickPhoto(ImageSource.gallery),
              onBack: _showHistory ? () => _closeResult(newScan: false) : null,
              onOpenWishlist: _openWishlist,
              onOpenPlan: widget.onOpenPlan,
              onNewScan: () => _closeResult(newScan: true),
            ),
            null =>
              _showWishlist
                  ? _wishlistTab()
                  : _showHistory
                  ? _historyTab()
                  : _scanner(),
          },
        ),
        if (_result == null && _showHistory && _selectingHistory)
          _selectionBar(history: true),
        if (_result == null && _showWishlist && _selectingWishlist)
          _selectionBar(history: false),
      ],
    ),
  );

  Widget _scanner() => ListView(
    key: PageStorageKey('recognition-scanner-$_scannerVersion'),
    padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
    children: [
      _scanNavigation(),
      const SizedBox(height: 12),
      _scanHero(),
      const SizedBox(height: 25),
      Container(
        decoration: _scanPanel(),
        padding: const EdgeInsets.all(16),
        child: const ScanPhotoGuidance(),
      ),
      const SizedBox(height: 24),
      Text(
        _location.isUsingRealGps
            ? context.l10n.scanQuickLandmarks
            : context.l10n.scanQuickLandmarksMap(_location.currentAreaName),
        style: VisualScanStyle.heading(20),
      ),
      const SizedBox(height: 5),
      Text(
        context.l10n.scanQuickLandmarksHint,
        style: const TextStyle(color: VisualScanStyle.muted, fontSize: 13),
      ),
      const SizedBox(height: 12),
      for (final place in _quickLandmarks) ...[
        _quickLandmarkCard(place),
        const SizedBox(height: 10),
      ],
      const SizedBox(height: 14),
      Text(
        context.l10n.scanHistoryPhotoPrivacy,
        style: const TextStyle(color: VisualScanStyle.muted, fontSize: 12),
      ),
    ],
  );

  Widget _scanNavigation() => Row(
    children: [
      Expanded(
        child: OutlinedButton.icon(
          key: const ValueKey('scan-history'),
          onPressed: () => setState(() => _showHistory = true),
          icon: const Icon(Icons.history, size: 17),
          label: Text(context.l10n.history),
          style: _heroButtonStyle(),
        ),
      ),
      const SizedBox(width: 10),
      Expanded(
        child: OutlinedButton.icon(
          key: const ValueKey('scan-wishlist'),
          onPressed: _openWishlist,
          icon: const Icon(Icons.bookmark_border, size: 17),
          label: Text(context.l10n.scanWishlist),
          style: _heroButtonStyle(),
        ),
      ),
    ],
  );

  List<Attraction> get _quickLandmarks {
    final picturedKualaLumpur = <Attraction>[
      curatedMalaysianAttractions.firstWhere(
        (place) => place.xid == 'curated_kl_01',
      ),
      curatedMalaysianAttractions.firstWhere(
        (place) => place.xid == 'curated_kl_02',
      ),
      const Attraction(
        xid: 'scan_sultan_abdul_samad',
        name: 'Sultan Abdul Samad Building',
        latitude: 3.14861,
        longitude: 101.69444,
        category: 'Historic Landmark',
        description:
            'A landmark beside Merdeka Square, known for its Moorish arches, copper domes and clock tower.',
      ),
    ];
    const distance = Distance(roundResult: false);
    final nearKualaLumpur =
        distance(_location.currentLocation, const LatLng(3.14861, 101.69444)) <=
        20000;
    final places = nearKualaLumpur
        ? picturedKualaLumpur
        : curatedMalaysianAttractions
              .where(
                (place) => RegExp(
                  r'sights|landmark|historic|cultural|museum|temple|nature|park',
                  caseSensitive: false,
                ).hasMatch(place.category),
              )
              .toList();
    places.sort(
      (a, b) => distance(
        _location.currentLocation,
        a.point,
      ).compareTo(distance(_location.currentLocation, b.point)),
    );
    return places.take(3).toList();
  }

  String? _quickPhoto(Attraction place) =>
      place.xid == 'scan_sultan_abdul_samad'
      ? 'assets/recognition/sultan_abdul_samad.jpg'
      : AttractionImageResolver.resolveAsset(place);

  Widget _quickLandmarkCard(Attraction place) {
    final meters = const Distance(roundResult: false)(
      _location.currentLocation,
      place.point,
    );
    final photo = _quickPhoto(place);
    return Material(
      color: VisualScanStyle.surface,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: VisualScanStyle.border),
      ),
      child: InkWell(
        onTap: () => _openQuickPlace(place, photo),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    width: 76,
                    height: 64,
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: photo == null
                          ? const Icon(
                              Icons.place_outlined,
                              color: VisualScanStyle.amber,
                            )
                          : Image.asset(photo, fit: BoxFit.cover),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          place.category.split(',').first,
                          style: const TextStyle(
                            color: VisualScanStyle.amber,
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(place.name, style: VisualScanStyle.heading(16)),
                        const SizedBox(height: 4),
                        Text(
                          place.description ?? '',
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: VisualScanStyle.muted,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const Divider(height: 1, color: VisualScanStyle.border),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      scanDistanceLabel(context, meters, fromLandmark: false),
                      style: const TextStyle(
                        color: VisualScanStyle.muted,
                        fontSize: 11,
                      ),
                    ),
                  ),
                  const Icon(
                    Icons.arrow_forward,
                    size: 16,
                    color: VisualScanStyle.amber,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _scanHero() => ClipRRect(
    borderRadius: BorderRadius.circular(18),
    child: Stack(
      children: [
        Positioned.fill(
          child: Image.asset(
            'assets/recognition/scan_hero_klcc.png',
            fit: BoxFit.cover,
            alignment: Alignment.topCenter,
          ),
        ),
        Positioned.fill(
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.black.withValues(alpha: 0.56),
                  Colors.black.withValues(alpha: 0.22),
                  Colors.black.withValues(alpha: 0.91),
                ],
              ),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 178),
              Text(
                context.l10n.scanIdentifyLandmark,
                style: VisualScanStyle.heading(27),
              ),
              const SizedBox(height: 7),
              Text(
                context.l10n.scanPhotoIntro,
                style: const TextStyle(
                  color: VisualScanStyle.text,
                  fontSize: 13,
                  height: 1.35,
                ),
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    child: _scanAction(
                      label: context.l10n.takePhoto,
                      icon: Icons.photo_camera_outlined,
                      source: ImageSource.camera,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _scanAction(
                      label:
                          Localizations.localeOf(context).languageCode == 'en'
                          ? 'Upload Image'
                          : context.l10n.uploadFromGallery,
                      icon: Icons.file_upload_outlined,
                      source: ImageSource.gallery,
                    ),
                  ),
                ],
              ),
              if (_picking)
                const Padding(
                  padding: EdgeInsets.only(top: 10),
                  child: LinearProgressIndicator(color: VisualScanStyle.amber),
                ),
            ],
          ),
        ),
      ],
    ),
  );

  ButtonStyle _heroButtonStyle() => OutlinedButton.styleFrom(
    foregroundColor: VisualScanStyle.text,
    backgroundColor: Colors.black.withValues(alpha: 0.58),
    minimumSize: const Size(0, 46),
    side: const BorderSide(color: VisualScanStyle.amber),
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    textStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
  );

  Widget _scanAction({
    required String label,
    required IconData icon,
    required ImageSource source,
  }) {
    return OutlinedButton.icon(
      onPressed: _picking || _recognizing ? null : () => _pickPhoto(source),
      icon: Icon(icon, size: 16),
      label: Text(label, textAlign: TextAlign.center),
      style: _heroButtonStyle(),
    );
  }

  Widget _historyTab() => ListView.builder(
    key: const PageStorageKey('recognition-history'),
    padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
    itemCount: _history.isEmpty ? 2 : _history.length + 1,
    itemBuilder: (context, index) {
      if (index == 0) {
        return Column(
          children: [
            Row(
              children: [
                BackButton(
                  color: VisualScanStyle.amber,
                  onPressed: () {
                    if (_selectingHistory) {
                      _cancelSelection();
                    } else {
                      setState(() => _showHistory = false);
                    }
                  },
                ),
                Expanded(
                  child: Text(
                    context.l10n.history,
                    style: VisualScanStyle.heading(22),
                  ),
                ),
                if (_history.isNotEmpty)
                  MediaQuery.textScalerOf(context).scale(14) > 19
                      ? IconButton.outlined(
                          tooltip: context.l10n.clearHistory,
                          onPressed: () =>
                              setState(() => _selectingHistory = true),
                          icon: const Icon(
                            Icons.delete_outline,
                            color: VisualScanStyle.amber,
                          ),
                        )
                      : SizedBox(
                          width: 140,
                          child: OutlinedButton(
                            onPressed: () =>
                                setState(() => _selectingHistory = true),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: VisualScanStyle.amber,
                              minimumSize: const Size(0, 40),
                              maximumSize: const Size(140, 48),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                              ),
                              side: const BorderSide(
                                color: VisualScanStyle.amber,
                              ),
                            ),
                            child: Text(
                              context.l10n.clearHistory,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ),
              ],
            ),
            const SizedBox(height: 12),
          ],
        );
      }
      if (_history.isEmpty) {
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 36),
          decoration: _scanPanel(),
          child: Column(
            children: [
              const Icon(Icons.history, size: 36, color: VisualScanStyle.amber),
              const SizedBox(height: 12),
              Text(context.l10n.noScansYet, style: VisualScanStyle.heading(18)),
              const SizedBox(height: 12),
              TextButton(
                onPressed: () => setState(() => _showHistory = false),
                style: TextButton.styleFrom(
                  foregroundColor: VisualScanStyle.amber,
                ),
                child: Text(context.l10n.goToScanner),
              ),
            ],
          ),
        );
      }
      final entry = _history[index - 1];
      return Column(
        children: [
          Material(
            color: VisualScanStyle.surface,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
              side: const BorderSide(color: VisualScanStyle.border),
            ),
            child: ListTile(
              leading: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (_selectingHistory)
                    Checkbox(
                      value: _selectedHistory.contains(index - 1),
                      activeColor: VisualScanStyle.amber,
                      onChanged: (_) => setState(() {
                        if (!_selectedHistory.add(index - 1)) {
                          _selectedHistory.remove(index - 1);
                        }
                      }),
                    ),
                  _historyThumbnail(entry.photoId),
                ],
              ),
              title: Text(
                entry.result.source == RecognitionSource.areaLookup
                    ? context.l10n.scanPlacesInArea
                    : entry.result.referenceCandidates.isNotEmpty
                    ? context.l10n.referencePossibleMatches
                    : entry.result.kind == 'unknown'
                    ? context.l10n.scanTryAnotherPhoto
                    : entry.result.name,
                style: const TextStyle(
                  color: VisualScanStyle.text,
                  fontWeight: FontWeight.w700,
                ),
              ),
              subtitle: Text(
                '${MaterialLocalizations.of(context).formatShortDate(entry.result.recognizedAt.toLocal())}'
                ' · ${TimeOfDay.fromDateTime(entry.result.recognizedAt.toLocal()).format(context)}',
                style: const TextStyle(color: VisualScanStyle.muted),
              ),
              trailing: _selectingHistory
                  ? null
                  : const Icon(
                      Icons.chevron_right,
                      color: VisualScanStyle.muted,
                    ),
              onTap: () => _selectingHistory
                  ? setState(() {
                      if (!_selectedHistory.add(index - 1)) {
                        _selectedHistory.remove(index - 1);
                      }
                    })
                  : _showHistoryEntry(entry),
            ),
          ),
          const SizedBox(height: 8),
        ],
      );
    },
  );

  Widget _wishlistTab() {
    final entries = _wishlistPlaces.asMap().entries.toList()
      ..sort((a, b) {
        final byDestination = _wishlistDestination(
          a.value,
        ).compareTo(_wishlistDestination(b.value));
        return byDestination != 0
            ? byDestination
            : a.value.name.compareTo(b.value.name);
      });
    return ListView(
      key: const PageStorageKey('recognition-wishlist'),
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
      children: [
        Row(
          children: [
            BackButton(
              color: VisualScanStyle.amber,
              onPressed: () {
                if (_selectingWishlist) {
                  _cancelSelection();
                } else {
                  setState(() => _showWishlist = false);
                }
              },
            ),
            Expanded(
              child: Text(
                context.l10n.scanWishlist,
                style: VisualScanStyle.heading(22),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        if (_wishlistPlaces.isNotEmpty) ...[
          Row(
            children: [
              Expanded(
                child: FilledButton.icon(
                  onPressed: () => setState(() {
                    _selectingWishlist = true;
                    _planningWishlist = true;
                    _selectedWishlist.clear();
                  }),
                  icon: const Icon(Icons.add),
                  label: Text(context.l10n.scanWishlistAddToPlan),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton(
                  onPressed: () => setState(() {
                    _selectingWishlist = true;
                    _planningWishlist = false;
                    _selectedWishlist.clear();
                  }),
                  child: Text(context.l10n.scanClearWishlist),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
        ],
        if (_wishlistPlaces.isEmpty)
          Container(
            padding: const EdgeInsets.all(24),
            decoration: _scanPanel(),
            child: Column(
              children: [
                const Icon(
                  Icons.bookmark_border,
                  size: 36,
                  color: VisualScanStyle.amber,
                ),
                const SizedBox(height: 12),
                Text(
                  context.l10n.scanWishlistEmpty,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: VisualScanStyle.muted),
                ),
              ],
            ),
          ),
        for (final item in entries) ...[
          if (entries.first == item ||
              _wishlistDestination(entries[entries.indexOf(item) - 1].value) !=
                  _wishlistDestination(item.value)) ...[
            Text(
              _wishlistDestination(item.value),
              style: VisualScanStyle.heading(18),
            ),
            if (item.value.latitude == 0 || item.value.longitude == 0)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  context.l10n.scanWishlistLocationHelp,
                  style: const TextStyle(
                    color: VisualScanStyle.muted,
                    fontSize: 13,
                  ),
                ),
              ),
            const SizedBox(height: 8),
          ],
          Material(
            color: VisualScanStyle.surface,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
              side: const BorderSide(color: VisualScanStyle.border),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ListTile(
                  leading: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (_selectingWishlist)
                        Checkbox(
                          value: _selectedWishlist.contains(item.key),
                          activeColor: VisualScanStyle.amber,
                          onChanged: (_) => setState(() {
                            if (!_selectedWishlist.add(item.key)) {
                              _selectedWishlist.remove(item.key);
                            }
                          }),
                        ),
                      _wishlistThumbnail(item.value),
                    ],
                  ),
                  title: Text(
                    item.value.name,
                    style: const TextStyle(color: VisualScanStyle.text),
                  ),
                  subtitle: Text(
                    item.value.category,
                    style: const TextStyle(color: VisualScanStyle.muted),
                  ),
                  trailing: _selectingWishlist
                      ? null
                      : const Icon(
                          Icons.chevron_right,
                          color: VisualScanStyle.muted,
                        ),
                  onTap: () => _selectingWishlist
                      ? setState(() {
                          if (!_selectedWishlist.add(item.key)) {
                            _selectedWishlist.remove(item.key);
                          }
                        })
                      : _openWishlistPlace(item.value),
                ),
                if (!_selectingWishlist)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                    child: SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: () => _editWishlistNote(item.value),
                        icon: const Icon(Icons.edit_note_outlined, size: 18),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: VisualScanStyle.amber,
                          side: const BorderSide(color: VisualScanStyle.border),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 12,
                          ),
                          alignment: Alignment.centerLeft,
                        ),
                        label: Text(
                          _wishlistNotes[item.value.xid]?.isNotEmpty == true
                              ? _wishlistNotes[item.value.xid]!
                              : context.l10n.scanWishlistAddNote,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 8),
        ],
      ],
    );
  }
}

BoxDecoration _scanPanel() => BoxDecoration(
  color: VisualScanStyle.surface,
  border: Border.all(color: VisualScanStyle.border),
  borderRadius: BorderRadius.circular(17),
);
