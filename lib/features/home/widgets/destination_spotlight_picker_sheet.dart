import 'package:flutter/material.dart';
import 'package:smart_travel_planner/core/theme/app_colors.dart';
import 'package:smart_travel_planner/features/home/models/spotlight_destination.dart';
import 'package:smart_travel_planner/l10n/app_localizations.dart';
import 'package:smart_travel_planner/l10n/localized_labels.dart';

/// Opens the Destination Spotlight picker sheet and returns the ordered list of
/// selected hubs when the traveler taps "Continue to planner", or `null` if
/// dismissed/cancelled.
Future<List<SpotlightDestination>?> showDestinationSpotlightPicker(
  BuildContext context,
) {
  return showModalBottomSheet<List<SpotlightDestination>>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: true,
    backgroundColor: AppColors.nightSurface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (_) => const DestinationSpotlightPickerSheet(),
  );
}

class DestinationSpotlightPickerSheet extends StatefulWidget {
  const DestinationSpotlightPickerSheet({super.key});

  @override
  State<DestinationSpotlightPickerSheet> createState() =>
      _DestinationSpotlightPickerSheetState();
}

class _DestinationSpotlightPickerSheetState
    extends State<DestinationSpotlightPickerSheet> {
  final List<String> _selectedIds = [];
  final TextEditingController _searchController = TextEditingController();
  late List<SpotlightDestination> _hubOrder;

  @override
  void initState() {
    super.initState();
    _hubOrder = shuffledSpotlightHubs();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _shuffleHubs() {
    setState(() {
      _hubOrder = shuffledSpotlightHubs();
    });
  }

  void _toggleDestination(String id) {
    setState(() {
      if (_selectedIds.contains(id)) {
        _selectedIds.remove(id);
      } else {
        _selectedIds.add(id);
      }
    });
  }

  List<SpotlightDestination> _visibleHubs(AppLocalizations l10n) {
    final q = _searchController.text.trim().toLowerCase();
    if (q.isEmpty) return _hubOrder;
    return _hubOrder.where((item) {
      final title = item.localizedTitle(l10n).toLowerCase();
      final region = item.localizedRegion(l10n).toLowerCase();
      final hub = item.hubName.toLowerCase();
      final state = item.stateName.toLowerCase();
      final highlight = item.highlightName?.toLowerCase() ?? '';
      return title.contains(q) ||
          region.contains(q) ||
          hub.contains(q) ||
          state.contains(q) ||
          highlight.contains(q);
    }).toList();
  }

  List<SpotlightDestination> get _orderedSelections {
    final byId = {for (final item in allSpotlightDestinations) item.id: item};
    return [
      for (final id in _selectedIds)
        if (byId[id] != null) byId[id]!,
    ];
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final visibleHubs = _visibleHubs(l10n);
    final maxHeight = MediaQuery.sizeOf(context).height * 0.88;

    return ConstrainedBox(
      constraints: BoxConstraints(maxHeight: maxHeight),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 4, 12, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        l10n.spotlightChooseDestinations,
                        style: const TextStyle(
                          color: AppColors.nightBody,
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    TextButton.icon(
                      key: const ValueKey('spotlight-shuffle-btn'),
                      onPressed: _shuffleHubs,
                      icon: const Icon(Icons.shuffle_rounded, size: 18),
                      label: Text(l10n.spotlightShuffle),
                      style: TextButton.styleFrom(
                        foregroundColor: AppColors.nightAccent,
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                      ),
                    ),
                    IconButton(
                      key: const ValueKey('spotlight-picker-close-btn'),
                      tooltip: l10n.close,
                      onPressed: () => Navigator.of(context).pop(),
                      constraints: const BoxConstraints(
                        minWidth: 48,
                        minHeight: 48,
                      ),
                      icon: const Icon(
                        Icons.close_rounded,
                        color: AppColors.nightMuted,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: Text(
                    l10n.spotlightPickerSubtitle,
                    style: const TextStyle(
                      color: AppColors.nightMuted,
                      fontSize: 13.5,
                      height: 1.4,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: TextField(
                    key: const ValueKey('spotlight-search-field'),
                    controller: _searchController,
                    onChanged: (_) => setState(() {}),
                    style: const TextStyle(
                      color: AppColors.nightBody,
                      fontSize: 14,
                    ),
                    decoration: InputDecoration(
                      hintText: l10n.spotlightSearchHint,
                      hintStyle: const TextStyle(
                        color: AppColors.nightMuted,
                        fontSize: 13.5,
                      ),
                      prefixIcon: const Icon(
                        Icons.search_rounded,
                        color: AppColors.nightMuted,
                        size: 20,
                      ),
                      suffixIcon: _searchController.text.isEmpty
                          ? null
                          : IconButton(
                              tooltip: l10n.clear,
                              onPressed: () {
                                _searchController.clear();
                                setState(() {});
                              },
                              icon: const Icon(
                                Icons.close_rounded,
                                size: 18,
                                color: AppColors.nightMuted,
                              ),
                            ),
                      filled: true,
                      fillColor: AppColors.nightRaised,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 12,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: const BorderSide(
                          color: AppColors.nightLine,
                        ),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: const BorderSide(
                          color: AppColors.nightLine,
                        ),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: const BorderSide(
                          color: AppColors.nightAccent,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          Flexible(
            child: visibleHubs.isEmpty
                ? Padding(
                    padding: const EdgeInsets.all(24),
                    child: Center(
                      child: Text(
                        l10n.spotlightNoMatchingHubs,
                        style: const TextStyle(
                          color: AppColors.nightMuted,
                          fontSize: 14,
                        ),
                      ),
                    ),
                  )
                : ListView.separated(
                    shrinkWrap: true,
                    padding: const EdgeInsets.fromLTRB(20, 4, 20, 16),
                    itemCount: visibleHubs.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 12),
                    itemBuilder: (context, index) {
                      final item = visibleHubs[index];
                      final orderIdx = _selectedIds.indexOf(item.id);
                      final isSelected = orderIdx >= 0;
                      final title = item.localizedTitle(l10n);
                      final region = item.localizedRegion(l10n);
                      final semanticLabel = isSelected
                          ? l10n.spotlightSelectedSemantics(title, region)
                          : l10n.spotlightNotSelectedSemantics(title, region);

                      return Semantics(
                        button: true,
                        selected: isSelected,
                        label: semanticLabel,
                        excludeSemantics: true,
                        child: Material(
                          color: Colors.transparent,
                          child: InkWell(
                            key: ValueKey('spotlight-option-${item.id}'),
                            borderRadius: BorderRadius.circular(16),
                            onTap: () => _toggleDestination(item.id),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 180),
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: isSelected
                                    ? Color.alphaBlend(
                                        AppColors.nightAccent.withValues(
                                          alpha: 0.1,
                                        ),
                                        AppColors.nightRaised,
                                      )
                                    : AppColors.nightRaised,
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(
                                  color: isSelected
                                      ? AppColors.nightAccent
                                      : AppColors.nightLine,
                                  width: isSelected ? 1.8 : 1.0,
                                ),
                              ),
                              child: Row(
                                children: [
                                  ClipRRect(
                                    borderRadius: BorderRadius.circular(12),
                                    child: item.imageAsset != null
                                        ? Image.asset(
                                            item.imageAsset!,
                                            width: 84,
                                            height: 72,
                                            fit: BoxFit.cover,
                                            excludeFromSemantics: true,
                                            errorBuilder: (_, _, _) =>
                                                const _SpotlightThumbFallback(),
                                          )
                                        : const _SpotlightThumbFallback(),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          title,
                                          style: const TextStyle(
                                            color: AppColors.nightBody,
                                            fontSize: 16,
                                            fontWeight: FontWeight.w700,
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          item.highlightName != null
                                              ? '$region · ${item.highlightName}'
                                              : region,
                                          maxLines: 2,
                                          overflow: TextOverflow.ellipsis,
                                          style: const TextStyle(
                                            color: AppColors.nightMuted,
                                            fontSize: 13,
                                          ),
                                        ),
                                        if (isSelected) ...[
                                          const SizedBox(height: 8),
                                          Container(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 8,
                                              vertical: 2,
                                            ),
                                            decoration: BoxDecoration(
                                              color: AppColors.nightAccent,
                                              borderRadius:
                                                  BorderRadius.circular(8),
                                            ),
                                            child: Text(
                                              orderIdx == 0
                                                  ? l10n.spotlightStartBadge
                                                  : l10n.spotlightStopOrder(
                                                      orderIdx + 1,
                                                    ),
                                              style: const TextStyle(
                                                color: AppColors.onNightAccent,
                                                fontSize: 11,
                                                fontWeight: FontWeight.w700,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Container(
                                    width: 28,
                                    height: 28,
                                    decoration: BoxDecoration(
                                      color: isSelected
                                          ? AppColors.nightAccent
                                          : Colors.transparent,
                                      shape: BoxShape.circle,
                                      border: Border.all(
                                        color: isSelected
                                            ? AppColors.nightAccent
                                            : AppColors.nightMuted,
                                        width: 1.5,
                                      ),
                                    ),
                                    child: isSelected
                                        ? const Icon(
                                            Icons.check_rounded,
                                            size: 18,
                                            color: AppColors.onNightAccent,
                                          )
                                        : null,
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
          ),
          Container(
            decoration: const BoxDecoration(
              border: Border(top: BorderSide(color: AppColors.nightLine)),
            ),
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
            child: SafeArea(
              top: false,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    l10n.spotlightSelectedCount(_selectedIds.length),
                    style: const TextStyle(
                      color: AppColors.nightMuted,
                      fontSize: 13,
                    ),
                  ),
                  const SizedBox(height: 12),
                  FilledButton(
                    key: const ValueKey('spotlight-continue-btn'),
                    onPressed: _selectedIds.isEmpty
                        ? null
                        : () => Navigator.of(context).pop(_orderedSelections),
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.nightAccent,
                      foregroundColor: AppColors.onNightAccent,
                      disabledBackgroundColor: AppColors.nightRaised,
                      disabledForegroundColor: AppColors.nightMuted,
                      minimumSize: const Size.fromHeight(48),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 14,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    child: Text(
                      l10n.spotlightContinueToPlanner,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SpotlightThumbFallback extends StatelessWidget {
  const _SpotlightThumbFallback();

  @override
  Widget build(BuildContext context) {
    return const SizedBox(
      width: 84,
      height: 72,
      child: ColoredBox(
        color: AppColors.nightSurface,
        child: Icon(
          Icons.place_outlined,
          color: AppColors.nightAccent,
          size: 26,
        ),
      ),
    );
  }
}
