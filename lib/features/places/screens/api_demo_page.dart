import 'package:smart_travel_planner/l10n/localized_labels.dart';
import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';

import 'package:smart_travel_planner/core/theme/app_colors.dart';
import 'package:smart_travel_planner/core/theme/app_decorations.dart';
import 'package:smart_travel_planner/shared/data/malaysia_states.dart';
import 'package:smart_travel_planner/shared/models/attraction.dart';
import 'package:smart_travel_planner/shared/models/route_info.dart';
import 'package:smart_travel_planner/features/itinerary/services/itinerary_service.dart';
import 'package:smart_travel_planner/shared/services/location_service.dart';
import 'package:smart_travel_planner/shared/services/google_route_service.dart';
import 'package:smart_travel_planner/features/places/services/places_service.dart';
import 'attraction_detail_page.dart';
import 'attraction_list_screen.dart';
import 'package:smart_travel_planner/shared/utils/demo_feedback.dart';
import 'package:smart_travel_planner/features/navigation/screens/map_screen.dart';

class ApiDemoPage extends StatefulWidget {
  const ApiDemoPage({super.key, this.isVisible = true, this.discoveryHeader});

  final bool isVisible;
  final Widget? discoveryHeader;

  @override
  State<ApiDemoPage> createState() => _ApiDemoPageState();
}

class _ApiDemoPageState extends State<ApiDemoPage> {
  final _placesService = PlacesService();
  final _routeService = GoogleRouteService();
  final _itineraryService = ItineraryService();
  final _locationService = LocationService();

  var _loading = true;
  int _loadGeneration = 0;
  PlacesPage? _page;
  bool _loadingMore = false;
  int _lastOffset = 0;
  final Set<String> _sources = {};
  final List<Map<String, dynamic>> _attributions = [];
  var _loadingRoute = false;
  var _selectedView = 0;
  String? _error;
  List<Attraction> _attractions = [];
  List<Attraction> _selectedStops = [];
  List<Attraction> _suggestedHighlights = [];
  RouteInfo? _route;

  // Search and Category filtering states
  String _searchQuery = '';
  String _selectedCategory = 'All';
  final _searchController = TextEditingController();

  static const _categories = [
    'All',
    '🏛️ Sights',
    '🍔 Food',
    '☕ Cafes',
    '🛍️ Shops',
    '🌳 Nature',
  ];

  late final PageController _pageController;

  @override
  void initState() {
    super.initState();
    _pageController = PageController(initialPage: _selectedView);
    _locationService.addListener(_onLocationChanged);
    _loadAttractions();
  }

  @override
  void dispose() {
    _locationService.removeListener(_onLocationChanged);
    _searchController.dispose();
    _pageController.dispose();
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
        latitude: loc.latitude,
        longitude: loc.longitude,
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
        _sources.add(page.source);
        _attributions.addAll(page.attributions);
        _attractions = attractions;
        _suggestedHighlights = itinerary;
        // Keep user saved places that are in the current area, or start fresh
        _selectedStops = _selectedStops
            .where((s) => attractions.any((a) => a.xid == s.xid))
            .toList();
      });

      if (_selectedStops.length >= 2) {
        await _loadRoute(_selectedStops);
      } else {
        if (mounted) setState(() => _route = null);
      }
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

  void _autoPickHighlights() {
    if (_suggestedHighlights.isEmpty) return;
    final topStops = _suggestedHighlights.take(5).toList();
    setState(() => _selectedStops = topStops);
    _loadRoute(topStops);
    _showSnack('Saved ${topStops.length} top highlights to your list!');
  }

  Future<void> _loadRoute(List<Attraction> stops) async {
    if (stops.length < 2) {
      if (mounted) setState(() => _route = null);
      return;
    }
    setState(() => _loadingRoute = true);

    try {
      final route = await _routeService.fetchRoute(stops.take(5).toList());
      if (mounted) setState(() => _route = route);
    } finally {
      if (mounted) setState(() => _loadingRoute = false);
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
    await _loadRoute(updated);
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
    return _attractions.where((attraction) {
      final matchesSearch = attraction.name.toLowerCase().contains(
        _searchQuery.toLowerCase(),
      );
      if (!matchesSearch) return false;

      if (_selectedCategory == 'All') return true;

      final kind = attraction.category.toLowerCase();
      final cat = _selectedCategory.toLowerCase();

      if (cat.contains('sight') || cat.contains('culture')) {
        return kind.contains('religion') ||
            kind.contains('cultural') ||
            kind.contains('historic') ||
            kind.contains('architecture') ||
            kind.contains('landmark') ||
            kind.contains('monument') ||
            kind.contains('sights') ||
            kind.contains('temple') ||
            kind.contains('museum');
      }
      if (cat.contains('food') ||
          cat.contains('dining') ||
          cat.contains('restaurant')) {
        return kind.contains('food') ||
            kind.contains('cafe') ||
            kind.contains('restaurant') ||
            kind.contains('dish') ||
            kind.contains('eat') ||
            kind.contains('hawker') ||
            kind.contains('dining') ||
            kind.contains('bakery');
      }
      if (cat.contains('cafe') || cat.contains('coffee')) {
        return kind.contains('cafe') || kind.contains('coffee');
      }
      if (cat.contains('shop') || cat.contains('market')) {
        return kind.contains('shop') ||
            kind.contains('mall') ||
            kind.contains('market') ||
            kind.contains('store') ||
            kind.contains('shopping');
      }
      if (cat.contains('nature') || cat.contains('park')) {
        return kind.contains('natural') ||
            kind.contains('park') ||
            kind.contains('nature') ||
            kind.contains('garden') ||
            kind.contains('forest') ||
            kind.contains('beach') ||
            kind.contains('outdoor');
      }
      return true;
    }).toList();
  }

  void _showLocationSelectorSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => const LocationSelectorSheet(),
    );
  }

  void _onTabTapped(int index) {
    if (_selectedView == index) return;
    setState(() => _selectedView = index);
    if (_pageController.hasClients) {
      _pageController.animateToPage(
        index,
        duration: const Duration(milliseconds: 280),
        curve: Curves.easeInOutCubic,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _buildTopNavigationBar(),
        Expanded(child: _buildBody()),
      ],
    );
  }

  Widget _buildTopNavigationBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 10),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final tabWidth = (constraints.maxWidth - 8) / 3;
          return Container(
            height: 48,
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: AppColors.sky.withValues(alpha: 0.6),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: AppColors.primary.withValues(alpha: 0.12),
              ),
            ),
            child: Stack(
              children: [
                // Animated sliding indicator pill
                AnimatedPositioned(
                  duration: const Duration(milliseconds: 260),
                  curve: Curves.easeInOutCubic,
                  left: _selectedView * tabWidth,
                  top: 0,
                  bottom: 0,
                  width: tabWidth,
                  child: Container(
                    decoration: BoxDecoration(
                      color: AppColors.primary,
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.primary.withValues(alpha: 0.3),
                          blurRadius: 8,
                          offset: const Offset(0, 3),
                        ),
                      ],
                    ),
                  ),
                ),
                // Tabs row
                Row(
                  children: [
                    _buildTopTabItem(
                      index: 0,
                      label: context.l10n.attractions,
                      icon: Icons.explore_rounded,
                    ),
                    _buildTopTabItem(
                      index: 1,
                      label: context.l10n.mapView,
                      icon: Icons.map_rounded,
                    ),
                    _buildTopTabItem(
                      index: 2,
                      label: context.l10n.saved,
                      icon: Icons.bookmark_rounded,
                      badgeCount: _selectedStops.length,
                    ),
                  ],
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildTopTabItem({
    required int index,
    required String label,
    required IconData icon,
    int? badgeCount,
  }) {
    final isSelected = _selectedView == index;
    return Expanded(
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
            demoHaptic();
            _onTabTapped(index);
          },
          borderRadius: BorderRadius.circular(12),
          child: Center(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  icon,
                  size: 18,
                  color: isSelected ? Colors.white : AppColors.muted,
                ),
                const SizedBox(width: 6),
                Flexible(
                  child: AnimatedDefaultTextStyle(
                    duration: const Duration(milliseconds: 200),
                    style: TextStyle(
                      fontFamily: Theme.of(
                        context,
                      ).textTheme.bodyMedium?.fontFamily,
                      fontSize: 13,
                      fontWeight: isSelected
                          ? FontWeight.w700
                          : FontWeight.w600,
                      color: isSelected ? Colors.white : AppColors.muted,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    child: Text(context.tr(label)),
                  ),
                ),
                if (badgeCount != null && badgeCount > 0) ...[
                  const SizedBox(width: 5),
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? Colors.white.withValues(alpha: 0.25)
                          : AppColors.primary.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      badgeCount.toString(),
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        color: isSelected ? Colors.white : AppColors.primary,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBody() {
    final filtered = _filteredAttractions;

    return PageView(
      controller: _pageController,
      physics: const NeverScrollableScrollPhysics(),
      children: [
        _KeepAlivePage(child: _buildAttractionsView(filtered)),
        _KeepAlivePage(child: _buildMapView(filtered)),
        _KeepAlivePage(child: _buildSavedView()),
      ],
    );
  }

  Widget _buildMapView(List<Attraction> filtered) {
    return Stack(
      children: [
        Positioned.fill(
          child: MapScreen(
            isVisible: widget.isVisible && _selectedView == 1,
            attractions: filtered,
            selectedStops: _selectedStops,
            route: _route,
            center: _locationService.currentLocation,
            onAttractionTap: _openDetails,
            onToggleStop: _toggleStop,
          ),
        ),
        Positioned(
          top: 12,
          left: 20,
          right: 20,
          child: _buildLocationSelector(),
        ),
      ],
    );
  }

  Widget _buildSavedView() {
    return _SavedPlacesView(
      stops: _selectedStops,
      route: _route,
      loadingRoute: _loadingRoute,
      onStopTap: _openDetails,
      onToggleStop: _toggleStop,
      onViewOnMap: () => _onTabTapped(1),
      onExploreMore: () => _onTabTapped(0),
      onAutoPickHighlights: _autoPickHighlights,
    );
  }

  Widget _buildAttractionsView(List<Attraction> filtered) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null) {
      return _ErrorState(message: _error!, onRetry: _loadAttractions);
    }

    return AttractionListScreen(
      header: Column(
        children: [
          if (widget.discoveryHeader != null) widget.discoveryHeader!,
          _buildLocationSelector(),
          const SizedBox(height: 10),
          _buildSearchBar(),
          const SizedBox(height: 10),
          _buildCategoryChips(),
          const SizedBox(height: 12),
        ],
      ),
      attractions: filtered,
      selectedStops: _selectedStops,
      highlights: _suggestedHighlights,
      hasMore: _page?.hasMore == true,
      loadingMore: _loadingMore,
      onLoadMore: () => _loadAttractions(append: true),
      attributions: _attributions,
      currentAreaName: _locationService.currentAreaName,
      selectedCategory: _selectedCategory,
      searchQuery: _searchQuery,
      onClearFilters: () {
        setState(() {
          _searchQuery = '';
          _searchController.clear();
          _selectedCategory = 'All';
        });
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
                color: Colors.white,
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
                        Row(
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
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 1.5,
                              ),
                              decoration: BoxDecoration(
                                color: AppColors.primary.withValues(
                                  alpha: 0.08,
                                ),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                context.l10n.text5KmRadius,
                                style: TextStyle(
                                  color: AppColors.primary,
                                  fontSize: 9.5,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 2),
                        Text(
                          _locationService.currentAreaName,
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
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: _searchQuery.isNotEmpty
              ? AppColors.primary
              : const Color(0xFFE2E8F0),
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
        onChanged: (val) => setState(() => _searchQuery = val),
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
        scrollDirection: Axis.horizontal,
        clipBehavior: Clip.none,
        itemCount: _categories.length,
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final cat = _categories[index];
          final active = _selectedCategory == cat;
          return Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: () {
                demoHaptic();
                setState(() => _selectedCategory = cat);
              },
              borderRadius: BorderRadius.circular(20),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: active ? AppColors.primary : Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: active ? AppColors.primary : const Color(0xFFE2E8F0),
                    width: 1.2,
                  ),
                  boxShadow: active
                      ? [
                          BoxShadow(
                            color: AppColors.primary.withValues(alpha: 0.28),
                            blurRadius: 8,
                            offset: const Offset(0, 3),
                          ),
                        ]
                      : [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.02),
                            blurRadius: 4,
                            offset: const Offset(0, 1),
                          ),
                        ],
                ),
                child: Center(
                  child: Text(
                    context.tr(cat),
                    style: TextStyle(
                      color: active ? Colors.white : AppColors.ink,
                      fontWeight: active ? FontWeight.w800 : FontWeight.w600,
                      fontSize: 12.5,
                    ),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _KeepAlivePage extends StatefulWidget {
  const _KeepAlivePage({required this.child});
  final Widget child;

  @override
  State<_KeepAlivePage> createState() => _KeepAlivePageState();
}

class _KeepAlivePageState extends State<_KeepAlivePage>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return widget.child;
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
        color: Colors.white,
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

class _SavedPlacesView extends StatelessWidget {
  const _SavedPlacesView({
    required this.stops,
    required this.route,
    required this.loadingRoute,
    required this.onStopTap,
    required this.onToggleStop,
    required this.onViewOnMap,
    required this.onExploreMore,
    required this.onAutoPickHighlights,
  });

  final List<Attraction> stops;
  final RouteInfo? route;
  final bool loadingRoute;
  final ValueChanged<Attraction> onStopTap;
  final ValueChanged<Attraction> onToggleStop;
  final VoidCallback onViewOnMap;
  final VoidCallback onExploreMore;
  final VoidCallback onAutoPickHighlights;

  @override
  Widget build(BuildContext context) {
    if (stops.isEmpty) {
      return Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.bookmark_outline_rounded,
                  size: 40,
                  color: AppColors.primary,
                ),
              ),
              const SizedBox(height: 18),
              Text(
                context.l10n.noSavedPlacesYet,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                  color: AppColors.ink,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                context.l10n
                    .browseAttractionsInValueAndTapSaveToBuildYourPersonalizedTravelWishlist(
                      (LocationService().currentAreaName).toString(),
                    ),
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 13,
                  color: AppColors.muted,
                  height: 1.45,
                ),
              ),
              const SizedBox(height: 22),
              FilledButton.icon(
                onPressed: onExploreMore,
                icon: const Icon(Icons.travel_explore, size: 18),
                label: Text(context.l10n.browseAttractions),
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 13,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
              ),
              const SizedBox(height: 10),
              TextButton.icon(
                onPressed: onAutoPickHighlights,
                icon: const Icon(Icons.auto_awesome, size: 16),
                label: Text(context.l10n.autoSaveTop5Highlights),
                style: TextButton.styleFrom(
                  foregroundColor: AppColors.primary,
                  textStyle: const TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
            ],
          ),
        ),
      );
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 28),
      children: [
        // Hero Header Card
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [AppColors.primary, Color(0xFF1E40AF)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(18),
            boxShadow: [
              BoxShadow(
                color: AppColors.primary.withValues(alpha: 0.25),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.18),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(
                      Icons.bookmark_rounded,
                      color: Colors.white,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          context.l10n.yourSavedPlaces,
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w900,
                            fontSize: 17,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          context.l10n.valueValueSavedInValue(
                            (stops.length).toString(),
                            (stops.length == 1 ? 'place' : 'places').toString(),
                            (LocationService().currentAreaName).toString(),
                          ),
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.85),
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              // Action Buttons Row
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: onViewOnMap,
                      icon: const Icon(Icons.map_outlined, size: 16),
                      label: Text(context.l10n.viewOnMap),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.white,
                        side: BorderSide(
                          color: Colors.white.withValues(alpha: 0.5),
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: onExploreMore,
                      icon: const Icon(Icons.add, size: 16),
                      label: Text(context.l10n.addMore),
                      style: FilledButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: AppColors.primary,
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              if (stops.length >= 2) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 7,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.route_outlined,
                        size: 14,
                        color: Colors.white,
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          loadingRoute
                              ? context.l10n.calculatingRouteEstimate
                              : context.l10n.routeEstValueKmValueMinDriving(
                                  (route?.distanceKm.toStringAsFixed(1) ??
                                          '0.0')
                                      .toString(),
                                  (route?.durationMinutes.round() ?? 0)
                                      .toString(),
                                ),
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
              ],
            ],
          ),
        ),
        const SizedBox(height: 16),

        // Section Title
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              context.l10n.savedAttractions,
              style: TextStyle(
                fontWeight: FontWeight.w900,
                color: AppColors.ink,
                fontSize: 15,
              ),
            ),
            Text(
              context.l10n.valueItems((stops.length).toString()),
              style: const TextStyle(
                color: AppColors.muted,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),

        // List of Cards
        ...stops.map((attraction) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: ModernAttractionCard(
              attraction: attraction,
              selected: true,
              onTap: () => onStopTap(attraction),
              onToggle: () => onToggleStop(attraction),
            ),
          );
        }),

        const SizedBox(height: 10),
        const _SavedTipsCard(),
      ],
    );
  }
}

class _SavedTipsCard extends StatelessWidget {
  const _SavedTipsCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.lightbulb_outline, size: 18, color: AppColors.primary),
              SizedBox(width: 6),
              Text(
                context.l10n.smartItineraryScheduling,
                style: TextStyle(
                  fontWeight: FontWeight.w900,
                  fontSize: 13.5,
                  color: AppColors.ink,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            context
                .l10n
                .savedPlacesCanBeViewedOnTheMapTabToSeeOptimalDrivingPathsOrVisitThePlanTabToAutomaticallyS,
            style: TextStyle(fontSize: 12, color: AppColors.muted, height: 1.4),
          ),
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
