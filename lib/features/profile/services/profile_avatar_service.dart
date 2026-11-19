import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:smart_travel_planner/core/config/supabase_config.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Keeps a device copy so the chosen photo remains visible while offline.
class ProfileAvatarService {
  ProfileAvatarService({this.rootDirectory});

  final Directory? rootDirectory;
  static const bucket = 'profile-avatars';
  static const maxBytes = 2 * 1024 * 1024;

  static String _localKey(String uid) => 'profile.avatar.local.v1:$uid';
  static String _pendingKey(String uid) => 'profile.avatar.pending.v1:$uid';

  static (String, String)? format(Uint8List bytes) {
    if (bytes.length < 12 || bytes.length > maxBytes) return null;
    if (bytes[0] == 0xff && bytes[1] == 0xd8 && bytes[2] == 0xff) {
      return ('jpg', 'image/jpeg');
    }
    if (bytes[0] == 0x89 &&
        bytes[1] == 0x50 &&
        bytes[2] == 0x4e &&
        bytes[3] == 0x47) {
      return ('png', 'image/png');
    }
    if (String.fromCharCodes(bytes.sublist(0, 4)) == 'RIFF' &&
        String.fromCharCodes(bytes.sublist(8, 12)) == 'WEBP') {
      return ('webp', 'image/webp');
    }
    return null;
  }

  static ImageProvider? imageProvider(String url) {
    if (url.isEmpty) return null;
    final uri = Uri.tryParse(url);
    if (uri?.scheme == 'file') return FileImage(File.fromUri(uri!));
    if (uri?.scheme == 'http' || uri?.scheme == 'https') {
      return NetworkImage(url);
    }
    return null;
  }

  Future<String?> saveLocal(String uid, Uint8List bytes) async {
    final imageFormat = format(bytes);
    if (imageFormat == null) return null;
    try {
      final directory =
          rootDirectory ??
          Directory(
            '${(await getApplicationDocumentsDirectory()).path}/profile_avatars',
          );
      await directory.create(recursive: true);
      final file = File('${directory.path}/$uid.${imageFormat.$1}');
      await file.writeAsBytes(bytes, flush: true);
      final url = file.uri.toString();
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_localKey(uid), url);
      await prefs.setBool(_pendingKey(uid), true);
      return url;
    } catch (_) {
      return null;
    }
  }

  Future<String?> localUrl(String uid) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final url = prefs.getString(_localKey(uid));
      if (url == null || !await File.fromUri(Uri.parse(url)).exists()) {
        return null;
      }
      return url;
    } catch (_) {
      return null;
    }
  }

  Future<void> syncPending(String uid) async {
    final client = SupabaseConfig.client;
    if (client == null || client.auth.currentUser?.id != uid) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      if (prefs.getBool(_pendingKey(uid)) != true) return;
      final url = await localUrl(uid);
      if (url == null) return;
      final bytes = await File.fromUri(Uri.parse(url)).readAsBytes();
      final imageFormat = format(bytes);
      if (imageFormat == null) return;
      final path = '$uid/avatar.${imageFormat.$1}';
      await client.storage
          .from(bucket)
          .uploadBinary(
            path,
            bytes,
            fileOptions: FileOptions(contentType: imageFormat.$2, upsert: true),
          )
          .timeout(const Duration(seconds: 25));
      final updated = await client
          .from('profiles')
          .update({'avatar_url': path})
          .eq('user_id', uid)
          .select('avatar_url')
          .maybeSingle()
          .timeout(const Duration(seconds: 10));
      if (updated?['avatar_url'] != path) return;
      if (client.auth.currentUser?.id == uid) {
        await prefs.setBool(_pendingKey(uid), false);
      }
    } catch (_) {
      // The local photo stays visible and sync retries on the next profile visit.
    }
  }

  Future<String> displayUrl(String uid, String storedUrl) async {
    final local = await localUrl(uid);
    try {
      final prefs = await SharedPreferences.getInstance();
      if (prefs.getBool(_pendingKey(uid)) == true && local != null) {
        return local;
      }
    } catch (_) {}
    if (storedUrl.startsWith('$uid/')) {
      final client = SupabaseConfig.client;
      if (client?.auth.currentUser?.id == uid) {
        try {
          return await client!.storage
              .from(bucket)
              .createSignedUrl(storedUrl, 7 * 24 * 60 * 60)
              .timeout(const Duration(seconds: 10));
        } catch (_) {}
      }
    }
    return local ?? storedUrl;
  }
}
