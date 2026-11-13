import 'package:flutter/material.dart';
import '../community_page.dart';

/// Editorial dark-themed feed card ("design box") inspired by Citylore.
/// Showcases author info, rich travel media, location/landmark metadata,
/// bold serif title, story preview, and interactive action buttons.
class CitylorePostCard extends StatelessWidget {
  const CitylorePostCard({
    super.key,
    required this.post,
    required this.onToggleLike,
    required this.onToggleSave,
    required this.onOpenDetail,
    required this.onOpenMessage,
    required this.onOpenLandmark,
  });

  final CommunityPost post;
  final VoidCallback onToggleLike;
  final VoidCallback onToggleSave;
  final VoidCallback onOpenDetail;
  final VoidCallback onOpenMessage;
  final VoidCallback onOpenLandmark;

  Widget _buildMedia() {
    final assetPath = post.asset;
    final isAsset = assetPath.startsWith('assets/');

    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: AspectRatio(
        aspectRatio: 16 / 10,
        child: Stack(
          fit: StackFit.expand,
          children: [
            isAsset
                ? Image.asset(
                    assetPath,
                    fit: BoxFit.cover,
                    semanticLabel: post.place,
                    errorBuilder: (_, _, _) => _fallbackImage(),
                  )
                : Image.network(
                    assetPath,
                    fit: BoxFit.cover,
                    semanticLabel: post.place,
                    errorBuilder: (_, _, _) => _fallbackImage(),
                  ),
            Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.black.withValues(alpha: 0.15),
                      Colors.transparent,
                      Colors.black.withValues(alpha: 0.35),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _fallbackImage() {
    return Container(
      color: const Color(0xFF26262B),
      child: const Center(
        child: Icon(
          Icons.image_outlined,
          color: Color(0xFF8E8E95),
          size: 40,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    const goldColor = Color(0xFFE5A93C);
    const cardBg = Color(0xFF19191C);
    const borderColor = Color(0xFF2C2C34);
    const textMuted = Color(0xFF8E8E95);
    const textBody = Color(0xFFA0A0A8);

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
                  color: const Color(0xFF2B2218),
                  border: Border.all(
                    color: goldColor.withValues(alpha: 0.4),
                    width: 1.2,
                  ),
                ),
                alignment: Alignment.center,
                child: Text(
                  post.authorInitials,
                  style: const TextStyle(
                    color: goldColor,
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
                      post.author,
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
                      post.authorSubtitle,
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
                  color: goldColor,
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 13),

          // 2. Media Image
          InkWell(
            onTap: onOpenDetail,
            borderRadius: BorderRadius.circular(16),
            child: _buildMedia(),
          ),
          const SizedBox(height: 13),

          // 3. Eyebrow Tag / Area and Place
          Row(
            children: [
              if (post.area.isNotEmpty) ...[
                Text(
                  post.area,
                  style: const TextStyle(
                    color: textMuted,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.2,
                  ),
                ),
                const SizedBox(width: 6),
                const Text(
                  '·',
                  style: TextStyle(color: textMuted, fontSize: 12),
                ),
                const SizedBox(width: 6),
              ],
              Text(
                post.place,
                style: const TextStyle(
                  color: textMuted,
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),

          // 4. Headline / Title (Editorial Serif Typography)
          InkWell(
            onTap: onOpenDetail,
            child: Text(
              post.title.isNotEmpty ? post.title : post.place,
              style: const TextStyle(
                color: Color(0xFFEDEDED),
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
              InkWell(
                onTap: onOpenLandmark,
                borderRadius: BorderRadius.circular(6),
                child: const Padding(
                  padding: EdgeInsets.symmetric(vertical: 3),
                  child: Text(
                    'View related landmark →',
                    style: TextStyle(
                      color: goldColor,
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
              const Spacer(),
              TextButton(
                onPressed: onOpenDetail,
                style: TextButton.styleFrom(
                  foregroundColor: goldColor,
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                child: const Text(
                  'Read story',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
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
              InkWell(
                onTap: onOpenMessage,
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 13,
                    vertical: 7.5,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFF222226),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFF35353E)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: const [
                      Icon(
                        Icons.chat_outlined,
                        size: 14,
                        color: goldColor,
                      ),
                      SizedBox(width: 5),
                      Text(
                        'Message',
                        style: TextStyle(
                          color: goldColor,
                          fontSize: 12.5,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
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
                          ? goldColor.withValues(alpha: 0.18)
                          : const Color(0xFF222226),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: post.saved ? goldColor : const Color(0xFF35353E),
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
                          color: goldColor,
                        ),
                        const SizedBox(width: 5),
                        Text(
                          post.saved ? 'Saved' : 'Save',
                          style: const TextStyle(
                            color: goldColor,
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
