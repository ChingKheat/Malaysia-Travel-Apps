import 'package:smart_travel_planner/core/theme/app_colors.dart';
import 'package:flutter/material.dart';
import 'package:smart_travel_planner/features/auth/services/auth_service.dart';
import 'package:smart_travel_planner/features/community/explore_page.dart';
import 'package:smart_travel_planner/features/community/community_page.dart';
import 'package:smart_travel_planner/features/home/models/spotlight_destination.dart';
import 'package:smart_travel_planner/features/home/services/destination_spotlight_controller.dart';
import 'package:smart_travel_planner/features/home/widgets/destination_spotlight_card.dart';
import 'package:smart_travel_planner/features/home/widgets/destination_spotlight_picker_sheet.dart';
import 'package:smart_travel_planner/features/home/widgets/popular_attractions_section.dart';
import 'package:smart_travel_planner/features/home/widgets/trip_cards.dart';
import 'package:smart_travel_planner/features/profile/screens/profile_page.dart';
import 'package:smart_travel_planner/features/profile/services/profile_avatar_service.dart';
import 'package:smart_travel_planner/features/itinerary/models/saved_trip.dart';
import 'package:smart_travel_planner/features/itinerary/services/supabase_itinerary_service.dart';
import 'package:smart_travel_planner/features/itinerary/services/trip_preferences_service.dart';
import 'package:smart_travel_planner/l10n/localized_labels.dart';
import 'package:smart_travel_planner/shared/models/attraction.dart';

class HomePage extends StatefulWidget {
  const HomePage({
    super.key,
    required this.onPlanTap,
    required this.onItineraryTap,
    required this.onRouteTap,
    required this.onAssistantTap,
    this.attractions,
    this.discoveryHeaderOnly = false,
    this.onCommunityTap,
    this.onSpotlightSelected,
    this.spotlightStore,
    this.showSpotlightOnlyWhenDismissed = false,
  });

  final VoidCallback onPlanTap;
  final VoidCallback onItineraryTap;
  final VoidCallback onRouteTap;
  final VoidCallback onAssistantTap;
  final List<Attraction>? attractions;
  final bool discoveryHeaderOnly;
  final VoidCallback? onCommunityTap;
  final ValueChanged<List<SpotlightDestination>>? onSpotlightSelected;
  final DestinationSpotlightStore? spotlightStore;
  final bool showSpotlightOnlyWhenDismissed;

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  List<SavedTrip> _dbSavedTrips = [];
  final TextEditingController _searchController = TextEditingController();
  DestinationSpotlightStore? _ownedSpotlightStore;
  DestinationSpotlightStore get _spotlightStore =>
      widget.spotlightStore ??
      (_ownedSpotlightStore ??= DestinationSpotlightStore());
  String get _searchQuery => _searchController.text.trim();
  String _selectedCategory = 'All';

  static const _categories = [
    'All',
    'Heritage',
    'Skyline',
    'Culture',
    'Sacred',
  ];

  @override
  void initState() {
    super.initState();
    SupabaseItineraryService().addListener(_onRepoChanged);
    if (widget.spotlightStore == null) {
      _spotlightStore.load();
    }
    _loadTrips();
  }

  @override
  void dispose() {
    SupabaseItineraryService().removeListener(_onRepoChanged);
    _ownedSpotlightStore?.dispose();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _openSpotlightPicker() async {
    final selected = await showDestinationSpotlightPicker(context);
    if (!mounted || selected == null || selected.isEmpty) return;
    if (widget.onSpotlightSelected != null) {
      widget.onSpotlightSelected!(selected);
    } else {
      widget.onPlanTap();
    }
  }

  void _onRepoChanged() {
    if (mounted) {
      _loadTrips(refresh: false);
    }
  }

  Future<void> _loadTrips({bool refresh = true}) async {
    try {
      final uid = AuthService().currentUser?.uid;
      final itineraries = await SupabaseItineraryService().getSavedItineraries(
        refresh: refresh,
      );
      if (mounted && uid == AuthService().currentUser?.uid) {
        setState(() {
          _dbSavedTrips = itineraries.map((e) => e.toSavedTrip()).toList();
        });
      }
    } catch (_) {}
  }

  SavedTrip? get _upcomingTrip {
    final userPrefs = TripPreferencesService.storedPreferences;
    if (userPrefs != null &&
        userPrefs.destination != null &&
        userPrefs.destination!.trim().isNotEmpty) {
      return SavedTrip(
        title: '${userPrefs.destination} Smart Schedule',
        isGenerated: true,
        date: 'Active Planned Trip',
        detail: '${userPrefs.numberOfDays ?? 3} days itinerary',
        destination: userPrefs.destination!,
        budget: userPrefs.budgetCategory ?? 'Medium',
        interests: userPrefs.interests,
        totalDays: userPrefs.numberOfDays ?? 3,
      );
    }
    if (_dbSavedTrips.isNotEmpty) {
      return _dbSavedTrips.first;
    }
    return null;
  }

  List<Attraction> get _filteredAttractions {
    final baseList = widget.attractions ?? defaultPopularAttractions;
    return baseList.where((attraction) {
      // 1. Search Query Filter
      if (_searchQuery.isNotEmpty) {
        final q = _searchQuery.toLowerCase();
        final matchName = attraction.name.toLowerCase().contains(q);
        final matchCat = attraction.category.toLowerCase().contains(q);
        final matchDesc =
            attraction.description?.toLowerCase().contains(q) ?? false;
        if (!matchName && !matchCat && !matchDesc) return false;
      }

      // 2. Category Chip Filter
      if (_selectedCategory == 'All') return true;
      final cat = attraction.category.toLowerCase();
      final name = attraction.name.toLowerCase();

      switch (_selectedCategory) {
        case 'Heritage':
          return cat.contains('heritage') ||
              cat.contains('historic') ||
              cat.contains('history') ||
              name.contains('samad') ||
              name.contains('stadthuys') ||
              name.contains('street art');
        case 'Skyline':
          return name.contains('twin towers') ||
              name.contains('klcc') ||
              name.contains('tower') ||
              name.contains('bridge') ||
              cat.contains('architecture') ||
              cat.contains('sights');
        case 'Culture':
          return cat.contains('culture') ||
              cat.contains('art') ||
              cat.contains('market') ||
              cat.contains('food') ||
              name.contains('alor') ||
              name.contains('lane') ||
              name.contains('batu');
        case 'Sacred':
          return cat.contains('religion') ||
              cat.contains('temple') ||
              cat.contains('mosque') ||
              name.contains('caves') ||
              name.contains('samad');
        default:
          return true;
      }
    }).toList();
  }

  void _showFeaturedStory(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.nightSurface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.sizeOf(ctx).height * 0.9,
            ),
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Center(
                    child: Container(
                      width: 42,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Colors.white24,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 18),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: Image.asset(
                      'assets/recognition/featured_sultan_abdul_samad.png',
                      height: 180,
                      width: double.infinity,
                      fit: BoxFit.cover,
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'CURATED CITY GUIDE · FEATURED STORY',
                    style: TextStyle(
                      color: AppColors.nightAccent,
                      fontSize: 11.5,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.5,
                    ),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'Kuala Lumpur: Where Heritage Meets Horizon',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      fontFamily: 'serif',
                    ),
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'Kuala Lumpur’s story unfolds along the confluence of the Klang and Gombak rivers. What began as a 19th-century tin-mining outpost has blossomed into one of Southeast Asia’s most captivating metropolises.\n\n'
                    'From Moorish copper domes and Art Deco market halls to the soaring twin spires of steel and glass, every district tells a tale of vibrant convergence. Wander Petaling Street at dawn for kaya toast and kopi tarik, marvel at the sacred rainbow steps of Batu Caves, and finish your night watching the musical fountains dance under the illuminated skyline of KLCC.',
                    style: TextStyle(
                      color: AppColors.nightBody,
                      fontSize: 14,
                      height: 1.5,
                    ),
                  ),
                  const SizedBox(height: 24),
                  ElevatedButton(
                    onPressed: () {
                      Navigator.pop(ctx);
                      widget.onPlanTap();
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.nightAccent,
                      foregroundColor: AppColors.onNightAccent,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    child: const Text(
                      'Plan a Trip to Kuala Lumpur',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                      ),
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

  @override
  Widget build(BuildContext context) {
    final upcomingTrip = _upcomingTrip;
    final spotlightSection = ListenableBuilder(
      listenable: _spotlightStore,
      builder: (context, _) {
        if (widget.showSpotlightOnlyWhenDismissed &&
            !_spotlightStore.isDismissed) {
          return const SizedBox.shrink();
        }
        return Padding(
          padding: const EdgeInsets.only(bottom: 16),
          child: DestinationSpotlightCard(
            dismissed: _spotlightStore.isDismissed,
            featured: _spotlightStore.featuredDestination,
            onChooseDestinations: _openSpotlightPicker,
            onDismiss: () => _spotlightStore.setDismissed(true),
          ),
        );
      },
    );
    if (widget.discoveryHeaderOnly) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          HeroPanel(
            onSearchTap: widget.onPlanTap,
            onAssistantTap: widget.onAssistantTap,
            onFeaturedTap: () => _showFeaturedStory(context),
            showSearch: false,
          ),
          const SizedBox(height: 16),
          spotlightSection,
          _MyTripsCard(onTap: widget.onItineraryTap),
          const SizedBox(height: 18),
          if (upcomingTrip != null) ...[
            TripCard(
              trip: upcomingTrip,
              onTap: widget.onItineraryTap,
              isDark: true,
            ),
            const SizedBox(height: 18),
          ],
          _CommunitySection(
            onOpenCommunity:
                widget.onCommunityTap ??
                () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const CommunityFeedScreen(),
                    ),
                  );
                },
          ),
          const SizedBox(height: 20),
        ],
      );
    }
    final filteredAttractions = _filteredAttractions;

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 28),
      children: [
        // Hero Curated City Guide Panel ("design box") with integrated Search bar
        HeroPanel(
          onSearchTap: widget.onPlanTap,
          onAssistantTap: widget.onAssistantTap,
          onFeaturedTap: () => _showFeaturedStory(context),
        ),
        const SizedBox(height: 16),
        spotlightSection,
        const SizedBox(height: 16),

        // Filter Categories Chips
        _CategoryFilterChips(
          categories: _categories,
          selectedCategory: _selectedCategory,
          onSelect: (cat) => setState(() => _selectedCategory = cat),
        ),
        const SizedBox(height: 20),

        // My Trips Card
        _MyTripsCard(onTap: widget.onItineraryTap),
        const SizedBox(height: 18),

        // Active Planned Trip Card if exists
        if (upcomingTrip != null) ...[
          TripCard(
            trip: upcomingTrip,
            onTap: widget.onItineraryTap,
            isDark: true,
          ),
          const SizedBox(height: 20),
        ],

        // "From the Community" Section
        _CommunitySection(
          onOpenCommunity: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const CommunityFeedScreen()),
            );
          },
        ),
        const SizedBox(height: 24),

        // "Landmarks to explore" Section
        PopularAttractionsSection(
          onSeeAllTap: widget.onRouteTap,
          attractions: filteredAttractions,
          title: 'Landmarks to explore',
          actionLabel: '${filteredAttractions.length} places',
          isDarkTheme: true,
        ),
        const SizedBox(height: 20),
      ],
    );
  }
}

/// Profile and trip summary for the home screen.
class HeroPanel extends StatelessWidget {
  const HeroPanel({
    super.key,
    required this.onSearchTap,
    this.onAssistantTap,
    this.onFeaturedTap,
    this.showSearch = true,
  });

  final VoidCallback onSearchTap;
  final VoidCallback? onAssistantTap;
  final VoidCallback? onFeaturedTap;
  final bool showSearch;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AnimatedBuilder(
          animation: AuthService(),
          builder: (context, _) {
            final user = AuthService().currentUser;
            return ClipRRect(
              borderRadius: BorderRadius.circular(20),
              child: Stack(
                children: [
                  Positioned.fill(
                    child: Image.asset(
                      'assets/recognition/explore_hero_langkawi.png',
                      fit: BoxFit.cover,
                      alignment: Alignment.center,
                      excludeFromSemantics: true,
                      errorBuilder: (_, _, _) =>
                          const ColoredBox(color: AppColors.nightRaised),
                    ),
                  ),
                  Positioned.fill(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            Colors.black.withValues(alpha: .48),
                            Colors.black.withValues(alpha: .36),
                            Colors.black.withValues(alpha: .72),
                          ],
                        ),
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Material(
                          color: Colors.transparent,
                          child: InkWell(
                            borderRadius: BorderRadius.circular(12),
                            onTap: user == null
                                ? null
                                : () => Navigator.of(context).push(
                                    MaterialPageRoute<void>(
                                      builder: (_) => const ProfilePage(),
                                    ),
                                  ),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(vertical: 8),
                              child: Row(
                                children: [
                                  CircleAvatar(
                                    radius: 36,
                                    backgroundColor: Colors.white,
                                    child: CircleAvatar(
                                      radius: 33,
                                      backgroundColor: AppColors.nightRaised,
                                      foregroundImage: user == null
                                          ? null
                                          : ProfileAvatarService.imageProvider(
                                              user.avatarUrl,
                                            ),
                                      onForegroundImageError:
                                          user != null &&
                                              user.avatarUrl.isNotEmpty
                                          ? (_, _) {}
                                          : null,
                                      child: const Icon(
                                        Icons.person,
                                        size: 34,
                                        color: Colors.white,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 16),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          user?.name ?? context.l10n.myProfile,
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontSize: 22,
                                            fontWeight: FontWeight.w900,
                                          ),
                                        ),
                                        const SizedBox(height: 6),
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 12,
                                            vertical: 5,
                                          ),
                                          decoration: BoxDecoration(
                                            color: AppColors.nightAccent,
                                            borderRadius: BorderRadius.circular(
                                              20,
                                            ),
                                          ),
                                          child: Text(
                                            user?.travelStyle.isNotEmpty == true
                                                ? user!.travelStyle
                                                : context.l10n.traveler,
                                            style: const TextStyle(
                                              color: AppColors.onNightAccent,
                                              fontWeight: FontWeight.w700,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  if (user != null) const _ExploreArrow(),
                                ],
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 24),
                        Row(
                          children: [
                            Expanded(
                              child: SizedBox(
                                height: 42,
                                child: ElevatedButton(
                                  onPressed: onFeaturedTap ?? onSearchTap,
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.white,
                                    foregroundColor: AppColors.onNightAccent,
                                    elevation: 0,
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                    ),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(22),
                                    ),
                                  ),
                                  child: const FittedBox(
                                    fit: BoxFit.scaleDown,
                                    child: Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Text(
                                          'Featured story',
                                          style: TextStyle(
                                            fontSize: 13,
                                            fontWeight: FontWeight.w700,
                                          ),
                                        ),
                                        SizedBox(width: 4),
                                        Icon(
                                          Icons.arrow_outward_rounded,
                                          size: 16,
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: SizedBox(
                                height: 42,
                                child: ElevatedButton(
                                  onPressed: onAssistantTap ?? onSearchTap,
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: AppColors.nightAccent,
                                    foregroundColor: AppColors.onNightAccent,
                                    elevation: 0,
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                    ),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(22),
                                    ),
                                  ),
                                  child: FittedBox(
                                    fit: BoxFit.scaleDown,
                                    child: Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        const Text(
                                          'Ask AI Assistant',
                                          style: TextStyle(
                                            fontSize: 13,
                                            fontWeight: FontWeight.w700,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
        ),
        if (showSearch) ...[
          const SizedBox(height: 16),
          // Search bar matching the dark screenshot styling
          Material(
            color: AppColors.nightSurface,
            borderRadius: BorderRadius.circular(16),
            child: InkWell(
              borderRadius: BorderRadius.circular(16),
              onTap: onSearchTap,
              child: Container(
                constraints: const BoxConstraints(minHeight: 48),
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                decoration: BoxDecoration(
                  color: AppColors.nightSurface,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.nightLine, width: 1.2),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.search_rounded,
                      color: AppColors.nightMuted,
                      size: 22,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        context.l10n.whereToNext,
                        style: const TextStyle(
                          color: AppColors.nightMuted,
                          fontSize: 14,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }
}

/// Filter chips row for categories: [All], [Heritage], [Skyline], [Culture], [Sacred].
class _CategoryFilterChips extends StatelessWidget {
  const _CategoryFilterChips({
    required this.categories,
    required this.selectedCategory,
    required this.onSelect,
  });

  final List<String> categories;
  final String selectedCategory;
  final ValueChanged<String> onSelect;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: categories.map((cat) {
          final isSelected = cat == selectedCategory;
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                borderRadius: BorderRadius.circular(12),
                onTap: () => onSelect(cat),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 18,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? AppColors.nightAccent
                        : AppColors.nightSurface,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isSelected
                          ? AppColors.nightAccent
                          : AppColors.nightLine,
                      width: 1.2,
                    ),
                  ),
                  child: Text(
                    cat,
                    style: TextStyle(
                      color: isSelected
                          ? AppColors.nightSurface
                          : AppColors.nightMuted,
                      fontSize: 13,
                      fontWeight: isSelected
                          ? FontWeight.w700
                          : FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}

/// Data model for community card posts.
class _CommunitySection extends StatelessWidget {
  const _CommunitySection({required this.onOpenCommunity});

  final VoidCallback onOpenCommunity;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.nightSurface,
      borderRadius: BorderRadius.circular(20),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        key: const ValueKey('home-community'),
        onTap: onOpenCommunity,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Image.asset(
              'assets/recognition/community_hero_penang.png',
              height: 164,
              fit: BoxFit.cover,
              alignment: Alignment.center,
              excludeFromSemantics: true,
              errorBuilder: (_, _, _) => const SizedBox(
                height: 164,
                child: ColoredBox(color: AppColors.nightRaised),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(20),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          communityText(
                            context,
                            'From the Community',
                            '来自社区',
                            'Daripada Komuniti',
                          ),
                          style: const TextStyle(
                            color: AppColors.nightBody,
                            fontSize: 21,
                            fontWeight: FontWeight.w700,
                            fontFamily: 'serif',
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          communityText(
                            context,
                            'Travel stories and local tips from fellow travellers.',
                            '看看其他旅友分享的游记和当地贴士。',
                            'Kisah perjalanan dan tip tempatan daripada pengembara lain.',
                          ),
                          style: const TextStyle(
                            color: AppColors.nightMuted,
                            height: 1.4,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  const _ExploreArrow(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MyTripsCard extends StatelessWidget {
  const _MyTripsCard({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.nightSurface,
      borderRadius: BorderRadius.circular(20),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        key: const ValueKey('home-my-trips'),
        onTap: onTap,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Image.asset(
              'assets/recognition/my_trips_cameron_highlands.png',
              height: 164,
              fit: BoxFit.cover,
              excludeFromSemantics: true,
              errorBuilder: (_, _, _) => const SizedBox(
                height: 164,
                child: ColoredBox(color: AppColors.nightRaised),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(20),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          context.l10n.myTrips,
                          style: const TextStyle(
                            color: AppColors.nightBody,
                            fontSize: 21,
                            fontWeight: FontWeight.w700,
                            fontFamily: 'serif',
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          context.l10n.viewSavedItinerariesAndYourCurrentPlan,
                          style: const TextStyle(
                            color: AppColors.nightMuted,
                            height: 1.4,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  const _ExploreArrow(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ExploreArrow extends StatelessWidget {
  const _ExploreArrow();

  @override
  Widget build(BuildContext context) => const Icon(
    Icons.arrow_forward_rounded,
    size: 24,
    color: AppColors.nightAccent,
  );
}
