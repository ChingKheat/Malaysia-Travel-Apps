import 'package:smart_travel_planner/core/theme/app_colors.dart';
import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';
import '../../shared/models/attraction.dart';
import '../../shared/data/malaysia_states.dart';
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

bool communityPlaceMatches(String postPlace, String selectedPlace) {
  final post = postPlace.trim().toLowerCase();
  final selected = selectedPlace.trim().toLowerCase();
  return post == selected || post.startsWith('$selected,');
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
  bool _savedOnly = false;
  String? _selectedPlace;

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
      setState(() => _savedOnly = false);
      await _refreshFeed();
    }
  }

  Future<void> _chooseLocation() async {
    MalaysiaStateData state = malaysiaStatesData.first;
    CityArea city = state.areas.first;
    final selected = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.nightSurface,
      builder: (sheetContext) => StatefulBuilder(
        builder: (sheetContext, refresh) => SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  communityText(
                    context,
                    'Choose a place',
                    '选择地点',
                    'Pilih tempat',
                  ),
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<MalaysiaStateData>(
                  initialValue: state,
                  isExpanded: true,
                  decoration: InputDecoration(
                    labelText: communityText(context, 'State', '州属', 'Negeri'),
                  ),
                  items: [
                    for (final item in malaysiaStatesData)
                      DropdownMenuItem(value: item, child: Text(item.name)),
                  ],
                  onChanged: (value) {
                    if (value != null) {
                      refresh(() {
                        state = value;
                        city = value.areas.first;
                      });
                    }
                  },
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<CityArea>(
                  key: ValueKey(state.name),
                  initialValue: city,
                  isExpanded: true,
                  decoration: InputDecoration(
                    labelText: communityText(
                      context,
                      'City or area',
                      '城市或地区',
                      'Bandar atau kawasan',
                    ),
                  ),
                  items: [
                    for (final item in state.areas)
                      DropdownMenuItem(value: item, child: Text(item.name)),
                  ],
                  onChanged: (value) {
                    if (value != null) refresh(() => city = value);
                  },
                ),
                const SizedBox(height: 24),
                FilledButton(
                  onPressed: () {
                    LocationService().updateLocation(
                      LatLng(city.latitude, city.longitude),
                      '${city.name}, ${state.name}',
                      state: state.name,
                    );
                    Navigator.pop(sheetContext, city.name);
                  },
                  child: Text(
                    communityText(
                      context,
                      'Show posts here',
                      '显示这里的帖子',
                      'Tunjuk siaran di sini',
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
    if (mounted && selected != null) setState(() => _selectedPlace = selected);
  }

  Future<void> _showPlaceFilter(List<CommunityPost> posts) async {
    final places =
        posts
            .map((post) => post.place.trim())
            .where((place) => place.isNotEmpty)
            .toSet()
            .toList()
          ..sort();
    final selection = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: AppColors.nightSurface,
      builder: (sheetContext) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 24, 24, 8),
              child: Text(
                communityText(
                  context,
                  'Filter posts by place',
                  '按地点筛选帖子',
                  'Tapis siaran mengikut tempat',
                ),
                style: Theme.of(context).textTheme.titleLarge,
              ),
            ),
            ListTile(
              leading: const Icon(Icons.public),
              title: Text(
                communityText(context, 'All locations', '所有地点', 'Semua lokasi'),
              ),
              onTap: () => Navigator.pop(sheetContext, ''),
            ),
            for (final place in places)
              ListTile(
                leading: const Icon(Icons.place_outlined),
                title: Text(place),
                onTap: () => Navigator.pop(sheetContext, place),
              ),
            ListTile(
              leading: const Icon(Icons.map_outlined),
              title: Text(
                communityText(
                  context,
                  'Choose another location',
                  '选择其他地点',
                  'Pilih lokasi lain',
                ),
              ),
              onTap: () => Navigator.pop(sheetContext, '__choose__'),
            ),
          ],
        ),
      ),
    );
    if (!mounted || selection == null) return;
    if (selection == '__choose__') {
      await _chooseLocation();
    } else {
      setState(() => _selectedPlace = selection.isEmpty ? null : selection);
    }
  }

  Future<void> _openPostDetail(CommunityPost post) async {
    if (_pendingReactions.contains(post)) return;
    await Navigator.of(context).push<bool>(
      MaterialPageRoute<bool>(
        builder: (_) => CommunityPostDetailPage(post: post),
      ),
    );
    if (mounted) await _refreshFeed();
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final posts = _feedAccount == _community.accountId
        ? _sharedPosts
        : <CommunityPost>[];
    final filteredPosts = posts.where((p) {
      if (_selectedPlace != null &&
          !communityPlaceMatches(p.place, _selectedPlace!)) {
        return false;
      }
      if (_savedOnly) return p.saved;
      return true;
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
              child: Container(
                height: 216,
                margin: const EdgeInsets.fromLTRB(16, 4, 16, 4),
                clipBehavior: Clip.antiAlias,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(20),
                  color: AppColors.nightSurface,
                ),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    Image.asset(
                      'assets/recognition/community_hero_penang.png',
                      fit: BoxFit.cover,
                    ),
                    const DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [Colors.transparent, Color(0xED101114)],
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          Text(
                            communityText(
                              context,
                              'Welcome to the community',
                              '欢迎来到社区',
                              'Selamat datang ke komuniti',
                            ),
                            style: const TextStyle(
                              color: Colors.white,
                              fontFamily: 'serif',
                              fontSize: 23,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            communityText(
                              context,
                              'Discover traveller stories and share your own.',
                              '探索旅人故事，也分享你的旅程。',
                              'Temui kisah pengembara dan kongsi pengalaman anda.',
                            ),
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 13,
                            ),
                          ),
                          const SizedBox(height: 12),
                          Align(
                            alignment: Alignment.centerRight,
                            child: FilledButton.icon(
                              key: const ValueKey('citylore-new-post-button'),
                              onPressed: _openComposer,
                              style: FilledButton.styleFrom(
                                minimumSize: const Size(0, 40),
                                maximumSize: const Size(156, 40),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                ),
                              ),
                              icon: const Icon(Icons.add, size: 18),
                              label: Text(
                                communityText(
                                  context,
                                  'New post',
                                  '发布帖子',
                                  'Siaran baharu',
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
                child: Column(
                  children: [
                    SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: OutlinedButton.icon(
                        onPressed: () => _showPlaceFilter(posts),
                        icon: const Icon(Icons.location_on_outlined),
                        label: Row(
                          children: [
                            Expanded(
                              child: Text(
                                _selectedPlace ??
                                    communityText(
                                      context,
                                      'All locations',
                                      '所有地点',
                                      'Semua lokasi',
                                    ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            const Icon(Icons.expand_more),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: OutlinedButton.icon(
                        onPressed: () => setState(
                          () => _savedOnly = !_savedOnly,
                        ),
                        icon: Icon(
                          _savedOnly
                              ? Icons.bookmark_rounded
                              : Icons.bookmark_border_rounded,
                        ),
                        label: Row(
                          children: [
                            Expanded(
                              child: Text(
                                communityText(
                                  context,
                                  'Saved posts',
                                  '已保存的帖子',
                                  'Siaran disimpan',
                                ),
                              ),
                            ),
                            if (_savedOnly)
                              const Icon(Icons.check),
                          ],
                        ),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: _savedOnly
                              ? AppColors.nightAccent
                              : null,
                        ),
                      ),
                    ),
                  ],
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

            // Post Feed Cards
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
                                : _selectedPlace != null || _savedOnly
                                ? communityText(
                                    context,
                                    'No posts match this filter.',
                                    '没有符合筛选条件的帖子。',
                                    'Tiada siaran yang sepadan dengan tapisan ini.',
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
                    onCommunityShared: () => _refreshFeed(),
                  );
                },
              ),

          ],
        ),
      ),
    );
  }
}
