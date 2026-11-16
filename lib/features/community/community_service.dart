import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/config/supabase_config.dart';
import '../auth/services/auth_service.dart';

class CommunityService {
  static const topics = ['Local Tip', 'Trip Log', 'Question', 'Photo'];
  static const _timeout = Duration(seconds: 10);
  static const _emptyFeed = <Map<String, dynamic>>[];

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

  Future<({List<Map<String, dynamic>> rows, bool unavailable})>
  loadFeed() async {
    final id = accountId;
    if (id == null) return (rows: _emptyFeed, unavailable: false);
    final key = 'community.feed.v1:${SupabaseConfig.supabaseUrl}:$id';
    try {
      final response = await _signedInClient
          .rpc('community_feed_v2')
          .timeout(_timeout);
      final rows = List<Map<String, dynamic>>.from(response as List);
      try {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString(key, jsonEncode(rows));
      } catch (_) {
        // The online feed is usable even when the device cache is unavailable.
      }
      return (rows: rows, unavailable: false);
    } catch (_) {
      try {
        final prefs = await SharedPreferences.getInstance();
        final cached = prefs.getString(key);
        if (cached != null) {
          return (
            rows: List<Map<String, dynamic>>.from(jsonDecode(cached) as List),
            unavailable: true,
          );
        }
      } catch (_) {
        // An unreadable cache leaves the feed unavailable until refresh.
      }
      return (rows: _emptyFeed, unavailable: true);
    }
  }

  /// Returns recent comments on the signed-in user's own posts, excluding
  /// comments they wrote themselves. The joined post filter is enforced by
  /// Postgres and remains subject to the existing community RLS policies.
  Future<List<Map<String, dynamic>>> loadCommentActivity() async {
    final userId = accountId;
    if (userId == null || !canSync) return const [];
    final since = DateTime.now()
        .subtract(const Duration(days: 30))
        .toUtc()
        .toIso8601String();
    final rows = await _signedInClient
        .from('community_comments')
        .select(
          'id, post_id, user_id, body, created_at, community_posts!inner(id, user_id)',
        )
        .eq('community_posts.user_id', userId)
        .neq('user_id', userId)
        .gte('created_at', since)
        .order('created_at', ascending: false)
        .limit(50)
        .timeout(_timeout);
    return List<Map<String, dynamic>>.from(rows);
  }

  /// Fetches a real post and its current reactions for a notification action.
  /// A deleted or inaccessible post returns null so callers can fail safely.
  Future<Map<String, dynamic>?> loadPostById(String postId) async {
    final userId = accountId;
    if (userId == null) return null;
    if (!canSync) {
      final feed = await loadFeed();
      for (final row in feed.rows) {
        if (row['id']?.toString() == postId) return row;
      }
      return null;
    }
    try {
      final post = await _signedInClient
          .from('community_posts')
          .select('id, user_id, author, place, topic, body, created_at')
          .eq('id', postId)
          .maybeSingle()
          .timeout(_timeout);
      if (post == null) return null;

      final results = await Future.wait([
        _signedInClient
            .from('community_comments')
            .select('id, user_id, body, created_at')
            .eq('post_id', postId)
            .order('created_at', ascending: true)
            .limit(30)
            .timeout(_timeout),
        _signedInClient
            .from('community_likes')
            .select('user_id')
            .eq('post_id', postId)
            .timeout(_timeout),
        _signedInClient
            .from('community_bookmarks')
            .select('post_id')
            .eq('post_id', postId)
            .eq('user_id', userId)
            .maybeSingle()
            .timeout(_timeout),
      ]);
      final comments = List<Map<String, dynamic>>.from(results[0] as List);
      final likes = List<Map<String, dynamic>>.from(results[1] as List);
      return {
        ...post,
        'likes_count': likes.length,
        'liked': likes.any((like) => like['user_id'] == userId),
        'saved': results[2] != null,
        'comments': [
          for (final comment in comments)
            {
              'id': comment['id'],
              'body': comment['body'],
              'is_mine': comment['user_id'] == userId,
            },
        ],
        'is_mine': post['user_id'] == userId,
      };
    } catch (_) {
      final feed = await loadFeed();
      for (final row in feed.rows) {
        if (row['id']?.toString() == postId) return row;
      }
      return null;
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
