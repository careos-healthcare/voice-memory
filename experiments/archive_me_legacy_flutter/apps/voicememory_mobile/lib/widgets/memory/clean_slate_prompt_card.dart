import 'package:flutter/material.dart';

import '../../features/memory/clean_slate_prompt_store.dart';
import '../../features/memory/cross_thread_confirmation.dart';
import '../../features/memory/entry_memory_mode.dart';
import '../../features/memory/entry_thread_scope.dart';
import '../../features/memory/memory_control_model.dart';
import '../../features/memory/memory_scope.dart';
import '../../features/memory/memory_scope_policy.dart';
import '../../features/memory/topic_shift_decision.dart';
import '../../features/archive_packs/cross_pack_confirmation.dart';
import '../../theme/app_spacing.dart';
import '../../theme/voicememory_cards.dart';
import 'new_thread_sheet.dart';

abstract class CleanSlatePromptCopy {
  CleanSlatePromptCopy._();

  static const String title = 'New direction?';
  static const String body =
      'This entry may be separate from your recent archive context.';
  static const String useArchiveContext = 'Use archive context';
  static const String keepSeparate = 'Keep separate';
  static const String startNewThread = 'Start new thread';
  static const String notNow = 'Not now';

  static const List<String> all = [
    title,
    body,
    useArchiveContext,
    keepSeparate,
    startNewThread,
    notNow,
  ];
}

/// Compact prompt when recent archive context may not fit this entry.
class CleanSlatePromptCard extends StatelessWidget {
  const CleanSlatePromptCard({
    super.key,
    required this.decision,
    required this.entryCount,
    this.cardType = MemoryCardType.threadReturn,
    this.source = 'record',
    this.onChanged,
  });

  final TopicShiftDecision decision;
  final int entryCount;
  final MemoryCardType cardType;
  final String source;
  final VoidCallback? onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const Key('clean_slate_prompt_card'),
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.sm),
      decoration: VoiceMemoryCards.flat(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            CleanSlatePromptCopy.title,
            style: Theme.of(context).textTheme.titleSmall,
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            CleanSlatePromptCopy.body,
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: AppSpacing.sm),
          Wrap(
            spacing: AppSpacing.xs,
            runSpacing: AppSpacing.xs,
            children: [
              OutlinedButton(
                key: const Key('clean_slate_use_archive_context'),
                onPressed: () => _useArchiveContext(context),
                child: const Text(CleanSlatePromptCopy.useArchiveContext),
              ),
              OutlinedButton(
                key: const Key('clean_slate_keep_separate'),
                onPressed: () => _keepSeparate(context),
                child: const Text(CleanSlatePromptCopy.keepSeparate),
              ),
              OutlinedButton(
                key: const Key('clean_slate_start_new_thread'),
                onPressed: () => _startNewThread(context),
                child: const Text(CleanSlatePromptCopy.startNewThread),
              ),
            ],
          ),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(
              key: const Key('clean_slate_not_now'),
              onPressed: () => _notNow(context),
              child: const Text(CleanSlatePromptCopy.notNow),
            ),
          ),
        ],
      ),
    );
  }

  void _useArchiveContext(BuildContext context) {
    CleanSlatePromptStore.chooseUseArchiveContext(
      entryCount: entryCount,
      source: source,
      decision: decision,
    );
    EntryMemoryModeSession.select(
      EntryMemoryMode.useArchiveContext,
      entryCount: entryCount,
    );
    if (MemoryScopePolicy.scope == MemoryScope.ask) {
      MemoryScopePolicy.connectApprovedForNextSave = true;
    }
    CrossThreadConfirmation.approve(cardType);
    CrossPackConfirmation.approve(cardType.id);
    onChanged?.call();
  }

  void _keepSeparate(BuildContext context) {
    CleanSlatePromptStore.chooseKeepSeparate(
      entryCount: entryCount,
      source: source,
      decision: decision,
    );
    EntryMemoryModeSession.select(
      EntryMemoryMode.keepSeparate,
      entryCount: entryCount,
    );
    onChanged?.call();
  }

  Future<void> _startNewThread(BuildContext context) async {
    final name = await showNewThreadSheet(context);
    if (name == null || name.trim().isEmpty) return;
    CleanSlatePromptStore.chooseStartNewThread(
      entryCount: entryCount,
      source: source,
      decision: decision,
    );
    EntryThreadScopeSession.setPendingNewThreadName(name);
    EntryMemoryModeSession.select(
      EntryMemoryMode.useArchiveContext,
      entryCount: entryCount,
    );
    onChanged?.call();
  }

  void _notNow(BuildContext context) {
    CleanSlatePromptStore.dismissForSession(
      entryCount: entryCount,
      source: source,
      decision: decision,
    );
    onChanged?.call();
  }
}
