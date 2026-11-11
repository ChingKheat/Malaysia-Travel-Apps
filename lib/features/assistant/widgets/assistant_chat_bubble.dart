import 'package:flutter/material.dart';
import 'package:smart_travel_planner/core/theme/app_colors.dart';
import 'package:smart_travel_planner/features/assistant/models/assistant_message.dart';
import 'package:smart_travel_planner/features/assistant/widgets/assistant_place_card.dart';
import 'package:smart_travel_planner/features/assistant/widgets/assistant_weather_card.dart';

class AssistantChatBubble extends StatelessWidget {
  const AssistantChatBubble({
    super.key,
    required this.message,
    this.onSelectChip,
  });

  final AssistantMessage message;
  final ValueChanged<String>? onSelectChip;

  String _formatTime(DateTime time) {
    final hour = time.hour > 12 ? time.hour - 12 : (time.hour == 0 ? 12 : time.hour);
    final minute = time.minute.toString().padLeft(2, '0');
    final period = time.hour >= 12 ? 'PM' : 'AM';
    return '$hour:$minute $period';
  }

  @override
  Widget build(BuildContext context) {
    if (message.isUser) {
      return _buildUserBubble();
    }
    return _buildAssistantBubble(context);
  }

  Widget _buildUserBubble() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14, left: 40),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: const BoxDecoration(
              color: AppColors.primary,
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(18),
                topRight: Radius.circular(4),
                bottomLeft: Radius.circular(18),
                bottomRight: Radius.circular(18),
              ),
              boxShadow: [
                BoxShadow(
                  color: Color(0x186652E8),
                  blurRadius: 8,
                  offset: Offset(0, 3),
                ),
              ],
            ),
            child: Text(
              message.text,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 13.5,
                fontWeight: FontWeight.w600,
                height: 1.4,
              ),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            _formatTime(message.timestamp),
            style: const TextStyle(
              fontSize: 10,
              color: AppColors.muted,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAssistantBubble(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16, right: 18),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // AI Robot Avatar
          Container(
            width: 32,
            height: 32,
            margin: const EdgeInsets.only(top: 2),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [AppColors.primary, Color(0xFF8675F7)],
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
            child: const Icon(Icons.smart_toy_rounded, color: Colors.white, size: 17),
          ),
          const SizedBox(width: 10),
          // Response Content
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 12),
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
                        color: Color(0x06111827),
                        blurRadius: 10,
                        offset: Offset(0, 3),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        message.text,
                        style: const TextStyle(
                          color: AppColors.ink,
                          fontSize: 13.5,
                          height: 1.45,
                        ),
                      ),
                      // Weather card if present
                      if (message.weatherAlert != null)
                        AssistantWeatherCard(alert: message.weatherAlert!),
                      // Place suggestion cards if present
                      if (message.places.isNotEmpty)
                        ...message.places.map((place) => AssistantPlaceCard(place: place)),
                    ],
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _formatTime(message.timestamp),
                  style: const TextStyle(
                    fontSize: 10,
                    color: AppColors.muted,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                // Follow up recommendation chips
                if (message.followUpChips.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: message.followUpChips.map((chip) {
                      return ActionChip(
                        label: Text(
                          chip,
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: AppColors.primary,
                          ),
                        ),
                        backgroundColor: Colors.white,
                        side: BorderSide(color: AppColors.primary.withValues(alpha: 0.25)),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        onPressed: () => onSelectChip?.call(chip),
                      );
                    }).toList(),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
