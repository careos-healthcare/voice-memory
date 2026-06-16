import 'package:flutter/material.dart';

import '../../design/archive_mobile_typography.dart';
import '../../features/memory/archive_thread.dart';
import '../../features/memory/archive_thread_store.dart';
import '../../features/memory/memory_authority_framing_engine.dart';
import '../../features/memory/memory_connection_rules.dart';
import '../../features/memory/memory_control_model.dart';
import '../../features/memory/memory_control_store.dart';
import '../../features/memory/memory_reliability_check.dart';
import '../../features/memory/memory_scope.dart';
import '../../features/memory/memory_scope_policy.dart';
import '../../features/memory/next_entry_fresh_mode.dart';
import '../../features/memory/wrong_thread_feedback.dart';
import '../../features/memory/memory_priority_decision.dart';
import '../../features/memory/not_important_feedback.dart';
import '../../features/pressure_retention/pressure_check_in_record.dart';
import '../../services/activation_funnel_analytics.dart';
import '../../services/app_services.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_spacing.dart';
import 'new_thread_sheet.dart';

/// Compact memory correction actions on memory-used cards.
class MemoryConnectionActionsRow extends StatefulWidget {
  const MemoryConnectionActionsRow({
    super.key,
    required this.cardType,
    this.onChanged,
  });

  final MemoryCardType cardType;
  final VoidCallback? onChanged;

  @override
  State<MemoryConnectionActionsRow> createState() =>
      _MemoryConnectionActionsRowState();
}

class _MemoryConnectionActionsRowState
    extends State<MemoryConnectionActionsRow> {
  String? _thanksLine;

  List<PressureCheckInRecord> get _candidates =>
      MemoryAuthorityFrameLog.candidatesFor(widget.cardType);

  void _keepConnected() {
    MemoryConnectionRules.keepConnected(widget.cardType);
    NotImportantFeedback.clearDemotion(widget.cardType);
    ActivationFunnelAnalytics.track(
      ActivationFunnelAnalytics.memoryConnectionKeepConnected,
      cardType: widget.cardType.id,
      memoryScope: MemoryScopePolicy.scope.id,
    );
    setState(() => _thanksLine = MemoryControlCopy.keepConnectedThanks);
    widget.onChanged?.call();
  }

  void _notRelated() {
    MemoryControlStore.markNotRelated(widget.cardType);
    ActivationFunnelAnalytics.track(
      ActivationFunnelAnalytics.memoryMarkedNotRelated,
      cardType: widget.cardType.id,
    );
    ActivationFunnelAnalytics.track(
      ActivationFunnelAnalytics.memoryConnectionNotRelated,
      cardType: widget.cardType.id,
      memoryScope: MemoryScopePolicy.scope.id,
    );
    setState(() => _thanksLine = MemoryControlCopy.notRelatedThanks);
    widget.onChanged?.call();
  }

  void _notImportant() {
    final entryId = _candidates.isNotEmpty ? _candidates.first.entryId : null;
    NotImportantFeedback.markNotImportant(widget.cardType, entryId: entryId);
    setState(() => _thanksLine = MemoryPriorityCopy.notImportantThanks);
    widget.onChanged?.call();
  }

  void _futureFresh() {
    MemoryConnectionRules.treatFutureAsNew(widget.cardType);
    ActivationFunnelAnalytics.track(
      ActivationFunnelAnalytics.memoryConnectionFutureFresh,
      cardType: widget.cardType.id,
      memoryScope: MemoryScopePolicy.scope.id,
    );
    setState(() => _thanksLine = MemoryControlCopy.futureFreshThanks);
    widget.onChanged?.call();
  }

  Future<void> _wrongThread() async {
    final result = await showModalBottomSheet<_WrongThreadChoice>(
      context: context,
      showDragHandle: true,
      builder: (_) => WrongThreadFeedbackSheet(cardType: widget.cardType),
    );
    if (!mounted || result == null) return;
    switch (result) {
      case _WrongThreadChoice.keepSeparate:
        WrongThreadFeedback.keepSeparate(
          widget.cardType,
          threadId: CrossThreadDetector.primaryThreadId(_candidates),
        );
        setState(
          () => _thanksLine = MemoryControlCopy.wrongThreadKeepSeparateThanks,
        );
      case _WrongThreadChoice.chooseThread:
        setState(() => _thanksLine = MemoryControlCopy.keepConnectedThanks);
      case _WrongThreadChoice.futureFresh:
        _futureFresh();
        return;
    }
    widget.onChanged?.call();
  }

  @override
  Widget build(BuildContext context) {
    if (_thanksLine != null) {
      return Padding(
        key: Key('memory_connection_thanks_${widget.cardType.id}'),
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Text(
          _thanksLine!,
          style: ArchiveMobileTypography.responsiveHelper(
            context,
          ).copyWith(color: AppColors.textSecondary),
        ),
      );
    }

    return Wrap(
      key: Key('memory_connection_actions_${widget.cardType.id}'),
      spacing: AppSpacing.xs,
      runSpacing: 4,
      children: [
        _action(context, MemoryControlCopy.keepConnectedLabel, _keepConnected),
        _action(context, MemoryControlCopy.wrongThreadLabel, _wrongThread),
        _action(context, MemoryControlCopy.notRelatedLabel, _notRelated),
        _action(context, MemoryPriorityCopy.notImportantLabel, _notImportant),
        _action(context, MemoryControlCopy.futureFreshLabel, _futureFresh),
        if (NextEntryFreshMode.isRelevant)
          _action(context, MemoryControlCopy.freshNextEntryShortLabel, () {
            NextEntryFreshMode.enable();
            setState(
              () => _thanksLine = MemoryControlCopy.freshNextEntryHelper,
            );
          }),
      ],
    );
  }

  Widget _action(BuildContext context, String label, VoidCallback onTap) {
    return TextButton(
      style: TextButton.styleFrom(
        minimumSize: const Size(0, 36),
        padding: const EdgeInsets.symmetric(horizontal: 8),
        foregroundColor: AppColors.textSecondary,
      ),
      onPressed: onTap,
      child: Text(
        label,
        style: ArchiveMobileTypography.responsiveHelper(
          context,
        ).copyWith(color: AppColors.textSecondary, fontWeight: FontWeight.w600),
      ),
    );
  }
}

enum _WrongThreadChoice { keepSeparate, chooseThread, futureFresh }

/// Wrong-thread correction sheet — thread names stay local only.
class WrongThreadFeedbackSheet extends StatefulWidget {
  const WrongThreadFeedbackSheet({super.key, required this.cardType});

  final MemoryCardType cardType;

  @override
  State<WrongThreadFeedbackSheet> createState() =>
      _WrongThreadFeedbackSheetState();
}

class _WrongThreadFeedbackSheetState extends State<WrongThreadFeedbackSheet> {
  List<ArchiveThread> _threads = const [];
  var _pickingThread = false;

  @override
  void initState() {
    super.initState();
    _loadThreads();
  }

  Future<void> _loadThreads() async {
    if (!AppServices.isInitialized) return;
    final threads = await ArchiveThreadStore.instance().loadAll();
    if (!mounted) return;
    setState(() => _threads = threads);
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        key: const Key('wrong_thread_feedback_sheet'),
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.md,
          AppSpacing.xs,
          AppSpacing.md,
          AppSpacing.md,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              MemoryControlCopy.wrongThreadTitle,
              style: ArchiveMobileTypography.responsiveSectionTitle(context),
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              MemoryControlCopy.wrongThreadBody,
              style: ArchiveMobileTypography.body(context),
            ),
            if (_pickingThread) ...[
              const SizedBox(height: AppSpacing.sm),
              for (final thread in _threads)
                ListTile(
                  key: Key('wrong_thread_pick_${thread.id}'),
                  title: Text(thread.name),
                  onTap: () {
                    WrongThreadFeedback.assignExplicitThread(
                      widget.cardType,
                      thread.id,
                    );
                    Navigator.pop(context, _WrongThreadChoice.chooseThread);
                  },
                ),
              ListTile(
                key: const Key('wrong_thread_pick_new'),
                title: const Text('New thread'),
                onTap: () async {
                  final name = await showNewThreadSheet(context);
                  if (!context.mounted || name == null || name.trim().isEmpty) {
                    return;
                  }
                  if (!AppServices.isInitialized) return;
                  final created = await ArchiveThreadStore.instance().create(
                    name.trim(),
                  );
                  if (!context.mounted || created == null) return;
                  WrongThreadFeedback.assignExplicitThread(
                    widget.cardType,
                    created.id,
                  );
                  Navigator.pop(context, _WrongThreadChoice.chooseThread);
                },
              ),
            ] else ...[
              const SizedBox(height: AppSpacing.sm),
              OutlinedButton(
                key: const Key('wrong_thread_keep_separate'),
                onPressed: () =>
                    Navigator.pop(context, _WrongThreadChoice.keepSeparate),
                child: Text(MemoryControlCopy.keepSeparateLabel),
              ),
              TextButton(
                key: const Key('wrong_thread_choose_thread'),
                onPressed: () => setState(() => _pickingThread = true),
                child: Text(MemoryControlCopy.chooseAnotherThreadLabel),
              ),
              TextButton(
                key: const Key('wrong_thread_future_fresh'),
                onPressed: () =>
                    Navigator.pop(context, _WrongThreadChoice.futureFresh),
                child: Text(MemoryControlCopy.futureFreshLabel),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
