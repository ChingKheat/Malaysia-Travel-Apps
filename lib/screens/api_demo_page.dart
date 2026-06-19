import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';

import '../core/api_keys.dart';
import '../core/app_colors.dart';
import '../core/app_decorations.dart';
import '../models/attraction.dart';
import '../models/route_info.dart';
import '../services/itinerary_service.dart';
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
  final _kualaLumpur = const LatLng(3.1390, 101.6869);

  var _loading = true;
  var _loadingRoute = false;
  var _selectedView = 0;
  String? _error;
  List<Attraction> _attractions = [];
  List<Attraction> _selectedStops = [];
  RouteInfo? _route;

  @override
  void initState() {
    super.initState();
    _loadAttractions();
  }

  Future<void> _loadAttractions() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final attractions = await _attractionService
          .fetchAttractionsNearKualaLumpur();
      final itinerary = _itineraryService.generateSmartItinerary(
        attractions: attractions,
        startPoint: _kualaLumpur,
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
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final hasApiKeys =
        ApiKeys.hasOpenTripMapKey && ApiKeys.hasOpenRouteServiceKey;

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 10),
              child: Column(
                children: [
                  AppHeader(
                    title: 'Smart Travel Demo',
                    subtitle: hasApiKeys
                        ? 'Live Malaysia attractions and route planning'
                        : 'Sample fallback active until API keys are added',
                  ),
                  const SizedBox(height: 12),
                  _ApiStatusCard(
                    hasOpenTripMap: ApiKeys.hasOpenTripMapKey,
                    hasOpenRouteService: ApiKeys.hasOpenRouteServiceKey,
                    isFallbackRoute: _route?.isFallback ?? false,
                    onRefresh: _loadAttractions,
                  ),
                  const SizedBox(height: 12),
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
                    onSelectionChanged: (value) =>
                        setState(() => _selectedView = value.first),
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

    if (_selectedView == 1) {
      return MapScreen(
        attractions: _attractions,
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
      attractions: _attractions,
      selectedStops: _selectedStops,
      onAttractionTap: _openDetails,
      onToggleStop: _toggleStop,
    );
  }
}

class _ApiStatusCard extends StatelessWidget {
  const _ApiStatusCard({
    required this.hasOpenTripMap,
    required this.hasOpenRouteService,
    required this.isFallbackRoute,
    required this.onRefresh,
  });

  final bool hasOpenTripMap;
  final bool hasOpenRouteService;
  final bool isFallbackRoute;
  final VoidCallback onRefresh;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: cardDecoration(),
      child: Row(
        children: [
          Expanded(
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _StatusChip(label: 'OpenTripMap', active: hasOpenTripMap),
                _StatusChip(
                  label: 'ORS Route',
                  active: hasOpenRouteService && !isFallbackRoute,
                ),
              ],
            ),
          ),
          IconButton.filledTonal(
            tooltip: 'Refresh attractions',
            onPressed: onRefresh,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.label, required this.active});

  final String label;
  final bool active;

  @override
  Widget build(BuildContext context) {
    return Chip(
      avatar: Icon(
        active ? Icons.check_circle : Icons.info_outline,
        color: active ? AppColors.teal : AppColors.warning,
        size: 18,
      ),
      label: Text(active ? '$label live' : '$label demo'),
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
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Demo Algorithm', style: TextStyle(fontWeight: FontWeight.w900)),
          SizedBox(height: 10),
          Text('1. Sort attractions by distance from Kuala Lumpur center.'),
          Text('2. Add nearest stops while total time stays below 6 hours.'),
          Text('3. Limit the route to maximum 5 attractions.'),
          Text('4. Draw route using OpenRouteService when API key exists.'),
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
