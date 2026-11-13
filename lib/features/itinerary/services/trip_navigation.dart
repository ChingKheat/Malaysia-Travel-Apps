import 'package:smart_travel_planner/shared/models/travel_stop.dart';
import 'package:url_launcher/url_launcher.dart';

enum TripNavigationMode { waze, moovit, maps, grab }

class TripNavigation {
  static bool hasCoordinates(TravelStop stop) =>
      stop.latitude.abs() <= 90 &&
      stop.longitude.abs() <= 180 &&
      (stop.latitude != 0 || stop.longitude != 0);

  static String coordinates(TravelStop stop) =>
      '${stop.latitude},${stop.longitude}';

  static Uri maps(TravelStop? origin, TravelStop destination, String mode) =>
      Uri.https('www.google.com', '/maps/dir/', {
        'api': '1',
        if (origin != null && hasCoordinates(origin))
          'origin': coordinates(origin),
        'destination': coordinates(destination),
        'travelmode': mode,
      });

  static List<Uri> links(
    TripNavigationMode option,
    TravelStop? origin,
    TravelStop destination,
    String travelMode,
  ) {
    if (!hasCoordinates(destination)) return [];
    final mode = switch (travelMode) {
      'Public Transport' => 'transit',
      'Walking' => 'walking',
      _ => 'driving',
    };
    return switch (option) {
      TripNavigationMode.waze => [
        Uri.https('waze.com', '/ul', {
          'll': coordinates(destination),
          'navigate': 'yes',
        }),
        maps(origin, destination, 'driving'),
      ],
      TripNavigationMode.moovit => [
        Uri(
          scheme: 'moovit',
          host: 'directions',
          query:
              {
                    'dest_lat': '${destination.latitude}',
                    'dest_lon': '${destination.longitude}',
                    'dest_name': destination.title,
                    if (origin != null && hasCoordinates(origin)) ...{
                      'orig_lat': '${origin.latitude}',
                      'orig_lon': '${origin.longitude}',
                      'orig_name': origin.title,
                    },
                    'auto_run': 'true',
                    'partner_id': 'Smart Travel Planner',
                  }.entries
                  .map(
                    (entry) =>
                        '${entry.key}=${Uri.encodeComponent(entry.value)}',
                  )
                  .join('&'),
        ),
        maps(origin, destination, 'transit'),
      ],
      TripNavigationMode.maps => [maps(origin, destination, mode)],
      TripNavigationMode.grab => [Uri.https('www.grab.com', '/my/transport/')],
    };
  }

  static Future<bool> open(
    List<Uri> links, {
    Future<bool> Function(Uri)? launch,
  }) async {
    final openLink =
        launch ?? (uri) => launchUrl(uri, mode: LaunchMode.externalApplication);
    for (final link in links) {
      try {
        if (await openLink(link)) return true;
      } on Exception {
        // Try the next provider when this app or scheme is unavailable.
      }
    }
    return false;
  }
}
