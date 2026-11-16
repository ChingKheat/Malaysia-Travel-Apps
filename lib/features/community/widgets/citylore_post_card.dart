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
  });

  final CommunityPost post;
  final VoidCallback onToggleLike;
  final VoidCallback onToggleSave;
  final VoidCallback onOpenDetail;
  @override
  Widget build(BuildContext context) {
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
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: borderColor, width: 1.2),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.45),
            blurRadius: 18,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 1. Author Header Row
          Row(
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
              Text(
                post.topic,
                style: const TextStyle(
                  color: accentColor,
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 13),

          InkWell(
            onTap: onOpenDetail,
            child: Text(
              post.place,
              style: const TextStyle(
                color: AppColors.nightBody,
                fontSize: 19,
                fontWeight: FontWeight.w700,
                fontFamily: 'serif',
                height: 1.25,
                letterSpacing: -0.25,
              ),
            ),
          ),
          const SizedBox(height: 8),

          // 5. Body Text
          Text(
            post.body,
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: textBody,
              fontSize: 13.5,
              height: 1.45,
            ),
          ),
          const SizedBox(height: 10),

          // 6. "View related landmark →" and "Read story"
          Row(
            children: [
              const Spacer(),
              TextButton(
                onPressed: onOpenDetail,
                style: TextButton.styleFrom(
                  foregroundColor: accentColor,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 2,
                  ),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                child: const Text(
                  'Read story',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // 7. Bottom Action Bar
          Row(
            children: [
              Tooltip(
                message: 'Like',
                child: InkWell(
                  onTap: onToggleLike,
                  borderRadius: BorderRadius.circular(16),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 4,
                      vertical: 4,
                    ),
                    child: Row(
                      children: [
                        Icon(
                          post.liked
                              ? Icons.favorite
                              : Icons.favorite_border_rounded,
                          size: 20,
                          color: post.liked
                              ? const Color(0xFFEF4444)
                              : textMuted,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          '${post.likesCount}',
                          style: const TextStyle(
                            color: textMuted,
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Tooltip(
                message: 'Comments',
                child: InkWell(
                  onTap: onOpenDetail,
                  borderRadius: BorderRadius.circular(16),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 4,
                      vertical: 4,
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.chat_bubble_outline_rounded,
                          size: 18,
                          color: textMuted,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          '${post.comments.length}',
                          style: const TextStyle(
                            color: textMuted,
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const Spacer(),
              const SizedBox(width: 8),
              Tooltip(
                message: 'Save post',
                child: InkWell(
                  onTap: onToggleSave,
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 13,
                      vertical: 7.5,
                    ),
                    decoration: BoxDecoration(
                      color: post.saved
                          ? accentColor.withValues(alpha: 0.18)
                          : AppColors.nightRaised,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: post.saved ? accentColor : AppColors.nightLine,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          post.saved
                              ? Icons.bookmark_rounded
                              : Icons.bookmark_border_rounded,
                          size: 14,
                          color: accentColor,
                        ),
                        const SizedBox(width: 5),
                        Text(
                          post.saved ? 'Saved' : 'Save',
                          style: const TextStyle(
                            color: accentColor,
                            fontSize: 12.5,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
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
