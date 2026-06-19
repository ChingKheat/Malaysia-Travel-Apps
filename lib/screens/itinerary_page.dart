import 'package:flutter/material.dart';

import '../core/demo_feedback.dart';
import '../data/sample_data.dart';
import '../widgets/app_header.dart';
import '../widgets/demo_tap.dart';
import '../widgets/stop_card.dart';
import '../widgets/summary_bar.dart';
import 'place_detail_page.dart';

class ItineraryPage extends StatefulWidget {
  const ItineraryPage({super.key});

  @override
  State<ItineraryPage> createState() => _ItineraryPageState();
}

class _ItineraryPageState extends State<ItineraryPage> {
  int _selectedDay = 0;

  static const _dayLabels = ['Day 1', 'Day 2', 'Day 3'];
  static const _daySummaries = [
    'Batu Caves, Central Market & Jalan Alor',
    'KLCC Park, Pavilion & Petronas Towers',
    'Melaka day trip & Jonker Street food walk',
  ];

  void _selectDay(int index) {
    if (_selectedDay == index) return;
    setState(() => _selectedDay = index);
    showDemoSnackBar(
      context,
      'Showing ${_dayLabels[index]} — ${_daySummaries[index]}',
      icon: Icons.calendar_today_outlined,
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
      children: [
        AppHeader(
          title: 'My Itinerary',
          subtitle: '${_dayLabels[_selectedDay]} - Kuala Lumpur',
        ),
        const SizedBox(height: 14),
        Row(
          children: List.generate(
            _dayLabels.length,
            (index) => DayPill(
              label: _dayLabels[index],
              active: _selectedDay == index,
              onTap: () => _selectDay(index),
            ),
          ),
        ),
        const SizedBox(height: 18),
        ...sampleStops.map(
          (stop) => StopCard(
            stop: stop,
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => PlaceDetailPage(stop: stop)),
            ),
          ),
        ),
        const SizedBox(height: 12),
        const SummaryBar(),
        const SizedBox(height: 14),
        OutlinedButton.icon(
          onPressed: () => showDemoSheet(
            context,
            title: 'Edit Itinerary',
            body:
                'Drag stops to reorder, swap activities, or adjust visit times. '
                'In this demo, your Day ${_selectedDay + 1} plan stays synced with the route map.',
            icon: Icons.edit_calendar_outlined,
            actionLabel: 'Continue editing',
          ),
          icon: const Icon(Icons.edit_calendar_outlined),
          label: const Text('Edit Itinerary'),
          style: demoOutlinedButtonStyle(),
        ),
      ],
    );
  }
}

class DayPill extends StatelessWidget {
  const DayPill({
    super.key,
    required this.label,
    required this.onTap,
    this.active = false,
  });

  final String label;
  final VoidCallback onTap;
  final bool active;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: DemoTapCard(
        onTap: onTap,
        margin: const EdgeInsets.only(right: 8),
        borderRadius: 14,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: active
                ? Theme.of(context).colorScheme.primary
                : Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: active
                  ? Theme.of(context).colorScheme.primary
                  : const Color(0xFFE6E9F4),
            ),
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: active ? Colors.white : const Color(0xFF151A3A),
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
      ),
    );
  }
}
