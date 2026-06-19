import 'package:flutter/material.dart';

import '../core/app_colors.dart';
import '../core/app_decorations.dart';
import '../core/demo_feedback.dart';
import '../data/malaysia_states.dart';
import '../widgets/app_header.dart';
import '../widgets/form_tile.dart';
import 'itinerary_ready_page.dart';

class PlannerPage extends StatefulWidget {
  const PlannerPage({super.key, required this.onItineraryReady});

  final VoidCallback onItineraryReady;

  @override
  State<PlannerPage> createState() => _PlannerPageState();
}

class _PlannerPageState extends State<PlannerPage> {
  int budget = 1;
  final interests = {'Food', 'Shopping'};
  String destination = 'Kuala Lumpur';
  DateTimeRange? travelDates;
  final adultsController = TextEditingController(text: '2');
  final seniorsController = TextEditingController();
  final childrenController = TextEditingController();

  static const _months = [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    travelDates = DateTimeRange(
      start: DateTime(now.year, now.month, now.day + 7),
      end: DateTime(now.year, now.month, now.day + 9),
    );
  }

  @override
  void dispose() {
    adultsController.dispose();
    seniorsController.dispose();
    childrenController.dispose();
    super.dispose();
  }

  String _formatDate(DateTime date) {
    return '${date.day} ${_months[date.month - 1]} ${date.year}';
  }

  String get _travelDateLabel {
    final dates = travelDates;
    if (dates == null) return 'Select travel dates';
    return '${_formatDate(dates.start)} - ${_formatDate(dates.end)}';
  }

  Future<void> _pickDestination() async {
    final selected = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (context) {
        return DraggableScrollableSheet(
          expand: false,
          initialChildSize: 0.65,
          minChildSize: 0.4,
          maxChildSize: 0.9,
          builder: (context, scrollController) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Padding(
                  padding: EdgeInsets.fromLTRB(20, 4, 20, 12),
                  child: Text(
                    'Select Destination',
                    style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900),
                  ),
                ),
                Expanded(
                  child: ListView.separated(
                    controller: scrollController,
                    itemCount: malaysiaStates.length,
                    separatorBuilder: (_, _) => const Divider(
                      height: 1,
                      indent: 20,
                      endIndent: 20,
                      color: AppColors.line,
                    ),
                    itemBuilder: (context, index) {
                      final state = malaysiaStates[index];
                      final isSelected = state == destination;
                      return ListTile(
                        title: Text(
                          '$state, Malaysia',
                          style: TextStyle(
                            fontWeight: isSelected
                                ? FontWeight.w800
                                : FontWeight.w600,
                            color: isSelected
                                ? AppColors.primary
                                : AppColors.ink,
                          ),
                        ),
                        trailing: isSelected
                            ? const Icon(Icons.check, color: AppColors.primary)
                            : null,
                        onTap: () => Navigator.pop(context, state),
                      );
                    },
                  ),
                ),
              ],
            );
          },
        );
      },
    );

    if (selected != null) {
      setState(() => destination = selected);
    }
  }

  Future<void> _pickTravelDates() async {
    final now = DateTime.now();
    final picked = await showDateRangePicker(
      context: context,
      firstDate: now,
      lastDate: now.add(const Duration(days: 365 * 2)),
      initialDateRange: travelDates,
      helpText: 'Select travel dates',
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.fromSeed(
              seedColor: AppColors.primary,
              primary: AppColors.primary,
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      setState(() => travelDates = picked);
    }
  }

  Future<void> _pickTravelers() async {
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (context) {
        return Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.viewInsetsOf(context).bottom,
          ),
          child: DraggableScrollableSheet(
            expand: false,
            initialChildSize: 0.45,
            minChildSize: 0.35,
            maxChildSize: 0.85,
            builder: (context, scrollController) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Padding(
                    padding: EdgeInsets.fromLTRB(20, 4, 20, 12),
                    child: Text(
                      'Travelers',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                  Expanded(
                    child: Container(
                      margin: const EdgeInsets.symmetric(horizontal: 20),
                      decoration: cardDecoration(),
                      child: TravelersSection(
                        adultsController: adultsController,
                        seniorsController: seniorsController,
                        childrenController: childrenController,
                        scrollController: scrollController,
                      ),
                    ),
                  ),
                  Padding(
                    padding: EdgeInsets.fromLTRB(
                      20,
                      12,
                      20,
                      20 + MediaQuery.paddingOf(context).bottom,
                    ),
                    child: FilledButton(
                      onPressed: () {
                        setState(() {});
                        Navigator.pop(context);
                      },
                      style: primaryFilledButtonStyle(),
                      child: const Text('Done'),
                    ),
                  ),
                ],
              );
            },
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;

    return SafeArea(
      child: ListView(
        padding: EdgeInsets.fromLTRB(20, 16, 20, 28 + bottomInset),
        keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
        children: [
        const AppHeader(
          title: 'Plan Your Trip',
          subtitle: 'Tell us your preferences',
        ),
        const SizedBox(height: 18),
        FormTile(
          label: 'Destination',
          value: '$destination, Malaysia',
          icon: Icons.place_outlined,
          onTap: _pickDestination,
        ),
        FormTile(
          label: 'Travel Date',
          value: _travelDateLabel,
          icon: Icons.calendar_month_outlined,
          onTap: _pickTravelDates,
        ),
        FormTile(
          label: 'Travelers',
          value: TravelersSection.summary(
            adultsController: adultsController,
            seniorsController: seniorsController,
            childrenController: childrenController,
          ),
          icon: Icons.group_outlined,
          onTap: _pickTravelers,
        ),
        const SizedBox(height: 10),
        const FieldLabel('Budget Per Day'),
        const SizedBox(height: 8),
        LayoutBuilder(
          builder: (context, constraints) {
            return SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: ConstrainedBox(
                constraints: BoxConstraints(minWidth: constraints.maxWidth),
                child: SegmentedButton<int>(
                  segments: const [
                    ButtonSegment(value: 0, label: Text('Low\n< RM150')),
                    ButtonSegment(value: 1, label: Text('Medium\nRM150-300')),
                    ButtonSegment(value: 2, label: Text('High\n> RM300')),
                  ],
                  selected: {budget},
                  onSelectionChanged: (value) {
                    setState(() => budget = value.first);
                    showDemoSnackBar(
                      context,
                      'Daily budget set to ${['Low', 'Medium', 'High'][value.first]}.',
                      icon: Icons.payments_outlined,
                    );
                  },
                ),
              ),
            );
          },
        ),
        const SizedBox(height: 18),
        const FieldLabel('Interests'),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children:
              [
                    'Culture',
                    'Food',
                    'Nature',
                    'Shopping',
                    'History',
                    'Adventure',
                    'Family',
                    'Nightlife',
                  ]
                  .map(
                    (interest) => FilterChip(
                      selected: interests.contains(interest),
                      label: Text(interest),
                      selectedColor: AppColors.primary.withValues(alpha: 0.16),
                      checkmarkColor: AppColors.primary,
                      onSelected: (selected) => setState(() {
                        selected
                            ? interests.add(interest)
                            : interests.remove(interest);
                      }),
                    ),
                  )
                  .toList(),
        ),
        const SizedBox(height: 22),
        FilledButton.icon(
          onPressed: () =>
              runDemoLoadingAction(
                context,
                loadingLabel: 'Building your itinerary…',
                successMessage: 'Itinerary generated — opening preview.',
                icon: Icons.auto_awesome,
                delay: const Duration(milliseconds: 1600),
              ).then((_) {
                if (!context.mounted) return;
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => ItineraryReadyPage(
                      onViewItinerary: widget.onItineraryReady,
                    ),
                  ),
                );
              }),
          icon: const Icon(Icons.auto_awesome),
          label: const Text('Generate My Itinerary'),
          style: primaryFilledButtonStyle(),
        ),
      ],
      ),
    );
  }
}
