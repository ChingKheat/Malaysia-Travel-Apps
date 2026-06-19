import 'package:flutter/material.dart';

import '../core/app_colors.dart';
import '../core/app_decorations.dart';
import '../models/attraction.dart';

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
                  selected ? Icons.check : Icons.place_outlined,
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

  String _distanceLabel(double? meters) {
    if (meters == null) return 'Distance available after route calculation';
    return '${(meters / 1000).toStringAsFixed(1)} km from Kuala Lumpur center';
  }
}
