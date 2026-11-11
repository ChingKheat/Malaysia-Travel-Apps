import 'package:smart_travel_planner/l10n/localized_labels.dart';
import 'package:flutter/material.dart';
import 'package:smart_travel_planner/core/theme/app_colors.dart';

class AssistantTypingIndicator extends StatefulWidget {
  const AssistantTypingIndicator({super.key});

  @override
  State<AssistantTypingIndicator> createState() =>
      _AssistantTypingIndicatorState();
}

class _AssistantTypingIndicatorState extends State<AssistantTypingIndicator>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Widget _buildDot(int index) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        final progress = (_controller.value - (index * 0.2)) % 1.0;
        final bounce = (progress < 0.5)
            ? (1.0 - (progress * 2 - 0.5).abs())
            : 0.0;
        return Transform.translate(
          offset: Offset(0, -4 * bounce),
          child: Container(
            width: 7,
            height: 7,
            margin: const EdgeInsets.symmetric(horizontal: 2.5),
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.4 + (0.6 * bounce)),
              shape: BoxShape.circle,
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [AppColors.primary, Color(0xFF9080F4)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: AppColors.primary.withValues(alpha: 0.25),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: const Icon(
              Icons.smart_toy_rounded,
              color: Colors.white,
              size: 17,
            ),
          ),
          const SizedBox(width: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(4),
                topRight: Radius.circular(18),
                bottomLeft: Radius.circular(18),
                bottomRight: Radius.circular(18),
              ),
              border: Border.all(color: AppColors.line),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x08111827),
                  blurRadius: 10,
                  offset: Offset(0, 4),
                ),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildDot(0),
                _buildDot(1),
                _buildDot(2),
                const SizedBox(width: 6),
                Text(
                  context.l10n.geminiIsThinking,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: AppColors.muted,
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
