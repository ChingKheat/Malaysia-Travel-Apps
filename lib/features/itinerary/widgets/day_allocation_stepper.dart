import 'package:flutter/material.dart';
import 'package:smart_travel_planner/features/itinerary/models/destination_leg.dart';
import 'package:smart_travel_planner/features/itinerary/services/transfer_manager.dart';

/// Interactive stepper for distributing [totalDays] across any number of
/// selected Malaysian [DestinationLeg] hubs, enforcing sum == totalDays.
class DayAllocationStepper extends StatelessWidget {
  final int totalDays;
  final List<DestinationLeg> legs;
  final bool autoOptimizeOrder;
  final ValueChanged<List<DestinationLeg>> onChanged;
  final ValueChanged<bool>? onAutoOptimizeChanged;

  const DayAllocationStepper({
    super.key,
    required this.totalDays,
    required this.legs,
    required this.onChanged,
    this.autoOptimizeOrder = true,
    this.onAutoOptimizeChanged,
  });

  int get _allocatedSum => legs.fold(0, (sum, l) => sum + l.allocatedDays);
  int get _remainingDays => totalDays - _allocatedSum;

  void _updateLeg(int index, int delta) {
    final target = legs[index];
    final nextVal = target.allocatedDays + delta;
    if (nextVal < 1) return;

    final updated = List<DestinationLeg>.from(legs);

    if (delta > 0 && _remainingDays <= 0) {
      int donorIndex = -1;
      int maxDays = 1;
      for (int i = 0; i < updated.length; i++) {
        if (i != index && updated[i].allocatedDays > maxDays) {
          maxDays = updated[i].allocatedDays;
          donorIndex = i;
        }
      }
      if (donorIndex == -1) return;
      updated[donorIndex] = updated[donorIndex].copyWith(
        allocatedDays: updated[donorIndex].allocatedDays - 1,
      );
    }

    updated[index] = target.copyWith(allocatedDays: nextVal);
    onChanged(updated);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final isBalanced = _remainingDays == 0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: isBalanced
                ? colors.primaryContainer.withValues(alpha: 0.35)
                : colors.errorContainer.withValues(alpha: 0.35),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isBalanced ? colors.primary : colors.error,
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Total Trip: $totalDays days',
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              Text(
                isBalanced
                    ? 'All days allocated'
                    : _remainingDays > 0
                        ? '$_remainingDays day(s) unassigned'
                        : '${_remainingDays.abs()} day(s) over',
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: isBalanced ? colors.primary : colors.error,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            if (onAutoOptimizeChanged != null)
              Expanded(
                child: SwitchListTile.adaptive(
                  contentPadding: EdgeInsets.zero,
                  dense: true,
                  title: const Text('Auto-optimize route order'),
                  value: autoOptimizeOrder,
                  onChanged: onAutoOptimizeChanged,
                ),
              ),
            TextButton.icon(
              onPressed: () =>
                  onChanged(TransferManager.autoDistributeDays(legs, totalDays)),
              icon: const Icon(Icons.auto_fix_high, size: 16),
              label: const Text('Auto-split'),
            ),
          ],
        ),
        const SizedBox(height: 8),
        ...List.generate(legs.length, (i) {
          final leg = legs[i];
          final canDecrement = leg.allocatedDays > 1;
          final canIncrement = _remainingDays > 0 ||
              legs.any((other) => other != leg && other.allocatedDays > 1);
          final requiresFlight = i > 0 && legs[i - 1].region.requiresFlightTo(leg.region);

          return Container(
            margin: const EdgeInsets.only(bottom: 10),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: colors.surfaceContainerHighest.withValues(alpha: 0.4),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: colors.outlineVariant),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Stop ${i + 1}: ${leg.hubName}',
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        i == 0
                            ? '${leg.stateName} • Starting Hub'
                            : requiresFlight
                                ? '${leg.stateName} • Flight transfer'
                                : '${leg.stateName} • Includes transfer day',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: colors.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                Row(
                  children: [
                    IconButton.outlined(
                      onPressed: canDecrement ? () => _updateLeg(i, -1) : null,
                      icon: const Icon(Icons.remove, size: 18),
                    ),
                    SizedBox(
                      width: 44,
                      child: Text(
                        '${leg.allocatedDays}d',
                        textAlign: TextAlign.center,
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    IconButton.outlined(
                      onPressed: canIncrement ? () => _updateLeg(i, 1) : null,
                      icon: const Icon(Icons.add, size: 18),
                    ),
                  ],
                ),
              ],
            ),
          );
        }),
      ],
    );
  }
}
