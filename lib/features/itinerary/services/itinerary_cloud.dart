import 'package:smart_travel_planner/core/config/supabase_config.dart';

abstract class ItineraryCloud {
  bool isAuthenticated(String userId);
  Future<void> save(Map<String, dynamic> trip);
  Future<void> delete(String userId, String itineraryId);
  Future<List<Map<String, dynamic>>> load(String userId);
}

class SupabaseItineraryCloud implements ItineraryCloud {
  @override
  bool isAuthenticated(String userId) =>
      SupabaseConfig.client?.auth.currentSession?.user.id == userId;
  @override
  Future<void> save(Map<String, dynamic> trip) async {
    await SupabaseConfig.client!
        .rpc('save_itinerary', params: {'payload': trip})
        .timeout(const Duration(seconds: 10));
  }

  @override
  Future<void> delete(String userId, String itineraryId) async {
    await SupabaseConfig.client!
        .from('itineraries')
        .delete()
        .eq('itinerary_id', itineraryId)
        .eq('user_id', userId)
        .timeout(const Duration(seconds: 10));
  }

  @override
  Future<List<Map<String, dynamic>>> load(String userId) async {
    final rows = await SupabaseConfig.client!
        .from('itineraries')
        .select('*, daily_schedules(*, itinerary_stops(*, places(*)))')
        .eq('user_id', userId)
        .timeout(const Duration(seconds: 10));
    return rows;
  }
}
