import 'package:flutter/material.dart';

import '../core/app_colors.dart';
import '../core/demo_feedback.dart';
import '../data/malaysia_states.dart';
import '../models/trip_preferences.dart';
import '../services/trip_preferences_service.dart';
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
  // Trip Preference Form State variables
  String? destination = 'Kuala Lumpur';
  DateTimeRange? travelDates;
  TimeOfDay? dailyStartTime = const TimeOfDay(hour: 8, minute: 0);
  TimeOfDay? dailyEndTime = const TimeOfDay(hour: 22, minute: 0);
  final Set<String> interests = {'Food', 'Shopping'};
  String budgetCategory = 'Medium';
  String travelMode = 'Driving';

  String? _errorMessage;
  Set<String> _highlightedEmptyFields = {};

  final List<TimeOfDay> _timeOptions = List.generate(
    18,
    (index) => TimeOfDay(hour: 6 + index, minute: 0),
  );

  static const _months = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
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

  String _formatDate(DateTime date) {
    return '${date.day} ${_months[date.month - 1]} ${date.year}';
  }

  String get _travelDateLabel {
    final dates = travelDates;
    if (dates == null) return 'Select travel dates';
    return '${_formatDate(dates.start)} - ${_formatDate(dates.end)}';
  }

  int get _calculatedDays {
    final dates = travelDates;
    if (dates == null) return 0;
    return dates.end.difference(dates.start).inDays + 1;
  }

  String _formatTimeOfDay(TimeOfDay? time) {
    if (time == null) return 'Select Time';
    final hour = time.hour.toString().padLeft(2, '0');
    final minute = time.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
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
                            fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                            color: isSelected ? AppColors.primary : AppColors.ink,
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
      setState(() {
        destination = selected;
        _errorMessage = null;
        _highlightedEmptyFields.remove('destination');
      });
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
      setState(() {
        travelDates = picked;
        _errorMessage = null;
        _highlightedEmptyFields.remove('numberOfDays');
      });
    }
  }

  void _handleGenerateItinerary() {
    demoHaptic();
    setState(() {
      _errorMessage = null;
      _highlightedEmptyFields.clear();
    });

    final currentPrefs = TripPreferences(
      destination: destination,
      numberOfDays: travelDates != null ? _calculatedDays : null,
      dailyStartTime: dailyStartTime,
      dailyEndTime: dailyEndTime,
      interests: interests.toList(),
      budgetCategory: budgetCategory,
      travelMode: travelMode,
    );

    // Validate using TripPreferencesService (FR300_3 to FR300_9)
    final validationResult = TripPreferencesService.validatePreferences(currentPrefs);

    if (!validationResult.success) {
      setState(() {
        _errorMessage = validationResult.message;
        _highlightedEmptyFields = validationResult.emptyFields;
      });
      return;
    }

    // Success (FR300_10 & FR300_11)
    showDemoSnackBar(
      context,
      TripPreferencesService.m1Success,
      icon: Icons.auto_awesome,
    );

    // Transition with demo loading effect
    runDemoLoadingAction(
      context,
      loadingLabel: 'Building your itinerary…',
      successMessage: 'Itinerary generated — opening preview.',
      icon: Icons.auto_awesome,
      delay: const Duration(milliseconds: 1600),
    ).then((_) {
      if (!mounted) return;
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => ItineraryReadyPage(
            onViewItinerary: widget.onItineraryReady,
          ),
        ),
      );
    });
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

          // Error Alerts Banner
          if (_errorMessage != null) ...[
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.red.shade50,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: Colors.red.shade200, width: 1.2),
              ),
              child: Row(
                children: [
                  Icon(Icons.error_outline_rounded, color: Colors.red.shade700, size: 22),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      _errorMessage!,
                      style: TextStyle(
                        color: Colors.red.shade900,
                        fontSize: 13.5,
                        fontWeight: FontWeight.w600,
                        height: 1.35,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
          ],

          // Destination Tile
          Container(
            decoration: BoxDecoration(
              border: _highlightedEmptyFields.contains('destination')
                  ? Border.all(color: Colors.red, width: 1.5)
                  : null,
              borderRadius: BorderRadius.circular(14),
            ),
            child: FormTile(
              label: 'Destination',
              value: destination != null ? '$destination, Malaysia' : 'Select State',
              icon: Icons.place_outlined,
              onTap: _pickDestination,
            ),
          ),
          const SizedBox(height: 12),

          // Travel Date (Calendar selector & Days calculation)
          Container(
            decoration: BoxDecoration(
              border: _highlightedEmptyFields.contains('numberOfDays')
                  ? Border.all(color: Colors.red, width: 1.5)
                  : null,
              borderRadius: BorderRadius.circular(14),
            ),
            child: FormTile(
              label: 'Travel Date',
              value: travelDates != null
                  ? '$_travelDateLabel ($_calculatedDays Days)'
                  : 'Select Travel Dates',
              icon: Icons.calendar_month_outlined,
              onTap: _pickTravelDates,
            ),
          ),
          const SizedBox(height: 16),

          // Daily Start & End Hours selector (Option A - Segmented hours selector)
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const FieldLabel('Start Hour'),
                    const SizedBox(height: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: _highlightedEmptyFields.contains('dailyStartTime')
                              ? Colors.red
                              : AppColors.line,
                          width: _highlightedEmptyFields.contains('dailyStartTime') ? 1.5 : 1,
                        ),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<TimeOfDay>(
                          value: dailyStartTime,
                          isExpanded: true,
                          hint: const Text('Start Time'),
                          items: _timeOptions.map((time) {
                            return DropdownMenuItem<TimeOfDay>(
                              value: time,
                              child: Text(_formatTimeOfDay(time)),
                            );
                          }).toList(),
                          onChanged: (val) {
                            setState(() {
                              dailyStartTime = val;
                              _errorMessage = null;
                            });
                          },
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const FieldLabel('End Hour'),
                    const SizedBox(height: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: _highlightedEmptyFields.contains('dailyEndTime')
                              ? Colors.red
                              : AppColors.line,
                          width: _highlightedEmptyFields.contains('dailyEndTime') ? 1.5 : 1,
                        ),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<TimeOfDay>(
                          value: dailyEndTime,
                          isExpanded: true,
                          hint: const Text('End Time'),
                          items: _timeOptions.map((time) {
                            return DropdownMenuItem<TimeOfDay>(
                              value: time,
                              child: Text(_formatTimeOfDay(time)),
                            );
                          }).toList(),
                          onChanged: (val) {
                            setState(() {
                              dailyEndTime = val;
                              _errorMessage = null;
                            });
                          },
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),

          // Budget Per Day selector
          const FieldLabel('Budget Category'),
          const SizedBox(height: 8),
          Container(
            decoration: BoxDecoration(
              border: _highlightedEmptyFields.contains('budgetCategory')
                  ? Border.all(color: Colors.red, width: 1.5)
                  : null,
              borderRadius: BorderRadius.circular(14),
            ),
            child: LayoutBuilder(
              builder: (context, constraints) {
                return SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: ConstrainedBox(
                    constraints: BoxConstraints(minWidth: constraints.maxWidth),
                    child: SegmentedButton<String>(
                      segments: const [
                        ButtonSegment(value: 'Low', label: Text('Low\n< RM150')),
                        ButtonSegment(value: 'Medium', label: Text('Medium\nRM150-300')),
                        ButtonSegment(value: 'High', label: Text('High\n> RM300')),
                      ],
                      selected: {budgetCategory},
                      onSelectionChanged: (value) {
                        setState(() {
                          budgetCategory = value.first;
                          _errorMessage = null;
                        });
                      },
                    ),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 18),

          // Travel Mode (Driving / Walking / Public Transport)
          const FieldLabel('Travel Mode'),
          const SizedBox(height: 8),
          Container(
            decoration: BoxDecoration(
              border: _highlightedEmptyFields.contains('travelMode')
                  ? Border.all(color: Colors.red, width: 1.5)
                  : null,
              borderRadius: BorderRadius.circular(14),
            ),
            child: LayoutBuilder(
              builder: (context, constraints) {
                return SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: ConstrainedBox(
                    constraints: BoxConstraints(minWidth: constraints.maxWidth),
                    child: SegmentedButton<String>(
                      segments: const [
                        ButtonSegment(value: 'Driving', icon: Icon(Icons.directions_car), label: Text('Driving')),
                        ButtonSegment(value: 'Walking', icon: Icon(Icons.directions_walk), label: Text('Walking')),
                        ButtonSegment(value: 'Public Transport', icon: Icon(Icons.directions_bus), label: Text('Transit')),
                      ],
                      selected: {travelMode},
                      onSelectionChanged: (value) {
                        setState(() {
                          travelMode = value.first;
                          _errorMessage = null;
                        });
                      },
                    ),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 18),

          // Interests selector
          const FieldLabel('Interests'),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              'Culture',
              'Food',
              'Nature',
              'Shopping',
              'History',
              'Adventure',
              'Family',
              'Nightlife',
            ].map((interest) {
              final isSelected = interests.contains(interest);
              return FilterChip(
                selected: isSelected,
                label: Text(interest),
                selectedColor: AppColors.primary.withValues(alpha: 0.16),
                checkmarkColor: AppColors.primary,
                onSelected: (selected) {
                  setState(() {
                    selected ? interests.add(interest) : interests.remove(interest);
                    _errorMessage = null;
                  });
                },
              );
            }).toList(),
          ),
          const SizedBox(height: 24),

          // Submit Button
          FilledButton.icon(
            onPressed: _handleGenerateItinerary,
            icon: const Icon(Icons.auto_awesome),
            label: const Text('Generate My Itinerary'),
            style: primaryFilledButtonStyle(),
          ),

          const SizedBox(height: 24),

          // Interactive UC300 testing tools
          Material(
            color: const Color(0xFFF1F5F9),
            borderRadius: BorderRadius.circular(14),
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: const Color(0xFFCBD5E1)),
              ),
              child: ExpansionTile(
                initiallyExpanded: false,
                title: Row(
                  children: const [
                    Icon(Icons.bug_report_outlined, size: 18, color: AppColors.primary),
                    SizedBox(width: 8),
                    Text(
                      'UC300 Flow Testing Tools',
                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.ink),
                    ),
                  ],
                ),
                subtitle: const Text(
                  'Quickly test messages M1–M8 & alternative flows A1–A7',
                  style: TextStyle(fontSize: 11, color: AppColors.muted),
                ),
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
                    child: Column(
                      children: [
                        const Divider(height: 1),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 6,
                          runSpacing: 6,
                          children: [
                            ActionChip(
                              avatar: const Icon(Icons.check_circle_outline, size: 16),
                              label: const Text('Fill Valid Form', style: TextStyle(fontSize: 11)),
                              onPressed: () {
                                final now = DateTime.now();
                                setState(() {
                                  destination = 'Kuala Lumpur';
                                  travelDates = DateTimeRange(
                                    start: DateTime(now.year, now.month, now.day + 2),
                                    end: DateTime(now.year, now.month, now.day + 5),
                                  );
                                  dailyStartTime = const TimeOfDay(hour: 8, minute: 0);
                                  dailyEndTime = const TimeOfDay(hour: 22, minute: 0);
                                  interests.clear();
                                  interests.addAll({'Food', 'Culture'});
                                  budgetCategory = 'Medium';
                                  travelMode = 'Driving';
                                  _errorMessage = null;
                                  _highlightedEmptyFields.clear();
                                });
                              },
                            ),
                            ActionChip(
                              avatar: const Icon(Icons.dangerous_outlined, size: 16),
                              label: const Text('Test A1 (Empty Fields)', style: TextStyle(fontSize: 11)),
                              onPressed: () {
                                setState(() {
                                  destination = null;
                                  travelDates = null;
                                  dailyStartTime = null;
                                  dailyEndTime = null;
                                  interests.clear();
                                  budgetCategory = '';
                                  travelMode = '';
                                  _errorMessage = null;
                                  _highlightedEmptyFields.clear();
                                });
                              },
                            ),
                            ActionChip(
                              avatar: const Icon(Icons.place, size: 16),
                              label: const Text('Test A2 (Bad Destination)', style: TextStyle(fontSize: 11)),
                              onPressed: () {
                                setState(() {
                                  destination = 'Invalid State';
                                  _errorMessage = null;
                                  _highlightedEmptyFields.clear();
                                });
                              },
                            ),
                            ActionChip(
                              avatar: const Icon(Icons.calendar_month, size: 16),
                              label: const Text('Test A3 (Invalid Days)', style: TextStyle(fontSize: 11)),
                              onPressed: () {
                                final now = DateTime.now();
                                setState(() {
                                  // Set dates to produce 31 days (violates 1-30 limit)
                                  travelDates = DateTimeRange(
                                    start: now,
                                    end: now.add(const Duration(days: 35)),
                                  );
                                  _errorMessage = null;
                                  _highlightedEmptyFields.clear();
                                });
                              },
                            ),
                            ActionChip(
                              avatar: const Icon(Icons.timer_outlined, size: 16),
                              label: const Text('Test A4 (Bad Time Range)', style: TextStyle(fontSize: 11)),
                              onPressed: () {
                                setState(() {
                                  dailyStartTime = const TimeOfDay(hour: 18, minute: 0);
                                  dailyEndTime = const TimeOfDay(hour: 8, minute: 0);
                                  _errorMessage = null;
                                  _highlightedEmptyFields.clear();
                                });
                              },
                            ),
                            ActionChip(
                              avatar: const Icon(Icons.category_outlined, size: 16),
                              label: const Text('Test A5 (No Interests)', style: TextStyle(fontSize: 11)),
                              onPressed: () {
                                setState(() {
                                  interests.clear();
                                  _errorMessage = null;
                                  _highlightedEmptyFields.clear();
                                });
                              },
                            ),
                            ActionChip(
                              avatar: const Icon(Icons.directions_bus, size: 16),
                              label: const Text('Test A7 (Transit)', style: TextStyle(fontSize: 11)),
                              onPressed: () {
                                setState(() {
                                  travelMode = 'Public Transport';
                                  _errorMessage = null;
                                  _highlightedEmptyFields.clear();
                                });
                              },
                            ),
                          ],
                        ),
                      ],
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

class FieldLabel extends StatelessWidget {
  const FieldLabel(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w800,
        color: AppColors.ink,
      ),
    );
  }
}
