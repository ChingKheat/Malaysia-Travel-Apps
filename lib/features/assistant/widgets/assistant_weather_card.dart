import 'package:smart_travel_planner/l10n/localized_labels.dart';
import 'package:flutter/material.dart';
import 'package:smart_travel_planner/core/theme/app_colors.dart';
import 'package:smart_travel_planner/features/assistant/models/assistant_message.dart';
import 'package:smart_travel_planner/shared/utils/demo_feedback.dart';

class AssistantWeatherCard extends StatelessWidget {
  const AssistantWeatherCard({super.key, required this.alert});

  final AssistantWeatherAlert alert;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            const Color(0xFFF3F4FD),
            AppColors.sky.withValues(alpha: 0.8),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.2)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x06111827),
            blurRadius: 8,
            offset: Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.thunderstorm_rounded,
                  size: 18,
                  color: AppColors.primary,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${alert.city} • ${alert.temperature}',
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                        color: AppColors.ink,
                      ),
                    ),
                    Text(
                      alert.condition,
                      style: const TextStyle(
                        fontSize: 11,
                        color: AppColors.muted,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: AppColors.warning.withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.umbrella_rounded,
                      size: 12,
                      color: Color(0xFFB45309),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      context.l10n.valueRain(
                        (alert.rainProbability).toString(),
                      ),
                      style: const TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFFB45309),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            alert.advisory,
            style: const TextStyle(
              fontSize: 12,
              height: 1.4,
              color: AppColors.ink,
            ),
          ),
          if (alert.suggestedIndoorPlace != null) ...[
            const SizedBox(height: 10),
            InkWell(
              onTap: () {
                demoHaptic();
                showDemoSnackBar(
                  context,
                  context.l10n
                      .rainSafeScheduleAppliedValueSwappedInForAfternoon(
                        (alert.suggestedIndoorPlace).toString(),
                      ),
                  icon: Icons.check_circle_outline_rounded,
                );
              },
              borderRadius: BorderRadius.circular(10),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 7,
                ),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: AppColors.primary.withValues(alpha: 0.2),
                  ),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.swap_horiz_rounded,
                      size: 16,
                      color: AppColors.primary,
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        context.l10n.swapToIndoorValue(
                          (alert.suggestedIndoorPlace).toString(),
                        ),
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: AppColors.primary,
                        ),
                      ),
                    ),
                    const Icon(
                      Icons.arrow_forward_ios_rounded,
                      size: 11,
                      color: AppColors.primary,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
