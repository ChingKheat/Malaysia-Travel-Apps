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
  final ScrollController _scrollController = ScrollController();

  final List<AssistantMessage> _messages = [];
  bool _isTyping = false;
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
    _scrollController.dispose();
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

  Future<void> _handleSendMessage(String text) async {
    if (_isTyping) return;
    final validationError = _service.validatePrompt(text);

    if (validationError != null) {
      demoHaptic();
      showDemoSnackBar(context, validationError, icon: Icons.info_outline);
      return;
    }

    demoHaptic();

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
    final questions = [
      (Icons.wb_cloudy_outlined, l.assistantPromptWeather),
      (Icons.restaurant_outlined, l.assistantPromptFood),
      (Icons.train_outlined, l.assistantPromptTransport),
      (Icons.route_outlined, l.assistantPromptItinerary),
    ];
    Widget choices(ValueChanged<String> select) => Column(
      children: [
        for (final (icon, question) in questions)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: ListTile(
              tileColor: AppColors.nightSurface,
              shape: RoundedRectangleBorder(
                side: const BorderSide(color: AppColors.line),
                borderRadius: BorderRadius.circular(12),
              ),
              leading: Icon(icon, color: AppColors.primary),
              title: Text(
                question,
                style: const TextStyle(color: AppColors.ink),
              ),
              trailing: const Icon(Icons.chevron_right, color: AppColors.muted),
              onTap: () => select(question),
            ),
          ),
      ],
    );
    return Column(
      children: [
        // Chat Messages Stream
        Expanded(
          child: Material(
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
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    AssistantChatBubble(
                      message: message,
                      onSelectChip: (chip) => _handleSendMessage(chip),
                    ),
                    if (index == 0 && _messages.length == 1)
                      choices(_handleSendMessage),
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
                if (_messages.length > 1)
                  Expanded(
                    child: FilledButton.icon(
                      icon: const Icon(Icons.chat_bubble_outline),
                      label: Text(l.assistantChooseQuestion),
                      onPressed: _isTyping
                          ? null
                          : () async {
                              final selected =
                                  await showModalBottomSheet<String>(
                                    context: context,
                                    backgroundColor: AppColors.nightCanvas,
                                    showDragHandle: true,
                                    builder: (sheet) => SafeArea(
                                      child: SingleChildScrollView(
                                        padding: const EdgeInsets.all(16),
                                        child: choices(
                                          (value) =>
                                              Navigator.pop(sheet, value),
                                        ),
                                      ),
                                    ),
                                  );
                              if (mounted && selected != null)
                                await _handleSendMessage(selected);
                            },
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
