import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:smart_travel_planner/features/itinerary/services/supabase_itinerary_service.dart';

import 'package:smart_travel_planner/core/theme/app_colors.dart';
import 'package:smart_travel_planner/features/places/screens/api_demo_page.dart';
import 'package:smart_travel_planner/features/assistant/screens/assistant_page.dart';
import 'package:smart_travel_planner/features/home/screens/home_page.dart';
import 'package:smart_travel_planner/features/image_recognition/screens/image_recognition_page.dart';
import 'package:smart_travel_planner/features/itinerary/screens/my_trips_screen.dart';
import 'package:smart_travel_planner/features/itinerary/screens/planner_page.dart';
import 'package:smart_travel_planner/features/auth/services/auth_service.dart';
import 'package:smart_travel_planner/shared/widgets/app_header.dart';

class TravelShell extends StatefulWidget {
  const TravelShell({super.key});

  @override
  State<TravelShell> createState() => _TravelShellState();
}

class _TravelShellState extends State<TravelShell> with WidgetsBindingObserver {
  Timer? _syncTimer;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _syncTimer = Timer.periodic(const Duration(minutes: 1), (_) {
      unawaited(SupabaseItineraryService().syncPending());
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      unawaited(SupabaseItineraryService().syncPending());
    }
  }

  @override
  void dispose() {
    _syncTimer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  int _selectedIndex = 0;
  bool _myTripsOpen = false;

  static const _tabTitles = [
    null, // Home: automatically shows Hello, <UserName>!
    'Explore Malaysia',
    'Image Recognition',
    'Plan Your Trip',
    'Trip Assistant',
  ];

  static const _tabSubtitles = [
    null, // Home: automatically shows Where would you like to explore today?
    'Discover attractions & places',
    'Discover Malaysia through your camera',
    'Tell us your preferences',
    'AI help, translation and weather alerts',
  ];

  void _goToTab(int index) {
    setState(() {
      _selectedIndex = index;
      _myTripsOpen = false;
    });
  }

  void _openMyTrips() {
    setState(() => _myTripsOpen = true);
  }

  void _closeMyTrips() {
    setState(() => _myTripsOpen = false);
  }

  @override
  Widget build(BuildContext context) {
    final pages = [
      HomePage(
        onPlanTap: () => _goToTab(3),
        onItineraryTap: _openMyTrips,
        onRouteTap: () => _goToTab(1),
        onAssistantTap: () => _goToTab(4),
      ),
      const ApiDemoPage(),
      ImageRecognitionPage(
        key: ValueKey(
          'recognition:${AuthService().currentUser?.uid ?? 'guest'}',
        ),
        userId: AuthService().currentUser?.uid ?? 'guest',
      ),
      PlannerPage(onItineraryReady: _openMyTrips, onMyTripsTap: _openMyTrips),
      const AssistantPage(),
      // Keep itinerary drafts and the selected day alive between visits.
      MyTripsScreen(onBackTap: _closeMyTrips, onPlanTap: () => _goToTab(3)),
    ];

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.dark.copyWith(
        statusBarColor: Colors.transparent,
        systemNavigationBarColor: Colors.white,
      ),
      child: PopScope(
        canPop: !_myTripsOpen,
        onPopInvokedWithResult: (didPop, _) {
          if (!didPop && _myTripsOpen) _closeMyTrips();
        },
        child: Scaffold(
          body: SafeArea(
            bottom: false,
            child: Column(
              children: [
                Offstage(
                  offstage: _myTripsOpen,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
                    child: AppHeader(
                      title: _tabTitles[_selectedIndex],
                      subtitle: _tabSubtitles[_selectedIndex],
                    ),
                  ),
                ),
                Expanded(
                  child: IndexedStack(
                    index: _myTripsOpen ? pages.length - 1 : _selectedIndex,
                    children: pages,
                  ),
                ),
              ],
            ),
          ),
          bottomNavigationBar: _myTripsOpen
              ? null
              : TravelBottomNavigation(
                  selectedIndex: _selectedIndex,
                  onSelected: _goToTab,
                ),
        ),
      ),
    );
  }
}

/// Five equal-width destinations keep Recognize at the physical centre.
class TravelBottomNavigation extends StatelessWidget {
  const TravelBottomNavigation({
    super.key,
    required this.selectedIndex,
    required this.onSelected,
  });

  final int selectedIndex;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) {
    Widget item(
      int index,
      IconData icon,
      String label, {
      IconData? selectedIcon,
      Key? key,
      String? tooltip,
    }) {
      final selected = selectedIndex == index;
      return Semantics(
        selected: selected,
        button: true,
        child: Tooltip(
          message: tooltip ?? label,
          child: InkWell(
            key: key,
            onTap: () => onSelected(index),
            borderRadius: BorderRadius.circular(16),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 2),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    width: 42,
                    height: 28,
                    decoration: BoxDecoration(
                      color: selected
                          ? AppColors.primary.withValues(alpha: 0.12)
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Icon(
                      selected ? selectedIcon ?? icon : icon,
                      size: 22,
                      color: selected ? AppColors.primary : AppColors.muted,
                    ),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                      color: selected ? AppColors.primary : AppColors.ink,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    return Material(
      color: Colors.white,
      child: SafeArea(
        top: false,
        minimum: const EdgeInsets.symmetric(horizontal: 8),
        child: SizedBox(
          height: 72,
          child: Row(
            children: [
              Expanded(
                child: item(
                  0,
                  Icons.home_outlined,
                  'Home',
                  selectedIcon: Icons.home,
                ),
              ),
              Expanded(
                child: item(
                  1,
                  Icons.travel_explore_outlined,
                  'Explore',
                  selectedIcon: Icons.travel_explore,
                ),
              ),
              Expanded(
                child: item(
                  2,
                  Icons.document_scanner_outlined,
                  'Recognize',
                  selectedIcon: Icons.document_scanner,
                  key: const ValueKey('scan-navigation-button'),
                  tooltip: 'Image recognition',
                ),
              ),
              Expanded(
                child: item(
                  3,
                  Icons.event_note_outlined,
                  'Plan',
                  selectedIcon: Icons.event_note,
                ),
              ),
              Expanded(
                child: item(
                  4,
                  Icons.smart_toy_outlined,
                  'AI',
                  selectedIcon: Icons.smart_toy,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
