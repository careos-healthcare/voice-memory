import 'dart:async';

import 'package:archiveme_mobile/config/screenshot_mode.dart';
import 'package:archiveme_mobile/design/archive_mobile_typography.dart';
import 'package:archiveme_mobile/features/curiosity_loop/data/models/curiosity_reaction_record.dart';
import 'package:archiveme_mobile/features/curiosity_loop/data/repositories/curiosity_reaction_repository.dart';
import 'package:archiveme_mobile/features/curiosity_loop/domain/services/curiosity_prompt_resolver.dart';
import 'package:archiveme_mobile/features/curiosity_loop/models/curiosity_hook.dart';
import 'package:archiveme_mobile/features/curiosity_loop/repositories/curiosity_hook_repository.dart';
import 'package:archiveme_mobile/features/curiosity_loop/services/curiosity_telemetry_tracker.dart';
import 'package:archiveme_mobile/features/curiosity_loop/services/yesterdays_snapshot_coordinator.dart';
import 'package:archiveme_mobile/features/curiosity_loop/services/yesterdays_snapshot_engine.dart';
import 'package:archiveme_mobile/features/curiosity_loop/yesterdays_snapshot_copy.dart';
import 'package:archiveme_mobile/features/curiosity_loop/yesterdays_snapshot_reaction.dart';
import 'package:archiveme_mobile/features/curiosity_loop/yesterdays_snapshot_routes.dart';
import 'package:archiveme_mobile/models/journal_entry.dart';
import 'package:archiveme_mobile/services/app_services.dart';
import 'package:archiveme_mobile/services/journal_service.dart';
import 'package:archiveme_mobile/theme/app_colors.dart';
import 'package:archiveme_mobile/theme/app_spacing.dart';
import 'package:archiveme_mobile/theme/voicememory_cards.dart';
import 'package:archiveme_mobile/widgets/capture_entry_actions.dart';
import 'package:archiveme_mobile/widgets/pushed_screen_shell.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

enum _YesterdaysSnapshotPhase { snapshot, recording }

/// Fast yesterday recap → one-tap reaction → today's voice capture.
class YesterdaysSnapshotScreen extends StatefulWidget {
  const YesterdaysSnapshotScreen({
    required this.hook, super.key,
    this.repository,
    this.journalService,
    this.initialSummaries,
    this.skipJournalLoad = false,
    this.onRecordingHandoff,
    this.telemetryTracker,
    this.reactionRepository,
    this.promptResolver,
  });

  /// Test hook to bypass navigation and assert handoff timing.
  const YesterdaysSnapshotScreen.test({
    required this.hook, super.key,
    this.repository,
    this.journalService,
    this.initialSummaries,
    this.onRecordingHandoff,
    this.telemetryTracker,
    this.reactionRepository,
    this.promptResolver,
  }) : skipJournalLoad = true;

  final CuriosityHook hook;
  final CuriosityHookRepository? repository;
  final CuriosityReactionRepository? reactionRepository;
  final JournalService? journalService;
  final List<String>? initialSummaries;
  final bool skipJournalLoad;
  final void Function(String recordRoute)? onRecordingHandoff;
  final CuriosityTelemetryTracker? telemetryTracker;
  final CuriosityPromptResolver? promptResolver;

  @override
  State<YesterdaysSnapshotScreen> createState() =>
      _YesterdaysSnapshotScreenState();
}

class _YesterdaysSnapshotScreenState extends State<YesterdaysSnapshotScreen> {
  _YesterdaysSnapshotPhase _phase = _YesterdaysSnapshotPhase.snapshot;
  List<String> _summaries = const [];
  String _displayPrompt = '';
  bool _loading = true;
  bool _processingReaction = false;
  YesterdaysSnapshotReaction? _selectedReaction;
  var _recordingHandoffAttempted = false;
  var _snapshotViewTracked = false;

  CuriosityHookRepository get _repository =>
      widget.repository ?? LocalCuriosityHookRepository.instance();

  CuriosityReactionRepository get _reactionRepository =>
      widget.reactionRepository ?? LocalCuriosityReactionRepository.instance();

  CuriosityTelemetryTracker get _telemetry =>
      widget.telemetryTracker ?? const CuriosityTelemetryTracker();

  CuriosityPromptResolver get _promptResolver =>
      widget.promptResolver ?? CuriosityPromptResolver();

  @override
  void initState() {
    super.initState();
    unawaited(_initializeScreen());
  }

  Future<void> _initializeScreen() async {
    final seeded = widget.initialSummaries;
    var summaries = seeded ?? const <String>[];
    var loading = seeded == null;

    JournalEntry? hookEntry;
    JournalEntry? sourceEntry;

    if (!widget.skipJournalLoad && !ScreenshotMode.enabled) {
      final journal = widget.journalService ?? AppServices.instance.journal;
      hookEntry = await journal.getEntry(widget.hook.entryId);
      final sourceId = widget.hook.sourceEntryId?.trim();
      if (sourceId != null && sourceId.isNotEmpty) {
        sourceEntry = await journal.getEntry(sourceId);
      }
      if (seeded == null) {
        summaries = YesterdaysSnapshotEngine.build(
          hook: widget.hook,
          entry: hookEntry,
        ).summaries;
        loading = false;
      }
    } else if (seeded == null) {
      summaries = YesterdaysSnapshotEngine.build(hook: widget.hook).summaries;
      loading = false;
    }

    final displayPrompt = await _promptResolver.resolveDisplayPrompt(
      hook: widget.hook,
      sourceEntry: sourceEntry,
      hookEntry: hookEntry,
    );

    if (!mounted) return;
    setState(() {
      _summaries = summaries;
      _displayPrompt = displayPrompt;
      _loading = loading;
    });
    _trackSnapshotViewedOnce();
  }

  void _trackSnapshotViewedOnce() {
    if (_snapshotViewTracked) return;
    _snapshotViewTracked = true;
    _telemetry.trackSnapshotViewed(
      hookId: widget.hook.id,
      hookType: widget.hook.hookType.name,
    );
  }

  Future<void> _selectReaction(YesterdaysSnapshotReaction reaction) async {
    if (_processingReaction || _phase != _YesterdaysSnapshotPhase.snapshot) {
      return;
    }

    setState(() {
      _processingReaction = true;
      _selectedReaction = reaction;
    });

    _telemetry.trackReactionTapped(
      hookId: widget.hook.id,
      reaction: reaction.name,
    );

    final reactionRecord = CuriosityReactionRecord(
      id: '${widget.hook.id}_${reaction.name}',
      hookId: widget.hook.id,
      timestamp: DateTime.now().toUtc(),
      reactionType: reaction,
      primaryAnchor: widget.hook.primaryAnchor,
      hookType: widget.hook.hookType,
    );
    await _reactionRepository.logReaction(reactionRecord);

    unawaited(_repository.markConsumed(widget.hook.id));

    if (!mounted) return;
    setState(() {
      _processingReaction = false;
      _phase = _YesterdaysSnapshotPhase.recording;
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _triggerRecordingHandoff(source: 'reaction_handoff');
    });
  }

  void _triggerRecordingHandoff({required String source}) {
    if (_recordingHandoffAttempted) return;
    _recordingHandoffAttempted = true;

    _telemetry.trackMicAutostarted(hookId: widget.hook.id, source: source);

    final route = YesterdaysSnapshotRoutes.recordHandoff(
      prompt: _displayPrompt,
    );
    final override = widget.onRecordingHandoff;
    if (override != null) {
      override(route);
      return;
    }
    context.go(route);
  }

  Future<void> _dismissSnapshot() async {
    await YesterdaysSnapshotCoordinator.dismissForDay();
    if (!mounted) return;
    if (context.canPop()) {
      context.pop();
      return;
    }
    context.go(YesterdaysSnapshotCopy.recordRoute);
  }

  @override
  Widget build(BuildContext context) {
    final onSnapshotExit = _phase == _YesterdaysSnapshotPhase.snapshot
        ? _dismissSnapshot
        : null;
    return PushedScreenShell(
      title: _phase == _YesterdaysSnapshotPhase.snapshot
          ? YesterdaysSnapshotCopy.title
          : YesterdaysSnapshotCopy.recordingTitle,
      fallbackRoute: YesterdaysSnapshotCopy.recordRoute,
      showBottomDone: _phase == _YesterdaysSnapshotPhase.snapshot,
      doneLabel: 'Skip for now',
      onBack: onSnapshotExit,
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : AnimatedSwitcher(
              duration: const Duration(milliseconds: 220),
              child: _phase == _YesterdaysSnapshotPhase.snapshot
                  ? _buildSnapshotPhase(context)
                  : _buildRecordingPhase(context),
            ),
    );
  }

  Widget _buildSnapshotPhase(BuildContext context) {
    return SingleChildScrollView(
      key: const Key('yesterdays_snapshot_review'),
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            YesterdaysSnapshotCopy.hookEyebrow,
            style: ArchiveMobileTypography.cardLabel(
              context,
            ).copyWith(color: AppColors.textSecondary),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            _displayPrompt,
            key: const Key('yesterdays_snapshot_prompt'),
            style: ArchiveMobileTypography.listTitle(context),
          ),
          const SizedBox(height: AppSpacing.lg),
          _MicroReviewCard(summaries: _summaries),
          const SizedBox(height: AppSpacing.lg),
          Text(
            YesterdaysSnapshotCopy.reactionTitle,
            style: ArchiveMobileTypography.responsiveSectionTitle(context),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            YesterdaysSnapshotCopy.reactionHelper,
            style: ArchiveMobileTypography.explanationBody(
              context,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          _QuickReactionBar(
            selected: _selectedReaction,
            processing: _processingReaction,
            onSelected: _selectReaction,
          ),
        ],
      ),
    );
  }

  Widget _buildRecordingPhase(BuildContext context) {
    return SingleChildScrollView(
      key: const Key('yesterdays_snapshot_recording'),
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            _displayPrompt,
            key: const Key('yesterdays_snapshot_recording_prompt'),
            style: ArchiveMobileTypography.listTitle(context),
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            YesterdaysSnapshotCopy.recordingHelper,
            style: ArchiveMobileTypography.explanationBody(
              context,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          Container(
            padding: const EdgeInsets.all(AppSpacing.md),
            decoration: VoiceMemoryCards.standard(
              background: const Color(0xFFF7FAF6),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Icon(
                  Icons.mic_none_rounded,
                  size: 48,
                  color: AppColors.textPrimary.withValues(alpha: 0.85),
                  semanticLabel: 'Microphone ready',
                ),
                const SizedBox(height: AppSpacing.sm),
                CaptureEntryActions(
                  onRecord: () =>
                      _triggerRecordingHandoff(source: 'record_cta'),
                  recordButtonKey: const Key('yesterdays_snapshot_record_cta'),
                  recordButtonLabel: YesterdaysSnapshotCopy.recordCta,
                  typeCapturePrompt: _displayPrompt,
                  pressureMomentPresentation:
                      CapturePressureMomentPresentation.none,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _MicroReviewCard extends StatelessWidget {
  const _MicroReviewCard({required this.summaries});

  final List<String> summaries;

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const Key('yesterdays_snapshot_micro_review'),
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: VoiceMemoryCards.standard(
        background: const Color(0xFFF8FAF8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            YesterdaysSnapshotCopy.microReviewTitle,
            style: ArchiveMobileTypography.responsiveSectionTitle(context),
          ),
          const SizedBox(height: AppSpacing.sm),
          for (var i = 0; i < summaries.length; i++) ...[
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '•',
                  style: ArchiveMobileTypography.explanationBody(context),
                ),
                const SizedBox(width: AppSpacing.xs),
                Expanded(
                  child: Text(
                    summaries[i],
                    key: Key('yesterdays_snapshot_bullet_$i'),
                    style: ArchiveMobileTypography.explanationBody(context),
                  ),
                ),
              ],
            ),
            if (i != summaries.length - 1)
              const SizedBox(height: AppSpacing.xs),
          ],
        ],
      ),
    );
  }
}

class _QuickReactionBar extends StatelessWidget {
  const _QuickReactionBar({
    required this.selected,
    required this.processing,
    required this.onSelected,
  });

  final YesterdaysSnapshotReaction? selected;
  final bool processing;
  final ValueChanged<YesterdaysSnapshotReaction> onSelected;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      key: const Key('yesterdays_snapshot_reaction_bar'),
      spacing: AppSpacing.xs,
      runSpacing: AppSpacing.xs,
      children: [
        for (final reaction in YesterdaysSnapshotReaction.values)
          _ReactionChip(
            reaction: reaction,
            selected: selected == reaction,
            enabled: !processing,
            onTap: () => onSelected(reaction),
          ),
      ],
    );
  }
}

class _ReactionChip extends StatelessWidget {
  const _ReactionChip({
    required this.reaction,
    required this.selected,
    required this.enabled,
    required this.onTap,
  });

  final YesterdaysSnapshotReaction reaction;
  final bool selected;
  final bool enabled;
  final VoidCallback onTap;

  Color _background() {
    switch (reaction) {
      case YesterdaysSnapshotReaction.progressed:
        return const Color(0xFFEAF6EE);
      case YesterdaysSnapshotReaction.stuck:
        return const Color(0xFFFFF6E8);
      case YesterdaysSnapshotReaction.pivot:
        return const Color(0xFFFDECEC);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      enabled: enabled,
      selected: selected,
      label: reaction.semanticsLabel,
      child: Material(
        color: _background(),
        borderRadius: BorderRadius.circular(999),
        child: InkWell(
          key: Key('yesterdays_snapshot_reaction_${reaction.name}'),
          onTap: enabled ? onTap : null,
          borderRadius: BorderRadius.circular(999),
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 48),
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.md,
                vertical: AppSpacing.sm,
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    reaction.emoji,
                    style: const TextStyle(fontSize: 16),
                    semanticsLabel: '',
                  ),
                  const SizedBox(width: AppSpacing.xs),
                  Text(
                    reaction.label,
                    style: ArchiveMobileTypography.cardLabel(
                      context,
                    ).copyWith(color: AppColors.textPrimary),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}