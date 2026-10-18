class ApiKeys {
  static const openTripMap = String.fromEnvironment('OPENTRIPMAP_API_KEY');
  static const openRouteService = String.fromEnvironment('ORS_API_KEY');
  static const openWeatherMapEnv = String.fromEnvironment(
    'OPENWEATHERMAP_API_KEY',
    defaultValue: '73fa52f0f056096288c44630ee67978e',
  );

  static String? _runtimeWeatherKey;
  static String get openWeatherMap => _runtimeWeatherKey ?? openWeatherMapEnv;
  static set openWeatherMap(String key) => _runtimeWeatherKey = key;

  static const googleMapsEnv = String.fromEnvironment(
    'GOOGLE_MAPS_API_KEY',
    defaultValue: 'AIzaSyDAPLDpQt61HmTptGwswe9usaUVRoxhcMw',
  );

  // Allow setting or overriding Google Maps key dynamically at runtime
  static String? _runtimeGoogleKey;
  static String get googleMaps => _runtimeGoogleKey ?? googleMapsEnv;
  static set googleMaps(String key) => _runtimeGoogleKey = key;

  static bool get hasOpenTripMapKey => openTripMap.trim().isNotEmpty;
  static bool get hasOpenRouteServiceKey => openRouteService.trim().isNotEmpty;
  static bool get hasOpenWeatherMapKey => openWeatherMap.trim().isNotEmpty;
  static bool get hasGoogleMapsKey => googleMaps.trim().isNotEmpty;
}
