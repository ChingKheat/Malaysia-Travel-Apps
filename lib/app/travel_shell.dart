import 'package:smart_travel_planner/l10n/localized_labels.dart';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:smart_travel_planner/features/itinerary/services/supabase_itinerary_service.dart';

import 'package:smart_travel_planner/core/theme/app_colors.dart';
import 'package:smart_travel_planner/features/community/explore_page.dart';
import 'package:smart_travel_planner/features/assistant/screens/assistant_page.dart';
import 'package:smart_travel_planner/features/home/screens/home_page.dart';
import 'package:smart_travel_planner/features/places/screens/api_demo_page.dart';
import 'package:smart_travel_planner/features/image_recognition/screens/image_recognition_page.dart';
import 'package:smart_travel_planner/features/itinerary/screens/my_trips_screen.dart';
import 'package:smart_travel_planner/features/itinerary/screens/planner_page.dart';
import 'package:smart_travel_planner/features/auth/services/auth_service.dart';
import 'package:smart_travel_planner/features/auth/screens/auth_screen.dart';
import 'package:smart_travel_planner/features/onboarding/screens/onboarding_setup_screen.dart';
import 'package:smart_travel_planner/features/onboarding/services/onboarding_service.dart';
import 'package:smart_travel_planner/shared/services/location_service.dart';
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
    AuthService().addListener(_onAuthStateChanged);
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
    AuthService().removeListener(_onAuthStateChanged);
    _syncTimer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  void _onAuthStateChanged() {
    if (!AuthService().isLoggedIn && mounted) {
      final targetScreen = !OnboardingService.instance.isCompleted
          ? const OnboardingSetupScreen()
          : const AuthScreen(initialTabIndex: 0, showLanguageSelector: false);
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => targetScreen),
        (route) => false,
      );
    }
  }

  int _selectedIndex = 0;
  bool _myTripsOpen = false;

  static const _tabTitles = [
    null,
    'Community',
    'Image Recognition',
    'Plan Your Trip',
    'Trip Assistant',
  ];

  static const _tabSubtitles = [
    null,
    'Traveller stories and local tips',
    'Landmarks & local dishes',
    'Tell us your preferences',
    'AI help, translation & weather',
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
      ApiDemoPage(
        isVisible: _selectedIndex == 0 && !_myTripsOpen,
        discoveryHeader: HomePage(
          discoveryHeaderOnly: true,
          onPlanTap: () => _goToTab(3),
          onItineraryTap: _openMyTrips,
          onRouteTap: () => _goToTab(0),
          onAssistantTap: () => _goToTab(4),
          onCommunityTap: () => _goToTab(1),
        ),
      ),
      ExplorePage(isVisible: _selectedIndex == 1 && !_myTripsOpen),
      ImageRecognitionPage(
        key: ValueKey(
          'recognition:${AuthService().currentUser?.uid ?? 'guest'}',
        ),
        userId: AuthService().currentUser?.uid ?? 'guest',
      ),
      PlannerPage(
        onItineraryReady: _openMyTrips,
        onMyTripsTap: _openMyTrips,
        useModernPicker: true,
      ),
      const AssistantPage(),
      // Keep itinerary drafts and the selected day alive between visits.
      MyTripsScreen(onBackTap: _closeMyTrips, onPlanTap: () => _goToTab(3)),
    ];

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light.copyWith(
        statusBarColor: Colors.transparent,
        systemNavigationBarColor: AppColors.nightSurface,
      ),
      child: PopScope(
        canPop: !_myTripsOpen,
        onPopInvokedWithResult: (didPop, _) {
          if (!didPop && _myTripsOpen) _closeMyTrips();
        },
        child: Scaffold(
          backgroundColor: AppColors.nightCanvas,
          body: SafeArea(
            bottom: false,
            child: Column(
              children: [
                Offstage(
                  offstage: _myTripsOpen,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
                    child: ListenableBuilder(
                      listenable: LocationService(),
                      builder: (context, _) => AppHeader(
                        onMyTripsTap: _openMyTrips,
                        title: _tabTitles[_selectedIndex],
                        subtitle: _selectedIndex == 0
                            ? LocationService().destinationState
                            : _tabSubtitles[_selectedIndex],
                        isDark: true,
                      ),
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
                  isDark: true,
                ),
        ),
      ),
    );
  }
}

/// The central Scan action rises above the other destinations.
class TravelBottomNavigation extends StatelessWidget {
  const TravelBottomNavigation({
    super.key,
    required this.selectedIndex,
    required this.onSelected,
    this.isDark = false,
  });

  final int selectedIndex;
  final ValueChanged<int> onSelected;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    Widget item(
      int index,
      IconData icon,
      String label, {
      IconData? selectedIcon,
    }) {
      final selected = selectedIndex == index;
      final activeColor = isDark ? AppColors.nightAccent : AppColors.primary;
      final inactiveColor = isDark ? AppColors.nightMuted : AppColors.muted;

      return Expanded(
        child: Padding(
          padding: const EdgeInsets.only(top: 18),
          child: Semantics(
            selected: selected,
            button: true,
            child: Tooltip(
              message: context.tr(label),
              child: InkWell(
                onTap: () => onSelected(index),
                borderRadius: BorderRadius.circular(16),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        width: 42,
                        height: 28,
                        decoration: BoxDecoration(
                          color: selected
                              ? activeColor.withValues(
                                  alpha: isDark ? 0.18 : 0.12,
                                )
                              : Colors.transparent,
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Icon(
                          selected ? selectedIcon ?? icon : icon,
                          size: 22,
                          color: selected ? activeColor : inactiveColor,
                        ),
                      ),
                      const SizedBox(height: 5),
                      Flexible(
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text(
                            context.tr(label),
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: selected
                                  ? FontWeight.w700
                                  : FontWeight.w600,
                              color: selected ? activeColor : inactiveColor,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      );
    }

    return Material(
      type: MaterialType.transparency,
      child: Stack(
        children: [
          Positioned.fill(
            top: 18,
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: isDark ? AppColors.nightSurface : Colors.white,
                border: Border(
                  top: BorderSide(
                    color: isDark ? AppColors.nightLine : AppColors.line,
                  ),
                ),
              ),
            ),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: SizedBox(
                height: 76,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    item(
                      0,
                      Icons.explore_outlined,
                      'Explore',
                      selectedIcon: Icons.explore,
                    ),
                    item(
                      1,
                      Icons.groups_outlined,
                      'Community',
                      selectedIcon: Icons.groups,
                    ),
                    Expanded(
                      child: Align(
                        alignment: Alignment.topCenter,
                        child: _ScanDestination(
                          selected: selectedIndex == 2,
                          onTap: () => onSelected(2),
                          isDark: isDark,
                        ),
                      ),
                    ),
                    item(
                      3,
                      Icons.event_note_outlined,
                      'Plan',
                      selectedIcon: Icons.event_note,
                    ),
                    item(
                      4,
                      Icons.auto_awesome,
                      'AI',
                      selectedIcon: Icons.auto_awesome,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ScanDestination extends StatelessWidget {
  const _ScanDestination({
    required this.selected,
    required this.onTap,
    this.isDark = false,
  });

  final bool selected;
  final VoidCallback onTap;
  final bool isDark;

  @override
  Widget build(BuildContext context) => Semantics(
    selected: selected,
    button: true,
    child: Tooltip(
      message: context.l10n.imageRecognition2,
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(
          key: const ValueKey('scan-navigation-button'),
          onTap: onTap,
          borderRadius: BorderRadius.circular(14),
          child: SizedBox(
            width: 56,
            height: 70,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Ink(
                  width: 48,
                  height: 42,
                  decoration: BoxDecoration(
                    color: isDark
                        ? AppColors.nightAccent
                        : (selected
                              ? AppColors.primaryDark
                              : AppColors.primary),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(
                    Icons.center_focus_strong_rounded,
                    color: isDark ? AppColors.nightSurface : Colors.white,
                    size: 26,
                  ),
                ),
                const SizedBox(height: 4),
                Flexible(
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      context.l10n.scan,
                      style: TextStyle(
                        color: isDark
                            ? (selected
                                  ? AppColors.nightAccent
                                  : AppColors.nightMuted)
                            : (selected
                                  ? AppColors.primaryDark
                                  : AppColors.ink),
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}
