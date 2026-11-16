import 'dart:async';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/theme/app_colors.dart';
import '../auth/services/auth_service.dart';
import '../community/community_page.dart' show communityText;
import 'messaging_service.dart';

String _t(BuildContext c, String en, String zh, String ms) =>
    communityText(c, en, zh, ms);

class MessagesInbox extends StatefulWidget {
  const MessagesInbox({super.key});
  @override
  State<MessagesInbox> createState() => _MessagesInboxState();
}

class _MessagesInboxState extends State<MessagesInbox>
    with WidgetsBindingObserver {
  final service = MessagingService();
  List<Map<String, dynamic>> rows = [];
  bool loading = true, offline = false;
  RealtimeChannel? channel;
  SupabaseClient? subscribedClient;
  Timer? timer;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    AuthService().addListener(_auth);
    _start();
  }

  void _auth() {
    if (service.account != AuthService().currentUser?.uid && mounted) {
      setState(() {
        rows = [];
        loading = false;
        offline = true;
      });
      if (channel != null) {
        subscribedClient?.removeChannel(channel!);
        channel = null;
      }
      Navigator.of(context).maybePop();
    }
  }

  Future<void> _start() async {
    final cached = await service.read('inbox');
    if (!mounted || service.account != AuthService().currentUser?.uid) return;
    rows = cached;
    setState(() {});
    await refresh();
    if (!mounted) return;
    timer = Timer.periodic(const Duration(seconds: 30), (_) => refresh());
    final c = service.client;
    if (c == null) return;
    subscribedClient = c;
    channel = c
        .channel('inbox:${service.account}')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'private_conversations',
          callback: (_) => refresh(),
        )
        .subscribe();
  }

  Future<void> refresh() async {
    try {
      final data = await service.inbox();
      if (mounted && service.account == AuthService().currentUser?.uid) {
        setState(() {
          rows = data;
          offline = false;
          loading = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          offline = true;
          loading = false;
        });
      }
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) refresh();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    AuthService().removeListener(_auth);
    timer?.cancel();
    if (channel != null) subscribedClient?.removeChannel(channel!);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: AppColors.nightCanvas,
    appBar: AppBar(
      title: Text(_t(context, 'Messages', '消息', 'Mesej')),
      actions: [
        IconButton(
          onPressed: refresh,
          icon: const Icon(Icons.refresh),
          tooltip: _t(context, 'Retry', '重试', 'Cuba lagi'),
        ),
      ],
    ),
    body: Column(
      children: [
        if (offline)
          _Notice(
            text: service.client == null
                ? _t(
                    context,
                    'Sign in to sync messages. Cached messages may be out of date.',
                    '请登录以同步消息。缓存可能不是最新的。',
                    'Log masuk untuk menyegerakkan mesej. Cache mungkin lapuk.',
                  )
                : _t(
                    context,
                    'Connection unavailable. Showing cached messages.',
                    '连接不可用。正在显示缓存消息。',
                    'Sambungan tidak tersedia. Memaparkan mesej cache.',
                  ),
          ),
        Expanded(
          child: loading && rows.isEmpty
              ? const Center(child: CircularProgressIndicator())
              : rows.isEmpty
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text(
                      _t(
                        context,
                        'No conversations yet. Message someone from a community post.',
                        '还没有对话。可从社区帖子发送消息。',
                        'Belum ada perbualan. Hantar mesej melalui siaran komuniti.',
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                )
              : RefreshIndicator(
                  onRefresh: refresh,
                  child: ListView.builder(
                    itemCount: rows.length,
                    itemBuilder: (context, i) {
                      final row = rows[i];
                      final unread =
                          (row['unread_count'] as num?)?.toInt() ?? 0;
                      return ListTile(
                        leading: const CircleAvatar(child: Icon(Icons.person)),
                        title: Text(
                          row['display_name'] as String? ??
                              _t(context, 'Traveller', '旅友', 'Pengembara'),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontWeight: unread > 0
                                ? FontWeight.bold
                                : FontWeight.normal,
                          ),
                        ),
                        subtitle: Text(
                          row['preview'] as String? ??
                              _t(
                                context,
                                'Start a conversation',
                                '开始对话',
                                'Mulakan perbualan',
                              ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        trailing: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(_time(row['message_at'])),
                            if (unread > 0)
                              CircleAvatar(
                                radius: 11,
                                backgroundColor: AppColors.nightAccent,
                                child: Text(
                                  '$unread',
                                  style: const TextStyle(
                                    fontSize: 10,
                                    color: Colors.black,
                                  ),
                                ),
                              ),
                          ],
                        ),
                        onTap: () async {
                          await Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => PrivateChat(
                                id: row['conversation_id'] as String,
                                name:
                                    row['display_name'] as String? ??
                                    'Traveller',
                              ),
                            ),
                          );
                          refresh();
                        },
                      );
                    },
                  ),
                ),
        ),
      ],
    ),
  );
}

String _time(Object? value) {
  final d = DateTime.tryParse(value?.toString() ?? '')?.toLocal();
  return d == null ? '' : DateFormat.MMMd().add_Hm().format(d);
}

class _Notice extends StatelessWidget {
  const _Notice({required this.text});
  final String text;
  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    color: AppColors.nightAccentContainer,
    padding: const EdgeInsets.all(12),
    child: Text(text),
  );
}

class PrivateChat extends StatefulWidget {
  const PrivateChat({super.key, required this.id, required this.name});
  final String id, name;
  @override
  State<PrivateChat> createState() => _PrivateChatState();
}

class _PrivateChatState extends State<PrivateChat> with WidgetsBindingObserver {
  final service = MessagingService();
  final input = TextEditingController();
  final scroll = ScrollController();
  List<Map<String, dynamic>> rows = [];
  bool loading = true,
      offline = false,
      sending = false,
      older = false,
      hasMore = true;
  RealtimeChannel? channel;
  SupabaseClient? subscribedClient;
  Timer? timer;
  bool syncing = false;
  bool active = true;
  final delivering = <String>{};
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    AuthService().addListener(_auth);
    input.addListener(_inputChanged);
    _start();
  }

  void _inputChanged() {
    if (mounted) setState(() {});
  }

  void _auth() {
    if (service.account != AuthService().currentUser?.uid && mounted) {
      setState(() {
        rows = [];
        loading = false;
        offline = true;
      });
      if (channel != null) {
        subscribedClient?.removeChannel(channel!);
        channel = null;
      }
      Navigator.of(context).maybePop();
    }
  }

  Future<void> _start() async {
    final cached = await service.read('chat:${widget.id}');
    if (!mounted || service.account != AuthService().currentUser?.uid) return;
    rows = cached;
    setState(() {});
    await refresh();
    if (!mounted) return;
    timer = Timer.periodic(const Duration(seconds: 30), (_) => refresh());
    final c = service.client;
    if (c == null) return;
    subscribedClient = c;
    channel = c
        .channel('chat:${widget.id}')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'private_messages',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'conversation_id',
            value: widget.id,
          ),
          callback: (_) => refresh(),
        )
        .subscribe();
  }

  Future<void> _save() => service.write('chat:${widget.id}', rows);
  void _merge(List<Map<String, dynamic>> incoming) {
    final map = <String, Map<String, dynamic>>{
      for (final r in rows) r['id'] as String: r,
    };
    for (final r in incoming) {
      map[r['id'] as String] = {...r, 'status': 'sent'};
    }
    rows = map.values.toList()
      ..sort((a, b) {
        final x = (a['created_at'] as String).compareTo(
          b['created_at'] as String,
        );
        return x != 0 ? x : (a['id'] as String).compareTo(b['id'] as String);
      });
  }

  Future<void> refresh() async {
    if (syncing || sending || !active) return;
    syncing = true;
    try {
      final incoming = await service.history(widget.id);
      if (!mounted || service.account != AuthService().currentUser?.uid) return;
      final nearBottom =
          !scroll.hasClients ||
          scroll.position.maxScrollExtent - scroll.offset < 120;
      _merge(incoming);
      await service.markRead(widget.id);
      await _save();
      if (mounted) {
        setState(() {
          offline = false;
          loading = false;
        });
      }
      if (nearBottom) _bottom();
      for (final row in List<Map<String, dynamic>>.from(
        rows.where(
          (r) =>
              r['status'] == 'pending' &&
              (DateTime.tryParse(
                    r['retry_after'] as String? ?? '',
                  )?.isBefore(DateTime.now().toUtc()) ??
                  true),
        ),
      )) {
        await _deliver(row);
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          offline = true;
          loading = false;
        });
      }
    } finally {
      syncing = false;
    }
  }

  void _bottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && scroll.hasClients) {
        scroll.animateTo(
          scroll.position.maxScrollExtent,
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _deliver(Map<String, dynamic> row) async {
    final id = row['id'] as String;
    if (!delivering.add(id)) return;
    try {
      final sent = await service.send(row);
      _merge([sent]);
    } catch (_) {
      final index = rows.indexWhere((r) => r['id'] == id);
      if (index >= 0 && rows[index]['status'] != 'sent') {
        final attempts = (rows[index]['attempts'] as int? ?? 0) + 1;
        rows[index] = {
          ...rows[index],
          'status': attempts >= 4 ? 'failed' : 'pending',
          'attempts': attempts,
          'retry_after': DateTime.now()
              .toUtc()
              .add(Duration(seconds: 30 * (1 << (attempts - 1))))
              .toIso8601String(),
        };
      }
    } finally {
      delivering.remove(id);
    }
    await _save();
    if (mounted) setState(() {});
  }

  Future<void> _send() async {
    final text = input.text.trim();
    if (sending ||
        syncing ||
        text.isEmpty ||
        text.runes.length > MessagingService.maxLength) {
      return;
    }
    setState(() => sending = true);
    try {
      final row = await service.enqueue(widget.id, text);
      if (!mounted || service.account != AuthService().currentUser?.uid) return;
      input.clear();
      rows.add(row);
      setState(() {});
      _bottom();
      await _deliver(row);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              _t(
                context,
                'Could not save your message. Please retry.',
                '无法保存消息，请重试。',
                'Mesej tidak dapat disimpan. Cuba lagi.',
              ),
            ),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => sending = false);
    }
  }

  Future<void> _older() async {
    if (older || rows.isEmpty) return;
    setState(() => older = true);
    try {
      final incoming = await service.history(
        widget.id,
        before: rows.first['created_at'] as String,
      );
      _merge(incoming);
      hasMore = incoming.length == 50;
      await _save();
    } catch (_) {
      offline = true;
    }
    if (mounted) setState(() => older = false);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    active = state == AppLifecycleState.resumed;
    if (active) refresh();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    AuthService().removeListener(_auth);
    timer?.cancel();
    if (channel != null) subscribedClient?.removeChannel(channel!);
    input.dispose();
    scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: AppColors.nightCanvas,
    appBar: AppBar(
      title: Row(
        children: [
          const CircleAvatar(child: Icon(Icons.person)),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              widget.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    ),
    body: SafeArea(
      child: Column(
        children: [
          if (offline)
            _Notice(
              text: _t(
                context,
                'Connection unavailable. Messages may be out of date.',
                '连接不可用，消息可能不是最新的。',
                'Sambungan tidak tersedia. Mesej mungkin lapuk.',
              ),
            ),
          Expanded(
            child: loading && rows.isEmpty
                ? const Center(child: CircularProgressIndicator())
                : rows.isEmpty
                ? Center(
                    child: Text(
                      _t(
                        context,
                        'Start the conversation',
                        '开始对话',
                        'Mulakan perbualan',
                      ),
                    ),
                  )
                : ListView.builder(
                    controller: scroll,
                    padding: const EdgeInsets.all(16),
                    itemCount: rows.length + 1,
                    itemBuilder: (context, i) {
                      if (i == 0) {
                        return hasMore
                            ? TextButton(
                                onPressed: older ? null : _older,
                                child: Text(
                                  _t(
                                    context,
                                    'Load older messages',
                                    '加载较早的消息',
                                    'Muat mesej terdahulu',
                                  ),
                                ),
                              )
                            : const SizedBox.shrink();
                      }
                      final r = rows[i - 1];
                      final mine = r['sender_id'] == service.account;
                      final status = r['status'];
                      return Align(
                        alignment: mine
                            ? Alignment.centerRight
                            : Alignment.centerLeft,
                        child: Container(
                          constraints: BoxConstraints(
                            maxWidth: MediaQuery.sizeOf(context).width * .78,
                          ),
                          margin: const EdgeInsets.only(bottom: 10),
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: mine
                                ? AppColors.nightAccentContainer
                                : AppColors.nightRaised,
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(r['content'] as String),
                              const SizedBox(height: 4),
                              Wrap(
                                crossAxisAlignment: WrapCrossAlignment.center,
                                spacing: 8,
                                children: [
                                  Text(
                                    _time(r['created_at']),
                                    style: Theme.of(
                                      context,
                                    ).textTheme.bodySmall,
                                  ),
                                  if (mine && status != 'sent')
                                    Text(
                                      status == 'failed'
                                          ? _t(
                                              context,
                                              'Failed',
                                              '发送失败',
                                              'Gagal',
                                            )
                                          : _t(
                                              context,
                                              'Pending',
                                              '待发送',
                                              'Menunggu',
                                            ),
                                      style: Theme.of(
                                        context,
                                      ).textTheme.bodySmall,
                                    ),
                                  if (mine && status == 'failed')
                                    InkWell(
                                      onTap: () async {
                                        setState(() {
                                          r['status'] = 'pending';
                                          r['attempts'] = 0;
                                          r.remove('retry_after');
                                        });
                                        await _save();
                                        await _deliver(r);
                                      },
                                      child: Text(
                                        _t(context, 'Retry', '重试', 'Cuba lagi'),
                                        style: const TextStyle(
                                          color: AppColors.nightAccent,
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
          ),
          Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Expanded(
                  child: TextField(
                    controller: input,
                    minLines: 1,
                    maxLines: 5,
                    maxLength: MessagingService.maxLength,
                    decoration: InputDecoration(
                      hintText: _t(
                        context,
                        'Write a message',
                        '输入消息',
                        'Tulis mesej',
                      ),
                      counterText: '',
                      border: const OutlineInputBorder(),
                    ),
                  ),
                ),
                IconButton(
                  onPressed: sending || input.text.trim().isEmpty
                      ? null
                      : _send,
                  icon: const Icon(Icons.send_rounded),
                  tooltip: _t(context, 'Send', '发送', 'Hantar'),
                ),
              ],
            ),
          ),
        ],
      ),
    ),
  );
}
