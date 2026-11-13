import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:smart_travel_planner/core/config/supabase_config.dart';
import 'package:smart_travel_planner/features/places/models/google_place_details.dart';
import 'package:smart_travel_planner/features/places/services/google_places_service.dart';

/// Maps place IDs to explicitly approved files already uploaded to Storage.
class PlacePhotoStorageService {
  static const String bucketName = 'place-photos';

  static const _approved = String.fromEnvironment(
    'APPROVED_PLACE_COVERS',
    defaultValue: '{}',
  );

  static bool isUsableLink(Object? value) {
    final uri = Uri.tryParse(value?.toString().trim() ?? '');
    return uri != null &&
        uri.scheme == 'https' &&
        uri.host.isNotEmpty &&
        !uri.host.endsWith('googleapis.com') &&
        !uri.host.endsWith('googleusercontent.com') &&
        !uri.queryParameters.containsKey('key') &&
        !uri.queryParameters.containsKey('token');
  }

  static Future<String?> approvedCover(String placeId) async {
    final path = (jsonDecode(_approved) as Map<String, dynamic>)[placeId];
    if (path == null) return null;
    if (path is! String ||
        !RegExp(
          r'^approved/[A-Za-z0-9_-]+\.(jpg|jpeg|png|webp)$',
        ).hasMatch(path)) {
      throw const FormatException('Invalid approved cover path');
    }
    final client = SupabaseConfig.client;
    if (client == null) throw StateError('Storage unavailable');
    final url = client.storage.from(bucketName).getPublicUrl(path);
    if (!isUsableLink(url)) throw StateError('Invalid public cover URL');
    final response = await http
        .head(Uri.parse(url))
        .timeout(const Duration(seconds: 8));
    if (response.statusCode != 200 ||
        !(response.headers['content-type'] ?? '').startsWith('image/')) {
      throw StateError('Approved image is unavailable');
    }
    return url;
  }

  /// Syncs the first official Google photo for [placeId] to Supabase Storage.
  static Future<String?> syncPhotoToStorage({
    required String placeId,
    required GooglePlacesService googleService,
    GooglePlacePhoto? photo,
    bool skipIfAlreadyCached = true,
  }) async {
    final client = SupabaseConfig.client;
    if (client == null) return null;

    try {
      final fileName = '$placeId.jpg';
      final publicUrl = client.storage.from(bucketName).getPublicUrl(fileName);

      if (skipIfAlreadyCached) {
        final existing = await client
            .from('places')
            .select('photo_url')
            .eq('place_id', placeId)
            .maybeSingle();
        final currentUrl = existing?['photo_url'] as String?;
        if (currentUrl != null &&
            currentUrl.contains(bucketName) &&
            currentUrl.startsWith('http')) {
          return currentUrl;
        }
      }

      GooglePlacePhoto? targetPhoto = photo;
      if (targetPhoto == null) {
        final details = await googleService.fetchDetails(placeId, basic: false);
        targetPhoto = details?.photos.firstOrNull;
      }
      if (targetPhoto == null) return null;

      final result = await googleService.fetchPhotoResult(targetPhoto);
      final bytes = result.bytes;
      if (bytes == null || bytes.isEmpty) return null;

      await client.storage.from(bucketName).uploadBinary(
        fileName,
        bytes,
        fileOptions: const FileOptions(
          contentType: 'image/jpeg',
          upsert: true,
        ),
      );

      try {
        await client
            .from('places')
            .update({'photo_url': publicUrl})
            .eq('place_id', placeId);
      } catch (_) {}

      return publicUrl;
    } catch (_) {
      return null;
    }
  }
}
