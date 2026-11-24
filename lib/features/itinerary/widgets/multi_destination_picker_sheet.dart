import 'package:flutter/material.dart';
import 'package:smart_travel_planner/features/itinerary/models/destination_leg.dart';
import 'package:smart_travel_planner/features/itinerary/services/transfer_manager.dart';
import 'package:smart_travel_planner/features/itinerary/widgets/day_allocation_stepper.dart';
import 'package:smart_travel_planner/shared/data/malaysia_states.dart';

class MultiDestinationResult {
  final List<DestinationLeg> legs;
  final bool autoOptimizeOrder;

  const MultiDestinationResult({
    required this.legs,
    required this.autoOptimizeOrder,
  });
}

/// Bottom sheet allowing users to pick any number of Malaysian states (up to
/// [totalDays]) and allocate days across them.
class MultiDestinationPickerSheet extends StatefulWidget {
  final int totalDays;
  final List<DestinationLeg> initialLegs;
  final bool initialAutoOptimize;

  const MultiDestinationPickerSheet({
    super.key,
    required this.totalDays,
    this.initialLegs = const [],
    this.initialAutoOptimize = true,
  });

  @override
  State<MultiDestinationPickerSheet> createState() =>
      _MultiDestinationPickerSheetState();
}

class _MultiDestinationPickerSheetState
    extends State<MultiDestinationPickerSheet> {
  late List<DestinationLeg> _legs;
  late bool _autoOptimize;
  int _step = 0; // 0 = pick states, 1 = allocate days

  @override
  void initState() {
    super.initState();
    _legs = List<DestinationLeg>.from(widget.initialLegs);
    _autoOptimize = widget.initialAutoOptimize;
  }

  void _toggleState(String stateName) {
    final existingIdx = _legs.indexWhere(
      (l) => l.stateName.toLowerCase() == stateName.toLowerCase(),
    );
    setState(() {
      if (existingIdx >= 0) {
        _legs.removeAt(existingIdx);
      } else {
        if (_legs.length >= widget.totalDays) return;
        _legs.add(
          DestinationLeg.fromStateName(
            stateName,
            allocatedDays: 1,
            sequence: _legs.length + 1,
          ),
        );
      }
      if (_autoOptimize && _legs.length > 1) {
        _legs = TransferManager.optimizeLegOrder(_legs);
      }
    });
  }

  void _proceedToAllocation() {
    setState(() {
      if (_autoOptimize && _legs.length > 1) {
        _legs = TransferManager.optimizeLegOrder(_legs);
      }
      final sum = _legs.fold<int>(0, (s, l) => s + l.allocatedDays);
      if (sum != widget.totalDays) {
        _legs = TransferManager.autoDistributeDays(_legs, widget.totalDays);
      }
      _step = 1;
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final allocatedSum = _legs.fold<int>(0, (s, l) => s + l.allocatedDays);
    final canConfirm = _legs.length >= 2 && allocatedSum == widget.totalDays;

    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.8,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      builder: (context, scrollController) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 8),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      _step == 0
                          ? 'Select Destinations (${_legs.length}/${widget.totalDays} max)'
                          : 'Allocate ${widget.totalDays} Days',
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                  if (_step == 1)
                    TextButton(
                      onPressed: () => setState(() => _step = 0),
                      child: const Text('Edit States'),
                    ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Text(
                _step == 0
                    ? 'Choose 2 or more states across Malaysia. Route order optimizes automatically.'
                    : 'Adjust days per destination. Transfers are scheduled automatically.',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: colors.onSurfaceVariant,
                ),
              ),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: ListView(
                controller: scrollController,
                padding: const EdgeInsets.symmetric(horizontal: 20),
                children: _step == 0
                    ? [
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: malaysiaStates.map((state) {
                            final selected = _legs.any(
                              (l) =>
                                  l.stateName.toLowerCase() ==
                                  state.toLowerCase(),
                            );
                            final disabled =
                                !selected && _legs.length >= widget.totalDays;
                            return FilterChip(
                              label: Text(state),
                              selected: selected,
                              onSelected: disabled
                                  ? null
                                  : (_) => _toggleState(state),
                            );
                          }).toList(),
                        ),
                      ]
                    : [
                        DayAllocationStepper(
                          totalDays: widget.totalDays,
                          legs: _legs,
                          autoOptimizeOrder: _autoOptimize,
                          onAutoOptimizeChanged: (val) {
                            setState(() {
                              _autoOptimize = val;
                              if (val) {
                                _legs = TransferManager.optimizeLegOrder(_legs);
                              }
                            });
                          },
                          onChanged: (updated) =>
                              setState(() => _legs = updated),
                        ),
                      ],
              ),
            ),
            SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: _step == 0
                        ? (_legs.length >= 2 ? _proceedToAllocation : null)
                        : (canConfirm
                            ? () => Navigator.pop(
                                  context,
                                  MultiDestinationResult(
                                    legs: _legs,
                                    autoOptimizeOrder: _autoOptimize,
                                  ),
                                )
                            : null),
                    child: Text(
                      _step == 0
                          ? 'Next: Allocate Days (${_legs.length} selected)'
                          : 'Confirm Multi-City Route',
                    ),
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}
