import 'package:smart_travel_planner/core/theme/app_colors.dart';
import 'package:flutter/material.dart';
import '../../shared/models/attraction.dart';
import '../places/screens/api_demo_page.dart';
import '../places/services/places_service.dart';
import 'community_page.dart';
import 'community_service.dart';
import 'widgets/citylore_post_card.dart';

class CommunityFeedScreen extends StatelessWidget {
  const CommunityFeedScreen({super.key});

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: Text(communityText(context, 'Traveler stories', '旅人分享', 'Kisah pengembara')),
    ),
    body: const ExplorePage(isVisible: true),
  );
}

/// Full-featured Citylore Explorer screen matching the modern dark aesthetic.
/// Features top share prompt, filter pills, and dark editorial feed cards ("design boxes").
class ExplorePage extends StatefulWidget {
  const ExplorePage({super.key, required this.isVisible, this.onPlacesLoaded});

  final bool isVisible;
  final ValueChanged<List<Attraction>>? onPlacesLoaded;

  @override
  State<ExplorePage> createState() => _ExplorePageState();
}

class _ExplorePageState extends State<ExplorePage> {
  final _placesService = PlacesService();
  final _community = CommunityService();
  final _pendingReactions = <CommunityPost>{};
  List<CommunityPost> _sharedPosts = [];
  String? _feedAccount;
  int _loadVersion = 0;
  String _selectedCategory = 'All';

  final List<CommunityPost> _feedPosts = [
    CommunityPost(
      author: 'Amina Rahman',
      authorRole: 'Architect',
      authorLocation: 'Penang',
      timeAgo: '2h ago',
      place: 'Kuala Lumpur',
      area: 'Chinatown Edge',
      topic: 'Local Tip',
      title: 'Early kopi tarik & kaya toast before Central Market opens',
      body:
          'Skip the midday rush by arriving along Jalan Tun H.S. Lee around 08:15. Wooden shutters open onto the street, kaya toast is grilled over charcoal, and the aromatic kopi tarik warms the morning.',
      asset: 'assets/recognition/kaya_toast.jpg',
      relatedLandmark: 'Central Market',
      likesCount: 38,
      saved: true,
      initialComments: [
        'Such a nostalgic spot in KL!',
        'The kaya toast is indeed the best here.',
      ],
    ),
    CommunityPost(
      author: 'Kenji Sato',
      authorRole: 'Photographer',
      authorLocation: 'Tokyo',
      timeAgo: '4h ago',
      place: 'Kuala Lumpur',
      area: 'KLCC Park',
      topic: 'Trip Log',
      title: 'Sunset reflections & fountain symphony at Petronas Towers',
      body:
          'An evening around the Petronas Twin Towers. Leave some time to walk through the park and enjoy the city views.',
      asset: 'assets/recognition/petronas.jpg',
      relatedLandmark: 'Petronas Twin Towers',
      likesCount: 64,
      initialComments: ['Great photo composition!'],
    ),
    CommunityPost(
      author: 'Sarah Jenkins',
      authorRole: 'Backpacker',
      authorLocation: 'Melbourne',
      timeAgo: '6h ago',
      place: 'Selangor',
      area: 'Batu Caves, Selangor',
      topic: 'Local Tip',
      title: 'Morning climb at Batu Caves before the midday sun',
      body:
          'Planning a visit to Batu Caves? Bring drinking water and comfortable shoes for the steps. Arrive right around 07:30 to beat the scorching heat!',
      asset: 'assets/recognition/batu_caves.jpg',
      relatedLandmark: 'Batu Caves',
      likesCount: 42,
    ),
    CommunityPost(
      author: 'Hafiz Zainal',
      authorRole: 'Foodie',
      authorLocation: 'Kuala Lumpur',
      timeAgo: '8h ago',
      place: 'Kuala Lumpur',
      area: 'Kampung Baru',
      topic: 'Photo',
      title: 'Fragrant pandan coconut rice & spicy sambal sotong',
      body:
          'A Malaysian breakfast inspiration: nasi lemak. Ask the stall about ingredients and available options before ordering.',
      asset: 'assets/recognition/nasi_lemak.jpg',
      relatedLandmark: 'Kampung Baru',
      likesCount: 89,
      saved: true,
      initialComments: ['The sambal sotong looks incredibly rich!'],
    ),
    CommunityPost(
      author: 'David Chen',
      authorRole: 'Historian',
      authorLocation: 'Singapore',
      timeAgo: '1d ago',
      place: 'Kuala Lumpur',
      area: 'Merdeka Square',
      topic: 'Question',
      title: 'Best vantage point for Sultan Abdul Samad Building illumination?',
      body:
          'Looking for recommendations on capturing the historic copper domes lit up after dark. Is the riverfront bridge pedestrian-friendly at night?',
      asset: 'assets/recognition/sultan_abdul_samad.jpg',
      relatedLandmark: 'Sultan Abdul Samad Building',
      likesCount: 27,
    ),
  ];

  @override
  void initState() {
    super.initState();
    _loadNearbyPlaces();
    _refreshFeed();
  }

  @override
  void didUpdateWidget(covariant ExplorePage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isVisible && !oldWidget.isVisible) _refreshFeed();
  }

  Future<void> _refreshFeed() async {
    final version = ++_loadVersion;
    final account = _community.accountId;
    final rows = await _community.loadFeed();
    if (!mounted || version != _loadVersion || account != _community.accountId) {
      return;
    }
    final posts = rows.map(CommunityPost.fromFeed).toList();
    setState(() {
      _feedAccount = account;
      _sharedPosts = posts;
    });
  }

  Future<void> _toggleReaction(
    CommunityPost post, {
    required bool bookmark,
  }) async {
    if (!_pendingReactions.add(post)) return;
    try {
      await post.setReaction(
        bookmark: bookmark,
        selected: !(bookmark ? post.saved : post.liked),
      );
      if (mounted) setState(() {});
    } catch (_) {
      if (mounted) showCommunitySyncError(context);
    } finally {
      _pendingReactions.remove(post);
    }
  }

  Future<void> _loadNearbyPlaces() async {
    final onPlacesLoaded = widget.onPlacesLoaded;
    if (onPlacesLoaded == null) return;
    try {
      final page = await _placesService.fetchPage(
        latitude: 3.1408,
        longitude: 101.6932,
      );
      if (mounted) onPlacesLoaded(page.items);
    } catch (_) {}
  }

  Future<void> _openComposer() async {
    final published = await Navigator.of(
      context,
    ).push(MaterialPageRoute<bool>(builder: (_) => const CommunityComposer()));
    if (mounted && published == true) {
      setState(() => _selectedCategory = 'All');
      await _refreshFeed();
    }
  }

  Future<void> _openPostDetail(CommunityPost post) async {
    if (_pendingReactions.contains(post)) return;
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => CommunityPostDetailPage(post: post),
      ),
    );
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    if (_selectedCategory == 'Places & Map') {
      return Column(
        children: [
          _buildFilterBar(),
          Expanded(
            child: ApiDemoPage(
              isVisible: widget.isVisible,
              onPlacesLoaded: widget.onPlacesLoaded,
            ),
          ),
        ],
      );
    }

    final filteredPosts = [
      if (_feedAccount == _community.accountId) ..._sharedPosts,
      ..._feedPosts,
    ].where((p) {
      if (_selectedCategory == 'All') return true;
      if (_selectedCategory == 'Saved') return p.saved;
      if (_selectedCategory == 'Local Tip') {
        return p.topic == 'Local Tip' || p.topic == 'Tips';
      }
      if (_selectedCategory == 'Trip Log') {
        return p.topic == 'Trip Log' || p.topic == 'Sights';
      }
      if (_selectedCategory == 'Question') return p.topic == 'Question';
      if (_selectedCategory == 'Photo') {
        return p.topic == 'Photo' || p.topic == 'Food';
      }
      return p.topic == _selectedCategory;
    }).toList();

    return Container(
      color: AppColors.nightCanvas,
      child: RefreshIndicator(
        onRefresh: _refreshFeed,
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          key: const PageStorageKey('citylore-explorer-feed'),
          slivers: [
            // 1. Share Prompt Card
            SliverToBoxAdapter(
              child: Container(
                margin: const EdgeInsets.fromLTRB(16, 6, 16, 10),
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 14,
                ),
                decoration: BoxDecoration(
                  color: AppColors.nightSurface,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: AppColors.nightLine),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: const [
                          Text(
                            'Share from Kuala Lumpur',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                            ),
                          ),
                          SizedBox(height: 3),
                          Text(
                            'Post a photo, local tip, or itinerary...',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 12,
                              color: AppColors.nightMuted,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 10),
                    Semantics(
                      button: true,
                      label: 'New post',
                      child: Material(
                        color: Colors.transparent,
                        child: InkWell(
                          key: const ValueKey('citylore-new-post-button'),
                          onTap: _openComposer,
                          borderRadius: BorderRadius.circular(12),
                          child: Ink(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 9,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.nightAccent,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: const [
                                Icon(
                                  Icons.add,
                                  size: 16,
                                  color: AppColors.onNightAccent,
                                ),
                                SizedBox(width: 4),
                                Text(
                                  'New post',
                                  style: TextStyle(
                                    color: AppColors.onNightAccent,
                                    fontWeight: FontWeight.w800,
                                    fontSize: 12.5,
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
              ),
            ),

            // 2. Category Filter Chips
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: _buildFilterBar(),
              ),
            ),

            // 3. Post Feed Cards
            if (filteredPosts.isEmpty)
              const SliverToBoxAdapter(
                child: Padding(
                  padding: EdgeInsets.all(40),
                  child: Center(
                    child: Text(
                      'No stories in this topic yet. Be the first to share!',
                      style: TextStyle(color: AppColors.nightMuted),
                    ),
                  ),
                ),
              )
            else
              SliverList.builder(
                itemCount: filteredPosts.length,
                itemBuilder: (context, index) {
                  final post = filteredPosts[index];
                  return CitylorePostCard(
                    post: post,
                    onToggleLike: () => _toggleReaction(post, bookmark: false),
                    onToggleSave: () => _toggleReaction(post, bookmark: true),
                    onOpenDetail: () => _openPostDetail(post),
                    onOpenMessage: post.id == null
                        ? () => showDirectMessageDialog(context, post)
                        : null,
                    onOpenLandmark: post.relatedLandmark == null
                        ? null
                        : () => openLandmarkDetail(context, post),
                  );
                },
              ),

            const SliverToBoxAdapter(child: SizedBox(height: 80)),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterBar() {
    const categories = [
      'All',
      'Local Tip',
      'Trip Log',
      'Question',
      'Photo',
      'Places & Map',
      'Saved',
    ];

    return SizedBox(
      height: 38,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: categories.length,
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final cat = categories[index];
          final selected = _selectedCategory == cat;

          return InkWell(
            onTap: () => setState(() => _selectedCategory = cat),
            borderRadius: BorderRadius.circular(12),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
              decoration: BoxDecoration(
                color: selected
                    ? AppColors.nightAccent
                    : AppColors.nightSurface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: selected ? AppColors.nightAccent : AppColors.nightLine,
                ),
              ),
              alignment: Alignment.center,
              child: Text(
                cat,
                style: TextStyle(
                  color: selected
                      ? AppColors.onNightAccent
                      : AppColors.nightMuted,
                  fontSize: 13,
                  fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
