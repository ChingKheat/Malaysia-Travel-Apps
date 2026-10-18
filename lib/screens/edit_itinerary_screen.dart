import 'dart:math' as math;
import 'package:flutter/material.dart';

import '../core/app_colors.dart';
import '../core/demo_feedback.dart';
import '../data/curated_attractions.dart';
import '../models/attraction.dart';
import '../models/itinerary_models.dart';
import '../models/travel_stop.dart';
import '../models/weather_forecast.dart';
import '../services/place_classifier.dart';
import '../services/smart_itinerary_service.dart';
import '../services/supabase_itinerary_service.dart';

/// UC602: Interactive Itinerary Editor Screen
/// Allows tourists to reorder stops (drag-and-drop), delete stops,
/// swap outdoor stops with weather-proof indoor attractions, and add new POIs.
class EditItineraryScreen extends StatefulWidget {
  const EditItineraryScreen({
    super.key,
    required this.tripTitle,
    required this.destination,
    required this.dayNumber,
    required this.initialStops,
    this.otherDaysStops = const [],
    this.weatherForecast,
    this.scheduleId,
  });

  final String tripTitle;
  final String destination;
  final int dayNumber;
  final List<TravelStop> initialStops;
  final List<TravelStop> otherDaysStops;
  final WeatherForecast? weatherForecast;
  final String? scheduleId;

  @override
  State<EditItineraryScreen> createState() => _EditItineraryScreenState();
}

class _EditItineraryScreenState extends State<EditItineraryScreen> {
  late List<TravelStop> _stops;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _stops = List<TravelStop>.from(widget.initialStops);
  }

  /// Recalculates chronological arrival and departure times for all stops
  List<TravelStop> _recalculateTimes(List<TravelStop> list) {
    final updated = <TravelStop>[];
    int currentMinutes = 9 * 60; // Start at 09:00 AM by default

    // Parse starting time from first stop if available
    if (list.isNotEmpty && list.first.time.isNotEmpty) {
      final firstTime = list.first.time;
      final startPart = firstTime.split('-').first.trim().toUpperCase();
      final isPm = startPart.contains('PM');
      final isAm = startPart.contains('AM');
      final clean = startPart.replaceAll('AM', '').replaceAll('PM', '').trim();
      final parts = clean.split(':');
      if (parts.isNotEmpty) {
        int h = int.tryParse(parts[0]) ?? 9;
        int m = parts.length > 1 ? (int.tryParse(parts[1]) ?? 0) : 0;
        if (isPm && h < 12) h += 12;
        if (isAm && h == 12) h = 0;
        currentMinutes = h * 60 + m;
      }
    }

    for (int i = 0; i < list.length; i++) {
      final s = list[i];
      final arrivalH = currentMinutes ~/ 60;
      final arrivalM = currentMinutes % 60;

      // 90 minutes visit duration
      final departMinutes = currentMinutes + 90;
      final departH = departMinutes ~/ 60;
      final departM = departMinutes % 60;

      final arrivalStr = _format12Hour(arrivalH, arrivalM);
      final departStr = _format12Hour(departH, departM);

      updated.add(
        TravelStop(
          title: s.title,
          time: '$arrivalStr - $departStr',
          note: s.note,
          description: s.description,
          duration: s.duration.isNotEmpty ? s.duration : '1 h 30 min',
          openingHours: s.openingHours,
          tips: s.tips,
          icon: s.icon,
          color: s.color,
          category: s.category,
          photoUrls: s.photoUrls,
          placeId: s.placeId,
          latitude: s.latitude,
          longitude: s.longitude,
        ),
      );

      // 15 min travel buffer between consecutive stops
      currentMinutes = departMinutes + 15;
    }

    return updated;
  }

  static String _format12Hour(int h, int m) {
    final period = h >= 12 ? 'PM' : 'AM';
    int h12 = h % 12;
    if (h12 == 0) h12 = 12;
    final mStr = m.toString().padLeft(2, '0');
    final hStr = h12.toString().padLeft(2, '0');
    return '$hStr:$mStr $period';
  }

  void _onReorder(int oldIndex, int newIndex) {
    setState(() {
      if (newIndex > oldIndex) newIndex -= 1;
      final item = _stops.removeAt(oldIndex);
      _stops.insert(newIndex, item);
      _stops = _recalculateTimes(_stops);
    });
    showDemoSnackBar(
      context,
      'Stop reordered. Schedule times automatically adjusted.',
      icon: Icons.swap_vert,
    );
  }

  void _deleteStop(int index) {
    if (_stops.length <= 1) {
      showDemoSnackBar(
        context,
        'An itinerary day must have at least 1 stop.',
        icon: Icons.warning_amber_rounded,
      );
      return;
    }
    final deleted = _stops[index];
    setState(() {
      _stops.removeAt(index);
      _stops = _recalculateTimes(_stops);
    });
    showDemoSnackBar(
      context,
      'Removed "${deleted.title}". Times updated.',
      icon: Icons.delete_outline,
    );
  }

  /// Validates whether a candidate attraction is identical to an existing stop
  /// by checking place ID, normalized name (e.g. ignoring parentheses like (KLCC)),
  /// word token overlap, or GPS proximity (< 400m with common words, or < 50m exact pin).
  bool _isSamePlace(Attraction candidate, TravelStop stop) {
    if (stop.placeId != null &&
        stop.placeId!.isNotEmpty &&
        candidate.xid.toLowerCase().trim() == stop.placeId!.toLowerCase().trim()) {
      return true;
    }

    final n1 = candidate.name.toLowerCase().trim();
    final n2 = stop.title.toLowerCase().trim();
    if (n1 == n2) return true;

    String clean(String s) {
      return s
          .replaceAll(RegExp(r'\(.*?\)'), '')
          .replaceAll(RegExp(r'[^a-zA-Z0-9\s]'), '')
          .toLowerCase()
          .replaceAll(RegExp(r'\s+'), ' ')
          .trim();
    }

    final c1 = clean(n1);
    final c2 = clean(n2);
    if (c1.isNotEmpty && c2.isNotEmpty) {
      if (c1 == c2) return true;
      if (c1.length >= 6 && c2.length >= 6) {
        if (c1.contains(c2) || c2.contains(c1)) return true;
      }
    }

    final stopWords = {'the', 'and', 'at', 'in', 'of', 'for', 'near'};
    final words1 = c1.split(' ').where((w) => w.length >= 4 && !stopWords.contains(w)).toSet();
    final words2 = c2.split(' ').where((w) => w.length >= 4 && !stopWords.contains(w)).toSet();
    final commonWords = words1.intersection(words2);

    if (candidate.latitude != 0.0 &&
        candidate.longitude != 0.0 &&
        stop.latitude != 0.0 &&
        stop.longitude != 0.0) {
      const p = 0.017453292519943295;
      final a = 0.5 -
          math.cos((stop.latitude - candidate.latitude) * p) / 2 +
          math.cos(candidate.latitude * p) *
              math.cos(stop.latitude * p) *
              (1 - math.cos((stop.longitude - candidate.longitude) * p)) /
              2;
      final distMeters = 12742000 * math.asin(math.sqrt(a));
      if (distMeters < 400 && commonWords.isNotEmpty) return true;
    }

    return false;
  }

  bool _isSameStop(TravelStop s1, TravelStop s2) {
    if (identical(s1, s2)) return true;

    if (s1.placeId != null &&
        s2.placeId != null &&
        s1.placeId!.isNotEmpty &&
        s2.placeId!.isNotEmpty &&
        s1.placeId!.toLowerCase().trim() == s2.placeId!.toLowerCase().trim()) {
      return true;
    }

    final n1 = s1.title.toLowerCase().trim();
    final n2 = s2.title.toLowerCase().trim();
    if (n1 == n2) return true;

    String clean(String s) {
      return s
          .replaceAll(RegExp(r'\(.*?\)'), '')
          .replaceAll(RegExp(r'[^a-zA-Z0-9\s]'), '')
          .toLowerCase()
          .replaceAll(RegExp(r'\s+'), ' ')
          .trim();
    }

    final c1 = clean(n1);
    final c2 = clean(n2);
    if (c1.isNotEmpty && c2.isNotEmpty) {
      if (c1 == c2) return true;
      if (c1.length >= 6 && c2.length >= 6) {
        if (c1.contains(c2) || c2.contains(c1)) return true;
      }
    }

    final stopWords = {'the', 'and', 'at', 'in', 'of', 'for', 'near'};
    final words1 = c1.split(' ').where((w) => w.length >= 4 && !stopWords.contains(w)).toSet();
    final words2 = c2.split(' ').where((w) => w.length >= 4 && !stopWords.contains(w)).toSet();
    final commonWords = words1.intersection(words2);

    if (s1.latitude != 0.0 &&
        s1.longitude != 0.0 &&
        s2.latitude != 0.0 &&
        s2.longitude != 0.0) {
      const p = 0.017453292519943295;
      final a = 0.5 -
          math.cos((s2.latitude - s1.latitude) * p) / 2 +
          math.cos(s1.latitude * p) *
              math.cos(s2.latitude * p) *
              (1 - math.cos((s2.longitude - s1.longitude) * p)) /
              2;
      final distMeters = 12742000 * math.asin(math.sqrt(a));
      if (distMeters < 400 && commonWords.isNotEmpty) return true;
    }

    return false;
  }

  List<Attraction> _getAllCandidateAttractions() {
    final cleanDest = widget.destination.split(',').first.trim().toLowerCase();
    final matching = curatedMalaysianAttractions.where((a) {
      final xid = a.xid.toLowerCase();
      final nm = a.name.toLowerCase();
      return xid.contains(cleanDest.replaceAll(' ', '_')) ||
          nm.contains(cleanDest) ||
          (cleanDest.contains('kuala') && xid.contains('kl'));
    }).toList();

    return matching.isNotEmpty ? matching : curatedMalaysianAttractions;
  }

  void _showSwapAttractionSheet(int stopIndex) {
    final current = _stops[stopIndex];
    final isCurrentlyIndoor = PlaceClassifier.classify(
          category: current.category,
          name: current.title,
        ) ==
        true;
    final isRainy = widget.weatherForecast != null &&
        !widget.weatherForecast!.isSuitableForOutdoor;

    // Filter out items already scheduled in any day of the entire itinerary
    // (except the current stop being replaced)
    final existingStopsToBlock = [
      ...widget.otherDaysStops,
      for (int i = 0; i < _stops.length; i++)
        if (i != stopIndex) _stops[i],
    ];

    final allInDest = _getAllCandidateAttractions().where((a) {
      return !existingStopsToBlock.any((s) => _isSamePlace(a, s));
    }).toList();

    // Default filter: If raining & currently outdoor, default to 'Indoor'. Else 'All'.
    String activeFilter = (isRainy && !isCurrentlyIndoor) ? 'Indoor' : 'All';

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            final indoorCount = allInDest
                .where((a) =>
                    PlaceClassifier.classify(
                        category: a.category, name: a.name) ==
                    true)
                .length;
            final outdoorCount = allInDest.length - indoorCount;

            final displayedList = allInDest.where((a) {
              final isInd = PlaceClassifier.classify(
                      category: a.category, name: a.name) ==
                  true;
              if (activeFilter == 'Indoor') return isInd;
              if (activeFilter == 'Outdoor') return !isInd;
              return true;
            }).toList();

            return SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Header
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: AppColors.primary.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(
                            Icons.swap_horiz_rounded,
                            color: AppColors.primary,
                            size: 20,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Swap Attraction',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w900,
                                  color: AppColors.ink,
                                ),
                              ),
                              Text(
                                'Replacing "${current.title}" (${isCurrentlyIndoor ? "Indoor" : "Outdoor"})',
                                style: const TextStyle(
                                  color: AppColors.muted,
                                  fontSize: 12,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),

                    // Weather recommendation hint banner
                    if (isRainy && !isCurrentlyIndoor)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                        margin: const EdgeInsets.only(bottom: 12),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFEF3C7),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: const Color(0xFFFDE68A)),
                        ),
                        child: const Row(
                          children: [
                            Icon(Icons.umbrella_outlined, size: 16, color: Color(0xFFD97706)),
                            SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'Rain forecasted today. Swapping to an Indoor attraction is recommended.',
                                style: TextStyle(
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.w600,
                                  color: Color(0xFF92400E),
                                ),
                              ),
                            ),
                          ],
                        ),
                      )
                    else if (!isRainy && isCurrentlyIndoor)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                        margin: const EdgeInsets.only(bottom: 12),
                        decoration: BoxDecoration(
                          color: const Color(0xFFDCFCE7),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: const Color(0xFFBBF7D0)),
                        ),
                        child: const Row(
                          children: [
                            Icon(Icons.wb_sunny_outlined, size: 16, color: Color(0xFF16A34A)),
                            SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'Good weather today! You can keep it indoor or swap to an outdoor sight.',
                                style: TextStyle(
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.w600,
                                  color: Color(0xFF166534),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),

                    // Filter Choice Chips
                    Row(
                      children: [
                        ChoiceChip(
                          label: Text('All (${allInDest.length})'),
                          selected: activeFilter == 'All',
                          onSelected: (_) => setModalState(() => activeFilter = 'All'),
                        ),
                        const SizedBox(width: 8),
                        ChoiceChip(
                          label: Text('🏛️ Indoor ($indoorCount)'),
                          selected: activeFilter == 'Indoor',
                          onSelected: (_) => setModalState(() => activeFilter = 'Indoor'),
                        ),
                        const SizedBox(width: 8),
                        ChoiceChip(
                          label: Text('🏞️ Outdoor ($outdoorCount)'),
                          selected: activeFilter == 'Outdoor',
                          onSelected: (_) => setModalState(() => activeFilter = 'Outdoor'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),

                    // Attraction list
                    Flexible(
                      child: displayedList.isEmpty
                          ? const Padding(
                              padding: EdgeInsets.symmetric(vertical: 24),
                              child: Center(
                                child: Text(
                                  'No attractions match this filter in this city.',
                                  style: TextStyle(color: AppColors.muted, fontSize: 13),
                                ),
                              ),
                            )
                          : ListView.separated(
                              shrinkWrap: true,
                              itemCount: displayedList.length,
                              separatorBuilder: (context, index) => const SizedBox(height: 8),
                              itemBuilder: (context, idx) {
                                final c = displayedList[idx];
                                final isIndoor = PlaceClassifier.classify(
                                      category: c.category,
                                      name: c.name,
                                    ) ==
                                    true;

                                return ListTile(
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    side: BorderSide(color: Colors.grey.shade200),
                                  ),
                                  leading: CircleAvatar(
                                    backgroundColor: isIndoor
                                        ? Colors.blue.withValues(alpha: 0.1)
                                        : Colors.green.withValues(alpha: 0.1),
                                    child: Icon(
                                      isIndoor ? Icons.roofing_outlined : Icons.park_outlined,
                                      color: isIndoor ? Colors.blue : Colors.green,
                                      size: 20,
                                    ),
                                  ),
                                  title: Text(
                                    c.name,
                                    style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
                                  ),
                                  subtitle: Text(
                                    '${c.category} • ${isIndoor ? "Indoor" : "Outdoor"}',
                                    style: const TextStyle(fontSize: 12, color: AppColors.muted),
                                    maxLines: 1,
                                  ),
                                  trailing: const Icon(Icons.swap_horiz, color: AppColors.primary),
                                  onTap: () {
                                    Navigator.pop(ctx);
                                    final swappedStop = TravelStop(
                                      title: c.name,
                                      time: current.time,
                                      note: isIndoor
                                          ? 'Indoor attraction • Weather safe'
                                          : 'Outdoor sightseeing',
                                      description: c.description ?? '',
                                      duration: '1 h 30 min',
                                      openingHours: 'Daily, 10:00 AM - 10:00 PM',
                                      tips: isIndoor
                                          ? const ['Air-conditioned', 'Rain-proof backup']
                                          : const ['Outdoor sight', 'Comfortable footwear advised'],
                                      icon: isIndoor ? Icons.roofing_outlined : Icons.place,
                                      color: isIndoor
                                          ? const Color(0xFF2563EB)
                                          : const Color(0xFF16A34A),
                                      category: c.category,
                                      placeId: c.xid,
                                      latitude: c.latitude,
                                      longitude: c.longitude,
                                    );

                                    setState(() {
                                      _stops[stopIndex] = swappedStop;
                                      _stops = _recalculateTimes(_stops);
                                    });

                                    showDemoSnackBar(
                                      context,
                                      'Swapped "${current.title}" with "${c.name}"',
                                      icon: Icons.swap_horiz,
                                    );
                                  },
                                );
                              },
                            ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  void _showAddStopSheet() {
    // Collect all existing stops across the entire itinerary to block
    final existingToBlock = [
      ...widget.otherDaysStops,
      ..._stops,
    ];

    final candidates = _getAllCandidateAttractions()
        .where((c) => !existingToBlock.any((s) => _isSamePlace(c, s)))
        .toList();

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Icon(Icons.add_location_alt_outlined, color: AppColors.primary),
                    SizedBox(width: 10),
                    Text(
                      'Add Stop to Day Schedule',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                        color: AppColors.ink,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                const Text(
                  'Select an attraction to append to your day route',
                  style: TextStyle(color: AppColors.muted, fontSize: 13),
                ),
                const SizedBox(height: 14),
                Flexible(
                  child: ListView.separated(
                    shrinkWrap: true,
                    itemCount: candidates.length,
                    separatorBuilder: (context, index) => const SizedBox(height: 8),
                    itemBuilder: (context, idx) {
                      final c = candidates[idx];
                      final isIndoor = PlaceClassifier.classify(category: c.category, name: c.name) == true;
                      return ListTile(
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                          side: BorderSide(color: Colors.grey.shade200),
                        ),
                        leading: CircleAvatar(
                          backgroundColor: isIndoor
                              ? Colors.blue.withValues(alpha: 0.1)
                              : Colors.green.withValues(alpha: 0.1),
                          child: Icon(
                            isIndoor ? Icons.roofing_outlined : Icons.park_outlined,
                            color: isIndoor ? Colors.blue : Colors.green,
                            size: 20,
                          ),
                        ),
                        title: Text(
                          c.name,
                          style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
                        ),
                        subtitle: Text(
                          '${c.category} • ${isIndoor ? "Indoor" : "Outdoor"}',
                          style: const TextStyle(fontSize: 12, color: AppColors.muted),
                          maxLines: 1,
                        ),
                        trailing: const Icon(Icons.add_circle_outline, color: AppColors.primary),
                        onTap: () {
                          Navigator.pop(ctx);
                          final newStop = TravelStop(
                            title: c.name,
                            time: '04:00 PM - 05:30 PM',
                            note: isIndoor ? 'Indoor activity' : 'Outdoor sightseeing',
                            description: c.description ?? '',
                            duration: '1 h 30 min',
                            openingHours: 'Daily, 9:00 AM - 9:00 PM',
                            tips: const ['Scheduled visit'],
                            icon: isIndoor ? Icons.roofing_outlined : Icons.place,
                            color: isIndoor ? const Color(0xFF2563EB) : const Color(0xFF16A34A),
                            category: c.category,
                            placeId: c.xid,
                            latitude: c.latitude,
                            longitude: c.longitude,
                          );

                          setState(() {
                            _stops.add(newStop);
                            _stops = _recalculateTimes(_stops);
                          });

                          showDemoSnackBar(
                            context,
                            'Added ${c.name} to Day ${widget.dayNumber}',
                            icon: Icons.add_circle,
                          );
                        },
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _saveAndReturn() async {
    // 1. Validate duplicates within current day (cannot have duplicate stops today)
    for (int i = 0; i < _stops.length; i++) {
      for (int j = i + 1; j < _stops.length; j++) {
        if (_isSameStop(_stops[i], _stops[j])) {
          showDemoSnackBar(
            context,
            'Cannot save: "${_stops[i].title}" appears multiple times today. Please remove or swap the duplicate stop.',
            icon: Icons.error_outline,
          );
          return;
        }
      }
    }

    // 2. Validate newly added stops against other itinerary days
    for (final stop in _stops) {
      final wasInInitial = widget.initialStops.any((s) => _isSameStop(s, stop));
      if (!wasInInitial && widget.otherDaysStops.any((o) => _isSameStop(stop, o))) {
        showDemoSnackBar(
          context,
          'Cannot save: "${stop.title}" is already scheduled on another day of this itinerary.',
          icon: Icons.error_outline,
        );
        return;
      }
    }

    setState(() => _isSaving = true);

    // If an existing schedule is stored in Supabase, update it directly
    if (widget.scheduleId != null && widget.scheduleId!.isNotEmpty) {
      final totalDist = SmartItineraryService.calculateRouteDistanceKm(_stops);
      final itinStops = [
        for (int i = 0; i < _stops.length; i++)
          ItineraryStop(
            id: '',
            scheduleId: widget.scheduleId!,
            placeId: (_stops[i].placeId != null && _stops[i].placeId!.isNotEmpty)
                ? _stops[i].placeId!
                : 'poi_${widget.destination.toLowerCase().replaceAll(' ', '_')}_d${widget.dayNumber}_$i',
            placeName: _stops[i].title,
            stopOrder: i + 1,
            arrivalTime: _stops[i].time.contains('-')
                ? _stops[i].time.split('-').first.trim()
                : '09:00 AM',
            departureTime: _stops[i].time.contains('-')
                ? _stops[i].time.split('-').last.trim()
                : '10:30 AM',
            category: _stops[i].category,
            latitude: _stops[i].latitude,
            longitude: _stops[i].longitude,
          ),
      ];

      await SupabaseItineraryService().updateDailyScheduleStops(
        scheduleId: widget.scheduleId!,
        totalDistanceKm: totalDist,
        stops: itinStops,
      );
    }

    if (mounted) {
      setState(() => _isSaving = false);
      Navigator.pop(context, _stops);
    }
  }

  @override
  Widget build(BuildContext context) {
    final distanceKm = SmartItineraryService.calculateRouteDistanceKm(_stops);
    final forecast = widget.weatherForecast;
    final hasSameDayDuplicate = _stops.any((s) =>
        _stops.where((other) => _isSameStop(s, other)).length > 1);

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: Text(
          'Edit Day ${widget.dayNumber} Schedule',
          style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 18),
        ),
        elevation: 0,
        backgroundColor: Colors.white,
        foregroundColor: AppColors.ink,
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 14),
            child: FilledButton.icon(
              onPressed: _isSaving ? null : _saveAndReturn,
              icon: _isSaving
                  ? const SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : const Icon(Icons.check, size: 18),
              label: const Text('Save'),
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.primary,
                padding: const EdgeInsets.symmetric(horizontal: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          // Intelligence & Metrics Banner
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            color: Colors.white,
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Row(
                        children: [
                          const Icon(Icons.route_outlined, color: AppColors.primary, size: 18),
                          const SizedBox(width: 8),
                          Text(
                            '$distanceKm km • ${_stops.length} stops',
                            style: const TextStyle(
                              color: AppColors.ink,
                              fontSize: 13.5,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (forecast != null)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: forecast.badgeColor.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          forecast.suitabilityBadge,
                          style: TextStyle(
                            color: forecast.badgeColor,
                            fontSize: 11.5,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 8),
                const Row(
                  children: [
                    Icon(Icons.info_outline, size: 14, color: AppColors.muted),
                    SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        'Drag items by the handle to reorder. Tap Swap to replace with indoor places.',
                        style: TextStyle(color: AppColors.muted, fontSize: 11.5),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: Color(0xFFE2E8F0)),

          if (hasSameDayDuplicate)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              color: const Color(0xFFFFFBEB),
              child: const Row(
                children: [
                  Icon(Icons.warning_amber_rounded, size: 20, color: Color(0xFFD97706)),
                  SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Duplicate attractions detected today. Please remove or swap them to save.',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF92400E),
                      ),
                    ),
                  ),
                ],
              ),
            ),

          // Reorderable Stops List
          Expanded(
            child: ReorderableListView.builder(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 80),
              itemCount: _stops.length,
              // ignore: deprecated_member_use
              onReorder: _onReorder,
              itemBuilder: (context, index) {
                final stop = _stops[index];
                final isIndoor = PlaceClassifier.classify(
                      category: stop.category,
                      name: stop.title,
                    ) ==
                    true;

                final hasLocalDuplicate = _stops.asMap().entries.any(
                      (e) => e.key != index && _isSameStop(stop, e.value),
                    );
                final hasCrossDayDuplicate = widget.otherDaysStops.any(
                      (other) => _isSameStop(stop, other),
                    );

                return Container(
                  key: ValueKey('${stop.title}_$index'),
                  margin: const EdgeInsets.only(bottom: 10),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: hasLocalDuplicate ? const Color(0xFFF59E0B) : const Color(0xFFE2E8F0),
                      width: hasLocalDuplicate ? 1.5 : 1,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.02),
                        blurRadius: 6,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      // Reorder Drag Handle
                      ReorderableDragStartListener(
                        index: index,
                        child: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF1F5F9),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Icon(Icons.drag_indicator, color: Color(0xFF64748B), size: 20),
                        ),
                      ),
                      const SizedBox(width: 12),

                      // Sequence Number
                      CircleAvatar(
                        radius: 12,
                        backgroundColor: hasLocalDuplicate
                            ? const Color(0xFFFEF3C7)
                            : AppColors.primary.withValues(alpha: 0.12),
                        child: Text(
                          '${index + 1}',
                          style: TextStyle(
                            color: hasLocalDuplicate ? const Color(0xFFD97706) : AppColors.primary,
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),

                      // Stop Details
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              stop.title,
                              style: const TextStyle(
                                fontWeight: FontWeight.w800,
                                fontSize: 14,
                                color: AppColors.ink,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 2),
                            Row(
                              children: [
                                Text(
                                  stop.time,
                                  style: const TextStyle(
                                    color: AppColors.muted,
                                    fontSize: 11.5,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                const SizedBox(width: 6),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: isIndoor
                                        ? Colors.blue.withValues(alpha: 0.1)
                                        : Colors.green.withValues(alpha: 0.1),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Text(
                                    isIndoor ? 'Indoor' : 'Outdoor',
                                    style: TextStyle(
                                      color: isIndoor ? Colors.blue : Colors.green,
                                      fontSize: 10,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            if (hasLocalDuplicate) ...[
                              const SizedBox(height: 4),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFFEF3C7),
                                  borderRadius: BorderRadius.circular(4),
                                  border: Border.all(color: const Color(0xFFFDE68A)),
                                ),
                                child: const Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(Icons.warning_amber_rounded, size: 12, color: Color(0xFFD97706)),
                                    SizedBox(width: 4),
                                    Flexible(
                                      child: Text(
                                        'Duplicate stop today',
                                        style: TextStyle(
                                          color: Color(0xFFB45309),
                                          fontSize: 10,
                                          fontWeight: FontWeight.w700,
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ] else if (hasCrossDayDuplicate) ...[
                              const SizedBox(height: 4),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFEFF6FF),
                                  borderRadius: BorderRadius.circular(4),
                                  border: Border.all(color: const Color(0xFFBFDBFE)),
                                ),
                                child: const Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(Icons.info_outline, size: 12, color: Color(0xFF2563EB)),
                                    SizedBox(width: 4),
                                    Flexible(
                                      child: Text(
                                        'In other day',
                                        style: TextStyle(
                                          color: Color(0xFF1D4ED8),
                                          fontSize: 10,
                                          fontWeight: FontWeight.w700,
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),

                      // Action 1: Swap Attraction
                      IconButton(
                        tooltip: 'Swap attraction',
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                        icon: Icon(
                          (widget.weatherForecast != null &&
                                  !widget.weatherForecast!.isSuitableForOutdoor &&
                                  !isIndoor)
                              ? Icons.umbrella_outlined
                              : Icons.swap_horiz_rounded,
                          color: (widget.weatherForecast != null &&
                                  !widget.weatherForecast!.isSuitableForOutdoor &&
                                  !isIndoor)
                              ? Colors.amber.shade800
                              : AppColors.primary,
                          size: 20,
                        ),
                        onPressed: () => _showSwapAttractionSheet(index),
                      ),

                      // Action 2: Delete Stop
                      IconButton(
                        tooltip: 'Remove stop',
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                        icon: const Icon(Icons.delete_outline, color: Colors.redAccent, size: 20),
                        onPressed: () => _deleteStop(index),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
      bottomNavigationBar: Container(
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
        decoration: BoxDecoration(
          color: Colors.white,
          border: const Border(top: BorderSide(color: Color(0xFFE2E8F0))),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 8,
              offset: const Offset(0, -3),
            ),
          ],
        ),
        child: Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: _showAddStopSheet,
                icon: const Icon(Icons.add, size: 18),
                label: const Text('Add Stop'),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: FilledButton.icon(
                onPressed: _isSaving ? null : _saveAndReturn,
                icon: const Icon(Icons.check_circle_outline, size: 18),
                label: const Text('Save Changes'),
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
