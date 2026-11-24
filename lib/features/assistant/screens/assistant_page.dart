import '../widgets/assistant_stop_preview.dart';
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
  String? _starterDraft;

  bool _canSendDraft(String text) {
    final trimmed = text.trim();
    return !_isTyping && trimmed.length >= 2 && trimmed != _starterDraft;
  }

  void _startDraft(String prompt) {
    final draft = prompt.trim();
    _starterDraft = draft;
    final text = '$draft ';
    _textController.value = TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: text.length),
    );
    _focusNode.requestFocus();
  }

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
    if (_isTyping) return;
    final text = overrideText ?? _textController.text;
    if (overrideText == null && !_canSendDraft(text)) return;
    final validationError = _service.validatePrompt(text);

    if (validationError != null) {
      demoHaptic();
      showDemoSnackBar(context, validationError, icon: Icons.info_outline);
      return;
    }

    demoHaptic();
    _starterDraft = null;
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
    if (response.stopProposals.length == 1 && mounted) {
      await showAssistantStopPreview(context, response.stopProposals.single);
    }
  }

  void _switchLanguage(AssistantLanguage language) {
    if (_service.currentLanguage == language) return;
    demoHaptic();
    setState(() {
      _service.clearConversation();
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
              _service.clearConversation();
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

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final starters = [
      (l.assistantStarterWeather, () => _startDraft(l.assistantPromptWeather)),
      (l.assistantStarterFood, () => _handleSendMessage(l.assistantPromptFood)),
      (
        l.assistantStarterTransport,
        () => _startDraft(l.assistantPromptTransport),
      ),
      (
        l.assistantStarterItinerary,
        () => _handleSendMessage(l.assistantPromptItinerary),
      ),
    ];
    return Column(
      children: [
        // Chat Messages Stream
        Expanded(
          child: Container(
            color: AppColors.nightCanvas,
            child: ListView.builder(
              controller: _scrollController,
              padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
              itemCount: _messages.length + (_isTyping ? 1 : 0),
              itemBuilder: (context, index) {
                if (index == _messages.length && _isTyping) {
                  return const AssistantTypingIndicator();
                }
                final message = _messages[index];
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    AssistantChatBubble(
                      message: message,
                      onSelectChip: (chip) => _handleSendMessage(chip),
                    ),
                    if (index == 0 && _messages.length == 1)
                      for (var row = 0; row < starters.length; row += 2)
                        Padding(
                          padding: EdgeInsets.only(top: row == 0 ? 0 : 8),
                          child: IntrinsicHeight(
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                for (var column = 0; column < 2; column++) ...[
                                  if (column > 0) const SizedBox(width: 8),
                                  Expanded(
                                    child: OutlinedButton(
                                      style: OutlinedButton.styleFrom(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 12,
                                          vertical: 8,
                                        ),
                                        minimumSize: const Size(48, 48),
                                        foregroundColor: AppColors.primary,
                                      ),
                                      onPressed: starters[row + column].$2,
                                      child: Text(
                                        starters[row + column].$1,
                                        textAlign: TextAlign.center,
                                      ),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ),
                    for (final proposal in message.stopProposals)
                      OutlinedButton(
                        onPressed: _isTyping
                            ? null
                            : () => showAssistantStopPreview(context, proposal),
                        child: Text(
                          '${l.assistantPreviewStop} · ${proposal['place_name']}',
                        ),
                      ),
                  ],
                );
              },
            ),
          ),
        ),

        // Bottom Input Bar
        Container(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
          decoration: const BoxDecoration(
            color: AppColors.nightSurface,
            border: Border(top: BorderSide(color: AppColors.line, width: 0.8)),
          ),
          child: SafeArea(
            top: false,
            child: Row(
              children: [
                PopupMenuButton<String>(
                  enabled: !_isTyping,
                  tooltip: l.assistantChatOptions,
                  icon: const Icon(Icons.more_vert_rounded),
                  onSelected: (value) {
                    if (value == 'newChat') {
                      _confirmClearChat();
                      return;
                    }
                    _switchLanguage(AssistantLanguage.values.byName(value));
                  },
                  itemBuilder: (_) => [
                    PopupMenuItem<String>(
                      enabled: false,
                      child: Text(l.assistantResponseLanguage),
                    ),
                    for (final language in AssistantLanguage.values)
                      CheckedPopupMenuItem(
                        value: language.name,
                        checked: language == _service.currentLanguage,
                        child: Text(language.label),
                      ),
                    const PopupMenuDivider(),
                    PopupMenuItem(
                      value: 'newChat',
                      child: Text(l.assistantNewChat),
                    ),
                  ],
                ),
                const SizedBox(width: 4),
                // Text Input Field
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    decoration: BoxDecoration(
                      color: AppColors.nightRaised,
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
                ValueListenableBuilder<TextEditingValue>(
                  valueListenable: _textController,
                  builder: (context, value, child) => IconButton.filled(
                    onPressed: _canSendDraft(value.text)
                        ? () => _handleSendMessage()
                        : null,
                    icon: const Icon(Icons.arrow_upward_rounded, size: 20),
                    tooltip: l.sendPrompt,
                    style: IconButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: AppColors.onNightAccent,
                      shape: const CircleBorder(),
                      minimumSize: const Size(48, 48),
                    ),
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
