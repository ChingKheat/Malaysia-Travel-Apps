import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../auth/services/auth_service.dart';

// Feature-local copy keeps the prototype usable in all existing app languages.
String communityText(BuildContext context, String en, String zh, String ms) =>
    switch (Localizations.localeOf(context).languageCode) {
      'zh' => zh,
      'ms' => ms,
      _ => en,
    };

class CommunityPost {
  CommunityPost({
    required this.author,
    required this.place,
    required this.topic,
    required this.body,
    required this.asset,
  });
  final String author, place, topic, body, asset;
  bool liked = false;
  bool saved = false;
  final List<String> comments = [];
}

class CommunityPage extends StatefulWidget {
  const CommunityPage({super.key, this.showAppBar = false});
  final bool showAppBar;
  @override
  State<CommunityPage> createState() => _CommunityPageState();
}

class _CommunityPageState extends State<CommunityPage> {
  final _posts = [
    CommunityPost(
      author: 'Sample traveler',
      place: 'Kuala Lumpur',
      topic: 'Sights',
      body:
          'An evening around the Petronas Twin Towers. Leave some time to walk through the park and enjoy the city views.',
      asset: 'assets/recognition/petronas.jpg',
    ),
    CommunityPost(
      author: 'Sample traveler',
      place: 'Selangor',
      topic: 'Tips',
      body:
          'Planning a visit to Batu Caves? Bring drinking water and comfortable shoes for the steps.',
      asset: 'assets/recognition/batu_caves.jpg',
    ),
    CommunityPost(
      author: 'Sample traveler',
      place: 'Kuala Lumpur',
      topic: 'Food',
      body:
          'A Malaysian breakfast inspiration: nasi lemak. Ask the stall about ingredients and available options before ordering.',
      asset: 'assets/recognition/nasi_lemak.jpg',
    ),
  ];
  String _topic = 'All';
  bool _savedOnly = false;

  Future<void> _open(CommunityPost post) async {
    await Navigator.of(
      context,
    ).push(MaterialPageRoute<void>(builder: (_) => _PostDetail(post: post)));
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final posts = _posts
        .where(
          (p) =>
              (_topic == 'All' || p.topic == _topic) &&
              (!_savedOnly || p.saved),
        )
        .toList();
    return Scaffold(
      appBar: widget.showAppBar
          ? AppBar(
              title: Text(
                communityText(
                  context,
                  'Traveler stories',
                  '旅人分享',
                  'Kisah pengembara',
                ),
              ),
            )
          : null,
      backgroundColor: Theme.of(context).colorScheme.surface,
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'community-compose',
        onPressed: () => Navigator.of(context).push(
          MaterialPageRoute<void>(builder: (_) => const CommunityComposer()),
        ),
        icon: const Icon(Icons.edit_outlined),
        label: Text(
          communityText(context, 'Create post', '发布帖子', 'Cipta siaran'),
        ),
      ),
      body: CustomScrollView(
        key: const PageStorageKey('community-feed'),
        slivers: [
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    communityText(
                      context,
                      'Travel inspiration, shared',
                      '分享旅途，发现灵感',
                      'Inspirasi perjalanan bersama',
                    ),
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    communityText(
                      context,
                      'Preview mode · Sample posts. Interactions stay in this session; nothing is published.',
                      '预览模式 · 示例帖子，互动仅保留在当前会话，不会公开发布。',
                      'Mod pratonton · Siaran contoh. Interaksi hanya untuk sesi ini; tiada penerbitan.',
                    ),
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 4,
                    children: [
                      for (final topic in ['All', 'Sights', 'Food', 'Tips'])
                        ChoiceChip(
                          label: Text(switch (topic) {
                            'Sights' => communityText(
                              context,
                              'Sights',
                              '景点',
                              'Tarikan',
                            ),
                            'Food' => communityText(
                              context,
                              'Food',
                              '美食',
                              'Makanan',
                            ),
                            'Tips' => communityText(
                              context,
                              'Tips',
                              '贴士',
                              'Petua',
                            ),
                            _ => communityText(context, 'All', '全部', 'Semua'),
                          }),
                          selected: _topic == topic,
                          onSelected: (_) => setState(() => _topic = topic),
                        ),
                      FilterChip(
                        avatar: const Icon(Icons.bookmark_outline, size: 18),
                        label: Text(
                          communityText(context, 'Saved', '已收藏', 'Disimpan'),
                        ),
                        selected: _savedOnly,
                        onSelected: (v) => setState(() => _savedOnly = v),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          if (posts.isEmpty)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Text(
                  communityText(
                    context,
                    'No posts here yet. Try another filter or bookmark a post.',
                    '暂无帖子。请更换筛选，或先收藏帖子。',
                    'Tiada siaran. Cuba penapis lain atau simpan siaran.',
                  ),
                ),
              ),
            ),
          SliverList.builder(
            itemCount: posts.length,
            itemBuilder: (context, index) {
              final post = posts[index];
              return Padding(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
                child: Card(
                  clipBehavior: Clip.antiAlias,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      ListTile(
                        leading: const CircleAvatar(
                          child: Icon(Icons.person_outline),
                        ),
                        title: Text(post.author),
                        subtitle: Text(post.place),
                        trailing: const Icon(Icons.location_on_outlined),
                      ),
                      InkWell(
                        onTap: () => _open(post),
                        child: AspectRatio(
                          aspectRatio: 4 / 3,
                          child: Image.asset(
                            post.asset,
                            fit: BoxFit.cover,
                            semanticLabel: post.place,
                          ),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.all(16),
                        child: Text(
                          post.body,
                          maxLines: 3,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Wrap(
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          IconButton(
                            tooltip: communityText(
                              context,
                              'Like',
                              '点赞',
                              'Suka',
                            ),
                            isSelected: post.liked,
                            selectedIcon: const Icon(Icons.favorite),
                            icon: const Icon(Icons.favorite_border),
                            onPressed: () =>
                                setState(() => post.liked = !post.liked),
                          ),
                          IconButton(
                            tooltip: communityText(
                              context,
                              'Comments',
                              '评论',
                              'Komen',
                            ),
                            icon: Badge(
                              label: Text('${post.comments.length}'),
                              isLabelVisible: post.comments.isNotEmpty,
                              child: const Icon(Icons.chat_bubble_outline),
                            ),
                            onPressed: () => _open(post),
                          ),
                          IconButton(
                            tooltip: communityText(
                              context,
                              'Save post',
                              '收藏帖子',
                              'Simpan siaran',
                            ),
                            isSelected: post.saved,
                            selectedIcon: const Icon(Icons.bookmark),
                            icon: const Icon(Icons.bookmark_outline),
                            onPressed: () =>
                                setState(() => post.saved = !post.saved),
                          ),
                          TextButton(
                            onPressed: () => _open(post),
                            child: Text(
                              communityText(
                                context,
                                'Read story',
                                '查看帖子',
                                'Baca kisah',
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
          const SliverToBoxAdapter(child: SizedBox(height: 100)),
        ],
      ),
    );
  }
}

class _PostDetail extends StatefulWidget {
  const _PostDetail({required this.post});
  final CommunityPost post;
  @override
  State<_PostDetail> createState() => _PostDetailState();
}

class _PostDetailState extends State<_PostDetail> {
  final _comment = TextEditingController();
  @override
  void dispose() {
    _comment.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text(widget.post.place)),
    body: ListView(
      padding: const EdgeInsets.all(20),
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: Image.asset(
            widget.post.asset,
            semanticLabel: widget.post.place,
          ),
        ),
        const SizedBox(height: 16),
        Text(
          widget.post.author,
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 12),
        Text(widget.post.body),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          children: [
            FilterChip(
              label: Text(communityText(context, 'Like', '点赞', 'Suka')),
              selected: widget.post.liked,
              onSelected: (v) => setState(() => widget.post.liked = v),
            ),
            FilterChip(
              label: Text(
                communityText(context, 'Save post', '收藏帖子', 'Simpan siaran'),
              ),
              selected: widget.post.saved,
              onSelected: (v) => setState(() => widget.post.saved = v),
            ),
          ],
        ),
        const Divider(height: 32),
        Text(
          communityText(
            context,
            'Comments · session preview',
            '评论 · 当前会话预览',
            'Komen · pratonton sesi',
          ),
          style: Theme.of(context).textTheme.titleMedium,
        ),
        for (final comment in widget.post.comments)
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.person_outline),
            title: Text(comment),
          ),
        const SizedBox(height: 16),
        TextField(
          controller: _comment,
          minLines: 1,
          maxLines: 4,
          maxLength: 500,
          decoration: InputDecoration(
            labelText: communityText(
              context,
              'Write a comment',
              '写评论',
              'Tulis komen',
            ),
            border: const OutlineInputBorder(),
          ),
        ),
        Align(
          alignment: Alignment.centerRight,
          child: FilledButton(
            onPressed: () {
              final text = _comment.text.trim();
              if (text.isEmpty) return;
              setState(() => widget.post.comments.add(text));
              _comment.clear();
            },
            child: Text(
              communityText(context, 'Add comment', '添加评论', 'Tambah komen'),
            ),
          ),
        ),
      ],
    ),
  );
}

/// Prototype composer. Only text/location drafts are persisted; photos are
/// explicitly session-only until the durable media repository is implemented.
class CommunityComposer extends StatefulWidget {
  const CommunityComposer({super.key});
  @override
  State<CommunityComposer> createState() => _CommunityComposerState();
}

class _CommunityComposerState extends State<CommunityComposer> {
  final _body = TextEditingController();
  final _place = TextEditingController();
  final List<Uint8List> _photos = [];
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
        jsonEncode({'body': _body.text, 'place': _place.text}),
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
              padding: const EdgeInsets.all(20),
              children: [
                Text(
                  communityText(
                    context,
                    'Preview only · No public uploads yet. Save a text draft to continue later. Photos are not saved.',
                    '仅供预览 · 暂不公开上传。可保存文字草稿，照片不会保存。',
                    'Pratonton sahaja · Tiada muat naik awam. Draf teks boleh disimpan; foto tidak disimpan.',
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
                OutlinedButton.icon(
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
                      communityText(
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
                OutlinedButton(
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
