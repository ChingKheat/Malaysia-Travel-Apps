class ApiKeys {
  static const openTripMap = String.fromEnvironment('OPENTRIPMAP_API_KEY');
  static const openRouteService = String.fromEnvironment('ORS_API_KEY');

  static bool get hasOpenTripMapKey => openTripMap.trim().isNotEmpty;
  static bool get hasOpenRouteServiceKey => openRouteService.trim().isNotEmpty;
}
