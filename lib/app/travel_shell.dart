import 'package:smart_travel_planner/l10n/localized_labels.dart';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:smart_travel_planner/features/places/utils/attraction_image_resolver.dart';
import 'package:smart_travel_planner/shared/models/attraction.dart';
import 'package:smart_travel_planner/features/itinerary/services/supabase_itinerary_service.dart';

import 'package:smart_travel_planner/features/community/explore_page.dart';
import 'package:smart_travel_planner/features/assistant/screens/assistant_page.dart';
import 'package:smart_travel_planner/features/home/screens/home_page.dart';
import 'package:smart_travel_planner/features/image_recognition/screens/image_recognition_page.dart';
import 'package:smart_travel_planner/features/image_recognition/widgets/visual_scan_style.dart';
import 'package:smart_travel_planner/features/itinerary/screens/my_trips_screen.dart';
import 'package:smart_travel_planner/features/itinerary/screens/planner_page.dart';
import 'package:smart_travel_planner/features/auth/services/auth_service.dart';
import 'package:smart_travel_planner/features/auth/screens/auth_screen.dart';
import 'package:smart_travel_planner/features/onboarding/screens/onboarding_setup_screen.dart';
import 'package:smart_travel_planner/features/onboarding/services/onboarding_service.dart';
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
  List<Attraction>? _homeAttractions;

  void _onPlacesLoaded(List<Attraction> places) {
    final pictured = places.where((place) {
      return AttractionImageResolver.resolvePhotoUrl(place) != null ||
          (place.googlePlaceId != null && place.googlePhotos.isNotEmpty);
    }).toList();
    if (pictured.isEmpty || !mounted) return;
    setState(() {
      _homeAttractions = pictured.take(10).toList();
    });
  }

  static const _sectionNames = [
    'Explore',
    'Community',
    'Visual Scan',
    'Route',
    'AI',
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
        attractions: _homeAttractions,
        onPlanTap: () => _goToTab(3),
        onItineraryTap: _openMyTrips,
        onRouteTap: () => _goToTab(1),
        onAssistantTap: () => _goToTab(4),
      ),
      ExplorePage(
        isVisible: _selectedIndex == 1 && !_myTripsOpen,
        onPlacesLoaded: _onPlacesLoaded,
      ),
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

    final section = _myTripsOpen
        ? context.l10n.myTrips
        : context.tr(_sectionNames[_selectedIndex]);
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light.copyWith(
        statusBarColor: Colors.transparent,
        systemNavigationBarColor: VisualScanStyle.navigation,
      ),
      child: PopScope(
        canPop: !_myTripsOpen,
        onPopInvokedWithResult: (didPop, _) {
          if (!didPop && _myTripsOpen) _closeMyTrips();
        },
        child: Scaffold(
          backgroundColor: VisualScanStyle.background,
          body: SafeArea(
            bottom: false,
            child: Column(
              children: [
                DecoratedBox(
                  decoration: const BoxDecoration(
                    border: Border(
                      bottom: BorderSide(color: VisualScanStyle.border),
                    ),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(17, 11, 18, 9),
                    child: AppHeader(
                      subtitle: 'Kuala Lumpur · $section',
                      isDark: true,
                      compactCitylore: true,
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
          bottomNavigationBar: TravelBottomNavigation(
            selectedIndex: _myTripsOpen ? 3 : _selectedIndex,
            onSelected: _goToTab,
          ),
        ),
      ),
    );
  }
}

/// Shared Citylore navigation for the travel shell.
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
    const destinations = [
      ('Explore', Icons.explore_outlined),
      ('Community', Icons.people_outline),
      ('Scan', Icons.photo_camera_outlined),
      ('Route', Icons.route_outlined),
      ('AI', Icons.auto_awesome_outlined),
    ];
    return Material(
      color: VisualScanStyle.navigation,
      child: DecoratedBox(
        decoration: const BoxDecoration(
          border: Border(top: BorderSide(color: VisualScanStyle.border)),
        ),
        child: SafeArea(
          top: false,
          child: SizedBox(
            height: 74,
            child: Row(
              children: [
                for (final (index, (label, icon)) in destinations.indexed)
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(1, 6, 1, 6),
                      child: Semantics(
                        selected: index == selectedIndex,
                        button: true,
                        child: InkWell(
                          key: index == 2
                              ? const ValueKey('scan-navigation-button')
                              : null,
                          onTap: () => onSelected(index),
                          borderRadius: BorderRadius.circular(15),
                          child: Padding(
                            padding: const EdgeInsets.only(bottom: 3),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.end,
                              children: [
                                if (index == 2)
                                  Container(
                                    height: 42,
                                    width: 42,
                                    decoration: BoxDecoration(
                                      color: VisualScanStyle.amber,
                                      borderRadius: BorderRadius.circular(13),
                                      border: Border.all(
                                        color: const Color(0xFFF2C280),
                                        width: 2,
                                      ),
                                    ),
                                    child: Icon(
                                      icon,
                                      size: 20,
                                      color: VisualScanStyle.background,
                                    ),
                                  )
                                else
                                  Icon(
                                    icon,
                                    size: 20,
                                    color: index == selectedIndex
                                        ? VisualScanStyle.amber
                                        : VisualScanStyle.muted,
                                  ),
                                const SizedBox(height: 3),
                                Flexible(
                                  child: FittedBox(
                                    fit: BoxFit.scaleDown,
                                    child: Text(
                                      context.tr(label),
                                      style: TextStyle(
                                        color:
                                            index == 2 || index == selectedIndex
                                            ? VisualScanStyle.amber
                                            : VisualScanStyle.muted,
                                        fontSize: 11,
                                        fontWeight: FontWeight.w500,
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
              ],
            ),
          ),
        ),
      ),
    );
  }
}
