import 'package:smart_travel_planner/core/theme/app_colors.dart';
import 'package:flutter/material.dart';
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
  if (selected.isEmpty) return true;
  if (post == selected) return true;
  if ((selected == 'kl' && post.contains('kuala lumpur')) ||
      (post == 'kl' && selected.contains('kuala lumpur'))) {
    return true;
  }
  if (post.startsWith('$selected,') || post.startsWith('$selected ')) return true;
  if (post.endsWith(', $selected') || post.endsWith(' $selected')) return true;
  final segments = post.split(RegExp(r'[,/|-]')).map((s) => s.trim()).toSet();
  if (segments.contains(selected)) return true;
  return post.contains(selected);
}

String formatCommunityPlaceName(String place) {
  final trimmed = place.trim();
  if (trimmed.isEmpty) return trimmed;
  return trimmed.split(' ').map((word) {
    if (word.isEmpty) return word;
    final hasComma = word.endsWith(',');
    final cleanWord = hasComma ? word.substring(0, word.length - 1) : word;
    if (cleanWord.isEmpty) return word;
    final capitalized =
        cleanWord[0].toUpperCase() + cleanWord.substring(1).toLowerCase();
    return hasComma ? '$capitalized,' : capitalized;
  }).join(' ');
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


  Future<void> _showPlaceFilter(List<CommunityPost> posts) async {
    const federalTerritories = {'Kuala Lumpur', 'Putrajaya', 'Labuan'};
    final statesList = malaysiaStatesData
        .map((s) => s.name)
        .where((name) => !federalTerritories.contains(name))
        .toSet()
        .toList()
      ..sort();
    final territoryList = federalTerritories.toList()..sort();

    // Precalculate post counts for each Malaysian state & territory
    final stateCounts = <String, int>{};
    for (final name in [...statesList, ...territoryList]) {
      final count = posts
          .where((p) => communityPlaceMatches(p.place, name))
          .length;
      stateCounts[name] = count;
    }

    String searchQuery = '';

    final selection = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.nightSurface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetContext) => StatefulBuilder(
        builder: (sheetContext, setSheetState) {
          final query = searchQuery.trim().toLowerCase();
          bool matchesQuery(String name) {
            if (query.isEmpty) return true;
            final n = name.toLowerCase();
            if (n.contains(query)) return true;
            if (query == 'kl' && n.contains('kuala lumpur')) return true;
            if ((query == 'pulau pinang' || query == 'penang') &&
                (n.contains('penang') || n.contains('pulau pinang'))) {
              return true;
            }
            if ((query == 'melaka' || query == 'malacca') &&
                (n.contains('melaka') || n.contains('malacca'))) {
              return true;
            }
            return false;
          }

          final filteredStates = statesList.where(matchesQuery).toList();
          final filteredTerritories =
              territoryList.where(matchesQuery).toList();

          Widget buildPlaceItem(String name, {required bool isTerritory}) {
            final isSelected = _selectedPlace != null &&
                communityPlaceMatches(_selectedPlace!, name);
            final count = stateCounts[name] ?? 0;
            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
              child: ListTile(
                dense: true,
                tileColor: isSelected
                    ? AppColors.nightAccent.withValues(alpha: 0.12)
                    : null,
                hoverColor: AppColors.nightAccent.withValues(alpha: 0.08),
                splashColor: AppColors.nightAccent.withValues(alpha: 0.16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: BorderSide(
                    color: isSelected
                        ? AppColors.nightAccent.withValues(alpha: 0.55)
                        : Colors.transparent,
                    width: 1.2,
                  ),
                ),
                leading: Icon(
                  isTerritory
                      ? Icons.apartment_outlined
                      : Icons.place_outlined,
                  color: isSelected
                      ? AppColors.nightAccent
                      : (count > 0 ? Colors.white70 : AppColors.nightMuted),
                ),
                title: Text(
                  name,
                  style: TextStyle(
                    fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                    color: isSelected
                        ? AppColors.nightAccent
                        : (count > 0 ? Colors.white : AppColors.nightMuted),
                  ),
                ),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (count > 0)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? AppColors.nightAccent.withValues(alpha: 0.22)
                              : AppColors.nightCanvas,
                          borderRadius: BorderRadius.circular(10),
                          border: isSelected
                              ? Border.all(
                                  color: AppColors.nightAccent
                                      .withValues(alpha: 0.35),
                                  width: 1,
                                )
                              : null,
                        ),
                        child: Text(
                          '$count',
                          style: TextStyle(
                            color: isSelected
                                ? AppColors.nightAccent
                                : Colors.white70,
                            fontSize: 12,
                            fontWeight: isSelected
                                ? FontWeight.w700
                                : FontWeight.w600,
                          ),
                        ),
                      ),
                    if (isSelected) ...[
                      const SizedBox(width: 8),
                      const Icon(
                        Icons.check_rounded,
                        color: AppColors.nightAccent,
                        size: 20,
                      ),
                    ],
                  ],
                ),
                onTap: () => Navigator.pop(sheetContext, name),
              ),
            );
          }

          Widget buildSectionHeader(String title) => Padding(
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 6),
                child: Text(
                  title,
                  style: const TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.8,
                    color: AppColors.nightMuted,
                  ),
                ),
              );

          return SafeArea(
            child: SizedBox(
              height: MediaQuery.sizeOf(context).height * 0.72,
              child: Column(
                children: [
                  const SizedBox(height: 12),
                  Center(
                    child: Container(
                      width: 36,
                      height: 4,
                      decoration: BoxDecoration(
                        color: AppColors.nightLine,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 10, 20, 8),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          communityText(
                            context,
                            'Filter posts by place',
                            '按地点筛选帖子',
                            'Tapis siaran mengikut tempat',
                          ),
                          style:
                              Theme.of(context).textTheme.titleLarge?.copyWith(
                                    fontSize: 18,
                                    fontWeight: FontWeight.w700,
                                  ),
                        ),
                        if (_selectedPlace != null)
                          TextButton(
                            onPressed: () => Navigator.pop(sheetContext, ''),
                            style: TextButton.styleFrom(
                              visualDensity: VisualDensity.compact,
                              foregroundColor: AppColors.nightAccent,
                            ),
                            child: Text(
                              communityText(
                                context,
                                'Reset',
                                '重置',
                                'Tetapkan semula',
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                  Padding(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                    child: TextField(
                      style:
                          const TextStyle(fontSize: 14, color: Colors.white),
                      decoration: InputDecoration(
                        hintText: communityText(
                          context,
                          'Search state or territory (e.g. Penang, KL)...',
                          '搜索州属或直辖区（如：槟城、KL）...',
                          'Cari negeri atau wilayah (cth. Pulau Pinang, KL)...',
                        ),
                        hintStyle: const TextStyle(
                          color: AppColors.nightMuted,
                          fontSize: 13,
                        ),
                        prefixIcon: const Icon(
                          Icons.search,
                          size: 20,
                          color: AppColors.nightMuted,
                        ),
                        filled: true,
                        fillColor: AppColors.nightCanvas,
                        contentPadding: const EdgeInsets.symmetric(
                          vertical: 0,
                          horizontal: 12,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none,
                        ),
                      ),
                      onChanged: (q) =>
                          setSheetState(() => searchQuery = q),
                    ),
                  ),
                  const SizedBox(height: 6),
                  const Divider(height: 1, color: AppColors.nightLine),
                  Expanded(
                    child: ListView(
                      children: [
                        if (query.isEmpty) ...[
                          Padding(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 2),
                            child: ListTile(
                              dense: true,
                              tileColor: _selectedPlace == null
                                  ? AppColors.nightAccent.withValues(alpha: 0.12)
                                  : null,
                              hoverColor: AppColors.nightAccent.withValues(alpha: 0.08),
                              splashColor: AppColors.nightAccent.withValues(alpha: 0.16),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                                side: BorderSide(
                                  color: _selectedPlace == null
                                      ? AppColors.nightAccent
                                          .withValues(alpha: 0.55)
                                      : Colors.transparent,
                                  width: 1.2,
                                ),
                              ),
                              leading: Icon(
                                Icons.public,
                                color: _selectedPlace == null
                                    ? AppColors.nightAccent
                                    : AppColors.nightMuted,
                              ),
                              title: Text(
                                communityText(
                                  context,
                                  'All locations',
                                  '所有地点',
                                  'Semua lokasi',
                                ),
                                style: TextStyle(
                                  fontWeight: _selectedPlace == null
                                      ? FontWeight.w700
                                      : FontWeight.w500,
                                  color: _selectedPlace == null
                                      ? AppColors.nightAccent
                                      : Colors.white,
                                ),
                              ),
                              trailing: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 2,
                                    ),
                                    decoration: BoxDecoration(
                                      color: _selectedPlace == null
                                          ? AppColors.nightAccent
                                              .withValues(alpha: 0.22)
                                          : AppColors.nightCanvas,
                                      borderRadius: BorderRadius.circular(10),
                                      border: _selectedPlace == null
                                          ? Border.all(
                                              color: AppColors.nightAccent
                                                  .withValues(alpha: 0.35),
                                              width: 1,
                                            )
                                          : null,
                                    ),
                                    child: Text(
                                      '${posts.length}',
                                      style: TextStyle(
                                        color: _selectedPlace == null
                                            ? AppColors.nightAccent
                                            : Colors.white70,
                                        fontSize: 12,
                                        fontWeight: _selectedPlace == null
                                            ? FontWeight.w700
                                            : FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                  if (_selectedPlace == null) ...[
                                    const SizedBox(width: 8),
                                    const Icon(
                                      Icons.check_rounded,
                                      color: AppColors.nightAccent,
                                      size: 20,
                                    ),
                                  ],
                                ],
                              ),
                              onTap: () => Navigator.pop(sheetContext, ''),
                            ),
                          ),
                          Builder(
                            builder: (context) {
                              final current =
                                  LocationService().destinationState;
                              final isCurrentSelected = _selectedPlace != null &&
                                  communityPlaceMatches(
                                      _selectedPlace!, current);
                              final currentCount = stateCounts[current] ?? 0;
                              return Padding(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 16, vertical: 2),
                                child: ListTile(
                                  dense: true,
                                  tileColor: isCurrentSelected
                                      ? AppColors.nightAccent.withValues(alpha: 0.12)
                                      : null,
                                  hoverColor: AppColors.nightAccent.withValues(alpha: 0.08),
                                  splashColor: AppColors.nightAccent.withValues(alpha: 0.16),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    side: BorderSide(
                                      color: isCurrentSelected
                                          ? AppColors.nightAccent
                                              .withValues(alpha: 0.55)
                                          : Colors.transparent,
                                      width: 1.2,
                                    ),
                                  ),
                                  leading: Icon(
                                    Icons.my_location,
                                    color: isCurrentSelected
                                        ? AppColors.nightAccent
                                        : AppColors.nightMuted,
                                  ),
                                  title: Text(
                                    communityText(
                                      context,
                                      'Current location ($current)',
                                      '当前位置 ($current)',
                                      'Lokasi semasa ($current)',
                                    ),
                                    style: TextStyle(
                                      fontWeight: isCurrentSelected
                                          ? FontWeight.w700
                                          : FontWeight.w500,
                                      color: isCurrentSelected
                                          ? AppColors.nightAccent
                                          : Colors.white,
                                    ),
                                  ),
                                  trailing: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      if (currentCount > 0)
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 8,
                                            vertical: 2,
                                          ),
                                          decoration: BoxDecoration(
                                            color: isCurrentSelected
                                                ? AppColors.nightAccent
                                                    .withValues(alpha: 0.22)
                                                : AppColors.nightCanvas,
                                            borderRadius:
                                                BorderRadius.circular(10),
                                            border: isCurrentSelected
                                                ? Border.all(
                                                    color: AppColors.nightAccent
                                                        .withValues(alpha: 0.35),
                                                    width: 1,
                                                  )
                                                : null,
                                          ),
                                          child: Text(
                                            '$currentCount',
                                            style: TextStyle(
                                              color: isCurrentSelected
                                                  ? AppColors.nightAccent
                                                  : Colors.white70,
                                              fontSize: 12,
                                              fontWeight: isCurrentSelected
                                                  ? FontWeight.w700
                                                  : FontWeight.w600,
                                            ),
                                          ),
                                        ),
                                      if (isCurrentSelected) ...[
                                        const SizedBox(width: 8),
                                        const Icon(
                                          Icons.check_rounded,
                                          color: AppColors.nightAccent,
                                          size: 20,
                                        ),
                                      ],
                                    ],
                                  ),
                                  onTap: () =>
                                      Navigator.pop(sheetContext, current),
                                ),
                              );
                            },
                          ),
                          const Divider(
                              height: 1, color: AppColors.nightLine),
                        ],
                        if (filteredStates.isNotEmpty) ...[
                          buildSectionHeader(
                            communityText(
                              context,
                              'STATES (13)',
                              '州属 (13)',
                              'NEGERI (13)',
                            ),
                          ),
                          for (final stateName in filteredStates)
                            buildPlaceItem(stateName, isTerritory: false),
                        ],
                        if (filteredTerritories.isNotEmpty) ...[
                          const SizedBox(height: 6),
                          const Divider(
                              height: 1, color: AppColors.nightLine),
                          buildSectionHeader(
                            communityText(
                              context,
                              'FEDERAL TERRITORIES (3)',
                              '联邦直辖区 (3)',
                              'WILAYAH PERSEKUTUAN (3)',
                            ),
                          ),
                          for (final territoryName in filteredTerritories)
                            buildPlaceItem(territoryName, isTerritory: true),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
    if (!mounted || selection == null) return;
    setState(() => _selectedPlace = selection.isEmpty ? null : selection);
  }

  Widget _buildEmptyFeedState() {
    if (_loadingFeed) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 60),
        child: Center(child: CircularProgressIndicator()),
      );
    }

    if (_feedUnavailable) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 48),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.nightSurface,
                border: Border.all(color: AppColors.nightLine),
              ),
              child: const Icon(
                Icons.cloud_off_outlined,
                size: 26,
                color: AppColors.nightMuted,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              communityText(
                context,
                'Could not load posts.',
                '无法载入帖子。',
                'Gagal memuatkan siaran.',
              ),
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              communityText(
                context,
                'Pull down or tap below to try again.',
                '下拉或点击下方按钮重试。',
                'Tarik ke bawah atau tekan di bawah untuk cuba lagi.',
              ),
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 13,
                color: AppColors.nightMuted,
              ),
            ),
            const SizedBox(height: 16),
            OutlinedButton.icon(
              onPressed: _refreshFeed,
              icon: const Icon(Icons.refresh, size: 18),
              label: Text(
                communityText(context, 'Retry', '重试', 'Cuba lagi'),
              ),
            ),
          ],
        ),
      );
    }

    // When filtered by state/location
    if (_selectedPlace != null) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.nightAccentContainer.withValues(alpha: 0.35),
                border: Border.all(
                  color: AppColors.nightAccent.withValues(alpha: 0.4),
                  width: 1.2,
                ),
              ),
              child: const Icon(
                Icons.location_city_outlined,
                size: 28,
                color: AppColors.nightAccent,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              communityText(
                context,
                'No stories from $_selectedPlace yet',
                '$_selectedPlace 暂无旅行故事',
                'Tiada kisah di $_selectedPlace lagi',
              ),
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 16.5,
                fontWeight: FontWeight.w700,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              communityText(
                context,
                'Be the first traveller to share tips, hidden gems, or photos from this state.',
                '成为第一位分享 $_selectedPlace 攻略、美景或照片的旅友。',
                'Jadilah pengembara pertama berkongsi tip atau foto dari negeri ini.',
              ),
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 13,
                color: AppColors.nightMuted,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                OutlinedButton.icon(
                  onPressed: () => setState(() => _selectedPlace = null),
                  icon: const Icon(Icons.clear, size: 16),
                  label: Text(
                    communityText(
                      context,
                      'Clear filter',
                      '清除筛选',
                      'Kosongkan tapisan',
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                FilledButton.icon(
                  onPressed: _openComposer,
                  icon: const Icon(Icons.add, size: 16),
                  label: Text(
                    communityText(
                      context,
                      'Share story',
                      '分享故事',
                      'Kongsi kisah',
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      );
    }

    // When filtered by saved
    if (_savedOnly) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.nightAccentContainer.withValues(alpha: 0.35),
                border: Border.all(
                  color: AppColors.nightAccent.withValues(alpha: 0.4),
                  width: 1.2,
                ),
              ),
              child: const Icon(
                Icons.bookmark_border_rounded,
                size: 28,
                color: AppColors.nightAccent,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              communityText(
                context,
                'No saved posts yet',
                '暂无已保存的帖子',
                'Tiada siaran disimpan lagi',
              ),
              style: const TextStyle(
                fontSize: 16.5,
                fontWeight: FontWeight.w700,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              communityText(
                context,
                'Tap the bookmark icon on any post to save it for your itinerary.',
                '点击帖子上的书签图标即可将其保存，方便规划行程。',
                'Tekan ikon penanda pada mana-mana siaran untuk menyimpannya.',
              ),
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 13,
                color: AppColors.nightMuted,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 20),
            OutlinedButton(
              onPressed: () => setState(() => _savedOnly = false),
              child: Text(
                communityText(
                  context,
                  'View all posts',
                  '查看所有帖子',
                  'Lihat semua siaran',
                ),
              ),
            ),
          ],
        ),
      );
    }

    // Default completely empty feed
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppColors.nightSurface,
              border: Border.all(color: AppColors.nightLine),
            ),
            child: const Icon(
              Icons.forum_outlined,
              size: 28,
              color: AppColors.nightMuted,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            communityText(
              context,
              'No posts yet.',
              '暂无帖子。',
              'Tiada siaran lagi.',
            ),
            style: const TextStyle(
              fontSize: 16.5,
              fontWeight: FontWeight.w700,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            communityText(
              context,
              'Be the first to share your travel story with other travellers.',
              '成为第一个与其他旅友分享旅行故事的人。',
              'Jadilah yang pertama berkongsi pengalaman dengan pengembara lain.',
            ),
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 13,
              color: AppColors.nightMuted,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 20),
          FilledButton.icon(
            onPressed: _openComposer,
            icon: const Icon(Icons.add, size: 16),
            label: Text(
              communityText(
                context,
                'Create a post',
                '发布帖子',
                'Cipta siaran',
              ),
            ),
          ),
        ],
      ),
    );
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
                child: Row(
                  children: [
                    Expanded(
                      child: InkWell(
                        onTap: () => _showPlaceFilter(posts),
                        borderRadius: BorderRadius.circular(12),
                        child: Container(
                          height: 42,
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          decoration: BoxDecoration(
                            color: _selectedPlace != null
                                ? AppColors.nightAccent.withValues(alpha: 0.12)
                                : AppColors.nightSurface,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: _selectedPlace != null
                                  ? AppColors.nightAccent.withValues(alpha: 0.55)
                                  : AppColors.nightLine,
                              width: 1.2,
                            ),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                Icons.location_on_outlined,
                                size: 18,
                                color: _selectedPlace != null
                                    ? AppColors.nightAccent
                                    : AppColors.nightMuted,
                              ),
                              const SizedBox(width: 8),
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
                                  style: TextStyle(
                                    fontSize: 13.5,
                                    fontWeight: _selectedPlace != null
                                        ? FontWeight.w700
                                        : FontWeight.w600,
                                    color: _selectedPlace != null
                                        ? AppColors.nightAccent
                                        : Colors.white,
                                  ),
                                ),
                              ),
                              Icon(
                                Icons.expand_more,
                                size: 20,
                                color: _selectedPlace != null
                                    ? AppColors.nightAccent
                                    : AppColors.nightMuted,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    InkWell(
                      onTap: () => setState(() => _savedOnly = !_savedOnly),
                      borderRadius: BorderRadius.circular(12),
                      child: Container(
                        height: 42,
                        padding: const EdgeInsets.symmetric(horizontal: 14),
                        decoration: BoxDecoration(
                          color: _savedOnly
                              ? AppColors.nightAccent.withValues(alpha: 0.12)
                              : AppColors.nightSurface,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: _savedOnly
                                ? AppColors.nightAccent.withValues(alpha: 0.55)
                                : AppColors.nightLine,
                            width: 1.2,
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              _savedOnly
                                  ? Icons.bookmark_rounded
                                  : Icons.bookmark_border_rounded,
                              size: 18,
                              color: _savedOnly
                                  ? AppColors.nightAccent
                                  : AppColors.nightMuted,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              communityText(
                                context,
                                'Saved posts',
                                '已保存的帖子',
                                'Siaran disimpan',
                              ),
                              style: TextStyle(
                                fontSize: 13.5,
                                fontWeight: _savedOnly
                                    ? FontWeight.w700
                                    : FontWeight.w600,
                                color: _savedOnly
                                    ? AppColors.nightAccent
                                    : Colors.white,
                              ),
                            ),
                            if (_savedOnly) ...[
                              const SizedBox(width: 6),
                              const Icon(
                                Icons.check,
                                size: 16,
                                color: AppColors.nightAccent,
                              ),
                            ],
                          ],
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
                child: _buildEmptyFeedState(),
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
