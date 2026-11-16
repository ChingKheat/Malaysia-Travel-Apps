import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/config/supabase_config.dart';
import '../auth/services/auth_service.dart';

class CommunityService {
  static const topics = ['Local Tip', 'Trip Log', 'Question', 'Photo'];
  static const _timeout = Duration(seconds: 10);

  SupabaseClient? get _client => SupabaseConfig.client;

  String? get accountId => AuthService().currentUser?.uid;

  bool get canSync {
    final id = accountId;
    return id != null && _client?.auth.currentSession?.user.id == id;
  }

  SupabaseClient get _signedInClient {
    if (!canSync) throw StateError('A Supabase session is required.');
    return _client!;
  }

  Future<List<Map<String, dynamic>>> loadFeed() async {
    final id = accountId;
    if (id == null) return [];
    final key = 'community.feed.v1:${SupabaseConfig.supabaseUrl}:$id';
    try {
      final response = await _signedInClient
          .rpc('community_feed')
          .timeout(_timeout);
      final rows = List<Map<String, dynamic>>.from(response as List);
      try {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString(key, jsonEncode(rows));
      } catch (_) {
        // The online feed is usable even when the device cache is unavailable.
      }
      return rows;
    } catch (_) {
      try {
        final prefs = await SharedPreferences.getInstance();
        final cached = prefs.getString(key);
        if (cached != null) {
          return List<Map<String, dynamic>>.from(jsonDecode(cached) as List);
        }
      } catch (_) {
        // A missing or unreadable cache falls back to the sample feed.
      }
      return [];
    }
  }

  Future<void> publish({
    required String id,
    required String body,
    required String place,
    required String topic,
  }) async {
    final client = _signedInClient;
    final name = AuthService().currentUser!.name.trim();
    await client
        .from('community_posts')
        .upsert({
          'id': id,
          'user_id': accountId,
          'author': name.isEmpty
              ? 'Traveller'
              : String.fromCharCodes(name.runes.take(100)),
          'body': body,
          'place': place,
          'topic': topic,
        }, ignoreDuplicates: true)
        .timeout(_timeout);
  }

  Future<void> setReaction({
    required String postId,
    required bool saved,
    required bool selected,
  }) async {
    final client = _signedInClient;
    final userId = accountId!;
    final table = client.from(
      saved ? 'community_bookmarks' : 'community_likes',
    );
    if (selected) {
      await table
          .upsert({
            'post_id': postId,
            'user_id': userId,
          }, ignoreDuplicates: true)
          .timeout(_timeout);
    } else {
      await table
          .delete()
          .eq('post_id', postId)
          .eq('user_id', userId)
          .timeout(_timeout);
    }
  }

  Future<void> comment(String id, String postId, String body) async {
    await _signedInClient
        .from('community_comments')
        .upsert({
          'id': id,
          'post_id': postId,
          'user_id': accountId,
          'body': body,
        }, ignoreDuplicates: true)
        .timeout(_timeout);
  }
}
