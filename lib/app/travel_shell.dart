import 'dart:async';
import 'package:flutter/material.dart';
import '../services/supabase_itinerary_service.dart';

import '../core/app_colors.dart';
import '../screens/api_demo_page.dart';
import '../screens/assistant_page.dart';
import '../screens/home_page.dart';
import '../screens/itinerary_page.dart';
import '../screens/planner_page.dart';
import '../widgets/app_header.dart';

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

  static const _tabTitles = [
    null, // Home: automatically shows Hello, <UserName>!
    'Explore Malaysia',
    'Plan Your Trip',
    'My Itinerary',
    'Trip Assistant',
  ];

  static const _tabSubtitles = [
    null, // Home: automatically shows Where would you like to explore today?
    'Discover attractions & places',
    'Tell us your preferences',
    'Custom smart schedule & stops',
    'AI help, translation and weather alerts',
  ];

  void _goToTab(int index) {
    setState(() => _selectedIndex = index);
  }

  @override
  Widget build(BuildContext context) {
    final pages = [
      HomePage(
        onPlanTap: () => _goToTab(2),
        onItineraryTap: () => _goToTab(3),
        onRouteTap: () => _goToTab(1),
        onAssistantTap: () => _goToTab(4),
      ),
      const ApiDemoPage(),
      PlannerPage(onItineraryReady: () => _goToTab(3)),
      ItineraryPage(onPlanTap: () => _goToTab(2)),
      const AssistantPage(),
    ];

    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
              child: AppHeader(
                title: _tabTitles[_selectedIndex],
                subtitle: _tabSubtitles[_selectedIndex],
              ),
            ),
            Expanded(
              child: IndexedStack(index: _selectedIndex, children: pages),
            ),
          ],
        ),
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _selectedIndex,
        height: 72,
        backgroundColor: Colors.white,
        indicatorColor: AppColors.primary.withValues(alpha: 0.12),
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        onDestinationSelected: _goToTab,
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home),
            label: 'Home',
          ),
          NavigationDestination(
            icon: Icon(Icons.travel_explore_outlined),
            selectedIcon: Icon(Icons.travel_explore),
            label: 'Explore',
          ),
          NavigationDestination(
            icon: Icon(Icons.event_note_outlined),
            selectedIcon: Icon(Icons.event_note),
            label: 'Plan',
          ),
          NavigationDestination(
            icon: Icon(Icons.list_alt_outlined),
            selectedIcon: Icon(Icons.list_alt),
            label: 'Itinerary',
          ),
          NavigationDestination(
            icon: Icon(Icons.smart_toy_outlined),
            selectedIcon: Icon(Icons.smart_toy),
            label: 'AI',
          ),
        ],
      ),
    );
  }
}
