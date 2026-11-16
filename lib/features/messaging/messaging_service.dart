import 'dart:async';
import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

import '../../core/config/supabase_config.dart';
import '../auth/services/auth_service.dart';

/// Account-scoped cache and idempotent message delivery. Never stores tokens.
class MessagingService {
  MessagingService() : account = AuthService().currentUser?.uid;
  final String? account;
  static const timeout = Duration(seconds: 10);
  static const maxLength = 4000;
  SupabaseClient? get client {
    final c = SupabaseConfig.client;
    return account != null &&
            AuthService().currentUser?.uid == account &&
            c?.auth.currentSession?.user.id == account
        ? c
        : null;
  }

  String _key(String name) =>
      'private_messages.v1:${SupabaseConfig.supabaseUrl}:$account:$name';

  Future<List<Map<String, dynamic>>> read(String name) async {
    if (account == null || AuthService().currentUser?.uid != account) return [];
    try {
      final p = await SharedPreferences.getInstance();
      final value = p.getString(_key(name));
      return value == null
          ? []
          : (jsonDecode(value) as List)
                .map((e) => Map<String, dynamic>.from(e as Map))
                .toList();
    } catch (_) {
      return [];
    }
  }

  Future<void> write(String name, List<Map<String, dynamic>> rows) async {
    if (account == null || AuthService().currentUser?.uid != account) return;
    final p = await SharedPreferences.getInstance();
    await p.setString(_key(name), jsonEncode(rows));
  }

  Future<List<Map<String, dynamic>>> inbox() async {
    final c = client;
    if (c == null) throw StateError('Authentication unavailable');
    final result = await c.rpc('private_inbox').timeout(timeout);
    final rows = (result as List)
        .map((e) => Map<String, dynamic>.from(e as Map))
        .toList();
    await write('inbox', rows);
    return rows;
  }

  Future<String> fromPost(String postId) async {
    final c = client;
    if (c == null) throw StateError('Authentication unavailable');
    return await c
            .rpc('private_conversation_from_post', params: {'post_id': postId})
            .timeout(timeout)
        as String;
  }

  Future<String> fromComment(String commentId) async {
    final c = client;
    if (c == null) throw StateError('Authentication unavailable');
    return await c
            .rpc(
              'private_conversation_from_comment',
              params: {'comment_id': commentId},
            )
            .timeout(timeout)
        as String;
  }

  Future<List<Map<String, dynamic>>> history(
    String id, {
    String? before,
  }) async {
    final c = client;
    if (c == null) throw StateError('Authentication unavailable');
    var query = c.from('private_messages').select().eq('conversation_id', id);
    if (before != null) query = query.lt('created_at', before);
    final data = await query
        .order('created_at', ascending: false)
        .order('id', ascending: false)
        .limit(50)
        .timeout(timeout);
    return data.map((e) => Map<String, dynamic>.from(e)).toList();
  }

  Future<void> markRead(String id) async {
    final c = client;
    if (c == null) throw StateError('Authentication unavailable');
    await c
        .rpc('private_messages_mark_read', params: {'chat_id': id})
        .timeout(timeout);
  }

  Future<Map<String, dynamic>> enqueue(String id, String text) async {
    final body = text.trim();
    if (account == null || body.isEmpty || body.runes.length > maxLength) {
      throw ArgumentError('Invalid message');
    }
    final row = <String, dynamic>{
      'id': const Uuid().v4(),
      'conversation_id': id,
      'sender_id': account,
      'content': body,
      'created_at': DateTime.now().toUtc().toIso8601String(),
      'status': 'pending',
    };
    final rows = await read('chat:$id');
    rows.add(row);
    await write('chat:$id', rows);
    return row;
  }

  Future<Map<String, dynamic>> send(Map<String, dynamic> row) async {
    final c = client;
    if (c == null) throw StateError('Authentication unavailable');
    final result = await c
        .rpc(
          'private_message_send',
          params: {
            'message_id': row['id'],
            'chat_id': row['conversation_id'],
            'message_text': row['content'],
          },
        )
        .timeout(timeout);
    return parseSentMessage(result);
  }

  /// PostgREST may return a composite result as a one-element array.
  static Map<String, dynamic> parseSentMessage(dynamic result) {
    final row = result is List && result.length == 1 ? result.single : result;
    if (row is! Map) throw const FormatException('Invalid send response');
    return Map<String, dynamic>.from(row)..['status'] = 'sent';
  }
}
