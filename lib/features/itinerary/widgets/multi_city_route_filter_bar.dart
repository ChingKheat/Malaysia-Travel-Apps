import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:smart_travel_planner/core/theme/app_colors.dart';
import 'package:smart_travel_planner/features/itinerary/models/destination_leg.dart';

/// Compact Route Line + Sleek Underline Tabs for viewing multi-destination
/// Big Plans one state trip at a time.
class MultiCityRouteFilterBar extends StatelessWidget {
  final List<DestinationLeg> legs;
  final DateTime startDate;
  final int? selectedLegIndex; // null = All days
  final ValueChanged<int?> onSelectLeg;

  const MultiCityRouteFilterBar({
    super.key,
    required this.legs,
    required this.startDate,
    required this.selectedLegIndex,
    required this.onSelectLeg,
  });

  int get _totalDays =>
      legs.fold<int>(0, (sum, leg) => sum + leg.allocatedDays);

  @override
  Widget build(BuildContext context) {
    final routeLine = legs.map((leg) => leg.stateName).join(' → ');
    final fmt = DateFormat.MMMd(Localizations.localeOf(context).toString());

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // The complete route stays visible above the state filters.
        Row(
          children: [
            const Icon(
              Icons.route_outlined,
              color: AppColors.primary,
              size: 16,
            ),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                routeLine,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: AppColors.muted,
                ),
              ),
            ),
          ],
        ),

        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 8),
          decoration: BoxDecoration(
            color: AppColors.nightSurface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.nightLine),
          ),
          child: Column(
            children: [
              for (int i = 0; i < legs.length; i++)
                _RouteLegRow(
                  leg: legs[i],
                  dateRangeLabel: () {
                    final offset = legs
                        .take(i)
                        .fold<int>(0, (sum, leg) => sum + leg.allocatedDays);
                    final start = DateTime(
                      startDate.year,
                      startDate.month,
                      startDate.day + offset,
                    );
                    final end = DateTime(
                      start.year,
                      start.month,
                      start.day + legs[i].allocatedDays - 1,
                    );
                    return '${fmt.format(start)} – ${fmt.format(end)}';
                  }(),
                  isSelected: selectedLegIndex == i,
                  isLast: i == legs.length - 1,
                  onTap: () => onSelectLeg(i),
                ),
            ],
          ),
        ),
        const SizedBox(height: 6),

        // 2. Sleek Underline Tabs
        Container(
          decoration: const BoxDecoration(
            border: Border(
              bottom: BorderSide(color: AppColors.nightLine, width: 1),
            ),
          ),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            child: Row(
              children: [
                _UnderlineTab(
                  label: 'All (${_totalDays}d)',
                  selected: selectedLegIndex == null,
                  onTap: () => onSelectLeg(null),
                ),
                for (int i = 0; i < legs.length; i++)
                  _UnderlineTab(
                    label: '${legs[i].stateName} (${legs[i].allocatedDays}d)',
                    selected: selectedLegIndex == i,
                    onTap: () => onSelectLeg(i),
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _UnderlineTab extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _UnderlineTab({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(6),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(
              color: selected ? AppColors.primary : Colors.transparent,
              width: 2.5,
            ),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: selected ? FontWeight.w800 : FontWeight.w500,
            color: selected ? AppColors.primary : AppColors.muted,
          ),
        ),
      ),
    );
  }
}

class _RouteLegRow extends StatelessWidget {
  final DestinationLeg leg;
  final String dateRangeLabel;
  final bool isSelected;
  final bool isLast;
  final VoidCallback onTap;

  const _RouteLegRow({
    required this.leg,
    required this.dateRangeLabel,
    required this.isSelected,
    required this.isLast,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SizedBox(
              width: 20,
              child: Column(
                children: [
                  const SizedBox(height: 6),
                  Icon(
                    Icons.circle,
                    size: 9,
                    color: isSelected ? AppColors.primary : AppColors.muted,
                  ),
                  if (!isLast)
                    Expanded(
                      child: Container(width: 2, color: AppColors.nightLine),
                    ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${leg.stateName} (${leg.hubName})',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: isSelected
                                  ? FontWeight.w800
                                  : FontWeight.w600,
                              color: isSelected
                                  ? AppColors.primary
                                  : AppColors.ink,
                            ),
                          ),
                          Text(
                            '${leg.allocatedDays} ${leg.allocatedDays == 1 ? 'Day' : 'Days'} · $dateRangeLabel',
                            style: const TextStyle(
                              fontSize: 11,
                              color: AppColors.muted,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Icon(
                      Icons.chevron_right,
                      size: 18,
                      color: isSelected ? AppColors.primary : AppColors.muted,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
