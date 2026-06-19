import 'package:flutter/material.dart';

import '../core/app_colors.dart';
import '../core/app_decorations.dart';
import 'demo_tap.dart';

class FormTile extends StatelessWidget {
  const FormTile({
    super.key,
    required this.label,
    required this.value,
    required this.icon,
    this.onTap,
  });

  final String label;
  final String value;
  final IconData icon;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          FieldLabel(label),
          const SizedBox(height: 7),
          DemoTapCard(
            onTap: onTap,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
              decoration: cardDecoration(),
              child: Row(
                children: [
                  Icon(icon, color: AppColors.primary, size: 20),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      value,
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                  ),
                  const Icon(Icons.keyboard_arrow_down, color: AppColors.muted),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class TravelersSection extends StatelessWidget {
  const TravelersSection({
    super.key,
    required this.adultsController,
    required this.seniorsController,
    required this.childrenController,
    this.scrollController,
  });

  final TextEditingController adultsController;
  final TextEditingController seniorsController;
  final TextEditingController childrenController;
  final ScrollController? scrollController;

  static String summary({
    required TextEditingController adultsController,
    required TextEditingController seniorsController,
    required TextEditingController childrenController,
  }) {
    final parts = <String>[];
    final adults = adultsController.text.trim();
    final seniors = seniorsController.text.trim();
    final children = childrenController.text.trim();

    if (adults.isNotEmpty && adults != '0') {
      parts.add('$adults Adult${adults == '1' ? '' : 's'}');
    }
    if (seniors.isNotEmpty && seniors != '0') {
      parts.add('$seniors Senior${seniors == '1' ? '' : 's'}');
    }
    if (children.isNotEmpty && children != '0') {
      parts.add('$children Child${children == '1' ? '' : 'ren'}');
    }

    return parts.isEmpty ? 'Add travelers' : parts.join(', ');
  }

  @override
  Widget build(BuildContext context) {
    final rows = [
      _TravelerCountRow(
        label: 'Adults',
        controller: adultsController,
        hintText: '0',
        showIcon: true,
      ),
      const Divider(height: 1, color: AppColors.line),
      _TravelerCountRow(
        label: 'Seniors',
        controller: seniorsController,
        hintText: '0',
      ),
      const Divider(height: 1, color: AppColors.line),
      _TravelerCountRow(
        label: 'Children',
        controller: childrenController,
        hintText: '0',
      ),
    ];

    if (scrollController != null) {
      return ListView(
        controller: scrollController,
        padding: const EdgeInsets.fromLTRB(14, 4, 14, 8),
        children: rows,
      );
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const FieldLabel('Travelers'),
          const SizedBox(height: 7),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
            decoration: cardDecoration(),
            child: Column(children: rows),
          ),
        ],
      ),
    );
  }
}

class _TravelerCountRow extends StatelessWidget {
  const _TravelerCountRow({
    required this.label,
    required this.controller,
    required this.hintText,
    this.showIcon = false,
  });

  final String label;
  final TextEditingController controller;
  final String hintText;
  final bool showIcon;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          if (showIcon) ...[
            const Icon(Icons.group_outlined, color: AppColors.primary, size: 20),
            const SizedBox(width: 12),
          ] else
            const SizedBox(width: 32),
          Expanded(
            child: Text(
              label,
              style: const TextStyle(
                fontWeight: FontWeight.w700,
                color: AppColors.ink,
              ),
            ),
          ),
          SizedBox(
            width: 72,
            child: TextField(
              controller: controller,
              keyboardType: TextInputType.number,
              textAlign: TextAlign.center,
              scrollPadding: const EdgeInsets.only(bottom: 160),
              decoration: InputDecoration(
                hintText: hintText,
                hintStyle: const TextStyle(
                  color: AppColors.muted,
                  fontWeight: FontWeight.w500,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(color: AppColors.line),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(color: AppColors.line),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(color: AppColors.primary),
                ),
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 8,
                  vertical: 10,
                ),
              ),
              style: const TextStyle(fontWeight: FontWeight.w800),
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
        fontWeight: FontWeight.w900,
        color: AppColors.ink,
        fontSize: 13,
      ),
    );
  }
}
