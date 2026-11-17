import 'package:smart_travel_planner/core/theme/app_colors.dart';
import 'package:flutter/material.dart';
import '../../shared/models/attraction.dart';
import '../places/screens/api_demo_page.dart';
import '../../shared/services/location_service.dart';
import 'community_page.dart';
import 'community_service.dart';
import 'widgets/citylore_post_card.dart';

class CommunityFeedScreen extends StatelessWidget {
  const CommunityFeedScreen({super.key});

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: Text(
        communityText(context, 'Traveler stories', '旅人分享', 'Kisah pengembara'),
      ),
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
  final _community = CommunityService();
  final _pendingReactions = <CommunityPost>{};
  List<CommunityPost> _sharedPosts = [];
  bool _loadingFeed = true;
  bool _feedUnavailable = false;
  String? _feedAccount;
  int _loadVersion = 0;
  String _selectedCategory = 'All';

  @override
  void initState() {
    super.initState();
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
    final feed = await _community.loadFeed();
    if (!mounted ||
        version != _loadVersion ||
        account != _community.accountId) {
      return;
    }
    final posts = feed.rows.map(CommunityPost.fromFeed).toList();
    setState(() {
      _feedAccount = account;
      _sharedPosts = posts;
      _loadingFeed = false;
      _feedUnavailable = feed.unavailable;
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
    final posts = _feedAccount == _community.accountId
        ? _sharedPosts
        : <CommunityPost>[];
    final filteredPosts = posts.where((p) {
      if (_selectedCategory == 'All') return true;
      if (_selectedCategory == 'Saved') return p.saved;
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
            SliverToBoxAdapter(
              child: ListenableBuilder(
                listenable: LocationService(),
                builder: (context, _) => Material(
                  color: Colors.transparent,
                  child: ListTile(
                    leading: const Icon(
                      Icons.location_on_outlined,
                      color: AppColors.nightAccent,
                    ),
                    title: Text(
                      '${LocationService().currentAreaName} Community',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    trailing: const Icon(Icons.keyboard_arrow_down),
                    onTap: () => showModalBottomSheet<void>(
                      context: context,
                      isScrollControlled: true,
                      backgroundColor: Colors.transparent,
                      builder: (_) => const LocationSelectorSheet(),
                    ),
                  ),
                ),
              ),
            ),
            if (_feedUnavailable && posts.isNotEmpty)
              const SliverToBoxAdapter(
                child: Padding(
                  padding: EdgeInsets.symmetric(horizontal: 20, vertical: 6),
                  child: Text(
                    'Offline · Showing cached posts',
                    style: TextStyle(color: AppColors.nightMuted),
                  ),
                ),
              ),
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
                            'Share a Tip or Ask a Question',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                            ),
                          ),
                          SizedBox(height: 3),
                          Text(
                            'Share a local tip, trip story, or question.',
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
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.all(40),
                  child: Center(
                    child: _loadingFeed
                        ? const CircularProgressIndicator()
                        : Text(
                            _feedUnavailable
                                ? communityText(
                                    context,
                                    'Could not load posts. Pull down to retry.',
                                    '暂时无法载入帖子，下拉重试。',
                                    'Siaran gagal dimuatkan. Tarik ke bawah untuk mencuba lagi.',
                                  )
                                : communityText(
                                    context,
                                    'No posts yet.',
                                    '暂无帖子。',
                                    'Tiada siaran lagi.',
                                  ),
                            style: const TextStyle(color: AppColors.nightMuted),
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
          final label = switch (cat) {
            'Local Tip' => 'Local Tips',
            'Trip Log' => 'Trip Logs',
            'Question' => 'Questions',
            'Photo' => 'Photos',
            _ => cat,
          };
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
                label,
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
