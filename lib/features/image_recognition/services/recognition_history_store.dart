import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:smart_travel_planner/features/image_recognition/models/recognition_result.dart';

typedef RecognitionHistoryEntry = ({RecognitionResult result, String? photoId});

/// Keeps the history index and its private photo files scoped to one account.
class RecognitionHistoryStore {
  RecognitionHistoryStore({
    required String userId,
    Future<Directory> Function()? applicationDirectory,
  }) : _key = 'recognition_history_v1:$userId',
       _folder = base64Url.encode(utf8.encode(userId)),
       _applicationDirectory =
           applicationDirectory ?? getApplicationSupportDirectory;

  final String _key;
  final String _folder;
  final Future<Directory> Function() _applicationDirectory;
  List<RecognitionHistoryEntry> _memory = [];
  final _sessionPhotos = <String, Uint8List>{};
  static const maxEntries = 30;
  static final _validId = RegExp(r'^[0-9a-f-]{36}$');

  Future<List<RecognitionHistoryEntry>> load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _memory = _readIndex(prefs.getString(_key));
    } catch (_) {
      // Keep session history usable if persistent storage is unavailable.
    }
    return List.unmodifiable(_memory);
  }

  List<RecognitionHistoryEntry> _readIndex(String? index) {
    final saved = jsonDecode(index ?? '[]');
    if (saved is! List) return [];
    final items = <RecognitionHistoryEntry>[];
    for (final value in saved.take(maxEntries)) {
      try {
        final json = Map<String, dynamic>.from(value);
        final id = json['photoId'];
        items.add((
          result: RecognitionResult.fromJson(json),
          photoId: id is String && _validId.hasMatch(id) ? id : null,
        ));
      } catch (_) {
        // One corrupt entry must not hide the remaining local history.
      }
    }
    return items;
  }

  Future<File> _photoFile(String id) async {
    final root = await _applicationDirectory();
    return File.fromUri(root.uri.resolve('scan_photos/$_folder/$id'));
  }

  Future<Uint8List?> loadPhoto(String? id) async {
    if (id == null || !_validId.hasMatch(id)) return null;
    if (_sessionPhotos[id] case final photo?) return photo;
    try {
      return await (await _photoFile(id)).readAsBytes();
    } catch (_) {
      return null;
    }
  }

  Future<bool> save(
    List<RecognitionHistoryEntry> entries, {
    (String, Uint8List)? photo,
  }) async {
    _memory = entries.take(maxEntries).toList();
    final activeIds = _memory.map((entry) => entry.photoId).nonNulls.toSet();
    _sessionPhotos.removeWhere((id, _) => !activeIds.contains(id));
    File? staged;
    if (photo case (
      final id,
      final bytes,
    ) when _validId.hasMatch(id) && activeIds.contains(id)) {
      _sessionPhotos[id] = bytes;
      try {
        staged = await _photoFile(id);
        await staged.parent.create(recursive: true);
        await staged.writeAsBytes(bytes, flush: true);
      } catch (_) {
        await _deletePhoto(staged);
        staged = null;
      }
    }
    try {
      final prefs = await SharedPreferences.getInstance();
      List<RecognitionHistoryEntry> previous = [];
      try {
        previous = _readIndex(prefs.getString(_key));
      } on FormatException {
        // A fresh index replaces damaged JSON.
      }
      final saved = await prefs.setString(
        _key,
        jsonEncode([
          for (final entry in _memory)
            {...entry.result.toJson(), 'photoId': ?entry.photoId},
        ]),
      );
      if (saved) {
        if (staged != null) _sessionPhotos.remove(photo!.$1);
        for (final id in previous.map((entry) => entry.photoId).nonNulls) {
          if (activeIds.contains(id)) continue;
          try {
            await _deletePhoto(await _photoFile(id));
          } catch (_) {
            // File storage may be unavailable while the index is writable.
          }
        }
        return true;
      }
    } catch (_) {
      // Preserve the current session when persistent storage is unavailable.
    }
    await _deletePhoto(staged);
    return false;
  }

  Future<void> _deletePhoto(File? file) async {
    try {
      await file?.delete();
    } catch (_) {
      // Missing or unavailable files do not prevent history access.
    }
  }
}
