import 'package:flutter/material.dart';
import 'package:smart_travel_planner/features/auth/services/auth_service.dart';
import 'package:smart_travel_planner/features/community/community_page.dart';
import 'package:smart_travel_planner/features/home/widgets/popular_attractions_section.dart';
import 'package:smart_travel_planner/features/home/widgets/trip_cards.dart';
import 'package:smart_travel_planner/features/itinerary/models/saved_trip.dart';
import 'package:smart_travel_planner/features/itinerary/services/supabase_itinerary_service.dart';
import 'package:smart_travel_planner/features/itinerary/services/trip_preferences_service.dart';
import 'package:smart_travel_planner/features/places/screens/api_retrieval_screen.dart';
import 'package:smart_travel_planner/l10n/localized_labels.dart';
import 'package:smart_travel_planner/shared/models/attraction.dart';
import 'package:smart_travel_planner/shared/widgets/demo_tap.dart';

class HomePage extends StatefulWidget {
  const HomePage({
    super.key,
    required this.onPlanTap,
    required this.onItineraryTap,
    required this.onRouteTap,
    required this.onAssistantTap,
    this.attractions,
  });

  final VoidCallback onPlanTap;
  final VoidCallback onItineraryTap;
  final VoidCallback onRouteTap;
  final VoidCallback onAssistantTap;
  final List<Attraction>? attractions;

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  List<SavedTrip> _dbSavedTrips = [];
  final TextEditingController _searchController = TextEditingController();
  String get _searchQuery => _searchController.text.trim();
  String _selectedCategory = 'All';

  static const _categories = ['All', 'Heritage', 'Skyline', 'Culture', 'Sacred'];

  @override
  void initState() {
    super.initState();
    SupabaseItineraryService().addListener(_onRepoChanged);
    _loadTrips();
  }

  @override
  void dispose() {
    SupabaseItineraryService().removeListener(_onRepoChanged);
    _searchController.dispose();
    super.dispose();
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
        destination: '${userPrefs.destination}, Malaysia',
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
        final matchDesc = attraction.description?.toLowerCase().contains(q) ?? false;
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
      backgroundColor: const Color(0xFF1A1B20),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return DraggableScrollableSheet(
          expand: false,
          initialChildSize: 0.72,
          maxChildSize: 0.9,
          minChildSize: 0.5,
          builder: (_, scrollController) {
            return ListView(
              controller: scrollController,
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
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
                    'assets/recognition/petronas.jpg',
                    height: 180,
                    width: double.infinity,
                    fit: BoxFit.cover,
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  'CURATED CITY GUIDE · FEATURED STORY',
                  style: TextStyle(
                    color: Color(0xFFE5A95C),
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
                    color: Color(0xFFC7CBD6),
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
                    backgroundColor: const Color(0xFFE5A95C),
                    foregroundColor: const Color(0xFF141518),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  child: const Text(
                    'Plan a Trip to Kuala Lumpur',
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _showCommunityPost(BuildContext context, _CommunityItem post) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF1A1B20),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return DraggableScrollableSheet(
          expand: false,
          initialChildSize: 0.65,
          maxChildSize: 0.85,
          minChildSize: 0.45,
          builder: (_, scrollController) {
            return ListView(
              controller: scrollController,
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
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
                const SizedBox(height: 16),
                ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: Image.asset(
                    post.asset,
                    height: 170,
                    width: double.infinity,
                    fit: BoxFit.cover,
                  ),
                ),
                const SizedBox(height: 14),
                Text(
                  post.tag,
                  style: const TextStyle(
                    color: Color(0xFFE5A95C),
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  post.title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    const Icon(Icons.person_pin, color: Colors.white70, size: 16),
                    const SizedBox(width: 6),
                    Text(
                      'Shared by ${post.author}',
                      style: const TextStyle(
                        color: Color(0xFF8F93A0),
                        fontSize: 12.5,
                      ),
                    ),
                    const Spacer(),
                    Icon(Icons.favorite_rounded, color: Colors.pink.shade300, size: 16),
                    const SizedBox(width: 4),
                    Text(
                      '${post.likes}',
                      style: const TextStyle(color: Colors.white70, fontSize: 12),
                    ),
                    const SizedBox(width: 12),
                    const Icon(Icons.chat_bubble_outline_rounded, color: Colors.white70, size: 16),
                    const SizedBox(width: 4),
                    Text(
                      '${post.comments}',
                      style: const TextStyle(color: Colors.white70, fontSize: 12),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Text(
                  post.content,
                  style: const TextStyle(
                    color: Color(0xFFD2D5DD),
                    fontSize: 14,
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 20),
                ElevatedButton.icon(
                  onPressed: () {
                    Navigator.pop(ctx);
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const CommunityPage(showAppBar: true),
                      ),
                    );
                  },
                  icon: const Icon(Icons.forum_outlined, size: 18),
                  label: const Text('View All Community Stories'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFE5A95C),
                    foregroundColor: const Color(0xFF141518),
                    padding: const EdgeInsets.symmetric(vertical: 13),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final upcomingTrip = _upcomingTrip;
    final filteredAttractions = _filteredAttractions;

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 28),
      children: [
        ListenableBuilder(
          listenable: AuthService(),
          builder: (context, _) {
            if (AuthService().currentUser?.isAdmin != true) {
              return const SizedBox.shrink();
            }
            return const Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [_SavedPlacesInspectorBanner(), SizedBox(height: 18)],
            );
          },
        ),

        // Hero Curated City Guide Panel ("design box") with integrated Search bar
        HeroPanel(
          onSearchTap: widget.onPlanTap,
          onAssistantTap: widget.onAssistantTap,
          onFeaturedTap: () => _showFeaturedStory(context),
        ),
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
              MaterialPageRoute(
                builder: (_) => const CommunityPage(showAppBar: true),
              ),
            );
          },
          onPostTap: (post) => _showCommunityPost(context, post),
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

        if (upcomingTrip == null)
          _EmptyTripCard(onPlanTap: widget.onPlanTap),
      ],
    );
  }
}

/// HeroPanel matching the Curated City Guide box in the design screenshot.
class HeroPanel extends StatelessWidget {
  const HeroPanel({
    super.key,
    required this.onSearchTap,
    this.onAssistantTap,
    this.onFeaturedTap,
  });

  final VoidCallback onSearchTap;
  final VoidCallback? onAssistantTap;
  final VoidCallback? onFeaturedTap;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          constraints: const BoxConstraints(minHeight: 285),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: const Color(0xFF282A33), width: 1.2),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.4),
                blurRadius: 18,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(23),
            child: Stack(
              fit: StackFit.passthrough,
              children: [
                // Background Image: Kuala Lumpur Skyline / Petronas Towers at Night
                Positioned.fill(
                  child: Image.asset(
                    'assets/recognition/petronas.jpg',
                    fit: BoxFit.cover,
                    errorBuilder: (_, _, _) => Container(
                      color: const Color(0xFF1E2028),
                      child: const Center(
                        child: Icon(
                          Icons.location_city,
                          color: Colors.white24,
                          size: 64,
                        ),
                      ),
                    ),
                  ),
                ),
                // Multi-stop dark gradient overlay for optimal text readability
                Positioned.fill(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.black.withValues(alpha: 0.35),
                          Colors.black.withValues(alpha: 0.60),
                          Colors.black.withValues(alpha: 0.94),
                        ],
                        stops: const [0.0, 0.45, 1.0],
                      ),
                    ),
                  ),
                ),
                // Foreground Content
                Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 50),
                      // Tag: Curated City Guide · 6 Landmarks
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerLeft,
                        child: Row(
                          children: [
                            Text(
                              context.l10n.smartTravelPlanning2,
                              style: const TextStyle(
                                color: Color(0xFFE5A95C),
                                fontSize: 12.5,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 0.2,
                              ),
                            ),
                            const SizedBox(width: 6),
                            const Text(
                              '· 6 Landmarks',
                              style: TextStyle(
                                color: Color(0xFFE5A95C),
                                fontSize: 12.5,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 6),
                      // Title: Kuala Lumpur
                      const Text(
                        'Kuala Lumpur',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 32,
                          fontWeight: FontWeight.bold,
                          fontFamily: 'serif',
                          height: 1.1,
                        ),
                      ),
                      const SizedBox(height: 8),
                      // Subtitle: Moorish brick domes, Art Deco craft halls...
                      const Text(
                        'Moorish brick domes, Art Deco craft halls, and twin steel spires along the Klang valley.',
                        style: TextStyle(
                          color: Color(0xFFD2D5DD),
                          fontSize: 13,
                          height: 1.4,
                        ),
                      ),
                      const SizedBox(height: 18),
                      // Action buttons row: [Featured story ↗] [✦ Ask AI Assistant]
                      Row(
                        children: [
                          // White pill button: "Featured story ↗"
                          Expanded(
                            child: SizedBox(
                              height: 42,
                              child: ElevatedButton(
                                onPressed: onFeaturedTap ?? onSearchTap,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.white,
                                  foregroundColor: const Color(0xFF141518),
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
                                    mainAxisAlignment: MainAxisAlignment.center,
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
                                      Icon(Icons.arrow_outward_rounded, size: 16),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          // Amber/gold pill button: "✦ Ask AI Assistant"
                          Expanded(
                            child: SizedBox(
                              height: 42,
                              child: ElevatedButton(
                                onPressed: onAssistantTap ?? onSearchTap,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFFE5A95C),
                                  foregroundColor: const Color(0xFF141518),
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
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        Icons.auto_awesome,
                                        size: 15,
                                        color: Color(0xFF141518),
                                      ),
                                      SizedBox(width: 6),
                                      Text(
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
          ),
        ),
        const SizedBox(height: 16),
        // Search bar matching the dark screenshot styling
        Material(
          color: const Color(0xFF1A1B20),
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
                color: const Color(0xFF1A1B20),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFF282A33), width: 1.2),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.search_rounded,
                    color: Color(0xFF757A88),
                    size: 22,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      context.l10n.whereToNext,
                      style: const TextStyle(
                        color: Color(0xFF757A88),
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
                        ? const Color(0xFFE5A95C)
                        : const Color(0xFF1A1B20),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isSelected
                          ? const Color(0xFFE5A95C)
                          : const Color(0xFF282A33),
                      width: 1.2,
                    ),
                  ),
                  child: Text(
                    cat,
                    style: TextStyle(
                      color: isSelected
                          ? const Color(0xFF141518)
                          : const Color(0xFF8F93A0),
                      fontSize: 13,
                      fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
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
class _CommunityItem {
  const _CommunityItem({
    required this.tag,
    required this.title,
    required this.author,
    required this.likes,
    required this.comments,
    required this.asset,
    required this.content,
  });

  final String tag;
  final String title;
  final String author;
  final int likes;
  final int comments;
  final String asset;
  final String content;
}

/// "From the Community" section with horizontal tip cards.
class _CommunitySection extends StatelessWidget {
  const _CommunitySection({
    required this.onOpenCommunity,
    required this.onPostTap,
  });

  final VoidCallback onOpenCommunity;
  final ValueChanged<_CommunityItem> onPostTap;

  static const List<_CommunityItem> _posts = [
    _CommunityItem(
      tag: 'Local Tip · Chinatown Edge',
      title: 'Early kopi tarik & kaya toast before Central...',
      author: 'Amina Rah...',
      likes: 38,
      comments: 2,
      asset: 'assets/recognition/nasi_lemak.jpg',
      content:
          'Wake up early and head to Chinatown for authentic charcoal-toasted kaya bread and smooth kopi tarik before the Central Market crowd arrives. Pair it with half-boiled eggs with dark soy sauce.',
    ),
    _CommunityItem(
      tag: 'Photo · Petaling Street',
      title: 'After-rain lantern reflections at...',
      author: 'Kenji Sato',
      likes: 64,
      comments: 1,
      asset: 'assets/recognition/sultan_abdul_samad.jpg',
      content:
          'Petaling Street after an evening tropical rain turns into a mirror of glowing red lanterns and neon street lights. Truly an atmospheric photography paradise around 7:30 PM.',
    ),
    _CommunityItem(
      tag: 'Guide · Batu Caves',
      title: 'Morning climb before the midday sun & crowd',
      author: 'David C.',
      likes: 52,
      comments: 5,
      asset: 'assets/recognition/batu_caves.jpg',
      content:
          'Take the KTM Komuter directly to Batu Caves. Starting the 272 steps at 7:30 AM means cooler weather and magical morning lighting through the limestone cave ceiling.',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Expanded(
              child: Text(
                'From the Community',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 21,
                  fontWeight: FontWeight.bold,
                  fontFamily: 'serif',
                ),
              ),
            ),
            InkWell(
              onTap: onOpenCommunity,
              borderRadius: BorderRadius.circular(8),
              child: const Padding(
                padding: EdgeInsets.symmetric(horizontal: 4, vertical: 6),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Open Community',
                      style: TextStyle(
                        color: Color(0xFFE5A95C),
                        fontSize: 13.5,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    SizedBox(width: 4),
                    Icon(
                      Icons.arrow_forward_rounded,
                      size: 15,
                      color: Color(0xFFE5A95C),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 228,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: _posts.length,
            separatorBuilder: (_, _) => const SizedBox(width: 14),
            itemBuilder: (context, index) {
              final post = _posts[index];
              return _CommunityPostCard(
                post: post,
                onTap: () => onPostTap(post),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _CommunityPostCard extends StatelessWidget {
  const _CommunityPostCard({
    required this.post,
    required this.onTap,
  });

  final _CommunityItem post;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return DemoTapCard(
      onTap: onTap,
      borderRadius: 16,
      child: Container(
        width: 215,
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          color: const Color(0xFF1A1B20),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFF282A33), width: 1.2),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Post Image
            Expanded(
              child: Image.asset(
                post.asset,
                fit: BoxFit.cover,
                errorBuilder: (_, _, _) => Container(
                  color: const Color(0xFF22242D),
                  child: const Center(
                    child: Icon(Icons.photo, color: Colors.white24, size: 32),
                  ),
                ),
              ),
            ),
            // Post Summary Text
            Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    post.tag,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Color(0xFFE5A95C),
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    post.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      height: 1.3,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          post.author,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Color(0xFF8F93A0),
                            fontSize: 11,
                          ),
                        ),
                      ),
                      const Icon(
                        Icons.favorite_border_rounded,
                        size: 13,
                        color: Color(0xFF8F93A0),
                      ),
                      const SizedBox(width: 3),
                      Text(
                        '${post.likes}',
                        style: const TextStyle(
                          color: Color(0xFF8F93A0),
                          fontSize: 11,
                        ),
                      ),
                      const SizedBox(width: 8),
                      const Icon(
                        Icons.chat_bubble_outline_rounded,
                        size: 13,
                        color: Color(0xFF8F93A0),
                      ),
                      const SizedBox(width: 3),
                      Text(
                        '${post.comments}',
                        style: const TextStyle(
                          color: Color(0xFF8F93A0),
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Admin-only banner on the home screen for inspecting synced place data.
class _SavedPlacesInspectorBanner extends StatelessWidget {
  const _SavedPlacesInspectorBanner();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF1E284A), Color(0xFF2A3B6E)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF3B4E8C), width: 1.2),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.3),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          const CircleAvatar(
            backgroundColor: Colors.white24,
            child: Icon(Icons.api, color: Colors.white),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  context.l10n.savedPlacesInspector,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                  ),
                ),
                Text(
                  context.l10n.viewAdminSyncedPlacesInspectSavedData,
                  style: const TextStyle(color: Colors.white70, fontSize: 12),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const ApiRetrievalScreen()),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFE5A95C),
              foregroundColor: const Color(0xFF141518),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            child: Text(context.l10n.open),
          ),
        ],
      ),
    );
  }
}

class _MyTripsCard extends StatelessWidget {
  const _MyTripsCard({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF1A1B20),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFF282A33), width: 1.2),
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(18),
        child: InkWell(
          key: const ValueKey('home-my-trips'),
          onTap: onTap,
          borderRadius: BorderRadius.circular(18),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFE5A95C).withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Icon(
                    Icons.folder_open_outlined,
                    color: Color(0xFFE5A95C),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        context.l10n.myTrips,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w900,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 5),
                      Text(
                        context.l10n.viewSavedItinerariesAndYourCurrentPlan,
                        style: const TextStyle(
                          color: Color(0xFF8F93A0),
                          fontSize: 13,
                          height: 1.4,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        context.l10n.viewAll,
                        style: const TextStyle(
                          color: Color(0xFFE5A95C),
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                const Icon(Icons.chevron_right, color: Color(0xFFE5A95C)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _EmptyTripCard extends StatelessWidget {
  const _EmptyTripCard({required this.onPlanTap});

  final VoidCallback onPlanTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onPlanTap,
      borderRadius: BorderRadius.circular(18),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFF1A1B20),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: const Color(0xFF282A33), width: 1.2),
        ),
        child: Row(
          children: [
            Container(
              width: 58,
              height: 58,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                color: const Color(0xFFE5A95C).withValues(alpha: 0.12),
              ),
              child: const Icon(
                Icons.add_location_alt_outlined,
                color: Color(0xFFE5A95C),
                size: 28,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    context.l10n.noActiveTripPlanned,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    context.l10n.tapToPlanYourSmartSchedule,
                    style: const TextStyle(
                      color: Color(0xFF8F93A0),
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(
              Icons.arrow_forward_ios,
              size: 16,
              color: Color(0xFF8F93A0),
            ),
          ],
        ),
      ),
    );
  }
}
