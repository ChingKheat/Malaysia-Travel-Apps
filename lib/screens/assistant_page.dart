import 'package:flutter/material.dart';

import '../core/app_colors.dart';
import '../core/app_decorations.dart';
import '../core/demo_feedback.dart';
import '../widgets/app_header.dart';
import '../widgets/demo_tap.dart';

class AssistantPage extends StatelessWidget {
  const AssistantPage({super.key});

  void _showAnswer(BuildContext context, String title, String answer) {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (context) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 10),
            Text(
              answer,
              style: const TextStyle(color: AppColors.muted, height: 1.4),
            ),
            const SizedBox(height: 18),
            FilledButton(
              onPressed: () => Navigator.pop(context),
              style: primaryFilledButtonStyle(),
              child: const Text('Got it'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
      children: [
        const AppHeader(
          title: 'Trip Assistant',
          subtitle: 'AI help, translation and weather alerts',
        ),
        const SizedBox(height: 18),
        Container(
          padding: const EdgeInsets.all(18),
          decoration: cardDecoration(AppColors.primary),
          child: const Text(
            "Hi! I'm your travel assistant. I can recommend places, translate itinerary details, and update your plan when weather changes.",
            style: TextStyle(
              color: Colors.white,
              height: 1.4,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        const SizedBox(height: 16),
        AssistantPrompt(
          icon: Icons.place_outlined,
          label: 'Recommend places to visit',
          onTap: () => _showAnswer(
            context,
            'Recommended Places',
            'Based on your Food and Shopping interests, add Central Market, Jalan Alor and Pavilion KL.',
          ),
        ),
        AssistantPrompt(
          icon: Icons.thunderstorm_outlined,
          label: 'Is it going to rain today?',
          onTap: () => _showAnswer(
            context,
            'Weather Check',
            'Light rain is possible after 3:00 PM. The plan keeps KLCC and Pavilion as indoor backup stops.',
          ),
        ),
        AssistantPrompt(
          icon: Icons.restaurant_outlined,
          label: 'Best local food to try?',
          onTap: () => _showAnswer(
            context,
            'Local Food',
            'Try nasi lemak, char kuey teow, satay, roti canai and cendol around Jalan Alor.',
          ),
        ),
        AssistantPrompt(
          icon: Icons.translate,
          label: 'Translate my itinerary',
          onTap: () => _showAnswer(
            context,
            'Translation',
            'Batu Caves is shown as Gua Batu in Malay. The app can prepare English, Malay and Chinese itinerary labels.',
          ),
        ),
        const SizedBox(height: 18),
        const TranslationCard(),
      ],
    );
  }
}

class AssistantPrompt extends StatelessWidget {
  const AssistantPrompt({
    super.key,
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return DemoTapCard(
      onTap: onTap,
      margin: const EdgeInsets.only(bottom: 10),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 15),
        decoration: cardDecoration(),
        child: Row(
          children: [
            Icon(icon, color: AppColors.primary),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                label,
                style: const TextStyle(fontWeight: FontWeight.w800),
              ),
            ),
            const Icon(
              Icons.arrow_forward_ios,
              size: 14,
              color: AppColors.muted,
            ),
          ],
        ),
      ),
    );
  }
}

class TranslationCard extends StatefulWidget {
  const TranslationCard({super.key});

  @override
  State<TranslationCard> createState() => _TranslationCardState();
}

class _TranslationCardState extends State<TranslationCard> {
  int _language = 0;

  static const _languages = ['English', 'Bahasa Melayu', 'Chinese'];
  static const _samples = [
    'Batu Caves — A famous limestone hill with temples and cultural attractions.',
    'Gua Batu — Bukit batu kapur terkenal dengan kuil dan tarikan budaya.',
    '黑风洞 — 著名的石灰岩山，有寺庙和文化景点。',
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Multi-language Support',
            style: TextStyle(fontWeight: FontWeight.w900, color: AppColors.ink),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: List.generate(
              _languages.length,
              (index) => ChoiceChip(
                label: Text(_languages[index]),
                selected: _language == index,
                selectedColor: AppColors.primary.withValues(alpha: 0.16),
                onSelected: (_) {
                  setState(() => _language = index);
                  showDemoSnackBar(
                    context,
                    'Itinerary labels switched to ${_languages[index]}.',
                    icon: Icons.translate,
                  );
                },
              ),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            _samples[_language],
            style: const TextStyle(color: AppColors.muted, height: 1.4),
          ),
        ],
      ),
    );
  }
}
