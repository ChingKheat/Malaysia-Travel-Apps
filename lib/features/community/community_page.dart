import '../messaging/messaging_service.dart';
import '../messaging/messaging_screens.dart';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';
import '../auth/services/auth_service.dart';
import '../../core/theme/app_colors.dart';
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

/// A minimal member view uses community display data, not private profile fields.
class CommunityMemberPage extends StatefulWidget {
  const CommunityMemberPage({
    super.key,
    required this.name,
    required this.commentId,
  });
  final String name;
  final String commentId;
  @override
  State<CommunityMemberPage> createState() => _CommunityMemberPageState();
}

class _CommunityMemberPageState extends State<CommunityMemberPage> {
  bool busy = false;
  Future<void> _message() async {
    if (busy) return;
    setState(() => busy = true);
    try {
      final id = await MessagingService().fromComment(widget.commentId);
      if (!mounted) return;
      await Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => PrivateChat(id: id, name: widget.name),
        ),
      );
    } catch (_) {
      if (mounted) showCommunitySyncError(context);
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final name = widget.name.trim().isEmpty
        ? communityText(context, 'Traveller', '旅友', 'Pengembara')
        : widget.name;
    return Scaffold(
      appBar: AppBar(
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
                    padding: const EdgeInsets.fromLTRB(24, 32, 24, 28),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          AppColors.nightHeroEnd,
                          AppColors.nightSurface,
                        ],
                      ),
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(color: AppColors.nightLine),
                    ),
                    child: Column(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(4),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(color: AppColors.nightAccent),
                          ),
                          child: const CircleAvatar(
                            radius: 42,
                            backgroundColor: AppColors.nightAccentContainer,
                            foregroundColor: AppColors.nightAccent,
                            child: Icon(Icons.person_outline, size: 42),
                          ),
                        ),
                        const SizedBox(height: 20),
                        Text(
                          name,
                          textAlign: TextAlign.center,
                          style: Theme.of(context).textTheme.headlineSmall
                              ?.copyWith(fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          communityText(
                            context,
                            'Community traveller',
                            '社区旅友',
                            'Pengembara komuniti',
                          ),
                          textAlign: TextAlign.center,
                          style: Theme.of(context).textTheme.bodyMedium
                              ?.copyWith(color: AppColors.nightMuted),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  Text(
                    communityText(
                      context,
                      'Start a conversation',
                      '开始聊天',
                      'Mulakan perbualan',
                    ),
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    communityText(
                      context,
                      'Connect with this traveller and share your travel experiences.',
                      '与这位旅友联系，分享你的旅行经历。',
                      'Berhubung dengan pengembara ini dan kongsi pengalaman perjalanan anda.',
                    ),
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: AppColors.nightMuted,
                      height: 1.5,
                    ),
                  ),
                  const SizedBox(height: 20),
                  SizedBox(
                    height: 56,
                    child: FilledButton.icon(
                      onPressed: busy ? null : _message,
                      icon: busy
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.chat_bubble_outline),
                      label: Text(
                        communityText(context, 'Message', '发送消息', 'Mesej'),
                      ),
                    ),
                  ),
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

  Future<void> _update(Future<void> Function() task) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await task();
    } catch (_) {
      if (mounted) showCommunitySyncError(context);
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
    final surface = colors.surfaceContainerLow;
    final border = OutlineInputBorder(borderRadius: BorderRadius.circular(16));
    return Scaffold(
      appBar: AppBar(
        title: Text(
          communityText(context, 'Community post', '社区帖子', 'Siaran komuniti'),
        ),
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
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            ExcludeSemantics(
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
                                  Text(
                                    communityAuthorLabel(
                                      context,
                                      post.author,
                                      post.isMine,
                                    ),
                                    style: text.titleMedium,
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
                        Text(
                          '${post.topic} · ${post.place}',
                          style: text.labelLarge?.copyWith(
                            color: colors.primary,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          post.body,
                          style: text.bodyLarge?.copyWith(height: 1.5),
                        ),
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
                Semantics(
                  header: true,
                  child: Text(
                    '${communityText(context, 'Comments', '评论', 'Komen')} (${post.comments.length})',
                    style: text.titleLarge,
                  ),
                ),
                if (post.comments.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    child: Text(
                      communityText(
                        context,
                        'No comments yet.',
                        '暂无评论。',
                        'Tiada komen lagi.',
                      ),
                      style: text.bodyMedium?.copyWith(
                        color: colors.onSurfaceVariant,
                      ),
                    ),
                  ),
                for (final comment in post.comments)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Card(
                      margin: EdgeInsets.zero,
                      color: surface,
                      elevation: 0,
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (!comment.isMine && comment.id != null)
                              InkWell(
                                onTap: () => Navigator.of(context).push(
                                  MaterialPageRoute<void>(
                                    builder: (_) => CommunityMemberPage(
                                      name: comment.author,
                                      commentId: comment.id!,
                                    ),
                                  ),
                                ),
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 8,
                                  ),
                                  child: Row(
                                    children: [
                                      Expanded(
                                        child: Text(
                                          communityAuthorLabel(
                                            context,
                                            comment.author,
                                            false,
                                          ),
                                          style: text.titleSmall?.copyWith(
                                            color: colors.primary,
                                          ),
                                        ),
                                      ),
                                      Icon(
                                        Icons.chevron_right,
                                        color: colors.primary,
                                      ),
                                    ],
                                  ),
                                ),
                              )
                            else
                              Text(
                                communityAuthorLabel(
                                  context,
                                  comment.author,
                                  comment.isMine,
                                ),
                                style: text.titleSmall,
                              ),
                            const SizedBox(height: 4),
                            Text(
                              comment.body,
                              style: text.bodyMedium?.copyWith(height: 1.5),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                const SizedBox(height: 20),
                TextField(
                  controller: _comment,
                  readOnly: _busy,
                  minLines: 2,
                  maxLines: 4,
                  maxLength: 500,
                  decoration: InputDecoration(
                    labelText: communityText(
                      context,
                      'Write a comment',
                      '写评论',
                      'Tulis komen',
                    ),
                    border: border,
                  ),
                ),
                Align(
                  alignment: AlignmentDirectional.centerEnd,
                  child: ValueListenableBuilder<TextEditingValue>(
                    valueListenable: _comment,
                    builder: (context, value, _) => FilledButton(
                      style: FilledButton.styleFrom(
                        minimumSize: const Size(48, 48),
                      ),
                      onPressed: _busy || value.text.trim().isEmpty
                          ? null
                          : _submitComment,
                      child: Text(
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

void showCommunitySyncError(BuildContext context) {
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text(
        communityText(
          context,
          'Could not sync. Sign in and try again when online.',
          '同步失败，请登录并在联网后重试。',
          'Gagal menyegerak. Log masuk dan cuba lagi dalam talian.',
        ),
      ),
    ),
  );
}

class CommunityComposer extends StatefulWidget {
  const CommunityComposer({super.key});
  @override
  State<CommunityComposer> createState() => _CommunityComposerState();
}

class _CommunityComposerState extends State<CommunityComposer> {
  final _body = TextEditingController();
  final _place = TextEditingController();
  final List<Uint8List> _photos = [];
  final _service = CommunityService();
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
        if (_postId != null) {
          _submittedPost = (_body.text.trim(), _place.text.trim(), _topic);
        }
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
    if (_submittedPost != (body, place, _topic)) {
      _submittedPost = (body, place, _topic);
      _postId = const Uuid().v4();
    }
    // Preserve the attempt ID with the draft so retries after a timeout
    // or process restart cannot create a duplicate post.
    if (!await _save() || !mounted) return;
    setState(() => _busy = true);
    try {
      await _service.publish(
        id: _postId!,
        body: body,
        place: place,
        topic: _topic,
      );
      try {
        final prefs = await SharedPreferences.getInstance();
        await prefs.remove(_draftKey);
      } catch (_) {
        // The post has already been published.
      }
      if (!mounted) return;
      setState(() => _allowPop = true);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) Navigator.pop(context, true);
      });
    } catch (_) {
      if (mounted) {
        setState(() => _busy = false);
        showCommunitySyncError(context);
      }
    }
  }

  Future<void> _leave() async {
    if (_loading || _busy) return;
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
        content: Text(
          communityText(
            context,
            'Photos are preview-only and must be selected again next time.',
            '照片仅用于本次预览，下次需重新选择。',
            'Foto hanya untuk pratonton dan perlu dipilih semula nanti.',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              communityText(
                context,
                'Continue editing',
                '继续编辑',
                'Terus menyunting',
              ),
            ),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(
              communityText(
                context,
                'Save & close',
                '保存并关闭',
                'Simpan dan tutup',
              ),
            ),
          ),
        ],
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
      final selected = await ImagePicker().pickMultiImage(
        maxWidth: 1600,
        maxHeight: 1600,
        imageQuality: 80,
      );
      final loaded = <Uint8List>[];
      for (final file in selected.take(5 - _photos.length)) {
        if (await file.length() > 10 * 1024 * 1024) {
          throw StateError('Image too large');
        }
        loaded.add(await file.readAsBytes());
      }
      if (mounted) setState(() => _photos.addAll(loaded));
    } catch (_) {
      if (mounted) setState(() => _error = 'photos');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
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
      appBar: AppBar(
        title: Text(
          communityText(context, 'Create post', '发布帖子', 'Cipta siaran'),
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
                    'Posts are visible to signed-in travellers. Photos are for preview only.',
                    '登录用户可看到发布的帖子。照片仅供预览。',
                    'Siaran boleh dilihat oleh pengguna yang log masuk. Foto untuk pratonton sahaja.',
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
                TextField(
                  controller: _place,
                  enabled: !_busy,
                  maxLength: 100,
                  decoration: InputDecoration(
                    labelText: communityText(
                      context,
                      'Place or city',
                      '地点或城市',
                      'Tempat atau bandar',
                    ),
                    prefixIcon: const Icon(Icons.location_on_outlined),
                    border: const OutlineInputBorder(),
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
                                    : () => setState(() => _photos.removeAt(i)),
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
                  onPressed: _busy || _photos.length >= 5 ? null : _pick,
                  icon: const Icon(Icons.add_photo_alternate_outlined),
                  label: Text(
                    '${communityText(context, 'Add photos', '添加照片', 'Tambah foto')} (${_photos.length}/5)',
                  ),
                ),
                if (_error != null)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    child: Text(
                      _error == 'required'
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
                      'Publish post',
                      '发布帖子',
                      'Terbitkan siaran',
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size(0, 48),
                  ),
                  onPressed: _busy
                      ? null
                      : () async {
                          if (await _save() && context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  communityText(
                                    context,
                                    'Text draft saved on this device.',
                                    '文字草稿已保存到本机。',
                                    'Draf teks disimpan pada peranti ini.',
                                  ),
                                ),
                              ),
                            );
                          }
                        },
                  child: Text(
                    communityText(
                      context,
                      'Save text draft',
                      '保存文字草稿',
                      'Simpan draf teks',
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                TextButton(
                  style: TextButton.styleFrom(minimumSize: const Size(0, 48)),
                  onPressed: _busy
                      ? null
                      : () {
                          if (_body.text.trim().isEmpty) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  communityText(
                                    context,
                                    'Write something to preview.',
                                    '请先填写帖子内容。',
                                    'Tulis kandungan dahulu.',
                                  ),
                                ),
                              ),
                            );
                            return;
                          }
                          Navigator.of(context).push(
                            MaterialPageRoute<void>(
                              builder: (context) => Scaffold(
                                appBar: AppBar(
                                  title: Text(
                                    communityText(
                                      context,
                                      'Private preview',
                                      '私人预览',
                                      'Pratonton peribadi',
                                    ),
                                  ),
                                ),
                                body: ListView(
                                  padding: const EdgeInsets.all(20),
                                  children: [
                                    Text(
                                      _place.text,
                                      style: Theme.of(
                                        context,
                                      ).textTheme.titleLarge,
                                    ),
                                    const SizedBox(height: 16),
                                    for (final photo in _photos)
                                      Padding(
                                        padding: const EdgeInsets.only(
                                          bottom: 12,
                                        ),
                                        child: Image.memory(
                                          photo,
                                          errorBuilder: (_, _, _) => const Icon(
                                            Icons.broken_image_outlined,
                                          ),
                                        ),
                                      ),
                                    Text(_body.text),
                                  ],
                                ),
                              ),
                            ),
                          );
                        },
                  child: Text(
                    communityText(
                      context,
                      'Preview post',
                      '预览帖子',
                      'Pratonton siaran',
                    ),
                  ),
                ),
                if (_busy) const LinearProgressIndicator(),
              ],
            ),
    ),
  );
}
