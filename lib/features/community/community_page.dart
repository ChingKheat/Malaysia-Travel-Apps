import '../messaging/messaging_service.dart';
import '../messaging/messaging_screens.dart';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:share_plus/share_plus.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';
import '../auth/services/auth_service.dart';
import '../../core/theme/app_colors.dart';
import '../../shared/services/location_service.dart';
import '../../shared/data/malaysia_states.dart';
import 'community_service.dart';

// Feature-local translations for the community screens.
String communityText(BuildContext context, String en, String zh, String ms) =>
    switch (Localizations.localeOf(context).languageCode) {
      'zh' => zh,
      'ms' => ms,
      _ => en,
    };

String communityAuthorLabel(BuildContext context, String author, bool isMine) {
  final name = author.isEmpty
      ? communityText(context, 'Traveller', '旅友', 'Pengembara')
      : author;
  return isMine
      ? '$name ${communityText(context, '(me)', '（我）', '(saya)')}'
      : name;
}

String communityRepostBody(CommunityPost post, {required String note}) {
  final credit = '${note.trim()}\n\nShared ${post.author}’s post\n\n';
  final source = '\n\n[community-source:${post.id}]';
  final available = 2000 - credit.runes.length - source.runes.length;
  return credit +
      String.fromCharCodes(post.body.runes.take(available.clamp(0, 2000))) +
      source;
}

({String thought, String author, String original, String? sourceId})?
communityRepostParts(String body) {
  const start = '\n\nShared ';
  const end = '’s post\n\n';
  final marker = body.indexOf(start);
  if (marker <= 0) return null;
  final authorStart = marker + start.length;
  final authorEnd = body.indexOf(end, authorStart);
  if (authorEnd <= authorStart) return null;
  final originalWithSource = body.substring(authorEnd + end.length);
  final sourceMarker = RegExp(
    r'\n\n\[community-source:([^\]\n]+)\]$',
  ).firstMatch(originalWithSource);
  return (
    thought: body.substring(0, marker),
    author: body.substring(authorStart, authorEnd),
    original: sourceMarker == null
        ? originalWithSource
        : originalWithSource.substring(0, sourceMarker.start),
    sourceId: sourceMarker?.group(1),
  );
}

Future<void> openCommunitySourceAuthor(
  BuildContext context,
  String name,
  String? sourceId,
  String original,
) async {
  if (sourceId == null) {
    final feed = await CommunityService().loadFeed();
    if (!context.mounted) return;
    final matches = feed.rows
        .where((row) => row['author'] == name && row['body'] == original)
        .take(2)
        .toList();
    if (matches.length == 1) sourceId = matches.single['id'] as String?;
  }
  if (!context.mounted) return;
  Navigator.of(context).push(
    MaterialPageRoute<void>(
      builder: (_) => CommunityMemberPage(name: name, postId: sourceId),
    ),
  );
}

void openCommunityPostAuthor(BuildContext context, CommunityPost post) {
  Navigator.of(context).push(
    MaterialPageRoute<void>(
      builder: (_) => CommunityMemberPage(
        name: post.author,
        postId: post.id,
        isMine: post.isMine,
      ),
    ),
  );
}

Future<void> shareCommunityPost(
  BuildContext context,
  CommunityPost post, {
  VoidCallback? onCommunityShared,
  CommunityService? service,
}) async {
  final choice = await showModalBottomSheet<String>(
    context: context,
    backgroundColor: AppColors.nightSurface,
    builder: (sheetContext) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            leading: const Icon(Icons.groups_outlined),
            title: Text(
              communityText(
                context,
                'Share to Community',
                '分享到社区',
                'Kongsi ke Komuniti',
              ),
            ),
            subtitle: Text(
              communityText(
                context,
                'Travellers can see who shared whose post.',
                '旅友可以看到谁分享了谁的帖子。',
                'Pengembara boleh melihat siapa berkongsi siaran siapa.',
              ),
            ),
            onTap: () => Navigator.pop(sheetContext, 'community'),
          ),
          ListTile(
            leading: const Icon(Icons.ios_share_outlined),
            title: Text(
              communityText(
                context,
                'Share to another app',
                '分享到其他应用',
                'Kongsi ke aplikasi lain',
              ),
            ),
            onTap: () => Navigator.pop(sheetContext, 'external'),
          ),
        ],
      ),
    ),
  );
  if (!context.mounted || choice == null) return;
  final community = service ?? CommunityService();
  if (choice == 'community') {
    final note = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.nightSurface,
      builder: (_) => _CommunityShareNoteSheet(post: post),
    );
    if (!context.mounted || note == null) return;
    try {
      final photos = <Uint8List>[];
      for (final path in post.photoPaths) {
        final bytes = await community.downloadPhoto(path);
        if (bytes != null) photos.add(bytes);
      }
      await community.publish(
        id: const Uuid().v4(),
        body: communityRepostBody(post, note: note),
        place: post.place,
        topic: post.topic,
        photos: photos,
      );
      onCommunityShared?.call();
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              communityText(
                context,
                'Shared to Community',
                '已分享到社区',
                'Dikongsi ke Komuniti',
              ),
            ),
          ),
        );
      }
    } catch (error) {
      if (context.mounted) showCommunitySyncError(context, error: error);
    }
    return;
  }
  final box = context.findRenderObject() as RenderBox?;
  final origin = box == null ? null : box.localToGlobal(Offset.zero) & box.size;
  final repost = communityRepostParts(post.body);
  final shareBody = repost == null
      ? post.body
      : '${repost.thought}\n\nShared ${repost.author}’s post\n\n${repost.original}';
  final text = '${post.place}\n\n$shareBody\n\n— ${post.author}';
  try {
    final path = post.photoPaths.firstOrNull;
    final photo = path == null ? null : await community.downloadPhoto(path);
    final extension = path?.split('.').last.toLowerCase();
    await SharePlus.instance.share(
      ShareParams(
        text: text,
        subject: post.place,
        files: photo == null
            ? null
            : [
                XFile.fromData(
                  photo,
                  mimeType: extension == 'png'
                      ? 'image/png'
                      : extension == 'webp'
                      ? 'image/webp'
                      : 'image/jpeg',
                ),
              ],
        fileNameOverrides: photo == null
            ? null
            : [
                'community-post.${extension == 'png' || extension == 'webp' ? extension : 'jpg'}',
              ],
        sharePositionOrigin: origin,
      ),
    );
  } catch (_) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            communityText(
              context,
              'Could not open sharing. Try again.',
              '无法打开分享，请重试。',
              'Perkongsian tidak dapat dibuka. Cuba lagi.',
            ),
          ),
        ),
      );
    }
  }
}

class _CommunityShareNoteSheet extends StatefulWidget {
  const _CommunityShareNoteSheet({required this.post});
  final CommunityPost post;

  @override
  State<_CommunityShareNoteSheet> createState() =>
      _CommunityShareNoteSheetState();
}

class _CommunityShareNoteSheetState extends State<_CommunityShareNoteSheet> {
  final _note = TextEditingController();

  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Padding(
    padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
    child: SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              communityText(
                context,
                'Share this post',
                '分享此帖子',
                'Kongsi siaran ini',
              ),
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            Text(
              communityText(
                context,
                'Tell travellers why you are sharing it.',
                '告诉旅友你为什么分享。',
                'Beritahu pengembara sebab anda berkongsi.',
              ),
              style: const TextStyle(color: AppColors.nightMuted),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _note,
              autofocus: true,
              minLines: 2,
              maxLines: 4,
              maxLength: 300,
              decoration: InputDecoration(
                hintText: communityText(
                  context,
                  'Write your thoughts...',
                  '写下你的想法…',
                  'Tulis pendapat anda...',
                ),
                border: const OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              '${widget.post.author} · ${widget.post.place}',
              style: const TextStyle(
                color: AppColors.nightAccent,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              widget.post.body,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: AppColors.nightMuted),
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size(0, 56),
                    ),
                    onPressed: () => Navigator.pop(context),
                    child: Text(
                      communityText(context, 'Cancel', '取消', 'Batal'),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ValueListenableBuilder<TextEditingValue>(
                    valueListenable: _note,
                    builder: (_, value, _) => FilledButton(
                      onPressed: value.text.trim().isEmpty
                          ? null
                          : () => Navigator.pop(context, value.text.trim()),
                      child: Text(
                        communityText(
                          context,
                          'Share post',
                          '分享帖子',
                          'Kongsi siaran',
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
    ),
  );
}

class CommunityComment {
  const CommunityComment({
    required this.body,
    this.id,
    this.author = '',
    this.isMine = false,
  });

  factory CommunityComment.fromFeed(Object? value) {
    // Cached feeds from older versions store the comment body as a string.
    if (value is String) return CommunityComment(body: value);
    final row = value as Map<String, dynamic>;
    return CommunityComment(
      body: row['body'] as String,
      id: row['id'] as String?,
      author: row['author'] as String? ?? '',
      isMine: row['is_mine'] == true,
    );
  }

  final String body;
  final String? id;
  final String author;
  final bool isMine;
}

class CommunityPost {
  CommunityPost({
    required this.id,
    required this.author,
    required this.place,
    required this.topic,
    required this.body,
    required this.date,
    required this.likesCount,
    required this.liked,
    required this.saved,
    required this.comments,
    this.photoPaths = const [],
    this.isMine = false,
  });

  factory CommunityPost.fromFeed(Map<String, dynamic> row) => CommunityPost(
    id: row['id'] as String,
    author: row['author'] as String,
    place: row['place'] as String,
    topic: row['topic'] as String,
    body: row['body'] as String,
    date: (row['created_at'] as String).split('T').first,
    likesCount: row['likes_count'] as int,
    liked: row['liked'] as bool,
    saved: row['saved'] as bool,
    isMine: row['is_mine'] == true,
    comments: (row['comments'] as List).map(CommunityComment.fromFeed).toList(),
    photoPaths: (row['photo_paths'] as List? ?? const [])
        .whereType<String>()
        .take(5)
        .toList(),
  );

  final String id;
  final String author;
  final String place;
  final String topic;
  final String body;
  final String date;
  int likesCount;
  bool liked;
  bool saved;
  final List<CommunityComment> comments;
  final List<String> photoPaths;
  final bool isMine;

  Future<void> setReaction({
    required bool bookmark,
    required bool selected,
  }) async {
    await CommunityService().setReaction(
      postId: id,
      saved: bookmark,
      selected: selected,
    );
    if (bookmark) {
      saved = selected;
    } else if (liked != selected) {
      liked = selected;
      likesCount += selected ? 1 : (likesCount > 0 ? -1 : 0);
    }
  }

  Future<void> addComment(String commentId, String text) async {
    final author = AuthService().currentUser?.name.trim() ?? '';
    await CommunityService().comment(commentId, id, text);
    comments.add(CommunityComment(body: text, author: author, isMine: true));
  }

  String get authorInitials {
    final parts = author.trim().split(RegExp(r'\s+'));
    if (parts.isEmpty || parts.first.isEmpty) return '?';
    if (parts.length == 1) return parts.first.substring(0, 1).toUpperCase();
    return (parts[0][0] + parts[1][0]).toUpperCase();
  }
}

class CommunityPostPhotos extends StatelessWidget {
  const CommunityPostPhotos({
    super.key,
    required this.paths,
    this.height = 180,
    this.photoLoader,
  });

  final List<String> paths;
  final double height;
  final Future<Uint8List?> Function(String)? photoLoader;

  @override
  Widget build(BuildContext context) {
    if (paths.isEmpty) return const SizedBox.shrink();
    return SizedBox(
      height: height,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: paths.length,
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (context, index) => ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: SizedBox(
            width: paths.length == 1
                ? MediaQuery.sizeOf(context).width - 64
                : MediaQuery.sizeOf(context).width * 0.7,
            child: GestureDetector(
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => _CommunityPhotoViewer(
                    path: paths[index],
                    loader: photoLoader ?? CommunityService().downloadPhoto,
                  ),
                ),
              ),
              child: _CommunityPhoto(
                key: ValueKey(paths[index]),
                path: paths[index],
                loader: photoLoader ?? CommunityService().downloadPhoto,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _CommunityPhotoViewer extends StatefulWidget {
  const _CommunityPhotoViewer({required this.path, required this.loader});
  final String path;
  final Future<Uint8List?> Function(String) loader;

  @override
  State<_CommunityPhotoViewer> createState() => _CommunityPhotoViewerState();
}

class _CommunityPhotoViewerState extends State<_CommunityPhotoViewer> {
  late final Future<Uint8List?> _bytes = widget.loader(widget.path);

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: Colors.black,
    appBar: AppBar(
      backgroundColor: Colors.black,
      title: Text(communityText(context, 'Photo', '照片', 'Foto')),
    ),
    body: FutureBuilder<Uint8List?>(
      future: _bytes,
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return Center(
            child: snapshot.connectionState == ConnectionState.done
                ? const Icon(Icons.broken_image_outlined)
                : const CircularProgressIndicator(),
          );
        }
        return InteractiveViewer(
          minScale: 1,
          maxScale: 5,
          child: Center(
            child: Image.memory(snapshot.data!, fit: BoxFit.contain),
          ),
        );
      },
    ),
  );
}

class _CommunityPhoto extends StatefulWidget {
  const _CommunityPhoto({super.key, required this.path, required this.loader});
  final String path;
  final Future<Uint8List?> Function(String) loader;

  @override
  State<_CommunityPhoto> createState() => _CommunityPhotoState();
}

class _CommunityPhotoState extends State<_CommunityPhoto> {
  late Future<Uint8List?> _bytes = widget.loader(widget.path);

  @override
  void didUpdateWidget(covariant _CommunityPhoto oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.path != widget.path) _bytes = widget.loader(widget.path);
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<Uint8List?>(
    future: _bytes,
    builder: (context, snapshot) {
      final bytes = snapshot.data;
      if (bytes == null) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const ColoredBox(
            color: AppColors.nightRaised,
            child: Center(child: CircularProgressIndicator()),
          );
        }
        return const ColoredBox(
          color: AppColors.nightRaised,
          child: Center(child: Icon(Icons.broken_image_outlined)),
        );
      }
      return Image.memory(
        bytes,
        fit: BoxFit.cover,
        errorBuilder: (_, _, _) => const ColoredBox(
          color: AppColors.nightRaised,
          child: Center(child: Icon(Icons.broken_image_outlined)),
        ),
      );
    },
  );
}

/// A minimal member view uses community display data, not private profile fields.
class CommunityMemberPage extends StatefulWidget {
  const CommunityMemberPage({
    super.key,
    required this.name,
    this.commentId,
    this.postId,
    this.isMine = false,
  });
  final String name;
  final String? commentId;
  final String? postId;
  final bool isMine;
  @override
  State<CommunityMemberPage> createState() => _CommunityMemberPageState();
}

class _CommunityMemberPageState extends State<CommunityMemberPage> {
  bool busy = false;
  Future<void> _message() async {
    if (busy) return;
    setState(() => busy = true);
    try {
      final id = widget.postId != null
          ? await MessagingService().fromPost(widget.postId!)
          : await MessagingService().fromComment(widget.commentId!);
      if (!mounted) return;
      await Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => PrivateChat(id: id, name: widget.name),
        ),
      );
    } catch (error) {
      if (mounted) showCommunitySyncError(context, error: error);
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final name = widget.name.trim().isEmpty
        ? communityText(context, 'Traveller', '旅友', 'Pengembara')
        : widget.name;
    final initials = name
        .trim()
        .split(RegExp(r'\s+'))
        .take(2)
        .map((part) => part.isEmpty ? '' : part[0].toUpperCase())
        .join();
    final canMessage =
        !widget.isMine && (widget.postId != null || widget.commentId != null);
    final text = Theme.of(context).textTheme;
    return Scaffold(
      backgroundColor: AppColors.nightCanvas,
      appBar: AppBar(
        backgroundColor: AppColors.nightCanvas,
        title: Text(
          communityText(context, 'Community member', '社区成员', 'Ahli komuniti'),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 24, 24, 32),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 520),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: AppColors.nightSurface,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: AppColors.nightLine),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              width: 72,
                              height: 72,
                              alignment: Alignment.center,
                              decoration: BoxDecoration(
                                color: AppColors.nightAccentContainer,
                                borderRadius: BorderRadius.circular(18),
                                border: Border.all(
                                  color: AppColors.nightAccent,
                                ),
                              ),
                              child: Text(
                                initials,
                                style: text.headlineSmall?.copyWith(
                                  color: AppColors.nightAccent,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const SizedBox(height: 4),
                                  Text(
                                    name,
                                    style: text.headlineSmall?.copyWith(
                                      color: AppColors.nightBody,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    communityText(
                                      context,
                                      'Community traveller',
                                      '社区旅友',
                                      'Pengembara komuniti',
                                    ),
                                    style: text.bodyMedium?.copyWith(
                                      color: AppColors.nightMuted,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 24),
                        const Divider(height: 1, color: AppColors.nightLine),
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            const Icon(
                              Icons.groups_outlined,
                              size: 18,
                              color: AppColors.nightAccent,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                communityText(
                                  context,
                                  'Part of the travel community',
                                  '旅行社区成员',
                                  'Ahli komuniti pengembara',
                                ),
                                style: text.bodyMedium?.copyWith(
                                  color: AppColors.nightMuted,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  if (canMessage) ...[
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: AppColors.nightSurface,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: AppColors.nightLine),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                width: 40,
                                height: 40,
                                decoration: BoxDecoration(
                                  color: AppColors.nightAccentContainer,
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: const Icon(
                                  Icons.chat_bubble_outline,
                                  size: 20,
                                  color: AppColors.nightAccent,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  communityText(
                                    context,
                                    'Start a conversation',
                                    '开始聊天',
                                    'Mulakan perbualan',
                                  ),
                                  style: text.titleMedium?.copyWith(
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Text(
                            communityText(
                              context,
                              'Send a private message to $name.',
                              '私信 $name。',
                              'Hantar mesej peribadi kepada $name.',
                            ),
                            style: text.bodyMedium?.copyWith(
                              color: AppColors.nightMuted,
                            ),
                          ),
                          const SizedBox(height: 20),
                          SizedBox(
                            width: double.infinity,
                            height: 52,
                            child: FilledButton.icon(
                              onPressed: busy ? null : _message,
                              icon: busy
                                  ? const SizedBox(
                                      width: 20,
                                      height: 20,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                      ),
                                    )
                                  : const Icon(Icons.chat_bubble_outline),
                              label: Text(
                                communityText(
                                  context,
                                  'Message',
                                  '发送消息',
                                  'Mesej',
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class CommunityPostDetailPage extends StatefulWidget {
  const CommunityPostDetailPage({super.key, required this.post});
  final CommunityPost post;
  @override
  State<CommunityPostDetailPage> createState() =>
      _CommunityPostDetailPageState();
}

class _CommunityPostDetailPageState extends State<CommunityPostDetailPage> {
  final _comment = TextEditingController();
  bool _busy = false;
  String? _commentId;
  String? _submittedComment;

  Future<void> _ownerAction(String action) async {
    if (action == 'edit') {
      final changed = await Navigator.of(context).push<bool>(
        MaterialPageRoute(
          builder: (_) => CommunityComposer(editing: widget.post),
        ),
      );
      if (changed == true && mounted) Navigator.of(context).pop(true);
      return;
    }
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(
          communityText(
            context,
            'Delete this post?',
            '删除此帖子？',
            'Padam siaran ini?',
          ),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              communityText(
                context,
                'This post and its photos will be permanently removed. This cannot be undone.',
                '此帖子及照片将被永久删除，无法撤销。',
                'Siaran dan fotonya akan dipadam secara kekal. Tindakan ini tidak boleh dibuat asal.',
              ),
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(dialogContext, false),
                    child: Text(
                      communityText(context, 'Cancel', '取消', 'Batal'),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: FilledButton(
                    onPressed: () => Navigator.pop(dialogContext, true),
                    child: Text(
                      communityText(context, 'Delete', '删除', 'Padam'),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
    if (confirmed != true || !mounted) return;
    await _update(() async {
      await CommunityService().deletePost(widget.post.id);
      if (mounted) Navigator.of(context).pop(true);
    });
  }

  Future<void> _update(Future<void> Function() task) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await task();
    } catch (error) {
      if (mounted) showCommunitySyncError(context, error: error);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  void dispose() {
    _comment.dispose();
    super.dispose();
  }

  Future<void> _submitComment() async {
    final text = _comment.text.trim();
    if (text.isEmpty || _busy) return;
    if (_submittedComment != text || _commentId == null) {
      _submittedComment = text;
      _commentId = const Uuid().v4();
    }
    await _update(() async {
      await widget.post.addComment(_commentId!, text);
      _commentId = null;
      if (mounted) _comment.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    final post = widget.post;
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final text = theme.textTheme;
    const surface = AppColors.nightSurface;
    return Scaffold(
      backgroundColor: AppColors.nightCanvas,
      appBar: AppBar(
        backgroundColor: AppColors.nightSurface,
        title: Text(
          communityText(context, 'Community post', '社区帖子', 'Siaran komuniti'),
        ),
        actions: [
          IconButton(
            tooltip: communityText(
              context,
              'Share post',
              '分享帖子',
              'Kongsi siaran',
            ),
            icon: const Icon(Icons.share_outlined),
            onPressed: () => shareCommunityPost(context, post),
          ),
        ],
      ),
      body: SafeArea(
        top: false,
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 640),
            child: ListView(
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
              children: [
                Card(
                  margin: EdgeInsets.zero,
                  color: surface,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                    side: const BorderSide(color: AppColors.nightLine),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            InkWell(
                              onTap: () =>
                                  openCommunityPostAuthor(context, post),
                              child: CircleAvatar(
                                backgroundColor: colors.primaryContainer,
                                foregroundColor: colors.onPrimaryContainer,
                                child: Text(post.authorInitials, maxLines: 1),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  InkWell(
                                    onTap: () =>
                                        openCommunityPostAuthor(context, post),
                                    child: Text(
                                      communityAuthorLabel(
                                        context,
                                        post.author,
                                        post.isMine,
                                      ),
                                      style: text.titleMedium,
                                    ),
                                  ),
                                  Text(
                                    post.date,
                                    style: text.bodySmall?.copyWith(
                                      color: colors.onSurfaceVariant,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            if (post.isMine)
                              PopupMenuButton<String>(
                                tooltip: communityText(
                                  context,
                                  'Post options',
                                  '帖子选项',
                                  'Pilihan siaran',
                                ),
                                icon: const Icon(Icons.more_horiz),
                                onSelected: _ownerAction,
                                itemBuilder: (context) => [
                                  PopupMenuItem(
                                    value: 'edit',
                                    child: Text(
                                      communityText(
                                        context,
                                        'Edit post and photos',
                                        '编辑帖子和照片',
                                        'Sunting siaran dan foto',
                                      ),
                                    ),
                                  ),
                                  PopupMenuItem(
                                    value: 'delete',
                                    child: Text(
                                      communityText(
                                        context,
                                        'Delete post',
                                        '删除帖子',
                                        'Padam siaran',
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            if (!post.isMine)
                              IconButton(
                                tooltip: communityText(
                                  context,
                                  'Message',
                                  '发送消息',
                                  'Mesej',
                                ),
                                onPressed: _busy
                                    ? null
                                    : () async {
                                        setState(() => _busy = true);
                                        try {
                                          final id = await MessagingService()
                                              .fromPost(post.id);
                                          if (!context.mounted) return;
                                          await Navigator.of(context).push(
                                            MaterialPageRoute<void>(
                                              builder: (_) => PrivateChat(
                                                id: id,
                                                name: post.author,
                                              ),
                                            ),
                                          );
                                        } catch (_) {
                                          if (context.mounted) {
                                            showCommunitySyncError(context);
                                          }
                                        } finally {
                                          if (mounted) {
                                            setState(() => _busy = false);
                                          }
                                        }
                                      },
                                icon: const Icon(Icons.chat_bubble_outline),
                              ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        if (communityRepostParts(post.body) == null) ...[
                          Text(
                            '${post.topic} · ${post.place}',
                            style: text.labelLarge?.copyWith(
                              color: colors.primary,
                            ),
                          ),
                          const SizedBox(height: 8),
                        ],
                        if (communityRepostParts(post.body)
                            case final repost?) ...[
                          Text(
                            repost.thought,
                            style: text.titleMedium?.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 16),
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
                              style: text.labelLarge?.copyWith(
                                color: AppColors.nightAccent,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                          const SizedBox(height: 12),
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: AppColors.nightCanvas,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: AppColors.nightLine),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  '${post.topic} · ${post.place}',
                                  style: text.labelLarge?.copyWith(
                                    color: colors.primary,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  repost.original,
                                  style: text.bodyLarge?.copyWith(height: 1.5),
                                ),
                              ],
                            ),
                          ),
                        ] else
                          Text(
                            post.body,
                            style: text.bodyLarge?.copyWith(height: 1.5),
                          ),
                        if (post.photoPaths.isNotEmpty) ...[
                          const SizedBox(height: 12),
                          CommunityPostPhotos(
                            paths: post.photoPaths,
                            height: 260,
                          ),
                        ],
                        const SizedBox(height: 12),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            FilterChip(
                              materialTapTargetSize:
                                  MaterialTapTargetSize.padded,
                              label: Text(
                                '${communityText(context, 'Like', '点赞', 'Suka')} · ${post.likesCount}',
                              ),
                              selected: post.liked,
                              onSelected: _busy
                                  ? null
                                  : (v) => _update(
                                      () => post.setReaction(
                                        bookmark: false,
                                        selected: v,
                                      ),
                                    ),
                            ),
                            FilterChip(
                              materialTapTargetSize:
                                  MaterialTapTargetSize.padded,
                              label: Text(
                                communityText(
                                  context,
                                  'Save post',
                                  '收藏帖子',
                                  'Simpan siaran',
                                ),
                              ),
                              selected: post.saved,
                              onSelected: _busy
                                  ? null
                                  : (v) => _update(
                                      () => post.setReaction(
                                        bookmark: true,
                                        selected: v,
                                      ),
                                    ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                Row(
                  children: [
                    Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: AppColors.nightAccentContainer,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(
                        Icons.forum_outlined,
                        color: AppColors.nightAccent,
                        size: 19,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Semantics(
                      header: true,
                      child: Text(
                        '${communityText(context, 'Comments', '评论', 'Komen')} (${post.comments.length})',
                        style: text.titleLarge?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                if (post.comments.isEmpty)
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: AppColors.nightSurface,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: AppColors.nightLine),
                    ),
                    child: Text(
                      communityText(
                        context,
                        'No comments yet. Start the conversation.',
                        '暂无评论，来开始交流吧。',
                        'Belum ada komen. Mulakan perbualan.',
                      ),
                      style: text.bodyMedium?.copyWith(
                        color: AppColors.nightMuted,
                      ),
                    ),
                  ),
                for (final comment in post.comments)
                  _CommunityCommentCard(comment: comment),
                const SizedBox(height: 20),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppColors.nightSurface,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: AppColors.nightLine),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        communityText(
                          context,
                          'Join the conversation',
                          '参与讨论',
                          'Sertai perbualan',
                        ),
                        style: text.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: _comment,
                        readOnly: _busy,
                        minLines: 2,
                        maxLines: 4,
                        maxLength: 500,
                        decoration: InputDecoration(
                          hintText: communityText(
                            context,
                            'Write a comment',
                            '写评论',
                            'Tulis komen',
                          ),
                          filled: true,
                          fillColor: AppColors.nightCanvas,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                      Align(
                        alignment: AlignmentDirectional.centerEnd,
                        child: ValueListenableBuilder<TextEditingValue>(
                          valueListenable: _comment,
                          builder: (context, value, _) => FilledButton.icon(
                            onPressed: _busy || value.text.trim().isEmpty
                                ? null
                                : _submitComment,
                            icon: const Icon(Icons.send_rounded, size: 17),
                            label: Text(
                              communityText(
                                context,
                                'Add comment',
                                '添加评论',
                                'Tambah komen',
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                if (_busy)
                  const Padding(
                    padding: EdgeInsets.only(top: 8),
                    child: LinearProgressIndicator(),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _CommunityCommentCard extends StatelessWidget {
  const _CommunityCommentCard({required this.comment});

  final CommunityComment comment;

  @override
  Widget build(BuildContext context) {
    final author = communityAuthorLabel(
      context,
      comment.author,
      comment.isMine,
    );
    final canOpenMember =
        !comment.isMine && comment.id != null && comment.author.isNotEmpty;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: AppColors.nightSurface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: AppColors.nightLine),
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: canOpenMember
              ? () => Navigator.push(
                  context,
                  MaterialPageRoute<void>(
                    builder: (_) => CommunityMemberPage(
                      name: comment.author,
                      commentId: comment.id!,
                    ),
                  ),
                )
              : null,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CircleAvatar(
                  radius: 18,
                  backgroundColor: AppColors.nightAccentContainer,
                  foregroundColor: AppColors.nightAccent,
                  child: Text(
                    comment.author.isEmpty
                        ? '?'
                        : comment.author.substring(0, 1).toUpperCase(),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        author.isEmpty
                            ? communityText(
                                context,
                                'Traveller',
                                '旅客',
                                'Pengembara',
                              )
                            : author,
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        comment.body,
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                    ],
                  ),
                ),
                if (canOpenMember)
                  const Icon(
                    Icons.chevron_right,
                    size: 20,
                    color: AppColors.nightMuted,
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

void showCommunitySyncError(BuildContext context, {Object? error}) {
  final permissionDenied =
      error is PostgrestException &&
      (error.code == '42501' || error.code == 'PGRST301');
  final signedOut =
      AuthService().currentUser == null ||
      error is StateError && error.toString().contains('Supabase session');
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text(
        permissionDenied
            ? communityText(
                context,
                'Post editing is unavailable because the database permissions need updating.',
                '数据库权限需要更新，暂时无法编辑帖子。',
                'Suntingan siaran tidak tersedia kerana kebenaran pangkalan data perlu dikemas kini.',
              )
            : signedOut
            ? communityText(
                context,
                'Sign in to continue.',
                '请登录以继续。',
                'Log masuk untuk meneruskan.',
              )
            : communityText(
                context,
                'Could not save the change. Check your connection and try again.',
                '无法保存更改，请检查网络后重试。',
                'Perubahan tidak dapat disimpan. Semak sambungan dan cuba lagi.',
              ),
      ),
    ),
  );
}

class CommunityComposer extends StatefulWidget {
  const CommunityComposer({
    super.key,
    this.service,
    this.imagePicker,
    this.editing,
  });
  final CommunityService? service;
  final ImagePicker? imagePicker;
  final CommunityPost? editing;
  @override
  State<CommunityComposer> createState() => _CommunityComposerState();
}

class _CommunityComposerState extends State<CommunityComposer> {
  final _body = TextEditingController();
  final _place = TextEditingController();
  final List<Uint8List> _photos = [];
  final List<String> _retainedPaths = [];
  int _draftPhotoCount = 0;
  late final CommunityService _service = widget.service ?? CommunityService();
  late final ImagePicker _imagePicker = widget.imagePicker ?? ImagePicker();
  String _topic = CommunityService.topics.first;
  String? _postId;
  (String, String, String)? _submittedPost;
  late final String _draftKey;
  bool _loading = true;
  bool _busy = false;
  bool _allowPop = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    if (widget.editing case final post?) {
      _body.text = post.body;
      _place.text = post.place;
      _topic = CommunityService.topics.contains(post.topic)
          ? post.topic
          : CommunityService.topics.first;
      _retainedPaths.addAll(post.photoPaths);
      _loading = false;
      return;
    }
    _draftKey =
        'community.draft.v1.${AuthService().currentUser?.uid ?? 'guest'}';
    _load();
  }

  Future<void> _load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_draftKey);
      if (!mounted) return;
      if (raw != null) {
        final data = jsonDecode(raw) as Map<String, dynamic>;
        _body.text = data['body'] as String? ?? '';
        _place.text = data['place'] as String? ?? '';
        final topic = data['topic'];
        if (CommunityService.topics.contains(topic)) _topic = topic as String;
        _postId = data['postId'] as String?;
        _draftPhotoCount = (data['photoCount'] as num?)?.toInt() ?? 0;
        if (_postId != null) {
          _submittedPost = (_body.text.trim(), _place.text.trim(), _topic);
        }
      } else {
        _place.text = LocationService().currentAreaName;
      }
    } catch (_) {
      if (mounted) _error = 'load';
    }
    if (mounted) setState(() => _loading = false);
  }

  Future<bool> _save() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final prefs = await SharedPreferences.getInstance();
      final saved = await prefs.setString(
        _draftKey,
        jsonEncode({
          'body': _body.text,
          'place': _place.text,
          'topic': _topic,
          'photoCount': _photos.isEmpty ? _draftPhotoCount : _photos.length,
          'postId':
              _submittedPost == (_body.text.trim(), _place.text.trim(), _topic)
              ? _postId
              : null,
        }),
      );
      if (!saved) throw StateError('Draft write failed');
      return true;
    } catch (_) {
      if (mounted) setState(() => _error = 'save');
      return false;
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _publish() async {
    final body = _body.text.trim();
    final place = _place.text.trim();
    if (body.isEmpty || place.isEmpty) {
      setState(() => _error = 'required');
      return;
    }
    if (widget.editing == null && _draftPhotoCount > 0 && _photos.isEmpty) {
      setState(() => _error = 'reselectPhotos');
      return;
    }
    if (_submittedPost != (body, place, _topic)) {
      _submittedPost = (body, place, _topic);
      _postId = const Uuid().v4();
    }
    // Preserve the attempt ID with the draft so retries after a timeout
    // or process restart cannot create a duplicate post.
    if (widget.editing == null && (!await _save() || !mounted)) return;
    setState(() => _busy = true);
    try {
      if (widget.editing case final post?) {
        await _service.updatePost(
          id: post.id,
          body: body,
          place: place,
          topic: _topic,
          retainedPaths: List.of(_retainedPaths),
          newPhotos: List.of(_photos),
        );
      } else {
        await _service.publish(
          id: _postId!,
          body: body,
          place: place,
          topic: _topic,
          photos: List.of(_photos),
        );
        try {
          final prefs = await SharedPreferences.getInstance();
          await prefs.remove(_draftKey);
        } catch (_) {}
      }
      if (!mounted) return;
      setState(() => _allowPop = true);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) Navigator.pop(context, true);
      });
    } catch (error) {
      if (mounted) {
        setState(() => _busy = false);
        showCommunitySyncError(context, error: error);
      }
    }
  }

  Future<void> _leave() async {
    if (_loading || _busy) return;
    if (widget.editing != null) {
      setState(() => _allowPop = true);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) Navigator.pop(context, false);
      });
      return;
    }
    final choice = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          communityText(
            context,
            'Keep your text draft?',
            '保留文字草稿？',
            'Simpan draf teks?',
          ),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              communityText(
                context,
                'Select your photos again before publishing this draft.',
                '发布此草稿前请重新选择照片。',
                'Pilih semula foto sebelum menerbitkan draf ini.',
              ),
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(context),
                    child: Text(
                      communityText(
                        context,
                        'Continue editing',
                        '继续编辑',
                        'Terus menyunting',
                      ),
                      maxLines: 2,
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: FilledButton(
                    style: FilledButton.styleFrom(
                      minimumSize: const Size(0, 56),
                    ),
                    onPressed: () => Navigator.pop(context, true),
                    child: Text(
                      communityText(
                        context,
                        'Save & close',
                        '保存并关闭',
                        'Simpan dan tutup',
                      ),
                      maxLines: 2,
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
    if (choice != true || !mounted) return;
    if (await _save() && mounted) {
      setState(() => _allowPop = true);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) Navigator.pop(context);
      });
    }
  }

  Future<void> _pick() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final selected = await _imagePicker.pickMultiImage(
        maxWidth: 1600,
        maxHeight: 1600,
        imageQuality: 80,
      );
      final loaded = <Uint8List>[];
      for (final file in selected.take(
        5 - _photos.length - _retainedPaths.length,
      )) {
        if (await file.length() > 10 * 1024 * 1024) {
          throw StateError('Image too large');
        }
        loaded.add(await file.readAsBytes());
      }
      if (mounted) {
        setState(() {
          _photos.addAll(loaded);
          if (loaded.isNotEmpty) {
            _draftPhotoCount = 0;
            _submittedPost = null;
          }
        });
      }
    } catch (_) {
      if (mounted) setState(() => _error = 'photos');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _choosePostPlace() async {
    var state = malaysiaStatesData.first;
    for (final candidate in malaysiaStatesData) {
      if (_place.text.contains(candidate.name)) {
        state = candidate;
        break;
      }
    }
    var city = state.areas.first;
    for (final candidate in state.areas) {
      if (_place.text.startsWith(candidate.name)) {
        city = candidate;
        break;
      }
    }
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
                  onPressed: () => Navigator.pop(
                    sheetContext,
                    '${city.name}, ${state.name}',
                  ),
                  child: Text(
                    communityText(
                      context,
                      'Use this place',
                      '使用此地点',
                      'Guna tempat ini',
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
    if (mounted && selected != null) setState(() => _place.text = selected);
  }

  @override
  void dispose() {
    _body.dispose();
    _place.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: _allowPop,
    onPopInvokedWithResult: (didPop, _) {
      if (!didPop) _leave();
    },
    child: Scaffold(
      backgroundColor: AppColors.nightCanvas,
      appBar: AppBar(
        backgroundColor: AppColors.nightSurface,
        title: Text(
          widget.editing == null
              ? communityText(context, 'Create post', '发布帖子', 'Cipta siaran')
              : communityText(context, 'Edit post', '编辑帖子', 'Sunting siaran'),
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              padding: EdgeInsets.fromLTRB(
                20,
                20,
                20,
                20 + MediaQuery.paddingOf(context).bottom,
              ),
              children: [
                Text(
                  communityText(
                    context,
                    'Your post and photos will appear in the Community feed.',
                    '您的帖子和照片会显示在社区动态中。',
                    'Siaran dan foto anda akan dipaparkan dalam suapan Komuniti.',
                  ),
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 20),
                TextField(
                  controller: _body,
                  enabled: !_busy,
                  minLines: 5,
                  maxLines: 10,
                  maxLength: 2000,
                  decoration: InputDecoration(
                    labelText: communityText(
                      context,
                      'Share your travel experience',
                      '分享你的旅行体验',
                      'Kongsi pengalaman perjalanan',
                    ),
                    alignLabelWithHint: true,
                    border: const OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 16),
                InkWell(
                  key: const ValueKey('community-place-picker'),
                  onTap: _busy ? null : _choosePostPlace,
                  borderRadius: BorderRadius.circular(8),
                  child: InputDecorator(
                    decoration: InputDecoration(
                      labelText: communityText(
                        context,
                        'Place or city',
                        '地点或城市',
                        'Tempat atau bandar',
                      ),
                      prefixIcon: const Icon(Icons.location_on_outlined),
                      suffixIcon: const Icon(Icons.expand_more),
                      border: const OutlineInputBorder(),
                    ),
                    child: Text(
                      _place.text.isEmpty
                          ? communityText(
                              context,
                              'Choose a place',
                              '选择地点',
                              'Pilih tempat',
                            )
                          : _place.text,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: _topic,
                  isExpanded: true,
                  decoration: InputDecoration(
                    labelText: communityText(context, 'Topic', '分类', 'Topik'),
                    prefixIcon: const Icon(Icons.label_outline),
                    border: const OutlineInputBorder(),
                  ),
                  items: [
                    for (final topic in CommunityService.topics)
                      DropdownMenuItem(value: topic, child: Text(topic)),
                  ],
                  onChanged: _busy
                      ? null
                      : (value) => setState(() => _topic = value!),
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final path in _retainedPaths)
                      SizedBox(
                        width: 100,
                        height: 110,
                        child: Stack(
                          fit: StackFit.expand,
                          children: [
                            CommunityPostPhotos(paths: [path], height: 110),
                            Positioned(
                              right: 0,
                              top: 0,
                              child: IconButton.filled(
                                tooltip: communityText(
                                  context,
                                  'Remove photo',
                                  '移除照片',
                                  'Buang foto',
                                ),
                                onPressed: _busy
                                    ? null
                                    : () => setState(
                                        () => _retainedPaths.remove(path),
                                      ),
                                icon: const Icon(Icons.close),
                              ),
                            ),
                          ],
                        ),
                      ),
                    for (var i = 0; i < _photos.length; i++)
                      SizedBox(
                        width: 100,
                        height: 110,
                        child: Stack(
                          fit: StackFit.expand,
                          children: [
                            Image.memory(
                              _photos[i],
                              fit: BoxFit.cover,
                              cacheWidth: 250,
                              errorBuilder: (_, _, _) =>
                                  const Icon(Icons.broken_image_outlined),
                            ),
                            Positioned(
                              right: 0,
                              top: 0,
                              child: IconButton.filled(
                                tooltip: communityText(
                                  context,
                                  'Remove photo',
                                  '移除照片',
                                  'Buang foto',
                                ),
                                onPressed: _busy
                                    ? null
                                    : () => setState(() {
                                        _photos.removeAt(i);
                                        _submittedPost = null;
                                      }),
                                icon: const Icon(Icons.close),
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
                if (_photos.isNotEmpty) const SizedBox(height: 12),
                OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size(0, 48),
                  ),
                  onPressed:
                      _busy || _photos.length + _retainedPaths.length >= 5
                      ? null
                      : _pick,
                  icon: const Icon(Icons.add_photo_alternate_outlined),
                  label: Text(
                    '${communityText(context, 'Add photos', '添加照片', 'Tambah foto')} (${_photos.length + _retainedPaths.length}/5)',
                  ),
                ),
                if (_error != null)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    child: Text(
                      _error == 'reselectPhotos'
                          ? communityText(
                              context,
                              'Select your photos again before publishing.',
                              '发布前请重新选择照片。',
                              'Pilih semula foto sebelum menerbitkan.',
                            )
                          : _error == 'required'
                          ? communityText(
                              context,
                              'Enter a place and post text.',
                              '请填写地点和正文。',
                              'Masukkan tempat dan teks siaran.',
                            )
                          : communityText(
                              context,
                              'Could not complete the action. Your current text is still here; please retry.',
                              '操作未完成，当前文字仍保留在页面上，请重试。',
                              'Tindakan gagal. Teks masih ada; sila cuba lagi.',
                            ),
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                      ),
                    ),
                  ),
                const SizedBox(height: 16),
                FilledButton(
                  style: FilledButton.styleFrom(minimumSize: const Size(0, 52)),
                  onPressed: _busy ? null : _publish,
                  child: Text(
                    communityText(
                      context,
                      widget.editing == null ? 'Publish post' : 'Save changes',
                      widget.editing == null ? '发布帖子' : '保存更改',
                      widget.editing == null
                          ? 'Terbitkan siaran'
                          : 'Simpan perubahan',
                    ),
                  ),
                ),
                if (_busy) const LinearProgressIndicator(),
              ],
            ),
    ),
  );
}
