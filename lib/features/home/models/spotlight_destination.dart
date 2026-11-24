import 'dart:math';

import 'package:latlong2/latlong.dart';
import 'package:smart_travel_planner/features/itinerary/models/destination_leg.dart';
import 'package:smart_travel_planner/features/places/data/curated_attractions.dart';
import 'package:smart_travel_planner/features/places/utils/attraction_image_resolver.dart';
import 'package:smart_travel_planner/l10n/app_localizations.dart';
import 'package:smart_travel_planner/shared/data/malaysia_states.dart';
import 'package:smart_travel_planner/shared/models/attraction.dart';

/// Canonical destination option for Home's Destination Spotlight.
///
/// Identifiers, [stateName], and [hubName] are locale-invariant and verified
/// against [malaysiaStatesData] so language changes never alter planner inputs.
class SpotlightDestination {
  const SpotlightDestination({
    required this.id,
    required this.stateName,
    required this.hubName,
    required this.latitude,
    required this.longitude,
    this.imageAsset,
    this.highlightName,
  });

  final String id;
  final String stateName;
  final String hubName;
  final double latitude;
  final double longitude;
  final String? imageAsset;
  final String? highlightName;

  String localizedTitle(AppLocalizations l10n) => switch (id) {
    'kuala_lumpur' => l10n.spotlightPlaceKualaLumpur,
    'george_town' => l10n.spotlightPlaceGeorgeTown,
    'langkawi' => l10n.spotlightPlaceLangkawi,
    'johor_bahru' => l10n.spotlightPlaceJohorBahru,
    'batu_caves' => l10n.spotlightPlaceBatuCaves,
    _ => hubName,
  };

  String localizedRegion(AppLocalizations l10n) => switch (stateName) {
    'Kuala Lumpur' => l10n.spotlightRegionKualaLumpur,
    'Penang' => l10n.spotlightRegionPenang,
    'Kedah' => l10n.spotlightRegionKedah,
    'Johor' => l10n.spotlightRegionJohor,
    _ => stateName,
  };

  /// Builds a canonical [DestinationLeg] for this hub without falling back to
  /// a state's default center.
  DestinationLeg toDestinationLeg({int allocatedDays = 1, int sequence = 1}) {
    final leg = DestinationLeg.fromStateName(
      stateName,
      hubName: hubName,
      allocatedDays: allocatedDays,
      sequence: sequence,
    );
    return leg.copyWith(destinationId: id);
  }
}

/// One-time confirmed selection sent from Home Spotlight to [PlannerPage].
class SpotlightPlannerRequest {
  const SpotlightPlannerRequest({required this.id, required this.destinations});

  final int id;
  final List<SpotlightDestination> destinations;
}

/// Verified photo-backed destinations used for popup spotlight rotation.
const List<SpotlightDestination> spotlightDestinations = [
  SpotlightDestination(
    id: 'kuala_lumpur',
    stateName: 'Kuala Lumpur',
    hubName: 'Kuala Lumpur',
    imageAsset: 'assets/recognition/petronas.jpg',
    latitude: 3.1516964,
    longitude: 101.6942371,
    highlightName: 'Petronas Twin Towers (KLCC)',
  ),
  SpotlightDestination(
    id: 'george_town',
    stateName: 'Penang',
    hubName: 'George Town',
    imageAsset: 'assets/recognition/community_hero_penang.png',
    latitude: 5.4141619,
    longitude: 100.3287352,
    highlightName: 'George Town Street Art & Murals',
  ),
  SpotlightDestination(
    id: 'langkawi',
    stateName: 'Kedah',
    hubName: 'Langkawi',
    imageAsset: 'assets/recognition/explore_hero_langkawi.png',
    latitude: 6.3500,
    longitude: 99.8000,
    highlightName: 'Langkawi Sky Bridge & SkyCab',
  ),
  SpotlightDestination(
    id: 'johor_bahru',
    stateName: 'Johor',
    hubName: 'Johor Bahru',
    imageAsset: 'assets/recognition/tan_hiok_nee.jpg',
    latitude: 1.4581986,
    longitude: 103.7649059,
    highlightName: 'Tan Hiok Nee Cultural Street',
  ),
  SpotlightDestination(
    id: 'batu_caves',
    stateName: 'Kuala Lumpur',
    hubName: 'Batu Caves',
    imageAsset: 'assets/recognition/batu_caves.jpg',
    latitude: 3.2369148,
    longitude: 101.6833464,
    highlightName: 'Batu Caves Temple & Murugan Statue',
  ),
];

const _distance = Distance();

/// Dynamically builds all supported Malaysian destination hubs from
/// [malaysiaStatesData], pairing nearby curated highlights and bundled photos
/// when available with zero network calls.
final List<SpotlightDestination> allSpotlightDestinations = _buildAllHubs();

List<SpotlightDestination> _buildAllHubs() {
  final featuredByKey = {
    for (final item in spotlightDestinations)
      '${item.stateName}|${item.hubName}': item,
  };

  final results = <SpotlightDestination>[];
  for (final state in malaysiaStatesData) {
    for (final area in state.areas) {
      final key = '${state.name}|${area.name}';
      final featured = featuredByKey[key];
      if (featured != null) {
        results.add(featured);
        continue;
      }

      final id = area.name
          .toLowerCase()
          .replaceAll(RegExp(r'[^a-z0-9]+'), '_')
          .replaceAll(RegExp(r'^_+|_+$'), '');
      final areaPoint = LatLng(area.latitude, area.longitude);

      Attraction? bestPlace;
      var closestKm = double.infinity;
      for (final place in curatedAttractionsForState(state.name)) {
        final km = _distance.as(LengthUnit.Kilometer, areaPoint, place.point);
        if (km <= 12 && km < closestKm) {
          closestKm = km;
          bestPlace = place;
        }
      }

      final highlight = bestPlace?.name;
      final asset = bestPlace != null
          ? AttractionImageResolver.resolveAsset(bestPlace)
          : null;

      results.add(
        SpotlightDestination(
          id: id.isEmpty ? 'kuala_lumpur' : id,
          stateName: state.name,
          hubName: area.name,
          latitude: area.latitude,
          longitude: area.longitude,
          imageAsset: asset,
          highlightName: highlight,
        ),
      );
    }
  }
  return List.unmodifiable(results);
}

/// Picks a featured destination with a bundled photo for the login popup.
SpotlightDestination pickFeaturedSpotlight({Random? random}) {
  final rng = random ?? Random();
  return spotlightDestinations[rng.nextInt(spotlightDestinations.length)];
}

/// Returns all Malaysian hubs in a freshly shuffled order, keeping hubs with
/// bundled photos or curated highlights prioritized near the top.
List<SpotlightDestination> shuffledSpotlightHubs({Random? random}) {
  final rng = random ?? Random();
  final featured = <SpotlightDestination>[];
  final highlighted = <SpotlightDestination>[];
  final others = <SpotlightDestination>[];

  for (final item in allSpotlightDestinations) {
    if (item.imageAsset != null) {
      featured.add(item);
    } else if (item.highlightName != null) {
      highlighted.add(item);
    } else {
      others.add(item);
    }
  }

  featured.shuffle(rng);
  highlighted.shuffle(rng);
  others.shuffle(rng);
  return [...featured, ...highlighted, ...others];
}
