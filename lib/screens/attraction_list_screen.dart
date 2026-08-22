import 'package:flutter/material.dart';

import '../core/app_colors.dart';
import '../core/app_decorations.dart';
import '../models/attraction.dart';
import '../services/location_service.dart';

class AttractionListScreen extends StatelessWidget {
  const AttractionListScreen({
    super.key,
    required this.attractions,
    required this.selectedStops,
    required this.onAttractionTap,
    required this.onToggleStop,
  });

  final List<Attraction> attractions;
  final List<Attraction> selectedStops;
  final ValueChanged<Attraction> onAttractionTap;
  final ValueChanged<Attraction> onToggleStop;

  @override
  Widget build(BuildContext context) {
    if (attractions.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 48),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.explore_outlined,
                size: 64,
                color: AppColors.primary.withValues(alpha: 0.3),
              ),
              const SizedBox(height: 16),
              Text(
                'No attractions loaded',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: AppColors.primaryDark,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Add an API key to load live attractions or search for places.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14,
                  color: AppColors.muted,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 28),
      itemCount: attractions.length,
      itemBuilder: (context, index) {
        final attraction = attractions[index];
        final selected = selectedStops.any(
          (item) => item.xid == attraction.xid,
        );

        return Container(
          margin: const EdgeInsets.only(bottom: 10),
          decoration: cardDecoration(),
          child: Material(
            color: Colors.transparent,
            borderRadius: BorderRadius.circular(18),
            child: ListTile(
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 14,
                vertical: 8,
              ),
              onTap: () => onAttractionTap(attraction),
              leading: CircleAvatar(
                backgroundColor: selected
                    ? AppColors.primary
                    : AppColors.primary.withValues(alpha: 0.12),
                child: Icon(
                  selected ? Icons.check : _getCategoryIcon(attraction.category),
                  color: selected ? Colors.white : AppColors.primary,
                ),
              ),
              title: Text(
                attraction.name,
                style: const TextStyle(fontWeight: FontWeight.w900),
              ),
              subtitle: Text(
                '${attraction.category}\n${_distanceLabel(attraction.distanceMeters)}',
                maxLines: 2,
              ),
              trailing: IconButton(
                tooltip: selected ? 'Remove from route' : 'Add to route',
                onPressed: () => onToggleStop(attraction),
                icon: Icon(selected ? Icons.remove_circle : Icons.add_circle),
                color: AppColors.primary,
              ),
            ),
          ),
        );
      },
    );
  }

  IconData _getCategoryIcon(String category) {
    final kind = category.toLowerCase();
    if (kind.contains('food') || kind.contains('cafe') || kind.contains('restaurant')) {
      return Icons.restaurant;
    }
    if (kind.contains('shop') || kind.contains('mall') || kind.contains('market') || kind.contains('shopping')) {
      return Icons.shopping_bag;
    }
    if (kind.contains('natural') || kind.contains('park') || kind.contains('nature') || kind.contains('garden') || kind.contains('forest') || kind.contains('beach')) {
      return Icons.park;
    }
    if (kind.contains('religion') || kind.contains('cultural') || kind.contains('historic') || kind.contains('architecture') || kind.contains('landmark') || kind.contains('monument') || kind.contains('sights') || kind.contains('temple') || kind.contains('museum')) {
      return Icons.museum;
    }
    return Icons.place_outlined;
  }

  String _distanceLabel(double? meters) {
    if (meters == null) return 'Distance not available';
    final area = LocationService().currentAreaName;
    return '${(meters / 1000).toStringAsFixed(1)} km from $area';
  }
}
