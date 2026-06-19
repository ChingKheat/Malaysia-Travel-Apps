import 'package:flutter/material.dart';

import '../core/demo_feedback.dart';
import '../widgets/app_header.dart';
import '../widgets/route_map.dart';
import '../widgets/summary_bar.dart';

class RoutePage extends StatelessWidget {
  const RoutePage({super.key});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
      children: [
        const AppHeader(
          title: 'Route Map',
          subtitle: 'Tap map pins to view place details',
        ),
        const SizedBox(height: 18),
        const MockMap(),
        const SizedBox(height: 14),
        const SummaryBar(),
        const SizedBox(height: 14),
        FilledButton.icon(
          onPressed: () => runDemoLoadingAction(
            context,
            loadingLabel: 'Optimizing route…',
            successMessage:
                'Route optimized — travel time reduced by 45 minutes.',
            icon: Icons.route_outlined,
          ),
          icon: const Icon(Icons.route_outlined),
          label: const Text('Optimize Route'),
          style: primaryFilledButtonStyle(),
        ),
        const SizedBox(height: 10),
        OutlinedButton.icon(
          onPressed: () => showDemoSnackBar(
            context,
            'Map centered on your current location.',
            icon: Icons.my_location,
          ),
          icon: const Icon(Icons.my_location),
          label: const Text('Re-center'),
          style: demoOutlinedButtonStyle(),
        ),
      ],
    );
  }
}
