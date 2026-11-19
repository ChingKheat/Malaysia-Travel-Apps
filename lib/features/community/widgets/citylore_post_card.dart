import 'package:smart_travel_planner/core/theme/app_colors.dart';
import 'package:flutter/material.dart';
import '../community_page.dart';

/// Shows a community post preview and its available interactions.
class CitylorePostCard extends StatelessWidget {
  const CitylorePostCard({
    super.key,
    required this.post,
    required this.onToggleLike,
    required this.onToggleSave,
    required this.onOpenDetail,
    this.onCommunityShared,
  });

  final CommunityPost post;
  final VoidCallback onToggleLike;
  final VoidCallback onToggleSave;
  final VoidCallback onOpenDetail;
  final VoidCallback? onCommunityShared;
  @override
  Widget build(BuildContext context) {
    final repost = communityRepostParts(post.body);
    const accentColor = AppColors.nightAccent;
    const cardBg = AppColors.nightSurface;
    const borderColor = AppColors.nightLine;
    const textMuted = AppColors.nightMuted;
    const textBody = AppColors.nightMuted;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 1. Author Header Row
          InkWell(
            onTap: () => openCommunityPostAuthor(context, post),
            borderRadius: BorderRadius.circular(12),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: AppColors.nightAccentContainer,
                    border: Border.all(
                      color: accentColor.withValues(alpha: 0.4),
                      width: 1.2,
                    ),
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    post.authorInitials,
                    style: const TextStyle(
                      color: accentColor,
                      fontWeight: FontWeight.w800,
                      fontSize: 13.5,
                    ),
                  ),
                ),
                const SizedBox(width: 11),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        communityAuthorLabel(context, post.author, post.isMine),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 15.5,
                          fontWeight: FontWeight.w700,
                          letterSpacing: -0.2,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        post.date,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: textMuted,
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.nightAccentContainer,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    post.topic,
                    style: const TextStyle(
                      color: accentColor,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 13),
          if (repost != null) ...[
            Text(
              repost.thought,
              style: const TextStyle(
                color: AppColors.nightBody,
                fontSize: 17,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 12),
            InkWell(
              onTap: () => openCommunitySourceAuthor(
                context,
                repost.author,
                repost.sourceId,
                repost.original,
              ),
              child: Text(
                communityText(
                  context,
                  'Shared ${repost.author}’s post',
                  '分享了 ${repost.author} 的帖子',
                  'Berkongsi siaran ${repost.author}',
                ),
                style: const TextStyle(
                  color: accentColor,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            const SizedBox(height: 12),
          ],
          InkWell(
            onTap: onOpenDetail,
            child: Container(
              width: double.infinity,
              padding: repost == null
                  ? EdgeInsets.zero
                  : const EdgeInsets.all(12),
              decoration: repost == null
                  ? null
                  : BoxDecoration(
                      color: AppColors.nightCanvas,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: borderColor),
                    ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    post.place,
                    style: const TextStyle(
                      color: AppColors.nightBody,
                      fontSize: 19,
                      fontWeight: FontWeight.w700,
                      fontFamily: 'serif',
                      height: 1.25,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    repost?.original ?? post.body,
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: textBody,
                      fontSize: 13.5,
                      height: 1.45,
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (post.photoPaths.isNotEmpty) ...[
            const SizedBox(height: 12),
            CommunityPostPhotos(paths: post.photoPaths),
          ],
          const SizedBox(height: 10),

          // Reactions and story actions
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: onToggleLike,
                  icon: Icon(
                    post.liked ? Icons.favorite : Icons.favorite_border_rounded,
                    size: 18,
                  ),
                  label: Text('${post.likesCount}'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: post.liked ? accentColor : textMuted,
                    side: const BorderSide(color: borderColor),
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: onOpenDetail,
                  icon: const Icon(Icons.chat_bubble_outline_rounded, size: 18),
                  label: Text('${post.comments.length}'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: textMuted,
                    side: const BorderSide(color: borderColor),
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Tooltip(
                  message: communityText(
                    context,
                    'Share post',
                    '分享帖子',
                    'Kongsi siaran',
                  ),
                  child: OutlinedButton.icon(
                    onPressed: () => shareCommunityPost(
                      context,
                      post,
                      onCommunityShared: onCommunityShared,
                    ),
                    icon: const Icon(Icons.share_outlined, size: 18),
                    label: Text(
                      communityText(context, 'Share', '分享', 'Kongsi'),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: textMuted,
                      side: const BorderSide(color: borderColor),
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: onOpenDetail,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: accentColor,
                    side: const BorderSide(color: borderColor),
                  ),
                  child: Text(
                    communityText(context, 'Read story', '阅读故事', 'Baca kisah'),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton(
                  onPressed: onToggleSave,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: accentColor,
                    side: BorderSide(
                      color: post.saved ? accentColor : borderColor,
                    ),
                  ),
                  child: Text(
                    post.saved
                        ? communityText(context, 'Saved', '已保存', 'Disimpan')
                        : communityText(context, 'Save', '保存', 'Simpan'),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
