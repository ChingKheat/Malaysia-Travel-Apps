import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

/// Semantic color tokens for the Modern Minimal Travel Date Range Picker.
class ModernDatePickerColors {
  const ModernDatePickerColors._();

  static const Color background = Color(0xFFFAFAF7);
  static const Color surface = Colors.white;
  static const Color primaryNavy = Color(0xFF0F172A);
  static const Color textMuted = Color(0xFF64748B);
  static const Color textDisabled = Color(0xFFCBD5E1);
  static const Color borderSubtle = Color(0xFFE2E8F0);
  static const Color tealPrimary = Color(0xFF0F766E);
  static const Color tealLight = Color(0xFFE6F5F2);
  static const Color tealAccent = Color(0xFF0D9488);
  static const Color buttonDark = Color(0xFF131D31);
  static const Color buttonDisabled = Color(0xFFE2E8F0);
  static const Color cardShadow = Color(0x0A0F172A);
}

/// Active field selection focus for the start/end date cards.
enum _ActiveDateField {
  start,
  end,
  none,
}

/// Localized copy dictionary for the Date Range Picker supporting English,
/// Chinese (Simplified), and Malay (Bahasa Melayu).
class _PickerStrings {
  const _PickerStrings({
    required this.appTitle,
    required this.stepText,
    required this.title,
    required this.subtitle,
    required this.startDateLabel,
    required this.endDateLabel,
    required this.selectDatePlaceholder,
    required this.selectedDatesLegend,
    required this.travelPeriodLegend,
    required this.reset,
    required this.yourTripDuration,
    required this.departureSelected,
    required this.selectYourDates,
    required this.confirmTravelDates,
    required this.selectTravelDates,
    required this.subtext,
    required this.weekdays,
    required this.languageCode,
  });

  final String appTitle;
  final String stepText;
  final String title;
  final String subtitle;
  final String startDateLabel;
  final String endDateLabel;
  final String selectDatePlaceholder;
  final String selectedDatesLegend;
  final String travelPeriodLegend;
  final String reset;
  final String yourTripDuration;
  final String departureSelected;
  final String selectYourDates;
  final String confirmTravelDates;
  final String selectTravelDates;
  final String subtext;
  final List<String> weekdays;
  final String languageCode;

  String formatDuration(int days, int nights) {
    if (languageCode == 'zh') {
      if (days == 1) return '1 天 · 0 晚（单日游）';
      return '$days 天 · $nights 晚';
    } else if (languageCode == 'ms') {
      if (days == 1) return '1 hari · 0 malam (Lawatan sehari)';
      return '$days hari · $nights malam';
    } else {
      if (days == 1) return '1 day · 0 nights (Day trip)';
      return '$days days · $nights ${nights == 1 ? 'night' : 'nights'}';
    }
  }

  static _PickerStrings of(
    BuildContext context, {
    String? appTitle,
    String? stepText,
    String? title,
    String? subtitle,
    String? confirmButtonText,
    String? subtext,
  }) {
    final languageCode = Localizations.localeOf(context).languageCode;

    if (languageCode == 'zh') {
      return _PickerStrings(
        appTitle: appTitle ?? '探索马来西亚',
        stepText: stepText ?? '',
        title: title ?? '什么时候出发？',
        subtitle: subtitle ?? '挑选适合您行程的出发与返程日期。',
        startDateLabel: '出发日期',
        endDateLabel: '返程日期',
        selectDatePlaceholder: '选择日期',
        selectedDatesLegend: '选中日期',
        travelPeriodLegend: '行程时段',
        reset: '重置',
        yourTripDuration: '您的行程时长',
        departureSelected: '已选出发日期 · 请选择返程日期',
        selectYourDates: '请选择您的旅行日期',
        confirmTravelDates: confirmButtonText ?? '确认旅行日期',
        selectTravelDates: '选择旅行日期',
        subtext: subtext ?? '您可以随时修改旅行日期。',
        weekdays: const ['一', '二', '三', '四', '五', '六', '日'],
        languageCode: languageCode,
      );
    } else if (languageCode == 'ms') {
      return _PickerStrings(
        appTitle: appTitle ?? 'Jelajah Malaysia',
        stepText: stepText ?? '',
        title: title ?? 'Bila pengembaraan anda?',
        subtitle: subtitle ?? 'Pilih tarikh yang sesuai untuk perjalanan anda.',
        startDateLabel: 'TARIKH MULA',
        endDateLabel: 'TARIKH TAMAT',
        selectDatePlaceholder: 'Pilih tarikh',
        selectedDatesLegend: 'Tarikh dipilih',
        travelPeriodLegend: 'Tempoh perjalanan',
        reset: 'Set semula',
        yourTripDuration: 'Tempoh perjalanan anda',
        departureSelected: 'Pelepasan dipilih · Pilih tarikh pulang',
        selectYourDates: 'Pilih tarikh perjalanan anda',
        confirmTravelDates: confirmButtonText ?? 'Sahkan tarikh perjalanan',
        selectTravelDates: 'Pilih tarikh perjalanan',
        subtext: subtext ?? 'Anda boleh menukar tarikh anda pada bila-bila masa.',
        weekdays: const ['I', 'S', 'R', 'K', 'J', 'S', 'A'],
        languageCode: languageCode,
      );
    } else {
      return _PickerStrings(
        appTitle: appTitle ?? 'Wander Malaysia',
        stepText: stepText ?? '',
        title: title ?? "When's your adventure?",
        subtitle: subtitle ?? 'Pick the dates that work for your trip.',
        startDateLabel: 'START DATE',
        endDateLabel: 'END DATE',
        selectDatePlaceholder: 'Select date',
        selectedDatesLegend: 'Selected dates',
        travelPeriodLegend: 'Travel period',
        reset: 'Reset',
        yourTripDuration: 'Your trip duration',
        departureSelected: 'Departure selected · Choose return date',
        selectYourDates: 'Select your travel dates',
        confirmTravelDates: confirmButtonText ?? 'Confirm travel dates',
        selectTravelDates: 'Select travel dates',
        subtext: subtext ?? 'You can change your dates anytime.',
        weekdays: const ['M', 'T', 'W', 'T', 'F', 'S', 'S'],
        languageCode: languageCode,
      );
    }
  }
}

/// A production-quality, Modern Minimal Travel Date Range Picker widget.
///
/// Implements dual start/end cards, monthly calendar navigation with cross-month/cross-year
/// selection, continuous range ribbon highlighting, automatic days & nights calculation,
/// accessible touch targets (>=44x44dp), past date disabling, localized strings,
/// dismissive close button, and a sticky confirmation CTA.
class ModernDateRangePicker extends StatefulWidget {
  const ModernDateRangePicker({
    super.key,
    this.initialDateRange,
    this.firstDate,
    this.lastDate,
    this.onDateRangeSelected,
    this.onCancel,
    this.appTitle,
    this.stepText,
    this.title,
    this.subtitle,
    this.showHeader = true,
    this.showProgressBar = false,
    this.totalSteps = 4,
    this.currentStep = 2,
    this.confirmButtonText,
    this.subtext,
  });

  final DateTimeRange? initialDateRange;
  final DateTime? firstDate;
  final DateTime? lastDate;
  final ValueChanged<DateTimeRange>? onDateRangeSelected;
  final VoidCallback? onCancel;
  final String? appTitle;
  final String? stepText;
  final String? title;
  final String? subtitle;
  final bool showHeader;
  final bool showProgressBar;
  final int totalSteps;
  final int currentStep;
  final String? confirmButtonText;
  final String? subtext;

  @override
  State<ModernDateRangePicker> createState() => _ModernDateRangePickerState();
}

class _ModernDateRangePickerState extends State<ModernDateRangePicker> {
  late DateTime _firstDate;
  late DateTime _lastDate;
  late DateTime _focusedMonth;

  DateTime? _startDate;
  DateTime? _endDate;
  _ActiveDateField _activeField = _ActiveDateField.start;

  static DateTime _normalize(DateTime dt) => DateTime(dt.year, dt.month, dt.day);

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _firstDate = _normalize(widget.firstDate ?? now);
    _lastDate = _normalize(widget.lastDate ?? now.add(const Duration(days: 365 * 2)));

    if (widget.initialDateRange != null) {
      _startDate = _normalize(widget.initialDateRange!.start);
      _endDate = _normalize(widget.initialDateRange!.end);
      _activeField = _ActiveDateField.none;
    }

    final initialFocus = _startDate ?? _firstDate;
    _focusedMonth = DateTime(initialFocus.year, initialFocus.month, 1);
  }

  bool _isSameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  bool get _isRangeComplete => _startDate != null && _endDate != null;

  int get _calculatedDays {
    if (_startDate == null) return 0;
    if (_endDate == null) return 1;
    return _endDate!.difference(_startDate!).inDays + 1;
  }

  int get _calculatedNights {
    if (_startDate == null || _endDate == null) return 0;
    return _endDate!.difference(_startDate!).inDays;
  }

  bool get _canGoPreviousMonth {
    final prevMonth = DateTime(_focusedMonth.year, _focusedMonth.month - 1, 1);
    final firstMonth = DateTime(_firstDate.year, _firstDate.month, 1);
    return !prevMonth.isBefore(firstMonth);
  }

  bool get _canGoNextMonth {
    final nextMonth = DateTime(_focusedMonth.year, _focusedMonth.month + 1, 1);
    final lastMonth = DateTime(_lastDate.year, _lastDate.month, 1);
    return !nextMonth.isAfter(lastMonth);
  }

  void _onPreviousMonth() {
    if (_canGoPreviousMonth) {
      setState(() {
        _focusedMonth = DateTime(_focusedMonth.year, _focusedMonth.month - 1, 1);
      });
    }
  }

  void _onNextMonth() {
    if (_canGoNextMonth) {
      setState(() {
        _focusedMonth = DateTime(_focusedMonth.year, _focusedMonth.month + 1, 1);
      });
    }
  }

  void _onReset() {
    setState(() {
      _startDate = null;
      _endDate = null;
      _activeField = _ActiveDateField.start;
    });
  }

  void _onSelectStartDateCard() {
    setState(() {
      _activeField = _ActiveDateField.start;
    });
  }

  void _onSelectEndDateCard() {
    setState(() {
      _activeField = _ActiveDateField.end;
    });
  }

  void _onDayTapped(DateTime date) {
    final normalized = _normalize(date);
    if (normalized.isBefore(_firstDate) || normalized.isAfter(_lastDate)) {
      return;
    }

    setState(() {
      if (_activeField == _ActiveDateField.start) {
        _startDate = normalized;
        if (_endDate != null && _endDate!.isBefore(normalized)) {
          _endDate = null;
          _activeField = _ActiveDateField.end;
        } else if (_endDate == null) {
          _activeField = _ActiveDateField.end;
        } else {
          _activeField = _ActiveDateField.none;
        }
      } else if (_activeField == _ActiveDateField.end) {
        if (_startDate == null) {
          _startDate = normalized;
          _activeField = _ActiveDateField.end;
        } else if (normalized.isBefore(_startDate!)) {
          _startDate = normalized;
          _activeField = _ActiveDateField.end;
        } else {
          _endDate = normalized;
          _activeField = _ActiveDateField.none;
        }
      } else {
        // Fresh selection
        _startDate = normalized;
        _endDate = null;
        _activeField = _ActiveDateField.end;
      }
    });
  }

  void _onConfirm() {
    if (_isRangeComplete && widget.onDateRangeSelected != null) {
      widget.onDateRangeSelected!(DateTimeRange(start: _startDate!, end: _endDate!));
    }
  }

  @override
  Widget build(BuildContext context) {
    final strings = _PickerStrings.of(
      context,
      appTitle: widget.appTitle,
      stepText: widget.stepText,
      title: widget.title,
      subtitle: widget.subtitle,
      confirmButtonText: widget.confirmButtonText,
      subtext: widget.subtext,
    );

    return Container(
      color: ModernDatePickerColors.background,
      child: SafeArea(
        top: false,
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (widget.showHeader) ...[
                      _buildHeader(strings),
                      const SizedBox(height: 16),
                    ],
                    _buildTitle(strings),
                    const SizedBox(height: 18),
                    _buildDateCards(strings),
                    const SizedBox(height: 24),
                    _buildCalendarSection(strings),
                    const SizedBox(height: 14),
                    _buildLegendAndReset(strings),
                    const SizedBox(height: 16),
                    _buildDurationCard(strings),
                    const SizedBox(height: 20),
                  ],
                ),
              ),
            ),
            _buildStickyBottomBar(strings),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(_PickerStrings strings) {
    final showStep = widget.stepText != null && widget.stepText!.isNotEmpty;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: ModernDatePickerColors.tealLight,
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(
                Icons.explore_outlined,
                color: ModernDatePickerColors.tealPrimary,
                size: 20,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                strings.appTitle,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                  color: ModernDatePickerColors.primaryNavy,
                  letterSpacing: -0.2,
                ),
              ),
            ),
            if (showStep) ...[
              const SizedBox(width: 8),
              Flexible(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    widget.stepText!,
                    maxLines: 1,
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.8,
                      color: ModernDatePickerColors.textMuted,
                    ),
                  ),
                ),
              ),
            ] else ...[
              const SizedBox(width: 8),
              Semantics(
                button: true,
                label: 'Close',
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: widget.onCancel ?? () => Navigator.of(context).maybePop(),
                    borderRadius: BorderRadius.circular(18),
                    child: Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        color: ModernDatePickerColors.surface,
                        shape: BoxShape.circle,
                        border: Border.all(color: ModernDatePickerColors.borderSubtle),
                      ),
                      child: const Icon(
                        Icons.close_rounded,
                        size: 18,
                        color: ModernDatePickerColors.primaryNavy,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
        if (widget.showProgressBar) ...[
          const SizedBox(height: 12),
          Row(
            children: List.generate(widget.totalSteps, (index) {
              final isFilled = index < widget.currentStep;
              return Expanded(
                child: Container(
                  height: 4,
                  margin: EdgeInsets.only(
                    right: index < widget.totalSteps - 1 ? 6 : 0,
                  ),
                  decoration: BoxDecoration(
                    color: isFilled
                        ? ModernDatePickerColors.tealPrimary
                        : ModernDatePickerColors.borderSubtle,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              );
            }),
          ),
        ],
      ],
    );
  }

  Widget _buildTitle(_PickerStrings strings) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          strings.title,
          style: const TextStyle(
            fontSize: 23,
            fontWeight: FontWeight.w800,
            color: ModernDatePickerColors.primaryNavy,
            letterSpacing: -0.5,
            height: 1.25,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          strings.subtitle,
          style: const TextStyle(
            fontSize: 14,
            color: ModernDatePickerColors.textMuted,
            fontWeight: FontWeight.w400,
            height: 1.35,
          ),
        ),
      ],
    );
  }

  Widget _buildDateCards(_PickerStrings strings) {
    return Row(
      children: [
        Expanded(
          child: _buildDateCard(
            label: strings.startDateLabel,
            placeholder: strings.selectDatePlaceholder,
            date: _startDate,
            isActive: _activeField == _ActiveDateField.start,
            onTap: _onSelectStartDateCard,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildDateCard(
            label: strings.endDateLabel,
            placeholder: strings.selectDatePlaceholder,
            date: _endDate,
            isActive: _activeField == _ActiveDateField.end,
            onTap: _onSelectEndDateCard,
          ),
        ),
      ],
    );
  }

  Widget _buildDateCard({
    required String label,
    required String placeholder,
    required DateTime? date,
    required bool isActive,
    required VoidCallback onTap,
  }) {
    final locale = Localizations.localeOf(context).toString();
    final formattedDate =
        date != null ? DateFormat.yMMMd(locale).format(date) : placeholder;

    return Semantics(
      button: true,
      label: '$label: $formattedDate',
      child: Material(
        color: ModernDatePickerColors.surface,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: ModernDatePickerColors.surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: isActive
                    ? ModernDatePickerColors.tealPrimary
                    : ModernDatePickerColors.borderSubtle,
                width: isActive ? 1.8 : 1.2,
              ),
              boxShadow: const [
                BoxShadow(
                  color: ModernDatePickerColors.cardShadow,
                  blurRadius: 8,
                  offset: Offset(0, 3),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.calendar_today_outlined,
                        size: 14,
                        color: ModernDatePickerColors.tealPrimary,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        label,
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.7,
                          color: ModernDatePickerColors.textMuted,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(
                    formattedDate,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: date != null
                          ? ModernDatePickerColors.primaryNavy
                          : ModernDatePickerColors.textDisabled,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCalendarSection(_PickerStrings strings) {
    final locale = Localizations.localeOf(context).toString();
    final monthYearString = DateFormat.yMMMM(locale).format(_focusedMonth);

    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Text(
                  monthYearString,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: ModernDatePickerColors.primaryNavy,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildChevronButton(
                  icon: Icons.chevron_left,
                  enabled: _canGoPreviousMonth,
                  onTap: _onPreviousMonth,
                  tooltip: 'Previous month',
                ),
                const SizedBox(width: 8),
                _buildChevronButton(
                  icon: Icons.chevron_right,
                  enabled: _canGoNextMonth,
                  onTap: _onNextMonth,
                  tooltip: 'Next month',
                ),
              ],
            ),
          ],
        ),
        const SizedBox(height: 16),
        _buildWeekdayHeaders(strings),
        const SizedBox(height: 8),
        _buildDaysGrid(),
      ],
    );
  }

  Widget _buildChevronButton({
    required IconData icon,
    required bool enabled,
    required VoidCallback onTap,
    required String tooltip,
  }) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: ModernDatePickerColors.surface,
        borderRadius: BorderRadius.circular(10),
        child: InkWell(
          onTap: enabled ? onTap : null,
          borderRadius: BorderRadius.circular(10),
          child: Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: ModernDatePickerColors.borderSubtle),
            ),
            child: Icon(
              icon,
              size: 20,
              color: enabled
                  ? ModernDatePickerColors.primaryNavy
                  : ModernDatePickerColors.textDisabled,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildWeekdayHeaders(_PickerStrings strings) {
    return Row(
      children: strings.weekdays.map((day) {
        return Expanded(
          child: Center(
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                day,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: ModernDatePickerColors.textMuted,
                ),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildDaysGrid() {
    final year = _focusedMonth.year;
    final month = _focusedMonth.month;
    final daysInMonth = DateTime(year, month + 1, 0).day;
    final firstWeekday = DateTime(year, month, 1).weekday; // 1 = Monday, 7 = Sunday
    final leadingBlanks = firstWeekday - 1;

    final totalSlots = leadingBlanks + daysInMonth;
    final rowCount = (totalSlots / 7).ceil();

    return Column(
      children: List.generate(rowCount, (rowIndex) {
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 2),
          child: Row(
            children: List.generate(7, (colIndex) {
              final slotIndex = rowIndex * 7 + colIndex;
              final dayNumber = slotIndex - leadingBlanks + 1;

              if (dayNumber < 1 || dayNumber > daysInMonth) {
                return const Expanded(child: SizedBox(height: 44));
              }

              final cellDate = DateTime(year, month, dayNumber);
              return Expanded(
                child: _buildDayCell(
                  date: cellDate,
                  colIndex: colIndex,
                  isFirstDayOfMonth: dayNumber == 1,
                  isLastDayOfMonth: dayNumber == daysInMonth,
                ),
              );
            }),
          ),
        );
      }),
    );
  }

  Widget _buildDayCell({
    required DateTime date,
    required int colIndex,
    required bool isFirstDayOfMonth,
    required bool isLastDayOfMonth,
  }) {
    final normalized = _normalize(date);
    final nowNormalized = _normalize(DateTime.now());
    final isPast = normalized.isBefore(_firstDate) || normalized.isAfter(_lastDate);
    final isToday = _isSameDay(normalized, nowNormalized);

    final isStart = _startDate != null && _isSameDay(normalized, _startDate!);
    final isEnd = _endDate != null && _isSameDay(normalized, _endDate!);
    final isInRange = _startDate != null &&
        _endDate != null &&
        normalized.isAfter(_startDate!) &&
        normalized.isBefore(_endDate!);

    final isSingleDaySelection = isStart && isEnd;
    final hasRange = _startDate != null && _endDate != null && !_isSameDay(_startDate!, _endDate!);

    // Range Ribbon Styling
    Widget ribbon = const SizedBox();
    if (isInRange) {
      final roundLeft = colIndex == 0 || isFirstDayOfMonth;
      final roundRight = colIndex == 6 || isLastDayOfMonth;
      ribbon = Container(
        height: 38,
        decoration: BoxDecoration(
          color: ModernDatePickerColors.tealLight,
          borderRadius: BorderRadius.horizontal(
            left: Radius.circular(roundLeft ? 12 : 0),
            right: Radius.circular(roundRight ? 12 : 0),
          ),
        ),
      );
    } else if (hasRange && isStart) {
      ribbon = Row(
        children: [
          const Expanded(child: SizedBox()),
          Expanded(
            child: Container(
              height: 38,
              decoration: const BoxDecoration(
                color: ModernDatePickerColors.tealLight,
              ),
            ),
          ),
        ],
      );
    } else if (hasRange && isEnd) {
      ribbon = Row(
        children: [
          Expanded(
            child: Container(
              height: 38,
              decoration: const BoxDecoration(
                color: ModernDatePickerColors.tealLight,
              ),
            ),
          ),
          const Expanded(child: SizedBox()),
        ],
      );
    }

    Color textColor;
    FontWeight fontWeight;
    if (isStart || isEnd) {
      textColor = Colors.white;
      fontWeight = FontWeight.w700;
    } else if (isPast) {
      textColor = ModernDatePickerColors.textDisabled;
      fontWeight = FontWeight.w400;
    } else if (isInRange) {
      textColor = ModernDatePickerColors.primaryNavy;
      fontWeight = FontWeight.w600;
    } else {
      textColor = ModernDatePickerColors.primaryNavy;
      fontWeight = FontWeight.w500;
    }

    final locale = Localizations.localeOf(context).toString();
    return Semantics(
      button: !isPast,
      enabled: !isPast,
      selected: isStart || isEnd || isInRange,
      label: '${DateFormat.yMMMMd(locale).format(date)}${isStart ? ', selected start date' : ''}${isEnd ? ', selected end date' : ''}',
      child: GestureDetector(
        onTap: isPast ? null : () => _onDayTapped(date),
        behavior: HitTestBehavior.opaque,
        child: SizedBox(
          height: 44,
          child: Stack(
            alignment: Alignment.center,
            children: [
              ribbon,
              if (isStart || isEnd || isSingleDaySelection)
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: ModernDatePickerColors.tealPrimary,
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      '${date.day}',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: fontWeight,
                        color: textColor,
                      ),
                    ),
                  ),
                  if (isToday && !isStart && !isEnd) ...[
                    const SizedBox(height: 2),
                    Container(
                      width: 4,
                      height: 4,
                      decoration: const BoxDecoration(
                        color: ModernDatePickerColors.tealPrimary,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLegendAndReset(_PickerStrings strings) {
    return Wrap(
      alignment: WrapAlignment.spaceBetween,
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: 12,
      runSpacing: 8,
      children: [
        FittedBox(
          fit: BoxFit.scaleDown,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: const BoxDecoration(
                  color: ModernDatePickerColors.tealPrimary,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 6),
              Text(
                strings.selectedDatesLegend,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: ModernDatePickerColors.textMuted,
                ),
              ),
            ],
          ),
        ),
        FittedBox(
          fit: BoxFit.scaleDown,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 10,
                height: 10,
                decoration: BoxDecoration(
                  color: ModernDatePickerColors.tealLight,
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
              const SizedBox(width: 6),
              Text(
                strings.travelPeriodLegend,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: ModernDatePickerColors.textMuted,
                ),
              ),
            ],
          ),
        ),
        TextButton(
          onPressed: (_startDate != null || _endDate != null) ? _onReset : null,
          style: TextButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            minimumSize: Size.zero,
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          ),
          child: Text(
            strings.reset,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: (_startDate != null || _endDate != null)
                  ? ModernDatePickerColors.primaryNavy
                  : ModernDatePickerColors.textDisabled,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildDurationCard(_PickerStrings strings) {
    final days = _calculatedDays;
    final nights = _calculatedNights;

    String headline;
    if (_isRangeComplete) {
      headline = strings.formatDuration(days, nights);
    } else if (_startDate != null) {
      headline = strings.departureSelected;
    } else {
      headline = strings.selectYourDates;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: ModernDatePickerColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: ModernDatePickerColors.borderSubtle),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.wb_sunny_outlined,
            color: ModernDatePickerColors.tealPrimary,
            size: 22,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  strings.yourTripDuration,
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                    color: ModernDatePickerColors.textMuted,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  headline,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: ModernDatePickerColors.primaryNavy,
                  ),
                ),
              ],
            ),
          ),
          if (_isRangeComplete) ...[
            const SizedBox(width: 8),
            const Icon(
              Icons.check_circle_rounded,
              color: ModernDatePickerColors.tealPrimary,
              size: 22,
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildStickyBottomBar(_PickerStrings strings) {
    final isEnabled = _isRangeComplete;

    return Container(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
      decoration: const BoxDecoration(
        color: ModernDatePickerColors.background,
        border: Border(
          top: BorderSide(color: ModernDatePickerColors.borderSubtle),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: double.infinity,
            height: 52,
            child: ElevatedButton(
              onPressed: isEnabled ? _onConfirm : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: ModernDatePickerColors.buttonDark,
                disabledBackgroundColor: ModernDatePickerColors.buttonDisabled,
                elevation: isEnabled ? 2 : 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(26),
                ),
              ),
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      isEnabled ? strings.confirmTravelDates : strings.selectTravelDates,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: isEnabled
                            ? Colors.white
                            : ModernDatePickerColors.textMuted,
                      ),
                    ),
                    if (isEnabled) ...[
                      const SizedBox(width: 8),
                      const Icon(
                        Icons.arrow_forward_rounded,
                        size: 18,
                        color: Colors.white,
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            strings.subtext,
            style: const TextStyle(
              fontSize: 12,
              color: ModernDatePickerColors.textMuted,
            ),
          ),
        ],
      ),
    );
  }
}

/// A Modal Bottom Sheet wrapper presenting the [ModernDateRangePicker] with
/// responsive constraints and a drag handle.
class ModernDateRangePickerSheet extends StatelessWidget {
  const ModernDateRangePickerSheet({
    super.key,
    this.initialDateRange,
    this.firstDate,
    this.lastDate,
    this.appTitle,
    this.stepText,
    this.title,
    this.subtitle,
    this.showProgressBar = false,
    this.confirmButtonText,
    this.subtext,
  });

  final DateTimeRange? initialDateRange;
  final DateTime? firstDate;
  final DateTime? lastDate;
  final String? appTitle;
  final String? stepText;
  final String? title;
  final String? subtitle;
  final bool showProgressBar;
  final String? confirmButtonText;
  final String? subtext;

  @override
  Widget build(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);
    final maxHeight = mediaQuery.size.height * 0.92;

    return Container(
      constraints: BoxConstraints(maxHeight: maxHeight),
      decoration: const BoxDecoration(
        color: ModernDatePickerColors.background,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: ClipRRect(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        child: Column(
          children: [
            Center(
              child: Container(
                width: 36,
                height: 4,
                margin: const EdgeInsets.only(top: 10, bottom: 6),
                decoration: BoxDecoration(
                  color: ModernDatePickerColors.borderSubtle,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            Expanded(
              child: ModernDateRangePicker(
                initialDateRange: initialDateRange,
                firstDate: firstDate,
                lastDate: lastDate,
                appTitle: appTitle,
                stepText: stepText,
                title: title,
                subtitle: subtitle,
                showProgressBar: showProgressBar,
                confirmButtonText: confirmButtonText,
                subtext: subtext,
                onDateRangeSelected: (range) {
                  Navigator.of(context).pop(range);
                },
                onCancel: () {
                  Navigator.of(context).pop();
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Shows the [ModernDateRangePicker] as a modern modal bottom sheet, returning
/// a [Future<DateTimeRange?>] when confirmed.
Future<DateTimeRange?> showModernDateRangePicker({
  required BuildContext context,
  DateTimeRange? initialDateRange,
  DateTime? firstDate,
  DateTime? lastDate,
  String? appTitle,
  String? stepText,
  String? title,
  String? subtitle,
  bool showProgressBar = false,
  String? confirmButtonText,
  String? subtext,
}) {
  return showModalBottomSheet<DateTimeRange>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (context) => ModernDateRangePickerSheet(
      initialDateRange: initialDateRange,
      firstDate: firstDate,
      lastDate: lastDate,
      appTitle: appTitle,
      stepText: stepText,
      title: title,
      subtitle: subtitle,
      showProgressBar: showProgressBar,
      confirmButtonText: confirmButtonText,
      subtext: subtext,
    ),
  );
}
