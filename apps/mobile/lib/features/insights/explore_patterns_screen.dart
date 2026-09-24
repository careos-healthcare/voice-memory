import 'dart:async';

import 'package:archiveme_mobile/core/config/v1_capability_registry.dart';
import 'package:archiveme_mobile/core/di/archive_feed_providers.dart';
import 'package:archiveme_mobile/design/archive_mobile_typography.dart';
import 'package:archiveme_mobile/features/insights/pattern_exploration_conversation_notifier.dart';
import 'package:archiveme_mobile/features/insights/pattern_exploration_conversation_state.dart';
import 'package:archiveme_mobile/features/insights/widgets/evidence_connection_graph_viewer.dart';
import 'package:archiveme_mobile/models/journal_entry.dart';
import 'package:archiveme_mobile/theme/app_colors.dart';
import 'package:archiveme_mobile/theme/app_spacing.dart';
import 'package:archiveme_mobile/widgets/archive/view_evidence_inline_link.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Multi-turn pattern exploration chat. The route itself is ungated.
class ExplorePatternsScreen extends ConsumerStatefulWidget {
  const ExplorePatternsScreen({super.key, this.seed});

  final ExplorePatternsSeed? seed;

  static const Key screenKey = Key('explore_patterns_screen');
  static const Key messageListKey = Key('explore_patterns_message_list');
  static const Key composerFieldKey = Key('explore_patterns_composer_field');
  static const Key sendButtonKey = Key('explore_patterns_send_button');
  static const Key errorBannerKey = Key('explore_patterns_error_banner');
  static const Key seeHowThisConnectsKey = Key(
    'explore_patterns_see_how_this_connects',
  );

  static const String screenTitle = 'Explore patterns';
  static const String composerHint = 'Ask about a pattern';
  static const String sendTooltip = 'Send';
  static const String dismissErrorTooltip = 'Dismiss';
  static const String seeHowThisConnectsLabel = 'See how this connects';

  @override
  ConsumerState<ExplorePatternsScreen> createState() =>
      _ExplorePatternsScreenState();
}

class _ExplorePatternsScreenState extends ConsumerState<ExplorePatternsScreen> {
  final _composer = TextEditingController();
  final _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    // Same once-on-mount guard as CaregiverInvitationLinkListenerHost.bind():
    // initState, not build(), so a seeded send cannot re-fire on rebuild.
    final seed = widget.seed;
    if (seed != null) {
      final notifier = ref.read(patternExplorationConversationProvider.notifier)
        ..reset();
      if (seed.transcript.trim().isNotEmpty) {
        unawaited(notifier.sendMessage(seed.transcript));
      }
    }
  }

  @override
  void dispose() {
    _composer.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollController.hasClients) return;
      unawaited(
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut,
        ),
      );
    });
  }

  void _submit() {
    final text = _composer.text;
    if (text.trim().isEmpty) return;
    _composer.clear();
    setState(() {});
    unawaited(
      ref
          .read(patternExplorationConversationProvider.notifier)
          .sendMessage(text),
    );
  }

  @override
  Widget build(BuildContext context) {
    final conversation = ref.watch(patternExplorationConversationProvider);
    ref.listen<PatternExplorationConversationState>(
      patternExplorationConversationProvider,
      (previous, next) {
        if (previous?.messages.length != next.messages.length) {
          _scrollToBottom();
        }
      },
    );

    final canSend = !conversation.isSending && _composer.text.trim().isNotEmpty;

    return Scaffold(
      key: ExplorePatternsScreen.screenKey,
      backgroundColor: AppColors.backgroundPrimary,
      resizeToAvoidBottomInset: true,
      appBar: AppBar(
        backgroundColor: AppColors.backgroundPrimary,
        title: const Text(ExplorePatternsScreen.screenTitle),
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              key: ExplorePatternsScreen.messageListKey,
              controller: _scrollController,
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.sm,
                AppSpacing.sm,
                AppSpacing.sm,
                AppSpacing.xs,
              ),
              itemCount: conversation.messages.length,
              itemBuilder: (context, index) {
                return _PatternExplorationBubble(
                  message: conversation.messages[index],
                );
              },
            ),
          ),
          if (conversation.errorMessage case final error?)
            _PatternExplorationErrorBanner(
              message: error,
              onDismiss: () => ref
                  .read(patternExplorationConversationProvider.notifier)
                  .dismissError(),
            ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.sm,
                AppSpacing.xs,
                AppSpacing.xs,
                AppSpacing.sm,
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Expanded(
                    child: TextField(
                      key: ExplorePatternsScreen.composerFieldKey,
                      controller: _composer,
                      enabled: !conversation.isSending,
                      minLines: 1,
                      maxLines: 5,
                      textCapitalization: TextCapitalization.sentences,
                      textInputAction: TextInputAction.send,
                      onChanged: (_) => setState(() {}),
                      onSubmitted: (_) {
                        if (canSend) _submit();
                      },
                      decoration: InputDecoration(
                        hintText: ExplorePatternsScreen.composerHint,
                        isDense: true,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: AppSpacing.sm,
                          vertical: 12,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.xs),
                  IconButton(
                    key: ExplorePatternsScreen.sendButtonKey,
                    tooltip: ExplorePatternsScreen.sendTooltip,
                    onPressed: canSend ? _submit : null,
                    icon: conversation.isSending
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.send),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PatternExplorationBubble extends StatelessWidget {
  const _PatternExplorationBubble({required this.message});

  final PatternExplorationMessage message;

  @override
  Widget build(BuildContext context) {
    final isUser = message.isUser;
    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: MediaQuery.sizeOf(context).width * 0.8,
        ),
        child: Padding(
          padding: const EdgeInsets.only(bottom: AppSpacing.xs),
          child: Container(
            padding: const EdgeInsets.all(AppSpacing.sm),
            decoration: BoxDecoration(
              color: isUser
                  ? AppColors.accentLight
                  : AppColors.backgroundSecondary,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.borderSubtle),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  message.content,
                  style: ArchiveMobileTypography.explanationBody(context),
                ),
                if (message.isAssistant && message.citedEntryIds.isNotEmpty)
                  ViewEvidenceInlineLink(
                    entryIds: message.citedEntryIds,
                    surface: 'pattern_exploration',
                    claimContext: message.content,
                  ),
                ExploreCitationGraphAction(message: message),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _PatternExplorationErrorBanner extends StatelessWidget {
  const _PatternExplorationErrorBanner({
    required this.message,
    required this.onDismiss,
  });

  final String message;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.destructiveLight,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.sm,
          AppSpacing.xs,
          AppSpacing.xs,
          AppSpacing.xs,
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                key: ExplorePatternsScreen.errorBannerKey,
                message,
                style: ArchiveMobileTypography.responsiveHelper(
                  context,
                ).copyWith(color: AppColors.error),
              ),
            ),
            IconButton(
              tooltip: ExplorePatternsScreen.dismissErrorTooltip,
              onPressed: onDismiss,
              icon: const Icon(Icons.close, size: 20),
            ),
          ],
        ),
      ),
    );
  }
}

/// Opens the citation graph for an assistant reply with two or more sources.
class ExploreCitationGraphAction extends ConsumerWidget {
  const ExploreCitationGraphAction({required this.message, super.key});

  final PatternExplorationMessage message;

  static bool shouldShow(PatternExplorationMessage message) {
    return V1CapabilityRegistry.patternExploration &&
        message.isAssistant &&
        message.citedEntryIds.length >= 2;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!shouldShow(message)) return const SizedBox.shrink();

    return Align(
      alignment: AlignmentDirectional.centerStart,
      child: TextButton(
        key: ExplorePatternsScreen.seeHowThisConnectsKey,
        onPressed: () => _openSheet(context, ref),
        style: TextButton.styleFrom(
          foregroundColor: AppColors.accentPrimary,
          padding: const EdgeInsets.symmetric(horizontal: 6),
          minimumSize: const Size(0, 40),
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        ),
        child: const Text(ExplorePatternsScreen.seeHowThisConnectsLabel),
      ),
    );
  }

  void _openSheet(BuildContext context, WidgetRef ref) {
    unawaited(
      showEvidenceConnectionGraphSheet(
        context,
        message: message,
        getById: (id) => _lookupEntry(ref, id),
      ),
    );
  }

  Future<JournalEntry?> _lookupEntry(WidgetRef ref, String id) async {
    try {
      return await ref.read(journalStoreProvider).getById(id);
    } on Object {
      return null;
    }
  }
}
