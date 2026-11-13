import 'package:smart_travel_planner/l10n/localized_labels.dart';
import 'package:flutter/material.dart';

import 'package:smart_travel_planner/core/theme/app_colors.dart';
import 'package:smart_travel_planner/shared/utils/demo_feedback.dart';
import 'package:smart_travel_planner/shared/data/malaysia_states.dart';
import 'package:smart_travel_planner/features/itinerary/models/trip_preferences.dart';
import 'package:smart_travel_planner/features/itinerary/services/smart_itinerary_service.dart';
import 'package:smart_travel_planner/features/itinerary/services/trip_preferences_service.dart';
import 'itinerary_ready_page.dart';

class PlannerPage extends StatefulWidget {
  const PlannerPage({
    super.key,
    required this.onItineraryReady,
    this.onMyTripsTap,
  });

  final VoidCallback onItineraryReady;
  final VoidCallback? onMyTripsTap;

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

  bool _destinationConfirmed = false;
  bool _datesConfirmed = false;
  bool _paceConfirmed = false;
  bool _budgetConfirmed = false;
  bool _modeConfirmed = false;
  bool _interestsConfirmed = false;
  bool _testingForm = false;

  String? _errorMessage;
  Set<String> _highlightedEmptyFields = {};

  final List<TimeOfDay> _timeOptions = List.generate(
    18,
    (index) => TimeOfDay(hour: 6 + index, minute: 0),
  );

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
    return context.localDate(date);
  }

  String get _travelDateLabel {
    final dates = travelDates;
    if (dates == null) return context.l10n.selectTravelDates;
    return '${_formatDate(dates.start)} - ${_formatDate(dates.end)}';
  }

  int get _calculatedDays {
    final dates = travelDates;
    if (dates == null) return 0;
    return dates.end.difference(dates.start).inDays + 1;
  }

  String _formatTimeOfDay(TimeOfDay? time) {
    if (time == null) return context.l10n.selectTime;
    return time.format(context);
  }

  bool _isSuggestedStartTime(TimeOfDay time) {
    return time.hour == 8 || time.hour == 9;
  }

  bool _isSuggestedEndTime(TimeOfDay time) {
    return time.hour == 18 || time.hour == 21 || time.hour == 22;
  }

  Widget _buildTimePresetChip({
    required String title,
    required int startHour,
    required int endHour,
    required String hoursLabel,
  }) {
    final isSelected =
        dailyStartTime?.hour == startHour &&
        dailyStartTime?.minute == 0 &&
        dailyEndTime?.hour == endHour &&
        dailyEndTime?.minute == 0;
    return _PlanOption(
      title: title,
      subtitle: hoursLabel,
      selected: isSelected,
      onTap: () {
        setState(() {
          dailyStartTime = TimeOfDay(hour: startHour, minute: 0);
          dailyEndTime = TimeOfDay(hour: endHour, minute: 0);
          _errorMessage = null;
          _highlightedEmptyFields.remove('dailyStartTime');
          _highlightedEmptyFields.remove('dailyEndTime');
        });
      },
    );
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
                Padding(
                  padding: EdgeInsets.fromLTRB(20, 4, 20, 12),
                  child: Text(
                    context.l10n.selectDestination,
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

    if (mounted && selected != null) {
      setState(() {
        destination = selected;
        _destinationConfirmed = true;
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
      helpText: context.l10n.selectTravelDates,
      builder: (context, child) {
        final compact = MediaQuery.sizeOf(context).width < 360;
        final theme = Theme.of(context);
        final pickerTheme = DatePickerTheme.of(context);
        return Theme(
          data: theme.copyWith(
            colorScheme: ColorScheme.fromSeed(
              seedColor: AppColors.primary,
              primary: AppColors.primary,
            ),
            datePickerTheme: compact
                ? pickerTheme.copyWith(
                    rangePickerHeaderHeadlineStyle:
                        (pickerTheme.rangePickerHeaderHeadlineStyle ??
                                theme.textTheme.titleLarge)
                            ?.copyWith(fontSize: 20),
                  )
                : pickerTheme,
          ),
          child: compact
              ? MediaQuery.withClampedTextScaling(
                  maxScaleFactor: 1.0,
                  child: child!,
                )
              : child!,
        );
      },
    );

    if (mounted && picked != null) {
      setState(() {
        travelDates = picked;
        _datesConfirmed = true;
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
      startDate: travelDates?.start,
      endDate: travelDates?.end,
      dailyStartTime: dailyStartTime,
      dailyEndTime: dailyEndTime,
      interests: interests.toList(),
      budgetCategory: budgetCategory,
      travelMode: travelMode,
    );

    // Validate using TripPreferencesService (FR300_3 to FR300_9)
    final validationResult = TripPreferencesService.validatePreferences(
      currentPrefs,
    );

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

    // Transition with demo loading effect and live generation
    runDemoLoadingAction(
      context,
      loadingLabel: context.l10n.buildingItineraryFromSavedPlaces,
      successMessage: context.l10n.itineraryGeneratedOpeningPreview,
      icon: Icons.auto_awesome,
      delay: const Duration(milliseconds: 1400),
    ).then((_) async {
      await SmartItineraryService.generateLiveItineraryForAllDays(
        preferences: currentPrefs,
      );

      if (!mounted) return;
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) =>
              ItineraryReadyPage(onViewItinerary: widget.onItineraryReady),
        ),
      );
    });
  }

  Widget _buildTimeField({
    required String label,
    required String field,
    required TimeOfDay? value,
    required bool Function(TimeOfDay) isSuggested,
    required ValueChanged<TimeOfDay?> onChanged,
  }) {
    final hasError = _highlightedEmptyFields.contains(field);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _PlanLabel(label),
        const SizedBox(height: 8),
        DecoratedBox(
          decoration: BoxDecoration(
            color: const Color(0xFFF8F9FD),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: hasError ? Colors.red.shade700 : AppColors.line,
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<TimeOfDay>(
                value: value,
                isExpanded: true,
                itemHeight: null,
                borderRadius: BorderRadius.circular(16),
                icon: const Icon(Icons.expand_more, color: AppColors.muted),
                hint: Text(context.tr(label)),
                selectedItemBuilder: (context) => _timeOptions
                    .map(
                      (time) => Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          _formatTimeOfDay(time),
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: AppColors.ink,
                          ),
                        ),
                      ),
                    )
                    .toList(),
                items: _timeOptions.map((time) {
                  final suggested = isSuggested(time);
                  return DropdownMenuItem<TimeOfDay>(
                    value: time,
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(minHeight: 48),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        child: Row(
                          children: [
                            Expanded(child: Text(_formatTimeOfDay(time))),
                            if (suggested)
                              Tooltip(
                                message: context.l10n.suggestedTime,
                                child: Icon(
                                  Icons.check_circle_outline,
                                  color: AppColors.teal,
                                  size: 18,
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                  );
                }).toList(),
                onChanged: (time) {
                  setState(() {
                    onChanged(time);
                    if (_dailyDurationLabel == null) _paceConfirmed = false;
                    _errorMessage = null;
                    _highlightedEmptyFields.remove(field);
                  });
                },
              ),
            ),
          ),
        ),
        if (hasError) const _PlanFieldError('Choose a time.'),
      ],
    );
  }

  String? get _dailyDurationLabel {
    final start = dailyStartTime;
    final end = dailyEndTime;
    if (start == null || end == null) return null;
    final minutes = end.hour * 60 + end.minute - start.hour * 60 - start.minute;
    if (minutes <= 0) return null;
    final hours = minutes ~/ 60;
    final remainder = minutes % 60;
    return remainder == 0
        ? context.l10n.valueHoursOfSightseeingPerDay(context.localNumber(hours))
        : context.l10n.valueHoursValueMinutesOfSightseeingPerDay(
            context.localNumber(hours),
            context.localNumber(remainder),
          );
  }

  String get _estimatedBudgetLabel {
    final days = _calculatedDays > 0 ? _calculatedDays : 1;
    return switch (budgetCategory) {
      'Low' => context.l10n.upToRmvalueTotal(context.localNumber(150 * days)),
      'Medium' => context.l10n.rmvalueRmvalueTotal(
        context.localNumber(150 * days),
        context.localNumber(300 * days),
      ),
      'High' => context.l10n.aboveRmvalueTotal(context.localNumber(300 * days)),
      _ => context.l10n.chooseYourDailyBudget,
    };
  }

  @override
  Widget build(BuildContext context) {
    final canEditDates = _testingForm || _destinationConfirmed;
    final canEditPace =
        _testingForm ||
        (canEditDates && _datesConfirmed && _calculatedDays <= 30);
    final canEditBudget = _testingForm || (canEditPace && _paceConfirmed);
    final canEditMode = _testingForm || (canEditBudget && _budgetConfirmed);
    final canEditInterests =
        _testingForm ||
        (canEditMode && _modeConfirmed && travelMode != 'Public Transport');
    final canGenerate =
        _testingForm || (canEditInterests && _interestsConfirmed);
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;
    final days = _calculatedDays;
    final duration = _dailyDurationLabel;
    final budgetError = _highlightedEmptyFields.contains('budgetCategory');
    final modeError = _highlightedEmptyFields.contains('travelMode');
    final interestError = _highlightedEmptyFields.contains('interests');

    return ListView(
      padding: EdgeInsets.fromLTRB(20, 4, 20, 24 + bottomInset),
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      children: [
        if (widget.onMyTripsTap != null) ...[
          Align(
            alignment: Alignment.centerRight,
            child: TextButton.icon(
              key: const ValueKey('plan-my-trips'),
              onPressed: widget.onMyTripsTap,
              icon: const Icon(Icons.folder_outlined, size: 20),
              label: Text(context.l10n.myTrips),
              style: TextButton.styleFrom(
                minimumSize: const Size(48, 48),
                foregroundColor: AppColors.primary,
              ),
            ),
          ),
          const SizedBox(height: 4),
        ],
        _PlanNotice(
          icon: Icons.auto_awesome_outlined,
          title: context.l10n.aTripThatFitsYou,
          message: context.l10n.chooseYourDatesDailyPaceAndFavouriteThingsToDo,
        ),
        const SizedBox(height: 20),
        _PlanSection(
          icon: Icons.luggage_outlined,
          title: context.l10n.tripDetails2,
          description: context.l10n.whereAndWhenWouldYouLikeToGo,
          children: [
            _PlanPickerField(
              label: context.l10n.destination,
              value: destination == null
                  ? 'Select State'
                  : '$destination, Malaysia',
              icon: Icons.place_outlined,
              hasError: _highlightedEmptyFields.contains('destination'),
              errorText: context.l10n.chooseADestination,
              onTap: _pickDestination,
            ),
            const SizedBox(height: 16),
            _PlanPickerField(
              label: context.l10n.travelDates,
              value: travelDates == null
                  ? 'Select Travel Dates'
                  : _travelDateLabel,
              icon: Icons.calendar_month_outlined,
              supportingText: days > 0
                  ? '$days ${days == 1 ? 'day' : 'days'} to explore'
                  : null,
              hasError: _highlightedEmptyFields.contains('numberOfDays'),
              errorText: context.l10n.chooseYourTravelDates,
              onTap: canEditDates ? _pickTravelDates : null,
            ),
            if (canEditDates && days > 30)
              _PlanFieldError(TripPreferencesService.m4InvalidDays),
          ],
        ),
        const SizedBox(height: 16),
        _PlanSection(
          enabled: canEditPace,
          icon: Icons.schedule_outlined,
          title: context.l10n.yourDailyPace,
          description:
              context.l10n.setAsideTimeForAttractionsMealsAndGettingAround,
          children: [
            const _PlanLabel('Choose a suggested schedule'),
            const SizedBox(height: 10),
            _PlanChoices(
              children: [
                _buildTimePresetChip(
                  title: context.l10n.standard,
                  startHour: 8,
                  endHour: 22,
                  hoursLabel: context.l10n.text8Am10Pm,
                ),
                _buildTimePresetChip(
                  title: context.l10n.popular,
                  startHour: 9,
                  endHour: 21,
                  hoursLabel: context.l10n.text9Am9Pm,
                ),
                _buildTimePresetChip(
                  title: context.l10n.relaxed,
                  startHour: 9,
                  endHour: 18,
                  hoursLabel: context.l10n.text9Am6Pm,
                ),
              ],
            ),
            const SizedBox(height: 18),
            LayoutBuilder(
              builder: (context, constraints) {
                final fields = [
                  _buildTimeField(
                    label: context.l10n.dailyStartTime,
                    field: 'dailyStartTime',
                    value: dailyStartTime,
                    isSuggested: _isSuggestedStartTime,
                    onChanged: (time) => dailyStartTime = time,
                  ),
                  _buildTimeField(
                    label: context.l10n.dailyEndTime,
                    field: 'dailyEndTime',
                    value: dailyEndTime,
                    isSuggested: _isSuggestedEndTime,
                    onChanged: (time) => dailyEndTime = time,
                  ),
                ];
                final scale = MediaQuery.textScalerOf(context).scale(14) / 14;
                if (constraints.maxWidth < 280 * scale) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      fields[0],
                      const SizedBox(height: 14),
                      fields[1],
                    ],
                  );
                }
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(child: fields[0]),
                    const SizedBox(width: 12),
                    Expanded(child: fields[1]),
                  ],
                );
              },
            ),
            if (duration != null) ...[
              const SizedBox(height: 14),
              _PlanInlineNote(icon: Icons.timelapse_outlined, text: duration),
            ] else
              _PlanFieldError(TripPreferencesService.m5InvalidTimeRange),
            if (!_paceConfirmed)
              TextButton(
                onPressed: !canEditPace || duration == null
                    ? null
                    : () => setState(() => _paceConfirmed = true),
                child: Text(
                  MaterialLocalizations.of(context).continueButtonLabel,
                ),
              ),
          ],
        ),
        const SizedBox(height: 16),
        _PlanSection(
          enabled: canEditBudget,
          icon: Icons.account_balance_wallet_outlined,
          title: context.l10n.dailyBudget,
          description: context
              .l10n
              .perPersonIncludingMealsAttractionTicketsAndLocalTransport,
          hasError: budgetError,
          children: [
            _PlanChoices(
              children: [
                for (final option in const [
                  ('Low', 'Under RM150'),
                  ('Medium', 'RM150–300'),
                  ('High', 'Over RM300'),
                ])
                  _PlanOption(
                    title: context.tr(option.$1),
                    subtitle: context.tr(option.$2),
                    selected: budgetCategory == option.$1,
                    onTap: () {
                      setState(() {
                        budgetCategory = option.$1;
                        _budgetConfirmed = true;
                        _errorMessage = null;
                        _highlightedEmptyFields.remove('budgetCategory');
                      });
                    },
                  ),
              ],
            ),
            if (budgetError) const _PlanFieldError('Choose a daily budget.'),
            const SizedBox(height: 14),
            _PlanNotice(
              icon: Icons.payments_outlined,
              title: _estimatedBudgetLabel,
              message: days <= 1
                  ? context.l10n.estimatedFor1DayPerPerson
                  : context.l10n.estimatedForValueDaysPerPerson(
                      context.localNumber(days),
                    ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        _PlanSection(
          enabled: canEditMode,
          icon: Icons.route_outlined,
          title: context.l10n.gettingAround,
          description: context.l10n.chooseHowYouWillTravelBetweenPlaces,
          hasError: modeError,
          children: [
            _PlanChoices(
              children: [
                for (final option in const [
                  ('Driving', 'Driving', Icons.directions_car_outlined),
                  ('Walking', 'Walking', Icons.directions_walk_outlined),
                  (
                    'Public Transport',
                    'Transit',
                    Icons.directions_bus_outlined,
                  ),
                ])
                  _PlanOption(
                    title: context.tr(option.$2),
                    icon: option.$3,
                    selected: travelMode == option.$1,
                    onTap: () {
                      setState(() {
                        travelMode = option.$1;
                        _modeConfirmed = true;
                        _errorMessage = null;
                        _highlightedEmptyFields.remove('travelMode');
                      });
                    },
                  ),
              ],
            ),
            if (modeError) const _PlanFieldError('Choose a travel mode.'),
            if (travelMode.isNotEmpty) ...[
              const SizedBox(height: 14),
              _PlanInlineNote(
                icon: travelMode == 'Public Transport'
                    ? Icons.info_outline
                    : Icons.check_circle_outline,
                text: switch (travelMode) {
                  'Driving' => 'Explore further by car or e-hailing.',
                  'Walking' => 'Enjoy nearby places at a walking pace.',
                  _ =>
                    'Transit planning is not available yet. Choose driving or walking to generate your trip.',
                },
              ),
            ],
          ],
        ),
        const SizedBox(height: 16),
        _PlanSection(
          enabled: canEditInterests,
          icon: Icons.favorite_border,
          title: context.l10n.makeItYourKindOfTrip,
          description:
              context.l10n.pickOneOrMoreInterestsWeLlUseTheseToFindPlacesForYou,
          hasError: interestError,
          children: [
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final option in const [
                  ('Culture', Icons.museum_outlined),
                  ('Food', Icons.restaurant_outlined),
                  ('Nature', Icons.park_outlined),
                  ('Shopping', Icons.shopping_bag_outlined),
                  ('History', Icons.account_balance_outlined),
                  ('Adventure', Icons.hiking_outlined),
                  ('Family', Icons.family_restroom_outlined),
                  ('Nightlife', Icons.nightlife_outlined),
                ])
                  FilterChip(
                    label: Text(context.tr(option.$1)),
                    avatar: interests.contains(option.$1)
                        ? null
                        : Icon(option.$2, size: 18, color: AppColors.muted),
                    selected: interests.contains(option.$1),
                    showCheckmark: true,
                    checkmarkColor: AppColors.primary,
                    selectedColor: const Color(0xFFEDE9FF),
                    backgroundColor: Colors.white,
                    side: BorderSide(
                      color: interests.contains(option.$1)
                          ? AppColors.primary.withValues(alpha: 0.4)
                          : AppColors.line,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 10,
                    ),
                    materialTapTargetSize: MaterialTapTargetSize.padded,
                    visualDensity: VisualDensity.standard,
                    labelStyle: TextStyle(
                      fontSize: 14,
                      fontWeight: interests.contains(option.$1)
                          ? FontWeight.w700
                          : FontWeight.w500,
                      color: interests.contains(option.$1)
                          ? AppColors.primaryDark
                          : AppColors.ink,
                    ),
                    onSelected: (selected) {
                      setState(() {
                        selected
                            ? interests.add(option.$1)
                            : interests.remove(option.$1);
                        if (interests.isEmpty) _interestsConfirmed = false;
                        _errorMessage = null;
                        _highlightedEmptyFields.remove('interests');
                      });
                    },
                  ),
              ],
            ),
            if (interestError)
              const _PlanFieldError('Choose at least one interest.'),
            if (!_interestsConfirmed)
              TextButton(
                onPressed: !canEditInterests || interests.isEmpty
                    ? null
                    : () => setState(() => _interestsConfirmed = true),
                child: Text(
                  MaterialLocalizations.of(context).continueButtonLabel,
                ),
              ),
          ],
        ),
        const SizedBox(height: 24),
        if (_errorMessage != null) ...[
          Semantics(
            liveRegion: true,
            child: _PlanNotice(
              icon: Icons.error_outline,
              title: context.l10n.checkYourTripPreferences,
              message: _errorMessage!,
              isError: true,
            ),
          ),
          const SizedBox(height: 16),
        ],
        FilledButton.icon(
          onPressed: canGenerate ? _handleGenerateItinerary : null,
          icon: const Icon(Icons.auto_awesome),
          label: Text(
            context.l10n.generateMyItinerary,
            textAlign: TextAlign.center,
          ),
          style: primaryFilledButtonStyle().copyWith(
            minimumSize: const WidgetStatePropertyAll(Size.fromHeight(56)),
            padding: const WidgetStatePropertyAll(
              EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            ),
          ),
        ),
        const SizedBox(height: 24),
        _buildTestingTools(),
      ],
    );
  }

  Widget _buildTestingTools() => Material(
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
          children: [
            Icon(Icons.bug_report_outlined, size: 18, color: AppColors.primary),
            SizedBox(width: 8),
            Expanded(
              child: Text(
                context.l10n.uc300FlowTestingTools,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: AppColors.ink,
                ),
              ),
            ),
          ],
        ),
        subtitle: Text(
          context.l10n.quicklyTestMessagesM1M8AlternativeFlowsA1A7,
          style: TextStyle(fontSize: 12, color: AppColors.muted),
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
                      label: Text(
                        context.l10n.fillValidForm,
                        style: TextStyle(fontSize: 12),
                      ),
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
                          _testingForm = true;
                        });
                      },
                    ),
                    ActionChip(
                      avatar: const Icon(Icons.dangerous_outlined, size: 16),
                      label: Text(
                        context.l10n.testA1EmptyFields,
                        style: TextStyle(fontSize: 12),
                      ),
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
                          _testingForm = true;
                        });
                      },
                    ),
                    ActionChip(
                      avatar: const Icon(Icons.place, size: 16),
                      label: Text(
                        context.l10n.testA2BadDestination,
                        style: TextStyle(fontSize: 12),
                      ),
                      onPressed: () {
                        setState(() {
                          destination = 'Invalid State';
                          _errorMessage = null;
                          _highlightedEmptyFields.clear();
                          _testingForm = true;
                        });
                      },
                    ),
                    ActionChip(
                      avatar: const Icon(Icons.calendar_month, size: 16),
                      label: Text(
                        context.l10n.testA3InvalidDays,
                        style: TextStyle(fontSize: 12),
                      ),
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
                          _testingForm = true;
                        });
                      },
                    ),
                    ActionChip(
                      avatar: const Icon(Icons.timer_outlined, size: 16),
                      label: Text(
                        context.l10n.testA4BadTimeRange,
                        style: TextStyle(fontSize: 12),
                      ),
                      onPressed: () {
                        setState(() {
                          dailyStartTime = const TimeOfDay(hour: 18, minute: 0);
                          dailyEndTime = const TimeOfDay(hour: 8, minute: 0);
                          _errorMessage = null;
                          _highlightedEmptyFields.clear();
                          _testingForm = true;
                        });
                      },
                    ),
                    ActionChip(
                      avatar: const Icon(Icons.category_outlined, size: 16),
                      label: Text(
                        context.l10n.testA5NoInterests,
                        style: TextStyle(fontSize: 12),
                      ),
                      onPressed: () {
                        setState(() {
                          interests.clear();
                          _errorMessage = null;
                          _highlightedEmptyFields.clear();
                          _testingForm = true;
                        });
                      },
                    ),
                    ActionChip(
                      avatar: const Icon(Icons.directions_bus, size: 16),
                      label: Text(
                        context.l10n.testA7Transit,
                        style: TextStyle(fontSize: 12),
                      ),
                      onPressed: () {
                        setState(() {
                          travelMode = 'Public Transport';
                          _errorMessage = null;
                          _highlightedEmptyFields.clear();
                          _testingForm = true;
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
  );
}

class _PlanSection extends StatelessWidget {
  const _PlanSection({
    required this.icon,
    required this.title,
    required this.description,
    required this.children,
    this.hasError = false,
    this.enabled = true,
  });

  final IconData icon;
  final String title;
  final String description;
  final List<Widget> children;
  final bool hasError;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: hasError ? Colors.red.shade700 : AppColors.line,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(9),
                decoration: BoxDecoration(
                  color: const Color(0xFFF0EDFF),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, size: 21, color: AppColors.primary),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  context.tr(title),
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: AppColors.ink,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            context.tr(description),
            style: const TextStyle(
              fontSize: 13,
              height: 1.5,
              color: AppColors.muted,
            ),
          ),
          const SizedBox(height: 18),
          if (enabled)
            ...children
          else
            _LockedPlanControls(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: children,
              ),
            ),
        ],
      ),
    );
  }
}

class _LockedPlanControls extends StatelessWidget {
  const _LockedPlanControls({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      enabled: false,
      child: ExcludeFocus(
        child: IgnorePointer(child: Opacity(opacity: 0.55, child: child)),
      ),
    );
  }
}

class _PlanPickerField extends StatelessWidget {
  const _PlanPickerField({
    required this.label,
    required this.value,
    required this.icon,
    required this.onTap,
    required this.hasError,
    required this.errorText,
    this.supportingText,
  });

  final String label;
  final String value;
  final IconData icon;
  final VoidCallback? onTap;
  final bool hasError;
  final String errorText;
  final String? supportingText;

  @override
  Widget build(BuildContext context) {
    final field = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _PlanLabel(label),
        const SizedBox(height: 8),
        Semantics(
          button: true,
          label: label,
          child: Material(
            color: const Color(0xFFF8F9FD),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
              side: BorderSide(
                color: hasError ? Colors.red.shade700 : AppColors.line,
              ),
            ),
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              onTap: onTap,
              child: ConstrainedBox(
                constraints: const BoxConstraints(minHeight: 60),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 14,
                  ),
                  child: Row(
                    children: [
                      Icon(icon, size: 21, color: AppColors.primary),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              value,
                              style: const TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w700,
                                color: AppColors.ink,
                              ),
                            ),
                            if (supportingText != null) ...[
                              const SizedBox(height: 5),
                              Text(
                                context.tr(supportingText!),
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.primary,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                      const SizedBox(width: 6),
                      const Icon(Icons.expand_more, color: AppColors.muted),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
        if (hasError) _PlanFieldError(errorText),
      ],
    );
    return onTap == null ? _LockedPlanControls(child: field) : field;
  }
}

class _PlanChoices extends StatelessWidget {
  const _PlanChoices({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        const gap = 8.0;
        final scale = MediaQuery.textScalerOf(context).scale(14) / 14;
        final columns = ((constraints.maxWidth + gap) / (96 * scale + gap))
            .floor()
            .clamp(1, 3);
        final width = (constraints.maxWidth - gap * (columns - 1)) / columns;
        return Wrap(
          spacing: gap,
          runSpacing: gap,
          children: [
            for (final child in children) SizedBox(width: width, child: child),
          ],
        );
      },
    );
  }
}

class _PlanOption extends StatelessWidget {
  const _PlanOption({
    required this.title,
    required this.selected,
    required this.onTap,
    this.subtitle,
    this.icon,
  });

  final String title;
  final String? subtitle;
  final IconData? icon;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      selected: selected,
      button: true,
      child: Material(
        color: selected ? const Color(0xFFF0EDFF) : const Color(0xFFF8F9FD),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: BorderSide(
            color: selected ? AppColors.primary : AppColors.line,
            width: selected ? 1.5 : 1,
          ),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 82),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    selected
                        ? Icons.check_circle
                        : icon ?? Icons.radio_button_unchecked,
                    size: 20,
                    color: selected ? AppColors.primary : AppColors.muted,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    context.tr(title),
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
                      color: selected ? AppColors.primaryDark : AppColors.ink,
                    ),
                  ),
                  if (subtitle != null) ...[
                    const SizedBox(height: 4),
                    Text(
                      context.tr(subtitle!),
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 12,
                        height: 1.4,
                        color: AppColors.muted,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _PlanNotice extends StatelessWidget {
  const _PlanNotice({
    required this.icon,
    required this.title,
    required this.message,
    this.isError = false,
  });

  final IconData icon;
  final String title;
  final String message;
  final bool isError;

  @override
  Widget build(BuildContext context) {
    final foreground = isError ? Colors.red.shade800 : AppColors.primaryDark;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isError ? Colors.red.shade50 : const Color(0xFFF0EDFF),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isError ? Colors.red.shade200 : const Color(0xFFE4DFFF),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 21, color: foreground),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  context.tr(title),
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: foreground,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  context.tr(message),
                  style: TextStyle(
                    fontSize: 13,
                    height: 1.5,
                    color: isError ? foreground : AppColors.muted,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _PlanInlineNote extends StatelessWidget {
  const _PlanInlineNote({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 18, color: AppColors.primary),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            context.tr(text),
            style: const TextStyle(
              fontSize: 13,
              height: 1.5,
              color: AppColors.muted,
            ),
          ),
        ),
      ],
    );
  }
}

class _PlanLabel extends StatelessWidget {
  const _PlanLabel(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      context.tr(text),
      style: const TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.w700,
        color: AppColors.ink,
      ),
    );
  }
}

class _PlanFieldError extends StatelessWidget {
  const _PlanFieldError(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Text(
        context.tr(text),
        style: TextStyle(fontSize: 13, color: Colors.red.shade700),
      ),
    );
  }
}
