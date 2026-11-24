import 'dart:async';
import 'package:smart_travel_planner/l10n/localized_labels.dart';
import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';

import 'package:smart_travel_planner/core/theme/app_colors.dart';
import 'package:smart_travel_planner/features/home/models/spotlight_destination.dart';
import 'package:smart_travel_planner/features/home/services/destination_spotlight_controller.dart';
import 'package:smart_travel_planner/features/home/widgets/destination_spotlight_card.dart';
import 'package:smart_travel_planner/features/home/widgets/destination_spotlight_picker_sheet.dart';
import 'package:smart_travel_planner/shared/data/malaysia_states.dart';
import 'package:smart_travel_planner/shared/models/attraction.dart';
import 'package:smart_travel_planner/features/itinerary/services/itinerary_service.dart';
import 'package:smart_travel_planner/shared/services/location_service.dart';
import 'package:smart_travel_planner/features/places/services/places_service.dart';
import 'package:smart_travel_planner/features/places/services/place_wishlist_store.dart';
import 'package:smart_travel_planner/features/auth/services/auth_service.dart';
import 'attraction_detail_page.dart';
import 'attraction_list_screen.dart';
import 'package:smart_travel_planner/shared/utils/demo_feedback.dart';

class ApiDemoPage extends StatefulWidget {
  const ApiDemoPage({
    super.key,
    this.isVisible = true,
    this.discoveryHeader,
    this.onPlacesLoaded,
    this.spotlightStore,
    this.onSpotlightSelected,
  });

  final bool isVisible;
  final Widget? discoveryHeader;
  final ValueChanged<List<Attraction>>? onPlacesLoaded;
  final DestinationSpotlightStore? spotlightStore;
  final ValueChanged<List<SpotlightDestination>>? onSpotlightSelected;

  @override
  State<ApiDemoPage> createState() => _ApiDemoPageState();
}

class _ApiDemoPageState extends State<ApiDemoPage> {
  final _placesService = PlacesService(includeCuratedFallback: true);
  final _itineraryService = ItineraryService();
  final _locationService = LocationService();

  var _loading = true;
  int _loadGeneration = 0;
  PlacesPage? _page;
  bool _loadingMore = false;
  int _lastOffset = 0;
  final Set<String> _sources = {};
  final List<Map<String, dynamic>> _attributions = [];
  String? _error;
  List<Attraction> _attractions = [];
  List<Attraction> _selectedStops = [];
  List<Attraction> _suggestedHighlights = [];

  // Search and Category filtering states
  String _searchQuery = '';
  String _selectedCategory = 'All';
  final _searchController = TextEditingController();

  static const _categories = [
    'All',
    'Sights',
    'Food',
    'Cafes',
    'Shops',
    'Nature',
  ];

  static const _categoryIcons = <String, IconData>{
    'All': Icons.explore_outlined,
    'Sights': Icons.account_balance_outlined,
    'Food': Icons.restaurant_outlined,
    'Cafes': Icons.local_cafe_outlined,
    'Shops': Icons.shopping_bag_outlined,
    'Nature': Icons.park_outlined,
  };

  Timer? _searchDebounce;

  @override
  void initState() {
    super.initState();
    _locationService.addListener(_onLocationChanged);
    AuthService().addListener(_onLocationChanged);
    _loadSavedStops();
    _loadAttractions();
  }

  Future<void> _loadSavedStops() async {
    try {
      final userId = AuthService().currentUser?.uid ?? 'guest';
      final saved = await PlaceWishlistStore(userId).load();
      if (mounted && saved.isNotEmpty) {
        setState(() {
          final existing = _selectedStops.map((s) => s.xid).toSet();
          for (final item in saved) {
            if (!existing.contains(item.xid) && _selectedStops.length < 10) {
              _selectedStops.add(item);
            }
          }
        });
      }
    } catch (_) {}
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _locationService.removeListener(_onLocationChanged);
    AuthService().removeListener(_onLocationChanged);
    _searchController.dispose();
    super.dispose();
  }

  void _onLocationChanged() {
    if (mounted) {
      _loadAttractions();
    }
  }

  Future<void> _loadAttractions({
    bool append = false,
    bool retry = false,
  }) async {
    final generation = ++_loadGeneration;
    setState(() {
      _loading = !append;
      _loadingMore = append;
      _error = null;
      if (!append) {
        _page = null;
        _attractions = [];
        _sources.clear();
        _attributions.clear();
      }
    });

    try {
      final loc = _locationService.currentLocation;
      final offset = retry
          ? _lastOffset
          : append
          ? (_page?.nextOffset ?? 0)
          : 0;
      _lastOffset = offset;
      final page = await _placesService.fetchPage(
        offset: offset,
        state: _destinationState,
        radiusMeters: null,
        latitude: loc.latitude,
        longitude: loc.longitude,
        query: _searchQuery,
        category: _selectedCategory,
        shouldContinue: () => mounted && generation == _loadGeneration,
      );

      if (!mounted || generation != _loadGeneration) return;

      final byId = {
        if (append)
          for (final item in _attractions) item.xid: item,
        for (final item in page.items) item.xid: item,
      };
      final attractions = byId.values.toList();
      final itinerary = _itineraryService.generateSmartItinerary(
        attractions: attractions,
        startPoint: loc,
      );

      setState(() {
        _page = page;
        if (page.items.isEmpty &&
            page.failure != PlacesFailure.none &&
            page.failure != PlacesFailure.emptyCatalog) {
          _error = page.notice;
        }
        _sources.add(page.source);
        _attributions.addAll(page.attributions);
        _attractions = attractions;
        _suggestedHighlights = itinerary;
        // Keep user saved places that are in the current area, or start fresh
        _selectedStops = _selectedStops
            .where((s) => attractions.any((a) => a.xid == s.xid))
            .toList();
      });

      widget.onPlacesLoaded?.call(attractions);
    } catch (error) {
      if (mounted && generation == _loadGeneration) {
        setState(
          () => _error = 'Unable to load attractions. Please try again.',
        );
      }
    } finally {
      if (mounted && generation == _loadGeneration) {
        setState(() {
          _loading = false;
          _loadingMore = false;
        });
      }
    }
  }

  Future<void> _toggleStop(Attraction attraction) async {
    final updated = [..._selectedStops];
    final exists = updated.any((item) => item.xid == attraction.xid);

    if (exists) {
      updated.removeWhere((item) => item.xid == attraction.xid);
      _showSnack('Removed "${attraction.name}" from Saved.');
    } else if (updated.length < 10) {
      updated.add(attraction);
      _showSnack('Saved "${attraction.name}" to your list.');
    } else {
      _showSnack('Saved list can hold up to 10 attractions.');
      return;
    }

    setState(() => _selectedStops = updated);
    final userId = AuthService().currentUser?.uid ?? 'guest';
    try {
      await PlaceWishlistStore(userId).toggle(attraction);
    } catch (_) {}
  }

  Future<void> _openDetails(Attraction attraction) async {
    if (!mounted) return;
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => AttractionDetailPage(
          attraction: attraction,
          isSaved: _selectedStops.any((s) => s.xid == attraction.xid),
          onToggleSaved: (place) {
            final canToggle =
                _selectedStops.length < 10 ||
                _selectedStops.any((s) => s.xid == place.xid);
            _toggleStop(place);
            return canToggle;
          },
        ),
      ),
    );
  }

  void _showSnack(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(context.tr(message))));
  }

  // Filtered attractions based on search and category
  List<Attraction> get _filteredAttractions {
    return _attractions;
  }

  String get _destinationState => _locationService.destinationState;

  Future<void> _showLocationSelectorSheet() async {
    final selected = await showModalBottomSheet<MalaysiaStateData>(
      context: context,
      builder: (context) => SafeArea(
        child: ListView.builder(
          itemCount: malaysiaStatesData.length + 1,
          itemBuilder: (context, index) {
            if (index == 0) {
              return ListTile(title: Text(context.l10n.selectState));
            }
            final state = malaysiaStatesData[index - 1];
            final isSelected = state.name == _destinationState;
            return ListTile(
              title: Text(state.name),
              selected: isSelected,
              trailing: isSelected ? const Icon(Icons.check) : null,
              onTap: () => Navigator.pop(context, state),
            );
          },
        ),
      ),
    );
    if (!mounted || selected == null) return;
    final reference = selected.browseCenter;
    _searchDebounce?.cancel();
    _searchQuery = '';
    _searchController.clear();
    _selectedCategory = 'All';
    _locationService.updateLocation(
      LatLng(reference.latitude, reference.longitude),
      selected.name,
      state: selected.name,
    );
  }

  Future<void> _openSpotlightFromFloatingCard() async {
    final selected = await showDestinationSpotlightPicker(context);
    if (!mounted || selected == null || selected.isEmpty) return;
    widget.onSpotlightSelected?.call(selected);
  }

  @override
  Widget build(BuildContext context) {
    final feed = _buildAttractionsView(_filteredAttractions);
    final store = widget.spotlightStore;
    if (store == null || widget.onSpotlightSelected == null) {
      return feed;
    }

    return Stack(
      children: [
        feed,
        ListenableBuilder(
          listenable: store,
          builder: (context, _) {
            if (!store.isLoaded || store.isDismissed) {
              return const SizedBox.shrink();
            }
            final maxCardHeight = MediaQuery.sizeOf(context).height * 0.72;
            return Positioned.fill(
              child: Stack(
                children: [
                  Positioned.fill(
                    child: GestureDetector(
                      key: const ValueKey('spotlight-backdrop'),
                      behavior: HitTestBehavior.opaque,
                      onTap: () => store.setDismissed(true),
                      child: ColoredBox(
                        color: Colors.black.withValues(alpha: 0.54),
                      ),
                    ),
                  ),
                  Center(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 24,
                        vertical: 20,
                      ),
                      child: ConstrainedBox(
                        constraints: BoxConstraints(
                          maxWidth: 340,
                          maxHeight: maxCardHeight,
                        ),
                        child: DestinationSpotlightCard(
                          floating: true,
                          dismissed: false,
                          featured: store.featuredDestination,
                          onChooseDestinations: _openSpotlightFromFloatingCard,
                          onDismiss: () => store.setDismissed(true),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ],
    );
  }

  Widget _buildAttractionsView(List<Attraction> filtered) {
    if (_loading || _error != null) {
      return ListView(
        key: const PageStorageKey('explore-attractions-list'),
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 32),
        children: [
          if (widget.discoveryHeader != null) widget.discoveryHeader!,
          _buildLocationSelector(),
          const SizedBox(height: 12),
          _buildSearchBar(),
          const SizedBox(height: 12),
          _buildCategoryChips(),
          const SizedBox(height: 16),
          if (_loading)
            const Padding(
              padding: EdgeInsets.all(24),
              child: Center(child: CircularProgressIndicator()),
            )
          else
            _ErrorState(message: _error!, onRetry: _loadAttractions),
        ],
      );
    }

    return AttractionListScreen(
      header: Column(
        children: [
          if (widget.discoveryHeader != null) widget.discoveryHeader!,
          if (_page?.source == 'Saved catalog')
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Text(
                'Saved catalog · ${_page?.savedAt?.toLocal().toString().split('.').first ?? 'update time unavailable'}',
                style: const TextStyle(color: AppColors.nightMuted),
              ),
            ),
          if (_page != null &&
              _page!.failure != PlacesFailure.none &&
              _page!.failure != PlacesFailure.emptyCatalog)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Text(
                _page!.notice,
                style: const TextStyle(color: AppColors.nightMuted),
              ),
            ),
          _buildLocationSelector(),
          const SizedBox(height: 12),
          _buildSearchBar(),
          const SizedBox(height: 12),
          _buildCategoryChips(),
          const SizedBox(height: 16),
        ],
      ),
      attractions: filtered,
      selectedStops: _selectedStops,
      highlights: _suggestedHighlights,
      hasMore: _page?.hasMore == true,
      loadingMore: _loadingMore,
      onLoadMore: () => _loadAttractions(append: true),
      attributions: _attributions,
      currentAreaName: _destinationState,
      selectedCategory: _selectedCategory,
      searchQuery: _searchQuery,
      onClearFilters: () {
        setState(() {
          _searchQuery = '';
          _searchController.clear();
          _selectedCategory = 'All';
        });
        _searchDebounce?.cancel();
        _loadAttractions();
      },
      onAttractionTap: _openDetails,
      onToggleStop: _toggleStop,
    );
  }

  Widget _buildLocationSelector() {
    return ListenableBuilder(
      listenable: _locationService,
      builder: (context, _) {
        return Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: () {
              demoHaptic();
              _showLocationSelectorSheet();
            },
            borderRadius: BorderRadius.circular(16),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: AppColors.nightSurface,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: AppColors.primary.withValues(alpha: 0.16),
                  width: 1.2,
                ),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.primary.withValues(alpha: 0.05),
                    blurRadius: 10,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          AppColors.primary,
                          AppColors.primary.withValues(alpha: 0.8),
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      _locationService.isUsingRealGps
                          ? Icons.my_location_rounded
                          : Icons.location_on_rounded,
                      color: Colors.white,
                      size: 19,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          context.l10n.currentDestination,
                          style: TextStyle(
                            color: AppColors.muted,
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.5,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          _destinationState,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: AppColors.ink,
                            fontSize: 14.5,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.sky,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          context.l10n.change,
                          style: TextStyle(
                            color: AppColors.primary,
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        SizedBox(width: 2),
                        Icon(
                          Icons.keyboard_arrow_down_rounded,
                          size: 16,
                          color: AppColors.primary,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildSearchBar() {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.nightSurface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: _searchQuery.isNotEmpty
              ? AppColors.primary
              : AppColors.nightLine,
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: TextField(
        controller: _searchController,
        onChanged: (val) {
          setState(() => _searchQuery = val);
          _searchDebounce?.cancel();
          _searchDebounce = Timer(
            const Duration(milliseconds: 300),
            _loadAttractions,
          );
        },
        style: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w600,
          color: AppColors.ink,
        ),
        decoration: InputDecoration(
          hintText: context.l10n.searchAttractionsFoodCulture,
          hintStyle: const TextStyle(
            fontSize: 13.5,
            fontWeight: FontWeight.w500,
            color: Color(0xFF94A3B8),
          ),
          prefixIcon: const Icon(
            Icons.search_rounded,
            size: 20,
            color: AppColors.primary,
          ),
          suffixIcon: _searchQuery.isNotEmpty
              ? IconButton(
                  icon: const Icon(Icons.close_rounded, size: 18),
                  onPressed: () {
                    _searchController.clear();
                    setState(() => _searchQuery = '');
                    _searchDebounce?.cancel();
                    _loadAttractions();
                  },
                )
              : null,
          isDense: true,
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 14,
            vertical: 12,
          ),
        ),
      ),
    );
  }

  Widget _buildCategoryChips() {
    return SizedBox(
      height: 38,
      child: ListView.separated(
        key: ValueKey('explore-categories-$_destinationState'),
        scrollDirection: Axis.horizontal,
        itemCount: _categories.length,
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final cat = _categories[index];
          final active = _selectedCategory == cat;
          final icon = _categoryIcons[cat] ?? Icons.label_outline_rounded;
          return Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: () {
                demoHaptic();
                setState(() => _selectedCategory = cat);
                _loadAttractions();
              },
              borderRadius: BorderRadius.circular(12),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: active ? AppColors.primary : AppColors.nightSurface,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: active
                        ? AppColors.primary
                        : AppColors.nightLine.withValues(alpha: 0.7),
                    width: 1.0,
                  ),
                  boxShadow: active
                      ? [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.16),
                            blurRadius: 4,
                            offset: const Offset(0, 1.5),
                          ),
                        ]
                      : null,
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      icon,
                      size: 16,
                      color: active
                          ? AppColors.onNightAccent
                          : AppColors.nightMuted,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      context.tr(cat),
                      style: TextStyle(
                        color: active ? AppColors.onNightAccent : AppColors.ink,
                        fontWeight: active ? FontWeight.w700 : FontWeight.w600,
                        fontSize: 13,
                        letterSpacing: -0.1,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class LocationSelectorSheet extends StatefulWidget {
  const LocationSelectorSheet({super.key});

  @override
  State<LocationSelectorSheet> createState() => _LocationSelectorSheetState();
}

class _LocationSelectorSheetState extends State<LocationSelectorSheet> {
  final _locationService = LocationService();
  int _selectedTab = 0; // 0: Browse States, 1: Simulate GPS

  MalaysiaStateData? _tempSelectedState = malaysiaStatesData.first;
  CityArea? _tempSelectedArea = malaysiaStatesData.first.areas.first;

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Container(
      decoration: const BoxDecoration(
        color: AppColors.nightSurface,
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(28),
          topRight: Radius.circular(28),
        ),
      ),
      padding: EdgeInsets.fromLTRB(24, 20, 24, 24 + bottomInset),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Drag handle
          Center(
            child: Container(
              width: 48,
              height: 5,
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          ),
          const SizedBox(height: 20),
          Text(
            context.l10n.exploreNewLocation,
            style: TextStyle(
              color: AppColors.ink,
              fontSize: 22,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            context.l10n.selectADestinationInMalaysiaOrSimulateGpsPositions,
            style: TextStyle(color: AppColors.muted, fontSize: 13),
          ),
          const SizedBox(height: 18),

          // Tabs
          Row(
            children: [
              Expanded(
                child: ChoiceChip(
                  label: Center(
                    child: Text(
                      context.l10n.browseStates,
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                  selected: _selectedTab == 0,
                  onSelected: (val) => setState(() => _selectedTab = 0),
                  selectedColor: AppColors.sky,
                  labelStyle: TextStyle(
                    color: _selectedTab == 0
                        ? AppColors.primary
                        : AppColors.muted,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: ChoiceChip(
                  label: Center(
                    child: Text(
                      context.l10n.simulateGps,
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                  selected: _selectedTab == 1,
                  onSelected: (val) => setState(() => _selectedTab = 1),
                  selectedColor: AppColors.sky,
                  labelStyle: TextStyle(
                    color: _selectedTab == 1
                        ? AppColors.primary
                        : AppColors.muted,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // Tab content
          if (_selectedTab == 0) ...[
            // State dropdown
            Text(
              context.l10n.chooseState,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 13,
                color: AppColors.muted,
              ),
            ),
            const SizedBox(height: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14),
              decoration: BoxDecoration(
                border: Border.all(color: AppColors.line),
                borderRadius: BorderRadius.circular(14),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<MalaysiaStateData>(
                  value: _tempSelectedState,
                  isExpanded: true,
                  items: malaysiaStatesData.map((state) {
                    return DropdownMenuItem(
                      value: state,
                      child: Text(
                        state.name,
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                    );
                  }).toList(),
                  onChanged: (state) {
                    if (state != null) {
                      setState(() {
                        _tempSelectedState = state;
                        _tempSelectedArea = state.areas.first;
                      });
                    }
                  },
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Area/City dropdown
            Text(
              context.l10n.chooseAreaCity,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 13,
                color: AppColors.muted,
              ),
            ),
            const SizedBox(height: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14),
              decoration: BoxDecoration(
                border: Border.all(color: AppColors.line),
                borderRadius: BorderRadius.circular(14),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<CityArea>(
                  value: _tempSelectedArea,
                  isExpanded: true,
                  items:
                      _tempSelectedState?.areas.map((area) {
                        return DropdownMenuItem(
                          value: area,
                          child: Text(
                            area.name,
                            style: const TextStyle(fontWeight: FontWeight.w700),
                          ),
                        );
                      }).toList() ??
                      [],
                  onChanged: (area) {
                    if (area != null) {
                      setState(() {
                        _tempSelectedArea = area;
                      });
                    }
                  },
                ),
              ),
            ),
            const SizedBox(height: 24),

            // Confirm Button
            SizedBox(
              width: double.infinity,
              height: 52,
              child: FilledButton(
                onPressed: () {
                  if (_tempSelectedArea != null) {
                    _locationService.updateLocation(
                      LatLng(
                        _tempSelectedArea!.latitude,
                        _tempSelectedArea!.longitude,
                      ),
                      '${_tempSelectedArea!.name}, ${_tempSelectedState!.name}',
                      state: _tempSelectedState!.name,
                    );
                    Navigator.pop(context);
                  }
                },
                child: Text(context.l10n.searchInThisArea),
              ),
            ),
          ] else ...[
            // GPS Options list
            Text(
              context.l10n.mockDeviceCoordinatesInMalaysia,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 13,
                color: AppColors.muted,
              ),
            ),
            const SizedBox(height: 10),
            Column(
              children: LocationService.mockGpsOptions.map((opt) {
                return Padding(
                  padding: const EdgeInsets.only(bottom: 8.0),
                  child: ListTile(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                      side: const BorderSide(color: AppColors.line),
                    ),
                    leading: const CircleAvatar(
                      backgroundColor: AppColors.sky,
                      child: Icon(
                        Icons.my_location,
                        color: AppColors.primary,
                        size: 18,
                      ),
                    ),
                    title: Text(
                      opt.name,
                      style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 14,
                      ),
                    ),
                    subtitle: Text(
                      'Lat: ${opt.lat}, Lon: ${opt.lon}',
                      style: const TextStyle(fontSize: 11),
                    ),
                    trailing: const Icon(Icons.chevron_right, size: 18),
                    onTap: () {
                      _locationService.updateLocation(
                        LatLng(opt.lat, opt.lon),
                        opt.name,
                        isRealGps: true,
                      );
                      Navigator.pop(context);
                    },
                  ),
                );
              }).toList(),
            ),
          ],
        ],
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.cloud_off, color: AppColors.primary, size: 42),
            const SizedBox(height: 12),
            Text(context.tr(message), textAlign: TextAlign.center),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: onRetry,
              child: Text(context.l10n.tryAgain),
            ),
          ],
        ),
      ),
    );
  }
}
