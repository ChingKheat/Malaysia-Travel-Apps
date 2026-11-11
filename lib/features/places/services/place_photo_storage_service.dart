import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:smart_travel_planner/core/config/supabase_config.dart';
import 'package:smart_travel_planner/features/places/models/google_place_details.dart';
import 'package:smart_travel_planner/features/places/services/google_places_service.dart';

/// Manages caching real Google place photos into Supabase Storage.
/// Keeps the Google API key strictly server-side while giving the mobile
/// app permanent, direct, non-expiring public URLs for place cards.
class PlacePhotoStorageService {
  const PlacePhotoStorageService._();

  static const String bucketName = 'place-photos';

  /// Syncs the first official Google photo for [placeId] to Supabase Storage.
  /// Returns the permanent public storage URL, or null if unavailable.
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

      // Check if photo is already cached to conserve Google API quota
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

      // 1. If photo metadata is not provided, fetch details first
      GooglePlacePhoto? targetPhoto = photo;
      if (targetPhoto == null) {
        final details = await googleService.fetchDetails(placeId, basic: false);
        targetPhoto = details?.photos.firstOrNull;
      }
      if (targetPhoto == null) return null;

      // 2. Fetch image bytes securely through existing Supabase Edge Function proxy
      final result = await googleService.fetchPhotoResult(targetPhoto);
      final bytes = result.bytes;
      if (bytes == null || bytes.isEmpty) return null;

      // 3. Upload to Supabase Storage bucket 'place-photos'
      await client.storage.from(bucketName).uploadBinary(
        fileName,
        bytes,
        fileOptions: const FileOptions(
          contentType: 'image/jpeg',
          upsert: true,
        ),
      );

      // 4. Get public URL and save to places table (if admin permissions permit)
      try {
        await client
            .from('places')
            .update({'photo_url': publicUrl})
            .eq('place_id', placeId);
      } catch (_) {
        // Ignored: Non-admin users might not have UPDATE rights on public.places,
        // but the storage file is already uploaded and publicly resolvable.
      }

      return publicUrl;
    } catch (_) {
      return null;
    }
  }

  /// Batch caches official Google photos for a list of [placeIds].
  /// Safely stops if shouldContinue returns false.
  static Future<int> batchCachePhotos({
    required List<String> placeIds,
    required GooglePlacesService googleService,
    bool Function()? shouldContinue,
    void Function(int current, int total, int cached)? onProgress,
  }) async {
    var cachedCount = 0;
    for (var i = 0; i < placeIds.length; i++) {
      if (shouldContinue != null && !shouldContinue()) break;
      final placeId = placeIds[i];
      final url = await syncPhotoToStorage(
        placeId: placeId,
        googleService: googleService,
        skipIfAlreadyCached: true,
      );
      if (url != null) cachedCount++;
      onProgress?.call(i + 1, placeIds.length, cachedCount);
      // Brief pause between requests to prevent overwhelming the proxy
      await Future<void>.delayed(const Duration(milliseconds: 300));
    }
    return cachedCount;
  }
}
