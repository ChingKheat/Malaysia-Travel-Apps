import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';

import '../core/api_keys.dart';
import '../core/app_colors.dart';
import '../core/app_decorations.dart';
import '../data/malaysia_states.dart';
import '../models/attraction.dart';
import '../models/route_info.dart';
import '../services/itinerary_service.dart';
import '../services/location_service.dart';
import '../services/openroute_service.dart';
import '../services/opentripmap_service.dart';
import '../widgets/app_header.dart';
import 'attraction_detail_page.dart';
import 'attraction_list_screen.dart';
import 'map_screen.dart';

class ApiDemoPage extends StatefulWidget {
  const ApiDemoPage({super.key});

  @override
  State<ApiDemoPage> createState() => _ApiDemoPageState();
}

class _ApiDemoPageState extends State<ApiDemoPage> {
  final _attractionService = OpenTripMapService();
  final _routeService = OpenRouteService();
  final _itineraryService = ItineraryService();
  final _locationService = LocationService();

  var _loading = true;
  var _loadingRoute = false;
  var _selectedView = 0;
  String? _error;
  List<Attraction> _attractions = [];
  List<Attraction> _selectedStops = [];
  RouteInfo? _route;

  // Search and Category filtering states
  String _searchQuery = '';
  String _selectedCategory = 'All';
  final _searchController = TextEditingController();

  static const _categories = ['All', '🏛️ Sights', '🍔 Food', '🛍️ Shops', '🌳 Nature'];

  @override
  void initState() {
    super.initState();
    _locationService.addListener(_onLocationChanged);
    _loadAttractions();
  }

  @override
  void dispose() {
    _locationService.removeListener(_onLocationChanged);
    _searchController.dispose();
    super.dispose();
  }

  void _onLocationChanged() {
    if (mounted) {
      _loadAttractions();
    }
  }

  Future<void> _loadAttractions() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final loc = _locationService.currentLocation;
      final attractions = await _attractionService.fetchAttractionsNearKualaLumpur(
        latitude: loc.latitude,
        longitude: loc.longitude,
      );

      final itinerary = _itineraryService.generateSmartItinerary(
        attractions: attractions,
        startPoint: loc,
      );

      setState(() {
        _attractions = attractions;
        _selectedStops = itinerary;
      });

      await _loadRoute(itinerary);
    } catch (error) {
      setState(() => _error = error.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _loadRoute(List<Attraction> stops) async {
    if (stops.length < 2) return;
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
    } else if (updated.length < 5) {
      updated.add(attraction);
    } else {
      _showSnack('Demo route supports up to 5 stops.');
      return;
    }

    setState(() => _selectedStops = updated);
    await _loadRoute(updated);
  }

  Future<void> _openDetails(Attraction attraction) async {
    final detail = await _attractionService.fetchAttractionDetails(attraction);
    if (!mounted) return;
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => AttractionDetailPage(attraction: detail),
      ),
    );
  }

  void _showSnack(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  // Filtered attractions based on search and category
  List<Attraction> get _filteredAttractions {
    return _attractions.where((attraction) {
      final matchesSearch = attraction.name.toLowerCase().contains(_searchQuery.toLowerCase());
      if (!matchesSearch) return false;

      if (_selectedCategory == 'All') return true;
      
      final kind = attraction.category.toLowerCase();
      if (_selectedCategory == '🏛️ Sights') {
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
      if (_selectedCategory == '🍔 Food') {
        return kind.contains('food') ||
            kind.contains('cafe') ||
            kind.contains('restaurant') ||
            kind.contains('dish') ||
            kind.contains('eat');
      }
      if (_selectedCategory == '🛍️ Shops') {
        return kind.contains('shop') ||
            kind.contains('mall') ||
            kind.contains('market') ||
            kind.contains('store') ||
            kind.contains('shopping');
      }
      if (_selectedCategory == '🌳 Nature') {
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

  @override
  Widget build(BuildContext context) {
    final hasApiKeys = ApiKeys.hasOpenTripMapKey && ApiKeys.hasOpenRouteServiceKey;

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 10),
              child: Column(
                children: [
                  AppHeader(
                    title: 'Explore Malaysia',
                    subtitle: hasApiKeys
                        ? 'Search tourist locations dynamically'
                        : 'Sample fallback active until API keys are added',
                  ),
                  const SizedBox(height: 12),

                  // Location Display Selector Bar
                  ListenableBuilder(
                    listenable: _locationService,
                    builder: (context, _) {
                      return InkWell(
                        onTap: _showLocationSelectorSheet,
                        borderRadius: BorderRadius.circular(16),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                          decoration: cardDecoration().copyWith(
                            color: AppColors.sky,
                            border: Border.all(color: AppColors.primary.withValues(alpha: 0.15)),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                _locationService.isUsingRealGps
                                    ? Icons.my_location
                                    : Icons.location_on,
                                color: AppColors.primary,
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text(
                                      'Current Location Area',
                                      style: TextStyle(
                                        color: AppColors.muted,
                                        fontSize: 11,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      _locationService.currentAreaName,
                                      style: const TextStyle(
                                        color: AppColors.ink,
                                        fontSize: 14,
                                        fontWeight: FontWeight.w900,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(color: AppColors.line),
                                ),
                                child: const Text(
                                  'Change',
                                  style: TextStyle(
                                    color: AppColors.primary,
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 12),

                  // Search & Filter Box
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _searchController,
                          onChanged: (val) => setState(() => _searchQuery = val),
                          decoration: InputDecoration(
                            hintText: 'Search attractions...',
                            prefixIcon: const Icon(Icons.search, size: 20),
                            suffixIcon: _searchQuery.isNotEmpty
                                ? IconButton(
                                    icon: const Icon(Icons.clear, size: 18),
                                    onPressed: () {
                                      _searchController.clear();
                                      setState(() => _searchQuery = '');
                                    },
                                  )
                                : null,
                            isDense: true,
                            contentPadding: const EdgeInsets.symmetric(vertical: 12),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(14),
                              borderSide: const BorderSide(color: AppColors.line),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),

                  // Category Filter Chips
                  SizedBox(
                    height: 38,
                    child: ListView.builder(
                      scrollDirection: Axis.horizontal,
                      itemCount: _categories.length,
                      itemBuilder: (context, index) {
                        final cat = _categories[index];
                        final active = _selectedCategory == cat;
                        return Padding(
                          padding: const EdgeInsets.only(right: 8.0),
                          child: FilterChip(
                            selected: active,
                            label: Text(
                              cat,
                              style: TextStyle(
                                color: active ? Colors.white : AppColors.ink,
                                fontWeight: active ? FontWeight.bold : FontWeight.normal,
                              ),
                            ),
                            selectedColor: AppColors.primary,
                            checkmarkColor: Colors.white,
                            backgroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(20),
                              side: BorderSide(
                                color: active ? AppColors.primary : AppColors.line,
                              ),
                            ),
                            onSelected: (val) {
                              setState(() => _selectedCategory = cat);
                            },
                          ),
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 10),

                  // Views Toggle SegmentedButton
                  SegmentedButton<int>(
                    segments: const [
                      ButtonSegment(
                        value: 0,
                        icon: Icon(Icons.list_alt_outlined),
                        label: Text('List'),
                      ),
                      ButtonSegment(
                        value: 1,
                        icon: Icon(Icons.map_outlined),
                        label: Text('Map'),
                      ),
                      ButtonSegment(
                        value: 2,
                        icon: Icon(Icons.auto_awesome),
                        label: Text('Itinerary'),
                      ),
                    ],
                    selected: {_selectedView},
                    onSelectionChanged: (value) => setState(() => _selectedView = value.first),
                  ),
                ],
              ),
            ),
            Expanded(child: _buildBody()),
          ],
        ),
      ),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null) {
      return _ErrorState(message: _error!, onRetry: _loadAttractions);
    }

    final filtered = _filteredAttractions;

    if (_selectedView == 1) {
      return MapScreen(
        attractions: filtered,
        selectedStops: _selectedStops,
        route: _route,
        onAttractionTap: _openDetails,
        onToggleStop: _toggleStop,
      );
    }

    if (_selectedView == 2) {
      return _ItineraryView(
        stops: _selectedStops,
        route: _route,
        loadingRoute: _loadingRoute,
        onStopTap: _openDetails,
      );
    }

    return AttractionListScreen(
      attractions: filtered,
      selectedStops: _selectedStops,
      onAttractionTap: _openDetails,
      onToggleStop: _toggleStop,
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
          const Text(
            'Explore New Location',
            style: TextStyle(
              color: AppColors.ink,
              fontSize: 22,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'Select a destination in Malaysia or simulate GPS positions.',
            style: TextStyle(color: AppColors.muted, fontSize: 13),
          ),
          const SizedBox(height: 18),

          // Tabs
          Row(
            children: [
              Expanded(
                child: ChoiceChip(
                  label: const Center(child: Text('🗺️ Browse States', style: TextStyle(fontWeight: FontWeight.bold))),
                  selected: _selectedTab == 0,
                  onSelected: (val) => setState(() => _selectedTab = 0),
                  selectedColor: AppColors.sky,
                  labelStyle: TextStyle(color: _selectedTab == 0 ? AppColors.primary : AppColors.muted),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: ChoiceChip(
                  label: const Center(child: Text('📍 Simulate GPS', style: TextStyle(fontWeight: FontWeight.bold))),
                  selected: _selectedTab == 1,
                  onSelected: (val) => setState(() => _selectedTab = 1),
                  selectedColor: AppColors.sky,
                  labelStyle: TextStyle(color: _selectedTab == 1 ? AppColors.primary : AppColors.muted),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // Tab content
          if (_selectedTab == 0) ...[
            // State dropdown
            const Text('Choose State', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppColors.muted)),
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
                      child: Text(state.name, style: const TextStyle(fontWeight: FontWeight.w700)),
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
            const Text('Choose Area / City', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppColors.muted)),
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
                  items: _tempSelectedState?.areas.map((area) {
                    return DropdownMenuItem(
                      value: area,
                      child: Text(area.name, style: const TextStyle(fontWeight: FontWeight.w700)),
                    );
                  }).toList() ?? [],
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
                      LatLng(_tempSelectedArea!.latitude, _tempSelectedArea!.longitude),
                      '${_tempSelectedArea!.name}, ${_tempSelectedState!.name}',
                    );
                    Navigator.pop(context);
                  }
                },
                child: const Text('Search in this area'),
              ),
            ),
          ] else ...[
            // GPS Options list
            const Text('Mock Device coordinates in Malaysia', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppColors.muted)),
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
                      child: Icon(Icons.my_location, color: AppColors.primary, size: 18),
                    ),
                    title: Text(opt.name, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14)),
                    subtitle: Text('Lat: ${opt.lat}, Lon: ${opt.lon}', style: const TextStyle(fontSize: 11)),
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

class _ItineraryView extends StatelessWidget {
  const _ItineraryView({
    required this.stops,
    required this.route,
    required this.loadingRoute,
    required this.onStopTap,
  });

  final List<Attraction> stops;
  final RouteInfo? route;
  final bool loadingRoute;
  final ValueChanged<Attraction> onStopTap;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 28),
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: cardDecoration(AppColors.primary),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Rule-based Smart Itinerary',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w900,
                  fontSize: 18,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                loadingRoute
                    ? 'Calculating route...'
                    : '${stops.length} stops - ${route?.distanceKm.toStringAsFixed(1) ?? '0.0'} km - ${route?.durationMinutes.round() ?? 0} min',
                style: const TextStyle(color: Color(0xFFE7EAFF)),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        if (stops.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 24),
            child: Center(
              child: Text(
                'No stops in this area. Try adding attractions from the List first!',
                style: TextStyle(color: AppColors.muted, fontWeight: FontWeight.bold),
              ),
            ),
          )
        else
          ...stops.asMap().entries.map((entry) {
            final index = entry.key + 1;
            final stop = entry.value;
            return InkWell(
              borderRadius: BorderRadius.circular(18),
              onTap: () => onStopTap(stop),
              child: Container(
                margin: const EdgeInsets.only(bottom: 10),
                padding: const EdgeInsets.all(14),
                decoration: cardDecoration(),
                child: Row(
                  children: [
                    CircleAvatar(
                      backgroundColor: AppColors.primary,
                      child: Text(
                        '$index',
                        style: const TextStyle(color: Colors.white),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            stop.name,
                            style: const TextStyle(fontWeight: FontWeight.w900),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            stop.category,
                            style: const TextStyle(color: AppColors.muted),
                          ),
                        ],
                      ),
                    ),
                    const Icon(Icons.chevron_right, color: AppColors.muted),
                  ],
                ),
              ),
            );
          }),
        const SizedBox(height: 10),
        const _AlgorithmCard(),
      ],
    );
  }
}

class _AlgorithmCard extends StatelessWidget {
  const _AlgorithmCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Demo Algorithm', style: TextStyle(fontWeight: FontWeight.w900)),
          const SizedBox(height: 10),
          Text('1. Sort attractions by distance from ${LocationService().currentAreaName} center.'),
          const Text('2. Add nearest stops while total time stays below 6 hours.'),
          const Text('3. Limit the route to maximum 5 attractions.'),
          const Text('4. Draw route using OpenRouteService when API key exists.'),
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
            Text(message, textAlign: TextAlign.center),
            const SizedBox(height: 16),
            FilledButton(onPressed: onRetry, child: const Text('Try Again')),
          ],
        ),
      ),
    );
  }
}
