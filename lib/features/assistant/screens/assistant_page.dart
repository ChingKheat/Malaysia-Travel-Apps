import 'package:smart_travel_planner/l10n/localized_labels.dart';
import 'package:flutter/material.dart';
import 'package:smart_travel_planner/core/theme/app_colors.dart';
import 'package:smart_travel_planner/features/assistant/models/assistant_message.dart';
import 'package:smart_travel_planner/features/assistant/services/travel_assistant_service.dart';
import 'package:smart_travel_planner/features/assistant/widgets/assistant_chat_bubble.dart';
import 'package:smart_travel_planner/features/assistant/widgets/assistant_typing_indicator.dart';
import 'package:smart_travel_planner/shared/utils/demo_feedback.dart';

class AssistantPage extends StatefulWidget {
  const AssistantPage({super.key});

  @override
  State<AssistantPage> createState() => _AssistantPageState();
}

class _AssistantPageState extends State<AssistantPage> {
  final TravelAssistantService _service = TravelAssistantService();
  final TextEditingController _textController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final FocusNode _focusNode = FocusNode();

  final List<AssistantMessage> _messages = [];
  bool _isTyping = false;

  final List<String> _quickPrompts = [
    '🌧️ Is it going to rain in KL today?',
    '🍜 Best Halal food near Bukit Bintang',
    '🏛️ Cultural etiquette for Batu Caves',
    '🚇 How to get from KL Sentral to KLCC',
    '🗣️ Useful Malay travel phrases',
    '🛍️ Top indoor shopping and museums',
  ];

  @override
  void initState() {
    super.initState();
    _loadInitialMessage();
  }

  void _loadInitialMessage() {
    setState(() {
      _messages.clear();
      _messages.add(_service.getInitialGreeting());
    });
  }

  @override
  void dispose() {
    _textController.dispose();
    _scrollController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _handleSendMessage([String? overrideText]) async {
    final text = overrideText ?? _textController.text;
    final validationError = _service.validatePrompt(text);

    if (validationError != null) {
      demoHaptic();
      showDemoSnackBar(context, validationError, icon: Icons.info_outline);
      return;
    }

    demoHaptic();
    _textController.clear();

    final userMessage = AssistantMessage(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      text: text.trim(),
      isUser: true,
      timestamp: DateTime.now(),
    );

    setState(() {
      _messages.add(userMessage);
      _isTyping = true;
    });
    _scrollToBottom();

    // Call service to get context-aware response
    final response = await _service.askAssistant(text.trim());

    if (!mounted) return;

    setState(() {
      _isTyping = false;
      _messages.add(response);
    });
    _scrollToBottom();
  }

  void _switchLanguage(AssistantLanguage language) {
    if (_service.currentLanguage == language) return;
    demoHaptic();
    setState(() {
      _service.currentLanguage = language;
      _loadInitialMessage();
    });
    showDemoSnackBar(
      context,
      context.l10n.assistantLanguageSetToValue((language.label).toString()),
      icon: Icons.translate_rounded,
    );
  }

  void _confirmClearChat() {
    demoHaptic();
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(context.l10n.clearChatHistory),
        content: Text(
          context.l10n.thisWillResetYourConversationWithTheTravelAssistant,
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(context.l10n.cancel),
          ),
          FilledButton(
            onPressed: () {
              Navigator.pop(ctx);
              _loadInitialMessage();
              showDemoSnackBar(
                context,
                context.l10n.chatHistoryCleared,
                icon: Icons.delete_sweep_rounded,
              );
            },
            style: FilledButton.styleFrom(backgroundColor: AppColors.primary),
            child: Text(context.l10n.clear),
          ),
        ],
      ),
    );
  }

  void _simulateVoiceInput() {
    demoHaptic();
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => Padding(
        padding: EdgeInsets.fromLTRB(
          20,
          8,
          20,
          24 + MediaQuery.paddingOf(ctx).bottom,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            CircleAvatar(
              radius: 24,
              backgroundColor: AppColors.primary.withValues(alpha: 0.12),
              child: const Icon(Icons.mic_rounded, color: AppColors.primary),
            ),
            const SizedBox(height: 12),
            Text(
              context.l10n.voiceTravelAssistant,
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 8),
            Text(
              context
                  .l10n
                  .listeningForVoiceCommandsInEnglishMalayOrChineseTapBelowToSendASampleSpokenQuery,
              style: TextStyle(color: AppColors.muted, height: 1.4),
            ),
            const SizedBox(height: 18),
            FilledButton.icon(
              onPressed: () {
                Navigator.pop(ctx);
                _handleSendMessage(
                  'Recommend 2 indoor spots if it rains near KLCC this afternoon.',
                );
              },
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.primary,
                minimumSize: const Size.fromHeight(48),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              icon: const Icon(Icons.play_arrow_rounded),
              label: Text(
                context.l10n.trySpokenQuery,
                style: TextStyle(fontWeight: FontWeight.w800),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Sub-header Bar: Status, Language Pill, and Clear Chat
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: const BoxDecoration(
            color: Colors.white,
            border: Border(
              bottom: BorderSide(color: AppColors.line, width: 0.8),
            ),
          ),
          child: Row(
            children: [
              // AI Online Status Indicator
              Container(
                width: 8,
                height: 8,
                margin: const EdgeInsets.only(right: 6),
                decoration: const BoxDecoration(
                  color: Color(0xFF10B981),
                  shape: BoxShape.circle,
                ),
              ),
              Expanded(
                child: Text(
                  context.l10n.gemini15FlashMalaysianTravelAi,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: AppColors.muted,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              // Language Selector Menu
              PopupMenuButton<AssistantLanguage>(
                initialValue: _service.currentLanguage,
                tooltip: context.l10n.assistantResponseLanguage,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
                onSelected: _switchLanguage,
                itemBuilder: (context) => [
                  const PopupMenuItem(
                    value: AssistantLanguage.english,
                    child: Text('English (EN)'),
                  ),
                  const PopupMenuItem(
                    value: AssistantLanguage.malay,
                    child: Text('Bahasa Melayu (MS)'),
                  ),
                  const PopupMenuItem(
                    value: AssistantLanguage.chinese,
                    child: Text('中文 (ZH)'),
                  ),
                ],
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: AppColors.primary.withValues(alpha: 0.2),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.translate_rounded,
                        size: 13,
                        color: AppColors.primary,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        _service.currentLanguage.code.toUpperCase(),
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          color: AppColors.primary,
                        ),
                      ),
                      const Icon(
                        Icons.arrow_drop_down,
                        size: 16,
                        color: AppColors.primary,
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 6),
              // Clear Chat
              IconButton(
                onPressed: _confirmClearChat,
                icon: const Icon(
                  Icons.refresh_rounded,
                  size: 19,
                  color: AppColors.muted,
                ),
                tooltip: context.l10n.resetConversation,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
              ),
            ],
          ),
        ),

        // Quick Suggestion Chips Carousel
        Container(
          height: 44,
          color: const Color(0xFFF9FAFD),
          child: ListView.separated(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
            scrollDirection: Axis.horizontal,
            itemCount: _quickPrompts.length,
            separatorBuilder: (context, index) => const SizedBox(width: 6),
            itemBuilder: (context, index) {
              final prompt = _quickPrompts[index];
              return InkWell(
                onTap: () => _handleSendMessage(prompt),
                borderRadius: BorderRadius.circular(16),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 11,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppColors.line),
                    boxShadow: const [
                      BoxShadow(
                        color: Color(0x04111827),
                        blurRadius: 4,
                        offset: Offset(0, 1),
                      ),
                    ],
                  ),
                  child: Center(
                    child: Text(
                      context.tr(prompt),
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: AppColors.ink,
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ),

        // Chat Messages Stream
        Expanded(
          child: Container(
            color: const Color(0xFFF9FAFD),
            child: ListView.builder(
              controller: _scrollController,
              padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
              itemCount: _messages.length + (_isTyping ? 1 : 0),
              itemBuilder: (context, index) {
                if (index == _messages.length && _isTyping) {
                  return const AssistantTypingIndicator();
                }
                final message = _messages[index];
                return AssistantChatBubble(
                  message: message,
                  onSelectChip: (chip) => _handleSendMessage(chip),
                );
              },
            ),
          ),
        ),

        // Bottom Input Bar
        Container(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
          decoration: const BoxDecoration(
            color: Colors.white,
            border: Border(top: BorderSide(color: AppColors.line, width: 0.8)),
          ),
          child: SafeArea(
            top: false,
            child: Row(
              children: [
                // Voice input button
                IconButton(
                  onPressed: _simulateVoiceInput,
                  icon: const Icon(
                    Icons.mic_none_rounded,
                    color: AppColors.primary,
                  ),
                  tooltip: context.l10n.voiceSearch,
                  style: IconButton.styleFrom(
                    backgroundColor: AppColors.primary.withValues(alpha: 0.08),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                // Text Input Field
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF3F4F8),
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(color: AppColors.line),
                    ),
                    child: TextField(
                      controller: _textController,
                      focusNode: _focusNode,
                      style: const TextStyle(
                        fontSize: 13.5,
                        color: AppColors.ink,
                      ),
                      decoration: InputDecoration(
                        hintText: context.l10n.askPlacesFoodWeatherOrPlans,
                        hintStyle: TextStyle(
                          fontSize: 12.5,
                          color: AppColors.muted,
                        ),
                        border: InputBorder.none,
                        isDense: true,
                        contentPadding: EdgeInsets.symmetric(vertical: 11),
                      ),
                      textInputAction: TextInputAction.send,
                      onSubmitted: (_) => _handleSendMessage(),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                // Send Button
                IconButton.filled(
                  onPressed: () => _handleSendMessage(),
                  icon: const Icon(
                    Icons.arrow_upward_rounded,
                    size: 20,
                    color: Colors.white,
                  ),
                  tooltip: context.l10n.sendPrompt,
                  style: IconButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    shape: const CircleBorder(),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
