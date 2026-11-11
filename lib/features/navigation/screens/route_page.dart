import 'package:smart_travel_planner/l10n/localized_labels.dart';
import 'package:flutter/material.dart';

import 'package:smart_travel_planner/shared/utils/demo_feedback.dart';
import 'package:smart_travel_planner/shared/widgets/app_header.dart';
import 'package:smart_travel_planner/features/navigation/widgets/route_map.dart';
import 'package:smart_travel_planner/features/itinerary/widgets/summary_bar.dart';

class RoutePage extends StatelessWidget {
  const RoutePage({super.key});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
      children: [
        AppHeader(
          title: context.l10n.routeMap,
          subtitle: context.l10n.tapMapPinsToViewPlaceDetails,
        ),
        const SizedBox(height: 18),
        const MockMap(),
        const SizedBox(height: 14),
        const SummaryBar(),
        const SizedBox(height: 14),
        FilledButton.icon(
          onPressed: () => runDemoLoadingAction(
            context,
            loadingLabel: context.l10n.optimizingRoute,
            successMessage:
                context.l10n.routeOptimizedTravelTimeReducedBy45Minutes,
            icon: Icons.route_outlined,
          ),
          icon: const Icon(Icons.route_outlined),
          label: Text(context.l10n.optimizeRoute),
          style: primaryFilledButtonStyle(),
        ),
        const SizedBox(height: 10),
        OutlinedButton.icon(
          onPressed: () => showDemoSnackBar(
            context,
            context.l10n.mapCenteredOnYourCurrentLocation,
            icon: Icons.my_location,
          ),
          icon: const Icon(Icons.my_location),
          label: Text(context.l10n.reCenter),
          style: demoOutlinedButtonStyle(),
        ),
      ],
    );
  }
}
